# Phase 3: GitHub Actions Release Pipeline - Research

**Researched:** 2026-02-15
**Domain:** GitHub Actions CI/CD for macOS app automated release distribution
**Confidence:** HIGH

## Summary

Phase 3 implements automated release builds triggered by git tag pushes. When a developer pushes a version tag (e.g., `v1.1.0`), GitHub Actions automatically builds the macOS app in Release configuration, packages it as a .zip file, generates a SHA256 checksum, and creates a GitHub Release with downloadable assets.

The architecture is straightforward: a YAML workflow file (`.github/workflows/release.yml`) defines a linear pipeline that runs on GitHub's macOS runners. The workflow uses native macOS tools (xcodebuild, ditto, codesign) and the official `actions/checkout` plus `ncipollo/release-action` for GitHub integration. No code signing certificates are required - ad-hoc signing satisfies Apple Silicon compatibility requirements.

**Primary recommendation:** Start with minimal workflow covering the core requirements (BUILD-01 through VERS-03), then iterate based on real release experience. Avoid premature optimization (DMG creation, complex changelog generation, build caching) until proven necessary.

**Critical constraints from prior research:**
- No Apple Developer account → no notarization or Developer ID signing
- Ad-hoc code signing mandatory for Apple Silicon compatibility
- Must use `ditto` (not `zip`) to preserve macOS metadata
- macOS 15.1+ Sequoia has severe restrictions on unsigned apps (users need detailed installation instructions)

## Standard Stack

### Core
| Library/Tool | Version | Purpose | Why Standard |
|--------------|---------|---------|--------------|
| GitHub Actions | N/A | CI/CD platform | Built into GitHub, zero setup, macOS runners available |
| macos-latest runner | → macos-15 | Build environment | Auto-updates to stable macOS; currently macOS 15 Sequoia |
| actions/checkout | v6 | Clone repository | Official GitHub action, latest major version |
| ncipollo/release-action | v1 | Create GitHub releases | Industry standard, actively maintained, simpler than deprecated alternatives |
| xcodebuild | System (Xcode CLI) | Build macOS app | Native Apple tool, already validated in project |
| ditto | System | Package .app as .zip | macOS native, preserves resource forks and metadata |
| codesign | System | Ad-hoc code signing | Required for Apple Silicon, native macOS tool |
| shasum | System | Generate SHA256 checksum | Standard Unix tool, security best practice |

### Supporting Tools (Native to macOS Runners)
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| PlistBuddy | System (/usr/libexec/) | Update Info.plist version | Extract version from git tag, write to CFBundleShortVersionString |
| gh CLI | Pre-installed | GitHub API operations | Alternative to release actions, useful for debugging |
| bash | System | Scripting | Version extraction, path manipulation, verification steps |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ncipollo/release-action | softprops/action-gh-release@v2 | Both are viable; ncipollo slightly simpler API, softprops has more stars |
| ncipollo/release-action | gh CLI (`gh release create`) | gh CLI more verbose but offers finer control; actions better for standard workflows |
| ditto | zip -r | zip doesn't preserve macOS metadata, causes "damaged app" errors |
| macos-latest | macos-15 (pinned) | macos-latest auto-updates (could break builds), pinned version is stable but requires manual updates |
| PlistBuddy | agvtool | agvtool more robust for multi-target projects but requires project configuration; PlistBuddy simpler for single-target |
| Ad-hoc signing | Skip signing entirely | Apple Silicon REQUIRES code signing (ad-hoc minimum); no signing = app won't run on ARM Macs |

**Installation:**
None required - all tools are native to GitHub Actions `macos-latest` runner or official GitHub actions referenced in workflow YAML.

## Architecture Patterns

### Recommended Project Structure
```
.github/
└── workflows/
    └── release.yml              # Tag-triggered release workflow

Scripts/                          # Existing directory
├── build.sh                      # Existing (local builds)
├── test.sh                       # Existing (local tests)
└── export-app.sh                 # Existing (local packaging)
# No new scripts needed - workflow uses inline bash

dist/                             # Local export directory (existing)
build/                            # xcodebuild output (existing, in .gitignore)
```

**Key insight:** GitHub Actions workflow reuses existing build patterns from `Scripts/export-app.sh` but runs them in CI environment. No duplication of build logic.

