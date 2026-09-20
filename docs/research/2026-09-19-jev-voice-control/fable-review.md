# Independent Fable review

Requested `claude-fable-5-1`, medium effort, through `claude -p`. Review of the initial written proposal; final dispositions are in review-resolutions.md. This is design critique, not runtime evidence.

# Review: Jev-powered Voice Control proposal

**Verdict:** Approve the direction, do not start the vertical slice yet. The design is rigorous, honest and safe. As written, the first release would still feel like a cautious demo. Every command waits on a cloud round trip, unknown controls prompt, compound commands are unsupported, text entry needs a prefix per sentence, and three stop verbs compete for one panicked word. Six amendments below fix that without widening the safety envelope. The full vision is sound and correctly excludes wake-word and unrestricted agents.

## Material issues

### 1. The "direct manipulation" promise contradicts the pipeline
The plan requires commitment, final ASR, observation, a Jev call, policy, revalidation, execution and verification before a click. The evaluation's own component budgets sum well past the p50 preview target. Speculative reuse only fires when the final transcript exactly matches the hypothesis, which ASR revisions make rare. The evaluation also budgets one batched decision per command, which contradicts per-partial speculative previews.

**Amend:** Add a local tier that never touches Jev. Exact visible label matches ("click Save" when one enabled Save exists), numbers, scroll verbs, key names, unique app aliases and stop all route deterministically. Start AX observation at Listening, not at commitment, and revalidate deltas. Make speculative reuse tolerant of case, punctuation and filler words. Report what fraction of commands hit the local tier as a first-class metric. This also gives graceful degradation when Jev is offline.

### 2. Literal insertion is under-specified and partly cloud-decided
Whether an utterance is literal text is head H01, a Jev question. So "type hello there" pays a round trip and inherits cloud failure modes. In hands-free mode, "type the meeting is over stop" is undefined. The plan wants both a live stop detector and a literal submode that can contain the word stop. The evaluation correctly flags that the existing streaming inserter flushes on cancel, but slice 2 names no replacement.

**Amend:** Make literal entry a local grammar with prefixes (type, insert, spell) and a sticky Typing submode (see UX idea 2). In hold mode the payload runs to release. In hands-free mode the payload runs to the acoustic endpoint. An isolated "stop" after a pause is a command. The word inside a continuous utterance is payload. Name a new stop-safe inserter in slice 2 that drops queued characters on revocation.

### 3. Stop has too many nouns
The plan distinguishes stop listening, pause task, cancel task and scroll stop. Users in trouble say "stop." Requiring them to pick the right noun is a contradiction with "immediate cancellation and honest state."

**Amend:** Bare "Stop" always halts whatever is moving, preserves state, keeps the session on. "Cancel" discards the pending action or task. Session end is the gesture, the menu item or "stop listening." Pause is automatic on user takeover, not a spoken verb in the first release. Escape and the hold key remain the physical equivalents of Stop.

### 4. The consequence policy will prompt on most web buttons
"Unknown-consequence controls ask or stop" plus "uncertainty never lowers risk" means most browser clicks prompt, because few controls have an adapter contract. That contradicts the ≤10% unnecessary-prompt gate and produces Apple Voice Control with a nag.

**Amend:** Define consequence classes deterministically from observable semantics. Known-consequential labels and roles (send, buy, pay, delete, publish, submit near recipient or payment fields) confirm. Navigational and reversible controls (links, tabs, menus, toggles, disclosures) run. Everything else runs with the outline preview as the consent moment and a receipt afterward, unless inside a known consequential context such as a compose window, checkout or destructive dialog. Treat "press Return" the same way: run in search and text fields, confirm in compose and terminal.

### 5. Reference continuity has no lifetime or reversibility table
The demo relies on "no, the other one" and on contextual repair. H09 and R04 exist, but nothing states how long a referent lives, whether "other one" after a clarification means candidates or prior action, or what reverses an opened link when the plan forbids treating undo as browser Back.

**Amend:** Specify the ledger entry as candidate set generation, chosen, rejected, action receipt and reversibility class. Referents live until the next successful different-target action or context invalidation. If the generation is gone, reshow numbered choices rather than guess. Add a fixed reversibility table per adapter: toggle re-toggles, text edit restores range, same-tab navigation uses Back only if the history entry matches the receipt, a tab or window we created closes, an app switch reactivates the previous app.

### 6. Compound commands are the most common phrasing and are unsupported
"Open File, then Export" and "go to Safari and open a new tab" are ordinary speech. Fan-out heads only see current candidates, so the second clause has nothing to select. The plan pushes this to bounded goals with a planner and a 12-action budget, which is Stage C. A system that answers "couldn't" to "select all and delete" feels like a demo.

**Amend:** Add a local clause splitter on conjunctions and "then." Resolve each clause sequentially against fresh observation with no planner. Show the queue in the pill. Stop and revocation apply between clauses. This belongs in Stage A.

## Scope creep to cut from the first release

- **Browser extension and native bridge in Stage A.** That is a second product with store distribution and a native messaging host. Ship Safari and Chrome via AX first. Verify Chrome's accessibility tree exposure under an assistive client early. Build the extension only if measured candidate recall fails.
- **File rename, move and delete.** High risk, low delight. Keep "open Downloads" and library actions.
- **Drag, OCR, numbered grid and window management.** Stage C.
- **Flight search style goals and the planner.** Full vision only. First multi-step is the clause queue above.
- **CLI observe/propose/execute surface.** Defer until the core is stable.

Keep volume and media controls. They are cheap and feel magical.

## Distinctive UX ideas

1. **Hold to inspect, release to go.** Finish speaking while still holding. The outline and intent label appear. Keep holding to hear yourself and say "no, the other one" before anything happens. Release commits. Confident users pay nothing. Hesitant users get a preview without a dialog.
2. **Sticky Typing chip.** "Type:" turns the pill into "Typing · Notes." Every utterance inserts as text through the dictation quality path and the stop-safe inserter until "done typing" or release-then-tap. A "Spell" sub-chip covers characters. This makes text entry first-class rather than a per-sentence prefix.
3. **Say what you see.** A modifier tap or "what can I say here" briefly labels the top affordances with their exact spoken names, drawn from the same AX snapshot sent to Jev. Discoverability is grounded in the real screen, and exact-name commands route through the local tier from issue 1.

## First release versus full vision

| | First release | Full vision |
|---|---|---|
| Invocation | Hold plus accessible toggle | Same |
| Apps | TextEdit, Notes, Finder, Safari, Chrome via AX | Extension, app adapters, matrix |
| Commands | Navigation, click, scroll, tabs, literal text, Typing chip, compound clauses, correction, undo, volume and media | Forms, files, cross-app transfer, planner goals |
| Rewrites | Selection rewrite via existing Transforms with preview | Same plus span-targeted edits |
| Policy | Deterministic consequence classes, outline as consent | Same plus semantic risk heads as supplement |

## Assumptions

- I read only the three named documents. Source reviews and the platform report were not consulted.
- Jev latency evidence is five synthetic text calls. No audio or end-to-end timing exists.
- Jev's capability set is taken as described: Choice, Noul, Score heads and a 255-option limit.
- Chrome AX exposure to third-party assistive clients needs live verification. I did not test it.
- Nothing was run, tested or edited. This reviews a proposal, not measured behavior.
