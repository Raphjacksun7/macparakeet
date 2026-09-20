# Correction, recovery, mixed input, and command observability

Date: 2026-09-19, implementation note 2026-09-20.
Research and product-direction note that the current branch now implements.
Correction, recovery, mixed-input pause, and local traces are in the runner
and contract; remaining work is qualification, not a missing architecture.

## Settled user direction

- Keep the already-built separate Voice Control panel for this experimental stage. A visual redesign is not required.
- Users bring their own Jev API key.
- Keep the useful voice-to-Transform integration while leaving the existing Transform functionality intact. Earlier side-conversation advice to remove that integration was an assistant overcorrection.
- Native Accessibility is the execution direction, including browsers. No required extension.
- Ordinary authorized task steps should proceed without repeated confirmations. Payment and comparable consequential commitments remain deliberate boundaries.
- Make correction and recovery first-class experiences.
- For now, manual interaction should yield control to the user. Longer term, the user envisions freely interleaving speech, typing, and mouse interaction without fighting the system.
- Larger experimental task budgets are acceptable. Their exact values are engineering choices to qualify, not settled product promises.
- Logs, observability, and command traces should be first-class tools for understanding and debugging what happened.

## What established work contributes

Google's conversation-design guidance distinguishes acknowledgement from a question requiring approval. It recommends accepting a correction in one utterance and preserving the conversation when parameters change. These are transferable interaction principles, not evidence that a particular MacParakeet classifier is reliable. [Google: confirmations and corrections](https://developers.google.com/assistant/conversation-design/confirmations).

Microsoft's human-AI guidelines emphasize efficient correction, useful short-term memory, dismissal, and explanations. Their validation supports treating recovery as a design requirement rather than an exceptional error dialog. Application to this voice-control implementation remains our design inference. [Microsoft: human-AI interaction guidelines](https://www.microsoft.com/en-us/research/?p=564561).

Mixed-initiative interaction research treats direct manipulation and automation as complementary contributions toward a shared goal. It supports preserving the user's goal while yielding execution control, rather than assuming any manual input means abandonment. It does not establish a universal algorithm for determining whether two actions conflict. [Horvitz: Principles of Mixed-Initiative User Interfaces](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/11/chi99horvitz.pdf).

