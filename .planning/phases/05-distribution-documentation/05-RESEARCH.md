# Phase 5: Distribution Documentation - Research

**Researched:** 2026-02-16
**Domain:** Documentation for macOS app distribution without Developer ID signing
**Confidence:** HIGH

## Summary

Phase 5 focuses purely on documentation to enable successful app distribution despite macOS Gatekeeper restrictions. With Phases 3-4 complete, the GitHub Actions workflow already produces universal binary releases with ad-hoc code signing. The challenge is user-facing: macOS Sequoia 15.1+ has severely restricted unsigned app installation, removing traditional bypass methods.

This phase requires updating README.md with clear installation instructions and documenting the `xattr -cr` command (or more specifically `xattr -r -d com.apple.quarantine`) to remove quarantine attributes. The release notes already include Sequoia-specific workarounds (implemented in Phase 3), so the README serves as permanent documentation for all users.

No code changes are needed—this is a pure documentation phase. The first release (v1.1.0) will validate that the complete pipeline (build → package → release → download → install) works end-to-end for real users.

**Primary recommendation:** Update README.md with a comprehensive Installation section that covers both standard and Sequoia-specific installation paths, document the xattr command with clear explanation of what it does and why it's needed, and create the first release tag to validate the complete distribution pipeline.

## Standard Stack

### Core Documentation Tools

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Markdown | GitHub-Flavored | README.md format | Universal for GitHub repositories, renders in web interface |
| GitHub Releases | N/A | Release distribution platform | Built into GitHub, no additional hosting needed |
| xattr command | System (macOS) | Remove quarantine attributes | Native macOS tool, available on all systems |

### Supporting Elements

| Element | Purpose | When to Use |
|---------|---------|-------------|
| Installation section in README | Primary user-facing documentation | Always - first thing users see |
| Release notes in GitHub Release | Version-specific instructions and changes | Per-release - covers what's new |
| Code blocks with shell commands | Copy-paste ready instructions | For technical steps requiring terminal |
| Troubleshooting subsections | Common installation issues | When known pain points exist (Sequoia restrictions) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| xattr -r -d com.apple.quarantine | xattr -cr | -cr removes ALL extended attributes (more aggressive), -r -d removes only quarantine (surgical) |
| README installation section | Separate INSTALL.md file | README is expected location for quick start, separate file adds friction |
| Command-line instructions | Screenshots/GIF walkthrough | Screenshots harder to maintain, text is copy-paste-able and version-control friendly |
| v1.1.0 first release | v1.0.0 first release | v1.0 implies initial public release, v1.1 signals this is an enhancement to existing v1.0 milestone |

**No installation required** - Documentation is written in Markdown, committed to repository.

## Architecture Patterns

### Recommended Documentation Structure

```
README.md
├── Header (badges, description)
├── Features
├── Installation                    # PRIMARY UPDATE FOR PHASE 5
│   ├── Download from GitHub Releases
│   ├── Standard Installation (macOS 14 and earlier)
│   ├── macOS Sequoia 15.1+ Installation (xattr workaround)
│   └── Verify Download (checksums)
├── Build from Source (existing)
├── Usage
├── Development (links to CLAUDE.md)
└── License
```

**Key insight:** Installation section must handle TWO user paths: (1) simple path for macOS 14 and earlier, (2) multi-step path for Sequoia 15.1+ with clear escalation from simple to complex.

### Pattern 1: Progressive Disclosure for Installation Steps

**What:** Start with simplest path, escalate to more complex steps only when needed

**When to use:** When user experience varies significantly by platform version (macOS 14 vs 15.1+)

**Example:**
```markdown
## Installation

### Download

Download the latest release from the [Releases](https://github.com/user/repo/releases) page.

### Standard Installation

1. Extract the .zip file
2. Move PomodoroApp.app to /Applications
3. **First launch:** Right-click → Open (required for unsigned apps)

> **macOS 15.1+ Sequoia users:** If you see a "damaged app" error, see [Sequoia Installation](#sequoia-installation) below.

### macOS 15.1+ Sequoia Installation {#sequoia-installation}

macOS Sequoia has stricter security requirements. Follow these steps:

1. Extract and move the app to /Applications as above
2. Open Terminal and run:
   ```bash
   xattr -cr /Applications/PomodoroApp.app
   ```
3. Go to System Settings → Privacy & Security
4. Scroll down and click "Open Anyway" next to PomodoroApp
```

