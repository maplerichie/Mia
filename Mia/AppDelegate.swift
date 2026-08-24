import AppKit
import os.log
import SwiftData
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private(set) var modelContainer: ModelContainer?
    private var syncTimer: Timer?
    private var settingsObservationTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.likkee.mia", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: Subscription.self, UsageSnapshot.self, ProviderCredential.self
            )
        } catch {
            logger.error("Failed to create SwiftData ModelContainer: \(error.localizedDescription)")
            NSApp.terminate(nil)
            return
        }
        self.modelContainer = container

        ProviderRegistry.shared.registerBuiltInProviders()

        let store = SubscriptionStore(modelContext: ModelContext(container))
        let notifications = NotificationsService()
        let syncEngine = SyncEngine(store: store)
        let settings = AppSettings.shared
        let controller = MenuBarController(
            store: store,
            settings: settings,
            syncEngine: syncEngine,
            notifications: notifications
        )
        menuBarController = controller

        // Phase 1.2 — auto-advance past renewal dates at launch.
        store.advancePastRenewals()
        // Phase 1.5 — opportunistic prune at launch.
        store.pruneOldSnapshots()

        // Phase 1.1 — start the background sync timer.
        scheduleSyncTimer(intervalMinutes: settings.syncIntervalMinutes, syncEngine: syncEngine, store: store, notifications: notifications, settings: settings)
        // Poll the user's preferred interval; cheap, runs once a minute.
        observeSyncIntervalChanges(settings: settings, syncEngine: syncEngine, store: store, notifications: notifications)

        Task {
            await notifications.requestAuthorizationIfNeeded()
            await syncEngine.syncAll()
            await notifications.evaluate(
                subscriptions: store.subscriptions,
                latestUsage: { store.latestUsage(for: $0) },
                settings: settings
            )
            controller.refreshMenuBarTitle()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Sync timer

    private var lastScheduledInterval: Int = -1

    private func scheduleSyncTimer(
        intervalMinutes: Int,
        syncEngine: SyncEngine,
        store: SubscriptionStore,
        notifications: NotificationsService,
        settings: AppSettings
    ) {
        syncTimer?.invalidate()
        syncTimer = nil
        lastScheduledInterval = intervalMinutes
        guard intervalMinutes > 0 else { return }
        let seconds = TimeInterval(intervalMinutes * 60)
        let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { _ in
            Task { @MainActor in
                await syncEngine.syncAll()
                await notifications.evaluate(
                    subscriptions: store.subscriptions,
                    latestUsage: { store.latestUsage(for: $0) },
                    settings: settings
                )
                self.menuBarController?.refreshMenuBarTitle()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        syncTimer = timer
    }

    private func observeSyncIntervalChanges(
        settings: AppSettings,
        syncEngine: SyncEngine,
        store: SubscriptionStore,
        notifications: NotificationsService
    ) {
        settingsObservationTask?.cancel()
        settingsObservationTask = Task { @MainActor [weak self] in
            // Lightweight poll — `@Observable` doesn't expose change streams
            // for non-SwiftUI consumers, and a once-per-minute check is
            // cheap enough that wiring up Combine isn't worth it.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard let self else { return }
                if settings.syncIntervalMinutes != self.lastScheduledInterval {
                    self.scheduleSyncTimer(
                        intervalMinutes: settings.syncIntervalMinutes,
                        syncEngine: syncEngine,
                        store: store,
                        notifications: notifications,
                        settings: settings
                    )
                }
                self.menuBarController?.refreshMenuBarTitle()
            }
        }
    }
}
