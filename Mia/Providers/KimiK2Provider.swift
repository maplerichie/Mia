import Foundation

/// Calls Kimi K2's legacy credit API with a user-provided API key.
///
/// CodexBar strategy: API key from config or `KIMI_K2_API_KEY` / `KIMI_API_KEY` env var.
struct KimiK2Provider: RegisterableProvider {
    static let key = "kimik2"
    static let displayName = "Kimi K2"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .manual,
            factory: { credential in
                KimiK2Provider(apiKey: credential?.value ?? "")
            }
        )
    }

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        apiKey: String,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://kimi-k2.ai"),
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

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/users/me/balance"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            BalanceResponse.self,
            request: request,
            client: client
        )

        return UsageInfo(
            used: Double(payload.consumed ?? 0),
            limit: payload.remaining.map { Double($0 + (payload.consumed ?? 0)) },
            unit: "credits",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    private struct BalanceResponse: Decodable {
        let consumed: Int?
        let remaining: Int?
    }
}
