# macbrow source review for Jev-powered MacParakeet command mode

Reviewed 2026-09-19. This is a source review, not a runtime benchmark or endorsement of desktop execution safety.

## Snapshot and verdict

- Repository: https://github.com/timpratim/macbrow
- Local source: `references/macbrow/`.
- Exact commit: `a392a9c56b8ff2978852c0fc911abbeb87b5c5b4`, committed 2026-09-19 13:16:10 +02:00, subject “macbrow: voice-controlled macOS agent”.
- License: MIT, copyright 2026 Pratim Bhosale (`LICENSE:1–3`).
- Python 3.12+, LiveKit Agents, Gradium STT/TTS, Silero VAD, TypeSafe SDK, and `browser-use/jev-ultrafast` (`pyproject.toml:1–24`). No nested AGENTS.md was found in this reference. The parent research brief and MacParakeet instructions governed this review.

**macbrow is an excellent map of the decisions a practical voice agent needs beyond “classify a command,” but its two-state execution controller is not a production interaction model.** Adopt its typed tools, speculative enum questions, browser follow-up context, completeness questions, and explicit outcome checks. Replace its confirmation handling, background execution lifecycle, loosely scoped contextual references, script-generation fallback, and outcome semantics before carrying these ideas into MacParakeet.

A particularly useful lesson is the distinction between fast direct commands and multi-step browser goals. Opening a known site or playing a video can bypass a general browser loop; modifying an unfamiliar page needs observation, action selection, and verification. The strongest UX opportunity is to preserve that fast path while making ambiguity, progress, cancellation, and recovery visible.

