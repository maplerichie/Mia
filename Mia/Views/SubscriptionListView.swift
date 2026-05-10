import SwiftUI

struct SubscriptionListView: View {
    @Bindable var store: SubscriptionStore
    @Bindable var syncEngine: SyncEngine
    let onEdit: (Subscription) -> Void

    var body: some View {
        if store.subscriptions.isEmpty {
            emptyState
        } else {
            List {
                ForEach(store.subscriptions) { subscription in
                    SubscriptionRow(
                        subscription: subscription,
                        latestUsage: store.latestUsage(for: subscription),
                        status: syncEngine.statuses[subscription.id] ?? .idle,
                        onEdit: { onEdit(subscription) },
                        onDelete: { store.delete(subscription) }
                    )
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") { onEdit(subscription) }
                        Button(role: .destructive) {
                            store.delete(subscription)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No subscriptions yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Click + to add one.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SubscriptionRow: View {
    let subscription: Subscription
    let latestUsage: UsageSnapshot?
    let status: SyncStatus
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "creditcard.fill")
                .foregroundStyle(.white)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(subscription.name)
                        .font(.body)
                    if !subscription.plan.isEmpty {
                        Text(subscription.plan)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    statusIndicator
                    Spacer(minLength: 8)
                    Text(costLabel)
                        .font(.body.monospacedDigit())
                }
                HStack(spacing: 6) {
                    Text(resetLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(renewalDateLabel)
                        .font(.caption2)
                        .foregroundStyle(renewalColor)
                }
                if let usage = latestUsage {
                    UsageBar(snapshot: usage, resetCycle: subscription.quotaResetCycle)
                }
            }

            Button(action: onEdit) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isHovering ? Color.accentColor : .secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Edit subscription")
        }
        .padding(.vertical, 2)
        .onHover { isHovering = $0 }
    }

    private var costLabel: String {
        let cost = subscription.cost.formatted(.currency(code: subscription.currency))
        return "\(cost)/\(subscription.billingCycle.abbreviation)"
    }

    private var renewalDateLabel: String {
        subscription.nextRenewalDate.formatted(
            .dateTime.day(.twoDigits).month(.twoDigits).year()
                .locale(Locale(identifier: "en_GB"))
        )
    }

    private var resetLabel: String {
        guard let nextReset = subscription.nextQuotaResetDate() else { return "" }
        let days = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: nextReset)
        ).day ?? 0
        if days < 0 { return "Reset overdue" }
        if days == 0 { return "Reset today" }
        if days == 1 { return "Reset in 1 day" }
        return "Reset in \(days) days"
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch status {
        case .syncing:
            ProgressView()
                .controlSize(.mini)
        case .failure(let message):
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .help(message)
        case .idle, .success:
            EmptyView()
        }
    }

    private var daysToRenewal: Int {
        let cal = Calendar.current
        return cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: .now),
            to: cal.startOfDay(for: subscription.nextRenewalDate)
        ).day ?? 0
    }

    private var renewalColor: Color {
        switch daysToRenewal {
        case ..<0: .red
        case 0...2: .orange
        default: .secondary
        }
    }
}

private extension BillingCycle {
    var abbreviation: String {
        switch self {
        case .monthly: "mo"
        case .yearly: "yr"
        case .custom: "cu"
        }
    }
}

private struct UsageBar: View {
    let snapshot: UsageSnapshot
    let resetCycle: QuotaResetCycle?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let limit = snapshot.limit, limit > 0 {
                let fraction = min(max(snapshot.used / limit, 0), 1)
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .tint(fraction >= 0.9 ? .red : (fraction >= 0.75 ? .orange : .accentColor))
                HStack(spacing: 6) {
                    Text("\(format(snapshot.used)) / \(format(limit)) \(snapshot.unit)")
                    if let resetCycle, resetCycle != .never {
                        Text("·").foregroundStyle(.tertiary)
                        Text("resets \(resetCycle.displayName.lowercased())")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    Text("\(format(snapshot.used)) \(snapshot.unit)")
                    if let resetCycle, resetCycle != .never {
                        Text("·").foregroundStyle(.tertiary)
                        Text("resets \(resetCycle.displayName.lowercased())")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }
}
