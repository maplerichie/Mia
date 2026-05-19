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
        static let syncIntervalMinutes = "settings.syncIntervalMinutes"
        static let showMenuBarTotal = "settings.showMenuBarTotal"
        static let notificationsEnabled = "settings.notificationsEnabled"
        static let renewalAlertsEnabled = "settings.renewalAlertsEnabled"
        static let quotaAlertsEnabled = "settings.quotaAlertsEnabled"
        static let primaryCurrencyOverride = "settings.primaryCurrencyOverride"
        static let appearance = "settings.appearance"
    }

    /// Allowed sync interval values (minutes). `0` means manual-only.
    static let syncIntervalChoices: [Int] = [0, 15, 30, 60, 120]

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

    /// Minutes between background syncs. `0` disables auto-sync.
    var syncIntervalMinutes: Int {
        didSet { defaults.set(syncIntervalMinutes, forKey: Key.syncIntervalMinutes) }
    }

    /// When `true`, the menu bar status item displays the normalized monthly
    /// total next to the icon.
    var showMenuBarTotal: Bool {
        didSet { defaults.set(showMenuBarTotal, forKey: Key.showMenuBarTotal) }
    }

    /// Master switch for user-facing notifications.
    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Key.notificationsEnabled) }
    }

    /// Fine-grained switch for upcoming-renewal notifications.
    var renewalAlertsEnabled: Bool {
        didSet { defaults.set(renewalAlertsEnabled, forKey: Key.renewalAlertsEnabled) }
    }

    /// Fine-grained switch for quota-threshold notifications.
    var quotaAlertsEnabled: Bool {
        didSet { defaults.set(quotaAlertsEnabled, forKey: Key.quotaAlertsEnabled) }
    }

    /// Empty string means auto-detect (most common currency present).
    var primaryCurrencyOverride: String {
        didSet { defaults.set(primaryCurrencyOverride, forKey: Key.primaryCurrencyOverride) }
    }

    /// Appearance preference: `system`, `light`, `dark`.
    var appearance: AppearancePreference {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.renewalThresholdDays: 3,
            Key.quotaThresholdPercent: 80,
            Key.launchAtLogin: false,
            Key.syncIntervalMinutes: 30,
            Key.showMenuBarTotal: false,
            Key.notificationsEnabled: true,
            Key.renewalAlertsEnabled: true,
            Key.quotaAlertsEnabled: true,
            Key.primaryCurrencyOverride: "",
            Key.appearance: AppearancePreference.system.rawValue
        ])
        self.renewalThresholdDays = defaults.integer(forKey: Key.renewalThresholdDays)
        self.quotaThresholdPercent = defaults.integer(forKey: Key.quotaThresholdPercent)
        self.launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        self.syncIntervalMinutes = defaults.integer(forKey: Key.syncIntervalMinutes)
        self.showMenuBarTotal = defaults.bool(forKey: Key.showMenuBarTotal)
        self.notificationsEnabled = defaults.bool(forKey: Key.notificationsEnabled)
        self.renewalAlertsEnabled = defaults.bool(forKey: Key.renewalAlertsEnabled)
        self.quotaAlertsEnabled = defaults.bool(forKey: Key.quotaAlertsEnabled)
        self.primaryCurrencyOverride = defaults.string(forKey: Key.primaryCurrencyOverride) ?? ""
        let raw = defaults.string(forKey: Key.appearance) ?? AppearancePreference.system.rawValue
        self.appearance = AppearancePreference(rawValue: raw) ?? .system
    }
}

enum AppearancePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "Follow system"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
