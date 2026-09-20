# Predict outcomes, not steps

**Date:** 2026-09-20. **Status:** adopted with amendments in the DEBUG experiment. Not a claim that live Flights results have passed.

Source: a practitioner note on using TypeSafe Jev (Tetris: ask where the piece lands, not which button to press). Independent review: [Fable 5.1 medium](consult-fable-jev-outcome-choice.md). This sits under [jev-decision-architecture.md](jev-decision-architecture.md).

## Verdict

The note is **TypeSafe-true and useful**. Jev is a judge of a closed option map. It is weak at simulating a multi-step transition function. Asking it to pick among **observed landings** moves that simulation into host code, which is the same split we already wanted (host owns legality and effects).

It is **not** a new planner, and it does **not** solve “win the whole task” as a Jev question. If we could compile any goal to a single observable win/lose predicate, we would not need the model.

## Tetris ladder → Voice Control

| Ask Jev | Voice Control |
| --- | --- |
| “Play Tetris” / “Find flights” as an agent loop | Host machine + unique local steps. Jev never owns the plan. |
| “Which button” | Unconstrained leftover: `operation` + `target_*` + `key`. Still a hole. |
| “Where should this piece land” | Competing city/date picker rows: one `outcome` Choice. Unique Zürich is local. Return is not a landing. |
| “Win or lose” | Refused. That is a receipt. `finished` is never independent evidence. |

The author’s unsolved tree (one outcome changes the next) is **not** a Jev problem. Re-observe after one compiled outcome; the next frame is a new independent Choice. Missing pieces are host bookkeeping (satisfied slots, undo as a landing, history of verified post-conditions), not lookahead.

## What we adopted

- Jev’s competing-event question is named **`outcome`**. Criteria are post-conditions: `After the host acts, <label> is the selected result.`
- `VoiceControlEnabledEvent` carries a `postcondition`. City/date picker landings use `.selectedLabel`. `.unknown` means “step in disguise” and is not offered as a picker landing.
- `VoiceControlOutcomes.competingLandings` only fires on `suggestionPicker` / `datePicker`. Generic footer links are **not** landings (Fable: unknown post-state).
- Wire `kind: outcome` on the event-choice request body.

## What we refused (this pass)

- “Should you win” as a Jev question.
- Compiling the whole Flights instruction into one Choice.
- Replacing unconstrained `operation`/`key` in the same change (documented hole; do not pretend a link press is a Tetris landing).
- Wiring `postcondition.holds` into `VoiceControlTurnRunner` yet. The helper exists and is tested; the runner still uses adapter receipts. That is the remaining half of Fable’s amendment.

## Verification

Focused VoiceControl tests cover outcome-named Jev payloads, picker landings without a Flights parse, form chrome not becoming a landing board, and `.selectedLabel` holding when the row is focused.
