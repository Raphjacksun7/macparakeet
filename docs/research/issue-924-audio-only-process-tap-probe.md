# Issue #924 audio-only process-tap probe

Status: experiment only; not a production backend.

This probe answers one narrow question from issue #924: can a Core Audio
process tap capture deterministic system playback when MacParakeet does not
start a microphone or VPIO path? It does not reverse ADR-014, compare long-run
reliability with ScreenCaptureKit, or establish compatibility across macOS
versions and output devices.

The probe:

- creates a global Core Audio process tap and private aggregate device;
- requests neither microphone input nor screen pixels;
- plays a generated 997 Hz stereo WAV through `/usr/bin/afplay`;
- records callback count, captured frames, RMS, peak, and 997 Hz amplitude;
- removes the IO callback, aggregate device, and process tap on every exit;
- exits nonzero if tap creation fails, no frames arrive, or the measured signal
  does not clear the declared 0.005 RMS and target-amplitude floors.

Run from the repository root:

```bash
scripts/run-process-tap-audio-only-probe.sh /absolute/output/directory
```

The runner compiles an ad-hoc-signed probe with a stable identifier and writes
`environment.txt`, `result.json`, stdout/stderr, the probe binary, and the
generated WAV into the supplied evidence directory. A result from one machine
is `SAFE-TO-TEST` evidence only. Product integration still requires maintainer
agreement, permission UX design, fallback policy, device/route coverage, and
reproduction of the previously documented VPIO conflict boundary.

## 2026-09-16 result

The probe passed twice as a fresh process on one physical Apple Silicon host:

| Run | Host/output | Format | Callbacks | Frames | RMS | 997 Hz amplitude |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| 1 | macOS 26.6.2 (25G83), `BuiltInSpeakerDevice` | 48 kHz stereo float32 | 328 | 167,936 | 0.186477 | 0.199056 |
| 2 | macOS 26.6.2 (25G83), `BuiltInSpeakerDevice` | 48 kHz stereo float32 | 287 | 146,944 | 0.199352 | 0.227493 |

Both runs created the Core Audio process tap, captured the generated tone above
the declared floors, and exited normally. The microphone and VPIO paths were
not started. The existing production path was not edited; its focused
regression suites also passed:

- `swift test --filter ScreenCaptureLifecycleTests`: 17 tests, 0 failures.
- `swift test --filter MeetingAudioCaptureServiceTests`: 36 tests, 0 failures.

This result directly demonstrates short, audio-only process-tap feasibility on
the named host. It does **not** demonstrate the first-run permission prompt or
permission migration for MacParakeet's signed app, coexistence with VPIO,
long-run stability, route/device changes, sleep/wake recovery, or support on
other macOS releases. `permissionOutcome: process_tap_created` records API
success, not a claim about which consent UI the user saw.
