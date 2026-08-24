import Foundation

/// Reads an Alibaba Token Plan web session from browser cookies or a manually-pasted
/// Cookie header and calls the Lingma/Alibaba Cloud token-plan API.
///
/// CodexBar strategy: browser cookies or a Lingma API key pasted as the credential.
struct AlibabaTokenPlanProvider: RegisterableProvider {
    static let key = "alibabatoken"
    static let displayName = "Alibaba Token Plan"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .browserCookie(BrowserCookieSource(
                browser: .chrome,
                domains: ["developer.aliyun.com", "tingwu.aliyuncs.com"],
                cookieNames: ["session", "aliyun_session"]
            )),
            factory: { credential in
                AlibabaTokenPlanProvider(credential: credential?.value)
            }
        )
    }

    private let credential: String?
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        credential: String?,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://developer.aliyun.com"),
        client: HTTPClient = URLSessionHTTPClient(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.credential = credential
        self.baseURL = baseURL
        self.client = client
        self.now = now
    }

    func fetchPlan() async throws -> PlanInfo? {
        nil
    }

    func fetchUsage() async throws -> UsageInfo? {
        guard let credential, !credential.isEmpty else {
            throw ProviderError.missingCredential
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/lingma/token-usage"))
        request.httpMethod = "GET"
        request.setValue(credential, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            UsageResponse.self,
            request: request,
            client: client
        )

        return UsageInfo(
            used: Double(payload.used ?? 0),
            limit: payload.limit.map(Double.init),
            unit: "tokens",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    private struct UsageResponse: Decodable {
        let used: Int?
        let limit: Int?
    }
}
