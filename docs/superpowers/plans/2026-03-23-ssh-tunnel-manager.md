# SSH Tunnel Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app that manages SSH port forwarding with monitoring, auto-reconnect, and persistent configuration.

**Architecture:** Single-process SwiftUI menu bar app (LSUIElement). Manages SSH child processes via `Process`, stores tunnel configs in JSON, passwords in Keychain. No dock icon, no main window.

**Tech Stack:** Swift 5.9+, SwiftUI, macOS 13+ (Ventura), XcodeGen for project generation, XCTest

---

## File Structure

```
ssh-tunnel-manager/
├── project.yml                                     # XcodeGen project spec
├── SSHTunnelManager/
│   ├── App/
│   │   ├── SSHTunnelManagerApp.swift               # @main entry, MenuBarExtra
│   │   └── Info.plist                              # LSUIElement = YES
│   ├── Models/
│   │   ├── TunnelConfig.swift                      # Codable data model
│   │   └── TunnelState.swift                       # Runtime state enum
│   ├── Services/
│   │   ├── SSHCommandBuilder.swift                 # Builds ssh command arguments
│   │   ├── KeychainService.swift                   # Keychain CRUD for passwords
│   │   ├── PortChecker.swift                       # Check if local port is available
│   │   ├── TunnelStore.swift                       # JSON file persistence
│   │   ├── TunnelProcess.swift                     # Single SSH process wrapper
│   │   ├── TunnelManager.swift                     # Manages all tunnels, observable
│   │   ├── ReconnectScheduler.swift                # Exponential backoff retry logic
│   │   └── NotificationService.swift               # UserNotifications wrapper
│   └── Views/
│       ├── MenuBarView.swift                       # Popover content (tunnel list)
│       ├── TunnelRowView.swift                     # Single tunnel row
│       ├── TunnelFormView.swift                    # Add/Edit tunnel sheet
│       ├── PreferencesView.swift                   # Preferences window
│       └── StatusBarIcon.swift                     # Dynamic icon color logic
├── SSHTunnelManagerTests/
│   ├── TunnelConfigTests.swift
│   ├── SSHCommandBuilderTests.swift
│   ├── KeychainServiceTests.swift
│   ├── PortCheckerTests.swift
│   ├── TunnelStoreTests.swift
│   └── ReconnectSchedulerTests.swift
└── askpass.sh                                      # SSH_ASKPASS helper script (bundled)
```

---

### Task 1: Project Scaffolding

**Files:**
- Create: `project.yml`
- Create: `SSHTunnelManager/App/SSHTunnelManagerApp.swift`
- Create: `SSHTunnelManager/App/Info.plist`

- [ ] **Step 1: Install XcodeGen if not present**

```bash
brew install xcodegen
```

- [ ] **Step 2: Create project.yml**

```yaml
name: SSHTunnelManager
options:
  bundleIdPrefix: com.lei.ssh-tunnel-manager
  deploymentTarget:
    macOS: "13.0"
  xcodeVersion: "15.0"
settings:
  SWIFT_VERSION: "5.9"
targets:
  SSHTunnelManager:
    type: application
    platform: macOS
    sources:
      - SSHTunnelManager
    settings:
      INFOPLIST_FILE: SSHTunnelManager/App/Info.plist
      PRODUCT_BUNDLE_IDENTIFIER: com.lei.ssh-tunnel-manager
      MACOSX_DEPLOYMENT_TARGET: "13.0"
      CODE_SIGN_ENTITLEMENTS: SSHTunnelManager/App/SSHTunnelManager.entitlements
    entitlements:
      path: SSHTunnelManager/App/SSHTunnelManager.entitlements
      properties:
        com.apple.security.app-sandbox: false
        com.apple.security.network.client: true
  SSHTunnelManagerTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - SSHTunnelManagerTests
    dependencies:
      - target: SSHTunnelManager
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.lei.ssh-tunnel-manager.tests
```

- [ ] **Step 3: Create Info.plist with LSUIElement**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 4: Create minimal app entry point**

```swift
// SSHTunnelManager/App/SSHTunnelManagerApp.swift
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
```

- [ ] **Step 5: Generate Xcode project and verify it builds**

```bash
cd /Users/lei/workspace/ssh-tunnel-manager
xcodegen generate
xcodebuild -project SSHTunnelManager.xcodeproj -scheme SSHTunnelManager -configuration Debug build
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: project scaffolding with menu bar app shell"
```

---

### Task 2: Data Models (TunnelConfig + TunnelState)

**Files:**
- Create: `SSHTunnelManager/Models/TunnelConfig.swift`
- Create: `SSHTunnelManager/Models/TunnelState.swift`
- Create: `SSHTunnelManagerTests/TunnelConfigTests.swift`

- [ ] **Step 1: Write failing tests for TunnelConfig**

