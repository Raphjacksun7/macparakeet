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
    func testOpenChromeMatchesRunningBrowserWithoutExactWording() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Notes",
            targets: [
                VoiceControlTarget(id: "app:1", label: "Google Chrome", role: "application", operations: [.activateApp]),
                VoiceControlTarget(id: "note", label: "New Note", role: "button", operations: [.press]),
            ])
        let result = try await router.decide(goal: "open up chrome app", snapshot: snapshot, history: [])
        XCTAssertEqual(
            result, .action(VoiceControlAction(operation: .activateApp, targetID: "app:1")))
    }
    func testOpenChromeDoesNotActivateWhenItIsAlreadyFront() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(id: "from", label: "Where from?", role: "AXComboBox", operations: [.setValue, .press]),
            ])
        let result = try await router.decide(goal: "open up chrome app", snapshot: snapshot, history: [])
        guard case .information(let message) = result else {
            return XCTFail("Already-front Chrome must not become a no-op activation")
        }
        XCTAssertTrue(message.localizedCaseInsensitiveContains("already"))
    }

    func testWebFlightGoalActivatesChromeWhenAnotherAppIsFront() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "cmux",
            targets: [
                VoiceControlTarget(id: "globe", label: "Globe", role: "AXButton", operations: [.press]),
                VoiceControlTarget(id: "app:1", label: "Google Chrome", role: "application", operations: [.activateApp]),
            ])
        let result = try await router.decide(
            goal: "Find one-way flights from Zurich to London on September 20 2026.", snapshot: snapshot, history: [])
        XCTAssertEqual(result, .action(VoiceControlAction(operation: .activateApp, targetID: "app:1")))
    }

    func testWebFlightGoalDoesNotActivateWhenABrowserIsAlreadyFront() async throws {
        let fallback = RecordingFallback()
        let router = VoiceControlCommandRouter(fallback: fallback)
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(id: "from", label: "Where from?", role: "AXComboBox", operations: [.setValue, .press]),
                VoiceControlTarget(id: "app:1", label: "Safari", role: "application", operations: [.activateApp]),
            ])
        _ = try await router.decide(goal: "Find one-way flights to London", snapshot: snapshot, history: [])
        let goals = await fallback.goals
        XCTAssertEqual(goals, ["Find one-way flights to London"])
    }

    func testFlightGoalOpensGoogleFlightsWhenThePageIsNotFlights() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(id: "tab", label: "New Tab", role: "AXButton", operations: [.press]),
                VoiceControlTarget(
                    id: "web:google-flights", label: "Google Flights", role: "url", operations: [.press],
                    isNavigation: true),
            ])
        let result = try await router.decide(
            goal: "Find one-way flights from Zurich to London on September 20 2026.", snapshot: snapshot, history: [])
        XCTAssertEqual(result, .action(VoiceControlAction(operation: .press, targetID: "web:google-flights", consequence: .ordinary)))
    }

    func testFlightGoalDoesNotReopenAfterTheSiteWasAlreadyOpened() async throws {
        let fallback = RecordingFallback()
        let router = VoiceControlCommandRouter(fallback: fallback)
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(id: "tab", label: "New Tab", role: "AXButton", operations: [.press]),
                VoiceControlTarget(
                    id: "web:google-flights", label: "Google Flights", role: "url", operations: [.press],
                    isNavigation: true),
            ])
        _ = try await router.decide(
            goal: "Find flights to London", snapshot: snapshot,
            history: [
                VoiceControlAction(
                    operation: .press, targetID: "web:google-flights", receiptStatus: .transitionObserved)
            ])
        let goals = await fallback.goals
        XCTAssertEqual(goals, ["Find flights to London"])
    }

    func testFlightPlanFillsOriginOnTheFlightsPage() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(
                    id: "from", label: "Where from?", role: "AXComboBox", value: "Home",
                    operations: [.setValue, .press]),
                VoiceControlTarget(
                    id: "to", label: "Where to? ", role: "AXComboBox", operations: [.setValue, .press]),
                VoiceControlTarget(
                    id: "type", label: "Change ticket type. Round trip", role: "AXComboBox", value: "Round trip",
                    operations: [.setValue]),
                VoiceControlTarget(
                    id: "web:google-flights", label: "Google Flights", role: "url", operations: [.press],
                    isNavigation: true),
            ])
        let result = try await router.decide(
            goal: "Find one-way flights from Zurich to London on September 20 2026.", snapshot: snapshot,
            history: [
                VoiceControlAction(
                    operation: .press, targetID: "web:google-flights", receiptStatus: .transitionObserved)
            ])
        XCTAssertEqual(
            result, .action(VoiceControlAction(operation: .setValue, targetID: "from", value: "Zurich", consequence: .ordinary)))
    }

    func testFlightPlanFillsOriginAfterTripType() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(
                    id: "from", label: "Where from?", role: "AXComboBox", value: "Home",
                    operations: [.setValue, .press]),
                VoiceControlTarget(
                    id: "to", label: "Where to? ", role: "AXComboBox", operations: [.setValue, .press]),
            ])
        let result = try await router.decide(
            goal: "Find one-way flights from Zurich to London on September 20 2026.", snapshot: snapshot,
            history: [
                VoiceControlAction(
                    operation: .setValue, targetID: "type", value: "One way", receiptStatus: .verified)
            ])
        XCTAssertEqual(
            result, .action(VoiceControlAction(operation: .setValue, targetID: "from", value: "Zurich", consequence: .ordinary)))
    }

    func testFlightPlanDismissesAutocompleteOverlayAfterCitiesAreFilled() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(
                    id: "else", label: "Where else?", role: "AXComboBox", operations: [.setValue, .press]),
                VoiceControlTarget(
                    id: "focus", label: "Where else?", role: "AXComboBox", operations: [.key], isFocused: true),
                VoiceControlTarget(
                    id: "web:google-flights", label: "Google Flights", role: "url", operations: [.press],
                    isNavigation: true),
            ])
        let result = try await router.decide(
            goal: "Find one-way flights from Zurich to London on September 20 2026.", snapshot: snapshot,
            history: [
                VoiceControlAction(
                    operation: .press, targetID: "web:google-flights", receiptStatus: .transitionObserved),
                VoiceControlAction(
                    operation: .setValue, targetID: "from", value: "Zurich", receiptStatus: .verified),
                VoiceControlAction(
                    operation: .setValue, targetID: "to", value: "London", receiptStatus: .verified),
            ])
        XCTAssertEqual(
            result, .action(VoiceControlAction(operation: .key, targetID: "focus", value: "escape", consequence: .ordinary)))
    }

    func testFlightPlanPressesTheFocusedCitySuggestionDespiteDiacritics() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(
                    id: "city", label: "Zürich, Switzerland", role: "AXStaticText", operations: [.key, .press],
                    isFocused: true),
                VoiceControlTarget(
                    id: "zrh", label: "Zurich Airport (ZRH)", role: "AXStaticText", operations: [.press]),
                VoiceControlTarget(
                    id: "else", label: "Where else?", role: "AXComboBox", operations: [.setValue, .press]),
            ])
        let result = try await router.decide(
            goal: "Find one-way flights from Zurich to London on September 20 2026.", snapshot: snapshot,
            history: [
                VoiceControlAction(
                    operation: .press, targetID: "web:google-flights", receiptStatus: .transitionObserved),
                VoiceControlAction(
                    operation: .setValue, targetID: "from", value: "Zurich", receiptStatus: .verified)
            ])
        XCTAssertEqual(
            result, .action(VoiceControlAction(operation: .press, targetID: "city", targetLabel: "Zürich, Switzerland", consequence: .ordinary)))
    }

    func testFlightPlanEscapesAgainAfterFillingDateIfTheOverlayReturns() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(
                    id: "city", label: "Zürich, Switzerland", role: "AXStaticText",
                    operations: [.key, .press], isFocused: true),
                VoiceControlTarget(
                    id: "else", label: "Where else?", role: "AXComboBox", operations: [.setValue, .press]),
            ])
        let result = try await router.decide(
            goal: "Find one-way flights from Zurich to London on September 20 2026.", snapshot: snapshot,
            history: [
                VoiceControlAction(
                    operation: .press, targetID: "web:google-flights", receiptStatus: .transitionObserved),
                VoiceControlAction(
                    operation: .setValue, targetID: "from", value: "Zurich", receiptStatus: .verified),
                VoiceControlAction(
                    operation: .setValue, targetID: "to", value: "London", receiptStatus: .verified),
                VoiceControlAction(
                    operation: .key, targetID: "focus", value: "escape", receiptStatus: .transitionObserved),
                VoiceControlAction(
                    operation: .setValue, targetID: "date", value: "September 20 2026", receiptStatus: .verified),
            ])
        XCTAssertEqual(
            result, .action(VoiceControlAction(operation: .key, targetID: "city", value: "escape", consequence: .ordinary)))
    }

    func testFlightPlanDoesNotSearchUntilTheRequestedDateIsFilled() async throws {
        let fallback = RecordingFallback()
        let router = VoiceControlCommandRouter(fallback: fallback)
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(
                    id: "from", label: "Where from?", role: "AXComboBox", value: "Zurich",
                    operations: [.setValue, .press]),
                VoiceControlTarget(
                    id: "to", label: "Where to?", role: "AXComboBox", value: "London",
                    operations: [.setValue, .press]),
                VoiceControlTarget(
                    id: "search", label: "Search flights", role: "AXButton", operations: [.press]),
            ])
        _ = try await router.decide(
            goal: "Find one-way flights from Zurich to London on September 20 2026.", snapshot: snapshot,
            history: [
                VoiceControlAction(
                    operation: .setValue, targetID: "from", value: "Zurich", receiptStatus: .verified),
                VoiceControlAction(
                    operation: .setValue, targetID: "to", value: "London", receiptStatus: .verified),
            ])
        let goals = await fallback.goals
        XCTAssertEqual(goals, ["Find one-way flights from Zurich to London on September 20 2026."])
    }

    func testFlightPlanFillsTheDepartureDateWhenTheFieldIsVisible() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(
                    id: "from", label: "Where from?", role: "AXComboBox", value: "Zurich",
                    operations: [.setValue, .press]),
                VoiceControlTarget(
                    id: "to", label: "Where to?", role: "AXComboBox", value: "London",
                    operations: [.setValue, .press]),
                VoiceControlTarget(
                    id: "date", label: "Departure", role: "AXComboBox", operations: [.setValue, .press]),
                VoiceControlTarget(
                    id: "search", label: "Search flights", role: "AXButton", operations: [.press]),
            ])
        let result = try await router.decide(
            goal: "Find one-way flights from Zurich to London on September 20 2026.", snapshot: snapshot,
            history: [
                VoiceControlAction(
                    operation: .setValue, targetID: "from", value: "Zurich", receiptStatus: .verified),
                VoiceControlAction(
                    operation: .setValue, targetID: "to", value: "London", receiptStatus: .verified),
            ])
        XCTAssertEqual(
            result,
            .action(VoiceControlAction(operation: .setValue, targetID: "date", value: "September 20 2026", consequence: .ordinary)))
    }

    func testFlightPlanSubmitsWithReturnWhenSearchIsNotOffered() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(
                    id: "from", label: "Where from?", role: "AXComboBox", value: "Zurich",
                    operations: [.setValue, .press, .key], isFocused: true),
                VoiceControlTarget(
                    id: "to", label: "Where to?", role: "AXComboBox", value: "London",
                    operations: [.setValue, .press]),
                VoiceControlTarget(
                    id: "date", label: "Departure", role: "AXTextField", value: "September 20 2026",
                    operations: [.setValue, .press]),
            ])
        let result = try await router.decide(
            goal: "Find one-way flights from Zurich to London on September 20 2026.", snapshot: snapshot,
            history: [
                VoiceControlAction(
                    operation: .press, targetID: "web:google-flights", receiptStatus: .transitionObserved),
                VoiceControlAction(
                    operation: .setValue, targetID: "from", value: "Zurich", receiptStatus: .verified),
                VoiceControlAction(
                    operation: .setValue, targetID: "to", value: "London", receiptStatus: .verified),
                VoiceControlAction(
                    operation: .setValue, targetID: "date", value: "September 20 2026", receiptStatus: .verified),
            ])
        XCTAssertEqual(
            result,
            .action(VoiceControlAction(operation: .key, targetID: "from", value: "return", consequence: .ordinary)))
    }

    func testFlightPlanDoesNotSubmitReturnWhileACityOverlayIsOpen() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(
                    id: "city", label: "Zürich, Switzerland", role: "AXStaticText",
                    operations: [.key, .press], isFocused: true),
                VoiceControlTarget(
                    id: "else", label: "Where else?", role: "AXComboBox", value: "London",
                    operations: [.setValue, .press, .key]),
                VoiceControlTarget(
                    id: "zrh", label: "Zurich Airport (ZRH)", role: "AXStaticText", operations: [.press]),
            ])
        let result = try await router.decide(
            goal: "Find one-way flights from Zurich to London on September 20 2026.", snapshot: snapshot,
            history: [
                VoiceControlAction(
                    operation: .press, targetID: "web:google-flights", receiptStatus: .transitionObserved),
                VoiceControlAction(
                    operation: .setValue, targetID: "from", value: "Zurich", receiptStatus: .verified),
                VoiceControlAction(
                    operation: .press, targetID: "city", targetLabel: "Zürich, Switzerland",
                    receiptStatus: .transitionObserved),
                VoiceControlAction(
                    operation: .setValue, targetID: "to", value: "London", receiptStatus: .verified),
                VoiceControlAction(
                    operation: .setValue, targetID: "date", value: "September 20 2026", receiptStatus: .verified),
            ])
        XCTAssertEqual(
            result, .action(VoiceControlAction(operation: .key, targetID: "city", value: "escape", consequence: .ordinary)))
    }

    func testFlightPlanMovesFocusInsteadOfRepeatingEscapeOnAStuckOverlay() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(
                    id: "city", label: "Zürich, Switzerland", role: "AXStaticText",
                    operations: [.key, .press], isFocused: true),
                VoiceControlTarget(
                    id: "else", label: "Where else?", role: "AXComboBox", value: "London",
                    operations: [.setValue, .press]),
            ])
        let result = try await router.decide(
            goal: "Find one-way flights from Zurich to London on September 20 2026.", snapshot: snapshot,
            history: [
                VoiceControlAction(
                    operation: .press, targetID: "web:google-flights", receiptStatus: .transitionObserved),
                VoiceControlAction(
                    operation: .setValue, targetID: "from", value: "Zurich", receiptStatus: .verified),
                VoiceControlAction(
                    operation: .setValue, targetID: "to", value: "London", receiptStatus: .verified),
                VoiceControlAction(
                    operation: .setValue, targetID: "date", value: "September 20 2026", receiptStatus: .verified),
                VoiceControlAction(
                    operation: .key, targetID: "city", value: "escape", receiptStatus: .transitionObserved),
            ])
        XCTAssertEqual(
            result,
            .action(VoiceControlAction(operation: .press, targetID: "else", targetLabel: "Where else?", consequence: .ordinary)))
    }

    func testFlightPlanPressesTheMatchingCalendarDay() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(
                    id: "day20",
                    label: "Sunday, September 20, 2026, departure date. , 276 US dollars",
                    role: "AXButton", operations: [.press]),
                VoiceControlTarget(
                    id: "day21", label: "Monday, September 21, 2026 , 184 US dollars", role: "AXButton",
                    operations: [.press]),
            ])
        let result = try await router.decide(
            goal: "Find one-way flights from Zurich to London on September 20 2026.", snapshot: snapshot,
            history: [
                VoiceControlAction(
                    operation: .press, targetID: "web:google-flights", receiptStatus: .transitionObserved),
                VoiceControlAction(
                    operation: .setValue, targetID: "date", value: "September 20 2026", receiptStatus: .verified),
            ])
        XCTAssertEqual(
            result,
            .action(
                VoiceControlAction(
                    operation: .press, targetID: "day20",
                    targetLabel: "Sunday, September 20, 2026, departure date. , 276 US dollars",
                    consequence: .ordinary)))
    }

    func testYouTubeQueryFillsTheSearchBox() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(
                    id: "q", label: "Search", role: "AXComboBox", operations: [.setValue, .press]),
                VoiceControlTarget(
                    id: "web:youtube", label: "YouTube", role: "url", operations: [.press], isNavigation: true),
            ])
        let result = try await router.decide(
            goal: "Play the Apollo 11 documentary on YouTube", snapshot: snapshot,
            history: [
                VoiceControlAction(operation: .press, targetID: "web:youtube", receiptStatus: .transitionObserved)
            ])
        XCTAssertEqual(
            result,
            .action(VoiceControlAction(operation: .setValue, targetID: "q", value: "the Apollo 11 documentary", consequence: .ordinary)))
    }

    func testWebSearchFillsGoogle() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(
                    id: "q", label: "Search", role: "AXComboBox", operations: [.setValue, .press]),
                VoiceControlTarget(
                    id: "web:google-search", label: "Google Search", role: "url", operations: [.press],
                    isNavigation: true),
            ])
        let result = try await router.decide(
            goal: "Search the web for weather in London", snapshot: snapshot,
            history: [
                VoiceControlAction(
                    operation: .press, targetID: "web:google-search", receiptStatus: .transitionObserved)
            ])
        XCTAssertEqual(
            result,
            .action(VoiceControlAction(operation: .setValue, targetID: "q", value: "weather in London", consequence: .ordinary)))
    }

    func testMapsQueryFillsDirections() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(
                    id: "q", label: "Search Google Maps", role: "AXComboBox", operations: [.setValue, .press]),
                VoiceControlTarget(
                    id: "web:google-maps", label: "Google Maps", role: "url", operations: [.press],
                    isNavigation: true),
            ])
        let result = try await router.decide(
            goal: "Directions to the Golden Gate Bridge", snapshot: snapshot,
            history: [
                VoiceControlAction(
                    operation: .press, targetID: "web:google-maps", receiptStatus: .transitionObserved)
            ])
        XCTAssertEqual(
            result,
            .action(VoiceControlAction(operation: .setValue, targetID: "q", value: "the Golden Gate Bridge", consequence: .ordinary)))
    }

    func testWikipediaQueryFillsSearch() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(
                    id: "q", label: "Search Wikipedia", role: "AXComboBox", operations: [.setValue, .press]),
                VoiceControlTarget(
                    id: "web:wikipedia", label: "Wikipedia", role: "url", operations: [.press],
                    isNavigation: true),
            ])
        let result = try await router.decide(
            goal: "Look up Alan Turing on Wikipedia", snapshot: snapshot,
            history: [
                VoiceControlAction(operation: .press, targetID: "web:wikipedia", receiptStatus: .transitionObserved)
            ])
        XCTAssertEqual(
            result, .action(VoiceControlAction(operation: .setValue, targetID: "q", value: "Alan Turing", consequence: .ordinary)))
    }

    func testGmailComposePressesTheUniqueButton() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(id: "compose", label: "Compose", role: "AXButton", operations: [.press]),
                VoiceControlTarget(
                    id: "web:gmail", label: "Gmail", role: "url", operations: [.press], isNavigation: true),
            ],
            summary: "Gmail Inbox")
        let result = try await router.decide(
            goal: "Compose a new email in Gmail", snapshot: snapshot,
            history: [
                VoiceControlAction(operation: .press, targetID: "web:gmail", receiptStatus: .transitionObserved)
            ])
        XCTAssertEqual(result, .action(VoiceControlAction(operation: .press, targetID: "compose", consequence: .ordinary)))
    }

    func testOpenGmailAfterChromeActivateStillOpensTheSite() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Google Chrome",
            targets: [
                VoiceControlTarget(id: "tab", label: "New Tab", role: "AXButton", operations: [.press]),
                VoiceControlTarget(
                    id: "web:gmail", label: "Gmail", role: "url", operations: [.press], isNavigation: true),
            ])
        let result = try await router.decide(
            goal: "open gmail", snapshot: snapshot,
            history: [
                VoiceControlAction(
                    operation: .activateApp, targetID: "app:1", targetLabel: "Google Chrome",
                    receiptStatus: .verified)
            ])
        XCTAssertEqual(
            result, .action(VoiceControlAction(operation: .press, targetID: "web:gmail", consequence: .ordinary)))
    }

    func testOpenChromeAppIsNotAWebSearch() async throws {
        let router = VoiceControlCommandRouter(fallback: MustNotDecide())
        let snapshot = VoiceControlSnapshot(
            contextID: "test", applicationName: "Finder",
            targets: [
                VoiceControlTarget(
                    id: "app:1", label: "Google Chrome", role: "application", operations: [.activateApp]),
            ])
        let result = try await router.decide(goal: "open Google Chrome", snapshot: snapshot, history: [])
        XCTAssertEqual(result, .action(VoiceControlAction(operation: .activateApp, targetID: "app:1")))
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

private actor RecordingFallback: VoiceControlDecisionEngine {
    var goals: [String] = []
    func decide(goal: String, snapshot: VoiceControlSnapshot, history: [VoiceControlAction]) async throws
        -> VoiceControlDecision
    {
        goals.append(goal)
        return .clarify("fallback")
    }
}
