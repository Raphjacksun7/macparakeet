import AppKit
import SwiftUI
import MacParakeetCore
import MacParakeetViewModels

struct VoiceControlPanelView: View {
    @Bindable var model: VoiceControlViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: model.microphoneOn ? "mic.fill" : "mic.slash")
                    .accessibilityLabel(model.microphoneOn ? "Microphone on" : "Microphone off")
                Text(model.literalMode ? "Voice Control · Literal" : "Voice Control").font(.headline)
                Spacer()
                Text(model.microphoneOn ? "Listening" : "Mic off").font(.caption).foregroundStyle(.secondary)
                Button("Close", systemImage: "xmark", action: { model.onEnd?() })
                    .labelStyle(.iconOnly).parakeetAction(.subtle)
            }
            if model.needsSetup {
                Text("Speak naturally. Act on your Mac.").font(.title2.bold())
                Text("Speech recognition stays on this Mac. Jev receives your command and a limited description of the current app’s controls. Password fields are excluded. Cloud control is optional and separate from ordinary dictation.")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                SecureField("TypeSafe / Jev API key", text: $model.keyInput)
                    .textFieldStyle(.roundedBorder)
                Toggle("Allow commands and app context to be sent to Jev", isOn: $model.consent)
                    .font(.callout)
                Toggle("Allow selected text to be sent to my configured writing provider", isOn: $model.writingConsent)
                    .font(.callout)
                HotkeyRecorderView(trigger: $model.holdTrigger,
                    defaultTrigger: VoiceControlCoordinator.holdTrigger,
                    additionalValidation: model.validateShortcut,
                    onRecordingStateChanged: model.onShortcutRecording)
                Button("Save and enable", action: { model.onSaveSetup?() })
                    .parakeetAction(.primaryProminent).disabled(!model.consent)
                Button("Disable and forget API key", role: .destructive, action: { model.onDisable?() })
                    .parakeetAction(.subtle)
                Text(model.message).font(.caption).foregroundStyle(.secondary)
                Text("Your API key is stored in macOS Keychain. No microphone opens until you start listening.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                if !model.transcript.isEmpty {
                    Text(model.transcript).font(.body.weight(.medium)).lineLimit(4)
                }
                Text(model.message).font(.callout).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("voice-control-status")
                if model.microphoneOn {
                    ProgressView(value: Double(model.audioLevel)).accessibilityLabel("Microphone level")
                }
                if model.phase == .confirmation {
                    HStack {
                        Button("Confirm this action", action: { model.onConfirm?() }).parakeetAction(.primaryProminent)
                        Button("Cancel task", action: { model.onCancel?() }).parakeetAction(.secondary)
                    }
                }
                HStack {
                    if model.microphoneOn {
                        Button("Finish speaking", action: { model.onCommit?() }).parakeetAction(.secondary)
                        Button("Mic off", action: { model.onStopListening?() }).parakeetAction(.secondary)
                    } else {
                        Button("Start listening", action: { model.onListen?() }).parakeetAction(.primary)
                    }
                    Button("Stop", action: { model.onStop?() }).parakeetAction(.secondary)
                        .keyboardShortcut(.cancelAction)
                    if model.phase == .paused {
                        Button("Resume", action: { model.onResume?() }).parakeetAction(.secondary)
                    }
                }
                HStack {
                    TextField("Instruction or correction", text: $model.input)
                        .textFieldStyle(.roundedBorder).onSubmit(submit)
                    Button("Go", action: submit).parakeetAction(.secondary)
                        .disabled(model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                HStack {
                    Text("Hold \(model.holdTrigger.shortSymbol) · Escape stops").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Setup", action: { model.onSettings?() }).parakeetAction(.subtle)
                }
            }
        }
        .padding(20).frame(width: 430)
        .background(.regularMaterial)
    }
    private func submit() {
        let value = model.input
        model.input = ""
        model.onSubmit?(value)
    }
}

@MainActor
final class VoiceControlPanelController {
    private let panel: NSPanel
    init(model: VoiceControlViewModel) {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 470, height: 330),
                        styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                        backing: .buffered, defer: false)
        panel.title = "Voice Control"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: VoiceControlPanelView(model: model))
    }
    func show() {
        if !panel.isVisible, let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameTopLeftPoint(NSPoint(x: frame.maxX - 490, y: frame.maxY - 32))
        }
        panel.orderFrontRegardless()
    }
    func hide() { panel.orderOut(nil) }
}
