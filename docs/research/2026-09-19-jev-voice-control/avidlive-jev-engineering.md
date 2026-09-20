# Avidlive “How to Master Jev / Jev Engineering”

**Source:** four-page guide, labeled Avidlive, sheets 1–4 of 4. Local copies: [sheet 1](avidlive-jev-engineering/sheet-1-understand-jev.jpg), [sheet 2](avidlive-jev-engineering/sheet-2-decision-loop.jpg), [sheet 3](avidlive-jev-engineering/sheet-3-choose-workflow.jpg), [sheet 4](avidlive-jev-engineering/sheet-4-build-and-measure.jpg).

**Date recorded:** 2026-09-20. **Status:** source extraction plus MacParakeet mapping. This is **not** official TypeSafe documentation. Bracketed `[1] [2] [3]` on the sheets are the author’s footnotes, not verified citations here.

**Independent second review:** Fable 5.1 medium via `claude -p` — [consult-fable-avidlive-jev-engineering.md](consult-fable-avidlive-jev-engineering.md). Parent dispositions below. This file was corrected for the four fidelity misses Fable found.

### Parent dispositions (Fable)

| Finding | Disposition |
|---|---|
| DeepSeek is the **worker**, Jev sits around it | Adopted. Extraction inverted this; corrected below. Still not a MacParakeet dependency. |
| Sheet 4 Amdahl numbers (40% decision time, 20× there → ~1.61× overall) | Adopted. Do not retarget latency from a 2× rewrite. |
| Do not call sheet 2 “official TypeSafe fan-out” | Adopted. Convergent with TypeSafe, not a citation. |
| “confer permission”; “Protect the final test” | Adopted transcription fixes. |
| Policy gate branches on **UNCERTAIN**, not NO | Adopted. |
| Score-applicability is a Jev call; rank valid candidates in code | Adopted. Not used for Voice Control v1 widgets. |
| Refuse 20-workflow map, Score in v1, generative worker in the loop, live dual-path shadow | Adopted. Shadow for us = offline snapshot+utterance replay. |
| Jev only when `\|events\| > 1` and the utterance does not resolve locally | Adopted (already the intended machine). |
| Overlay Choice first; calendar/Search/numbered picks stay non-Jev | Adopted. |

---

## The one idea

Jev is a **judge of a bounded next move**. It is not the worker, not the policy, and not the proof that work finished.

Give each layer one job:

| Layer | Job | Must not do |
|---|---|---|
| **Application / host** | Own policy, permissions, execution, identity, arithmetic, and the completion receipt | Treat a Jev answer as authorization or as “done” |
| **Jev** | Given compact evidence + explicit criteria, return typed answers (`Choice` / `Score` / `Noul`) | Generate the artifact, invent options, compute dates/counts, confer rights |
| **Generative worker** (optional) | Write or reason when the job is an artifact (draft, code, summary) | Choose the route, authorize the action, or verify the goal |

The sheets’ slogan: *Jev selects and evaluates. A generative worker writes and reasons. Your application owns the action.*

Read the four pages top to bottom: **understand the interface → construct evidence → route safely → integrate → measure.**

Start with **one repeated decision** that has known outcomes, a real fallback, and examples you can label.

---

## Sheet 1 — Understand Jev

### 01 System / responsibility map

Input is `task + current evidence`. Code first asks: **what decision is needed?** That decision must have **known options**, **supplied context**, and **explicit criteria**.

Then three boxes, in order:

1. **Jev / judgment** — choose the route (handler / model / review); return typed answers.
2. **Host / control** — apply policy (validate + authorize); dispatch only a **known handler + target**.
3. **Worker / execution** — create the artifact if needed (DeepSeek / another LLM); run tools (code / browser / services).

After tools: **check the actual result** on **fresh evidence**, then continue. The verify arrow does not go back to Jev’s opinion; it goes to observed state.

The sheet’s “useful split”: **use Jev around the worker** — route the task, flag missing evidence, then check requirements against the result. DeepSeek (or any generative LLM) sits in the **Worker / Execution** box and creates the artifact. Jev is not that worker and is not a Flash-speed analogue. The “design pattern, not a measured speed claim” line on the sheet applies to the whole split. MacParakeet does not take DeepSeek as a dependency; Voice Control also has **no generative worker in the click loop**.

### 02 Three answer shapes

Match the question to the type. A category, an ordered level, and a probability ask different questions.

