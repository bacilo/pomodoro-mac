# Technology Stack - GitHub Actions Release Distribution

**Project:** PomodoroApp (macOS menubar timer)
**Researched:** 2026-02-15
**Scope:** CI/CD for automated release builds and distribution (unsigned)

## Recommended Stack

### GitHub Actions Runner
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| macos-latest | → macos-15 | CI/CD runner environment | Current stable standard; macos-14 deprecated by July 2026; macos-15 is the default for macos-latest since August 2025 |

**Rationale:** Use `macos-latest` in workflows for automatic updates to current stable macOS. As of February 2026, this resolves to macOS 15 (Sequoia). Avoid `macos-14` (deprecated), consider `macos-26` (beta, may have stability/queueing issues).

### Core GitHub Actions
| Action | Version | Purpose | Why |
|--------|---------|---------|-----|
| actions/checkout | v6 | Repository checkout | Latest major version; handles git operations efficiently |
| softprops/action-gh-release | v2.5.0 | Create/update releases | Industry standard; handles draft uploads, asset management, changelog; simpler than gh CLI for basic releases |

**Rationale for softprops over gh CLI:** While gh CLI offers more control, softprops/action-gh-release provides better ergonomics for standard release workflows - automatic draft creation, batch asset uploads, and built-in changelog support. Use gh CLI only if you need advanced release manipulation.

### Build Tools (macOS Native)
| Tool | Version | Purpose | Why |
|------|---------|---------|-----|
| xcodebuild | System | Build and archive | Native Apple tool; already validated in your workflow |
| ditto | System | Create distribution .zip | macOS native; preserves symlinks, resource forks, metadata; produces smaller archives than standard zip |
| create-dmg (optional) | Latest from npm | Create .dmg installers | Optional; improves UX but .zip is sufficient for menubar apps |

**Rationale:** Leverage native macOS tools (no external dependencies). `ditto -c -k --sequesterRsrc --keepParent` creates proper macOS app bundles that match Finder's "Compress" behavior.

### Version Management
| Approach | Implementation | Purpose | Why |
|----------|---------------|---------|-----|
| Git tags | v*.*.* pattern | Version source | Simple; no extra actions needed; trigger workflow with tag push |
| GitHub ref extraction | `${GITHUB_REF#refs/tags/}` | Extract version from tag | Built-in bash; no third-party actions; works for simple v-prefixed tags |

**Rationale:** Avoid version extraction actions (jannemattila/get-version-from-tag, etc.) unless you need complex semver parsing. Simple bash string manipulation is sufficient for straightforward tags like `v1.2.3`.

## Build Configuration

### xcodebuild Flags for Unsigned Release Builds

**Archive command:**
```bash
xcodebuild archive \
  -project PomodoroApp.xcodeproj \
  -scheme PomodoroApp \
  -configuration Release \
  -archivePath build/PomodoroApp.xcarchive \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

**Export command (not needed for unsigned):**
Skip `xcodebuild -exportArchive` - it requires code signing. Instead, directly use the built .app from the archive.

**Extract .app from archive:**
```bash
cp -R build/PomodoroApp.xcarchive/Products/Applications/PomodoroApp.app build/
```

### Release Configuration vs Debug

| Aspect | Debug | Release |
|--------|-------|---------|
| Optimization | None | Fastest/smallest |
| Debug symbols | Full | Stripped |
| Size | Larger | Smaller |
| Performance | Slower | Faster |

**Use `-configuration Release`** for all CI builds to match App Store optimization levels.

### Creating Distribution Archives

**Recommended: ditto (native macOS)**
```bash
ditto -c -k --sequesterRsrc --keepParent \
  build/PomodoroApp.app \
  build/PomodoroApp.zip
```

**Flags explained:**
- `-c -k`: Create PKZip archive
- `--sequesterRsrc`: Preserve macOS resource forks
- `--keepParent`: Maintain parent directory structure

**Why not standard zip?** Standard `zip -r` may miss resource forks, symlinks, and produces larger files. `ditto` matches Finder's compression behavior.

**Optional: DMG creation**
```bash
npx create-dmg build/PomodoroApp.app build/ --no-code-sign
```

DMG provides better UX (drag-to-Applications UI) but adds complexity. Use only if user feedback requests it.

## GitHub Actions Permissions

### Required Permissions

```yaml
permissions:
  contents: write  # Required to create releases and upload assets
```

**Why `contents: write`?** Creating releases requires write access to repository contents. The default `GITHUB_TOKEN` has this permission when explicitly declared.

**Caveat:** This permission grants broader access (commits, PR merges). For security-conscious repos, use a dedicated release workflow with restricted scope.

## Workflow Trigger Configuration

### Recommended Trigger Pattern

```yaml
on:
  push:
    tags:
      - 'v*.*.*'  # Matches v1.0.0, v2.3.1, etc.
```

**Why this pattern?**
- Semantic versioning convention
- Prevents accidental triggers on non-version tags
- Clear intent (v prefix = release)

**Extract version in workflow:**
```yaml
- name: Extract version
  run: echo "VERSION=${GITHUB_REF#refs/tags/}" >> $GITHUB_ENV
