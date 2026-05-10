# Mia

> A native macOS menu-bar app for tracking subscriptions, spend, and provider usage.

[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)](#)
[![Swift](https://img.shields.io/badge/swift-5.10%2B-orange)](#)
[![License](https://img.shields.io/badge/license-MIT-green)](#license)

Mia lives in your menu bar. It tracks every recurring service you pay for,
warns before renewals, and pulls token / message usage from APIs that expose
it (Anthropic, OpenAI today). Local SwiftData store, Keychain-backed
secrets, no telemetry, no cloud.

```diagram
╭───────────────────────────────╮
│  Mia                       ⟳  │
│  $74.96 / month               │
├───────────────────────────────┤
│  💳 Anthropic   Pro    $20/mo │
│      Reset in 4 days   15/12  │
│  💳 OpenAI      Tier 2 $50/mo │
│      Reset in 9 days   01/01  │
│  💳 Spotify     Family $4.99  │
├───────────────────────────────┤
│  +    ⚙          Quit         │
╰───────────────────────────────╯
```

## Features

- Menu-bar popover with subscriptions, monthly total, and quota progress.
- Built-in providers: **Manual**, **Anthropic** (Admin Usage API),
  **OpenAI** (Org Usage API). Adding more is a one-file change.
- Renewal and quota notifications, debounced once per day.
- Parallel sync (`TaskGroup` + per-provider timeout).
- Launch-at-login via `SMAppService`.

## Build

Requires Xcode 15+ and macOS 14+.

```bash
brew install xcodegen
xcodegen generate
open Mia.xcodeproj            # ⌘R
```

Or from the command line:

```bash
xcodebuild -scheme Mia -configuration Debug -destination 'platform=macOS' build
xcodebuild test  -scheme Mia -destination 'platform=macOS'
```

## Usage

1. Click **+** to add a subscription. Pick a provider; for API-backed
   providers, paste an API key — it's stored in macOS Keychain under
   `com.likkee.<providerKey>`, never in the SwiftData store.
2. Click **⟳** to refresh, or wait for the launch-time sync.
3. Tune renewal-day and quota-percent thresholds in **⚙ Settings**.

Provider failures surface as a ⚠ on the affected row with the error in a
tooltip — they never crash the app.

## Architecture

```diagram
╭──────────────────────────────────────────────╮
│  MenuBarApp (NSStatusItem + NSPopover)       │
├──────────────────────────────────────────────┤
│  SubscriptionStore  (SwiftData)              │
│   • Subscription · UsageSnapshot             │
│   • ProviderCredential → Keychain            │
├──────────────────────────────────────────────┤
│  SyncEngine         (TaskGroup + timeout)    │
│  NotificationsService                        │
├──────────────────────────────────────────────┤
│  Provider protocol  →  implementations       │
│   • ManualProvider                           │
│   • AnthropicProvider                        │
│   • OpenAIProvider                           │
│   • <your provider>     ← open a PR          │
╰──────────────────────────────────────────────╯
```

| Layer | Responsibility |
|------|----------------|
| `MenuBar` | `NSStatusItem`, popover lifecycle |
| `Store` | SwiftData container, CRUD |
| `Sync` | Concurrent provider refresh |
| `Providers` | One file per service |
| `Security` | Keychain wrapper |
| `Notifications` | Renewal + quota alerts |

## Adding a Provider

The contribution surface is intentionally tiny:

> Copy a provider template, paste your fetch logic, append your type to one
> array, run the tests, open a PR.

Full recipe in **[`docs/ADDING_A_PROVIDER.md`](./docs/ADDING_A_PROVIDER.md)**.

Wanted: Spotify, GitHub Copilot, Cursor, Vercel, Linear, 1Password, Notion,
Figma, …

## Stack

Swift 5.10 · SwiftUI + AppKit · SwiftData · `URLSession` async/await ·
`UserNotifications` · `Security` (Keychain) · `SMAppService` · xcodegen.

No third-party runtime dependencies.

## Security

- Sandboxed; network entitlement only.
- API keys: Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- Hardened runtime; notarization planned for distribution.

## License

MIT — see [`LICENSE`](./LICENSE).
