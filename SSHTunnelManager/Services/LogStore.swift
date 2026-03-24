import Foundation

@Observable
class LogStore {
    private(set) var logs: [TunnelLog] = []
    private let maxEntries = 1000

    func append(tunnelId: UUID, tunnelName: String, level: LogLevel, message: String) {
        let entry = TunnelLog(tunnelId: tunnelId, tunnelName: tunnelName, level: level, message: message)
        logs.append(entry)
        if logs.count > maxEntries {
            logs.removeFirst(logs.count - maxEntries)
        }
    }

    func logs(for tunnelId: UUID) -> [TunnelLog] {
        logs.filter { $0.tunnelId == tunnelId }
    }

    func logs(level: LogLevel) -> [TunnelLog] {
        logs.filter { $0.level == level }
    }

    func clear() {
        logs.removeAll()
    }
}
