import SwiftUI

/// Renders the credential inputs and source-specific hints for the
/// Add/Edit subscription form.
struct CredentialSectionView: View {
    let source: CredentialSource
    let providerKey: String
    let editing: Subscription?
    @Binding var apiKey: String
    let apiKeyError: String?
    let manualLabel: String
    let localLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch source {
            case .manual, .browserCookie:
                SecureField(manualLabel, text: $apiKey)
                    .textContentType(.password)
            case .localFile, .keychainItem:
                SecureField(localLabel, text: $apiKey)
                    .textContentType(.password)
            case .oauthDeviceFlow(let flowSource):
                OAuthDeviceFlowSection(
                    source: flowSource,
                    credential: $apiKey,
                    hasExistingCredential: editing?.providerKey == providerKey && editing?.credential != nil
                )
            }

            if let hint = ProviderHints.hint(for: providerKey, source: source) {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text(hint.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let url = hint.url {
                        Link("Open", destination: url)
                            .font(.caption)
                    }
                }
            }

            switch source {
            case .localFile(let fileSource):
                Text("Reads from: \(fileSource.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .keychainItem(let keychainSource):
                Text("Reads Keychain item: \(keychainSource.service)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .browserCookie(let cookieSource):
                Text("Looks for cookie: \(cookieSource.cookieNames.joined(separator: ", ")) in \(cookieSource.browser.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .manual, .oauthDeviceFlow:
                EmptyView()
            }

            if let apiKeyError {
                Label(apiKeyError, systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }
}
