import Foundation
import Observation

/// User-tunable preferences persisted in `UserDefaults`. Mutations push back
/// through the `@Observable` machinery so SwiftUI views update automatically.
@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    private enum Key {
        static let renewalThresholdDays = "settings.renewalThresholdDays"
        static let quotaThresholdPercent = "settings.quotaThresholdPercent"
        static let launchAtLogin = "settings.launchAtLogin"
    }

    private let defaults: UserDefaults

    /// Days before renewal at which a notification fires.
    var renewalThresholdDays: Int {
        didSet { defaults.set(renewalThresholdDays, forKey: Key.renewalThresholdDays) }
    }

    /// Usage percentage (0–100) at which a quota notification fires.
    var quotaThresholdPercent: Int {
        didSet { defaults.set(quotaThresholdPercent, forKey: Key.quotaThresholdPercent) }
    }

    /// Mirror of the actual `SMAppService` state so SwiftUI can bind a Toggle.
    var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Key.launchAtLogin)
            do {
                try LaunchAtLogin.setEnabled(launchAtLogin)
            } catch {
                // Re-sync without re-entering this didSet.
                let actual = LaunchAtLogin.isEnabled
                if actual != launchAtLogin {
                    launchAtLogin = actual
                }
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.renewalThresholdDays: 3,
            Key.quotaThresholdPercent: 80,
            Key.launchAtLogin: false
        ])
        self.renewalThresholdDays = defaults.integer(forKey: Key.renewalThresholdDays)
        self.quotaThresholdPercent = defaults.integer(forKey: Key.quotaThresholdPercent)
        self.launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
    }
}
