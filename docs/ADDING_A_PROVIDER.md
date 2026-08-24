# Adding a Provider

Mia is built around a small `SubscriptionProvider` protocol. Anyone can ship
a new service in **three files** and a **single registration line** — no
runtime plugin host, no dynamic loading, no boilerplate generators. Source
is the contract.

This document covers the full recipe. There is no separate "plugin SDK" to
learn — every built-in provider (Manual, Anthropic, OpenAI) follows the same
template you'll use.

## TL;DR

1. Copy [`docs/templates/_TemplateProvider.swift.template`](./templates/_TemplateProvider.swift.template) to
   `Mia/Providers/<YourService>Provider.swift`. Rename the type, `key`, and
   `displayName`.
2. Implement `fetchPlan()` and/or `fetchUsage()` against the service's API
   using `URLSession` + `async/await`.
3. Append your type to [`ProviderRegistry.builtIns`](../Mia/Providers/ProviderRegistry.swift).
4. Copy [`docs/templates/_TemplateProviderTests.swift.template`](./templates/_TemplateProviderTests.swift.template)
   to `MiaTests/<YourService>ProviderTests.swift`, swap in real fixture JSON,
   and run `xcodebuild test -scheme Mia -destination 'platform=macOS'`.

That's it. Open a PR.

## Anatomy of a Provider

```swift
struct MyProvider: RegisterableProvider {
    static let key = "myservice"          // lowercase, persisted on Subscription
    static let displayName = "My Service" // shown in the picker
    let requiresCredential = true         // collects a credential via the UI

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .manual,     // or .localFile / .keychainItem / .browserCookie
            factory: { credential in MyProvider(apiKey: credential?.value ?? "") }
        )
    }

    private let apiKey: String
    init(apiKey: String) { self.apiKey = apiKey }

    func fetchPlan() async throws -> PlanInfo? { nil }      // return nil if N/A
    func fetchUsage() async throws -> UsageInfo? { … }      // throw on failure
}
```

Then register it once:

```swift
// Mia/Providers/ProviderRegistry.swift
static let builtIns: [any RegisterableProvider.Type] = [
    ManualProvider.self,
    AnthropicProvider.self,
    OpenAIProvider.self,
    MyProvider.self,        // ← add this line
]
```

## Conventions

| Concern             | Rule                                                                                          |
|---------------------|-----------------------------------------------------------------------------------------------|
| Networking          | `URLSession` + `async/await` only — **no** third-party HTTP clients. Use `ProviderHTTP.fetchJSON` for request + response validation + decoding. Inject `HTTPClient` for tests. |
| Money               | `Decimal`, never `Double`.                                                                    |
| Errors              | Throw `ProviderError`. Map upstream `401/403 → .invalidCredential`, `429 → .rateLimited`, decode failures → `.decoding(detail)`, transport → `.network(detail)`. |
| Hardcoded URLs      | Use `ProviderHTTP.hardcodedURL("https://...")` instead of force-unwrapping `URL(string:)`. |
| Secrets             | The framework writes the API key into Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) under service `com.likkee.<key>` keyed by the subscription UUID. The factory closure receives it as `secret`. |
| Concurrency         | Provider types are `Sendable`. No mutable shared state. `SyncEngine` calls each provider concurrently in a `TaskGroup` with a per-provider 15s timeout. |
| Naming              | `key` lowercase (`"anthropic"`); `displayName` as the user reads it (`"Anthropic"`).        |
| File layout         | One primary type per file, filename matches type. Tests mirror the source path under `MiaTests/`. |

## Credential sources

Providers declare how their credential is obtained via the `credentialSource`
parameter on `ProviderDescriptor`:

