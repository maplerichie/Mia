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

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            SubscriptionListView(
                store: store,
                syncEngine: syncEngine,
                onEdit: { subscription in
                    activeSheet = .edit(subscription.id)
                }
            )
            Divider()
            footer
        }
        .frame(width: 360, height: 480)
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
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
                Button {
                    Task { await refresh() }
                } label: {
                    if syncEngine.isSyncing {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(syncEngine.isSyncing)
                .help("Refresh usage")
            }
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
        .padding(12)
    }

    private var footer: some View {
        HStack {
            Button {
                activeSheet = .add
            } label: {
                Label("Add", systemImage: "plus")
            }
            Spacer()
            Button {
                activeSheet = .settings
            } label: {
                Label("Settings", systemImage: "gear")
            }
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding(8)
    }

    private func refresh() async {
        await syncEngine.syncAll()
        await notifications.evaluate(
            subscriptions: store.subscriptions,
            latestUsage: { store.latestUsage(for: $0) },
            settings: settings
        )
    }
}
