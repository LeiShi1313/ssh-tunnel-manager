import SwiftUI

@main
struct SSHTunnelManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(manager: appDelegate.manager)
        } label: {
            Image(systemName: "network")
                .symbolRenderingMode(.palette)
                .foregroundStyle(StatusBarIcon.color(for: appDelegate.manager.aggregateState))
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
            "reconnectMaxRetries": 6,
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
