# Product and UX review of the Jev Voice Control proposal

Reviewed 2026-09-19 against `plans/active/2026-09-19-jev-voice-control.md`, `routing-catalog.md`, and `evaluation.md`. Document review only: no implementation, tests, APIs or app actions. This reviewer also authored the evaluation draft; its inconsistencies are reviewed on the same terms as the other documents.

## Verdict

**The proposal meets the user's requested full-feature ambition.** It includes native and browser control, precise text manipulation, spoken rewrites, hands-free operation, cross-app work and natural repair. It does not reduce the vision to a small safe demo. Direct manipulation, compact target feedback, contextual help, independent outcome verification and staged delivery form a coherent direction.

The plan is ready to discuss as a researched product proposal, but **three interaction contracts need resolution before implementation is treated as settled**: literal-mode escape/stop, pause/resume state, and the accessibility/repair requirements of the first beta. The source-inspired execution invariants are stronger than the corresponding user-facing mode definitions. Those gaps can be closed without narrowing the intended feature.

## Prioritized findings

### P1 — Literal mode has no complete hands-free escape contract

**Where:** Proposal → “Invocation and modes” (lines 59–61), “Speech commitment and correction” (lines 81–89); route catalog → R01, R16 and “Proposed fast paths and their exclusions”; evaluation → scenarios 15, 18, 19 and latency Stop row.

The proposal says literal-entry owns text until its boundary and reserved emergency controls need escape semantics. The catalog excludes stop words inside literal payload, while the proposal requires an active-session speech stop detector. Neither defines how a person who cannot press Escape ends literal dictation, says the literal word “stop,” or interrupts a long insertion after speech has committed. R16 also combines free-text literal entry and character spelling, which need different vocabulary behavior.

**Why it matters:** “Enter literal mode, dictate a paragraph, stop entering text, edit that paragraph” is a common full-feature journey. Without a precise mode contract, implementers will choose incompatible behavior; an accessibility user can become unable to leave a mode or have their prose interpreted as control.

**Recommended resolution:** Specify separate command/literal/spelling states, visible and accessible mode indicators, and exact transitions. Choose a reserved escape phrase in hands-free literal mode with an explicit quoting/escaping method; retain physical cancel and configurable assistive-switch input. Distinguish finish dictation, cancel uncommitted dictation, and revoke remaining insertion after dispatch. Define whether stop during a quoted one-shot “type…” command is payload or control from state and boundaries, not model preference. Add held-out tests for reserved phrase spoken literally, no-keyboard exit, long silence, interruption during insertion, and switching to spelling then back.

### P1 — Pause, stop listening, cancel task and resume have distinct prose promises but no complete state/route mapping

**Where:** Proposal → “Invocation and modes,” UI states “Paused / Needs help” and “Stopped,” bounded-task budget at line 136; route catalog → lifecycle diagram, R01 and R24; examples include “Pause listening.”

The proposal distinguishes stop listening (capture off and authority revoked), pause task (advancement halted), and cancel task (terminated). The catalog groups stop/cancel into terminal and has no explicit pause/resume route or paused state. Budget exhaustion says pause with progress preserved, while terminal language says no task silently resumes. “Pause listening” is an example without a defined capture/task effect. An implementer cannot determine whether “resume” restarts a task, restarts listening, or resumes a literal-entry session.

**Why it matters:** Multi-step control needs predictable pause/takeover/resume behavior, particularly while a person consults another app. Otherwise the excellent stated recovery design collapses into always restarting the command or unexpectedly continuing it.

**Recommended resolution:** Add a small orthogonal table for capture state and task state. Explicitly define “stop,” “stop listening,” “pause task,” “resume task,” “cancel task,” and budget/manual-takeover transitions. A paused task retains goal/receipts but has no action authority; resume creates fresh observation/approval as required. A terminated task cannot resume; “do it again” is a new task. Label the UI control by its concrete effect, and test these utterances in each state. No additional general-purpose state framework is needed.

### P1 — The first beta's promised repair/accessibility experience conflicts with delivery ordering

**Where:** Proposal → implementation slices 3, 6, 7 and line 163 (“Slices 1–4 … direct-control beta”); route catalog → Stages A/B/C; evaluation → “Reversible action alpha,” “Correction and multi-step alpha,” recovery/clarification gates, accessibility matrix.

