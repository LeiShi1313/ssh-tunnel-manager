import Foundation

enum AskpassHelper {
    static func createScript(for tunnelId: UUID, serviceName: String = "com.lei.ssh-tunnel-manager") throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SSHTunnelManager")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let scriptURL = tempDir.appendingPathComponent("askpass-\(tunnelId.uuidString).sh")
        let script = """
        #!/bin/bash
        /usr/bin/security find-generic-password -s "\(serviceName)" -a "\(tunnelId.uuidString)" -w 2>/dev/null
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        return scriptURL
    }

    static func cleanup(for tunnelId: UUID) {
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SSHTunnelManager")
            .appendingPathComponent("askpass-\(tunnelId.uuidString).sh")
        try? FileManager.default.removeItem(at: scriptURL)
    }
}
