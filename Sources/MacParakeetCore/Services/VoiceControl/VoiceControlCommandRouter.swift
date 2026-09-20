import Foundation

/// Exact local commands remain usable without a model request. All returned actions
/// still pass the runner's policy, freshness checks and revocable execution boundary.
public struct VoiceControlCommandRouter: VoiceControlDecisionEngine {
    public typealias Rewrite = @Sendable (_ text: String, _ instruction: String) async throws -> String
    private let fallback: any VoiceControlDecisionEngine
    private let rewrite: Rewrite?
    private let selectionAtInvocation: (@Sendable () async -> VoiceControlSnapshot?)?
    public init(fallback: any VoiceControlDecisionEngine, rewrite: Rewrite? = nil,
                selectionAtInvocation: (@Sendable () async -> VoiceControlSnapshot?)? = nil) {
        self.fallback = fallback; self.rewrite = rewrite; self.selectionAtInvocation = selectionAtInvocation
    }

    public func decide(goal: String, snapshot: VoiceControlSnapshot, history: [VoiceControlAction]) async throws -> VoiceControlDecision {
        let command = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = command.lowercased()
        let focused = snapshot.targets.filter { $0.isFocused && $0.operations.contains(.insertText) }
        // A verified direct action has finished this single-command route. The goal
        // loop for open-ended requests remains delegated to the semantic engine.
        func result(_ action: VoiceControlAction) -> VoiceControlDecision { history.isEmpty ? .action(action) : .finished }
        for prefix in ["type the words ", "type literally ", "type "] where lower.hasPrefix(prefix) {
            guard focused.count == 1 else { return .clarify("Focus one editable field before typing.") }
            let payload = String(command.dropFirst(prefix.count))
            guard !payload.isEmpty, payload.utf16.count <= 32_000 else { return .clarify("Say the text to enter, up to 32,000 characters.") }
            return result(VoiceControlAction(operation: .insertText, targetID: focused[0].id, value: payload))
        }
        if lower.hasPrefix("replace "), let delimiter = lower.range(of: " with ") {
            guard focused.count == 1, focused[0].valueIsComplete, let value = focused[0].value else {
                return .clarify("Focus a supported text field with its complete text available.")
            }
            let source = Self.unquote(String(command[command.index(command.startIndex, offsetBy: 8)..<delimiter.lowerBound]))
            let replacement = Self.unquote(String(command[delimiter.upperBound...]))
            guard !source.isEmpty else { return .clarify("Which exact words should I replace?") }
            let occurrences = value.ranges(of: source)
            guard occurrences.count == 1, let range = occurrences.first else {
                return .clarify(occurrences.isEmpty ? "Those words are not in the focused field." : "Those words appear more than once. Select the intended text first.")
            }
            let changed = value.replacingCharacters(in: range, with: replacement)
            guard focused[0].operations.contains(.setValue) else { return .clarify("This field does not support a precise replacement.") }
            return result(VoiceControlAction(operation: .setValue, targetID: focused[0].id, value: changed))
        }
        for prefix in ["click ", "press ", "open "] where lower.hasPrefix(prefix) {
            let label = String(command.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            let matches = snapshot.targets.filter { $0.label.caseInsensitiveCompare(label) == .orderedSame && ($0.operations.contains(.press) || $0.operations.contains(.activateApp)) }
            if matches.count == 1 {
                return result(VoiceControlAction(operation: matches[0].operations.contains(.activateApp) ? .activateApp : .press, targetID: matches[0].id))
            }
            if matches.count > 1 { return .clarify("More than one control is named \(label). Describe which one.") }
        }
        if ["undo", "undo that", "undo last edit"].contains(lower),
           let target = snapshot.targets.first(where: { $0.role == "undo" }) {
            return result(VoiceControlAction(operation: .press, targetID: target.id))
        }
        let keys: Set<String> = ["tab", "escape", "enter", "return", "left", "right", "up", "down", "backspace", "delete"]
        let key = lower.hasPrefix("press ") ? String(lower.dropFirst(6)) : ""
        if keys.contains(key), let target = snapshot.targets.first(where: { $0.isFocused && $0.operations.contains(.key) }) {
            return result(VoiceControlAction(operation: .key, targetID: target.id, value: key))
        }
        if ["scroll down", "scroll up"].contains(lower) {
            let candidates = snapshot.targets.filter { $0.operations.contains(.scroll) }
            guard candidates.count == 1 else { return .clarify("Which part of the window should I scroll?") }
            return result(VoiceControlAction(operation: .scroll, targetID: candidates[0].id, value: lower == "scroll up" ? "up" : "down"))
        }
        if ["rewrite ", "make this ", "translate this ", "summarize this"].contains(where: lower.hasPrefix) {
            guard history.isEmpty else { return .finished }
            guard focused.count == 1, let selected = focused[0].selectedText, !selected.isEmpty else {
                return .clarify("Select the text to rewrite in a supported editable field first.")
            }
            if let selectionAtInvocation {
                guard let original = await selectionAtInvocation(), original.contextID == snapshot.contextID,
                      let source = original.targets.first(where: { $0.isFocused }),
                      source.label == focused[0].label, source.role == focused[0].role,
                      source.value == focused[0].value, source.selectedText == selected,
                      original.targets.filter({ $0.label == source.label && $0.role == source.role }).count == 1,
                      snapshot.targets.filter({ $0.label == source.label && $0.role == source.role }).count == 1 else {
                    return .clarify("The original selection changed. Select the text and repeat the rewrite.")
                }
            }
            guard let rewrite else { return .clarify("Configure and enable a writing provider to rewrite selected text.") }
            let rewritten = try await rewrite(selected, command)
            try Task.checkCancellation()
            guard !rewritten.isEmpty, rewritten.utf16.count <= 32_000 else { return .clarify("The rewrite was empty or too long. Try a smaller selection.") }
            return .action(VoiceControlAction(operation: .insertText, targetID: focused[0].id,
                value: rewritten, targetLabel: focused[0].label, requiresConfirmation: true))
        }
        return try await fallback.decide(goal: command, snapshot: snapshot, history: history)
    }
    private static func unquote(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        for (opening, closing) in [("\"", "\""), ("“", "”"), ("'", "'")] where trimmed.hasPrefix(opening) && trimmed.hasSuffix(closing) && trimmed.count >= 2 {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }
}

private extension String {
    func ranges(of needle: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        var start = startIndex
        while start < endIndex, let match = range(of: needle, range: start..<endIndex) {
            found.append(match); start = match.upperBound
        }
        return found
    }
}
