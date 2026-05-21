#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CLIPBAR_CONFIGURATION:-release}"
APP_DISPLAY_NAME="${CLIPBAR_APP_DISPLAY_NAME:-ClipBar}"
BUNDLE_IDENTIFIER="${CLIPBAR_BUNDLE_IDENTIFIER:-com.markz.clipbar}"
STORAGE_APP_NAME="${CLIPBAR_STORAGE_APP_NAME:-ClipBar}"
APP_DIR="${CLIPBAR_APP_DIR:-$ROOT_DIR/build/$APP_DISPLAY_NAME.app}"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$MACOS_DIR/ClipBar"

cd "$ROOT_DIR"

if [[ "${CLIPBAR_SKIP_BUILD:-0}" != "1" ]]; then
    swift build -c "$CONFIGURATION" --product ClipBar
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/$CONFIGURATION/ClipBar" "$EXECUTABLE"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_DISPLAY_NAME</string>
    <key>CFBundleExecutable</key>
    <string>ClipBar</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_IDENTIFIER</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_DISPLAY_NAME</string>
    <key>ClipBarStorageAppName</key>
    <string>$STORAGE_APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>ClipBar 需要发送粘贴快捷键，把你选择的剪切板内容直接粘贴到前台 App。</string>
</dict>
</plist>
PLIST

SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/Apple Development|Developer ID Application/ { print $2; exit }')"

if [[ -n "$SIGNING_IDENTITY" ]]; then
    codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_DIR"
    echo "Signed with: $SIGNING_IDENTITY"
else
    codesign --force --deep --sign - "$APP_DIR"
    echo "Signed with: ad-hoc temporary signature"
    echo "Note: macOS may require Accessibility permission again after rebuilding."
fi

echo "$APP_DIR"
