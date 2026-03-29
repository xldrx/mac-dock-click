#!/bin/bash
set -euo pipefail

APP_NAME="DockClick"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "==> Cleaning build directory…"
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "==> Generating app icon…"
swift generate_icon.swift /tmp/dockclick_icon_1024.png
ICONSET="/tmp/DockClick.iconset"
rm -rf "$ICONSET" && mkdir "$ICONSET"
for spec in "16:icon_16x16" "32:icon_16x16@2x" "32:icon_32x32" "64:icon_32x32@2x" \
            "128:icon_128x128" "256:icon_128x128@2x" "256:icon_256x256" \
            "512:icon_256x256@2x" "512:icon_512x512" "1024:icon_512x512@2x"; do
    sz="${spec%%:*}"; name="${spec##*:}"
    sips -z "$sz" "$sz" /tmp/dockclick_icon_1024.png --out "$ICONSET/${name}.png" > /dev/null
done
iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET" /tmp/dockclick_icon_1024.png

echo "==> Compiling Swift sources…"
swiftc \
    Sources/main.swift \
    Sources/AppDelegate.swift \
    Sources/DockMonitor.swift \
    Sources/AboutWindowController.swift \
    -sdk "$(xcrun --show-sdk-path)" \
    -O \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "==> Copying Info.plist…"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"

echo "==> Signing with Developer ID…"
CERT="Developer ID Application: Sayed Hadi Hashemi (YW79ZL632W)"
codesign --force \
         --options runtime \
         --entitlements DockClick.entitlements \
         --sign "$CERT" \
         "$APP_BUNDLE"

echo "==> Notarizing…"
ditto -c -k --keepParent "$APP_BUNDLE" /tmp/DockClick_notarize.zip
xcrun notarytool submit /tmp/DockClick_notarize.zip \
    --keychain-profile "DockClick" \
    --wait
rm /tmp/DockClick_notarize.zip

echo "==> Stapling notarization ticket…"
xcrun stapler staple "$APP_BUNDLE"

echo ""
echo "✓  Built: $APP_BUNDLE"
echo ""
echo "Run now:"
echo "    open $APP_BUNDLE"
echo ""
echo "Or install to /Applications:"
echo "    cp -r $APP_BUNDLE /Applications/"
echo "    open /Applications/$APP_NAME.app"
echo ""
echo "NOTE: On first launch, macOS will prompt for Accessibility permission."
echo "      Grant it in System Settings → Privacy & Security → Accessibility,"
echo "      then relaunch the app."
