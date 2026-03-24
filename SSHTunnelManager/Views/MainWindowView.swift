import SwiftUI

enum SidebarItem: Identifiable, Hashable {
    case dashboard
    case logs
    case settings
    case tunnelForm(editing: UUID?)

    var id: String {
        switch self {
        case .dashboard: return "dashboard"
        case .logs: return "logs"
        case .settings: return "settings"
        case .tunnelForm(let id): return "tunnelForm-\(id?.uuidString ?? "new")"
        }
    }

    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .logs: return "Logs"
        case .settings: return "Settings"
        case .tunnelForm(let id): return id == nil ? "New Tunnel" : "Edit Tunnel"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.33percent"
        case .logs: return "terminal"
        case .settings: return "gearshape"
        case .tunnelForm: return "point.3.connected.trianglepath.dotted"
        }
    }

    static var navItems: [SidebarItem] { [.dashboard, .logs, .settings] }
}

struct MainWindowView: View {
    @Bindable var manager: TunnelManager
    @State var selectedItem: SidebarItem = .dashboard

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .frame(minWidth: 960, minHeight: 750)
        .onAppear {
            // Check if manager has a pending edit request
            if let tunnelId = manager.pendingEditTunnelId {
                selectedItem = .tunnelForm(editing: tunnelId)
                manager.pendingEditTunnelId = nil
            }
        }
        .onChange(of: manager.pendingEditTunnelId) { _, newValue in
            if let tunnelId = newValue {
                selectedItem = .tunnelForm(editing: tunnelId)
                manager.pendingEditTunnelId = nil
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .dashboard:
            DashboardView(
                manager: manager,
                onNewTunnel: { selectedItem = .tunnelForm(editing: nil) },
                onEditTunnel: { tunnel in selectedItem = .tunnelForm(editing: tunnel.id) }
            )
        case .logs:
            LogsView(manager: manager)
        case .settings:
            PreferencesView()
        case .tunnelForm(let editingId):
            let tunnel = editingId.flatMap { id in manager.tunnels.first { $0.id == id } }
            TunnelFormView(manager: manager, editing: tunnel, onComplete: {
                selectedItem = .dashboard
            })
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Brand header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [.dsPrimary, .dsPrimaryContainer],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "network")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Forward")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Color.dsPrimary)
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.dsOnSurfaceVariant.opacity(0.5))
                        .textCase(.uppercase)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 24)

            // Nav items
            VStack(spacing: 4) {
                ForEach(SidebarItem.navItems) { item in
                    let isSelected = selectedItem == item
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.15)) {
                            selectedItem = item
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: item.icon)
                                .font(.system(size: 14))
                            Text(item.label)
                                .font(.system(size: 13, weight: .bold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isSelected ? Color.dsPrimary : .clear)
                        .foregroundStyle(isSelected ? .white : Color.dsOnSurfaceVariant)
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Show tunnel form nav item when active
                if case .tunnelForm = selectedItem {
                    HStack(spacing: 10) {
                        Image(systemName: selectedItem.icon)
                            .font(.system(size: 14))
                        Text(selectedItem.label)
                            .font(.system(size: 13, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.dsPrimary)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            // New Tunnel button
            Button(action: {
                withAnimation(.easeOut(duration: 0.15)) {
                    selectedItem = .tunnelForm(editing: nil)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("New Tunnel")
                        .font(.system(size: 13, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.dsPrimary, .dsPrimaryDim],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: .dsPrimary.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 200)
        .background(Color.dsSurfaceContainerLow.opacity(0.5))
    }
}
