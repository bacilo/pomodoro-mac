#!/bin/bash
# Export PomodoroApp as a standalone .app bundle

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
EXPORT_DIR="$PROJECT_DIR/dist"

echo "🔨 Building PomodoroApp for release..."

# Clean previous builds
rm -rf "$BUILD_DIR"
rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

# Build the app
xcodebuild build \
  -project "$PROJECT_DIR/PomodoroApp.xcodeproj" \
  -scheme PomodoroApp \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | xcpretty || xcodebuild build \
  -project "$PROJECT_DIR/PomodoroApp.xcodeproj" \
  -scheme PomodoroApp \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# Find and copy the built app
APP_PATH=$(find "$BUILD_DIR" -name "PomodoroApp.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
  echo "❌ Build failed - app not found"
  exit 1
fi

cp -R "$APP_PATH" "$EXPORT_DIR/"

echo ""
echo "✅ Build successful!"
echo ""
echo "📦 App location: $EXPORT_DIR/PomodoroApp.app"
echo ""
echo "To install:"
echo "  1. Copy to Applications: cp -R \"$EXPORT_DIR/PomodoroApp.app\" /Applications/"
echo "  2. Or double-click the app in Finder to run it"
echo ""
echo "To open the app now:"
echo "  open \"$EXPORT_DIR/PomodoroApp.app\""
