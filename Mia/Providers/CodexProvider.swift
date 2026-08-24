import Foundation

/// Reads the local Codex OAuth credential from `~/.codex/auth.json` and calls
/// the ChatGPT backend usage endpoint for the session/weekly window.
///
/// CodexBar strategy: local file auth, no CLI required.
struct CodexProvider: RegisterableProvider {
    static let key = "codex"
    static let displayName = "Codex"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .localFile(LocalFileSource(
                path: "~/.codex/auth.json",
                keyPath: ["access_token"],
                environmentOverride: "CODEX_HOME"
            )),
            factory: { credential in
                CodexProvider(accessToken: credential?.value)
            }
        )
    }

    private let accessToken: String?
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        accessToken: String?,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://chatgpt.com"),
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

        var request = URLRequest(url: baseURL.appendingPathComponent("/backend-api/wham/usage"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
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
            unit: "requests",
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
