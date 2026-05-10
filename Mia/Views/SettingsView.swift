import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Notifications") {
                    Stepper(
                        "Renewal warning: \(settings.renewalThresholdDays) day\(settings.renewalThresholdDays == 1 ? "" : "s") before",
                        value: $settings.renewalThresholdDays,
                        in: 0...30
                    )
                    Stepper(
                        "Quota warning at \(settings.quotaThresholdPercent)%",
                        value: $settings.quotaThresholdPercent,
                        in: 0...100,
                        step: 5
                    )
                }
                Section("General") {
                    Toggle("Launch at login", isOn: $settings.launchAtLogin)
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
        .frame(width: 360, height: 320)
    }
}
