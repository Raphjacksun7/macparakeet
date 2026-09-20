# Voice reply (TTS) and Jev CLI — later

Date: 2026-09-19. Notes only. Do not implement in the current Voice Control loop.

## Local TTS (later)

The magic loop can already execute without talking back. Spoken replies come after the
typed/spoken command reliably drives Chrome, Notes, and similar everyday apps.

Detailed research (APIs, existing MacParakeet audio, Jev CLI repos, eval workflow):
[local-tts-and-jev-cli.md](local-tts-and-jev-cli.md). Do not implement TTS or adopt Jev CLI as the HTTP client in this loop.

Use `AVSpeechSynthesizer` on-device for short status lines: “Looking at Chrome…”,
“Need a destination”, “Done — check the results.” Do not read page contents, field
values, or API errors. Barge-in: hold-to-talk or Stop cancels speech. Personal Voice
is optional later, not a v1 requirement. MacParakeet already owns the microphone
stream; TTS should be a small playback helper, not a second speech runtime.

Do not pull in ElevenLabs, cloud TTS, or a generic “voice assistant” stack.

## Jev CLI tools (not now)

[Jev CLI Tools](https://mrjev.com/projects/category/cli/) are Unix filters that send
typed System One questions. Useful examples for later evals: `jev-repl` for question
wording, `tumf/jev-cli` as a scratch client. We already call
`https://api.typesafe.ai/v1/systemone` from `JevDecisionClient`. Do not replace that
client, do not shell out with the API key, and do not pipe live page text into a CLI.

For evals later: keep `latest.json` (instruction, control labels, stage traces) as the
local corpus. Optional follow-up is a content-minimized Jev request/answer sidecar
(question ids, choices, scores — no field values or keys).
