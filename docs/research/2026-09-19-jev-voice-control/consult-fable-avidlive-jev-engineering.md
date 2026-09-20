# Independent Fable review — Avidlive Jev Engineering sheets

Requested `claude-fable-5-1`, effort **medium**, through `claude -p` on 2026-09-20. Primary sources: the four Avidlive sheets plus the parent extraction [avidlive-jev-engineering.md](avidlive-jev-engineering.md). Design critique, not runtime evidence.

Invocation: `--permission-mode plan`, tools Read/Glob/Grep, no file edits. Envelope `modelUsage` keyed `claude-fable-5-1` (thinkingTokens 3161) plus auxiliary `claude-haiku-4-5-20251001`. Duration ~105s. Parent dispositions are in the extraction file.

---

## Fable 5.1 second review — Avidlive "Jev Engineering" sheets

### 1. Fidelity

The extraction is faithful on sheets 2 and 3 and on the responsibility split. Four material misreads:

- **DeepSeek is the worker, not Jev's analogue.** Sheet 1 says "Use Jev around the worker: route the task, flag missing evidence, then check requirements against the result." The extraction renders this as "Jev ≈ DeepSeek Flash … a role analogy (fast router)." The sheet places DeepSeek in the Worker/Execution box and Jev outside it. The mapping conclusion ("not a dependency") survives, but the reading is inverted.
- **Economics numbers were changed and the replacement arithmetic is wrong.** Sheet 4: "Assume 40% decision time and a 20× improvement there: overall ≈ 1.61×." Extraction: "make it 2×, overall is ~1.4×." Amdahl gives 1.25× for 2×. Keep the sheet's numbers.
- **"Official TypeSafe fan-out pattern"** (extraction line 98) is not on sheet 2. The sheet only says "Batch when evidence is shared … [1]." Do not launder Avidlive text into TypeSafe authority.
- **Two transcription errors that flip meaning:** "confer calls" should be "confer permission" (sheet 4, "Keep the boundary clear"), and "Protect the final stack" should be "Protect the final test."

Minor: sheet 3's "Score applicability" box is a Jev call with ranking "in code"; the extraction folds both into code. Sheet 2's policy gate branches on UNCERTAIN, not NO.

### 2. Load-bearing ideas

**TypeSafe-true** (convergent with platform docs; implement as invariants):

1. **Closed option map with an escape.** Choice includes "other" or "insufficient evidence." For Voice Control the map is the current machine's enabled events plus `insufficient_evidence`.
2. **Independent questions, combined in code.** "No question reads another answer in this batch." One snapshot fans out to operation Choice plus per-operation target heads. Consume only the matching head.
3. **Confidence is a routing signal, not correctness.** "High confidence can still accompany a wrong answer." Thresholds are tested per action risk.
4. **No generation, no arithmetic.** Dates, counts, amounts stay in code. Jev never drafts, never resolves "next Friday."

**Avidlive-process** (sound engineering, adopt as practice, not contract):

5. **Three separate gates:** valid + complete → meets tested policy → authorized + current. A malformed response executes nothing.
6. **Failure keeps its own status.** "Timeout ≠ no. Missing evidence ≠ false. Malformed response ≠ pass."
7. **Completion receipt from fresh observation.** "A selected 'done' option cannot prove that work finished."
8. **Bind to observation and re-check the target before acting.** This is the AX staleness rule stated generically.

### 3. What to refuse

- **The 20-workflow map.** Voice Control has one insertion point. Do not build a menu.
- **"Put the decision where work branches."** Taken literally this puts Jev at every state transition. Jev is called only when enabled events exceed one and the utterance does not resolve deterministically.
- **Rank wide, read narrow via Jev Score.** Widget eligibility is AX filtering in code. Never Score-rank every visible element; that is a 500-candidate cloud call on a page label set.
- **Score type in v1.** No Voice Control decision is an ordered level.
- **A generative worker in the loop.** There is no artifact. The sheet's "worker drafts a reply" has no analogue; do not invent one.
- **Live shadow mode as drawn.** Shadow assumes an existing authoritative router receiving the same event. Voice Control has no incumbent router for a novel page. Shadow for us means replaying recorded snapshots plus utterances against new question packs, offline.
- **The 1.61× framing.** Useful reminder that STT + AX walk + settle dominate; useless as a target.

### 4. Voice Control insertion

Jev occupies exactly the **Decide** box of sheet 2's loop. Code does Observe (AX snapshot → enabled events), the host does Act and Verify.

- **City overlay open.** Enabled events: pick suggestion *i*, dismiss, continue typing. Return is not in the set, so it cannot be chosen. If the utterance string-matches one suggestion, |events| = 1, no Jev call. Jev is asked only when several suggestions plausibly match, with `insufficient_evidence` mapped to `clarify`.
- **Calendar.** Date parsing is exact work in code. Enabled events are day cells derived from the parsed date. Jev is not called. If parsing fails, the state is `not_checked`, surfaced as a clarify prompt.
- **Search.** Enabled only when origin, destination, and dates read non-empty from AX values. Pressing it is deterministic. Verify is the results list present in the AX tree, the completion receipt. Jev `finished` is never consulted.
- **Numbered picks** ("choose three") are a code-resolved enabled event, never a Jev question.
- **Generic unknown page.** Operation Choice over enabled events plus target head, gated by per-action thresholds; pay/delete/send route to `confirm` regardless of confidence.

The extraction's Flights diagnosis is correct: Return was an illegal enabled event, and the transition was treated as progress.

### 5. Gaps

- **Speech.** The sheets assume clean text. Nothing on STT confidence as an input to `insufficient_evidence`, utterance segmentation, or partial-hypothesis timing.
- **AX identity.** "Retain source IDs" and "stable pointers" have no AX equivalent. Re-identification is role + title + frame + parent path, and the sheets do not address false re-matches after layout shift.
- **Duplicate effects.** "Use idempotency where supported" is the whole treatment. AX presses and typing are not idempotent. `duplicate_blocked` keyed on snapshot generation must be host-side and is not on the sheets.
- **Optional DOM.** "Build candidates from observed elements" assumes one observation source. Nothing on merging AX and DOM, precedence when they disagree, or whether a DOM-only candidate may be an enabled event when AX cannot see it.
- **Privacy floor.** "Send the evidence that changes the decision" says nothing about what must not leave the machine. Page labels can be personal data; consent scope needs its own rule.
- **Labels.** Held-out evaluation presumes a labeled corpus. A personal desktop tool has to generate one from local traces, which the sheets do not discuss.

### 6. Verdict

**Adopt with amendments as engineering doctrine; reject as the architecture.** The architecture is already settled: a state machine whose enabled events are Choices, native AX as the observation source, host-owned execution. The sheets describe the judge slot inside that machine well, and rules 1 through 8 above should land in the ADR nearly verbatim, with the DeepSeek and economics misreads corrected and "official TypeSafe" claims removed. Everything that is specific to Avidlive's support-ticket business, the 20-workflow map, the Score type, the generative worker, and live dual-path shadow mode, should be dropped or replaced with offline snapshot replay. The open questions in the extraction resolve as: start with the overlay Choice, defer Score entirely, and keep numbered picks and calendar dates as non-Jev events.
