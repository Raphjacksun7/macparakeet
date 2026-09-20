# Independent Fable architecture consult — how to use Jev

Requested `claude-fable-5-1`, effort **high**, through `claude -p` on 2026-09-20. Greenfield design against [briefs/jev-state-machine-architecture.md](briefs/jev-state-machine-architecture.md). Design critique, not runtime evidence. Parent synthesis: [jev-decision-architecture.md](jev-decision-architecture.md).

---

I have what I need. The brief, the north-star synthesis, and the direction doc settle the constraints; the report follows.

# Jev architecture for MacParakeet Voice Control

## 1. Verdict on "state machine + enabled events as Choices"

Accept the shape, refine the substance. The hypothesis is right that Jev should pick among *enabled events*, and the Flights stall proves the converse: when illegal events (Return under an open suggestion popup) reach the Choice set, Jev cannot save you. The refinement is **where the machine lives and who authors it**:

- The machine is not a per-site graph and not a Mac-wide graph. It is a **small universal interaction machine** whose states are *observed situations* (about seven), derived by code from the AX tree on every observation.
- Enabled events are **operations on observed candidates**, computed by a legality table `(Situation, Candidate) → allowed operations`. Jev never sees an operation the table forbids.
- Task progress is a **slot ledger** in code. Jev never emits `finished` as a terminal signal.
- Jev is called only when the legal set has more than one plausible member.

## 2. Architecture

```
utterance ─► Intake (1 Jev request, once per utterance)
                │  intent class · slot spans · correction-vs-new
                ▼
           TaskLedger (slots, goal, destination)  ◄── Stop/Continue keep this
                │
   ┌────────────┴───────────── step loop ─────────────────────────┐
   │ Observe (adapter) ─► Observation{candidates, situation, key} │
   │      ▼                                                       │
   │ Legality(situation, ledger) ─► enabled events               │
   │      ▼                                                       │
   │ |enabled| == 1 or deterministic? ──yes──► Execute            │
   │      │ no                                                    │
   │ Step request (Jev fan-out) ─► Validate ─► consume once       │
   │      ▼                                                       │
   │ Freshness guard ─► Execute (AX or DOM handle) ─► Ledger      │
   │      ▼                                                       │
   │ Verify postcondition ─► update slots ─► done? blocked?       │
   └──────────────────────────────────────────────────────────────┘
   Trace records every stage, every gate, adapter used.
```

## 3. Core abstractions

| Type | Owner | Content |
|---|---|---|
| `Observation` | adapter | `candidates[]`, `situation`, `windowKey`, `focused`, `webAreaLoaded` |
| `Candidate` | adapter | snapshot-local `id`, `handle` (AX element or DOM node ref), `role`, `label`, `value`, `enabled`, `expanded`, `selected`, `placement` (page or toolbar), `scopeLabel` (enclosing row/group/dialog), `guard` hash |
| `Situation` | code classifier | one of `plain`, `textFieldFocused`, `comboboxEditing`, `menuOpen`, `modalDialog`, `datePickerOpen`, `loading` |
| `Legality` | code, static table | maps situation → allowed `Operation` kinds; also per-candidate filters (only popup options are `choose` targets while `comboboxEditing`) |
| `Operation` | code | closed enum: `navigate(destination)`, `focus(id)`, `type(id, span)`, `choose(id)`, `press(id)`, `key(escape or return)`, `scroll(id, amount)`, `wait`, `clarify(slot)` |
| `TaskLedger` | code | goal text, `today`, destination, `slots{name: value, satisfied}`, `actions[]`, `consequence` flags |
| `Decision` | Jev client | validated answer; consumed exactly once |
| `Verifier` | code | per-operation postcondition over the next `Observation` |
| `Trace` | code | stage, gates `{name, value, threshold, pass, note}`, adapter, truncation |

Module boundary: adapters produce `Observation` and execute `Operation` on a `handle`. Everything above the adapter line is adapter-blind.

## 4. Jev request recipe

**State** (bounded summary, no page text, no field values beyond the observed controls being decided on):

