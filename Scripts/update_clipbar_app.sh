#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DESTINATION="/Applications/ClipBar.app"

if pgrep -x ClipBar >/dev/null 2>&1; then
    pkill -x ClipBar || true
    sleep 0.5
fi

"$ROOT_DIR/Scripts/install_clipbar_app.sh"

echo "Updated: $APP_DESTINATION"
echo "Keep using the /Applications version for the most stable permissions."
