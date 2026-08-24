import Foundation

/// Catch-all provider for services without an API. The user enters cost,
/// cycle, renewal date, and (optionally) usage by hand. `fetchPlan` and
/// `fetchUsage` intentionally return `nil` — the data already lives on the
/// `Subscription` row itself.
struct ManualProvider: RegisterableProvider {
    static let key = "manual"
    static let displayName = "Manual"

    let requiresCredential = false

    func fetchPlan() async throws -> PlanInfo? {
        nil
    }

    func fetchUsage() async throws -> UsageInfo? {
        nil
    }

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: false,
            factory: { _ in ManualProvider() }
        )
    }
}
