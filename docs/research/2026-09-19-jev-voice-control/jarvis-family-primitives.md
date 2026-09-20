# Jarvis-family and intent-capture primitives

**Date:** 2026-09-20. **Status:** source extraction plus MacParakeet mapping. Not a claim that live Flights results or the microphone path have passed.

**New checkouts** (cloned into `/Users/dmoon/code/macparakeet/references/` on 2026-09-20; gitignored):

| Folder | Upstream | What is actually in the checkout |
|---|---|---|
| `J.A.R.V.I.S` | BolisettySujith/J.A.R.V.I.S | 2021 Python hobby assistant. MIT. Cloud Google STT, keyword `if/elif`, PyQt fan animation. |
| `Jarvis` | sukeesh/Jarvis | CLI personal assistant, ~150 plugins. MIT. Voice is optional I/O on a `cmd.Cmd` REPL. |
| `Jarvis-Desktop-Voice-Assistant` | student hobby | One Python file. Cloud STT, keyword soup, unconfirmed shutdown. |
| `OpenJarvis` | open-jarvis/OpenJarvis (Stanford Hazy Research) | Apache 2.0. Local-first agent *framework* (chat, digest, browser tools, RBAC). Not an AX Mac controller. |

Jev checkouts (`jev-ultrafast`, `jev-use`, `jev-voice-browser`, `macbrow`, `third-hand`, `jev-browser`, `jev-desktop`, `Jevbridge`, `hermes-jev-skills`, `tiptour-macos`, `jev-research-sources`) were already extracted in [north-star-computer-use.md](north-star-computer-use.md). This note is the **non-Jev assistant** layer: how a 2026–2027 MacParakeet should feel when speech captures intent and the Mac executes it.

Independent Sonnet 5 medium extracts via `claude -p` (2026-09-20): `/tmp/jarvis-swarm/{J.A.R.V.I.S,Jarvis,Jarvis-Desktop,OpenJarvis}.md`. Parent dispositions stay here.

---

## The one idea

Dictation is 2025. The next product is **intent → observe → decide → act → verify** on the user's real Mac.

Jarvis demos sell that future with a personality and a keyword list. They are useful as *negative* examples (substring matching, cloud STT, unconfirmed shutdown) and for a handful of *positive* interaction shapes (show what was heard, distinguish silence from “didn't understand”, number the alternatives, confirm the compiled effect). OpenJarvis is the only modern stack in this set: local-first models, a capability floor the model cannot talk down, AX-as-text for the browser. We take those as philosophy, not as their Playwright/CodeAct runtime.

MacParakeet already has the loop. The Jarvis gap we still had: when several controls match, the user had to restate a label. Apple Voice Control and Rango number **on-screen overlays**. We shipped a numbered **text list in the panel** (same “say the number” interaction, different affordance). Overlays remain later.

---

## 1. What we refuse from every Jarvis demo

- Wake words (`wake up`, `listen`). Dedicated invocation already exists.
- Cloud STT (`recognize_google`) and cloud TTS (gTTS, ElevenLabs, OpenAI TTS as default).
- Keyword soup (`"shutdown" in query`). Isolated-utterance grammar + enabled events.
- LLM/CodeAct emitting `Action:` / AppleScript / pyautogui.
- Personality, fan animation, plugin marketplace, scheduled “morning digest” daemons.
- Delay-as-confirmation (`sleep 10` then shutdown).
- Substring `yes`/`yeah` authorizing anything.

## 2. What we adopt

| Primitive | Source | MacParakeet |
|---|---|---|
| Numbered local disambiguation | Apple Voice Control, Rango, JARVIS “which one”, sukeesh “did you mean” | `VoiceControlSpokenPick` + `.pick` decision. Isolated `1` / `two` / `the second one`. `the other one` is not option 1. |
| Show what was heard | Negative: J.A.R.V.I.S `No_result_found` hides the transcript | Panel already shows transcript + task |
| Silence ≠ didn't-understand | Jarvis-Desktop distinct timeout vs unknown-value | Keep distinct receipts / messages; never one generic failure |
| Confirm compiled effect, isolated accept | sukeesh `file_manage` y/n; OpenJarvis `[y/N]` | Already pay/delete/send; filler words do not authorize |
| Generate help from live capabilities | Negative: J.A.R.V.I.S hand-written “what can you do” omits half the branches | `contextualHelp` from the snapshot |
| Local-first, cloud as fallback | OpenJarvis STT discovery | Speech stays local; Jev is optional and fail-open |
| Capability floor the model cannot lower | OpenJarvis `DEFAULT_TOOL_CAPABILITIES` | `VoiceControlConsequencePolicy` |
| AX as structured text, not pixels | OpenJarvis `browser_axtree` | Native AX snapshot; Playwright AX is not our transport |
| Announce listening transitions | sukeesh `hear` plugin | Panel Listening / Mic off; TTS later |
| Once-per-session fallback disclosure | OpenJarvis TTS voice substitute | Trace / status when an engine substitutes |

## 3. UI/UX for intent capture (2026–2027)

These are product rules, not a second surface.

1. **The panel is the cockpit.** Always visible: listening state, current mode (command vs typing), the last committed utterance, the current task, Stop. Hidden mode is how VoiceCraft and JARVIS GUIs fail people who cannot look away.
2. **Intent is restated as an effect, not a vibe.** “Click Save (the second one)” beats “Working…”. Numbered picks are the restatement when the intent was ambiguous.
3. **Correction is cheaper than restart.** “No, the other one” / “Actually London” / typed revision keep verified history.
4. **One missing slot, by name.** “Need a destination” later; do not ask “are you sure?” for ordinary navigation.
5. **Discoverability is pulled from this window.** Help lists observed controls. Never a static superpower list.
6. **Failures name the missing permission or the unmatched Choice.** OpenJarvis “Nothing heard — try again.” is the right weight for ASR miss. Mic-permission failure must not look like silence (J.A.R.V.I.S `except: return None` trap).
7. **No Iron Man HUD.** One panel. Skales’ collapsing eleven-place sidebar is the warning.
8. **TTS, when it lands, speaks the confirmation and the mode**, then barge-in stops *work*. Personality voices are out.

## 4. What shipped this pass

- `VoiceControlDecision.pick` with labels bound to snapshot-local target IDs.
- Isolated spoken index (`VoiceControlSpokenPick`). Duplicate names become `Save (1)` / `Save (2)` or `Save (role)` when roles differ.
- Help: “If several controls match, say the number.”
- “The other one” remaining alternatives are numbered; `2` presses the second, not a model call.

## 5. Later (not this commit)

Spoken confirm/mode via `AVSpeechSynthesizer`. Numbered *on-screen* overlays (Apple “show numbers”). Named references (Rango `mark as`). OpenJarvis silence-threshold split for hold-to-talk. Hotkey “last key seen”. Distinct copy for “heard nothing” vs “heard, no match” on the live mic path (unit-covered receipts already exist).

## 6. Verification

`swift test --filter VoiceControl` after this slice: **127 tests, 0 failures** (re-run after Fable low amendments). Combined dictation/Transform gate: **182 / 0**. Live Flights/mic remain open. No Jarvis or OpenJarvis binary was executed.
