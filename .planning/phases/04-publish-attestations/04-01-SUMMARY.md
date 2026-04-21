---
phase: 04
plan: 01
subsystem: release-publishing
tags: [sbom, provenance, release-notes, cyclonedx]
requires: [phase-03]
provides: [sbom-attestation, provenance-attestation, auto-release-notes]
affects: [workflows/release.yml]
tech-stack.added: [sbom: true, provenance: mode=max, softprops/action-gh-release@v2]
patterns: [native-build-push, auto-release-notes]
key-files.created: []
key-files.modified: [.github/workflows/release.yml]
key-decisions: [CycloneDX SBOM format, mode=max provenance, auto release notes from commits]
requirements: [REQ-PUB-001, REQ-PUB-002]
duration: ~5min
completed: 2026-04-20
---

# Phase 4 Plan 01: SBOM + Provenance + Release Notes Summary

## One-Liner

Added CycloneDX SBOM generation and full build provenance (mode=max) to release workflow via docker/build-push-action@v7, plus auto-generated GitHub release notes for v* tag pushes.

## Tasks Executed

| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 | Add SBOM + provenance to release.yml build job | Complete | `eff8aab` |
| 2 | Add release-notes job to release.yml | Complete | `eff8aab` |

## Files Modified

- `.github/workflows/release.yml` (+28, -7 lines)
  - Added `make base` step before build
  - Added `sbom: true` and `provenance: mode=max` to docker/build-push-action@v7
  - Removed redundant `make all` step
  - Added `release-notes` job with `softprops/action-gh-release@v2`

## Key Changes

### SBOM Generation
- `sbom: true` enables native CycloneDX SBOM generation in docker/build-push-action@v7
- SBOM attached to all release images pushed to ghcr.io

### Provenance Attestation
- `provenance: mode=max` provides full build provenance (build config, source, dependencies)
- Attestations pushed to ghcr.io as image metadata

### Release Notes
- New `release-notes` job triggered on `v*` tags
- Uses `softprops/action-gh-release@v2` with `generate_release_notes: true`
- Auto-generates release notes from commit messages
- Depends on `security` job completing (all scans pass first)

## Requirements Completed

- **REQ-PUB-001**: Image push to ghcr.io with SBOM + provenance
- **REQ-PUB-002**: Build attestations (CycloneDX SBOM + mode=max provenance)

## Self-Check

- [x] `sbom: true` present in docker/build-push-action@v7 step
- [x] `provenance: mode=max` present in docker/build-push-action@v7 step
- [x] `make base` step added before build-push-action
- [x] Redundant `make all` step removed
- [x] All existing build job steps preserved
- [x] Matrix strategy with 4 variants preserved
- [x] Tags from metadata action preserved
- [x] CycloneDX SBOM format (default for sbom: true)
- [x] GHA cache settings preserved
- [x] `release-notes` job added with tag condition
- [x] `softprops/action-gh-release@v2` with `generate_release_notes: true`
- [x] Release job depends on `security` job
