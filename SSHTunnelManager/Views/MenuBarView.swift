import SwiftUI

struct MenuBarView: View {
    @Bindable var manager: TunnelManager

    private var activeTunnelCount: Int {
        manager.states.values.filter { state in
            if case .connected = state { return true }
            return false
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with stats
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SSH Tunnels")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.dsOnSurface)
                    Text("\(activeTunnelCount) active of \(manager.tunnels.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.dsOnSurfaceVariant)
                }
                Spacer()
                if !manager.tunnels.isEmpty {
                    Text(activeTunnelCount > 0 ? "Online" : "Idle")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(activeTunnelCount > 0 ? Color.dsPrimary : Color.dsOnSurfaceVariant)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(activeTunnelCount > 0 ? Color.dsPrimary.opacity(0.1) : Color.dsOnSurfaceVariant.opacity(0.08))
                        )
                }
            }
            .padding(.horizontal, DS.sectionPadding)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, DS.sectionPadding)

            // Tunnel list
            if manager.tunnels.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.dsOutlineVariant)
                    Text("No tunnels configured")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dsOnSurfaceVariant)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(manager.tunnels) { tunnel in
                            TunnelRowView(
                                config: tunnel,
                                state: manager.states[tunnel.id] ?? .disconnected,
                                onToggle: { manager.toggleConnection(tunnel.id) },
                                onEdit: { manager.openDashboard(editingTunnelId: tunnel.id) },
                                onDuplicate: { manager.duplicateTunnel(tunnel.id) },
                                onDelete: { manager.deleteTunnel(tunnel.id) }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 340)
            }

            Divider()
                .padding(.horizontal, DS.sectionPadding)

            // Bottom toolbar
            HStack(spacing: 10) {
                Button(action: { manager.openDashboard() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.expand.vertical")
                            .font(.system(size: 12))
                        Text("Dashboard")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.dsPrimary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "power")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dsOnSurfaceVariant)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.sectionPadding)
            .padding(.vertical, 10)
        }
        .frame(width: 360)
    }
}
