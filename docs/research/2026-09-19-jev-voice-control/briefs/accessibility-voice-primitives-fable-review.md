# Consultation brief: accessibility / voice primitives (not Jev)

**Date:** 2026-09-20
**Audience:** Claude Fable 5.1 via `claude -p`, effort **medium**
**Output:** a design critique. Do not edit files. Parent will adopt or refuse in code.

Read these, then write the report:

1. `docs/research/2026-09-19-jev-voice-control/accessibility-voice-primitives.md` (parent extraction; primary)
2. The three reference checkouts under `/Users/dmoon/code/macparakeet/references/` — `blind.sh/`, `VoiceCraft/`, `skales/` (README + CHANGELOG + `docs/skales-guide.html` only for Skales; source was removed)
3. Current MacParakeet surfaces: `Sources/MacParakeet/App/VoiceControlCoordinator.swift` (literalMode), `Sources/MacParakeetCore/Services/VoiceControl/VoiceControlCommandRouter.swift` (help + type prefix), `Sources/MacParakeetCore/Services/VoiceControl/VoiceControlTurnRunner.swift` (`offerConfirmation`), `spec/contracts/voice-control.md` (literal grammar)

## One concern

These three repos are **not Jev**. They are accessibility / desktop-agent primitives. What should MacParakeet Voice Control actually take, and what is a trap?

## Settled product (do not reopen)

Native Accessibility only. Confirm only pay/delete/send. Local STT. TTS later = `AVSpeechSynthesizer`. Jev is a judge of closed Choices, never a worker that emits AppleScript/Python. No wake word. Voice Control is a dedicated invocation, separate from ordinary dictation. DEBUG `--enable-voice-control`.

## Parent's draft dispositions (challenge them)

- **Adopt:** named command vs typing session, isolated-utterance grammar, accessibility aliases (`typing mode` / `start typing` / `activate type` enter; `stop typing` / `command mode` leave; `command stop` pauses). Do not parse mode phrases out of the middle of typed prose.
- **Adopt:** confirmation copy names the control, the consequence, and that Cancel task stops here (nothing is paid / deleted / sent). No always-allow for pay/delete/send. Filler words never authorize.
- **Adopt:** Help advertises typing mode when a focused editable field exists.
- **Refuse:** LLM → osascript / pyautogui / selenium / `eval`. Pixel mouse grids. Confirm-every-click Safety Mode. Wake word. Cloud STT/TTS. Generated code execution. Shutdown-by-substring.
- **Later:** barge-in on spoken status (needs TTS). Numbered AX overlays. Always-allow only if ever scoped to a non-commitment class.

## Report shape

Markdown. Sections:

1. Verdict on the extraction (faithful / four material misses)
2. What is a real primitive vs folk accessibility theatre
3. Mode grammar: isolated utterance vs substring (VoiceCraft `mode reset` hazard)
4. Confirmation cards: Skales always-allow vs MacParakeet pay/delete/send
5. What to implement this pass vs refuse vs later
6. Traps that would make Voice Control less reliable
7. Open questions

Stay under ~1200 words. Prefer invariants. Do not propose a second planner, CDP, screenshots-in-the-loop, or copying Skales product chrome.
