import SwiftUI

struct TunnelFormView: View {
    var manager: TunnelManager
    var editing: TunnelConfig?
    var onDismiss: (() -> Void)?

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
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(isEditing ? "Edit Tunnel" : "New Tunnel")
                        .font(.headline)

                    LabeledField("Name") {
                        TextField("e.g. Dev DB", text: $name)
                    }

                    LabeledField("SSH Host") {
                        TextField("e.g. myserver.com", text: $host)
                    }

                    HStack(spacing: 12) {
                        LabeledField("Local Port") {
                            TextField("e.g. 5432", text: $localPort)
                        }
                        Text("←")
                            .foregroundStyle(.secondary)
                            .padding(.top, 18)
                        LabeledField("Remote Port") {
                            TextField("e.g. 5432", text: $remotePort)
                        }
                    }

                    Divider()

                    DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                LabeledField("Username") {
                                    TextField("", text: $user)
                                }
                                LabeledField("SSH Port") {
                                    TextField("22", text: $port)
                                        .frame(width: 60)
                                }
                            }

                            LabeledField("Remote Host") {
                                TextField("localhost", text: $remoteHost)
                            }

                            LabeledField("Forwarding Type") {
                                Picker("", selection: $forwardingType) {
                                    Text("Local (-L)").tag(ForwardingType.local)
                                    Text("Remote (-R)").tag(ForwardingType.remote)
                                    Text("Dynamic (-D)").tag(ForwardingType.dynamic)
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                            }

                            LabeledField("Authentication") {
                                Picker("", selection: $authMethod) {
                                    Text("SSH Key (auto)").tag(AuthMethod.key)
                                    Text("Password").tag(AuthMethod.password)
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                            }

                            if authMethod == .key {
                                LabeledField("Key Path") {
                                    HStack {
                                        TextField("Leave empty for default", text: $keyPath)
                                        Button("Browse...") { browseForKey() }
                                    }
                                }
                            } else {
                                LabeledField("Password") {
                                    SecureField("", text: $password)
                                }
                            }

                            Toggle("Auto-connect on launch", isOn: $autoConnect)
                                .padding(.top, 4)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("Cancel") { onDismiss?() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding(16)
        }
        .frame(width: 420)
        .frame(minHeight: 300, maxHeight: 560)
        .onAppear { loadEditing() }
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
        onDismiss?()
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

struct LabeledField<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content
                .textFieldStyle(.roundedBorder)
        }
    }
}
