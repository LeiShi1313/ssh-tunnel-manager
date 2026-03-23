import XCTest
@testable import SSHTunnelManager

final class TunnelConfigTests: XCTestCase {

    func testEncodeDecodeTunnelConfig() throws {
        let config = TunnelConfig(
            name: "Dev DB",
            host: "server.example.com",
            port: 22,
            user: "admin",
            authMethod: .key,
            keyPath: "~/.ssh/id_ed25519",
            forwardingType: .local,
            localPort: 5432,
            remoteHost: "localhost",
            remotePort: 5432,
            autoConnect: true,
            enabled: true
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TunnelConfig.self, from: data)

        XCTAssertEqual(config.id, decoded.id)
        XCTAssertEqual(config.name, decoded.name)
        XCTAssertEqual(config.host, decoded.host)
        XCTAssertEqual(config.port, decoded.port)
        XCTAssertEqual(config.user, decoded.user)
        XCTAssertEqual(config.authMethod, decoded.authMethod)
        XCTAssertEqual(config.keyPath, decoded.keyPath)
        XCTAssertEqual(config.forwardingType, decoded.forwardingType)
        XCTAssertEqual(config.localPort, decoded.localPort)
        XCTAssertEqual(config.remoteHost, decoded.remoteHost)
        XCTAssertEqual(config.remotePort, decoded.remotePort)
        XCTAssertEqual(config.autoConnect, decoded.autoConnect)
        XCTAssertEqual(config.enabled, decoded.enabled)
    }

    func testDynamicTunnelOmitsRemoteHostAndPort() throws {
        let config = TunnelConfig(
            name: "SOCKS Proxy",
            host: "proxy.example.com",
            port: 22,
            user: "admin",
            authMethod: .key,
            keyPath: nil,
            forwardingType: .dynamic,
            localPort: 1080,
            remoteHost: nil,
            remotePort: nil,
            autoConnect: false,
            enabled: true
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TunnelConfig.self, from: data)

        XCTAssertNil(decoded.remoteHost)
        XCTAssertNil(decoded.remotePort)
        XCTAssertEqual(decoded.forwardingType, .dynamic)
    }

    func testDefaultPortIs22() {
        let config = TunnelConfig(
            name: "Test",
            host: "host",
            user: "user",
            authMethod: .key,
            forwardingType: .local,
            localPort: 8080
        )
        XCTAssertEqual(config.port, 22)
    }

    func testForwardingSummaryLocal() {
        let config = TunnelConfig(
            name: "Test",
            host: "host",
            user: "user",
            authMethod: .key,
            forwardingType: .local,
            localPort: 5432,
            remoteHost: "localhost",
            remotePort: 5432
        )
        XCTAssertEqual(config.forwardingSummary, "L:5432 → localhost:5432")
    }

    func testForwardingSummaryDynamic() {
        let config = TunnelConfig(
            name: "Test",
            host: "host",
            user: "user",
            authMethod: .key,
            forwardingType: .dynamic,
            localPort: 1080
        )
        XCTAssertEqual(config.forwardingSummary, "D:1080")
    }
}
