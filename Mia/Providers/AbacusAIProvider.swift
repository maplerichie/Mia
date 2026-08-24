import Foundation

/// Reads an Abacus AI web session from browser cookies or a manually-pasted
/// Cookie header and calls the Abacus AI compute-points API.
///
/// CodexBar strategy: browser cookies for abacus.ai, no CLI required.
struct AbacusAIProvider: RegisterableProvider {
    static let key = "abacusai"
    static let displayName = "Abacus AI"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .browserCookie(BrowserCookieSource(
                browser: .chrome,
                domains: ["abacus.ai", "apps.abacus.ai"],
                cookieNames: ["session", "abacus-session"]
            )),
            factory: { credential in
                AbacusAIProvider(cookieHeader: credential?.value)
            }
        )
    }

    private let cookieHeader: String?
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        cookieHeader: String?,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://abacus.ai"),
        client: HTTPClient = URLSessionHTTPClient(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.cookieHeader = cookieHeader
        self.baseURL = baseURL
        self.client = client
        self.now = now
    }

    func fetchPlan() async throws -> PlanInfo? {
        nil
    }

    func fetchUsage() async throws -> UsageInfo? {
        guard let cookieHeader, !cookieHeader.isEmpty else {
            throw ProviderError.missingCredential
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/billing/compute-points"))
        request.httpMethod = "GET"
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            PointsResponse.self,
            request: request,
            client: client
        )

        return UsageInfo(
            used: Double(payload.used ?? 0),
            limit: payload.total.map(Double.init),
            unit: "points",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    private struct PointsResponse: Decodable {
        let used: Int?
        let total: Int?
    }
}
