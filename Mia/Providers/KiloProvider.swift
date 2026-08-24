import Foundation

/// Reads a Kilo web session from browser cookies or a manually-pasted
/// Cookie header. When `localFilePath` points to an existing JSON file, it is
/// read first; otherwise the cookie-based API is used. A future update can read Kilo's local state file.
///
/// CodexBar strategy: browser cookies for kilo.ai, no CLI required.
struct KiloProvider: RegisterableProvider {
    static let key = "kilo"
    static let displayName = "Kilo"

    static var defaultLocalFilePath: String {
        NSHomeDirectory().appending("/.config/kilo/usage.json")
    }

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .browserCookie(BrowserCookieSource(
                browser: .chrome,
                domains: ["kilo.ai"],
                cookieNames: ["session"]
            )),
            factory: { credential in
                KiloProvider(cookieHeader: credential?.value)
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
        baseURL: URL = ProviderHTTP.hardcodedURL("https://kilo.ai"),
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
                unit: "credits",
                capturedAt: now()
            )
        }

        guard let cookieHeader, !cookieHeader.isEmpty else {
            throw ProviderError.missingCredential
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/usage"))
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
            unit: "credits",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    private struct UsageResponse: Decodable {
        let used: Int?
        let limit: Int?
    }
}
