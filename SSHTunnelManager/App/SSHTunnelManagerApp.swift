import SwiftUI

@main
struct SSHTunnelManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(manager: appDelegate.manager)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "network")
                Image(systemName: "circle.fill")
                    .font(.system(size: 5))
                    .foregroundStyle(StatusBarIcon.color(for: appDelegate.manager.aggregateState))
            }
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let manager = TunnelManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register UserDefaults defaults (AppStorage defaults only apply in SwiftUI views)
        UserDefaults.standard.register(defaults: [
            "reconnectEnabled": true,
            "reconnectMaxRetries": 0,
        ])

        // Skip notification setup when running under XCTest to avoid UNUserNotificationCenter crash
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !isRunningTests {
            NotificationService.shared.requestPermission()
        }
        manager.loadAndAutoConnect()
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager.shutdownAll()
    }
}
