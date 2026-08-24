import Foundation
@testable import Mia
import SwiftData
import XCTest

@MainActor
final class SubscriptionStoreTests: XCTestCase {
    private func makeStore() throws -> SubscriptionStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Subscription.self, UsageSnapshot.self, ProviderCredential.self,
            configurations: config
        )
        return SubscriptionStore(modelContext: ModelContext(container))
    }

    func testCreateAndFetch() throws {
        let store = try makeStore()
        XCTAssertTrue(store.subscriptions.isEmpty)

        try store.create(Subscription(
            name: "Spotify",
            cost: XCTUnwrap(Decimal(string: "9.99")),
            nextRenewalDate: .now
        ))

        XCTAssertEqual(store.subscriptions.count, 1)
        XCTAssertEqual(store.subscriptions.first?.name, "Spotify")
    }

    func testMonthlyTotalNormalizesYearly() throws {
        let store = try makeStore()
        store.create(Subscription(
            name: "Yearly Tool",
            cost: 120,
            billingCycle: .yearly,
            nextRenewalDate: .now
        ))
        store.create(Subscription(
            name: "Monthly Tool",
            cost: 5,
            billingCycle: .monthly,
            nextRenewalDate: .now
        ))

        // 120/12 + 5 = 15
        XCTAssertEqual(store.monthlyTotal, Decimal(15))
    }

    func testDeleteRemoves() throws {
        let store = try makeStore()
        let sub = Subscription(name: "Temp", cost: 1, nextRenewalDate: .now)
        store.create(sub)
        XCTAssertEqual(store.subscriptions.count, 1)

        store.delete(sub)
        XCTAssertTrue(store.subscriptions.isEmpty)
    }

    func testSubscriptionsSortedByResetDate() throws {
        let store = try makeStore()
        let calendar = Calendar.current
        let now = Date()
        let monthlyResetInTenDays = try XCTUnwrap(calendar.date(byAdding: .day, value: 10, to: now))
        let weeklyRenewalWithResetTomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 43, to: now))
        let noResetCycle = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: now))

        store.create(Subscription(
            name: "Monthly Reset",
            cost: 1,
            nextRenewalDate: monthlyResetInTenDays,
            quotaResetCycle: .monthly
        ))
        store.create(Subscription(
            name: "No Reset",
            cost: 1,
            nextRenewalDate: noResetCycle
        ))
        store.create(Subscription(
            name: "Weekly Reset",
            cost: 1,
            nextRenewalDate: weeklyRenewalWithResetTomorrow,
            quotaResetCycle: .weekly
        ))

        XCTAssertEqual(store.subscriptions.map(\.name), ["Weekly Reset", "Monthly Reset", "No Reset"])
    }

    func testAdvancePastRenewalsRollsForward() throws {
        let store = try makeStore()
        let cal = Calendar.current
        let twoMonthsAgo = try XCTUnwrap(cal.date(byAdding: .month, value: -2, to: .now))
        store.create(Subscription(
            name: "Stale",
            cost: 5,
            billingCycle: .monthly,
            nextRenewalDate: twoMonthsAgo
        ))
        store.advancePastRenewals()
        let rolled = try XCTUnwrap(store.subscriptions.first)
        XCTAssertGreaterThan(rolled.nextRenewalDate, .now)
    }

    func testPruneOldSnapshotsDropsStaleRows() throws {
        let store = try makeStore()
        let sub = Subscription(name: "Tracked", cost: 5, nextRenewalDate: .now)
        store.create(sub)
        let fresh = UsageSnapshot(capturedAt: .now, used: 1, unit: "calls")
        let stale = try UsageSnapshot(
            capturedAt: XCTUnwrap(Calendar.current.date(byAdding: .day, value: -120, to: .now)),
            used: 1,
            unit: "calls"
        )
        store.appendUsageSnapshot(fresh, to: sub)
        store.appendUsageSnapshot(stale, to: sub)
        XCTAssertEqual(sub.usageSnapshots.count, 2)
        store.pruneOldSnapshots()
        XCTAssertEqual(sub.usageSnapshots.count, 1)
    }

    func testMonthlyTotalsByCurrencyBucketsSeparately() throws {
        let store = try makeStore()
        store.create(Subscription(name: "USD Plan", cost: 10, currency: "USD", nextRenewalDate: .now))
        store.create(Subscription(name: "EUR Plan", cost: 8, currency: "EUR", nextRenewalDate: .now))
        XCTAssertTrue(store.hasMixedCurrencies)
        let totals = Dictionary(uniqueKeysWithValues: store.monthlyTotalsByCurrency.map { ($0.currency, $0.total) })
        XCTAssertEqual(totals["USD"], 10)
        XCTAssertEqual(totals["EUR"], 8)
    }

    func testCustomCycleMonthsNormalizesMonthlyCost() throws {
        let store = try makeStore()
        store.create(Subscription(
            name: "Quarterly",
            cost: 30,
            billingCycle: .custom,
            nextRenewalDate: .now,
            customCycleMonths: 3
        ))
        // 30 / 3 = 10
        XCTAssertEqual(store.monthlyTotal, Decimal(10))
    }
}
