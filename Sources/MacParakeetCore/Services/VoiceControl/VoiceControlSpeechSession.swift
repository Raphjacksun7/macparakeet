import AVFoundation
import Foundation

public enum VoiceControlSpeechEvent: Sendable {
    case listening, speechBegan, transcribing
    case level(Float)
    case transcript(String)
    case stopped
    case failed(String)
}

/// Deterministic, conservative endpointing. No action is based on partial text.
/// This energy-based detector needs real microphone qualification; noise is not
/// speech recognition, and hold-to-talk remains available in noisy environments.
public struct VoiceControlEndpointer: Sendable {
    public enum Signal: Sendable, Equatable { case none, began, ended, tooLong }
    private var speechSamples = 0
    private var silenceSamples = 0
    private var totalSamples = 0
    private var began = false
    public init() {}
    public mutating func reset() { self = Self() }
    public mutating func consume(_ samples: [Float]) -> Signal {
        guard !samples.isEmpty else { return .none }
        let rms = sqrt(samples.reduce(Float(0)) { $0 + $1 * $1 } / Float(samples.count))
        if rms >= 0.012 {
            speechSamples += samples.count
            silenceSamples = 0
        } else {
            silenceSamples += samples.count
            if !began, silenceSamples > 4800 { speechSamples = 0 }
        }
        if began { totalSamples += samples.count }
        if !began, speechSamples >= 2400 {
            began = true
            totalSamples = speechSamples
            return .began
        }
        if began, totalSamples >= 480_000 { reset(); return .tooLong }
        if began, silenceSamples >= 14_400 { reset(); return .ended }
        return .none
    }
}

/// Raw local command speech over the process-wide microphone and STT scheduler.
/// Hands-free keeps capture alive while finalized segments are transcribed, so
/// incoming speech can revoke execution before another command has been decoded.
public actor VoiceControlSpeechSession {
    public nonisolated let events: AsyncStream<VoiceControlSpeechEvent>
    private let continuation: AsyncStream<VoiceControlSpeechEvent>.Continuation
    private let audio: any AudioProcessorProtocol
    private let stt: any STTTranscribing
    private var generation = 0
    private var active = false
    private var handsFree = false
    private var sampleTask: Task<Void, Never>?
    private var finalTask: Task<Void, Never>?
    private var limitTask: Task<Void, Never>?
    private var sampleContinuation: AsyncStream<[Float]>.Continuation?
    private var endpointer = VoiceControlEndpointer()
    private var utterance: [Float] = []
    private var hasSpeech = false

    public init(audio: any AudioProcessorProtocol, stt: any STTTranscribing) {
        self.audio = audio
        self.stt = stt
        let pair = AsyncStream<VoiceControlSpeechEvent>.makeStream(bufferingPolicy: .bufferingNewest(32))
        events = pair.stream
        continuation = pair.continuation
    }

    public func begin(handsFree: Bool) async throws {
        guard !active else { return }
        generation += 1
        let token = generation
        active = true
        self.handsFree = handsFree
        endpointer.reset(); utterance = []; hasSpeech = false
        let pair = AsyncStream<[Float]>.makeStream(bufferingPolicy: .bufferingNewest(128))
        sampleContinuation = pair.continuation
        sampleTask = Task { [weak self] in
            for await samples in pair.stream {
                guard !Task.isCancelled else { break }
                await self?.consume(samples, token: token)
            }
        }
        do {
            try await audio.startCapture(sampleSink: DictationAudioSampleSink(
                onSamples: { [weak self] samples in
                    if case .dropped = pair.continuation.yield(samples) {
                        Task { await self?.captureOverflow(token: token) }
                    }
                }, onFinish: { pair.continuation.finish() },
                onCancel: { pair.continuation.finish() }
            ))
            guard active, generation == token else {
                if let url = try? await audio.stopCapture() { try? FileManager.default.removeItem(at: url) }
                throw CancellationError()
            }
            continuation.yield(.listening)
            limitTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(handsFree ? 600 : 30))
                guard !Task.isCancelled else { return }
                await self?.expire(token: token)
            }
        } catch {
            if generation == token {
                active = false
                sampleContinuation?.finish(); sampleTask?.cancel()
            }
            throw error
        }
    }

    public func commit() async {
        guard active else { return }
        let token = generation
        active = false
        limitTask?.cancel()
        do {
            let url = try await audio.stopCapture()
            sampleContinuation?.finish()
            await sampleTask?.value
            continuation.yield(.transcribing)
            await transcribe(url: url, token: token)
        } catch {
            if generation == token { continuation.yield(.failed("Could not finish microphone capture.")) }
        }
        if generation == token { continuation.yield(.stopped) }
    }

    public func cancel() async {
        generation += 1
        active = false
        limitTask?.cancel(); finalTask?.cancel()
        sampleContinuation?.finish(); sampleTask?.cancel()
        if let url = try? await audio.stopCapture() { try? FileManager.default.removeItem(at: url) }
        utterance = []; hasSpeech = false
        continuation.yield(.stopped)
    }

    private func consume(_ samples: [Float], token: Int) {
        guard active, token == generation else { return }
        let rms = sqrt(samples.reduce(Float(0)) { $0 + $1 * $1 } / Float(max(1, samples.count)))
        continuation.yield(.level(min(1, rms * 12)))
        guard handsFree else { return }
        utterance.append(contentsOf: samples)
        switch endpointer.consume(samples) {
        case .began:
            hasSpeech = true
            finalTask?.cancel()
            continuation.yield(.speechBegan)
        case .ended:
            let segment = utterance
            utterance = []; hasSpeech = false
            finalTask?.cancel()
            finalTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let url = try Self.writeSegment(segment)
                    await self.transcribe(url: url, token: token)
                } catch { await self.segmentFailed(token: token) }
            }
        case .tooLong:
            utterance = []; hasSpeech = false
            continuation.yield(.failed("That utterance was too long. Try a shorter instruction."))
        case .none:
            // Retain at most 350 ms before actual speech, and bound active speech.
            if !hasSpeech, utterance.count > 5600 { utterance.removeFirst(utterance.count - 5600) }
        }
    }

    private func transcribe(url: URL, token: Int) async {
        defer { try? FileManager.default.removeItem(at: url) }
        guard token == generation, !Task.isCancelled else { return }
        continuation.yield(.transcribing)
        do {
            let result = try await stt.transcribe(audioPath: url.path, job: .dictation, onProgress: nil)
            guard token == generation, !Task.isCancelled else { return }
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { continuation.yield(.transcript(text)) }
        } catch is CancellationError { return }
        catch {
            guard token == generation, !Task.isCancelled else { return }
            continuation.yield(.failed("Speech recognition failed. Please try again."))
        }
    }

    private func segmentFailed(token: Int) {
        if token == generation { continuation.yield(.failed("Could not prepare command audio.")) }
    }
    private func captureOverflow(token: Int) async {
        guard token == generation else { return }
        await cancel()
        continuation.yield(.failed("Audio could not keep up. Please start listening again."))
    }
    private func expire(token: Int) async {
        guard active, token == generation else { return }
        if handsFree { await cancel() } else { await commit() }
    }
    private static func writeSegment(_ samples: [Float]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice-command-\(UUID()).wav")
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { throw AudioProcessorError.insufficientSamples }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
            return url
        } catch { try? FileManager.default.removeItem(at: url); throw error }
    }
}
