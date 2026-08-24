import Foundation

/// Maps a `providerKey` (or a user-chosen manual icon name) to an SF Symbol
/// + accent tint. Keeping the lookup centralized so any new provider added
/// to `ProviderRegistry.builtIns` only needs one extra line here.
enum ProviderIcons {
    /// Curated icon palette offered when the user adds a manual subscription.
    struct ManualIcon: Equatable, Sendable {
        let key: String
        let symbol: String
        let label: String
    }

    static let manualPalette: [ManualIcon] = [
        ManualIcon(key: "tag", symbol: "tag.fill", label: "Generic"),
        ManualIcon(key: "music", symbol: "music.note", label: "Music"),
        ManualIcon(key: "video", symbol: "play.rectangle.fill", label: "Video"),
        ManualIcon(key: "cloud", symbol: "icloud.fill", label: "Cloud"),
        ManualIcon(key: "code", symbol: "chevron.left.forwardslash.chevron.right", label: "Code"),
        ManualIcon(key: "chat", symbol: "bubble.left.and.bubble.right.fill", label: "Chat"),
        ManualIcon(key: "game", symbol: "gamecontroller.fill", label: "Games"),
        ManualIcon(key: "news", symbol: "newspaper.fill", label: "News"),
        ManualIcon(key: "book", symbol: "book.fill", label: "Reading"),
        ManualIcon(key: "fitness", symbol: "figure.run", label: "Fitness"),
        ManualIcon(key: "ai", symbol: "sparkles", label: "AI"),
        ManualIcon(key: "creditcard", symbol: "creditcard.fill", label: "Card")
    ]

    private static let symbolMap: [String: String] = [
        "anthropic": "brain.head.profile",
        "claude": "brain.head.profile",
        "deepseek": "brain.head.profile",
        "devin": "brain.head.profile",
        "minimax": "brain.head.profile",
        "openai": "sparkles",
        "codex": "sparkles",
        "codebuff": "sparkles",
        "groqcloud": "sparkles",
        "poe": "sparkles",
        "venice": "sparkles",
        "ollama": "sparkles",
        "chutes": "sparkles",
        "cursor": "cursorarrow.rays",
        "commandcode": "cursorarrow.rays",
        "github-copilot": "chevron.left.forwardslash.chevron.right",
        "githubcopilot": "chevron.left.forwardslash.chevron.right",
        "github": "chevron.left.forwardslash.chevron.right",
        "vercel": "triangle.fill",
        "aws": "server.rack",
        "awsbedrock": "server.rack",
        "linear": "line.diagonal",
        "1password": "key.fill",
        "onepassword": "key.fill",
        "notion": "doc.text.fill",
        "figma": "paintbrush.pointed.fill",
        "perplexity": "bubble.left.and.bubble.right.fill",
        "t3chat": "bubble.left.and.bubble.right.fill",
        "manus": "bubble.left.and.bubble.right.fill",
        "qoder": "bubble.left.and.bubble.right.fill",
        "sakanaai": "bubble.left.and.bubble.right.fill",
        "opencode": "bubble.left.and.bubble.right.fill",
        "droidfactory": "bubble.left.and.bubble.right.fill",
        "windsurf": "bubble.left.and.bubble.right.fill",
        "mistral": "wind",
        "openrouter": "network",
        "elevenlabs": "waveform",
        "deepgram": "waveform",
        "moonshot": "moon.fill",
        "kimik2": "k.square",
        "crof": "c.square",
        "crossmodel": "x.square",
        "clawrouter": "arrow.triangle.branch",
        "llmproxy": "network",
        "synthetic": "s.circle",
        "zai": "z.square",
        "warp": "bolt.horizontal.circle",
        "doubao": "d.circle",
        "wayfinder": "location.north.line",
        "abacusai": "cpu",
        "xiaomimimo": "m.square",
        "alibabacoding": "a.square",
        "alibabatoken": "a.square",
        "jetbrainsai": "j.square",
        "kilo": "k.circle",
        "opencodego": "o.square",
        "stepfun": "s.square",
        "zed": "z.square",
        "manual": "tag.fill"
    ]

    /// Resolve a provider key + optional manual icon override into an SF
    /// Symbol name.
    static func symbol(providerKey: String, iconAssetName: String? = nil) -> String {
        if providerKey == "manual", let key = iconAssetName,
           let entry = manualPalette.first(where: { $0.key == key }) {
            return entry.symbol
        }
        return symbolMap[providerKey.lowercased()] ?? "creditcard.fill"
    }
}
