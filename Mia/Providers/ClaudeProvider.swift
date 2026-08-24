import Foundation

/// Reads the local Claude OAuth credential from `~/.claude/.credentials.json`
/// and calls Anthropic's OAuth usage endpoint.
///
/// CodexBar strategy: local file auth, no CLI required. Falls back to the
/// `Claude Code-credentials` keychain item if the file is absent.
struct ClaudeProvider: RegisterableProvider {
    static let key = "claude"
    static let displayName = "Claude"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .localFile(LocalFileSource(
                path: "~/.claude/.credentials.json",
                keyPath: ["access_token"],
                environmentOverride: nil
            )),
            factory: { credential in
                ClaudeProvider(accessToken: credential?.value)
            }
        )
    }

    private let accessToken: String?
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        accessToken: String?,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://api.anthropic.com"),
        client: HTTPClient = URLSessionHTTPClient(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.accessToken = accessToken
        self.baseURL = baseURL
        self.client = client
        self.now = now
    }

    func fetchPlan() async throws -> PlanInfo? {
        nil
    }

    func fetchUsage() async throws -> UsageInfo? {
        guard let accessToken, !accessToken.isEmpty else {
            throw ProviderError.missingCredential
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/oauth/usage"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            UsageResponse.self,
            request: request,
            client: client
        )

        let primary = payload.rateLimit?.primaryWindow
        return UsageInfo(
            used: Double(primary?.used ?? 0),
            limit: primary?.limit.map(Double.init),
            unit: "messages",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    // MARK: - Decoding

    private struct UsageResponse: Decodable {
        let rateLimit: RateLimit?

        enum CodingKeys: String, CodingKey {
            case rateLimit = "rate_limit"
        }

        struct RateLimit: Decodable {
            let primaryWindow: Window?
            let secondaryWindow: Window?

            enum CodingKeys: String, CodingKey {
                case primaryWindow = "primary_window"
                case secondaryWindow = "secondary_window"
            }
        }

        struct Window: Decodable {
            let used: Int
            let limit: Int?
        }
    }
}
