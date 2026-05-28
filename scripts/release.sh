#!/usr/bin/env bash
# Builds a Release .app, packages it as a drag-to-Applications .dmg, and
# (optionally) publishes a GitHub Release with the .dmg attached.
#
# Notarization is automatic when both env vars are set:
#   SIGN_ID         e.g. "Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE  a notarytool keychain profile (see: xcrun notarytool store-credentials)
# When unset, it produces an unsigned ad-hoc .dmg (works locally, Gatekeeper-warned).
#
# Usage:
#   scripts/release.sh 1.1.0                       # build dmg only
#   scripts/release.sh 1.1.0 --publish             # build + GitHub release
#   SIGN_ID="..." NOTARY_PROFILE="AlpacaNotary" \
#     scripts/release.sh 1.1.0 --publish           # signed + notarized + published
set -euo pipefail

cd "$(dirname "$0")/.."

version="${1:-}"
if [ -z "$version" ]; then
  echo "usage: scripts/release.sh <version> [--publish]   e.g. scripts/release.sh 1.1.0"
  exit 1
fi
tag="v$version"

project="AlpacaPortfolioMonitor.xcodeproj"
scheme="AlpacaPortfolioMonitor"
app_name="AlpacaPortfolioMonitor.app"
volume="Alpaca Monitor"
dmg="AlpacaMonitor-$version.dmg"

sign_id="${SIGN_ID:-}"
notary_profile="${NOTARY_PROFILE:-}"
notarize=false
[ -n "$sign_id" ] && [ -n "$notary_profile" ] && notarize=true

command -v xcodegen >/dev/null || { echo "install xcodegen: brew install xcodegen"; exit 1; }

echo "==> Generating project + building Release"
xcodegen generate >/dev/null
derived="$(mktemp -d)"
xcodebuild -project "$project" -scheme "$scheme" -configuration Release \
  -derivedDataPath "$derived" build >/dev/null
app="$derived/Build/Products/Release/$app_name"
[ -d "$app" ] || { echo "build product missing at $app"; exit 1; }

if $notarize; then
  echo "==> Signing app with Developer ID"
  codesign --force --options runtime --timestamp --sign "$sign_id" "$app"
  codesign --verify --strict "$app"
  echo "==> Notarizing app (waiting)"
  ditto -c -k --keepParent "$app" "$derived/app.zip"
  xcrun notarytool submit "$derived/app.zip" --keychain-profile "$notary_profile" --wait
  xcrun stapler staple "$app"
else
  echo "==> SIGN_ID/NOTARY_PROFILE not set: building unsigned ad-hoc .dmg"
fi

echo "==> Creating $dmg"
stage="$(mktemp -d)"
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"
rm -f "$dmg"
hdiutil create -volname "$volume" -srcfolder "$stage" -ov -format UDZO "$dmg" >/dev/null

if $notarize; then
  echo "==> Signing + notarizing dmg (waiting)"
  codesign --force --timestamp --sign "$sign_id" "$dmg"
  xcrun notarytool submit "$dmg" --keychain-profile "$notary_profile" --wait
  xcrun stapler staple "$dmg"
  spctl -a -t open --context context:primary-signature -v "$dmg" || true
fi

rm -rf "$derived" "$stage"
echo "    built $(du -h "$dmg" | cut -f1) -> $dmg"

if [ "${2:-}" = "--publish" ]; then
  command -v gh >/dev/null || { echo "install gh to publish: brew install gh"; exit 1; }
  echo "==> Tagging $tag and creating GitHub release"
  git tag -f "$tag"
  git push -f origin "$tag"
  if $notarize; then
    notes=$(cat <<'NOTES'
Read-only macOS menu bar app for monitoring your Alpaca portfolio.

This build is signed with a Developer ID and notarized by Apple, so it opens normally.

### Install
1. Open the .dmg and drag **AlpacaPortfolioMonitor** to **Applications**.
2. Launch it, enter your Alpaca **live** API key + secret, and (optionally) enable
   **Open at Login** from the gear menu.
NOTES
)
  else
    notes=$(cat <<'NOTES'
Read-only macOS menu bar app for monitoring your Alpaca portfolio.

### Install
1. Open the .dmg and drag **AlpacaPortfolioMonitor** to **Applications**.
2. This build is not notarized, so the first launch is blocked by Gatekeeper.
   Right-click the app in Applications, choose **Open**, then **Open** again, or run:
   `xattr -dr com.apple.quarantine /Applications/AlpacaPortfolioMonitor.app`
3. Launch it, enter your Alpaca **live** API key + secret.
NOTES
)
  fi
  if gh release view "$tag" >/dev/null 2>&1; then
    gh release upload "$tag" "$dmg" --clobber
  else
    gh release create "$tag" "$dmg" --title "$volume $version" --notes "$notes"
  fi
  echo "==> Published: $(gh release view "$tag" --json url -q .url)"
fi

echo "Done."
