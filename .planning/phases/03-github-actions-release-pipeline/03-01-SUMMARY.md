# Phase 03 Plan 01: GitHub Actions Release Workflow Summary

**One-liner:** Complete tag-triggered release automation with version injection, testing gate, ad-hoc signing, ditto packaging, and GitHub Release creation.

---
phase: 03-github-actions-release-pipeline
plan: 01
subsystem: ci-cd
tags: [github-actions, automation, release, packaging, code-signing]
requires: [xcodebuild, test-suite, git-tagging]
provides: [automated-releases, release-workflow, version-management]
affects: [release-process, distribution]
tech-stack-added: [github-actions, ncipollo/release-action@v1, ditto, codesign]
tech-stack-patterns: [tag-triggered-workflow, version-extraction-from-tag, ad-hoc-signing, macos-packaging]
key-files-created: [.github/workflows/release.yml]
key-files-modified: []
key-decisions:
  - decision: Use MARKETING_VERSION build setting override instead of agvtool or PlistBuddy
    rationale: Command-line build settings override project.pbxproj values without modifying files, cleaner for CI
    alternatives: [agvtool, PlistBuddy on project.pbxproj]
  - decision: Use macos-latest runner (not pinned version)
    rationale: Start with auto-updates, pin to specific version if builds become unstable
    alternatives: [macos-15 pinned]
  - decision: Include comprehensive macOS 15.1+ Sequoia installation instructions
    rationale: Sequoia severely restricts unsigned apps, users need detailed xattr workaround
    alternatives: [minimal instructions, external documentation]
metrics:
  duration: 2m 14s
  tasks_completed: 2
  commits: 1
  files_created: 1
  completed_date: 2026-02-15
---

## Objective

Create the GitHub Actions release workflow that triggers on version tag pushes, builds the app, packages it, and creates a GitHub Release with downloadable assets.

**Goal:** Automate the entire release pipeline so pushing a tag (e.g., `v1.1.0`) produces a downloadable GitHub Release with zero manual steps.

## What Was Built

### 1. GitHub Actions Release Workflow

Created `.github/workflows/release.yml` with complete release automation pipeline:

**Trigger:** Push tags matching `v*` pattern (e.g., `v1.0.0`, `v2.1.3-beta`)

**Pipeline Steps:**
1. **Checkout code** - Clone repository at tagged commit
2. **Extract version** - Parse semantic version from git tag (`v1.2.3` → `1.2.3`)
3. **Run tests** - Gate entire release on passing test suite (test-first requirement)
4. **Build app** - Release configuration with version injected via `MARKETING_VERSION` build setting
5. **Ad-hoc code sign** - Apply ad-hoc signature for Apple Silicon compatibility
6. **Verify build** - Confirm .app exists and version matches tag (fail if mismatch)
7. **Package zip** - Use ditto to preserve macOS metadata (not standard zip)
8. **Generate checksum** - SHA256 hash for download verification
9. **Create release** - GitHub Release with zip + checksum as downloadable assets

**Key Features:**
- Version is single source of truth (git tag)
- Tests must pass before release creation
- Built app version verified against tag
- Comprehensive installation instructions for macOS 15.1+ Sequoia
- Automatic prerelease detection (tags containing "beta" or "alpha")
- Auto-generated release notes from commits

### 2. Local Validation

Validated all core pipeline steps locally before committing:

**Validated:**
- ✅ MARKETING_VERSION build setting override works (tested with v99.99.99)
- ✅ Ad-hoc code signing successful (codesign --verify passes)
- ✅ ditto packaging creates valid zip (1.5MB, correct format)
- ✅ SHA256 checksum generation works
- ✅ YAML syntax valid

**Results:** All validation checks passed. Workflow is ready for first real tag push.

## Requirements Coverage

### BUILD Requirements

| Req | Description | Implementation |
|-----|-------------|----------------|
| BUILD-01 | Tag trigger | `on.push.tags: v*` in workflow |
| BUILD-02 | Release configuration | `xcodebuild build -configuration Release` |
| BUILD-03 | ditto packaging | `ditto -c -k --keepParent --sequesterRsrc` |
| BUILD-04 | GitHub Release creation | `ncipollo/release-action@v1` with artifacts |
| BUILD-05 | SHA256 checksum | `shasum -a 256`, included in release assets |

