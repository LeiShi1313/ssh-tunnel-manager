import XCTest
@testable import SSHTunnelManager

final class SSHCommandBuilderTests: XCTestCase {

    func testLocalForwardingCommand() {
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
            remotePort: 5432
        )
        let args = SSHCommandBuilder.buildArguments(for: config)
        XCTAssertTrue(args.contains("-N"))
        XCTAssertTrue(args.contains("-o"))
        XCTAssertTrue(args.contains("ExitOnForwardFailure=yes"))
        XCTAssertTrue(args.contains("-L"))
        XCTAssertTrue(args.contains("5432:localhost:5432"))
        XCTAssertTrue(args.contains("-i"))
        XCTAssertTrue(args.contains("~/.ssh/id_ed25519"))
        XCTAssertTrue(args.contains("-p"))
        XCTAssertTrue(args.contains("22"))
        XCTAssertTrue(args.contains("admin@server.example.com"))
    }

    func testRemoteForwardingCommand() {
        let config = TunnelConfig(
            name: "Remote",
            host: "server.example.com",
            port: 2222,
            user: "admin",
            authMethod: .key,
            forwardingType: .remote,
            localPort: 3000,
            remoteHost: "localhost",
            remotePort: 8080
        )
        let args = SSHCommandBuilder.buildArguments(for: config)
        XCTAssertTrue(args.contains("-R"))
        XCTAssertTrue(args.contains("8080:localhost:3000"))
        XCTAssertTrue(args.contains("2222"))
    }

    func testDynamicForwardingCommand() {
        let config = TunnelConfig(
            name: "SOCKS",
            host: "proxy.example.com",
            port: 22,
            user: "admin",
            authMethod: .key,
            forwardingType: .dynamic,
            localPort: 1080
        )
        let args = SSHCommandBuilder.buildArguments(for: config)
        XCTAssertTrue(args.contains("-D"))
        XCTAssertTrue(args.contains("1080"))
        XCTAssertFalse(args.contains("-L"))
        XCTAssertFalse(args.contains("-R"))
    }

    func testPasswordAuthNoKeyFlag() {
        let config = TunnelConfig(
            name: "Password",
            host: "server.example.com",
            port: 22,
            user: "admin",
            authMethod: .password,
            forwardingType: .local,
            localPort: 8080,
            remoteHost: "localhost",
            remotePort: 80
        )
        let args = SSHCommandBuilder.buildArguments(for: config)
        XCTAssertFalse(args.contains("-i"))
    }

    func testServerAliveOptions() {
        let config = TunnelConfig(
            name: "Test",
            host: "host",
            user: "user",
            authMethod: .key,
            forwardingType: .local,
            localPort: 8080,
            remoteHost: "localhost",
            remotePort: 80
        )
        let args = SSHCommandBuilder.buildArguments(for: config)
        XCTAssertTrue(args.contains("ServerAliveInterval=30"))
        XCTAssertTrue(args.contains("ServerAliveCountMax=3"))
    }
}
