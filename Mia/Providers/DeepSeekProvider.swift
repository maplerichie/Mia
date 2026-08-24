import Foundation

/// Calls DeepSeek's balance API with a user-provided API key.
///
/// CodexBar strategy: API key from config or `DEEPSEEK_API_KEY` env var.
struct DeepSeekProvider: RegisterableProvider {
    static let key = "deepseek"
    static let displayName = "DeepSeek"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .manual,
            factory: { credential in
                DeepSeekProvider(apiKey: credential?.value ?? "")
            }
        )
    }

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        apiKey: String,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://api.deepseek.com"),
        client: HTTPClient = URLSessionHTTPClient(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = client
        self.now = now
    }

    func fetchPlan() async throws -> PlanInfo? {
        nil
    }

    func fetchUsage() async throws -> UsageInfo? {
        guard !apiKey.isEmpty else { throw ProviderError.missingCredential }

        var request = URLRequest(url: baseURL.appendingPathComponent("/user/balance"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            BalanceResponse.self,
            request: request,
            client: client
        )

        let usd = payload.balanceInfos?.first { $0.currency == "USD" }
            ?? payload.balanceInfos?.first
        let total = Decimal(string: usd?.totalBalance ?? "0") ?? Decimal.zero
        let granted = Decimal(string: usd?.grantedBalance ?? "0") ?? Decimal.zero
        let used = (total - granted).doubleValue
        let limit = total.doubleValue

        return UsageInfo(
            used: max(used, 0),
            limit: limit > 0 ? limit : nil,
            unit: "USD",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    // MARK: - Decoding

    private struct BalanceResponse: Decodable {
        let balanceInfos: [BalanceInfo]?

        enum CodingKeys: String, CodingKey {
            case balanceInfos = "balance_infos"
        }

        struct BalanceInfo: Decodable {
            let currency: String
            let totalBalance: String
            let grantedBalance: String

            enum CodingKeys: String, CodingKey {
                case currency
                case totalBalance = "total_balance"
                case grantedBalance = "granted_balance"
            }
        }
    }
}

private extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
