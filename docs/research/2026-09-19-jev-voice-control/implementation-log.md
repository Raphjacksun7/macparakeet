# Voice Control implementation log

## Authorization and context

2026-09-19: user explicitly requested full implementation, Fable 5.1 medium design review first, meaningful commits, local/API/native qualification, a high-quality PR and demo recording if possible. User authorized implementation judgment and delegation. PR is the delivery boundary; merging or stable release publication is not part of this execution.

Worktree: `/Users/dmoon/code/macparakeet-jev-voice-control`; branch `feat/jev-voice-control`, fetched origin/main base `3f52977e272bf08c00cf53ef7f4db9068b070f46`. Original checkout and unrelated dirty work preserved. Existing research copied into this branch. Credential remains local in original checkout, ignored, never included in artifacts or logs.

## Context zone

Implement explicit Voice Control with shared local speech infrastructure, Jev decisions over observed UI, bounded goal execution, corrections, stop-safe effects and visible outcomes. Native macOS Accessibility owns target identity for apps and existing browser sessions. The optional browser bridge was an earlier experiment and is no longer shipped. Add product entry points, settings/consent, qualification harness and documentation. Reuse configured writing providers where generation is required.

Invariants: normal dictation never interprets commands; existing dictation insertion/cancellation semantics unchanged; no competing STT runtime; no raw audio cloud upload; secrets excluded before model requests; no silent replay of unknown effects; Stop revokes future effects; prior callbacks cannot revive a task; explicit consequence confirmations remain action-bound. No arbitrary generated scripts, ambient listening or personal-browser CDP restart. Preserve user app data and other running dev instances.

## Milestones

Current source status; runtime/release qualification is a separate milestone.

- [x] Isolated branch and durable research checkpoint.
- [x] Fable design review and implementation review; later findings remain tracked separately.
- [x] Core typed decisions, consequence policy, bounded runner and focused tests implemented.
- [x] Native Accessibility observation/execution for apps and existing browsers implemented; coverage qualification pending.
- [x] Shared speech, native UI and product wiring implemented.
- [x] Current implemented scope documented in contracts and release-scope matrix.
- [ ] Broader full-plan routes and full-release qualification.
- [ ] Live model and native/browser qualification, demo.
- [ ] Independent review, final checks, PR with exact limitations.

## Verification discipline

Focused suites during implementation; full Swift suite at most once as final gate. No live behavior claimed from mocks. Record exact commands, results and limitations. API use only with sanitized fixtures or explicitly enabled feature context. No credential content in command output.

## Historical checkpoints

The following checkpoints record the source and evidence at their stated time.
Extension transport, universal press confirmation and packaging entries below were
superseded by the native-only/current-status section at the end. Test totals refer
to those revisions and must not be presented as final-head verification.

## First implementation checkpoint

- Fable 5.1 medium source review completed before implementation; full report in `implementation-fable-review.md`. Adopted separate raw command capture, new AX subsystem, shared GUI admission, dedicated Jev client and AX-first goal proof. At this historical checkpoint, the browser extension remained in scope.
- `swift test --filter VoiceControl` passed: 22 tests, zero failures (2026-09-19 17:26 local). This compiles app/core/view-model/browser-host targets. Earlier concurrent source edits invalidated two builds; these were not test failures and the settled run passed.
- Browser worker ran nine real Playwright DOM checks, passing; detailed browser artifacts/README owned by that subsystem.
- Live Swift Jev client tested only synthetic form context: destination London selected correctly (~385ms); negated search caused no action (~109ms); compound source/destination requests produced correct origin selection in several runs and clarification in others. One response failed strict validation; later probes observed probability sums of 0.99, so rounding tolerance needs a regression check. These are model-call durations, not voice-to-effect latency.
- Review caught incomplete selected-text data loss; adapters now omit over-limit selections rather than rewrite a prefix over the full range.
- Outstanding before qualification: richer observed transitions for generic presses, direct-route terminal bookkeeping, hands-free cancellation/partial preview hardening, native fixture/hardware trials and full scope audit. This checkpoint is not release ready.

## Live-loop qualification and corrections

