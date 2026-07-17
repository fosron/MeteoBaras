#!/bin/bash
set -e

SRC_DIR="$(cd "$(dirname "$0")/Sources/MeteoBaras" && pwd)"
BUILD_DIR="$(cd "$(dirname "$0")" && pwd)/build"
APP_NAME="MeteoBaras.app"
APP_PATH="$BUILD_DIR/$APP_NAME"

echo "=== Building MeteoBaras ==="

# Clean
rm -rf "$APP_PATH"

# Create app bundle structure
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Compile
echo "Compiling..."
swiftc \
  -target arm64-apple-macos13 \
  -o "$APP_PATH/Contents/MacOS/MeteoBaras" \
  -framework AppKit \
  -framework CoreLocation \
  "$SRC_DIR/main.swift" \
  "$SRC_DIR/App.swift" \
  "$SRC_DIR/StatusBarManager.swift" \
  "$SRC_DIR/WeatherService.swift" \
  "$SRC_DIR/WeatherModels.swift" \
  "$SRC_DIR/WeatherConditionIcon.swift" \
  "$SRC_DIR/LocationUpdater.swift"

# Copy Info.plist
cp "$SRC_DIR/Info.plist" "$APP_PATH/Contents/Info.plist"

echo "=== Build complete! ==="
echo "Run: open \"$APP_PATH\""
