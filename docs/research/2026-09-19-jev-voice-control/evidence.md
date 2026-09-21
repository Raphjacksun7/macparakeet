# Evidence

This is not a stable-release claim. Native Google Flights **results** and the integrated microphone have not passed.

## What is proven in tests

Focused `swift test --filter VoiceControl`: **136 tests, 0 failures** (2026-09-20). Combined dictation / Transform admission (`VoiceControl|DictationFlowCoordinator|TransformRunSerializer`): **191 / 0**.

Covered: unique named press without `click`; numbered picks bound to ids; `press return` as a key; skip-if-already-typed; overlay never enables Return; competing cities as an outcome Choice; unique Zürich stays local; unconstrained Jev omits keystrokes; stale ids rematch by unique label; confirmation reobserves after an expired snapshot; shareable traces omit labels; Jev wire omits `selectedText`.

The full Swift suite has not been run. It is the final merge gate, once.

## Google Flights, honestly

Typed goal: `Find one-way flights from Zurich to London on September 20 2026.`

A live turn opened Flights, filled Zurich and London, committed the Zürich suggestion, typed the date, and **stalled**. It did not produce a results list.

The last snapshot was the origin autocomplete overlay (focused Zürich, plus ZRH, Zürich HB, Lake Zurich, Illinois). Policy outcome: `duplicate_blocked` on a key, not a city press. After cities and date were filled, the origin overlay returned. `Where else?` was still in the tree, so the plan treated the form as visible and sent Return on the focused suggestion. Repeating Escape then hit duplicate-effect protection.

A second stall class: airport names on a **results** list were classified as a city overlay, which hid Search. Classification now requires a focused suggestion or `Where else?` chrome.

Fixture tests make those stalls illegal. **ZRH→LON results have not been demonstrated.**

## Native Chrome observations

A disposable Chrome tab, existing process, no extension or CDP:

- Unfocused Chrome exposes browser chrome (~36 nodes). After focusing the dedicated window, the webpage tree appears.
- Google Flights’ initial page is ~355 AX nodes; form controls sit at depth 22. Traversal is depth 32, 600-node bound.
- Ticket type is an `AXComboBox`. Its list children are **pressable `AXStaticText`** with empty labels and AXValue `One way` / `Round trip` / `Multi-city`. A role-only filter that skips static text misses them.
- `AXSetValue` is asynchronous. Immediate readback is “unknown” even when the text appears ~70 ms later. Bounded read-only polling verifies the same write; the write is never retried.
- Chromium webpage controls need `AXManualAccessibility` / `AXEnhancedUserInterface` once per process, then a wait for a populated web area. Setter return codes of -25205 / -25208 were observed; do not treat a failed setter as “the tree will never appear.”

A historical headless-Chrome **extension** recording against a synthetic flight form is not native-path evidence. See [historical-browser-extension](historical-browser-extension/README.md).

## Why native Accessibility is harder than a CDP demo

CDP Flights demos own a tab, keep DOM nodes, and click `[role=option]`. We keep the *policy* (code-owned URLs and values, consume once, do not retry an uncertain mutation) and throw away the transport.

Typed text is not a selected airport. Calendar day names include weekday, month, year, and sometimes a price — `contains("20")` matches 2026. Snapshot ids collide across observations. Chromium webpage controls require `AXManualAccessibility` / `AXEnhancedUserInterface` once per process; without them the adapter sees chrome, not the form. A generic interface change is `transitionObserved`, not “search completed.”

## Traces

After a turn:

1. `/tmp/macparakeet-voice-control/latest.md` — one wide event: outcome, why, actor (`local` / `jev`), route, last control, last receipt
2. `latest.json` — the same plus joinable per-step records
3. `events.jsonl` — streaming steps, one `type=turn` when the loop stops

Local logs may include the instruction and control labels. Copy diagnostics strips names and keeps opaque ids. Field values, selected text, audio, screenshots, credentials, and remote bodies stay out.

## Earlier text-only Jev probes

Five synthetic Choice calls (Save / scroll / incomplete / negated / ambiguous) took 216–293 ms, median 238 ms. Text-only, tiny, no speech or Accessibility. Not a p95 voice-to-action claim.
