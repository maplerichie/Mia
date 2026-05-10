import AppKit
import SwiftData
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private(set) var modelContainer: ModelContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: Subscription.self, UsageSnapshot.self, ProviderCredential.self
            )
        } catch {
            assertionFailure("Failed to create SwiftData ModelContainer: \(error)")
            return
        }
        self.modelContainer = container

        ProviderRegistry.shared.registerBuiltInProviders()

        let store = SubscriptionStore(modelContext: ModelContext(container))
        let notifications = NotificationsService()
        let syncEngine = SyncEngine(store: store)
        menuBarController = MenuBarController(
            store: store,
            settings: AppSettings.shared,
            syncEngine: syncEngine,
            notifications: notifications
        )

        Task {
            await notifications.requestAuthorizationIfNeeded()
            await syncEngine.syncAll()
            await notifications.evaluate(
                subscriptions: store.subscriptions,
                latestUsage: { store.latestUsage(for: $0) },
                settings: AppSettings.shared
            )
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
