import AppKit
import MacParakeetCore
import MacParakeetViewModels

/// Owns one explicit command session. Ordinary dictation never enters this path.
@MainActor
final class VoiceControlCoordinator {
    static let holdTrigger = HotkeyTrigger.chord(modifiers: ["control", "option"], keyCode: 49)
    static var configuredHoldTrigger: HotkeyTrigger {
        guard let data = UserDefaults.standard.data(forKey: "voiceControl.holdShortcut"),
              let trigger = try? JSONDecoder().decode(HotkeyTrigger.self, from: data) else { return holdTrigger }
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
    private var runner: VoiceControlTurnRunner?
    private var panel: VoiceControlPanelController?
    private var hotkey: HotkeyManager?
    private var speechEvents: Task<Void, Never>?
    private var runnerEvents: Task<Void, Never>?
    private var execution: Task<Void, Never>?
    private var capture: Task<Void, Never>?
    private var cleanup: Task<Void, Never>?
    private var adapterStartup: Task<Void, Error>?
    private var invocationSnapshot: VoiceControlSnapshot?
    private var speechSubmission = false
    private var interactionLease: GUIMutationArbiter.Lease?
    private var sessionGeneration = 0
    private var wantsCapture = false
    private var handsFree = false
    private var acceptingEvents = false
    private var globalEscape: Any?
    private var localEscape: Any?

    init(sharedMicStream: SharedMicrophoneStream, scheduler: STTScheduler,
         adapter: any VoiceControlAdapter,
         rewrite: VoiceControlCommandRouter.Rewrite? = nil,
         onShortcutRecording: @escaping (Bool) -> Void = { _ in },
         isStartSuppressed: @escaping () -> Bool = { false },
         conflictingHotkeys: @escaping () -> [HotkeyTrigger] = { [] }) {
        speech = VoiceControlSpeechSession(audio: AudioProcessor(sharedMicStream: sharedMicStream), stt: scheduler)
        self.adapter = adapter
        self.rewrite = rewrite
        self.isStartSuppressed = isStartSuppressed
        self.conflictingHotkeys = conflictingHotkeys
        model.consent = consent.hasConsent
        model.writingConsent = UserDefaults.standard.bool(forKey: "voiceControl.writingConsent.v1")
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
        guard !conflictingHotkeys().contains(where: { Self.configuredHoldTrigger.conflicts(with: $0) }) else {
            model.message = "Control–Option–Space conflicts with another shortcut. Start from the Voice Control menu."
            return
        }
        let manager = HotkeyManager(trigger: Self.configuredHoldTrigger, gestureMode: .holdOnly,
                                   holdToTalkStopTailMs: AppHotkeyCoordinator.holdToTalkStopTailMs)
        manager.onStartRecording = { [weak self] _ in self?.beginCapture(handsFree: false) }
        manager.onStopRecording = { [weak self] in self?.commitCapture() }
        manager.onCancelRecording = { [weak self] in self?.stopListening() }
        manager.onDiscardRecording = { [weak self] _ in self?.stopListening() }
        manager.onEscapeWhileIdle = { [weak self] in self?.stop() }
        if manager.start() { hotkey = manager }
        if globalEscape == nil {
            globalEscape = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { Task { @MainActor in self?.stop() } }
            }
            localEscape = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { self?.stop() }
                return event
            }
        }
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
    }

    private func saveSetup() {
        guard model.consent else { return }
        do {
            if !model.keyInput.isEmpty { try credentials.saveAPIKey(model.keyInput.trimmingCharacters(in: .whitespacesAndNewlines)) }
            guard let key = try credentials.loadAPIKey(), !key.isEmpty else {
                model.message = "Enter a Jev API key first."; return
            }
            if case .blocked(let message)? = model.validateShortcut?(model.holdTrigger) {
                model.message = message; return
            }
            consent.hasConsent = true
            UserDefaults.standard.set(model.writingConsent, forKey: "voiceControl.writingConsent.v1")
            UserDefaults.standard.set(try JSONEncoder().encode(model.holdTrigger), forKey: "voiceControl.holdShortcut")
            model.keyInput = ""
            model.needsSetup = false
            model.message = "Ready. Hold Control–Option–Space, or start a listening session."
            installHotkey()
        } catch { model.message = "Could not save the API key to Keychain." }
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
        let engine = JevDecisionClient(apiKey: key, consent: {
            UserDefaults.standard.bool(forKey: "voiceControl.cloudContextConsent.v1")
        })
        if let browser = adapter as? VoiceControlBrowserMultiplexer {
            adapterStartup = Task { try await browser.startBrowserIfPaired() }
        }
        let router = VoiceControlCommandRouter(fallback: engine, rewrite: rewrite, selectionAtInvocation: { [weak self] in
            await MainActor.run { self?.invocationSnapshot }
        })
        let runner = VoiceControlTurnRunner(adapter: adapter, engine: router)
        self.runner = runner
        runnerEvents?.cancel()
        runnerEvents = Task { [weak self, runner] in
            for await event in runner.events {
                guard !Task.isCancelled, let self, self.acceptingEvents else { return }
                self.model.apply(event)
            }
        }
        show()
        return true
    }

    private func beginCapture(handsFree: Bool) {
        guard ensureSession(), !wantsCapture else { return }
        runner?.stop()
        wantsCapture = true
        self.handsFree = handsFree
        let generation = sessionGeneration
        model.microphoneOn = true
        model.phase = .listening
        model.message = handsFree ? "Listening. Pause after an instruction. Say ‘stop listening’ to turn the mic off." : "Listening. Release the shortcut to act."
        capture = Task { [weak self, speech] in
            do {
                guard let self else { return }
                try await self.adapterStartup?.value
                self.invocationSnapshot = try? await self.adapter.observe()
                guard self.sessionGeneration == generation, self.acceptingEvents else { return }
                try await speech.begin(handsFree: handsFree)
                guard self.sessionGeneration == generation else { return }
                if !self.wantsCapture { await speech.commit() }
            } catch {
                guard let self, self.sessionGeneration == generation else { return }
                self.wantsCapture = false; self.model.microphoneOn = false
                self.model.phase = .failed; self.model.message = "Could not start the microphone. Check microphone permission."
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
        case .listening: if wantsCapture { model.phase = .listening }
        case .speechBegan: runner?.stop(); model.phase = .listening; model.message = "Listening to your next instruction…"
        case .level(let level): model.audioLevel = level
        case .transcribing: model.phase = .transcribing; model.message = "Recognizing speech on this Mac…"
        case .transcript(let text):
            speechSubmission = true
            submit(text)
            speechSubmission = false
        case .stopped: model.microphoneOn = false; wantsCapture = false
        case .failed(let message): model.phase = .failed; model.message = message
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
            let payload = command.hasPrefix("type literally ") ? String(text.dropFirst(13)) : text
            dispatch("type " + payload)
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
    private func dispatch(_ text: String) {
        model.transcript = text; model.steps = []
        runner?.stop()
        guard let runner else { return }
        let clarification = model.phase == .clarification
        let needsSnapshot = !speechSubmission
        let generation = sessionGeneration
        execution = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.adapterStartup?.value
                if needsSnapshot { self.invocationSnapshot = try? await self.adapter.observe() }
                guard self.sessionGeneration == generation, self.acceptingEvents else { return }
                if clarification { await runner.clarify(text) } else { await runner.submit(text) }
            } catch {
                guard self.sessionGeneration == generation else { return }
                self.model.phase = .failed; self.model.message = "Could not connect to the authorized browser. Check its extension."
            }
        }
    }
    private func stop() {
        guard interactionLease != nil else { return }
        runner?.stop()
        model.phase = .paused; model.message = "Stopped. Check the app before resuming."
    }
    private func stopListening() {
        stop()
        wantsCapture = false; model.microphoneOn = false
        hotkey?.resetToIdle()
        let prior = capture
        capture = Task { [speech] in
            await prior?.value
            await speech.cancel()
        }
    }
    private func cancelTask() {
        runner?.stop()
        if let runner { execution = Task { await runner.cancel() } }
    }
    private func confirm() {
        guard model.phase == .confirmation, let runner else { return }
        execution = Task { await runner.confirm() }
    }
    private func resume() {
        guard ensureSession(), let runner else { return }
        execution = Task { await runner.resume() }
    }
    private func end(hide: Bool = true) {
        guard cleanup == nil else { return }
        runner?.stop()
        acceptingEvents = false; wantsCapture = false; sessionGeneration += 1
        literalMode = false; model.literalMode = false
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
            await currentRunner?.cancel()
            _ = try? await startup?.value
            await browser?.stop()
            guard let self else { return }
            if let lease { GUIMutationArbiter.shared.release(lease) }
            self.interactionLease = nil; self.runner = nil; self.cleanup = nil
            self.invocationSnapshot = nil; self.adapterStartup = nil
            self.model.phase = .idle; self.model.transcript = ""; self.model.steps = []
        }
    }
}

struct VoiceControlWritingConsentRequired: LocalizedError {
    var errorDescription: String? { "Enable selected-text sharing with your writing provider in Voice Control setup first." }
}
