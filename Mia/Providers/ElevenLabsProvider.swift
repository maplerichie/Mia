import Foundation

/// Calls ElevenLabs' subscription API with a user-provided API key.
///
/// CodexBar strategy: API key from config or `ELEVENLABS_API_KEY` / `XI_API_KEY` env var.
struct ElevenLabsProvider: RegisterableProvider {
    static let key = "elevenlabs"
    static let displayName = "ElevenLabs"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .manual,
            factory: { credential in
                ElevenLabsProvider(apiKey: credential?.value ?? "")
            }
        )
    }

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        apiKey: String,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://api.elevenlabs.io"),
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

        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/user/subscription"))
        request.httpMethod = "GET"
        request.setValue("\(apiKey)", forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            SubscriptionResponse.self,
            request: request,
            client: client
        )

        return UsageInfo(
            used: Double(payload.characterUsage ?? 0),
            limit: payload.characterLimit.map(Double.init),
            unit: "characters",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    // MARK: - Decoding

    private struct SubscriptionResponse: Decodable {
        let characterUsage: Int?
        let characterLimit: Int?

        enum CodingKeys: String, CodingKey {
            case characterUsage = "character_usage"
            case characterLimit = "character_limit"
        }
    }
}
