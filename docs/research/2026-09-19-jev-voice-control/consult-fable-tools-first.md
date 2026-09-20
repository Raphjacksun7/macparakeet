# Independent Fable consult — tools-first macOS computer control

Requested `claude-fable-5-1`, effort **medium**, through `claude -p` on 2026-09-20. Critique of treating native Accessibility operations as host tools, with Jev as chooser rather than default brain or extra safety veto. Not runtime evidence.

## Parent dispositions

**Adopted:** tools-first; bare unique labels on `.plain` only; reserved keys are keys (`press return` clarifies if nothing focused); skip-type uses original payload and does not skip a non-empty selection; click unique-prefix after exact miss; Return/Enter keys are ordinary; numbered picks rematch by id+label; confirmation reobserves after `observationExpired`.

**Refused:** Jev as a second “are you sure?” on ordinary tools; widening confirmation.

**Later:** spoken-tool presses completing on `.unknown` (needs a compilation origin flag); caret-aware join-space; File > Export menu paths; on-screen overlays.

---

# Tools-first native AX control for Voice Control: design critique

## 1. Verdict: adopt tools-first, with two amendments

Adopt. The runner is already a compiled tool executor: press, setValue, insertText, key, scroll, activateApp, each with its own receipt logic in `NativeVoiceControlAdapter.execute`. Jev never touches a handle. The write-up drifted Jev-shaped because the router's last line is an unconstrained fallback, not because Jev does the work. Make the fallthrough the exception and the report will match the code.

Amendments:

- **Legality applies to model-chosen actions, not to user-named tools.** `offeredKeys` and `offeredTargets` exist to stop Jev pressing Return under an open picker. A user who says `press return` has stated intent. Keep that local and unconditional, as the PR draft already admits it is.
- **Explicit tool presses should not pause on `.unknown`.** Today a generic button press with no transition evidence returns `.unknown`, and `perform` pauses with "could not be verified". For `click Save` or bare `Save`, the user asked for a press, not an outcome. Report "Pressed Save" with dispatch status and end the task. Reserve the pause for model-chosen or plan-driven presses. This needs a decision-origin flag on the action, which is cheap.

## 2. Traps in the five parent upgrades

**Bare unique label (1).** Three traps.

- Exact, whole-string, case-insensitive equality only. No prefix match for bare labels. Otherwise bare `London` under a `suggestionPicker` matches both London rows and produces a numbered pick, stealing the landing Choice that `competingLandings` is built to hand to Jev. Place the bare-label branch after the flight plan and web query branches and skip it entirely when the situation is not `.plain`.
- Strip a fixed article and role vocabulary (`the`, `button`, `link`, `tab`) before matching, so `the Save button` and `Save` are one command. Do not fuzzy-match beyond that.
- Exclude `role == "url"` and `role == "application"` targets, as the click branch already does. Bare `Google Flights` should reach the destination logic, not press a synthetic url row.

**Reserved keys are keys (2).** The real trap is in `VoiceControlConsequencePolicy`. Return and Enter resolve to `.unknown` unless the focused field's label contains "search", and `.unknown` triggers the "I can't tell what X does. Press it anyway?" prompt. That is exactly the second "are you sure" the brief forbids. Make explicit return/enter `.ordinary`. Delete and Backspace already stay destructive outside a focused text field, which matches the confirm set. Second trap: when nothing focused offers `.key`, `press return` falls through to unconstrained Jev. Return a local clarify instead: "Nothing is focused to receive that key."

**Skip type (3).** The join-space code prepends a space when the field's last character is not whitespace. A naive equality check will therefore never fire on a repeat, because the payload is now ` hello`. Compare the trimmed payload against `value.hasSuffix(trimmedPayload)`. Do not skip when `selectedText` is non-empty, because insertText replaces the selection and that is a different request. `.information` is the right return. `.directCompleted` requires a verified history entry, which a fresh submission does not have.

**Click prefix match (4).** Only when exact matches are zero. Require a word boundary, so `click Send` cannot match `Sender`. Multiple prefix matches go to the same numbered pick. The consequence policy already catches `Send feedback` and similar, so the safety story is unchanged.

**Jev is not a sensitivity guard (5).** Correct, and the code agrees: `consequence(of:)` ignores model-supplied `.ordinary` when local words say pay, delete, or send. Nothing to add beyond the return/enter fix above.

## 3. What Jev should still do

- **Outcome Choice among competing landings** when `competingLandings` returns more than one row. This is the Zürich versus Zurich, Ontario case and it is the strongest use of Jev in the codebase.
- **Legality-filtered leftover on generic pages** when no local tool matches and the goal is longer than a label. Keep it, keep it documented, and keep keys out of it.
- Nothing else. No ranking of numbered picks, no "is this goal complete", no payload extraction.

## 4. What must stay later

On-screen numbered overlays, TTS, menus as paths such as `File > Export`, Rango-style container-scoped scrolling and `again`, mark and reference targets, `fill_form` batching for multi-field forms, and any coordinate-click fallback for AX-dead elements. None of these change the tools-first verdict. Each adds a new observation or effect surface with its own verification story.

## 5. Fresh-eye silences worth fixing now

- **Numbered pick binds by snapshot-local ID without a label check.** `resolvedPick` presses whatever target now carries the stored `n:<index>` id. IDs are reassigned on every observe in traversal order. A Chromium tree rebuild between the prompt and the answer can press a different control. Store the raw label and role alongside the id and require both to match before pressing. Cheap.
- **Confirmation can outlive the observation window.** `execute` rejects snapshots older than 20 seconds. `confirm` performs against `pending.snapshot`, so a slow "yes" produces `observationExpired` and a failed task rather than a re-observe and rebind. Route that error through the same stale-reobserve path `run` already uses.
- **Router and runner compare labels differently.** The router uses `caseInsensitiveCompare`, `bind` uses `localizedStandardCompare`. A label that matches in one and not the other yields "The requested control is no longer available" for a control that is visibly present. Pick one.
- **`open X` is ambiguous between control and app.** The click branch runs before `requestedApplication`, so `open Settings` presses a Settings button when one exists. Acceptable, but say so in help copy.
- **Join-space assumes the caret is at the end.** It reads `value.last`, but insertText replaces `selectedRange`, which may sit mid-text. Not cheap to fix without caret position in the snapshot. Flag it, do not fix this pass.