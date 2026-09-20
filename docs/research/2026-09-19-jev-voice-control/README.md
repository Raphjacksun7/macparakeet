# Jev-powered voice control: research and feature design

**Date:** 2026-09-19. **Status:** researched proposal; not implemented, runtime-verified or released.

[Open the interactive HTML feature walkthrough](walkthrough.html) for a visual tour of the planned experience, features and delivery stages.

## Recommendation

Build it as a native MacParakeet **Voice Control** mode. The references demonstrate useful component patterns: fast semantic routing, compact action candidates, native Accessibility execution and conversational follow-ups. The product opportunity is a single fluent experience around those components: immediate target feedback, natural corrections, precise text handling, dependable stopping and clear outcomes.

Jev is a strong fit for the action-selection path. It should evaluate the current spoken intent against actual observed controls and typed capabilities. Local code should own execution; the existing text-model path should handle actual rewriting, and an optional planner should handle bounded goals that need decomposition. Do not put a generative reasoning call in front of every click, and do not require Jev to generate strings it cannot generate.

### Start here

1. [Canonical feature plan](../../../plans/active/2026-09-19-jev-voice-control.md): full experience, interaction states, architecture, privacy, staged implementation and decisions to validate.
2. [UX storyboards](ux-storyboards.md): hold-to-inspect, correction, persistent typing, short sequences, larger tasks, stopping and onboarding.
3. [Classifier/router and use-case catalog](routing-catalog.md): 14 question-head families, 25 proposed routes, 60+ utterances, model-free paths, clarification, correction, confirmation and error behavior.
4. [Evaluation and rollout](evaluation.md): 30 task templates, 42 failure/correction families, independent oracles, route-specific metrics, proposed latency targets and accessibility/hardware/locale matrix.
5. [Platform and additional implementations](platform-and-ecosystem.md): official Jev facts, measured-vs-claimed evidence, Jev Ultrafast source review, six additional open-source projects and current MacParakeet reuse boundaries.

## What to take from each reference

| Reference | Best idea to carry forward | Important limitation to solve |
|---|---|---|
| [jev-voice-browser](jev-voice-browser.md) | One batch of typed semantic questions, explicit policy, on-page numbered clarification | Stale speech and target state can execute; selecting a numbered alternative bypasses consequential-action policy; “verbatim” spans are modified |
| [macbrow](macbrow.md) | Fast direct tool routing, missing-slot questions and browser follow-up continuity | Clarification and confirmation state get conflated; free text adds a second call; approval/account identity and outcome checks need stronger contracts |
| [third-hand](third-hand.md) | Native AX observation and action loop, compatible target heads, revalidation and OCR recovery | Input is typed, not speech; completion can display Done for unverified work and fail to terminate the runner |
| [Jev Ultrafast](platform-and-ecosystem.md#browser-use-jev-ultrafast--deep-source-review) | Dynamic observed action space, real node identity, consume-once decisions, execution recorded before follow-up observation | Needs voice semantics, calibrated abstention, user repair, scoped authority and product UX |

Source-review failure scenarios are not reproduced incidents. Each report pins the inspected commit and gives code anchors. All four deep-reviewed references use MIT licenses; review dependencies and preserve notices before copying implementation.

## Product lessons

- **Natural language needs a precise escape hatch.** Semantic matching should cover ordinary requests; stable labels, spelling and grids rescue difficult targets without forcing everyone to learn a command language.
- **Let the user see understanding early.** Highlight while listening; commit against the current utterance and target. A visible preview can feel responsive without performing an unfinished command.
- **Correction is a core flow.** “Not that,” “the other one,” “change it to Friday,” and “again” need typed session references and action receipts. A single last-string variable is not enough.
- **Separate identifying from authorizing.** Choosing option two resolves a target. It does not approve sending, purchasing or deleting. All paths return through the same action policy.
- **Text is its own interaction surface.** Literal payloads, precise edits, dictated rewrites and generated drafts have different contracts. Preserve punctuation and exact source spans; do not blindly clear a focused field.
- **Use actual state, not the last screenshot or label alone.** App/window/tab/document/field identity must survive inference latency. Reobserve each multi-step transition.
- **Done means observed completion.** Successful input dispatch and a model's success opinion are insufficient. Preserve partial/unknown outcomes and never blindly replay a possibly completed submission.
- **Optimize the whole loop.** Local ASR, endpointing, AX traversal and settling can dominate Jev latency. Measure them independently and eliminate unnecessary serial requests and fixed sleeps.
- **A separate mode can still feel fluid.** Keep ordinary dictation unchanged; offer a deliberate voice-control gesture plus an explicitly started hands-free session. Show the active target and stop affordance continuously.

## Evidence, scope and limitations

Deep source review covered the three supplied checkouts and Browser Use Jev Ultrafast. Broader primary-documentation research covered Talon community, Cursorless, Rango, mac-use, OpenDex, Cua and Apple's Voice Control baseline. Official TypeSafe docs were refreshed during this pass. The prior local TypeSafe research note remains background; this package is the current voice-control-specific proposal.

Five synthetic Jev calls earlier in this conversation took **216–293 ms**, median **238 ms**, and handled the tested Save/scroll/incomplete/negated/ambiguous commands without selecting a wrong action target. One completeness answer on a negated command was .63, illustrating why separate questions cannot independently authorize effects. This was text-only and tiny; no claim of real voice accuracy, p95 or broad computer-use reliability follows. See the [measurement ledger](platform-and-ecosystem.md#what-was-measured-in-this-conversation).

No reference application, speech session, desktop action, or model request was executed during this research task. No production code or accepted ADR was changed. Proposed budgets and success percentages in the plan are targets for testing, not achieved numbers. Personal UI contents and credentials were not inspected by research agents.

## Independent research and review

- [Sonnet UX research](sonnet-ux-research.md): requested `claude-sonnet-5`, high effort, through `claude -p`; independent suggestions with source-quality caveats. Parent editorial reconciliation is included at its start. Its broader claims are not automatically adopted.
- [Architecture review](review-architecture.md) and [product review](review-product.md): independent critique of the written plan; findings and dispositions are captured in [review resolutions](review-resolutions.md).
- [Fable review](fable-review.md): requested `claude-fable-5-1`, medium effort, for a fresh assessment of coherence and interaction quality.
- Delegation prompts are preserved under [briefs](briefs/). Reference checkout identities and public permalinks live in each report. The documents stand alone without requiring the ignored local checkout folder.

`/references/` was added to the repository `.gitignore` as requested. Local checkouts and fetched source caches remain on disk. No commit, push, issue, website publication or deployment was performed.
