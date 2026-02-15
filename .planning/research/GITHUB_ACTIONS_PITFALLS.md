# Domain Pitfalls: GitHub Actions Release Automation for macOS Apps

**Domain:** macOS app distribution via GitHub Actions CI/CD
**Researched:** 2026-02-15
**Confidence:** MEDIUM-HIGH (verified with official docs and community sources)

## Critical Pitfalls

Mistakes that cause rewrites, broken releases, or user-facing failures.

### Pitfall 1: macOS Sequoia 15.1+ Makes Unsigned Apps Extremely Difficult to Run
**What goes wrong:** Users on macOS 15.1+ cannot easily open unsigned apps. The traditional Control-click/right-click "Open Anyway" bypass was removed.

**Why it happens:** Apple removed Gatekeeper contextual menu override in Sequoia. Even the `sudo spctl --master-disable` Terminal command no longer works on macOS 15+.

**Consequences:**
- Users on Sequoia 15.1+ face multi-step process: attempt launch → dismiss dialog → open System Settings → Privacy & Security → scroll to Security section → click "Open Anyway"
- Many users will give up or assume the app is malicious
- Downloads may trigger quarantine attribute, adding additional friction
- Community debate whether this is bug or intended behavior suggests instability

**Prevention:**
- **Consider code signing/notarization** even for simple apps (reduces friction dramatically)
- Document clear installation instructions with screenshots for Sequoia users
- Provide alternative distribution (Homebrew cask with `--no-quarantine` flag)
- Add prominent warning in README about macOS 15.1+ installation challenges

**Detection:**
- Test downloads on macOS 15.1+ (Sequoia) before each release
- Monitor GitHub issues for "can't open app" complaints
- Check if users report "damaged app" errors (quarantine attribute issue)

