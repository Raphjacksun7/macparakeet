# Local TTS and Jev CLI tooling

**Date:** 2026-09-19. **Status:** research only; no implementation.

---

## 1) Local TTS for voice-control replies

### macOS APIs (short agent replies)

| API | Role | Quality / latency for 1–2 sentence replies |
|-----|------|---------------------------------------------|
| **`AVSpeechSynthesizer`** (`AVFoundation`) | Primary on-device TTS | Best fit. System voices (e.g. Samantha, Daniel) are adequate for status/clarify/confirm. Cold first utterance ~200–500 ms; pre-warm the voice instance. `AVSpeechUtterance` + delegate for start/finish/cancel. |
| **Personal Voice** | Optional voice quality | User-enrolled only (Settings → Accessibility → Personal Voice; macOS 14+). Speaks as the *user’s* voice—not an agent persona. Useful for accessibility parity, not required for v1. Selected via `AVSpeechSynthesisVoice(identifier:)` when available. |
| **`Speech.framework`** | On-device **recognition** only | Already covered by local STT. **Not** a TTS path on macOS. |

No cloud TTS needed for v1 if replies stay templated and short. FluidAudio’s PocketTTS/Kokoro stack (`spec/06-stt-engine.md`) is STT-engine baggage, not wired to Voice Control.

### What MacParakeet already has

- **No TTS.** Grep of `Sources/` finds no `AVSpeechSynthesizer` / speech synthesis.
- **UI chimes only:** `Sources/MacParakeet/Views/Components/SoundManager.swift` — preloaded `AVAudioPlayer` + `NSSound` fallbacks (`recordStart`, `recordStop`, `transcriptionComplete`, etc.). Respects macOS “Play sound effects.”
- **Voice Control feedback is visual:** panel messages via `VoiceControlCoordinator` / `VoiceControlTurnRunner`; traces in `VoiceControlTraceStore` (`latest.json`, `/tmp/macparakeet-voice-control/`). `native-accessibility-direction.md` explicitly defers conversational TTS confirmation.
- **Mic path:** `VoiceControlSpeechSession` on `SharedMicrophoneStream` + `STTScheduler`; `VoiceControlSpeechRevocation` already stops in-flight work when new speech arrives—reuse this pattern for barge-in over TTS.

### Minimal v1 (when built—**not now**)

| Speak | Never speak |
|-------|-------------|
| One-line clarify (“Which date?”) | Page labels, field values, candidate lists |
| Destructive confirm summary (amount/recipient/action, no full UI readout) | User instruction, Jev reasoning, API errors with detail |
| Hands-free session bookends (“Listening”, “Stopped”, “Done”) | Transcripts, corrections word-for-word, secrets |

**Barge-in:** `stopSpeaking(at: .immediate)` on hold-to-talk press, new `speechBegan`, Escape/Stop, or session end. Prefer **chime** (`SoundManager`) for low-stakes ack; reserve speech for clarify/confirm/destructive.

### Recommendation

**Later, not now.** Ship Voice Control with panel text + existing chimes; evaluation gates (`evaluation.md`, plan acoustic row for “TTS and Bluetooth”) are unmet. TTS adds mic echo, Bluetooth full-duplex, and endpointing coupling without unblocking core speak→act→verify.

### One-week slice (post–v1 ship)

1. `VoiceControlSpeechReply` actor: `AVSpeechSynthesizer`, pre-warmed voice, max ~120 chars, cancellable.
2. Hook `VoiceControlCoordinator` clarify/confirm/stop paths only; settings toggle default off.
3. Duck/cancel TTS when `VoiceControlSpeechSession` signals capture; reuse dictation media-pause policy if speaker bleed appears.
4. Qualification: scripted replies + hold-to-talk interrupt + Bluetooth matrix in `scripts/dev/voice-control/`.

**Touch files:** new `Sources/MacParakeetCore/Services/VoiceControl/VoiceControlSpeechReply.swift`; `VoiceControlCoordinator.swift`; optional `VoiceControlPanel.swift` toggle; extend `SoundManager` only if adding a dedicated VC chime.

---

## 2) Jev CLI ecosystem ([mrjev.com CLI category](https://mrjev.com/projects/category/cli/))

### What it is

Community **Unix filters and REPLs** around TypeSafe **System One**: stdin/text/JSON in → typed **Noul / Choice / Score** out → stable exit codes or JSON. Complements, not replaces, in-app HTTP. MacParakeet already posts to `https://api.typesafe.ai/v1/systemone` with `jev-1.13.0` in `JevDecisionClient.swift` and logs sanitized traces in `VoiceControlTraceStore`.

### Repos: useful now vs later

| Repo | URL | Verdict |
|------|-----|---------|
| **jev-ts-repl** (`jev-repl`) | https://github.com/aoprisan/jev-ts-repl | **NOW** — REPL + headless `jev run/json/check/cost`; **mock mode without API key**; `.jev` sketch pages; `:ts`/codegen mirrors request shapes. Best for iterating question wording in `routing-catalog.md` before Swift changes. |
| **SemDecide** | https://github.com/sharziki/semdecide | **LATER** — `is`/`choose`/`score`/`filter`/`guard` with versioned JSON + grep-like exit codes. Useful once frozen observation+transcript fixtures exist for batch route eval; `guard` recipe interesting for destructive-policy prototyping. |
| **typesafe-ai-playground** | https://github.com/markjaquith/typesafe-ai-playground | **LATER / narrow** — Rust experiment CLI (PHI scan, comment review, load-bearing heat map). Patterns for multi-head fan-out, not voice-control traces. |
| **jeff** | https://github.com/Alurith/jeff | **Skip** — Go code-quality linter over source files. |
| **jev-semgrep**, **commit-miner**, **jev-commit**, **jev-shell-history**, **triagedy** | various | **Skip** for VC eval (semantic grep, commits, shell history, alert triage). |

**Already in-repo (prefer over CLI for runtime eval):** `VoiceControlTraceStore` session logs; `scripts/dev/voice-control/` AX/browser fixtures; `evaluation.md` replay layers; injectable transport on `JevDecisionClient`.

### What NOT to adopt

- **Duplicate HTTP client** — keep `JevDecisionClient` actor (Keychain, consent, strict validation, size caps). Do not embed `jev-repl` Client in the app.
- **Leaking keys** — fixture README already forbids keys in probes; never commit `TYPESAFE_API_KEY` into `.jev` pages, CI env in logs, or trace JSON.
- **Capturing page text** — reject playground/jeff-style “send full file/page to API” for eval; MacParakeet policy is bounded snapshot summaries and observed target IDs only (`JevDecisionClient` caps). SemDecide batch runs belong on **synthetic/redacted** fixture exports, not live `latest.json` with real labels from user sessions.

### Practical NOW workflow

1. Sketch decision heads in `jev-repl` mock mode → `:save` `.jev` → `jev check` / `jev json`.
2. Compare mock vs live on **redacted** fixture utterances before updating Swift question builders.
3. Keep authoritative eval traces in `VoiceControlTraceStore`; use CLI for **schema/question R&D**, not production telemetry.
