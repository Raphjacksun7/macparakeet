# Voice Control: transplants from typesafe-computer-use

**Status:** ACTIVE. **Date:** 2026-09-20. **Owner:** MacParakeet core.
**Source review:** [docs/research/2026-09-20-typesafe-computer-use/README.md](../../docs/research/2026-09-20-typesafe-computer-use/README.md) and the [developer walkthrough](../../docs/research/2026-09-20-typesafe-computer-use/walkthrough.html).
**Governing decisions:** [ADR-033](../../spec/adr/033-explicit-voice-control.md), [contract](../../spec/contracts/voice-control.md). Owner decisions recorded 2026-09-20: all seven recommendations in the walkthrough accepted, including on-device OCR as a second source of targets and state.

## Doctrine that does not move

Code observes, lists legal events, executes and verifies. Jev chooses among options code built, only when several are enabled. Authority is revocable; effects are consumed once; uncertain effects are never replayed; pay/delete/send confirm; speech, pixels and field values stay on the Mac. Nothing below changes this.

## Sequence

PR #1104 merges first as the DEBUG experiment it claims to be. Each item below is its own PR based on `origin/main`, independently reviewable and measurable on saved snapshots. Order is by leverage: observability makes every later change measurable offline.

| # | PR | Scope | Verifies |
|---|---|---|---|
| A | Observability and replay | Full Jev probability map and offered keys in the local session log; redacted snapshot fixture per observation (no values); `macparakeet-cli voice-control replay <fixture> --goal …`; `--dry-run` through a no-op adapter; per-turn timing line with session mean/max | `VoiceControlTraceStoreTests`; replay of the recorded overlay stall reproduces `duplicate_blocked` offline; shareable copy unchanged |
| B | Pure AX walk | `AXTreeWalk` over an `AXTreeSource` protocol; TCU pruning rules (off-display subtrees, <4 pt slivers, closed `AXMenu`, nameless `AXGroup`, label inheritance, dedupe, node/time caps) ported with fake-tree tests; off-screen pressables collected separately; display bounds and window frame read once per observe; expensive attributes read only for roles that use them | Fake-tree tests; observe time on Chrome/Finder/Notes in the timing line; existing 194 focused tests |
| C | Lean Tier-3 request | `kind` / `target` / focused-only `value`; second request only when filling an unfocused target; gate `min(kind, target)`; no prompt from consequence confidence; one `send(state:questions:)`; prioritised truncation instead of `contextTooLarge`; `SpokenDateParser` with `dated … (in N days)` hints | Replay corpus from A: payload bytes, latency, invalid/too-large rate, clarify rate before/after |
| D | On-device OCR | Vision OCR of the frontmost window, tile-diff cache, merge with AX by box overlap + text match; text-only targets with pixel-click fallback and `unknown`-unless-transition receipts; window-scoped screen text into the snapshot `summary`; OCR redaction (secure-word filter, excluded frames, 4,000-char cap, local log only); ADR-033 amendment; DEBUG flag | Terminal/Spotify fixture yields targets AX lacks; Flights results fixture shows prices/dates in `summary`; no image persisted by default; shareable diagnostics unchanged |

## Invariants to test in every PR

- No audio, screenshot, field value, credential or remote body in any trace or fixture.
- Copy diagnostics output is byte-identical in shape (labels and instruction still stripped).
- `swift test --filter 'VoiceControl|DictationFlowCoordinator|TransformRunSerializer'` green; full suite once before each PR is marked ready.

## Open follow-ups recorded in the walkthrough

Q6 off-screen presses: allow only for explicitly named local commands, receipts postcondition-only, not offered to Tier-3 Jev initially. Q7 OCR wire volume: same consent as AX labels, measured before default-on.
