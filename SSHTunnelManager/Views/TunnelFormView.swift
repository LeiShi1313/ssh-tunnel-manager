import SwiftUI

struct TunnelFormView: View {
    @Environment(\.dismiss) private var dismiss
    var manager: TunnelManager
    var editing: TunnelConfig?

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var user: String = ""
    @State private var authMethod: AuthMethod = .key
    @State private var keyPath: String = ""
    @State private var password: String = ""
    @State private var forwardingType: ForwardingType = .local
    @State private var localPort: String = ""
    @State private var remoteHost: String = "localhost"
    @State private var remotePort: String = ""
    @State private var autoConnect: Bool = false

    var isEditing: Bool { editing != nil }

    var body: some View {
        Form {
            Section("Connection") {
                TextField("Name", text: $name)
                TextField("SSH Host", text: $host)
                TextField("SSH Port", text: $port)
                TextField("Username", text: $user)
            }

            Section("Authentication") {
                Picker("Method", selection: $authMethod) {
                    Text("SSH Key").tag(AuthMethod.key)
                    Text("Password").tag(AuthMethod.password)
                }
                .pickerStyle(.segmented)

                if authMethod == .key {
                    HStack {
                        TextField("Key Path", text: $keyPath)
                        Button("Browse...") { browseForKey() }
                    }
                } else {
                    SecureField("Password", text: $password)
                }
            }

            Section("Forwarding") {
                Picker("Type", selection: $forwardingType) {
                    Text("Local (-L)").tag(ForwardingType.local)
                    Text("Remote (-R)").tag(ForwardingType.remote)
                    Text("Dynamic (-D)").tag(ForwardingType.dynamic)
                }

                TextField("Local Port", text: $localPort)

                if forwardingType != .dynamic {
                    TextField("Remote Host", text: $remoteHost)
                    TextField("Remote Port", text: $remotePort)
                }
            }

            Section {
                Toggle("Auto-connect on launch", isOn: $autoConnect)
            }

            HStack {
                Button("Cancel") { dismiss() }
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
        !name.isEmpty && !host.isEmpty && !user.isEmpty &&
        Int(port) != nil && Int(localPort) != nil &&
        (forwardingType == .dynamic || (Int(remotePort) != nil && !remoteHost.isEmpty))
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
    }

    private func save() {
        let config = TunnelConfig(
            id: editing?.id ?? UUID(),
            name: name,
            host: host,
            port: Int(port) ?? 22,
            user: user,
            authMethod: authMethod,
            keyPath: authMethod == .key ? (keyPath.isEmpty ? nil : keyPath) : nil,
            forwardingType: forwardingType,
            localPort: Int(localPort) ?? 0,
            remoteHost: forwardingType == .dynamic ? nil : remoteHost,
            remotePort: forwardingType == .dynamic ? nil : Int(remotePort),
            autoConnect: autoConnect,
            enabled: editing?.enabled ?? true
        )

        let pwd = authMethod == .password && !password.isEmpty ? password : nil

        if isEditing {
            manager.updateTunnel(config, password: pwd)
        } else {
            manager.addTunnel(config, password: pwd)
        }
        dismiss()
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