- Native AX probe initially failed its global focused-application check. A separate minimal AX probe returned `AXFocusedApplication -25204` on this Mac while NSWorkspace correctly identified the foreground application. The adapter now reads foreground PID on MainActor through NSWorkspace and retains scoped AX window/control revalidation. It does not bypass target freshness.
- Native observation initially descended closed system menus; the live fixture exposed recent-item labels. Closed menu descendants are now excluded. The qualification probe explicitly disables menu/app enumeration so only disposable fixture controls reach its synthetic Jev calls. No raw native snapshot from that initial discovery is committed.
- Native live Jev+AX two-field goal succeeded after correction: Origin verified at383ms, Destination verified at560ms, model completion at710ms. These are one local fixture and text instruction, not microphone latency or broad app compatibility.
- Browser worker completed full synthetic flight goal through actual extension/native host/private socket/Swift runner/live Jev, with independent DOM assertion of origin/destination/date/trip type. Seven decisions, roughly150–260ms each. Fixture-only allowlisted confirmation automation and loopback permission distinguish this from production/manual confirmation qualification. No real flight booking occurred.

## Hardened integration checkpoint

- `swift test --filter 'VoiceControl|DictationFlowCoordinator|TransformRunSerializer'`: 96 tests, zero failures at 17:46 local. Includes ordinary dictation and Transform admission/cancellation regression suites, speech Stop fencing, browser socket safety and exact local command completion. Full suite has not run yet.
- Fable implementation review is recorded in `implementation-fable-adversarial-review.md`. Fixes include synchronous speech revocation, microphone startup independent of UI observation, immediate consent revocation, source selection redaction, direct verified completion, stale socket recovery and payment-field exclusion.
- Browser recording saved under ignored `output/voice-control/`; detailed evidence and unsuccessful confidence-pause trials are in `browser-implementation-evidence.md`.
- Local Parakeet correctly transcribed a synthetic speech file: “Set origin to Zurich and destination to London.” This used the existing file CLI, not the command capture path, so it does not qualify microphone integration. The initial CLI invocation omitted `--no-history` and created synthetic history item `14BA4552-7D80-4143-A413-6F8B9E3EAA5C`; it has been left intact. Further CLI qualification must use `--no-history` or isolated state. No existing user records were changed or deleted.

## Review resolution notes

The adversarial report is retained verbatim as review evidence, not current status.
Its blocking speech confirmation, GUI admission feedback, literal introducer and
direct completion findings have focused regressions in the hardened checkpoint.
Consent, microphone ordering, stale socket, scroll direction, payment exclusion,
pre-dispatch cancellation and short-tap copy fixes are implemented. Native AX
IPC uses a bounded timeout and no focus read occurs inside the revocation lock.
Probability normalization uses 0.010001 tolerance, enough for observed 0.99
rounding plus floating-point error; it does not accept arbitrary malformed sums.
Manual keyboard/mouse takeover intentionally pauses a retained task; ordinary
terminal sessions release admission when their microphone is off. Physical
speech/confirmation and packaged installation evidence still need separate checks.

## Packaged setup checkpoint

- Hardened integration rerun: 105 tests passed, zero failures at 17:53 local. Includes five native registration tests and contextual-help/Unicode replacement regressions. Dev/dist scripts pass `bash -n`.
- At this historical checkpoint, browser host and extension embedded in dev/dist bundles; native setup registers an exact extension ID with explicit replacement and secure file handling. A browser listener can start without microphone capture. Web Store publication is still separate.
- Native review found hidden/offscreen controls, ambiguous AX read failures, cross-window undo and stale foreground checks. Observation now requires visible geometry before reading values/offering controls; required edit values fail closed; undo retains its original window; effects recheck foreground ownership. Generic checkboxes/links require confirmation because their semantics can be consequential. These require runtime rerun in the disposable fixture.

## Preserved checkpoint before native-only direction

Implementation is committed through `b85642a5`, following research checkpoint
`b8bc41e0` and first implementation `36a2c337`. The user subsequently supplied
[native-accessibility-direction.md](native-accessibility-direction.md) as the
governing product direction: browser control must work through native macOS
Accessibility without requiring an extension. At this checkpoint, extension
product wiring and packaging still exist; the direction change has been reviewed
but not applied. Preserve earlier browser evidence as historical evidence only.

