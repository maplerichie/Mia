import Foundation

/// Calls OpenRouter's credits API with a user-provided API key.
///
/// CodexBar strategy: API token from config or `OPENROUTER_API_KEY` env var.
struct OpenRouterProvider: RegisterableProvider {
    static let key = "openrouter"
    static let displayName = "OpenRouter"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .manual,
            factory: { credential in
                OpenRouterProvider(apiKey: credential?.value ?? "")
            }
        )
    }

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        apiKey: String,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://openrouter.ai/api"),
        client: HTTPClient = URLSessionHTTPClient(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = client
        self.now = now
    }

    func fetchPlan() async throws -> PlanInfo? {
        nil
    }

    func fetchUsage() async throws -> UsageInfo? {
        guard !apiKey.isEmpty else { throw ProviderError.missingCredential }

        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/credits"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            CreditsResponse.self,
            request: request,
            client: client
        )

        return UsageInfo(
            used: payload.data?.totalUsage ?? 0,
            limit: payload.data?.totalCredits,
            unit: "credits",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    // MARK: - Decoding

    private struct CreditsResponse: Decodable {
        let data: CreditsData?

        struct CreditsData: Decodable {
            let totalCredits: Double?
            let totalUsage: Double

            enum CodingKeys: String, CodingKey {
                case totalCredits = "total_credits"
                case totalUsage = "total_usage"
            }
        }
    }
}
