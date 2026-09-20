# Consultation brief: Jev architecture for MacParakeet Voice Control

**Date:** 2026-09-20
**Audience:** independent design consults (GPT-6 Astra via `codex exec`; Claude Fable 5.1 via `claude -p`)
**Output:** a proposed architecture for *how we use Jev*. Not an implementation. Not a review of the current Swift types. We will take the design that makes the most sense even if it discards today's `VoiceControlFlightPlan` / `JevDecisionClient` shape.

Parent will synthesize both reports into a canonical design note. Write as if your report is the design.

---

## One concern

Propose the right architecture, abstractions, and Jev request shape for MacParakeet Voice Control so ordinary speech/typed intent can drive the frontmost Mac and browser.

## Product (settled — do not re-litigate)

- One install: the native MacParakeet app. Voice Control is a deliberate mode (DEBUG flag today; not always-on wake-word).
- **Required observation/execution path:** macOS Accessibility on the user's existing apps, including their existing Chrome. No CDP, no debug-port attach, no automation browser, no restart of the personal profile.
- **Optional DOM path:** if a MacParakeet browser extension has **connected this tab**, in-page observe/execute may use DOM (node identity, shadow, frames, hit-test). If the extension is absent or the tab is not connected, that is not an error — same command, same confirms, Accessibility. Browser chrome (tabs, URL bar, window) stays Accessibility either way. One runner, one policy, one trace; the user is not asked which adapter ran.
- Confirm only for payment, destructive deletion, and external send. Ordinary navigation, form fill, overlay dismiss, search, unique clicks proceed without a prompt.
- Local speech-to-text (existing MacParakeet pipeline). Commands never become ordinary dictation. Jev is cloud text-only, explicit consent, BYO key. Jev does not generate AppleScript, JS, or selectors.
- Stop / mouse-grab pauses and keeps the goal. Continue reobserves. Unknown or duplicate effects do not retry.
- Hands-free daily driver is the north star. The Google Flights goal ("Find one-way flights from Zurich to London on September 20 2026") is the acceptance bar for the *native* path: results list without an extension. Typed input is valid for proving the controller; mic is a later qualification of the same architecture.

## Jev contract (facts — design must respect these)

Official TypeSafe/Jev (`jev-1.13.0`):

- One request: `state` + named `questions`. Questions share state, run **independently**, and **cannot read each other's answers**.
- Question types: **Choice** (closed options + probabilities + confidence), **Noul** (P(yes), no confidence), **Score**.
- Fan-out is intended: speculative heads in one call; **code** consumes only the branch that applies (e.g. target head whose premise is the chosen operation).
- Jev is System One judgment, not a planner and not a generator. Weak at math, dates, counting, indirection, huge irrelevant state, and **generation**. Strong at picking among named options given criteria.
- Do arithmetic, date compare, URL construction, and identity in code. Text values should be **selected spans** from the user's utterance (or observed field values), not model-authored strings.
- Choice sets are bounded (~255 including a reserved `none` / `clarify` / `finished` as you see fit). Pin the model version.
- Confidence is a collapse of the probability distribution, not P(task success). A model's `finished` is never independent evidence of goal completion.
- Public docs: https://docs.typesafe.ai/concepts/state.md , `/primitives`, `/patterns/fan-out`, `/cookbooks/function_calling`, `/cookbooks/pre_parsed_value_extraction_cookbook`, `/model-jaggedness/jev-1.13`.

A suggested usage from the Jev community:

> Model your agent logic as a state machine. Give Jev the state + goal; the enabled events it can trigger are Choices. That's how you use Jev with state machines. It works extremely well.

Treat that as a hypothesis to accept, refine, or replace. Do not rubber-stamp it if a better Jev-shaped design exists.

Reference systems (ideas only, not transport to copy): jev-ultrafast (operation + per-operation target heads, consume-once, semantic freshness); jev-voice-browser (two-gate speech, numbered local picks); macbrow (session IDLE/CONFIRM, missing-slot Choice); third-hand (AX re-identify, progress guard). CDP/Playwright in those repos is **not** our transport.

## What went wrong in live Flights (evidence, not a prescribed fix)

Native AX sees the Flights form, city suggestion overlay (including `Zürich` vs `Zurich`), calendar day buttons, and `Where else?`. Live typed turns opened the site and filled cities/date, then stalled: Return ran while a suggestion overlay was focused (`duplicate_blocked`). The overlay was in the accessibility tree. Missing DOM was not the failure. Illegal **Return** was enabled while the overlay was open. State detection ("is the overlay open?") and which transitions are legal were the actual bugs.

## Constraints on the answer

- Greenfield on *Jev usage and agent logic*. Ignore current Swift type names if they fight the right design.
- Do not propose CDP, screenshots-to-cloud, generated tools, a second LLM planner in front of every click, or requiring the extension for the magic demo.
- Do not encode the entire Mac as one giant state graph.
- Unique deterministic steps should not pay for a Jev round trip.
- Be concrete: named abstractions, what lives in code vs Jev, request/response shape, who derives `state`, who lists enabled events, who executes, who verifies, who traces.
- Include a Flights walkthrough in the proposed model (origin overlay, dest overlay, calendar, Search, results).
- Call out failure modes and what you would refuse to implement.

## Report shape

Markdown. No file edits. Sections:

1. Verdict on the state-machine + enabled-events-as-Choices idea
2. Architecture (diagram in mermaid or ASCII is fine)
3. Core abstractions (types / module boundaries — language-agnostic)
4. Jev request recipe (state schema, questions, fan-out, when *not* to call)
5. Adapters (AX vs optional DOM) relative to the machine
6. Session vs task vs page machines
7. Verification, freshness, duplicates, Stop
8. Flights walkthrough
9. What you reject
10. Open questions you could not settle

Stay under ~1500 words. Prefer invariants and types over slogans.
