import Foundation

enum LogLevel: String, CaseIterable {
    case info
    case debug
    case warning
    case error
}

struct TunnelLog: Identifiable {
    let id: UUID
    let tunnelId: UUID
    let tunnelName: String
    let timestamp: Date
    let level: LogLevel
    let message: String

    init(tunnelId: UUID, tunnelName: String, level: LogLevel, message: String) {
        self.id = UUID()
        self.tunnelId = tunnelId
        self.tunnelName = tunnelName
        self.timestamp = Date()
        self.level = level
        self.message = message
    }
}
