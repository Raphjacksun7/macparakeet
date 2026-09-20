# Product direction: native Accessibility for Voice Control

Date: 2026-09-19
Audience: main implementation agent
Source: explicit user clarification in a side conversation

## Intent

Make MacParakeet a native macOS voice-control experience that works with the user's current application, including their existing browser, through macOS Accessibility. Browser control must not require installing a Chrome/browser extension.

The user explicitly said: “a browser extension is extra hurdle that will not gain popularity at all. we absolutely need to make this native. and let's use native accessibility pls.”

This changes the implementation direction. Earlier discussion of an optional extension was an assistant proposal, not the user's chosen product direction. Do not treat extension onboarding or distribution as a requirement to finish this feature.

## Motive

The intended experience is simple: install MacParakeet, grant the relevant macOS permissions, enable Voice Control, and speak to operate the app already in front of you. Requiring an extension, developer mode, an extension ID, native-host registration, or tab pairing adds setup friction and makes browser control feel like a separate product.

The browser should be another application MacParakeet can control. The user wants the same interaction model across webpages, browser UI, and native Mac apps.

An extension can provide extra DOM detail, but we have not demonstrated that those benefits are necessary for the visible workflows the user wants. The successful extension-based demo proves that particular implementation works; it does not establish an extension requirement.

## Desired end state

- MacParakeet controls supported visible interfaces through native macOS Accessibility, including browser webpage content and native application controls.
- Users work in their existing browser and current session. There is no required extension, special automation browser, remote-debugging setup, or browser restart.
- Speech becomes finalized command text through MacParakeet's existing local speech infrastructure. The command system then routes that text, uses Jev where needed to choose among observed actions, executes locally, and checks the outcome.
- Ordinary dictation remains ordinary dictation. Cloud command/context sharing remains an explicit Voice Control choice; native execution does not mean Jev inference is local.
- The interaction feels consistent across applications: clear listening and task state, useful clarification, reliable Stop, and honest result reporting.
- Unsupported controls produce a clear limitation or recovery path. Do not claim unrestricted control or introduce an extension requirement as the default answer to compatibility gaps.

## What to preserve and reconsider

Preserve useful work already done: the speech integration, typed command boundary, Jev decision client, bounded task runner, native adapter, cancellation and freshness protections, confirmations, and meaningful tests.

Reconsider extension-specific product wiring, setup UI, registration, and packaging against this direction. Those should not remain dependencies of the delivered user experience. The main agent should choose the simplest maintainable way to retire or isolate that work while preserving useful research and accurately labeled historical evidence. This note does not ask for deletion of users' browser settings, profiles, installed extensions, or local data.

No particular class structure, refactor sequence, or low-level AX technique is prescribed. Inspect the current implementation, make sensible engineering choices, and document real limitations. Keep the focus on delivering the native experience rather than defending the existing implementation.

## Evidence that should establish success

Demonstrate representative browser and native-app workflows through the actual native Accessibility execution path, without relying on an extension for observation or actions. Include a multistep browser task comparable to the flight-search example, as well as correction, cancellation, and changing-interface behavior.

Typed commands are valid primary inputs for qualifying the downstream controller. The user explicitly accepts the existing MacParakeet audio-to-text pipeline as the upstream component; there is no need to re-prove speech recognition from scratch. A focused integrated voice smoke test should establish that the connection behaves correctly and feels responsive.

Distinguish native-path evidence from the earlier extension-based recording. Record what worked, what failed, and what remains unsupported. Carry the revised direction into the plan, product documentation, PR description, and final demo. Do not represent fixture success as universal website compatibility or a finished stable release.

## Follow-up direction: seamless execution and proportionate confirmation

The user explicitly agreed that repeated confirmations for ordinary actions create too much friction and asked to remove it: “we want as seamless as possible unless for stuff like payment.”

Treat an explicit command or goal as authorization for its ordinary, reasonably implied interaction steps. Navigation, opening selectors, choosing dates, filling requested form values, scrolling, and searching should normally proceed without repeated permission prompts. In particular, an unambiguous “click Search” should not ask permission merely because the operation is a button press. A flight-search goal should be able to run through its ordinary steps smoothly.

Make confirmation depend on the consequence and the user's expressed intent, rather than the mechanical operation type or the fact that several clicks are involved. Payment or final purchase commitment is the clearest user-specified exception. Apply comparable judgment to other consequential commitments such as destructive deletion or external submission; do not expand these exceptions until routine use becomes confirmation-heavy again. Searching for a flight does not authorize buying a ticket.

Keep clarification distinct from permission: if the target, amount, recipient, or requested outcome is genuinely ambiguous, ask the specific missing question. Avoid generic “Are you sure?” interruptions where the instruction already settles the decision.

Preserve target freshness checks, cancellation, consent, effect verification, and protection against duplicate or unknown effects. Removing unnecessary prompts does not mean removing these execution guarantees. If an effect cannot be verified, explain the uncertainty rather than blindly replaying it.

A future local text-to-speech interaction could make consequential confirmation conversational, for example reading a purchase summary and accepting an explicit spoken response. The user raised this as a future possibility, not a prerequisite for implementing the lower-friction policy now. Do not add another provider or a large speech-dialog subsystem just to complete this change.

Qualify the result through ordinary multistep tasks that complete without repeated confirmation, alongside a consequential-action example that stops at the actual commitment boundary. Document the implemented distinction and remaining limitations. The main agent should choose the implementation; this is product direction, not a prescribed classifier or policy architecture.

## Scope of this handoff

This side conversation requested a direction document only. No implementation, packaging, git-state changes, or agent coordination were performed here. The main thread remains responsible for applying the direction and completing its authorized implementation and verification work.
