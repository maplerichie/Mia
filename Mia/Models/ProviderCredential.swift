import Foundation
import SwiftData

/// Reference record pointing at a Keychain-stored secret. The secret itself
/// never lives in SwiftData — only the lookup metadata does.
@Model
final class ProviderCredential {
    @Attribute(.unique) var id: UUID
    /// Keychain account identifier (typically the subscription UUID).
    var keychainAccount: String
    /// Keychain service identifier, scoped per provider.
    var keychainService: String
    var createdAt: Date

    var subscription: Subscription?

    init(
        id: UUID = UUID(),
        keychainAccount: String,
        keychainService: String,
        createdAt: Date = .now,
        subscription: Subscription? = nil
    ) {
        self.id = id
        self.keychainAccount = keychainAccount
        self.keychainService = keychainService
        self.createdAt = createdAt
        self.subscription = subscription
    }
}
