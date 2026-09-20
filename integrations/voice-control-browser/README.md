# Voice Control browser adapter

This optional Chromium Manifest V3 extension connects an explicitly chosen tab to MacParakeet. Speech recognition and Jev credentials remain in the native app. The extension observes visible controls, executes typed operations, and returns effect receipts. It does not run model-generated JavaScript and does not use CDP.

## Setup

1. Build `swift build --product macparakeet-browser-host` from this checkout. The app must also include Voice Control support.
2. Open Chrome's extensions page, enable Developer mode, and choose **Load unpacked** for this directory's `extension/` folder. Copy its extension ID.
3. Run `python3 integrations/voice-control-browser/install.py --extension-id YOUR_EXTENSION_ID --host /absolute/path/to/macparakeet-browser-host`. Optional `--browser chromium` or `--browser chrome-for-testing` changes the user-scoped native-host manifest location. This explicit installation creates a private pairing configuration; it does not start or restart a browser.
4. Enable Voice Control in MacParakeet. Open the extension popup in the intended tab and choose **Connect this tab**.
5. Use the native Voice Control UI. **Disconnect** in the extension ends browser authorization. Selecting another tab or navigating to a different origin disconnects. Same-origin navigation invalidates old observations and binds the new document automatically.

The installer intentionally preserves an existing pairing/host manifest instead of overwriting it. To change extension installations, stop the bridge and explicitly replace the old pairing and native-host registration. After an abnormal app termination, a stale `bridge.sock` may remain in `~/Library/Application Support/MacParakeet/VoiceControlBrowser/`; verify no bridge app is running before removing that socket. A live socket is never unlinked automatically, protecting parallel worktrees.

This is an unpacked developer installation. Chrome Web Store publication, stable extension-ID provisioning, signed bundle embedding, and automatic host registration during packaged-app setup require release integration; this directory does not imply those distribution steps have happened.

## Protocol and authority

The service worker uses `runtime.connectNative('com.macparakeet.voice_control')`. Chrome launches a small host process whose standard input/output use 32-bit native-byte-order length prefixes followed by UTF-8 JSON. Application frames are limited to 256 KiB in both directions.

The host verifies Chrome's caller-origin argument against the exact paired extension ID, then authenticates to the native app with a randomly generated secret from a mode-0600 file. The private socket directory is mode 0700 and socket mode 0600. The app replies with `hostReady` only after authentication. The pairing secret and Jev key are never sent to the extension. This is a same-user local trust boundary; it does not defend against malware already controlling the user's account.

The extension explicitly sends `authorize` with a context comprising its profile installation UUID, window, tab, document, and a fresh authorization nonce. The app issues a session ID. Each `observe` or `execute` has a request ID, session/context, and deadline. Replies echo session/request identity. Navigation sends `invalidate` before rebinding; old pending requests are rejected. Disconnect discards all pending continuations.

Execution requires a current observation UUID and an offered target/operation. The isolated content script consumes the observation before effects, retains the actual DOM node, and rechecks connection, semantic fingerprint, value/selection, enabled state, visibility, and occlusion. Secure/password/file/hidden/one-time-code fields are excluded before value reads. Observations carry explicit completeness and text-truncation flags. No page `postMessage` channel exists.

The native authority check is serialized with socket dispatch. An already dispatched remote effect cannot be unsent by Stop. Remote execution expires after 750 ms; cancellation sends revocation, and missing acknowledgements produce an **unknown** receipt rather than a retry. This boundary must be reflected in the UI. Browser press effects without independently observable state change also report **unknown**; the engine decides how to inspect/continue without blindly repeating.

## Supported operations and limits

- Visible buttons/links, ordinary text fields, select options, page scroll, open shadow roots.
- Exact field replacement and insertion at a known selection; focus state and selected text are included for native direct-command routing.
- Top document only. Cross-origin frames, closed shadow roots, offscreen controls, rich editor insertion, file pickers, secure fields, arbitrary key shortcuts, and native dialogs are not exposed as supported operations.
- Dynamic elements are discovered on every observation. Node numbers never become persistent selectors.
- No background-tab automation: dispatch checks the bound tab is active in the focused browser window.
- Native AX remains available without pairing. After browser selection, losing authorization never silently redirects the command to a different native app.

## Verification

`tests/dom.test.cjs` runs real DOM interactions through Playwright with a mocked extension message entrypoint. It verifies secure-field exclusion, exact fill, consume-once execution, stale-value rejection, option selection, removed targets, occlusion, expired dispatch, and wrong-document rejection. It does **not** by itself qualify Chrome's native-host installation or an end-to-end microphone session.

Install Playwright in your test environment, then run:

```sh
node integrations/voice-control-browser/tests/dom.test.cjs
swift test --filter VoiceControlBrowserWireTests
```

The DOM script defaults to an installed Chrome channel. `PLAYWRIGHT_CHANNEL` changes the channel; `PLAYWRIGHT_MODULE` can name an existing Playwright module path without modifying the repository's dependencies. Framing tests cover ordered frame boundaries, oversized headers/output, empty frames, and partial-frame EOF. Keep native-host stdout exclusively framed; diagnostics belong on stderr and must omit page content.
