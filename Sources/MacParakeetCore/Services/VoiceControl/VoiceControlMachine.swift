import Foundation

/// Observed interaction protocol, recomputed every snapshot. Not a persisted graph.
public enum VoiceControlSituation: String, Sendable, Equatable {
    case plain
    case suggestionPicker
    case datePicker

    public static func classify(_ snapshot: VoiceControlSnapshot) -> VoiceControlSituation {
        if snapshot.targets.contains(where: VoiceControlLegality.isCalendarDay) { return .datePicker }
        if snapshot.targets.contains(where: VoiceControlLegality.isCitySuggestion) { return .suggestionPicker }
        let whereElse = snapshot.targets.contains {
            $0.label.localizedStandardContains("Where else")
        }
        let focusedChoice = snapshot.targets.contains {
            $0.isFocused && $0.operations.contains(.press) && $0.role == "AXStaticText"
        }
        if whereElse && focusedChoice { return .suggestionPicker }
        return .plain
    }
}

/// One legal transition the host is willing to execute. Jev may only pick among these.
public struct VoiceControlEnabledEvent: Equatable, Sendable, Identifiable {
    public let id: String
    public let criteria: String
    public let action: VoiceControlAction
    public init(id: String, criteria: String, action: VoiceControlAction) {
        self.id = id; self.criteria = criteria; self.action = action
    }
}

public struct VoiceControlMachineFrame: Equatable, Sendable {
    public let machine: String
    public let situation: VoiceControlSituation
    public let state: String
    public let events: [VoiceControlEnabledEvent]
    public init(machine: String, situation: VoiceControlSituation, state: String, events: [VoiceControlEnabledEvent]) {
        self.machine = machine; self.situation = situation; self.state = state; self.events = events
    }
}

/// Code-owned legality for both domain machines and unconstrained Jev fallback.
public enum VoiceControlLegality {
    public static func isCitySuggestion(_ target: VoiceControlTarget) -> Bool {
        target.operations.contains(.press) && target.role != "url" && target.role != "application"
            && (target.label.contains(",") || target.label.localizedStandardContains("Airport"))
            && !target.label.localizedStandardContains("Toggle")
    }

    public static func isCalendarDay(_ target: VoiceControlTarget) -> Bool {
        target.operations.contains(.press) && target.label.localizedStandardContains("departure date")
    }

    public static func offeredTargets(in snapshot: VoiceControlSnapshot) -> [VoiceControlTarget] {
        let page = snapshot.targets.filter { !$0.operations.contains(.activateApp) && $0.role != "url" }
        switch VoiceControlSituation.classify(snapshot) {
        case .plain:
            return page
        case .suggestionPicker:
            return page.filter {
                isCitySuggestion($0) || isOverlayChrome($0)
                    || ($0.isFocused && $0.operations.contains(.key))
            }
        case .datePicker:
            return page.filter {
                isCalendarDay($0) || isOverlayChrome($0)
                    || ($0.isFocused && $0.operations.contains(.key))
            }
        }
    }

    public static func offeredKeys(in snapshot: VoiceControlSnapshot) -> [String] {
        switch VoiceControlSituation.classify(snapshot) {
        case .suggestionPicker, .datePicker: return ["escape"]
        case .plain: return ["return", "escape", "tab"]
        }
    }

    private static func isOverlayChrome(_ target: VoiceControlTarget) -> Bool {
        let label = target.label.lowercased()
        return label.contains("where else") || label.contains("where to") || label.contains("where from")
            || label.contains("departure") || label.contains("dates")
    }
}

public extension VoiceControlDecisionEngine {
    func decide(
        goal: String, snapshot: VoiceControlSnapshot, history: [VoiceControlAction],
        events: [VoiceControlEnabledEvent]
    ) async throws -> VoiceControlDecision {
        try await decide(goal: goal, snapshot: snapshot, history: history)
    }
}
