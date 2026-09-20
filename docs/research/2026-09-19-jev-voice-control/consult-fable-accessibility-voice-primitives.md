# Independent Fable consult — accessibility / voice primitives

Requested `claude-fable-5-1`, effort **medium**, through `claude -p` on 2026-09-20. Design critique against [briefs/accessibility-voice-primitives-fable-review.md](briefs/accessibility-voice-primitives-fable-review.md) and [accessibility-voice-primitives.md](accessibility-voice-primitives.md). Not runtime evidence. Parent dispositions after the report.

---

## Parent dispositions (after the consult)

**Adopted**

- Confirmation copy names the compiled effect. Decline matches the panel **Cancel task** control and does not claim the rest of the task was undone. Class-specific “Nothing is paid / deleted / sent.” Unknown: “I can’t tell what {label} does. Press it anyway?”
- Spoken accept while a confirmation is pending: only `yes` / `confirm` / `confirm this action`. `ok` / `okay` / `alright` / `yep` do not authorize.
- Isolated `no` / `cancel` / `cancel task` decline a pending confirmation (same as Cancel task). `confirm` without a pending prompt is a normal instruction, not a silent no-op.
- Entering or using literal mode dismisses a pending confirmation or clarification with an explicit message. Literal payloads skip `takeClarification` and are not treated as corrections.
- Grammar normalizes internal separators (`command-mode`, extra spaces).
- Consecutive `type` utterances prepend a joining space when appending at the caret onto a non-whitespace character, unless the payload starts with punctuation.
- Payment word list adds `order` and `booking`. Not `book` / `reserve` (Address Book, calendar Reserve).

**Refused**

- Always prepend `type ` so `type literally` cannot insert reserved phrases. Keep `type literally command mode` as the documented escape.
- Require the class word (“payment”) on spoken accept. Too much friction for a hands-free `yes`.
- ML punctuator in Voice Control typing. Dictation owns punctuation.
- `book` / `reserve` as payment tokens.
- Everything already refused in the extraction (LLM→script, pixel mouse, Safety Mode every-click, always-allow, wake word, cloud STT).

**Later**

- Spoken confirmation prompt and mode announcement via `AVSpeechSynthesizer` (ahead of barge-in).
- Numbered AX overlays.
- Hotkey diagnosability (“last key seen”) from Skales AIPointer docs.

Open questions Fable asked, answered in code: entering literal **cancels** a pending confirmation with a message; separators live in the **router**; `type literally` remains an escape; `command stop` still pauses and leaves literal mode on.

---

All reading is done. Here is the report.

# Review: accessibility / voice primitives extraction

Reviewer: Claude Fable 5.1, 2026-09-20. Read the extraction, all three checkouts (Skales as docs only), and the four MacParakeet surfaces plus the new `VoiceControlSessionGrammar` and its tests. No files edited, nothing executed.

## 1. Verdict on the extraction

Faithful on sources. Every cited claim checks out against `blind.sh`, `v3.py`, `Ideas.txt`, the Skales README, guide, and CHANGELOG. Dispositions are right. Four material misses, all on the MacParakeet side of the mapping:

1. **The new confirmation copy over-claims.** "Cancel leaves the app unchanged" is false whenever the task already filled a form. The contract itself says the UI must never claim an effect was undone. The sentence should describe the skipped step, not the app.
2. **The accept token is cheaper than the decline.** `submit` treats `yes`, `okay`, `ok` as confirmation. In hands-free mode with a pay confirmation pending, room speech containing "okay" pays. blind.sh's default-No transfers as "no filler word authorizes", not merely "deny is the non-action".
3. **Literal mode leaks in the coordinator.** A typed utterance while a clarification is pending goes to `runner.clarify` because `dispatch` calls `takeClarification()` unconditionally. A typed utterance while a confirmation is pending silently discards it with no message. Inside literal mode, `type literally X` is still parsed as a prefix, so literal mode is not literal.
4. **Modality.** blind.sh is for people with low vision, and its only confirmation is a visual dialog showing an osascript string. The transferable primitive is "confirm in the modality the user commands in". The extraction files TTS under barge-in. It is the precondition for the confirmation card being accessible at all.

Factual nit: VoiceCraft's type mode never worked as shipped. `model = "test"` at `v3.py:100`, so `restore_punctuation` raises. Describe it as a design, not a working mode machine.

## 2. Real primitive vs folk theatre

Real:
- Whole-utterance grammar with a closed set of phrases. The current implementation does this.
- Compiled effect named at the boundary. Target label, not transcript.
- Consequence decided from observed control identity, never from model self-report. `VoiceControlConsequencePolicy` already lets local evidence win.
- Honesty when a capability cannot execute. "Focus one editable field" beats a fake mode.
- Illegal events omitted by the host rather than discouraged. Same shape as Skales Plan/Ask refusing write tools.
- Failure direction: a grammar miss must produce typed text, never a dispatched action.

