import XCTest
@testable import Mia

@MainActor
final class ProviderRegistryTests: XCTestCase {
    override func setUp() async throws {
        ProviderRegistry.shared._reset()
    }

    func testRegisterBuiltInsIncludesManual() {
        ProviderRegistry.shared.registerBuiltInProviders()
        let descriptor = ProviderRegistry.shared.descriptor(forKey: ManualProvider.key)
        XCTAssertNotNil(descriptor)
        XCTAssertEqual(descriptor?.displayName, "Manual")
        XCTAssertFalse(descriptor?.requiresCredential ?? true)
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
