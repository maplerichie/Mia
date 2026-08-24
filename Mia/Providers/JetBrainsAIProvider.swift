import Foundation

/// Reads a JetBrains AI web session from browser cookies or a manually-pasted
/// Cookie header. When `localFilePath` points to an existing JSON file, it is
/// read first; otherwise the cookie-based API is used. A future update can read JetBrains' local usage XML/state.
///
/// CodexBar strategy: browser cookies for account.jetbrains.com, no CLI required.
struct JetBrainsAIProvider: RegisterableProvider {
    static let key = "jetbrainsai"
    static let displayName = "JetBrains AI"

    static var defaultLocalFilePath: String {
        NSHomeDirectory().appending("/Library/Application Support/JetBrains/AI/usage.json")
    }

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .browserCookie(BrowserCookieSource(
                browser: .chrome,
                domains: ["account.jetbrains.com"],
                cookieNames: ["session", "jbsession"]
            )),
            factory: { credential in
                JetBrainsAIProvider(cookieHeader: credential?.value)
            }
        )
    }

    private let cookieHeader: String?
    private let localFilePath: String?
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        cookieHeader: String?,
        localFilePath: String? = nil,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://account.jetbrains.com"),
        client: HTTPClient = URLSessionHTTPClient(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.cookieHeader = cookieHeader
        self.localFilePath = localFilePath
        self.baseURL = baseURL
        self.client = client
        self.now = now
    }

    func fetchPlan() async throws -> PlanInfo? {
        nil
    }

    func fetchUsage() async throws -> UsageInfo? {
        if let localFilePath, FileManager.default.fileExists(atPath: localFilePath) {
            return try LocalUsageReader.readJSON(
                path: localFilePath,
                usedKeyPath: ["used"],
                limitKeyPath: ["limit"],
                unit: "tokens",
                capturedAt: now()
            )
        }

        guard let cookieHeader, !cookieHeader.isEmpty else {
            throw ProviderError.missingCredential
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/ai/usage"))
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
