#!/usr/bin/env bash
# One-time setup of a persistent "CmdV Signing" certificate (optional).
#
# Why: TCC keys the Accessibility grant on the app's code signature. Ad-hoc
# signatures change on every build/release, so the grant resets each time.
# A stable self-signed certificate gives the app a stable designated
# requirement, and the grant survives rebuilds and updates.
#
# macOS requires the certificate to be *trusted* for code signing, which
# cannot be fully automated without an admin GUI prompt — so this script
# guides you through Keychain Access's Certificate Assistant instead:
set -euo pipefail

if security find-identity -v -p codesigning | grep -q "CmdV Signing"; then
  echo "'CmdV Signing' already exists and is valid. Nothing to do."
  exit 0
fi

cat <<'EOF'
Create the certificate with Keychain Access (about 30 seconds):

  1. Open Keychain Access (it will open now).
  2. Menu bar: Keychain Access → Certificate Assistant → Create a Certificate…
  3. Name:            CmdV Signing
     Identity Type:   Self-Signed Root
     Certificate Type: Code Signing
  4. Click Create, then Done.

Afterwards, verify with:

  security find-identity -v -p codesigning | grep "CmdV Signing"

Release builds will then automatically use it (see scripts/release.sh).
EOF

open -a "Keychain Access"
