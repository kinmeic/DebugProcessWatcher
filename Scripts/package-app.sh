#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-debug}"
OUTPUT_APP_DIR="${OUTPUT_APP_DIR:-$ROOT_DIR/Artifacts/DebugProcessWatcher.app}"
BUILD_DIR="$(swift build --package-path "$ROOT_DIR" --configuration "$BUILD_CONFIGURATION" --show-bin-path)"
APP_DIR="$OUTPUT_APP_DIR"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SOURCE_DIR="$ROOT_DIR/Sources/DebugProcessWatcher/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/Artifacts/Legacy/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$BUILD_DIR/DebugProcessWatcher" "$MACOS_DIR/DebugProcessWatcher"

# Copy menu bar icon resources directly into Contents/Resources (no nested bundle)
mkdir -p "$RESOURCES_DIR/MenuBarIcon.imageset"
cp "$SOURCE_DIR/Assets.xcassets/MenuBarIcon.imageset/menu_icon_24.png" "$RESOURCES_DIR/MenuBarIcon.imageset/"
cp "$SOURCE_DIR/Assets.xcassets/MenuBarIcon.imageset/menu_icon_48.png" "$RESOURCES_DIR/MenuBarIcon.imageset/"

if [[ -f "$SOURCE_DIR/AppIcon.icns" ]]; then
  cp "$SOURCE_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

chmod +x "$MACOS_DIR/DebugProcessWatcher"

# Ad-hoc sign the main app (no nested bundles to sign separately)
codesign --force --sign - "$APP_DIR"