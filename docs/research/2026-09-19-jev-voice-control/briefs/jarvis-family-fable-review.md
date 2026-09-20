# Brief: Fable 5.1 low — Jarvis-family + numbered picks

**Date:** 2026-09-20
**Audience:** Claude Fable 5.1 via `claude -p`, effort **low**
**Output:** short design critique. Do not edit files.

Read:

1. `docs/research/2026-09-19-jev-voice-control/jarvis-family-primitives.md`
2. `Sources/MacParakeetCore/Services/VoiceControl/VoiceControlSessionGrammar.swift` (`VoiceControlSpokenPick`)
3. `VoiceControlTypes.swift` (`.pick`)
4. `VoiceControlTurnRunner.swift` (`clarify`, `resolvedPick`, `alternativeDecision`)
5. `VoiceControlCommandRouter.swift` (ambiguous `click`)

## Settled

Native AX. Confirm only pay/delete/send. No wake word. Isolated-utterance grammar. Filler words never authorize.

## Report

Markdown, under 700 words.

1. Verdict on the Jarvis extraction (faithful / material misses)
2. Numbered-pick invariants: isolated index, IDs not labels, `the other one` is not 1, pay/delete/send still confirm after a pick
3. Traps
4. Adopt / refuse / later

Do not propose CDP, wake words, or on-screen overlays for this pass.
