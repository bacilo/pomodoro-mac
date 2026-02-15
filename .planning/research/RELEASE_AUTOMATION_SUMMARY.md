# Research Summary: GitHub Actions Release Automation

**Domain:** Automated macOS app distribution via GitHub Actions
**Researched:** 2026-02-15
**Overall confidence:** HIGH

## Executive Summary

GitHub Actions release automation for macOS apps follows a well-established pattern: tag push triggers workflow, workflow builds app, packages as zip, generates checksum, and creates release with assets. This is table stakes for open source macOS projects.

The core workflow is straightforward (LOW complexity): trigger on version tags (`v*` pattern), build with `xcodebuild`, package with `ditto`, checksum with `shasum`, and upload with `gh release create`. GitHub's built-in release notes generation eliminates need for custom changelog solutions.

Key finding: **Start simple.** Zip-only distribution, no version bumping, no DMG. The macOS runner cost ($0.08/min) is negligible for typical release cadence (<10/month). Defer enhancements (DMG, attestation, changelog generation) until MVP proves value.

Critical constraint: Project has NO code signing/notarization (explicit), which simplifies workflow but requires clear user communication about unsigned app warnings.

## Key Findings

**Stack:** GitHub Actions with macos-latest runner, GitHub CLI for release management, native macOS tools (xcodebuild, ditto, shasum)

**Architecture:** Single-workflow pattern - tag push → checkout → build → package → checksum → release with auto-generated notes

**Critical pitfall:** .app bundles are folders; upload requires zip packaging, not direct upload (Actions treats as directory)

## Implications for Roadmap

Based on research, suggested phase structure:

1. **Phase 1: Core Release Workflow** (1-2 days)
   - Addresses: Tag-triggered builds, zip packaging, checksum generation, GitHub release creation
   - Avoids: Over-engineering (no DMG, no version bumping, no signing)
   - Rationale: Get working releases immediately, iterate from user feedback

2. **Phase 2: Enhanced Release Notes** (optional, 0.5-1 day)
   - Addresses: Structured changelog from PR labels, contributor attribution
   - Avoids: Complex commit parsing (no conventional commits requirement)
   - Rationale: Polish existing workflow without changing development practices

3. **Phase 3: Release Improvements** (optional, 1-2 days)
   - Addresses: DMG creation, build attestation, draft release workflow
   - Avoids: Auto-updater framework (separate feature domain)
   - Rationale: Enhancements based on user requests after MVP validation

**Phase ordering rationale:**
- Phase 1 provides immediate value (downloadable releases) with minimal complexity
- No dependencies between phases (each builds on working releases)
- Each phase can be skipped if not needed (flexible roadmap)
- Cost-conscious: macOS runner time only for actual releases (tag-triggered)

**Research flags for phases:**
- Phase 1: **Unlikely to need research** - standard patterns, well-documented
- Phase 2: **Unlikely to need research** - GitHub native feature with simple config
- Phase 3: **May need DMG research** - hdiutil scripting has edge cases (volume sizing, aesthetics)

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | GitHub Actions + CLI + native tools all verified via official docs |
| Features | HIGH | Clear table stakes (build/package/release) vs nice-to-have (DMG/attestation) |
| Architecture | HIGH | Single workflow pattern is universal for release automation |
| Pitfalls | HIGH | .app bundle folder issue well-documented; unsigned app warnings clear |

## Gaps to Address

**Resolved during research:**
- Tag trigger patterns → HIGH confidence (official docs + multiple sources)
- Zip packaging on macOS → HIGH confidence (ditto is standard tool)
- Release asset upload → HIGH confidence (GitHub CLI pre-installed on runners)
- Checksum generation → HIGH confidence (standard shasum tool)

**Deferred to implementation:**
- Exact xcodebuild command for this specific project → Read build docs in phase
- Build output path for .app location → Verify during first build
- GitHub runner macOS version vs deployment target → Check compatibility matrix

**Not needed for MVP:**
- Version bumping automation (anti-feature per project constraints)
- Code signing/notarization (explicitly out of scope)
- Sparkle auto-updater (separate feature domain)
