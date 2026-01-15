#!/bin/bash
# Build PomodoroApp for release

set -e

echo "🔨 Building PomodoroApp..."

xcodebuild build \
  -project PomodoroApp.xcodeproj \
  -scheme PomodoroApp \
  -configuration Release \
  -destination 'platform=macOS' \
  -quiet \
  2>&1 | xcpretty || xcodebuild build \
  -project PomodoroApp.xcodeproj \
  -scheme PomodoroApp \
  -configuration Release \
  -destination 'platform=macOS' \
  -quiet

echo "✅ Build successful!"
