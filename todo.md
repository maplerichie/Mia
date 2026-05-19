# Mia — UI/UX & Feature Improvement Plan

> Guiding principle: Mia is a **quiet, local-first utility**. Every change should
> make the app feel more alive and trustworthy without adding complexity the user
> has to manage. No cloud, no accounts, no bloat.

---

## Phase 1 · Foundation Polish (the "it just works" pass) ✅

Small, high-confidence changes that eliminate rough edges. Each is ≤ 1 day.

### 1.1 Auto-sync on a timer ✅
- [x] Add a repeating background sync (default every 30 min, configurable in Settings).
- [x] Sync should fire silently — no UI flash unless data actually changed.
- [x] Surface a subtle "Last synced: 5 min ago" timestamp in the popover header (already tracked in `SyncEngine.lastSyncedAt`, just not displayed).

### 1.2 Renewal date auto-advance ✅
- [x] When `nextRenewalDate` is in the past, auto-roll it forward by the billing cycle until it's in the future.
- [x] Run this logic during sync and on app launch.

### 1.3 Provider-aware row icons ✅
- [x] Map each `providerKey` to a distinct SF Symbol (e.g. Anthropic → `brain.head.profile`, OpenAI → `sparkles`, Manual → `tag.fill`).
- [x] For manual subscriptions, let the user pick from a curated icon set (12 options).
- [x] Fall back to current `creditcard.fill` for unknown providers.

### 1.4 Keyboard shortcuts ✅
- [x] `⌘N` → Add subscription
- [x] `⌘R` → Refresh / sync all
- [x] `⌘,` → Settings
- [x] `⌘Q` → Quit
- [ ] Arrow key navigation in subscription list with `Enter` to edit. *(deferred — non-trivial focus management in popover-hosted list)*

### 1.5 Snapshot retention / pruning ✅
- [x] Keep max 90 days of `UsageSnapshot` per subscription.
- [x] Prune on each sync cycle, silently.

---

## Phase 2 · Information Density & Clarity

### 2.1 Usage sparkline ✅
- [x] Add a tiny 7-day sparkline to each subscription row that has usage history.
- [x] Use SwiftUI `Path` drawing — no charting library.
- [ ] Tap/hover tooltip with exact value + date. *(deferred — basic line shipped; tooltip pass later)*

### 2.2 Subscription detail popover / expandable row
- [ ] Clicking a subscription row expands inline or opens a detail popover.
- [ ] Detail view shows: full usage history chart (30 days), notes, API key status, raw cost breakdown, renewal countdown.

### 2.3 Menu bar cost badge (opt-in) ✅
- [x] In Settings, add a toggle: "Show monthly total in menu bar".
- [x] When enabled, the status item displays `$XX` next to the icon.
- [x] Respect the user's primary currency symbol.

### 2.4 Smarter empty state & onboarding (partial) ✅
- [x] Replace the bare "Click + to add one" with a warmer empty state with CTA.
- [x] Show a hint with link to the provider's API-key dashboard when the user picks a credentialed provider.
- [ ] Post-add toast. *(deferred)*

---

## Phase 3 · Settings & Control

### 3.1 Expanded Settings view ✅
- [x] **Sync interval** — picker: 15m / 30m / 1h / 2h / Manual only.
- [x] **Notifications** — master toggle + individual controls for renewal vs. quota. Warning + Open-Settings button when system denies.
- [x] **Currency** — explicit primary currency picker (instead of auto-detect).
- [x] **Appearance** — follow system / light / dark.
- [x] **About** — version number, GitHub link, "Made with ♥" one-liner.

### 3.2 Mixed-currency awareness ✅
- [x] When subscriptions span multiple currencies, show **per-currency subtotals** in the header (e.g. `$16.99/mo · €9.99/mo`).
- [x] Auto-detect picks the single common currency; mixed surfaces are shown explicitly. No live exchange rates.

### 3.3 Custom billing cycle interval ✅
- [x] When user selects "Custom" billing cycle, show "Every ___ months" stepper (1–36).
- [x] Use this value for monthly-total normalization and renewal auto-advance.

---

## Phase 4 · Data Portability & Safety *(deferred — needs a dedicated session)*

### 4.1 Export subscriptions
- [ ] `File → Export…` saves a JSON file with all subscriptions.
- [ ] Explicitly exclude API keys / credentials.

### 4.2 Import subscriptions
- [ ] `File → Import…` reads the exported JSON and upserts subscriptions.

---

## Phase 5 · New Providers *(deferred — each requires API research + token rate-limit testing)*

### 5.1 Priority providers
- [ ] Cursor, GitHub Copilot, Vercel, AWS Cost Explorer

### 5.2 Secondary providers
- [ ] Linear, 1Password, Notion, Figma

### 5.3 Provider health indicator ✅
- [x] Show a small colored dot on each row: green = OK, red = failed.

---

## Phase 6 · Delight

### 6.1 Popover adaptive height ✅
- [x] Dynamically size the popover to fit content: min 200pt, max 600pt.

### 6.2 Subtle sync animation ✅
- [x] During sync, animate the ↻ button with a slow rotation.
- [x] On completion, briefly flash a ✓ checkmark before reverting.

### 6.3 Renewal countdown in context ✅
- [x] For subscriptions renewing within 7 days, show "Renews in 3 days" as warm text.
- [x] For subscriptions renewing today, show "Renews today" in red.

### 6.4 Right-click quick actions ✅
- [x] Right-click a subscription row → context menu: Edit, Sync this one, Copy cost, Delete.
- [x] "Sync this one" refreshes only that provider.

---

*Last updated: 2026-05-19 — Phases 1, 3, 6 complete plus high-leverage items from 2 and 5. Phases 4 (import/export) and 5 (new provider integrations) intentionally deferred to dedicated sessions. All 32 tests passing.*
