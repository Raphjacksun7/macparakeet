# Consultation brief: predict outcomes, not steps (Jev granularity)

**Date:** 2026-09-20
**Audience:** Claude Fable 5.1 via `claude -p`, effort **medium**
**Output:** a design critique. Do not edit files. Parent will adopt or refuse in code.

---

## One concern

A practitioner wrote that Jev is not an agent: it is good at judging what needs to be true, and weak at executing the steps that get there. Their workaround:

> You need to "predict outcomes, not steps towards an outcome."

Tetris ladder they give:

| Ask Jev | Quality |
| --- | --- |
| “Play Tetris” | Fails. Requires Jev to plan and execute. |
| “Which button to press” | Better, still a step. |
| “Where should this piece land” | Bypasses multi-step planning. |
| “Should you win or lose” | Even better as a goal predicate — but if we could compile any problem to that, we would not need the model. |

They say they have not solved trees where one outcome deeply changes the next, and that solving that is what would make workflow automation with Jev work.

Evaluate: is this TypeSafe-true, useful for MacParakeet Voice Control, or a slogan? What should we adopt, amend, or refuse?

## Product (settled)

Native MacParakeet Voice Control. Observation/execution is macOS Accessibility on the user's existing apps and browser. No CDP. Confirm only pay/delete/send. Jev is cloud text-only, `jev-1.13.0`, explicit consent. Unique deterministic steps must not pay for a Jev call.

Acceptance bar: typed “Find one-way flights from Zurich to London on September 20 2026” to a **results list** on native AX.

## Current architecture (facts)

Host classifies a snapshot as `plain` / `suggestionPicker` / `datePicker`, lists **enabled events** (each event carries one AX `VoiceControlAction`). `|events|==1` executes locally; `>1` is one Jev Choice over those ids plus `insufficient_evidence` / `clarify`; `0` is unconstrained Jev (operation + per-operation target heads + value spans + key).

Flights competing unfocused city rows are already a Choice among city **presses**. Unique Zürich is local. Return is not enabled on an overlay.

Unconstrained leftover still asks “which operation” then “which control” then “which key” — i.e. the Tetris “which button” rung.

## Jev contract (do not violate)

Independent Choice questions; no generation; no arithmetic/dates in Jev; `finished` is never a receipt; closed option map with escape; confidence is not P(success). Official: https://docs.typesafe.ai/concepts/state.md

## Report shape

Markdown. Sections:

1. Verdict (adopt / adopt-with-amendments / refuse) in one paragraph
2. What is TypeSafe-true vs folk engineering
3. Tetris ladder mapped onto Voice Control (Flights overlay, calendar, Search, generic page, unconstrained path)
4. What “outcome” means as a type (vs enabled-event-as-AX-primitive)
5. The unsolved tree problem: is re-observe-after-one-outcome the answer, or is something missing?
6. What to change in the Jev request (instructions, criteria, question names)
7. What to refuse (win/lose as a Jev question, compiling an entire workflow into one Choice, etc.)
8. Open questions

Stay under ~1200 words. Prefer invariants over slogans. Do not propose a second planner LLM, CDP, or Score-ranking every widget.
