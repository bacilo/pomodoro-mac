# Architecture: GitHub Actions Release Automation

**Project:** PomodoroApp
**Domain:** macOS app automated release distribution
**Researched:** 2026-02-15
**Confidence:** HIGH

## Executive Summary

GitHub Actions integrates with existing Xcode projects through YAML workflow files stored in `.github/workflows/`, triggered by git tag pushes. The architecture follows a linear pipeline: **Tag Push → Version Extraction → Build → Archive → Export → Zip → Release Creation**. The workflow runs on GitHub-hosted macOS runners (macos-latest = macOS 15 as of Feb 2026) and uses native macOS tools (xcodebuild, codesign, ditto, PlistBuddy) to transform source code into distributable .app bundles uploaded to GitHub Releases.

**Key Integration Point:** The workflow does NOT modify the existing Xcode project structure or build process. It orchestrates existing tools (xcodebuild) in a CI environment, then adds post-build steps (packaging, uploading) that don't exist locally.

## Recommended Architecture

### System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          Developer                              │
│                              │                                   │
│                              ▼                                   │
│                      git tag v1.2.3                              │
│                      git push --tags                             │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Repository                           │
│  Event: push (tag matching pattern v*)                          │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│              GitHub Actions Runner (macos-latest)               │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Step 1: Checkout Code                                      │ │
│  │   actions/checkout@v4                                      │ │
│  │   → Clones repository to $GITHUB_WORKSPACE                 │ │
│  └────────────────────────────────────────────────────────────┘ │
│                               │                                  │
│                               ▼                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Step 2: Extract Version from Tag                           │ │
│  │   GITHUB_REF=refs/tags/v1.2.3                              │ │
│  │   VERSION=${GITHUB_REF#refs/tags/v}  → 1.2.3               │ │
│  │   Set as environment variable for later steps              │ │
│  └────────────────────────────────────────────────────────────┘ │
│                               │                                  │
│                               ▼                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Step 3: Update Xcode Version Settings                      │ │
│  │   PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" │ │
│  │              PomodoroApp/Info.plist                        │ │
│  │   Updates MARKETING_VERSION in project.pbxproj             │ │
│  └────────────────────────────────────────────────────────────┘ │
│                               │                                  │
│                               ▼                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Step 4: Build Release                                      │ │
│  │   xcodebuild -project PomodoroApp.xcodeproj \              │ │
│  │              -scheme PomodoroApp \                         │ │
│  │              -configuration Release \                      │ │
│  │              -derivedDataPath build/                       │ │
│  │   → build/Build/Products/Release/PomodoroApp.app           │ │
│  └────────────────────────────────────────────────────────────┘ │
│                               │                                  │
│                               ▼                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Step 5: Ad-hoc Code Sign (Apple Silicon Compatibility)    │ │
│  │   codesign --force --deep \                                │ │
│  │            --sign - \                                      │ │
│  │            build/.../PomodoroApp.app                       │ │
│  │   Required for ARM Macs to launch unsigned apps           │ │
│  └────────────────────────────────────────────────────────────┘ │
│                               │                                  │
│                               ▼                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Step 6: Create Distribution Zip                            │ │
│  │   ditto -c -k --keepParent --sequesterRsrc \               │ │
│  │         build/.../PomodoroApp.app \                        │ │
│  │         PomodoroApp-v$VERSION.zip                          │ │
│  │   Preserves macOS metadata, resource forks                 │ │
│  └────────────────────────────────────────────────────────────┘ │
│                               │                                  │
│                               ▼                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Step 7: Create GitHub Release                              │ │
│  │   ncipollo/release-action@v1                               │ │
│  │     tag: ${{ github.ref_name }}                            │ │
│  │     artifacts: PomodoroApp-v*.zip                          │ │
│  │     body: Auto-generated release notes                     │ │
│  └────────────────────────────────────────────────────────────┘ │
│                               │                                  │
└───────────────────────────────┼──────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      GitHub Release                             │
│  Tag: v1.2.3                                                    │
│  Asset: PomodoroApp-v1.2.3.zip (downloadable)                   │
└─────────────────────────────────────────────────────────────────┘
```

### Component Boundaries

| Component | Responsibility | Communicates With | Location |
|-----------|---------------|-------------------|----------|
| **Workflow YAML** | Defines trigger, jobs, steps | GitHub Actions runner | `.github/workflows/release.yml` |
| **Checkout Step** | Clones repository to runner | GitHub API | GitHub-hosted action |
| **Version Extraction Script** | Parses git tag to version string | Environment variables | Inline bash in workflow |
| **Version Update Script** | Updates Info.plist with version | PlistBuddy, project.pbxproj | Inline bash or separate script |
| **Build Step** | Compiles .app bundle | xcodebuild, Xcode toolchain | Uses existing project |
| **Code Signing Step** | Ad-hoc signs for ARM compatibility | codesign tool | Operates on build output |
| **Packaging Step** | Creates .zip for distribution | ditto tool | Operates on build output |
| **Release Creation Step** | Uploads artifact to GitHub Release | GitHub API via action | GitHub-hosted action |

### Data Flow

```
1. Git Tag (v1.2.3)
   ↓
2. GitHub Event (on.push.tags)
   ↓
3. Runner Environment Variables
   - GITHUB_REF = refs/tags/v1.2.3
   - GITHUB_WORKSPACE = /Users/runner/work/pomodoro-mac/pomodoro-mac
   ↓
4. Version String (1.2.3)
   ↓
5. Info.plist CFBundleShortVersionString = 1.2.3
   ↓
6. xcodebuild reads Info.plist
   ↓
7. PomodoroApp.app (with embedded version)
   ↓
8. PomodoroApp.app (ad-hoc signed)
   ↓
9. PomodoroApp-v1.2.3.zip
   ↓
10. GitHub Release Asset (downloadable by users)
```

**Critical Data Points:**
- **Tag → Version**: Strip "v" prefix from tag name
- **Version → Info.plist**: Write to CFBundleShortVersionString
- **Info.plist → Build**: xcodebuild embeds during compilation
- **.app → .zip**: ditto preserves metadata required for macOS

## Integration Points

### NEW Components (Created by this milestone)

| Component | Type | Location | Purpose |
|-----------|------|----------|---------|
| `.github/workflows/release.yml` | YAML file | New directory `.github/workflows/` | Workflow definition |
| `Scripts/update-version.sh` (optional) | Bash script | Existing `Scripts/` dir | Version update logic (if extracted from workflow) |
| `Scripts/package-release.sh` (optional) | Bash script | Existing `Scripts/` dir | Packaging logic (if extracted from workflow) |

**Recommendation:** Start with inline bash in workflow YAML. Extract to Scripts/ only if reused locally.

### MODIFIED Components (Updated by this milestone)

| Component | Change | Why | When Modified |
|-----------|--------|-----|---------------|
| `PomodoroApp/Info.plist` | `CFBundleShortVersionString` updated at build time | Embed version from tag | During CI build (not committed) |
| `.gitignore` (optional) | Add `*.zip` pattern | Prevent accidental local zip commits | Setup phase |

**Note:** Info.plist modification happens in CI runner, NOT in repository. Local Info.plist keeps default "1.0".

### UNCHANGED Components (Used but not modified)

| Component | How Used | Notes |
|-----------|----------|-------|
| `PomodoroApp.xcodeproj/` | Read by xcodebuild | No changes to project structure or build settings |
| `PomodoroApp/` source files | Compiled into .app | No changes to Swift code |
| `build/` directory | Build output location | Created by xcodebuild, already in .gitignore |
| Existing `Scripts/test.sh` | Not used in workflow initially | Don't modify; may add test job later |
| `CLAUDE.md` | Reference for build commands | Use same xcodebuild pattern |

### Integration Point Details

#### 1. Workflow File Location
**Path:** `.github/workflows/release.yml`
**Integration:** GitHub automatically detects YAML files in this directory
**Trigger:** Workflow runs when matching tags pushed (e.g., `v*`)
**Naming:** File name can be anything; workflow name defined in YAML `name:` field

#### 2. Version Flow: Tag → Xcode
**Input:** Git tag (e.g., `v1.2.3`)
**Transform:** Bash parameter expansion `${GITHUB_REF#refs/tags/v}` strips prefix
**Output:** Version string `1.2.3`

**Two approaches:**

**Option A (Simple, Recommended):** Modify Info.plist directly
```bash
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.2.3" \
                        PomodoroApp/Info.plist
```

**Option B (Robust):** Use agvtool to update project build settings
```bash
agvtool new-marketing-version 1.2.3
```

**Recommendation:** Option A for this project (single-target, straightforward versioning).

#### 3. Build Output Location
**Current local builds:** `build/Build/Products/Release/PomodoroApp.app`
**In CI:** `$GITHUB_WORKSPACE/build/Build/Products/Release/PomodoroApp.app`
**Integration:** xcodebuild `-derivedDataPath build/` ensures consistent location across environments

**Why this matters:** Packaging step needs predictable .app location; hardcoded paths work if derivedDataPath is fixed.

#### 4. Signing Requirement (CRITICAL for ARM Macs)
**Current state:** No signing (unsigned app)
**Problem:** ARM Macs (Apple Silicon) refuse to launch unsigned executables
**Solution:** Ad-hoc signing with `codesign --sign -`

```bash
codesign --force --deep --sign - build/.../PomodoroApp.app
```

**What this does:**
- `--sign -`: Ad-hoc signature (no certificate, just checksum)
- `--force`: Re-sign if already signed
- `--deep`: Sign nested code (frameworks, plugins)

**Impact:** Users can launch app without "developer cannot be verified" dialog (still need right-click → Open on first launch for Gatekeeper).

#### 5. Distribution Format (Why ditto, not zip)
**Input:** `.app` bundle
**Tool:** `ditto -c -k --keepParent --sequesterRsrc`
**Output:** `.zip` file with preserved macOS metadata

**Why NOT `zip -r`?**
- Standard zip doesn't preserve resource forks
- Extended attributes (xattrs) lost
- May cause "app is damaged" errors on extraction

**Why ditto?**
- macOS-native tool, understands HFS+ and APFS metadata
- `--sequesterRsrc` stores resource forks in `__MACOSX/` subdirectory
- `--keepParent` keeps `PomodoroApp.app` as top-level folder in zip

#### 6. Release Asset Upload
**Tool:** `ncipollo/release-action@v1`
**Why this action?** Actively maintained, feature-rich, simpler than actions/create-release (deprecated)

**Inputs:**
- `tag`: Use `${{ github.ref_name }}` (just tag name, e.g., `v1.2.3`)
- `artifacts`: Glob pattern `PomodoroApp-v*.zip`
- `body`: Markdown release notes (can use template or auto-generate)
- `prerelease`: Boolean (set based on tag name containing "beta"/"alpha")

**Authentication:** Uses `GITHUB_TOKEN` (auto-provided secret, no configuration needed)

**Permissions Required:** `contents: write` in workflow permissions block

## Workflow YAML Structure

### Minimal Example (Production-Ready)

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'  # Trigger on tags like v1.0, v1.2.3, v2.0.0-beta

jobs:
  build-and-release:
    runs-on: macos-latest

    permissions:
      contents: write  # Required for release creation

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Extract version from tag
        run: |
          VERSION=${GITHUB_REF#refs/tags/v}
          echo "VERSION=$VERSION" >> $GITHUB_ENV
          echo "Building version $VERSION"

      - name: Update Info.plist with version
        run: |
          /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${{ env.VERSION }}" \
                                  PomodoroApp/Info.plist

      - name: Build app
        run: |
          xcodebuild -project PomodoroApp.xcodeproj \
                     -scheme PomodoroApp \
                     -configuration Release \
                     -derivedDataPath build/ \
                     -destination 'platform=macOS'

      - name: Ad-hoc code sign
        run: |
          codesign --force --deep --sign - \
                   build/Build/Products/Release/PomodoroApp.app

      - name: Create distribution zip
        run: |
          ditto -c -k --keepParent --sequesterRsrc \
                build/Build/Products/Release/PomodoroApp.app \
                PomodoroApp-v${{ env.VERSION }}.zip

      - name: Create GitHub Release
        uses: ncipollo/release-action@v1
        with:
          artifacts: 'PomodoroApp-v*.zip'
          body: |
            ## PomodoroApp v${{ env.VERSION }}

            **Installation:**
            1. Download and unzip
            2. Move PomodoroApp.app to /Applications
            3. First launch: Right-click → Open (for unsigned apps)

            **What's Changed:**
            See commits since last release
          draft: false
          prerelease: false
```

### Enhanced Example (With Verification Steps)

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build-and-release:
    runs-on: macos-latest

    permissions:
      contents: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Extract version from tag
        id: version
        run: |
          VERSION=${GITHUB_REF#refs/tags/v}
          echo "VERSION=$VERSION" >> $GITHUB_ENV
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "Building PomodoroApp v$VERSION"

      - name: Verify Xcode version
        run: |
          xcodebuild -version
          xcrun --show-sdk-version

      - name: Update version in Info.plist
        run: |
          INFO_PLIST="PomodoroApp/Info.plist"
          /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${{ env.VERSION }}" "$INFO_PLIST"

          # Verify the update
          CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")
          echo "Updated CFBundleShortVersionString to: $CURRENT_VERSION"

      - name: Clean build directory
        run: rm -rf build/

      - name: Build app (Release)
        run: |
          xcodebuild -project PomodoroApp.xcodeproj \
                     -scheme PomodoroApp \
                     -configuration Release \
                     -derivedDataPath build/ \
                     -destination 'platform=macOS' \
                     CODE_SIGN_IDENTITY="-" \
                     CODE_SIGNING_REQUIRED=NO

      - name: Verify build output
        run: |
          APP_PATH="build/Build/Products/Release/PomodoroApp.app"
          if [ ! -d "$APP_PATH" ]; then
            echo "Build failed: PomodoroApp.app not found"
            exit 1
          fi

          BUNDLE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
                           "$APP_PATH/Contents/Info.plist")
          echo "App bundle version: $BUNDLE_VERSION"

          if [ "$BUNDLE_VERSION" != "${{ env.VERSION }}" ]; then
            echo "Version mismatch: expected ${{ env.VERSION }}, got $BUNDLE_VERSION"
            exit 1
          fi

      - name: Ad-hoc code sign (ARM compatibility)
        run: |
          APP_PATH="build/Build/Products/Release/PomodoroApp.app"
          codesign --force --deep --sign - "$APP_PATH"
          codesign --verify --verbose "$APP_PATH"

      - name: Create distribution zip
        run: |
          APP_PATH="build/Build/Products/Release/PomodoroApp.app"
          ZIP_NAME="PomodoroApp-v${{ env.VERSION }}.zip"

          ditto -c -k --keepParent --sequesterRsrc "$APP_PATH" "$ZIP_NAME"

          ls -lh "$ZIP_NAME"
          echo "Created $ZIP_NAME"

      - name: Upload build artifact (for debugging)
        uses: actions/upload-artifact@v4
        with:
          name: PomodoroApp-v${{ env.VERSION }}
          path: PomodoroApp-v${{ env.VERSION }}.zip
          retention-days: 7

      - name: Create GitHub Release
        uses: ncipollo/release-action@v1
        with:
          tag: ${{ github.ref_name }}
          name: PomodoroApp v${{ env.VERSION }}
          artifacts: 'PomodoroApp-v*.zip'
          body: |
            ## PomodoroApp v${{ env.VERSION }}

            ### Installation

            1. **Download**: Click `PomodoroApp-v${{ env.VERSION }}.zip` below
            2. **Extract**: Double-click the .zip file
            3. **Move**: Drag `PomodoroApp.app` to `/Applications`
            4. **Open**: Right-click → Open (required for unsigned apps on first launch)

            ### What's New

            See [commits since last release](https://github.com/${{ github.repository }}/compare/${{ github.event.before }}...${{ github.sha }})

            ---

            **Note:** This is an unsigned macOS app. On first launch, you must right-click → Open to bypass Gatekeeper.
          draft: false
          prerelease: ${{ contains(github.ref_name, 'beta') || contains(github.ref_name, 'alpha') }}
          makeLatest: true
```

### Key YAML Components Explained

#### Triggers (`on`)
```yaml
on:
  push:
    tags:
      - 'v*'              # Matches v1.0, v1.2.3, v2.0.0-beta
      - 'v[0-9]+.[0-9]+*' # Stricter: only semantic versions
```

**How it works:**
- GitHub monitors repository for tag pushes
- Tag name matched against glob pattern
- `GITHUB_REF` set to `refs/tags/v1.2.3`
- `github.ref_name` contains just tag name `v1.2.3`

#### Runner Selection (`runs-on`)
```yaml
runs-on: macos-latest  # Currently macOS 15 (as of Feb 2026)
```

**Options:**
- `macos-latest`: Auto-updates to newest stable (currently macOS 15 Sequoia)
- `macos-14`: macOS 14 Sonoma (Intel + ARM)
- `macos-15`: macOS 15 Sequoia (ARM only)

**Recommendation:** Use `macos-latest` for automatic updates.

#### Permissions
```yaml
permissions:
  contents: write  # Required for creating releases
```

**Why needed:** GitHub Actions uses fine-grained permissions; `contents: write` allows release creation and asset upload.

#### Environment Variables
```yaml
# Set for subsequent steps
- run: |
    VERSION=${GITHUB_REF#refs/tags/v}
    echo "VERSION=$VERSION" >> $GITHUB_ENV

# Use in later steps
- run: echo "Building ${{ env.VERSION }}"
```

#### Outputs (for cross-step communication)
```yaml
- id: version
  run: echo "version=1.2.3" >> $GITHUB_OUTPUT

- run: echo "Version: ${{ steps.version.outputs.version }}"
```

## Patterns to Follow

### Pattern 1: Version Extraction from Tag
**What:** Parse version string from git tag
**When:** Tag follows semantic versioning (v1.2.3 format)
**Example:**
```bash
VERSION=${GITHUB_REF#refs/tags/v}  # Removes refs/tags/v prefix → 1.2.3
echo "VERSION=$VERSION" >> $GITHUB_ENV
```

**Why:** Bash parameter expansion more reliable than regex; no external tools needed.

### Pattern 2: PlistBuddy for Version Updates
**What:** Modify Info.plist values from command line
**When:** Need to set version strings programmatically
**Example:**
```bash
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.2.3" \
                        PomodoroApp/Info.plist
```

**Why:** Native macOS tool, no dependencies, handles plist format correctly.

### Pattern 3: Build Verification
**What:** Check .app bundle exists and has correct version
**When:** Before packaging and releasing
**Example:**
```bash
APP_PATH="build/Build/Products/Release/PomodoroApp.app"
if [ ! -d "$APP_PATH" ]; then
  echo "Build failed"
  exit 1
fi

ACTUAL_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
                 "$APP_PATH/Contents/Info.plist")
if [ "$ACTUAL_VERSION" != "$VERSION" ]; then
  echo "Version mismatch"
  exit 1
fi
```

**Why:** Fail fast if build produces unexpected output; prevents releasing wrong version.

### Pattern 4: Ad-hoc Signing for Unsigned Distribution
**What:** Apply minimal code signature for ARM compatibility
**When:** No Developer ID certificate, but need ARM Mac compatibility
**Example:**
```bash
codesign --force --deep --sign - build/.../PomodoroApp.app
```

**Why:** ARM Macs refuse unsigned code; ad-hoc signing satisfies minimum requirement.

### Pattern 5: ditto for macOS App Packaging
**What:** Create zip that preserves macOS metadata
**When:** Distributing .app bundles as .zip files
**Example:**
```bash
ditto -c -k --keepParent --sequesterRsrc \
      PomodoroApp.app \
      PomodoroApp-v1.2.3.zip
```

**Why:** Standard `zip` command may corrupt macOS metadata; `ditto` is macOS-native.

### Pattern 6: Conditional Pre-release Flag
**What:** Mark releases as pre-release based on tag name
**When:** Using semantic versioning with beta/alpha suffixes
**Example:**
```yaml
prerelease: ${{ contains(github.ref_name, 'beta') || contains(github.ref_name, 'alpha') }}
```

**Why:** v1.0.0-beta shows as pre-release; v1.0.0 shows as stable.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Modifying project.pbxproj Directly
**What:** Editing Xcode project file XML with sed/awk
**Why bad:** Fragile, breaks on Xcode format changes, corrupts project
**Instead:** Use PlistBuddy for Info.plist OR agvtool for project settings

### Anti-Pattern 2: Using xcodebuild -exportArchive for Unsigned Apps
**What:** Attempting to use exportArchive + exportOptionsPlist for unsigned distribution
**Why bad:** exportArchive requires valid signing configuration; fails for unsigned
**Instead:** Use simple `xcodebuild build`, then package the .app directly

### Anti-Pattern 3: Standard zip Command
**What:** `zip -r app.zip PomodoroApp.app`
**Why bad:** Doesn't preserve resource forks, extended attributes; causes "damaged app" errors
**Instead:** Use `ditto -c -k --keepParent --sequesterRsrc`

### Anti-Pattern 4: Hardcoding Version in Workflow
**What:** Manually updating version in workflow YAML
**Why bad:** Version lives in two places (tag + YAML); easy to forget updating
**Instead:** Extract version from tag name programmatically

### Anti-Pattern 5: Skipping Build Verification
**What:** Assuming xcodebuild success means .app exists and is correct
**Why bad:** Build can succeed but produce unexpected output location or missing files
**Instead:** Explicitly check .app exists, has correct version, before packaging

### Anti-Pattern 6: Not Setting CODE_SIGN_IDENTITY
**What:** Relying on xcodebuild default signing behavior
**Why bad:** May fail if project has signing configured
**Instead:** Explicitly set `CODE_SIGN_IDENTITY="-"` and `CODE_SIGNING_REQUIRED=NO`

## Build Order and Dependencies

### Suggested Implementation Order

1. **Create `.github/workflows/` directory**
   - No dependencies
   - Action: `mkdir -p .github/workflows`

2. **Create minimal workflow YAML**
   - Depends on: Step 1
   - Action: Create `release.yml` with checkout + version extraction

3. **Add version update step**
   - Depends on: Step 2
   - Action: Add PlistBuddy command

4. **Add build step**
   - Depends on: Step 3
   - Action: Add xcodebuild command (from CLAUDE.md)

5. **Add ad-hoc signing step**
   - Depends on: Step 4
   - Action: Add codesign command

6. **Add packaging step**
   - Depends on: Step 5
   - Action: Add ditto command

7. **Add release creation step**
   - Depends on: Step 6
   - Action: Add ncipollo/release-action

8. **Test workflow with pre-release tag**
   - Depends on: Step 7
   - Action: `git tag v0.0.1-test && git push --tags`

9. **Verify release and artifact**
   - Depends on: Step 8
   - Action: Download .zip, test on macOS

10. **Add verification steps**
    - Depends on: Step 9
    - Action: Add build verification, better release notes

### Critical Path

```
Directory (1) → YAML (2) → Version (3) → Build (4) → Sign (5) → Package (6) → Release (7)
                                                                                    ↓
                                                                            Test (8) → Verify (9) → Improve (10)
```

**Each step depends on previous step's output.** Linear pipeline, no parallel opportunities in this workflow.

## Sources

### Official Documentation (HIGH confidence)
- [Workflow syntax for GitHub Actions](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions)
- [Events that trigger workflows](https://docs.github.com/actions/learn-github-actions/events-that-trigger-workflows)
- [Technical Q&A QA1827: Automating Version and Build Numbers Using agvtool](https://developer.apple.com/library/archive/qa/qa1827/_index.html)
- [DITTO(1) Man Page](https://keith.github.io/xcode-man-pages/ditto.1.html)
- [Build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)

### Community Resources (MEDIUM confidence, verified)
- [Distributing Mac Apps With GitHub Actions](https://defn.io/2023/09/22/distributing-mac-apps-with-github-actions/)
- [ncipollo/release-action](https://github.com/ncipollo/release-action)
- [macOS distribution gist](https://gist.github.com/rsms/929c9c2fec231f0cf843a1a746a416f5)
- [GitHub Actions runner-images macOS 15](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md)
- [Git Tag Based Released Process Using GitHub Actions](https://www.codingwithcalvin.net/git-tag-based-released-process-using-github-actions/)
