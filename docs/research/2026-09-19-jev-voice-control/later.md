# Later

Ship the silent, native loop first. Nothing below is required to keep unique local tools working.

## Still open on this experiment

- One live native Flights search through to a results list
- Integrated hold-to-talk microphone path, with dictation / Transform regression
- Unconstrained Jev on generic pages is still `operation` + `target_*`. Documented leftover; do not pretend a footer link is a landing
- Spoken-tool presses that return Accessibility “unknown” still pause. Completing them needs a compilation origin so plan-driven presses keep pausing
- Join-space for `type` assumes the caret is at the end of the field value

## Next tools

- Numbered **on-screen** overlays (Apple “show numbers”). The panel list already ships
- Named references (`mark as inbox`, then `click inbox`)
- `File > Export` and other menu paths
- Container-scoped scrolling (“a little more”, “to the bottom”)
- One named missing-slot question (“Need a destination”)
- Semantic freshness guards and loop-breaking on (action, screen signature), excluding clocks

## Transplants from typesafe-computer-use

Source review and plan: `docs/research/2026-09-20-typesafe-computer-use/` and `plans/active/2026-09-20-voice-control-transplants.md`. Done: probabilities in the log, replayable observations, `voice-control replay`, inbox dry run, timing line. Next: pure `AXTreeWalk` over an injectable source with off-screen pressables; lean Tier-3 request (`kind` / `target` / focused `value`); on-device Vision OCR as a second source of targets and state.

## Spoken replies

On-device `AVSpeechSynthesizer`. Short templated lines: “Need a destination”, “Done — check the results.” Do not read page contents, field values, or API errors. Hold-to-talk or Stop cancels speech. No ElevenLabs, no cloud TTS, no personality voice.

## Jev CLI

Unix-filter CLIs are useful later as an eval workbench on **redacted** fixtures. Production already calls System One over HTTPS from `JevDecisionClient`. Do not shell out with the key, and do not replace that client.

## Explicitly out of scope

Chrome DevTools Protocol, a required extension, an automation browser, screenshot-to-cloud, generated AppleScript or tools, OCR as a primary grounder, OpenRouter planners, local HTTP harnesses, coordinate clicking as targeting, always-on listening, unattended send/book.
