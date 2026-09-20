import Foundation
import Observation
import MacParakeetCore

public struct VoiceControlConversationState: Sendable {
    public enum Response: Sendable { case confirmation, clarification }
    public private(set) var expectedResponse: Response?
    public var shouldPauseForSpeech: Bool { expectedResponse == nil }
    public init() {}
    public mutating func receive(_ event: VoiceControlEvent) {
        switch event {
        case .confirmation: expectedResponse = .confirmation
        case .clarification: expectedResponse = .clarification
        case .paused, .cancelled, .completed, .failed: expectedResponse = nil
        default: break
        }
    }
    public mutating func cancel() { expectedResponse = nil }
    public mutating func takeConfirmation() -> Bool {
        guard expectedResponse == .confirmation else { return false }
        expectedResponse = nil
        return true
    }
    public mutating func takeClarification() -> Bool {
        let result = expectedResponse == .clarification
        expectedResponse = nil
        return result
    }
}

@MainActor @Observable
public final class VoiceControlViewModel {
    public enum Phase: Equatable {
        case idle, listening, transcribing, working, confirmation, clarification, paused, done, failed
    }
    public var phase: Phase = .idle
    public var conversation = VoiceControlConversationState()
    public var microphoneOn = false
    public var literalMode = false
    public var audioLevel: Float = 0
    public var transcript = ""
    public var partialTranscript = ""
    public var message = "Hold Control–Option–Space to give an instruction."
    public var steps: [String] = []
    public var needsSetup = true
    public var keyInput = ""
    public var consent = false
    public var writingConsent = false
    public var browserEnabled = false
    public var browserChoice: VoiceControlBrowserChoice = .chrome
    public var browserExtensionID = ""
    public var replaceBrowserPairing = false
    public var browserSetupStatus = "Native app control works without the browser extension."
    public var isRegisteringBrowser = false
    public var isConnectingBrowser = false
    public var onConnectBrowser: (() -> Void)?
    public var onOpenExtensionFolder: (() -> Void)?
    public var onRegisterBrowser: (() -> Void)?
    public var onBrowserDisabled: (() -> Void)?
    public var holdTrigger = HotkeyTrigger.chord(modifiers: ["control", "option"], keyCode: 49)
    public var onShortcutRecording: ((Bool) -> Void)?
    public var validateShortcut: ((HotkeyTrigger) -> HotkeyTrigger.ValidationResult)?
    public var input = ""
    public var onListen: (() -> Void)?
    public var onCommit: (() -> Void)?
    public var onStop: (() -> Void)?
    public var onStopListening: (() -> Void)?
    public var onCancel: (() -> Void)?
    public var onEnd: (() -> Void)?
    public var onConfirm: (() -> Void)?
    public var onResume: (() -> Void)?
    public var onSubmit: ((String) -> Void)?
    public var onSaveSetup: (() -> Void)?
    public var onSettings: (() -> Void)?
    public var onDisable: (() -> Void)?
    public var onRevokeConsent: (() -> Void)?
    public var onRevokeWritingConsent: (() -> Void)?
    public init() {}
    public func apply(_ event: VoiceControlEvent) {
        conversation.receive(event)
        switch event {
        case .observing: phase = .working; message = "Looking at the current app…"
        case .deciding: phase = .working; message = "Choosing the next step…"
        case .acting(let action):
            phase = .working; message = "Applying the next step…"
            steps.append(action.operation.rawValue)
            if steps.count > 12 { steps.removeFirst() }
        case .confirmation(_, let message): phase = .confirmation; self.message = message
        case .clarification(let message): phase = .clarification; self.message = message
        case .paused(let message): phase = .paused; self.message = message
        case .completed(let message): phase = .done; self.message = message
        case .failed(let message): phase = .failed; self.message = message
        case .cancelled: phase = .idle; message = "Task cancelled."
        }
    }
}