OpenTelemetry distinguishes an end-to-end trace from its individual operations, with events and correlated logs recording what happened along the way. That vocabulary fits command execution. Adopting it conceptually does not require a collector, remote backend, or new production dependency. [OpenTelemetry: traces](https://opentelemetry.io/docs/concepts/signals/traces/).

## Correction should amend the task, not erase it

The central product contract should be: retain the parts of the request that still apply, revise the part the user corrected, and reassess the current interface before acting.

| Situation | Desired experience | Important boundary |
| --- | --- | --- |
| Before any action: “Find flights to Paris… actually London.” | Commit the corrected destination when the utterance is finalized. | Do not act on an abandoned partial phrase. |
| After filling Paris: “Actually London.” | Update the destination and retain origin/date/trip type. | If London could refer to another parameter, ask which one. |
| Wrong candidate: “No, the other one.” | Refer to the recent relevant alternatives and exclude the rejected choice. | If more than one alternative remains, ask a targeted question or show choices. |
| “Undo that.” after a field change | Restore the known prior field value when still applicable. | Do not overwrite a subsequent manual edit or pretend a submitted transaction can be undone. |
| User fixes a field manually, then says “Continue.” | Observe the corrected state and continue the remaining goal. | Do not restore the old model-selected value or replay completed work. |
| Outcome of a press is unknown | Explain which step was attempted and what could not be verified. | A correction or Resume must not automatically repeat a potentially completed effect. |

Remember only the context that helps resolve these interactions: the active goal, revisions, recent targets and alternatives, actual effect receipts, and any current clarification. Retaining a transcript string alone does not establish what an ambiguous pronoun refers to. Conversely, do not require a large general memory subsystem before implementing useful short-term repair.

Acknowledge small revisions briefly, for example “London instead of Paris,” without asking the user to approve the same clear correction again. Treat this as a proposed UI example, not a mandatory wording or TTS requirement.

Goal revision and physical rollback are different. If a user changes a date after the field was filled, update that field. If a purchase already completed, revising the desired date cannot retroactively change that commitment. Keep the actual effect history intact even when the goal changes.

## Yield now; support collaboration later

For this experiment, typing, clicking, dragging, or scrolling that competes with automation should pause pending automation and leave the task available for repair. Explicit Stop remains authoritative. Do not automatically resume solely because the user has been idle for a short interval.

Mere pointer motion need not mean takeover: it does not itself change a field or activate a control. This is a recommendation for the main agent to validate, not a demand to add high-volume mouse tracking. Distinguish physical user input from our own generated events.

Preserve the distinction between listening, understanding the goal, and holding permission to mutate the UI. Pausing execution should not necessarily erase context or terminate an explicitly enabled conversation. This gives the design room to later let users contribute a click or edit, have the system recognize that progress, and continue coherently.

The future aspiration of freely chatting does not imply that every spoken sentence is a command. Question versus instruction, literal dictation, incidental speech, and explicit task changes need a clear interpretation boundary. Do not implement ambient chat or speculative actions solely on the basis of this architectural aspiration.

## Observability should serve users and developers

A user should be able to expand the current or recent task and answer: What did I request? What changed? Where did it stop? What can I fix? The experimental panel is a suitable starting point; no separate dashboard is required.

Illustrative user-facing activity:

- Destination set to Paris — verified.
- You corrected the destination to London.
- Destination set to London — verified.
- Departure date selected — verified.
- Search pressed — interface changed; waiting for results.

Only show an assertion such as “verified” when the recorded evidence supports it. Do not invent a fluent explanation after the fact or label an AX dispatch success as a completed user goal.

Developer inspection should connect each instruction and correction to its observations, decision requests, proposed actions, policy outcomes, dispatches, and result checks. Include cancellation, stale-result rejection, incomplete observation, retry, timeout, manual takeover, and unknown-effect events. These are often more informative than the happy path.

Useful diagnostic facts include correlation IDs, parent task/revision, native versus other route, application/context identity in an appropriate local form, observation coverage, offered operation counts, selected operation/target reference, model/version, measured decision score, dispatch status, verification result, and timing per stage. Treat a model score as a score, not a calibrated probability that the user's task succeeded. Explain policy decisions from recorded rules and state; do not imply access to hidden model reasoning.

Separate user-facing task content from operational diagnostics. Keep the live task activity useful with its actual context; maintain bounded, content-minimized local diagnostic records by default. If users want a persistent detailed command history or a reproduction bundle containing UI text, make that recording mode and retention clear. Do not silently change the prior ephemeral-command contract into indefinite transcript or full-screen retention. Never include credentials; do not capture raw audio/screenshots merely because tracing exists. Sharing/export should allow inspection and redaction and should not upload automatically.

A trace viewer or offline replay should replay recorded observations and decisions for inspection, not re-execute effects on the live desktop. Command history is not authority to perform the command again.

## Experimental limits

Increase task duration/action budgets where they are interrupting reasonable experiments. Keep finite bounds, immediate Stop, duplicate-effect protection, and no-progress detection. Separate active automation time from time waiting for a human answer, and make remaining-work continuation intelligible. A more generous task budget does not justify extending a stale target or confirmation indefinitely.

Use traces to tune the limits from actual workloads. Do not optimize only for the fastest successful recording while omitting pauses, abandoned tasks, corrections, and unsuccessful requests.

## Qualification questions for the deep dive

Build a correction corpus covering parameter changes, target changes, rejected alternatives, before/after-dispatch corrections, repeated corrections, expired references, manual edits, literal command words, and recovery after unknown effects. Compare short corrective utterances with forced restarts on the same tasks.

Measure task success, turns/time needed to repair an error, unnecessary confirmation/clarification counts, preserved correct work, overwritten manual edits, repeated effects, stale-action dispatch, and time from Stop to the last dispatched effect. Report outcome correctness separately from latency.

For mixed input, distinguish pointer motion, real edits, unrelated app switches, intended navigation, clicks in our own panel, and synthetic events. For observability, deliberately inject faults at observation, model, policy, dispatch, and verification boundaries; check whether the trace locates the true stage without exposing private content.

Outstanding research and runtime work: determine which referent-resolution decisions Jev handles reliably against actual native snapshots; compare small bounded context representations; qualify realistic ambiguous corrections across apps; evaluate user understanding of the activity panel; validate content redaction and diagnostic retention. The primary-source review above grounds the direction but does not settle those empirical questions.

## Scope

This is a side-conversation research artifact. No agents were contacted and no implementation or git state was changed. The main agent owns code changes, final scope, verification, and integration into the PR.
