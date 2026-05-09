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
SOURCE_BUNDLE="$BUILD_DIR/DebugProcessWatcher_DebugProcessWatcher.bundle"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/Artifacts/Legacy/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$BUILD_DIR/DebugProcessWatcher" "$MACOS_DIR/DebugProcessWatcher"
cp -R "$SOURCE_BUNDLE" "$APP_DIR/"

if [[ -f "$SOURCE_BUNDLE/AppIcon.icns" ]]; then
  cp "$SOURCE_BUNDLE/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

chmod +x "$MACOS_DIR/DebugProcessWatcher"

# Ad-hoc sign all nested bundles and the main app (required for macOS 15+)
codesign --force --deep --sign - "$APP_DIR/DebugProcessWatcher_DebugProcessWatcher.bundle"
codesign --force --deep --sign - "$APP_DIR"
