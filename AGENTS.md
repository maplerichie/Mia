# Mia — Open-source Subscription & Usage Tracker (macOS menu bar app)

See [README.md](./README.md) for full scope. Codebase is pre-implementation; this file pins the conventions.

## Build / Lint / Test
- Generate project (after editing `project.yml`): `xcodegen generate`
- Build (debug): `xcodebuild -scheme Mia -configuration Debug -destination 'platform=macOS' build`
- Run app: open `Mia.xcodeproj` in Xcode and ⌘R
- All tests: `xcodebuild test -scheme Mia -destination 'platform=macOS'`
- Single test: `xcodebuild test -scheme Mia -destination 'platform=macOS' -only-testing:MiaTests/<ClassName>/<testMethod>`
- Lint/format: `swiftformat .` and `swiftlint` (add configs at repo root once tooling is wired in)

## Architecture
- **Language/UI**: Swift 5.10+, SwiftUI popover + AppKit `NSStatusItem` menu bar entry. Target macOS 14+.
- **Layers**: `MenuBarApp` (NSStatusItem/NSPopover, AppDelegate) → `SubscriptionStore` (SwiftData `ModelContainer`) → `SyncEngine` (per-provider concurrent refresh with timeouts) → `Provider` protocol implementations registered in `ProviderRegistry`.
- **Models** (SwiftData): `Subscription`, `UsageSnapshot`, `ProviderCredential` (Keychain-backed). Decimal money, `Date` renewals.
- **Providers**: conform to `SubscriptionProvider` (`key`, `displayName`, `requiresCredential`, `fetchPlan()`, `fetchUsage()`). Built-ins also conform to `RegisterableProvider` and expose `static var descriptor`; add a new service by appending its type to `ProviderRegistry.builtIns` — see [docs/ADDING_A_PROVIDER.md](./docs/ADDING_A_PROVIDER.md). Built-ins today: Manual, Anthropic, OpenAI.
- **Networking**: `URLSession` + `async/await` only — no third-party HTTP clients.
- **Notifications**: `UNUserNotificationCenter` for renewal/quota alerts (debounced once/day/subscription).
- **Secrets**: Keychain via `Security` framework, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Sandboxed app, network-only entitlement, hardened runtime.

## Code Style
- Naming: `UpperCamelCase` types/protocols, `lowerCamelCase` vars/funcs, `SCREAMING_SNAKE_CASE` only for C-bridged constants. Provider keys are lowercase (`"anthropic"`).
- Imports: stdlib first, then Apple frameworks (`Foundation`, `SwiftUI`, `AppKit`, `SwiftData`, `Security`, `UserNotifications`), then SwiftPM deps; alphabetized within groups.
- Types: prefer `struct`/`enum` and value semantics; `actor` or `@MainActor` for shared mutable state; explicit types on public API; `Decimal` for money; never `Double` for currency.
- Async: `async/await` everywhere; no completion handlers; use `TaskGroup` for parallel provider sync with `Task.timeout`-style cancellation.
- Errors: define typed `enum ProviderError: Error`; throw, never return `nil` to mask failures; surface to UI as a row warning icon, never crash.
- SwiftUI: small composable views, `@Observable` models, no business logic in views; format currency via `Decimal.formatted(.currency(code:))`.
- Files: one primary type per file, filename matches type. Tests live in `MiaTests/` as `*Tests.swift` mirroring source paths.
