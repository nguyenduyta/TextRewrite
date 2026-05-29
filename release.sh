#!/bin/bash
set -e

APP_NAME="TextRewriter"
APP_PATH="dist/${APP_NAME}.app"
VERSION="${1:-1.0.0}"
OUT="dist/${APP_NAME}-${VERSION}.zip"

echo "▶ Building..."
bash "$(dirname "$0")/build.sh"

echo "▶ Ad-hoc signing..."
codesign --force --deep --sign - \
  --entitlements "$(dirname "$0")/Assets/TextRewriter.entitlements" \
  "$APP_PATH" 2>/dev/null || \
codesign --force --deep --sign - "$APP_PATH"

echo "▶ Verifying signature..."
codesign --verify --deep --strict "$APP_PATH" && echo "  Signature OK"

echo "▶ Packaging..."
cd dist
zip -qr "../${OUT}" "${APP_NAME}.app"
cd ..

echo ""
echo "✅ Release ready: ${OUT}"
echo "   Size: $(du -sh "$OUT" | cut -f1)"
echo ""
echo "Upload to GitHub Releases, users install by:"
echo "  1. Download & unzip"
echo "  2. Move TextRewriter.app to /Applications"
echo "  3. First launch: right-click → Open → Open (bypass Gatekeeper)"
echo "  4. Grant Accessibility in System Settings"
