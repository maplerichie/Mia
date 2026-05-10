import Foundation

/// Calls OpenAI's organization usage endpoint
/// (`/v1/organization/usage/completions`) with an admin key (`sk-admin-…`)
/// to surface token usage for the current calendar month. Plan / billing
/// info is not exposed by a stable JSON API so `fetchPlan()` returns `nil`.
///
/// Docs: https://platform.openai.com/docs/api-reference/usage
struct OpenAIProvider: RegisterableProvider {
    static let key = "openai"
    static let displayName = "OpenAI"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            factory: { secret in OpenAIProvider(apiKey: secret ?? "") }
        )
    }

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.openai.com")!,
        client: HTTPClient = URLSessionHTTPClient(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = client
        self.now = now
    }

    func fetchPlan() async throws -> PlanInfo? { nil }

    func fetchUsage() async throws -> UsageInfo? {
        guard !apiKey.isEmpty else { throw ProviderError.missingCredential }

        let (start, end) = AnthropicProvider.currentMonthRange(reference: now())
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/v1/organization/usage/completions"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "start_time", value: String(Int(start.timeIntervalSince1970))),
            URLQueryItem(name: "end_time", value: String(Int(end.timeIntervalSince1970))),
            URLQueryItem(name: "bucket_width", value: "1d")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (data, response) = try await client.data(for: request)
        try AnthropicProvider.validate(response: response) // shared status mapping

        let payload: UsagePage
        do {
            payload = try JSONDecoder().decode(UsagePage.self, from: data)
        } catch {
            throw ProviderError.decoding(String(describing: error))
        }

        return UsageInfo(
            used: Double(payload.totalTokens),
            limit: nil,
            unit: "tokens",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }
}

// MARK: - Decoding

private struct UsagePage: Decodable {
    let data: [Bucket]

    struct Bucket: Decodable {
        let results: [Result]
    }

    struct Result: Decodable {
        let inputTokens: Int?
        let outputTokens: Int?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }

        var total: Int {
            (inputTokens ?? 0) + (outputTokens ?? 0)
        }
    }

    var totalTokens: Int {
        data.reduce(0) { acc, bucket in
            acc + bucket.results.reduce(0) { $0 + $1.total }
        }
    }
}
