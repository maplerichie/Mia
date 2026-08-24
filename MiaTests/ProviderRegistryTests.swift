import XCTest
@testable import Mia

@MainActor
final class ProviderRegistryTests: XCTestCase {
    override func setUp() async throws {
        ProviderRegistry.shared.resetRegistry()
    }

    func testRegisterBuiltInsIncludesManual() {
        ProviderRegistry.shared.registerBuiltInProviders()
        let descriptor = ProviderRegistry.shared.descriptor(forKey: ManualProvider.key)
        XCTAssertNotNil(descriptor)
        XCTAssertEqual(descriptor?.displayName, "Manual")
        XCTAssertFalse(descriptor?.requiresCredential ?? true)
    }

    func testRegisterBuiltInsIncludesLocalSourceProviders() {
        ProviderRegistry.shared.registerBuiltInProviders()
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: CodexProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: ClaudeProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: CursorProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: ZedProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: CodebuffProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: OpenRouterProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: PerplexityProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: DeepSeekProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: ElevenLabsProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: GroqCloudProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: MistralProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: MoonshotProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: PoeProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: KimiK2Provider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: VeniceProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: CrofProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: WarpProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: T3ChatProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: OllamaProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: ManusProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: DevinProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: MiniMaxProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: CommandCodeProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: QoderProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: SakanaAIProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: AbacusAIProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: XiaomiMiMoProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: ChutesProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: CrossModelProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: ClawRouterProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: LLMProxyProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: SyntheticProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: ZaiProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: DeepgramProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: DoubaoProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: OpenCodeProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: WayfinderProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: DroidFactoryProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: AlibabaCodingPlanProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: AlibabaTokenPlanProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: WindsurfProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: JetBrainsAIProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: KiloProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: OpenCodeGoProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: StepFunProvider.key))
        XCTAssertNotNil(ProviderRegistry.shared.descriptor(forKey: AWSBedrockProvider.key))
    }

    func testRegisterIsIdempotent() {
        let descriptor = ProviderDescriptor(
            key: ManualProvider.key,
            displayName: ManualProvider.displayName,
            requiresCredential: false,
            factory: { _ in ManualProvider() }
        )
        ProviderRegistry.shared.register(descriptor)
        ProviderRegistry.shared.register(descriptor)
        XCTAssertEqual(ProviderRegistry.shared.descriptors.count, 1)
    }

    func testProviderFactoryReturnsInstance() {
        ProviderRegistry.shared.registerBuiltInProviders()
        let provider = ProviderRegistry.shared.provider(forKey: ManualProvider.key)
        XCTAssertNotNil(provider)
        XCTAssertTrue(provider is ManualProvider)
    }

    func testManualProviderReturnsNil() async throws {
        let provider = ManualProvider()
        let plan = try await provider.fetchPlan()
        let usage = try await provider.fetchUsage()
        XCTAssertNil(plan)
        XCTAssertNil(usage)
    }
}
