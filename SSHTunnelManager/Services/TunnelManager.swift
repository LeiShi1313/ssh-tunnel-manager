// SSHTunnelManager/Services/TunnelManager.swift
import Foundation
import SwiftUI

@Observable
class TunnelManager {

    var tunnels: [TunnelConfig] = []
    var states: [UUID: TunnelState] = [:]
    var metrics: [UUID: TunnelMetrics] = [:]
    let logStore = LogStore()
    var pendingEditTunnelId: UUID?

    private var processes: [UUID: TunnelProcess] = [:]
    private var retryItems: [UUID: DispatchWorkItem] = [:]
    private var retryCounts: [UUID: Int] = [:]
    private var waitingForNetworkIds: Set<UUID> = []

    private let store: TunnelStore
    private let keychain: KeychainService
    private let notifications: NotificationService
    private let networkMonitor: NetworkMonitoring

    private let activeTunnelIdsKey = "activeTunnelIds"

    private var statusTimer: Timer?

    init(
        store: TunnelStore = TunnelStore(),
        keychain: KeychainService = KeychainService(),
        notifications: NotificationService = .shared,
        networkMonitor: NetworkMonitoring = NetworkMonitor()
    ) {
        self.store = store
        self.keychain = keychain
        self.notifications = notifications
        self.networkMonitor = networkMonitor
        self.networkMonitor.onStatusChange = { [weak self] isOnline in
            self?.handleNetworkStatusChange(isOnline: isOnline)
        }
    }

    // MARK: - Lifecycle

    func loadAndAutoConnect() {
        networkMonitor.start()
        do {
            tunnels = try store.load()
        } catch {
            tunnels = []
        }
        for tunnel in tunnels {
            states[tunnel.id] = .disconnected
        }

        // Kill orphaned SSH processes from previous app instance
        killOrphanedSSHProcesses()

        let activeIds = loadActiveTunnelIds()
        for tunnel in tunnels where tunnel.enabled {
            if tunnel.autoConnect || activeIds.contains(tunnel.id) {
                connect(tunnel.id)
            }
        }

        // Periodically sync UI state with actual process status
        startStatusTimer()
    }

    private func killOrphanedSSHProcesses() {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        proc.arguments = ["-f", "ssh -N -o ExitOnForwardFailure=yes"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return }

        for line in output.split(separator: "\n") {
            if let pid = Int32(line.trimmingCharacters(in: .whitespaces)) {
                kill(pid, SIGTERM)
            }
        }
        // Brief wait for ports to be released
        usleep(500_000)
    }

