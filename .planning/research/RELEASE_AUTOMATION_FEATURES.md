# Feature Landscape: GitHub Actions Release Distribution

**Domain:** Automated macOS app releases via GitHub Actions
**Researched:** 2026-02-15

## Table Stakes

Features users expect from automated release workflows. Missing = incomplete release automation.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Tag-triggered release | Industry standard pattern - push tag → release | Low | `on: push: tags: 'v*'` is universal pattern |
| Build app on tag push | Core requirement - must build .app from source | Low | Uses `xcodebuild` on macos-latest runner |
| Zip artifact creation | Simplest macOS distribution format | Low | Use `ditto -c -k --sequesterRsrc --keepParent` |
| Upload zip to release | Users need downloadable artifact | Low | `gh release upload` or upload-release-asset action |
| SHA256 checksum | Security verification for downloads | Low | Generate with `shasum -a 256` |
| Automatic release notes | GitHub native feature, users expect it | Low | Built-in via `.github/release.yml` config |
| Release asset listing | Users need to see what's available | Low | Automatic when assets uploaded |
| GitHub CLI for releases | Pre-installed on runners, most reliable | Low | `gh release create` simpler than API actions |

## Differentiators

Features that set release automation apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Version bump automation | Auto-increment version in Xcode project | Medium | Requires `agvtool` and project config changes |
| Changelog from commits | Conventional commits → structured notes | Medium | Actions like release-changelog-builder |
| Draft release workflow | Review before publish, attach all assets first | Low | Recommended for immutable releases |
| Multiple asset formats | .zip + .dmg for user choice | Medium | DMG creation requires `hdiutil create` |
| Attestation/provenance | Supply chain security, verify build source | Medium | GitHub's `actions/attest-build-provenance` |
| Release size reporting | Show download size in notes | Low | Parse zip size, add to release body |
| Caching build artifacts | Faster subsequent builds | Low | Cache derived data with `actions/cache` |
| Version extraction from tag | Parse semver from git tag for versioning | Low | Use `${GITHUB_REF#refs/tags/}` |
| Asset upload retry logic | Resilience against network failures | Low | Built into `gh` CLI or use softprops/action-gh-release |
| Prerelease tagging | Mark beta/rc releases distinctly | Low | `gh release create --prerelease` for non-stable |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Semantic version auto-bumping | Requires commit conventions not in place; adds complexity without project buy-in | Manual version tags (developer controls versioning) |
| Code signing in CI | Requires secrets management for certificates; outside project scope (explicitly no signing) | Document that app is unsigned; user responsibility |
| Notarization workflow | Requires Apple Developer account, paid; explicitly out of scope | Skip entirely per project constraints |
| Auto-merge version bumps | Risk of broken builds in main; unnecessary for tag-based workflow | Tag on main directly, no version bump commits |
| DMG with custom background | Adds design complexity, large binary assets in repo | Use plain DMG or just zip |
| Delta updates/auto-updater | Requires embedded update framework (Sparkle); separate feature domain | Future consideration, not in release automation scope |
| Multi-platform builds | macOS-only app | N/A |
| App Store distribution | Outside scope (direct distribution only) | GitHub releases only |
| Version number validation | Tags are source of truth; pre-push validation belongs in dev workflow | Trust developer to tag correctly |
| Rollback automation | Releases are immutable; delete manually if needed | GitHub web UI for release management |

## Feature Dependencies

```
Tag push (Git) → Workflow trigger
Workflow trigger → Checkout code → Build app
Build app → Create zip
Create zip → Generate checksum
Checksum + zip → Upload to release
Release creation → Auto-generated notes (if .github/release.yml exists)

Optional enhancements:
Tag → Parse version → Set in release metadata
Draft release → Upload assets → Publish release (manual)
Build → Attest provenance → Upload attestation
```

## MVP Recommendation

**Phase 1: Basic automated release**
Prioritize:
1. **Tag-triggered workflow** - `on: push: tags: 'v*'` pattern
2. **Build .app with xcodebuild** - Standard build command
3. **Zip creation** - `ditto` for macOS-compatible archive
4. **SHA256 checksum** - Security best practice
5. **GitHub CLI release creation** - `gh release create` with assets
6. **Basic release notes** - GitHub auto-generated from PRs/commits

**Phase 2: Polish and resilience** (if desired)
Defer to future:
- Changelog generation from conventional commits
- Draft release workflow
- Build attestation/provenance
- DMG creation as alternative format
- Version extraction and metadata

## Complexity Analysis