### Pattern 1: Tag-Triggered Workflow
**What:** Git tag push automatically triggers GitHub Actions workflow
**When to use:** Want version tags to be the source of truth for releases
**Example:**
```yaml
# Source: Official GitHub Actions docs
name: Release

on:
  push:
    tags:
      - 'v*'  # Matches v1.0, v1.2.3, v2.0.0-beta

jobs:
  build-and-release:
    runs-on: macos-latest
    permissions:
      contents: write  # Required for release creation
```

**Why this pattern:**
- Single source of truth: git tag = release version
- Developer pushes tag → automatic build, no manual intervention
- Tag naming convention (`v*`) prevents accidental triggers
- Permissions declared explicitly (security best practice)

### Pattern 2: Version Extraction from Git Tag
**What:** Parse semantic version from git tag, inject into build
**When to use:** Tag format is `v1.2.3` and you need `1.2.3` as version string
**Example:**
```bash
# Source: GitHub Actions environment variables documentation
VERSION=${GITHUB_REF#refs/tags/v}  # Strips "refs/tags/v" prefix
echo "VERSION=$VERSION" >> $GITHUB_ENV  # Make available to subsequent steps

# Later steps use: ${{ env.VERSION }}
```

**Why this pattern:**
- No external actions needed (bash parameter expansion)
- GITHUB_REF format is `refs/tags/v1.2.3`, strip prefix to get `1.2.3`
- Environment variable persists across workflow steps

### Pattern 3: PlistBuddy Version Update
**What:** Update Info.plist version from extracted tag version
**When to use:** Need CFBundleShortVersionString to match git tag before build
**Example:**
```bash
# Source: Apple PlistBuddy documentation
/usr/libexec/PlistBuddy \
  -c "Set :CFBundleShortVersionString $VERSION" \
  PomodoroApp/Info.plist

# Verify (optional but recommended)
CURRENT=$(/usr/libexec/PlistBuddy \
  -c "Print :CFBundleShortVersionString" \
  PomodoroApp/Info.plist)
echo "Updated to version: $CURRENT"
```

**Why this pattern:**
- Native macOS tool, no dependencies
- Handles plist format correctly (XML)
- Safer than sed/awk on XML
- Works for MARKETING_VERSION in project.pbxproj too

**Note for this project:** Info.plist currently only has LSUIElement key. Version is stored in project.pbxproj as `MARKETING_VERSION = 1.0`. Update project.pbxproj or use agvtool instead.

### Pattern 4: Unsigned Build for Distribution
**What:** Build .app without code signing certificates, use ad-hoc signing for compatibility
**When to use:** No Apple Developer account, distributing outside App Store
**Example:**
```bash
# Source: Existing Scripts/export-app.sh (verified pattern)
xcodebuild build \
  -project PomodoroApp.xcodeproj \
  -scheme PomodoroApp \
  -configuration Release \
  -derivedDataPath build/ \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# Then apply ad-hoc signing for Apple Silicon
codesign --force --deep --sign - \
  build/Build/Products/Release/PomodoroApp.app
```

**Why this pattern:**
- `CODE_SIGN_IDENTITY="-"` uses ad-hoc signing
- `CODE_SIGNING_REQUIRED=NO` bypasses certificate requirement
- Separate `codesign` step ensures Apple Silicon compatibility
- `--deep` signs nested code (frameworks, if any)

### Pattern 5: ditto Packaging for macOS Distribution
**What:** Create .zip that preserves macOS app bundle metadata
**When to use:** Distributing .app bundles as downloadable .zip files
**Example:**
```bash
# Source: macOS ditto man page, existing Scripts/export-app.sh pattern
ditto -c -k --sequesterRsrc --keepParent \
  build/Build/Products/Release/PomodoroApp.app \
  PomodoroApp-v${VERSION}.zip

# Verify zip was created
ls -lh PomodoroApp-v${VERSION}.zip
```

**Flags explained:**
- `-c -k`: Create PKZip archive
- `--sequesterRsrc`: Preserve resource forks in `__MACOSX/` subdirectory
- `--keepParent`: Keep `PomodoroApp.app` as top-level folder in zip

**Why NOT `zip -r`?** Standard zip doesn't preserve extended attributes and resource forks, causing "app is damaged" errors on extraction.

### Pattern 6: SHA256 Checksum for Download Verification
**What:** Generate checksum file for users to verify download integrity
**When to use:** Distributing binary files, security best practice
**Example:**
```bash
# Source: Standard Unix tool documentation
shasum -a 256 PomodoroApp-v${VERSION}.zip > checksums.txt

# Standard format output:
# abc123...def PomodoroApp-v1.1.0.zip

# Users verify with:
# shasum -a 256 -c checksums.txt
```

