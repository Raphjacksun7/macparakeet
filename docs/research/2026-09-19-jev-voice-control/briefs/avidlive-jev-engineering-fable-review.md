# Fable 5.1 medium — second review of Avidlive Jev Engineering sheets

Read these four images, in order, as primary source:

- docs/research/2026-09-19-jev-voice-control/avidlive-jev-engineering/sheet-1-understand-jev.jpg
- docs/research/2026-09-19-jev-voice-control/avidlive-jev-engineering/sheet-2-decision-loop.jpg
- docs/research/2026-09-19-jev-voice-control/avidlive-jev-engineering/sheet-3-choose-workflow.jpg
- docs/research/2026-09-19-jev-voice-control/avidlive-jev-engineering/sheet-4-build-and-measure.jpg

Then read the parent extraction:

- docs/research/2026-09-19-jev-voice-control/avidlive-jev-engineering.md

You are an independent design critic. The sheets are Avidlive “How to Master Jev / Jev Engineering,” not official TypeSafe docs. The extraction is a parent transcription plus a MacParakeet mapping.

## Settled product (do not re-litigate)

MacParakeet Voice Control: native macOS Accessibility is the required path; optional browser extension supplies DOM only when a tab is connected; confirm only pay/delete/send; local STT; Jev is cloud text with consent; no CDP on the personal Chrome profile. Google Flights to a results list is the native acceptance bar.

## What to return

Markdown. No file edits, no delegation, no tests. Sections:

1. **Fidelity** — material misreads in the extraction vs the sheets (quote the sheet). If the extraction is faithful, say so in one sentence.
2. **Load-bearing ideas** — the 5–8 rules you would actually implement. Distinguish TypeSafe-true (independent questions, no generation, confidence ≠ success) from Avidlive-process (shadow mode, 20 workflows, DeepSeek analogy).
3. **What to refuse** — slogans or workflows that would harm Voice Control if copied.
4. **Voice Control insertion** — where this guide says to put Jev relative to a state machine whose enabled events are Choices. Be concrete about overlay/calendar/Search on Flights.
5. **Gaps** — what the sheets leave open (speech, AX identity, duplicate effects, optional DOM).
6. **Verdict** — adopt as engineering doctrine / adopt with amendments / reject as the architecture. One paragraph.

Stay under 1000 words. Prefer disagreements with the parent extraction. Do not invent TypeSafe API details that are not on the sheets or in the extraction.
