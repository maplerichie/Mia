import AppKit
import SwiftUI

/// Identifiers for the sheets presented from the popover.
/// Shared between AppKit chrome (`MenuBarController`) and SwiftUI content
/// (`PopoverRootView`) so the status-bar menu can open sheets.
enum PopoverSheet: Identifiable, Sendable {
    case add
    case settings
    case edit(UUID)
    case welcome

    var id: String {
        switch self {
        case .add: "add"
        case .settings: "settings"
        case .edit(let id): "edit-\(id.uuidString)"
        case .welcome: "welcome"
        }
    }
}

/// Shared state between AppKit menu-bar chrome and the SwiftUI popover content.
@MainActor
@Observable
final class PopoverState {
    var activeSheet: PopoverSheet?
}

/// Owns the `NSStatusItem` in the system menu bar and the popover that hosts
/// the SwiftUI subscription list.
@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let store: SubscriptionStore
    private let settings: AppSettings
    private let syncEngine: SyncEngine
    private let notifications: NotificationsService
    private let popoverState = PopoverState()

    init(
        store: SubscriptionStore,
        settings: AppSettings,
        syncEngine: SyncEngine,
        notifications: NotificationsService
    ) {
        self.store = store
        self.settings = settings
        self.syncEngine = syncEngine
        self.notifications = notifications
        // `variableLength` lets us grow/shrink when the optional $XX badge
        // toggles in Settings.
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        configureStatusItem()
        configurePopover()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            let image = NSImage(named: "MenuBarIcon") ?? NSImage(
                systemSymbolName: "creditcard",
                accessibilityDescription: "Mia"
            )
            image?.accessibilityDescription = "Mia"
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeft
            button.target = self
            button.action = #selector(togglePopover(_:))
            // Distinguish left-click (open popover) from right-click (show menu).
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        refreshMenuBarTitle()
    }

    /// Recompute the optional `$XX` badge from current settings + store totals.
    /// Cheap; called from the sync timer and after the user toggles the
    /// Settings switch.
    func refreshMenuBarTitle() {
        guard let button = statusItem.button else { return }
        if settings.showMenuBarTotal, !store.subscriptions.isEmpty {
            let total = store.monthlyTotal
            // Compact integer rendering — keep the menu bar narrow.
            let rounded = NSDecimalNumber(decimal: total).intValue
            let symbol = Locale.current.localizedString(forCurrencyCode: store.primaryCurrency) ?? store.primaryCurrency
            let glyph = currencyGlyph(for: store.primaryCurrency) ?? symbol
            button.title = " \(glyph)\(rounded)"
        } else {
            button.title = ""
        }
    }

    private func currencyGlyph(for code: String) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol
    }

    private func configurePopover() {
        // `.transient` already dismisses the popover when the user interacts
        // with anything outside it (including switching apps), so we don't
        // install a redundant global event monitor — that monitor was racing
        // with `.transient`, leaving the popover's window in a non-key state
        // on re-show, which made buttons appear focused but unclickable.
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView(
                store: store,
                settings: settings,
                syncEngine: syncEngine,
                notifications: notifications,
                popoverState: popoverState
            )
        )
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showStatusBarMenu()
            return
        }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        store.reload()
        refreshMenuBarTitle()

        // For `LSUIElement` (menu-bar-only) apps, the process is not active by
        // default. Without activating, the popover's window can't become key
        // on re-open, so SwiftUI buttons render with focus rings but ignore
        // clicks. Activate first, then show.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if let window = popover.contentViewController?.view.window {
            window.makeKeyAndOrderFront(nil)
            // Drop any stale first responder from the previous show so no
            // button renders pre-selected.
            window.makeFirstResponder(nil)
        }
        statusItem.button?.highlight(true)
    }

    private func showStatusBarMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Sync Now", action: #selector(syncNow(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Add Subscription…", action: #selector(addSubscription(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Mia", action: #selector(quit(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        // Attach the menu temporarily so `performClick` opens it, then remove
        // it in `menuDidClose` so left-clicks continue to toggle the popover.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    @objc private func syncNow(_ sender: Any?) {
        Task {
            await syncEngine.syncAll()
            await notifications.evaluate(
                subscriptions: store.subscriptions,
                latestUsage: { store.latestUsage(for: $0) },
                settings: settings
            )
            refreshMenuBarTitle()
        }
    }

    @objc private func addSubscription(_ sender: Any?) {
        showPopover()
        popoverState.activeSheet = .add
    }

    @objc private func openSettings(_ sender: Any?) {
        showPopover()
        popoverState.activeSheet = .settings
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
        refreshMenuBarTitle()
    }
}
