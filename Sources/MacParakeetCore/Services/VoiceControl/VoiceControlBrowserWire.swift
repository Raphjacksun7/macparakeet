import Darwin
import Foundation

/// Bounded native-messaging frames. No transcript or page content is logged.
public enum VoiceControlBrowserWire {
    public static let maximumFrameBytes = 262_144
    public static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MacParakeet/VoiceControlBrowser", isDirectory: true)
    }
    public static var socketPath: String { directory.appendingPathComponent("bridge.sock").path }

    public enum WireError: Error { case disconnected, invalidFrame, invalidConfiguration, socketFailure }

    public struct Configuration: Codable, Sendable {
        public let extensionOrigin: String
        public let token: String
    }

    public static func configuration() throws -> Configuration {
        let url = directory.appendingPathComponent("pairing.json")
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600,
              (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid() else {
            throw WireError.invalidConfiguration
        }
        let config = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: url))
        guard config.token.count >= 64,
              config.extensionOrigin.range(of: #"^chrome-extension://[a-p]{32}/$"#, options: .regularExpression) != nil else {
            throw WireError.invalidConfiguration
        }
        return config
    }

    public static func readFrame(from descriptor: Int32) throws -> Data {
        let header = try readExactly(4, from: descriptor)
        let length = header.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        guard length > 0, length <= maximumFrameBytes else { throw WireError.invalidFrame }
        return try readExactly(Int(length), from: descriptor)
    }

    public static func writeFrame(_ data: Data, to descriptor: Int32) throws {
        guard !data.isEmpty, data.count <= maximumFrameBytes else { throw WireError.invalidFrame }
        var length = UInt32(data.count)
        let header = withUnsafeBytes(of: &length) { Data($0) }
        try writeAll(header + data, to: descriptor)
    }

    private static func readExactly(_ count: Int, from descriptor: Int32) throws -> Data {
        var data = Data(count: count)
        try data.withUnsafeMutableBytes { buffer in
            var offset = 0
            while offset < count {
                let n = Darwin.read(descriptor, buffer.baseAddress!.advanced(by: offset), count - offset)
                if n < 0 && errno == EINTR { continue }
                guard n > 0 else { throw WireError.disconnected }
                offset += n
            }
        }
        return data
    }

    private static func writeAll(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < data.count {
                let n = Darwin.write(descriptor, buffer.baseAddress!.advanced(by: offset), data.count - offset)
                if n < 0 && errno == EINTR { continue }
                guard n > 0 else { throw WireError.disconnected }
                offset += n
            }
        }
    }

    public static func makeSocket() throws -> Int32 {
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw WireError.socketFailure }
        var one: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
        return descriptor
    }

    public static func withAddress<T>(_ path: String, _ body: (UnsafePointer<sockaddr>, socklen_t) throws -> T) throws -> T {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8) + [0]
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { throw WireError.socketFailure }
        withUnsafeMutableBytes(of: &address.sun_path) { destination in
            destination.copyBytes(from: bytes)
        }
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        return try withUnsafePointer(to: &address) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                try body($0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
    }
}
