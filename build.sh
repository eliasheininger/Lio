#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Lio"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"

echo "→ Building release binary..."
swift build -c release

BINARY=".build/release/$APP_NAME"
RESOURCE_BUNDLE=".build/release/${APP_NAME}_${APP_NAME}.bundle"

echo "→ Assembling $APP_NAME.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Executable
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Info.plist
cp "Lio/Shared/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# ── App icon ─────────────────────────────────────────────────────────────────
PNG_SRC="Lio/Shared/Resources/LioApp.png"
if [ -f "$PNG_SRC" ]; then
    ICONSET=$(mktemp -d)/AppIcon.iconset
    mkdir -p "$ICONSET"
    for size in 16 32 64 128 256 512; do
        sips -z $size $size "$PNG_SRC" --out "$ICONSET/icon_${size}x${size}.png"     > /dev/null 2>&1
        double=$((size * 2))
        sips -z $double $double "$PNG_SRC" --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null 2>&1
    done
    iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    rm -rf "$(dirname "$ICONSET")"
    echo "  ✓ Generated AppIcon.icns from Lio.png"
else
    echo "  ⚠ No Lio.png found — app will have no Dock icon"
fi

# ── Resource bundle (contains Lio.svg) ───────────────────────────────────────
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -r "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
    echo "  ✓ Copied resource bundle"
else
    cp "Lio/Shared/Resources/Lio.svg" "$APP_BUNDLE/Contents/Resources/Lio.svg"
    echo "  ✓ Copied Lio.svg directly"
fi

echo ""
echo "✓ Done: $APP_BUNDLE"
echo ""
echo "To distribute:"
echo "  zip -r Lio.zip Lio.app && open ."
echo ""
echo "Testers: right-click → Open on first launch to bypass Gatekeeper"
