# Jev voice control: platform, ecosystem, and MacParakeet fit

Date: 2026-09-19. Research, not a shipped capability. Primary-source review; no reference app was executed. Local MacParakeet inspected at `3f52977e272bf08c00cf53ef7f4db9068b070f46`. Recommendations below are this study's synthesis, not upstream performance guarantees.

## Jev contract and implications

Live official docs were fetched on the research date. Temporary copies are in ignored `references/jev-research-sources/`; the public links below are the durable sources.

| Verified contract | Design implication |
|---|---|
| Text/JSON input; Choice, Noul and Score answers | Local ASR supplies the utterance; Accessibility/DOM adapters supply observable controls. Jev selects among grounded actions; it does not synthesize selectors or coordinates. |
| Questions share state, execute independently, and cannot consume each other's answers | Ask conditional target questions: “Assuming operation is click…” and “Assuming operation is type…”. Consume only the branch the operation answer selects. Reobserve between steps whose evidence changes. |
| Choice/Score confidence summarizes a distribution; Noul gives P(yes) without separate confidence | Do not interpret 0.95 confidence as a 95% end-to-end task success rate. Evaluate calibration by route, candidate count, language and model version. |
| Known weaknesses include indirection, irrelevant context, numerical precision and adversarial state | Compute counts, geometry, ordering, dates and permission rules locally. Keep UI content marked as observations and minimize it. Model classification cannot grant authority. |
| Current version `jev-1.13.0`; moving aliases exist | Pin model and question-pack versions for acceptance testing. Treat upgrades as behavioral changes. |
| Published price $0.042/M input tokens, output free; rate limits are explicitly dynamic | Track actual usage. Suppress redundant partials and bound concurrency; do not poll the model continuously while idle. |
| No customer-request training according to vendor; enterprise ZDR offered separately | Cloud command mode needs explicit disclosure. Do not equate “not trained on” with “not retained.” |

