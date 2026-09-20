import AppKit
import MacParakeetCore
import MacParakeetViewModels

/// Owns one explicit command session. Ordinary dictation never enters this path.
@MainActor
final class VoiceControlCoordinator {
    static let holdTrigger = HotkeyTrigger.chord(modifiers: ["control", "option"], keyCode: 49)
    static var configuredHoldTrigger: HotkeyTrigger {
        guard let data = UserDefaults.standard.data(forKey: "voiceControl.holdShortcut"),
            let trigger = try? JSONDecoder().decode(HotkeyTrigger.self, from: data)
        else { return holdTrigger }
        return trigger
    }
    let model = VoiceControlViewModel()
    private let speech: VoiceControlSpeechSession
    private let adapter: any VoiceControlAdapter
    private var literalMode = false
    private let rewrite: VoiceControlCommandRouter.Rewrite?
    private let credentials = VoiceControlCredentialStore()
    private let consent = VoiceControlConsentStore()
    private let isStartSuppressed: () -> Bool
    private let conflictingHotkeys: () -> [HotkeyTrigger]
    private let onShortcutChanged: () -> Void
    private var runner: VoiceControlTurnRunner?
    private var panel: VoiceControlPanelController?
    private var hotkey: HotkeyManager?
    private var speechEvents: Task<Void, Never>?
    private var runnerEvents: Task<Void, Never>?
    private var execution: Task<Void, Never>?
    private var capture: Task<Void, Never>?
    private var cleanup: Task<Void, Never>?
    private var adapterStartup: Task<Void, Error>?
    private var browserConnectionGeneration = 0
    private var invocationSnapshot: VoiceControlSnapshot?
    private var speechSubmission = false
    private var currentCaptureID: UUID?
    private var currentUtteranceID: UUID?
    private var invocationSnapshotTask: Task<VoiceControlSnapshot?, Never>?
    private var interactionLease: GUIMutationArbiter.Lease?
    private var sessionGeneration = 0
    private var wantsCapture = false
    private var handsFree = false
    private var acceptingEvents = false
    private var globalEscape: Any?
    private var localEscape: Any?

