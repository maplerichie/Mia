import XCTest
import Foundation
@testable import Mia

final class SubscriptionListViewTests: XCTestCase {
    func testSortedByResetDateUsesResetDateThenRenewalDateThenName() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: today)!
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: today)!

        let a = Subscription(
            name: "Alpha",
            providerKey: "manual",
            cost: 10,
            currency: "USD",
            billingCycle: .monthly,
            nextRenewalDate: nextMonth,
            quotaResetCycle: .weekly
        )
        a.nextRenewalDate = tomorrow

        let b = Subscription(
            name: "Beta",
            providerKey: "manual",
            cost: 20,
            currency: "USD",
            billingCycle: .monthly,
            nextRenewalDate: nextWeek,
            quotaResetCycle: .weekly
        )
        b.nextRenewalDate = tomorrow

        let c = Subscription(
            name: "Charlie",
            providerKey: "manual",
            cost: 30,
            currency: "USD",
            billingCycle: .monthly,
            nextRenewalDate: nextWeek,
            quotaResetCycle: .weekly
        )
        c.nextRenewalDate = nextWeek

        let sorted = [c, a, b].sortedByResetDate(now: today)
        XCTAssertEqual(sorted.map(\.name), ["Alpha", "Beta", "Charlie"])
    }
}
