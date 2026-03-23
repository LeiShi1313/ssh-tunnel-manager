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
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("SSH Host", text: $host)
                    .textContentType(.URL)
                HStack(spacing: 12) {
                    TextField("Local Port", text: $localPort)
                    Image(systemName: "arrow.left")
                        .foregroundStyle(.secondary)
                    TextField("Remote Port", text: $remotePort)
                }
            }

            DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                TextField("Username", text: $user)
                TextField("SSH Port", text: $port)
                TextField("Remote Host", text: $remoteHost)

                Picker("Forwarding", selection: $forwardingType) {
                    Text("Local (-L)").tag(ForwardingType.local)
                    Text("Remote (-R)").tag(ForwardingType.remote)
                    Text("Dynamic (-D)").tag(ForwardingType.dynamic)
                }

                Picker("Auth", selection: $authMethod) {
                    Text("SSH Key (auto)").tag(AuthMethod.key)
                    Text("Password").tag(AuthMethod.password)
                }
                .pickerStyle(.segmented)

                if authMethod == .key {
                    HStack {
                        TextField("Key Path (leave empty for default)", text: $keyPath)
                        Button("Browse...") { browseForKey() }
                    }
                } else {
                    SecureField("Password", text: $password)
                }

                Toggle("Auto-connect on launch", isOn: $autoConnect)
            }

            HStack {
                Button("Cancel") { onDismiss?() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding(.top, 8)
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .padding()
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
        // Show advanced if any non-default values
        if config.port != 22 || config.user != NSUserName() ||
           config.remoteHost != "localhost" && config.remoteHost != nil ||
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
