# ADR-033: Explicit Voice Control

Status: ACCEPTED for implementation; release qualification pending.
Date: 2026-09-19.

## Decision

Add user-invoked Voice Control as a deliberate extension to ADR-027's private
speech-memory direction. Speech can express actions on the user's Mac as well
as material to retain. Commands are ephemeral by default and do not enter the
speech library. This surface is distinct from ordinary dictation.

Reuse the process-wide microphone stream and STT scheduler (ADR-016). Command
capture owns its own session and ephemeral audio, but no independent speech
runtime. Raw audio stays local. The final unmodified transcript supplies the
instruction; dictation cleanup, text replacement and paste processing do not.

Jev receives minimized command and relevant UI text after explicit cloud
consent. Credentials belong in Keychain. This extends ADR-011's cloud boundary
with structured decision requests, separate from configured writing providers.
The provider's response selects typed capabilities and observed targets; it
never grants authority or supplies executable code.

A bounded runner retains goals across fresh observations. Separate generation
is needed only for writing/reasoning that selection cannot supply. Native AX
and an optional browser extension execute local effects with revalidation,
action-bound confirmations, revocable authority and explicit outcomes. Goal
completion must be supported by observed evidence, not a model's optimism.

Spoken rewrites reuse ADR-022's configured providers while preserving the
selection captured for the command. They must not recapture an unrelated
selection after a network wait. Ordinary dictation and Transform cancellation
semantics remain unchanged; command insertion stops queued input on revocation.

## Boundaries

No ambient activation, arbitrary shell/code execution, unattended remote
control, or automatic expansion into another browser profile. Normal dictation
never becomes a command. Secure fields are excluded before context creation.
The user may stop locally without waiting for a model response. Already
submitted effects are reported honestly; unknown effects are not replayed.

## Consequences

The capability and compatibility matrix must be qualified per app, browser,
operation and speech engine. A development build and fixture tests do not imply
stable release readiness. The feature remains explicitly enabled and subject to
its evaluation gates. See the [implementation plan](../../plans/active/2026-09-19-jev-voice-control.md).
