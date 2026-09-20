# Independent Fable consult — Jarvis-family + numbered picks

Requested `claude-fable-5-1`, effort **low**, through `claude -p` on 2026-09-20. Critique of [jarvis-family-primitives.md](jarvis-family-primitives.md) and the numbered-pick implementation. Not runtime evidence.

## Parent dispositions

**Adopted:** trailing `one` is not stripped when it is the index (`number one`, `one please`); stale pick IDs re-prompt instead of calling Jev; pick order is snapshot order; trace outcome is `numbered_pick`. Panel list is not claimed as Apple “show numbers” overlay.

**Refused:** label fallback once a target ID exists.

---

# Fable review: Jarvis-family extraction + numbered picks

**Scope:** read the primitives note and the five Swift surfaces named in the brief. I did not open the Jarvis/OpenJarvis checkouts and did not run tests, so claims about the upstream repos are taken as stated.

## 1. Verdict on the extraction

**Faithful in shape.** The refuse list (wake words, cloud STT, keyword soup, delay-as-confirmation, substring `yes`) matches what the settled rules already forbid, and each adopted primitive maps to a real symbol in the tree. The "one idea" paragraph is honest that Jarvis demos are mostly negative examples.

**Material misses:**

- **Two grammars for "the other one."** `revise` recognizes it via a hard-coded list of normalized strings (`VoiceControlTurnRunner.swift:121`); `VoiceControlSpokenPick` separately guarantees it is not index 1. The note presents one primitive. They should share a normalizer, or the doc should say why they differ.
- **Apple Voice Control and Rango are cited as precedent, but both number *on-screen overlays*.** What shipped is a numbered *text list in the panel*. That is a different affordance, and the note should not imply parity.
- **"Shipped this pass" claims 127 tests green.** Not verified here. Fine as a status line, but the doc reads as if the mic path exercised the pick; section 6 admits it did not.

## 2. Numbered-pick invariants

| Invariant | Holds? | Evidence |
|---|---|---|
| Isolated index | Mostly | `index(in:count:)` strips `the/number/option` prefixes and `one/please` suffixes, then requires exactly one token. `the other one` → `other` → nil. |
| IDs, not labels | Yes | `clarify` stores both, `resolvedPick` and `alternativeDecision` resolve by `chosenTargetID` first; label is fallback only. |
| `the other one` is not 1 | Yes | Confirmed by trace above; also `revise` routes it to `otherRequested` before `clarify` ever sees it. |
| Pay/delete/send still confirm | Yes | `resolvedPick` returns a bare `.action`; the run loop recomputes consequence via `VoiceControlConsequencePolicy` at line 471 and offers confirmation. A pick never carries authority. |

## 3. Traps

- **Suffix stripping eats the index.** `number one`, `option one`, and `one please` all reduce to an empty token list and return nil, while `number two` works. The trailing-`one` strip must not fire when `one` is the only remaining token.
- **Stale pick escalates to Jev with a bare digit.** If the chosen target ID is gone from the next snapshot, `resolvedPick` returns nil and the loop falls through to a model call with amendment `User clarification: 2`. The model sees "2" with no list. Should re-prompt or say alternatives are no longer current, as `alternativeDecision` already does for the 30-second case.
- **Display labels poison the label fallback.** The router passes `displayLabels` (e.g. `Save (1)`, `Save (button)`) as `labels`. If IDs were ever absent, `chosenAlternative = "Save (1)"` matches nothing. The fallback is dead code today; either drop it or pass raw labels alongside.
- **No cap symmetry.** Router emits `.pick` for 2 to 6 matches; `alternativeDecision` sorts labels alphabetically and takes 6, so pick order can differ from screen order. Users will read top-to-bottom.
- **Non-pick answers while a pick is pending** re-prompt silently and return before `record`. Diagnostics lose the miss.
- **Trace outcome for a pick is `clarification_needed` with a detail string.** Dashboards filtering on outcome cannot separate free-text clarify from numbered pick.

## 4. Adopt / refuse / later

**Adopt now:**
- Fix the `one`-suffix strip so `number one` and `one please` resolve.
- On stale pick ID, re-issue the prompt from the current snapshot instead of calling Jev.
- Record a distinct trace outcome (`numbered_pick`) rather than a detail string.
- Preserve snapshot order in `alternativeDecision` picks.

**Refuse:**
- Any label-based resolution once IDs exist; delete the fallback branch.
- Widening accept tokens beyond `yes / confirm / confirm this action`.

**Later (matches the note's section 5):**
- Spoken confirmation via `AVSpeechSynthesizer`.
- Distinct live-mic copy for "heard nothing" vs "no match."
- Unifying the `revise` phrase list and `VoiceControlSessionGrammar` under one normalizer.

Per the brief, no CDP, wake-word, or overlay proposals in this pass.
