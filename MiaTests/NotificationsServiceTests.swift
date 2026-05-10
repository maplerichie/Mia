import Foundation
import UserNotifications
import XCTest
@testable import Mia

@MainActor
final class NotificationsServiceTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suite = "tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    // MARK: - Pure threshold logic

    func testRenewalShouldNotifyAtAndBelowThreshold() {
        XCTAssertTrue(NotificationsService.renewalShouldNotify(daysToRenewal: 0, threshold: 3))
        XCTAssertTrue(NotificationsService.renewalShouldNotify(daysToRenewal: 3, threshold: 3))
        XCTAssertTrue(NotificationsService.renewalShouldNotify(daysToRenewal: -1, threshold: 3))
    }

    func testRenewalDoesNotNotifyAboveThreshold() {
        XCTAssertFalse(NotificationsService.renewalShouldNotify(daysToRenewal: 4, threshold: 3))
        XCTAssertFalse(NotificationsService.renewalShouldNotify(daysToRenewal: 30, threshold: 3))
    }

    func testRenewalThresholdNegativeDisables() {
        XCTAssertFalse(NotificationsService.renewalShouldNotify(daysToRenewal: 0, threshold: -1))
    }

    func testQuotaShouldNotifyAtOrAboveThreshold() {
        XCTAssertTrue(NotificationsService.quotaShouldNotify(used: 80, limit: 100, thresholdPercent: 80))
        XCTAssertTrue(NotificationsService.quotaShouldNotify(used: 95, limit: 100, thresholdPercent: 80))
    }

    func testQuotaDoesNotNotifyBelowThreshold() {
        XCTAssertFalse(NotificationsService.quotaShouldNotify(used: 79, limit: 100, thresholdPercent: 80))
    }

    func testQuotaWithoutLimitDoesNotNotify() {
        XCTAssertFalse(NotificationsService.quotaShouldNotify(used: 1_000_000, limit: nil, thresholdPercent: 1))
        XCTAssertFalse(NotificationsService.quotaShouldNotify(used: 100, limit: 0, thresholdPercent: 1))
    }

    // MARK: - Debounce key lifecycle

    func testResetDebounceClearsKey() {
        let defaults = makeDefaults()
        let now = Date(timeIntervalSince1970: 1_762_473_600)
        let service = NotificationsService(defaults: defaults, now: { now })

        let id = UUID()
        let key = "notifications.lastFired.renewal.\(id.uuidString)"

        defaults.set(now, forKey: key)
        XCTAssertNotNil(defaults.object(forKey: key))

        service._resetDebounce(for: id, kind: .renewal)
        XCTAssertNil(defaults.object(forKey: key))
    }
}
