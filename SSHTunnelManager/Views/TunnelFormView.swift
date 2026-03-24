import SwiftUI

struct TunnelFormView: View {
    var manager: TunnelManager
    var editing: TunnelConfig?
    var onComplete: (() -> Void)?

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var localPort: String = ""
    @State private var remotePort: String = ""

    // Advanced (with sensible defaults)
    @State private var showAdvanced = false
    @State private var user: String = NSUserName()
    @State private var port: String = "22"
    @State private var remoteHost: String = "localhost"
    @State private var forwardingType: ForwardingType = .local
    @State private var authMethod: AuthMethod = .key
    @State private var keyPath: String = ""
    @State private var password: String = ""
    @State private var autoConnect: Bool = true

    var isEditing: Bool { editing != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(isEditing ? "Edit Tunnel" : "New Tunnel")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.dsOnSurface)
                    Text("Configure your secure port forwarding")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dsOnSurfaceVariant)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

                // Form fields
                VStack(alignment: .leading, spacing: 20) {
                DSField("Connection Name") {
                    TextField("e.g. Dev DB", text: $name)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color.dsSurfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadiusSmall))
                }

                DSField("SSH Host") {
                    TextField("e.g. myserver.com", text: $host)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color.dsSurfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadiusSmall))
                }

                HStack(spacing: 12) {
                    DSField("Local Port") {
                        TextField("e.g. 5432", text: $localPort)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.dsSurfaceContainerLow)
                            .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadiusSmall))
                    }
                    Image(systemName: "arrow.left")
                        .foregroundStyle(Color.dsOutlineVariant)
                        .padding(.top, 18)
                    DSField("Remote Port") {
                        TextField("e.g. 5432", text: $remotePort)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.dsSurfaceContainerLow)
                            .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadiusSmall))
                    }
                }

                Divider()

                DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            DSField("Username") {
                                TextField("", text: $user)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Color.dsSurfaceContainerLow)
                                    .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadiusSmall))
                            }
                            DSField("SSH Port") {
                                TextField("22", text: $port)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .frame(width: 70)
                                    .background(Color.dsSurfaceContainerLow)
                                    .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadiusSmall))
                            }
                        }

                        DSField("Remote Host") {
                            TextField("localhost", text: $remoteHost)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.dsSurfaceContainerLow)
                                .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadiusSmall))
                        }

                        DSField("Forwarding Type") {
                            Picker("", selection: $forwardingType) {
                                Text("Local (-L)").tag(ForwardingType.local)
                                Text("Remote (-R)").tag(ForwardingType.remote)
                                Text("Dynamic (-D)").tag(ForwardingType.dynamic)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }

                        DSField("Authentication") {
                            Picker("", selection: $authMethod) {
                                Text("SSH Key (auto)").tag(AuthMethod.key)
                                Text("Password").tag(AuthMethod.password)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }

                        if authMethod == .key {
                            DSField("Key Path") {
                                HStack {
                                    TextField("Leave empty for default", text: $keyPath)
                                        .textFieldStyle(.plain)
                                        .padding(10)
                                        .background(Color.dsSurfaceContainerLow)
                                        .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadiusSmall))
                                    Button("Browse...") { browseForKey() }
                                }
                            }
                        } else {
                            DSField("Password") {
                                SecureField("", text: $password)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Color.dsSurfaceContainerLow)
                                    .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadiusSmall))
                            }
                        }

                        Toggle("Auto-connect on launch", isOn: $autoConnect)
                            .tint(.dsPrimary)
                            .padding(.top, 4)
                    }
                    .padding(.top, 8)
                }
                .tint(.dsPrimary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                Button(action: { onComplete?() }) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.dsOnSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.dsSurfaceContainerHigh)
                        .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Button(action: { save() }) {
                    Text(isEditing ? "Save" : "Add Tunnel")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [.dsPrimary, .dsPrimaryDim],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius))
                        .shadow(color: .dsPrimary.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
                .opacity(isValid ? 1.0 : 0.5)
            }
            .padding(20)
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dsSurface)
        .onAppear { loadEditing() }
        .animation(.easeInOut(duration: 0.2), value: showAdvanced)
    }

    private var isValid: Bool {
        !name.isEmpty && !host.isEmpty && Int(localPort) != nil &&
        (forwardingType == .dynamic || Int(remotePort) != nil)
    }

    private func loadEditing() {
        guard let config = editing else { return }
        name = config.name
        host = config.host
        port = "\(config.port)"
        user = config.user
        authMethod = config.authMethod
        keyPath = config.keyPath ?? ""
        forwardingType = config.forwardingType
        localPort = "\(config.localPort)"
        remoteHost = config.remoteHost ?? "localhost"
        remotePort = config.remotePort.map { "\($0)" } ?? ""
        autoConnect = config.autoConnect
        if config.port != 22 || config.user != NSUserName() ||
           (config.remoteHost != "localhost" && config.remoteHost != nil) ||
           config.forwardingType != .local || config.authMethod != .key ||
           config.keyPath != nil {
            showAdvanced = true
        }
    }

    private func save() {
        let resolvedUser = user.isEmpty ? NSUserName() : user
        let config = TunnelConfig(
            id: editing?.id ?? UUID(),
            name: name,
            host: host,
            port: Int(port) ?? 22,
            user: resolvedUser,
            authMethod: authMethod,
            keyPath: authMethod == .key ? (keyPath.isEmpty ? nil : keyPath) : nil,
            forwardingType: forwardingType,
            localPort: Int(localPort) ?? 0,
            remoteHost: forwardingType == .dynamic ? nil : (remoteHost.isEmpty ? "localhost" : remoteHost),
            remotePort: forwardingType == .dynamic ? nil : Int(remotePort),
            autoConnect: autoConnect,
            enabled: editing?.enabled ?? true
        )

        let pwd = authMethod == .password && !password.isEmpty ? password : nil

        if isEditing {
            manager.updateTunnel(config, password: pwd)
        } else {
            manager.addTunnel(config, password: pwd)
            manager.connect(config.id)
        }
        onComplete?()
    }

    private func browseForKey() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".ssh")
        if panel.runModal() == .OK, let url = panel.url {
            keyPath = url.path
        }
    }
}

struct DSField<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color.dsPrimary)
            content
        }
    }
}