```json
{
  "today": "2026-09-20",
  "goal": "Find one-way flights from Zurich to London on September 20 2026",
  "situation": "comboboxEditing",
  "working_slot": {"name": "origin", "value": "Zurich"},
  "slots": {"origin": "unsatisfied", "destination": "unsatisfied",
            "depart_date": "2026-09-20 (unsatisfied)", "trip_type": "one_way (unsatisfied)"},
  "focused": {"id": 7, "role": "textField", "label": "Where from?", "value": "Zurich"},
  "candidates": [{"id": 12, "role": "option", "label": "Zürich, Switzerland", "scope": "suggestions"},
                 {"id": 13, "role": "option", "label": "Zurich Airport ZRH", "scope": "suggestions"}],
  "recent_actions": ["focus 'Where from?' verified", "type 'Zurich' verified"]
}
```

**Intake request** (once per utterance): `intent` Choice over `{web_task, app_command, correction, chat, stop, none}`; `slot_<name>_first` and `slot_<name>_last` Choices over utterance word indices for each slot the destination declares; `is_correction` Noul when a task is active. Code resolves dates against `today`, normalizes cities, and builds the URL.

**Step request** (only when needed): `operation` Choice over the enabled kinds plus `clarify` and `none`. One target head per enabled operation, each stating its premise: `press_target` ("if the operation is press…"), `choose_target`, `focus_target`, `scroll_target`, each with a reserved `none`. Optional `field_slot` Choice ("which slot does the focused field represent") when labels are unfamiliar. Code reads only the head matching the chosen operation.

**Validation before execution:** chosen option is an offered id, probability keys equal offered ids, all finite in [0,1], sum within 0.02 of 1, choice is argmax. Failure means nothing executes.

**Do not call Jev for:** `navigate` to a known destination; `type` of an already-resolved slot value into the focused field; `key(escape)` when legality says the only exit from an unwanted popup is dismissal; a `choose` or `press` where exactly one candidate matches the slot value after code normalization (diacritics folded, date formats parsed); a spoken number pick; Stop, Continue, takeover; a slot already satisfied by observed field value.

**Never ask Jev:** whether the task is finished, whether an action is safe, or what text to type.

## 5. Adapters relative to the machine

Both adapters implement `observe() → Observation` and `execute(Operation)`. The situation classifier, legality table, ledger, and verifier run on `Observation` regardless of source.

- **AX (required):** Chromium handshake once per process (`AXManualAccessibility`, `AXEnhancedUserInterface`), wait for a loaded `AXWebArea`, settle on stable candidate count. Candidate `handle` is the AX element; identity re-derived by handle equality, then unique role+label+scope, then center proximity.
- **DOM (optional, per connected tab):** contributes page-region candidates with node identity, shadow and frame coverage, and hit-test occlusion. Browser chrome candidates always come from AX. When both are present, page candidates are unified by DOM (authoritative for identity) and AX supplies the frontmost-window key and chrome.
- The `Candidate.handle` union is the only place adapter choice appears. The trace records which handle executed. Legality, confirms, and slots are identical either way.

## 6. Session, task, and page machines

- **Session** (one per Voice Control activation): `idle → listening → intaking → running → {paused, clarifying, confirming, done, blocked} → idle`. Stop and takeover transition to `paused` from any running state and keep the `TaskLedger`. Continue returns to `running` via a fresh observation.
- **Task** (one per utterance or correction): the `TaskLedger`. Progress is slot satisfaction plus a destination-declared completion predicate (for Flights: navigation happened after Search and a results list region is observed). Corrections mutate a slot and mark it unsatisfied.
- **Page/interaction** (one per observation): the seven-state `Situation`. It is recomputed, never persisted, so a stale belief about "is the overlay open" cannot survive an observation.

## 7. Verification, freshness, duplicates, Stop