    init(
        sharedMicStream: SharedMicrophoneStream, scheduler: STTScheduler,
        adapter: any VoiceControlAdapter,
        rewrite: VoiceControlCommandRouter.Rewrite? = nil,
        onShortcutRecording: @escaping (Bool) -> Void = { _ in },
        onShortcutChanged: @escaping () -> Void = {},
        isStartSuppressed: @escaping () -> Bool = { false },
        conflictingHotkeys: @escaping () -> [HotkeyTrigger] = { [] }
    ) {
        speech = VoiceControlSpeechSession(audio: AudioProcessor(sharedMicStream: sharedMicStream), stt: scheduler)
        self.adapter = adapter
        self.rewrite = rewrite
        self.isStartSuppressed = isStartSuppressed
        self.conflictingHotkeys = conflictingHotkeys
        self.onShortcutChanged = onShortcutChanged
        model.consent = consent.hasConsent
        model.writingConsent = UserDefaults.standard.bool(forKey: "voiceControl.writingConsent.v1")
        model.browserEnabled = UserDefaults.standard.bool(forKey: "voiceControl.browserBridgeEnabled.v1")
        model.browserExtensionID = UserDefaults.standard.string(forKey: "voiceControl.browserExtensionID") ?? ""
        model.browserChoice =
            VoiceControlBrowserChoice(
                rawValue: UserDefaults.standard.string(forKey: "voiceControl.browserChoice") ?? "chrome") ?? .chrome
        model.onOpenExtensionFolder = { [weak self] in
            guard let url = VoiceControlBrowserRegistration.bundledExtensionURL() else {
                self?.model.browserSetupStatus =
                    "This build does not include the browser extension. Use a packaged dev build."
                return
            }
            NSWorkspace.shared.open(url)
        }
        model.onRegisterBrowser = { [weak self] in self?.registerBrowser() }
        model.onConnectBrowser = { [weak self] in self?.connectBrowser() }
        model.onBrowserDisabled = { [weak self] in
            UserDefaults.standard.set(false, forKey: "voiceControl.browserBridgeEnabled.v1")
            self?.end(hide: false)
            self?.model.browserSetupStatus = "Browser control is off. Native app controls remain available."
        }
        model.holdTrigger = Self.configuredHoldTrigger
        model.validateShortcut = { [weak self] trigger in
            if self?.conflictingHotkeys().contains(where: { trigger.conflicts(with: $0) }) == true {
                return .blocked("This shortcut is already used by another capture action.")
            }
            return .allowed
        }
        model.onShortcutRecording = { [weak self] recording in
            if recording { self?.suspendHotkey() }
            onShortcutRecording(recording)
            if !recording { self?.installHotkey() }
        }
        model.needsSetup = !consent.hasConsent || (try? credentials.loadAPIKey()) == nil
        model.onListen = { [weak self] in self?.beginCapture(handsFree: true) }
        model.onCommit = { [weak self] in self?.commitCapture() }
        model.onStop = { [weak self] in self?.stop() }
        model.onStopListening = { [weak self] in self?.stopListening() }
        model.onCancel = { [weak self] in self?.cancelTask() }
        model.onEnd = { [weak self] in self?.end() }
        model.onConfirm = { [weak self] in self?.confirm() }
        model.onResume = { [weak self] in self?.resume() }
        model.onSubmit = { [weak self] in self?.submit($0) }
        model.onSaveSetup = { [weak self] in self?.saveSetup() }
        model.onRevokeConsent = { [weak self] in
            guard let self else { return }
            self.consent.hasConsent = false
            self.model.needsSetup = true
            self.end(hide: false)
            self.model.message = "Cloud control is disabled. Normal dictation stays local."
        }
        model.onRevokeWritingConsent = {
            UserDefaults.standard.set(false, forKey: "voiceControl.writingConsent.v1")
        }
        model.onDisable = { [weak self] in
            guard let self else { return }
            self.consent.hasConsent = false
            try? self.credentials.saveAPIKey("")
            self.model.consent = false; self.model.needsSetup = true
            self.end(hide: false)
        }
        model.onSettings = { [weak self] in
            self?.end(hide: false)
            self?.model.needsSetup = true
            self?.show()
        }
        speechEvents = Task { [weak self, speech] in
            for await event in speech.events {
                guard !Task.isCancelled else { return }
                self?.handleSpeech(event)
            }
        }
    }

