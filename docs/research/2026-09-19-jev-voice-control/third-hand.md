# Third Hand: source research for Jev-powered voice control

Research date: 2026-09-19 (America/Los_Angeles). Source-only review; no application launch, API calls, desktop actions, installations, or credential access. Tests were inspected, not executed.

## Verdict

Third Hand is a valuable **native macOS action-loop reference**, especially for Accessibility discovery, focus-safe text entry, bounded candidate selection, stale-target rejection, local OCR recovery, and repeat-action suppression. It is **not a voice implementation**: the entry point is a typed SwiftUI `TextField`; there is no microphone, speech recognizer, endpointing, streaming transcript, or spoken correction loop in this checkout. MacParakeet would supply that whole interaction layer.

The important lesson is that fast Jev selection is only one component of a trustworthy experience. This code spends at least about one second waiting for each action's UI to settle, performs additional network calls for text selection and completion, and can incorrectly show **Done** for unverified or blocked work. Its safeguards are useful ingredients, but its terminal-state handling and privacy filtering should not be copied as a finished design.

## Provenance and reading map

- Repository: https://github.com/shhivv/third-hand
- Local checkout: `references/third-hand`.
- Reviewed commit: [`430394b35dbb44ff8b303bf19da29b0828d92bd2`](https://github.com/shhivv/third-hand/commit/430394b35dbb44ff8b303bf19da29b0828d92bd2), “Treat blocked recovery as done and bump to 0.1.3”. Commit timestamp `2026-09-20T03:00:56+10:00`, equivalent to September 19 in UTC and Los Angeles.
- License: [MIT](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/LICENSE), copyright 2026 Shiv Shanmugam. Retain license attribution when reusing code.
- Package: Swift tools 5.9, macOS 14+, one executable and one test target, no declared package dependencies ([Package.swift](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Package.swift)).
- Local `AGENTS.md` emphasizes preserving signing identity and actual TCC permission state; no build/install instructions were executed for this review.

Source anchors below are pinned to that commit. Paths without URLs are relative to `references/third-hand`.

| Evidence | Source |
|---|---|
| Goal input, activation, cancellation, setup disclosure | [AppDelegate.swift:87–215](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Sources/ThirdHand/AppDelegate.swift#L87-L215), [OverlayPanel.swift:103–158](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Sources/ThirdHand/OverlayPanel.swift#L103-L158) |
| Classifier questions, target candidates, request budget | [JevClient.swift:35–205](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Sources/ThirdHand/JevClient.swift#L35-L205) |
| Text-selection subflow, completion, response decoding | [JevClient.swift:233–388](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Sources/ThirdHand/JevClient.swift#L233-L388) |
| Run lifecycle and per-action policy | [TaskRunner.swift:35–240](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Sources/ThirdHand/TaskRunner.swift#L35-L240) |
| Observe, settle, execute | [TaskRunner.swift:248–380](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Sources/ThirdHand/TaskRunner.swift#L248-L380) |
| Verification and repeat suppression | [RunProgress.swift:9–97](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Sources/ThirdHand/RunProgress.swift#L9-L97) |

## Architecture and actual user experience

1. Control–Space captures the frontmost app and opens a dimmed, app-sized overlay with app icon/name and a typed command field. Return submits; Escape dismisses. The same hotkey cancels an active task.
2. A nonactivating status panel shows stages such as Observing, Thinking, Choosing text, Entering text, and Checking the action, with an explicit cancel button. The runner reactivates the captured application and stops if another app becomes frontmost.
3. Observation prefers an already-enabled, verified Electron debugging connection; otherwise it walks Accessibility. Local Vision OCR is added only during recovery and only with Screen Recording permission.
4. A single Jev request asks for operation, compatible operation-specific targets, completion, and missing-control state. No executable code is generated.
5. The executor validates the proposed operation and target, re-observes targeted controls after model latency, then performs an Accessibility action or synthesized input.
6. It waits for settling, records observed effect, and repeats. It has 30 executed actions, 40 loop iterations, and a three-minute overall budget.

This is a single-app task assistant. Cross-app workflows are not supported: changing frontmost app stops the run. There are no numbered target overlays, target preview, clarification dialogue, correction command, undo ledger, resumable checkpoints, or voice barge-in. The UI exposes task phase, not the selected target or the pending action's consequence. [AppDelegate.swift:87–169](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Sources/ThirdHand/AppDelegate.swift#L87-L169), [StatusIndicatorWindow.swift:38–70](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Sources/ThirdHand/StatusIndicatorWindow.swift#L38-L70).

## Exhaustive discovered classifier and router inventory

### Jev decisions

| Decision / classifier | Candidates or output | Downstream route and limits |
|---|---|---|
| `done` in each action request | `noul`, default 0 on absent/unparseable field | At `>= 0.70`, overrides chosen action to `DONE`; separate fresh completion call follows. Initial decode does not validate finite/range like final completion does. |
| `absent` | `noul`, default 0 | Returned and logged; `absentThreshold = 0.50` exists but is not used to route the runner. Missing-target behavior actually follows `__none__` or `BLOCKED`. |
| `operation` | `CLICK`, `TYPE_TEXT`, `CLICK_TEXT` when compatible targets exist; always `SCROLL_UP`, `SCROLL_DOWN`, `PRESS_RETURN`, `PRESS_TAB`, `PRESS_ESCAPE`, `WAIT`, `DONE`, `BLOCKED` | Exactly one action per loop. Unknown operations rejected. No operation confidence/margin policy. |
| `click_target` | Enabled editable fields, recognized interactive roles, or AXPress/Open/Confirm/Pick actions; `__none__` | Return observed target ID; none becomes `BLOCKED`. |
| `type_text_target` | Enabled AXTextField, AXTextArea, AXComboBox; `__none__` | Return editable target, then separately select entry kind and content. |
| `click_text_target` | OCR regions with geometry; `__none__` | Explicit lower-assurance OCR click path. Prompt says not to click ordinary text, but local code cannot prove interactivity. |
| Text `intent` | `literal`, `unsupported`; `search` added for nonterminal apps | Unsupported throws with request for exact wording. Terminal search/navigation never becomes generated shell code. |
| Text `content` | Up to 100 contiguous user-request phrases, with extracted/quoted literal candidates first; `none` | Separate dependent request conditioned on selected intent; choose exact candidate or fail. No free-form generation. |
| Final `done` | Separate completion-only `noul` question | Validates finite number in 0...1 and threshold 0.70. True and false both currently end with the same user-visible Done callback. |

Evidence: `JevClient.swift:23–25, 35–155, 233–321, 341–388`. All model requests use `jev-latest` and `https://api.typesafe.ai/v1/systemone`; no pinned model version or calibrated threshold evidence is supplied.

### Deterministic routing and execution

| Route | Trigger | Actual behavior |
|---|---|---|
| Setup | No Accessibility / no API key | Show setup or key prompt; hotkey installation tracks permission. |
| Input dismissal | Hotkey while overlay open / Escape | Close prompt; Escape cancellation reactivates target. |
| Run cancellation | Hotkey while runner exists / status × | Cancel task, disconnect CDP, dismiss status. |
| Native observation | Default / failed or empty CDP extraction | AX walk of focused window, fallback app windows. |
| Electron observation | Electron framework plus explicit debug-port arg, owned listener, reachable endpoint | Connect only if exactly one page target and geometry/focus match; otherwise AX. |
| OCR recovery | No usable controls, invalid selector output, BLOCKED, repeated/nonprogressing actions | One local OCR upgrade; permission missing causes explicit stop. |
| Stale-window retry | Window ID/frame changed after selection | Discard decision and re-observe. |
| Stale-target retry | Re-observation cannot match target with same geometry and enabled state | Discard decision and re-observe. |
| Click | CLICK / CLICK_TEXT | Prefer supported AX action; otherwise click center within target window. OCR can only coordinate-click. |
| Text entry | TYPE_TEXT | Confirm actual field focus; request AX focus then click fallback; select-all and Unicode events. Nonterminal field already equal to desired text skips typing; three consecutive skips stop. |
| Terminal text | Known terminal bundle IDs | Control-A / Control-K before literal insertion; no automatic retyping after one successful input; Return remains a separate action. Assumes shell/readline semantics. |
| Keypress | PRESS_RETURN / TAB / ESCAPE | Decode to KEY_PRESS with exact allowed key. Other keyboard shortcuts are not offered by Jev. |
| Scroll | SCROLL_UP / DOWN | Fixed five-line synthesized wheel input at window center; no region, amount, horizontal, or continuous scroll selector. |
| Wait | WAIT | 700 ms wait followed by normal settling/verification. |
| Completion | DONE or done threshold | Fresh observation and second Jev completion check; both confirmed and inconclusive show Done. |
| Service rejection | Non-200 Jev response | Stop with bounded/redacted service detail, rather than OCR retry. |
| Other action-selection errors | Invalid output / timeout | Attempt OCR recovery. |
| Execution error | Input/focus operation fails | Record failed action, re-observe, let progress/recovery policy decide next step. |
| Loop / time budget | 30 actions, 40 observations, 180 seconds | Stop with error unless earlier erroneous Done callback has detached UI ownership. |

`DOUBLE_CLICK`, `RIGHT_CLICK`, arbitrary supported `KEY_PRESS`, and normalized image coordinates appear in lower-level decision validation/execution but are **not reachable Jev choices**. `hasScreenshot` is always false in the runner; screenshot-coordinate selection is not a working route. Do not infer product support from executor cases alone. [AgentTypes.swift:13–57](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Sources/ThirdHand/AgentTypes.swift#L13-L57), `TaskRunner.swift:160,179,324–379`.

## Candidate construction and grounding

Accessibility walking has a nominal 0.8-second budget, 0.1-second AX messaging timeout, depth 30, 3,000 visited nodes, 1,200 collected nodes, and 500 returned elements. It batches common attributes, restricts geometry to the front window, and prioritizes focused controls, outcome evidence, and fields. It discards unlabeled/unvalued controls, so many icon-only affordances are absent. Outcome evidence is partly app-shaped heuristics: “now playing”, “pause”, AXProgressIndicator, AXStatus. [AXTreeWalker.swift:5–46](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Sources/ThirdHand/AXTreeWalker.swift#L5-L46), [AccessibilityElement.swift:15–19](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Sources/ThirdHand/AccessibilityElement.swift#L15-L19).

Jev candidates preserve role compatibility and reserve one choice for none. General choice cap is 255, but production request preparation first selects at most 160 elements, truncates label/value to 160 characters, retains four 256-character history entries, and repeatedly halves candidate count to meet 24,000 bytes. Goals over 4,000 UTF-8 bytes are rejected rather than silently truncated. Focus and outcome evidence score ahead of goal-word overlap. Response targets are decoded against the exact offered shortlist, using original local metadata. This is a strong protection against fabricated/unoffered IDs.

The request's state includes ID, label, role, enabled/focused flags, source, and value, but **not frame, hierarchy, parent label, ordinal, or neighboring context**. Thus “the second Delete”, “the one on the left”, or “Save under Billing” lacks sufficient semantic grounding even though geometry exists locally. Compaction always marks observation as potentially truncated. A MacParakeet adapter should carry concise relational context and expose explicit disambiguation rather than betting on flat duplicate labels.

## Browser and native applicability

The browser adapter is specifically opportunistic **Electron** support, not a general browser integration. It discovers only a debug port already present in the captured process's arguments, checks listener ownership, restricts WebSocket host/port to localhost, accepts exactly one page, and validates page focus and outer-window geometry. It never restarts the target or silently enables remote debugging. These are good ownership boundaries. [ElectronDetector.swift:13–65](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Sources/ThirdHand/ElectronDetector.swift#L13-L65), [CDPClient.swift:16–84](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Sources/ThirdHand/CDPClient.swift#L16-L84).

DOM extraction walks visible ordinary children, uses ARIA/tag roles plus pointer/tabindex heuristics, captures field values and labels, and caps at 500. It does not descend shadow roots or iframe documents, fully resolve accessible names, or hit-test occlusion. The coordinate mapping estimates top chrome from outer height minus inner height. It yields semantic observations but executes through native coordinate/input events, not durable DOM locators. Browser navigation can change document without changing window identity. Native AX references provide stronger identity than the DOM fallback's role/label/geometry matching. [CDPClient.swift:150–265](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Sources/ThirdHand/CDPClient.swift#L150-L265).

OCR runs Apple Vision locally with accurate recognition, language correction, confidence >= 0.8, and a maximum of 500 results. It converts image coordinates to screen coordinates, suppresses overlaps with matching native controls, labels results as OCR static text, and permits a distinct CLICK_TEXT action. Retain provenance, but add a preview/confirmation or stronger local hit-test for ambiguous OCR targets. [VisionObserver.swift:6–70](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Sources/ThirdHand/VisionObserver.swift#L6-L70).

## Important defects and limits to avoid

### 1. Terminal UI state does not reliably terminate execution

`TaskRunner.recover()` calls `taskRunnerDone` when recovery is exhausted and then returns normally (`TaskRunner.swift:225–231`). Callers at lines 99, 115, 142, and 190 continue their run loop. `AppDelegate.taskRunnerDone` clears its `taskRunner` reference at line 155; the runner's asynchronous task still owns its work, and `active` stays true until `run()` actually exits. Source-level consequence: later observation/model calls can occur after Done, and if a later action is admitted it can execute without the UI retaining the runner for cancellation. The loop/time budget eventually bounds it, but this is not a terminal-state guarantee. This is a control-flow finding, not a runtime reproduction.

**MacParakeet requirement:** terminal outcomes must return/throw out of the executor and revoke its action authority before publishing completion. Test that no API call or input event is possible after any done/blocked/cancelled transition, including recovery paths.

### 2. Inconclusive verification is deliberately presented as Done

`TaskRunner.swift:134–136` logs verified=false but calls the same Done delegate as success; `StatusIndicatorWindow.swift:44–48` shows Done and disappears after 1.5 seconds. Recovery exhaustion does likewise. Preserve the good instinct to stop rather than toggle a completed action again, but show **Stopped — result unconfirmed** or **Needs your help**, with the last observed evidence. Completion, safe stopping, and blocked recovery need separate outcomes.

### 3. No local sensitive-field filter or consequential-action policy

The DOM extractor reads `node.value` and treats otherwise unrecognized input types as text fields (`CDPClient.swift:171–177,223–227`), including password inputs. Jev request state includes values (`JevClient.swift:115–118`). Thus visible password-field values can be sent to the remote service if observed and retained. Accessibility value extraction likewise has no explicit secure-role/subrole filter. This is a source-supported data path, not proof that any particular app exposed a password.

There is also no separate policy route for Send, Delete, Purchase, credential entry, or shell command submission. A compatible observed button or Return is sufficient after model selection. MacParakeet needs sensitive-context redaction **before candidate construction**, app/domain controls, explicit cloud-context consent, and consequence-specific confirmation. Prompt instructions are not a substitute for a local policy boundary.

### 4. Stale target checking is useful but incomplete

Re-observation checks matched target, enabled state, and equal geometry. AX identity uses CFEqual; fallback uses source/role/label and nearby frame. It does not bind operation to an immutable document revision or action authority token. Untargeted Return/Tab/Escape only receive window/app checks; focus can change within the same window during network delay. Add focus identity for keyboard actions and a generation/revision check for every action; voice transcript revisions must join that same validity envelope.

### 5. Fast selection does not imply fast action feedback

`settle()` waits at least one second before accepting verified stable UI, polls every 150 ms, requires 400 ms quiet, and caps at 2.5 seconds (`TaskRunner.swift:279–296`). Every TYPE_TEXT introduces two sequential Jev calls after initial operation selection; completion introduces another. AX walking and process inspection also run synchronously in paths reached from the main actor. Actual perceived latency must be measured across speech endpoint, observation, selection, focus, input, and verification, with immediate preview/acknowledgment and action-specific verification. Do not copy a blanket one-second settlement gate into simple click/scroll commands.

### 6. Text extraction is bounded but brittle for long instructions

Candidates enumerate unigrams before bigrams and longer spans, stop at 100, and limit unquoted spans to 12 words. Long requests can exhaust the budget before their useful multiword phrase appears. Prioritized exact/quoted text helps, but spoken “quote” punctuation is not naturally guaranteed. Multiline text is rejected; typing replaces the whole field rather than editing an insertion range. Build command grammar and literal-span preservation around actual STT output, and separate insert, replace, append, select, and transform intentions.

## Privacy and permission boundaries

The app honestly discloses that goal, app name, screen labels/values, and recent action results go to TypeSafe. Screenshots and OCR computation remain local. The key is stored in Keychain and loaded outside hotkey handling because a Keychain prompt can steal target focus (`AppDelegate.swift:38–43,185–205`). Accessibility is required; Screen Recording is conditional for OCR. Unicode event typing avoids modifying the user's clipboard and clears modifier flags to prevent text becoming shortcuts. [InputController.swift:55–77](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Sources/ThirdHand/InputController.swift#L55-L77).

Do not summarize this as “screen content stays local”: extracted screen **text** crosses the network. Action history also embeds target labels and entered text (`TaskRunner.swift:299–302`). Logs omit raw successful goals/text in most events, but service error text is retained up to 400 characters after key redaction; error messages can still contain request details. No provider-retention guarantee was established by this repository review.

## Tests and evidence quality

The checkout contains six test files with coverage for decoder allowlists and request bounds, exact offered-target rejection, text-only payloads, service-error redaction, text candidates and mocked text selection, OCR merge/coordinate mapping, key events, focus polling/cancellation, window selection, repeat suppression, and timeout races. Representative sources: [JevTests.swift:11–166](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Tests/ThirdHandTests/JevTests.swift#L11-L166), [RunProgressTests.swift:9–147](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Tests/ThirdHandTests/RunProgressTests.swift#L9-L147), [TextFieldFocusTests.swift:6–102](https://github.com/shhivv/third-hand/blob/430394b35dbb44ff8b303bf19da29b0828d92bd2/Tests/ThirdHandTests/TextFieldFocusTests.swift#L6-L102).

Tests largely exercise pure helpers and stubbed network responses. They do not establish live Jev accuracy, actual application completion, speech UX, password exclusion, irreversible-action policy, end-to-end recovery termination, or cancellation-to-last-input latency. No latency distribution or reproducible accuracy benchmark was found. `jev_ms` logging measures request round-trip only. README describes the project as experimental and warns reported completion needs user judgment; that caveat is consistent with source limitations. This review did not run the suite and makes no current passing-test claim.

## Example journeys and what MacParakeet should learn

| Intended journey | Third Hand route | MacParakeet requirement |
|---|---|---|
| “Search for Adele” | Find editable target → classify search → choose “Adele” span → focus/replace → Return on later step → inspect result | Preserve entity span, show search target and query, verify results rather than merely successful typing. |
| “Play this album” | Click result/play controls → UI changes → done assessment → separate completion question | Distinguish an available Play button from actual Now Playing evidence; stop without toggling when uncertain. |
| “Click the second Delete” | Flat choice among same-labeled controls; no positional state | Expose numbered choices or contextual labels; bind confirmation to exact item and action. |
| “Scroll down a little” | Fixed five-line scroll at center | Route direction, amount, intended scroll region, and continued/stop state separately. |
| “Type ‘ls -la’” in Terminal | Literal span → known terminal editing keys → type once → separate Return | Show exact command and separate insertion from execution; never retry partially sent command automatically. |
| “Actually, stop” during typing | No voice route; hotkey or status cancel only | Local high-priority stop path independent of Jev/network; invalidate prepared actions and stop Unicode stream. |
| “Make this paragraph shorter” | Text intent unsupported | Route to existing selected-text Transform with explicit selection identity and generative-model boundary. |
| “Open Safari and search…” | Captured-app constraint stops on app change | Cross-app navigation needs explicit target transitions, not weakening the frontmost-app invariant globally. |

## Actionable design lessons

1. **Keep Jev's output typed and capability-scoped.** Build compatible target choices locally and reject unoffered IDs. Give every selection an explicit none/ambiguous path.
2. **Parallelize independent questions, sequence dependent ones deliberately.** Operation and compatible targets can share a request; text kind affects text content. Measure whether a smaller literal/search fast path can safely avoid extra round trips.
3. **Separate action dispatch, observed effect, and task completion.** Each needs its own state and UI. Never equate a changed screen or a callback named Done with verified success.
4. **Give every action a revocable validity envelope.** Include session, transcript revision, app/window/document generation, target identity, and focus identity. Revalidate after model latency and before input.
5. **Make recovery improve evidence, not repeat input.** OCR is a bounded adapter fallback; preserve repeat history across it. Exhausted recovery must truly terminate execution.
6. **Treat target disambiguation as first-class UX.** Geometry and hierarchy must reach a contextual target resolver or a numbered overlay. Flat labels are insufficient for common repeated controls.
7. **Reuse the focus-confirmation discipline.** Confirm the editable field or its inner editor before selecting/replacing, and keep checking during input. Use suitable editor-specific insertion adapters rather than universal select-all.
8. **Keep local OCR while describing the cloud text boundary precisely.** Filter credentials and sensitive content before building model state, not merely at logging time.
9. **Design voice around a command lifecycle this project lacks.** Listening, partial understanding, target preview, commitment, execution, verification, interruption, clarification, correction, and undo must be explicit.
10. **Benchmark complete interactions.** Track first-feedback and end-of-speech-to-action separately from completion latency, false-action rate, wrong-target rate, cancellation leakage, and truthful status. Fast model round trips are promising but do not measure these outcomes.

## Remaining unknowns

No physical application testing, network benchmarking, API-version verification, release-signature verification, or speech testing was performed. Local AX/OCR quality across apps, focus behavior under load, real Jev choice reliability, and runtime manifestation of the control-flow findings remain unmeasured. The next useful experiment is a replayable recorded-observation corpus plus an instrumented native-app/browser fixture that asserts target identity, irreversible-action gating, and zero post-terminal input events.
