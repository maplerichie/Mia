import SwiftUI

struct WelcomeView: View {
    let onAdd: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "creditcard.and.123")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 6) {
                Text("Welcome to Mia")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Your menu-bar companion for subscriptions and API usage.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "arrow.clockwise", title: "Auto-sync", description: "Pulls usage from 50+ providers in parallel.")
                featureRow(icon: "bell", title: "Smart alerts", description: "Warns before renewals and quota thresholds.")
                featureRow(icon: "lock", title: "Private by default", description: "Data stays on your Mac; keys live in Keychain.")
            }
            .padding(.horizontal, 12)

            VStack(spacing: 10) {
                Button(action: onAdd) {
                    Label("Add Your First Subscription", systemImage: "plus")
                        .font(.headline)
                }
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)

                Button("Maybe later") {
                    onDismiss()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 380)
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    WelcomeView(onAdd: {}, onDismiss: {})
}