| Type | Example on the sheet | Rule |
|---|---|---|
| **Choice** — select one | Which owner? Technical / Billing / Other | Closed option map with clear boundaries. Include **other** or **insufficient evidence** when the options may not cover the input. Returns confidence + distribution. |
| **Score** — ordered levels | How frustrated? 0 Calm / 1 Concerned / 2 Angry | Define the levels first. A score **can fall between levels**. A 1.6 on a three-level rubric is **not** a probability of correctness. Returns confidence + distribution. |
| **Noul** — P(yes) | Refund requested? | One explicit yes/no condition. Scale 0–1. **No separate confidence field.** |

Question pattern, written as a contract:

> given [named evidence], decide [one property] using [explicit criteria].

### 03 State / evidence selection

Do not dump the world into `state`. **Construct a compact decision record** from what the application actually has.

Available input is filtered:

- Current item (message / passage / task)
- Verified context (account / policy / goal)
- Relevant history (only useful prior events)
- Noise + duplicates (stale logs / repetitions) — **omit**

Code: retrieve + filter (retain source IDs), label provenance (fact / quote / instruction). The decision record is one useful state: item, context, facts, sources as stable pointers, `observed_at` timestamp. **Preserve the evidence trail.**

Invariants on the sheet:

- **Separate evidence from instructions.** A web page or quoted message can contain text that tries to steer the model. Treat that as material to judge, not as a system prompt.
- **Bind the result to an observation.** Record what was visible when the decision was made. Recheck a changed destination, amount, or target before acting.
- **Keep exact work in code.** Dates, counts, amounts, access rules stay in the application. Jev 1.13 is weak at numeric precision and at long irrelevant state.
- **Missing input is its own state.** Failed extraction should become `"not checked"` or a request for evidence — not a silent empty field.

---

## Sheet 2 — Run the decision loop

### 04 Batching / fan-out and combine

**One shared state. Several independent judgments.** Batch questions that can be answered from the same evidence. Combine their answers **in code**.

Example: support ticket (message + account + policy) fans out to Department (Choice), Frustration (Score), Urgency (Noul), Missing details (Noul). None of those questions reads another answer. Code then branches policy (route / review / escalate).

Rules:

- **Batch when evidence is shared.** Intent, urgency, and missing information can all refer to the same ticket. Each question must state its complete task (because heads cannot see each other).
- **Stage when evidence changes.** First choose a document. Then retrieve its full text. A question about that full text belongs in a later request.
- **Measure the real gain.** Compare batching with the existing implementation, including concurrent requests where supported. Count total latency, billed usage, and failed calls.
- **Dependency test:** if you could write this question using only the original state, it may fit the first batch. If it needs another answer, it does not.

The sheet’s own test: if you could write this question using only the original state, it may fit the first batch. That is convergent with TypeSafe’s independent-questions rule; the sheet does not cite TypeSafe here.

### 05 Action gates / explicit branches

**Every answer needs a permitted next step.** Response validity, semantic uncertainty, and authorization are **separate checks**.

```
Response arrives (known request + version)
        │
        ▼
Valid + complete?  ──no──► Not checked (error / missing evidence / existing fallback)
        │ yes
        ▼
Meets tested policy? (confidence + action risk)
        │ UNCERTAIN ──► Resolve uncertainty (more evidence / review / different system)
        │ yes
        ▼
Authorized + current? (permissions + fresh target)
        │ no ──► Stop / seek approval (no inferred permission)
        │ yes
        ▼
Execute allowed action
```

Never turn an API failure into a successful check. Record the reason and preserve the existing fallback.

Side rules:

- **Confidence is a routing signal**, derived from the answer distribution. High confidence can still accompany a **wrong** answer. Test the threshold on representative cases.
- **Action-specific thresholds.** A reversible tag and a payment do not share a bar. Preserve the application’s approval requirements.
- **Keep failure visible.** Timeout ≠ no. Missing evidence ≠ false. Malformed response ≠ pass. These cases retain their own status.

### 06 Control / observe decide act verify

**A decision becomes useful when the result is checked.** Fresh state closes the loop. A selected `"done"` option cannot prove that work finished.

The execution loop repeats only while the goal is incomplete:

```
Observe (read current state)
  → Decide (bounded questions)
    → Act through the host (validated permitted action)
      → Verify the outcome (compare with the goal)
        → Done — retain the receipt
        or Refresh / stop (new evidence / review)
Decision trace sits in the middle: state + question version + route + verified outcome.
```

**Completion receipt:** the exported file, stored queue record, or newly read setting that **proves the intended change**. Not Jev’s Choice, not “the tool returned 200.”