| Source | Meaning | UI behavior |
|---|---|---|
| `.manual` | User pastes an API key; stored in Mia's Keychain under `com.likkee.<key>`. | SecureField is required for new subscriptions. |
| `.localFile(path:keyPath:environmentOverride:)` | Reads an existing file from the Mac (e.g. `~/.codex/auth.json`). | No input required; a manual override is optional. |
| `.keychainItem(service:account:isGeneric:)` | Reads another app's Keychain item (e.g. Zed's editor session). | No input required; a manual override is optional. |
| `.browserCookie(browser:domains:cookieNames:)` | Reads a browser cookie (Firefox plaintext is supported; Chrome/Safari require manual Cookie header paste today). | SecureField for manual Cookie header is optional. |
| `.oauthDeviceFlow(OAuthDeviceFlowSource)` | OAuth 2.0 device-code flow (e.g. GitHub). | Opens a browser for user authorization and polls for a token. |

The `SyncEngine` resolves credentials through `CredentialResolverFactory` before
calling `fetchUsage()`. The resolved `ResolvedCredential` contains both the secret
value and an optional `account` (e.g. the Zed user ID) for providers that need an
identity header.

## Local-source providers (CodexBar-style)

For apps that leave credentials or session data on the Mac, Mia can read them
instead of asking the user to paste a key. Examples:

- **Codex** reads `~/.codex/auth.json` and calls `chatgpt.com/backend-api/wham/usage`.
- **Claude** reads `~/.claude/.credentials.json` and calls `api.anthropic.com/api/oauth/usage`.
- **Cursor** reads a browser Cookie header for `cursor.com` and calls `cursor.com/api/usage-summary`.
- **Zed** reads the Zed editor's Keychain item for `https://zed.dev` and calls `cloud.zed.dev/client/users/me`.

Local-source providers are registered the same way as API-key providers; only
the `credentialSource` differs. If you add a provider that reads a new directory,
add a corresponding sandbox temporary exception in `Mia/Mia.entitlements` or move
to a user-granted security-scoped bookmark in the future.

## What `fetchPlan()` vs `fetchUsage()` returns

| Method        | Return                                                                                                     | Example                                          |
|---------------|------------------------------------------------------------------------------------------------------------|--------------------------------------------------|
| `fetchPlan()` | `PlanInfo?` — name, cost, currency, billing cycle, next renewal date. Return `nil` if the API doesn't expose it. | OpenAI / Anthropic: `nil` (no public plan API).  |
| `fetchUsage()`| `UsageInfo?` — `used`, optional `limit`, free-form `unit` string (`"tokens"`, `"messages"`, `"GB"`, `"hours"`), `capturedAt`, raw payload for debugging. | Anthropic: sums tokens for the current UTC month. |

If both return `nil` (e.g. `ManualProvider`), the user enters everything by
hand on the row — that's a totally valid provider.

## Testing

Use the bundled [`StubHTTPClient`](../MiaTests/Support/StubHTTPClient.swift)
to inject canned responses. Every provider in the repo has a sibling
`*ProviderTests.swift`; follow [`AnthropicProviderTests.swift`](../MiaTests/AnthropicProviderTests.swift)
or the test template for the structure.

```bash
xcodegen generate
xcodebuild test -scheme Mia -destination 'platform=macOS'

# single test:
xcodebuild test -scheme Mia -destination 'platform=macOS' \
  -only-testing:MiaTests/MyProviderTests/testFetchUsageDecodes
```

## What about runtime / dylib plugins?

Mia is sandboxed and signed for distribution outside the App Store. macOS
makes runtime-loaded code controversial under hardened runtime + sandbox,
so the project deliberately treats *source contributions* as the plugin
mechanism: open a PR with your provider file + tests, get it reviewed, ship
it in the next signed build. This keeps every provider auditable and
debuggable, and means contributors don't need to ship their own signed
bundles.

## Checklist before opening a PR

- [ ] One file under `Mia/Providers/`, type conforms to `RegisterableProvider`.
- [ ] `key` is lowercase, unique, and stable (persisted in user data).
- [ ] `requiresCredential` is correct; the SecureField will appear or hide accordingly.
- [ ] `fetchUsage()` throws typed `ProviderError` cases for credential / rate-limit / network / decode failures.
- [ ] No `Double` for money. No third-party HTTP clients.
- [ ] Type appended to `ProviderRegistry.builtIns`.
- [ ] Sibling tests under `MiaTests/` using `StubHTTPClient`.
- [ ] `xcodebuild test -scheme Mia -destination 'platform=macOS'` passes.
