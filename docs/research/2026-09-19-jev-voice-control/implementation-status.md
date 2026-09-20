# Native Voice Control implementation checkpoint

Recorded September 19, 2026, 19:13 PDT. This is a local continuation record, not a claim of completed validation, an opened PR, or a stable release. The user requested local documentation now and a PR when the work is ready.

## Current verdict

The native-only feature and initial hardening are committed as `b6aabd10`. **122 focused tests passed** before the isolated PR gate's follow-up policy changes. Real Google Flights end-to-end completion, integrated microphone qualification, and a native demo remain pending in the recorded evidence. No PR or push has completed as of this checkpoint.

## Two worktrees with separate owners

| Checkout | Branch | Responsibility / observed state |
| --- | --- | --- |
| `/Users/dmoon/code/macparakeet-jev-voice-control` | `feat/jev-voice-control` | Testing and original implementation checkout, code checkpoint `b6aabd10`; separate testing agent owns desktop interaction and Google Flights harness work. |
| `/Users/dmoon/code/macparakeet-jev-pr` | `feat/jev-native-voice-control` | PR validation submitted from `b6aabd10`; pipeline owns the branch until validation finishes. Do not edit, reset, rebase, or cherry-pick into it during the active run. |

The testing agent's `scripts/dev/voice-control/AXFlightsProbe.swift` and `run_ax_flights_probe.py` were untracked at the snapshot and intentionally excluded from our checkpoint. They remain on disk. Their presence does not prove a successful run. Preserve their ongoing work; do not use broad staging or cleanup commands.

The primary `/Users/dmoon/code/macparakeet` checkout contains unrelated work and is not the target of this task.

## Committed implementation

- Native Accessibility is the production execution path for native apps and existing browsers. The extension/native-host experiment is retired from package targets and packaging, with historical evidence preserved separately.
- Dedicated command capture uses the existing microphone stream and STT scheduler while bypassing ordinary dictation formatting, history and insertion. Experimental panel, BYO Jev Keychain setup and separately consented selected-text writing remain.
- Task corrections retain the original goal and receipts; “other one” uses recent alternatives and asks when ambiguous. Manual input pauses and preserves the task. Paused mic-off tasks release GUI admission after work drains; Continue reacquires ownership and observes user changes.
- Ordinary task steps avoid blanket confirmation. Consequential and unknown actions require action-bound checks. Finite limits are 40 effects, 100 decisions, 180 active seconds, excluding human waits; confirmation expires after 20 seconds.
- Activity is bounded and ephemeral. The 256-record diagnostic trace excludes commands, field text, audio, screenshots and credentials. Copy diagnostics is explicit and local.
- Native observation reaches deeper browser controls with bounded traversal. Actionable static-text choices use their AXValue name. Known account/profile badges are minimized; this is not universal personal-data redaction.
- Text writes use bounded read-only verification without write retries; rich text requires selection insertion rather than whole-value replacement. AX press errors are uncertain because the action may already have occurred.

## Review fixes included in b6aabd10

| Finding | Resolution |
| --- | --- |
| Typed command awaiting a snapshot could revive after Stop/manual takeover | Revocable submission identity checked across snapshot waits and runner ingress; queued control actions share the same fence. |
| Cancel could allow a pending speech result to start a new task | Synchronous speech revocation, pending utterance discard, and guarded queued cancel. |
| Delete/Backspace could act destructively on a selected non-text item without confirmation | Ordinary only for focused targets supporting text insertion; model ordinary cannot override non-text deletion classification. |
| AXPress errors could permit replay after an uncertain effect | Return unknown after dispatch errors; retain uncertain-effect non-replay. |
| Stored manual values could override a later spoken correction | Explicit revision supersedes older manual overrides; regression exercises Paris then London. |
| Consequential action could continue after only generic interface change | Pause and block replay when a consequential action has only transition evidence. |
| Explicit Jev clarify looked like an ambiguous target | Dedicated clarification handling asks for next-step/outcome detail. |
| Paused tasks released admission and missed later manual edits | Retained paused tasks record manual-input evidence without acquiring a lease or interfering with normal input. |
| Cancelled UI retained the old goal | Cancel clears goal/activity and pending response state. |

## Active validation run — not yet finished

Run ID: `01M2Y8417KV5WDC7ANVQ2BRGPV`.

Observed at 19:12–19:13 PDT: intent and rebase complete; review in its first fix/review round; full test, document, lint, push, PR and CI stages still pending. Pipeline-reported head is `2539da9f79d0f9fa0a60ae5428c31c5a1aeda762`. The local PR checkout remains on `b6aabd10` until the tool offers synchronization. The pipeline commit is not yet locally inspected or claimed as tested.

The pipeline is still running in the background and was **not aborted** when the user requested documentation. The driver was given `--yes` under the existing autonomous completion authorization, so it may advance through validation, push and draft-PR creation after this snapshot. Refresh its state before making any claims or changes. No merge or release is authorized as part of this run.

