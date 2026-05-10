import Foundation

/// Calls Anthropic's Admin "Usage Report" endpoint to surface message-token
/// usage for the current calendar month. Plan / billing info is not exposed
/// by a stable public endpoint, so `fetchPlan()` returns `nil` and the user
/// enters cost manually.
///
/// Docs: https://docs.anthropic.com/en/api/admin-api/usage-cost/get-messages-usage-report
struct AnthropicProvider: RegisterableProvider {
    static let key = "anthropic"
    static let displayName = "Anthropic"
    static let apiVersion = "2023-06-01"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            factory: { secret in AnthropicProvider(apiKey: secret ?? "") }
        )
    }

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.anthropic.com")!,
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
            url: baseURL.appendingPathComponent("/v1/organizations/usage_report/messages"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "starting_at", value: ISO8601DateFormatter.utc.string(from: start)),
            URLQueryItem(name: "ending_at", value: ISO8601DateFormatter.utc.string(from: end))
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(AnthropicProvider.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (data, response) = try await client.data(for: request)
        try AnthropicProvider.validate(response: response)

        let payload: UsageReport
        do {
            payload = try JSONDecoder().decode(UsageReport.self, from: data)
        } catch {
            throw ProviderError.decoding(String(describing: error))
        }

        let total = payload.totalTokens
        return UsageInfo(
            used: Double(total),
            limit: nil,
            unit: "tokens",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    // MARK: Helpers

    static func currentMonthRange(reference: Date, calendar: Calendar = .iso8601UTC) -> (start: Date, end: Date) {
        let comps = calendar.dateComponents([.year, .month], from: reference)
        let start = calendar.date(from: comps) ?? reference
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? reference
        return (start, end)
    }

    static func validate(response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299: return
        case 401, 403: throw ProviderError.invalidCredential
        case 429: throw ProviderError.rateLimited
        default:
            throw ProviderError.network("HTTP \(response.statusCode)")
        }
    }
}

// MARK: - Decoding

private struct UsageReport: Decodable {
    let data: [Bucket]

    struct Bucket: Decodable {
        let results: [Result]
    }

    struct Result: Decodable {
        let uncachedInputTokens: Int?
        let cacheReadInputTokens: Int?
        let cacheCreationInputTokens: Int?
        let outputTokens: Int?

        enum CodingKeys: String, CodingKey {
            case uncachedInputTokens = "uncached_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case outputTokens = "output_tokens"
        }

        var total: Int {
            (uncachedInputTokens ?? 0)
                + (cacheReadInputTokens ?? 0)
                + (cacheCreationInputTokens ?? 0)
                + (outputTokens ?? 0)
        }
    }

    var totalTokens: Int {
        data.reduce(0) { acc, bucket in
            acc + bucket.results.reduce(0) { $0 + $1.total }
        }
    }
}

// MARK: - Calendar helper

extension Calendar {
    static let iso8601UTC: Calendar = {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return cal
    }()
}

extension ISO8601DateFormatter {
    static let utc: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return f
    }()
}
