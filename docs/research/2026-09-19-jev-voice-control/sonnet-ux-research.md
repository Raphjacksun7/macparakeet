# Independent Sonnet UX research

Requested model: `claude-sonnet-5`, effort high, via `claude -p`. Source-research and design opinion, not measured product performance. Parent synthesis verifies and reconciles recommendations; this independent report is supporting evidence, not the canonical plan.

## Parent editorial reconciliation

This is an independent consultation retained for traceability. Its linked secondary articles, search-derived paper claims, unverified numeric benefits, and broad claims about another project's defaults are research leads, not verified findings in the canonical plan. In particular, its portrayal of a transcript-update timeout as acoustic silence is corrected by the source audit; fixed .5 command thresholds are not adopted. We do not adopt its ambient always-listening suggestion, arbitrary action learning, generic automatic repeat, or any shortcut around fresh policy checks.

Adopted as design proposals: typed recent referents, contextual rather than global help, stable ambiguity labels, semantic editing alongside literal entry, optional feedback for hands-free users, and correction-focused usability evaluation. These are recommendations to test. The canonical plan and route catalog take precedence over this report where wording differs.

# Voice-Control UX Research for MacParakeet + Jev

**Scope note:** This is independent interaction-design research, not an implementation review. It draws on (a) public primary sources for Talon, Cursorless, Rango, and Apple Voice Control; (b) HCI/CHI literature on voice text-editing; and (c) the three local reference prototypes (`jev-voice-browser`, `macbrow`, `third-hand`) and TypeSafe's own Jev docs, read only to understand what Jev *can and cannot* do as a decision engine — not to critique their code. Some primary docs are JS-rendered SPAs that WebFetch could only partially retrieve (noted inline); I cross-checked those with GitHub source, DeepWiki summaries, and independent write-ups rather than presenting a single thin fetch as ground truth. Where I could not verify a claim against a primary page, I flag it explicitly.

---

## 1. Primary-source lessons

