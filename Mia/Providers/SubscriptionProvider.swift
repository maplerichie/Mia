import Foundation

/// Plan-level metadata returned by a provider.
struct PlanInfo: Equatable, Sendable {
    var name: String
    var cost: Decimal?
    var currency: String?
    var billingCycle: BillingCycle?
    var nextRenewalDate: Date?
}

/// Point-in-time usage reading returned by a provider.
struct UsageInfo: Equatable, Sendable {
    var used: Double
    var limit: Double?
    var unit: String
    var capturedAt: Date
    var rawJSON: String?
}

/// Typed errors surfaced from provider implementations. UI maps these onto
/// row-level warning icons; never crash on a provider failure.
enum ProviderError: Error, Equatable, Sendable {
    case missingCredential
    case invalidCredential
    case network(String)
    case rateLimited
    case decoding(String)
    case unsupported
    case timeout
    case other(String)
}

/// All concrete providers (Anthropic, OpenAI, Spotify, Manual, …) conform to
/// this protocol and are registered in `ProviderRegistry`.
protocol SubscriptionProvider: Sendable {
    /// Stable lowercase key persisted on `Subscription.providerKey`.
    static var key: String { get }
    /// Human-readable name for the "Add Subscription" picker.
    static var displayName: String { get }
    /// Whether the provider needs a Keychain-stored secret to function.
    var requiresCredential: Bool { get }

    /// Fetch plan / billing info. Return `nil` if the provider has no plan API
    /// (e.g. `ManualProvider`). Throw `ProviderError` on failure.
    func fetchPlan() async throws -> PlanInfo?

    /// Fetch a usage snapshot. Return `nil` if the provider has no usage API.
    /// Throw `ProviderError` on failure.
    func fetchUsage() async throws -> UsageInfo?
}

/// Conforming providers self-describe how to be built (with or without a
/// Keychain secret). The `ProviderRegistry` auto-registers every type listed
/// in its built-in array via this descriptor.
///
/// Community providers should conform to `RegisterableProvider`, expose a
/// `static var descriptor`, and append themselves to
/// `ProviderRegistry.builtIns`. See `docs/ADDING_A_PROVIDER.md`.
protocol RegisterableProvider: SubscriptionProvider {
    static var descriptor: ProviderDescriptor { get }
}
