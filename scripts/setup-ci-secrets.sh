#!/usr/bin/env bash
# One-time setup of GitHub Actions secrets for the notarized release workflow
# (.github/workflows/release.yml).
#
# Prereqs:
#   - gh authenticated (gh auth status)
#   - A "Developer ID Application" .p12 exported from Keychain Access:
#       Keychain Access -> right-click the "Developer ID Application: ..." cert
#       -> Export... -> save as developer-id.p12 and set a password.
#
# Usage:
#   P12_PATH=developer-id.p12 P12_PASSWORD='p12-pass' \
#   NOTARY_APPLE_ID='you@email.com' NOTARY_TEAM_ID='TEAMID' \
#   NOTARY_PASSWORD='app-specific-pw' \
#   SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
#     scripts/setup-ci-secrets.sh
set -euo pipefail
cd "$(dirname "$0")/.."

: "${P12_PATH:?set P12_PATH to your exported Developer ID .p12}"
: "${P12_PASSWORD:?set P12_PASSWORD (the .p12 export password)}"
: "${NOTARY_APPLE_ID:?set NOTARY_APPLE_ID}"
: "${NOTARY_TEAM_ID:?set NOTARY_TEAM_ID}"
: "${NOTARY_PASSWORD:?set NOTARY_PASSWORD (app-specific password)}"
: "${SIGN_IDENTITY:?set SIGN_IDENTITY}"

command -v gh >/dev/null || { echo "gh not found - brew install gh"; exit 1; }
[ -f "$P12_PATH" ] || { echo "p12 not found: $P12_PATH"; exit 1; }

keychain_password="$(openssl rand -base64 24)"
repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
echo "Setting secrets on $repo ..."

base64 -i "$P12_PATH"            | gh secret set MACOS_CERT_P12_BASE64
printf '%s' "$P12_PASSWORD"      | gh secret set MACOS_CERT_PASSWORD
printf '%s' "$keychain_password" | gh secret set KEYCHAIN_PASSWORD
printf '%s' "$NOTARY_APPLE_ID"   | gh secret set NOTARY_APPLE_ID
printf '%s' "$NOTARY_TEAM_ID"    | gh secret set NOTARY_TEAM_ID
printf '%s' "$NOTARY_PASSWORD"   | gh secret set NOTARY_PASSWORD
printf '%s' "$SIGN_IDENTITY"     | gh secret set SIGN_IDENTITY

echo "Done. Trigger a release with:  git tag v1.1.0 && git push origin v1.1.0"
