# Independent Fable review — predict outcomes, not steps

Requested `claude-fable-5-1`, effort **medium**, through `claude -p` on 2026-09-20. Brief: [briefs/jev-outcome-choice.md](briefs/jev-outcome-choice.md). Parent dispositions: [jev-outcome-choice.md](jev-outcome-choice.md).

Invocation: `--permission-mode plan`, tools Read/Glob/Grep, no file edits. Envelope `modelUsage` keyed `claude-fable-5-1` (thinkingTokens 2831, outputTokens 7219) plus auxiliary `claude-haiku-4-5-20251001`. Duration ~183s.

---

# Critique: "predict outcomes, not steps" for Jev in MacParakeet Voice Control

## 1. Verdict

**Adopt with amendments.** The slogan names something the current code already half-does: `VoiceControlOutcomes.criteria(landing:)` phrases options as post-conditions, and the host compiles each option to one AX action. What is missing is the other half of an "outcome": a host-side verifier that checks the post-condition on the next snapshot and stamps the receipt. Without that, "outcome" is a prose style for Jev criteria, not an invariant. The unconstrained path still asks operation, then target, then key, which is the "which button" rung. The "win or lose" rung and any whole-workflow compilation should be refused.

## 2. TypeSafe-true vs folk engineering

TypeSafe-true:

- Jev answers independent Choice questions over a closed option map. It discriminates among offered options given evidence. It does not simulate the interface's transition function. An option phrased as a step ("press button 14") asks Jev to do exactly that simulation. An option phrased as an observable landing ("London Heathrow is the selected result") asks only for discrimination against the goal. That is why the Tetris ladder improves as it climbs: each rung moves the transition function from the model to the compiler.
- The ladder only works if the host owns a deterministic compiler from outcome to action. Tetris has one. Voice Control has one only where a machine exists, such as flights and the pickers. On a generic page, "press this link" has no known post-state, so relabeling it an outcome is a step in disguise.

Folk engineering:

- "Outcomes are always better." An outcome Jev cannot see in the current snapshot is not an option, it is generation. "Zürich selected" is legal only when a Zürich row is offered.
- "Win or lose" as a question. That is a receipt, and the contract says `finished` is never a receipt.
- The framing that the tree problem is a model problem. It is a bookkeeping problem, covered in section 5.

## 3. Ladder mapped onto Voice Control

| Surface | Step rung (today or risk) | Outcome rung (target) |
| --- | --- | --- |
| Flights city overlay | Already outcome: competing rows are landings, unique Zürich is local, Return not enabled. | Keep. Add verifier: focused or selected row label equals chosen label on next snapshot. |
| Date picker | Unique day is local. Risk: two "September 20" cells when depart and return calendars are both visible. | Landing per cell with criteria "departure date is September 20". Date resolution stays in host. |
| Search field | Unconstrained asks operation, target, value span. | One event per candidate field: "field X contains the goal's query span". Value head already target-conditioned, so only the field is the choice. Return stays a host compile after verified value. |
| Generic page | `competingLandings` matches any five-letter goal token against rows. "flights" will match footer links. | Keep the shape but make criteria role-specific: link means "page for X is shown", radio means "X is selected". Drop rows whose post-state is unknown. |
| Unconstrained leftover | operation, then target, then key. This is "which button". | Replace `operation` with a closed set of outcome kinds, each compiling to one host action. Keep conditioned target heads. Never offer a key as an outcome. |

## 4. "Outcome" as a type

Today `VoiceControlEnabledEvent` is `id`, `criteria` string, `action`. The `criteria` is read only by Jev. An outcome type needs a fourth member the host reads:

```swift
struct VoiceControlEnabledEvent {
    let id: String
    let criteria: String            // prose for Jev
    let action: VoiceControlAction  // host compile, exactly one
    let postcondition: Postcondition // host verifies on next snapshot
}
enum Postcondition {
    case selectedLabel(String)
    case fieldValue(targetID: String, span: String)
    case situation(VoiceControlSituation)
    case unknown                    // step in disguise; allowed but marked
}
```

