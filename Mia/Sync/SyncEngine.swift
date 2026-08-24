import Foundation
import Observation
import SwiftData

/// Per-subscription sync outcome surfaced to the UI as a row warning icon.
enum SyncStatus: Equatable, Sendable {
    case idle
    case syncing
    case success(at: Date)
    case failure(message: String)
}

/// Coordinates per-provider refresh. Runs on `@MainActor` so it can mutate
/// the SwiftData context and `SubscriptionStore`. Network work happens in
/// detached child tasks and is awaited concurrently via `TaskGroup`.
@Observable
@MainActor
final class SyncEngine {
    private let store: SubscriptionStore
    private let registry: ProviderRegistry
    private let keychainServicePrefix: String
    /// Per-provider timeout. Failures cancel only the offending task; other
    /// providers continue to completion.
    private let perProviderTimeout: Duration

    private(set) var statuses: [UUID: SyncStatus] = [:]
    private(set) var lastSyncedAt: Date?
    private(set) var isSyncing = false

    init(
        store: SubscriptionStore,
        registry: ProviderRegistry? = nil,
        keychainServicePrefix: String = "com.likkee",
        perProviderTimeout: Duration = .seconds(15)
    ) {
        self.store = store
        self.registry = registry ?? .shared
        self.keychainServicePrefix = keychainServicePrefix
        self.perProviderTimeout = perProviderTimeout
    }

    /// Refresh every subscription concurrently. Persists a `UsageSnapshot`
    /// for each provider that returns one. Also performs incidental hygiene:
    /// rolls past renewal dates forward and prunes stale snapshots.
    func syncAll() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer {
            isSyncing = false
            lastSyncedAt = .now
            store.pruneOldSnapshots()
            store.advancePastRenewals()
        }

        let work = store.subscriptions.map { (id: $0.id, providerKey: $0.providerKey) }
        for (id, _) in work {
            statuses[id] = .syncing
        }

        // Fan-out fetch; results come back as (id, Result<UsageInfo?, Error>).
        let results = await withTaskGroup(
            of: (UUID, Result<UsageInfo?, Error>).self
        ) { group -> [(UUID, Result<UsageInfo?, Error>)] in
            for (id, providerKey) in work {
                group.addTask { [weak self] in
                    guard let self else {
                        return (id, .failure(ProviderError.other("engine deallocated")))
                    }
                    let provider = await self.makeProvider(forSubscriptionID: id, providerKey: providerKey)
                    guard let provider else {
                        return (id, .failure(ProviderError.unsupported))
                    }
                    return await Self.runWithTimeout(self.perProviderTimeout, id: id) {
                        try await provider.fetchUsage()
                    }
                }
            }
            var collected: [(UUID, Result<UsageInfo?, Error>)] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        // Apply results on the main actor (SwiftData mutations).
        for (id, result) in results {
            apply(result: result, toSubscriptionID: id)
        }
    }

    /// Refresh a single subscription. Used by the row context menu.
    func syncOne(id: UUID) async {
        guard let subscription = store.subscriptions.first(where: { $0.id == id }) else { return }
        statuses[id] = .syncing
        let provider = await makeProvider(forSubscriptionID: id, providerKey: subscription.providerKey)
        guard let provider else {
            statuses[id] = .failure(message: "Provider unavailable")
            return
        }
        let result = await Self.runWithTimeout(perProviderTimeout, id: id) {
            try await provider.fetchUsage()
        }
        apply(result: result.1, toSubscriptionID: id)
        lastSyncedAt = .now
    }

    // MARK: - Internals

    private func makeProvider(forSubscriptionID id: UUID, providerKey: String) async -> (any SubscriptionProvider)? {
        guard let descriptor = registry.descriptor(forKey: providerKey) else {
            return nil
        }
        var credential: ResolvedCredential?
        if descriptor.requiresCredential {
            let resolver = CredentialResolverFactory.resolver(
                for: descriptor.credentialSource,
                providerKey: providerKey,
                subscriptionID: id
            )
            do {
                credential = try await resolver.resolve()
            } catch {
                return nil
            }
            guard credential != nil else { return nil }
        }
        return descriptor.makeProvider(credential: credential)
    }

    private func apply(result: Result<UsageInfo?, Error>, toSubscriptionID id: UUID) {
        guard let subscription = store.subscriptions.first(where: { $0.id == id }) else { return }
        switch result {
        case .success(let usage?):
            store.appendUsageSnapshot(
                UsageSnapshot(
                    capturedAt: usage.capturedAt,
                    used: usage.used,
                    limit: usage.limit,
                    unit: usage.unit,
                    rawJSON: usage.rawJSON
                ),
                to: subscription
            )
            statuses[id] = .success(at: .now)
        case .success(nil):
            // Provider doesn't expose usage; treat as a clean no-op.
            statuses[id] = .success(at: .now)
        case .failure(let error):
            statuses[id] = .failure(message: Self.message(for: error))
        }
    }

    /// Race the provider call against a `Task.sleep` of `timeout`. Whichever
    /// finishes first wins; the loser is cancelled.
    private static func runWithTimeout(
        _ timeout: Duration,
        id: UUID,
        operation: @Sendable @escaping () async throws -> UsageInfo?
    ) async -> (UUID, Result<UsageInfo?, Error>) {
        do {
            let value = try await withThrowingTaskGroup(of: UsageInfo?.self) { group in
                group.addTask { try await operation() }
                group.addTask {
                    try await Task.sleep(for: timeout)
                    throw ProviderError.timeout
                }
                let result = try await group.next()
                group.cancelAll()
                return result ?? nil
            }
            return (id, .success(value))
        } catch {
            return (id, .failure(error))
        }
    }

    private static func message(for error: Error) -> String {
        if let providerError = error as? ProviderError {
            return providerMessage(providerError)
        }
        if let credentialError = error as? CredentialResolutionError {
            return credentialMessage(credentialError)
        }
        return String(describing: error)
    }

    private static func providerMessage(_ error: ProviderError) -> String {
        switch error {
        case .missingCredential: return "Missing API key"
        case .invalidCredential: return "Invalid API key"
        case .network(let detail): return "Network: \(detail)"
        case .rateLimited: return "Rate limited"
        case .decoding(let detail): return "Decode: \(detail)"
        case .unsupported: return "Provider unavailable"
        case .timeout: return "Timed out"
        case .other(let detail): return detail
        }
    }

    private static func credentialMessage(_ error: CredentialResolutionError) -> String {
        switch error {
        case .sourceUnavailable: return "Credential source unavailable"
        case .fileNotFound(let path): return "Missing local file: \(path)"
        case .fileUnreadable(let path): return "Cannot read: \(path)"
        case .keyNotFound(let key): return "Missing key: \(key)"
        case .keychainAccessDenied(let detail): return "Keychain access denied: \(detail)"
        case .cookieStoreUnavailable(let browser): return "\(browser.displayName) cookie store unavailable"
        case .decoding(let detail): return "Decode: \(detail)"
        case .other(let detail): return detail
        }
    }
}