Sources: [models](https://docs.typesafe.ai/models.md), [API](https://docs.typesafe.ai/api.md), [confidence](https://docs.typesafe.ai/confidence.md), [state](https://docs.typesafe.ai/concepts/state.md), [fan-out](https://docs.typesafe.ai/patterns/fan-out.md), [function calling](https://docs.typesafe.ai/cookbooks/function_calling.md), [value selection](https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md), [limitations](https://docs.typesafe.ai/model-jaggedness/jev-1.13.md), [legal overview](https://docs.typesafe.ai/legal.md).

### What was measured in this conversation

Before this research request, five synthetic text-only calls to `jev-1.13.0` used three questions per request: action, target, and completeness. The UI was a fabricated document toolbar and two Delete buttons. Each request included about 554–556 input tokens. Observed wall times: 293, 218, 238, 216, and 251 ms (median 238 ms). No audio recognition, UI observation, computer action, or verification was included. Results were displayed in this conversation; this is a transcription of that evidence, not a new benchmark run.

| Utterance | Action | Target | Completeness P(yes) | ms |
|---|---|---|---:|---:|
| click save | click | Save | .91 | 293 |
| scroll down a little | scroll | none | .76 | 218 |
| click the | none | none | .04 | 238 |
| do not click save | none | none | .63 | 216 |
| click delete | click | none (two matching buttons) | .85 | 251 |

The negation example is instructive: action suppression worked, but the completeness question still scored .63 even though its wording excluded negation. Correct composition matters more than any single score. Five hand-picked inputs do not establish calibration, p95 latency, voice accuracy, or app compatibility. Estimated input charge at the published rate was about $0.00012 total; no billing receipt was inspected.

## Additional implementations

### Browser Use Jev Ultrafast — deep source review

Snapshot: [`browser-use/jev-ultrafast` at `1231850a0bf1a0c0341fe408ef1668dbbfdfac46`](https://github.com/browser-use/jev-ultrafast/tree/1231850a0bf1a0c0341fe408ef1668dbbfdfac46), MIT. Locally cloned into ignored `references/jev-ultrafast` for reading. It is a goal-driven browser agent, not a speech frontend.

Its strongest reusable idea is a dynamic action space: one observed node index can support several operations, with a separate target question for each operation. The selected operation consumes only its matching target head. See [`model.py:48–148`](https://github.com/browser-use/jev-ultrafast/blob/1231850a0bf1a0c0341fe408ef1668dbbfdfac46/jev_ultrafast/model.py#L48). Schema validation checks IDs, finite probabilities, normalization, and whether the chosen option actually has maximal probability (`model.py:30–45`). The implementation reports confidence but does not turn that validator into a calibrated abstention policy.

The executor consumes a decision before mutation, checks freshness again after a text-helper call, and records an executed action before attempting the next observation. That last detail prevents a failed post-action read from erasing the fact that an action already happened. Text results may be reused only when the complete helper input is unchanged. See [`agent.py`](https://github.com/browser-use/jev-ultrafast/blob/1231850a0bf1a0c0341fe408ef1668dbbfdfac46/jev_ultrafast/agent.py).

The snapshot retains actual DOM nodes, separates semantic state from geometry, resolves current geometry before input, and checks occlusion. This avoids invalidating every prediction merely because an animation moved a control, while still detecting changed meaning. See [`snapshot.js`](https://github.com/browser-use/jev-ultrafast/blob/1231850a0bf1a0c0341fe408ef1668dbbfdfac46/jev_ultrafast/snapshot.js) and [`browser.py`](https://github.com/browser-use/jev-ultrafast/blob/1231850a0bf1a0c0341fe408ef1668dbbfdfac46/jev_ultrafast/browser.py).

Operations include click, type, select, snapshot-supplied controls, DONE and BLOCKED. Typing calls a separate generative model; an absent required value must not be guessed. Its test source includes stale prediction, incompatible target head, duplicated mutation, text retry context, atomic snapshot, wrong flight details, and execution-receipt preservation scenarios. Tests were read, not run. The 7.1-second flight demo is upstream-reported, not reproduced here.

**Adopt:** operation-conditioned questions, target identity, live geometry, consume-once decisions, execution receipts and independent task-specific verification. **Change:** add voice turn semantics, explicit no-match target options, route-calibrated abstention, consent scopes, manual takeover and stronger terminal-state verification. Do not make every verbatim typing operation pay for a generative call.

### Mature voice interfaces — documentation-level review

| Project / exact snapshot | Observed contribution | Lesson for our proposal |
|---|---|---|
| [Talon community](https://github.com/talonhub/community/tree/a85f85091451eb5950debd598da10e6d52a13e3f), MIT command collection | App-context command sets and “help active” / searchable help | Discoverability should show a few things possible in this window; natural phrasing should not require memorizing a grammar. Talon runtime itself is distinct from this open-source command collection. |
| [Rango](https://github.com/david-tejada/rango/tree/de798d0db94581fe71c2e13572ca85dcedd3fd26), MIT | Browser hints, text targets, named references, tab and scroll-region targeting | Semantic speech first; stable labels on demand or when disambiguating; let users name recurrent targets. Browser control deserves a DOM bridge rather than only simulated keystrokes. |
| [Cursorless](https://github.com/cursorless-dev/cursorless/tree/2b287d967c49b4637a12908f09758f27f127f9fd), MIT | Visual token decorations and structured editing via spoken targets | Borrow the precision of explicit targets and composable edit operations. Do not promise full editor semantics from generic Accessibility text alone. |
| [mac-use](https://github.com/entpnomad/mac-use/tree/b634ca80cfc262f0d4b591d44c96b123c2b34d6d), MIT | AX/System Events tools for windows, elements, menus, field values, keyboard and forms | Build a typed native adapter, with role filters and bounded traversal. Its README acknowledges complex trees can take 10–30 seconds; “any app” and “exact” are marketing claims, not established coverage. |
| [OpenDex](https://github.com/wassgha/opendex/tree/3e898343d1127c8d5075b459acdd55da83b83f04), MIT | Session follow-ups, interrupting replies, compact persistent UI, optional computer control | Keep listening/task state visible and interruption first-class. Our product should reuse native Swift UI and local capture, not adopt its Electron/provider stack. These are README observations, not source-audited guarantees. |
| [Cua](https://github.com/trycua/cua/tree/9bbfa7dd3e27ca7f1861ede70aaca390174493f9), MIT-reported repository | Computer-use infrastructure and cross-OS evaluation tooling | Useful evaluation/sandbox reference, not a necessary production dependency. Per-package dependency licenses require checking before reuse. |

[Apple Voice Control](https://support.apple.com/guide/mac-help/mh40719/mac) is a product baseline rather than open-source implementation: visible names/numbers, hierarchical grids, command/dictation/spelling modes and drag targeting. Our usability study should compare task completion and correction burden with this available baseline. “Jev is faster” is not a substitute for testing the full loop.

## Existing MacParakeet foundations and gaps

Source paths below refer to inspected main, not proposed additions.

| Existing source | Reuse | Limit / adaptation needed |
|---|---|---|
| `Sources/MacParakeetCore/STT/STTScheduler.swift`, `STT/README.md` | Shared runtime, priority, cancellation and engine ownership | Command capture must use this control plane, not instantiate a second STTClient/model runtime. Check active meeting and dictation resource arbitration. |
| `STT/NativeLiveDictating.swift`, `STT/SpeechEngineCapabilities.swift` | Native partial and final result lifecycle | Engine-dependent availability/latency; default TDT preview differs from native streaming; Cohere is batch-only. No uniform word-by-word promise. |
| `Services/Dictation/LiveTranscriptStabilizer.swift:3–22` | Stable display concepts | Explicitly display-only. Its append-only display is not an authoritative committed command stream. Corrections and truncation must remain visible to the decision policy. |
| `Sources/MacParakeet/App/DictationFlowCoordinator.swift` | Capture lifecycle, overlay and hotkey orchestration patterns | Dictation inserts text into the finish target. Command execution needs an independent target binding, not a global change to dictation semantics. |
| `Services/System/AccessibilityService.swift`, `SelectionCaptureService.swift`, `SelectionReplacementService.swift` | AX selected text, clipboard preservation, replacement and verification patterns | Not a whole-screen control inventory or click executor. Clipboard fallback is an interaction, not a harmless observation; do not invoke it during speculative previews. |
| `Services/Transforms/TransformExecutor.swift` | Text rewrite through configured LLM | Existing `run` captures selection when invoked. Spoken rewrite must carry the selection captured at invocation through speech capture, not silently recapture later. |
| `Services/Transforms/TransformRunSerializer.swift` | Cancel previous work and wait for cleanup before starting next | New command execution must share exclusive mutation ownership with transforms/dictation paste, not create competing serializers. |
| `Sources/MacParakeet/Views/Dictation/DictationOverlayController.swift:192`, `DictationOverlayView.swift` | Dormant command presentation, nonactivating overlay patterns | Command overlay model currently lives in app target; proposed new testable view model belongs in ViewModels. Dormant UI is not a working command feature. |
| `Sources/MacParakeet/Hotkey/HotkeyManager.swift`, Core hotkey policy | Configurable gestures and conflict handling | Add deliberate command invocation, plus an accessible session toggle; do not infer actions in ordinary dictation. |
| `Sources/CLI/Commands/LLMTransformCommand.swift` | Existing typed transform prompt entry point | A future computer-control contract needs explicit observation/run/stop/result semantics and consent; no automatic blanket CLI parity requirement for hotkeys/overlays. |

Governing documents: `spec/adr/022-transforms-system-wide-rewrite.md`, `spec/adr/027-product-north-star.md`, `spec/adr/011-llm-cloud-and-local-providers.md`, `plans/active/2026-06-21-spoken-transforms.md`, `plans/active/2026-05-voice-command-agent-mode.md`, `Sources/MacParakeetCore/Services/System/README.md`.

**Product scope implication:** the user now explicitly asks to plan broader computer control. That authorizes this exploration beyond the old parked plan. General desktop automation still extends ADR-027's narrow speech-memory filter. The feature proposal must record the deliberate extension and update governing docs in its implementation phase; do not silently claim it already conforms or rewrite accepted ADRs during research.

## Evidence limits

Only the three user references and Jev Ultrafast received deep source review in this research package. The other ecosystem projects received primary documentation review. No downloaded reference code ran, no current user UI was captured, no OS permissions were changed, and no Jev request was made during this research pass. Prior synthetic calls remain a small feasibility signal. Reference licenses are recorded to support future evaluation; adopting code still requires preserving relevant notices and checking dependencies.