All path/line references below are relative to the reference repository at the exact commit. Permalink base: [source tree](https://github.com/timpratim/macbrow/tree/a392a9c56b8ff2978852c0fc911abbeb87b5c5b4).

## Architecture and data flow

`agent.py:64–94,118–129` configures streaming Gradium STT, Silero VAD, Gradium TTS, and a short-answer conversational LLM. It handles commands in `on_user_turn_completed`; preemptive generation is disabled. There is no application-defined partial-transcript action path, no push-to-talk contract, and no endpointing configuration exposed here beyond the selected SDK components. Consequently, its “300 ms routing” should not be confused with end-of-speech-to-action latency. [Voice entrypoint](https://github.com/timpratim/macbrow/blob/a392a9c56b8ff2978852c0fc911abbeb87b5c5b4/agent.py#L64)

`ContextPoller` keeps the frontmost and running apps in a cache refreshed about once per second; installed applications refresh every 60 seconds. Context contains app names, not native Accessibility controls, selections, windows, or focus generations. Probing failures substitute Finder or preserve old cached context. `ToolRegistry.available` offers global tools and tools whose scoped app is running, excluding policy-blocked scripts (`applescript.py:83–148`; `registry.py:60–68,88–102,180–184`).

The primary request asks Jev to choose a tool while speculatively choosing every enum argument of every available tool. Only the winning tool's argument answers are consumed. Free-text arguments require a **second** Jev request selecting among utterance substrings (`router.py:134–176,220–235,253–282`). README language suggesting all arguments need one request is therefore inaccurate for free text. [Router implementation](https://github.com/timpratim/macbrow/blob/a392a9c56b8ff2978852c0fc911abbeb87b5c5b4/macbrow/router.py#L220)

Execution has three tiers:

1. Fixed AppleScript template, escaped argument substitution, optional Python computed argument, final policy scan, `osascript` subprocess.
2. Browser goal: optional clarification/confirmation, LLM objective composition, profile-pinned CDP browser loop delegated to jev-ultrafast, final Jev achievement check, possibly one recovery run.
3. Unknown action: generative LLM creates an AppleScript tool; policy, compilation, superficial effect detection, Jev plausibility review, duplicate check, persistence, spoken first-run confirmation. Learning is enabled by default (`agent.py:112–115`).

The conversational LLM is also used for small talk, browser objective composition, flight query compaction, and text-to-type, so “Jev powered” does not mean “no generation.”

## Full discovered classifier and router inventory

Thresholds here describe this prototype; they are not calibrated recommendations for MacParakeet. `Choice.confidence` and winning option probability are used differently in different places. Preserve that distinction in evaluations.

| Decision | Inputs and output choices | Downstream behavior / threshold | Source |
|---|---|---|---|
| Tool availability | Running app names, scope, template policy | Global + running-app tools, policy-blocked removed | `registry.py:88–102,180–184` |
| Main intent | Utterance, date, frontmost/running apps, optional browser context; available tool names + `chat`, `stop_listening`, `new_action` | Existing tool below confidence 0.45 → uncertain; unknown tool name → new action | `router.py:58–69,94–133,193–219` |
| Speculative enum arguments | One Choice for each enum of every candidate tool; static criteria or live apps | Consume only winner; weakest confidence retained | `router.py:134–150,220–231` |
| Text arguments | Up to nominally 200 utterance spans + `__none__`, one Choice per text slot | Clean selected text; `__none__` becomes default or entire utterance | `router.py:253–282,335–368` |
| Hesitant novel intent | `new_action` confidence <0.6 and best existing probability ≥0.2 | Ask about existing tool instead of code generation | `router.py:198–210` |
| Browser continuation | Noul on recent goal, page title/URL, status, clarification question + utterance | ≥0.5 overrides tool/uncertain/new/chat route to `web_task` | `router.py:153–165`; `agent.py:121–162` |
| Goal completeness | Noul: required website fields supplied without invention, relative date interpretation | <0.4 → clarification if a missing slot exists | `router.py:285–303`; `agent.py:216–235` |
| Missing website detail | Choice: `exact_dates`, `destination`, `origin`, `product`, `recipient`, `content`, `nothing` | Fixed targeted spoken question; merged goal may re-ask a detail once, three total asks | `router.py:316–328`; `agent.py:132–161,531–538` |
| Forbidden website goal | Noul: purchase/payment/sign-in/account modification required | ≥0.6 → refusal; additional hard-term regex | `router.py:304–315`; `agent.py:556–564` |
| Pending approval | Separate confirm/deny Nouls on current utterance | Confirm ≥0.6 and greater than denial → execute staged action; deny ≥0.6 → cancel; neither → discard pending action, fresh route | `router.py:166–174`; `agent.py:166–176` |
| Text pronoun resolution | Exact pronoun set → previous successful arguments for same tool | Replace from memory or ask who is meant | `agent.py:37–49,464–477` |
| Argument confidence | Weakest selected enum/text argument | <0.35 → spoken question, stage original args | `agent.py:202–210` |
| Native action risk | Explicit flag or risky-script regex | Stage and ask before execution | `registry.py:42–48,127–142`; `agent.py:242–247` |
| Browser state-changing goal | Regex includes cart/send/post/book/upload/delete/save/create/edit/etc. | Stage entire utterance and ask permission | `policy.py:237–253`; `agent.py:236–240` |
| Computed argument | Resolver function name from reviewed tool schema | `youtube_first_result`; fetch failure → spoken error | `resolvers.py:38–66`; `agent.py:485–494` |
| Generated tool feasibility | LLM structured `feasible` field | False → speak reason; malformed → retry | `generator.py:77–95,188–205` |
| Generated script acceptance | Policy, compile result, effect regex, Jev `works` Noul | Up to 3 attempts, policy stops after 2 strikes; plausibility <0.4 repairs | `generator.py:188–269,356–382` |
| Duplicate learned action | Choice over available tools + `__none__` | Confidence ≥0.6 → reuse existing tool | `generator.py:317–354` |
| Browser objective composition | LLM structured `objective`, `success`, `search_query` | Resolve references; keep user constraints; use direct search URL where available | `browser_task.py:171–213`; `agent.py:306–328` |
| Browser operation and target | Delegated to jev-ultrafast indexed controls | README describes click/type/select/scroll/wait/done; exact upstream decision internals not present in this repository | `README.md:43–47`; `browser_task.py:500–605` |
| Field value | LLM schema text or null | Null/blank/>2000 characters → no typing | `browser_task.py:255–301` |
| Achievement | Jev Noul on objective/success + final title, URL, first 3000 text characters | ≥0.5 verified; below threshold permits one more run; unavailable returns `None` | `agent.py:330–350,383–415` |
| Stall diagnosis | Choice: `missing_details`, `login_required`, `unsupported_page`, `already_satisfied`, `wandered`, `unclear` | Chosen probability ≥0.55 → fixed spoken explanation | `agent.py:417–449,539–545` |

Permalinks: [confirmation and browser dispatch](https://github.com/timpratim/macbrow/blob/a392a9c56b8ff2978852c0fc911abbeb87b5c5b4/macbrow/agent.py#L166), [website questions](https://github.com/timpratim/macbrow/blob/a392a9c56b8ff2978852c0fc911abbeb87b5c5b4/macbrow/router.py#L285), [verification and stall reasons](https://github.com/timpratim/macbrow/blob/a392a9c56b8ff2978852c0fc911abbeb87b5c5b4/macbrow/agent.py#L383), [generation gates](https://github.com/timpratim/macbrow/blob/a392a9c56b8ff2978852c0fc911abbeb87b5c5b4/macbrow/generator.py#L188).

## Seed capability inventory

The checked-in seed contains **32 tools** (30 allowed and 2 blocked by the default policy, as asserted by `tests/test_policy.py:8–54`). The README's allowed categories include capabilities that may require learned actions; they are not all seed implementations. In particular, there is no checked-in Slack/Message/Mail sending tool or general native control discovery implementation.

| Family | Complete seed names | Arguments / scope | Evidence |
|---|---|---|---|
| Desktop and system | `set_volume`, `open_app`, `quit_app`, `hide_others`, `toggle_dark_mode`, `show_notification`, `take_screenshot`, `lock_screen`, `empty_trash` | Volume enum; live-app enum; dictated notification; mostly global. Trash is policy blocked | `tools/seed.json:3–143` |
| Safari | `safari_get_url`, `safari_open`, `safari_new_tab`, `safari_close_tab`, `safari_close_all_tabs`, `safari_reload`, `safari_back` | Safari must be running; open has site enum and text query | `tools/seed.json:145–267` |
| Chrome and web | `chrome_get_url`, `chrome_open`, `youtube_play`, `web_task`, `chrome_close_tab`, `chrome_close_all_tabs`, `chrome_reload` | Chrome-scoped except YouTube and web task; query text; web site enum | `tools/seed.json:269–438` |
| Files and notes | `finder_open_folder`, `notes_create` | Folder enum: desktop/downloads/documents/home/applications; note body text | `tools/seed.json:440–481` |
| Music | `music_play_pause`, `music_next`, `music_now_playing` | Music running | `tools/seed.json:483–516` |
| Spotify | `spotify_play_pause`, `spotify_next`, `spotify_now_playing` | Spotify running | `tools/seed.json:518–549` |
| Terminal | `terminal_run` | Text command, Terminal running; policy blocked | `tools/seed.json:551–570` |

`web_task` site choices: Amazon, Gmail, Google, YouTube, X/Twitter, LinkedIn, GitHub, Google Calendar, Google Drive, Notion, other, Google Flights, Google Maps, Google Shopping (`seed.json:373–391`). `current_tab` is inserted by follow-up routing rather than selected by this seed enum. Browser openers have a separate 30-option site list including Docs, Slack, Figma, ChatGPT, Claude, Reddit, Wikipedia, Netflix, Spotify web, Hacker News, Stack Overflow, Hugging Face, Linear, Vercel, LiveKit, Gradium, TypeSafe, Outlook, and WhatsApp web (`seed.json:161–197,285–321`). [Seed definitions](https://github.com/timpratim/macbrow/blob/a392a9c56b8ff2978852c0fc911abbeb87b5c5b4/tools/seed.json#L367)

## UX strengths worth adopting

1. **Fast direct paths for ordinary work.** App activation, volume, tab operations, opening a search URL, and video lookup do not need a general page-navigation agent. Define explicit executor contracts for them and measure their latency separately.
2. **Argument classification parallel to intent.** The speculative enum approach reduces serial network latency for bounded small registries. Benchmark payload/candidate growth before extending it to hundreds of controls.
3. **Ask the missing question, not “please clarify.”** Dates, origin, destination, recipient, and content have specific questions. Put the answers in a real slot-filling session so a user can say “Tuesday, from Oakland” without repeating the task.
4. **Continue in the same tab.** macbrow stores goal, title, URL, tab ID and status for 15 minutes. “Make that black” or “the return date is November 4” is a first-class follow-up. MacParakeet should bind this to an explicit task and target identity, with visible context.
5. **Separate objective from success evidence.** The browser agent receives a concrete completion criterion, and another Jev judgment checks it. This is substantially better than treating a click as task completion.
6. **Keep result pages visible.** Browser close detaches and restores device metrics while leaving the working tab open (`browser_task.py:399–412`). The user can inspect, correct, or take over.
7. **Announce slow transitions.** Learning and browser execution have short spoken acknowledgments, and browser progress is emitted every 12 seconds. A polished UI should show progress sooner visually while keeping voice sparse and optional.
8. **Adapt execution to the real control.** The browser click/fill patch scrolls an observed control into view, verifies visibility/disabled/read-only state and hit testing, then acts (`browser_task.py:420–497`). These guards belong in executors, not in model prompts.

## Concrete defects and limits to avoid

These findings are code-grounded inferences, not reproduced desktop incidents.

- **Clarification is implemented as confirmation.** “Which app?” stages the original low-confidence args; a subsequent “yes” runs them. A supplied replacement value is instead routed as a new command. Uncertain “A or B?” also stages only A. Native unresolved pronouns ask a question without storing a slot-resolution session. Use separate `clarifying(slot, candidates)` and `awaitingApproval(plan)` states (`agent.py:166–207`).
- **Uncertain browser routes lose the original goal.** `_stage(route.tool, route.args)` is used for uncertain intent and low-confidence arguments without `utterance`; approving it executes a browser tool with an empty goal (`agent.py:193–207,460–462,482–484`). All pending actions need a complete immutable intent envelope.
- **The browser site fallback is unreachable.** The general weakest-argument branch returns before the following browser-specific low-confidence branch (`agent.py:203–210`). This explains why ordering of router paths requires tests, not only threshold tuning.
- **Cancellation is not a demonstrated execution guarantee.** The controller has no operation token, shared cancellation event, per-session execution lock, or stale-generation check. `run_task` uses `asyncio.to_thread`; cancelling its await does not inherently stop the thread. `_with_timeout` abandons a daemon thread still running. The 90-second browser budget is checked only after a yielded step. Timed-out connection work can continue; a hung step can exceed the nominal budget (`browser_task.py:523–554,602–605,644–660`). The dependency may add its own limits, but the local code does not guarantee stopping it.
- **Pending confirmations do not expire or revalidate identity.** `Pending.staged_at` is assigned but never read. The script can target whatever front window or active tab exists later. Context polling records app names only (`agent.py:70–75,460–462`; `applescript.py:83–148`). MacParakeet needs app/process/window/tab/control generations and revalidation before mutation.
- **Success can fail open.** A failed achievement request returns `None`; `executed` accepts `achieved is None`. AppleScript success means exit status zero, even when script output says no window was open or the wrong app remained in front (`agent.py:350,413–415,502–528`). Use `verified`, `executed-unverified`, `blocked`, and `failed` states with honest copy.
- **The policy is a regex filter, not a capability boundary.** Generated scripts can interact with System Events and browser JavaScript; checks cannot prove semantic safety. Browser restrictions mostly govern the starting goal or appear in prompts; the local patch does not authorize each control action against the user's intended effect. Reviewed typed actions with per-effect authorization are preferable to generated scripts for the shipping feature (`policy.py`; `browser_task.py:46–56,420–497`).
- **Profile pinning falls back to an unintended account.** Missing configured email falls back to last-used/Default, and a failed profile context probe falls back to the default browser context (`chrome.py:40–62`; `browser_task.py:324–349,371–375`). For work/personal identity-sensitive actions, failed identity resolution must ask or stop.
- **Browser follow-up matching can override unrelated action classes.** At 0.5 it wins over all tool/uncertain/new/chat routes; stored context can persist for 15 minutes. Pronoun args are remembered per tool without a time limit. Context continuity should be explicit and inspectable, with corrections clearing obsolete assumptions (`agent.py:121–130,451–477`).
- **Text extraction corrupts literal content.** `_clean_value` always rewrites spoken “dot” and “slash” and strips terminal punctuation/quotes, including notes and messages. `__none__` silently becomes the whole command; one-character spans are excluded. Suffix generation can exceed its nominal 200 candidate budget for very long input. Use field-specific normalization and a real missing-value state (`router.py:257–282,335–368`).
- **Choice capacity has an off-by-one.** Tool selection takes `255 - 2` tools and adds three special choices, potentially producing 256 options. Speculative args also iterate all available tools rather than the truncated intent set (`router.py:94–119,134–150`; `registry.py:34`). Hierarchical routing must bound both question and candidate counts.
- **UI recovery lacks inspection affordances.** There is no native target highlight, live transcript chip, alternatives picker, plan preview, undo receipt, action timeline, or “take over” control in this source. Voice-only “Done in N steps” reports mechanics rather than the user's result.

## Example journeys and MacParakeet implications

| User journey | macbrow path | Better MacParakeet experience |
|---|---|---|
| “Open Notes” | App enum + AppleScript activation | Immediate app label; verify frontmost app; no verbose narration |
| “Search GitHub for Swift audio” | Browser opener + text span + direct search URL | Show exact query and browser/profile; preserve punctuation where meaningful |
| “Find flights to Tokyo next month” | Missing dates/origin questions, then composed browser task | Visible editable trip slots; answers update slots; show plan before first browser action |
| “Make the return November fourth” | Browser follow-up Noul; reuse tab if present | Keep selected trip context visible; update exactly one field and verify |
| “No, the second one” | Follow-up or generic intent; contextual targeting delegated | Numbered candidates tied to current snapshot; selection resolves the pending ambiguity |
| “Send her another message” | Learned action + per-tool pronoun memory | Explicit recipient chip, content preview, scoped confirmation, verified send result |
| “Stop” while page navigation is active | Stop intent exists, but in-flight execution cancellation not established | Local immediate cancel; abort queued actions and reject all late decisions; leave visible last state |
| “Do that again” | No dedicated repeat route in the reviewed controller | Replay intent with fresh targets and risk review; never replay stale raw coordinates |

Native macOS applicability is strongest for reviewed app commands plus Accessibility-backed actions. This project does not implement a general native AX candidate table; MacParakeet would need to build that. Browser DOM controls offer richer semantic evidence than native app-name context, but browser tasks also bring iframe/shadow-root/canvas, account identity, dynamic layout, and navigation lifecycle requirements. Do not claim coverage of those from this wrapper alone.

## Privacy, permissions, and observability

Audio goes to Gradium; command text, app names, options, and relevant browser context go to Jev. Browser text helper and objective composition can go to LiveKit's hosted LLM unless LM Studio is configured. Native tools themselves run locally, but that does not make the pipeline local-first. The code logs utterances, selected arguments, objective/search strings, browser URLs, and typed text (`agent.py:71–75`; `router.py:238–244`; `macbrow/agent.py:320,351–360`; `browser_task.py:555–565`). Learned tools persist executable templates locally in `tools/learned.json` (`registry.py:186–200`).

MacParakeet should keep local STT, show an explicit Jev/cloud-context boundary, minimize transmitted UI context, avoid password/secure controls, and make diagnostic logging opt-in with redaction. Permissions need a first-run explanation for Accessibility/Automation/browser integration; browser remote debugging is a powerful account-context surface and should not be silently enabled. macbrow's README documents per-app Automation prompts and Chrome remote debugging setup, but this is not a permission UX implementation (`README.md:75–82`).

## Evidence quality and evaluation backlog

README reports roughly 300 ms routing, 11 seconds/4 steps for Amazon cart addition, 3.7 seconds/6 steps for a flight correction, and 1.6 seconds from speech end to playing a trailer (`README.md:33–55`). These are author-reported examples without a checked-in reproducible benchmark or latency distribution. This review made no API calls, read no credentials or browser profiles, installed nothing, and executed no computer actions.

The checked-in test files cover policy examples, registry escaping/persistence/scope, Chrome profile lookup, resolver parsing, and text-span helpers. README claims 26 offline tests. There are no checked-in agent-state-machine, cancellation, real-browser, audio-endpointing, or model-accuracy tests in the reviewed test directory. This report does not claim that tests were run.

Before adopting this architecture, evaluate: negated/incomplete commands; interruption during routing and after staging; ambiguous app/control names; missing arguments; a new command during an old task; changed focused window; stale or closed tabs; profile mismatch; required-field clarification; literal punctuation; duplicate execution; service outage; lost completion evidence; and stop latency during blocked I/O. Measure end-of-speech→preview, end-of-speech→verified action, wrong-target rate, inappropriate-execution rate, clarification rate, correction cost, task success, and p50/p95 tail latency independently.

**Recommended transfer:** build the full experience around typed commands, grounded targets, context-bound corrections, and verified effects. Jev can power many narrow decisions in that system. macbrow shows that the classifier is only one decision among roughly twenty; the quality of the surrounding state machine determines whether fast decisions become a dependable voice UI.
