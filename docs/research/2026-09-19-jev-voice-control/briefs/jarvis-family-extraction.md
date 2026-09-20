# Brief: Jarvis-family reference extraction (not Jev)

**Date:** 2026-09-20
**Audience:** Claude Sonnet 5 via `claude -p`, effort **medium**
**Output:** Markdown report in the final answer. Do not edit files. Do not run the reference apps.

## One concern

Extract **interaction primitives** from a hobby/assistant checkout that MacParakeet Voice Control can adopt. These are demos. The *design* matters, not the feature list.

## Settled product (do not reopen)

Native macOS Accessibility only. Confirm only pay/delete/send. Local STT. TTS later = `AVSpeechSynthesizer`. Jev is a judge of closed Choices, never a worker that emits scripts. No wake word. Voice Control is a dedicated invocation, separate from ordinary dictation. DEBUG `--enable-voice-control`. Do not copy Iron Man chrome, personality, or cloud APIs.

## Report shape

Markdown, under ~900 words.

1. What this repo actually is (licence, language, one-sentence)
2. Real primitives vs theatre (wake word, keyword soup, generated scripts, cloud STT)
3. UI/UX ideas worth stealing (status visibility, correction, help, confirmation, silence)
4. Adopt / adapt / refuse / later table with MacParakeet surface names if known
5. Traps that would make Voice Control less reliable

Cite `file:line` when you have them. Do not treat README marketing numbers as facts.
