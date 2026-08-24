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
                Section {
                    Picker(selection: $settings.syncIntervalMinutes) {
                        ForEach(AppSettings.syncIntervalChoices, id: \.self) { minutes in
                            Text(label(forMinutes: minutes)).tag(minutes)
                        }
                    } label: {
                        Label("Sync interval", systemImage: "arrow.clockwise")
                    }
                } header: {
                    sectionHeader("Sync", icon: "arrow.clockwise")
                }

                Section {
                    Toggle(isOn: $settings.notificationsEnabled) {
                        Label("Enable notifications", systemImage: "bell")
                    }
                    Toggle(isOn: $settings.renewalAlertsEnabled) {
                        Label("Renewal alerts", systemImage: "calendar.badge.exclamationmark")
                    }
                    .disabled(!settings.notificationsEnabled)
                    Toggle(isOn: $settings.quotaAlertsEnabled) {
                        Label("Quota alerts", systemImage: "chart.bar.fill")
                    }
                    .disabled(!settings.notificationsEnabled)
                    Stepper(
                        value: $settings.renewalThresholdDays,
                        in: 0...30
                    ) {
                        Label(
                            "Renewal warning: \(settings.renewalThresholdDays) day\(settings.renewalThresholdDays == 1 ? "" : "s") before",
                            systemImage: "exclamationmark.bubble"
                        )
                    }
                    .disabled(!settings.notificationsEnabled || !settings.renewalAlertsEnabled)
                    Stepper(
                        value: $settings.quotaThresholdPercent,
                        in: 0...100,
                        step: 5
                    ) {
                        Label(
                            "Quota warning at \(settings.quotaThresholdPercent)%",
                            systemImage: "percent"
                        )
                    }
                    .disabled(!settings.notificationsEnabled || !settings.quotaAlertsEnabled)
                    if notificationStatus == .denied {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .padding(.top, 2)
                            Text("Notifications are disabled in System Settings. Enable them to receive renewal and quota alerts.")
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
                } header: {
                    sectionHeader("Notifications", icon: "bell")
                }

                Section {
                    Toggle(isOn: $settings.showMenuBarTotal) {
                        Label("Show monthly total in menu bar", systemImage: "menubar.rectangle")
                    }
                    Picker(selection: $settings.primaryCurrencyOverride) {
                        Text("Auto-detect").tag("")
                        ForEach(CurrencyCatalog.common) { entry in
                            Text("\(entry.code) — \(entry.name)").tag(entry.code)
                        }
                    } label: {
                        Label("Primary currency", systemImage: "dollarsign.circle")
                    }
                    Picker(selection: $settings.appearance) {
                        ForEach(AppearancePreference.allCases) { pref in
                            Text(pref.displayName).tag(pref)
                        }
                    } label: {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                } header: {
                    sectionHeader("Display", icon: "display")
                }

                Section {
                    Toggle(isOn: $settings.launchAtLogin) {
                        Label("Launch at login", systemImage: "power")
                    }
                } header: {
                    sectionHeader("General", icon: "gear")
                }

                Section {
                    HStack {
                        Label("Mia", systemImage: "creditcard.and.123")
                        Spacer()
                        Text(bundleVersion).foregroundStyle(.secondary)
                    }
                    if let githubURL = URL(string: "https://github.com/maplerichie/mia") {
                        Link(destination: githubURL) {
                            Label("GitHub", systemImage: "link")
                        }
                    }
                    Text("Made with ♥ — your data stays on this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    sectionHeader("About", icon: "info.circle")
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

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(.primary)
            .textCase(nil)
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
