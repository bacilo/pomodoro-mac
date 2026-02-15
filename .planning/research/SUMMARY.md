# Project Research Summary: GitHub Actions Release Automation

**Project:** PomodoroApp (macOS menubar Pomodoro timer)
**Domain:** CI/CD automation for unsigned macOS app distribution via GitHub Actions
**Milestone:** v1.1 Release Automation
**Researched:** 2026-02-15
**Confidence:** HIGH

## Executive Summary

Release automation for unsigned macOS menubar apps requires a pragmatic, tag-driven GitHub Actions workflow that orchestrates existing build tools (xcodebuild, ditto, codesign) without modifying the project structure. The recommended approach is a linear CI/CD pipeline triggered by semantic version tags (v*.*.*)—checkout → build → ad-hoc sign → zip → release—using native macOS tools and GitHub's built-in release actions. **Critical design choice:** Apple Silicon Macs require ad-hoc code signing at minimum; completely unsigned builds fail on ARM64 hardware. **Key risk:** macOS Sequoia (15.1+) severely restricts unsigned app launching; this is unavoidable for unsigned distribution but must be documented and mitigated through clear installation instructions and optional Homebrew distribution. The workflow is architecturally simple but operationally requires understanding macOS security models, GitHub Actions runner environments, and proper build output handling to avoid common pitfalls (quarantine attributes, version drift, permission failures).

## Key Findings

### Recommended Stack

GitHub Actions release automation for macOS builds on native CI/CD infrastructure with minimal external dependencies. The stack leverages GitHub-provided macOS runners and integrates with existing Xcode toolchain:

**Core technologies:**
- **GitHub Actions (`macos-latest` → macOS 15):** CI/CD execution environment — use `macos-latest` for automatic updates to stable macOS version, currently resolving to macOS 15 Sequoia (as of Feb 2026); avoid `macos-14` (deprecated July 2026) and beta `macos-26` (stability issues)
- **actions/checkout@v6:** Repository cloning — latest major version; handles git operations efficiently without extra configuration
- **xcodebuild (native):** Build orchestration — uses existing project configuration; already validated in local workflow from `CLAUDE.md`
- **ditto (native macOS tool):** Distribution packaging — creates .zip files with preserved macOS metadata (resource forks, extended attributes); superior to standard `zip` command for app bundles
- **codesign (native):** Ad-hoc code signing — required minimum for Apple Silicon compatibility; uses `codesign --sign -` for unsigned apps (satisfies ARM64 security requirement without certificates)
- **PlistBuddy (native):** Version synchronization — updates `CFBundleShortVersionString` in Info.plist from git tag; no external dependencies
- **ncipollo/release-action@v1:** Release creation and asset upload — actively maintained alternative to deprecated `actions/create-release`; supports batch asset uploads and pre-release flagging

**Why this stack:**
All components are either native to macOS runners (no installation overhead) or well-maintained GitHub Actions with high community adoption. Avoids over-engineered solutions (e.g., Fastlane for unsigned builds) and deprecated actions. Total setup time: ~30 minutes to create `.github/workflows/release.yml`.

### Expected Features

Release automation for PomodoroApp has clear table stakes and reasonable deferrals based on complexity and user expectations:

**Table stakes (must implement):**
- Tag-triggered workflow (`on: push: tags: 'v*'`) — industry standard pattern; enables developers to push version tags and automatic releases
- Unsigned .app build via xcodebuild — produces Release configuration binary matching local build process
- Zip packaging with ditto — only distribution format needed for menubar app; users don't need installer
- SHA256 checksums — security best practice for download verification (even if rarely used)
- GitHub release creation with assets — makes .zip downloadable from Releases page
- Automatic release notes — GitHub's native feature generates notes from PR labels/commits

**Differentiators (should implement):**
- Ad-hoc code signing (required for ARM) — enables cross-architecture compatibility; goes from "crashes on M1" to "works everywhere"
- Draft release workflow — allows review before publishing (optional but recommended for confidence)
- Build verification steps — validate .app exists, version matches tag, before packaging (prevents releasing wrong artifacts)
- Pre-release flagging — tags with `-beta`/`-alpha` marked as pre-release in GitHub UI

