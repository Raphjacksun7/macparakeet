import Foundation
import Observation
import MacParakeetCore

@MainActor @Observable
public final class VoiceControlViewModel {
    public enum Phase: Equatable { case idle, listening, transcribing, working, confirmation, clarification, paused, done, failed }
    public var phase: Phase = .idle
    public var microphoneOn = false
    public var literalMode = false
    public var audioLevel: Float = 0
    public var transcript = ""
    public var message = "Hold Control–Option–Space to give an instruction."
    public var steps: [String] = []
    public var needsSetup = true
    public var keyInput = ""
    public var consent = false
    public var writingConsent = false
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
    public init() {}
    public func apply(_ event: VoiceControlEvent) {
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
