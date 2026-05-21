#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_SOURCE="$ROOT_DIR/build/ClipBar.app"
APP_DESTINATION="/Applications/ClipBar.app"

"$ROOT_DIR/Scripts/build_clipbar_app.sh"

if [[ -d "$APP_DESTINATION" ]]; then
    rm -rf "$APP_DESTINATION"
fi

cp -R "$APP_SOURCE" "$APP_DESTINATION"
xattr -dr com.apple.quarantine "$APP_DESTINATION" 2>/dev/null || true

open "$APP_DESTINATION"

echo "Installed: $APP_DESTINATION"
echo "If direct paste does not work, open System Settings > Privacy & Security > Accessibility and allow ClipBar."