The invariant: an event may be offered to Jev only if its post-condition is observable on the next snapshot, or it is explicitly `.unknown` and the receipt will be marked unknown. This connects the slogan to a contract already in the README: receipts distinguish verified effects from unknown outcomes, and unknown outcomes stop automatic advancement. Right now that distinction comes from the adapter. With a post-condition it comes from the outcome the decision named, which is the stronger check.

The enabled-event-as-AX-primitive model stays. An outcome is not a new abstraction above events. It is an event whose criteria and receipt agree.

## 5. The unsolved tree

Re-observe after one outcome is already the architecture. `VoiceControlSituation` is recomputed per snapshot and is explicitly not a persisted graph. That handles the local branch: choosing one-way reshapes the next frame, and the next frame simply reflects it.

What is missing is not lookahead. Three things are missing:

- **Goal-slot bookkeeping.** The flights machine knows which slots are satisfied through `nextAction` and history. The generic path does not. Without a code-owned list of unsatisfied goal conditions, Jev is re-asked about slots that are already true, and "finished" gets chosen from appearance rather than from a satisfied-slot list.
- **Undo as an enabled event.** When a verified outcome leads to a frame with zero events and no new slot satisfied, the host should offer "overlay dismissed" or "previous page shown" as a landing, not ask Jev for a key. That is backtracking without a planner.
- **Receipt-driven history.** History passed to Jev should be the list of verified post-conditions, not dispatched actions. Verified conditions are what changed the tree.

Deep dependency between outcomes is then a host concern: the frame builder reads satisfied slots and current situation. Jev only ever sees the frontier.

## 6. Changes to the Jev request

- Rename the event question from `event` to `outcome`. Names are contract surface; the current name invites step-thinking.
- Put the frame in state: machine, state name, situation, and the list of already-verified conditions ("origin is Zürich", "trip type is one-way").
- Template every criteria as a post-condition: "After the host acts, <predicate>." Drop "not a button to mash" from the criteria; it is instruction, not criteria.
- Tighten `insufficient_evidence`: "No offered outcome corresponds to an unsatisfied goal condition."
- Unconstrained path: replace the `operation` question with `next_outcome_kind`, options such as "next empty goal field holds its span", "a listed result matching the goal is selected", "current overlay is dismissed", `finished_inferred`, `clarify`. Each compiles to one host action given the conditioned target heads. The `key` question is removed from Jev; keys are compiled by the host from the chosen outcome.
- Keep `value_<target>` heads as they are. They are already outcome-shaped.

## 7. Refuse

- "Should you win or lose" as a Jev question. It is a receipt and it is unobservable.
- Compiling the whole instruction into one Choice. Options would not be present in any snapshot.
- Offering outcomes whose subject is not visible in the current snapshot. That is generation through the option map.
- Treating `finished` as anything but an inferred claim gated by satisfied slots.
- Any key as an outcome. Return and Escape are steps; only the host emits them after a verified value or a chosen dismissal.
- A persisted plan graph, a second planner model, CDP, or scoring every widget. The brief already excludes these and the tree section shows they are unnecessary.

## 8. Open questions

- Does the `jev-1.13.0` state schema accept structured fields for verified conditions, or only prose in `criteria`? If prose only, the post-condition type is host-internal and criteria is rendered from it.
- Two rows with identical labels, such as two "London" entries. Is the landing then ambiguous by construction, and should the host clarify locally without a Jev call?
- The generic `competingLandings` token heuristic. What false-positive rate is acceptable before it costs a Jev call on a footer?
- Acceptance bar: can native AX observe a "results list" as a post-condition, or is the terminal receipt for the Zurich to London task necessarily `.unknown`? If the latter, the bar should say so.
- Is Jev confidence useful as a tie-break between re-observe and clarify when two landings score close, given it is concentration and not success probability?