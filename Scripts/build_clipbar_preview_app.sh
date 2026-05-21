#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

CLIPBAR_APP_DISPLAY_NAME="ClipBar UI Preview" \
CLIPBAR_BUNDLE_IDENTIFIER="com.markz.clipbar.preview" \
CLIPBAR_STORAGE_APP_NAME="ClipBar-Preview" \
CLIPBAR_SKIP_BUILD="${CLIPBAR_SKIP_BUILD:-0}" \
CLIPBAR_APP_DIR="$ROOT_DIR/build/ClipBar UI Preview.app" \
"$ROOT_DIR/Scripts/build_clipbar_app.sh"