**Why this pattern:**
- Industry standard for binary distribution
- Detects corrupted downloads
- Users can verify file wasn't tampered with
- Simple one-liner, no dependencies

### Pattern 7: Release Asset Upload with Actions
**What:** Create GitHub Release and attach .zip + checksum as downloadable assets
**When to use:** Want releases to appear on GitHub Releases page
**Example:**
```yaml
# Source: ncipollo/release-action documentation
- name: Create GitHub Release
  uses: ncipollo/release-action@v1
  with:
    tag: ${{ github.ref_name }}
    name: PomodoroApp v${{ env.VERSION }}
    artifacts: |
      PomodoroApp-v*.zip
      checksums.txt
    body: |
      ## PomodoroApp v${{ env.VERSION }}

      Download the .zip file below, extract, and move to /Applications.

      **First launch:** Right-click → Open (for unsigned apps)
    draft: false
    prerelease: ${{ contains(github.ref_name, 'beta') }}
```

**Why this pattern:**
- `artifacts` supports glob patterns (wildcards)
- `github.ref_name` is just tag name (`v1.1.0`), not full ref
- `prerelease` flag auto-detects beta/alpha tags
- Markdown `body` shows in release notes

### Anti-Patterns to Avoid

**❌ DON'T: Use `macos-latest` without understanding it changes**
- `macos-latest` currently points to macOS 15 (as of Aug 2025)
- GitHub updates this label periodically, can break builds
- **INSTEAD:** Pin to specific version (`macos-15`) for stability, or accept auto-updates and test thoroughly

**❌ DON'T: Use `xcodebuild archive` + `exportArchive` for unsigned apps**
- Modern xcodebuild requires export options plist with teamID
- Complicates unsigned workflows unnecessarily
- **INSTEAD:** Use `xcodebuild build` and package the .app directly from build output

**❌ DON'T: Skip ad-hoc code signing**
- Apple Silicon Macs REQUIRE code signing (even ad-hoc)
- Unsigned apps crash on M1/M2/M3 Macs
- **INSTEAD:** Always use `codesign --sign -` after build for ARM compatibility

**❌ DON'T: Use standard `zip -r` for .app bundles**
- Loses macOS resource forks and extended attributes
- Causes "app is damaged" errors on user's machine
- **INSTEAD:** Use `ditto -c -k --sequesterRsrc --keepParent`

**❌ DON'T: Forget `permissions: contents: write`**
- Default GITHUB_TOKEN doesn't have release creation permission
- Upload fails with 403 Forbidden error
- **INSTEAD:** Add `permissions: contents: write` to workflow

**❌ DON'T: Hardcode version in multiple places**
- Version in YAML + tag = maintenance burden, easy to desync
- **INSTEAD:** Extract version from git tag programmatically

**❌ DON'T: Skip build verification before packaging**
- Build can succeed but output .app at unexpected location
- Packaging step fails silently or creates empty/wrong zip
- **INSTEAD:** Verify .app exists and has correct version before creating release

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Release creation + asset upload | Custom GitHub API calls with curl | `ncipollo/release-action` or `softprops/action-gh-release` | Handles authentication, retries, draft uploads, error handling, pagination |
| Version bumping in Xcode projects | sed/awk on project.pbxproj XML | PlistBuddy for Info.plist OR agvtool for project settings | project.pbxproj is fragile XML, easy to corrupt; native tools handle format correctly |
| macOS app packaging | Custom zip with specific flags | ditto with standard flags (`-c -k --sequesterRsrc --keepParent`) | Resource fork handling is complex, ditto matches Finder's compression behavior |
| Tag version parsing | Regex in bash or third-party action | Bash parameter expansion `${GITHUB_REF#refs/tags/v}` | Simple string manipulation, no dependencies, reliable for v*.*.* pattern |
| Checksum generation | Custom hashing implementation | shasum (SHA256) | Standard tool, widely recognized format, users know how to verify |
| Code signing for compatibility | Skip entirely or implement custom signing | codesign with ad-hoc signature (`--sign -`) | Apple Silicon enforcement is strict, ad-hoc is minimum requirement |
| Workflow testing locally | Push to test branch repeatedly | `act` (local GitHub Actions runner) or create test tags | Faster iteration, doesn't pollute commit history or release tags |

**Key insight:** GitHub Actions ecosystem is mature. Standard tools (native macOS + official actions) cover 100% of requirements. Custom solutions introduce bugs and maintenance burden without benefits.

