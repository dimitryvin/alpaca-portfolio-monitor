#!/usr/bin/env bash
# Builds a Release .app, packages it as a drag-to-Applications .dmg, and
# (optionally) publishes a GitHub Release with the .dmg attached.
#
# Usage:
#   scripts/release.sh 1.0.0            # just build AlpacaMonitor-1.0.0.dmg
#   scripts/release.sh 1.0.0 --publish  # also tag + create the GitHub release
set -euo pipefail

cd "$(dirname "$0")/.."

version="${1:-}"
if [ -z "$version" ]; then
  echo "usage: scripts/release.sh <version> [--publish]   e.g. scripts/release.sh 1.0.0"
  exit 1
fi
tag="v$version"

project="AlpacaPortfolioMonitor.xcodeproj"
scheme="AlpacaPortfolioMonitor"
app_name="AlpacaPortfolioMonitor.app"
volume="Alpaca Monitor"
dmg="AlpacaMonitor-$version.dmg"

command -v xcodegen >/dev/null || { echo "install xcodegen: brew install xcodegen"; exit 1; }

echo "==> Generating project + building Release"
xcodegen generate >/dev/null
derived="$(mktemp -d)"
xcodebuild -project "$project" -scheme "$scheme" -configuration Release \
  -derivedDataPath "$derived" build >/dev/null
built="$derived/Build/Products/Release/$app_name"
[ -d "$built" ] || { echo "build product missing at $built"; exit 1; }

echo "==> Staging .dmg layout (app + Applications symlink)"
stage="$(mktemp -d)"
cp -R "$built" "$stage/"
ln -s /Applications "$stage/Applications"

echo "==> Creating $dmg"
rm -f "$dmg"
hdiutil create -volname "$volume" -srcfolder "$stage" -ov -format UDZO "$dmg" >/dev/null
rm -rf "$derived" "$stage"
echo "    built $(du -h "$dmg" | cut -f1) -> $dmg"

if [ "${2:-}" = "--publish" ]; then
  command -v gh >/dev/null || { echo "install gh to publish: brew install gh"; exit 1; }
  echo "==> Tagging $tag and creating GitHub release"
  git tag -f "$tag"
  git push -f origin "$tag"
  notes=$(cat <<'NOTES'
Read-only macOS menu bar app for monitoring your Alpaca portfolio.

### Install
1. Open the .dmg and drag **AlpacaPortfolioMonitor** to **Applications**.
2. This build is not notarized, so macOS Gatekeeper blocks it the first time.
   Right-click the app in Applications, choose **Open**, then **Open** again, or run:
   `xattr -dr com.apple.quarantine /Applications/AlpacaPortfolioMonitor.app`
3. Launch it, enter your Alpaca **live** API key + secret, and (optionally) enable
   **Open at Login** from the gear menu.
NOTES
)
  if gh release view "$tag" >/dev/null 2>&1; then
    gh release upload "$tag" "$dmg" --clobber
  else
    gh release create "$tag" "$dmg" --title "$volume $version" --notes "$notes"
  fi
  echo "==> Published: $(gh release view "$tag" --json url -q .url)"
fi

echo "Done."
