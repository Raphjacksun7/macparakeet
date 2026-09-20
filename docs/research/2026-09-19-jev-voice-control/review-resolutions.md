# Review resolutions and research method

Date: 2026-09-19. This records proposal review, not implementation verification.

## Work performed

Three independent source reviewers read the user-supplied repositories and wrote pinned reports. The parent researched official TypeSafe contracts, audited Jev Ultrafast, checked existing MacParakeet implementation boundaries and wrote the canonical plan/platform synthesis. Further agent work produced the route catalog and evaluation design. Independent architecture/product reviews then examined the concrete documents; both rechecked revisions and reported all material original findings addressed at proposal level.

A `claude -p` consultation requested **claude-sonnet-5 / high**, restricted to reading/searching/public research, for interaction-design ideas. A second requested **claude-fable-5-1 / medium**, restricted to reading the named plan documents, for a fresh critique. Returned model-usage metadata included the requested model in each run plus `claude-haiku-4-5-20251001` auxiliary usage. We do not label that as an all-Sonnet or all-Fable swarm. Both completed successfully. Durable briefs and returned substantive reports are linked in the research index; temporary CLI JSON envelopes are outside the repository.

## Architecture/product findings

| Finding | Resolution in canonical proposal |
|---|---|
| Existing dictation cancellation flushes text | Separate stop-safe command text executor in first direct-control slice; retain dictation behavior; test revocation before every queued input |
| Incoming turn during execution undecided | Stop priority; pause advancement; account for current effect; keep newest pending committed turn; no unbounded queue |
| Hold-mode context lifetime unclear | Proposed 30-second typed referent/clarification window, mic off; 20-second confirmation expiry; relevant state changes revoke immediately |
| Literal exit/stop and pause/resume unclear | One-shot payload owns its utterance; explicit persistent mode and local escape grammar; bare Stop pauses, Cancel discards, stop listening suspends capture; active-session Resume versus fresh invocation distinguished |
| First beta lacked accessibility/help/basic repair | Accessible session toggle, local Stop, contextual help and basic “other one” repair required in first direct-control beta |
| Cross-app generation lacks source-read contract | Typed bounded content snapshot with source/time/ranges/sensitivity/completeness; separate provider disclosure; source changes handled explicitly |
| Task budgets disagree | Align default experiment/product limits: 12 dispatched actions, 30 model requests, 60 seconds, 2 consecutive no-progress attempts |
| Literal accuracy denominator penalizes correct cancellation | Complete-entry accuracy excludes intended cancellations; cancellation and partial-effect correctness measured separately |
| Stopped vs Paused and takeover wording | Resumable work labeled Paused; manual takeover pauses; Cancel/End session terminate; stop listening is explicitly distinct |

See [architecture review](review-architecture.md), [product review](review-product.md). Follow-up reviews were read before the final wording adjustments above. No new runtime assurance follows from resolving document inconsistencies.

## Fable recommendations: adopted and qualified

- **Adopt:** observe at Listening, exact local routes, metric for local-route share, bounded speculative calls, hold-to-inspect UX, persistent Typing, precise reference lifetime/inverses and short explicit command sequences.
- **Qualify:** the initial critique said every command requires cloud and all compound commands are unsupported. Local paths already existed in the initial catalog; the revision makes their first-release role and sequencing clearer. Actual local-route coverage remains to be measured.
- **Do not adopt broad filler removal:** only route-specific harmless canonicalization; never strip negation, quantities or literal payload characters.
- **Do not split arbitrary speech on “and”:** source-span clause parsing is limited to clear supported command sequences outside quotes/literal payloads; ambiguous wording asks or uses semantic interpretation.
- **Do not treat preview as blanket consequence consent:** reviewed navigation can be prompt-free, but unknown submit-like effects cannot execute solely because an outline was displayed. Measure unnecessary prompts and improve adapter evidence rather than loosen authorization based on appearance.
- **Browser bridge:** measure native AX first and advertise only proven operations; retain optional extension in full scope for stronger DOM/tab/frame identity. Do not require CDP or personal-profile restarts. Release scope can qualify native browser baseline before richer extension coverage, but must not claim the latter until it passes.
- **Full vision preserved:** planner goals, source-aware cross-app drafting, richer editing, optional OCR/grid and system capabilities remain planned; stages do not imply these already exist.

## Sonnet recommendations: accepted evidence boundaries

Useful design proposals include typed referents, contextual help, integrated target clarification, spelling fallback, non-hold input alternatives and correction-focused usability studies. The independent report also uses secondary sources and some uncertain source claims. Those remain explicitly labeled leads; exact paper statistics, broad claims about another product's defaults and its suggested fixed probability thresholds were not promoted into verified findings. Its comparison of transcript-update gaps with silence is superseded by the source audit. No ambient wake-listening or arbitrary learned-script execution is adopted.

## Verification for this documentation change

Final checks passed: all five reference/source-cache directories match the new `/references/` ignore rule; all local Markdown links in the 19-document package/plan resolve; no conflict markers were found; `git diff --check` is clean. The existing unrelated plan-index edit remains preserved. No Swift code changed, so no build/full test suite was run. No reference app was launched; no microphone, screenshot or user-app action was performed. No new Jev calls occurred during research. The five earlier text-only API calls are documented as a prior conversational sample, not an end-to-end benchmark.

The user-authorized files are the new research package and feature plan, a minimal append to the already-dirty plans index, and `/references/` in `.gitignore`. Unrelated dirty files, all reference checkouts and the previously saved local credential are preserved. No publication, commit or deployment was authorized or performed.
