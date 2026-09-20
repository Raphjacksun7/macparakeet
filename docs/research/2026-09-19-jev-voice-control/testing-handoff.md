# Voice Control: native Google Flights testing handoff

Updated 2026-09-19. This is the handoff for a separate testing agent. **The native Google Flights acceptance flow has not passed yet.** The implementation agent has stopped desktop/model testing so the testing agent can own foreground interaction.

## Start here

Work in `/Users/dmoon/code/macparakeet-jev-voice-control`, branch `feat/jev-voice-control`. At handoff, HEAD is `bd15facc`. There are substantial uncommitted native-only, correction/recovery, diagnostics, tests, and documentation changes after that checkpoint. Test the working tree, record its actual revision and dirty state, and preserve all edits. Do not reset, stash, switch branches, or clean generated/user files to establish a baseline. The primary `/Users/dmoon/code/macparakeet` checkout has unrelated work.

Read these alongside this handoff:

- [Native Accessibility direction](native-accessibility-direction.md)
- [Correction, recovery, and observability direction](correction-recovery-observability-direction.md)
- [Native browser observations](native-browser-qualification.md)
- [Current behavior contract](../../../spec/contracts/voice-control.md)
- [Implementation log](implementation-log.md)
- [Release scope](release-scope.md), whose older capability rows still need reconciliation with the native-only implementation

The product uses native macOS Accessibility for browsers and native apps, without a required extension. Keep the experimental panel, BYO Jev key, and voice-to-Transform integration. Ordinary authorized steps should proceed without repeated confirmation. Payment, destructive operations, and consequential external commitments retain deliberate checks. Manual input pauses automation while preserving the task.

## Concurrent implementation ownership

The implementation agent is finishing the native adapter's actionable static-text label fallback, core clarification/consequential-receipt handling, documentation, and PR preparation. The testing agent owns desktop interaction and qualification artifacts. Report product defects before editing these same source files so changes can be coordinated. The label fallback is now implemented but still needs runtime qualification. The implementation agent owns the final full-suite gate; use focused tests during qualification.

## Acceptance bar

Use the real page: https://www.google.com/travel/flights?gl=US&hl=en-US

Run in a dedicated window of the existing Chrome process using the actual production native adapter, runner, and Jev client. No extension, CDP, DOM injection, browser restart, or alternate automation backend may substitute for the product path. Native tools may inspect the page and establish evidence; distinguish tester intervention from product actions.

1. **Complete search:** “Find one-way flights from Zürich to London on September 20.” At the handoff date this means September 20, 2026; use an explicitly stated future date if testing later. Verify one-way, origin, destination, date, and displayed flight results. Stop at results; do not book or pay. Typing the goal tests the execution loop, not speech capture.
2. **Contextual correction:** Change London to Paris while the task is active, then correct it back. Preserve the original goal and unaffected fields; ensure stale actions do not win. Exercise “the other one” against a genuinely ambiguous set of choices and require a useful clarification when needed.
3. **Manual takeover:** Physically edit a field or interact with the mouse while automation runs. Confirm automation pauses, preserves progress, and Continue observes and respects the new state. Moving to an unrelated window must not allow actions there or silently discard the task.
4. **Stop and recovery:** Stop during model work and during a pending effect. Check that no new effects dispatch afterward, unknown effects are not blindly replayed, and the UI accurately distinguishes stopped, waiting, failed, and completed states.
5. **Ordinary versus consequential actions:** Search, dropdown selection, field editing, and navigation should not repeatedly ask permission. Use a disposable synthetic payment/destructive-action fixture to verify deliberate confirmation, expiry, and uncertain outcomes. Never test a real purchase or real destructive action.
6. **Integrated voice:** Run at least one complete command through the app's actual command microphone/STT path into native execution, then an ordinary dictation and a voice-to-Transform regression smoke. The shared speech infrastructure must not turn command text into normal pasted dictation. A typed harness or file-transcription CLI run does not satisfy this check.
7. **Observability:** Confirm useful panel history and bounded, content-minimized diagnostics, including correction/recovery and failure outcomes. End should clear task data. No keys, raw audio, account labels, or full private page snapshots should enter shared artifacts.

Run several independent attempts, report failures as well as successes, and separate correctness from speed. Record speech-end-to-first-effect, model decision durations, total task duration, website waiting time, and intervention count when measurable. The demo's 7.1 seconds is inspiration, not a measured guarantee for our implementation.

## Known implementation gaps to investigate first

