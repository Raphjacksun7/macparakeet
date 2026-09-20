import Darwin
import Foundation
import XCTest
@testable import MacParakeetCore

final class VoiceControlBrowserWireTests: XCTestCase {
    func testFramesRoundTripWithoutMergingMessages() throws {
        var descriptors: [Int32] = [0, 0]
        XCTAssertEqual(pipe(&descriptors), 0)
        defer { Darwin.close(descriptors[0]); Darwin.close(descriptors[1]) }
        let first = Data("{\"type\":\"observe\"}".utf8)
        let second = Data("{\"type\":\"revoke\"}".utf8)
        try VoiceControlBrowserWire.writeFrame(first, to: descriptors[1])
        try VoiceControlBrowserWire.writeFrame(second, to: descriptors[1])
        XCTAssertEqual(try VoiceControlBrowserWire.readFrame(from: descriptors[0]), first)
        XCTAssertEqual(try VoiceControlBrowserWire.readFrame(from: descriptors[0]), second)
    }
    func testOversizedHeaderRejectedBeforeReadingBody() throws {
        var descriptors: [Int32] = [0, 0]
        XCTAssertEqual(pipe(&descriptors), 0)
        defer { Darwin.close(descriptors[0]); Darwin.close(descriptors[1]) }
        var length = UInt32(VoiceControlBrowserWire.maximumFrameBytes + 1)
        withUnsafeBytes(of: &length) { _ = Darwin.write(descriptors[1], $0.baseAddress, $0.count) }
        XCTAssertThrowsError(try VoiceControlBrowserWire.readFrame(from: descriptors[0]))
    }
    func testEmptyAndOversizedOutputAreRejected() {
        XCTAssertThrowsError(try VoiceControlBrowserWire.writeFrame(Data(), to: -1))
        XCTAssertThrowsError(try VoiceControlBrowserWire.writeFrame(Data(count: VoiceControlBrowserWire.maximumFrameBytes + 1), to: -1))
    }
    func testPartialFrameEOFDoesNotProduceReceipt() throws {
        var descriptors: [Int32] = [0, 0]
        XCTAssertEqual(pipe(&descriptors), 0)
        defer { Darwin.close(descriptors[0]) }
        var length: UInt32 = 10
        withUnsafeBytes(of: &length) { _ = Darwin.write(descriptors[1], $0.baseAddress, $0.count) }
        Darwin.close(descriptors[1])
        XCTAssertThrowsError(try VoiceControlBrowserWire.readFrame(from: descriptors[0]))
    }
}
