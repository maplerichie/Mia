import Foundation
@testable import Mia
import SwiftData
import XCTest

private struct FakeProvider: SubscriptionProvider {
    static let key = "fake-success"
    static let displayName = "Fake Success"
    let requiresCredential = false
    func fetchPlan() async throws -> PlanInfo? {
        nil
    }

    func fetchUsage() async throws -> UsageInfo? {
        UsageInfo(used: 42, limit: 100, unit: "tokens", capturedAt: .now)
    }
}

private struct FailingProvider: SubscriptionProvider {
    static let key = "fake-fail"
    static let displayName = "Fake Fail"
    let requiresCredential = false
    func fetchPlan() async throws -> PlanInfo? {
        nil
    }

    func fetchUsage() async throws -> UsageInfo? {
        throw ProviderError.network("boom")
    }
}

@MainActor
final class SyncEngineTests: XCTestCase {
    private func makeStore() throws -> SubscriptionStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Subscription.self, UsageSnapshot.self, ProviderCredential.self,
            configurations: config
        )
        return SubscriptionStore(modelContext: ModelContext(container))
    }

    override func setUp() async throws {
        ProviderRegistry.shared.resetRegistry()
        ProviderRegistry.shared.register(ProviderDescriptor(
            key: FakeProvider.key,
            displayName: FakeProvider.displayName,
            requiresCredential: false,
            factory: { _ in FakeProvider() }
        ))
        ProviderRegistry.shared.register(ProviderDescriptor(
            key: FailingProvider.key,
            displayName: FailingProvider.displayName,
            requiresCredential: false,
            factory: { _ in FailingProvider() }
        ))
    }

    func testSyncAllAppendsSnapshotForSuccessProvider() async throws {
        let store = try makeStore()
        let sub = Subscription(
            name: "Fake",
            providerKey: FakeProvider.key,
            cost: 10,
            nextRenewalDate: .now
        )
        store.create(sub)

        let engine = SyncEngine(store: store)
        await engine.syncAll()

        XCTAssertEqual(sub.usageSnapshots.count, 1)
        XCTAssertEqual(sub.usageSnapshots.first?.used, 42)
        if case .success = engine.statuses[sub.id] {} else {
            XCTFail("expected success status, got \(String(describing: engine.statuses[sub.id]))")
        }
    }

    func testSyncAllRecordsFailureWithoutCrashing() async throws {
        let store = try makeStore()
        let sub = Subscription(
            name: "Fail",
            providerKey: FailingProvider.key,
            cost: 5,
            nextRenewalDate: .now
        )
        store.create(sub)

        let engine = SyncEngine(store: store)
        await engine.syncAll()

        XCTAssertTrue(sub.usageSnapshots.isEmpty)
        if case .failure(let message) = engine.statuses[sub.id] {
            XCTAssertTrue(message.contains("boom"))
        } else {
            XCTFail("expected failure status, got \(String(describing: engine.statuses[sub.id]))")
        }
    }

    func testSyncAllHandlesUnknownProviderGracefully() async throws {
        let store = try makeStore()
        let sub = Subscription(
            name: "Mystery",
            providerKey: "not-registered",
            cost: 1,
            nextRenewalDate: .now
        )
        store.create(sub)

        let engine = SyncEngine(store: store)
        await engine.syncAll()

        if case .failure = engine.statuses[sub.id] {} else {
            XCTFail("expected failure for unregistered provider")
        }
    }
}
