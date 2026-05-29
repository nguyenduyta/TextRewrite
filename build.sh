#!/bin/bash
set -e

APP_NAME="TextRewriter"
BUNDLE_ID="com.sharewis.textrewriter"
BUILD_DIR=".build/release"
APP_DIR="dist/${APP_NAME}.app"

echo "▶ Building Swift package..."
swift build -c release 2>&1

echo "▶ Creating app bundle..."
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Copy app icon if available
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICON_SRC="${SCRIPT_DIR}/Assets/AppIcon.icns"
if [ -f "$ICON_SRC" ]; then
  cp "$ICON_SRC" "${APP_DIR}/Contents/Resources/AppIcon.icns"
fi

cat > "${APP_DIR}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>Text Rewriter needs Accessibility access to detect selected text across apps.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "✅ Built: dist/${APP_NAME}.app"
echo ""
echo "To run:"
echo "  open dist/${APP_NAME}.app"
echo ""
echo "IMPORTANT: First run will prompt for Accessibility permission."
echo "  System Settings → Privacy & Security → Accessibility → enable TextRewriter"
