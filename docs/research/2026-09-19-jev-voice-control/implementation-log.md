# Voice Control implementation log

## Authorization and context

2026-09-19: user explicitly requested full implementation, Fable 5.1 medium design review first, meaningful commits, local/API/native qualification, a high-quality PR and demo recording if possible. User authorized implementation judgment and delegation. PR is the delivery boundary; merging or stable release publication is not part of this execution.

Worktree: `/Users/dmoon/code/macparakeet-jev-voice-control`; branch `feat/jev-voice-control`, fetched origin/main base `3f52977e272bf08c00cf53ef7f4db9068b070f46`. Original checkout and unrelated dirty work preserved. Existing research copied into this branch. Credential remains local in original checkout, ignored, never included in artifacts or logs.

## Context zone

Implement explicit Voice Control with shared local speech infrastructure, Jev decisions over observed UI, bounded goal execution, corrections, stop-safe effects and visible outcomes. Native AX and an authenticated optional browser bridge own target identity. Add product entry points, settings/consent, qualification harness and documentation. Reuse configured writing providers where generation is required.

Invariants: normal dictation never interprets commands; existing dictation insertion/cancellation semantics unchanged; no competing STT runtime; no raw audio cloud upload; secrets excluded before model requests; no silent replay of unknown effects; Stop revokes future effects; prior callbacks cannot revive a task; explicit consequence confirmations remain action-bound. No arbitrary generated scripts, ambient listening or personal-browser CDP restart. Preserve user app data and other running dev instances.

## Milestones

- [x] Isolated branch and durable research checkpoint.
- [ ] Fable design review and resolutions.
- [ ] Core typed decisions, policy, bounded runner and focused tests.
- [ ] Native/browser observation and execution.
- [ ] Shared speech, native UI and product wiring.
- [ ] Full scope integration and docs/contracts.
- [ ] Live model and native/browser qualification, demo.
- [ ] Independent review, final checks, PR with exact limitations.

## Verification discipline

Focused suites during implementation; full Swift suite at most once as final gate. No live behavior claimed from mocks. Record exact commands, results and limitations. API use only with sanitized fixtures or explicitly enabled feature context. No credential content in command output.
