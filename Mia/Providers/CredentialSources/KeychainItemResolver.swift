import Foundation
import Security

/// Resolves a credential by reading a specific macOS Keychain item created by
/// another app (e.g. Zed's editor session).
struct KeychainItemResolver: CredentialResolver {
    let source: KeychainItemSource

    var label: String {
        "Keychain: \(source.service)"
    }

    func resolve() async throws -> ResolvedCredential? {
        var query: [String: Any] = [
            kSecClass as String: source.isGeneric ? kSecClassGenericPassword : kSecClassInternetPassword,
            kSecAttrServer as String: source.service,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecAttrSynchronizable as String: false
        ]

        if let account = source.account, !account.isEmpty {
            query[kSecAttrAccount as String] = account
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        } else {
            query[kSecMatchLimit as String] = kSecMatchLimitAll
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            if let account = source.account, !account.isEmpty {
                return credential(from: item)
            } else {
                // Search without account: pick the first readable item.
                guard let items = item as? [[String: Any]] else { return nil }
                for dict in items {
                    if let credential = credential(from: dict as CFTypeRef) {
                        return credential
                    }
                }
                return nil
            }
        case errSecItemNotFound:
            return nil
        case errSecUserCanceled:
            throw CredentialResolutionError.keychainAccessDenied("user canceled")
        default:
            let message = SecCopyErrorMessageString(status, nil) as String? ?? String(status)
            throw CredentialResolutionError.keychainAccessDenied(message)
        }
    }

    private func credential(from item: CFTypeRef?) -> ResolvedCredential? {
        guard let dict = item as? [String: Any] else { return nil }
        guard let data = dict[kSecValueData as String] as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        let account = dict[kSecAttrAccount as String] as? String
        return ResolvedCredential(value: value, account: account)
    }
}
