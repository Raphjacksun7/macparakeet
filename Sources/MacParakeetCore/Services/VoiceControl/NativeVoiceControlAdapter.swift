import AppKit
import ApplicationServices
import Foundation

public enum NativeVoiceControlError: Error, LocalizedError, Sendable, Equatable {
    case permission, noWindow, changed, unsupported, excluded, targetChanged, windowChanged, observationExpired
    public var errorDescription: String? {
        switch self {
        case .permission: "Enable Accessibility for MacParakeet to control this app."
        case .noWindow: "No accessible window is available."
        case .changed: "The app or control changed. Please try again."
        case .targetChanged: "The control’s contents or selection changed. Please repeat the request."
        case .windowChanged: "The focused app or window changed. Please repeat the request."
        case .observationExpired: "The observed interface expired. Please repeat the request."
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
    private var undoEdit: (element: Element, window: Element, before: String, after: String, pid: Int32, time: Date)?
    private var undoTargetID: String?
    private let excludedBundleIDs: Set<String>
    private let maxNodes: Int
    private let includeMenus: Bool
    private let includeApplications: Bool
    /// Chromium rebuilds its AX tree when these flags are first set. Ask once per process.
    private var chromiumAccessibilityPIDs: Set<Int32> = []

    public init(
        excludedBundleIDs: Set<String> = [
            "com.apple.keychainaccess", "com.1password.1password", "com.agilebits.onepassword7",
            "com.bitwarden.desktop", "com.apple.Passwords",
        ], maxNodes: Int = 600, includeMenus: Bool = true, includeApplications: Bool = true
    ) {
        self.excludedBundleIDs = excludedBundleIDs
        self.maxNodes = min(800, max(1, maxNodes))
        self.includeMenus = includeMenus; self.includeApplications = includeApplications
    }

    public func observe() async throws -> VoiceControlSnapshot {
        guard AXIsProcessTrusted() else { throw NativeVoiceControlError.permission }
        var last = NativeVoiceControlError.noWindow
        var acquired: (Int32, String, String, [(Int32, String, String)], AXUIElement)?
        for attempt in 0..<6 {
            if attempt > 0 { try await Task.sleep(for: .milliseconds(180)) }
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
            guard let (pid, name, bundle, running) = context else { last = .noWindow; continue }
            if excludedBundleIDs.contains(bundle) { throw NativeVoiceControlError.excluded }
            if pid == ProcessInfo.processInfo.processIdentifier { last = .excluded; continue }
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.15)
            guard let root = Self.focusedOrMainWindow(app) else { last = .noWindow; continue }
            acquired = (pid, name, bundle, running, root)
            break
        }
        guard let (pid, name, bundle, running, initialRoot) = acquired else { throw last }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15)
        try await enableChromiumAccessibilityIfNeeded(app: app, pid: pid, bundle: bundle)
        let root = Self.focusedOrMainWindow(app) ?? initialRoot
        let snapshotID = UUID()
        handles.removeAll(); applications.removeAll(); undoTargetID = nil
        window = Element(value: root); processID = pid; observedAt = .now
        var targets: [VoiceControlTarget] = []
        var text: [String] = []
        var stack: [(AXUIElement, Int, Bool)] = []
        if includeMenus, !Self.isBrowserBundle(bundle), let menu = Self.element(app, kAXMenuBarAttribute) {
            stack.append((menu, 0, false))
        }
        stack.append((root, 0, false))
        if let focused = Self.element(app, kAXFocusedUIElementAttribute) { stack.append((focused, 0, false)) }
        var visited: Set<CFHashCode> = []
        var count = 0
        var complete = true
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        let focused = Self.element(app, kAXFocusedUIElementAttribute)
        let isBrowser = Self.isBrowserBundle(bundle)
        var pending: [(target: VoiceControlTarget, bound: BoundTarget, inWeb: Bool)] = []
        while let (node, depth, inWebArea) = stack.popLast() {
            try Task.checkCancellation()
            guard count < maxNodes, ContinuousClock.now < deadline else { complete = false; break }
            let hash = CFHash(node)
            guard visited.insert(hash).inserted else { continue }
            count += 1
            let role = Self.string(node, kAXRoleAttribute)
            guard !Self.isSecure(node, role: role), Self.attribute(node, "AXHidden") as? Bool != true else { continue }
            var label = Self.label(node)
            let visible = Self.isVisible(node, within: root)
            let readableValue = visible ? Self.attribute(node, kAXValueAttribute) : nil
            let value = (readableValue as? String) ?? (readableValue as? NSNumber)?.stringValue ?? ""
            let enabled = Self.attribute(node, kAXEnabledAttribute) as? Bool ?? true
            var operations: Set<VoiceControlOperation> = []
            var actionNames: CFArray?
            AXUIElementCopyActionNames(node, &actionNames)
            let actions = actionNames as? [String] ?? []
            if visible { label = Self.actionLabel(label, value: value, role: role, pressable: actions.contains(kAXPressAction)) }
            if visible, enabled, actions.contains(kAXPressAction) { operations.insert(.press) }
            if visible, enabled {
                operations.formUnion(Self.textOperations(
                    role: role, readableValue: readableValue is String,
                    valueSettable: Self.settable(node, kAXValueAttribute),
                    selectionSettable: Self.settable(node, kAXSelectedTextAttribute)))
            }
            if visible, role == kAXScrollAreaRole { operations.insert(.scroll) }
            if visible, let focused, CFEqual(focused, node), enabled { operations.insert(.key) }
            var inWeb = inWebArea || role == "AXWebArea"
            if isBrowser, !inWeb, !operations.isEmpty { inWeb = Self.ancestorIsWebArea(node) }
            if !operations.isEmpty {
                let publicLabel = Self.contextLabel(label, role: role)
                let target = VoiceControlTarget(
                    id: "pending", label: String(publicLabel.prefix(240)), role: role,
                    value: value.isEmpty || publicLabel != label ? nil : String(value.prefix(500)), operations: operations,
                    isNavigation: Self.isOrdinaryControl(role: role, pressable: operations.contains(.press)),
                    isFocused: focused.map { CFEqual($0, node) } ?? false,
                    selectedText: Self.completeSelection(node),
                    valueIsComplete: value.count <= 500)
                pending.append(
                    (
                        target,
                        BoundTarget(
                            element: Element(value: node), target: target, fingerprint: Self.fingerprint(node)),
                        inWeb
                    ))
            } else if visible, role == kAXStaticTextRole, !label.isEmpty || !value.isEmpty, text.joined().count < 3000 {
                text.append(String((label.isEmpty ? value : label).prefix(250)))
            }
            let closedMenu = role == kAXMenuBarItemRole && (Self.attribute(node, kAXSelectedAttribute) as? Bool != true)
            if !closedMenu, let children = Self.attribute(node, kAXChildrenAttribute) as? [AXUIElement] {
                if depth < 32 {
                    if children.count > 250 { complete = false }
                    stack.append(contentsOf: children.prefix(250).reversed().map { ($0, depth + 1, inWeb) })
                } else if !children.isEmpty { complete = false }
            }
        }
        let hasWebContent = pending.contains { $0.inWeb }
        for item in pending
        where Self.keepOfferedControl(
            isBrowser: isBrowser, inWebArea: item.inWeb, hasWebContent: hasWebContent, label: item.target.label,
            role: item.target.role)
        {
            let id = "n:\(targets.count)"
            let target = VoiceControlTarget(
                id: id, label: item.target.label, role: item.target.role, value: item.target.value,
                operations: item.target.operations, isNavigation: item.target.isNavigation,
                isFocused: item.target.isFocused, selectedText: item.target.selectedText,
                valueIsComplete: item.target.valueIsComplete, consequence: item.target.consequence)
            handles[id] = BoundTarget(
                element: item.bound.element, target: target, fingerprint: item.bound.fingerprint)
            targets.append(target)
        }
        var seenApps = Set<String>()
        for (appPID, appName, appBundle) in running.prefix(includeApplications ? 15 : 0)
        where !excludedBundleIDs.contains(appBundle) && appPID != pid {
            let key = appName.lowercased()
            guard seenApps.insert(key).inserted else { continue }
            let id = "app:\(appPID)"
            applications[id] = appPID
            targets.append(
                VoiceControlTarget(
                    id: id, label: appName, role: "application", operations: [.activateApp], isNavigation: true))
        }
        if isBrowser {
            for destination in VoiceControlWebDestination.all {
                targets.append(
                    VoiceControlTarget(
                        id: destination.id, label: destination.label, role: "url",
                        operations: [.press], isNavigation: true))
            }
        }
        if let undo = undoEdit, undo.pid == pid, CFEqual(undo.window.value, root), Self.isVisible(undo.element.value),
            Date().timeIntervalSince(undo.time) < 30,
            Self.attribute(undo.element.value, kAXValueAttribute) as? String == undo.after
        {
            let id = "undo"
            let target = VoiceControlTarget(
                id: id, label: "Undo last text edit", role: "undo", operations: [.press], isNavigation: true)
            targets.append(target)
            handles[id] = BoundTarget(
                element: undo.element, target: target, fingerprint: Self.fingerprint(undo.element.value))
            undoTargetID = id
        } else {
            undoEdit = nil
        }
        let title = Self.string(root, kAXTitleAttribute)
        let contextID = "ax:\(pid):\(CFHash(root))"
        let snapshot = VoiceControlSnapshot(
            id: snapshotID, contextID: contextID, applicationName: name,
            targets: targets, summary: String(([title] + text).joined(separator: "\n").prefix(4000)),
            isComplete: complete && stack.isEmpty)
        current = snapshot
        return snapshot
    }