```swift
// SSHTunnelManagerTests/TunnelConfigTests.swift
import XCTest
@testable import SSHTunnelManager

final class TunnelConfigTests: XCTestCase {

    func testEncodeDecodeTunnelConfig() throws {
        let config = TunnelConfig(
            name: "Dev DB",
            host: "server.example.com",
            port: 22,
            user: "admin",
            authMethod: .key,
            keyPath: "~/.ssh/id_ed25519",
            forwardingType: .local,
            localPort: 5432,
            remoteHost: "localhost",
            remotePort: 5432,
            autoConnect: true,
            enabled: true
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TunnelConfig.self, from: data)

        XCTAssertEqual(config.id, decoded.id)
        XCTAssertEqual(config.name, decoded.name)
        XCTAssertEqual(config.host, decoded.host)
        XCTAssertEqual(config.port, decoded.port)
        XCTAssertEqual(config.user, decoded.user)
        XCTAssertEqual(config.authMethod, decoded.authMethod)
        XCTAssertEqual(config.keyPath, decoded.keyPath)
        XCTAssertEqual(config.forwardingType, decoded.forwardingType)
        XCTAssertEqual(config.localPort, decoded.localPort)
        XCTAssertEqual(config.remoteHost, decoded.remoteHost)
        XCTAssertEqual(config.remotePort, decoded.remotePort)
        XCTAssertEqual(config.autoConnect, decoded.autoConnect)
        XCTAssertEqual(config.enabled, decoded.enabled)
    }

    func testDynamicTunnelOmitsRemoteHostAndPort() throws {
        let config = TunnelConfig(
            name: "SOCKS Proxy",
            host: "proxy.example.com",
            port: 22,
            user: "admin",
            authMethod: .key,
            keyPath: nil,
            forwardingType: .dynamic,
            localPort: 1080,
            remoteHost: nil,
            remotePort: nil,
            autoConnect: false,
            enabled: true
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TunnelConfig.self, from: data)

        XCTAssertNil(decoded.remoteHost)
        XCTAssertNil(decoded.remotePort)
        XCTAssertEqual(decoded.forwardingType, .dynamic)
    }

    func testDefaultPortIs22() {
        let config = TunnelConfig(
            name: "Test",
            host: "host",
            user: "user",
            authMethod: .key,
            forwardingType: .local,
            localPort: 8080
        )
        XCTAssertEqual(config.port, 22)
    }

    func testForwardingSummaryLocal() {
        let config = TunnelConfig(
            name: "Test",
            host: "host",
            user: "user",
            authMethod: .key,
            forwardingType: .local,
            localPort: 5432,
            remoteHost: "localhost",
            remotePort: 5432
        )
        XCTAssertEqual(config.forwardingSummary, "L:5432 → localhost:5432")
    }

    func testForwardingSummaryDynamic() {
        let config = TunnelConfig(
            name: "Test",
            host: "host",
            user: "user",
            authMethod: .key,
            forwardingType: .dynamic,
            localPort: 1080
        )
        XCTAssertEqual(config.forwardingSummary, "D:1080")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project SSHTunnelManager.xcodeproj -scheme SSHTunnelManagerTests -configuration Debug
```

Expected: Compilation failure — `TunnelConfig` not defined.

- [ ] **Step 3: Implement TunnelConfig**

```swift
// SSHTunnelManager/Models/TunnelConfig.swift
import Foundation

enum AuthMethod: String, Codable, CaseIterable {
    case key
    case password
}

enum ForwardingType: String, Codable, CaseIterable {
    case local
    case remote
    case dynamic
}

struct TunnelConfig: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var user: String
    var authMethod: AuthMethod
    var keyPath: String?
    var forwardingType: ForwardingType
    var localPort: Int
    var remoteHost: String?
    var remotePort: Int?
    var autoConnect: Bool
    var enabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        user: String,
        authMethod: AuthMethod,
        keyPath: String? = nil,
        forwardingType: ForwardingType,
        localPort: Int,
        remoteHost: String? = nil,
        remotePort: Int? = nil,
        autoConnect: Bool = false,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.user = user
        self.authMethod = authMethod
        self.keyPath = keyPath
        self.forwardingType = forwardingType
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.autoConnect = autoConnect
        self.enabled = enabled
    }

    var forwardingSummary: String {
        switch forwardingType {
        case .local:
            return "L:\(localPort) → \(remoteHost ?? "localhost"):\(remotePort ?? 0)"
        case .remote:
            return "R:\(remotePort ?? 0) → \(remoteHost ?? "localhost"):\(localPort)"
        case .dynamic:
            return "D:\(localPort)"
        }
    }
}
```

- [ ] **Step 4: Implement TunnelState**

```swift
// SSHTunnelManager/Models/TunnelState.swift
import Foundation

enum TunnelState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case failed(reason: String)
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
xcodebuild test -project SSHTunnelManager.xcodeproj -scheme SSHTunnelManagerTests -configuration Debug
```

Expected: All 5 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add TunnelConfig and TunnelState data models"
```

---

### Task 3: SSH Command Builder

**Files:**
- Create: `SSHTunnelManager/Services/SSHCommandBuilder.swift`
- Create: `SSHTunnelManagerTests/SSHCommandBuilderTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// SSHTunnelManagerTests/SSHCommandBuilderTests.swift
import XCTest
@testable import SSHTunnelManager

final class SSHCommandBuilderTests: XCTestCase {

