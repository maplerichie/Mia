import Foundation
import Observation
import os.log
import SwiftData

/// Owns the SwiftData `ModelContext` and exposes typed CRUD over `Subscription`.
/// Acts as the single mutation entry point so the menu bar UI stays declarative.
@Observable
@MainActor
final class SubscriptionStore {
    /// Snapshots older than this are pruned on each sync cycle to keep the
    /// SwiftData store bounded.
    static let snapshotRetentionDays: Int = 90

    private static let logger = Logger(subsystem: "com.likkee.mia", category: "SubscriptionStore")

    private let modelContext: ModelContext

    private(set) var subscriptions: [Subscription] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        reload()
    }

    // MARK: CRUD

    func create(_ subscription: Subscription) {
        modelContext.insert(subscription)
        save()
        reload()
    }

    func update(_ subscription: Subscription, apply: (Subscription) -> Void) {
        apply(subscription)
        save()
        reload()
    }

    func delete(_ subscription: Subscription) {
        if let credential = subscription.credential {
            let keychain = KeychainStore(service: credential.keychainService)
            try? keychain.deleteSecret(account: credential.keychainAccount)
        }
        modelContext.delete(subscription)
        save()
        reload()
    }

    func appendUsageSnapshot(_ snapshot: UsageSnapshot, to subscription: Subscription) {
        snapshot.subscription = subscription
        modelContext.insert(snapshot)
        save()
    }

    /// Most recent `UsageSnapshot` for a given subscription, if any.
    func latestUsage(for subscription: Subscription) -> UsageSnapshot? {
        subscription.usageSnapshots.max(by: { $0.capturedAt < $1.capturedAt })
    }

    /// Returns the last `days` of snapshots for the given subscription,
    /// sorted from oldest to newest. Used by the sparkline.
    func recentSnapshots(for subscription: Subscription, days: Int = 7) -> [UsageSnapshot] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
        return subscription.usageSnapshots
            .filter { $0.capturedAt >= cutoff }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    /// Auto-roll any past `nextRenewalDate` forward by full billing cycles.
    /// Safe to call from sync and app-launch hooks.
    func advancePastRenewals(now: Date = .now) {
        var changed = false
        for sub in subscriptions where sub.advanceRenewalIfNeeded(now: now) {
            changed = true
        }
        if changed {
            save()
            reload()
        }
    }

    /// Prune `UsageSnapshot` rows older than `Self.snapshotRetentionDays`.
    /// Silent on errors — pruning is a hygiene task, never user-visible.
    func pruneOldSnapshots(now: Date = .now) {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -Self.snapshotRetentionDays, to: now) else {
            return
        }
        let descriptor = FetchDescriptor<UsageSnapshot>(
            predicate: #Predicate { $0.capturedAt < cutoff }
        )
        do {
            let stale = try modelContext.fetch(descriptor)
            guard !stale.isEmpty else { return }
            for snapshot in stale {
                modelContext.delete(snapshot)
            }
            save()
        } catch {
            // Non-fatal hygiene task.
        }
    }

    func reload() {
        let descriptor = FetchDescriptor<Subscription>(
            sortBy: [SortDescriptor(\.nextRenewalDate, order: .forward)]
        )
        do {
            subscriptions = sortByResetDate(try modelContext.fetch(descriptor))
        } catch {
            Self.logger.error("Failed to fetch subscriptions: \(error.localizedDescription)")
            subscriptions = []
        }
    }

    private func sortByResetDate(_ subscriptions: [Subscription]) -> [Subscription] {
        let now = Date()
        let calendar = Calendar.current

        return subscriptions.sorted { lhs, rhs in
            let lhsReset = lhs.nextQuotaResetDate(now: now).map { calendar.startOfDay(for: $0) }
            let rhsReset = rhs.nextQuotaResetDate(now: now).map { calendar.startOfDay(for: $0) }

            switch (lhsReset, rhsReset) {
            case let (lhsReset?, rhsReset?) where lhsReset != rhsReset:
                return lhsReset < rhsReset
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                break
            }

            if lhs.nextRenewalDate != rhs.nextRenewalDate {
                return lhs.nextRenewalDate < rhs.nextRenewalDate
            }

            let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    // MARK: Aggregates

    /// Total normalized monthly spend across all tracked subscriptions, in
    /// the auto-detected primary currency. Subscriptions in other currencies
    /// are excluded — see `monthlyTotalsByCurrency` for the safe multi-currency
    /// view.
    var monthlyTotal: Decimal {
        let target = primaryCurrency
        return subscriptions.reduce(Decimal.zero) { acc, sub in
            guard sub.currency == target else { return acc }
            return acc + (sub.cost / sub.effectiveMonthsPerCycleDecimal)
        }
    }

    var yearlyTotal: Decimal {
        monthlyTotal * 12
    }

    /// Normalized monthly spend bucketed by currency. Ensures we never silently
    /// produce a wrong total by summing across e.g. USD and EUR.
    var monthlyTotalsByCurrency: [(currency: String, total: Decimal)] {
        var totals: [String: Decimal] = [:]
        for sub in subscriptions {
            totals[sub.currency, default: .zero] += sub.cost / sub.effectiveMonthsPerCycleDecimal
        }
        return totals
            .map { (currency: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    /// `true` when subscriptions use more than one ISO-4217 currency code.
    var hasMixedCurrencies: Bool {
        Set(subscriptions.map(\.currency)).count > 1
    }

    /// Currency used for the aggregate totals. Honors the user's explicit
    /// override (Settings → Display); otherwise auto-detects the most common
    /// currency present. Mixed-currency portfolios are surfaced separately via
    /// `monthlyTotalsByCurrency` and `hasMixedCurrencies`.
    var primaryCurrency: String {
        let override = AppSettings.shared.primaryCurrencyOverride
        if !override.isEmpty { return override }
        let counts = subscriptions.reduce(into: [String: Int]()) { acc, sub in
            acc[sub.currency, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? "USD"
    }

    // MARK: Persistence

    private func save() {
        guard modelContext.hasChanges else { return }
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Failed to save SwiftData context: \(error.localizedDescription)")
        }
    }
}
