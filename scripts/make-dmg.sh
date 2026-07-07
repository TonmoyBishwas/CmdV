#!/usr/bin/env bash
# Builds a drag-to-Applications DMG for CmdV.
# Usage: make-dmg.sh <path/to/CmdV.app> <output.dmg>
set -euo pipefail

APP="${1:?usage: make-dmg.sh <CmdV.app> <output.dmg>}"
OUT="${2:?usage: make-dmg.sh <CmdV.app> <output.dmg>}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"

if command -v create-dmg >/dev/null 2>&1; then
  # create-dmg exits 2 when it can't set the Finder icon layout (e.g. in a
  # headless session) even though the DMG was written — tolerate that.
  create-dmg \
    --volname "CmdV" \
    --background "$REPO_ROOT/assets/dmg-background.png" \
    --window-size 600 420 \
    --icon-size 110 \
    --icon "CmdV.app" 150 200 \
    --app-drop-link 450 200 \
    --no-internet-enable \
    "$OUT" \
    "$(dirname "$APP")/$(basename "$APP")" || [ -f "$OUT" ]
else
  echo "create-dmg not found — falling back to plain hdiutil (no background art)."
  STAGING="$(mktemp -d)"
  cp -R "$APP" "$STAGING/"
  ln -s /Applications "$STAGING/Applications"
  hdiutil create -volname "CmdV" -srcfolder "$STAGING" -ov -format UDZO "$OUT"
  rm -rf "$STAGING"
fi

echo "DMG written to $OUT"