    func testLocalForwardingCommand() {
        let config = TunnelConfig(
            name: "Dev DB",
            host: "server.example.com",
            port: 22,
            user: "admin",
            authMethod: .key,
            keyPath: "~/.ssh/id_ed25519",
            forwardingType: .local,
            localPort: 5432,
            remoteHost: "localhost",
            remotePort: 5432
        )

        let args = SSHCommandBuilder.buildArguments(for: config)

        XCTAssertTrue(args.contains("-N"))
        XCTAssertTrue(args.contains("-o"))
        XCTAssertTrue(args.contains("ExitOnForwardFailure=yes"))
        XCTAssertTrue(args.contains("-L"))
        XCTAssertTrue(args.contains("5432:localhost:5432"))
        XCTAssertTrue(args.contains("-i"))
        XCTAssertTrue(args.contains("~/.ssh/id_ed25519"))
        XCTAssertTrue(args.contains("-p"))
        XCTAssertTrue(args.contains("22"))
        XCTAssertTrue(args.contains("admin@server.example.com"))
    }

    func testRemoteForwardingCommand() {
        let config = TunnelConfig(
            name: "Remote",
            host: "server.example.com",
            port: 2222,
            user: "admin",
            authMethod: .key,
            forwardingType: .remote,
            localPort: 3000,
            remoteHost: "localhost",
            remotePort: 8080
        )

        let args = SSHCommandBuilder.buildArguments(for: config)

        XCTAssertTrue(args.contains("-R"))
        XCTAssertTrue(args.contains("8080:localhost:3000"))
        XCTAssertTrue(args.contains("2222"))
    }

    func testDynamicForwardingCommand() {
        let config = TunnelConfig(
            name: "SOCKS",
            host: "proxy.example.com",
            port: 22,
            user: "admin",
            authMethod: .key,
            forwardingType: .dynamic,
            localPort: 1080
        )

        let args = SSHCommandBuilder.buildArguments(for: config)

        XCTAssertTrue(args.contains("-D"))
        XCTAssertTrue(args.contains("1080"))
        XCTAssertFalse(args.contains("-L"))
        XCTAssertFalse(args.contains("-R"))
    }

    func testPasswordAuthNoKeyFlag() {
        let config = TunnelConfig(
            name: "Password",
            host: "server.example.com",
            port: 22,
            user: "admin",
            authMethod: .password,
            forwardingType: .local,
            localPort: 8080,
            remoteHost: "localhost",
            remotePort: 80
        )

        let args = SSHCommandBuilder.buildArguments(for: config)

        XCTAssertFalse(args.contains("-i"))
    }

