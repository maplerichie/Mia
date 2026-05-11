import Foundation
import Observation
import SwiftData

/// Owns the SwiftData `ModelContext` and exposes typed CRUD over `Subscription`.
/// Acts as the single mutation entry point so the menu bar UI stays declarative.
@Observable
@MainActor
final class SubscriptionStore {
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

    func reload() {
        let descriptor = FetchDescriptor<Subscription>(
            sortBy: [SortDescriptor(\.nextRenewalDate, order: .forward)]
        )
        do {
            subscriptions = sortByResetDate(try modelContext.fetch(descriptor))
        } catch {
            assertionFailure("Failed to fetch subscriptions: \(error)")
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

    /// Total normalized monthly spend across all tracked subscriptions.
    /// Yearly subscriptions are divided by 12; custom cycles count once.
    var monthlyTotal: Decimal {
        subscriptions.reduce(Decimal.zero) { acc, sub in
            acc + (sub.cost / sub.billingCycle.monthsPerCycle)
        }
    }

    var yearlyTotal: Decimal {
        monthlyTotal * 12
    }

    /// Currency used for the aggregate totals. v1 picks the most common
    /// currency present; mixed-currency portfolios are an explicit non-goal.
    var primaryCurrency: String {
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
            assertionFailure("Failed to save SwiftData context: \(error)")
        }
    }
}
