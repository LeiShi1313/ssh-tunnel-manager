// SSHTunnelManagerTests/KeychainServiceTests.swift
import XCTest
@testable import SSHTunnelManager

final class KeychainServiceTests: XCTestCase {

    private let testService = "com.lei.ssh-tunnel-manager.test"

    override func tearDown() {
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
