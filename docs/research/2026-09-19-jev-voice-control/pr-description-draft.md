<!-- Local draft for the eventual GitHub PR. Links are relative to the repository root for publication. Refresh validation and qualification results before posting. -->

## Voice commands that act in the app already open

This adds an explicitly enabled Voice Control experiment: hold Control–Option–Space, say an instruction, and let Jev choose bounded actions against the current macOS Accessibility interface. Browsers use the same native adapter as other apps. There is no required extension, debugging port, separate browser profile, or browser restart.

The feature remains disabled by default; DEBUG builds can expose it with `--enable-voice-control`. This PR is a developer experiment, not a stable-release claim. Real Google Flights and integrated microphone qualification are being performed separately, following the checked-in testing handoff.

## Behavior and architecture

Command capture shares the existing microphone stream and STT scheduler, while bypassing dictation formatting, snippet expansion, normal history insertion, and paste. Existing dictation keeps its meaning. A nonactivating panel supports typed instructions, hold-to-talk, explicit hands-free capture, BYO Jev credentials, corrections, task history, and local diagnostics. Selected-text rewrites continue through the configured Transform writing provider under separate consent.

The router handles supported literal commands locally and delegates semantic decisions to Jev. Every effect is bound to a fresh observation and revocable authority. Ordinary authorized navigation, field edits, and search steps run without repeated confirmation. Payment, destructive actions, external commitments, and unknown consequences require an action-bound deliberate check. Interface changes are distinguished from verified effects; uncertain effects cannot replay automatically.

Corrections preserve the goal and effect history. Manual keyboard/mouse interaction pauses automation; Continue observes the user's edits before replanning. Stop invalidates queued work and pending confirmations. The experimental loop has finite budgets of 40 effects, 100 decisions, and 180 seconds of active automation, excluding human waiting time.

## Privacy and scope

Speech stays local. Explicit Jev consent permits sending the command and bounded visible control context; writing-provider consent is separate. The key lives in Keychain. Recognized secret fields and configured password-manager apps are excluded. Local diagnostic records omit command text, control values, audio, screenshots, and credentials; the activity UI intentionally shows the user's task. Known browser account badges are minimized, but arbitrary page content is not claimed to be universally redacted.

The previous extension experiment is preserved as uncompiled historical research. Its demo is not native browser proof. There is no public Voice Control CLI, general coordinate/OCR fallback, or qualified autonomous booking/sending workflow in this PR. The release matrix identifies the remaining broader proposed routes.

## Validation and qualification

The integrated focused run passed **122 tests, zero failures** after the latest native/recovery fixes (`VoiceControl|DictationFlowCoordinator|TransformRunSerializer`). Shell syntax and Python harness compilation also passed. Full-suite and remote checks will be recorded separately. New regressions cover actionable static-text labels, rich-text editing capability, correction history, manual overrides, uncertain-result non-replay, consequence policy, explicit clarification, and stale queued submissions.

Native live-Jev synthetic field edits worked. Real Google Flights inspection exposed controls at depth 22 and pressable static-text trip choices; adapter changes address those observed representations. A complete native Google Flights run, integrated voice demo, and signed GUI qualification remain pending. No purchase or booking is authorized for qualification.

Read [the testing handoff](docs/research/2026-09-19-jev-voice-control/testing-handoff.md), [native observations](docs/research/2026-09-19-jev-voice-control/native-browser-qualification.md), [behavior contract](spec/contracts/voice-control.md), and [capability matrix](docs/research/2026-09-19-jev-voice-control/release-scope.md).
