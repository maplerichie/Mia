import Foundation
@testable import Mia
import XCTest

@MainActor
final class AppSettingsTests: XCTestCase {
    func testHasSeenWelcomeDefaultsToFalse() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertFalse(settings.hasSeenWelcome)
    }

    func testHasSeenWelcomePersists() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let first = AppSettings(defaults: defaults)
        first.hasSeenWelcome = true

        let second = AppSettings(defaults: defaults)
        XCTAssertTrue(second.hasSeenWelcome)
    }
}
