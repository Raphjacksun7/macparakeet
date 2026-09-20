# Fable implementation review

Static review during implementation; findings require checking against subsequent fixes. Requested Fable 5.1 medium.

Review complete. Everything below is static reading of the worktree as of the last read. I executed nothing; the only runtime evidence I cite comes from `docs/research/2026-09-19-jev-voice-control/implementation-log.md` lines 33 to 35, which records 22 passing Swift tests, nine Playwright checks, and live Jev probes with one strict validation failure. Types, runner, coordinator, speech session, native adapter and view model changed while I was reading, so line numbers refer to the latest read and items marked "recheck" overlap in-progress work.

## Blocking findings

- **Spoken confirmation can never succeed.** `Sources/MacParakeet/App/VoiceControlCoordinator.swift:193` and `:239` call `runner?.stop()` on every capture start and speech onset, which revokes the authority stored in `pending`, so `VoiceControlTurnRunner.swift:69` reports "Confirmation expired" for any voice "confirm" in both hold and hands-free modes. The concurrent observe at `VoiceControlCoordinator.swift:242` also evicts the pending snapshot from `VoiceControlBrowserMultiplexer.swift:30` and native `current` at `NativeVoiceControlAdapter.swift:145`, so even a valid confirm would throw. The new `VoiceControlConversationState.shouldPauseForSpeech` in the view model suggests this is in flight; recheck that both the stop and the observe are gated on it, and add a runner test for confirm after a speech onset.

- **The GUI lease is held for the entire panel session and silently disables dictation.** `VoiceControlCoordinator.swift:163` acquires in `ensureSession` and releases only at the end of `end()`. `DictationFlowCoordinator.swift:381` and `MenuBarCoordinator.swift:851` return silently when acquisition fails, so with the Voice Control panel open the dictation hotkey does nothing with no feedback. Smallest fix: acquire when the mic turns on or a runner call starts, release when the mic is off and the runner reaches a terminal event. At minimum dictation needs the same message Transforms shows. The dictation file is in the dirty diff; recheck.

- **Literal mode mangles "type literally".** `VoiceControlCoordinator.swift:280` drops 13 characters from a 15 character prefix, producing "type ly hello". Fix: dispatch the original text unchanged when it already starts with that prefix, since the router strips it at `VoiceControlCommandRouter.swift:24`.

- **Verified direct commands end in a false "only part of the interface is visible" warning.** The router returns `.finished` after a verified effect at `VoiceControlCommandRouter.swift:19`, the runner gates that on `snapshot.isComplete` at `VoiceControlTurnRunner.swift:153`, and native completeness is `stack.isEmpty` under a 180 node budget at `NativeVoiceControlAdapter.swift:144`. Most real windows exceed that budget, so "type hello" succeeds but reports uncertainty, and every Jev `finished` does the same. Fix: give `finished` an associated `requiresCompleteObservation` flag that the router sets false when the last history entry is verified. Needs runtime node counts on Mail, Safari and TextEdit.

## Correctness, privacy and cancellation

- **Jev probability tolerance fails at the boundary.** `JevDecisionClient.swift:135` uses `<= 0.01`, and a sum of exactly 0.99 exceeds that in floating point. The implementation log recorded one validation failure and 0.99 sums. Fix: widen to 0.02 and add a regression fixture.

- **Selected text goes to Jev regardless of the writing-provider consent toggle.** `JevDecisionClient.swift:60` encodes the full snapshot including `selectedText` up to 4000 characters and field values. Setup copy at `VoiceControlPanel.swift:21` promises "a limited description of the current app's controls" while the summary carries visible page text. Fix: map targets to `selectedText: nil` before encoding, and change the copy to "visible text and controls".

- **Mic start waits behind the AX walk, and adapter errors masquerade as mic errors.** `VoiceControlCoordinator.swift:206` awaits adapter startup and `observe()` before `speech.begin`, so hold-to-talk clips the first words by up to the 2 second native or 5 second browser wait. A stale socket or bridge failure then shows "Could not start the microphone." at line 215. Fix: begin speech first, observe concurrently, and report adapter errors separately.

- **A stale bridge socket permanently breaks the browser path.** Unlink happens only in the async cleanup at `VoiceControlCoordinator.swift:377`, which does not run on crash or termination. The next launch hits `alreadyRunning` at `VoiceControlBrowserAdapter.swift:254`. Fix: on bind failure, probe with `connect()`; on ECONNREFUSED unlink and retry once. The 0700 directory makes this safe.

- **Revoke can still block on AX IPC.** The key path at `NativeVoiceControlAdapter.swift:251` performs a focused-element lookup inside `authority.perform`, and every `AXUIElementCreateApplication` in `validateContext` and `frontmostPID` lacks `AXUIElementSetMessagingTimeout`, so a hung target app stalls `stop()` on the main actor for the default timeout. The other paths were just moved outside the lock; recheck. Fix: set the short timeout on every created element and move the focus check before `perform`.

- **Escape anywhere pauses the task and discards speech whenever a session exists.** The global monitor at `VoiceControlCoordinator.swift:115` plus the lease-only guard at line 324 means dismissing a dialog in another app produces "Stopped." and drops the pending utterance. Fix: guard on working, confirmation, or mic on.

- **Browser scroll ignores the action value and offered options exceed adapter support.** `content.js:110` scrolls by target ID, so a Jev "scroll up" bound to `scroll:down` scrolls down. The `direction` and `key` questions at `JevDecisionClient.swift:58` offer left, right, shift-tab and space, which the native adapter rejects as unsupported and the runner reports as a generic failure. Fix: honor `action.value` in `content.js` and restrict offered criteria to supported values.

- **Pre-dispatch revocation is recorded as an unknown effect.** A revoked write in `VoiceControlBrowserAdapter.swift:135` surfaces as `CancellationError`, which `execute` converts to `.unknown` at line 195; the runner then blocks Resume with "The last action is uncertain" although nothing was sent. Fix: rethrow when the failure precedes the write.

## Shipping gaps and UX polish

- **Short taps of the hold shortcut show "Could not finish microphone capture."** `AudioRecorder.stop()` throws `insufficientSamples` under 0.3 seconds; `VoiceControlSpeechSession.swift:166` maps every error to that message. Catch this case and say "Hold the shortcut while you speak."

- **Payment fields are not excluded in the browser.** Add `[autocomplete^="cc-"]` to `content.js:7` to match the native "credit card" heuristic.

- **Hotkey conflict message hardcodes the default chord and ignores a failed tap.** `VoiceControlCoordinator.swift:103` names Control–Option–Space even with a custom trigger, and a `false` from `manager.start()` at line 113 is silent. Use `displayName` and set a message on failure.

- **Consent toggle drifts from storage.** The consent binding persists only on Save, so unchecking and closing leaves stored consent true.

- **Needs runtime evidence before qualification.** App activation from a non-active app is cooperative on macOS 14 and later, so `activateApp` at `NativeVoiceControlAdapter.swift:160` will often return `.unknown`. Also verify that clicking Confirm or typing in the nonactivating panel does not change the system-wide focused application used by `frontmostPID()`, and that the energy endpointer does not stop tasks on keyboard noise in hands-free mode.

Suggested focused tests: runner confirm after speech onset, literal-mode payload as a pure function, Jev tolerance, Jev payload redaction of selected text, browser socket recovery, and a `content.js` scroll-direction case.
