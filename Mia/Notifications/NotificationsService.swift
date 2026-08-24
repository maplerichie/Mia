import Foundation
import Observation
import UserNotifications

/// Schedules user-facing alerts for renewal proximity and quota thresholds.
/// Each `(subscription, kind)` pair is debounced to fire at most once per day
/// using `UserDefaults` as the persistence backstop.
@Observable
@MainActor
final class NotificationsService {
    enum Kind: String, Sendable {
        case renewal
        case quota
    }

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.center = center
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
    }

    /// Requests notification permission. Safe to call repeatedly; the user is
    /// only prompted on the first call.
    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // Non-fatal; user denied or system rejected.
        }
        let updated = await center.notificationSettings()
        authorizationStatus = updated.authorizationStatus
    }

    /// Walk every subscription, fire renewal + quota notifications when the
    /// configured thresholds are crossed and the per-day debounce permits it.
    func evaluate(subscriptions: [Subscription], latestUsage: (Subscription) -> UsageSnapshot?, settings: AppSettings) async {
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }
        guard settings.notificationsEnabled else { return }
        for subscription in subscriptions {
            if settings.renewalAlertsEnabled {
                await maybeFireRenewal(for: subscription, settings: settings)
            }
            if settings.quotaAlertsEnabled, let snapshot = latestUsage(subscription) {
                await maybeFireQuota(for: subscription, snapshot: snapshot, settings: settings)
            }
        }
    }

    // MARK: - Decision (pure, testable)

    /// Pure threshold check. The renewal alert fires when
    /// `daysToRenewal <= threshold` and `threshold >= 0`.
    static func renewalShouldNotify(daysToRenewal: Int, threshold: Int) -> Bool {
        threshold >= 0 && daysToRenewal <= threshold
    }

    /// Pure threshold check. Quota alert fires when usage >= percent of limit.
    static func quotaShouldNotify(used: Double, limit: Double?, thresholdPercent: Int) -> Bool {
        guard let limit, limit > 0 else { return false }
        let percent = (used / limit) * 100
        return percent >= Double(thresholdPercent)
    }

    // MARK: - Per-kind evaluation

    private func maybeFireRenewal(for subscription: Subscription, settings: AppSettings) async {
        let daysAway = calendar.dateComponents([.day], from: now(), to: subscription.nextRenewalDate).day ?? Int.max
        guard Self.renewalShouldNotify(daysToRenewal: daysAway, threshold: settings.renewalThresholdDays) else { return }
        guard shouldFire(.renewal, for: subscription) else { return }

        let body: String
        if daysAway <= 0 {
            body = "\(subscription.name) renews today (\(subscription.cost.formatted(.currency(code: subscription.currency))))."
        } else {
            let cost = subscription.cost.formatted(.currency(code: subscription.currency))
            body = "\(subscription.name) renews in \(daysAway) day\(daysAway == 1 ? "" : "s") — \(cost)."
        }
        await post(title: "Upcoming renewal", body: body, kind: .renewal, subscriptionID: subscription.id)
        markFired(.renewal, for: subscription)
    }

    private func maybeFireQuota(for subscription: Subscription, snapshot: UsageSnapshot, settings: AppSettings) async {
        guard Self.quotaShouldNotify(
            used: snapshot.used,
            limit: snapshot.limit,
            thresholdPercent: settings.quotaThresholdPercent
        ) else { return }
        guard shouldFire(.quota, for: subscription) else { return }

        let percent = Int((snapshot.used / (snapshot.limit ?? 1)) * 100)
        let body = "\(subscription.name) is at \(percent)% of its \(snapshot.unit) quota."
        await post(title: "Quota alert", body: body, kind: .quota, subscriptionID: subscription.id)
        markFired(.quota, for: subscription)
    }

    // MARK: - Posting

    private func post(title: String, body: String, kind: Kind, subscriptionID: UUID) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(kind.rawValue).\(subscriptionID.uuidString).\(Int(now().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        do {
            try await center.add(request)
        } catch {
            // Silent failure; the row warning icon already covers errors.
        }
    }

    // MARK: - Debounce

    private func defaultsKey(_ kind: Kind, _ id: UUID) -> String {
        "notifications.lastFired.\(kind.rawValue).\(id.uuidString)"
    }

    private func shouldFire(_ kind: Kind, for subscription: Subscription) -> Bool {
        let key = defaultsKey(kind, subscription.id)
        guard let last = defaults.object(forKey: key) as? Date else { return true }
        return !calendar.isDate(last, inSameDayAs: now())
    }

    private func markFired(_ kind: Kind, for subscription: Subscription) {
        defaults.set(now(), forKey: defaultsKey(kind, subscription.id))
    }

    /// Test/debug helper.
    func resetDebounce(for subscriptionID: UUID, kind: Kind) {
        defaults.removeObject(forKey: defaultsKey(kind, subscriptionID))
    }
}
