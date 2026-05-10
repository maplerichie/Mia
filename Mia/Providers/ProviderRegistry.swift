import Foundation

/// Catalog entry surfaced in UI (e.g. "Add Subscription" picker) and used by
/// `SyncEngine` to instantiate a provider for a given `Subscription`.
struct ProviderDescriptor: Identifiable, Hashable, Sendable {
    let key: String
    let displayName: String
    let requiresCredential: Bool
    /// Build a configured provider. `secret` is non-nil iff
    /// `requiresCredential == true` and a Keychain entry was found.
    private let factory: @Sendable (_ secret: String?) -> any SubscriptionProvider

    var id: String { key }

    init(
        key: String,
        displayName: String,
        requiresCredential: Bool,
        factory: @escaping @Sendable (_ secret: String?) -> any SubscriptionProvider
    ) {
        self.key = key
        self.displayName = displayName
        self.requiresCredential = requiresCredential
        self.factory = factory
    }

    func makeProvider(secret: String? = nil) -> any SubscriptionProvider {
        factory(secret)
    }

    static func == (lhs: ProviderDescriptor, rhs: ProviderDescriptor) -> Bool {
        lhs.key == rhs.key
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
}

/// Process-wide list of available providers. Concrete provider modules
/// register themselves at app launch via `register(_:)`.
@MainActor
final class ProviderRegistry {
    static let shared = ProviderRegistry()

    private(set) var descriptors: [ProviderDescriptor] = []

    private init() {}

    func register(_ descriptor: ProviderDescriptor) {
        guard !descriptors.contains(where: { $0.key == descriptor.key }) else { return }
        descriptors.append(descriptor)
        descriptors.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func descriptor(forKey key: String) -> ProviderDescriptor? {
        descriptors.first { $0.key == key }
    }

    func provider(forKey key: String, secret: String? = nil) -> (any SubscriptionProvider)? {
        descriptor(forKey: key)?.makeProvider(secret: secret)
    }

    /// Wipes the registry. Test-only.
    func _reset() {
        descriptors.removeAll()
    }
}

extension ProviderRegistry {
    /// Single source of truth for provider discovery. To ship a new provider:
    ///
    ///   1. Add a Swift file in `Mia/Providers/` whose type conforms to
    ///      `RegisterableProvider` and exposes `static var descriptor`.
    ///   2. Append the type to this array.
    ///
    /// See `docs/ADDING_A_PROVIDER.md` for the full recipe and template.
    static let builtIns: [any RegisterableProvider.Type] = [
        ManualProvider.self,
        AnthropicProvider.self,
        OpenAIProvider.self
    ]

    /// Registers every type listed in `builtIns`. Called once from
    /// `AppDelegate.applicationDidFinishLaunching`.
    func registerBuiltInProviders() {
        for providerType in Self.builtIns {
            register(providerType.descriptor)
        }
    }
}