The direct-control beta is positioned before hands-free endpointing (slice 6), contextual help (slice 7), and substantial correction (catalog Stage B). Yet invocation promises an accessible session toggle, onboarding teaches correction/stop, and evaluation's early alpha requires a toggle alternative. Beta gates require correction usability across induced misunderstandings. A hold-only beta with click/scroll/text capabilities could meet the implementation table while failing the promised everyday experience and excluding users who cannot hold a shortcut.

**Why it matters:** Repair and discoverability are central to this user's requested UIUX, not optional polish. It is reasonable to stage advanced editing/planning later, but basic accessible invocation, cancellation, target clarification and repair must accompany initial real execution.

**Recommended resolution:** Define a minimum beta experience bundle: accessible hold/toggle invocation with its endpoint semantics, onboarding/playground, “what can I say here,” numbered clarification, cancel, correction before dispatch, and one explicit recovery path after reversible navigation/text actions. Move those portions into slice 3/Stage A; leave advanced referents, rich editor adapters and multi-step planning later. Apply each evaluation gate only to enabled routes, but require the minimum bundle itself before calling the result a user beta.

### P2 — Multi-step limits differ across the plan and evaluation

**Where:** Proposal → “Policy and bounded tasks” line 136; evaluation → “Latency and resource budget” line 163.

The product default is 12 actions / 60 seconds / 2 no-progress attempts; evaluation's initial fixture ceilings are 20 actions / 30 requests / 60 seconds. Both are explicitly proposed, but the evaluation is also declared authoritative. A task can pass at action 15 in evaluation and be paused at action 12 in the product. The pause/continuation UX is not directly scored.

