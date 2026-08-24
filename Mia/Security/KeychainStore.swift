import Foundation
import Security

/// Typed errors raised by `KeychainStore`. Mapped to `OSStatus` codes from
/// the Security framework.
enum KeychainError: Error, Equatable {
    case unexpectedData
    case status(OSStatus)
}

/// Thin async wrapper around the `Security` framework for storing per-provider
/// secrets. Items are written with
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` so they never sync to iCloud
/// Keychain or other devices.
struct KeychainStore: Sendable {
    /// Service identifier used to namespace items, e.g. `"com.likkee.anthropic"`.
    let service: String

    // MARK: API

    func setSecret(_ secret: String, account: String) throws {
        guard let data = secret.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }

        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            try update(secret: data, account: account)
        default:
            throw KeychainError.status(status)
        }
    }

    func secret(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                throw KeychainError.unexpectedData
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.status(status)
        }
    }

    func deleteSecret(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw KeychainError.status(status)
        }
    }

    // MARK: Internals

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
    }

    private func update(secret data: Data, account: String) throws {
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainError.status(status)
        }
    }
}
