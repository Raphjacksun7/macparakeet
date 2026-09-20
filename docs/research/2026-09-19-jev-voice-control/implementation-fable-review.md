# Fable pre-implementation design review

Requested claude-fable-5-1, medium effort. Source review, not runtime evidence.

Review complete. No code was built or run; every finding below comes from reading the plan, the research docs, and the current source at `3f52977e`.

## Verdict

The plan is coherent and its invariants are right, but three of its load-bearing assumptions do not match the code. The AX control layer is entirely greenfield, dictation capture cannot be reused for command utterances, and the browser extension is sequenced as a prerequisite for the early goal demo when it does not need to be. Fix the ordering and contracts below before slice 1, and the rest of the plan stands.

## Blockers and corrections, in priority order

1. **No AX inventory or executor exists anywhere.** `Sources/MacParakeetCore/Services/System/AccessibilityService.swift:48` exposes only focused-element selected text. There is no `AXUIElementPerformAction`, child traversal, window enumeration, or geometry read in `Sources/`. Slice 2 is not an adaptation of existing services; it is a new subsystem, and every fast path, preview outline, and postcondition check depends on it. Validation: contract tests against a fake observer first, then a TextEdit/Notes/Finder matrix on hardware.

2. **`DictationService` must not capture command speech.** Its stop path runs `processCapturedAudio` at `Sources/MacParakeetCore/Services/Dictation/DictationService.swift:1370`, which injects Voice Return triggers, expands snippets, runs the AI Formatter, emits dictation telemetry, and writes history. A command utterance through that path would violate the dictation invariant and the privacy posture. Build a separate `UtteranceCapture` that owns a second `AudioRecorder` subscriber on `SharedMicrophoneStream` (fan-out is the documented model in `Sources/MacParakeetCore/Audio/README.md:454`) and talks to `STTScheduler` directly. Reuse job kind `.dictation` for the final pass so the trailing-silence pad still applies (`Sources/MacParakeetCore/STT/README.md:189`). Add a mutual-exclusion lease so the dictation and voice-control hotkeys cannot both start capture. Validation: a test asserting the voice-control trigger during an active dictation yields "busy" and never inserts text.

3. **The browser extension is not required for the early spoken-goal milestone.** No extension, native-messaging host, or bridge code exists, and a Safari extension needs a new Xcode app-extension target with signing and notarization changes. Safari and Chrome expose `AXWebArea` trees with links, buttons, text fields, and URLs through the same AX API as native apps. Correct slice 4: prove the Zürich to London flight goal over the AX browser adapter plus Playwright-served fixture pages, measure candidate coverage, and only then decide whether the extension is needed. Playwright launches its own Chromium for tests. The user's personal browser is never relaunched with CDP flags.

4. **Cancellation-safe text entry confirmed as a real gap.** `Sources/MacParakeetCore/Services/System/StreamingCursorInserter.swift:229` catches `CancellationError` and drains every remaining chunk, and the head-insert tap re-posts the user's keystroke after that drain. Write a new `RevocableTextEntry` that checks an authority token before each posted batch and reports `.partial(committed:)` on revocation. Reuse `StreamingCursorEventPosting`, `StreamingCursorScheduler`, and `StreamingCursorEventMarker` so `HotkeyManager` keeps ignoring synthetic events. Leave the inserter and its tests untouched.

5. **No process-wide GUI mutation owner exists.** `TransformRunSerializer` is a per-coordinator `@MainActor` class, and the dictation paste effect in `DictationFlowCoordinator` has no serializer at all. Add a small Core `GUIMutationArbiter` actor with timed acquire. Adopt it in the Transforms run body and the dictation paste effect in a separate behavior-preserving PR before voice control lands. Validation: `TransformRunSerializerTests` still pass plus an interleaving test that a voice-control action cannot dispatch while a paste lease is held.

6. **Jev needs its own client, not `LLMService`.** Jev's Choice/Noul/Score shape is not chat completions. Build `JevDecisionClient` as an actor with Codable request/response types, strict validation (offered-ID membership, finite normalized probabilities, argmax equals chosen), a pinned model version, and its own `KeychainKeyValueStore` service name following `LLMConfigStore`. Reuse `LLMHTTPErrorMapper.scrubAPIKeyArtifacts`. Consent lives in a new `VoiceControlConsentStore`, separate from LLM provider configuration. One correction for the docs: the routing catalog links `.agents/skills/typesafe-ai/SKILL.md`, which does not exist in this worktree. Verify the live Jev wire format before coding the client.

