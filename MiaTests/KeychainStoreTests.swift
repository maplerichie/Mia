import Security
import XCTest
@testable import Mia

final class KeychainStoreTests: XCTestCase {
    private let service = "dev.mia.tests.\(UUID().uuidString)"
    private lazy var store = KeychainStore(service: service)
    private let account = "test-account"

    override func tearDownWithError() throws {
        try? store.deleteSecret(account: account)
    }

    func testRoundTrip() throws {
        do {
            try store.setSecret("sk-12345", account: account)
        } catch KeychainError.status(let status) where status == errSecMissingEntitlement || status == -34018 {
            throw XCTSkip("Keychain unavailable in unit test sandbox (status=\(status))")
        }

        let secret = try store.secret(account: account)
        XCTAssertEqual(secret, "sk-12345")
    }

    func testOverwriteExistingSecret() throws {
        do {
            try store.setSecret("old", account: account)
        } catch KeychainError.status(let status) where status == errSecMissingEntitlement || status == -34018 {
            throw XCTSkip("Keychain unavailable in unit test sandbox (status=\(status))")
        }
        try store.setSecret("new", account: account)
        XCTAssertEqual(try store.secret(account: account), "new")
    }

    func testMissingSecretReturnsNil() throws {
        let value: String?
        do {
            value = try store.secret(account: "does-not-exist")
        } catch KeychainError.status(let status) where status == errSecMissingEntitlement || status == -34018 {
            throw XCTSkip("Keychain unavailable in unit test sandbox (status=\(status))")
        }
        XCTAssertNil(value)
    }
}
