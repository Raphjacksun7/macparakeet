# Jev decision architecture for Voice Control

**Date:** 2026-09-20. **Status:** implemented in the DEBUG experiment. Not a claim that live Google Flights results or the microphone path have passed.

This is the design we are building to: code lists **legal events**, Jev **chooses among them** when more than one is plausible, the host **executes and verifies**. Independent consults: [GPT-6 Astra](consult-gpt6-astra-jev-architecture.md), [Fable 5.1 high](consult-fable-jev-architecture.md), [Avidlive sheets + Fable medium](avidlive-jev-engineering.md). macOS computer-use references (`third-hand`, `jev-use`, `jev-ultrafast`, `macbrow`) inform policy, not transport.

## Doctrine

```
Observe (AX, or DOM if the tab is connected)
  → Situation (plain / suggestionPicker / datePicker)
    → Enabled events (code)
      → |events| == 1  → execute locally
      → |events|  > 1  → one Jev Choice over those event ids
      → |events| == 0  → unconstrained Jev on legality-filtered targets
        → host policy → execute once → verify on a fresh snapshot
```

Jev is a judge, not a worker and not a completion oracle. `finished` is never a receipt. Return is **not** an enabled key while a suggestion or date picker is open.

## What we did not build

A seven-state universal Mac graph, Score-ranking of every widget, a generative worker in the click loop, live dual-path shadow dispatch, or CDP. Those were considered and rejected as overengineering for this product.

## Types

| Type | Job |
|---|---|
| `VoiceControlSituation` | Recomputed every snapshot from AX facts. |
| `VoiceControlEnabledEvent` | One legal `VoiceControlAction` plus criteria text for Jev. |
| `VoiceControlMachineFrame` | Named machine (`flights`), situation, events. |
| `VoiceControlLegality` | Shared filters for domain machines **and** unconstrained Jev (no Search/Return on an overlay). |
| `VoiceControlFlightPlan.frame` | Flights obligations → events. Unique → local. Competing cities → Jev. |
| `JevDecisionClient.decide(..., events:)` | One `event` Choice plus `insufficient_evidence` / `clarify`. |

Adapters, speech, traces, confirmation, and Stop are unchanged.

## Workflows (insertion points)

Repeated, labelable decisions. Unique steps stay local.

| Workflow | Local when unique | Jev when |
|---|---|---|
| Open allowlisted site / running app | yes | never (`role=url` / activateApp stay host-owned) |
| Exact click / type / replace / scroll / keys | yes | never |
| Flights fill origin/dest/date, One way, Search | yes | — |
| Flights city overlay | unique diacritic match, or Escape | several cities match the typed span |
| Flights calendar day | unique day token match | (not Score; parse in code) |
| YouTube / Maps / Wikipedia / web search box | yes | unfamiliar in-page follow-up |
| Gmail Compose | unique Compose | — |
| Pay / delete / send | — | never auto; confirm |
| Generic unknown page | — | legality-filtered operation+target heads |

## Verification

`swift test --filter VoiceControl` — **107 tests, 0 failures** (2026-09-20). Includes overlay Return exclusion, competing-city Jev events, unique Zürich local press, event-only Jev payload, unconstrained overlay omitting Return/Search, and `replace with X` no longer building an invalid string range.

Live Flights-to-results and microphone qualification remain open. This architecture makes the recorded overlay stall **illegal** (Return is not enabled) instead of hoping Jev will not pick it.
