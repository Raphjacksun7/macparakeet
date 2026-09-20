import XCTest
@testable import MacParakeetCore

final class VoiceControlCommandRouterTests: XCTestCase {
    func testLiteralCommandWordsNeverReachSemanticEngine() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = editable("hello", selected: "hello")
        let text = "stop and click send. Keep ALL punctuation!"
        let result = try await router.decide(goal: "type " + text, snapshot: snapshot, history: [])
        XCTAssertEqual(result, .action(VoiceControlAction(operation: .insertText, targetID: "field", value: text)))
    }
    func testAmbiguousReplacementDoesNotChangeWholeField() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let result = try await router.decide(goal: "replace tomorrow with Friday", snapshot: editable("tomorrow and tomorrow"), history: [])
        guard case .clarify = result else { return XCTFail("Duplicate occurrences require selection") }
    }
    func testReplacementPreservesRestOfFieldAndQuotedPayload() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let result = try await router.decide(goal: "replace \"tomorrow\" with \"Friday\"", snapshot: editable("See you tomorrow!"), history: [])
        XCTAssertEqual(result, .action(VoiceControlAction(operation: .setValue, targetID: "field", value: "See you Friday!")))
    }
    func testTruncatedFieldCannotBeOverwritten() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let result = try await router.decide(goal: "replace tomorrow with Friday", snapshot: editable("tomorrow", complete: false), history: [])
        guard case .clarify = result else { return XCTFail("Truncated data must not authorize replacement") }
    }
    func testGeneratedRewriteRequiresConfirmationAndUsesSelection() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide(), rewrite: { text, instruction in
            XCTAssertEqual(text, "Selected sentence.")
            XCTAssertEqual(instruction, "make this shorter")
            return "Shorter."
        })
        let result = try await router.decide(goal: "make this shorter", snapshot: editable("Other. Selected sentence.", selected: "Selected sentence."), history: [])
        guard case .action(let action) = result else { return XCTFail("Expected rewrite") }
        XCTAssertTrue(action.requiresConfirmation)
        XCTAssertEqual(action.value, "Shorter.")
        XCTAssertEqual(action.operation, .insertText)
    }
    private func editable(_ value: String, selected: String? = nil, complete: Bool = true) -> VoiceControlSnapshot {
        VoiceControlSnapshot(contextID: "test", applicationName: "Fixture", targets: [
            VoiceControlTarget(id: "field", label: "Body", role: "text", value: value,
                               operations: [.insertText, .setValue, .key], isFocused: true,
                               selectedText: selected, valueIsComplete: complete)
        ])
    }
}
private struct MustNotDecide: VoiceControlDecisionEngine {
    func decide(goal: String, snapshot: VoiceControlSnapshot, history: [VoiceControlAction]) async throws -> VoiceControlDecision {
        XCTFail("Unexpected semantic request for an exact local command")
        return .clarify("Unexpected request")
    }
}
