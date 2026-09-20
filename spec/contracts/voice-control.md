# Voice Control boundary contract

Status: implemented behind the disabled-by-default Voice Control feature gate;
release and device qualification remain separate from source/test evidence.

## Purpose

Voice Control turns an explicitly supplied instruction into bounded interaction
with the current app or existing browser through macOS Accessibility. Ordinary
dictation must keep inserting speech as text. Enabling Voice Control does not
change the meaning of the existing dictation shortcuts, processing pipeline,
history, or cancellation behavior.

This contract describes the implemented boundary, not every feature proposed in
the [research plan](../../plans/active/2026-09-19-jev-voice-control.md).

## Producers and consumers

- `VoiceControlCoordinator`, `VoiceControlViewModel`, and `VoiceControlPanelView`
  own invocation, consent, shortcuts, listening, corrections and visible outcomes.
- `VoiceControlSpeechSession` produces raw final command transcripts using a
  dedicated `AudioProcessor` subscriber on `AppEnvironment.sharedMicStream` and
  the existing process-wide `AppEnvironment.sttScheduler`.
- `VoiceControlCommandRouter` handles supported exact commands locally and
  delegates semantic decisions to `JevDecisionClient`.
- `VoiceControlTurnRunner` binds decisions to observations, applies confirmation
  and budget policy, and consumes execution receipts.
- `NativeVoiceControlAdapter` observes macOS Accessibility controls and executes
  the supported typed operations in the current app, including existing browsers.
- `GUIMutationArbiter` coordinates foreground effects with dictation, Transforms
  and menu/history paste.

No public CLI speech-control command or external automation API is introduced by
this boundary. Developer qualification executables are test tools.

## Entry, credentials and consent

`AppFeatures.voiceControlEnabled` defaults to false. DEBUG builds can expose the
feature with `--enable-voice-control`; release builds ignore that override.
The Capture/status menu opens a nonactivating Voice Control panel. Opening the
panel does not open the microphone. The default hold shortcut is
Control–Option–Space and is configurable in the panel's setup. Installation checks
conflicts against this app's capture shortcuts and configured Transform shortcuts;
it does not claim to detect every shortcut registered by another application.

The Jev key is stored in macOS Keychain under service
`com.macparakeet.voice-control.jev`, account `apiKey`. Production app code has no
shell-environment or repository-file key fallback. There is no default key in
source, diagnostic output, examples or tests.

Two independent preferences govern disclosure:

| Preference | Meaning |
| --- | --- |
| `voiceControl.cloudContextConsent.v1` | Allow the command and minimized visible text/control context to be sent to Jev. |
| `voiceControl.writingConsent.v1` | Allow selected text and the rewrite instruction to be sent to the configured writing provider. |

Enabling consent requires Save. Unchecking a consent control revokes its stored
permission immediately. Revoking cloud control stops the current session;
forgetting the key also deletes the Keychain item. Neither operation disables
ordinary local dictation. A request already sent to a provider cannot be recalled.

Browser control uses the same native Accessibility adapter. The shipping app has
no extension installation, extension ID, host registration, pairing, debugging
port or special browser profile requirement. It uses the browser/session already
open. Historical extension experiments are not a supported product path. Existing
browser data or settings must not be removed as part of this change.

Audio stays on the Mac. Jev is text-only and receives no audio. Native observation
excludes configured password-manager apps and recognized secret fields.
Jev request serialization omits the dedicated `selectedText` property; visible
field values can still contain the same text under the general context consent.
The writing toggle controls the separate writing-provider call, not whether any
visible text appears in a Jev context snapshot.

## Speech lifecycle and commitment

The speech session must never instantiate a second `STTRuntime`, `STTScheduler`,
or app-side `STTClient`. A microphone subscription is independent from ordinary
dictation state but shares the same physical microphone stream. Engine leases
pin the selected Live Speech route across capture and final transcription.

Authoritative transcripts come from recorded audio through the shared scheduler's
`.dictation` lane, preserving its interactive admission and final trailing-silence
handling. Command audio does not enter `DictationService`'s formatter, snippet
expansion, Voice Return transformation, normal dictation persistence or paste path.
Owned temporary command WAVs are removed after finalization/cancellation.

Hold release commits a single utterance. An explicitly started hands-free session
keeps microphone capture active during final transcription and task execution.
It segments speech locally; it never retranscribes the entire rolling recording
as a new command when the user chooses Finish speaking. The implementation uses
an energy endpointer with these current tuning values:

- 16 kHz mono input, 0.012 RMS speech threshold.
- At least 150 ms of speech-level input before a speech-start event.
- 900 ms of silence to commit an utterance.
- A 30-second utterance bound and a 10-minute explicit listening-session bound.

These values are implementation tuning, not proven accuracy or latency claims.
Energy is not a speech classifier. Keyboard noise, quiet voices, Bluetooth and
background speech require microphone qualification. Hold-to-talk remains the
available explicit commitment mechanism in unsuitable acoustic conditions.

Native Nemotron/Parakeet Unified previews and Parakeet tail-window previews use
the shared scheduler and remain display-only. Whisper and Cohere are final-only
in this path. Preview failure or dropped preview samples cannot authorize an
operation or replace the recorded-file final result. Preview sessions drain before
final STT admission so a live preview does not retain the interactive slot.

Accessibility observation is requested concurrently with microphone start. It must not
delay capture behind a window traversal. Rewrite context
is the invocation observation and must still match the current context, target
and selection before generation/application. Observations are not promises that
the user has finished speaking.

## Cancellation, corrections and ownership

Queued typed instructions, confirmations and Continue requests carry revocable
submission identity across snapshot preparation and runner actor hops. Stop,
manual takeover, cancellation or a newer intent invalidates that identity; late
preparation cannot renew execution authority. Cancel also revokes pending speech
so a late final transcript cannot silently restart the cancelled task.

Physical Stop/Escape and manual keyboard, mouse or scroll input outside the Voice
Control panel revoke future effects. Marked synthetic insertion events and the
configured Voice Control shortcut are excluded from manual-takeover detection.
An effect already dispatched may finish; the UI must not claim it was undone.

Speech has an independent synchronous revocation fence. Queued speech-start,
preview and final events carry capture/utterance identity and cannot revive a
stopped turn. After Stop, a hands-free session discards the remainder of the
current utterance and requires silence before another utterance can begin.

| Intent | Required behavior |
| --- | --- |
| Stop / pause | Revoke advancement and pending confirmations; keep an explicitly active hands-free microphone on. |
| Cancel task | Discard the task. It does not implicitly end an active listening session. |
| Stop listening | Revoke advancement and stop/discard microphone capture. |
| End Voice Control | Revoke and drain the task, stop capture, clear active session state and release foreground ownership. |
| Continue / resume | Observe the current state and remaining goal. Never blindly replay an unresolved unknown effect. |
| Confirm / yes / okay | Consume a current, action-bound confirmation; never authorize an unrelated later action. |

Starting speech while awaiting a clarification or confirmation preserves that
pending response. It does not call Stop or take a new observation that would
invalidate the pending snapshot. Listening/transcribing presentation is distinct
from the retained response state. An explicit Stop does invalidate it.

The GUI arbiter admits one owner. Dictation holds its lease through asynchronous
paste completion and its cancellation/Undo window; ordinary success-dwell restart
semantics remain intact. Transforms retain ownership through cancellation cleanup
and clipboard restoration. Voice Control retains ownership until the runner has
drained. Completed/failed/cancelled and paused mic-off tasks release ownership
automatically while their context and result remain visible. Continue, a correction,
or a new command reacquires ownership before work. A retained paused task does not
block ordinary dictation. An active listening session retains ownership; competing
dictation/history actions explain that the microphone must be turned off or the
session ended.

Manual takeover preserves the task and pauses advancement. Continue uses a fresh
observation after the user's edit. Correction phrases such as “Actually London”
and “No, the other one” revise the current task rather than discard the original
goal. Unrelated instructions start a new task; clarification answers retain their
pending response. Ambiguous references require clarification. A replacement
utterance that supersedes unfinished recognition is identified in task activity.

The panel displays the original goal, current instruction, stopping reason and an
expandable activity list bounded to 100 entries. Attempting an action is not a
success receipt. Verified effects, observed transitions and unknown effects remain
distinct. Activity is ephemeral and clears on End; no default audio, screenshot,
full command or UI-text history is persisted or uploaded for diagnostics.

## Decisions, effects and completion

The stable operation vocabulary is `press`, `setValue`, `insertText`, `select`,
`scroll`, `key`, and `activateApp`. A target advertises the subset it supports.
The model may choose only offered IDs and operations. It never returns executable
JavaScript, AppleScript, arbitrary selectors or shell commands.