## Common Pitfalls

### Pitfall 1: macOS Sequoia 15.1+ Severely Restricts Unsigned Apps
**What goes wrong:** Users on macOS 15.1+ cannot easily open unsigned apps. The traditional Control-click/right-click "Open Anyway" bypass was removed in Sequoia.

**Why it happens:** Apple removed Gatekeeper contextual menu override. Even `sudo spctl --master-disable` no longer works on macOS 15+.

**How to avoid:**
- **Document installation steps with screenshots** in release notes and README
- Provide clear step-by-step: Download → Extract → Move to Applications → System Settings → Privacy & Security → "Open Anyway" button
- Consider code signing/notarization for better UX (future enhancement, requires Apple Developer account)
- Add prominent warning in README about macOS 15.1+ installation challenges
- Test every release on macOS 15.1+ before publishing

**Warning signs:**
- GitHub issues reporting "can't open app" or "app is damaged"
- Users on Sequoia report different experience than older macOS
- Downloads work on macOS 14 but fail on macOS 15

**Sources:**
- [Apple Forces The Signing Of Applications In MacOS Sequoia 15.1 | Hackaday](https://hackaday.com/2024/11/01/apple-forces-the-signing-of-applications-in-macos-sequoia-15-1/)
- [Bug or intentional? macOS 15.1 completely removes ability to launch unsigned applications](https://www.osnews.com/story/141055/)

### Pitfall 2: ZIP Quarantine Attributes Cause "Damaged App" Errors
**What goes wrong:** macOS adds `com.apple.quarantine` extended attribute to downloaded ZIPs. When users extract with Finder, the attribute propagates to .app bundle, triggering "app is damaged" errors instead of normal unsigned warnings.

**Why it happens:** Browser downloads are automatically quarantined by macOS. Finder's Archive Utility preserves quarantine attributes during extraction.

**How to avoid:**
- **Include xattr removal instructions** prominently in release notes:
  ```bash
  xattr -r -d com.apple.quarantine PomodoroApp.app
  ```
- Consider providing installation script that removes quarantine automatically
- Document that "damaged app" error is different from "unidentified developer" warning
- Note: Command-line unzip doesn't propagate quarantine, but GitHub web downloads always quarantine

**Warning signs:**
- Users report "app is damaged" instead of "unidentified developer"
- Right-click → Open doesn't work
- Error message says "move to trash" with no override option

**Sources:**
- [macOS distribution — code signing, notarization, quarantine (gist)](https://gist.github.com/rsms/929c9c2fec231f0cf843a1a746a416f5)
- [macOS security and com.apple.quarantine extended attribute](https://www.isscloud.io/guides/macos-security-and-com-apple-quarantine-extended-attribute/)

### Pitfall 3: `macos-latest` Runner Label Changes Without Warning
**What goes wrong:** GitHub periodically updates what `macos-latest` points to. Workflows that worked on macOS 14 suddenly break when `macos-latest` shifts to macOS 15.

**Why it happens:** GitHub's deprecation policy for runner images. `macos-latest` is a moving target, currently macOS 15 (as of Aug 2025).

**How to avoid:**
- **Decision point:** Use `macos-latest` for auto-updates OR pin to `macos-15` for stability
- If using `macos-latest`: Monitor [actions/runner-images](https://github.com/actions/runner-images) for deprecation announcements
- Test workflow on next macOS version before `macos-latest` shifts
- Document runner version in workflow comments
- Consider matrix strategy during transition periods

**Warning signs:**
- Workflow failures after no code changes
- Different Xcode version in CI logs compared to previous runs
- GitHub deprecation warnings in workflow run logs
- Xcode/Swift version mismatches

**Sources:**
- [macOS-latest YAML-label will use macos-15 in August 2025](https://github.com/actions/runner-images/issues/12520)
- [GitHub Actions macOS: Changes in 2025](https://www.roundfleet.com/blog/github-actions-macos-runners-changes-2025)

### Pitfall 4: Apple Silicon Requires Code Signing (Ad Hoc Minimum)
**What goes wrong:** Completely unsigned apps won't run on Apple Silicon Macs. Even with Gatekeeper disabled, Apple Silicon enforces code signing.

**Why it happens:** Apple Silicon's security model requires all executables be signed (even ad-hoc). Intel Macs allow unsigned code.

**How to avoid:**
- **Always use ad-hoc signing minimum**: `codesign --force --deep --sign - <app>`
- Set `CODE_SIGN_IDENTITY="-"` in xcodebuild (uses ad-hoc signature)
- Don't use `CODE_SIGNING_REQUIRED=NO` alone - still need ad-hoc signing afterward
- Test on Apple Silicon hardware before releases
- GitHub Actions `macos-15` runners are Apple Silicon (ARM64)

**Warning signs:**
- App works on Intel Macs but crashes on M1/M2/M3
- "Code signature not valid" errors on Apple Silicon
- Split user experience based on Mac architecture

**Sources:**
- [Can I use xcodebuild to build an archive without signing it - Apple Developer Forums](https://developer.apple.com/forums/thread/95624)
- [Code Signing on CI](https://trinhngocthuyen.com/posts/tech/code-signing-on-ci/)

### Pitfall 5: Missing `permissions: contents: write` Blocks Release Upload
**What goes wrong:** Upload release asset fails with "Resource not accessible by integration" or 403 Forbidden error.

**Why it happens:** Default GITHUB_TOKEN permissions don't include `contents: write` in repositories with stricter security settings.

**How to avoid:**
- **Add explicit permissions** at workflow level:
  ```yaml
  permissions:
    contents: write
  ```
- Or per-job:
  ```yaml
  jobs:
    release:
      permissions:
        contents: write
  ```
- Test on fork or test repository first to catch permission issues

**Warning signs:**
- Release created but no assets attached
- HTTP 403 errors during upload step
- "Resource not accessible by integration" in logs

**Sources:**
- [Controlling permissions for GITHUB_TOKEN - GitHub Docs](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/controlling-permissions-for-github_token)

### Pitfall 6: Info.plist Version Not Updated Before Build
**What goes wrong:** All releases show same version number (e.g., "1.0") because CFBundleShortVersionString not updated from git tag before build.

**Why it happens:** This project uses `MARKETING_VERSION` in project.pbxproj, not CFBundleShortVersionString in Info.plist. Xcode auto-generates Info.plist from project settings.

**How to avoid:**
- **Project-specific:** Update `MARKETING_VERSION` in project.pbxproj OR use agvtool:
  ```bash
  xcrun agvtool new-marketing-version $VERSION
  ```
- Verify version in built app after build:
  ```bash
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
    build/.../PomodoroApp.app/Contents/Info.plist
  ```
- Add verification step to fail build if version mismatch detected

**Warning signs:**
- All releases show "Version 1.0" in About dialog
- Downloaded v2.0 shows as v1.0 in app
- Version in built app doesn't match git tag

**Note for this project:** `GENERATE_INFOPLIST_FILE = YES` in project.pbxproj means Xcode generates Info.plist from build settings. Update `MARKETING_VERSION` build setting, not Info.plist directly.

### Pitfall 7: Architecture Mismatch (Intel vs ARM)
**What goes wrong:** Workflow builds only for runner's native architecture (ARM64 on macos-15), excluding Intel Mac users.

**Why it happens:** Default builds produce architecture-specific binaries unless explicitly configured for universal.

**How to avoid:**
- **Build universal binary** (both architectures):
  ```bash
  xcodebuild build \
    -project PomodoroApp.xcodeproj \
    -scheme PomodoroApp \
    ONLY_ACTIVE_ARCH=NO
  ```
- Or set in Xcode: Build Settings → Architectures → "Standard Architectures (Apple Silicon, Intel)"
- Verify binary is universal: `file build/.../PomodoroApp.app/Contents/MacOS/PomodoroApp` should show `Mach-O universal binary with 2 architectures`
- Test on both architectures if possible

**Warning signs:**
- Users report "app not compatible with this Mac"
- Intel Mac users blocked from running app
- `file` command shows single architecture only

**Sources:**
- [macOS distribution gist](https://gist.github.com/rsms/929c9c2fec231f0cf843a1a746a416f5)

### Pitfall 8: No Test Validation Before Release
**What goes wrong:** GitHub Actions builds and releases app without running test suite, shipping broken builds.

**Why it happens:** Forgot to add test step before release asset creation. Easy to skip in minimal workflows.

**How to avoid:**
- **Add test step before build** (existing project has test suite):
  ```yaml
  - name: Run tests
    run: |
      xcodebuild test \
        -project PomodoroApp.xcodeproj \
        -scheme PomodoroApp \
        -destination 'platform=macOS'

  - name: Build for release
    if: success()  # Only if tests pass
    run: xcodebuild build ...
  ```
- Make test failure block release creation
- Use same test command as CLAUDE.md documents

**Warning signs:**
- Releases created despite failing tests locally
- CI logs show no test execution
- Workflow completes suspiciously fast (<1 minute)

**Sources:**
- Existing project pattern (Scripts/test.sh, CLAUDE.md test-first development)

## Code Examples

Verified patterns from official sources and existing project:

### Complete Minimal Workflow (Production-Ready)
```yaml
# Source: Synthesized from GitHub Actions docs + existing project patterns
name: Release

on:
  push:
    tags:
      - 'v*'  # Matches v1.0, v1.2.3, v2.0.0-beta

jobs:
  build-and-release:
    runs-on: macos-latest

    permissions:
      contents: write  # Required for release creation

    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Extract version from tag
        run: |
          VERSION=${GITHUB_REF#refs/tags/v}
          echo "VERSION=$VERSION" >> $GITHUB_ENV
          echo "Building version $VERSION"

      - name: Run tests
        run: |
          xcodebuild test \
            -project PomodoroApp.xcodeproj \
            -scheme PomodoroApp \
            -destination 'platform=macOS'

      - name: Build app (Release configuration)
        run: |
          xcodebuild build \
            -project PomodoroApp.xcodeproj \
            -scheme PomodoroApp \
            -configuration Release \
            -derivedDataPath build/ \
            -destination 'platform=macOS' \
            CODE_SIGN_IDENTITY="-" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO

      - name: Ad-hoc code sign for Apple Silicon
        run: |
          codesign --force --deep --sign - \
            build/Build/Products/Release/PomodoroApp.app

      - name: Create distribution zip
        run: |
          ditto -c -k --keepParent --sequesterRsrc \
            build/Build/Products/Release/PomodoroApp.app \
            PomodoroApp-v${{ env.VERSION }}.zip

      - name: Generate SHA256 checksum
        run: |
          shasum -a 256 PomodoroApp-v${{ env.VERSION }}.zip > checksums.txt

      - name: Create GitHub Release
        uses: ncipollo/release-action@v1
        with:
          artifacts: |
            PomodoroApp-v*.zip
            checksums.txt
          body: |
            ## PomodoroApp v${{ env.VERSION }}

            ### Installation

            1. **Download**: Click `PomodoroApp-v${{ env.VERSION }}.zip` below
            2. **Extract**: Double-click the .zip file
            3. **Move**: Drag `PomodoroApp.app` to `/Applications`
            4. **Open**: Right-click → Open (required for unsigned apps on first launch)

            **macOS 15.1+ (Sequoia) users:**
            - If "Open" doesn't work, run: `xattr -r -d com.apple.quarantine /Applications/PomodoroApp.app`
            - Then go to System Settings → Privacy & Security → Click "Open Anyway"

            ### Verify Download (Optional)

            ```bash
            shasum -a 256 -c checksums.txt
            ```

            ---

            **Note:** This is an unsigned macOS app. On first launch, you must right-click → Open to bypass Gatekeeper.
          draft: false
          prerelease: ${{ contains(github.ref_name, 'beta') || contains(github.ref_name, 'alpha') }}
```

### Version Update via agvtool (Alternative to PlistBuddy)
```bash
# Source: Apple agvtool documentation
# Use if MARKETING_VERSION lives in project.pbxproj build settings

# Update marketing version (user-facing version)
xcrun agvtool new-marketing-version $VERSION

# Increment build number (optional, for tracking builds)
xcrun agvtool next-version -all

# Verify
xcrun agvtool what-marketing-version
xcrun agvtool what-version
```

**Note for this project:** Current project has `CURRENT_PROJECT_VERSION = 1` and `MARKETING_VERSION = 1.0` in project.pbxproj. Use agvtool OR update project.pbxproj directly with PlistBuddy/sed.

### Build Verification Script
```bash
# Source: Best practices from existing Scripts/export-app.sh
APP_PATH="build/Build/Products/Release/PomodoroApp.app"

# Check app exists
if [ ! -d "$APP_PATH" ]; then
  echo "❌ Build failed: PomodoroApp.app not found"
  exit 1
fi

# Check version matches tag
BUILT_VERSION=$(/usr/libexec/PlistBuddy \
  -c 'Print :CFBundleShortVersionString' \
  "$APP_PATH/Contents/Info.plist")

if [ "$BUILT_VERSION" != "$VERSION" ]; then
  echo "❌ Version mismatch: expected $VERSION, got $BUILT_VERSION"
  exit 1
fi

# Verify universal binary (Intel + ARM)
ARCHS=$(file "$APP_PATH/Contents/MacOS/PomodoroApp" | grep -o 'x86_64\|arm64' | sort | uniq | tr '\n' ' ')
echo "Built architectures: $ARCHS"

if [[ ! "$ARCHS" =~ "arm64" ]] || [[ ! "$ARCHS" =~ "x86_64" ]]; then
  echo "⚠️  Warning: Not a universal binary. Some users may not be able to run the app."
fi

echo "✅ Build verification passed"
```

### Conditional Prerelease Detection
```yaml
# Source: GitHub Actions expression syntax documentation
- name: Create GitHub Release
  uses: ncipollo/release-action@v1
  with:
    # Mark as prerelease if tag contains beta, alpha, rc
    prerelease: ${{ contains(github.ref_name, 'beta') || contains(github.ref_name, 'alpha') || contains(github.ref_name, 'rc') }}
    # Mark as latest only for stable releases
    makeLatest: ${{ !(contains(github.ref_name, 'beta') || contains(github.ref_name, 'alpha') || contains(github.ref_name, 'rc')) }}
```

**Examples:**
- `v1.2.3` → stable release, marked as latest
- `v1.2.3-beta.1` → prerelease, not marked as latest
- `v2.0.0-rc.1` → prerelease, not marked as latest

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| actions/create-release + actions/upload-release-asset | ncipollo/release-action OR softprops/action-gh-release | Deprecated 2022 | Old actions no longer maintained; new actions combine create + upload in one step |
| macos-14 (Intel + ARM) | macos-15 (ARM only) | Aug 2025 | macos-latest now points to macos-15; faster builds, ARM-native |
| Right-click → Open for unsigned apps | Multi-step process via System Settings | macOS 15.1 (Nov 2024) | Unsigned apps much harder to open on Sequoia 15.1+ |
| `zip -r` for packaging | `ditto -c -k` | Always preferred | zip never properly preserved macOS metadata; ditto is correct approach |
| Manual release creation | Automated via tag push | CI/CD standard | Tag push = release; no manual GitHub UI interaction |

**Deprecated/outdated:**
- **actions/create-release**: Deprecated, use ncipollo/release-action or softprops/action-gh-release
- **actions/upload-release-asset**: Deprecated, use ncipollo/release-action with `artifacts:` parameter
- **macos-13**: Deprecated Dec 2024, use macos-14 or macos-15
- **Xcode 26.x on GitHub Actions**: Known hanging issues, pin to Xcode 15.x until resolved (tracked in actions/runner-images#13264)

## Open Questions

### Question 1: Should we pin to macos-15 or use macos-latest?
**What we know:**
- `macos-latest` currently points to macOS 15 (as of Aug 2025)
- GitHub will update `macos-latest` to macOS 16 eventually
- `macos-15` is stable but requires manual updates when deprecated

**What's unclear:**
- How frequently will builds break when `macos-latest` updates?
- Is auto-update benefit worth the stability risk?

**Recommendation:**
- **Start with `macos-latest`** (easier, auto-updates)
- Monitor for breaking changes
- Pin to specific version if builds become unstable
- Document decision in workflow comments

### Question 2: Should we use agvtool or PlistBuddy for version updates?
**What we know:**
- Project uses `GENERATE_INFOPLIST_FILE = YES` (Xcode generates Info.plist from build settings)
- `MARKETING_VERSION = 1.0` lives in project.pbxproj
- agvtool is Apple's official tool for version management
- PlistBuddy can modify project.pbxproj (XML format)

**What's unclear:**
- Does agvtool work correctly with `GENERATE_INFOPLIST_FILE = YES`?
- Is modifying project.pbxproj with PlistBuddy safe?

**Recommendation:**
- **Test both approaches** in workflow development
- agvtool preferred (official tool, designed for this)
- Fallback to PlistBuddy if agvtool fails
- Verify built app's version after build regardless of approach

### Question 3: Do we need DMG creation in addition to ZIP?
**What we know:**
- ZIP is simpler (one-liner with ditto)
- DMG provides better UX (drag-to-Applications visual)
- DMG creation requires `create-dmg` npm package or `hdiutil` scripting
- Menubar apps don't strictly need installation instructions

**What's unclear:**
- Will users complain about ZIP-only distribution?
- Is DMG complexity worth the UX improvement?

**Recommendation:**
- **Start with ZIP only** (meets requirements)
- Add DMG in future if users request it
- Document as potential enhancement in roadmap

### Question 4: Should we generate changelog automatically from commits?
**What we know:**
- GitHub provides auto-generated release notes from PRs/commits
- Conventional commits would enable structured changelogs
- Project doesn't currently use conventional commit format

**What's unclear:**
- Is manual release notes writing acceptable?
- Would auto-generated notes provide value?

**Recommendation:**
- **Use basic GitHub auto-generated notes** (enable with `generateReleaseNotes: true`)
- Manually write release highlights in workflow `body:`
- Consider conventional commits + changelog generation in future milestone

## Sources

### Primary (HIGH confidence)
**Official Documentation:**
- [Workflow syntax for GitHub Actions](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions) - Workflow YAML structure
- [Events that trigger workflows](https://docs.github.com/actions/learn-github-actions/events-that-trigger-workflows) - Tag triggers
- [Controlling permissions for GITHUB_TOKEN](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/controlling-permissions-for-github_token) - Permissions model
- [DITTO(1) Man Page](https://keith.github.io/xcode-man-pages/ditto.1.html) - ditto flags and usage
- [Apple Developer: Build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference) - Xcode build settings

**GitHub Actions:**
- [actions/checkout repository](https://github.com/actions/checkout) - Official checkout action
- [ncipollo/release-action repository](https://github.com/ncipollo/release-action) - Release action we're using
- [GitHub Actions runner-images macOS 15](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md) - Runner environment

### Secondary (MEDIUM confidence)
**Community Guides:**
- [Distributing Mac Apps With GitHub Actions](https://defn.io/2023/09/22/distributing-mac-apps-with-github-actions/) - Comprehensive guide
- [macOS distribution gist by rsms](https://gist.github.com/rsms/929c9c2fec231f0cf843a1a746a416f5) - Code signing, notarization, quarantine
- [GitHub Actions macOS: Changes in 2025](https://www.roundfleet.com/blog/github-actions-macos-runners-changes-2025) - Runner updates

**Pitfalls Research:**
- [Apple Forces The Signing Of Applications In MacOS Sequoia 15.1 | Hackaday](https://hackaday.com/2024/11/01/apple-forces-the-signing-of-applications-in-macos-sequoia-15-1/) - Sequoia restrictions
- [macOS 15.1 completely removes ability to launch unsigned applications – OSnews](https://www.osnews.com/story/141055/) - Gatekeeper changes
- [macOS security and com.apple.quarantine extended attribute](https://www.isscloud.io/guides/macos-security-and-com-apple-quarantine-extended-attribute/) - Quarantine attribute

**GitHub Issues (tracking ongoing issues):**
- [macos-latest will use macos-15 in August 2025](https://github.com/actions/runner-images/issues/12520) - Runner updates
- [Xcode 26.0.1 / 26.1 RC hanging on macos-15](https://github.com/actions/runner-images/issues/13264) - Current Xcode issue

### Tertiary (LOW confidence - needs validation)
**Community Discussions:**
- [Apple Developer Forums: Can I use xcodebuild to build an archive without signing it](https://developer.apple.com/forums/thread/95624) - Unsigned builds
- [Code Signing on CI](https://trinhngocthuyen.com/posts/tech/code-signing-on-ci/) - CI code signing patterns

**Existing Project:**
- `Scripts/export-app.sh` - Verified existing build pattern (unsigned build with CODE_SIGN_IDENTITY="-")
- `Scripts/test.sh` - Existing test command
- `CLAUDE.md` - Project build commands and test-first workflow

## Metadata

**Confidence breakdown:**
- **Standard stack:** HIGH - GitHub Actions is industry standard, tools are native/official
- **Architecture:** HIGH - Linear pipeline well-documented, existing scripts validate approach
- **Pitfalls:** HIGH - macOS Sequoia restrictions verified from multiple sources, Apple Silicon requirements documented
- **Version management:** MEDIUM - Multiple valid approaches (agvtool vs PlistBuddy), project-specific testing needed
- **Release UX:** MEDIUM - Unsigned app user experience subject to macOS version changes

**Research date:** 2026-02-15
**Valid until:** ~60 days (GitHub Actions stable, macOS updates semi-annual)

**Dependencies:**
- macOS Sequoia 15.1+ behavior may change (Apple could restore Gatekeeper override)
- Xcode 26.x hanging issue resolution (tracked in actions/runner-images#13264)
- GitHub Actions runner deprecation schedule (monitor actions/runner-images)

**Ready for planning:** Yes. Planner has sufficient information to create detailed task breakdown for all requirements (BUILD-01 through VERS-03).