### VERS Requirements

| Req | Description | Implementation |
|-----|-------------|----------------|
| VERS-01 | Extract version from tag | `VERSION=${GITHUB_REF#refs/tags/v}` bash expansion |
| VERS-02 | Set MARKETING_VERSION | `MARKETING_VERSION=${{ env.VERSION }}` in xcodebuild |
| VERS-03 | Set build number | `CURRENT_PROJECT_VERSION=${{ github.run_number }}` |

**All 8 requirements met.**

## Deviations from Plan

**None - plan executed exactly as written.**

No bugs discovered, no missing critical functionality, no blocking issues encountered.

## Key Decisions

### 1. Use MARKETING_VERSION Build Setting Override

**Decision:** Pass `MARKETING_VERSION=${{ env.VERSION }}` as command-line argument to xcodebuild instead of using agvtool or modifying project.pbxproj with PlistBuddy.

**Rationale:**
- Command-line build settings override project.pbxproj values without file modification
- Cleaner for CI (no git changes during build)
- Xcode's `GENERATE_INFOPLIST_FILE = YES` means Info.plist is generated from build settings
- Tested locally and confirmed working (99.99.99 test version injected successfully)

**Alternatives considered:**
- `agvtool new-marketing-version` - More robust but requires project configuration, modifies files
- PlistBuddy on project.pbxproj - Fragile (XML editing), risk of corruption

### 2. Use macos-latest Runner

**Decision:** Use `macos-latest` (currently macOS 15) instead of pinning to `macos-15`.

**Rationale:**
- Start with auto-updates for latest Xcode and macOS features
- GitHub maintains runner compatibility
- Can pin to specific version later if builds become unstable
- Research showed this is acceptable starting point

**Alternatives considered:**
- Pin to `macos-15` - More stable but requires manual updates when deprecated

**Monitoring plan:** Watch for workflow failures after no code changes, indicating runner update broke build.

### 3. Comprehensive macOS 15.1+ Sequoia Instructions

**Decision:** Include detailed installation instructions with xattr workaround and System Settings path in release body.

**Rationale:**
- macOS Sequoia 15.1+ severely restricts unsigned apps (research Pitfall 1)
- Traditional right-click → Open bypass removed in Sequoia
- Users will encounter "damaged app" errors from quarantine attributes (research Pitfall 2)
- Clear instructions reduce support burden

**Release body includes:**
- Standard installation steps (download, extract, move, right-click Open)
- Sequoia-specific xattr command: `xattr -r -d com.apple.quarantine`
- System Settings → Privacy & Security path
- Checksum verification command

## Technical Notes

### Version Injection Mechanism

The workflow uses command-line build setting overrides instead of modifying project files:

```bash
xcodebuild build \
  MARKETING_VERSION=${{ env.VERSION }} \
  CURRENT_PROJECT_VERSION=${{ github.run_number }}
```

This works because:
1. Xcode generates Info.plist from build settings (`GENERATE_INFOPLIST_FILE = YES`)
2. Command-line settings override project.pbxproj values
3. Built app's CFBundleShortVersionString reflects the overridden value

**Local validation confirmed:** Built app shows version 99.99.99 when `MARKETING_VERSION=99.99.99` passed to xcodebuild.

### Why ditto, Not zip

Standard `zip -r` loses macOS extended attributes and resource forks, causing "app is damaged" errors when users extract. The workflow uses:

```bash
ditto -c -k --keepParent --sequesterRsrc
```

**Flags:**
- `-c -k`: Create PKZip archive
- `--keepParent`: Keep PomodoroApp.app as top-level folder
- `--sequesterRsrc`: Preserve resource forks in `__MACOSX/` subdirectory

This matches Finder's compression behavior and prevents "damaged app" errors.

### Ad-Hoc Code Signing Requirement

Apple Silicon Macs REQUIRE code signing (even ad-hoc). The workflow:

1. Builds with `CODE_SIGN_IDENTITY="-"` (no Developer ID)
2. Then applies ad-hoc signature: `codesign --force --deep --sign -`

