# macOS computer-control tools (pre-Jev, adopted)

**Date:** 2026-09-20. Native Accessibility operations are **host tools**. Jev chooses among competing tools; it does not execute, and it does not add a second “are you sure?” on ordinary actions.

Sources: `third-hand` matching/skip/progress, `jev-use` AX observation, `mac-use` name/role targeting, Apple Voice Control named clicks, Fable 5.1 medium [consult-fable-tools-first.md](consult-fable-tools-first.md).

## Tools that compile locally

| Spoken intent | Tool | Notes |
|---|---|---|
| `Save` / `the Save button` / `click Save` | press unique AX control | Bare names only on `.plain`. Overlays stay landings. |
| 2–6 same names | numbered panel pick | Id + label rematch after the next observe |
| `click Search` with unique `Search flights` | press (word-prefix) | Exact match wins first. `research` ≠ `search` |
| `press return` / `escape` / `tab` | key on the focused field | Not a hunt for a button named Return. `click Return` is the button |
| `type hello` when the field already holds hello | skip (information) | Does not skip when a selection is present |
| Unique running app name | activateApp | `open Settings` prefers a Settings *control* if one is visible |
| Allowlisted site / Flights / Gmail Compose | existing host plans | Unchanged |

Pay / delete / send still confirm after a compiled press. A pick is not authority.

Validation: `swift test --filter VoiceControl` — 136 / 0. Combined admission gate 191 / 0. Live Flights/mic remain open.

## What we refused

- Jev as a sensitivity guard or extra confirm on ordinary tools
- Bare-name matching inside suggestion/date pickers (steals the landing Choice)
- CDP, wake word, overlays, OCR, File > Export menu paths (later)
- Completing plan-driven presses on unverified `.unknown` (later; needs origin flag)

## UI/UX

The panel is still the cockpit. A unique name is restated by doing it. Several names become a numbered list. A reserved key that has nowhere to go says “Focus a field that can receive the return key,” not a Jev question. Help lists observed unique controls as “Click Save — or just say Save.”
