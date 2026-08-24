import Foundation

/// Reads a Devin web session from browser cookies or a manually-pasted
/// Bearer token and calls the Devin quota API.
///
/// CodexBar strategy: Chrome localStorage session or manual Bearer token, no CLI required.
struct DevinProvider: RegisterableProvider {
    static let key = "devin"
    static let displayName = "Devin"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .browserCookie(BrowserCookieSource(
                browser: .chrome,
                domains: ["app.devin.ai", "devin.ai"],
                cookieNames: ["auth1_session", "session"]
            )),
            factory: { credential in
                DevinProvider(cookieHeader: credential?.value)
            }
        )
    }

    private let cookieHeader: String?
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        cookieHeader: String?,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://app.devin.ai"),
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

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/billing/quota/usage"))
        request.httpMethod = "GET"
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            QuotaResponse.self,
            request: request,
            client: client
        )

        return UsageInfo(
            used: Double(payload.daily?.used ?? 0),
            limit: payload.daily?.limit.map(Double.init),
            unit: "requests",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    private struct QuotaResponse: Decodable {
        let daily: Bucket?
        let weekly: Bucket?

        struct Bucket: Decodable {
            let used: Int
            let limit: Int?
        }
    }
}
