# Historical extension implementation and qualification evidence

**Superseded product direction:** this report qualifies the retired extension experiment. Current browser control uses native macOS Accessibility; this recording is not native-path evidence. See [native-accessibility-direction.md](native-accessibility-direction.md).

Date: 2026-09-19. This records source and runtime evidence, not a release claim.

## Implemented path

The Chromium MV3 extension uses an isolated content script and a service worker. The worker binds an explicitly chosen profile/window/tab/document. Chrome launches `macparakeet-browser-host`, which authenticates its allowed extension origin and connects through a private Unix socket to `VoiceControlBrowserAdapter`. The adapter uses the same `VoiceControlAdapter`, typed actions, revocable authority, Jev client, and goal runner as native control.

Same-origin navigation invalidates observations and rebinds the new document. Cross-origin navigation or choosing another tab revokes browser authorization. The native multiplexer never silently redirects a browser task into a different app after losing authorization.

A bounded local postcondition distinguishes verified field/selection/scroll changes, observed interface transitions (new controls, expanded menus, dialogs, status regions, or same-origin navigation), and unknown effects. An interface transition is evidence for a new observation, not proof of send/purchase/task success. The runner records dispatched history and rejects blind repeated effects.

Fable review fixes applied here:

- Private stale socket recovery requires an exclusive bridge lock, `ECONNREFUSED`, same UID, socket type, mode 0600, and unchanged device/inode. It preserves live listeners, symlinks, and regular files.
- Scroll respects the bound direction argument rather than inferring direction from the selected candidate ID.
- Payment `autocomplete=cc-*` fields join password, one-time-code, file, hidden, and explicitly private fields in pre-read exclusion.
- Predispatch cancellation propagates as cancellation. After dispatch, interruption/missing receipt remains unknown and is never silently replayed.
- Truncated selected text is omitted entirely to avoid replacing a larger original selection with a rewrite of only its prefix. Full local values participate in stale guards; only bounded values reach Jev.

## Real browser goal proof

The recorded run used:

- A real headless Chrome for Testing process and a fresh disposable browser profile.
- The real extension background/content code, native-messaging host executable, authenticated Unix socket, and exact production Swift adapter/runner/Jev source.
- A live request to Jev `jev-1.13.0`, using the locally supplied credential without putting it in source, command arguments, extension storage, recordings, or logs.
- A synthetic local flight-search page. It contains ordinary form inputs, an initially hidden date-picker dialog, dynamically available date controls, and a result status. No real accounts, transactions, or flight websites were accessed.
- An explicit same-origin page navigation before the goal. The harness confirmed fresh document binding and rejection of a stale pre-navigation action.

The instruction was: `Find one way flights from Zürich to London on 20 September.`

The model chose these steps from current observations: select One way; fill Zürich; fill London; open the date picker; choose 20 September; search. The final DOM assertion required all four goal values in the result, independently of the runner's completion event.

Recorded goal duration: **1,549 ms**, from goal submission after fixture setup to the runner completion event. Seven Jev decisions took **270, 194, 212, 251, 158, 162, 152 ms** (median **194 ms**). The unedited recording is **8.04 seconds**, including setup/navigation, a deliberate two-second presentation hold before the measured goal, and a final result hold. MP4 is a real-time transcode of the WebM; no action timings were altered.

A small [MP4 recording](demo/browser-proof.mp4), [final screenshot](demo/browser-proof.png), and [sanitized evidence manifest](demo/browser-evidence.json) are committed for review. The source artifacts remain local:

- `output/voice-control/browser-proof.mp4`
- `output/voice-control/browser-proof.webm`
- `output/voice-control/browser-proof.png`
- `output/voice-control/browser-evidence.json`
- `output/voice-control/browser-runtime.txt`

### Exact limits of this proof

This input was **typed**, not spoken. No microphone/STT latency or speech accuracy is included. The fixture harness automatically acknowledged only three explicitly allowlisted synthetic button confirmations; it does not demonstrate human confirmation UX or authorize actions on other websites.

Headless programmatic opening of the popup does not confer Chrome's real user-gesture `activeTab` permission. The disposable test copy of the manifest therefore grants **only `http://127.0.0.1/*`**. Production manifest permissions remain `activeTab`, `scripting`, `nativeMessaging`, and `storage`; the production setup's actual toolbar user-gesture permission grant still needs physical qualification.

Three evolving-fixture runs completed the goal. Two recording-development runs safely paused after the first step because model operation/target confidence did not meet the existing threshold. Their failure recordings/artifacts were preserved in temporary fixture directories. This is not a fixed-workload reliability sample or a claim of universal subsecond performance. The observed confidence pauses must inform further classifier/clarification qualification; a successful recording does not erase them.

## Focused checks

The real-DOM Playwright script passes secure-value exclusion, exact fill, consume-once replay rejection, stale value, select option, removed target, occlusion, deadline, document identity, dynamic menu transition, long-selection omission, secure-value getter exclusion, payment exclusion, and scroll-argument direction assertions.

Installer checks verified mode 0600, exact extension-origin allowlist, custom disposable profile registration, and preservation of existing pairing. Swift framing/socket tests cover frame boundaries, oversized messages, partial EOF, owned stale socket recovery, and preservation of live sockets/regular files; integrated test results are owned by the parent qualification log.

## Reproduction

See `integrations/voice-control-browser/README.md` for setup and limits. `tests/BrowserQualification.swift` is compiled alongside the exact production Types, JevDecisionClient, VoiceControlTurnRunner, BrowserWire, and BrowserAdapter files, without substituting a fake adapter or model. The live test accepts explicit environment opt-in, a harness path, the built host path, and a Jev credential through environment injection. It refuses to overwrite an existing user pairing and cleans up only configuration/socket files proven to belong to that invocation.

The stable production distribution work remains distinct: extension-store publication/stable ID, signed native-host embedding, installation/onboarding across browser channels, and real-site compatibility qualification are not proven by this development harness.
