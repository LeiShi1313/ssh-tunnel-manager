import SwiftUI

struct MenuBarView: View {
    @Bindable var manager: TunnelManager

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
                                onEdit: { openEditForm(tunnel) },
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
                Button(action: { openAddForm() }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { openPreferences() }) {
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
    }

    private func openAddForm() {
        WindowManager.shared.openWindow(
            id: "add-tunnel",
            title: "Add Tunnel",
            content: TunnelFormView(manager: manager, onDismiss: {
                WindowManager.shared.closeWindow(id: "add-tunnel")
            })
        )
    }

    private func openEditForm(_ tunnel: TunnelConfig) {
        let windowId = "edit-tunnel-\(tunnel.id)"
        WindowManager.shared.openWindow(
            id: windowId,
            title: "Edit Tunnel",
            content: TunnelFormView(manager: manager, editing: tunnel, onDismiss: {
                WindowManager.shared.closeWindow(id: windowId)
            })
        )
    }

    private func openPreferences() {
        WindowManager.shared.openWindow(
            id: "preferences",
            title: "Preferences",
            content: PreferencesView(onDismiss: {
                WindowManager.shared.closeWindow(id: "preferences")
            })
        )
    }
}
