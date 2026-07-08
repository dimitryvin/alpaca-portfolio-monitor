#!/bin/sh

# Xcode Cloud clones the repository without the generated `.xcodeproj` (it is
# gitignored and produced by XcodeGen). Regenerate it here, after the clone and
# before Xcode Cloud resolves packages and builds.

set -e

echo "Installing XcodeGen…"
brew install xcodegen

echo "Generating Xcode project…"
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate

echo "Done."
