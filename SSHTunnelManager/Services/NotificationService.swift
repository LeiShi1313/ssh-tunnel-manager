import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func sendDisconnected(tunnelName: String, reconnecting: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "Tunnel Disconnected"
        content.body = reconnecting
            ? "Tunnel '\(tunnelName)' disconnected. Reconnecting..."
            : "Tunnel '\(tunnelName)' disconnected."
        content.sound = .default
        send(content, id: "disconnect-\(tunnelName)")
    }

    func sendReconnected(tunnelName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Tunnel Reconnected"
        content.body = "Tunnel '\(tunnelName)' reconnected."
        content.sound = .default
        send(content, id: "reconnect-\(tunnelName)")
    }

    func sendWaitingForNetwork(tunnelName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Tunnel Waiting for Network"
        content.body = "Tunnel '\(tunnelName)' is paused until the network connection returns."
        content.sound = .default
        send(content, id: "network-\(tunnelName)")
    }

    func sendFailed(tunnelName: String, attempts: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Tunnel Failed"
        content.body = "Tunnel '\(tunnelName)' failed after \(attempts) attempts. Click to retry."
        content.sound = .default
        send(content, id: "failed-\(tunnelName)")
    }

    private func send(_ content: UNNotificationContent, id: String) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
