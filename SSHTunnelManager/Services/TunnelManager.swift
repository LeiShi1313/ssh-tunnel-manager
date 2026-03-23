// SSHTunnelManager/Services/TunnelManager.swift
import Foundation
import SwiftUI

@Observable
class TunnelManager {

    var tunnels: [TunnelConfig] = []
    var states: [UUID: TunnelState] = [:]

    private var processes: [UUID: TunnelProcess] = [:]
    private var retryItems: [UUID: DispatchWorkItem] = [:]
    private var retryCounts: [UUID: Int] = [:]

    private let store: TunnelStore
    private let keychain: KeychainService
    private let reconnectScheduler = ReconnectScheduler()
    private let notifications: NotificationService

    private let activeTunnelIdsKey = "activeTunnelIds"

    init(
        store: TunnelStore = TunnelStore(),
        keychain: KeychainService = KeychainService(),
        notifications: NotificationService = .shared
    ) {
        self.store = store
        self.keychain = keychain
        self.notifications = notifications
    }

    // MARK: - Lifecycle

    func loadAndAutoConnect() {
        do {
            tunnels = try store.load()
        } catch {
            tunnels = []
        }
        for tunnel in tunnels {
            states[tunnel.id] = .disconnected
        }
        let activeIds = loadActiveTunnelIds()
        for tunnel in tunnels where tunnel.enabled {
            if tunnel.autoConnect || activeIds.contains(tunnel.id) {
                connect(tunnel.id)
            }
        }
    }

    func shutdownAll() {
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
        guard let config = tunnels.first(where: { $0.id == id }), config.enabled else { return }
        cancelRetry(for: id)
        retryCounts[id] = 0
        states[id] = .connecting

        let proc = TunnelProcess(config: config)
        proc.onTermination = { [weak self] exitCode in
            self?.handleTermination(tunnelId: id, exitCode: exitCode)
        }

        do {
            try proc.start()
            processes[id] = proc
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                if proc.isRunning {
                    self?.states[id] = .connected
                    self?.retryCounts[id] = 0
                }
            }
        } catch {
            states[id] = .failed(reason: error.localizedDescription)
            notifications.sendDisconnected(tunnelName: config.name, reconnecting: false)
        }
    }

    func disconnect(_ id: UUID) {
        cancelRetry(for: id)
        processes[id]?.stop()
        processes.removeValue(forKey: id)
        states[id] = .disconnected
    }

    func toggleConnection(_ id: UUID) {
        if processes[id]?.isRunning == true {
            disconnect(id)
        } else {
            connect(id)
        }
    }

    // MARK: - Reconnect

    private func handleTermination(tunnelId: UUID, exitCode: Int32) {
        processes.removeValue(forKey: tunnelId)
        guard states[tunnelId] != .disconnected else { return }
        guard let config = tunnels.first(where: { $0.id == tunnelId }) else { return }

        let reconnectEnabled = UserDefaults.standard.bool(forKey: "reconnectEnabled")
        guard reconnectEnabled else {
            states[tunnelId] = .failed(reason: "Exit code: \(exitCode)")
            notifications.sendDisconnected(tunnelName: config.name, reconnecting: false)
            return
        }

        let attempt = retryCounts[tunnelId] ?? 0
        let maxRetries = UserDefaults.standard.integer(forKey: "reconnectMaxRetries")

        if ReconnectScheduler(maxRetries: maxRetries).shouldRetry(attempt: attempt) {
            states[tunnelId] = .reconnecting(attempt: attempt + 1)
            notifications.sendDisconnected(tunnelName: config.name, reconnecting: true)
            let item = reconnectScheduler.scheduleRetry(attempt: attempt) { [weak self] in
                self?.retryCounts[tunnelId] = attempt + 1
                self?.connect(tunnelId)
            }
            if let item = item {
                retryItems[tunnelId] = item
            }
        } else {
            states[tunnelId] = .failed(reason: "Max retries reached")
            notifications.sendFailed(tunnelName: config.name, attempts: attempt)
        }
    }

    private func cancelRetry(for id: UUID) {
        retryItems[id]?.cancel()
        retryItems.removeValue(forKey: id)
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
            if $0 == .connecting { return true }
            return false
        }) {
            return .partial
        }
        return .allConnected
    }
}

enum AggregateState {
    case idle
    case allConnected
    case partial
    case error
}
