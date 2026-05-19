import Foundation

/// Tiny lookup that powers the "where do I find my API key?" hint shown in
/// the Add/Edit form for credentialed providers.
enum ProviderHints {
    struct Hint {
        let text: String
        let url: URL?
    }

    static func apiKeyHint(for providerKey: String) -> Hint? {
        switch providerKey.lowercased() {
        case "anthropic":
            return Hint(
                text: "Create an admin key in console.anthropic.com → Settings.",
                url: URL(string: "https://console.anthropic.com/settings/keys")
            )
        case "openai":
            return Hint(
                text: "Create a key in platform.openai.com → API keys.",
                url: URL(string: "https://platform.openai.com/api-keys")
            )
        default:
            return nil
        }
    }
}
