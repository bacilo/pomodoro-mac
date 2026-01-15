#!/bin/bash
# Run all tests for PomodoroApp

set -e

echo "🧪 Running PomodoroApp tests..."

xcodebuild test \
  -project PomodoroApp.xcodeproj \
  -scheme PomodoroApp \
  -destination 'platform=macOS' \
  -quiet \
  2>&1 | xcpretty || xcodebuild test \
  -project PomodoroApp.xcodeproj \
  -scheme PomodoroApp \
  -destination 'platform=macOS' \
  -quiet

echo "✅ All tests passed!"
