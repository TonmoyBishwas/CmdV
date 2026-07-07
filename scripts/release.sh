#!/usr/bin/env bash
# Builds, signs, packages, and publishes a CmdV release to GitHub.
# Usage: release.sh 1.0.0
#
# Signing: uses $CMDV_SIGN_IDENTITY if that identity exists in the keychain
# (e.g. "CmdV Signing" created via scripts/dev-sign-setup.sh, or a
# "Developer ID Application: ..." certificate — in which case notarization
# can be added below). Falls back to ad-hoc ("-"), which is fine for
# Gatekeeper (users right-click → Open either way) but resets the
# Accessibility grant on updates.
set -euo pipefail

VERSION="${1:?usage: release.sh <version>  (e.g. 1.0.0)}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

IDENTITY="${CMDV_SIGN_IDENTITY:-CmdV Signing}"
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
  echo "Signing identity '$IDENTITY' not found — using ad-hoc signature."
  IDENTITY="-"
fi

echo "==> Building CmdV $VERSION (Release)"
xcodegen generate
xcodebuild -project CmdV.xcodeproj -scheme CmdV -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build \
  MARKETING_VERSION="$VERSION" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_ALLOWED=NO \
  build

APP="build/Build/Products/Release/CmdV.app"

echo "==> Signing with identity: $IDENTITY"
codesign --force --options runtime --sign "$IDENTITY" "$APP"
codesign --verify --strict "$APP"

# To notarize with a Developer ID identity, uncomment:
#   ditto -c -k --keepParent "$APP" dist/CmdV.zip
#   xcrun notarytool submit dist/CmdV.zip --keychain-profile CmdV --wait
#   xcrun stapler staple "$APP"

echo "==> Creating DMG"
DMG="dist/CmdV-$VERSION.dmg"
./scripts/make-dmg.sh "$APP" "$DMG"

echo "==> Tagging v$VERSION"
git tag -f "v$VERSION"
git push -f origin "v$VERSION"

echo "==> Publishing GitHub release"
NOTES="$(sed "s/{VERSION}/$VERSION/g" scripts/release-notes-template.md)"
gh release create "v$VERSION" "$DMG" \
  --title "CmdV $VERSION" \
  --notes "$NOTES"

echo "==> Done: https://github.com/TonmoyBishwas/CmdV/releases/tag/v$VERSION"
