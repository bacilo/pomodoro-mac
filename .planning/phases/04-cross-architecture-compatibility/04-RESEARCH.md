# Research: Phase 4 — Cross-Architecture Compatibility

## Current State Analysis

The Phase 3 workflow (`.github/workflows/release.yml`) already has:
- **Ad-hoc code signing**: `codesign --force --deep --sign -` (line 48-49)
- **Build with `CODE_SIGN_IDENTITY="-"`**: Disables signing during build, signs after
- **Basic verification**: Checks app exists and version matches tag

**Missing for Phase 4:**
1. No universal binary build — builds only for runner's native arch (ARM64 on `macos-latest`)
2. No architecture verification (`lipo -info`)
3. No code signing verification (`codesign -v`)

## Key Findings

### Universal Binary Build

To produce a universal binary (Intel x86_64 + Apple Silicon arm64):

```yaml
xcodebuild build \
  ...
  ARCHS="x86_64 arm64" \
  ONLY_ACTIVE_ARCH=NO
```

- `ONLY_ACTIVE_ARCH=YES` is set in project Debug config (line 367 of pbxproj) — irrelevant since CI uses Release config
- Build setting overrides on command line take precedence over project settings
- `macos-latest` runners (Apple Silicon) can cross-compile for x86_64 via Rosetta/SDK support

### Ad-hoc Code Signing

Current workflow already does ad-hoc signing. Needs adjustment:
- **`--deep` flag**: Signs nested frameworks/binaries — good practice
- **`--force` flag**: Replaces any existing signature — needed since build may partially sign
- Post-signing, verify with `codesign --verify --deep --strict`

### Verification Steps

Three verification checks needed:
1. **Architecture check**: `lipo -info PomodoroApp.app/Contents/MacOS/PomodoroApp` should show `x86_64 arm64`
2. **Code signing check**: `codesign --verify --deep --strict PomodoroApp.app` should exit 0
3. **Version check**: Already exists from Phase 3

### GitHub Actions Runner

- `macos-latest` = Apple Silicon (M-series) runner
- Can build universal binaries natively — Xcode SDK includes both arch support
- No special runner configuration needed

## Implementation Approach

**Single plan** — all changes go to the same workflow file:

1. Add `ARCHS` and `ONLY_ACTIVE_ARCH` to the existing build step
2. Keep existing ad-hoc signing step (already correct)
3. Expand "Verify build" step to include architecture and signing checks
4. No new files needed — purely workflow modifications

## Risks

- **Cross-compilation**: If `macos-latest` runner doesn't have x86_64 SDK support, build will fail. Mitigation: This is standard Xcode behavior, should work.
- **Deep signing**: `--deep` may not catch all embedded binaries. For this simple app (no frameworks), this is not a concern.

## RESEARCH COMPLETE
