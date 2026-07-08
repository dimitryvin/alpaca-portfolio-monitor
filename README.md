<p align="center">
  <img src="docs/icon.png" width="120" alt="Alpaca Monitor icon">
</p>

# Alpaca Portfolio Monitor

[![Release](https://github.com/dimitryvin/alpaca-portfolio-monitor/actions/workflows/release.yml/badge.svg)](https://github.com/dimitryvin/alpaca-portfolio-monitor/actions/workflows/release.yml)

A lightweight macOS **menu bar** app that shows your [Alpaca](https://alpaca.markets)
brokerage portfolio value and today's change at a glance. Click the menu bar item for a
popover with an equity chart, key stats, your open positions, and your trade history with
realized P/L.

A companion **iOS app** (built with [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture))
mirrors the same portfolio on your phone. Pair it in seconds by scanning a QR code the
Mac app shows — no retyping keys. See [iOS companion app](#ios-companion-app) below.

> **Read-only.** The app only issues `GET` requests to Alpaca and never places trades.

<p align="center">
  <img src="docs/menubar.png" height="24" alt="Menu bar value"><br><br>
  <img src="docs/portfolio.png" width="320" alt="Portfolio popover">
</p>

## Download

Install with [Homebrew](https://brew.sh):

```bash
brew install --cask dimitryvin/tap/alpaca-portfolio-monitor
```

Or grab the latest `.dmg` from [Releases](https://github.com/dimitryvin/alpaca-portfolio-monitor/releases),
open it, and drag the app to **Applications**. Builds are signed with a Developer ID and
notarized by Apple, so they open normally.

To build a release `.dmg` yourself: `scripts/release.sh 1.0.0` (add `--publish` to upload to GitHub).
To produce a signed + notarized build, set `SIGN_ID` and `NOTARY_PROFILE` first:

```bash
SIGN_ID="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE="AlpacaNotary" \
  scripts/release.sh 1.0.0 --publish
```

Or push a `v*` tag to build, sign, notarize, and publish automatically via GitHub Actions
(`.github/workflows/release.yml`). Configure the required secrets once with
`scripts/setup-ci-secrets.sh`, then `git tag v1.1.0 && git push origin v1.1.0`.

## Features

- Menu bar text: portfolio value + today's change %, tinted green/red
  (e.g. `$12,345  ▲1.2%`), shown immediately on launch.
- **Portfolio** tab:
  - Equity chart and a range picker (1D / 1W / 1M / 3M / 1Y / All).
  - Key stats: equity, today's P/L ($ and %), cash, buying power.
  - Positions list: market value and **unrealized P/L since entry** per holding.
- **Trades** tab: executed fills, newest first, with **realized P/L on sells**
  (computed from average-cost basis) and a total realized P/L.
- Auto-refreshes every 60 seconds, plus a manual refresh button.
- **Open at Login** toggle (via `SMAppService`).
- Credentials stored securely in the macOS Keychain (never logged).

## Requirements

- macOS 14+ (built on macOS 26 / Xcode 26, Swift 6).
- [XcodeGen](https://github.com/yonyz/XcodeGen): `brew install xcodegen`.
- A **live** Alpaca account API key + secret
  ([create one here](https://app.alpaca.markets/account/profile)).

## Build & run

```bash
# 1. Generate the Xcode project from project.yml
xcodegen generate

# 2. Build
xcodebuild -project AlpacaPortfolioMonitor.xcodeproj \
  -scheme AlpacaPortfolioMonitor -configuration Debug build

# 3. Launch the built app (path printed by the build under DerivedData),
#    or just open it in Xcode and press Run:
open AlpacaPortfolioMonitor.xcodeproj
```

On first launch a setup popover asks for your API Key ID and Secret. They are validated
with a single `GET /v2/account` call, then saved to the Keychain. Use the gear menu in the
popover to **Change API Keys** or **Quit**.

## Run tests

```bash
xcodebuild test -project AlpacaPortfolioMonitor.xcodeproj -scheme AlpacaPortfolioMonitor
```

## Notes

- The app is **live-only** (`https://api.alpaca.markets`).
- It runs as an agent app (no Dock icon) via `LSUIElement`.
- Local/automatic signing is sufficient for personal use.

## iOS companion app

`AlpacaMonitorMobile` is an iPhone app (SwiftUI + The Composable Architecture) that shows
the same Portfolio (equity chart, key stats, positions) and Trades (realized P/L) as the
Mac app. It shares the domain layer in `Shared/` with the Mac app — the models, the
read-only `AlpacaClient`, and the trade builder are compiled into both.

**Pairing.** On the Mac, open the popover → gear menu → **Connect iPhone…** to show a QR
code. In the iOS app, scan it. The QR carries your Alpaca API key/secret (a versioned JSON
payload, `Shared/Pairing/PairingPayload.swift`); the app validates them with a single
`GET /v2/account`, then stores them in the iOS Keychain. A manual key-entry fallback is
available (e.g. in the Simulator, which has no camera).

> **Keep the QR private.** It contains your API keys in plaintext. It's meant to be shown
> on your own screen and scanned by your own phone. Regenerate your Alpaca keys if exposed.

**Build & run (Simulator):**

```bash
xcodegen generate
xcodebuild build -scheme AlpacaMonitorMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipMacroValidation
xcodebuild test  -scheme AlpacaMonitorMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipMacroValidation
```

To preview the UI with canned data (no account needed), launch with `ALPACA_DEMO=1`
(DEBUG-only; stripped from release builds):

```bash
SIMCTL_CHILD_ALPACA_DEMO=1 xcrun simctl launch booted com.alpacamonitor.mobile
```

### TestFlight via Xcode Cloud

The iOS target is set up for [Xcode Cloud](https://developer.apple.com/xcode-cloud/):
`ci_scripts/ci_post_clone.sh` runs `xcodegen generate` after each clone (the `.xcodeproj`
is generated, not committed), and the `AlpacaMonitorMobile` scheme is shared. It signs
under personal team **`GFUCLJHK34`** with automatic signing (bundle id
`com.alpacamonitor.mobile`).

First-time setup (needs your App Store Connect login — one-time):

1. **Register the App ID** `com.alpacamonitor.mobile` under team `GFUCLJHK34`.
2. **Create the app record** in App Store Connect (name, bundle id, personal team).
3. In **Xcode → the project → Xcode Cloud tab**, create a workflow for the
   `AlpacaMonitorMobile` scheme with an **Archive → TestFlight (Internal Testing)** action,
   grant it access to this repo, and start a build. Xcode Cloud manages the distribution
   certificate/profile for you.

Subsequent builds: push to the configured branch (or tag) and the workflow builds, signs,
and delivers to TestFlight automatically.

## Project layout

```
project.yml                 XcodeGen spec (the .xcodeproj is generated, not committed)
Shared/                     Cross-platform domain, compiled into BOTH apps
  Models/                   Codable models, Credentials, chart range mapping
  Services/                 Read-only Alpaca client + trade builder
  Pairing/                  PairingPayload — the QR pairing codec
  Formatters.swift          Currency/percent formatting
Sources/                    macOS menu-bar app
  App/                      @main app + Info.plist
  Services/                 Keychain store, observable store, notifier, launch-at-login
  Views/                    Menu bar label, popover, chart, stats, positions, setup, QR
iOSApp/                     iOS companion app (TCA)
  App/                      @main app + Info.plist
  Client/                   AlpacaAPIClient + Keychain-backed CredentialsClient (deps)
  Features/                 App / Pairing / Dashboard / Portfolio / Trades reducers
  Views/                    Pairing, QR scanner, dashboard, chart, stats, trades
iOSAppTests/                TCA TestStore feature tests
Tests/                      macOS parsing/calculation tests + pairing codec test
ci_scripts/                 Xcode Cloud post-clone hook (runs xcodegen)
```