- Real Google Flights' trip selector exposes **pressable AXStaticText** choices with empty labels and useful AXValue strings (`One way`, `Round trip`, `Multi-city`). The adapter needs to expose these values as actionable labels; the existing AXMenuItem fallback alone does not cover them. Ordinary list selection must not be misclassified as a consequential commitment.
- The real initial page has roughly 355 AX nodes and controls at depth 22. Traversal was expanded to depth 32 and a default 600-node bound; verify actual coverage and latency. A truncated observation is not proof that a goal is satisfied.
- Autocomplete selection, calendar interaction, and results verification are not yet proven end to end. Text visible in an input is not necessarily a committed airport/city selection. A generic interface change is not proof of correct search results or a successful consequential action.
- Chrome AX writes can become readable asynchronously. Bounded read-only polling now verifies the original write; never “fix” this by replaying an uncertain write.
- Recent adapter changes add static result text to transition evidence and sanitize known account/profile badges before model context. These changes need verification; they do not constitute general personal-data redaction.
- Synthetic native attempts encountered target clarifications, focus guards, and an unknown search receipt. One displayed synthetic result still had the wrong trip type. No complete native success is claimed.
- Recheck explicit model clarification handling and the behavior after a confirmed consequential action yields only transition evidence. Core fixes were being finalized at handoff; inspect current code and focused tests before assuming they are included or verified.

Coordinate file ownership with the implementation agent before fixing product code. Report exact reproduction, observed AX role/capability, expected outcome, and a minimal proposed fix. Do not broaden the scope into a different browser automation backend.

## Setup and commands

Run commands from the feature worktree. Follow its AGENTS.md. Do not use Orca.

### GUI build

Use the repository build script, which owns macro-validation flags, signing, and safe termination of this worktree's old executable:

```sh
GIT_EXEC_PATH=/opt/homebrew/opt/git/libexec/git-core \
MACPARAKEET_DEBUG_APP_STATE_DIR=/tmp/jev-qualification/app-state \
scripts/dev/run_app.sh --enable-voice-control
```

The previous attempt failed during Xcode package resolution with “Couldn't update repository submodules.” The explicit Homebrew `GIT_EXEC_PATH` above is a proposed retry, **not a verified fix**. Logs: `/tmp/jev-native-app-build.log` and `$TMPDIR/macparakeet-dev-build.log`. Do not restart or replace unrelated app instances. No new integrated GUI/microphone qualification has passed.

Configure BYO Jev through the experimental panel and grant the app's required permissions. Existing credential file: `/Users/dmoon/code/macparakeet/.env.jev.local` (ignored, mode 0600). Never print its contents or put the key in shell arguments, documentation, screenshots, logs, or commits. The app uses Keychain service `com.macparakeet.voice-control.jev`, account `apiKey`. Existing writing-provider consent remains separate.

### Synthetic native harness

The fixture server was left running on `127.0.0.1:56474`, PID `97958`, serving `scripts/dev/voice-control`. Refresh process state before reusing it; do not blindly start a second server or kill an unrelated process.

```sh
python3 scripts/dev/voice-control/run_ax_browser_probe.py \
  --env-file /Users/dmoon/code/macparakeet/.env.jev.local \
  --goal 'Find one way flights from Zürich to London on 20 September.'
```

This script compiles the current production Types, Diagnostics, TurnRunner, CommandRouter, JevDecisionClient, and NativeVoiceControlAdapter, plus the unchanged event-marker enum and `AXBrowserProbe.swift`, into a temporary executable. It securely injects the recognized credential into the child environment. The native fixture must be foreground when execution starts after compilation.

**This harness is guarded to the synthetic loopback fixture only. There is no real Google Flights harness yet.** Do not simply relax its URL/title checks: it logs full synthetic snapshot context, which is inappropriate for a real account-bearing page. Build a narrow Google Flights guard and content-minimized evidence path first, or qualify through the actual app with suitable evidence capture.

Other tools: `AXBrowserInspection.swift`, `flight-fixture.html`, and `QualificationApp.swift` in the same directory. Temporary read-only Google inspection source is `/tmp/AXFlightsInspection.swift`; inspect it before use. Its `AX_BROWSER_OPEN_TRIP=1` option performs an actual press and should not be set casually.

### Desktop state left for the testing agent

These IDs are historical observations and must be refreshed before acting:

| Window | Last observed state |
|---|---|
| Chrome `1864301181` | Real Google Flights, single tab at the acceptance URL; trip-type selector left open |
| Chrome `1864301179` | Synthetic flight fixture, `http://127.0.0.1:56474/flight-fixture.html`; last observed foreground |