| Feature Category | Complexity | Rationale |
|------------------|------------|-----------|
| Core workflow setup | Low | Well-documented pattern, simple YAML |
| Xcode build in CI | Low | Single `xcodebuild` command, no signing |
| Zip packaging | Low | One-liner `ditto` command |
| Checksum generation | Low | One-liner `shasum` command |
| GitHub CLI upload | Low | `gh release create` handles everything |
| Auto release notes | Low | Config file `.github/release.yml` |
| Version bumping | Medium | Requires `agvtool` setup + project settings |
| Changelog generation | Medium | Third-party action configuration |
| DMG creation | Medium | `hdiutil` scripting, testing needed |
| Build caching | Low | `actions/cache` with derived data path |

## Implementation Notes

### Tag Format
Recommend semver tags: `v1.0.0`, `v1.1.0`, `v2.0.0-beta.1`
- Prefix `v` is convention for version tags
- Semver enables `v*` wildcard matching
- Prerelease suffix (e.g., `-beta.1`) for testing

### Workflow File Location
`.github/workflows/release.yml`

### Runner Choice
`runs-on: macos-latest` ($0.08/min)
- Cost consideration: macOS runners are 10x more expensive than Linux
- Optimization: Only trigger on tags, not all pushes
- Build time estimate: 2-5 minutes for typical macOS app

### Zip vs DMG
**Start with zip only:**
- Simpler (one command)
- No binary assets to maintain
- Sufficient for menubar app with no installer needs
- macOS handles zip extraction natively

**DMG considerations for later:**
- Better for apps needing installation instructions
- Can include symlink to /Applications
- Perception of "more professional"
- Adds complexity: volume size calculation, testing

### Current Project Version Fields
Project uses:
- `MARKETING_VERSION=1.0` (user-facing version)
- `CURRENT_PROJECT_VERSION=1` (build number)

**Recommendation:**
- Do NOT auto-bump these in workflow
- Keep versions in Xcode project, sync with git tags manually
- Tag format `v1.0` matches MARKETING_VERSION
- Avoid version drift between code and tags

### Release Notes Strategy
**Use GitHub's auto-generated notes:**
1. Create `.github/release.yml`:
```yaml
changelog:
  categories:
    - title: Features
      labels: [feature, enhancement]
    - title: Bug Fixes
      labels: [bug, fix]
    - title: Other Changes
      labels: ["*"]
```
2. Label PRs appropriately
3. Auto-generation includes contributor list

**Alternative:** If no PR workflow, use `gh release create --generate-notes` which creates notes from commits.

### Checksum File Format
Standard format for macOS distribution:
```
SHA256 (PomodoroApp.zip) = abc123...
```

Users verify with: `shasum -a 256 -c checksums.txt`

### Asset Naming Convention
- `PomodoroApp-v1.0.0.zip` - Include version in filename
- `checksums.txt` - Standard name for checksum file
- Avoid: `app.zip`, `release.zip` (not descriptive)

## Workflow Stages

Typical flow for tag → release:

```
1. Developer creates tag locally:
   git tag v1.0.0
   git push origin v1.0.0

2. GitHub Actions workflow triggers:
   - Checkout code
   - Extract version from tag (e.g., "v1.0.0")
   - Build with xcodebuild
   - Locate .app bundle in build output
   - Create zip with ditto
   - Generate SHA256 checksum
   - Create checksums.txt file

3. Release creation:
   - gh release create $TAG
   - Upload zip
   - Upload checksums.txt
   - Auto-generate release notes
   - Mark as prerelease if tag contains -beta/-rc

4. User downloads:
   - Visit Releases page
   - Download .zip
   - Verify checksum (optional but recommended)
   - Extract and run
```

## Testing Strategy

| Test Type | Approach | Complexity |
|-----------|----------|------------|
| Workflow syntax | Local with `act` or push to test branch | Low |
| Build success | Create test tag, verify build completes | Low |
| Zip validity | Download artifact, verify extraction | Low |
| Checksum accuracy | Download zip, run `shasum -a 256 -c` | Low |
| Release notes | Verify auto-generation works | Low |
| Version parsing | Test with various tag formats | Low |

## Cost Considerations

| Factor | Impact | Mitigation |
|--------|--------|------------|
| macOS runner cost | $0.08/min vs $0.008/min Linux | Only run on tags, not all pushes |
| Build time | 2-5 min per release | Acceptable for infrequent releases |
| Storage | Release assets count toward repo size | Zips are small (<10MB for typical menubar app) |
| Monthly minutes | 2,000 free/month for public repos | ~400 releases before hitting limit (unrealistic) |

