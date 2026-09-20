# Fresh-eye review — Voice Control tools-first (2026-09-20)

Independent pass against the PR draft claims, the current diff, and pre-Jev macOS computer-control references (`third-hand`, `jev-use` AX half, `mac-use`, Apple Voice Control). Fable 5.1 medium: [consult-fable-tools-first.md](consult-fable-tools-first.md).

This is not a merge. Live Flights results and the microphone path remain unproven. Full Swift suite not run.

## Claims vs code

| PR draft claim | Holds? |
|---|---|
| Native AX only; no required extension | Yes |
| Jev is the judge of competing landings | Yes, when several picker rows remain |
| Unique clicks stay local | **Was** prefix-only (`click Save`). Now also bare unique names on a plain window |
| Confirm only pay/delete/send | Yes. Return/Enter keys are ordinary host tools |
| Stale AX IDs rematch by unique label | `bind` did. Numbered picks now rematch id **and** label; confirmation reobserves after expiry |
| Optional connected-tab DOM adapter | Follow-up wording leftover. Not a shipping path. Native AX remains the product |
| CI on `aae51715` pending | Stale status line. Do not treat as current evidence |

## Block vs follow-up

**Blocks (fixed this pass):**

- Prefixed `click`/`press` was required; Apple Voice Control and third-hand match by unique name. Bare unique labels are now local tools on `.plain` snapshots.
- `press return` could bind a button named Return before sending a key. Reserved keys are keys; `click Return` still presses the control.
- Repeat `type hello` into a field that already holds `hello` would insert again (` hello`). Skip with `.information`.
- Return/Enter keys were `.unknown` unless the focused label contained “search”, which prompted “are you sure?” — the extra safety veto the product forbids.
- Numbered pick bound only snapshot-local IDs. IDs are reassigned every observe. Resolve now requires matching label, with unique-label rematch if the id moved.
- Confirmation performed against the pending snapshot. A slow “yes” past 20s failed instead of reobserve+bind.

**Follow-up, not merge hostages:**

- Spoken-tool presses that return `.unknown` still pause. Completing them needs a compilation-origin flag so plan-driven presses keep pausing.
- Join-space assumes the caret is at `value.last`. Mid-field selection is a different request (now not skipped) but still not caret-aware.
- `open Settings` prefers a Settings **control** over the Settings **app** when both exist. Help copy says so.
- Unconstrained Jev leftover on generic pages is still `operation` + `target_*`. Documented, not pretended away.
- Live ZRH→LON and microphone qualification.

## Architecture after this pass

```
observe AX → compile a host tool if unique → execute → verify
          → numbered pick if 2–6 names collide
          → Jev Choice only among competing landings / leftover
          → confirm only pay / delete / send
```

Jev is not a tool runtime and not a sensitivity guard. Confirmation copy is the guard. Host tools are the 2026 computer-control path; Jev is the chooser when the host cannot compile.

## Verified

`swift test --filter VoiceControl` — **136 tests, 0 failures**. Combined `VoiceControl|DictationFlowCoordinator|TransformRunSerializer` — **191 / 0**.

## Not verified

Live Flights results, integrated microphone, full Swift suite, hosted CI on this HEAD. No reference binary was executed.
