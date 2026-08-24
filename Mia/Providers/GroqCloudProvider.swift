import Foundation

/// Calls GroqCloud's Prometheus metrics endpoint with an API key.
///
/// CodexBar strategy: API key from config or `GROQ_API_KEY` env var.
struct GroqCloudProvider: RegisterableProvider {
    static let key = "groqcloud"
    static let displayName = "GroqCloud"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .manual,
            factory: { credential in
                GroqCloudProvider(apiKey: credential?.value ?? "")
            }
        )
    }

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        apiKey: String,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://api.groq.com"),
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

        var request = URLRequest(url: baseURL.appendingPathComponent("/openai/v1/usage"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            UsageResponse.self,
            request: request,
            client: client
        )

        return UsageInfo(
            used: Double(payload.requests ?? 0),
            limit: payload.requestsLimit.map(Double.init),
            unit: "requests",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    // MARK: - Decoding

    private struct UsageResponse: Decodable {
        let requests: Int?
        let requestsLimit: Int?

        enum CodingKeys: String, CodingKey {
            case requests
            case requestsLimit = "requests_limit"
        }
    }
}
