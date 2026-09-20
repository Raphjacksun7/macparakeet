# Architecture review: Jev Voice Control proposal

Review date: 2026-09-19. Reviewed the proposal, routing catalog, and evaluation design plus the current `StreamingCursorInserter` implementation/test source. No runtime tests, application actions, or API requests. This review changes no proposal or production code.

## Verdict

The proposal supports the user's full-feature objective and uses the reference projects selectively: Jev has typed choices, ordinary code owns effects, and both native and browser adapters have explicit identities. Its highest-value decisions are correct: committed speech before mutation, no hidden command interpretation in dictation, distinct clarification/approval, exact source spans, and verified outcomes.

Resolve the following concrete behavior gaps before the first executable vertical slice. These are implementation-divergence risks, not objections to the feature or requests for a larger architecture framework.

## Findings

### P1 — Command text entry needs an explicit executor boundary; existing cancellation deliberately drains text

**Anchors:** [proposal:124](../../../plans/active/2026-09-19-jev-voice-control.md#transaction-identity-and-verification), [proposal slices 2 and 5](../../../plans/active/2026-09-19-jev-voice-control.md#implementation-sequence-and-verification-ownership); [evaluation existing test contracts](evaluation.md#test-layers-and-what-each-can-establish), lines 51–54.

**Scenario:** An implementer follows the reuse guidance, wraps the existing paste/typing path in the new single-writer owner, and calls `Task.cancel()` on Stop. The existing streaming insertion function catches cancellation and inserts the rest of the text, so the new owner is logically stopped while lower-level code still posts input. Manual user takeover also intentionally triggers the same drain behavior. A surrounding actor or cancellation check before entry cannot repair this behavior once inside the inserter.

**Source validation:** `Sources/MacParakeetCore/Services/System/StreamingCursorInserter.swift:216–231` catches `CancellationError`, calls `playback.interruptAndDrain()`, and returns successfully. Lines 249–253 install an interrupt callback that also drains. `Tests/MacParakeetTests/Services/System/StreamingCursorInserterTests.swift:184–196` explicitly asserts the full string is present after task cancellation; lines 135–159 assert full insertion after physical interruption. The evaluation finding is correct. This is an established dictation contract, not an existing dictation bug.

**Resolution:** Add a concrete slice-2 deliverable: a command-specific text executor with per-batch action authority/focus checks, immediate stop of queued dispatch, and a partial-effect receipt. Preserve dictation's drain behavior. Require this executor for Stage A's exact insertion, not only slice 5's later precise editing. Gate its integration with the existing cancellation test retained unchanged and a new command-path test asserting no posts after revocation.

### P1 — Incoming utterance arbitration is not decided during an active action/task

**Anchors:** [proposal speech commitment and correction](../../../plans/active/2026-09-19-jev-voice-control.md#speech-commitment-and-correction), lines 89–90; [routing lifecycle](routing-catalog.md#proposed-decision-envelope-and-state-lifecycle), lines 25–49; [evaluation scenario 23](evaluation.md#adversarial-correction-and-interruption-corpus), line 100.

**Scenario:** In a hands-free session, “open the budget tab” is being verified when the user says “type forty.” The evaluation permits “serialize, explicitly replace, or reject according to visible policy,” but the policy never selects one. Queuing can type into a tab the user did not intend; replacing can abandon an unknown external effect; rejecting can lose a natural follow-up. Another case is “no, the other one” arriving while a click has been dispatched but before receipt publication: the correction needs to distinguish retracting a plan from repairing an effect.

**Resolution:** Specify the default now: stop/cancel interrupts immediately; correction revokes pending effects, waits for in-flight effect reconciliation, then enters repair; ordinary new commands during execution do not silently queue and either visibly pause/replace at a safe boundary or get a clear busy response. Distinguish the active command turn from the active task. State whether scoped follow-ups are accepted during verification and how they bind to the pending receipt. Add one exact expected result per example rather than leaving three equally conforming implementations.

### P2 — Hold-mode turn completion and follow-up context lifetime are underspecified

**Anchors:** [proposal desired experience](../../../plans/active/2026-09-19-jev-voice-control.md#desired-everyday-experience), lines 25–29; [proposal UI states](../../../plans/active/2026-09-19-jev-voice-control.md#ui-states-and-exact-promises), line 70; [proposal privacy lifecycle](../../../plans/active/2026-09-19-jev-voice-control.md#privacy-and-data-lifecycle), line 146; [routing referent ledger](routing-catalog.md#proposed-everyday-evaluation-utterances), line 152.

**Scenario:** The user hold-speaks “open the second result,” releases, sees success, then invokes again and says “no, the other one.” Success dismisses the hold UI and history clears at session end, but the plan never defines whether hold release, task completion, or dismissing the UI ends that session. One implementation deletes the candidate/receipt context and cannot deliver the advertised correction; another leaves an invisible session retaining private text indefinitely. Clarification or confirmation in hold mode has the same problem when another hold invocation is required to answer.

**Resolution:** Define microphone turn, command/task, and context session lifetimes separately. A concrete default can close the microphone after each hold while retaining only bounded target/receipt context for a short, visible correction window; pending clarification/approval remains its own explicit state with expiry. Define what clears that context, how a new invocation joins it, and what “stop listening” clears. Do not retain full utterance/UI text merely to support “other one.”

### P2 — Literal-mode escape and pause semantics are acknowledged but not specified

**Anchors:** [proposal invocation and modes](../../../plans/active/2026-09-19-jev-voice-control.md#invocation-and-modes), line 58; [routing R01](routing-catalog.md#proposed-route-catalog), line 83; [routing fast paths](routing-catalog.md#proposed-fast-paths-and-their-exclusions), line 122; [routing examples](routing-catalog.md#proposed-everyday-evaluation-utterances), line 138.

**Scenario:** A hands-free user enters literal mode and says “stop” intending to end a long insertion. The fast path excludes literal payload, and no spoken escape is defined. Treating Stop globally breaks “type stop”; treating it as payload can leave a person who relies on voice unable to regain control. Separately, the proposal distinguishes “stop listening”, “pause task”, and “cancel task”, but R01 collapses stop/cancel and the examples introduce “pause listening” without defining whether task execution continues or how microphone-off pause can be resumed.

**Resolution:** Choose an explicit literal-mode control grammar, boundary, and accessible fallback. For example, reserve a configurable two-word control phrase outside a quoted span and show it while literal mode is active; exact literal insertion of that phrase requires spelling or an explicit quoted span. Specify separate state effects for stop listening, pause task, cancel task, and resume, including whether paused capture still runs a small local resume detector. Test every reserved phrase as both control and payload. This is a product grammar decision, not a threshold-tuning question.

### P2 — Read-and-transfer work needs a first-class content-acquisition contract

**Anchors:** [proposal desired task](../../../plans/active/2026-09-19-jev-voice-control.md#desired-everyday-experience), line 31; [proposal privacy](../../../plans/active/2026-09-19-jev-voice-control.md#privacy-and-data-lifecycle), lines 141–144; [routing R20–22](routing-catalog.md#proposed-route-catalog), lines 102–104; [routing planner](routing-catalog.md#proposed-action-policy-confirmations-and-escalation), line 116.

**Scenario:** “Find the latest design note and draft a reply in Mail” requires reading content, carrying it across an app switch, and supplying it to a generative provider. The catalog covers selecting files, literal spans, UI observations, and typed effects, but not a typed read result/source artifact with a privacy boundary. Implementers may feed a whole page body into generic Jev state, pass a mutable selection whose text changed, or have the planner invent content from labels. The proposal says to read only needed content with scope visible, but does not identify the operation carrying that scope.

**Resolution:** Add a bounded `readSelection/readDocumentExcerpt` capability (or explicit subroute of R20/R22) producing a locally owned content snapshot with source identity/revision, range, privacy class, and user-request scope. Distinguish observation used to choose controls from content read to fulfill a task. Bind transfer/draft plans to that snapshot and destination, and disclose which authorized provider receives the excerpt. No broad document-ingestion framework is needed; this contract makes the promised cross-app task implementable without silently widening cloud context.

### P2 — Product and evaluation ceilings disagree for the same task

**Anchors:** [proposal policy and bounded tasks](../../../plans/active/2026-09-19-jev-voice-control.md#policy-and-bounded-tasks), line 136: 12 actions / 60 seconds / 2 no-progress attempts; [evaluation resource budget](evaluation.md#latency-and-resource-budget), line 163: fixture ceilings of 20 actions / 30 model requests / 60 seconds, with user-visible continuation afterward.

**Scenario:** A 16-action workflow passes the described evaluation fixture but production pauses after action 12. Reported task-success and latency results do not describe the product experience. “Experiment knobs” allows exploratory variants, but no rule says which configuration is used for acceptance evidence.

**Resolution:** Declare one baseline budget shared by production proposal and release-gate fixtures, including request cap and no-progress count. Permit clearly labeled exploratory variants, but disallow pooling them into acceptance metrics for a different configured budget. A simple shared table/reference is sufficient.

## Scope and source reuse checks

- The full feature remains in scope: native/browser control, precise editing, correction, hands-free sessions, and bounded cross-app tasks. Delivery staging does not improperly reduce it to spoken transforms.
- Third Hand's known defects are not adopted: the proposal explicitly separates unknown/blocked from success and revokes terminal authority before UI completion.
- The proposed extension is a deliberate improvement over Third Hand's opportunistic single-page Electron CDP adapter, not a claim that the reference already provides a general browser solution.
- Jev is correctly treated as a selector. Generative rewriting and decomposition have separate configured providers; no generated executable code enters the action loop.
- Existing source supports the streaming-cancellation warning. Exact behavior was inspected but not physically tested.

No production edits or broader redesign are requested by this review. Resolving the findings above should tighten the current plan while preserving its scope.

## Disposition after bounded revision review

Rechecked the changed canonical proposal, routing catalog and evaluation sections on 2026-09-19. No new source research or runtime verification.

| Original finding | Disposition |
|---|---|
| Command text cancellation | **Resolved in proposal.** Transaction section explicitly requires a command-specific cancellation-safe executor in the first direct-control slice, per-chunk/key authority checks, partial-effect reporting, and preservation of existing dictation behavior; slice 2 names this deliverable. |
| Incoming-turn arbitration | **Resolved in proposal.** Stop/cancel has priority; new speech pauses future dispatch; current dispatched effect is accounted for before ownership release; only newest committed pending turn is resolved, with visible goal replacement. |
| Hold-mode context lifetime | **Resolved in proposal.** Microphone-off referent/clarification continuation is bounded to 30 seconds; confirmation to 20 seconds; explicit end/incompatible context clears references. References carry no execution authority. |
| Literal escape / pause semantics | **Substantially resolved.** One-shot and persistent modes have separate boundaries; persistent mode teaches isolated `command mode` / `command stop` and a literal introducer; bare Stop pauses, Cancel terminates, stop listening turns capture off. Narrow resume wording cleanup below remains. |
| Read-content capability | **Resolved in proposal.** A bounded typed snapshot carries source identity/range/time/origin/sensitivity, explicit source scope and generative-provider disclosure. R20 and task slice include it. |
| Task ceilings | **Resolved in proposal.** Plan, routing, and evaluation agree on 12 dispatched actions / 30 model requests / 60 seconds / 2 no-progress attempts. |

The added local exact-command tier, early observation, bounded speculation, short explicit clause sequences, and per-adapter inverse table fit the existing transaction model. Local routes retain ordinary policy; quote/literal spans are excluded from clause decomposition; inverse operations require current identity and before/after evidence. These additions preserve the user's full-feature scope.

Two small remaining wording conflicts should be aligned before treating this as an implementation contract:

1. **P2 — Resume while the microphone remains on.** In the canonical plan's “Literal entry, stopping and continuation,” bare Stop leaves an enabled session available for repair, but the next paragraph says every paused task requires a “fresh explicit invocation.” A hands-free implementation could unnecessarily require a keyboard/toggle action despite already listening. State that a new committed `Resume task` utterance is sufficient in an active listening session; new capture invocation is required when listening is off. This clarifies the intended default rather than adding another mode.
2. **P2 — User takeover should not become terminal in the route table.** Routing catalog “Proposed terminal, unavailable and error behavior” still groups `User takeover/cancel/session close` under terminal UI, while the canonical plan pauses on manual takeover and reserves terminal handling for cancellation/end. Split the row: takeover revokes authority and enters Paused with a reconciled receipt; cancel/close terminates. Otherwise two implementers could differ on whether a manual adjustment permits task continuation.

Apart from those narrow wording alignments, the reviewed revisions close the substantive architecture gaps. This is a document-level disposition, not evidence of implemented or tested behavior.
