import Foundation

/// Content-minimized, in-memory diagnostics. Never stores commands, field values,
/// selected text, screenshots, audio, credentials or remote error bodies.
public struct VoiceControlTraceRecord: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let taskID: UUID
    public let revision: Int
    public let timestamp: Date
    public let stage: String
    public let operation: VoiceControlOperation?
    public let outcome: String
    public let durationMilliseconds: Int?
    public let candidateCount: Int?
    public let observationComplete: Bool?
    public let modelID: String?
    /// Model distribution concentration, never probability of task success.
    public let decisionScore: Double?
}

public struct VoiceControlTaskLimits: Sendable {
    public let actions: Int
    public let decisions: Int
    public let activeSeconds: Double
    public let confirmationSeconds: Double
    public init(actions: Int = 40, decisions: Int = 100, activeSeconds: Double = 180, confirmationSeconds: Double = 20) {
        self.actions = max(1, actions); self.decisions = max(1, decisions)
        self.activeSeconds = max(0.01, activeSeconds); self.confirmationSeconds = max(0.01, confirmationSeconds)
    }
}

public enum VoiceControlConsequence: String, Codable, Sendable, CaseIterable {
    case ordinary, payment, destructive, externalCommitment, unknown
}

public enum VoiceControlConsequencePolicy {
    public static func consequence(of action: VoiceControlAction, target: VoiceControlTarget) -> VoiceControlConsequence {
        // Editing payment-related fields is not a payment commitment.
        if [.setValue, .insertText, .scroll, .activateApp].contains(action.operation) { return .ordinary }
        if action.operation == .key, ["backspace", "delete"].contains(action.value?.lowercased() ?? "") {
            // Delete in a collection can remove a message/file, even when the
            // model labels it ordinary. Only focused text editing is exempt.
            return target.isFocused && target.operations.contains(.insertText) ? .ordinary : .destructive
        }
        let label = target.label.lowercased()
        // Reviewed local evidence always wins over model-proposed ordinary risk.
        let words = Set(label.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        if !words.isDisjoint(with: ["pay", "purchase", "checkout", "buy", "payment", "subscribe"]) { return .payment }
        if !words.isDisjoint(with: ["delete", "erase", "trash", "destroy"]) { return .destructive }
        if !words.isDisjoint(with: ["send", "publish", "post", "transfer", "invite", "share"]) { return .externalCommitment }
        if let known = target.consequence, known != .unknown && known != .ordinary { return known }
        if let supplied = action.consequence, supplied != .ordinary && supplied != .unknown { return supplied }
        switch action.operation {
        case .setValue, .insertText, .scroll, .activateApp, .select: return .ordinary
        case .key:
            let key = action.value?.lowercased() ?? ""
            if ["tab", "escape", "left", "right", "up", "down"].contains(key) { return .ordinary }
            if ["return", "enter"].contains(key), words.contains("search") { return .ordinary }
        case .press:
            let normalLabels: Set<String> = ["search", "search flights", "find", "find flights", "next", "previous", "back", "forward", "done", "close", "cancel", "open", "settings", "help"]
            if normalLabels.contains(label.trimmingCharacters(in: .whitespacesAndNewlines)) || target.isNavigation { return .ordinary }
        }
        if target.consequence == .ordinary || action.consequence == .ordinary { return .ordinary }
        return .unknown
    }
}