    func installHotkey() {
        hotkey?.stop(); hotkey = nil
        installTakeoverMonitors()
        guard !conflictingHotkeys().contains(where: { Self.configuredHoldTrigger.conflicts(with: $0) }) else {
            model.message =
                "\(Self.configuredHoldTrigger.displayName) conflicts with another shortcut. Start from the Voice Control menu or change the shortcut in Setup."
            return
        }
        let manager = HotkeyManager(
            trigger: Self.configuredHoldTrigger, gestureMode: .holdOnly,
            holdToTalkStopTailMs: AppHotkeyCoordinator.holdToTalkStopTailMs)
        manager.onStartRecording = { [weak self] _ in self?.beginCapture(handsFree: false) }
        manager.onStopRecording = { [weak self] in self?.commitCapture() }
        manager.onCancelRecording = { [weak self] in self?.stopListening() }
        manager.onDiscardRecording = { [weak self] _ in self?.stopListening() }
        manager.onEscapeWhileIdle = { [weak self] in self?.stop() }
        if manager.start() {
            hotkey = manager
        } else {
            model.message = "The shortcut could not start. Check Accessibility permission, or use Start listening."
        }
    }
    private func installTakeoverMonitors() {
        if globalEscape == nil {
            let mask: NSEvent.EventTypeMask = [
                .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel,
            ]
            globalEscape = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
                let marked = event.cgEvent.map(StreamingCursorEventMarker.isMarked) ?? false
                let key = event.type == .keyDown ? event.keyCode : nil
                let flags = event.modifierFlags.rawValue
                Task { @MainActor in self?.handleExternalInput(key: key, flags: flags, marked: marked) }
            }
            localEscape = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                guard let self else { return event }
                if event.type == .keyDown, event.keyCode == 53 { self.stop(); return event }
                if self.panel?.owns(event: event) == true { return event }
                let marked = event.cgEvent.map(StreamingCursorEventMarker.isMarked) ?? false
                self.handleExternalInput(
                    key: event.type == .keyDown ? event.keyCode : nil,
                    flags: event.modifierFlags.rawValue, marked: marked)
                return event
            }
        }
    }
    private func handleExternalInput(key: UInt16?, flags: UInt, marked: Bool) {
        guard interactionLease != nil, !marked else { return }
        if let key,
            Self.isVoiceShortcutKey(
                key, flags: NSEvent.ModifierFlags(rawValue: flags), trigger: Self.configuredHoldTrigger)
        {
            return
        }
        stop()
        model.message = "Paused because you used the keyboard or mouse. Give a new instruction when ready."
    }
    static func isVoiceShortcutKey(_ key: UInt16, flags: NSEvent.ModifierFlags, trigger: HotkeyTrigger) -> Bool {
        guard key == trigger.keyCode else { return false }
        if trigger.kind == .keyCode { return true }
        guard trigger.kind == .chord else { return false }
        let names = trigger.chordModifiers ?? []
        var expected: NSEvent.ModifierFlags = []
        for (name, flag): (String, NSEvent.ModifierFlags) in [
            ("command", .command), ("option", .option), ("control", .control), ("shift", .shift), ("fn", .function),
        ] {
            if names.contains(name) { expected.insert(flag) }
        }
        return flags.intersection([.command, .option, .control, .shift, .function]) == expected
    }
    func suspendHotkey() { hotkey?.stop() }
    func show() {
        if panel == nil { panel = VoiceControlPanelController(model: model) }
        panel?.show()
    }
    func shutdown() {
        hotkey?.stop()
        if let globalEscape { NSEvent.removeMonitor(globalEscape) }
        if let localEscape { NSEvent.removeMonitor(localEscape) }
        globalEscape = nil; localEscape = nil
        end()
        speechEvents?.cancel()
    }

    private func saveSetup() {
        guard model.consent else { return }
        do {
            if !model.keyInput.isEmpty {
                try credentials.saveAPIKey(model.keyInput.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            guard let key = try credentials.loadAPIKey(), !key.isEmpty else {
                model.message = "Enter a Jev API key first."; return
            }
            if case .blocked(let message)? = model.validateShortcut?(model.holdTrigger) {
                model.message = message; return
            }
            consent.hasConsent = true
            UserDefaults.standard.set(model.writingConsent, forKey: "voiceControl.writingConsent.v1")
            UserDefaults.standard.set(model.browserEnabled, forKey: "voiceControl.browserBridgeEnabled.v1")
            UserDefaults.standard.set(try JSONEncoder().encode(model.holdTrigger), forKey: "voiceControl.holdShortcut")
            model.keyInput = ""
            model.needsSetup = false
            model.message = "Ready. Hold \(model.holdTrigger.displayName), or start a listening session."
            show()
            installHotkey()
            onShortcutChanged()
        } catch { model.message = "Could not save the API key to Keychain." }
    }

    private func registerBrowser() {
        guard !model.isRegisteringBrowser else { return }
        guard let hostURL = VoiceControlBrowserRegistration.bundledHostURL() else {
            model.browserSetupStatus = "This build does not include the native browser host. Use a packaged dev build."
            return
        }
        let extensionID = model.browserExtensionID.trimmingCharacters(in: .whitespacesAndNewlines)
        let browserChoice = model.browserChoice
        let replace = model.replaceBrowserPairing
        end(hide: false)
        let pendingCleanup = cleanup
        model.isRegisteringBrowser = true
        model.browserSetupStatus = "Registering the selected browser extension…"
        Task { [weak self] in
            await pendingCleanup?.value
            do {
                try await VoiceControlBrowserRegistration().register(
                    extensionID: extensionID, browser: browserChoice,
                    hostURL: hostURL, replaceExisting: replace)
                guard let self else { return }
                UserDefaults.standard.set(extensionID, forKey: "voiceControl.browserExtensionID")
                UserDefaults.standard.set(browserChoice.rawValue, forKey: "voiceControl.browserChoice")
                UserDefaults.standard.set(true, forKey: "voiceControl.browserBridgeEnabled.v1")
                self.model.browserEnabled = true
                self.model.replaceBrowserPairing = false
                self.model.browserSetupStatus =
                    "Registered for \(browserChoice.displayName). Starting the browser connection…"
                self.connectBrowser()
            } catch {
                self?.model.browserSetupStatus = error.localizedDescription
            }
            self?.model.isRegisteringBrowser = false
        }
    }

    private func connectBrowser() {
        guard !model.isConnectingBrowser, let browser = adapter as? VoiceControlBrowserMultiplexer else { return }
        let pairing = VoiceControlBrowserWire.directory.appendingPathComponent("pairing.json")
        guard FileManager.default.fileExists(atPath: pairing.path) else {
            model.browserSetupStatus = "Register the extension ID first."
            return
        }
        model.isConnectingBrowser = true
        model.browserEnabled = true
        UserDefaults.standard.set(true, forKey: "voiceControl.browserBridgeEnabled.v1")
        browserConnectionGeneration += 1
        let generation = browserConnectionGeneration
        let pendingCleanup = cleanup
        let connection = Task<Void, Error> { [weak self] in
            await pendingCleanup?.value
            guard let self, self.browserConnectionGeneration == generation else { throw CancellationError() }
            try await browser.startBrowserIfPaired()
            guard self.browserConnectionGeneration == generation else {
                await browser.stop()
                throw CancellationError()
            }
        }
        adapterStartup = connection
        Task { [weak self] in
            do {
                try await connection.value
                guard let self, self.browserConnectionGeneration == generation else { return }
                self.model.browserSetupStatus =
                    "Ready for a tab. Click the extension icon in your browser and choose Connect this tab. The microphone stays off."
            } catch {
                guard let self, self.browserConnectionGeneration == generation else { return }
                self.model.browserSetupStatus = error.localizedDescription
            }
            self?.model.isConnectingBrowser = false
        }
    }

    private func ensureSession() -> Bool {
        guard cleanup == nil, !isStartSuppressed() else { return false }
        if interactionLease != nil { return true }
        guard consent.hasConsent, let key = try? credentials.loadAPIKey(), !key.isEmpty else {
            model.needsSetup = true; show(); return false
        }
        guard let lease = GUIMutationArbiter.shared.acquire(.voiceControl) else {
            model.message = "Finish the current dictation or Transform first."; show(); return false
        }
        interactionLease = lease
        acceptingEvents = true
        sessionGeneration += 1
        let engine = JevDecisionClient(
            apiKey: key,
            consent: {
                UserDefaults.standard.bool(forKey: "voiceControl.cloudContextConsent.v1")
            })
        if UserDefaults.standard.bool(forKey: "voiceControl.browserBridgeEnabled.v1"),
            let browser = adapter as? VoiceControlBrowserMultiplexer
        {
            adapterStartup = Task { try await browser.startBrowserIfPaired() }
        }
        let router = VoiceControlCommandRouter(
            fallback: engine, rewrite: rewrite,
            selectionAtInvocation: { [weak self] in
                await MainActor.run { self?.invocationSnapshot }
            })
        let runner = VoiceControlTurnRunner(adapter: adapter, engine: router)
        self.runner = runner
        runnerEvents?.cancel()
        runnerEvents = Task { [weak self, runner] in
            for await event in runner.events {
                guard !Task.isCancelled, let self, self.acceptingEvents else { return }
                self.model.apply(event)
                switch event {
                case .completed, .failed, .cancelled: self.releaseFinishedSessionIfMicOff()
                default: break
                }
            }
        }
        show()
        return true
    }

    private func beginCapture(handsFree: Bool) {
        guard ensureSession(), !wantsCapture else { return }
        if model.conversation.shouldPauseForSpeech { runner?.stop() }
        wantsCapture = true
        self.handsFree = handsFree
        let generation = sessionGeneration
        let captureID = UUID()
        currentCaptureID = captureID
        currentUtteranceID = nil
        model.microphoneOn = true
        model.phase = .listening
        model.message =
            handsFree
            ? "Listening. Pause after an instruction. Say ‘stop listening’ to turn the mic off."
            : "Listening. Release the shortcut to act."
        if model.conversation.shouldPauseForSpeech {
            let startup = adapterStartup
            invocationSnapshotTask = Task { [adapter] in
                _ = try? await startup?.value
                return try? await adapter.observe()
            }
        }
        capture = Task { [weak self, speech] in
            do {
                guard let self, self.sessionGeneration == generation, self.acceptingEvents else { return }
                try await speech.begin(handsFree: handsFree, captureID: captureID)
                guard self.sessionGeneration == generation else { return }

            } catch {
                guard let self, self.sessionGeneration == generation else { return }
                self.wantsCapture = false; self.model.microphoneOn = false
                self.model.phase = .failed;
                self.model.message = "Could not start the microphone. Check microphone permission."
                self.releaseFinishedSessionIfMicOff()
            }
        }
    }
    private func commitCapture() {
        guard wantsCapture else { return }
        wantsCapture = false; model.microphoneOn = false
        hotkey?.resetToIdle()
        let previous = capture
        capture = Task { [speech] in
            await previous?.value
            await speech.commit()
        }
    }
    private func handleSpeech(_ event: VoiceControlSpeechEvent) {
        guard acceptingEvents else { return }
        switch event {
        case .listening(let capture, let utterance):
            guard currentCaptureID == capture, speech.isCurrentUtterance(utterance) else { return }
            currentUtteranceID = utterance
            if wantsCapture { model.phase = .listening }
        case .speechBegan(let capture, let utterance):
            guard currentCaptureID == capture, wantsCapture, speech.isCurrentUtterance(utterance) else { return }
            currentUtteranceID = utterance
            if model.conversation.shouldPauseForSpeech { runner?.stop() }
            model.phase = .listening; model.message = "Listening to your next instruction…"
            if model.conversation.shouldPauseForSpeech {
                invocationSnapshotTask?.cancel()
                invocationSnapshotTask = Task { [adapter] in try? await adapter.observe() }
            }
        case .level(let level, let capture):
            if currentCaptureID == capture { model.audioLevel = level }
        case .partial(let text, let capture, let utterance):
            guard currentCaptureID == capture, currentUtteranceID == utterance, speech.isCurrentUtterance(utterance)
            else { return }
            model.partialTranscript = text
            // Revoking is safe on a partial. No effect or resume is authorized here.
            let control = text.lowercased().trimmingCharacters(
                in: .whitespacesAndNewlines.union(.punctuationCharacters))
            if ["stop", "stop listening", "cancel", "command stop"].contains(control) { runner?.stop() }
        case .transcribing(let capture, let utterance):
            guard currentCaptureID == capture, currentUtteranceID == utterance, speech.isCurrentUtterance(utterance)
            else { return }
            model.phase = .transcribing; model.message = "Recognizing speech on this Mac…"
        case .transcript(let text, let capture, let utterance):
            guard currentCaptureID == capture, currentUtteranceID == utterance, speech.isCurrentUtterance(utterance)
            else { return }
            model.partialTranscript = ""
            speechSubmission = true
            submit(text)
            speechSubmission = false
        case .stopped(let capture):
            guard currentCaptureID == capture else { return }
            if wantsCapture { stop() }
            model.microphoneOn = false; wantsCapture = false
            releaseFinishedSessionIfMicOff()
        case .failed(let message, let capture):
            guard currentCaptureID == capture else { return }
            model.phase = .failed; model.message = message
        }
    }
    private func submit(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, ensureSession() else { return }
        let command = text.lowercased().trimmingCharacters(in: .punctuationCharacters)
        if literalMode {
            if command == "command mode" {
                literalMode = false; model.literalMode = false
                model.message = "Command mode. Instructions control the app again."
                return
            }
            if command == "command stop" { stop(); return }
            dispatch(Self.literalInstruction(text))
            return
        }
        switch command {
        case "literal mode", "dictation mode":
            literalMode = true; model.literalMode = true
            model.message = "Literal mode. Words are typed. Say ‘command mode’ to return or ‘command stop’ to pause."
            return
        case "stop", "pause": stop(); return
        case "cancel", "cancel task": cancelTask(); return
        case "stop listening": stopListening(); return
        case "end voice control": end(); return
        case "resume": resume(); return
        case "confirm", "confirm this action": confirm(); return
        default: break
        }
        dispatch(text)
    }
    static func literalInstruction(_ text: String) -> String {
        text.lowercased().hasPrefix("type literally ") ? text : "type " + text
    }
    func explainInteractionBusy() {
        model.message =
            "Voice Control still owns this task. End Voice Control to start dictation or paste from history."
        show()
    }
    private func releaseFinishedSessionIfMicOff() {
        guard !wantsCapture, !model.microphoneOn else { return }
        switch model.phase {
        case .done, .failed, .idle: end(hide: false, preservePresentation: true)
        default: break
        }
    }
    private func dispatch(_ text: String) {
        model.transcript = text; model.steps = []
        runner?.stop()
        guard let runner else { return }
        let clarification = model.conversation.takeClarification()
        let needsSnapshot = !speechSubmission
        let snapshotTask = invocationSnapshotTask
        let speechUtterance = currentUtteranceID
        let generation = sessionGeneration
        execution = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.adapterStartup?.value
                if needsSnapshot {
                    self.invocationSnapshot = try? await self.adapter.observe()
                } else if let snapshotTask {
                    self.invocationSnapshot = await snapshotTask.value
                }
                if !needsSnapshot, self.currentUtteranceID != speechUtterance { return }
                guard self.sessionGeneration == generation, self.acceptingEvents else { return }
                if clarification { await runner.clarify(text) } else { await runner.submit(text) }
            } catch {
                guard self.sessionGeneration == generation else { return }
                self.model.phase = .failed;
                self.model.message = "Could not connect to the authorized browser. Check its extension."
                self.releaseFinishedSessionIfMicOff()
            }
        }
    }
    private func stop() {
        guard interactionLease != nil else { return }
        runner?.stop()
        speech.revokePendingTranscripts()
        currentUtteranceID = nil
        model.conversation.cancel()
        model.partialTranscript = ""
        Task { [speech] in await speech.discardPendingUtterance() }
        model.phase = .paused; model.message = "Stopped. Check the app before resuming."
    }
    private func stopListening() {
        stop()
        wantsCapture = false; model.microphoneOn = false
        hotkey?.resetToIdle()
        currentCaptureID = nil
        let prior = capture
        capture = Task { [speech] in
            await speech.cancel()
            await prior?.value
        }
    }
    private func cancelTask() {
        runner?.stop()
        model.conversation.cancel()
        if let runner { execution = Task { await runner.cancel() } }
    }
    private func confirm() {
        guard let runner, model.conversation.takeConfirmation() else { return }
        execution = Task { await runner.confirm() }
    }
    private func resume() {
        guard ensureSession(), let runner else { return }
        execution = Task { await runner.resume() }
    }
    private func end(hide: Bool = true, preservePresentation: Bool = false) {
        guard cleanup == nil else { return }
        if !preservePresentation {
            browserConnectionGeneration += 1
            model.isConnectingBrowser = false
        }
        runner?.stop()
        speech.revokePendingTranscripts()
        acceptingEvents = false; wantsCapture = false; sessionGeneration += 1
        currentCaptureID = nil; currentUtteranceID = nil
        invocationSnapshotTask?.cancel(); invocationSnapshotTask = nil
        if !preservePresentation { literalMode = false; model.literalMode = false }
        model.microphoneOn = false
        hotkey?.resetToIdle()
        if hide { panel?.hide() }
        let priorCapture = capture
        let priorExecution = execution
        let currentRunner = runner
        let startup = adapterStartup
        let browser = adapter as? VoiceControlBrowserMultiplexer
        let lease = interactionLease
        runnerEvents?.cancel()
        cleanup = Task { [weak self, speech] in
            await speech.cancel()
            await priorCapture?.value
            await priorExecution?.value
            await currentRunner?.cancelAndDrain()
            _ = try? await startup?.value
            if !preservePresentation { await browser?.stop() }
            guard let self else { return }
            if let lease { GUIMutationArbiter.shared.release(lease) }
            self.interactionLease = nil; self.runner = nil; self.cleanup = nil
            self.invocationSnapshot = nil
            if !preservePresentation { self.adapterStartup = nil }
            if !preservePresentation {
                self.model.phase = .idle; self.model.transcript = ""; self.model.steps = []
            }
        }
    }
}

struct VoiceControlWritingConsentRequired: LocalizedError {
    var errorDescription: String? {
        "Enable selected-text sharing with your writing provider in Voice Control setup first."
    }
}
