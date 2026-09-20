# Voice Control boundary contract

Status: implemented behind the disabled-by-default Voice Control feature gate;
release and device qualification remain separate from source/test evidence.

## Purpose

Voice Control turns an explicitly supplied instruction into bounded interaction
with the current native app or an explicitly authorized browser tab. Ordinary
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
- `NativeVoiceControlAdapter` and the optional `VoiceControlBrowserMultiplexer`
  observe controls and execute the supported typed operations.
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

Browser setup is available in the native setup panel: reveal the bundled extension,
choose a supported Chromium browser, enter its extension ID, and register the
bundled native host. Replacing another pairing requires the explicit replacement
checkbox. Registration first ends/drains the active bridge and preserves foreign
registrations. The extension still requires the browser's own unpacked-extension
installation flow and explicit Connect this tab authorization. Start browser
connection opens the local bridge without opening the microphone or acquiring GUI
mutation ownership. An idle bridge may remain available across completed tasks;
explicit End, disable, or shutdown closes it. `voiceControl.browserBridgeEnabled.v1`
controls whether new sessions start that optional bridge. No personal browser is
restarted with debugging flags.

Audio stays on the Mac. Jev is text-only and receives no audio. Native observation
excludes configured password-manager apps and recognized secret fields. The
browser adapter excludes secret/payment fields using its own document rules.
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

AX/DOM observation is requested concurrently with microphone start. It must not
delay capture behind a window traversal or browser connection. Rewrite context
is the invocation observation and must still match the current context, target
and selection before generation/application. Observations are not promises that
the user has finished speaking.

## Cancellation, corrections and ownership

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
| End Voice Control | Revoke and drain the task, stop capture/bridge, clear active session state and release foreground ownership. |
| Resume | Continue only when the runner has no unresolved unknown effect. |
| Confirm | Consume a current, action-bound confirmation; never authorize an unrelated later action. |

Starting speech while awaiting a clarification or confirmation preserves that
pending response. It does not call Stop or take a new observation that would
invalidate the pending snapshot. Listening/transcribing presentation is distinct
from the retained response state. An explicit Stop does invalidate it.

The GUI arbiter admits one owner. Dictation holds its lease through asynchronous
paste completion and its cancellation/Undo window; ordinary success-dwell restart
semantics remain intact. Transforms retain ownership through cancellation cleanup
and clipboard restoration. Voice Control retains ownership until the runner has
drained. Completed/failed/cancelled mic-off tasks release ownership automatically
while their result can remain visible. Paused tasks retain their resumable state;
a competing dictation/history action surfaces a message explaining how to end
Voice Control rather than silently appearing broken.

## Decisions, effects and completion

The stable operation vocabulary is `press`, `setValue`, `insertText`, `select`,
`scroll`, `key`, and `activateApp`. A target advertises the subset it supports.
The model may choose only offered IDs and operations. It never returns executable
JavaScript, AppleScript, arbitrary selectors or shell commands.

Snapshots carry observation identity, context identity, target descriptions and
coverage. Execution checks freshness, current application/document context, target
availability and revocable authority. Browser authorization is explicit; once a
browser session is selected, losing it must not silently reroute an effect to a
native application. Expired observations require a new decision.

Receipts distinguish a verified requested effect, an observed transition, an
unknown result, and a failed result. A transition allows a new observation and
decision but is not proof the user's whole goal succeeded. Unknown effects block
blind replay and Resume. A verified direct command can report completion without
requiring exhaustive enumeration of the entire window. Semantic goal completion
remains an inference and is labeled accordingly; incomplete observations cannot
prove arbitrary goal completion.

The runner limits each task to 12 dispatched actions, 30 decision requests,
60 seconds and two repeated unchanged observations. Confirmation expires after
20 seconds and remains bound to its exact action, snapshot and authority. Presses
that are not adapter-proven navigation, generated replacements, and key actions
require confirmation in the current conservative policy. Clarifying a target is
not consequence authorization. Repeated actions against the same observed state
are rejected to avoid unintended duplicate effects.

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
a wake word, speaker authentication, or a Safari extension. Native accessibility
coverage varies by application. Browser extension installation/pairing and browser
version behavior require their own qualification. Model confidence is not calibrated
end-to-end task success. The upstream flight demo's timing is not a MacParakeet
benchmark.

Release qualification must independently demonstrate actual microphone capture,
local STT, native/browser target coverage, stop races, speech confirmation,
endpointer behavior, onboarding and signed-app permissions. Fake-adapter tests,
text-only Jev probes and browser DOM fixtures do not constitute that full evidence.
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
browser fixture checks and native qualification tools. Speech regressions include
raw-final preservation, owned-file cleanup, late noncooperative STT after Stop,
queued-event revocation, hands-free Finish not replaying prior commands, pending
confirmation/clarification surviving listening presentation, literal payload
preservation and the dictation Undo-window lease.

This is an internal app boundary, not a versioned public CLI payload. Additive
fields must preserve existing consumers. Changing consent scope requires a new
consent version and renewed permission. Breaking action, cancellation, persistence
or disclosure semantics requires updating this document and focused tests in the
same PR. No migration may turn ordinary dictation into command execution.
