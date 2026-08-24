import Foundation

/// Creates a `CredentialResolver` for a given `CredentialSource`.
///
/// `manual` and `browserCookie` sources are stored in Mia's Keychain under
/// the provider's namespace, keyed by the subscription's UUID, so they reuse
/// the existing `KeychainStore`. Local file and keychain-item sources read
/// credentials from other apps or config files without user entry.
enum CredentialResolverFactory: Sendable {
    static func resolver(
        for source: CredentialSource,
        providerKey: String,
        subscriptionID: UUID
    ) -> CredentialResolver {
        let manual = KeychainCredentialResolver(
            service: "com.likkee.\(providerKey)",
            account: subscriptionID.uuidString
        )
        switch source {
        case .manual:
            return manual
        case .browserCookie(let cookieSource):
            // Browser cookies are also stored as a manual header in Mia's
            // Keychain for providers that cannot be auto-imported yet.
            return ChainedCredentialResolver(resolvers: [
                BrowserCookieResolver(source: cookieSource),
                manual
            ])
        case .localFile(let fileSource):
            return ChainedCredentialResolver(resolvers: [
                LocalFileResolver(source: fileSource),
                manual
            ])
        case .keychainItem(let keychainSource):
            return ChainedCredentialResolver(resolvers: [
                KeychainItemResolver(source: keychainSource),
                manual
            ])
        case .oauthDeviceFlow:
            // The OAuth device flow itself is interactive and happens at setup
            // time. The resulting access token is stored in Mia's Keychain, so
            // sync-time resolution is identical to a manual credential.
            return manual
        }
    }
}

/// Reads a credential that Mia itself stored in the Keychain (manual entry).
struct KeychainCredentialResolver: CredentialResolver {
    let service: String
    let account: String
    let keychain: KeychainStore

    var label: String {
        "Mia Keychain: \(service)"
    }

    init(service: String, account: String) {
        self.service = service
        self.account = account
        keychain = KeychainStore(service: service)
    }

    func resolve() async throws -> ResolvedCredential? {
        guard let value = try keychain.secret(account: account) else { return nil }
        return ResolvedCredential(value: value)
    }
}

/// Tries resolvers in order and returns the first success.
struct ChainedCredentialResolver: CredentialResolver {
    let resolvers: [CredentialResolver]

    var label: String {
        resolvers.map(\.label).joined(separator: " → ")
    }

    func resolve() async throws -> ResolvedCredential? {
        var lastError: Error?
        for resolver in resolvers {
            do {
                if let credential = try await resolver.resolve() {
                    return credential
                }
            } catch {
                lastError = error
            }
        }
        if let lastError {
            throw lastError
        }
        return nil
    }
}