Theatre:
- Confirm-every-action. Habituates the user to say yes.
- Always-allow with a reach sentence. Skales words it honestly, but a one-tap "always" on voice is exactly the accidental send.
- A translucent waveform window as the mode indicator.
- Pixel grids and relative mouse moves.
- Per-turn temp directories as a safety story. Snapshot identity already isolates turns here.
- Skales "stops when done or before a consequential action". A runner definition, not an import.

## 3. Mode grammar

Invariants the grammar should hold, and mostly does:

- In literal mode the only non-typing outcomes are exit and pause. Both are harmless.
- Match the normalized whole utterance. Never substring. VoiceCraft's `"mode reset" in text` at `v3.py:468` is the hazard, and the extraction's test `please mode reset the form` is the right regression.
- The escape phrase is never inserted, and no partial payload is typed.
- A missed exit types words. A false exit drops one sentence. Neither dispatches an action.

Gaps:
- **Segmentation is the real boundary.** In hands-free mode, "isolated" means 900 ms of silence. "...and then command mode" spoken without a pause is typed. Correct failure direction. Document it and do not add a substring fallback to fix it.
- **Normalization.** Only leading and trailing punctuation is trimmed. `command-mode` or double spaces miss. Collapse internal non-alphanumerics to one space before the set lookup.
- **`type literally` inside literal mode** should type those words. Recommend `literalInstruction` always prepend `type `, so the only escapes are the grammar's.
- **Clarification and confirmation pending.** Entering literal mode should cancel a pending expected response with a message, or the literal branch should bypass `takeClarification`.

## 4. Confirmation cards

Skales cards say three things: the action, what no does, how far always reaches. Adopt the first two. Refuse the third outright, and the reason is structural: the consequence class is a label-word heuristic. An always-allow scoped to a heuristic is scoped to nothing.

Copy per class, replacing the "unchanged" sentence:

```
Confirm payment on Pay now? Cancel skips this step. Nothing is paid.
Confirm deletion on Trash? Cancel skips this step. Nothing is deleted.
Confirm send on Send? Cancel skips this step. Nothing is sent.
```

For `.unknown`, replace "unverified consequence" with plain words: "I can't tell what this control does. Press it anyway?"

Spoken accept: drop `ok` and `okay`. Keep `confirm` and `yes`. Consider requiring the class word on payment. Keep the 20-second expiry and the rule that Return in the panel never confirms.

## 5. This pass / refuse / later

This pass:
- Copy fix above, with a test that the prompt never contains "unchanged" or "always".
- Remove `ok`/`okay` from the accept set.
- Fix the clarification leak and surface "confirmation dismissed" when a literal utterance replaces a pending one.
- Decide `type literally` inside literal mode. Recommend literal.
- Normalization of internal separators.
- Extend the payment word list. See section 6.

Refuse: everything in the parent's list, plus an ML punctuator in Voice Control typing. Punctuation is Dictation's product.

Next slice, not later: **utterance joining.** Consecutive hands-free literal utterances insert with no separator, since `insertText` replaces the selected range only. The router sees the focused target's value and can prepend one space deterministically when the preceding character is not whitespace and the payload does not start with punctuation. Without this the typing session is unusable for prose.

Later: spoken confirmation prompt and spoken mode announcement via `AVSpeechSynthesizer`, before barge-in. Numbered AX overlays.

## 6. Traps

- **Filler-word authorization** in hands-free mode, above.
- **Name heuristic false negatives.** The payment list is `pay, purchase, checkout, buy, payment, subscribe`. "Place your order", "Book", "Reserve", "Complete booking" are ordinary and proceed without confirmation. Add `order`, `book`, `reserve`, `booking`.
- **Silent dismissal** of a pending confirmation by any new utterance.
- **Over-claiming** what cancel does.
- **Substring anywhere in command routing.** Any `contains` on the utterance is VoiceCraft's keyword soup. Current router uses prefixes and exact sets. Keep it that way.
- **Hidden mode.** Literal mode is visible only in the panel today. A voice-first user cannot see it. Until TTS, keep the entry message and never let End preserve literal mode without saying so.
- **Skales marketing numbers** treated as facts. The extraction already flags this.

## 7. Open questions

1. Should entering literal mode be refused while a confirmation is pending, or cancel it with a message?
2. Who owns separators between literal utterances, router or adapter?
3. Is `type literally` a command inside literal mode?
4. Should spoken payment confirmation require the class word?
5. What does `command stop` mean in literal mode? It revokes advancement but leaves literal mode on, so the next utterance types again. Is that pause, or should it be stop listening?
6. When TTS lands, is the spoken confirmation prompt ahead of barge-in in priority?
