import Foundation

/// Reads Zed's signed-in session from the macOS Keychain and calls the Zed
/// cloud API for plan and edit-prediction quota.
///
/// CodexBar strategy: Keychain item for `https://zed.dev`, account = user ID,
/// secret = access token. Authorization header is `{user_id} {access_token}`.
struct ZedProvider: RegisterableProvider {
    static let key = "zed"
    static let displayName = "Zed"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .keychainItem(KeychainItemSource(
                service: "https://zed.dev",
                account: nil,
                isGeneric: false
            )),
            factory: { credential in
                ZedProvider(
                    userID: credential?.account,
                    accessToken: credential?.value
                )
            }
        )
    }

    private let userID: String?
    private let accessToken: String?
    private let baseURL: URL
    private let client: HTTPClient
    private let now: @Sendable () -> Date

    init(
        userID: String?,
        accessToken: String?,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://cloud.zed.dev"),
        client: HTTPClient = URLSessionHTTPClient(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.userID = userID
        self.accessToken = accessToken
        self.baseURL = baseURL
        self.client = client
        self.now = now
    }

    func fetchPlan() async throws -> PlanInfo? {
        nil
    }

    func fetchUsage() async throws -> UsageInfo? {
        guard let userID, !userID.isEmpty,
              let accessToken, !accessToken.isEmpty else {
            throw ProviderError.missingCredential
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("/client/users/me"))
        request.httpMethod = "GET"
        request.setValue("\(userID) \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (payload, data) = try await ProviderHTTP.fetchJSON(
            UserResponse.self,
            request: request,
            client: client
        )

        let editPredictions = payload.plan?.usage?.editPredictions
        return UsageInfo(
            used: Double(editPredictions?.used ?? 0),
            limit: editPredictions?.limit.map(Double.init),
            unit: "edit predictions",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    // MARK: - Decoding

    private struct UserResponse: Decodable {
        let plan: Plan?

        struct Plan: Decodable {
            let planV3: String?
            let usage: Usage?
            let hasOverdueInvoices: Bool?

            enum CodingKeys: String, CodingKey {
                case planV3 = "plan_v3"
                case usage
                case hasOverdueInvoices = "has_overdue_invoices"
            }
        }

        struct Usage: Decodable {
            let editPredictions: Quota?

            enum CodingKeys: String, CodingKey {
                case editPredictions = "edit_predictions"
            }
        }

        struct Quota: Decodable {
            let used: Int
            let limit: Int?
        }
    }
}
