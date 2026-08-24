import Foundation

/// Calls Crof's usage API with a user-provided API key.
///
/// CodexBar strategy: API key from config or `CROF_API_KEY` / `CROFAI_API_KEY` env var.
struct CrofProvider: RegisterableProvider {
    static let key = "crof"
    static let displayName = "Crof"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .manual,
            factory: { credential in
                CrofProvider(apiKey: credential?.value ?? "")
            }
        )
    }

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        apiKey: String,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://crof.ai"),
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

        var request = URLRequest(url: baseURL.appendingPathComponent("/usage_api/"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            UsageResponse.self,
            request: request,
            client: client
        )

        return UsageInfo(
            used: Double(payload.requestsPlan.used),
            limit: Double(payload.requestsPlan.total),
            unit: "requests",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    private struct UsageResponse: Decodable {
        let credits: Double
        let requestsPlan: PlanWindow
        let usableRequests: Int

        enum CodingKeys: String, CodingKey {
            case credits
            case requestsPlan = "requests_plan"
            case usableRequests = "usable_requests"
        }

        struct PlanWindow: Decodable {
            let used: Int
            let total: Int
        }
    }
}
