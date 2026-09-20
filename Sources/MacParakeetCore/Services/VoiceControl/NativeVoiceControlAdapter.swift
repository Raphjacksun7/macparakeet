import AppKit
import ApplicationServices
import Foundation

public enum NativeVoiceControlError: Error, LocalizedError, Sendable {
    case permission, noWindow, changed, unsupported, excluded
    public var errorDescription: String? {
        switch self {
        case .permission: "Enable Accessibility for MacParakeet to control this app."
        case .noWindow: "No accessible window is available."
        case .changed: "The app or control changed. Please try again."
        case .unsupported: "This control does not support that operation."
        case .excluded: "Voice Control is unavailable in this app."
        }
    }
}

/// Actual AX handles never leave this actor. An ID belongs to exactly one snapshot.
/// Synchronous AX IPC uses a short messaging timeout and never runs on MainActor.
public actor NativeVoiceControlAdapter: VoiceControlAdapter {
    private struct Element: @unchecked Sendable { let value: AXUIElement }
    private struct BoundTarget {
        let element: Element
        let target: VoiceControlTarget
        let fingerprint: String
    }
    private var handles: [String: BoundTarget] = [:]
    private var applications: [String: Int32] = [:]
    private var current: VoiceControlSnapshot?
    private var window: Element?
    private var processID: Int32 = 0
    private var observedAt = ContinuousClock.now
    private var undoEdit: (element: Element, before: String, after: String, pid: Int32, time: Date)?
    private var undoTargetID: String?
    private let excludedBundleIDs: Set<String>
    private let maxNodes: Int

    public init(excludedBundleIDs: Set<String> = [
        "com.apple.keychainaccess", "com.1password.1password", "com.agilebits.onepassword7",
        "com.bitwarden.desktop", "com.apple.Passwords"
    ], maxNodes: Int = 180) {
        self.excludedBundleIDs = excludedBundleIDs
        self.maxNodes = min(180, max(1, maxNodes))
    }

    public func observe() async throws -> VoiceControlSnapshot {
        guard AXIsProcessTrusted() else { throw NativeVoiceControlError.permission }
        let context = await MainActor.run { () -> (Int32, String, String, [(Int32, String, String)])? in
            guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
            let running = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
            }.compactMap { app -> (Int32, String, String)? in
                guard let bundle = app.bundleIdentifier else { return nil }
                return (app.processIdentifier, app.localizedName ?? bundle, bundle)
            }
            return (app.processIdentifier, app.localizedName ?? "App", app.bundleIdentifier ?? "", running)
        }
        guard let (pid, name, bundle, running) = context else { throw NativeVoiceControlError.noWindow }
        guard !excludedBundleIDs.contains(bundle), pid != ProcessInfo.processInfo.processIdentifier else {
            throw NativeVoiceControlError.excluded
        }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15)
        guard let root = Self.element(app, kAXFocusedWindowAttribute) else { throw NativeVoiceControlError.noWindow }
        let snapshotID = UUID()
        handles.removeAll(); applications.removeAll(); undoTargetID = nil
        window = Element(value: root); processID = pid; observedAt = .now
        var targets: [VoiceControlTarget] = []
        var text: [String] = []
        var stack: [(AXUIElement, Int)] = [(root, 0)]
        if let menu = Self.element(app, kAXMenuBarAttribute) { stack.append((menu, 0)) }
        var visited: Set<CFHashCode> = []
        var count = 0
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        let focused = Self.element(app, kAXFocusedUIElementAttribute)
        while let (node, depth) = stack.popLast() {
            try Task.checkCancellation()
            guard count < maxNodes, ContinuousClock.now < deadline else { break }
            let hash = CFHash(node)
            guard visited.insert(hash).inserted else { continue }
            count += 1
            let role = Self.string(node, kAXRoleAttribute)
            guard !Self.isSecure(node, role: role) else { continue }
            let label = Self.label(node)
            let value = Self.string(node, kAXValueAttribute)
            let enabled = Self.attribute(node, kAXEnabledAttribute) as? Bool ?? true
            var operations: Set<VoiceControlOperation> = []
            var actionNames: CFArray?
            AXUIElementCopyActionNames(node, &actionNames)
            let actions = actionNames as? [String] ?? []
            if enabled, actions.contains(kAXPressAction) { operations.insert(.press) }
            if enabled, [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role),
               Self.settable(node, kAXValueAttribute) {
                operations.formUnion([.setValue, .insertText])
            }
            if role == kAXScrollAreaRole { operations.insert(.scroll) }
            if let focused, CFEqual(focused, node), enabled { operations.insert(.key) }
            if !operations.isEmpty {
                let id = "\(snapshotID.uuidString):\(targets.count)"
                let target = VoiceControlTarget(id: id, label: String(label.prefix(240)), role: role,
                    value: value.isEmpty ? nil : String(value.prefix(500)), operations: operations,
                    isNavigation: Self.isOrdinaryControl(node, role: role),
                    isFocused: focused.map { CFEqual($0, node) } ?? false,
                    selectedText: Self.completeSelection(node),
                    valueIsComplete: value.count <= 500)
                handles[id] = BoundTarget(element: Element(value: node), target: target,
                    fingerprint: Self.fingerprint(node))
                targets.append(target)
            } else if role == kAXStaticTextRole, !label.isEmpty || !value.isEmpty, text.joined().count < 3000 {
                text.append(String((label.isEmpty ? value : label).prefix(250)))
            }
            if depth < 18, let children = Self.attribute(node, kAXChildrenAttribute) as? [AXUIElement] {
                stack.append(contentsOf: children.prefix(250).reversed().map { ($0, depth + 1) })
            }
        }
        for (appPID, appName, appBundle) in running.prefix(15) where !excludedBundleIDs.contains(appBundle) {
            let id = "\(snapshotID.uuidString):app:\(appPID)"
            applications[id] = appPID
            targets.append(VoiceControlTarget(id: id, label: appName, role: "application", operations: [.activateApp], isNavigation: true))
        }
        if let undo = undoEdit, undo.pid == pid, Date().timeIntervalSince(undo.time) < 30,
           Self.string(undo.element.value, kAXValueAttribute) == undo.after {
            let id = "\(snapshotID.uuidString):undo"
            let target = VoiceControlTarget(id: id, label: "Undo last text edit", role: "undo", operations: [.press], isNavigation: true)
            targets.append(target)
            handles[id] = BoundTarget(element: undo.element, target: target, fingerprint: Self.fingerprint(undo.element.value))
            undoTargetID = id
        } else { undoEdit = nil }
        let title = Self.string(root, kAXTitleAttribute)
        let contextID = "ax:\(pid):\(CFHash(root))"
        let snapshot = VoiceControlSnapshot(id: snapshotID, contextID: contextID, applicationName: name,
            targets: targets, summary: String(([title] + text).joined(separator: "\n").prefix(4000)),
            isComplete: stack.isEmpty)
        current = snapshot
        return snapshot
    }

    public func execute(action: VoiceControlAction, snapshot: VoiceControlSnapshot,
                        authority: ActionAuthority) async throws -> VoiceControlReceipt {
        try authority.check()
        guard current?.id == snapshot.id, observedAt.duration(to: .now) < .seconds(20) else { throw NativeVoiceControlError.changed }
        try validateContext()
        if action.operation == .activateApp {
            guard let pid = applications[action.targetID] else { throw NativeVoiceControlError.changed }
            current = nil
            let activated = try await MainActor.run {
                try authority.perform { NSRunningApplication(processIdentifier: pid)?.activate() ?? false }
            }
            guard activated else { return VoiceControlReceipt(status: .failed, message: "Couldn’t activate that app.") }
            try await Task.sleep(for: .milliseconds(100))
            return VoiceControlReceipt(status: Self.frontmostPID() == pid ? .verified : .unknown,
                                       message: "Requested app activation.")
        }
        guard let bound = handles[action.targetID], bound.target.operations.contains(action.operation) else {
            throw NativeVoiceControlError.unsupported
        }
        let node = bound.element.value
        guard Self.fingerprint(node) == bound.fingerprint, !Self.isSecure(node, role: bound.target.role) else {
            throw NativeVoiceControlError.changed
        }
        // Consume the observation before dispatch: a thrown/unknown result cannot be replayed.
        current = nil
        let beforeValue = Self.string(node, kAXValueAttribute)
        if action.targetID == undoTargetID, let undo = undoEdit, action.operation == .press {
            undoEdit = nil
            guard undo.pid == processID, Date().timeIntervalSince(undo.time) < 30, beforeValue == undo.after else {
                throw NativeVoiceControlError.changed
            }
            let status = try authority.perform {
                try validateContext()
                guard Self.fingerprint(node) == bound.fingerprint else { throw NativeVoiceControlError.changed }
                return AXUIElementSetAttributeValue(node, kAXValueAttribute as CFString, undo.before as CFString)
            }
            return VoiceControlReceipt(status: status == .success && Self.string(node, kAXValueAttribute) == undo.before ? .verified : .unknown,
                                       message: "Checked the restored text.")
        }
        switch action.operation {
        case .setValue, .insertText:
            guard let supplied = action.value, supplied.utf16.count <= 32_000 else { throw NativeVoiceControlError.unsupported }
            let replacement: String
            if action.operation == .insertText {
                guard let range = Self.selectedRange(node), beforeValue.utf16.count <= 64_000,
                      range.location >= 0, range.length >= 0,
                      range.location <= beforeValue.utf16.count,
                      range.length <= beforeValue.utf16.count - range.location else {
                    throw NativeVoiceControlError.unsupported
                }
                replacement = (beforeValue as NSString).replacingCharacters(in: NSRange(location: range.location, length: range.length), with: supplied)
            } else { replacement = supplied }
            let status = try authority.perform {
                try validateContext()
                guard Self.fingerprint(node) == bound.fingerprint else { throw NativeVoiceControlError.changed }
                return AXUIElementSetAttributeValue(node, kAXValueAttribute as CFString, replacement as CFString)
            }
            guard status == .success else { return VoiceControlReceipt(status: .failed, message: "The app rejected the text change.") }
            if Self.string(node, kAXValueAttribute) == replacement {
                undoEdit = (Element(value: node), beforeValue, replacement, processID, Date())
            }
            return VoiceControlReceipt(status: Self.string(node, kAXValueAttribute) == replacement ? .verified : .unknown,
                                       message: "Checked the text field after the change.")
        case .press, .select:
            let status = try authority.perform {
                try validateContext()
                guard Self.fingerprint(node) == bound.fingerprint else { throw NativeVoiceControlError.changed }
                return AXUIElementPerformAction(node, kAXPressAction as CFString)
            }
            guard status == .success else { return VoiceControlReceipt(status: .failed, message: "The app rejected the press.") }
            try await Task.sleep(for: .milliseconds(120))
            // A successful AX return only proves dispatch. Controls with observable state
            // changes can be verified; generic buttons must remain unknown.
            if bound.target.role == kAXCheckBoxRole || bound.target.role == kAXRadioButtonRole {
                return VoiceControlReceipt(status: Self.string(node, kAXValueAttribute) != beforeValue ? .verified : .unknown,
                                           message: "Checked the control’s state.")
            }
            if bound.target.role == kAXPopUpButtonRole || bound.target.role == kAXMenuBarItemRole {
                let children = Self.attribute(node, kAXChildrenAttribute) as? [AXUIElement] ?? []
                if children.contains(where: { Self.string($0, kAXRoleAttribute) == kAXMenuRole }) {
                    return VoiceControlReceipt(status: .verified, message: "Menu opened.")
                }
            }
            return VoiceControlReceipt(status: .unknown, message: "Control pressed. Check the result before continuing.")
        case .key:
            guard let key = action.value, let code = Self.keyCodes[key.lowercased()] else { throw NativeVoiceControlError.unsupported }
            guard let focused = Self.element(AXUIElementCreateApplication(processID), kAXFocusedUIElementAttribute),
                  CFEqual(focused, node) else { throw NativeVoiceControlError.changed }
            try authority.perform {
                try validateContext()
                guard let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true),
                      let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) else {
                    throw NativeVoiceControlError.unsupported
                }
                down.setIntegerValueField(.eventSourceUserData, value: StreamingCursorEventMarker.userData)
                up.setIntegerValueField(.eventSourceUserData, value: StreamingCursorEventMarker.userData)
                down.postToPid(processID); up.postToPid(processID)
            }
            return VoiceControlReceipt(status: .unknown, message: "Key sent. Check the result before continuing.")
        case .scroll:
            let direction = action.value?.lowercased() ?? "down"
            guard ["up", "down"].contains(direction) else { throw NativeVoiceControlError.unsupported }
            let scrollbarAttribute = direction == "up" || direction == "down" ? kAXVerticalScrollBarAttribute : kAXHorizontalScrollBarAttribute
            guard let bar = Self.element(node, scrollbarAttribute),
                  let value = Self.attribute(bar, kAXValueAttribute) as? Double,
                  Self.settable(bar, kAXValueAttribute) else { throw NativeVoiceControlError.unsupported }
            let next = min(1, max(0, value + (direction == "down" ? 0.2 : -0.2)))
            let status = try authority.perform {
                try validateContext()
                return AXUIElementSetAttributeValue(bar, kAXValueAttribute as CFString, NSNumber(value: next))
            }
            let observed = Self.attribute(bar, kAXValueAttribute) as? Double
            return VoiceControlReceipt(status: status == .success && observed == next ? .verified : .unknown,
                                       message: "Checked the scroll position.")
        case .activateApp: throw NativeVoiceControlError.unsupported
        }
    }

    private func validateContext() throws {
        guard Self.frontmostPID() == processID, let window,
              let focused = Self.element(AXUIElementCreateApplication(processID), kAXFocusedWindowAttribute),
              CFEqual(focused, window.value) else { throw NativeVoiceControlError.changed }
    }
    private static let keyCodes: [String: CGKeyCode] = ["tab": 48, "escape": 53, "enter": 36, "return": 36,
        "left": 123, "right": 124, "down": 125, "up": 126, "backspace": 51, "delete": 117]
    private static func frontmostPID() -> Int32? {
        guard let app = element(AXUIElementCreateSystemWide(), kAXFocusedApplicationAttribute) else { return nil }
        var pid: pid_t = 0
        return AXUIElementGetPid(app, &pid) == .success ? pid : nil
    }
    private static func attribute(_ node: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(node, name as CFString, &value) == .success ? value : nil
    }
    private static func element(_ node: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(node, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value as AnyObject, to: AXUIElement.self)
    }
    private static func string(_ node: AXUIElement, _ name: String) -> String {
        if let value = attribute(node, name) as? String { return value }
        if let value = attribute(node, name) as? NSNumber { return value.stringValue }
        return ""
    }
    private static func label(_ node: AXUIElement) -> String {
        for key in [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute] {
            let value = string(node, key)
            if !value.isEmpty { return value }
        }
        return ""
    }
    private static func isSecure(_ node: AXUIElement, role: String) -> Bool {
        let subrole = string(node, kAXSubroleAttribute).lowercased()
        let name = label(node).lowercased()
        return subrole.contains("secure") || role.lowercased().contains("secure") ||
            ["password", "passcode", "one-time", "verification code", "api key", "secret", "credit card"].contains(where: name.contains)
    }
    private static func isOrdinaryControl(_ node: AXUIElement, role: String) -> Bool {
        if [kAXMenuBarItemRole, kAXPopUpButtonRole].contains(role) { return true }
        if role == "AXLink", let url = attribute(node, kAXURLAttribute) as? URL {
            return ["https", "http"].contains(url.scheme?.lowercased() ?? "")
        }
        return false
    }
    private static func fingerprint(_ node: AXUIElement) -> String {
        [string(node, kAXRoleAttribute), string(node, kAXSubroleAttribute), label(node),
         string(node, kAXValueAttribute), string(node, kAXEnabledAttribute),
         String(describing: attribute(node, kAXURLAttribute)),
         String(describing: selectedRange(node))].joined(separator: "\u{1f}")
    }
    private static func settable(_ node: AXUIElement, _ name: String) -> Bool {
        var result: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(node, name as CFString, &result) == .success && result.boolValue
    }
    private static func completeSelection(_ node: AXUIElement) -> String? {
        let selected = string(node, kAXSelectedTextAttribute)
        return selected.count <= 4000 ? selected : nil
    }
    private static func selectedRange(_ node: AXUIElement) -> CFRange? {
        guard let raw = attribute(node, kAXSelectedTextRangeAttribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        let value = unsafeDowncast(raw as AnyObject, to: AXValue.self)
        guard AXValueGetType(value) == .cfRange else { return nil }
        var range = CFRange()
        return AXValueGetValue(value, .cfRange, &range) ? range : nil
    }
}
