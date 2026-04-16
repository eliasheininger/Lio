#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRODUCT="Whisk"
BUILD="${SCRIPT_DIR}/.build/release"
APP="${SCRIPT_DIR}/${PRODUCT}.app"
CONTENTS="${APP}/Contents"

echo "==> Building..."
swift build -c release --package-path "${SCRIPT_DIR}"

echo "==> Assembling ${PRODUCT}.app..."
rm -rf "${APP}"
mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources"

cp "${BUILD}/${PRODUCT}"                              "${CONTENTS}/MacOS/${PRODUCT}"
cp -r "${BUILD}/${PRODUCT}_${PRODUCT}.bundle"         "${CONTENTS}/Resources/"
cp "${SCRIPT_DIR}/${PRODUCT}/Resources/Info.plist"    "${CONTENTS}/Info.plist"

# Remove quarantine so Gatekeeper doesn't block the unsigned app.
# We intentionally skip codesign — ad-hoc signing changes the binary hash every
# build, causing macOS to revoke Accessibility permission on each rebuild.
# Without signing, TCC uses bundle ID + path as a stable identity, so you only
# need to grant Accessibility once.
xattr -cr "${APP}"

echo ""
echo "✓ Built: ${APP}"
echo "  Run: open '${APP}'"
echo ""
echo "  If this is the first run after changing the build:"
echo "  1. Open: System Settings → Privacy & Security → Accessibility"
echo "  2. Remove any old Whisk entry, then add ${APP}"
echo "  3. Re-open Whisk.app"