Snapshots carry observation identity, context identity, target descriptions and
coverage. Execution checks freshness, current application/document context, target
availability and revocable authority. Changing app/window context invalidates
pending target authority. Expired observations require a new decision.

Receipts distinguish a verified requested effect, an observed transition, an
unknown result, and a failed result. An ordinary transition allows a new observation
and decision but is not proof the user's whole goal succeeded. A consequential
action with only transition evidence pauses for manual verification and cannot
be replayed automatically. An AX press error after dispatch is also uncertain. Unknown effects block
blind replay, including through correction and Continue. A verified direct command can report completion without
requiring exhaustive enumeration of the entire window. Semantic goal completion
remains an inference and is labeled accordingly; incomplete observations cannot
prove arbitrary goal completion.

The experimental runner limits each task to 40 dispatched actions, 100 decision
requests, 180 seconds of active execution and repeated unchanged-state guards.
Waiting for human clarification, correction or confirmation does not consume the
active execution budget. Confirmation expires after 20 seconds and remains bound
to its exact action, snapshot and authority.

Confirmation is consequence-based. Ordinary navigation, selection, form edits,
scrolling and search proceed within the requested task. Payment commitments,
destructive actions and external commitments require confirmation; uncertain
consequences ask rather than assume. Generated replacements remain previewed for
confirmation. Clarifying a target is distinct from consequence authorization.
Repeated actions against the same observed state are rejected to avoid duplicate
effects; correcting a goal must not erase unknown-effect or execution history.

The runner keeps bounded in-memory diagnostic records containing task/revision
IDs, stage, operation, outcome, candidate counts and elapsed timing. These records
exclude commands, field values, selected text, screenshots, audio, keys and remote
error bodies. They are distinct from the ephemeral user-visible activity panel.
The experimental panel exposes actual records in an expandable Diagnostics view
with explicit Refresh and Copy diagnostics actions. Copy writes only these
content-minimized records to the local clipboard; it does not save a file or
upload anything. End clears the panel diagnostics.

Supported exact local routes include literal text entry, unambiguous label
selection, offered navigation keys, scrolling, advertised undo and precise
single-occurrence replacement. Literal mode treats utterances as text; isolated
`command mode` exits and `command stop` pauses. `type literally command mode`
enters those words. Prefix handling must preserve the payload rather than
shortening or stripping arbitrary fillers. Selected-text rewriting uses the
explicitly enabled writing provider and previews the generated action for
confirmation.

## Scope and evidence limits

This implementation does not promise arbitrary application support, pixel/OCR
fallback, dragging, a universal reversible undo stack, custom workflow recording,
a wake word, speaker authentication, or universal browser coverage. Native accessibility
coverage varies by application and browser. Model confidence is not calibrated
end-to-end task success. The upstream flight demo's timing is not a MacParakeet
benchmark.

Release qualification must independently demonstrate actual microphone capture,
local STT, native Accessibility target coverage, stop races, speech confirmation,
endpointer behavior, onboarding and signed-app permissions. Fake-adapter tests,
text-only Jev probes and historical browser DOM fixtures do not constitute that full evidence.
The current evidence and remaining gaps belong in the implementation log/PR.

## Stable and non-stable fields

Stable: the consent purposes and versioned preference keys; Keychain scope;
ordinary-dictation separation; raw final transcript authority; capture/utterance
revocation; typed offered-target execution; receipt distinctions; action-bound
confirmation; no blind replay; shared scheduler and GUI ownership semantics.

Non-stable: generated UUIDs, ephemeral paths, exact UI copy, panel placement,
observation traversal order, endpoint tuning and presentation timing. Tuning
changes still need relevant behavioral tests and updated qualification evidence.

## Tests and compatibility

Focused enforcement lives in `VoiceControlSpeechTests`, `VoiceControlCoreTests`,
`DictationFlowCoordinatorTests`, and `TransformRunSerializerTests`, alongside the
native qualification tools. Speech regressions include
raw-final preservation, owned-file cleanup, late noncooperative STT after Stop,
queued-event revocation, hands-free Finish not replaying prior commands, pending
confirmation/clarification surviving listening presentation, literal payload
preservation and the dictation Undo-window lease.

This is an internal app boundary, not a versioned public CLI payload. Additive
fields must preserve existing consumers. Changing consent scope requires a new
consent version and renewed permission. Breaking action, cancellation, persistence
or disclosure semantics requires updating this document and focused tests in the
same PR. No migration may turn ordinary dictation into command execution.
