# Current integration findings

Verified against base 3f52977e by two independent source explorers before coding.

## Speech

Use a dedicated AudioProcessor(sharedMicStream: environment.sharedMicStream)
with environment.sttScheduler. Same process microphone engine and speech runtime,
separate command recorder/session. STTTranscribing and
STTLiveDictationTranscribing provide final/streaming seams. Commands use raw final
text, not DictationService cleanup/history/AI formatting/paste. Audio sample sink
is 16 kHz Float32 and supports endpointing. Native live sessions must be finished
or cancelled before submitting a final interactive job. TDT display previews
cannot authorize actions. Endpointing must see actual speech first and respect
revisions, bounds and cancellation. Stop/transcribe/restart introduces a deaf gap;
do not call that uninterrupted hands-free recognition.

## Mutation ownership

DictationFlowCoordinator.isStartSuppressed is an admission seam.
TransformsCoordinator.handleTrigger owns Transform admission; its run serializer
can finish paste cleanup after cancellation, so refusal/drain is required before
command ownership. Menu/history paste actions also mutate foreground text.
A gate must cover real operation lifetime, not only an event tap being suspended.

## Native observation

Existing AX code is selection-oriented. New adapter needs retained actual handles,
PID and focused window identity, secure-role exclusion before value reads, bounded
traversal, AX messaging timeout, fresh semantic checks and verified postconditions.
SelectionReplacementService returns write success without rereading; this is not
an independent verification oracle.

## Browser

No existing general-purpose IPC transport. Prefer MV3 extension to a small native
messaging host and a private app-owned Unix socket. Explicit tab/profile/document
binding; no fallback to another tab. Native host origin allowlist and bounded
framing; socket private directory/permissions and connection authorization. Never
accept instructions via page postMessage or generated script. Nodes must remain
connected, visible, semantically unchanged and unobscured at execution. Open
shadow roots can be traversed; unsupported frames/closed roots must be explicit.

Primary framing reference: https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging
