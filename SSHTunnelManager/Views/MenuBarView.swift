import SwiftUI

struct MenuBarView: View {
    @Bindable var manager: TunnelManager
    @State private var showAddForm = false
    @State private var editingTunnel: TunnelConfig?
    @State private var showPreferences = false

    var body: some View {
        VStack(spacing: 0) {
            if manager.tunnels.isEmpty {
                Text("No tunnels configured")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(manager.tunnels) { tunnel in
                            TunnelRowView(
                                config: tunnel,
                                state: manager.states[tunnel.id] ?? .disconnected,
                                onToggle: { manager.toggleConnection(tunnel.id) },
                                onEdit: { editingTunnel = tunnel },
                                onDuplicate: { manager.duplicateTunnel(tunnel.id) },
                                onDelete: { manager.deleteTunnel(tunnel.id) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 300)
            }

            Divider()

            HStack {
                Button(action: { showAddForm = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { showPreferences = true }) {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
            }
            .padding(8)
        }
        .frame(width: 320)
        .sheet(isPresented: $showAddForm) {
            TunnelFormView(manager: manager)
        }
        .sheet(item: $editingTunnel) { tunnel in
            TunnelFormView(manager: manager, editing: tunnel)
        }
        .sheet(isPresented: $showPreferences) {
            PreferencesView()
        }
    }
}