**Defer to v2+ (not essential):**
- DMG creation — adds complexity (hdiutil scripting) and macOS image files; .zip sufficient for menubar app
- Semantic version auto-bumping — requires developer discipline with conventional commits; manual tagging is simpler
- Changelog from conventional commits — depends on project using PR labels; manual release notes acceptable
- Multi-format distribution (zip + dmg + tar) — pick one format (zip) and stick with it
- Build attestation/provenance — new GitHub feature; not critical for simple app
- Notarization or code signing with certificates — explicitly out of scope per project constraints

**Why this scope:**
The table stakes features directly enable the core use case (tag → download ready app). Differentiators improve reliability and user experience but aren't blockers. Deferred items require infrastructure (signing certs, versioning discipline) or add marginal value for a menubar app distributed via GitHub Releases.

### Architecture Approach

The release workflow architecture is a linear, single-job pipeline that doesn't modify the existing Xcode project structure. GitHub Actions provides the CI environment; the workflow orchestrates native macOS tools and GitHub APIs to transform git tags into downloadable app releases. Integration points are minimal: workflow files go in `.github/workflows/`, version updates happen in-CI only (Info.plist not committed), and build commands match local `CLAUDE.md` patterns.

**Key architecture decisions:**
1. **Single-job pipeline** — No parallelization needed; build → sign → zip → release has strict sequential dependencies
2. **Version flow: Tag → Info.plist → Xcode → Release** — Uses bash parameter expansion (`${GITHUB_REF#refs/tags/v}`) to extract version from tag; PlistBuddy updates Info.plist before build; xcodebuild embeds version into .app bundle
3. **Ad-hoc signing post-build** — Adds code signature after xcodebuild completes, enabling ARM compatibility without breaking unsigned distribution model
4. **Build vs. Archive:** Uses `xcodebuild build` (not archive) for simpler unsigned workflows; avoids need for `-exportArchive` which requires signing configuration
5. **Release creation via ncipollo/release-action** — Handles tag → release mapping, batch asset uploads, and pre-release detection without manual steps

**Major components:**
1. `.github/workflows/release.yml` — Workflow definition; triggers on `v*` tag push; defines 7-9 steps (checkout, version extraction, version update, build, sign, package, release)
2. GitHub Actions runner (macos-latest = macOS 15) — Provides Xcode toolchain, native tools (ditto, codesign, PlistBuddy); ~5-10 minute execution time
3. Build output directory (`build/Build/Products/Release/PomodoroApp.app`) — Consistent location via `-derivedDataPath build/`; expected by packaging step
4. Distribution artifact (`PomodoroApp-v1.2.3.zip`) — Created with ditto; uploaded as release asset; preserves macOS metadata for correct extraction

**Data flow:**
Git tag `v1.2.3` → GitHub event → Runner extracts version `1.2.3` → Updates Info.plist → xcodebuild embeds version → codesign applies ad-hoc signature → ditto creates zip → ncipollo uploads to release. Users download .zip and extract locally.

### Critical Pitfalls

Five pitfalls pose significant risk to release automation; understanding and preventing them is essential for a smooth v1.1 launch:

1. **Sequoia 15.1+ Gatekeeper restrictions (Critical):** macOS Sequoia 15.1+ removed the right-click "Open Anyway" bypass for unsigned apps. Users must navigate System Settings → Privacy & Security → scroll to app name → click "Open Anyway." This is unavoidable for unsigned apps. **Prevention:** Document installation steps with screenshots in README and release notes. Provide Homebrew cask as alternative distribution channel (users can install with `brew install pomodoro-mac --no-quarantine`). Test every release on latest macOS version. Set expectation in security documentation that unsigned apps require manual approval.

2. **ZIP quarantine attributes cause "app is damaged" errors (Critical):** macOS attaches `com.apple.quarantine` extended attribute to browser-downloaded ZIPs. When users extract with Finder, the attribute propagates to the .app bundle, triggering "app is damaged and can't be opened" error instead of standard unsigned app warning. **Prevention:** Document `xattr -r -d com.apple.quarantine PomodoroApp.app` command prominently in release notes. Create optional install script that removes quarantine and launches app. Consider DMG distribution (allows custom view with installation instructions) as future option. Note that command-line downloads (`curl`, `wget`) don't propagate quarantine, only browser downloads do.

