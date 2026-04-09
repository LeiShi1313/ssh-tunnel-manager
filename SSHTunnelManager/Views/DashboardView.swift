import SwiftUI

struct DashboardView: View {
    @Bindable var manager: TunnelManager
    var onNewTunnel: () -> Void = {}
    var onEditTunnel: (TunnelConfig) -> Void = { _ in }

    private var activeTunnelCount: Int {
        manager.states.values.filter { state in
            if case .connected = state { return true }
            return false
        }.count
    }

    private var totalUptime: TimeInterval {
        manager.metrics.values.reduce(0) { $0 + $1.uptimeSeconds }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Forwarding")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.dsOnSurface)
                    Text("Manage your active network tunnels and port assignments.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.dsOnSurfaceVariant)
                }
                Spacer()
                Button(action: onNewTunnel) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("New Tunnel")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.dsPrimary)
                    .clipShape(Capsule())
                    .shadow(color: .dsPrimary.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 20)

            // Main content grid
            HStack(alignment: .top, spacing: 24) {
                // Left: Tunnel cards
                ScrollView {
                    VStack(spacing: 12) {
                        if manager.tunnels.isEmpty {
                            emptyState
                        } else {
                            ForEach(manager.tunnels) { tunnel in
                                DashboardTunnelCard(
                                    config: tunnel,
                                    state: manager.states[tunnel.id] ?? .disconnected,
                                    metrics: manager.metrics[tunnel.id],
                                    onToggle: { manager.toggleConnection(tunnel.id) },
                                    onEdit: { onEditTunnel(tunnel) },
                                    onDuplicate: { manager.duplicateTunnel(tunnel.id) },
                                    onDelete: { manager.deleteTunnel(tunnel.id) }
                                )
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // Right: Health panel
                VStack(spacing: 16) {
                    healthPanel
                    Spacer()
                }
                .frame(width: 280)
            }
            .padding(.horizontal, 32)

            // Bottom stats
            statsBar
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.dsSurface)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(.system(size: 36))
                .foregroundStyle(Color.dsOutlineVariant)
            Text("No tunnels configured")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.dsOnSurfaceVariant)
            Text("Add a tunnel from the menu bar to get started.")
                .font(.system(size: 13))
                .foregroundStyle(Color.dsOutlineVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var healthPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Network Health")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.7))

            Text(activeTunnelCount > 0 ? "All Systems\nOperational" : "No Active\nConnections")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .lineSpacing(2)

            VStack(spacing: 8) {
                HStack {
                    Text("Active Tunnels")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("\(activeTunnelCount) / \(manager.tunnels.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.2))
                            .frame(height: 6)
                        Capsule()
                            .fill(.white)
                            .frame(width: manager.tunnels.isEmpty ? 0 : geo.size.width * CGFloat(activeTunnelCount) / CGFloat(manager.tunnels.count), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [.dsPrimary, .dsPrimaryDim],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadiusLarge))
    }

    private var statsBar: some View {
        HStack(spacing: 16) {
            StatCard(label: "Active Tunnels", value: "\(activeTunnelCount)", unit: "Live")
            StatCard(label: "Total Configured", value: "\(manager.tunnels.count)", unit: "Tunnels")
            StatCard(label: "Encryption", value: "SSH", unit: "AES-256")
            StatCard(label: "Total Uptime", value: formatUptime(totalUptime), unit: "")
        }
        .padding(.top, 16)
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "\(Int(seconds))s" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        return "\(Int(seconds / 3600))h"
    }
}

// MARK: - Subviews

struct DashboardTunnelCard: View {
    let config: TunnelConfig
    let state: TunnelState
    let metrics: TunnelMetrics?
    let onToggle: () -> Void
    var onEdit: () -> Void = {}
    var onDuplicate: () -> Void = {}
    var onDelete: () -> Void = {}

    @State private var isHovered = false

    private var isActive: Bool {
        switch state {
        case .connected, .connecting, .reconnecting, .waitingForNetwork: return true
        default: return false
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(isActive ? Color.dsPrimary.opacity(0.1) : Color.dsOnSurfaceVariant.opacity(0.06))
                    .frame(width: 48, height: 48)
                Image(systemName: isActive ? "bolt.fill" : "cloud.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(isActive ? Color.dsPrimary : Color.dsOnSurfaceVariant)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(config.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.dsOnSurface)
                Text(config.forwardingSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dsOnSurfaceVariant)
            }

            Spacer()

            // Status
            VStack(alignment: .trailing, spacing: 4) {
                Text("Status")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.dsOnSurfaceVariant.opacity(0.6))
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
            }

            // Toggle button
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.dsSurfaceContainer : Color.dsPrimary)
                        .frame(width: 36, height: 36)
                    Image(systemName: isActive ? "stop.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isActive ? Color.dsOnSurfaceVariant : .white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: DS.cornerRadius)
                .fill(.white)
                .shadow(color: isHovered ? .black.opacity(0.06) : .clear, radius: 20, y: 8)
        )
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) { onEdit() }
        .contextMenu {
            Button("Edit...") { onEdit() }
            Button("Duplicate") { onDuplicate() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private var statusColor: Color {
        switch state {
        case .connected: return .dsPrimary
        case .connecting, .reconnecting: return .dsTertiary
        case .waitingForNetwork: return .orange
        case .disconnected: return .dsOnSurfaceVariant
        case .failed: return .dsError
        }
    }

    private var statusText: String {
        switch state {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .reconnecting: return "Reconnecting"
        case .waitingForNetwork: return "Waiting for network"
        case .disconnected: return "Stopped"
        case .failed: return "Failed"
        }
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Color.dsOnSurfaceVariant)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.dsOnSurface)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.dsPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.dsSurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius))
    }
}
