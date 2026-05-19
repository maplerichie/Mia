import Foundation

/// Maps a `providerKey` (or a user-chosen manual icon name) to an SF Symbol
/// + accent tint. Keeping the lookup centralized so any new provider added
/// to `ProviderRegistry.builtIns` only needs one extra line here.
enum ProviderIcons {
    /// Curated icon palette offered when the user adds a manual subscription.
    /// Tuple: (storage key, SF Symbol name, human-readable label).
    static let manualPalette: [(key: String, symbol: String, label: String)] = [
        ("tag", "tag.fill", "Generic"),
        ("music", "music.note", "Music"),
        ("video", "play.rectangle.fill", "Video"),
        ("cloud", "icloud.fill", "Cloud"),
        ("code", "chevron.left.forwardslash.chevron.right", "Code"),
        ("chat", "bubble.left.and.bubble.right.fill", "Chat"),
        ("game", "gamecontroller.fill", "Games"),
        ("news", "newspaper.fill", "News"),
        ("book", "book.fill", "Reading"),
        ("fitness", "figure.run", "Fitness"),
        ("ai", "sparkles", "AI"),
        ("creditcard", "creditcard.fill", "Card")
    ]

    /// Resolve a provider key + optional manual icon override into an SF
    /// Symbol name.
    static func symbol(providerKey: String, iconAssetName: String? = nil) -> String {
        // Manual subscriptions: prefer user-picked icon from the palette.
        if providerKey == "manual", let key = iconAssetName,
           let entry = manualPalette.first(where: { $0.key == key }) {
            return entry.symbol
        }
        switch providerKey.lowercased() {
        case "anthropic": return "brain.head.profile"
        case "openai": return "sparkles"
        case "cursor": return "cursorarrow.rays"
        case "github-copilot", "github": return "chevron.left.forwardslash.chevron.right"
        case "vercel": return "triangle.fill"
        case "aws": return "server.rack"
        case "linear": return "line.diagonal"
        case "1password", "onepassword": return "key.fill"
        case "notion": return "doc.text.fill"
        case "figma": return "paintbrush.pointed.fill"
        case "manual": return "tag.fill"
        default: return "creditcard.fill"
        }
    }
}
