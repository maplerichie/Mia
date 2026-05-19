import SwiftUI

struct SubscriptionListView: View {
    @Bindable var store: SubscriptionStore
    @Bindable var syncEngine: SyncEngine
    let onAdd: () -> Void
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
                        recentSnapshots: store.recentSnapshots(for: subscription, days: 7),
                        status: syncEngine.statuses[subscription.id] ?? .idle,
                        onEdit: { onEdit(subscription) },
                        onDelete: { store.delete(subscription) }
                    )
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") { onEdit(subscription) }
                        Button("Sync this one", systemImage: "arrow.clockwise") {
                            Task { await syncEngine.syncOne(id: subscription.id) }
                        }
                        Button("Copy cost", systemImage: "doc.on.doc") {
                            let s = subscription.cost.formatted(.currency(code: subscription.currency))
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(s, forType: .string)
                        }
                        Divider()
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
        VStack(spacing: 12) {
            Image(systemName: "creditcard.and.123")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Track your first subscription")
                .font(.headline)
            Text("Stay on top of renewals and API usage — all stored locally.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(action: onAdd) {
                Label("Add Subscription", systemImage: "plus")
            }
            .controlSize(.regular)
            .keyboardShortcut("n", modifiers: [.command])
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }
}

private struct SubscriptionRow: View {
    let subscription: Subscription
    let latestUsage: UsageSnapshot?
    let recentSnapshots: [UsageSnapshot]
    let status: SyncStatus
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                healthDot
                    .frame(width: 8, height: 8)
                    .offset(x: 9, y: -9)
                Image(systemName: ProviderIcons.symbol(
                    providerKey: subscription.providerKey,
                    iconAssetName: subscription.iconAssetName
                ))
                .foregroundStyle(.primary)
                .frame(width: 22)
            }

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
                if recentSnapshots.count >= 2 {
                    Sparkline(snapshots: recentSnapshots)
                        .frame(height: 12)
                        .padding(.top, 2)
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
        let days = daysToRenewal
        switch days {
        case ..<0:
            return "Overdue"
        case 0:
            return "Renews today"
        case 1:
            return "Renews tomorrow"
        case 2...7:
            return "Renews in \(days) days"
        default:
            return subscription.nextRenewalDate.formatted(
                .dateTime.day(.twoDigits).month(.twoDigits).year()
                    .locale(Locale(identifier: "en_GB"))
            )
        }
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

    /// Persistent provider-health dot anchored to the icon.
    @ViewBuilder
    private var healthDot: some View {
        switch status {
        case .success:
            Circle().fill(.green).opacity(0.9)
        case .failure:
            Circle().fill(.red).opacity(0.9)
        case .syncing, .idle:
            Circle().fill(.clear)
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
        case 0: .red
        case 1...2: .orange
        case 3...7: .yellow
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

/// Tiny 7-day usage trend line. Pure SwiftUI `Path` — no charting deps.
private struct Sparkline: View {
    let snapshots: [UsageSnapshot]

    var body: some View {
        GeometryReader { geo in
            let values = snapshots.map(\.used)
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let range = max(maxV - minV, 0.0001)
            let stepX = values.count > 1 ? geo.size.width / CGFloat(values.count - 1) : 0
            Path { path in
                for (idx, value) in values.enumerated() {
                    let normalized = (value - minV) / range
                    let x = CGFloat(idx) * stepX
                    let y = geo.size.height * (1 - CGFloat(normalized))
                    if idx == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.accentColor.opacity(0.7), lineWidth: 1)
        }
        .help("7-day usage trend")
    }
}