No browser profile, extension installation, or user data was deleted. Preserve unrelated tabs/windows and stable app instances. Only one agent should own foreground desktop interaction at a time.

## Latest implementation checkpoint

The independent implementation fixes passed **122 focused tests, zero failures**, at 18:49 local on September 19 (`/tmp/jev-pr-focused-tests.log`). This supersedes the older 107-test result below for the tested source. Includes pressable static-text naming, uncertain AX press errors, deletion-key policy, explicit clarification, consequential transition pause, correction precedence, and queued submission fencing. Real-site and integrated voice evidence remains pending. Refresh git state before testing; the implementation agent is committing this checkpoint and preparing the PR gate.

## Verification evidence and limits

- Latest completed focused command: `swift test --filter 'VoiceControl|DictationFlowCoordinator|TransformRunSerializer'` — **107 tests passed**, September 19 at 18:32:44 local. Log: `/tmp/jev-native-direction-tests.log`.
- That pass predates subsequent native adapter and possible final core edits. It is **not an exact-current-tree pass**. Re-run focused tests after fixes settle.
- The full Swift suite has **not** been run for this task. Coordinate the single final full-suite run with the implementation/release gate owner; do not run it on every testing iteration.
- Earlier native fixture field writes and live Jev decisions worked. They establish partial feasibility, not the real Google Flights or voice acceptance criteria.
- `output/voice-control/native-browser-runtime{,-2,-3,-4}.txt` contains ignored partial synthetic attempt evidence. Review before sharing.
- `demo/browser-proof.mp4`, its screenshot, and `browser-evidence.json` document the **historical extension fixture**. They are not native browser proof, real Google Flights proof, or speech proof.
- Prior Fable reviews informed implementation, but no settled native-only final review is complete. Greptile failed authentication. no-mistakes was initialized; its final gate, remote CI, and a PR are still outstanding.
- A prior file-transcription smoke accidentally wrote one synthetic history item, ID `14BA4552-7D80-4143-A413-6F8B9E3EAA5C`. It was left intact. Use isolated app state or the CLI's `--no-history` option for future file tests; do not delete user library records.

## Deliverables from the testing agent

Write a local qualification report beside this file containing exact source revision/dirty state, app build identity, environment, test commands, each attempt's outcome, interventions, timings, failures, and artifact paths. Clearly distinguish typed harness, integrated voice, fixture, and real-site evidence.

If possible, record a real-time native Google Flights demo including the utterance, visible progress, and verified results. Also capture correction/manual takeover. Scope the recording to the dedicated window/panel, exclude credentials and account details, and preserve waits and failures in the evidence. A polished edited clip may accompany, but must not replace, the unedited qualification evidence.

## Work remaining beyond testing

1. Finish the real-page AX gaps and any correction/recovery/consequence defects found during qualification.
2. Verify the integrated app path and regressions: dictation, Transform, microphone arbitration, manual takeover, stale callbacks, cancellation, and rich-text editing safety.
3. Reconcile the implementation log, release capability matrix, contract, plan, and walkthrough with what actually ships. Preserve historical extension evidence with explicit labeling.
4. Review the settled native-only changes independently, resolve findings, run focused checks and the coordinated final gate, then commit meaningful verified checkpoints.
5. Prepare and push a high-quality PR with honest scope, validation, limitations, and native demo evidence; pass remote checks. No PR has been opened or pushed at this handoff. Merge and stable release are separate from implementation and qualification.

The core feature is substantial and implemented in the working tree; it is not yet a qualified full release. The immediate blocker is completing and demonstrating the actual native Google Flights loop, followed by integrated speech qualification and final review.

### PR validation isolation (18:50 local)

Implementation checkpoint `b6aabd10` passed 122 focused tests. PR validation is running from `/Users/dmoon/code/macparakeet-jev-pr`, branch `feat/jev-native-voice-control`, based on that checkpoint. The testing checkout remains `feat/jev-voice-control`; its newly added `AXFlightsProbe.swift` and `run_ax_flights_probe.py` were deliberately left uncommitted for the testing agent. Do not assume the PR validation checkout includes later qualification fixes. Send those fixes/evidence back for explicit integration after the gate; do not rebase or reset the testing checkout to follow the gate.

### Local implementation status

See [implementation-status.md](implementation-status.md) for the complete 19:13 PDT checkpoint, review fixes, active gate/run identity, separate branch ownership, verification limits, and ordered integration steps. Refresh the active gate status: it may advance after this document snapshot.
