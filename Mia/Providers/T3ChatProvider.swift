import Foundation

/// Reads a T3 Chat web session from browser cookies or a manually-pasted
/// Cookie header and calls the T3 Chat customer-data endpoint.
///
/// CodexBar strategy: browser cookies, no CLI required.
struct T3ChatProvider: RegisterableProvider {
    static let key = "t3chat"
    static let displayName = "T3 Chat"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .browserCookie(BrowserCookieSource(
                browser: .chrome,
                domains: ["t3.chat"],
                cookieNames: ["session", "__session", "t3-session"]
            )),
            factory: { credential in
                T3ChatProvider(cookieHeader: credential?.value)
            }
        )
    }

    private let cookieHeader: String?
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        cookieHeader: String?,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://t3.chat"),
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

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/trpc/getCustomerData"))
        request.httpMethod = "GET"
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            CustomerDataResponse.self,
            request: request,
            client: client
        )

        return UsageInfo(
            used: Double(payload.base?.used ?? 0),
            limit: payload.base?.limit.map(Double.init),
            unit: "messages",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    private struct CustomerDataResponse: Decodable {
        let base: Bucket?

        struct Bucket: Decodable {
            let used: Int
            let limit: Int?
        }
    }
}
