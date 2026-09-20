import Foundation
import XCTest
@testable import MacParakeetCore

final class VoiceControlCoreTests: XCTestCase {
    func testAuthorityPreventsEveryEffectAfterRevocation() throws {
        let authority = ActionAuthority()
        var effects = 0
        try authority.perform { effects += 1 }
        authority.revoke()
        XCTAssertThrowsError(try authority.perform { effects += 1 })
        XCTAssertEqual(effects, 1)
    }

    func testJevRejectsUnlistedTargetAndInvalidDistributions() throws {
        let valid = JevDecisionClient.Answer(type: "choice", choice: "a", probabilities: ["a": 0.8, "b": 0.2], confidence: 0.6)
        XCTAssertNoThrow(try JevDecisionClient.validate(valid, offered: ["a", "b"]))
        XCTAssertThrowsError(try JevDecisionClient.validate(valid, offered: ["a"]))
        let wrongMaximum = JevDecisionClient.Answer(type: "choice", choice: "b", probabilities: ["a": 0.8, "b": 0.2], confidence: 0.6)
        XCTAssertThrowsError(try JevDecisionClient.validate(wrongMaximum, offered: ["a", "b"]))
        let nonNormalized = JevDecisionClient.Answer(type: "choice", choice: "a", probabilities: ["a": 0.8, "b": 0.8], confidence: 0.6)
        XCTAssertThrowsError(try JevDecisionClient.validate(nonNormalized, offered: ["a", "b"]))
    }

    func testSourceSpansPreserveLiteralText() {
        let text = "type Please, keep  BOTH spaces and punctuation!"
        XCTAssertTrue(JevDecisionClient.sourceSpans(text).contains("Please, keep  BOTH spaces and punctuation!"))
        XCTAssertTrue(JevDecisionClient.sourceSpans(text).allSatisfy { text.contains($0) })
        XCTAssertEqual(JevDecisionClient.sourceSpans(""), [])
    }

    func testNoNetworkWithoutConsentAndErrorsNeverEchoResponse() async throws {
        let calls = CoreTransportCounter()
        let snapshot = VoiceControlSnapshot(contextID: "test", applicationName: "Fixture", targets: [])
        let denied = JevDecisionClient(apiKey: "test-secret", consent: { false }, transport: { request in
            await calls.increment()
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        do { _ = try await denied.decide(goal: "test", snapshot: snapshot, history: []); XCTFail("Expected consent rejection") }
        catch { XCTAssertFalse(error.localizedDescription.contains("test-secret")) }
        let count = await calls.count
        XCTAssertEqual(count, 0)
        let rejected = JevDecisionClient(apiKey: "test-secret", consent: { true }, transport: { request in
            (Data("test-secret private document".utf8), HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!)
        })
        do { _ = try await rejected.decide(goal: "test", snapshot: snapshot, history: []); XCTFail("Expected rejection") }
        catch { XCTAssertFalse(error.localizedDescription.contains("test-secret")); XCTAssertFalse(error.localizedDescription.contains("private document")) }
    }

    func testUnknownPressRequiresConfirmationAndStopRevokesIt() async {
        let adapter = CoreTestAdapter()
        let runner = VoiceControlTurnRunner(adapter: adapter, engine: CoreTestEngine())
        await runner.submit("Click send")
        let initial = await adapter.executed
        XCTAssertEqual(initial, 0)
        runner.stop()
        await runner.confirm()
        let stopped = await adapter.executed
        XCTAssertEqual(stopped, 0)
    }

    func testUnknownReceiptIsNeverAutomaticallyRetried() async {
        let adapter = CoreTestAdapter(navigation: true)
        let runner = VoiceControlTurnRunner(adapter: adapter, engine: CoreTestEngine())
        await runner.submit("Open item")
        await runner.resume()
        let executed = await adapter.executed
        XCTAssertEqual(executed, 1)
    }
}

private actor CoreTestAdapter: VoiceControlAdapter {
    var executed = 0
    let navigation: Bool
    init(navigation: Bool = false) { self.navigation = navigation }
    func observe() async throws -> VoiceControlSnapshot {
        VoiceControlSnapshot(contextID: "test", applicationName: "Fixture", targets: [VoiceControlTarget(id: "t1", label: "Send", role: "button", operations: [.press], isNavigation: navigation)])
    }
    func execute(action: VoiceControlAction, snapshot: VoiceControlSnapshot, authority: ActionAuthority) async throws -> VoiceControlReceipt {
        try authority.check(); executed += 1
        return VoiceControlReceipt(status: .unknown)
    }
}
private struct CoreTestEngine: VoiceControlDecisionEngine {
    func decide(goal: String, snapshot: VoiceControlSnapshot, history: [VoiceControlAction]) async throws -> VoiceControlDecision {
        .action(VoiceControlAction(operation: .press, targetID: "t1"))
    }
}

private actor CoreTransportCounter {
    var count = 0
    func increment() { count += 1 }
}
