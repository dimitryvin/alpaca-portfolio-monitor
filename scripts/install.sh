#!/usr/bin/env bash
# Builds a Release version of Alpaca Monitor and installs it to /Applications.
set -euo pipefail

cd "$(dirname "$0")/.."

project="AlpacaPortfolioMonitor.xcodeproj"
scheme="AlpacaPortfolioMonitor"
app_name="AlpacaPortfolioMonitor.app"
dest="/Applications/$app_name"

echo "Generating Xcode project..."
command -v xcodegen >/dev/null || { echo "xcodegen not found - run: brew install xcodegen"; exit 1; }
xcodegen generate >/dev/null

echo "Building Release..."
derived="$(mktemp -d)"
xcodebuild -project "$project" -scheme "$scheme" -configuration Release \
  -derivedDataPath "$derived" build >/dev/null

built="$derived/Build/Products/Release/$app_name"
if [ ! -d "$built" ]; then
  echo "Build product not found at $built"
  exit 1
fi

echo "Installing to $dest ..."
pkill -f "$app_name" 2>/dev/null || true
sleep 1
rm -rf "$dest"
cp -R "$built" "$dest"
rm -rf "$derived"

echo "Launching..."
open "$dest"
echo "Done. Installed Alpaca Monitor to /Applications and launched it."
echo "Enable 'Open at Login' from the gear menu in the popover to start on boot."
