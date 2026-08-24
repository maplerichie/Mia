import Foundation

/// Reads an OpenCode Go web session from browser cookies or a manually-pasted
/// Cookie header. A future update can read OpenCode Go's local SQLite state.
///
/// CodexBar strategy: browser cookies for opencode.go, no CLI required.
struct OpenCodeGoProvider: RegisterableProvider {
    static let key = "opencodego"
    static let displayName = "OpenCode Go"

    static var defaultLocalFilePath: String {
        NSHomeDirectory().appending("/.config/opencode-go/usage.json")
    }

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .browserCookie(BrowserCookieSource(
                browser: .chrome,
                domains: ["opencode.go"],
                cookieNames: ["session"]
            )),
            factory: { credential in
                OpenCodeGoProvider(cookieHeader: credential?.value)
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
        baseURL: URL = ProviderHTTP.hardcodedURL("https://opencode.go"),
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