Three work kinds named on the sheet:

| Kind | Loop |
|---|---|
| **Browser work** | Build candidates from observed elements. Jev chooses a **permitted** operation and target. The **host** resolves and executes it. |
| **Agent work** | A worker completes a step. Compare the resulting artifact or tool state with the user’s actual goal. |
| **Recovery** | If a tool may have acted before an error, inspect the result before retrying. Use idempotency where supported. Track stalled progress and attempts **in code**. |

---

## Sheet 3 — Choose your workflow

This page is a **menu of insertion points**, not a claim that twenty workflows are shipped.

### 07 Retrieval / rank wide then narrow

Two different checks:

1. **Is this relevant?** — narrows attention (shortlist).
2. **Does this source support this claim?** — tests evidence (after retrieving full text).

Pattern: many candidate **summaries** → **Score applicability** (Jev; same request + criteria) → rank those scores **in code** → retrieve full instructions only for the top candidates → recheck actual fit (select / no match / review). Eligibility (available tools, permissions, budget) is filtered in code **before** scoring. Voice Control v1 does not Score-rank AX widgets.

Filter eligibility in code first: available tools, supported inputs, permissions, budget. Rank **only valid** candidates. A selector cannot recover a document excluded upstream — measure whether the correct item reaches the shortlist before judging final selection.

### 08 Application map / 20 workflow sketches

Put the decision **where work already branches**. Pick the insertion with a measurable problem and available evidence.

The twenty names are proposals (agent control, memory, quality, business). Recurring shape for all of them:

> event → bounded judgment → application policy → existing handler → verified outcome

**How to choose:** look for a repeated semantic judgment with a stable set of outcomes and enough past examples to label. Support ownership, source relevance, and draft-requirement checks have clear inputs and reviewable outputs.

The sheet is explicit: **presence here is not a claim that all 20 have been deployed or validated.**

### 09 Worked example — ticket to verified handoff

State: ticket + current policy (verified account context, original message retained).

Fan-out: Owner (Choice: technical / billing / other), Frustration (Score), Urgency (Noul), Cancellation intent (Noul). Code routes: code the work (conditional intent + policy) **or** worker drafts a reply. Then **check + approved handoff** (requirements + verified queue).

Warnings on the example:

- “Fix it or cancel” is a **conditional** request, not unconditional permission to close the account.
- Urgency, frustration, and cancellation intent may coexist. Combine them under a **documented** queue policy.
- Check the output: does the reply address the issue? Does it promise something policy does not allow? Verify the queue record or draft artifact.

Caption: example only. No model output, accuracy score, or live support claim is asserted.

---

## Sheet 4 — Build and measure

### 10 Integration / preserve the existing workflow

**Start with a shadow branch** in the sheet’s sense: current system keeps serving users while Jev records decisions for comparison. Voice Control has no incumbent page router, so **shadow here means offline replay of recorded snapshots + utterances** against new question packs — not a live dual dispatcher.

Same incoming event, same decision-time state, **two** decisions:

- Existing path: current decision → existing handler (authoritative in shadow mode).
- Shadow path: Jev proposal (observation only) → compare + log. **No second execution.**

Same event, two decisions. Preserve evidence IDs. A controlled switch: implement off, shadow, and active modes. Keep the original fallback and test rollback before enabling active.

Two prompt audiences: give the **build prompt** to your coding agent; give Jev a **state and bounded questions**.

### 11 Evaluation / learn then test

Improve in a cycle. Release through a gate.

Development: inspect failures (evidence + saved response) → adjust questions (criteria + policy; **version each change**) → replay the cases. Then freeze a candidate.

Release: held-out evaluation (quality + cost + latency) → shadow comparison (same state, no side effects) → limited active use (monitor + rollback). New failures inform the next development cycle.

**Change = re-evaluate:** model version, provider, language, question wording, candidate set, or policy.

What to measure: wrong routes, critical misses, review rate, automatic-decision coverage, API failures, verified task outcomes. Include sample sizes.

Separate **code** from **model** tests. Fixtures test routing, policy, and fallback behavior. Labeled model evaluations test judgment quality. One does not substitute for the other.

Protect the final **test**: once a held-out failure guides tuning, it is development data. Fresh test cases for the next final assessment.

### 12 Economics / measure the whole task

**A faster decision is one part of the gain.** Count observation, retrieval, generation, execution, verification, and retries in the comparison.

