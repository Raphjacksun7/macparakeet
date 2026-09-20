# North-star adoption from the Jev / computer-use references

**Date:** 2026-09-19. Synthesis lives in [north-star-computer-use.md](north-star-computer-use.md). This file is what we actually took into MacParakeet Voice Control, and what we refused.

## Adopted this pass

| Item | From | Where |
|---|---|---|
| Chromium AX handshake once per process (`AXManualAccessibility` + `AXEnhancedUserInterface`), wait for a populated `AXWebArea` | `jev-use` `Desktop.waitForWebContent`, `third-hand` `TaskRunner` | `NativeVoiceControlAdapter` |
| Code-owned URLs; Jev never receives `role == "url"` | `jev-voice-browser` `SITE_HOME`, existing `VoiceControlWebDestination` | destinations + `JevDecisionClient` |
| Local search-box filling after the site is open | same + Flights layering | `VoiceControlWebQuery` |
| Unique labeled page click that is not send/pay/delete | everyday Gmail compose | `VoiceControlNamedPageAction` |
| Overlay dismiss with Escape rather than asking Jev | live Flights “Where else?” overlay | `VoiceControlFlightPlan.dismissOverlay` |
| Ignore destination chrome when deciding “are we already on this page?” | bug found while expanding YouTube/Maps | `VoiceControlWebDestination.pageMatches` |
| Query fill only after `pageMatches` or a verified destination open, never because the allowlist IDs are injected | fresh-eye review | `VoiceControlWebDestination.isCurrent` |
| `open gmail` after activating Chrome still opens Gmail | fresh-eye: `result()` was completing on any verified hop | router `result(_:)` is command-scoped; URL labels excluded from `click`/`open` |
| Local web actions declare `.ordinary`; pay/delete/send word scan is only for short labels | wrong confirm on Return / “buy” in a video title | `VoiceControlWebQuery` / `FlightPlan` / `NamedPageAction` + policy |
| Jev never receives `role == "url"` even on a blank tab | `available = pageTargets.isEmpty ? all : page` leaked destinations | `JevDecisionClient` |
| Pre-dispatch `observationExpired` / `windowChanged` reobserve instead of poisoning the task | confirmed payment that expired under the 20s window | `VoiceControlTurnRunner.perform` |
| Strict choice validation (offered IDs, probability keys, argmax, sum≈1) | `jev-ultrafast` `validate_choice` | already in `JevDecisionClient.validate` |
| Confirm only pay / delete / send | product rule; reject macbrow’s save/create/edit list | `VoiceControlConsequencePolicy` |
| Fail-open: malformed Jev answer executes nothing | `hermes-jev-skills`, `jev-ultrafast` | `JevDecisionError.invalidResponse` |

## Explicitly not adopted

CDP, Chrome extension, automation browser, screenshot-to-cloud, generated AppleScript/tools, `visible[0]` fallback, cloud TTS, Jev CLI as the HTTP client, coordinate clicking as targeting, OCR, OpenRouter planners, tiptour loopback servers.

## Next high-leverage items (not this pass unless traces demand them)

Semantic freshness guards (`jev-ultrafast` pageKey), third-hand re-match after model latency, numbered local disambiguation (`jev-voice-browser`), two-gate speech commitment for free-text payloads, batched AX reads. Each is 40–120 lines; none is required to keep the everyday local routes working.