**Why this pattern:**
- Users on older macOS don't see intimidating terminal commands first
- Clear signpost ("If you see X error, go here") helps users self-diagnose
- Technical users can skip to their relevant section
- Anchor links enable cross-referencing from GitHub Release notes

### Pattern 2: Command Explanation, Not Just Commands

**What:** Explain what a terminal command does and why it's necessary, not just "run this"

**When to use:** When asking users to run potentially concerning commands (xattr, sudo)

**Example:**
```markdown
### Why This Command is Needed

macOS adds a "quarantine" flag to downloaded apps for security. This causes
Sequoia 15.1+ to block unsigned apps entirely. The command below removes
only this quarantine flag, allowing the app to run normally.

```bash
xattr -cr /Applications/PomodoroApp.app
```

**What this does:** Removes quarantine attributes from the app (does not modify the app code itself)
```

**Why this pattern:**
- Builds user trust (they understand what they're running)
- Reduces support requests ("is this safe?")
- Educates users about macOS security model
- Differentiates between xattr -cr (remove all attributes) and xattr -r -d (remove specific attribute)

### Pattern 3: Version-First Release Tagging

**What:** First GitHub Release should match milestone version (v1.1.0), not v1.0.0

**When to use:** When v1.0 was a prior milestone (Bug Fixes) and current milestone is v1.1 (Distribution)

**Rationale:**
- Roadmap shows v1.0 milestone already shipped (Phases 1-2)
- v1.1 milestone is in progress (Phases 3-5)
- First *automated* release is v1.1.0, not first release ever
- Semantic versioning: v1.1.0 indicates minor feature addition (automated distribution) to v1.0 (working app)

**Tag naming:** v1.1.0 (not v1.0.0)

### Anti-Patterns to Avoid

**❌ DON'T: Use `xattr -cr` without explaining the difference from `xattr -r -d com.apple.quarantine`**
- `xattr -cr` removes ALL extended attributes (Finder tags, metadata, etc.)
- `xattr -r -d com.apple.quarantine` removes ONLY the quarantine flag
- Research shows -r -d is more surgical, but -cr is simpler for users to type
- **INSTEAD:** Use `xattr -cr` for simplicity (matches requirement DOCS-02), explain what it does in documentation

**❌ DON'T: Bury Sequoia instructions in footnotes or "Advanced" sections**
- Sequoia 15.1+ users represent growing percentage of macOS users
- "Damaged app" error is blocking, not optional
- **INSTEAD:** Make Sequoia section prominent with clear signposting from main installation section

**❌ DON'T: Document workarounds without explaining why they're needed**
- "Run this command" without context feels suspicious
- Users won't trust random terminal commands from internet
- **INSTEAD:** Explain macOS quarantine system, what xattr does, why it's safe

**❌ DON'T: Assume users know what "Gatekeeper" or "quarantine attributes" mean**
- Technical jargon intimidates non-technical users
- **INSTEAD:** Use plain language ("macOS security flag", "downloaded app restrictions")

**❌ DON'T: Skip checksum verification instructions**
- Phase 3 workflow generates SHA256 checksums
- Security best practice for downloaded binaries
- **INSTEAD:** Include optional "Verify Download" section with shasum command

**❌ DON'T: Create v1.0.0 as first release when v1.0 milestone already shipped**
- Confuses versioning history (v1.0 Bug Fixes milestone already complete)
- **INSTEAD:** Use v1.1.0 to match current milestone (v1.1 Distribution)

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Installation walkthroughs | Custom documentation site, Notion, GitBook | README.md Installation section | Users expect instructions in README, additional sites add friction and maintenance burden |
| Release distribution | Self-hosted downloads, Dropbox links | GitHub Releases | Built into GitHub, includes versioning, asset management, no hosting costs |
| macOS security workarounds | Custom installer scripts, DMG with post-install hooks | Document xattr command in README | Scripts can be blocked by Gatekeeper too, manual command is most reliable |
| Screenshot tutorials | Custom screenshot hosting, embedding images | Markdown code blocks with copy-paste commands | Screenshots go stale with UI changes, text commands are version-control friendly |
| Checksum verification | Custom verification scripts | Document shasum -a 256 -c command | Standard Unix tool, widely recognized, no dependencies |

**Key insight:** For distribution documentation, simplicity and discoverability beat sophistication. Users need clear, copy-paste-able instructions in the README, not elaborate documentation systems.

## Common Pitfalls

### Pitfall 1: xattr -cr vs xattr -r -d com.apple.quarantine Confusion

**What goes wrong:** Documentation uses one form, release notes use another, users get confused about which to use.

**Why it happens:** Multiple valid commands exist for removing quarantine attributes. Research shows both work, but they differ in scope:
- `xattr -cr`: Removes ALL extended attributes recursively (simpler command)
- `xattr -r -d com.apple.quarantine`: Removes ONLY quarantine attribute (more surgical)

**How to avoid:**
- **Pick ONE command** for user-facing documentation (requirement DOCS-02 specifies `xattr -cr`)
- Use `xattr -cr` consistently in README and release notes
- Explain what it does: "removes security flags from the downloaded app"
- Note in docs that this is safe (only removes flags, doesn't modify app code)

**Warning signs:**
- Users reporting both commands in issues, unsure which to use
- Inconsistent instructions between README and release notes
- Support burden from "which command should I run?" questions

**Sources:**
- [macOS security and com.apple.quarantine extended attribute – ISSCloud](https://www.isscloud.io/guides/macos-security-and-com-apple-quarantine-extended-attribute/)
- [Clearing the quarantine extended attribute from downloaded applications | Der Flounder](https://derflounder.wordpress.com/2012/11/20/clearing-the-quarantine-extended-attribute-from-downloaded-applications/)

### Pitfall 2: Sequoia 15.1+ Restrictions Underdocumented

**What goes wrong:** Users on macOS 15.1+ encounter "damaged app" errors and don't know it's a Sequoia-specific issue requiring different steps.

**Why it happens:** macOS Sequoia 15.1 (released Nov 2024) removed traditional Gatekeeper bypass methods:
- Right-click → "Open Anyway" still works, BUT
- Quarantine attributes now cause "damaged app" errors instead of "unidentified developer" warnings
- `sudo spctl --master-disable` no longer works on Sequoia

**How to avoid:**
- Create dedicated Sequoia section in Installation docs
- Add prominent callout after standard installation steps: "macOS 15.1+ users: see below if you get 'damaged app' error"
- Explain the difference: "damaged app" (quarantine issue) vs "unidentified developer" (signing issue)
- Document complete flow: xattr command → System Settings → Privacy & Security → Open Anyway
- Note which macOS versions are affected (15.1+)

**Warning signs:**
- GitHub issues from users reporting "damaged app" errors
- Different experience on macOS 14 vs 15.1+
- Users saying "Right-click → Open doesn't work" (because quarantine flag blocks it)

**Sources:**
- [Apple Forces The Signing Of Applications In MacOS Sequoia 15.1 | Hackaday](https://hackaday.com/2024/11/01/apple-forces-the-signing-of-applications-in-macos-sequoia-15-1/)
- [macOS Sequoia: Bypassing Gatekeeper to install unsigned apps - TechBloat](https://www.techbloat.com/macos-sequoia-bypassing-gatekeeper-to-install-unsigned-apps.html)
- [How to run unsigned apps in macOS 15.1 – IT Notes](https://ordonez.tv/2024/11/04/how-to-run-unsigned-apps-in-macos-15-1/)

### Pitfall 3: README Installation Section Buried or Missing

**What goes wrong:** Users download release, don't know how to install, file GitHub issues asking for installation instructions.

**Why it happens:**
- Existing README lacks dedicated Installation section (current state shows "Installation" with Download subsection, but no details for handling unsigned apps)
- Instructions exist in release notes but users may not see them
- Users expect quick-start in README, not just "download from releases"

**How to avoid:**
- Make "Installation" a top-level section in README (after Features, before Usage)
- Include all installation paths: standard, Sequoia-specific, build from source
- Cross-reference from release notes: "See README for detailed installation instructions"
- Keep release notes focused on version-specific changes, README as permanent reference
- Add "First time using this app?" callout linking to Installation section

**Warning signs:**
- GitHub issues asking "how do I install this?"
- Users reporting errors that would be prevented by following documented steps
- High traffic on release notes, low traffic on README

**Sources:**
- [GitHub - jehna/readme-best-practices](https://github.com/jehna/readme-best-practices)
- [README Best Practices - Tilburg Science Hub](https://tilburgsciencehub.com/building-blocks/store-and-document-your-data/document-data/readme-best-practices/)

### Pitfall 4: Checksum Verification Undocumented or Overcomplicated

**What goes wrong:** Users download potentially corrupted or tampered files, no way to verify integrity.

**Why it happens:**
- Phase 3 workflow generates checksums.txt but README doesn't explain how to use it
- Security-conscious users want to verify downloads but don't know shasum command
- Overcomplicated instructions ("download checksums.txt, compare hashes manually") discourage verification

**How to avoid:**
- Add "Verify Download (Optional)" subsection to Installation
- Provide one-line command: `shasum -a 256 -c checksums.txt`
- Explain expected output: "PomodoroApp-v1.1.0.zip: OK"
- Mark as optional (don't block casual users)
- Note this detects corrupted downloads, not malware (set expectations)

**Warning signs:**
- Security-focused users asking about download verification in issues
- checksums.txt included in releases but unused
- No documentation for SHA256 hash verification

**Sources:**
- Phase 3 research documented SHA256 checksum generation as security best practice

### Pitfall 5: First Release Version Mismatch with Milestone

**What goes wrong:** Creating v1.0.0 as first release conflicts with roadmap showing v1.0 milestone already shipped.

**Why it happens:**
- Intuition suggests "first release = v1.0.0"
- But roadmap shows v1.0 Bug Fixes milestone completed (Phases 1-2) on 2026-02-15
- Current milestone is v1.1 Distribution (Phases 3-5)
- v1.1.0 is first *automated GitHub Release*, not first version of app

**How to avoid:**
- Use v1.1.0 for first release tag (matches current milestone)
- Release notes should explain: "This is the first automated release via GitHub Actions. Previous versions (v1.0) were distributed manually."
- Follow semantic versioning: v1.1.0 indicates minor feature (automated distribution) added to v1.0 (working app)
- Maintain consistency with roadmap milestone numbering

**Warning signs:**
- Confusion about version history ("where is v1.0?")
- Semantic versioning violation (v1.0 already shipped, can't re-release as v1.0.0)
- Roadmap and release versions out of sync

**Sources:**
- [Semantic Versioning 2.0.0](https://semver.org/)
- [Best Practices When Versioning a Release](https://www.cloudbees.com/blog/best-practices-when-versioning-a-release)

### Pitfall 6: No Visual Hierarchy in Installation Instructions

**What goes wrong:** Wall-of-text installation instructions overwhelm users, high abandonment rate.

**Why it happens:**
- Too much information without structure
- No clear progression (Step 1 → Step 2 → Step 3)
- Technical details mixed with action steps

**How to avoid:**
- Use numbered lists for sequential steps
- Use blockquotes or callouts for platform-specific warnings
- Code blocks for copy-paste commands (not inline code)
- Subheadings for different installation paths (Standard vs Sequoia)
- Keep action verbs in steps: "Download", "Extract", "Move", "Open"
- Separate "Why this is needed" explanations from "How to do it" steps

**Warning signs:**
- High bounce rate from Releases page
- Users skipping installation steps, encountering predictable errors
- Support burden from installation questions

**Sources:**
- [Write documentation | IDS Best Practices](https://maastrichtu-ids.github.io/best-practices/docs/documentation/)
- [GitHub - banesullivan/README: How to write a good README](https://github.com/banesullivan/README)

### Pitfall 7: Assuming Developer ID and Notarization Path is Accessible

**What goes wrong:** Documentation suggests "get Developer ID certificate" or "notarize your app" as solution to Gatekeeper issues.

**Why it happens:**
- Developer ID requires $99/year Apple Developer account
- Notarization requires Developer ID certificate
- Project constraint: "No Apple Developer account"
- Users and contributors may suggest this path

**How to avoid:**
- Acknowledge in README that app is unsigned (no Developer ID)
- Explain why: "This is a free, open-source app with no Apple Developer account"
- Frame xattr workaround as expected path, not fallback
- Document this as known limitation, potential future enhancement
- Don't apologize excessively - many open-source apps distribute unsigned

**Warning signs:**
- GitHub issues requesting notarization
- Pull requests attempting to add code signing without Developer ID
- Users confused about why app isn't signed

**Sources:**
- Phase 3 research "Critical constraints": No Apple Developer account, no notarization
- Phase 4 research: Ad-hoc signing is minimum for Apple Silicon compatibility
- [What's happening with code signing and future macOS? – Eclectic Light Company](https://eclecticlight.co/2026/01/17/whats-happening-with-code-signing-and-future-macos/)

## Code Examples

### README Installation Section (Complete)

```markdown
## Installation

### Download

Download the latest release from the [Releases](https://github.com/bacilo/pomodoro-mac/releases) page.

### Standard Installation

1. **Download** the `PomodoroApp-v*.zip` file from the latest release
2. **Extract** the .zip file (double-click in Finder)
3. **Move** the `PomodoroApp.app` to your `/Applications` folder
4. **First Launch**: Right-click → Open (required for unsigned apps on first launch)

> **macOS 15.1+ Sequoia users:** If you see a "damaged app" error or right-click → Open doesn't work, see [Sequoia Installation](#sequoia-installation) below.

### macOS 15.1+ Sequoia Installation {#sequoia-installation}

macOS Sequoia has stricter security requirements for unsigned apps. Follow these steps:

1. Extract and move the app to `/Applications` as described above
2. Open Terminal (Applications → Utilities → Terminal)
3. Run this command to remove quarantine flags:
   ```bash
   xattr -cr /Applications/PomodoroApp.app
   ```
4. Go to **System Settings → Privacy & Security**
5. Scroll down and click **"Open Anyway"** next to PomodoroApp
6. Try launching the app again

**What does `xattr -cr` do?** This command removes security flags that macOS adds to downloaded apps. It does not modify the app code itself - it only removes the "quarantine" flag that blocks unsigned apps on Sequoia.

**Why is this needed?** macOS Sequoia 15.1+ removed the traditional right-click → Open bypass for unsigned apps. This command restores the ability to run the app after you explicitly approve it in System Settings.

### Verify Download (Optional)

To verify your download hasn't been corrupted:

1. Download `checksums.txt` from the release
2. Open Terminal and navigate to your Downloads folder:
   ```bash
   cd ~/Downloads
   ```
3. Run the verification command:
   ```bash
   shasum -a 256 -c checksums.txt
   ```
4. You should see: `PomodoroApp-v1.1.0.zip: OK`

### Build from Source

If you prefer to build from source instead:

```bash
# Clone the repository
git clone https://github.com/bacilo/pomodoro-mac.git
cd pomodoro-mac

# Build
xcodebuild build -project PomodoroApp.xcodeproj -scheme PomodoroApp -destination 'platform=macOS'

# Or open in Xcode
open PomodoroApp.xcodeproj
```

### Why isn't this app signed?

This is a free, open-source project without an Apple Developer account ($99/year required for code signing). The app uses ad-hoc signing for Apple Silicon compatibility, but isn't notarized by Apple. This is common for open-source macOS apps distributed outside the Mac App Store.

Future enhancement: If the project gains sponsorship, we may add Developer ID signing and notarization for a smoother installation experience.
```

### First Release Body (v1.1.0)

```markdown
## PomodoroApp v1.1.0 - First Automated Release

This is the first release with automated GitHub Actions build and distribution. 🎉

**What's new in v1.1:**
- Universal binary support (Intel + Apple Silicon Macs)
- Automated release builds from git tags
- SHA256 checksums for download verification
- Enhanced installation documentation for macOS Sequoia 15.1+

### Installation

See the [README Installation section](https://github.com/bacilo/pomodoro-mac#installation) for detailed instructions.

**Quick start:**
1. Download `PomodoroApp-v1.1.0.zip` below
2. Extract and move to `/Applications`
3. Right-click → Open on first launch

**macOS 15.1+ Sequoia users:** If you get a "damaged app" error, run this command in Terminal:
```bash
xattr -cr /Applications/PomodoroApp.app
```
Then go to System Settings → Privacy & Security → "Open Anyway".

### Verify Download

```bash
shasum -a 256 -c checksums.txt
```

Expected: `PomodoroApp-v1.1.0.zip: OK`

---

**Previous versions:** v1.0 was distributed manually. This is the first automated release via GitHub Actions. See [ROADMAP.md](.planning/ROADMAP.md) for version history.
```

### Git Tag Creation and Push

```bash
# Create annotated tag for v1.1.0
git tag -a v1.1.0 -m "Release v1.1.0 - First automated release with universal binary support"

# Push tag to trigger GitHub Actions workflow
git push origin v1.1.0

# Verify workflow triggered
# Go to https://github.com/bacilo/pomodoro-mac/actions
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Developer ID + notarization required | Ad-hoc signing acceptable for distribution | Ongoing (2024+) | Open-source apps can distribute without $99/year Apple account |
| Right-click → "Open Anyway" bypass | xattr command + System Settings approval | macOS 15.1 (Nov 2024) | Unsigned app installation requires terminal command, more friction |
| Installation instructions in wiki/docs | Installation in README | Standard practice | Users expect README to be primary documentation, not external sites |
| Manual release uploads | Automated release via CI/CD | Industry standard (2020+) | Tag push triggers build, eliminates manual packaging errors |
| Screenshots for installation | Text-based code blocks | Best practice for open source | Text is version-control friendly, copy-paste-able, accessibility-friendly |

**Deprecated/outdated:**
- **`sudo spctl --master-disable`**: No longer works on macOS Sequoia 15+ (disabled Gatekeeper globally)
- **Right-click → "Open Anyway" as primary method**: Still works, but quarantine attributes now cause "damaged app" errors first
- **Separate INSTALL.md files**: Users expect installation in README, separate files add friction
- **v1.0.0 as first release**: Conflicts with roadmap showing v1.0 milestone already shipped

## Open Questions

### Question 1: Should we use xattr -cr or xattr -r -d com.apple.quarantine?

**What we know:**
- Requirement DOCS-02 specifies `xattr -cr` (removes all extended attributes)
- Research shows `xattr -r -d com.apple.quarantine` is more surgical (removes only quarantine flag)
- Both commands work for the goal (allow app to run)
- `xattr -cr` is shorter, simpler to type
- Phase 3 release notes already use `xattr -r -d com.apple.quarantine`

**What's unclear:**
- Do users care about preserving other extended attributes (Finder tags, etc.)?
- Does one command have better success rate on Sequoia?

**Recommendation:**
- **Use `xattr -cr`** in README (matches requirement DOCS-02, simpler command)
- **Update release notes** to use `xattr -cr` consistently (currently uses longer form)
- Explain what it does: "removes security flags from downloaded app"
- Note: This is safe, only removes flags, doesn't modify app code

**Confidence:** HIGH - Both commands work, consistency matters more than which one

### Question 2: Should we add screenshots to installation instructions?

**What we know:**
- Screenshots help visual learners
- Screenshots go stale with macOS UI changes
- Text-based instructions are version-control friendly and copy-paste-able
- Research shows text-based code blocks are best practice for open source

**What's unclear:**
- Will user success rate improve significantly with screenshots?
- How often do macOS UI changes break screenshot documentation?

**Recommendation:**
- **Start with text-only** (matches best practices, easier to maintain)
- Monitor GitHub issues for installation confusion
- Add screenshots in future if evidence shows they're needed
- If adding screenshots, host in repository (not external) and version control them

**Confidence:** MEDIUM - No hard data on screenshot effectiveness for this specific app

### Question 3: Should first release be v1.0.0 or v1.1.0?

**What we know:**
- Roadmap shows v1.0 milestone (Bug Fixes) completed 2026-02-15
- Current milestone is v1.1 (Distribution) - Phases 3-5
- Semantic versioning: v1.1.0 = minor feature added to v1.0
- This is first *automated GitHub Release*, but not first version of app

**What's unclear:**
- Does GitHub require semver to start at 1.0.0?
- Will users be confused by missing v1.0.0 release on GitHub?

**Recommendation:**
- **Use v1.1.0** (matches roadmap milestone)
- Explain in release notes: "First automated release. Previous v1.0 was distributed manually."
- Maintains consistency with roadmap and semantic versioning
- Avoids version number conflict with already-shipped v1.0 milestone

**Confidence:** HIGH - Roadmap is source of truth, v1.1.0 is correct

## Sources

### Primary (HIGH confidence)

**Official Documentation:**
- [GitHub - jehna/readme-best-practices](https://github.com/jehna/readme-best-practices) - README structure and content guidelines
- [Semantic Versioning 2.0.0](https://semver.org/) - Versioning standards
- [macOS security and com.apple.quarantine extended attribute – ISSCloud](https://www.isscloud.io/guides/macos-security-and-com-apple-quarantine-extended-attribute/) - Technical details on quarantine attribute

**macOS Sequoia Security Changes:**
- [Apple Forces The Signing Of Applications In MacOS Sequoia 15.1 | Hackaday](https://hackaday.com/2024/11/01/apple-forces-the-signing-of-applications-in-macos-sequoia-15-1/) - Sequoia 15.1 restrictions documented
- [How to run unsigned apps in macOS 15.1 – IT Notes](https://ordonez.tv/2024/11/04/how-to-run-unsigned-apps-in-macos-15-1/) - xattr workaround documented
- [macOS Sequoia: Bypassing Gatekeeper to install unsigned apps - TechBloat](https://www.techbloat.com/macos-sequoia-bypassing-gatekeeper-to-install-unsigned-apps.html) - Installation methods

**Code Signing Context:**
- [What's happening with code signing and future macOS? – Eclectic Light Company](https://eclecticlight.co/2026/01/17/whats-happening-with-code-signing-and-future-macos/) - Current state of macOS code signing
- [macOS distribution gist by rsms](https://gist.github.com/rsms/929c9c2fec231f0cf843a1a746a416f5) - Code signing, notarization, distribution best practices

### Secondary (MEDIUM confidence)

**Documentation Best Practices:**
- [README Best Practices - Tilburg Science Hub](https://tilburgsciencehub.com/building-blocks/store-and-document-your-data/document-data/readme-best-practices/) - Academic best practices
- [Write documentation | IDS Best Practices](https://maastrichtu-ids.github.io/best-practices/docs/documentation/) - Documentation guidelines
- [GitHub - banesullivan/README: How to write a good README](https://github.com/banesullivan/README) - README writing guide

**Versioning:**
- [Best Practices When Versioning a Release](https://www.cloudbees.com/blog/best-practices-when-versioning-a-release) - Release versioning strategies
- [About semantic versioning | npm Docs](https://docs.npmjs.com/about-semantic-versioning/) - Semver explanation

**xattr Commands:**
- [Clearing the quarantine extended attribute from downloaded applications | Der Flounder](https://derflounder.wordpress.com/2012/11/20/clearing-the-quarantine-extended-attribute-from-downloaded-applications/) - Historical context on xattr
- [Run xattr -r -d com.apple.quarantine App.app on casks on Apple Silicon MacOS · Issue #17979 · Homebrew/brew](https://github.com/Homebrew/brew/issues/17979) - Real-world usage examples

### Tertiary (LOW confidence - context only)

**Community Discussions:**
- [macOS 15.1 completely removes ability to launch unsigned applications | MacRumors Forums](https://forums.macrumors.com/threads/macos-15-1-completely-removes-ability-to-launch-unsigned-applications.2441792/) - User discussions on Sequoia
- [Disable Gatekeeper on macOS Catalina](https://disable-gatekeeper.github.io/) - Historical Gatekeeper bypass methods (outdated for Sequoia)

**Existing Project:**
- `.github/workflows/release.yml` - Release notes already include Sequoia instructions (Phase 3)
- `README.md` - Current installation section needs expansion
- `.planning/ROADMAP.md` - v1.0 milestone completed, v1.1 in progress

## Metadata

**Confidence breakdown:**
- **Installation instructions:** HIGH - Research verified Sequoia restrictions, xattr commands work, existing release notes validate approach
- **xattr command choice:** HIGH - Both commands work, DOCS-02 specifies xattr -cr, consistency matters most
- **README structure:** HIGH - Best practices well-documented, matches successful open-source projects
- **Version numbering:** HIGH - Roadmap is source of truth, semantic versioning clear
- **Screenshot necessity:** MEDIUM - Best practices favor text, but no project-specific evidence

**Research date:** 2026-02-16
**Valid until:** ~90 days (macOS Sequoia behavior stable, no announced changes for macOS 16)

**Dependencies:**
- macOS Sequoia 15.2+ could change Gatekeeper behavior (monitor Apple release notes)
- GitHub Releases UI changes could affect documentation screenshots (if added later)
- Community feedback on first release could reveal undocumented installation issues

**Ready for planning:** Yes. Planner has sufficient information to create task breakdown for DOCS-01 and DOCS-02, plus first release (v1.1.0) validation.
