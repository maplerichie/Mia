import SwiftUI

/// Reusable OAuth device flow UI for providers that obtain an access token
/// interactively (e.g. GitHub Copilot). The resulting token is written to the
/// bound `credential` string so the parent Add/Edit form can store it in the
/// Keychain on save.
struct OAuthDeviceFlowSection: View {
    let source: OAuthDeviceFlowSource
    @Binding var credential: String
    let hasExistingCredential: Bool

    @State private var deviceCode: GitHubOAuthDeviceFlow.DeviceCode?
    @State private var flowError: String?
    @State private var flowTask: Task<Void, Never>?

    private var isConnected: Bool {
        !credential.isEmpty || hasExistingCredential
    }

    var body: some View {
        Group {
            if isConnected {
                connectedView
            } else if let deviceCode {
                authorizingView(deviceCode: deviceCode)
            } else {
                connectButton
            }
        }
        .onDisappear {
            cancelFlow()
        }
    }

    @ViewBuilder
    private var connectedView: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Connected to \(source.providerName)")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Reconnect") {
                credential = ""
                deviceCode = nil
                flowError = nil
                startFlow()
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func authorizingView(deviceCode: GitHubOAuthDeviceFlow.DeviceCode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Code:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(deviceCode.userCode)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(deviceCode.userCode, forType: .string)
                }
                .controlSize(.small)
            }
            Link("Open \(source.providerName) and enter the code", destination: deviceCode.verificationURI)
                .font(.caption)
            if flowError == nil {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Waiting for authorization...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        if let flowError {
            Label(flowError, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
        }
    }

    @ViewBuilder
    private var connectButton: some View {
        Button("Connect with \(source.providerName)") {
            startFlow()
        }
    }

    private func startFlow() {
        flowTask?.cancel()
        flowError = nil
        deviceCode = nil
        flowTask = Task {
            do {
                let flow = GitHubOAuthDeviceFlow(
                    clientID: source.clientID,
                    baseURL: source.baseURL
                )
                let code = try await flow.startDeviceFlow()
                await MainActor.run {
                    self.deviceCode = code
                }
                let token = try await flow.pollForToken(
                    deviceCode: code.deviceCode,
                    interval: code.interval
                )
                await MainActor.run {
                    credential = token.accessToken
                    deviceCode = nil
                    flowError = nil
                }
            } catch {
                await MainActor.run {
                    flowError = String(describing: error)
                    deviceCode = nil
                }
            }
        }
    }

    private func cancelFlow() {
        flowTask?.cancel()
        flowTask = nil
    }
}
