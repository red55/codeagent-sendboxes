---
phase: 04
plan: 02
subsystem: pr-publishing
tags: [pr-artifacts, fork-pr, registry-push]
requires: [phase-03]
provides: [pr-image-tags, fork-gating]
affects: [workflows/pr.yml]
tech-stack.added: [docker/login-action@v4, docker/build-push-action@v7 for PR push]
patterns: [fork-gating, conditional-push]
key-files.created: []
key-files.modified: [.github/workflows/pr.yml]
key-decisions: [Fork PRs only, pr-<number> tags, packages: write permission]
requirements: [REQ-PUB-003]
duration: ~5min
completed: 2026-04-20
---

# Phase 4 Plan 02: Fork PR Gated Registry Push Summary

## One-Liner

Added fork PR-gated GHCR login and image push to PR workflow — fork PRs push images with pr-<number> tags for review, non-fork PRs build locally only.

## Tasks Executed

| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 | Add fork PR gating and image push to pr.yml | Complete | `52bdefb` |

## Files Modified

- `.github/workflows/pr.yml` (+18 lines)
  - Added `packages: write` to permissions block
  - Added GHCR login step gated on fork PR check
  - Added image push step with pr-<number> and sha tags gated on fork PR check

## Key Changes

### Fork PR Gating
- Login and push steps gated on `github.event.pull_request.head.repo.fork == true`
- Non-fork PRs: `make all` builds images locally (for Trivy scanning), no registry push
- Fork PRs: images pushed to ghcr.io with `pr-<number>` and `<sha>` tags

### Permissions
- Added `packages: write` to top-level permissions (required for registry push)
- Lint and Trivy scan jobs run for all PRs (no fork check)

## Requirements Completed

- **REQ-PUB-003**: PR build artifacts via registry tags (fork PRs only)

## Self-Check

- [x] `packages: write` permission added
- [x] Fork PR check `github.event.pull_request.head.repo.fork == true` on login and push steps
- [x] `make all` step preserved (runs for all PRs)
- [x] GHCR login step gated on fork PR check
- [x] Image push step gated on fork PR check with pr-<number> tags
- [x] Lint job runs for all PRs (no fork check)
- [x] Trivy scan job runs for all PRs (no fork check)
- [x] Matrix strategy with 4 variants preserved
