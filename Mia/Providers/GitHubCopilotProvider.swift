import Foundation

/// Reads GitHub Copilot usage via an OAuth access token. The companion
/// `GitHubOAuthDeviceFlow` helper can obtain the token through GitHub's device
/// flow; once acquired, the token is stored in Mia's Keychain and passed here.
///
/// CodexBar strategy: OAuth device flow (via `GitHubOAuthDeviceFlow`) or paste
/// an existing `gho_` access token.
///
/// IMPORTANT: Replace `githubOAuthClientID` with a real GitHub OAuth app
/// client ID registered at https://github.com/settings/developers
///
/// IMPORTANT: Replace `githubOAuthClientID` with a real GitHub OAuth app
/// client ID registered at https://github.com/settings/developers
struct GitHubCopilotProvider: RegisterableProvider {
    static let key = "githubcopilot"
    static let displayName = "GitHub Copilot"

    let requiresCredential = true

    /// OAuth client identifier for the GitHub device flow.
    /// Register a new OAuth app at https://github.com/settings/developers and
    /// replace this placeholder before shipping.
    static let githubOAuthClientID = "YOUR_GITHUB_OAUTH_CLIENT_ID"

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .oauthDeviceFlow(OAuthDeviceFlowSource(
                clientID: githubOAuthClientID
            )),
            factory: { credential in
                GitHubCopilotProvider(accessToken: credential?.value)
            }
        )
    }

    private let accessToken: String?
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        accessToken: String?,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://api.github.com"),
        client: HTTPClient = URLSessionHTTPClient(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.accessToken = accessToken
        self.baseURL = baseURL
        self.client = client
        self.now = now
    }

    func fetchPlan() async throws -> PlanInfo? { nil }

    func fetchUsage() async throws -> UsageInfo? {
        guard let accessToken, !accessToken.isEmpty else {
            throw ProviderError.missingCredential
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("/copilot/usage"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            UsageResponse.self,
            request: request,
            client: client
        )

        return UsageInfo(
            used: Double(payload.usedSuggestions ?? 0),
            limit: payload.totalSuggestions.map(Double.init),
            unit: "suggestions",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    private struct UsageResponse: Decodable {
        let usedSuggestions: Int?
        let totalSuggestions: Int?

        enum CodingKeys: String, CodingKey {
            case usedSuggestions = "used_suggestions"
            case totalSuggestions = "total_suggestions"
        }
    }
}
