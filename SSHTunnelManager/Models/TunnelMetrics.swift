import Foundation

struct TunnelMetrics {
    var connectedAt: Date?
    var disconnectedAt: Date?
    var reconnectCount: Int = 0
    var lastError: String?

    var uptimeSeconds: TimeInterval {
        guard let start = connectedAt else { return 0 }
        let end = disconnectedAt ?? Date()
        return end.timeIntervalSince(start)
    }

    var isConnected: Bool {
        connectedAt != nil && disconnectedAt == nil
    }
}
