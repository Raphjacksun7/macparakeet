# Accessibility / voice primitives from three non-Jev references

**Date:** 2026-09-20. **Status:** source extraction plus MacParakeet mapping. Not a claim that live Flights results or the microphone path have passed.

**Checkouts** (cloned into `/Users/dmoon/code/macparakeet/references/` on 2026-09-20; gitignored, not vendored):

| Folder | Upstream | What is actually in the checkout |
|---|---|---|
| `blind.sh` | [realrasengan/blind.sh](https://github.com/realrasengan/blind.sh) | One bash script + README. MIT. |
| `VoiceCraft` | [parthgupta1208/VoiceCraft](https://github.com/parthgupta1208/VoiceCraft) | Python Tk/pyautogui assistant. MIT. |
| `skales` | [skalesapp/skales](https://github.com/skalesapp/skales) | **Distribution repo.** Proprietary EULA. Source snapshot removed at 12.9.30. Evidence is README, CHANGELOG, `docs/skales-guide.html`. |

These are **not Jev**. The useful residue is interaction primitives: modes, confirmation copy, honesty about unknown work, and several execution traps.

Independent review: Fable 5.1 medium via `claude -p` — [consult-fable-accessibility-voice-primitives.md](consult-fable-accessibility-voice-primitives.md). Parent dispositions in that file and in §4–§5 here. Fable: adopt-with-amendments. Subagent deep-dives of Skales (docs only) and VoiceCraft (`v3.py` / `Ideas.txt`) agreed with the extraction; extras are folded below.

---

## The one idea

Voice computer-use is two products jammed into one microphone:

1. **Commands** that change the world (click, fill, search, send).
2. **Literal speech** that must land as text and must not be reinterpreted as a command.

Every working accessibility assistant in this set rediscovers that split. The ones that hurt people blur it (substring mode resets, generated scripts, confirm-nothing *or* confirm-everything).

MacParakeet already has the split: one-shot `type …`, persistent `literalMode`, isolated `command mode` / `command stop`. What was thin: the spoken *names* of the typing session, Help advertising it, and confirmation copy that names the decline.

---

## 1. `blind.sh` — confirm the compiled effect, never the model's intent

Primary: `blind.sh` itself.

Pipeline, one shot:

1. `sox` records until ~2 s of silence (`blind.sh:7`).
2. Cloud Whisper transcribes (`blind.sh:8-12`).
3. GPT-3.5 is instructed to reply with **only** an `osascript` command (`blind.sh:16-26`), few-shot with “open Chrome” and “Terminal uptime”.
4. A macOS dialog asks `Run $BLIND_COMMAND?` with buttons No / Yes, **default No**, caution icon (`blind.sh:39`).
5. Only then is the string written to `/tmp/blind.sh/$UUID/run.sh` and executed (`blind.sh:47`).

**Primitives worth keeping as policy:**

| Primitive | Why it transfers | MacParakeet |
|---|---|---|
| Show the **compiled effect**, not the transcript, at the authorization boundary | The user authorizes *what will run*, not what they meant | Confirm on the target label. Decline copy names **Cancel task** and the skipped commitment (“Nothing is paid”), not “the app is unchanged”. |
| Default **No** | Accidental Return must not pay/delete/send | Panel Confirm is explicit; Escape/Stop already revoke. Do not make Confirm the default keyboard action for payment. |
| Isolated per-turn workspace (`uuidgen` temp dir) | A failed turn must not reuse another turn's artifact | AX handles are already snapshot-local. Keep that. |
| Fail closed if the user says No | “I transcribed you” is not permission | Already true. |

**Traps (refuse):**

- Model output **is** the program (`osascript -e …` executed via `run.sh`). That is the macbrow-generator failure mode with a thinner prompt. Voice Control compiles host-owned `VoiceControlAction` values from observed AX ids.
- Cloud Whisper + ChatGPT in the click path. Speech stays local; Jev stays a Choice judge.
- The system prompt claims the reply will be run “directly in terminal” (`blind.sh:20`) — then a dialog is added as a patch. Authorization as an afterthought is how these demos get a README warning: “This could severely damage your computer” (`README.md:18`).

---

## 2. `VoiceCraft` — mode state machine good; execution catastrophic

Primary: `v3.py`, `Ideas.txt`, `README.md`. Windows hobby project. GPT-3.5 emits pyautogui/selenium, which is `os.system`'d (`v3.py:45-63`, `v3.py:65-83`). `pyautogui.FAILSAFE=False` (`v3.py:24`). Hardcoded OpenWeather key (`v3.py:27`). Spoken `eval` for “calculate” (`v3.py:279-291`). Substring `"shutdown"` runs `shutdown -s` (`v3.py:321-322`).

**The mode machine** (`state` global, `v3.py:42`, `v3.py:496-509`):

| State | Enter (substring in the utterance) | Subsequent audio | Exit |
|---|---|---|---|
| `start` (command) | default | `check_text` keyword soup | — |
| `type` | `"activate type"` (`v3.py:204-206`) | `type_text`: punctuate + `typewrite` (`v3.py:466-476`) | `"mode reset"` **stripped from the text then still typed around** (`v3.py:468-471`) |
| `voicemouse` | `"activate voice mouse"` | relative moves, click, scroll (`v3.py:428-463`) | `"mode reset"` |
| `code` | `"activate code"` | GPT writes a file and runs it | `"end coding"` or language chosen |
| `grid` | `"mouse map"` | spoken integer → 10×7 pixel cell center (`v3.py:178-194`) | picking a cell returns to `voicemouse` |

`Ideas.txt` is more careful than the code: it asks for **explicit** “Switch to typing mode” / “Switch to command mode”, a visible toggle, and user testing with people who do not have arms. The shipped code matches none of that discipline: modes are **substrings**, `"mode reset"` can fire inside a sentence, and there is no on-screen mode name except a translucent waveform window (`v3.py:517-522`). Fable + the VoiceCraft agent: type mode **never ran as shipped** (`model = "test"` at `v3.py:100`, so punctuation restore raises). Treat it as a design, not a working machine. Mode-entry checks are sequential `if`, not `elif`, so one utterance can set several modes. `v2.py` used a four-word exit (`end typing code confirm`) — awkward, but it was the right instinct for an isolated escape. `FAILSAFE=False` removes the only physical abort those stacks have.

**Primitives worth keeping:**

| Primitive | Adapt for MacParakeet | Refuse the VoiceCraft shape |
|---|---|---|
| Persistent typing session until an isolated escape | Already `literalMode`. Add accessibility aliases that people actually say: `typing mode`, `start typing`, `activate type`, `type mode`. Exit: existing `command mode` plus `stop typing`. Stop: `command stop`. | Do not treat `"mode reset"` as a substring of typed prose. Do not type the escape phrase into the field. |
| Visible mode name | Panel already shows `Voice Control · Literal` | Do not hide mode in a 0.6-alpha toy window |
| Grid as a *rescue* for hard targets | Product reviews already parked numbered overlays as future | Do not move the **mouse** to pixel cell centers. Targeting is AX ids + labels. |
| One-shot type vs session type | `type hello` already owns the rest of that utterance | Do not merge with MacParakeet Dictation. Voice Control typing is “insert into the focused AX field”. |
| Semantic caret motion (`Ideas.txt`: “start of the line”) | Native AX already moves by control, not pixels | Do not ship 100px nudges; “left click” substring-matched `"left"` and moved first |

**Traps (refuse, and treat as regression tests against our posture):**

- LLM emits code, host execs it.
- Coordinate mouse (`moveRel`, `click`, `FAILSAFE=False`). A corner-of-screen failsafe is the only physical abort those stacks have; disabling it is the opposite of our Escape/Stop revoke.
- Keyword soup: any utterance containing `"google"` or `"open"` fires a side effect **in addition to** other matches (`v3.py:231-324` is a chain of `if`, not `elif`, after the Friday branch).
- Cloud Google STT (`recognize_google`, `v3.py:489`).
- `eval` of spoken arithmetic.
- App launch via Start-menu keystrokes.
- No literal escape: you cannot type the words `"mode reset"`. That is why we keep `type literally command mode`.

---

## 3. `skales` — stop conditions, honest cards, barge-in (docs only)

There is **no application source** in this checkout. README states the v7 tree was removed because it no longer described the shipped product. Claims below are from `docs/skales-guide.html` and README marketing; they are **not** verified runtime.

**Primitives that match work we already wanted:**

| Claim (docs) | Transfer |
|---|---|
| A goal “stops when the task is done, when it genuinely needs a decision, or before a consequential action” (`skales-guide.html` `/goal` chapter; README `/goal`) | This is already the Voice Control loop: verified/finished, clarify, confirm pay/delete/send, pause on unknown. Keep it as the **definition** of the runner, not a new planner. |
| Success criteria + evidence in a Cockpit | We have receipts and traces, not a Kanban. Do not build a second product surface. Do keep “unknown is a valid ending”. |
| Confirmation card names the action, **what happens if you say no**, and how far “always” would reach (`skales-guide.html` Safety Mode) | Adopt the first two sentences for pay/delete/send. **Refuse always-allow** on those three classes. A session-scoped always-allow on ordinary navigation is how people accidentally send. |
| Safety Mode: every Computer Use action asks; a control whose **name** says delete/buy/pay asks regardless (`skales-guide.html` Computer Use warn box) | Split: we will not confirm every click (product rule). We **will** keep name-based consequence on the target (`VoiceControlConsequencePolicy`). |
| Barge-in: speak-over stops the voice **and the work** (`skales-guide.html` Voice interrupting) | Later, with `AVSpeechSynthesizer`. Today Stop/Escape already stop work. Do not add a wake word. |
| Accessibility tree for in-app browser agent (README “semantic element detection through the accessibility tree”) | Policy confirmation of native AX. Not a reason to embed a Skales browser. |
| Dictation-on-device read-back before send (Pocket) | Interesting for **Send**, which already confirms. Do not add a second dictation product. |
| “A machine with no key stops claiming it can read or draw a picture” (CHANGELOG honesty work) | If Voice Control cannot type (no focused field), say so. Do not pretend a mode is active that cannot execute. |
| Plan/Ask sessions refuse write tools rather than “discouraging” them (`skales-guide.html` Code modes) | Same shape as our legality filters: overlay does not offer Return. Host omits the illegal event instead of asking Jev not to pick it. |

**Refuse as product chrome:** mascot, Discover feed, plugins marketplace, Electron, screenshot computer-use, QR phone relay, cost ceilings, always-allow on commitments, local wake-word as the Voice Control entry.

Licence: proprietary EULA, private study allowed (`LICENSE` §3.5 allows independent ideas, not prompts/UI). We copy **ideas**, not UI, trademarks, or (nonexistent) source.

Docs-only extras (not verified runtime): `INSTALL-MAC.md` contradicts README signing/version claims — treat install-side numbers as stale. The guide’s “check afterwards” and “a deny list the shell does not know about is theatre” already match our postcondition + host-side legality. Jev in their CHANGELOG is the same judge framing we already settled: optional, no tools, stop when looping. Hotkey diagnosability (“last key seen”) and “never fail silently” STT copy are later. A session-scoped always-allow on pay/delete/send was suggested as a two-tier compromise; we still refuse it — the consequence class is a label heuristic, so an always scoped to it is scoped to nothing.

---

## 4. Disposition table

| Idea | Source | Disposition | MacParakeet surface |
|---|---|---|---|
| Compiled-effect confirmation, default deny | blind.sh | **Adopt** copy (Fable: no “unchanged”; no filler-word accept) | `VoiceControlConfirmationCopy` + panel Confirm / Cancel task |
| Isolated typing session with spoken aliases | VoiceCraft / Ideas.txt | **Adopt** aliases; keep isolated-utterance rule | `VoiceControlSessionGrammar` + coordinator |
| Help teaches the typing session | Ideas.txt toggle + our R16 | **Adopt** | `contextualHelp` |
| Pixel mouse grid | VoiceCraft | **Refuse** | — |
| LLM → script → exec | blind.sh, VoiceCraft | **Refuse** | already host-compiled actions |
| Confirm every click | Skales Safety Mode | **Refuse** | ordinary proceeds |
| Always-allow on pay/delete/send (including session-scoped) | Skales cards | **Refuse** | — |
| Stop when done / blocked / consequential | Skales `/goal` | **Already the runner** | `VoiceControlTurnRunner` |
| Barge-in | Skales Voice | **Later** (TTS) | Stop/Escape today |
| Wake word | Skales Iris | **Refuse** | dedicated invocation |
| Honesty when a capability is off | Skales CHANGELOG | **Adopt** as a rule | literal mode still needs a focused field (router clarify) |

---

## 5. What shipped from this pass

1. Pure session grammar (aliases, hyphen/space normalize, filler-word-proof confirmation tokens).
2. Coordinator uses that grammar. Literal payloads skip clarification and dismiss a pending authorization with a message. Isolated `confirm` only authorizes while a prompt is pending.
3. Help lists typing mode when a focused editable field exists.
4. Confirmation copy names the control, the class, and **Cancel task stops here** plus “Nothing is paid / deleted / sent.” Never always-allow. Never “unchanged.”
5. Consecutive `type` insertions join with a space at the caret.
6. Payment heuristic adds `order` / `booking`. Not `book` / `reserve`.
7. Contract sentences for aliases, confirmation tokens, and type-join.

Not this pass: TTS (spoken confirm / mode, then barge-in), numbered AX overlays, mouse, screenshots, Skales UI, requiring the word “payment” to accept.

---

## 6. Verification

Focused VoiceControl tests for grammar, confirmation copy, type-join, payment words, and help: **127 tests, 0 failures** (`swift test --filter VoiceControl`, 2026-09-20). Combined dictation/Transform admission: **182 tests, 0 failures**. Live Flights/mic remain open. No Skales or VoiceCraft binary was executed. Full Swift suite not run.

## Evidence limits

VoiceCraft and blind.sh were read in full (they are small). Skales was read as documentation of a proprietary app we cannot run from this checkout. Do not treat Skales README latency, RAM, or “260+ tools” claims as facts about MacParakeet or as verified behavior.