The signed development-app build attempted through `scripts/dev/run_app.sh`
stopped during Xcode package resolution with “Couldn’t update repository
submodules.” It did not launch a new app or establish microphone/UI qualification.
The installed Homebrew Git provides its helpers at
`/opt/homebrew/opt/git/libexec/git-core`; retrying with the appropriate
`GIT_EXEC_PATH` remains to be done. The local Greptile review could not run because
its CLI was not signed in. Neither attempted check is a passing review/build.
The full Swift suite, final qualification and PR delivery remain outstanding.


## Current native-only implementation and qualification handoff

The governing [native direction](native-accessibility-direction.md) and
[recovery direction](correction-recovery-observability-direction.md) are now
implemented in the source. AppDelegate constructs `NativeVoiceControlAdapter`
directly. The app no longer exposes extension setup, registration or pairing;
the build no longer packages a browser extension/native host. Historical browser
research remains separate and is not proof of native browser compatibility.

Current behavior includes goal amendments, recent-target alternative clarification,
manual takeover with explicit Continue, and preserved unknown-effect guards across
corrections. Paused/completed mic-off tasks keep their context but release GUI
admission after work drains; new work reacquires admission. Ordinary supported
navigation, form edits and search do not repeatedly ask permission. Consequential
or unknown effects retain action-bound confirmation. Defaults are 40 dispatched
actions, 100 decisions and 180 active seconds, excluding waits for the user;
confirmation expires after 20 seconds.

The native panel retains BYO Jev Keychain setup, local command speech, typed input,
separate writing-provider consent, literal mode and selected-text rewrites. It
shows the original goal and bounded ephemeral task activity distinguishing attempts,
verified effects, transitions and unknown outcomes. Diagnostics exposes actual
in-memory stage/operation/outcome, task/revision IDs, timing, candidate/coverage and
model metadata. Explicit Copy writes only content-minimized records to the local
clipboard. No automatic file export/upload or default persisted command/UI-text
history, raw audio or screenshot capture is added. Visible field values still go
to Jev under the general app-context consent; omitting the dedicated selectedText
property does not imply selected words can never appear in visible values.

Desktop qualification is assigned separately while independent code, documentation,
review and PR preparation continue. There is **no demonstrated native Google Flights
success** in the evidence recorded here. The historical extension fixture video,
native two-field fixture and file-based synthetic STT check must remain identified
as separate evidence classes. Do not relabel them as a shipped native browser demo
or a complete microphone-to-flight result.

The broader unimplemented routes remain in [release-scope.md](release-scope.md),
including numbered overlays, broad window/tab operations, spelling/range editing,
system controls and cross-app content workflows. Final-head checks, open-PR details
and external desktop qualification results must be appended when actually observed;
this reconciliation does not claim a passing final build, full suite or stable release.

### Native-only PR checkpoint verification (2026-09-19 18:49 local)

`swift test --filter 'VoiceControl|DictationFlowCoordinator|TransformRunSerializer'`
passed **122 tests, zero failures** after native-only integration and the review
fixes. Log: `/tmp/jev-pr-focused-tests.log`. This compiles app/core/view-model
code; it does not prove a signed GUI launch or microphone/Google Flights behavior.
Shell syntax checks for both packaging scripts and Python harness compilation
also passed. The full-suite final gate has not yet run.

Independent read-only review found and drove fixes for non-text Delete bypassing
confirmation, AX press errors permitting uncertain replay, and stale manual edits
overriding later spoken corrections. UI review drove revocable submission identity
across snapshot/actor waits, pending-speech cancellation, retained paused-task
manual-edit tracking, and clearing the cancelled goal. Focused regressions cover
these policies and stale ingress; actual AX failures still require runtime testing.

The native adapter now names pressable AXStaticText choices from AXValue and treats
an error after AXPress as an unknown outcome. No desktop interaction was performed
in this checkpoint; the separate qualification agent owns real-site evidence.
