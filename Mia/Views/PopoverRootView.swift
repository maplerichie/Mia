import AppKit
import SwiftUI

struct PopoverRootView: View {
    @Bindable var store: SubscriptionStore
    @Bindable var settings: AppSettings
    @Bindable var syncEngine: SyncEngine
    @Bindable var notifications: NotificationsService

    /// SwiftUI only supports one active sheet per view; we drive every
    /// presentation through a single `.sheet(item:)` to avoid the
    /// "Currently, only presenting a single sheet is supported" runtime
    /// warning that fires during app-switch re-evaluation.
    private enum Sheet: Identifiable {
        case add
        case settings
        case edit(UUID)

        var id: String {
            switch self {
            case .add: "add"
            case .settings: "settings"
            case .edit(let id): "edit-\(id.uuidString)"
            }
        }
    }

    @State private var activeSheet: Sheet?
    @State private var syncRotation: Double = 0
    @State private var showSyncCheck: Bool = false
    @State private var tickTrigger: Int = 0
    /// `min` and `max` from todo Phase 6.1.
    private static let minHeight: CGFloat = 200
    private static let maxHeight: CGFloat = 600

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            SubscriptionListView(
                store: store,
                syncEngine: syncEngine,
                onAdd: { activeSheet = .add },
                onEdit: { subscription in
                    activeSheet = .edit(subscription.id)
                }
            )
            Divider()
            footer
        }
        .frame(width: 360)
        .frame(minHeight: Self.minHeight, idealHeight: idealHeight, maxHeight: Self.maxHeight)
        .preferredColorScheme(colorScheme)
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .background(keyboardShortcuts)
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            tickTrigger &+= 1
        }
    }

    /// Heuristic so a near-empty popover doesn't show a yawning void: ~64pt
    /// per row + ~140pt chrome (header + footer + padding), clamped to bounds.
    private var idealHeight: CGFloat {
        let chrome: CGFloat = 140
        let rowHeight: CGFloat = 64
        let count = max(store.subscriptions.count, 1)
        let ideal = chrome + CGFloat(count) * rowHeight
        return min(max(ideal, Self.minHeight), Self.maxHeight)
    }

    private var colorScheme: ColorScheme? {
        switch settings.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: Sheet) -> some View {
        switch sheet {
        case .add:
            AddSubscriptionView(
                store: store,
                isPresented: dismissBinding,
                editing: nil
            )
        case .settings:
            SettingsView(
                settings: settings,
                isPresented: dismissBinding
            )
        case .edit(let id):
            if let existing = store.subscriptions.first(where: { $0.id == id }) {
                AddSubscriptionView(
                    store: store,
                    isPresented: dismissBinding,
                    editing: existing
                )
            } else {
                // Subscription was deleted between trigger and presentation;
                // dismiss immediately.
                Color.clear
                    .frame(width: 1, height: 1)
                    .onAppear { activeSheet = nil }
            }
        }
    }

    /// Convenience binding shared by every child sheet — when set to `false`
    /// it clears `activeSheet` so the same single `.sheet(item:)` modifier
    /// can drive any of the three flows.
    private var dismissBinding: Binding<Bool> {
        Binding(
            get: { activeSheet != nil },
            set: { if !$0 { activeSheet = nil } }
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Mia")
                    .font(.headline)
                Spacer()
                if let stamp = lastSyncedLabel {
                    Text(stamp)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .id(tickTrigger) // refresh relative label every minute
                }
                Button {
                    Task { await refresh() }
                } label: {
                    ZStack {
                        if showSyncCheck {
                            Image(systemName: "checkmark")
                                .transition(.opacity)
                        } else if syncEngine.isSyncing {
                            Image(systemName: "arrow.clockwise")
                                .rotationEffect(.degrees(syncRotation))
                                .onAppear {
                                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                        syncRotation = 360
                                    }
                                }
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
                .buttonStyle(.borderless)
                .disabled(syncEngine.isSyncing)
                .help("Refresh usage (⌘R)")
                .keyboardShortcut("r", modifiers: [.command])
            }
            totalsRow
        }
        .padding(12)
    }

    @ViewBuilder
    private var totalsRow: some View {
        if store.hasMixedCurrencies {
            // Multi-currency: show per-currency subtotals to avoid silently
            // summing across non-comparable currencies.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                ForEach(store.monthlyTotalsByCurrency.prefix(3), id: \.currency) { entry in
                    HStack(spacing: 2) {
                        Text(entry.total.formatted(.currency(code: entry.currency)))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("/mo")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text(store.monthlyTotal.formatted(.currency(code: store.primaryCurrency)))
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("/ month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(store.yearlyTotal.formatted(.currency(code: store.primaryCurrency)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("/ year")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var lastSyncedLabel: String? {
        guard let date = syncEngine.lastSyncedAt else { return nil }
        let interval = Date.now.timeIntervalSince(date)
        if interval < 5 { return "Just synced" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Synced " + formatter.localizedString(for: date, relativeTo: .now)
    }

    private var footer: some View {
        HStack {
            Button {
                activeSheet = .add
            } label: {
                Label("Add", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: [.command])
            Spacer()
            Button {
                activeSheet = .settings
            } label: {
                Label("Settings", systemImage: "gear")
            }
            .keyboardShortcut(",", modifiers: [.command])
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
        .padding(8)
    }

    /// Catch-all shortcut surface in case Buttons are not in the focus
    /// chain (popover hosts can drop first responder occasionally).
    @ViewBuilder
    private var keyboardShortcuts: some View {
        Group {
            Button("") { activeSheet = .add }
                .keyboardShortcut("n", modifiers: [.command])
            Button("") { Task { await refresh() } }
                .keyboardShortcut("r", modifiers: [.command])
            Button("") { activeSheet = .settings }
                .keyboardShortcut(",", modifiers: [.command])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
    }

    private func refresh() async {
        await syncEngine.syncAll()
        // Brief checkmark flash on completion.
        withAnimation(.easeInOut(duration: 0.2)) { showSyncCheck = true }
        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.easeInOut(duration: 0.2)) { showSyncCheck = false }
        await notifications.evaluate(
            subscriptions: store.subscriptions,
            latestUsage: { store.latestUsage(for: $0) },
            settings: settings
        )
    }
}