Without this, app won't run on M1/M2/M3 Macs. GitHub Actions `macos-latest` runners are ARM64.

## Testing Strategy

### Validation Performed

**Local dry-run build:**
- ✅ Built Release configuration with version override (99.99.99)
- ✅ Verified version in built Info.plist matches override
- ✅ Applied ad-hoc code signature successfully
- ✅ Created ditto zip (1.5MB)
- ✅ Generated SHA256 checksum

**YAML validation:**
- ✅ Syntax valid (python yaml.safe_load)
- ✅ All required steps present (grep verification)

### Next Steps for Testing

**First real release:**
1. Push annotated tag: `git tag -a v1.1.0 -m "Release v1.1.0"`
2. Push tag to trigger workflow: `git push origin v1.1.0`
3. Monitor workflow run in GitHub Actions tab
4. Verify GitHub Release created with assets
5. Download zip, verify checksum, test installation on macOS 15.1+

**Success criteria for first release:**
- Workflow completes without errors
- Release appears on GitHub Releases page
- Zip and checksums.txt attached as assets
- Downloaded app runs on Apple Silicon Mac
- Version shown in app matches tag

## Files Changed

### Created

**`.github/workflows/release.yml`** (129 lines)
- Complete tag-triggered release automation pipeline
- Implements all 8 BUILD/VERS requirements
- Includes comprehensive macOS 15.1+ installation instructions
- Auto-detects prerelease from tag name (beta/alpha)

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | ea1cc97 | feat(03-01): add GitHub Actions release workflow |
| 2 | (validation only, no commit) | - |

## Integration Points

### Upstream Dependencies

**Required for workflow to succeed:**
- Git tags matching `v*` pattern (manual step by developer)
- Test suite passing (`xcodebuild test` must succeed)
- Valid Xcode project configuration (PomodoroApp.xcodeproj)
- GitHub repository with Actions enabled

### Downstream Impacts

**This workflow enables:**
- Zero-manual-step release process (tag push → downloadable release)
- Consistent versioning (tag = source of truth)
- Quality gate (tests must pass before release)
- User verification (checksums for download integrity)

**Affects:**
- Release process (now fully automated)
- Version management (no manual Info.plist edits)
- Distribution (GitHub Releases instead of manual file sharing)

## Known Limitations

### 1. Unsigned App Installation Complexity

**Issue:** macOS 15.1+ Sequoia users face multi-step installation process for unsigned apps.

**Impact:** Higher support burden, potential user confusion.

**Mitigation:** Comprehensive installation instructions in release notes, documented xattr workaround.

**Future enhancement:** Apple Developer account + code signing + notarization (requires paid account).

### 2. Runner Version Auto-Updates

**Issue:** `macos-latest` label will shift to macOS 16 eventually, may break builds.

**Impact:** Workflow could fail after no code changes.

**Mitigation:** Monitor GitHub's actions/runner-images announcements, test on next macOS version before shift.

**Fallback:** Pin to specific version (e.g., `macos-15`) if auto-updates cause instability.

### 3. No Architecture Verification

**Issue:** Workflow doesn't verify universal binary (Intel + ARM).

**Impact:** Could ship ARM-only or Intel-only builds, excluding some users.

**Mitigation:** Default Xcode settings build universal binaries. Future enhancement: add `file` command to verify both architectures present.

## Next Phase

**Phase 03, Plan 02 (if additional plans exist):** Continue implementing remaining requirements from roadmap.

**If Phase 03 complete:** Proceed to Phase 04 as defined in `.planning/ROADMAP.md`.

**Immediate next step:** Push first version tag (`v1.1.0`) to test release workflow end-to-end.

## Self-Check: PASSED

**Created files verified:**
- ✅ `/Users/pedf/workspace/pomodoro-mac/.github/workflows/release.yml` exists

**Commits verified:**
- ✅ ea1cc97 exists in git history

**Validation verified:**
- ✅ MARKETING_VERSION override works (tested with v99.99.99)
- ✅ Ad-hoc code signing works (codesign --verify passes)
- ✅ ditto packaging creates valid zip
- ✅ SHA256 checksum generation works
- ✅ YAML syntax valid

All claims in this summary have been verified.