    private func startStatusTimer() {
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.syncStates()
        }
    }

    private func syncStates() {
        for (id, proc) in processes {
            if proc.isRunning && states[id] != .connected {
                let shouldNotify = {
                    if case .reconnecting = states[id] { return true }
                    if case .waitingForNetwork = states[id] { return true }
                    return false
                }()

                states[id] = .connected
                retryCounts[id] = 0
                waitingForNetworkIds.remove(id)
                if let name = tunnels.first(where: { $0.id == id })?.name {
                    logStore.append(tunnelId: id, tunnelName: name, level: .info, message: "Connection established")
                    if shouldNotify {
                        notifications.sendReconnected(tunnelName: name)
                    }
                }
            }
        }
    }

    func shutdownAll() {
        statusTimer?.invalidate()
        statusTimer = nil
        saveActiveTunnelIds()
        for (id, _) in processes {
            cancelRetry(for: id)
            processes[id]?.stop()
        }
        processes.removeAll()
    }

    // MARK: - CRUD

    func addTunnel(_ config: TunnelConfig, password: String? = nil) {
        tunnels.append(config)
        states[config.id] = .disconnected
        if let password = password, config.authMethod == .password {
            try? keychain.savePassword(password, for: config.id)
        }
        saveToDisk()
    }

    func updateTunnel(_ config: TunnelConfig, password: String? = nil) {
        if let index = tunnels.firstIndex(where: { $0.id == config.id }) {
            let wasConnected = processes[config.id]?.isRunning ?? false
            if wasConnected { disconnect(config.id) }
            tunnels[index] = config
            if let password = password, config.authMethod == .password {
                try? keychain.savePassword(password, for: config.id)
            }
            saveToDisk()
            if wasConnected { connect(config.id) }
        }
    }

    func deleteTunnel(_ id: UUID) {
        disconnect(id)
        try? keychain.deletePassword(for: id)
        tunnels.removeAll { $0.id == id }
        states.removeValue(forKey: id)
        saveToDisk()
    }

    func duplicateTunnel(_ id: UUID) {
        guard let original = tunnels.first(where: { $0.id == id }) else { return }
        var copy = original
        copy.id = UUID()
        copy.name = "\(original.name) (Copy)"
        copy.autoConnect = false
        addTunnel(copy)
    }

    // MARK: - Connect / Disconnect

    func connect(_ id: UUID) {
        connect(id, isRetry: false)
    }

    private func connect(_ id: UUID, isRetry: Bool) {
        guard let config = tunnels.first(where: { $0.id == id }), config.enabled else { return }
        cancelRetry(for: id)
        waitingForNetworkIds.remove(id)
        if !isRetry {
            retryCounts[id] = 0
        }

        guard networkMonitor.isOnline else {
            if isRetry {
                enterWaitingForNetworkState(tunnelId: id, tunnelName: config.name, attempt: (retryCounts[id] ?? 0) + 1)
            } else {
                states[id] = .waitingForNetwork(attempt: 1)
                logStore.append(tunnelId: id, tunnelName: config.name, level: .warning, message: "No network connection. Waiting to connect until the network returns.")
                waitingForNetworkIds.insert(id)
                notifications.sendWaitingForNetwork(tunnelName: config.name)
            }
            return
        }

        states[id] = .connecting

        logStore.append(tunnelId: id, tunnelName: config.name, level: .info, message: "Connecting to \(config.host):\(config.port)...")
        metrics[id] = TunnelMetrics(connectedAt: Date())

        let proc = TunnelProcess(config: config)
        proc.onTermination = { [weak self] exitCode in
            self?.handleTermination(tunnelId: id, exitCode: exitCode)
        }
        proc.onOutput = { [weak self] line in
            self?.handleProcessOutput(tunnelId: id, tunnelName: config.name, line: line)
        }

        do {
            try proc.start()
            processes[id] = proc
        } catch {
            states[id] = .failed(reason: error.localizedDescription)
            metrics[id]?.disconnectedAt = Date()
            metrics[id]?.lastError = error.localizedDescription
            logStore.append(tunnelId: id, tunnelName: config.name, level: .error, message: error.localizedDescription)
            notifications.sendDisconnected(tunnelName: config.name, reconnecting: false)
        }
    }

    func disconnect(_ id: UUID) {
        cancelRetry(for: id)
        waitingForNetworkIds.remove(id)
        processes[id]?.stop()
        processes.removeValue(forKey: id)
        states[id] = .disconnected
        metrics[id]?.disconnectedAt = Date()
        if let name = tunnels.first(where: { $0.id == id })?.name {
            logStore.append(tunnelId: id, tunnelName: name, level: .info, message: "Disconnected")
        }
    }

    func toggleConnection(_ id: UUID) {
        if processes[id]?.isRunning == true {
            disconnect(id)
        } else {
            connect(id)
        }
    }

    // MARK: - Reconnect

    private func handleProcessOutput(tunnelId: UUID, tunnelName: String, line: String) {
        let lower = line.lowercased()
        let level: LogLevel
        if lower.contains("error") || lower.contains("fatal") || lower.contains("refused") {
            level = .error
        } else if lower.contains("warning") || lower.contains("warn") {
            level = .warning
        } else if lower.contains("debug") {
            level = .debug
        } else {
            level = .info
        }
        logStore.append(tunnelId: tunnelId, tunnelName: tunnelName, level: level, message: line)
    }

    private func handleTermination(tunnelId: UUID, exitCode: Int32) {
        processes.removeValue(forKey: tunnelId)
        guard states[tunnelId] != .disconnected else { return }
        guard let config = tunnels.first(where: { $0.id == tunnelId }) else { return }

        metrics[tunnelId]?.disconnectedAt = Date()
        logStore.append(tunnelId: tunnelId, tunnelName: config.name, level: exitCode == 0 ? .info : .error, message: "Process exited with code \(exitCode)")

        let reconnectEnabled = UserDefaults.standard.bool(forKey: "reconnectEnabled")
        guard reconnectEnabled else {
            states[tunnelId] = .failed(reason: "Exit code: \(exitCode)")
            notifications.sendDisconnected(tunnelName: config.name, reconnecting: false)
            return
        }

        let attempt = retryCounts[tunnelId] ?? 0
        scheduleReconnect(for: config, currentAttempt: attempt)
    }

    private func cancelRetry(for id: UUID) {
        retryItems[id]?.cancel()
        retryItems.removeValue(forKey: id)
    }

    // MARK: - Dashboard

    func openDashboard(editingTunnelId: UUID? = nil) {
        pendingEditTunnelId = editingTunnelId
        WindowManager.shared.openWindow(
            id: "dashboard",
            title: "SSH Tunnel Manager",
            content: MainWindowView(manager: self)
        )
    }

    // MARK: - Persistence

    private func saveToDisk() {
        try? store.save(tunnels)
    }

    private func saveActiveTunnelIds() {
        let activeIds = processes.filter { $0.value.isRunning }.map { $0.key.uuidString }
        UserDefaults.standard.set(activeIds, forKey: activeTunnelIdsKey)
    }

    private func loadActiveTunnelIds() -> Set<UUID> {
        guard let strings = UserDefaults.standard.stringArray(forKey: activeTunnelIdsKey) else {
            return []
        }
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }

    // MARK: - Aggregate State (for status bar icon)

    var aggregateState: AggregateState {
        if tunnels.isEmpty || states.values.allSatisfy({ $0 == .disconnected }) {
            return .idle
        }
        if states.values.contains(where: {
            if case .failed = $0 { return true }; return false
        }) {
            return .error
        }
        if states.values.contains(where: {
            if case .reconnecting = $0 { return true }
            if case .waitingForNetwork = $0 { return true }
            if $0 == .connecting { return true }
            return false
        }) {
            return .partial
        }
        return .allConnected
    }

    private func scheduleReconnect(for config: TunnelConfig, currentAttempt: Int) {
        let scheduler = ReconnectScheduler(maxRetries: UserDefaults.standard.integer(forKey: "reconnectMaxRetries"))
        guard scheduler.shouldRetry(attempt: currentAttempt) else {
            states[config.id] = .failed(reason: "Max retries reached")
            notifications.sendFailed(tunnelName: config.name, attempts: currentAttempt)
            return
        }

        metrics[config.id]?.reconnectCount = currentAttempt + 1

        guard networkMonitor.isOnline else {
            enterWaitingForNetworkState(tunnelId: config.id, tunnelName: config.name, attempt: currentAttempt + 1)
            return
        }

        states[config.id] = .reconnecting(attempt: currentAttempt + 1)
        notifications.sendDisconnected(tunnelName: config.name, reconnecting: true)
        let item = scheduler.scheduleRetry(attempt: currentAttempt) { [weak self] in
            self?.retryCounts[config.id] = currentAttempt + 1
            self?.connect(config.id, isRetry: true)
        }
        if let item {
            retryItems[config.id] = item
        }
    }

    private func enterWaitingForNetworkState(tunnelId: UUID, tunnelName: String, attempt: Int) {
        cancelRetry(for: tunnelId)
        waitingForNetworkIds.insert(tunnelId)
        states[tunnelId] = .waitingForNetwork(attempt: attempt)
        logStore.append(tunnelId: tunnelId, tunnelName: tunnelName, level: .warning, message: "Network unavailable. Reconnect is paused until connectivity returns.")
        notifications.sendWaitingForNetwork(tunnelName: tunnelName)
    }

    private func handleNetworkStatusChange(isOnline: Bool) {
        guard isOnline else { return }

        let waitingIds = waitingForNetworkIds
        waitingForNetworkIds.removeAll()

        for tunnelId in waitingIds {
            guard let config = tunnels.first(where: { $0.id == tunnelId }) else { continue }

            if processes[tunnelId]?.isRunning == true {
                continue
            }

            if retryCounts[tunnelId] == nil {
                logStore.append(tunnelId: tunnelId, tunnelName: config.name, level: .info, message: "Network restored. Trying to connect.")
                connect(tunnelId, isRetry: false)
            } else {
                let currentAttempt = retryCounts[tunnelId] ?? 0
                logStore.append(tunnelId: tunnelId, tunnelName: config.name, level: .info, message: "Network restored. Resuming reconnect attempts.")
                scheduleReconnect(for: config, currentAttempt: currentAttempt)
            }
        }
    }
}

enum AggregateState {
    case idle
    case allConnected
    case partial
    case error
}
