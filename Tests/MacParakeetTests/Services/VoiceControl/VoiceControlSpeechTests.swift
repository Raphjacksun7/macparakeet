import XCTest
@testable import MacParakeetCore

final class VoiceControlSpeechTests: XCTestCase {
    func testSilenceNeverCommitsAnUtterance() {
        var endpoint = VoiceControlEndpointer()
        for _ in 0..<1000 {
            XCTAssertEqual(endpoint.consume(Array(repeating: 0, count: 1600)), .none)
        }
    }
    func testRequiresSpeechBeforePauseCommitsAndResets() {
        var endpoint = VoiceControlEndpointer()
        XCTAssertEqual(endpoint.consume(Array(repeating: 0.1, count: 1600)), .none)
        XCTAssertEqual(endpoint.consume(Array(repeating: 0.1, count: 1600)), .began)
        for _ in 0..<8 { XCTAssertEqual(endpoint.consume(Array(repeating: 0, count: 1600)), .none) }
        XCTAssertEqual(endpoint.consume(Array(repeating: 0, count: 1600)), .ended)
        XCTAssertEqual(endpoint.consume(Array(repeating: 0, count: 32_000)), .none)
    }
    func testBriefNoiseDoesNotCountAsSpeechAcrossLongSilence() {
        var endpoint = VoiceControlEndpointer()
        for _ in 0..<10 {
            XCTAssertEqual(endpoint.consume(Array(repeating: 0.1, count: 800)), .none)
            XCTAssertEqual(endpoint.consume(Array(repeating: 0, count: 8000)), .none)
        }
    }
    func testUtteranceHasBoundedLength() {
        var endpoint = VoiceControlEndpointer()
        XCTAssertEqual(endpoint.consume(Array(repeating: 0.1, count: 2400)), .began)
        XCTAssertEqual(endpoint.consume(Array(repeating: 0.1, count: 480_000)), .tooLong)
        XCTAssertEqual(endpoint.consume(Array(repeating: 0, count: 32_000)), .none)
    }
    @MainActor func testOwnershipExcludesCompetingEffectsUntilCleanup() {
        let arbiter = GUIMutationArbiter()
        let transform = arbiter.acquire(.transform)!
        XCTAssertNil(arbiter.acquire(.voiceControl))
        XCTAssertNil(arbiter.acquire(.dictation))
        arbiter.release(transform)
        let voice = arbiter.acquire(.voiceControl)!
        arbiter.release(transform)
        XCTAssertEqual(arbiter.current, voice, "An old cleanup cannot release a newer session")
        XCTAssertNil(arbiter.acquire(.historyPaste))
        arbiter.release(voice)
        XCTAssertNotNil(arbiter.acquire(.dictation))
    }
}

private actor VoiceControlTestAudio: AudioProcessorProtocol {
    let url: URL
    var isRecording = false
    var audioLevel: Float { 0 }
    var recordingDeviceInfo: RecordingDeviceInfo? { nil }
    init() throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("voice-speech-test-\(UUID()).wav")
        try Data([1, 2, 3]).write(to: url)
    }
    func convert(fileURL: URL) async throws -> URL { fileURL }
    func startCapture() async throws { isRecording = true }
    func stopCapture() async throws -> URL { isRecording = false; return url }
}

private actor VoiceControlTestSTT: STTTranscribing {
    var jobs: [STTJobKind] = []
    func transcribe(audioPath: String, job: STTJobKind, onProgress: (@Sendable (Int, Int) -> Void)?) async throws -> STTResult {
        jobs.append(job)
        return STTResult(text: "type um, DO NOT expand this snippet")
    }
}

extension VoiceControlSpeechTests {
    func testCommitUsesRawFinalDictationLaneAndDeletesOnlyOwnedAudio() async throws {
        let audio = try VoiceControlTestAudio()
        let stt = VoiceControlTestSTT()
        let session = VoiceControlSpeechSession(audio: audio, stt: stt)
        let events = session.events
        let collector = Task<String?, Never> {
            for await event in events {
                if case .transcript(let text) = event { return text }
                if case .failed = event { return nil }
            }
            return nil
        }
        try await session.begin(handsFree: false)
        await session.commit()
        let text = await collector.value
        XCTAssertEqual(text, "type um, DO NOT expand this snippet")
        let jobs = await stt.jobs
        XCTAssertEqual(jobs, [.dictation])
        XCTAssertFalse(FileManager.default.fileExists(atPath: audio.url.path))
    }
    func testCancelDeletesCaptureWithoutSubmittingSTT() async throws {
        let audio = try VoiceControlTestAudio()
        let stt = VoiceControlTestSTT()
        let session = VoiceControlSpeechSession(audio: audio, stt: stt)
        try await session.begin(handsFree: false)
        await session.cancel()
        let jobs = await stt.jobs
        XCTAssertTrue(jobs.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: audio.url.path))
    }
}