Review findings and dispositions:

1. `dictation-mutex-regression`: preserve the intentionally shared foreground mutation arbiter; check that competing dictation reports a visible busy state without breaking ordinary dictation. The fix agent reports adding regression coverage rather than removing coordination.
2. `consequence-model-trust-bypass`: accepted for hardening. An opaque generic button must not be ordinary solely because the model says so. Preserve established ordinary search/navigation/field/selector actions; recognize final commitment phrases and require deliberate checks. Follow-up code and tests are under gate review; do not yet describe them as passing.
3. `real-desktop-interaction-during-implementation`: temporal misunderstanding. Earlier real desktop inspection was explicitly authorized. The no-desktop instruction applies to this validation run after the separate testing handoff. Preserve historical evidence and clarify scope rather than deleting observations or inventing proof.

The gate also received instructions to add a superseding current-state note to the research README, whose original proposal-only status is stale. The exact submitted [validation intent](validation-intent.txt) is saved locally. [PR description draft](pr-description-draft.md) is ready for revision with final results; its links are written for the eventual repository-root GitHub description.

### Resume safely

From `/Users/dmoon/code/macparakeet-jev-pr`:

```sh
/Users/dmoon/.local/bin/no-mistakes axi status
/Users/dmoon/.local/bin/no-mistakes axi logs --step review --full
```

Run commands according to the tool's returned next action. While pipeline-owned, do not independently edit its source or bypass it with a direct push. Do not start a duplicate run. If a gate is awaiting a decision, inspect findings and preserve the user's chosen native-only behavior. After a terminal or successful result, use the offered guarded synchronization/recovery command before follow-up work; preserve all pipeline commits.

The active driver log is `/tmp/jev-pr-gate-fix.log`; initial run log `/tmp/jev-pr-gate.log`. These temporary logs are useful diagnostics, not the durable source of truth. This document preserves the important facts and decisions independently of them.

## Verification ledger

- `swift test --filter 'VoiceControl|DictationFlowCoordinator|TransformRunSerializer'`: **122 tests, zero failures**, 18:49:16 PDT. Log `/tmp/jev-pr-focused-tests.log`. This was before the pipeline follow-up changes.
- `git diff --check`, shell syntax checks for development/distribution scripts, and synthetic Python harness compilation passed at the implementation checkpoint.
- Full Swift suite: not yet run by the final gate at this snapshot. Reserve at most one full run for this task; use focused checks for later corrections.
- Local Greptile attempted against committed branch and failed authentication: `not signed in. Set GREPTILE_API_KEY or run greptile login --api-key`. This is unavailable review evidence, not approval. Log `/tmp/jev-pr-greptile.log`.
- Initial native GUI build failed Xcode package resolution. The documented Homebrew `GIT_EXEC_PATH` retry remains a proposed fix until the testing agent records a successful build.
- Native synthetic field edits/live Jev and historical extension fixture evidence are recorded separately. Neither proves the real Google Flights or integrated speech acceptance flow.

## Remaining work and integration order

1. Let the active gate finish review/fixes and validation; inspect the resulting commits and actual test evidence. Resolve concrete findings without weakening the accepted product direction.
2. Testing agent completes real Google Flights, correction/manual takeover/Stop, consequential-action fixture checks, integrated speech and dictation/Transform regression qualification. Preserve failed attempts and intervention counts, not only a polished clip.
3. Compare the testing checkout's later fixes with the pipeline's final tree. Explicitly integrate them into the PR branch without losing either side's changes; rerun affected focused tests. Runtime evidence must identify which revision it exercised.
4. Refresh the capability matrix, contract, implementation log, handoff and PR description with final outcomes. Local documentation made after the PR branch split also needs deliberate integration.
5. Open/update the draft PR when validation is ready, attach/link actual native evidence, and inspect remote CI/review. Keep the feature disabled by default. Merge and stable distribution are separate decisions.

Broader proposed routes remain unimplemented: numbered target overlays, richer range/spelling editing, general inverses/redo/repeat, dedicated window/tab/system controls, explicit cross-app content workflows, and optional OCR/grid fallback. Do not label this checkpoint the complete full feature set.

## Local document map

- [Testing handoff](testing-handoff.md): setup, scenarios, desktop ownership, known AX gaps and required evidence.
- [Native observations](native-browser-qualification.md): actual browser/fixture observations and their limits.
- [Implementation log](implementation-log.md): chronological checkpoints and test evidence.
- [Capability matrix](release-scope.md): implemented scope versus broader plan.
- [Native direction](native-accessibility-direction.md) and [correction/recovery direction](correction-recovery-observability-direction.md): user decisions.
- [Behavior contract](../../../spec/contracts/voice-control.md): current product boundary.
- [HTML walkthrough](walkthrough.html): visual feature explanation, including proposed work.
- [PR draft](pr-description-draft.md) and [validation intent](validation-intent.txt): continuation artifacts.
