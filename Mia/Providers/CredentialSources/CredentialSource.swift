import Foundation

/// Describes where a provider's credential is expected to come from.
///
/// `manual` is the existing Mia behaviour: the user pastes a secret and it is
/// stored in the Keychain under `com.likkee.<providerKey>`.
///
/// Local-source providers copy the CodexBar strategy: they read an existing
/// credential/session from the Mac (browser cookies, app config files, or
/// another app's keychain item) so the user never has to paste an API key.
///
/// `oauthDeviceFlow` performs an interactive OAuth device flow at setup time,
/// stores the resulting access token in Mia's Keychain, and resolves it like a
/// manual credential at sync time.
enum CredentialSource: Equatable, Sendable {
    /// User-supplied secret, stored in Mia's Keychain namespace.
    case manual
    /// Read a cookie from a browser's cookie store.
    case browserCookie(BrowserCookieSource)
    /// Read a value from a local file (JSON/plist/txt).
    case localFile(LocalFileSource)
    /// Read a specific item from the macOS Keychain.
    case keychainItem(KeychainItemSource)
    /// Interactively obtain an access token via OAuth device flow.
    case oauthDeviceFlow(OAuthDeviceFlowSource)

    var requiresCredential: Bool {
        true
    }

    var displayName: String {
        switch self {
        case .manual: "API key"
        case .browserCookie: "Browser cookie"
        case .localFile: "Local file"
        case .keychainItem: "Keychain item"
        case .oauthDeviceFlow: "OAuth sign-in"
        }
    }
}

/// Configuration for an OAuth device flow source.
struct OAuthDeviceFlowSource: Equatable, Sendable {
    /// OAuth client identifier. Not secret, but must be unique per app.
    let clientID: String
    /// OAuth authorization server base URL (e.g. `https://github.com`).
    let baseURL: URL
    /// Space-delimited scopes requested from the authorization server.
    let scope: String
    /// Human-readable name of the authorization server, shown in the UI.
    let providerName: String

    init(
        clientID: String,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://github.com"),
        scope: String = "read:user,copilot",
        providerName: String = "GitHub"
    ) {
        self.clientID = clientID
        self.baseURL = baseURL
        self.scope = scope
        self.providerName = providerName
    }
}

struct BrowserCookieSource: Equatable, Sendable {
    let browser: Browser
    let domains: [String]
    let cookieNames: [String]

    /// The provider is considered available if any one of these cookies exists.
    var requiredNames: [String] {
        cookieNames
    }
}

struct LocalFileSource: Equatable, Sendable {
    /// Path, may start with `~`.
    let path: String
    /// Optional JSON key path, e.g. `["access_token"]`.
    let keyPath: [String]
    /// Optional env-var override, e.g. `CODEX_HOME`.
    let environmentOverride: String?
}

struct KeychainItemSource: Equatable, Sendable {
    /// Service identifier (e.g. `https://zed.dev`).
    let service: String
    /// Account identifier (e.g. the user ID, or a wildcard marker).
    let account: String?
    /// `true` for generic password items, `false` for internet password items.
    let isGeneric: Bool
}

enum Browser: String, CaseIterable, Identifiable, Sendable {
    case chrome
    case safari
    case firefox
    case brave
    case edge
    case arc

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .chrome: "Chrome"
        case .safari: "Safari"
        case .firefox: "Firefox"
        case .brave: "Brave"
        case .edge: "Edge"
        case .arc: "Arc"
        }
    }
}
