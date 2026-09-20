import Foundation

public enum VoiceControlOperation: String, Codable, Sendable, CaseIterable {
    case press, setValue, insertText, select, scroll, key, activateApp
}

public struct VoiceControlTarget: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let role: String
    public let value: String?
    public let operations: Set<VoiceControlOperation>
    /// Only adapter-proven navigation may dispatch a press without confirmation.
    public let isNavigation: Bool
    public let isFocused: Bool
    public let selectedText: String?
    public let valueIsComplete: Bool
    public init(id: String, label: String, role: String, value: String? = nil,
                operations: Set<VoiceControlOperation>, isNavigation: Bool = false,
                isFocused: Bool = false, selectedText: String? = nil, valueIsComplete: Bool = true) {
        self.id = id; self.label = label; self.role = role; self.value = value
        self.operations = operations; self.isNavigation = isNavigation
        self.isFocused = isFocused; self.selectedText = selectedText; self.valueIsComplete = valueIsComplete
    }
}

public struct VoiceControlSnapshot: Codable, Sendable, Equatable {
    public let id: UUID
    public let contextID: String
    public let applicationName: String
    public let targets: [VoiceControlTarget]
    public let summary: String
    public let isComplete: Bool
    public init(id: UUID = UUID(), contextID: String, applicationName: String,
                targets: [VoiceControlTarget], summary: String = "", isComplete: Bool = true) {
        self.id = id; self.contextID = contextID; self.applicationName = applicationName
        self.targets = targets; self.summary = summary; self.isComplete = isComplete
    }
}

public struct VoiceControlAction: Codable, Sendable, Equatable {
    public let operation: VoiceControlOperation
    public let targetID: String
    /// Text is an exact source span, or an explicitly approved generated rewrite.
    public let value: String?
    public let targetLabel: String?
    public let requiresConfirmation: Bool
    public init(operation: VoiceControlOperation, targetID: String, value: String? = nil, targetLabel: String? = nil, requiresConfirmation: Bool = false) {
        self.operation = operation; self.targetID = targetID; self.value = value; self.targetLabel = targetLabel; self.requiresConfirmation = requiresConfirmation
    }
}

/// Synchronous revocation is independent of any actor currently awaiting I/O.
public final class ActionAuthority: @unchecked Sendable {
    private let lock = NSLock()
    private var revoked = false
    public init() {}
    public func revoke() { lock.lock(); revoked = true; lock.unlock() }
    public var isValid: Bool { lock.lock(); defer { lock.unlock() }; return !revoked }
    public func check() throws { if !isValid { throw CancellationError() } }
    /// Serialize the final check with a synchronous individual effect. Never await inside this closure.
    public func perform<T>(_ effect: () throws -> T) throws -> T {
        lock.lock(); defer { lock.unlock() }
        guard !revoked else { throw CancellationError() }
        return try effect()
    }
}

public struct VoiceControlReceipt: Sendable, Equatable {
    public enum Status: String, Sendable { case verified, unknown, failed }
    public let status: Status
    public let message: String
    public init(status: Status, message: String = "") { self.status = status; self.message = message }
}

public protocol VoiceControlAdapter: Sendable {
    func observe() async throws -> VoiceControlSnapshot
    func execute(action: VoiceControlAction, snapshot: VoiceControlSnapshot,
                 authority: ActionAuthority) async throws -> VoiceControlReceipt
}

public enum VoiceControlDecision: Sendable, Equatable {
    case action(VoiceControlAction)
    case clarify(String)
    /// Model inference is never reported as independently verified task completion.
    case finished
}

public protocol VoiceControlDecisionEngine: Sendable {
    func decide(goal: String, snapshot: VoiceControlSnapshot, history: [VoiceControlAction]) async throws -> VoiceControlDecision
}

public enum VoiceControlEvent: Sendable, Equatable {
    case observing, deciding
    case acting(VoiceControlAction)
    case confirmation(VoiceControlAction, String)
    case clarification(String)
    case paused(String)
    case completed(String)
    case failed(String)
    case cancelled
}
