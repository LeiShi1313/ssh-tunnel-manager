import Foundation

enum AuthMethod: String, Codable, CaseIterable {
    case key
    case password
}

enum ForwardingType: String, Codable, CaseIterable {
    case local
    case remote
    case dynamic
}

struct TunnelConfig: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var user: String
    var authMethod: AuthMethod
    var keyPath: String?
    var forwardingType: ForwardingType
    var localPort: Int
    var remoteHost: String?
    var remotePort: Int?
    var autoConnect: Bool
    var enabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        user: String,
        authMethod: AuthMethod,
        keyPath: String? = nil,
        forwardingType: ForwardingType,
        localPort: Int,
        remoteHost: String? = nil,
        remotePort: Int? = nil,
        autoConnect: Bool = false,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.user = user
        self.authMethod = authMethod
        self.keyPath = keyPath
        self.forwardingType = forwardingType
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.autoConnect = autoConnect
        self.enabled = enabled
    }

    var forwardingSummary: String {
        switch forwardingType {
        case .local:
            return "L:\(localPort) → \(remoteHost ?? "localhost"):\(remotePort ?? 0)"
        case .remote:
            return "R:\(remotePort ?? 0) → \(remoteHost ?? "localhost"):\(localPort)"
        case .dynamic:
            return "D:\(localPort)"
        }
    }
}