7. **Hotkey layer needs a hold-capable trigger, not the auxiliary template.** `AppHotkeyCoordinator.startAuxiliaryHotkey` uses `GlobalShortcutManager`, which is keyDown-only. Voice control needs `HotkeyManager` with `.holdOnly` for hold-to-talk and `.singleTapToggle` for the accessible session toggle. Its `onStartRecording`/`onStopRecording`/`onCancelRecording` callbacks and built-in Escape handling map directly onto invoke, commit, and physical Stop. Register the new trigger in `HotkeyConflictPolicy` candidates and in the Transforms reserved-hotkey provider.

8. **Turn commitment is hold-release only today.** Native partials arrive as plain cumulative strings through `beginLiveDictationTranscription`; there are no revision IDs and no dictation endpointer. Ship hold-to-talk commit first. Hands-free commit needs a Silero endpointer adapted from the meeting VAD chunker and belongs in slice 3 or later, as the plan already hedges.

9. **ADR debt is concrete.** `spec/adr/011-llm-cloud-and-local-providers.md:87` states the app ships "no voice Command Mode". ADR-027's filter excludes general desktop control. `spec/13-agent-workflows.md` is already the draft home for voice control and the plan does not cite it. Slice 0 must amend ADR-011, add a new ADR for the deliberate surface extension, and link or supersede spec 13.

10. **Smaller confirmations.** `AppFeatures` uses compile-time constants plus a DEBUG launch argument; follow the `voiceProfilesEnabled` pattern exactly. The dormant `.command` overlay kind in `DictationOverlayViewModel` is a presentation stub only and should not be extended; build a new view model in `MacParakeetViewModels`. Defer any CLI voice-control surface out of slices 1 to 4; `integrations/README.md` scope and ADR-027 §3 both discourage mirroring live controls. New telemetry names are a two-repo change and belong in slice 7.

## Recommended first contracts

Core runner, in `Sources/MacParakeetCore/Services/VoiceControl/`:

```swift
public protocol VoiceControlObserving: Sendable {
    func observe(scope: ObservationScope, budget: ObservationBudget) async throws -> ObservationSnapshot
    func revalidate(_ candidate: Candidate) async -> RevalidationResult   // .valid(geometry) | .changed | .gone
    func check(_ postcondition: Postcondition) async -> PostconditionResult // .observed | .failed | .unknown
}

public protocol VoiceControlActing: Sendable {
    func perform(_ action: BoundAction, authority: ActionAuthority) async -> ActionReceipt
}

public protocol DecisionEngine: Sendable {
    func decide(_ request: DecisionRequest) async throws -> DecisionResponse
}

public actor VoiceControlTurnRunner {
    public var events: AsyncStream<VoiceControlEvent>
    public func submit(_ turn: CommittedTurn) async -> TurnOutcome
    public func stop()            // revoke authority, pause task, local only
    public func cancelTask()
    public func resumeTask() async
}
```

`ObservationSnapshot` carries a generation, a `ContextIdentity` (pid, bundle, window, tab, document), candidates with opaque IDs and a privacy class, and a coverage status. `ActionAuthority` is consume-once and revocable. `GoalTask` carries the 12/30/60/2 budget from the plan.

Speech:

```swift
public protocol UtteranceCapturing: Sendable {
    func begin(mode: UtteranceMode) async throws -> UtteranceSession
}
public actor UtteranceSession {
    public var revisions: AsyncStream<TranscriptRevision>   // revision: Int, text, isFinal
    public func commit() async throws -> CommittedTranscript
    public func cancel() async
}
```

UI: `VoiceControlCoordinator` in the App target wires `HotkeyManager` to capture and the runner, `VoiceControlViewModel` in `MacParakeetViewModels` holds the state table from the plan, and a nonactivating pill plus a per-screen highlight window follow `DictationOverlayController`.

## Sequencing

1. ADR amendment, new ADR, `spec/contracts/voice-control.md`, feature flag, `GUIMutationArbiter` adopted by Transforms and dictation paste.
2. Pure runner, policy, receipts, `JevDecisionClient` with recorded fixtures and no network in tests.
3. `UtteranceCapture`, hotkey trigger, minimal pill, dictation-invariant test.
4. Native AX observer and actor, `RevocableTextEntry`, native app matrix.
5. AX browser adapter, goal runner, Playwright fixtures, the flight goal over AX, coverage measurement, then the extension decision.
6. Remaining slices as written.

The evaluation doc's file references were confirmed to exist. Its specific line numbers were not re-verified.
