import SwiftUI

@main
struct SSHTunnelManagerApp: App {
    var body: some Scene {
        MenuBarExtra("SSH Tunnel Manager", systemImage: "network") {
            Text("SSH Tunnel Manager")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
