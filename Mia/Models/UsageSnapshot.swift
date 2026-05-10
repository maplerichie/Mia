import Foundation
import SwiftData

/// Point-in-time usage reading captured from a provider.
@Model
final class UsageSnapshot {
    @Attribute(.unique) var id: UUID
    var capturedAt: Date
    /// Numeric usage value (tokens, messages, GB, hours, etc.).
    var used: Double
    /// Optional ceiling reported by the provider.
    var limit: Double?
    /// Free-form unit label, e.g. `"tokens"`, `"messages"`, `"GB"`.
    var unit: String
    /// Raw provider payload retained for debugging only.
    var rawJSON: String?

    var subscription: Subscription?

    init(
        id: UUID = UUID(),
        capturedAt: Date = .now,
        used: Double,
        limit: Double? = nil,
        unit: String,
        rawJSON: String? = nil,
        subscription: Subscription? = nil
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.used = used
        self.limit = limit
        self.unit = unit
        self.rawJSON = rawJSON
        self.subscription = subscription
    }
}
