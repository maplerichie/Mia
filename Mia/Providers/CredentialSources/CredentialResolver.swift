import Foundation

/// A credential resolved from a local source. `account` is optional and is
/// populated when the source also yields an identity (e.g. the Zed user ID
/// stored in a keychain item's account field).
struct ResolvedCredential: Equatable, Sendable {
    let value: String
    let account: String?

    init(value: String, account: String? = nil) {
        self.value = value
        self.account = account
    }
}

/// Resolves a credential for a local-source provider.
///
/// A credential is typically an opaque session token, cookie header, or
/// bearer token that the provider then attaches to its HTTP requests.
/// Resolvers are `Sendable` and stateless so they can be called from the
/// concurrent `SyncEngine` task group.
protocol CredentialResolver: Sendable {
    /// Human-readable label for the credential source (used in UI and errors).
    var label: String { get }

    /// Returns the resolved credential, or `nil` if the source is unavailable.
    /// Throws typed `CredentialResolutionError` on failure.
    func resolve() async throws -> ResolvedCredential?
}

enum CredentialResolutionError: Error, Equatable, Sendable {
    case sourceUnavailable
    case fileNotFound(String)
    case fileUnreadable(String)
    case keyNotFound(String)
    case keychainAccessDenied(String)
    case cookieStoreUnavailable(Browser)
    case decoding(String)
    case other(String)
}
