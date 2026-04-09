import Foundation
import Network

protocol NetworkMonitoring: AnyObject {
    var isOnline: Bool { get }
    var onStatusChange: ((Bool) -> Void)? { get set }
    func start()
}

final class NetworkMonitor: NetworkMonitoring {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.lei.ssh-tunnel-manager.network-monitor")

    private(set) var isOnline = true
    var onStatusChange: ((Bool) -> Void)?
    private var hasStarted = false

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let isOnline = path.status == .satisfied
            guard self.isOnline != isOnline else { return }
            self.isOnline = isOnline
            DispatchQueue.main.async {
                self.onStatusChange?(isOnline)
            }
        }

        monitor.start(queue: queue)
        isOnline = monitor.currentPath.status == .satisfied
    }
}