```

No third-party actions needed for simple version extraction.

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Release Action | softprops/action-gh-release | gh CLI | More verbose; requires manual release creation + upload; gh CLI better for complex workflows |
| Release Action | softprops/action-gh-release | actions/create-release | Deprecated; not maintained |
| Archiving | ditto | zip -r | Doesn't preserve macOS metadata; larger files |
| DMG Creation | None (defer) | create-dmg | Adds complexity; .zip sufficient for menubar apps; consider later if users request |
| Version Extraction | Bash string manipulation | jannemattila/get-version-from-tag | Over-engineered for simple v*.*.* tags; extra dependency |
| Runner | macos-latest | macos-14 | Deprecated by July 2026 |
| Runner | macos-latest | macos-26 (beta) | Beta status; potential instability and queueing issues |
| Build Tool | Fastlane | N/A | Overkill for unsigned builds; adds dependency; xcodebuild sufficient |
| Signing | None (unsigned) | Certificates/notarization | Not needed per requirements; users accept Gatekeeper warnings |

## Installation & Setup

### No Installation Required

All tools are native to GitHub Actions `macos-latest` runner:
- xcodebuild (Xcode CLI tools)
- ditto (macOS system tool)
- gh CLI (pre-installed on GitHub runners)

### Workflow Dependencies

Add to workflow file only:
```yaml
- uses: actions/checkout@v6
- uses: softprops/action-gh-release@v2
  with:
    files: build/*.zip
```

### Optional: DMG Support (if needed later)

```yaml
- name: Install create-dmg
  run: npm install --global create-dmg
```

Only add if user feedback requests .dmg format.

## Anti-Patterns to Avoid

### ❌ DON'T: Use xcodebuild -exportArchive for unsigned apps

Modern xcodebuild requires `-exportOptionsPlist` with `teamID` for export. This complicates unsigned workflows.

**Instead:** Extract .app directly from `.xcarchive/Products/Applications/`

### ❌ DON'T: Use deprecated actions

- `actions/create-release` (deprecated)
- `actions/upload-release-asset` (deprecated)

**Instead:** Use `softprops/action-gh-release@v2` which handles both.

### ❌ DON'T: Skip CODE_SIGNING_* flags

Without explicit `CODE_SIGN_IDENTITY=""` and `CODE_SIGNING_REQUIRED=NO`, xcodebuild may fail if signing identity is configured in Xcode project.

### ❌ DON'T: Use `macos-14` runner

Deprecated by July 2026. Use `macos-latest` or `macos-15`.

### ❌ DON'T: Forget `permissions: contents: write`

Default GITHUB_TOKEN doesn't have release creation permissions unless explicitly declared.

### ❌ DON'T: Use standard `zip -r` for macOS apps

Loses metadata, resource forks, and produces larger files than ditto.

## Confidence Assessment

| Area | Confidence | Source |
|------|------------|--------|
| GitHub Actions runners | HIGH | Official GitHub Actions runner-images repository, deprecation announcements |
| softprops/action-gh-release | HIGH | Official releases page, widely adopted (verified from marketplace usage) |
| xcodebuild unsigned flags | MEDIUM | Apple Developer Forums confirm approach; no official docs for "skip signing" workflow |
| ditto command | HIGH | Apple Developer Documentation, Fastlane source code confirms usage |
| Permissions | HIGH | Official GitHub Docs, community discussions |
| actions/checkout@v6 | HIGH | Official actions/checkout repository |

## Sources

**GitHub Actions Runners:**
- [GitHub Actions macOS runner versions issue #13008](https://github.com/actions/runner-images/issues/13008) - macOS 26 beta announcement
- [macOS-latest label issue #12520](https://github.com/actions/runner-images/issues/12520) - macos-15 default timeline
- [GitHub-hosted runners reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

**Release Actions:**
- [softprops/action-gh-release repository](https://github.com/softprops/action-gh-release)
- [softprops/action-gh-release v2.2.1 release](https://github.com/softprops/action-gh-release/releases/tag/v2.2.1)

**Build Tools:**
- [xcodebuild export archive unsigned - Apple Developer Forums](https://developer.apple.com/forums/thread/75636)
- [Packaging Mac software for distribution - Apple Developer Documentation](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
- [Fastlane issue #11095 - ditto for efficient packaging](https://github.com/fastlane/fastlane/issues/11095)

**Permissions:**
- [GitHub Actions GITHUB_TOKEN permissions discussion #121022](https://github.com/orgs/community/discussions/121022)
- [Controlling permissions for GITHUB_TOKEN](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/controlling-permissions-for-github_token)

**Workflow Triggers:**
- [GitHub Actions tag trigger patterns - Dev Cheatsheets](https://michaelcurrin.github.io/dev-cheatsheets/cheatsheets/ci-cd/github-actions/triggers.html)

**DMG Creation:**
- [create-dmg by Sindre Sorhus](https://github.com/sindresorhus/create-dmg)
- [Distributing Mac Apps With GitHub Actions](https://defn.io/2023/09/22/distributing-mac-apps-with-github-actions/)

**actions/checkout:**
- [actions/checkout repository](https://github.com/actions/checkout)

**xcodebuild configurations:**
- [Debug vs Release builds - Medium](https://medium.com/geekculture/what-are-debug-and-release-modes-in-xcode-how-to-check-app-is-running-in-debug-mode-8dadad6a3428)

**gh CLI:**
- [gh release create command](https://cli.github.com/manual/gh_release_create)