- **Freshness:** compare `windowKey` and target `guard` immediately before dispatch; on mismatch, discard the decision and re-observe. Geometry is re-read right before pointer routes.
- **Consume once:** the decision is cleared from state before any mutation; the ledger entry is written before the post-action observation.
- **Postconditions:** `type` verifies readback; `focus` verifies the focused flag; `choose` verifies popup gone and field value changed; `press` verifies a situation or navigation change; `scroll` verifies offset change. Unchanged means "no effect, choose differently", never success.
- **Duplicates and unknowns:** a dispatch that times out mid-flight is recorded `effect: unknown` and the task goes `blocked` with that reason. Same `(operation, guard, windowKey)` twice is blocked. Two consecutive unverified actions block.
- **Stop:** revokes the current speech generation, cancels in-flight Jev requests, discards any unconsumed decision, keeps the ledger. Mouse or keyboard input from the user, or a frontmost-app change, is the same transition.
- **Confirm** only when the ledger's deterministic consequence metadata says payment, destructive deletion, or external send. A model answer never lowers that flag.

## 8. Flights walkthrough

1. **Intake.** Jev picks spans: origin `Zurich`, destination `London`, date span `September 20 2026`; trip type `one-way` from the utterance. Code resolves the date against `today`, sets destination Google Flights. One request.
2. **Navigate.** Deterministic. Wait for web area loaded and settled.
3. **Origin.** Situation `plain`, working slot `origin`. Legal: `focus`, `press`, `scroll`. Step request: `focus_target` among page text fields. Execute focus. Verify focused.
4. **Type.** Deterministic `type("Zurich")`. Verify readback.
5. **Overlay.** Situation `comboboxEditing`. Legal: `choose(option)`, `key(escape)`, `type`. **Return is not in the set.** Candidates normalize to more than one match (`Zürich, Switzerland`, `Zurich Airport`), so one step request: `choose_target`. Execute press on the option. Verify popup closed and field value non-empty. Origin satisfied.
6. **Destination.** Same path for `Where to?` and `London`. If `Where else?` or a suggestion overlay is focused, legality again excludes Return and generic presses.
7. **Date.** Focus the departure field; situation `datePickerOpen`. Legal: `choose(day)`, `press` on picker controls, `key(escape)`. Code normalizes day-button labels; a unique match on 2026-09-20 executes without Jev, otherwise `choose_target`. Press Done if present. Verify field value.
8. **Trip type.** Observed value `Round trip` versus slot `one_way`: press the popup button, situation `menuOpen`, choose `One way` (unique normalized match, no Jev). Verify value.
9. **Search.** All slots satisfied, situation `plain`. `press_target` with `none` if Search is not unique among page buttons. No confirm.
10. **Done.** Code predicate: navigation occurred and a list region with result rows is observed. Task `done` with "results shown". If the predicate fails after settle, `blocked: results not observed`, no retry.

Expected Jev calls for a clean run: one intake, roughly three to five step requests.

## 9. What I reject

- Hand-authored per-site state graphs, and any Mac-wide graph. The seven-situation machine is the entire authored state space.
- A generative planner, generated scripts, selectors, or model-authored text.
- Jev `finished` or any safety Noul as evidence of completion or permission.
- Falling back to the first candidate when a decision fails validation.
- Retrying an action whose effect is unknown.
- CDP, debug ports, screenshots in the loop, page text as state, or requiring the extension for the native demo.
- Confirmation keyed on verbs or operation type.
- Return as a legal operation whenever a popup, menu, or picker is open.
- Splitting Choices past 254 options. Narrow the candidate set instead.

## 10. Open questions

- How reliably Chromium AX exposes suggestion popups as distinguishable structures for the `comboboxEditing` classifier. This is the load-bearing empirical check.
- Whether destination-declared slot vocabularies scale, or whether a generic slot set with `field_slot` inference suffices.
- Where the `wait` operation belongs: only in `loading`, or also as a Jev-selectable event after a press.
- Whether the DOM adapter's node identity can be folded into the shared `guard` hash without leaking DOM-specific fields into the machine.
- Partial-transcript gating for slot spans versus closed-set intents, which the intake request currently assumes are finalized.