Illustrative on the sheet (not a benchmark): assume **40% decision time** and a **20× improvement there: overall ≈ 1.61×** — **all other work stays the same**. Useful as a reminder that STT + AX walk + settle dominate; useless as a Voice Control latency target. Re-run the comparison on our own loop.

Unit for the decision task: **verified acceptable completions**, counting failed attempts in the numerator. Quality constraint: faster at acceptable quality; keep fallback + downstream repair costs.

Watch downstream effects: better routing can avoid expensive work; wrong routing can add repair calls, queue time, and human review.

Keep the boundary clear: **Jev can supply useful judgments. It does not establish truth, confer permission, generate the artifact, or prove a side effect occurred.**

### Copy-this-design / audit

Inspect an existing workflow. Find one repeated decision with known outcomes and a useful fallback. Read TypeSafe’s current API docs. Add Jev behind off / shadow / active modes. Build compact state, use explicit criteria, batch independent questions. Validate responses. Keep calculations, permissions, and execution in code. Use server-side secrets. Add review paths for uncertainty, missing evidence, and API errors. Log model and question versions, route, latency, cost, and verified outcome. Test failures with fixtures, then compare labeled examples against the current workflow. Deliver the integration, replay command, and rollback switch. Leave active mode off until evaluated.

**Adoption rule:** expand only when the **full workflow** improves at the quality level you need. Replace `[workflow]` with the process you already use.

---

## What this is not

- Not a claim that Jev replaces the Mac accessibility loop.
- Not permission to treat `finished` / `done` as a completion oracle.
- Not a requirement to stand up all 20 insertion sketches.
- Not DeepSeek as a MacParakeet dependency.
- Not official TypeSafe text. Where the sheets agree with [platform-and-ecosystem.md](platform-and-ecosystem.md) (independent questions, no generation, confidence ≠ success, numeric work in code), treat that as convergent. Where they invent product workflows, treat those as examples.

---

## Mapping onto MacParakeet Voice Control

Settled product: native Accessibility required; optional DOM extension if the tab is connected; confirm only pay / delete / send; Jev is cloud text with consent; no CDP on the personal browser.

| Sheet rule | Voice Control |
|---|---|
| Host owns action | AX/DOM adapter executes; Jev never presses. |
| Known options + explicit criteria | Enabled events of the **current machine** (session / task / page), not every visible widget. |
| Unique deterministic step | No Jev call (`\|events\| == 1`). |
| Fan-out | One snapshot → operation Choice + per-operation target heads; consume only the matching head. |
| Separate evidence from instructions | Page labels are observations. They are not extra system prompts. |
| Bind to observation | Re-identify target after latency; overlay open ⇒ Return is **not** an enabled event. |
| Action gates | Malformed Jev → nothing executed. Pay/delete/send → confirm. Stale target → reobserve. `duplicate_blocked` stays a host status. |
| Verify vs goal | Results list / field+URL evidence, not Jev `finished`. |
| Browser work (sheet 2) | Exactly the intended computer-use loop: candidates from AX (or DOM), Jev picks permitted event, host executes, host verifies. |
| Shadow first | Offline replay of recorded snapshots + utterances against new question packs. Not a live second dispatcher. |
| Whole-task latency | STT + AX walk + settle + Jev + verify. Speeding Jev alone will not make Flights feel magic. |

The community line “model your agent as a state machine; enabled events are Choices” is the same design as sheets 1–2: **code lists legal moves, Jev picks among them, the host checks the world afterward.**

The Flights stall (Return while the city overlay was focused) is a sheet-05/06 failure: an illegal event was enabled, and a transition was treated as progress. The overlay was already in the AX tree. DOM was not the missing piece.

---

## Load-bearing invariants (copy into an ADR)

1. Jev judges; the host authorizes and executes; a worker (if any) only writes artifacts.
2. State is a compact, provenanced decision record. Missing evidence is a first-class value.
3. Questions are independent, batched only when they share that record, combined in code.
4. Every answer maps to a permitted next step or to an explicit non-action (`not_checked`, `clarify`, `confirm`, `stop`).
5. Fresh observation closes the loop. Jev `done` is never a completion receipt.
6. Ship question-pack changes behind versioned fixtures and offline snapshot replay before they dispatch. Off → replay/shadow → limited active, with rollback and verified-outcome metrics.

Open questions Fable settled: start with the overlay Choice (`insufficient_evidence` → clarify); do not use Score in v1; numbered picks and calendar dates stay non-Jev events. Speech, AX re-identity, `duplicate_blocked`, AX vs DOM merge, and the privacy floor of what labels may leave the machine remain host problems the sheets do not cover.
