# Roadmap: PomodoroApp

## Milestones

- ✅ **v1.0 Bug Fixes** - Phases 1-2 (shipped 2026-02-15)
- 🚧 **v1.1 Distribution** - Phases 3-5 (in progress)

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

<details>
<summary>✅ v1.0 Bug Fixes (Phases 1-2) - SHIPPED 2026-02-15</summary>

### Phase 1: Day Detection Reliability
**Goal**: App detects new calendar day while running and reinitializes
**Plans**: 1 plan

Plans:
- [x] 01-01: Triple-redundancy day detection system

### Phase 2: Popover Positioning
**Goal**: Popover remains anchored to status item on multi-monitor setups
**Plans**: 1 plan

Plans:
- [x] 02-01: Popover positioning fixes

</details>

### 🚧 v1.1 Distribution (In Progress)

**Milestone Goal:** Set up automated release distribution via GitHub Actions so tagged versions produce downloadable releases.

- [ ] **Phase 3: GitHub Actions Release Pipeline** - Tag push triggers automated build and release creation
- [ ] **Phase 4: Cross-Architecture Compatibility** - Releases work on both Intel and Apple Silicon Macs
- [ ] **Phase 5: Distribution Documentation** - Users can successfully download and run the app

## Phase Details

### Phase 3: GitHub Actions Release Pipeline
**Goal**: Tag push triggers automated build and GitHub release creation
**Depends on**: Phase 2 (completed in v1.0)
**Requirements**: BUILD-01, BUILD-02, BUILD-03, BUILD-04, BUILD-05, VERS-01, VERS-02, VERS-03
**Success Criteria** (what must be TRUE):
  1. Pushing a version tag (v1.1.0) triggers GitHub Actions workflow automatically
  2. Workflow builds Release configuration .app with version number from tag
  3. Built .app is packaged into downloadable .zip file
  4. GitHub Release is created with .zip and SHA256 checksum as downloadable assets
  5. Release version matches git tag version
**Plans**: 1 plan

Plans:
- [ ] 03-01-PLAN.md — GitHub Actions release workflow (build, package, release)

### Phase 4: Cross-Architecture Compatibility
**Goal**: Releases work on both Intel and Apple Silicon Macs
**Depends on**: Phase 3
**Requirements**: COMPAT-01, COMPAT-02, COMPAT-03
**Success Criteria** (what must be TRUE):
  1. Built .app is ad-hoc code signed for Apple Silicon compatibility
  2. .app binary is universal (supports Intel and ARM64 architectures)
  3. CI verifies .app structure and version before packaging
**Plans**: 1 plan

Plans:
- [ ] 04-01-PLAN.md — Universal binary build with architecture and signing verification

### Phase 5: Distribution Documentation
**Goal**: Users can successfully download and run the app despite macOS Gatekeeper
**Depends on**: Phase 4
**Requirements**: DOCS-01, DOCS-02
**Success Criteria** (what must be TRUE):
  1. README includes clear download and installation instructions
  2. README documents Gatekeeper bypass steps (xattr -cr command)
  3. First release (v1.1.0) is published and downloadable from GitHub Releases
**Plans**: TBD

Plans:
- [ ] TBD during phase planning

## Progress

**Execution Order:**
Phases execute in numeric order: 3 → 4 → 5

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Day Detection | v1.0 | 1/1 | Complete | 2026-02-12 |
| 2. Popover Positioning | v1.0 | 1/1 | Complete | 2026-02-12 |
| 3. GitHub Actions Release Pipeline | v1.1 | 0/1 | In progress | - |
| 4. Cross-Architecture Compatibility | v1.1 | 0/1 | Not started | - |
| 5. Distribution Documentation | v1.1 | 0/0 | Not started | - |
