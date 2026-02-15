# Requirements: PomodoroApp

**Defined:** 2026-02-15
**Core Value:** The timer must reliably track work sessions and automatically reset for each new day without manual intervention.

## v1.1 Requirements

Requirements for v1.1 Distribution milestone. Each maps to roadmap phases.

### Build & Release Automation

- [ ] **BUILD-01**: GitHub Actions workflow triggers on version tag push (v*)
- [ ] **BUILD-02**: Workflow builds app with xcodebuild in Release configuration
- [ ] **BUILD-03**: Built .app is packaged into zip using ditto
- [ ] **BUILD-04**: GitHub Release is created with zip attached as downloadable asset
- [ ] **BUILD-05**: SHA256 checksum file is generated and attached to release

### Version Management

- [ ] **VERS-01**: Version number is extracted from git tag (v1.1 → 1.1)
- [ ] **VERS-02**: MARKETING_VERSION in Info.plist is set from tag during CI build
- [ ] **VERS-03**: CURRENT_PROJECT_VERSION is bumped in CI build

### Compatibility

- [ ] **COMPAT-01**: Built .app is ad-hoc code signed for Apple Silicon compatibility
- [ ] **COMPAT-02**: Build produces universal binary (Intel + Apple Silicon)
- [ ] **COMPAT-03**: CI verifies .app structure and version match after build

### Documentation

- [ ] **DOCS-01**: README includes installation instructions for downloading and opening the app
- [ ] **DOCS-02**: README includes Gatekeeper bypass instructions (xattr -cr)

## Future Requirements

None deferred for this milestone.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Code signing with Developer ID | No Apple Developer account; users accept Gatekeeper warnings |
| Notarization | Requires Developer ID signing first |
| Auto-updater (Sparkle) | Premature for first release; add when user base exists |
| DMG packaging | Zip is simpler and sufficient for initial distribution |
| Homebrew cask | Can add later once releases are established |
| Semantic version auto-bumping | Manual tag control preferred |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUILD-01 | Phase 3 | Pending |
| BUILD-02 | Phase 3 | Pending |
| BUILD-03 | Phase 3 | Pending |
| BUILD-04 | Phase 3 | Pending |
| BUILD-05 | Phase 3 | Pending |
| VERS-01 | Phase 3 | Pending |
| VERS-02 | Phase 3 | Pending |
| VERS-03 | Phase 3 | Pending |
| COMPAT-01 | Phase 4 | Pending |
| COMPAT-02 | Phase 4 | Pending |
| COMPAT-03 | Phase 4 | Pending |
| DOCS-01 | Phase 5 | Pending |
| DOCS-02 | Phase 5 | Pending |

**Coverage:**
- v1.1 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0 ✓

---
*Requirements defined: 2026-02-15*
*Last updated: 2026-02-15 after roadmap creation*