    func testServerAliveOptions() {
        let config = TunnelConfig(
            name: "Test",
            host: "host",
            user: "user",
            authMethod: .key,
            forwardingType: .local,
            localPort: 8080,
            remoteHost: "localhost",
            remotePort: 80
        )

        let args = SSHCommandBuilder.buildArguments(for: config)

        XCTAssertTrue(args.contains("ServerAliveInterval=30"))
        XCTAssertTrue(args.contains("ServerAliveCountMax=3"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: Compilation failure — `SSHCommandBuilder` not defined.

- [ ] **Step 3: Implement SSHCommandBuilder**

```swift
// SSHTunnelManager/Services/SSHCommandBuilder.swift
import Foundation

enum SSHCommandBuilder {

    static func buildArguments(for config: TunnelConfig) -> [String] {
        var args: [String] = []

        // No remote command
        args.append("-N")

        // SSH options
        args += ["-o", "ExitOnForwardFailure=yes"]
        args += ["-o", "ServerAliveInterval=30"]
        args += ["-o", "ServerAliveCountMax=3"]

        // Forwarding
        switch config.forwardingType {
        case .local:
            args.append("-L")
            args.append("\(config.localPort):\(config.remoteHost ?? "localhost"):\(config.remotePort ?? 0)")
        case .remote:
            args.append("-R")
            args.append("\(config.remotePort ?? 0):\(config.remoteHost ?? "localhost"):\(config.localPort)")
        case .dynamic:
            args.append("-D")
            args.append("\(config.localPort)")
        }

        // Key auth
        if config.authMethod == .key, let keyPath = config.keyPath {
            args += ["-i", keyPath]
        }

        // Port
        args += ["-p", "\(config.port)"]

        // Destination
        args.append("\(config.user)@\(config.host)")

        return args
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add SSHCommandBuilder for constructing ssh arguments"
```

---

### Task 4: Keychain Service

**Files:**
- Create: `SSHTunnelManager/Services/KeychainService.swift`
- Create: `SSHTunnelManagerTests/KeychainServiceTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// SSHTunnelManagerTests/KeychainServiceTests.swift
import XCTest
@testable import SSHTunnelManager

final class KeychainServiceTests: XCTestCase {

    private let testService = "com.lei.ssh-tunnel-manager.test"

    override func tearDown() {
        // Clean up any test entries
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: testService,
        ]
        SecItemDelete(query as CFDictionary)
        super.tearDown()
    }

    func testSaveAndRetrievePassword() throws {
        let tunnelId = UUID()
        let password = "s3cretP@ss"

        let service = KeychainService(serviceName: testService)
        try service.savePassword(password, for: tunnelId)

        let retrieved = try service.getPassword(for: tunnelId)
        XCTAssertEqual(retrieved, password)
    }

    func testUpdateExistingPassword() throws {
        let tunnelId = UUID()
        let service = KeychainService(serviceName: testService)

        try service.savePassword("oldpass", for: tunnelId)
        try service.savePassword("newpass", for: tunnelId)

        let retrieved = try service.getPassword(for: tunnelId)
        XCTAssertEqual(retrieved, "newpass")
    }

    func testDeletePassword() throws {
        let tunnelId = UUID()
        let service = KeychainService(serviceName: testService)

        try service.savePassword("pass", for: tunnelId)
        try service.deletePassword(for: tunnelId)

        XCTAssertNil(try service.getPassword(for: tunnelId))
    }

    func testGetNonExistentPasswordReturnsNil() throws {
        let service = KeychainService(serviceName: testService)
        let result = try service.getPassword(for: UUID())
        XCTAssertNil(result)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: Compilation failure — `KeychainService` not defined.

- [ ] **Step 3: Implement KeychainService**

```swift
// SSHTunnelManager/Services/KeychainService.swift
import Foundation
import Security

struct KeychainService {

    let serviceName: String

    init(serviceName: String = "com.lei.ssh-tunnel-manager") {
        self.serviceName = serviceName
    }

    func savePassword(_ password: String, for tunnelId: UUID) throws {
        let data = Data(password.utf8)
        let account = tunnelId.uuidString

        // Try to update first
        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
        ]
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Add new
            var addQuery = searchQuery
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.saveFailed(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.saveFailed(updateStatus)
        }
    }

    func getPassword(for tunnelId: UUID) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: tunnelId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.readFailed(status)
        }
        return String(data: data, encoding: .utf8)
    }

    func deletePassword(for tunnelId: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: tunnelId.uuidString,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add KeychainService for secure password storage"
```

---

### Task 5: Port Checker

**Files:**
- Create: `SSHTunnelManager/Services/PortChecker.swift`
- Create: `SSHTunnelManagerTests/PortCheckerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// SSHTunnelManagerTests/PortCheckerTests.swift
import XCTest
@testable import SSHTunnelManager

final class PortCheckerTests: XCTestCase {

    func testAvailablePortReturnsTrue() {
        // Use a high ephemeral port unlikely to be in use
        let available = PortChecker.isPortAvailable(59123)
        XCTAssertTrue(available)
    }

    func testOccupiedPortReturnsFalse() throws {
        // Bind a port, then check it
        let socket = socket(AF_INET, SOCK_STREAM, 0)
        XCTAssertTrue(socket >= 0)
        defer { close(socket) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(59124).bigEndian
        addr.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        XCTAssertEqual(bindResult, 0, "Failed to bind test port")
        listen(socket, 1)

        let available = PortChecker.isPortAvailable(59124)
        XCTAssertFalse(available)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: Compilation failure — `PortChecker` not defined.

- [ ] **Step 3: Implement PortChecker**

```swift
// SSHTunnelManager/Services/PortChecker.swift
import Foundation

enum PortChecker {

    static func isPortAvailable(_ port: Int) -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All 2 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add PortChecker for local port availability detection"
```

---

### Task 6: Tunnel Store (JSON Persistence)

**Files:**
- Create: `SSHTunnelManager/Services/TunnelStore.swift`
- Create: `SSHTunnelManagerTests/TunnelStoreTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// SSHTunnelManagerTests/TunnelStoreTests.swift
import XCTest
@testable import SSHTunnelManager

final class TunnelStoreTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func testSaveAndLoadTunnels() throws {
        let store = TunnelStore(fileURL: tempURL)
        let tunnel = TunnelConfig(
            name: "Dev DB",
            host: "server.example.com",
            user: "admin",
            authMethod: .key,
            forwardingType: .local,
            localPort: 5432,
            remoteHost: "localhost",
            remotePort: 5432
        )

        try store.save([tunnel])
        let loaded = try store.load()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "Dev DB")
        XCTAssertEqual(loaded[0].id, tunnel.id)
    }

    func testLoadFromNonExistentFileReturnsEmpty() throws {
        let store = TunnelStore(fileURL: tempURL)
        let loaded = try store.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testSaveCreatesDirectoryIfNeeded() throws {
        let nestedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("tunnels.json")
        let store = TunnelStore(fileURL: nestedURL)

        let tunnel = TunnelConfig(
            name: "Test",
            host: "host",
            user: "user",
            authMethod: .key,
            forwardingType: .dynamic,
            localPort: 1080
        )

        try store.save([tunnel])
        let loaded = try store.load()
        XCTAssertEqual(loaded.count, 1)

        // Clean up
        try? FileManager.default.removeItem(at: nestedURL.deletingLastPathComponent())
    }

    func testSaveOverwritesPreviousData() throws {
        let store = TunnelStore(fileURL: tempURL)

        let tunnel1 = TunnelConfig(name: "A", host: "h", user: "u", authMethod: .key, forwardingType: .local, localPort: 1000)
        let tunnel2 = TunnelConfig(name: "B", host: "h", user: "u", authMethod: .key, forwardingType: .local, localPort: 2000)

        try store.save([tunnel1, tunnel2])
        try store.save([tunnel1])

        let loaded = try store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "A")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: Compilation failure — `TunnelStore` not defined.

- [ ] **Step 3: Implement TunnelStore**

```swift
// SSHTunnelManager/Services/TunnelStore.swift
import Foundation

class TunnelStore {

    let fileURL: URL

    static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SSHTunnelManager")
            .appendingPathComponent("tunnels.json")
    }

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL
    }

    func load() throws -> [TunnelConfig] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([TunnelConfig].self, from: data)
    }

    func save(_ tunnels: [TunnelConfig]) throws {
        let dir = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(tunnels)
        try data.write(to: fileURL, options: .atomic)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add TunnelStore for JSON file persistence"
```

---

### Task 7: Reconnect Scheduler

**Files:**
- Create: `SSHTunnelManager/Services/ReconnectScheduler.swift`
- Create: `SSHTunnelManagerTests/ReconnectSchedulerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// SSHTunnelManagerTests/ReconnectSchedulerTests.swift
import XCTest
@testable import SSHTunnelManager

final class ReconnectSchedulerTests: XCTestCase {

    func testBackoffSchedule() {
        let scheduler = ReconnectScheduler()
        XCTAssertEqual(scheduler.delay(forAttempt: 0), 1.0)
        XCTAssertEqual(scheduler.delay(forAttempt: 1), 2.0)
        XCTAssertEqual(scheduler.delay(forAttempt: 2), 5.0)
        XCTAssertEqual(scheduler.delay(forAttempt: 3), 10.0)
        XCTAssertEqual(scheduler.delay(forAttempt: 4), 30.0)
        XCTAssertEqual(scheduler.delay(forAttempt: 5), 60.0)
    }

    func testBackoffCapsAt60() {
        let scheduler = ReconnectScheduler()
        XCTAssertEqual(scheduler.delay(forAttempt: 6), 60.0)
        XCTAssertEqual(scheduler.delay(forAttempt: 100), 60.0)
    }

    func testShouldRetryUnlimited() {
        let scheduler = ReconnectScheduler(maxRetries: 0)
        XCTAssertTrue(scheduler.shouldRetry(attempt: 0))
        XCTAssertTrue(scheduler.shouldRetry(attempt: 999))
    }

    func testShouldRetryLimited() {
        let scheduler = ReconnectScheduler(maxRetries: 3)
        XCTAssertTrue(scheduler.shouldRetry(attempt: 0))
        XCTAssertTrue(scheduler.shouldRetry(attempt: 2))
        XCTAssertFalse(scheduler.shouldRetry(attempt: 3))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: Compilation failure — `ReconnectScheduler` not defined.

- [ ] **Step 3: Implement ReconnectScheduler**

```swift
// SSHTunnelManager/Services/ReconnectScheduler.swift
import Foundation

class ReconnectScheduler {

    private static let backoffSchedule: [TimeInterval] = [1, 2, 5, 10, 30, 60]
    let maxRetries: Int  // 0 = unlimited

    init(maxRetries: Int = 0) {
        self.maxRetries = maxRetries
    }

    func delay(forAttempt attempt: Int) -> TimeInterval {
        let index = min(attempt, Self.backoffSchedule.count - 1)
        return Self.backoffSchedule[index]
    }

    func shouldRetry(attempt: Int) -> Bool {
        if maxRetries == 0 { return true }
        return attempt < maxRetries
    }

    func scheduleRetry(attempt: Int, action: @escaping () -> Void) -> DispatchWorkItem? {
        guard shouldRetry(attempt: attempt) else { return nil }
        let item = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay(forAttempt: attempt), execute: item)
        return item
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add ReconnectScheduler with exponential backoff"
```

---

### Task 8: Notification Service

**Files:**
- Create: `SSHTunnelManager/Services/NotificationService.swift`

- [ ] **Step 1: Implement NotificationService**

No unit tests for this — it wraps `UNUserNotificationCenter` which requires user permission and a running app. Will be tested during integration.

```swift
// SSHTunnelManager/Services/NotificationService.swift
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
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "feat: add NotificationService for tunnel status alerts"
```

---

### Task 9: SSH_ASKPASS Helper

**Files:**
- Create: `SSHTunnelManager/Services/AskpassHelper.swift`

- [ ] **Step 1: Implement AskpassHelper**

This generates a temporary askpass script at runtime that uses `security` CLI to read from Keychain.

```swift
// SSHTunnelManager/Services/AskpassHelper.swift
import Foundation

enum AskpassHelper {

    static func createScript(for tunnelId: UUID, serviceName: String = "com.lei.ssh-tunnel-manager") throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SSHTunnelManager")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let scriptURL = tempDir.appendingPathComponent("askpass-\(tunnelId.uuidString).sh")

        let script = """
        #!/bin/bash
        /usr/bin/security find-generic-password -s "\(serviceName)" -a "\(tunnelId.uuidString)" -w 2>/dev/null
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: scriptURL.path
        )

        return scriptURL
    }

    static func cleanup(for tunnelId: UUID) {
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SSHTunnelManager")
            .appendingPathComponent("askpass-\(tunnelId.uuidString).sh")
        try? FileManager.default.removeItem(at: scriptURL)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "feat: add AskpassHelper for SSH_ASKPASS password delivery"
```

---

### Task 10: TunnelProcess (Single SSH Process Wrapper)

**Files:**
- Create: `SSHTunnelManager/Services/TunnelProcess.swift`

- [ ] **Step 1: Implement TunnelProcess**

This wraps a single `Process` for one SSH tunnel. Not unit-testable (requires real SSH), but provides a clean interface for TunnelManager.

```swift
// SSHTunnelManager/Services/TunnelProcess.swift
import Foundation

class TunnelProcess {

    let config: TunnelConfig
    private var process: Process?
    private var askpassURL: URL?

    var isRunning: Bool { process?.isRunning ?? false }

    var onTermination: ((Int32) -> Void)?

    init(config: TunnelConfig) {
        self.config = config
    }

    func start() throws {
        guard !isRunning else { return }

        // Check port availability
        guard PortChecker.isPortAvailable(config.localPort) else {
            throw TunnelError.portInUse(config.localPort)
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        proc.arguments = SSHCommandBuilder.buildArguments(for: config)

        // Set up environment for password auth
        if config.authMethod == .password {
            let scriptURL = try AskpassHelper.createScript(for: config.id)
            askpassURL = scriptURL
            var env = ProcessInfo.processInfo.environment
            env["SSH_ASKPASS"] = scriptURL.path
            env["SSH_ASKPASS_REQUIRE"] = "force"
            env["DISPLAY"] = ":0"
            proc.environment = env
        }

        // Suppress stdout/stderr
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        proc.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.onTermination?(process.terminationStatus)
            }
        }

        try proc.run()
        self.process = proc
    }

    func stop() {
        guard let proc = process, proc.isRunning else { return }
        proc.terminate()

        // Give it 2 seconds, then SIGKILL
        let pid = proc.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak proc] in
            if let proc = proc, proc.isRunning {
                kill(pid, SIGKILL)
            }
        }

        cleanup()
    }

    private func cleanup() {
        AskpassHelper.cleanup(for: config.id)
        askpassURL = nil
    }

    deinit {
        stop()
    }
}

enum TunnelError: LocalizedError {
    case portInUse(Int)

    var errorDescription: String? {
        switch self {
        case .portInUse(let port):
            return "Port \(port) is already in use"
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "feat: add TunnelProcess wrapper for SSH child processes"
```

---

### Task 11: TunnelManager (Core Observable State)

**Files:**
- Create: `SSHTunnelManager/Services/TunnelManager.swift`

- [ ] **Step 1: Implement TunnelManager**

This is the central `@Observable` class that the UI binds to.

```swift
// SSHTunnelManager/Services/TunnelManager.swift
import Foundation
import SwiftUI

@Observable
class TunnelManager {

    var tunnels: [TunnelConfig] = []
    var states: [UUID: TunnelState] = [:]

    private var processes: [UUID: TunnelProcess] = [:]
    private var retryItems: [UUID: DispatchWorkItem] = [:]
    private var retryCounts: [UUID: Int] = [:]

    private let store: TunnelStore
    private let keychain: KeychainService
    private let reconnectScheduler = ReconnectScheduler()
    private let notifications: NotificationService

    // Track which tunnels were active (for restore on relaunch)
    private let activeTunnelIdsKey = "activeTunnelIds"

    init(
        store: TunnelStore = TunnelStore(),
        keychain: KeychainService = KeychainService(),
        notifications: NotificationService = .shared
    ) {
        self.store = store
        self.keychain = keychain
        self.notifications = notifications
    }

    // MARK: - Lifecycle

    func loadAndAutoConnect() {
        do {
            tunnels = try store.load()
        } catch {
            tunnels = []
        }

        // Initialize states
        for tunnel in tunnels {
            states[tunnel.id] = .disconnected
        }

        // Restore previously active tunnels
        let activeIds = loadActiveTunnelIds()

        for tunnel in tunnels where tunnel.enabled {
            if tunnel.autoConnect || activeIds.contains(tunnel.id) {
                connect(tunnel.id)
            }
        }
    }

    func shutdownAll() {
        saveActiveTunnelIds()
        for (id, _) in processes {
            cancelRetry(for: id)
            processes[id]?.stop()
        }
        processes.removeAll()
    }

    // MARK: - CRUD

    func addTunnel(_ config: TunnelConfig, password: String? = nil) {
        tunnels.append(config)
        states[config.id] = .disconnected
        if let password = password, config.authMethod == .password {
            try? keychain.savePassword(password, for: config.id)
        }
        saveToDisk()
    }

    func updateTunnel(_ config: TunnelConfig, password: String? = nil) {
        if let index = tunnels.firstIndex(where: { $0.id == config.id }) {
            let wasConnected = processes[config.id]?.isRunning ?? false
            if wasConnected { disconnect(config.id) }

            tunnels[index] = config
            if let password = password, config.authMethod == .password {
                try? keychain.savePassword(password, for: config.id)
            }
            saveToDisk()

            if wasConnected { connect(config.id) }
        }
    }

    func deleteTunnel(_ id: UUID) {
        disconnect(id)
        try? keychain.deletePassword(for: id)
        tunnels.removeAll { $0.id == id }
        states.removeValue(forKey: id)
        saveToDisk()
    }

    func duplicateTunnel(_ id: UUID) {
        guard let original = tunnels.first(where: { $0.id == id }) else { return }
        var copy = original
        copy.id = UUID()
        copy.name = "\(original.name) (Copy)"
        copy.autoConnect = false
        addTunnel(copy)
    }

    // MARK: - Connect / Disconnect

    func connect(_ id: UUID) {
        guard let config = tunnels.first(where: { $0.id == id }), config.enabled else { return }

        cancelRetry(for: id)
        retryCounts[id] = 0
        states[id] = .connecting

        let proc = TunnelProcess(config: config)
        proc.onTermination = { [weak self] exitCode in
            self?.handleTermination(tunnelId: id, exitCode: exitCode)
        }

        do {
            try proc.start()
            processes[id] = proc
            // Consider connected after a brief delay (ssh doesn't signal success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                if proc.isRunning {
                    self?.states[id] = .connected
                    self?.retryCounts[id] = 0
                }
            }
        } catch {
            states[id] = .failed(reason: error.localizedDescription)
            notifications.sendDisconnected(tunnelName: config.name, reconnecting: false)
        }
    }

    func disconnect(_ id: UUID) {
        cancelRetry(for: id)
        processes[id]?.stop()
        processes.removeValue(forKey: id)
        states[id] = .disconnected
    }

    func toggleConnection(_ id: UUID) {
        if processes[id]?.isRunning == true {
            disconnect(id)
        } else {
            connect(id)
        }
    }

    // MARK: - Reconnect

    private func handleTermination(tunnelId: UUID, exitCode: Int32) {
        processes.removeValue(forKey: tunnelId)

        // If state is already .disconnected, it was intentional
        guard states[tunnelId] != .disconnected else { return }

        guard let config = tunnels.first(where: { $0.id == tunnelId }) else { return }

        let reconnectEnabled = UserDefaults.standard.bool(forKey: "reconnectEnabled")
        guard reconnectEnabled else {
            states[tunnelId] = .failed(reason: "Exit code: \(exitCode)")
            notifications.sendDisconnected(tunnelName: config.name, reconnecting: false)
            return
        }

        let attempt = retryCounts[tunnelId] ?? 0
        let maxRetries = UserDefaults.standard.integer(forKey: "reconnectMaxRetries")

        if ReconnectScheduler(maxRetries: maxRetries).shouldRetry(attempt: attempt) {
            states[tunnelId] = .reconnecting(attempt: attempt + 1)
            notifications.sendDisconnected(tunnelName: config.name, reconnecting: true)

            let item = reconnectScheduler.scheduleRetry(attempt: attempt) { [weak self] in
                self?.retryCounts[tunnelId] = attempt + 1
                self?.connect(tunnelId)
            }
            if let item = item {
                retryItems[tunnelId] = item
            }
        } else {
            states[tunnelId] = .failed(reason: "Max retries reached")
            notifications.sendFailed(tunnelName: config.name, attempts: attempt)
        }
    }

    private func cancelRetry(for id: UUID) {
        retryItems[id]?.cancel()
        retryItems.removeValue(forKey: id)
    }

    // MARK: - Persistence

    private func saveToDisk() {
        try? store.save(tunnels)
    }

    private func saveActiveTunnelIds() {
        let activeIds = processes.filter { $0.value.isRunning }.map { $0.key.uuidString }
        UserDefaults.standard.set(activeIds, forKey: activeTunnelIdsKey)
    }

    private func loadActiveTunnelIds() -> Set<UUID> {
        guard let strings = UserDefaults.standard.stringArray(forKey: activeTunnelIdsKey) else {
            return []
        }
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }

    // MARK: - Aggregate State (for status bar icon)

    var aggregateState: AggregateState {
        if tunnels.isEmpty || states.values.allSatisfy({ $0 == .disconnected }) {
            return .idle
        }
        if states.values.contains(where: {
            if case .failed = $0 { return true }; return false
        }) {
            return .error
        }
        if states.values.contains(where: {
            if case .reconnecting = $0 { return true }
            if $0 == .connecting { return true }
            return false
        }) {
            return .partial
        }
        return .allConnected
    }
}

enum AggregateState {
    case idle          // gray
    case allConnected  // green
    case partial       // yellow
    case error         // red
}
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "feat: add TunnelManager as central observable state manager"
```

---

### Task 12: Menu Bar & Tunnel List Views

**Files:**
- Modify: `SSHTunnelManager/App/SSHTunnelManagerApp.swift`
- Create: `SSHTunnelManager/Views/StatusBarIcon.swift`
- Create: `SSHTunnelManager/Views/MenuBarView.swift`
- Create: `SSHTunnelManager/Views/TunnelRowView.swift`

- [ ] **Step 1: Create StatusBarIcon**

```swift
// SSHTunnelManager/Views/StatusBarIcon.swift
import SwiftUI

struct StatusBarIcon {
    static func systemImageName(for state: AggregateState) -> String {
        "network"
    }

    static func color(for state: AggregateState) -> Color {
        switch state {
        case .idle: return .gray
        case .allConnected: return .green
        case .partial: return .orange
        case .error: return .red
        }
    }
}
```

- [ ] **Step 2: Create TunnelRowView**

```swift
// SSHTunnelManager/Views/TunnelRowView.swift
import SwiftUI

struct TunnelRowView: View {
    let config: TunnelConfig
    let state: TunnelState
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.system(size: 13, weight: .medium))
                Text(config.forwardingSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if case .reconnecting(let attempt) = state {
                Text("retry \(attempt)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Button(action: onToggle) {
                Image(systemName: isActive ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(isActive ? .red : .green)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contextMenu {
            Button("Edit...") { onEdit() }
            Button("Duplicate") { onDuplicate() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private var isActive: Bool {
        switch state {
        case .connected, .connecting, .reconnecting:
            return true
        default:
            return false
        }
    }

    private var stateColor: Color {
        switch state {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .reconnecting: return .orange
        case .failed: return .red
        }
    }
}
```

- [ ] **Step 3: Create MenuBarView**

```swift
// SSHTunnelManager/Views/MenuBarView.swift
import SwiftUI

struct MenuBarView: View {
    @Bindable var manager: TunnelManager
    @State private var showAddForm = false
    @State private var editingTunnel: TunnelConfig?
    @State private var showPreferences = false

    var body: some View {
        VStack(spacing: 0) {
            if manager.tunnels.isEmpty {
                Text("No tunnels configured")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(manager.tunnels) { tunnel in
                            TunnelRowView(
                                config: tunnel,
                                state: manager.states[tunnel.id] ?? .disconnected,
                                onToggle: { manager.toggleConnection(tunnel.id) },
                                onEdit: { editingTunnel = tunnel },
                                onDuplicate: { manager.duplicateTunnel(tunnel.id) },
                                onDelete: { manager.deleteTunnel(tunnel.id) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 300)
            }

            Divider()

            HStack {
                Button(action: { showAddForm = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { showPreferences = true }) {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
            }
            .padding(8)
        }
        .frame(width: 320)
        .sheet(isPresented: $showAddForm) {
            TunnelFormView(manager: manager)
        }
        .sheet(item: $editingTunnel) { tunnel in
            TunnelFormView(manager: manager, editing: tunnel)
        }
        .sheet(isPresented: $showPreferences) {
            PreferencesView()
        }
    }
}
```

- [ ] **Step 4: Update SSHTunnelManagerApp to use the views**

```swift
// SSHTunnelManager/App/SSHTunnelManagerApp.swift
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
        NotificationService.shared.requestPermission()
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager.shutdownAll()
    }
}
```

Note: `loadAndAutoConnect()` will be wired in Task 15 (App Lifecycle). For now the app launches with an empty list.

- [ ] **Step 5: Build and verify**

```bash
xcodegen generate && xcodebuild -project SSHTunnelManager.xcodeproj -scheme SSHTunnelManager -configuration Debug build
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add menu bar UI with tunnel list and status icon"
```

---

### Task 13: Add/Edit Tunnel Form

**Files:**
- Create: `SSHTunnelManager/Views/TunnelFormView.swift`

- [ ] **Step 1: Implement TunnelFormView**

```swift
// SSHTunnelManager/Views/TunnelFormView.swift
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
```

- [ ] **Step 2: Build and verify**

```bash
xcodegen generate && xcodebuild -project SSHTunnelManager.xcodeproj -scheme SSHTunnelManager -configuration Debug build
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add tunnel add/edit form with validation"
```

---

### Task 14: Preferences View

**Files:**
- Create: `SSHTunnelManager/Views/PreferencesView.swift`

- [ ] **Step 1: Implement PreferencesView**

```swift
// SSHTunnelManager/Views/PreferencesView.swift
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
```

- [ ] **Step 2: Build and verify**

```bash
xcodegen generate && xcodebuild -project SSHTunnelManager.xcodeproj -scheme SSHTunnelManager -configuration Debug build
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add preferences view with launch-at-login and reconnect settings"
```

---

### Task 15: App Lifecycle (Auto-Connect, Quit Cleanup)

**Files:**
- Modify: `SSHTunnelManager/App/SSHTunnelManagerApp.swift`

- [ ] **Step 1: Wire up lifecycle events using AppDelegate**

Replace the app entry point with a concrete AppDelegate-based approach. This ensures `loadAndAutoConnect()` fires on app launch (not on first popover open) and `shutdownAll()` fires on quit.

```swift
// SSHTunnelManager/App/SSHTunnelManagerApp.swift
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
        NotificationService.shared.requestPermission()
        manager.loadAndAutoConnect()
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager.shutdownAll()
    }
}
```

Key points:
- `@NSApplicationDelegateAdaptor` registers the delegate automatically
- `manager` lives on `AppDelegate`, not as `@State` on the struct — avoids ownership issues
- Both lifecycle hooks are concrete, no placeholders

- [ ] **Step 2: Build and verify**

```bash
xcodegen generate && xcodebuild -project SSHTunnelManager.xcodeproj -scheme SSHTunnelManager -configuration Debug build
```

- [ ] **Step 3: Run all tests**

```bash
xcodebuild test -project SSHTunnelManager.xcodeproj -scheme SSHTunnelManagerTests -configuration Debug
```

Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: wire up app lifecycle — auto-connect on launch, cleanup on quit"
```

---

### Task 16: Manual Integration Test

- [ ] **Step 1: Build and launch the app**

```bash
xcodebuild -project SSHTunnelManager.xcodeproj -scheme SSHTunnelManager -configuration Debug build
open build/Debug/SSHTunnelManager.app
```

- [ ] **Step 2: Verify manually**

Checklist:
- App appears in menu bar with gray network icon (no tunnels)
- Click icon → popover shows "No tunnels configured"
- Click "+" → Add tunnel form appears
- Fill in a test tunnel (local forwarding to any SSH server available)
- Save → tunnel appears in list with gray dot
- Click play → tunnel connects (green dot)
- Click stop → tunnel disconnects (gray dot)
- Edit, Duplicate, Delete via right-click
- Open Preferences → toggle Launch at Login, reconnect settings
- Quit via power icon

- [ ] **Step 3: Final commit with version tag**

```bash
git add -A
git commit -m "feat: SSH Tunnel Manager v1.0 — complete implementation"
git tag v1.0.0
```
