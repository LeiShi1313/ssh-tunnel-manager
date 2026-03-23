// SSHTunnelManagerTests/PortCheckerTests.swift
import XCTest
@testable import SSHTunnelManager

final class PortCheckerTests: XCTestCase {

    func testAvailablePortReturnsTrue() {
        let available = PortChecker.isPortAvailable(59123)
        XCTAssertTrue(available)
    }

    func testOccupiedPortReturnsFalse() throws {
        let socket = socket(AF_INET, SOCK_STREAM, 0)
        XCTAssertTrue(socket >= 0)
        defer { close(socket) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(59124).bigEndian
        addr.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        XCTAssertEqual(bindResult, 0, "Failed to bind test port")
        listen(socket, 1)

        let available = PortChecker.isPortAvailable(59124)
        XCTAssertFalse(available)
    }
}
