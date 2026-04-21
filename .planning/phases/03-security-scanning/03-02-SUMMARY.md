---
phase: 03
plan: 02
subsystem: trivy-workflows
tags: [trivy, security, workflows, pr, release]
requires: [03-01]
provides: [trivy-scanning, sarif-upload, pr-comments]
affects: [workflows/pr.yml, workflows/release.yml]
tech-stack.added: [trivy-action@v0.35.0, reviewdog/action-trivy]
patterns: [matrix-strategy, sarif-upload, pr-comments]
key-files.created: []
key-files.modified: [.github/workflows/pr.yml, .github/workflows/release.yml]
key-decisions: [PR scans use local image, release scans use pushed image, SARIF uploads to Security tab]
requirements: [REQ-SEC-001, REQ-SEC-002, REQ-SEC-003]
duration: ~10min
completed: 2026-04-20
---

# Phase 3 Plan 02: Add Trivy to Workflows Summary

## One-Liner

Integrated Trivy vulnerability, secret, and misconfiguration scanning into PR and release workflows with SARIF uploads to GitHub Security tab and PR comment posting via reviewdog.

## Tasks Executed

| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 | Modify `pr.yml` — add trivy-scan job | Complete | `0008415` |
| 2 | Modify `release.yml` — replace security stub with real Trivy | Complete | `0008415` |

## Files Modified

- `.github/workflows/pr.yml` (+107 lines) — Added `trivy-scan` job with vulnerability, secret, and config scans; SARIF uploads; PR comment posting via reviewdog
- `.github/workflows/release.yml` (+38 lines, -9 lines) — Replaced stub security job with real Trivy scanning (3 scan types, 3 SARIF uploads)

## Key Changes

### pr.yml
- New `trivy-scan` job with `needs: build` dependency
- Matrix strategy: `[oc-go, qc-go, oc-ansible, qc-ansible]`
- Three Trivy steps: vulnerability scan, secret scan, config scan
- SARIF uploads to Security tab (3 uploads, one per scan type)
- PR comment posting via `reviewdog/action-trivy` with `level: warning`
- Scans locally-built images using `image-ref: ghcr.io/red55/sandbox-<variant>:pr-<pr_number>`

### release.yml
- Replaced stub security job (had `exit-code: "0"`, `continue-on-error: true`)
- Real Trivy scanning with `exit-code: "1"` for CRITICAL/HIGH vulnerabilities
- Three scan types: vulnerability (os+library), secret (with path suppression), config (Dockerfiles)
- SARIF uploads for all three scan types with variant-specific categories
- Scans pushed images using `image-ref: ghcr.io/red55/sandbox-<variant>:<sha>`

## Requirements Completed

- **REQ-SEC-001**: Vulnerability scanning on both PR and release builds
- **REQ-SEC-002**: Secret scanning with Context7 token suppression
- **REQ-SEC-003**: Dockerfile misconfiguration scanning

## Self-Check

- [x] `pr.yml` is valid YAML with `trivy-scan` job
- [x] `trivy-scan` job has `needs: build` and matrix with 4 variants
- [x] `trivy-scan` job runs `trivy-action@v0.35.0` for 3 scan types
- [x] SARIF uploads for all 3 scan types
- [x] PR comment posting via reviewdog present
- [x] `release.yml` is valid YAML
- [x] Old stub replaced with real Trivy scanning (no `continue-on-error`)
- [x] Release security job has matrix strategy with 4 variants
- [x] Vulnerability scan: `exit-code: 1`, `severity: CRITICAL,HIGH`, `ignore-unfixed: true`
- [x] Secret scan: `scanners: secret`, config: `trivy-secret.yaml`
- [x] Config scan: `scan-type: config`, scans all 5 Dockerfiles
- [x] Both workflows reference `.github/lint/trivy.yaml` config
