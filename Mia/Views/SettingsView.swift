import SwiftUI
import UserNotifications
import AppKit

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Binding var isPresented: Bool
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private var bundleVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Sync") {
                    Picker("Sync interval", selection: $settings.syncIntervalMinutes) {
                        ForEach(AppSettings.syncIntervalChoices, id: \.self) { minutes in
                            Text(label(forMinutes: minutes)).tag(minutes)
                        }
                    }
                }

                Section("Notifications") {
                    Toggle("Enable notifications", isOn: $settings.notificationsEnabled)
                    Toggle("Renewal alerts", isOn: $settings.renewalAlertsEnabled)
                        .disabled(!settings.notificationsEnabled)
                    Toggle("Quota alerts", isOn: $settings.quotaAlertsEnabled)
                        .disabled(!settings.notificationsEnabled)
                    Stepper(
                        "Renewal warning: \(settings.renewalThresholdDays) day\(settings.renewalThresholdDays == 1 ? "" : "s") before",
                        value: $settings.renewalThresholdDays,
                        in: 0...30
                    )
                    .disabled(!settings.notificationsEnabled || !settings.renewalAlertsEnabled)
                    Stepper(
                        "Quota warning at \(settings.quotaThresholdPercent)%",
                        value: $settings.quotaThresholdPercent,
                        in: 0...100,
                        step: 5
                    )
                    .disabled(!settings.notificationsEnabled || !settings.quotaAlertsEnabled)
                    if notificationStatus == .denied {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Notifications are disabled in System Settings.")
                                .font(.caption)
                            Spacer()
                            Button("Open Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .controlSize(.small)
                        }
                    }
                }

                Section("Display") {
                    Toggle("Show monthly total in menu bar", isOn: $settings.showMenuBarTotal)
                    Picker("Primary currency", selection: $settings.primaryCurrencyOverride) {
                        Text("Auto-detect").tag("")
                        ForEach(CurrencyCatalog.common) { entry in
                            Text("\(entry.code) — \(entry.name)").tag(entry.code)
                        }
                    }
                    Picker("Appearance", selection: $settings.appearance) {
                        ForEach(AppearancePreference.allCases) { pref in
                            Text(pref.displayName).tag(pref)
                        }
                    }
                }

                Section("General") {
                    Toggle("Launch at login", isOn: $settings.launchAtLogin)
                }

                Section("About") {
                    HStack {
                        Text("Mia")
                        Spacer()
                        Text(bundleVersion).foregroundStyle(.secondary)
                    }
                    Link("GitHub", destination: URL(string: "https://github.com/maplerichie/mia")!)
                    Text("Made with ♥ — your data stays on this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 420, height: 540)
        .task {
            notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }
    }

    private func label(forMinutes minutes: Int) -> String {
        switch minutes {
        case 0: return "Manual only"
        case let m where m < 60: return "Every \(m) min"
        case 60: return "Every hour"
        case let m: return "Every \(m / 60) hours"
        }
    }
}
