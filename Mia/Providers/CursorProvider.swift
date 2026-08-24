import Foundation

/// Reads a Cursor web session from browser cookies or a manually-pasted Cookie
/// header and calls the cursor.com usage API.
///
/// CodexBar strategy: web session via cookies, no CLI required. Automatic
/// browser import is supported for Firefox; Chrome/Safari require manual
/// cookie headers because their cookies are encrypted.
struct CursorProvider: RegisterableProvider {
    static let key = "cursor"
    static let displayName = "Cursor"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .browserCookie(BrowserCookieSource(
                browser: .chrome,
                domains: ["cursor.com", "cursor.sh"],
                cookieNames: [
                    "WorkosCursorSessionToken",
                    "__Secure-next-auth.session-token",
                    "next-auth.session-token"
                ]
            )),
            factory: { credential in
                CursorProvider(cookieHeader: credential?.value)
            }
        )
    }

    private let cookieHeader: String?
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        cookieHeader: String?,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://cursor.com"),
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

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/usage-summary"))
        request.httpMethod = "GET"
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            UsageResponse.self,
            request: request,
            client: client
        )

        return UsageInfo(
            used: Double(payload.usage?.used ?? 0),
            limit: payload.usage?.limit.map(Double.init),
            unit: "requests",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    // MARK: - Decoding

    private struct UsageResponse: Decodable {
        let usage: Usage?

        struct Usage: Decodable {
            let used: Int
            let limit: Int?
        }
    }
}