3. **Apple Silicon requires ad-hoc code signing minimum (Critical):** ARM64 Macs (M1, M2, M3) refuse to launch completely unsigned executables, even with Gatekeeper disabled. Projects built with `CODE_SIGNING_REQUIRED=NO` crash on Apple Silicon with "Code signature invalid" errors. **Prevention:** Use `CODE_SIGN_IDENTITY="-"` (ad-hoc signing) instead of skipping signing entirely. Add `codesign --force --deep --sign -` step post-build to ensure ARM compatibility. Test on actual Apple Silicon hardware before releases. Verify GitHub Actions runners are ARM64 (`uname -m` → `arm64` in logs).

4. **macos-latest label changes break workflows (Moderate):** GitHub periodically updates what `macos-latest` points to (currently macOS 15 as of Aug 2025; will change to macOS 16 in ~12 months). Xcode version, Swift version, and available simulators change silently. Workflows that worked for months suddenly fail after GitHub updates runners. **Prevention:** Pin to specific runner version for releases: use `macos-15` instead of `macos-latest`. Monitor [actions/runner-images deprecation announcements](https://github.com/actions/runner-images/issues) for schedule. When macOS 16 lands, evaluate and upgrade workflow explicitly. Document runner version used for each release.

5. **Missing `permissions: contents: write` silently blocks release upload (Moderate):** Default GITHUB_TOKEN doesn't include release creation permissions in stricter security configs. Release action creates release object but fails to upload assets with 403 Forbidden, appearing as silent failure. **Prevention:** Add explicit `permissions: contents: write` to workflow or job. Test on fork/test repository before enabling on main. Check logs for "Resource not accessible by integration" errors.

**Integration-specific pitfalls:**
- **No test validation before release:** Workflow builds and releases without running test suite; broken code ships. Add test step before build; fail release if tests fail.
- **Info.plist version not synced with tags:** All releases show "1.0" because Info.plist not updated. Use PlistBuddy or agvtool to update version from tag before build.
- **Architecture mismatch (Intel vs ARM):** macOS 15 runners are ARM64; default builds are ARM-only. Add `-destination 'platform=macOS,arch=x86_64' -destination 'platform=macOS,arch=arm64'` and `ONLY_ACTIVE_ARCH=NO` for universal binaries. Or set in Xcode project settings.

## Implications for Roadmap

Research suggests a 3-phase approach, with deliberate choices informed by GitHub Actions patterns, macOS security constraints, and existing project structure:

### Phase 1: Core Release Workflow (Tag → Zip → Release)
**Rationale:** Establishes minimal viable release automation; creates the workflow file, hooks git tags to GitHub releases, validates build output can be packaged. Foundation for all future phases.

**Delivers:**
- `.github/workflows/release.yml` with 7-step pipeline
- Version extraction from tag
- xcodebuild Release build
- ditto zip packaging
- Release creation via ncipollo/release-action
- Checksums generated and included

**Implements (FEATURES.md):**
- Tag-triggered release
- Build app on tag push
- Zip artifact creation
- Upload zip to release
- SHA256 checksums
- GitHub CLI for releases

**Avoids (PITFALLS.md):**
- Pitfall 6: Missing permissions (add `permissions: contents: write` from start)
- Pitfall 13: No test validation (add `xcodebuild test` step before build)
- Pitfall 12: Build output path confusion (use consistent `-derivedDataPath build/`)

**Research flags:**
- Test workflow locally with `act` tool (optional, not critical)
- Validate xcodebuild flags match local `CLAUDE.md` patterns

**Standard patterns (skip research):**
- GitHub Actions workflow syntax (well-documented)
- xcodebuild command structure (existing project)

### Phase 2: Cross-Architecture and ARM Compatibility (Ad-hoc Signing + Verification)
**Rationale:** Adds critical missing piece for Apple Silicon support; prevents "crashes on M1" user reports. Also adds build verification to catch broken artifacts before release.

**Delivers:**
- Ad-hoc code signing step (`codesign --sign -`)
- Build verification (check .app exists, version matches)
- ARM64 compatibility for all releases
- Confidence that released .app is correct

**Implements (FEATURES.md):**
- Ad-hoc code signing (differentiator)
- Build verification steps

**Avoids (PITFALLS.md):**
- Pitfall 4: Apple Silicon code signing requirement (use ad hoc minimum)
- Pitfall 15: Info.plist version not updated (verify version in built .app matches tag)

**Research flags:**
- Test on actual Apple Silicon hardware if available
- Validate codesign command works post-build without breaking zip

**Standard patterns (skip research):**
- codesign command structure (documented in ARCHITECTURE.md)

### Phase 3: Release Polish and macOS Gatekeeper Guidance (Documentation + Optional Draft Workflow)
**Rationale:** Addresses operational risks around Sequoia restrictions and quarantine attributes; sets user expectations clearly. Optional draft release feature improves confidence for each release.

**Delivers:**
- Clear installation instructions in README
- Prominent release notes about Sequoia 15.1+ limitations
- xattr removal command documented
- Optional: Draft release workflow (review before publish)
- Optional: Homebrew cask integration (alternative distribution channel)

**Implements (FEATURES.md):**
- Draft release workflow (differentiator, deferred but easy to add)
- Automatic release notes customization
- Pre-release flagging for beta versions

**Avoids (PITFALLS.md):**
- Pitfall 1: Sequoia Gatekeeper restrictions (document installation steps with screenshots)
- Pitfall 2: ZIP quarantine attributes (document xattr command)
- Pitfall 5: Batch tag push limits (not applicable, single tag per release)

**Research flags:**
- Test release downloads on macOS 15.1+ actual hardware
- User testing on Sequoia to validate documentation clarity
- Evaluate Homebrew cask distribution (separate research if proceeding)

**Standard patterns (skip research):**
- GitHub release notes formatting (ARCHITECTURE.md provides examples)
- README documentation best practices

### Phase Ordering Rationale

1. **Phase 1 first:** Tag-triggered build is mandatory foundation. Cannot proceed to signing/verification without working build pipeline.
2. **Phase 2 second:** Adds code signing post-build (isolated change). Verification step improves reliability without changing workflow structure.
3. **Phase 3 third:** Documentation and optional enhancements. Phase 1 + 2 are sufficient for basic releases; Phase 3 improves user experience and prevents support burden.

**Why this grouping:**
Each phase has clear deliverables and can be tested independently. Phase 1 is MVP (tag → zip → release). Phase 2 solves critical ARM compatibility without modifying Phase 1 structure. Phase 3 is operational polish that can be deferred if schedule-constrained.

### Research Flags

**Phases needing deeper research:**
- **Phase 1 (optional):** Workflow testing with `act` tool (GitHub Actions runner simulator); not critical but can catch syntax errors locally before pushing
- **Phase 3 (optional):** Homebrew cask integration as alternative distribution channel; only if user feedback requests it

**Phases with standard, well-documented patterns:**
- **Phase 1:** GitHub Actions syntax, xcodebuild commands, ditto packaging all documented in ARCHITECTURE.md with examples
- **Phase 2:** Code signing and verification commands documented in ARCHITECTURE.md
- **Phase 3:** GitHub release notes formatting, README updates follow community best practices

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All technologies verified with official GitHub documentation, Apple Developer docs, and active GitHub Actions community. macos-latest → macOS 15 transition confirmed from runner-images repository. softprops/action-gh-release v2.5+ actively maintained with 1000+ stars. |
| Features | HIGH | Table stakes/differentiators/deferrals align with GitHub Actions release patterns and community best practices. Feature dependencies clearly mapped. Complexity analysis verified against multiple real-world macOS release workflows. |
| Architecture | HIGH | Workflow design follows GitHub Actions reference documentation. Version flow, build output paths, and release creation steps confirmed across official Apple docs, GitHub docs, and community implementations. ARCHITECTURE.md includes production-ready YAML examples. |
| Pitfalls | MEDIUM-HIGH | Critical pitfalls (Sequoia restrictions, quarantine attributes, ARM signing) verified against multiple sources including Apple security documentation and recent community reports (Hackaday, OSnews). GitHub Actions runner pitfalls from official runner-images repository. Some pitfalls (e.g., Xcode 26.x hanging) from recent open issues; timeline/resolution unknown. |

**Overall confidence:** HIGH

### Gaps to Address

- **Xcode 26.x stability:** PITFALLS.md flags Xcode 26.0.1/26.1 hanging issues on GitHub runners (~75-80% failure rate). GitHub Actions runner-images issue #13264 suggests resolution pending. Recommendation: Pin to Xcode 15.x for Phase 1, evaluate 26.x after patch release.
- **Sequoia 15.1+ behavior permanence:** Currently (as of Feb 2026), unsigned apps face severe Gatekeeper restrictions on Sequoia. It's unclear if this is permanent policy or temporary enforcement bug. Mitigation: Document limitation prominently; monitor Apple dev forums. Consider code signing/notarization if user friction becomes significant.
- **Homebrew distribution viability:** PITFALLS.md mentions Homebrew as alternative with `--no-quarantine` flag for better UX. Not researched in FEATURES.md because it's outside core release automation scope. Defer to Phase 3+ if users request it.
- **Build caching performance:** FEATURES.md mentions `actions/cache` for derived data but not explored in detail. Not critical for ~5-minute build times, but could accelerate if phased builds become necessary.
- **Multi-architecture universal binary validation:** PITFALLS.md discusses Intel/ARM split but doesn't provide validated xcodebuild flags for universal builds. Phase 2 research should include explicit testing of dual-arch build configuration.

## Sources

### Official Documentation (HIGH confidence)
- [GitHub Actions Workflow Syntax](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions) — workflow YAML structure, triggers, runners
- [GitHub Actions macOS Runners Reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) — macOS versions, deprecation schedule
- [Controlling permissions for GITHUB_TOKEN](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/controlling-permissions-for-github_token) — required permissions for releases
- [Apple Packaging Mac Software for Distribution](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution) — ditto, code signing, build configuration
- [Apple Code Signing Guide](https://developer.apple.com/documentation/xcode/code-signing) — ad-hoc signing, entitlements
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release) — production release action
- [actions/checkout@v6](https://github.com/actions/checkout) — repository cloning in workflows

### Community Resources (MEDIUM-HIGH confidence)
- [Distributing Mac Apps With GitHub Actions (defn.io 2023)](https://defn.io/2023/09/22/distributing-mac-apps-with-github-actions/) — comprehensive workflow examples, patterns
- [macOS Distribution: Code Signing, Notarization, Quarantine (rsms gist)](https://gist.github.com/rsms/929c9c2fec231f0cf843a1a746a416f5) — detailed explanation of quarantine, signing requirements
- [GitHub Actions Runner Images Repository](https://github.com/actions/runner-images) — deprecation announcements, Xcode versions, known issues
- [Apple Forces The Signing Of Applications In MacOS Sequoia 15.1 (Hackaday 2024)](https://hackaday.com/2024/11/01/apple-forces-the-signing-of-applications-in-macos-sequoia-15-1/) — Sequoia Gatekeeper restrictions
- [macOS 15.1 Completely Removes Ability to Launch Unsigned Applications (OSnews)](https://www.osnews.com/story/141055/) — alternative perspective on Sequoia behavior

### Research Files (This Milestone)
- `STACK.md` — Technology selections with deprecation timelines and build configuration flags
- `RELEASE_AUTOMATION_FEATURES.md` — Feature landscape with MVP scope and deferrals
- `RELEASE_AUTOMATION_ARCHITECTURE.md` — Complete workflow design with YAML examples and patterns
- `GITHUB_ACTIONS_PITFALLS.md` — 16 documented pitfalls with detection and prevention strategies

---

**Research completed:** 2026-02-15
**Synthesized by:** GSD Research Synthesizer
**Ready for roadmap:** yes
**Next step:** Proceed to Phase 1 planning with ARCHITECTURE.md YAML examples as starting point
