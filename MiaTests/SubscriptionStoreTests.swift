import Foundation
import SwiftData
import XCTest
@testable import Mia

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

        store.create(Subscription(
            name: "Spotify",
            cost: Decimal(string: "9.99")!,
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
        let monthlyResetInTenDays = calendar.date(byAdding: .day, value: 10, to: now)!
        let weeklyRenewalWithResetTomorrow = calendar.date(byAdding: .day, value: 43, to: now)!
        let noResetCycle = calendar.date(byAdding: .day, value: 1, to: now)!

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
}
