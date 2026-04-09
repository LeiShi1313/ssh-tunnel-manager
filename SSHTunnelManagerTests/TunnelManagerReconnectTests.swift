import XCTest
@testable import SSHTunnelManager

final class TunnelManagerReconnectTests: XCTestCase {

    func testConnectWaitsForNetworkWhenOffline() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let networkMonitor = MockNetworkMonitor(isOnline: false)
        let manager = TunnelManager(
            store: TunnelStore(fileURL: tempDirectory.appendingPathComponent("tunnels.json")),
            keychain: KeychainService(serviceName: "com.lei.ssh-tunnel-manager.tests.\(UUID().uuidString)"),
            notifications: NotificationService(),
            networkMonitor: networkMonitor
        )

        let tunnel = TunnelConfig(
            name: "Offline Tunnel",
            host: "example.com",
            user: "tester",
            authMethod: .key,
            forwardingType: .local,
            localPort: 5432,
            remoteHost: "localhost",
            remotePort: 5432
        )

        manager.addTunnel(tunnel)
        manager.connect(tunnel.id)

        XCTAssertEqual(manager.states[tunnel.id], .waitingForNetwork(attempt: 1))
    }
}

private final class MockNetworkMonitor: NetworkMonitoring {
    var isOnline: Bool
    var onStatusChange: ((Bool) -> Void)?

    init(isOnline: Bool) {
        self.isOnline = isOnline
    }

    func start() {}
}
