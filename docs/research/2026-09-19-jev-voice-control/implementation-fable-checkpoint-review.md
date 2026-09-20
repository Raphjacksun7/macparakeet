# Fable checkpoint review

Requested Fable 5.1 medium. Static review of the earlier extension-capable checkpoint; no independent build/runtime or git diff validation. Subsequent native-only direction supersedes browser-specific findings. Rich-text replacement, paused admission, cancellation and confirmation expiry findings inform the revised implementation.

**Verdict (static review only):** the branch is sound as a compile-time-gated experimental PR, but I would fix three things before merge: whole-field AX rewrites that can flatten rich text, a browser multiplexer that permanently disables native control after a tab disconnect, and GUI-lease retention in paused states that cannot resume. Everything else is follow-up material. I ran nothing, and Bash was denied, so I could not diff against origin/main or check git state; file inventory came from Glob and Grep.

## Prior adversarial review: status

Resolved in code, not repeated below: spoken confirmation gating (`VoiceControlCoordinator.swift:364,419`), dictation busy message (`DictationFlowCoordinator.swift:382`, `AppDelegate.swift:718`), literal prefix (`VoiceControlCoordinator.swift:485`), verified direct completion (`VoiceControlCommandRouter.swift:28-39`), probability tolerance (`JevDecisionClient.swift:211`), selectedText redaction (`JevDecisionClient.swift:107`), mic-before-observe ordering (`VoiceControlCoordinator.swift:377-397`), stale socket recovery (`VoiceControlBrowserWire.swift:79`), per-attribute AX timeout (`NativeVoiceControlAdapter.swift:393`), key focus check before `perform` (`:307`), scroll direction (`content.js:112`), pre-dispatch cancellation (`VoiceControlBrowserAdapter.swift:145,209`), short-tap copy, payment fields, conflict copy, consent immediate revoke.

Still open from that list: the runtime items (cooperative `activate()`, nonactivating panel vs `frontmostApplication`, keyboard noise in hands-free). "Escape anywhere" was narrowed to lease-held only, which for paused states is the same as "session exists"; folded into findings 3 and 8.

## Findings by severity

**High**

1. **Native text entry rewrites the whole field.** `insertText` and `setValue` both set `kAXValueAttribute` with the full replacement string (`NativeVoiceControlAdapter.swift:246-255`). In NSTextView-backed apps (Notes, TextEdit, Mail compose) that flattens attributes and attachments across the entire document, not just the caret span. The browser adapter refuses contentEditable for exactly this reason (`content.js:140-143`); the native adapter has no equivalent guard, and the undo affordance lasts 30 s only while the value is unchanged. The repo already has the safer primitive: `SelectionReplacementService.writeSelectionViaAX` sets `kAXSelectedTextAttribute` (`SelectionReplacementService.swift:334-350`). Fix: use the selected-text setter for `insertText`, and limit whole-value `setValue` to `AXTextField`/`AXComboBox`.

2. **Browser selection is sticky across sessions with no recovery path.** `browserWasSelected` is set on first browser observe and cleared only by `stop()`; `useNative()` has zero callers (`VoiceControlBrowserMultiplexer.swift:8,22-28`). After the tab disconnects (tab switch, cross-origin navigation, Disconnect), every observe throws `notConnected`, the runner maps it to the generic "Check the connection and app permissions" (`VoiceControlTurnRunner.swift:246-250`), and the finished-session path skips `browser.stop()` (`VoiceControlCoordinator.swift:591`), so the flag survives into the next task. Native control stays dead until the user clicks Close. Fix: reset when a new goal starts and the browser is not connected, and surface `BridgeError.localizedDescription`.

3. **Lease held indefinitely in non-resumable paused states.** Release happens only for `.done/.failed/.idle` (`VoiceControlCoordinator.swift:493-499`). Terminal `.paused` outcomes include "Only part of the interface is visible" (`VoiceControlTurnRunner.swift:191`, driven by `isComplete = stack.isEmpty` under a 180-node budget at `NativeVoiceControlAdapter.swift:162`, which real windows will exceed), "Task limit reached", "The app is not changing", and the hands-free 10-minute expiry (`:448`). `.confirmation` also never times out in the UI: the 20 s expiry is checked only inside `confirm()` (`:70-71`) with no event. Result: dictation and history paste are blocked, Resume repeats the same result, and the only exit is the Close icon. Fix: release or auto-end for pauses Resume cannot change; emit a timed expiry event for confirmations.

**Medium**

4. **Stop cannot interrupt an in-flight Jev or observe call.** Authority is checked only between awaits (`VoiceControlTurnRunner.swift:159-176`). The Jev transport is a plain `session.data(for:)` with a 15 s timeout and no link to revocation (`JevDecisionClient.swift:24,120`). `cancelAndDrain()` (`:44-47`) and any new `submit` (`:53`) therefore wait behind it, and `end()` cleanup holds the GUI lease for that long. Browser observe can add up to 9 s (`VoiceControlBrowserAdapter.swift:175-179`). Fix: run decide/observe in a child Task cancelled by `gate.revoke()`.

5. **Hands-free silently drops the previous command when the user speaks again early.** `.began` cancels `finalTask` and rotates `utteranceID` (`VoiceControlSpeechSession.swift:236-239`); the transcript guards then drop it (`:265-269`), and the coordinator drops it again (`VoiceControlCoordinator.swift:440,518`). Intentional per the comment at `:47-48`, but there is no user feedback that "scroll down" was discarded.

6. **Same-origin re-injection under real `activeTab` is unverified.** `background.js:108` re-runs `executeScript` after navigation and any failure disconnects silently (`:118`). The recorded proof granted a loopback host permission instead of activeTab (`browser-implementation-evidence.md:49`). If Chrome revokes activeTab on navigation, the session dies after the first click-through and finding 2 makes it permanent. Also note every browser press requires confirmation because all DOM targets are `isNavigation:false` (`content.js:73`, `VoiceControlTurnRunner.swift:210`).

7. **Registration dead-end.** A manifest with our host name but a missing `pairing.json` fails as `.conflictingManifest` regardless of the Replace toggle (`VoiceControlBrowserRegistration.swift:129-135`). No UI recovery exists. Allow replacement when `decoded.name` is ours.

**Low**

8. Escape fires `stop()` twice (CGEvent tap `:153` and global monitor `:165-193`), the second overwriting the message. `.scrollWheel` in the global mask (`:162-164`) means inertial scroll residue pauses the task and discards the pending utterance.
9. "Yes" or "okay" to a confirmation starts a new goal; `takeClarification()` clears a pending confirmation as a side effect (`VoiceControlViewModel.swift:24-28`). Fails closed, but surprising.
10. `AppFeatures.swift:20-22` documents `voiceControlEnabled` as "Experimental speaker recognition".
11. The host target links all of `MacParakeetCore` (`Package.swift:128-132`) for a 48-line relay, dragging the app's dependency graph into a Chrome-launched helper. Verify signing and size in the underway signed build; a tiny wire-only target would avoid it.
12. `explainInteractionBusy` tells users to "End Voice Control" but the panel's only affordance is the Close icon (`VoiceControlPanel.swift:17`).

## Limits

No build, tests, git commands, or runtime checks were run. I did not review `tests/BrowserQualification.swift`, the Playwright scripts, `HotkeyManager` internals, or `STTScheduler` admission beyond the cited lines. Findings 1, 2, 4 and 5 are code-traceable; 3 is partly a design choice the contract documents, so the fix scope is the user's call; 6 and 11 need the signed build and a physical browser run to confirm.