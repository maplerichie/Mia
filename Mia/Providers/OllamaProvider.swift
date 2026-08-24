import Foundation

/// Reads an Ollama web session from browser cookies or a manually-pasted
/// Cookie header, with an API-key fallback for Ollama Cloud access.
///
/// CodexBar strategy: web session via cookies, plus API key for Cloud access.
struct OllamaProvider: RegisterableProvider {
    static let key = "ollama"
    static let displayName = "Ollama"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .browserCookie(BrowserCookieSource(
                browser: .chrome,
                domains: ["ollama.com"],
                cookieNames: ["session", "ollama-session"]
            )),
            factory: { credential in
                OllamaProvider(cookieHeader: credential?.value)
            }
        )
    }

    private let cookieHeader: String?
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        cookieHeader: String?,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://ollama.com"),
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

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/settings/usage"))
        request.httpMethod = "GET"
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            UsageResponse.self,
            request: request,
            client: client
        )

        return UsageInfo(
            used: Double(payload.used ?? 0),
            limit: payload.limit.map(Double.init),
            unit: "requests",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    private struct UsageResponse: Decodable {
        let used: Int?
        let limit: Int?
    }
}
