// SSHTunnelManagerTests/TunnelStoreTests.swift
import XCTest
@testable import SSHTunnelManager

final class TunnelStoreTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func testSaveAndLoadTunnels() throws {
        let store = TunnelStore(fileURL: tempURL)
        let tunnel = TunnelConfig(
            name: "Dev DB",
            host: "server.example.com",
            user: "admin",
            authMethod: .key,
            forwardingType: .local,
            localPort: 5432,
            remoteHost: "localhost",
            remotePort: 5432
        )
        try store.save([tunnel])
        let loaded = try store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "Dev DB")
        XCTAssertEqual(loaded[0].id, tunnel.id)
    }

    func testLoadFromNonExistentFileReturnsEmpty() throws {
        let store = TunnelStore(fileURL: tempURL)
        let loaded = try store.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testSaveCreatesDirectoryIfNeeded() throws {
        let nestedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("tunnels.json")
        let store = TunnelStore(fileURL: nestedURL)
        let tunnel = TunnelConfig(
            name: "Test",
            host: "host",
            user: "user",
            authMethod: .key,
            forwardingType: .dynamic,
            localPort: 1080
        )
        try store.save([tunnel])
        let loaded = try store.load()
        XCTAssertEqual(loaded.count, 1)
        try? FileManager.default.removeItem(at: nestedURL.deletingLastPathComponent())
    }

    func testSaveOverwritesPreviousData() throws {
        let store = TunnelStore(fileURL: tempURL)
        let tunnel1 = TunnelConfig(name: "A", host: "h", user: "u", authMethod: .key, forwardingType: .local, localPort: 1000)
        let tunnel2 = TunnelConfig(name: "B", host: "h", user: "u", authMethod: .key, forwardingType: .local, localPort: 2000)
        try store.save([tunnel1, tunnel2])
        try store.save([tunnel1])
        let loaded = try store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "A")
    }
}
