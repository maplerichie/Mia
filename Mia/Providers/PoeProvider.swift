import Foundation

/// Calls Poe's usage API with a user-provided API key.
///
/// CodexBar strategy: API key from config or `POE_API_KEY` env var.
struct PoeProvider: RegisterableProvider {
    static let key = "poe"
    static let displayName = "Poe"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .manual,
            factory: { credential in
                PoeProvider(apiKey: credential?.value ?? "")
            }
        )
    }

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        apiKey: String,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://api.poe.com"),
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

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/balance"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            BalanceResponse.self,
            request: request,
            client: client
        )

        return UsageInfo(
            used: Double(payload.usedPoints ?? 0),
            limit: payload.totalPoints.map(Double.init),
            unit: "points",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    private struct BalanceResponse: Decodable {
        let usedPoints: Int?
        let totalPoints: Int?

        enum CodingKeys: String, CodingKey {
            case usedPoints = "used_points"
            case totalPoints = "total_points"
        }
    }
}
