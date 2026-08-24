import Foundation

/// Reads a Qoder web session from browser cookies or a manually-pasted
/// Cookie header and calls the Qoder account dashboard.
///
/// CodexBar strategy: Chrome session cookies, no CLI required.
struct QoderProvider: RegisterableProvider {
    static let key = "qoder"
    static let displayName = "Qoder"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .browserCookie(BrowserCookieSource(
                browser: .chrome,
                domains: ["qoder.com", "qoder.com.cn"],
                cookieNames: ["session", "qoder-session"]
            )),
            factory: { credential in
                QoderProvider(cookieHeader: credential?.value)
            }
        )
    }

    private let cookieHeader: String?
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        cookieHeader: String?,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://qoder.com"),
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

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/account/credits"))
        request.httpMethod = "GET"
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            CreditsResponse.self,
            request: request,
            client: client
        )

        return UsageInfo(
            used: Double(payload.used ?? 0),
            limit: payload.total.map(Double.init),
            unit: "credits",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    private struct CreditsResponse: Decodable {
        let used: Int?
        let total: Int?
    }
}
