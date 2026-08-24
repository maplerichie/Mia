import Foundation

/// Reads a Manus web session from browser cookies or a manually-pasted
/// Cookie header and calls the Manus credits API.
///
/// CodexBar strategy: browser `session_id` cookie, no CLI required.
struct ManusProvider: RegisterableProvider {
    static let key = "manus"
    static let displayName = "Manus"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .browserCookie(BrowserCookieSource(
                browser: .chrome,
                domains: ["manus.im", "api.manus.im"],
                cookieNames: ["session_id"]
            )),
            factory: { credential in
                ManusProvider(cookieHeader: credential?.value)
            }
        )
    }

    private let cookieHeader: String?
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        cookieHeader: String?,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://api.manus.im"),
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

        var request = URLRequest(url: baseURL.appendingPathComponent("/user.v1.UserService/GetAvailableCredits"))
        request.httpMethod = "POST"
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.httpBody = Data("{}".utf8)

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            CreditsResponse.self,
            request: request,
            client: client
        )

        return UsageInfo(
            used: Double(payload.used ?? 0),
            limit: payload.available.map(Double.init),
            unit: "credits",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    private struct CreditsResponse: Decodable {
        let used: Int?
        let available: Int?
    }
}
