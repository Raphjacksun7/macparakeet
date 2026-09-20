# Brief: Fable 5.1 medium — tools-first macOS control, Jev as chooser

**Date:** 2026-09-20
**Audience:** Claude Fable 5.1 via `claude -p`, effort **medium**
**Output:** design critique. Do not edit files.

## One concern

Should MacParakeet Voice Control treat native Accessibility operations as **host tools** (pre-Jev computer control), with Jev only choosing among competing tools — not as the default brain, and not as an extra safety veto on ordinary actions?

## Settled — do not re-litigate

- Native AX only. No CDP, extension, wake word, cloud STT, OCR, on-screen number overlays this pass.
- Confirm only pay / delete / send. Ordinary navigation, unique clicks, typing, scrolling proceed without a prompt.
- Speech stays local. DEBUG `--enable-voice-control`.
- Do not claim live Flights results or microphone qualification.
- Ambition over model-typical over-safety: unique named controls should execute locally. Do not recommend Jev as a second “are you sure?” on ordinary tools.

## Context

The PR has become Jev-shaped in the write-up. The actual runner is already host-compiled AX: press, setValue, insertText, select, scroll, key, activateApp. Unique `click Save` is local. Unique Gmail Compose is a special-case local tool. Everything else that is not a prefixed command falls through to unconstrained Jev (`operation` + `target_*`).

Pre-Jev references (`third-hand`, `jev-use` AX half, `mac-use`, Apple Voice Control, Rango names): match by role+label, skip if already satisfied, rematch after latency, keys are keys.

Parent is implementing this pass (tell us if any is a trap):

1. **Bare unique label is a tool.** Saying `Save` (or `the Save button`) presses the unique Save. 2–6 duplicates → numbered panel pick. Goals longer than a name do not steal.
2. **`press return` / `press escape` / reserved keys are keys**, not a hunt for a button named Return. `click Return` still targets a control.
3. **Skip type when the focused field already holds the requested text** (`.information`, not `.directCompleted` — the runner treats unverified `.directCompleted` as a pause).
4. **Click remainder may unique-prefix match** (`click Search` → unique `Search flights`).
5. **Jev is not a sensitivity guard.** Confirmation copy is the guard. Jev chooses among competing landings / unconstrained leftovers only.

Read:

- `docs/research/2026-09-19-jev-voice-control/pr-description-draft.md`
- `north-star-computer-use.md` §§2.4, 2.5, 2.11 (third-hand, jev-use, mac-use/Rango)
- `VoiceControlCommandRouter.swift`
- `VoiceControlTurnRunner.swift` (`bind`, `directCompleted`, `isRepeated`)
- `NativeVoiceControlAdapter.swift` (`execute` snapshot-id + 20s)

## Report

Markdown, under 900 words.

1. Verdict: tools-first vs Jev-default (adopt / amend / refuse)
2. Traps in the five parent upgrades (especially bare labels vs Flights goals, keys vs buttons, skip-type vs insert join-space)
3. What Jev should still do
4. What must stay later (overlays, TTS, menus-as-paths)
5. Fresh-eye silences in the current router/runner/adapter that parent should fix now if cheap

Do not propose CDP, wake words, screenshot-to-model, or widening confirmation.
