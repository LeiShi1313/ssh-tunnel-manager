import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("reconnectEnabled") private var reconnectEnabled = true
    @AppStorage("reconnectMaxRetries") private var reconnectMaxRetries = 0
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = !newValue
                        }
                    }
            }

            Section("Reconnect") {
                Toggle("Auto-reconnect on disconnect", isOn: $reconnectEnabled)

                if reconnectEnabled {
                    Stepper(
                        "Max retries: \(reconnectMaxRetries == 0 ? "Unlimited" : "\(reconnectMaxRetries)")",
                        value: $reconnectMaxRetries,
                        in: 0...100
                    )
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .formStyle(.grouped)
        .frame(width: 350)
        .padding()
    }
}
