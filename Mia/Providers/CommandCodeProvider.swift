import Foundation

/// Reads a Command Code web session from browser cookies or a manually-pasted
/// Cookie header and calls the Command Code billing API.
///
/// CodexBar strategy: browser session cookies, no CLI required.
struct CommandCodeProvider: RegisterableProvider {
    static let key = "commandcode"
    static let displayName = "Command Code"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .browserCookie(BrowserCookieSource(
                browser: .chrome,
                domains: ["commandcode.ai", "www.commandcode.ai", "api.commandcode.ai"],
                cookieNames: ["session", "commandcode.session"]
            )),
            factory: { credential in
                CommandCodeProvider(cookieHeader: credential?.value)
            }
        )
    }

    private let cookieHeader: String?
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        cookieHeader: String?,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://api.commandcode.ai"),
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

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/billing/credits"))
        request.httpMethod = "GET"
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            CreditsResponse.self,
            request: request,
            client: client
        )

        return UsageInfo(
            used: payload.used ?? 0,
            limit: payload.total,
            unit: "USD",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    private struct CreditsResponse: Decodable {
        let used: Double?
        let total: Double?
    }
}
