import Foundation

/// Tiny lookup that powers the credential-source hint shown in the Add/Edit
/// form for providers that need a credential.
enum ProviderHints {
    struct Hint {
        let text: String
        let url: URL?
    }

    static func hint(for providerKey: String, source: CredentialSource) -> Hint? {
        switch source {
        case .manual:
            apiKeyHint(for: providerKey)
        case .localFile:
            localFileHint(for: providerKey)
        case .keychainItem:
            keychainHint(for: providerKey)
        case .browserCookie:
            browserCookieHint(for: providerKey)
        case .oauthDeviceFlow:
            oauthDeviceFlowHint(for: providerKey)
        }
    }

    // MARK: - API key hints

    private static let apiKeyHints: [String: Hint] = [
        "anthropic": Hint(
            text: "Create an admin key in console.anthropic.com → Settings.",
            url: URL(string: "https://console.anthropic.com/settings/keys")
        ),
        "openai": Hint(
            text: "Create a key in platform.openai.com → API keys.",
            url: URL(string: "https://platform.openai.com/api-keys")
        ),
        "openrouter": Hint(
            text: "Create a key in openrouter.ai → Keys.",
            url: URL(string: "https://openrouter.ai/keys")
        ),
        "deepseek": Hint(
            text: "Create a key in platform.deepseek.com → API keys.",
            url: URL(string: "https://platform.deepseek.com/api_keys")
        ),
        "elevenlabs": Hint(
            text: "Create a key in elevenlabs.io → API keys.",
            url: URL(string: "https://elevenlabs.io/app/settings/api-keys")
        ),
        "groqcloud": Hint(
            text: "Create a key in console.groq.com → API keys.",
            url: URL(string: "https://console.groq.com/keys")
        ),
        "poe": Hint(
            text: "Create a key in poe.com → API keys.",
            url: URL(string: "https://poe.com/api_keys")
        ),
        "moonshot": Hint(
            text: "Create a key in platform.moonshot.cn → API keys.",
            url: URL(string: "https://platform.moonshot.cn")
        ),
        "kimik2": Hint(
            text: "Create a key in kimi-k2.ai → API keys.",
            url: URL(string: "https://kimi-k2.ai")
        ),
        "venice": Hint(
            text: "Create a key in venice.ai → API keys.",
            url: URL(string: "https://venice.ai/settings/api")
        ),
        "crof": Hint(
            text: "Create a key in crof.ai → API keys.",
            url: URL(string: "https://crof.ai")
        ),
        "warp": Hint(
            text: "Create a key in warp.dev → API keys.",
            url: URL(string: "https://app.warp.dev/settings/api-keys")
        ),
        "chutes": Hint(
            text: "Create a key in chutes.ai → API keys.",
            url: URL(string: "https://chutes.ai/settings/api")
        ),
        "crossmodel": Hint(
            text: "Create a key in crossmodel.io → API keys.",
            url: URL(string: "https://crossmodel.io/settings/api")
        ),
        "clawrouter": Hint(
            text: "Create a key in clawrouter.com → API keys.",
            url: URL(string: "https://clawrouter.com/settings/api")
        ),
        "llmproxy": Hint(
            text: "Create a key in llmproxy.com → API keys.",
            url: URL(string: "https://app.llmproxy.com/settings/api")
        ),
        "synthetic": Hint(
            text: "Create a key in syntheticai.com → API keys.",
            url: URL(string: "https://syntheticai.com/settings/api")
        ),
        "zai": Hint(
            text: "Create a key in z.ai → API keys.",
            url: URL(string: "https://z.ai/settings/api")
        ),
        "deepgram": Hint(
            text: "Create a key in console.deepgram.com → API keys.",
            url: URL(string: "https://console.deepgram.com")
        ),
        "doubao": Hint(
            text: "Create a key in the Volcengine Doubao console.",
            url: URL(string: "https://console.volcengine.com/ark")
        ),
        "wayfinder": Hint(
            text: "Provide the API key for your local Wayfinder gateway.",
            url: nil
        ),
        "stepfun": Hint(
            text: "Create a key in the StepFun platform → API keys.",
            url: URL(string: "https://platform.stepfun.com")
        ),
        "awsbedrock": Hint(
            text: "Paste AWS credentials as accessKeyID:secretAccessKey.",
            url: URL(string: "https://docs.aws.amazon.com/bedrock/")
        ),
        "githubcopilot": Hint(
            text: "Paste a GitHub Copilot access token (use GitHubOAuthDeviceFlow to obtain one).",
            url: URL(string: "https://github.com/settings/tokens")
        )
    ]

    private static func apiKeyHint(for providerKey: String) -> Hint? {
        apiKeyHints[providerKey.lowercased()]
    }

    // MARK: - Local file hints

    private static let localFileHints: [String: Hint] = [
        "codex": Hint(
            text: "Sign in to the Codex CLI once so ~/.codex/auth.json exists.",
            url: URL(string: "https://github.com/openai/codex")
        ),
        "claude": Hint(
            text: "Sign in to Claude Code once so ~/.claude/.credentials.json exists.",
            url: URL(string: "https://claude.ai")
        ),
        "codebuff": Hint(
            text: "Run `codebuff login` once so ~/.config/manicode/credentials.json exists.",
            url: URL(string: "https://codebuff.com")
        )
    ]

