import Foundation

/// Catalog entry surfaced in UI (e.g. "Add Subscription" picker) and used by
/// `SyncEngine` to instantiate a provider for a given `Subscription`.
struct ProviderDescriptor: Identifiable, Hashable, Sendable {
    let key: String
    let displayName: String
    let requiresCredential: Bool
    /// Where the credential is expected to come from. Defaults to `.manual`
    /// (user-pasted API key stored in Mia's Keychain) for API-backed providers.
    let credentialSource: CredentialSource
    /// Build a configured provider. `credential` is non-nil iff the resolved
    /// credential source returned a value; it includes both the secret value
    /// and an optional account identity for providers that need both.
    private let factory: @Sendable (_ credential: ResolvedCredential?) -> any SubscriptionProvider

    var id: String {
        key
    }

    init(
        key: String,
        displayName: String,
        requiresCredential: Bool,
        credentialSource: CredentialSource = .manual,
        factory: @escaping @Sendable (_ credential: ResolvedCredential?) -> any SubscriptionProvider
    ) {
        self.key = key
        self.displayName = displayName
        self.requiresCredential = requiresCredential
        self.credentialSource = credentialSource
        self.factory = factory
    }

    func makeProvider(credential: ResolvedCredential? = nil) -> any SubscriptionProvider {
        factory(credential)
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

    func provider(forKey key: String, credential: ResolvedCredential? = nil) -> (any SubscriptionProvider)? {
        descriptor(forKey: key)?.makeProvider(credential: credential)
    }

    /// Wipes the registry. Test-only.
    func resetRegistry() {
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
        AbacusAIProvider.self,
        AlibabaCodingPlanProvider.self,
        AlibabaTokenPlanProvider.self,
        AnthropicProvider.self,
        AWSBedrockProvider.self,
        DroidFactoryProvider.self,
        ChutesProvider.self,
        ClawRouterProvider.self,
        CodebuffProvider.self,
        CodexProvider.self,
        ClaudeProvider.self,
        CommandCodeProvider.self,
        CrofProvider.self,
        CrossModelProvider.self,
        CursorProvider.self,
        DeepSeekProvider.self,
        DeepgramProvider.self,
        DevinProvider.self,
        DoubaoProvider.self,
        ElevenLabsProvider.self,
        GroqCloudProvider.self,
        JetBrainsAIProvider.self,
        KimiK2Provider.self,
        KiloProvider.self,
        LLMProxyProvider.self,
        ManusProvider.self,
        OpenCodeProvider.self,
        OpenCodeGoProvider.self,
        MiniMaxProvider.self,
        MistralProvider.self,
        MoonshotProvider.self,
        OllamaProvider.self,
        OpenAIProvider.self,
        OpenRouterProvider.self,
        PerplexityProvider.self,
        PoeProvider.self,
        QoderProvider.self,
        SakanaAIProvider.self,
        StepFunProvider.self,
        SyntheticProvider.self,
        T3ChatProvider.self,
        VeniceProvider.self,
        WarpProvider.self,
        WayfinderProvider.self,
        WindsurfProvider.self,
        XiaomiMiMoProvider.self,
        ZaiProvider.self,
        ZedProvider.self
    ]

    /// Registers every type listed in `builtIns`. Called once from
    /// `AppDelegate.applicationDidFinishLaunching`.
    func registerBuiltInProviders() {
        for providerType in Self.builtIns {
            register(providerType.descriptor)
        }
    }
}