    public func execute(
        action: VoiceControlAction, snapshot: VoiceControlSnapshot,
        authority: ActionAuthority
    ) async throws -> VoiceControlReceipt {
        try authority.check()
        guard current?.id == snapshot.id, observedAt.duration(to: .now) < .seconds(20) else {
            throw NativeVoiceControlError.observationExpired
        }
        let expectedPID = processID
        guard let expectedWindow = window else { throw NativeVoiceControlError.windowChanged }
        let foregroundPID = await MainActor.run { NSWorkspace.shared.frontmostApplication?.processIdentifier }
        guard foregroundPID == processID else { throw NativeVoiceControlError.windowChanged }
        try validateContext()
        if action.operation == .activateApp {
            guard let pid = applications[action.targetID] else { throw NativeVoiceControlError.changed }
            current = nil
            try authority.check()
            let activated = await VoiceControlAppActivation.bringForward(processID: pid)
            try authority.check()
            return VoiceControlReceipt(
                status: activated ? .verified : .failed,
                message: activated ? "Brought the requested app forward." : "Couldn’t activate that app.")
        }
        if let destination = VoiceControlWebDestination.named(action.targetID) {
            guard action.operation == .press, snapshot.targets.contains(where: { $0.id == destination.id }) else {
                throw NativeVoiceControlError.unsupported
            }
            current = nil
            let opened = try await MainActor.run {
                try authority.perform {
                    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == expectedPID else {
                        throw NativeVoiceControlError.windowChanged
                    }
                    return NSWorkspace.shared.open(destination.url)
                }
            }
            guard opened else { return VoiceControlReceipt(status: .failed, message: "Couldn’t open that website.") }
            try await Task.sleep(for: .milliseconds(1_800))
            return VoiceControlReceipt(
                status: .transitionObserved, message: "Opened the requested website.")
        }
        guard let bound = handles[action.targetID], bound.target.operations.contains(action.operation) else {
            throw NativeVoiceControlError.unsupported
        }
        let node = bound.element.value
        guard Self.isVisible(node, within: expectedWindow.value), Self.fingerprint(node) == bound.fingerprint,
            !Self.isSecure(node, role: bound.target.role)
        else {
            throw NativeVoiceControlError.targetChanged
        }
        // Consume the observation before dispatch: a thrown/unknown result cannot be replayed.
        current = nil
        let observedValue = Self.attribute(node, kAXValueAttribute)
        if [.setValue, .insertText].contains(action.operation) || action.targetID == undoTargetID {
            guard observedValue is String else { throw NativeVoiceControlError.targetChanged }
        }
        let beforeValue = (observedValue as? String) ?? (observedValue as? NSNumber)?.stringValue ?? ""
        if action.targetID == undoTargetID, let undo = undoEdit, action.operation == .press {
            undoEdit = nil
            guard undo.pid == processID, let window, CFEqual(undo.window.value, window.value),
                Date().timeIntervalSince(undo.time) < 30, beforeValue == undo.after
            else {
                throw NativeVoiceControlError.changed
            }
            try validateContext()
            guard Self.fingerprint(node) == bound.fingerprint else { throw NativeVoiceControlError.targetChanged }
            try await validateForeground(expectedPID: expectedPID, expectedWindow: expectedWindow)
            let status = try authority.perform {
                return AXUIElementSetAttributeValue(node, kAXValueAttribute as CFString, undo.before as CFString)
            }
            return VoiceControlReceipt(
                status: status == .success && Self.attribute(node, kAXValueAttribute) as? String == undo.before
                    ? .verified : .unknown,
                message: "Checked the restored text.")
        }
        switch action.operation {
        case .setValue, .insertText:
            guard let supplied = action.value, supplied.utf16.count <= 32_000 else {
                throw NativeVoiceControlError.unsupported
            }
            let replacement: String
            if action.operation == .insertText {
                guard let range = Self.selectedRange(node), beforeValue.utf16.count <= 64_000,
                    range.location >= 0, range.length >= 0,
                    range.location <= beforeValue.utf16.count,
                    range.length <= beforeValue.utf16.count - range.location
                else {
                    throw NativeVoiceControlError.unsupported
                }
                replacement = (beforeValue as NSString).replacingCharacters(
                    in: NSRange(location: range.location, length: range.length), with: supplied)
            } else {
                replacement = supplied
            }
            try validateContext()
            guard Self.fingerprint(node) == bound.fingerprint else { throw NativeVoiceControlError.targetChanged }
            try await validateForeground(expectedPID: expectedPID, expectedWindow: expectedWindow)
            // Replace only the selected span in rich text. Setting AXValue on
            // an NSTextView can flatten styling and attachments in the document.
            let usesSelection = action.operation == .insertText && Self.settable(node, kAXSelectedTextAttribute)
            let plainField = [kAXTextFieldRole, kAXComboBoxRole].contains(bound.target.role)
            guard usesSelection || plainField else { throw NativeVoiceControlError.unsupported }
            let status = try authority.perform {
                AXUIElementSetAttributeValue(node,
                    (usesSelection ? kAXSelectedTextAttribute : kAXValueAttribute) as CFString,
                    (usesSelection ? supplied : replacement) as CFString)
            }
            // Browser accessibility caches can lag a successful setter. Verify
            // the same retained control with bounded reads; never retry the write.
            let verified = await verifyTextValue(node, expected: replacement, authority: authority)
            if plainField, verified {
                undoEdit = (Element(value: node), expectedWindow, beforeValue, replacement, expectedPID, Date())
                if bound.target.role == kAXComboBoxRole {
                    try await Task.sleep(for: .milliseconds(450))
                }
            }
            if !plainField { undoEdit = nil }
            return VoiceControlReceipt(
                status: verified ? .verified : .unknown,
                message: verified ? "Checked the text field after the change."
                    : status == .success ? "Text was dispatched; its result could not be verified." : "The app reported a text error; check whether it changed.")
        case .press, .select:
            let beforeTransition = transitionEvidence()
            try validateContext()
            guard Self.fingerprint(node) == bound.fingerprint else { throw NativeVoiceControlError.targetChanged }
            try await validateForeground(expectedPID: expectedPID, expectedWindow: expectedWindow)
            let status = try authority.perform {
                return AXUIElementPerformAction(node, kAXPressAction as CFString)
            }
            guard status == .success else {
                // AX errors can arrive after an app handled the action. Without
                // a definitive postcondition, retrying could duplicate a commitment.
                return VoiceControlReceipt(status: .unknown, message: "The app reported a press error; check whether the action completed.")
            }
            try await Task.sleep(for: .milliseconds(120))
            // A successful AX return only proves dispatch. Controls with observable state
            // changes can be verified; generic buttons must remain unknown.
            if bound.target.role == kAXCheckBoxRole || bound.target.role == kAXRadioButtonRole {
                let after = Self.attribute(node, kAXValueAttribute)
                let afterValue = (after as? String) ?? (after as? NSNumber)?.stringValue
                return VoiceControlReceipt(
                    status: afterValue.map { $0 != beforeValue } == true ? .verified : .unknown,
                    message: "Checked the control’s state.")
            }
            if bound.target.role == kAXPopUpButtonRole || bound.target.role == kAXMenuBarItemRole {
                if Self.attribute(node, "AXExpanded") as? Bool == true ||
                    (bound.target.role == kAXMenuBarItemRole && Self.attribute(node, kAXSelectedAttribute) as? Bool == true) {
                    return VoiceControlReceipt(status: .verified, message: "Menu opened.")
                }
            }
            for _ in 0..<3 {
                try await Task.sleep(for: .milliseconds(120))
                try authority.check()
                let afterTransition = transitionEvidence()
                if afterTransition != beforeTransition, !afterTransition.isEmpty {
                    return VoiceControlReceipt(
                        status: .transitionObserved,
                        message: "The interface changed after the press; checking the next step.")
                }
            }
            return VoiceControlReceipt(
                status: .unknown, message: "Control pressed. Check the result before continuing.")
        case .key:
            guard let key = action.value, let code = Self.keyCodes[key.lowercased()] else {
                throw NativeVoiceControlError.unsupported
            }
            guard let focused = Self.element(AXUIElementCreateApplication(processID), kAXFocusedUIElementAttribute),
                CFEqual(focused, node)
            else { throw NativeVoiceControlError.changed }
            try validateContext()
            guard
                let currentFocus = Self.element(AXUIElementCreateApplication(processID), kAXFocusedUIElementAttribute),
                CFEqual(currentFocus, node)
            else { throw NativeVoiceControlError.changed }
            try await validateForeground(expectedPID: expectedPID, expectedWindow: expectedWindow)
            let beforeTransition = transitionEvidence()
            try authority.perform {
                guard let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true),
                    let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false)
                else {
                    throw NativeVoiceControlError.unsupported
                }
                down.setIntegerValueField(.eventSourceUserData, value: StreamingCursorEventMarker.userData)
                up.setIntegerValueField(.eventSourceUserData, value: StreamingCursorEventMarker.userData)
                down.postToPid(expectedPID); up.postToPid(expectedPID)
            }
            if ["return", "enter", "tab", "escape"].contains(key.lowercased()) {
                for _ in 0..<4 {
                    try await Task.sleep(for: .milliseconds(120))
                    try authority.check()
                    let afterTransition = transitionEvidence()
                    if afterTransition != beforeTransition, !afterTransition.isEmpty {
                        return VoiceControlReceipt(
                            status: .transitionObserved,
                            message: "The interface changed after the key; checking the next step.")
                    }
                }
            }
            return VoiceControlReceipt(status: .unknown, message: "Key sent. Check the result before continuing.")
        case .scroll:
            let direction = action.value?.lowercased() ?? "down"
            guard ["up", "down"].contains(direction) else { throw NativeVoiceControlError.unsupported }
            let scrollbarAttribute =
                direction == "up" || direction == "down"
                ? kAXVerticalScrollBarAttribute : kAXHorizontalScrollBarAttribute
            guard let bar = Self.element(node, scrollbarAttribute),
                let value = Self.attribute(bar, kAXValueAttribute) as? Double,
                Self.settable(bar, kAXValueAttribute)
            else { throw NativeVoiceControlError.unsupported }
            let next = min(1, max(0, value + (direction == "down" ? 0.2 : -0.2)))
            try validateContext()
            try await validateForeground(expectedPID: expectedPID, expectedWindow: expectedWindow)
            let status = try authority.perform {
                return AXUIElementSetAttributeValue(bar, kAXValueAttribute as CFString, NSNumber(value: next))
            }
            let observed = Self.attribute(bar, kAXValueAttribute) as? Double
            return VoiceControlReceipt(
                status: status == .success && observed == next ? .verified : .unknown,
                message: "Checked the scroll position.")
        case .activateApp: throw NativeVoiceControlError.unsupported
        }
    }

    private func verifyTextValue(_ node: AXUIElement, expected: String, authority: ActionAuthority) async -> Bool {
        for attempt in 0..<6 {
            guard authority.isValid, !Task.isCancelled else { return false }
            if Self.attribute(node, kAXValueAttribute) as? String == expected { return true }
            if attempt < 5 { try? await Task.sleep(for: .milliseconds(60)) }
        }
        return false
    }

    /// Bounded structural evidence, not a model's success assertion. Changes to
    /// editable values, menus, URLs or window identity permit fresh planning.
    private func transitionEvidence() -> Set<String> {
        guard let root = Self.focusedOrMainWindow(AXUIElementCreateApplication(processID)) else {
            return []
        }
        var evidence: Set<String> = ["window:\(CFHash(root))"]
        var queue = [root]
        var visited: Set<CFHashCode> = []
        let deadline = ContinuousClock.now.advanced(by: .milliseconds(350))
        while let node = queue.popLast(), visited.count < 200, ContinuousClock.now < deadline {
            guard visited.insert(CFHash(node)).inserted else { continue }
            let role = Self.string(node, kAXRoleAttribute)
            guard !Self.isSecure(node, role: role), Self.attribute(node, "AXHidden") as? Bool != true else { continue }
            if Self.isVisible(node),
                [
                    kAXTextFieldRole, kAXComboBoxRole, kAXPopUpButtonRole, kAXMenuRole, kAXMenuItemRole,
                    kAXButtonRole, kAXCheckBoxRole, kAXRadioButtonRole, kAXStaticTextRole, "AXWebArea", "AXLink",
                ].contains(role)
            {
                evidence.insert(
                    role + "|" + Self.label(node) + "|" + Self.string(node, kAXValueAttribute)
                        + "|" + String(describing: Self.attribute(node, kAXURLAttribute)))
            }
            if let children = Self.attribute(node, kAXChildrenAttribute) as? [AXUIElement] {
                queue.append(contentsOf: children.prefix(80).reversed())
            }
        }
        return evidence
    }

    private func validateContext() throws {
        guard let window,
            let focused = Self.focusedOrMainWindow(AXUIElementCreateApplication(processID)),
            CFEqual(focused, window.value)
        else { throw NativeVoiceControlError.windowChanged }
    }
    private static let keyCodes: [String: CGKeyCode] = [
        "tab": 48, "escape": 53, "enter": 36, "return": 36,
        "left": 123, "right": 124, "down": 125, "up": 126, "backspace": 51, "delete": 117,
    ]
    private static func attribute(_ node: AXUIElement, _ name: String) -> CFTypeRef? {
        AXUIElementSetMessagingTimeout(node, 0.15)
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(node, name as CFString, &value) == .success ? value : nil
    }
    private static func element(_ node: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(node, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value as AnyObject, to: AXUIElement.self)
    }
    private static func focusedOrMainWindow(_ app: AXUIElement) -> AXUIElement? {
        if let focused = element(app, kAXFocusedWindowAttribute) { return focused }
        guard let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] else { return nil }
        return windows.first
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
        return subrole.contains("secure") || role.lowercased().contains("secure")
            || ["password", "passcode", "one-time", "verification code", "api key", "secret", "credit card"].contains(
                where: name.contains)
    }
    static func actionLabel(_ label: String, value: String, role: String, pressable: Bool) -> String {
        // Web list choices can be pressable static text with their name only in AXValue.
        guard label.isEmpty, role == kAXMenuItemRole || (role == kAXStaticTextRole && pressable) else { return label }
        return value
    }

    static func contextLabel(_ label: String, role: String) -> String {
        // Browser account badges expose personal names/emails in their accessible
        // descriptions. The task needs the menu capability, not that identity.
        guard [kAXButtonRole, kAXPopUpButtonRole, "AXMenuButton"].contains(role) else { return label }
        let lower = label.lowercased()
        if lower.hasPrefix("google account:") { return "Account menu" }
        if lower.hasPrefix("profile:") || lower.hasPrefix("profile ") { return "Browser profile menu" }
        return label
    }

    static func textOperations(role: String, readableValue: Bool, valueSettable: Bool,
                               selectionSettable: Bool) -> Set<VoiceControlOperation> {
        guard readableValue, [kAXTextFieldRole, kAXComboBoxRole, kAXTextAreaRole].contains(role) else { return [] }
        var result: Set<VoiceControlOperation> = []
        if [kAXTextFieldRole, kAXComboBoxRole].contains(role), valueSettable {
            result.formUnion([.setValue, .insertText])
        }
        if selectionSettable { result.insert(.insertText) }
        return result
    }
    static func isOrdinaryControl(role: String, pressable: Bool) -> Bool {
        // Opening selectors and choosing an offered option is ordinary task
        // work. A checkbox or HTTP link can still subscribe, share, or commit.
        if [kAXMenuBarItemRole, kAXPopUpButtonRole, kAXMenuItemRole, kAXComboBoxRole, kAXRadioButtonRole]
            .contains(role)
        {
            return true
        }
        return role == kAXStaticTextRole && pressable
    }
    static func isBrowserBundle(_ bundle: String) -> Bool {
        [
            "com.google.Chrome", "com.google.Chrome.canary", "com.apple.Safari", "org.mozilla.firefox",
            "org.mozilla.firefoxdeveloperedition", "com.microsoft.edgemac", "com.brave.Browser",
            "company.thebrowser.Browser",
        ].contains(bundle)
    }
    static func isChromiumBundle(_ bundle: String) -> Bool {
        [
            "com.google.Chrome", "com.google.Chrome.canary", "com.microsoft.edgemac", "com.brave.Browser",
            "company.thebrowser.Browser",
        ].contains(bundle)
    }
    /// Electron honours AXManualAccessibility; Chromium honours AXEnhancedUserInterface.
    /// Setting them rebuilds the tree, so this runs once per process and then waits for a page.
    private func enableChromiumAccessibilityIfNeeded(app: AXUIElement, pid: Int32, bundle: String) async throws {
        guard Self.isChromiumBundle(bundle) else { return }
        let firstAsk = chromiumAccessibilityPIDs.insert(pid).inserted
        if firstAsk {
            AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
            for _ in 0..<8 {
                if Self.hasPopulatedWebArea(app) { return }
                try await Task.sleep(for: .milliseconds(150))
            }
            return
        }
        // Chromium can drop its tree after a navigation; ask once more, briefly.
        guard !Self.hasPopulatedWebArea(app) else { return }
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        try await Task.sleep(for: .milliseconds(250))
    }
    static func hasPopulatedWebArea(_ app: AXUIElement) -> Bool {
        guard let window = focusedOrMainWindow(app) else { return false }
        var pending = [window]
        var visited = 0
        while let node = pending.popLast(), visited < 400 {
            visited += 1
            if string(node, kAXRoleAttribute) == "AXWebArea" {
                let children = attribute(node, kAXChildrenAttribute) as? [AXUIElement] ?? []
                if !children.isEmpty { return true }
                continue
            }
            if let children = attribute(node, kAXChildrenAttribute) as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
        return false
    }
    static func isBrowserShellNoise(label: String, role: String) -> Bool {
        let lower = label.lowercased()
        if lower.contains("memory usage") || lower.contains("cpu usage") || lower.contains("gpu usage") {
            return true
        }
        if lower.contains("address and search") || lower == "tab search" || lower.hasPrefix("tab search") {
            return true
        }
        if role == kAXStaticTextRole, lower.contains("book your ticket"), lower.contains("google flights") {
            return true
        }
        return false
    }
    static func keepOfferedControl(
        isBrowser: Bool, inWebArea: Bool, hasWebContent: Bool, label: String, role: String
    ) -> Bool {
        if isBrowserShellNoise(label: label, role: role) { return false }
        if isBrowser, hasWebContent, !inWebArea, role != "application", role != "undo" { return false }
        return true
    }
    private static func ancestorIsWebArea(_ node: AXUIElement) -> Bool {
        var current = node
        for _ in 0..<24 {
            guard let parent = element(current, kAXParentAttribute) else { return false }
            if string(parent, kAXRoleAttribute) == "AXWebArea" { return true }
            current = parent
        }
        return false
    }
    private static func isVisible(_ node: AXUIElement, within window: AXUIElement? = nil) -> Bool {
        guard attribute(node, "AXHidden") as? Bool != true,
            let rawPosition = attribute(node, kAXPositionAttribute),
            let rawSize = attribute(node, kAXSizeAttribute),
            CFGetTypeID(rawPosition) == AXValueGetTypeID(), CFGetTypeID(rawSize) == AXValueGetTypeID()
        else { return false }
        let position = unsafeDowncast(rawPosition as AnyObject, to: AXValue.self)
        let size = unsafeDowncast(rawSize as AnyObject, to: AXValue.self)
        guard AXValueGetType(position) == .cgPoint, AXValueGetType(size) == .cgSize else { return false }
        var point = CGPoint.zero; var extent = CGSize.zero
        guard AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(size, .cgSize, &extent),
            extent.width > 0, extent.height > 0
        else { return false }
        let frame = CGRect(origin: point, size: extent)
        if let window, ![kAXMenuBarItemRole, kAXMenuItemRole, kAXMenuRole].contains(string(node, kAXRoleAttribute)),
           let windowPosition = attribute(window, kAXPositionAttribute),
           let windowSize = attribute(window, kAXSizeAttribute),
           CFGetTypeID(windowPosition) == AXValueGetTypeID(), CFGetTypeID(windowSize) == AXValueGetTypeID() {
            let wp = unsafeDowncast(windowPosition as AnyObject, to: AXValue.self)
            let ws = unsafeDowncast(windowSize as AnyObject, to: AXValue.self)
            var origin = CGPoint.zero; var dimensions = CGSize.zero
            guard AXValueGetType(wp) == .cgPoint, AXValueGetType(ws) == .cgSize,
                  AXValueGetValue(wp, .cgPoint, &origin), AXValueGetValue(ws, .cgSize, &dimensions),
                  CGRect(origin: origin, size: dimensions).intersects(frame) else { return false }
        }
        var displays = [CGDirectDisplayID](repeating: 0, count: 32)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(32, &displays, &count) == .success else { return false }
        return displays.prefix(Int(count)).contains { CGDisplayBounds($0).intersects(frame) }
    }
    private func validateForeground(expectedPID: Int32, expectedWindow: Element) async throws {
        let frontmost = await MainActor.run { NSWorkspace.shared.frontmostApplication?.processIdentifier }
        guard frontmost == expectedPID, processID == expectedPID, let window,
            CFEqual(window.value, expectedWindow.value)
        else { throw NativeVoiceControlError.windowChanged }
        try validateContext()
    }
    private static func fingerprint(_ node: AXUIElement) -> String {
        [
            string(node, kAXRoleAttribute), string(node, kAXSubroleAttribute), label(node),
            string(node, kAXValueAttribute), string(node, kAXEnabledAttribute),
            String(describing: attribute(node, kAXURLAttribute)),
            String(describing: selectedRange(node)),
        ].joined(separator: "\u{1f}")
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
        guard let raw = attribute(node, kAXSelectedTextRangeAttribute), CFGetTypeID(raw) == AXValueGetTypeID() else {
            return nil
        }
        let value = unsafeDowncast(raw as AnyObject, to: AXValue.self)
        guard AXValueGetType(value) == .cfRange else { return nil }
        var range = CFRange()
        return AXValueGetValue(value, .cfRange, &range) ? range : nil
    }
}
