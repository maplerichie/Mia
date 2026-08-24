import Foundation

/// Calls Doubao's token/usage API with a user-provided API key.
struct DoubaoProvider: RegisterableProvider {
    static let key = "doubao"
    static let displayName = "Doubao"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .manual,
            factory: { credential in
                DoubaoProvider(apiKey: credential?.value ?? "")
            }
        )
    }

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        apiKey: String,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://ark.cn-beijing.volces.com"),
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

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v3/usage"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            UsageResponse.self,
            request: request,
            client: client
        )

        return UsageInfo(
            used: Double(payload.usedTokens ?? 0),
            limit: payload.totalTokens.map(Double.init),
            unit: "tokens",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    private struct UsageResponse: Decodable {
        let usedTokens: Int?
        let totalTokens: Int?

        enum CodingKeys: String, CodingKey {
            case usedTokens = "used_tokens"
            case totalTokens = "total_tokens"
        }
    }
}