**Verdict:** Cost is negligible for typical release cadence (< 10 releases/month).

## Sources

### Official Documentation
- [GitHub Actions Workflow Syntax](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions) - MEDIUM confidence (official but generic)
- [GitHub Automatically Generated Release Notes](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes) - HIGH confidence (official, specific feature)
- [GitHub Managing Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository) - HIGH confidence (official)

### Community Resources & Actions
- [GitHub Actions Complete Guide 2026](https://devtoolbox.dedyn.io/blog/github-actions-cicd-complete-guide) - MEDIUM confidence (comprehensive guide)
- [Release Changelog Builder Action](https://github.com/marketplace/actions/release-changelog-builder) - MEDIUM confidence (popular action)
- [iOS Bump Version Action](https://github.com/marketplace/actions/ios-bump-version) - MEDIUM confidence (version bumping pattern)
- [Upload Release Asset Action](https://github.com/marketplace/actions/upload-release-asset) - MEDIUM confidence (official GitHub action)
- [SHA256 Checksum Action](https://github.com/marketplace/actions/sha256-checksum) - LOW confidence (community action)
- [Tag/Release on Push](https://github.com/marketplace/actions/tag-release-on-push-action) - MEDIUM confidence (establishes pattern)

### Technical Implementation
- [Distributing Mac Apps Outside App Store](https://www.rambo.codes/posts/2021-01-08-distributing-mac-apps-outside-the-app-store) - MEDIUM confidence (practical guide, slightly dated)
- [GitHub Actions Run on Tag Creation](https://futurestud.io/tutorials/github-actions-run-a-workflow-when-creating-a-tag) - MEDIUM confidence (pattern documentation)
- [Automatically Bump Xcode Versions](https://gist.github.com/dimitribouniol/24f0406e0878e5880f3a64dea3c528b6) - LOW confidence (gist, not maintained)
- [Upload File to GitHub Release](https://michael-mckenna.com/how-to-upload-file-to-github-release-in-a-workflow/) - MEDIUM confidence (tutorial with examples)

### Build Attestation
- [GitHub Actions Attest Build Provenance](https://github.com/actions/attest-build-provenance) - HIGH confidence (official GitHub action)
- [Using Artifact Attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations) - HIGH confidence (official docs)

### Discussion & Best Practices
- [Xcode Version Bump Setup](https://www.paleblueapps.com/rockandnull/how-to-setup-github-actions-to-bump-xcode-version/) - MEDIUM confidence (practical implementation)
- [macOS Bundle Upload Issue](https://github.com/actions/upload-artifact/issues/326) - MEDIUM confidence (identifies .app bundle handling gotcha)
- [Release Workflow Patterns](https://www.thisdot.co/blog/tag-and-release-your-project-with-github-actions-workflows) - MEDIUM confidence (pattern guide)

## Confidence Assessment

| Area | Confidence | Rationale |
|------|------------|-----------|
| Tag-triggered workflow | HIGH | Universal pattern, GitHub official docs, multiple sources |
| Build process | HIGH | Standard xcodebuild, well-documented |
| Zip packaging | HIGH | macOS native tool (ditto), multiple sources confirm |
| GitHub CLI usage | HIGH | Pre-installed on runners, official tool |
| Checksum generation | HIGH | Standard Unix tool, security best practice |
| Auto release notes | HIGH | GitHub native feature, official docs |
| Version bumping | MEDIUM | Multiple approaches exist, agvtool has gotchas |
| Changelog generation | MEDIUM | Third-party actions, configuration varies |
| DMG creation | MEDIUM | hdiutil is standard but scripting complexity |
| Build attestation | MEDIUM | New GitHub feature, less battle-tested |

## Gaps & Future Research

**Topics not fully explored (low priority for MVP):**
- Sparkle auto-updater integration (separate feature domain)
- Brew cask distribution (alternative distribution channel)
- Download analytics (requires third-party service)
- Release announcement automation (Discord/Slack webhooks)

**Known unknowns:**
- Optimal build caching strategy for Xcode (phase-specific research if builds are slow)
- Multi-architecture builds (Intel + Apple Silicon) - may need `xcodebuild -arch` flags

**Validation needed in implementation phase:**
- Exact xcodebuild command for menubar app
- Build output path for .app bundle location
- ditto flags compatibility with current macOS versions
- GitHub runner macOS version compatibility with deployment target
