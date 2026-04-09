import Foundation

enum TunnelState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case waitingForNetwork(attempt: Int)
    case failed(reason: String)
}
