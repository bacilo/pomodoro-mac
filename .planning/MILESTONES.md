# Milestones

## v1.0 Bug Fixes (Shipped: 2026-02-15)

**Phases:** 1-2 | **Plans:** 2 | **Tasks:** 6
**Timeline:** 28 days (2026-01-15 → 2026-02-12)
**Git range:** `eea20f5..ff28449` | **Changes:** 15 files, +1,878/-59

**Key accomplishments:**
- Triple-redundancy day detection (NSCalendarDayChanged + wake + midnight timer + timezone change)
- Timezone-safe date formatting with explicit TimeZone.current
- Fixed-width status item preventing popover anchor jitter
- Timer suspension during popover display
- Graceful dismissal on display configuration changes

**Known limitations:**
- Popover positioning works on 2/3 screens (third screen edge case accepted)

---

