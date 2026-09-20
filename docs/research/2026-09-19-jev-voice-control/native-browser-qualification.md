# Native browser qualification — in progress

2026-09-19. This supersedes extension-based acceptance evidence. The extension experiment is historical; its recording does not prove native Accessibility browser control.

## Setup and boundary

A disposable single-tab window was opened in the user's existing Google Chrome process. No restart, separate profile, extension, debugging port, Playwright, or DOM injection was used. The first page was a synthetic local flight form; the acceptance target subsequently changed to the real [Google Flights page](https://www.google.com/travel/flights?gl=US&hl=en-US). Search is authorized; booking and payment are not performed.

The native harness compiles the actual production Types, Diagnostics, TurnRunner, CommandRouter, JevDecisionClient, and NativeVoiceControlAdapter. It extracts the existing StreamingCursorEventMarker enum unchanged to avoid linking unrelated audio dependencies. Input is typed command text. This is not speech/microphone qualification. API credentials are loaded into process environment from an explicitly provided ignored local file and are never printed.

`AXBrowserProbe.swift` guards the foreground app, focused window title, and AXWebArea loopback URL before every observation/effect. `run_ax_browser_probe.py` is the build/run entry point. The source fixture is `flight-fixture.html`, served only from this fixture directory on port 56474. Runtime files are under ignored `output/voice-control/`.

## Observed native behavior

- Initial Chrome tree exposed only browser chrome (36 nodes); after explicit focus on the dedicated window, its webpage AX tree appeared (62 nodes). Setting application AXManualAccessibility returned -25205 and application AXEnhancedUserInterface -25208; window setters returned -25205. Therefore we cannot attribute activation to a successful setter. No renderer restart was used.
- The local fixture's AXWebArea is at depth 8, text fields/options at depths 11–13. Native HTML select options expose AXMenuItem with an empty title/description and a useful AXValue label. Native popup and web option representations can both appear.
- Chrome AXSetValue succeeds asynchronously: immediate AXValue checking produced an unknown receipt despite the text appearing shortly afterward. Read-only bounded polling now verifies the same single write (~69–74 ms observed). The write is never retried.
- Production runner ordinary steps execute without repeated permission prompts. Uncertain effects pause and are not replayed. Several early synthetic runs stopped on model target clarification or focus loss; no complete native acceptance pass is claimed yet.
- A search produced visible synthetic results but returned unknown because native transition evidence did not yet consider the newly displayed result text. This finding was sent to the adapter owner.

## Real Google Flights read-only findings

The initial real page has 355 native AX nodes, with flight form controls at depth 22. The prior depth-18 limit would exclude these controls; the expanded depth-32 traversal reaches them.

| Control | Native role | Observed capability |
|---|---|---|
| Change ticket type. Round trip | AXComboBox | AXPress, settable AXValue |
| Where from? | AXComboBox | AXPress, settable AXValue |
| Where to? | AXComboBox | AXPress, settable AXValue |
| Departure / Return | AXTextField | AXPress, settable AXValue |
| Explore destinations | AXButton | AXPress |

Pressing the actual ticket type control exposed an AXList labeled “Select your ticket type.” at depth 23. Its children are **AXStaticText** at depth 24, with empty labels but AXValue of “Round trip”, “One way”, and “Multi-city”; each supports **AXPress**. A role-only assumption that static text is never actionable would miss these real controls. The modal tree temporarily hides the rest of the webpage. Account/profile labels were excluded from diagnostic output; no real page context has yet been sent to Jev at this checkpoint.

Chromium's [Accessibility Technical Documentation](https://www.chromium.org/developers/design-documents/accessibility/) describes assistive-technology-driven renderer activation. Our observed unsupported setters and delayed tree availability are recorded separately from that documented mechanism.