    private static func localFileHint(for providerKey: String) -> Hint? {
        localFileHints[providerKey.lowercased()]
    }

    // MARK: - Keychain hints

    private static func keychainHint(for providerKey: String) -> Hint? {
        guard providerKey.lowercased() == "zed" else { return nil }
        return Hint(
            text: "Sign in to the Zed editor so its Keychain session is available.",
            url: URL(string: "https://zed.dev")
        )
    }

    // MARK: - Browser cookie hints

    private static let browserCookieHints: [String: Hint] = [
        "cursor": Hint(
            text: "Sign in to cursor.com, then copy the Cookie header from any cursor.com request.",
            url: URL(string: "https://cursor.com")
        ),
        "perplexity": Hint(
            text: "Sign in to perplexity.ai, then copy the Cookie header from any perplexity.ai request.",
            url: URL(string: "https://perplexity.ai")
        ),
        "mistral": Hint(
            text: "Sign in to console.mistral.ai, then copy the Cookie header from any mistral.ai request.",
            url: URL(string: "https://console.mistral.ai")
        ),
        "t3chat": Hint(
            text: "Sign in to t3.chat, then copy the Cookie header from any t3.chat request.",
            url: URL(string: "https://t3.chat")
        ),
        "ollama": Hint(
            text: "Sign in to ollama.com, then copy the Cookie header from any ollama.com request.",
            url: URL(string: "https://ollama.com")
        ),
        "manus": Hint(
            text: "Sign in to manus.im, then copy the Cookie header from any manus.im request.",
            url: URL(string: "https://manus.im")
        ),
        "devin": Hint(
            text: "Sign in to app.devin.ai, then copy the Cookie header from any devin.ai request.",
            url: URL(string: "https://app.devin.ai")
        ),
        "minimax": Hint(
            text: "Sign in to minimax.chat, then copy the Cookie header from any minimax.chat request.",
            url: URL(string: "https://minimax.chat")
        ),
        "commandcode": Hint(
            text: "Sign in to commandcode.ai, then copy the Cookie header from any commandcode.ai request.",
            url: URL(string: "https://commandcode.ai")
        ),
        "qoder": Hint(
            text: "Sign in to qoder.com, then copy the Cookie header from any qoder.com request.",
            url: URL(string: "https://qoder.com")
        ),
        "sakanaai": Hint(
            text: "Sign in to console.sakana.ai, then copy the Cookie header from any sakana.ai request.",
            url: URL(string: "https://console.sakana.ai")
        ),
        "abacusai": Hint(
            text: "Sign in to abacus.ai, then copy the Cookie header from any abacus.ai request.",
            url: URL(string: "https://abacus.ai")
        ),
        "xiaomimimo": Hint(
            text: "Sign in to platform.xiaomimimo.com, then copy the Cookie header from any xiaomimimo.com request.",
            url: URL(string: "https://platform.xiaomimimo.com")
        ),
        "opencode": Hint(
            text: "Sign in to opencode.ai, then copy the Cookie header from any opencode.ai request.",
            url: URL(string: "https://opencode.ai")
        ),
        "droidfactory": Hint(
            text: "Sign in to app.factory.ai, then copy the Cookie header from any factory.ai request.",
            url: URL(string: "https://app.factory.ai")
        ),
        "alibabacoding": Hint(
            text: "Sign in to developer.aliyun.com, then copy the Cookie header from any aliyun.com request.",
            url: URL(string: "https://developer.aliyun.com")
        ),
        "alibabatoken": Hint(
            text: "Sign in to developer.aliyun.com, then copy the Cookie header from any aliyun.com request.",
            url: URL(string: "https://developer.aliyun.com")
        ),
        "windsurf": Hint(
            text: "Sign in to windsurf.com, then copy the Cookie header from any windsurf.com request.",
            url: URL(string: "https://windsurf.com")
        ),
        "jetbrainsai": Hint(
            text: "Sign in to account.jetbrains.com, then copy the Cookie header from any jetbrains.com request.",
            url: URL(string: "https://account.jetbrains.com")
        ),
        "kilo": Hint(
            text: "Sign in to kilo.ai, then copy the Cookie header from any kilo.ai request.",
            url: URL(string: "https://kilo.ai")
        ),
        "opencodego": Hint(
            text: "Sign in to opencode.go, then copy the Cookie header from any opencode.go request.",
            url: URL(string: "https://opencode.go")
        )
    ]

    private static func browserCookieHint(for providerKey: String) -> Hint? {
        browserCookieHints[providerKey.lowercased()] ?? Hint(
            text: "Sign in via browser, then paste the relevant Cookie header.",
            url: nil
        )
    }

    // MARK: - OAuth device flow hints

    private static let oauthDeviceFlowHints: [String: Hint] = [
        "githubcopilot": Hint(
            text: "Sign in with GitHub to authorize Copilot access.",
            url: URL(string: "https://github.com/login/device")
        )
    ]

    private static func oauthDeviceFlowHint(for providerKey: String) -> Hint? {
        oauthDeviceFlowHints[providerKey.lowercased()] ?? Hint(
            text: "Sign in with your OAuth provider to authorize access.",
            url: nil
        )
    }

}