| Source | Lesson | Link |
|---|---|---|
| Talon Community Wiki | Two-mode grammar (command vs. dictation) plus a hard sleep/wake gate is the load-bearing safety mechanism against false triggers, not confidence scoring alone. | [Voice Coding Overview](https://talon.wiki/Voice%20Coding/voice-coding-overview/), [Basic Usage](https://talon.wiki/Basic%20Usage/basic_usage/) |
| Talon (community) | Sleep/wake ("go to sleep" / "wake up") is a *voice-issued* state transition, not a hardware toggle — the mic never turns off, but a minimal wake-word-like grammar gates everything else. | [wolfmanstout modes docs](https://wolfmanstout.github.io/wolfmanstout_talon/core/modes/) |
| Talon | "Noise" triggers (a `pop` for click, sustained `hiss` for drag/scroll) turn non-speech mouth/throat sounds into discrete UI events — a hands-free alternative to both push-to-talk *and* to spoken click commands, useful for users whose voice tires. | [Medium: Make Your Mac Hands-Free](https://medium.com/hubabl/make-your-mac-hands-free-part-1-fe70980f36b) |
| Cursorless | Every command is `action + target`; targets resolve through hats (visual token anchors) → scopes/modifiers → a `StoredTargets`/"that" mechanism referencing the last result. This is the clearest *typed-referent* precedent I found, though I could not confirm exact end-user phrasing for "that" beyond its confirmed existence as a stored-target primitive (verified via GitHub source class names + community discussion, not a single canonical doc page). | [GitHub README](https://github.com/cursorless-dev/cursorless), [Cheatsheet](https://www.cursorless.org/cheatsheet), [DeepWiki summary](https://deepwiki.com/cursorless-dev/cursorless) *(uncertain: exact "that" syntax)* |
| Cursorless | Discoverability is deliberately **pulled**, not painted: users say "cursorless cheatsheet" to open a separate reference surface, rather than the editor rendering command hints inline all the time. | [Cheatsheet issue #840](https://github.com/cursorless-dev/cursorless/issues/840) |
| Rango | Hint labels are transient (appear on trigger, e.g. a hesitation pattern in speech) and compose via connectives — `and` for lists, `until` for ranges, `again` for repeating the last scroll direction on a previously hinted target — giving a small, learnable grammar for chaining instead of one command per element. | [Rango README](https://github.com/david-tejada/rango/blob/main/readme.md) |
| Apple Voice Control | "Show numbers" / "show grid" overlays are explicitly on-demand and hierarchical (say a grid number to drill into a sub-grid) — the only always-on overlay is the always-numbered menu bar/dock, which Apple keeps minimal by default. | [Apple Support: Numbers & Grid](https://support.apple.com/en-sg/guide/mac-help/mchl26854b08/12.0/mac/12.0) |
| Apple Voice Control | "Correct \<phrase\>" surfaces a numbered list of alternate interpretations; if none fit, you simply *speak the right text* while the wrong phrase stays selected — correction reuses the same selection+replace primitive as normal editing rather than inventing a separate repair grammar. | [MacMost: Voice Control Dictation Tips](https://macmost.com/20-voice-control-dictation-tips.html) |
| Ghosh, Liu, Zhao, Hara (ACM TOCHI 2020) | A Wizard-of-Oz study found users spontaneously split into two correction strategies — **Commanding** ("replace go with goes") and **Re-dictation** (just re-saying the fixed phrase in place) — and a controlled study found Re-dictation wins for semantically complex edits, Commanding wins for single-word deletions. Neither strategy alone satisfies users. | ["Commanding and Re-Dictation"](https://dl.acm.org/doi/10.1145/3390889) *(full text paywalled; summarized from abstract/related coverage)* |
| Fan, Xu, Yu, Shi (UIST 2021) | Recalling the *original* erroneous words to construct a "replace X with Y" command is itself a major cognitive-load source in eyes-free editing; techniques that avoid asking users to restate the error reduced failure rate by 54% over descriptive commands or re-speaking. | ["Just Speak It"](https://dl.acm.org/doi/10.1145/3472749.3474795) |
| Levinson & Torreira (2015) | Human conversational turn-taking has a modal gap of ~200ms despite production planning taking 600ms+ — achieved because listeners begin planning their response before the speaker finishes. This is the natural baseline users unconsciously compare system latency against. | ["Timing in turn-taking..."](https://philpapers.org/rec/LEVTIT-8) |
| Schäfer (thoughtbot, practitioner account) | Real-world comparison of Copilot Voice, Serenade, and Talon+Cursorless: Serenade's NL-first approach broke down on accented English vowels with no fallback; Talon's phonetic-spelling fallback ("alpha bravo...") was what made errors *recoverable* rather than just less frequent. | ["I'm currently talking to the machine..."](https://thoughtbot.com/blog/i-m-currently-talking-to-the-machine-and-it-s-not-helpful-at-all) |
| Serenade (cautionary, not a success story) | A natural-language-first voice coding tool with no comparable fallback grammar; public GitHub activity slowed sharply and a practitioner review from 2025 called it unmaintained for "three years." I could not find an official shutdown announcement — treat "abandoned" as inferred from activity level and third-party review, not confirmed. | [Serenade GitHub](https://github.com/serenadeai) *(uncertain: no official EOL statement found)* |

---

## 2. Common user-task families (varied utterances → expected UX)

Framed against MacParakeet's actual surfaces (dictation, Transforms on selected text, meeting recording, plus the direct-control ambition shown in `macbrow`/`third-hand`):

| Family | Example utterances | Expected UX |
|---|---|---|
| **Session control** | "start dictating" / "pause the meeting" / "stop, stop, stop" | Immediate, no-confirm execution; must be recognized even mid-utterance of something else (barge-in), since these are often panic/urgent. |
| **Transform invocation on selection** | "make this more formal" / "clean up my rambling" / "turn this into bullet points" / "translate to Spanish" | Selection must already be visually indicated; the transform *previews* the diff before committing if it changes meaning materially, executes near-silently if it's a well-worn transform the user runs often. |
| **In-place correction of just-dictated text** | "scratch that" / "no, I meant Tuesday not Thursday" / "put a comma after that" | Two grammars, not one: a Commanding form (explicit replace) and a Re-dictation form (just say the fix); the system should accept either without the user declaring which mode they're in (see §4, §9). |
| **Referential follow-up edits** | "make that bold too" / "do the same thing to the next paragraph" / "undo that" / "not that one, the other one" | Requires a short typed history (last selection, last transform, last target) — not just a single "last utterance" slot — so "the other one" can resolve against type, not just recency. |
| **Direct app/system control** (per `macbrow`/`third-hand`'s ambition) | "open Slack and jump to the design channel" / "click the second search result" / "type my email into the field" | Should look and feel like Rango/Cursorless-style targeted action: numbered disambiguation only when confidence is genuinely split, silent execution otherwise. Destructive-looking actions (send, delete, buy) always get a spoken/visual confirm gate. |
| **Meeting-specific commands** *(speculative — MacParakeet-specific, no direct precedent in the sources reviewed)* | "mark this a follow-up" / "jump back to when we discussed pricing" / "who said that" | Needs a scrollback/transcript-addressable referent model — closer to Cursorless's scope+modifier idea (addressing a *segment* of a document) than to Rango's DOM-hint idea. |
| **Lookup / query, no state change** | "what did I just say" / "find the part about the roadmap" | Zero-risk, so should be the *fastest and most eagerly executed* class — no confirmation needed regardless of confidence tier, since a wrong lookup just gets re-asked. |

---

## 3. State model

Grounded in three real precedents: Talon's sleep/wake + command/dictation dual mode, Apple Voice Control's overlay-on-demand pattern, and — notably — `jev-voice-browser`'s already-implemented `act / wait / ignore / confirm / disambiguate` policy loop, which is the closest existing analogue to "a Jev-mediated voice UI state machine" in this codebase family. I'm treating that prototype as a prior-art data point to build on, not something to imitate uncritically.

```
[Asleep] --wake phrase / hotkey--> [Listening (armed)]
   ^                                     |
   |                                 partial transcript
   |                                     v
   |                             [Interpreting]  (Jev: is_command, intent, complete — all in parallel, one request)
   |                                     |
   |             is_command low ---------+--- is_command high, intent confident + complete
   |                    |                                    |
   |                    v                                    v
   |               [Ignored]                          confidence tier?
   |           (no feedback; stay armed)                     |
   |                        low target/intent confidence -----+----- high confidence, non-destructive
   |                                |                                       |
   |                                v                                       v
   |                        [Clarifying]                            [Preview] (optional, see below)
   |                     (numbered options,                                 |
   |                      spoken or on-screen,                              v
   |                      no model re-call)                          [Executing]
   |                                |                                       |
   |                       resolved by "N" or -----------------------> [Committed]
   |                       repeat with fix                                  |
   |                                                                        v
   |                                                              [Correction window]
   |                                                        (short grace period: "scratch that" /
   |                                                         re-dictation both accepted, see §4)
   |                                                                        |
   +------------------ "go to sleep" / timeout -----------------  back to [Listening]

   destructive == true  ---->  [Awaiting Confirmation] --"confirm"--> [Executing]
                                                          --"cancel"--> [Listening]  (no penalty, no scolding)

   any stage: recognizer/model error, timeout, or explicit "stop" ---> [Failed / Fallback]
                                                                        (non-voice affordance surfaces:
                                                                         menu, keyboard shortcut, or
                                                                         "say it again" — never a dead end)
```

Key design commitments this implies:

- **Sleep/wake is a real state, not cosmetic.** Talon's evidence is that this is the primary false-trigger defense, doing more work than confidence thresholds alone.
- **"Preview" is conditional, not universal.** For Transforms that materially change meaning (rewrite, translate) or direct actions with UI side effects, show a diff/preview before commit. For low-risk, frequently-repeated actions (start/stop, simple formatting), skip straight to execute — this mirrors TypeSafe's own three-tier confidence guidance (act / proceed-with-caution / don't-act) rather than a single always-preview rule.
- **Disambiguation should not re-call the model.** `jev-voice-browser`'s pattern — top 2–3 candidates get numbered, a spoken digit picks one with zero additional inference — is worth carrying forward: it's both faster and cheaper than asking Jev again.
- **A correction window exists after commit**, not just before it — because both academic sources in §1 show users correct *after* seeing the result, not only mid-command.

---

## 4. Referent strategies — "this," "other one," "again," "not that," and embedded commands

**Referring to prior targets/results.** Cursorless's `StoredTargets`/"that" concept and Rango's `mark <name>` are the two clearest mechanisms found, but both share a real limitation worth naming: a single "last thing" slot is easily clobbered by an intervening command, and neither source I could verify documents a multi-slot history. **Recommendation (not sourced — my own synthesis):** maintain a short *typed* stack — last selection, last transform result, last opened/navigated target, last spoken number — so that "the other one" or "again" can resolve by matching the phrase's implied type against the stack rather than always defaulting to the most recent action regardless of kind. This directly targets a gap I could not find solved in any reviewed system.

**"Not that" / negative correction.** No source gave a first-class negation grammar; Apple's "Correct \<phrase\>" implicitly handles it by surfacing alternates. Practical approach: treat "not that, the other one" as re-triggering disambiguation over the *same candidate set* Jev already scored, rather than as a fresh command — cheap, and matches the "don't re-call the model for disambiguation" principle above.

**"Again."** Rango's precedent (repeating the last scroll/pan direction without re-hinting) suggests "again" should replay the last *action*, holding its target fixed unless the utterance supplies a new one — distinct from "do the same to the next paragraph," which replays the action but *advances* the target.

**Commands embedded in dictated text.** This is the hardest and most under-solved problem across all sources reviewed. The HCI literature (search-derived, not independently verified in full) frames it as the dual-mode/mixed-mode problem: systems either (a) require an explicit mode switch, which users forget they're in, or (b) attempt statistical disambiguation of every utterance, which is exactly the failure mode Jev's own jaggedness documentation warns about — `jev-1.13` "answers the question you wrote... at face value" and is weak at *indirection* (a command hidden inside a sentence is a two-hop inference: "is there a command here" then "where does it start"). Given that, I'd weight this toward **cheap structural cues before invoking Jev at all**: a distinguishing prefix or trailing pause (as `jev-voice-browser` already does by requiring either a 900ms silence or a closed-set phrase to treat something as `complete`), reserving Jev's `is_command` Noul for the genuinely ambiguous middle band rather than as the sole gate. Gist-vs-verbatim framing from Ratnaparkhi et al.-adjacent CUI 2023 work looked directly relevant but its full text was inaccessible to me (403); treat that citation as a lead, not a verified source.

---

## 5. Modality switching and hands-free alternatives to push-to-talk

Sourced precedents, ranked by how "hands-free" they actually are:

1. **Apple Voice Control** is the most complete hands-free precedent: no PTT at all, continuous listening gated by spoken sleep/wake, with numbers/grid overlays as the fallback pointing mechanism when speech alone can't disambiguate a screen location.
2. **Talon's noise triggers** (pop/hiss) hands-free-ify the *clicking* half of the problem specifically, which voice alone is bad at (saying "click" is slower and more fatiguing than a tongue pop).
3. **Talon sleep/wake by voice** — the mic stays open; the state machine, not the hardware, decides whether to act. This is the opposite design axis from PTT (hardware-gated) and is the one to weigh against MacParakeet's existing hotkey-based invocation (`third-hand`'s Control-Space, `macbrow`'s LiveKit voice loop) if a PTT-free mode is wanted.
4. Eye-tracking + voice combinations are commonly discussed in the Talon community as a pairing for pointing without a mouse, but I did not find a primary doc from the sources in scope that specifies the interaction contract precisely enough to cite with confidence — **flagging as a lead, not a sourced recommendation.**

**Recommendation:** offer PTT as the default (safest against false triggers and the most private, since it bounds when audio is processed at all) but treat continuous-listening as a real, supportable second mode gated the way `jev-voice-browser` already demonstrates — a cheap `is_command` Noul plus a required completion signal — rather than treating "always listening" as inherently riskier than PTT. The privacy cost of always-listening is real and separate from the UX cost; MacParakeet's local-first posture argues for continuous-listening being opt-in and clearly indicated (see §6), not default-on.

---

## 6. Proactive discoverability without noisy overlays

The sources split cleanly into two philosophies:

- **Ambient/persistent** (Talon+Cursorless hats): every token gets a colored hat, all the time, while Cursorless mode is active. This is the "noisy" end — accepted by its power-user audience specifically *because* they opted into a mode where visual density is the price of precision addressing.
- **On-demand/transient** (Apple's "show numbers," Cursorless's separate cheatsheet, Rango's hint-on-trigger): the affordance is summoned by the user's own request and disappears after use.

For a mainstream dictation/meeting app, the on-demand family is the better fit. Concretely:

- No always-on visual overlay for discoverability. Instead, a **pull-based reference** (a cheatsheet panel or "what can I say" query) reachable by voice or keyboard, following Cursorless's separation of the editing surface from its own documentation.
- **Confidence-gated hinting**: only render a transient numbered/labeled overlay (Apple/Rango-style) at the moment Jev's confidence actually falls into the disambiguation band — i.e., discoverability affordances double as error-recovery affordances, appearing exactly when needed and nowhere else.
- A quiet, persistent **command log** (not a HUD) — a small scrollable strip of "heard: X → did: Y" — gives ambient discoverability and a correction/undo entry point without painting anything onto the user's actual content. This is my own synthesis, not directly sourced, but it's a direct answer to "discoverability without noise": the log is optional to look at, unlike a canvas overlay.

---

## 7. Fast-path vs. larger-model escalation

This is where the local Jev documentation is unusually concrete and worth leaning on directly, since it's a stated design contract rather than a guess:

- Jev is explicitly a **System One** model (Kahneman framing, per TypeSafe's own docs): fast, typed, calibrated judgments — not generation. Its documented failure modes (jaggedness doc) are counting, math, date arithmetic, multi-hop indirection, and text generation — precisely the operations a voice command pipeline needs *somewhere*, just not from Jev.
- `jev-voice-browser` and `macbrow` both already encode a working three-tier ladder:
  1. **Code-only, zero-latency**: closed-set phrases resolved without any model call (e.g., `macbrow`'s routing candidates are pre-filtered to only the tools that apply to currently-open apps before Jev ever sees them; `jev-voice-browser` extracts candidate spans by regex before asking Jev to *pick*, never to generate).
  2. **Jev fast path (~250–350ms measured** in `jev-voice-browser`, ~300ms in `macbrow`): parallel Choice/Score/Noul questions — intent, target, completeness, destructiveness — answered in one request.
  3. **Escalation to a generative/System Two model**: reserved for free-form text (Transform prompt authoring, a truly novel action `macbrow` has no tool for), with the generated artifact then *cached* and checked, not re-generated every time.
- The confidence-threshold pattern from TypeSafe's own docs (high → act, medium → confirm/verify, low → don't act, and *stakes-dependent* thresholds — a destructive action needs a higher bar than a read-only one) is directly reusable as the gate between tiers 2 and 3, and between "execute silently" and "confirm first" within tier 2.

**Recommendation:** keep this three-tier shape for MacParakeet's own voice feature. The interesting design work is less "should we escalate" (the local prototypes already answer that) and more *what counts as stakes* for a dictation/meeting app specifically — e.g., overwriting dictated text a user hasn't saved yet should probably sit at the same confirmation tier as `macbrow`'s "buying, checkout, payments," even though it looks harmless compared to a browser action.

---

## 8. Usability evaluation and latency criteria — **PROPOSED, NOT MEASURED**

No user testing has been conducted for this report; the following are targets to validate, not results.

**Latency ladder** (anchored to Levinson & Torreira's ~200ms human turn-taking baseline, Nielsen's classic 0.1s/1s/10s response-time doctrine, and the ~300ms Jev round-trip actually measured in `jev-voice-browser` on real hardware):

| Interaction class | Proposed target | Rationale |
|---|---|---|
| Closed-set commands resolved in code (stop, undo, pause) | **< 150ms** end-to-end | Below the ~200ms human turn-taking gap so it reads as instantaneous, not "the computer responding." |
| Jev-mediated intent + target resolution (single request) | **< 400ms** | Above Nielsen's 0.1s "direct manipulation" bar but comfortably inside his 1s "uninterrupted flow of thought" bar; matches the ~300–350ms already measured for Jev in this codebase family. |
| Disambiguation round-trip (numbered pick, no model re-call) | **< 200ms** from spoken digit to action | No inference cost, so should be near-instant; a slow disambiguation defeats the point of avoiding a second model call. |
| Escalation to a generative/System-Two model (Transform authoring, novel action synthesis) | **Explicit "thinking" affordance if > 800ms–1s** | Nielsen's 1s threshold is where users notice a delay; beyond it, silence reads as failure, not speed. |

**Usability metrics** (methodology drawn from general VUI evaluation practice — task success rate, correction rate, turns-to-completion, and a post-task SUS-style questionnaire — [general VUI methodology overview](https://dl.acm.org/doi/10.1145/3772318.3791747), [SUS validation for VUIs](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10909179/)):

- **Task success rate** per task family from §2, measured separately, since "session control" and "referential follow-up edits" have very different inherent difficulty.
- **Correction rate**: fraction of commands followed within N seconds by a "scratch that"/re-dictation/undo — a proxy for silent failures that succeeded technically but not intentionally.
- **Referent-resolution accuracy**: specifically for "that"/"the other one"/"again," since §4 identifies this as the highest-uncertainty area — track how often the resolved target matches user intent vs. requires a follow-up correction.
- **False-trigger rate** in continuous-listening mode: utterances not addressed to the system that were nonetheless acted on — this is the single most reputation-damaging failure mode and should be tracked separately from ordinary task failure.

---

## 9. Ideas that improve on demo-style interfaces

Most demo voice UIs (and, candidly, the local reference prototypes are explicit about being demos/prototypes) either narrate every action ("OK, doing X...") or confirm nothing at all, use a single referent slot, and support exactly one correction grammar. Three concrete improvements:

1. **Calibrated verbal economy instead of constant narration.** Use TypeSafe's own three-tier confidence framing as a *speech budget*, not just an action gate: stay silent on high-confidence low-stakes actions, give a brief non-verbal cue (a soft tone or the transient log entry from §6) at medium confidence, and reserve actual spoken clarification for genuinely low-confidence or destructive cases. Nearly every demo system narrates uniformly regardless of stakes, which trains users to tune it out — the opposite of what a confirmation is for.
2. **Dual correction grammar by default, not by mode.** Per Ghosh et al.'s finding that users spontaneously switch between Commanding and Re-dictation depending on the edit's complexity, support both without asking the user to declare which one they're using — accept "replace go with goes" *and* simply re-saying "he goes there" as equally valid repairs to the same error. Most systems (Serenade included, per the practitioner account in §1) pick one grammar and force users into it.
3. **A typed multi-slot referent history instead of a single "that."** As argued in §4, this is a gap in every referent system I could verify (Cursorless's stored-target and Rango's `mark` are both effectively single-slot or explicitly-named). A short stack of typed "last things" (last selection / last transform result / last navigation target / last spoken number) lets "the other one" and "again" disambiguate by type rather than pure recency, which should reduce the referent-resolution failures flagged as the highest-uncertainty metric in §8.
4. *(Bonus, lower confidence)* **Discoverability that doubles as error recovery.** Rather than a help overlay and a disambiguation overlay being two different UI surfaces (as they effectively are in Apple Voice Control — numbers/grid vs. the Commands list in System Settings), unify them: the same transient, numbered affordance that appears when Jev's confidence dips into the disambiguation band (§3, §7) *is* the discoverability mechanism — seeing it teaches the vocabulary at exactly the moment it's needed, rather than requiring a separate "what can I say" lookup.

---

## Compact decision table

| Confidence tier (Jev) | Stakes | System response | Feedback | Model calls |
|---|---|---|---|---|
| High (`is_command`≥0.5, intent conf. high) | Low/reversible | Execute silently | Transient log entry only | 1 (fast path) |
| High | Destructive/hard-to-reverse | Confirm-then-execute | Spoken/visual confirm prompt, wait for "confirm"/"cancel" | 1 (fast path) + 0 for confirm parse (closed-set) |
| Medium (split top candidates) | Any | Disambiguate | Numbered overlay (transient, Apple/Rango-style), spoken digit resolves | 1 (no re-call for disambiguation) |
| Low (`is_command` low or intent `none`) | — | Ignore | None (stay armed) | 1, cheap Noul only |
| Command needs free-form generation (novel Transform, unseen action) | Depends on generated artifact | Escalate to System Two, cache result, re-verify with Jev before commit | "Thinking" affordance if >800ms–1s | 1 fast-path (routing) + 1 generative + 1 Jev re-check |
| Recognizer/timeout/explicit "stop" | — | Fail to a non-voice affordance (menu, shortcut, retry) | Clear, non-blaming failure message | 0 |

---

**Overall uncertainty flags to carry forward:** (1) Cursorless's exact end-user "that" phrasing wasn't confirmed against a single canonical doc page — I only verified the underlying mechanism exists. (2) The "gist vs. verbatim" CUI 2023 paper and the full Ghosh et al. 2020 text were both inaccessible (403/paywall) — cited via abstracts and secondary coverage only. (3) Eye-tracking + voice pairing in the Talon ecosystem is a known community topic but I found no primary spec precise enough to cite as a sourced recommendation. Everything in §8 and the "bonus" idea in §9 is explicitly my own synthesis, not drawn from a tested system.
