import XCTest
@testable import MacParakeetCore

final class VoiceControlCommandRouterTests: XCTestCase {
    func testContextualHelpIsLocalAndOnlyAdvertisesObservedCapabilities() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        for alias in ["help", "show commands", "What can I say here?"] {
            let result = try await router.decide(goal: alias, snapshot: editable("hello"), history: [])
            guard case .information(let message) = result else {
                return XCTFail("Help is information, not a clarification or effect")
            }
            XCTAssertTrue(message.contains("Type hello"))
            XCTAssertTrue(message.contains("Replace old words"))
            XCTAssertTrue(message.contains("Stop"))
            XCTAssertFalse(message.contains("Scroll down"))
            XCTAssertFalse(message.contains("Make this shorter"))
            XCTAssertFalse(message.contains("verified"))
        }
    }
    func testContextualHelpOmitsAmbiguousLabelsAndReportsLimitedCoverage() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Fixture",
            targets: [
                VoiceControlTarget(id: "one", label: "Save", role: "button", operations: [.press]),
                VoiceControlTarget(id: "two", label: "Save", role: "button", operations: [.press]),
                VoiceControlTarget(id: "three", label: "Settings", role: "button", operations: [.press]),
            ], isComplete: false)
        let result = try await router.decide(goal: "show commands", snapshot: snapshot, history: [])
        guard case .information(let message) = result else { return XCTFail("Expected local help") }
        XCTAssertFalse(message.contains("Click Save"))
        XCTAssertTrue(message.contains("Click Settings"))
        XCTAssertTrue(message.contains("Only part"))
    }
    func testLiteralCommandWordsNeverReachSemanticEngine() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = editable("hello", selected: "hello")
        let text = "stop and click send. Keep ALL punctuation!"
        let result = try await router.decide(goal: "type " + text, snapshot: snapshot, history: [])
        XCTAssertEqual(result, .action(VoiceControlAction(operation: .insertText, targetID: "field", value: text)))
    }
    func testAmbiguousReplacementDoesNotChangeWholeField() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let result = try await router.decide(
            goal: "replace tomorrow with Friday", snapshot: editable("tomorrow and tomorrow"), history: [])
        guard case .clarify = result else { return XCTFail("Duplicate occurrences require selection") }
    }
    func testReplacementPreservesRestOfFieldAndQuotedPayload() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let result = try await router.decide(
            goal: "replace \"tomorrow\" with \"Friday\"", snapshot: editable("See you tomorrow!"), history: [])
        XCTAssertEqual(
            result, .action(VoiceControlAction(operation: .setValue, targetID: "field", value: "See you Friday!")))
    }
    func testUnicodeCaseExpansionKeepsReplacementIndicesInOriginalCommand() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let result = try await router.decide(
            goal: "replace İstanbul WITH İzmir", snapshot: editable("Visit İstanbul tomorrow."), history: [])
        XCTAssertEqual(
            result, .action(VoiceControlAction(operation: .setValue, targetID: "field", value: "Visit İzmir tomorrow."))
        )
    }
    func testTruncatedFieldCannotBeOverwritten() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let result = try await router.decide(
            goal: "replace tomorrow with Friday", snapshot: editable("tomorrow", complete: false), history: [])
        guard case .clarify = result else { return XCTFail("Truncated data must not authorize replacement") }
    }
    func testGeneratedRewriteRequiresConfirmationAndUsesSelection() async throws {
        let router = VoiceControlCommandRouter(
            fallback: MustNotDecide(),
            rewrite: { text, instruction in
                XCTAssertEqual(text, "Selected sentence.")
                XCTAssertEqual(instruction, "make this shorter")
                return "Shorter."
            })
        let result = try await router.decide(
            goal: "make this shorter", snapshot: editable("Other. Selected sentence.", selected: "Selected sentence."),
            history: [])
        guard case .action(let action) = result else { return XCTFail("Expected rewrite") }
        XCTAssertTrue(action.requiresConfirmation)
        XCTAssertEqual(action.value, "Shorter.")
        XCTAssertEqual(action.operation, .insertText)
    }
    func testVerifiedReplacementFinishesWithoutSearchingForOldWords() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let result = try await router.decide(
            goal: "replace tomorrow with Friday", snapshot: editable("Friday"),
            history: [
                VoiceControlAction(operation: .setValue, targetID: "old", value: "Friday", receiptStatus: .verified)
            ])
        XCTAssertEqual(result, .directCompleted("Done. The requested change was verified."))
    }
    func testChangedInvocationSelectionNeverReachesWritingProvider() async throws {
        let original = editable("old", selected: "old")
        let router = VoiceControlCommandRouter(
            fallback: MustNotDecide(),
            rewrite: { _, _ in
                XCTFail("Changed source must be rejected before provider call")
                return "bad"
            }, selectionAtInvocation: { original })
        let result = try await router.decide(
            goal: "make this shorter", snapshot: editable("new", selected: "new"), history: [])
        guard case .clarify = result else { return XCTFail("Expected changed-selection clarification") }
    }
    func testVerifiedExactPressFinishesAfterTargetDisappears() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let result = try await router.decide(
            goal: "click Done", snapshot: editable("result"),
            history: [
                VoiceControlAction(operation: .press, targetID: "old", targetLabel: "Done", receiptStatus: .verified)
            ])
        XCTAssertEqual(result, .directCompleted("Done. The requested change was verified."))
    }
    private func editable(_ value: String, selected: String? = nil, complete: Bool = true) -> VoiceControlSnapshot {
        VoiceControlSnapshot(
            contextID: "test", applicationName: "Fixture",
            targets: [
                VoiceControlTarget(
                    id: "field", label: "Body", role: "text", value: value,
                    operations: [.insertText, .setValue, .key], isFocused: true,
                    selectedText: selected, valueIsComplete: complete)
            ])
    }
}
private struct MustNotDecide: VoiceControlDecisionEngine {
    func decide(goal: String, snapshot: VoiceControlSnapshot, history: [VoiceControlAction]) async throws
        -> VoiceControlDecision
    {
        XCTFail("Unexpected semantic request for an exact local command")
        return .clarify("Unexpected request")
    }
}