**Sources:**
- [Apple Forces The Signing Of Applications In MacOS Sequoia 15.1 | Hackaday](https://hackaday.com/2024/11/01/apple-forces-the-signing-of-applications-in-macos-sequoia-15-1/)
- [Bug or intentional? macOS 15.1 completely removes ability to launch unsigned applications – OSnews](https://www.osnews.com/story/141055/bug-or-intentional-macos-15-1-completely-removes-ability-to-launch-unsigned-applications/)
- [macOS Sequoia removes the Control-click method to bypass Gatekeeper](https://www.idownloadblog.com/2024/08/07/apple-macos-sequoia-gatekeeper-change-install-unsigned-apps-mac/)

---

### Pitfall 2: ZIP Quarantine Attributes Cause "Damaged App" Errors
**What goes wrong:** macOS adds `com.apple.quarantine` extended attribute to downloaded ZIPs. When users extract with Finder's Archive Utility, the attribute propagates to `.app` bundle, triggering Gatekeeper warnings or "app is damaged" errors.

**Why it happens:** User-level unarchiving tools (like Finder's Archive Utility) preserve quarantine attributes. No way to prevent this when distributing via ZIP.

**Consequences:**
- Users see "App is damaged and can't be opened" instead of standard unsigned app warning
- Instructions to "right-click → Open" don't work (quarantine attribute takes precedence)
- Users must run `xattr -r -d com.apple.quarantine PomodoroApp.app` in Terminal
- Non-technical users unlikely to resolve this

**Prevention:**
- **Document xattr removal command prominently** in release notes
- Provide installation script that removes quarantine:
  ```bash
  #!/bin/bash
  xattr -r -d com.apple.quarantine PomodoroApp.app
  open PomodoroApp.app
  ```
- Consider DMG instead of ZIP (allows custom installation instructions view)
- Note: Command-line tools (`unzip`, `tar`) don't propagate quarantine, but GitHub web UI downloads will always quarantine

**Detection:**
- Download your own release ZIP via browser and test extraction
- Check for quarantine: `xattr -l PomodoroApp.app`
- Monitor user reports of "damaged app" vs "unidentified developer"

**Sources:**
- [macOS distribution — code signing, notarization, quarantine](https://gist.github.com/rsms/929c9c2fec231f0cf843a1a746a416f5)
- [macOS security and com.apple.quarantine extended attribute – ISSCloud](https://www.isscloud.io/guides/macos-security-and-com-apple-quarantine-extended-attribute/)
- [Clearing the quarantine extended attribute from downloaded applications | Der Flounder](https://derflounder.wordpress.com/2012/11/20/clearing-the-quarantine-extended-attribute-from-downloaded-applications/)

---

### Pitfall 3: `macos-latest` Label Changes Break Workflows Silently
**What goes wrong:** GitHub periodically updates what `macos-latest` points to (currently macOS 15 as of Aug 2025). Workflows break when underlying OS/Xcode versions change without warning.

**Why it happens:** GitHub's deprecation policy for runner images. `macos-latest` is a moving target that shifts to newer OS versions on announced schedules.

**Consequences:**
- Xcode version changes between builds without code changes
- Simulator runtimes deprecated/removed (e.g., iOS 16.x on macOS 15)
- Build settings that worked on macOS 14 fail on macOS 15
- Swift version/API availability changes
- Workflows suddenly fail after working for months

**Prevention:**
- **Pin to specific runner version** for releases: `runs-on: macos-15` (not `macos-latest`)
- Monitor [actions/runner-images deprecation announcements](https://github.com/actions/runner-images/issues)
- Set up workflow to test against both current and next macOS version
- Add matrix strategy for multiple macOS versions during transition periods
- Document runner version in release notes/tags

**Detection:**
- Workflow failures after no code changes
- Different Xcode versions in CI logs compared to local
- GitHub deprecation warnings in workflow run logs
- Subscribe to runner-images repository for announcements

**Sources:**
- [macOS-latest YAML-label will use macos-15 in August 2025](https://github.com/actions/runner-images/issues/12520)
- [macOS 13 deprecation announcement](https://github.com/actions/runner-images/issues/13046)
- [GitHub Actions macOS: Changes in 2025](https://www.roundfleet.com/blog/github-actions-macos-runners-changes-2025)

---

### Pitfall 4: Apple Silicon Requires Code Signing (Ad Hoc Minimum)
**What goes wrong:** Completely unsigned apps won't run on Apple Silicon Macs. Even with Gatekeeper disabled, Apple Silicon enforces code signing.

**Why it happens:** Apple Silicon's security model requires all executables be signed (even ad hoc). Intel Macs allow unsigned code.

**Consequences:**
- App built with `CODE_SIGNING_REQUIRED=NO` crashes on M1/M2/M3 Macs
- "Code signature not valid" errors on Apple Silicon
- Split user experience: Intel users OK, Apple Silicon users blocked
- CI runners are often Apple Silicon now, adding another variable

**Prevention:**
- **Use ad hoc signing minimum**: `CODE_SIGN_IDENTITY="-"`
- Set in Xcode: "Sign to Run Locally" (ad hoc signing)
- Don't use `CODE_SIGNING_REQUIRED=NO` if targeting Apple Silicon
- Test on both Intel and Apple Silicon hardware before releases
- GitHub Actions `macos-15` runners are Apple Silicon (ARM64)

**Detection:**
- Test releases on Apple Silicon Mac
- Check CI runner architecture in logs (`uname -m` → `arm64`)
- Users report crashes on M1/M2 but not Intel
- "signature validation failed" in crash logs

**Sources:**
- [Can I use xcodebuild to build an archive without signing it](https://developer.apple.com/forums/thread/95624)
- [Code Signing on CI](https://trinhngocthuyen.com/posts/tech/code-signing-on-ci/)
- [macOS distribution — code signing, notarization, quarantine](https://gist.github.com/rsms/929c9c2fec231f0cf843a1a746a416f5)

---

## Moderate Pitfalls

Issues that cause delays, confusion, or require rework but aren't critical.

### Pitfall 5: Tag Triggers Don't Work with Release Events
**What goes wrong:** Mixing `on: release` with tag filters like `tags: ['v*']` doesn't work. Tag filters only apply to `on: push` events.

**Why it happens:** GitHub Actions event filtering rules. Tag filters are only available for `push` and `pull_request` events, not `release` events.

**Consequences:**
- Workflow doesn't trigger when you create release from GitHub UI
- Confusion between release creation and tag push events
- Duplicate workflows if trying to cover both scenarios
- Manual releases fail to trigger automation

**Prevention:**
- Use `on: push: tags: ['v*']` for tag-triggered releases (creating release from UI also pushes tag)
- Or use `on: release: types: [published]` and filter with `if: startsWith(github.ref, 'refs/tags/v')`
- Don't mix tag filters with release events
- Document which method the project uses

**Detection:**
- Workflow doesn't run when release created from GitHub UI
- GitHub Actions tab shows no workflow runs for release
- Tag exists but workflow skipped

**Sources:**
- [How to trigger action from release, ignoring specific tags](https://github.com/orgs/community/discussions/25312)
- [Trigger with release event and specific tag](https://github.com/orgs/community/discussions/26603)
- [How to automate tagging and release workflows in GitHub](https://graphite.com/guides/how-to-automate-tagging-and-release-workflows-in-github)

---

### Pitfall 6: Missing `permissions: contents: write` Blocks Release Upload
**What goes wrong:** Upload release asset fails with 403 Forbidden or "Resource not accessible by integration" error.

**Why it happens:** Default `GITHUB_TOKEN` permissions in repositories with stricter security settings don't include `contents: write`.

**Consequences:**
- Release created but no assets attached
- Silent failure (workflow succeeds but ZIP missing)
- Manual asset upload required
- Users download source code instead of built app

**Prevention:**
- Add explicit permissions to workflow:
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
- Test release workflow on fork or test repository first

**Detection:**
- "Resource not accessible by integration" error in logs
- Release exists but has no uploaded assets
- HTTP 403 errors during upload step

**Sources:**
- [Controlling permissions for GITHUB_TOKEN - GitHub Docs](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/controlling-permissions-for-github_token)
- [What GitHub Actions permissions does Release Drafter Need](https://github.com/release-drafter/release-drafter/issues/869)
- [GitHub Actions Workflow Permissions - Ken Muse](https://www.kenmuse.com/blog/github-actions-workflow-permissions/)

---

### Pitfall 7: `xcodebuild archive` Requires Export Options Plist
**What goes wrong:** `xcodebuild -exportArchive` fails with "No 'teamID' specified and no team ID found in the archive" even when trying to export unsigned.

**Why it happens:** Xcode's export process requires `-exportOptionsPlist` parameter with explicit configuration, even for unsigned exports.

**Consequences:**
- Can't extract `.app` from `.xcarchive` automatically
- Need to create export options plist file in CI
- Manual archive extraction required (unreliable)
- Build succeeds but export fails

**Prevention:**
- Create `ExportOptions.plist` for unsigned export:
  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
      <key>method</key>
      <string>mac-application</string>
      <key>signingStyle</key>
      <string>automatic</string>
      <key>stripSwiftSymbols</key>
      <true/>
  </dict>
  </plist>
  ```
- Or extract `.app` directly from `.xcarchive/Products/Applications/`
- Use `xcodebuild build` instead of `archive` for unsigned apps (simpler path)

**Detection:**
- "No 'teamID' specified" error during export
- `.xcarchive` exists but export step fails
- Looking for exportOptionsPlist parameter errors

**Sources:**
- [xcodebuild export archive unsigned - Apple Developer Forums](https://developer.apple.com/forums/thread/75636)
- [xcodebuild -exportArchive fails - Apple Developer Forums](https://developer.apple.com/forums/thread/688626)
- [Use xcodebuild to archive and export app - R0uter's Blog](https://www.logcg.com/en/archives/3385.html)

---

### Pitfall 8: Upload Release Asset Doesn't Support Wildcards
**What goes wrong:** `actions/upload-release-asset` fails when using wildcards in `asset_path` like `build/*.zip`.

**Why it happens:** Action requires explicit filename, doesn't expand globs/wildcards.

**Consequences:**
- Can't upload dynamically named files (e.g., `PomodoroApp-v1.2.3.zip`)
- Need to know exact filename in advance or use shell tricks
- Multiple assets require multiple action invocations
- Complex workflows with find/set-output gymnastics

**Prevention:**
- Use shell to resolve filename before upload:
  ```yaml
  - name: Get artifact filename
    id: artifact
    run: echo "filename=$(ls build/*.zip)" >> $GITHUB_OUTPUT

  - name: Upload Release Asset
    uses: actions/upload-release-asset@v1
    with:
      asset_path: ${{ steps.artifact.outputs.filename }}
  ```
- Or use alternative actions that support wildcards:
  - `svenstaro/upload-release-action@v2`
  - `softprops/action-gh-release@v1`
- Use fixed naming: `PomodoroApp.zip` instead of version in filename

**Detection:**
- "Error: Unable to find *.zip" in workflow logs
- Asset path with asterisks visible in error message
- Upload step skipped or fails silently

**Sources:**
- [Add the ability to use wildcards for uploading files](https://github.com/actions/upload-release-asset/issues/60)
- [Dynamic Filenames (or an array?)](https://github.com/actions/upload-release-asset/issues/4)
- [use wildcards in asset_path](https://github.com/actions/upload-release-asset/issues/47)

---

### Pitfall 9: Pushing 3+ Tags Simultaneously Skips Workflow
**What goes wrong:** Tag-triggered workflows don't run if more than 3 tags are pushed at once.

**Why it happens:** GitHub Actions rate limiting/batch processing limitation to prevent abuse.

**Consequences:**
- Batch tagging for releases doesn't trigger CI
- Syncing tags from another repo misses builds
- Creating multiple version tags at once (e.g., `v1.0.0`, `v1.0`, `v1`) fails
- Silent skip (no error, just no workflow run)

**Prevention:**
- Push tags individually: `git push origin v1.0.0` (wait) then `git push origin v1.0`
- Use release workflow instead of tag workflow for batch scenarios
- Script to push tags with delays between pushes
- Document this limitation for maintainers

**Detection:**
- Multiple tags pushed but only 2-3 workflow runs
- Tags exist but corresponding builds missing
- Check workflow run history vs tag history

**Sources:**
- [How to trigger action from release, ignoring specific tags](https://github.com/orgs/community/discussions/25312)
- [Exploring GitHub Actions Triggers - Earthly Blog](https://earthly.dev/blog/github-action-triggers/)

---

## Minor Pitfalls

Small issues that are easy to fix or work around.

### Pitfall 10: Xcode 26.x Hangs/Times Out on GitHub Runners
**What goes wrong:** Builds using Xcode 26.0.1 or 26.1 hang for extended periods (30+ minutes) before timing out. ~75-80% failure rate.

**Why it happens:** Known issue with Xcode 26.x on GitHub Actions runners (both `macos-15` and `macos-15-arm64`).

**Consequences:**
- Workflow times out after 6 hours (default)
- Wasted CI minutes
- Unreliable builds
- Flaky test results

**Prevention:**
- **Pin to Xcode 15.x** until 26.x issue resolved:
  ```yaml
  - name: Select Xcode version
    run: sudo xcode-select -s /Applications/Xcode_15.4.app
  ```
- Monitor [actions/runner-images#13264](https://github.com/actions/runner-images/issues/13264) for resolution
- Add workflow timeout to fail fast: `timeout-minutes: 30`

**Detection:**
- Workflows that previously took 5-10 minutes now timeout
- Hanging at test phase (no output for 20+ minutes)
- Xcode 26.x visible in setup logs

**Sources:**
- [Xcode 26.0.1 / 26.1 RC hanging on both macos-15-arm64 and macos-26-xlarge](https://github.com/actions/runner-images/issues/13264)

---

### Pitfall 11: Simulator Runtimes Deprecated on macOS 15
**What goes wrong:** iOS/watchOS/tvOS simulator runtimes for older versions removed from macOS 15 runners due to disk space limits.

**Why it happens:** GitHub Actions limits macOS runners to 3 runtime sets per Xcode version. Older runtimes deprecated on schedule.

**Consequences:**
- Tests requiring iOS 16.x simulators fail on macos-15
- "Unable to find simulator runtime" errors
- Tests pass locally but fail in CI
- Not applicable to macOS-only apps (menubar timer safe)

**Prevention:**
- Download runtimes on-the-fly if needed:
  ```bash
  xcodebuild -downloadPlatform iOS -buildVersion 16.4
  ```
- Use macOS 14 runners if needing legacy simulators
- For macOS-only apps: not a concern
- Check deprecation schedule in runner-images issues

**Detection:**
- "No simulator runtime" errors in test phase
- Works on macos-14 but fails on macos-15
- Specific iOS version not found

**Sources:**
- [Deprecation of simulator runtimes for Xcode 26.0.1 on macOS 15](https://github.com/actions/runner-images/issues/13570)
- [Deprecation of simulator runtimes for Xcode 16.3 and older](https://github.com/actions/runner-images/issues/13392)

---

### Pitfall 12: Build vs Archive Output Paths Differ
**What goes wrong:** Expecting `.app` at same location regardless of whether using `xcodebuild build` or `xcodebuild archive`.

**Why it happens:** `build` outputs to `DerivedData/Build/Products/`, `archive` outputs to `.xcarchive/Products/Applications/`.

**Consequences:**
- ZIP step can't find `.app` bundle
- Switching between build/archive breaks workflow
- Hard-coded paths in CI scripts fail

**Prevention:**
- **Use consistent build command** across local and CI
- For unsigned apps, `xcodebuild build` is simpler (no export needed)
- If using `archive`, extract from correct path:
  ```bash
  cp -R build/PomodoroApp.xcarchive/Products/Applications/PomodoroApp.app .
  ```
- Or specify `-derivedDataPath` for predictable location

**Detection:**
- "No such file or directory" during ZIP step
- `.app` exists but at unexpected path
- Switching build type breaks CI

**Sources:**
- [Identifying the type of build (Build, Archive) at compile time in Xcode](https://blog.timac.org/2016/0623-identifying-the-type-of-build-build-archive-at-compile-time-in-xcode/)
- [xcodebuild archive not "single-bundle" - Apple Developer Forums](https://developer.apple.com/forums/thread/15694)

---

### Pitfall 13: `GITHUB_TOKEN` Can't Trigger Downstream Workflows
**What goes wrong:** Creating a release or tag with `GITHUB_TOKEN` doesn't trigger other workflows configured on `on: release` or `on: push: tags`.

**Why it happens:** Security feature preventing recursive workflow chains. Actions using `GITHUB_TOKEN` act as `github-actions[bot]`, which can't trigger new workflows.

**Consequences:**
- Workflow creates release but follow-up automation doesn't run
- Tag pushed by action doesn't trigger tag-based workflows
- Expected workflow chains break

**Prevention:**
- Use Personal Access Token (PAT) if chaining workflows is required
- Combine steps into single workflow instead of chaining
- Use `repository_dispatch` or `workflow_dispatch` for manual chaining
- Document that automated tags won't trigger other workflows

**Detection:**
- Release created but expected workflow doesn't run
- Manual releases work, automated ones don't
- `github.actor` shows "github-actions[bot]" in skipped runs

**Sources:**
- [How to trigger action from release, ignoring specific tags](https://github.com/orgs/community/discussions/25312)
- [Exploring GitHub Actions Triggers - Earthly Blog](https://earthly.dev/blog/github-action-triggers/)

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|----------------|------------|
| Workflow Setup | `macos-latest` changes | Pin to `macos-15` specifically |
| Build Configuration | Apple Silicon code signing | Use ad hoc signing minimum (`CODE_SIGN_IDENTITY="-"`) |
| Release Asset Upload | Missing permissions | Add `permissions: contents: write` |
| Tag Triggers | Tag filters on release events | Use `on: push: tags:` instead |
| Distribution Testing | Sequoia 15.1+ restrictions | Test on latest macOS, document installation |
| ZIP Creation | Quarantine attributes | Document `xattr` removal command |
| Multiple Tags | Batch push limit (3 tags) | Push tags individually with delays |
| Xcode Version | Xcode 26.x hanging | Pin to Xcode 15.x until resolved |
| Asset Naming | Wildcard paths fail | Resolve filename dynamically or use alt action |
| Build vs Archive | Different output paths | Use `build` for unsigned apps (simpler) |

---

## Integration Pitfalls

Specific to adding release automation to *existing* macOS menubar Pomodoro app.

### Pitfall 14: No Test Validation Before Release
**What goes wrong:** GitHub Actions builds and releases app without running test suite, shipping broken builds.

**Why it happens:** Forgot to add test step before release asset creation. Easy to skip in minimal workflows.

**Consequences:**
- Broken releases shipped to users
- Regression bugs in production
- Manual testing required before each release
- Loss of existing test coverage value

**Prevention:**
- **Add test step before build**:
  ```yaml
  - name: Run tests
    run: xcodebuild test -project PomodoroApp.xcodeproj -scheme PomodoroApp -destination 'platform=macOS'

  - name: Build for release
    if: success() # only if tests pass
    run: xcodebuild build ...
  ```
- Make test failure block release creation
- Use same test command as documented in `CLAUDE.md`

**Detection:**
- Releases created despite failing tests locally
- CI logs show no test execution
- Workflow completes in <1 minute (suspiciously fast)

---

### Pitfall 15: Info.plist Version Not Updated for Releases
**What goes wrong:** Built app shows wrong version number (e.g., "1.0" for all releases) because `CFBundleShortVersionString` not updated before build.

**Why it happens:** Manual version updates in Xcode not synced with git tags. CI builds whatever is committed.

**Consequences:**
- All releases show same version in "About" dialog
- Users can't tell which version they downloaded
- Multiple "1.0" releases confuse support/debugging

**Prevention:**
- Use `agvtool` to update version from tag:
  ```bash
  VERSION=${GITHUB_REF#refs/tags/v}
  xcrun agvtool new-marketing-version $VERSION
  ```
- Or use PlistBuddy:
  ```bash
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" Info.plist
  ```
- Add version bump script to workflow before build
- Consider automated version management (e.g., version file)

**Detection:**
- All releases show "Version 1.0" in About dialog
- Version in Info.plist doesn't match git tag
- Downloaded v2.0 shows as v1.0 in app

---

### Pitfall 16: Architecture Mismatch (Intel vs ARM)
**What goes wrong:** Workflow builds only for runner's native architecture, excluding half the user base.

**Why it happens:** `macos-15` runners are ARM64. Default builds produce ARM-only binaries unless explicitly configured for universal.

**Consequences:**
- Intel Mac users can't run downloaded app
- "architecture mismatch" errors on older Macs
- Need separate releases for Intel/ARM
- Rosetta 2 required for ARM-on-Intel (reverse won't work)

**Prevention:**
- **Build universal binary** (both architectures):
  ```yaml
  xcodebuild build \
    -project PomodoroApp.xcodeproj \
    -scheme PomodoroApp \
    -destination 'platform=macOS,arch=x86_64' \
    -destination 'platform=macOS,arch=arm64' \
    ONLY_ACTIVE_ARCH=NO
  ```
- Or set in Xcode: Build Settings → Architectures → "Standard Architectures (Apple Silicon, Intel)"
- Test on both architectures if possible

**Detection:**
- Users report "app not compatible with this Mac"
- `file PomodoroApp.app/Contents/MacOS/PomodoroApp` shows single arch
- Intel Mac users blocked

---

## Summary: Top 5 Pitfalls to Address First

1. **Sequoia 15.1+ Gatekeeper restrictions** (Critical) - Affects all unsigned apps, needs clear documentation
2. **ZIP quarantine attributes** (Critical) - Causes "damaged app" errors, needs xattr instructions
3. **Apple Silicon code signing requirement** (Critical) - Must use ad hoc signing minimum
4. **`macos-latest` instability** (Moderate) - Pin to specific version to prevent surprises
5. **Missing test validation** (Integration) - Don't ship untested builds

## Confidence Assessment

| Area | Confidence | Reason |
|------|------------|--------|
| macOS Security (Gatekeeper/Quarantine) | HIGH | Multiple official Apple sources, recent community reports |
| GitHub Actions Runners | HIGH | Official GitHub documentation and issue tracker |
| Xcodebuild/Code Signing | MEDIUM | Apple Developer Forums, varied solutions across Xcode versions |
| Tag/Release Triggers | HIGH | Official GitHub documentation, consistent behavior |
| Unsigned Distribution UX | MEDIUM | Community experience, subject to macOS version changes |

**Low confidence areas:**
- Future macOS restrictions on unsigned apps (Sequoia behavior may change)
- Xcode 26.x stability timeline (recent issue, resolution unknown)

**Verification sources:**
- Official GitHub Actions documentation
- Apple Developer documentation and forums
- GitHub Actions runner-images issue tracker
- Community technical blogs (verified against official sources)