**Recommended resolution:** State one versioned product default (for example the proposal's 12/60/2) and use it for release-gate runs. Keep expanded 20-action experiments clearly labeled non-gating diagnostic runs. Define whether observation/verification and retries consume request, action or no-progress budgets. Include an exact-limit task and a one-over-limit task, measuring whether users understand the pause and can continue without duplicate effects.

### P2 — Literal-entry gate mixes expected cancellation with successful completed entry

**Where:** Evaluation → metrics row “Exact literal payload,” adversarial cases 19 and 28.

The denominator says all literal-entry trials including aborted attempts, while the gate asks for ≥99% successful complete entries. A correctly cancelled partial insertion is deliberately not a complete entry. It should not lower ordinary entry accuracy, but it must remain visible in cancellation correctness and partial-effect reporting.

**Recommended resolution:** Split completed-entry fidelity (all non-cancelled requested complete-entry trials, failures included) from cancelled-entry behavior (all accepted cancellation trials, expected prefix/no further dispatch and honest partial receipt). Report overall task-intent success separately. Also separate exact preservation of committed ASR text from end-to-end correctness against intended speech so a perfect executor cannot hide recognition errors.

### P2 — “Reading” and cross-app content acquisition lack an explicit route/observation contract

**Where:** Proposal → scope table “Scrolling and reading,” everyday example “find the latest design note and draft a reply in Mail,” “Cross-app transfer”; route catalog → R20–22; privacy → no arbitrary page bodies, additional content only when needed.

The full goal needs the agent to select and read an appropriate source, carry relevant text to a destination, and sometimes summarize or compose. Current routes cover UI actions, library entities and generative planning, but do not clearly identify read/extract acquisition, source disambiguation, truncation/coverage, or a user-facing indication of which document informed the draft. The privacy rule is sensible but is not the concrete workflow contract.

**Why it matters:** “Use this note in a reply” is a compelling differentiator beyond click-by-voice. Wrong-note or partial-content drafting can look successful even when every UI action succeeds.

**Recommended resolution:** Add an explicit read/extract capability (standalone or a documented subroute of R20/R22) with source identity, requested scope, completeness/truncation status, and cloud-provider exposure metadata. For drafts, show a concise source chip and destination/recipient; clarify duplicate “latest” documents. Add fixture tasks with two similarly named notes, selection versus whole document, truncated content, changed source while composing, and no configured generation provider. This does not require collecting arbitrary background content.

## Useful refinements, not blockers

- **Browser setup and compatibility:** The optional extension decision is coherent, but the first-run journey should say which browser families ship first, how a user sees that an origin is unavailable, and when AX provides reduced coverage. A capability/status panel would keep help honest. Avoid implying Safari and Chromium extension packaging are one implementation task.
- **Intentional repeated actions:** “Keep scrolling,” “keep going,” and “do the same in the next row” should clearly distinguish continuous motion, one repeated action, and bounded iteration. Ordinary repeat suppression must not block intentional repetition. Add a held-input/continuous-scroll stop trial and row-by-row target freshness trial.
- **Feedback burden:** The no-chat-dashboard direction is good. Evaluate optional sound/TTS against visual-only use and long work sessions; avoid a spoken “Done” after every key/scroll. Specific feedback should be proportional to effect, with detailed receipts available on demand.
- **Gates at realistic scale:** The evaluation properly distinguishes measured and proposed counts and notes correlation. A short practical gate checklist should identify which deterministic tests run on each code change versus expensive held-out model/device runs on a release candidate. Do not repeat thousands of paid trials after an unrelated copy change.
- **Permission for generative help:** When rewrite/planner setup is absent, provide one concise explanation and a supported fallback such as selecting a saved Transform or limiting a task to literal actions. The feature should not strand the user after successfully understanding their request.

## Recommended disposition

Accept the breadth and overall architecture as the basis for planning. Resolve P1 mode/state and beta-bundle contracts before implementation briefs are finalized; reconcile P2 metrics/budgets and add content acquisition before the full task-runner slice. These changes make the feature more complete and easier to use without expanding it into unrestricted autonomous computer use.

## Follow-up review after revisions

Rechecked the revised interaction defaults, delivery slices, local fast path/sequence additions, inverse table, read-content contract, and updated evaluation on 2026-09-19. No new source research or runtime testing was performed.

**Disposition: the six material findings above are addressed at proposal level.** They remain historical review findings, not outstanding blockers. The proposal now preserves its full-feature scope while supplying implementable defaults for the difficult interactions.

| Earlier finding | Resolution observed | Follow-up status |
|---|---|---|
| P1 literal escape/stop | Proposal “Literal entry, stopping and continuation” defines one-shot payload ownership, persistent Typing words/Spelling states, isolated `command mode` and `command stop`, and literal escaping. Catalog copies the defaults; evaluation adds acoustic/boundary cases. | Addressed as proposed grammar; real accessibility/accent trials remain a release gate. |
| P1 pause/resume | Bare Stop pauses/revokes; Cancel terminates/discards; Stop listening disables capture and pauses; resume reobserves. Catalog now has Paused transitions and R01 includes these semantics. | Addressed; one minor wording clarification below. |
| P1 beta bundle | Slice 3, Stage A and early evaluation alpha now require accessible toggle, help, basic referent repair, local Stop and clarification. Slice 6 is advanced tuning/planning, not the first accessible session. | Addressed. |
| P2 task budgets | Plan/catalog/evaluation agree on 12 dispatched actions, 30 model requests, 60 seconds and two consecutive no-progress attempts. | Addressed. |
| P2 literal denominator | Complete-entry fidelity excludes intentionally cancelled trials; cancellations remain in partial-effect/revocation metrics. | Addressed. |
| P2 read provenance | Typed bounded source snapshots, source identity/time/spans/sensitivity, source preview, changed-source behavior and separate provider disclosure appear in proposal and R20. | Addressed; completeness/truncation should be a snapshot field in the implementation contract. |

The additional local tier and pre-observation improve the responsiveness story without weakening target or consequence checks. The 2–3-clause direct sequence path makes the initial beta substantially more useful without requiring a general planner. Excluding literal/quoted payloads and preserving ambiguous conjunctions is the right boundary. The contextual inverse table turns “other one” and “undo” into concrete repair behavior rather than optimistic promises. None of these additions reduces the full feature to a demo or requires always-on ambient listening.

### Two minor wording clarifications before implementation briefs

1. **Resume within a still-listening session:** The proposal says bare Stop leaves the session available, then says a paused task can resume only after “a fresh explicit invocation.” Clarify that a committed “resume task” in an already-listening session is sufficient; a new physical/session invocation is required only when capture is off. Otherwise a literal reading unnecessarily forces a keyboard/button interaction on hands-free users.
2. **Stopped versus paused UI:** The table still has a Stopped outcome while bare Stop now pauses. Display “Paused” for resumable progress (optionally acknowledge “Stopped” briefly), and reserve cancelled/ended labels for discarded tasks or capture shutdown. Do not make the user infer resumability from a hidden state.

These are consistency edits, not architectural blockers. Gate actual hands-free grammar, expiry timing, long-form literal entry and compound-command usability with the proposed participant and acoustic trials. The feature's broad scope and initial useful-beta bar are now coherent.
