import Foundation
import SwiftData

/// A user-tracked recurring service (e.g. Spotify, Anthropic).
@Model
final class Subscription {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Lowercase provider key, e.g. `"manual"`, `"anthropic"`.
    var providerKey: String
    var plan: String
    /// Use `Decimal` exclusively for money — never `Double`.
    var cost: Decimal
    /// ISO-4217 currency code, e.g. `"USD"`.
    var currency: String
    var billingCycle: BillingCycle
    var nextRenewalDate: Date
    /// How often the provider's usage quota resets. Independent from the
    /// billing cycle (e.g. Anthropic Pro is monthly billing but weekly
    /// message quotas; iCloud storage is monthly billing but never resets).
    /// `nil` means unknown / not applicable.
    var quotaResetCycle: QuotaResetCycle?
    var iconAssetName: String?
    var notes: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \UsageSnapshot.subscription)
    var usageSnapshots: [UsageSnapshot] = []

    @Relationship(deleteRule: .cascade, inverse: \ProviderCredential.subscription)
    var credential: ProviderCredential?

    init(
        id: UUID = UUID(),
        name: String,
        providerKey: String = "manual",
        plan: String = "",
        cost: Decimal,
        currency: String = "USD",
        billingCycle: BillingCycle = .monthly,
        nextRenewalDate: Date,
        quotaResetCycle: QuotaResetCycle? = nil,
        iconAssetName: String? = nil,
        notes: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.providerKey = providerKey
        self.plan = plan
        self.cost = cost
        self.currency = currency
        self.billingCycle = billingCycle
        self.nextRenewalDate = nextRenewalDate
        self.quotaResetCycle = quotaResetCycle
        self.iconAssetName = iconAssetName
        self.notes = notes
        self.createdAt = createdAt
    }
}

/// Cadence on which a provider's usage counter resets. Most subscription
/// services fall into one of these buckets:
///
/// * **Daily**  — rate-limited APIs, ChatGPT Free message caps.
/// * **Weekly** — Claude Pro / Cursor message caps in some tiers.
/// * **Monthly** — most paid AI APIs (Anthropic Admin, OpenAI Org), Copilot.
/// * **Yearly** — annual prepaid credits.
/// * **Never** — cumulative storage (iCloud, Dropbox, Google One).
enum QuotaResetCycle: String, Codable, CaseIterable, Identifiable, Sendable {
    case daily
    case weekly
    case monthly
    case yearly
    case never

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .never: "Never (cumulative)"
        }
    }
}

enum BillingCycle: String, Codable, CaseIterable, Identifiable {
    case monthly
    case yearly
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .custom: "Custom"
        }
    }

    /// Number of months in this billing cycle. Used to normalize costs into a
    /// per-month figure via division (avoids `Decimal` rounding from `1/12`).
    var monthsPerCycle: Decimal {
        switch self {
        case .monthly: 1
        case .yearly: 12
        case .custom: 1
        }
    }
}

extension QuotaResetCycle {
    /// Calendar component used to step the cycle interval. `nil` for `.never`.
    var stepComponent: Calendar.Component? {
        switch self {
        case .daily: .day
        case .weekly: .weekOfYear
        case .monthly: .month
        case .yearly: .year
        case .never: nil
        }
    }
}

extension Subscription {
    /// Next quota reset date derived from `nextRenewalDate` and
    /// `quotaResetCycle`. Walks the cycle interval relative to the renewal
    /// anchor until the first reset strictly after `now`. Returns `nil` for
    /// `.never` or when no cycle is set.
    func nextQuotaResetDate(now: Date = .now) -> Date? {
        guard let cycle = quotaResetCycle,
              let component = cycle.stepComponent else { return nil }

        let cal = Calendar.current
        var date = nextRenewalDate

        // Roll back while the candidate is still in the future.
        while date > now {
            guard let prev = cal.date(byAdding: component, value: -1, to: date) else { break }
            if prev <= now { break }
            date = prev
        }
        // Roll forward to the first candidate after now.
        while date <= now {
            guard let next = cal.date(byAdding: component, value: 1, to: date) else { break }
            date = next
        }
        return date
    }
}
