---
phase: 03
plan: 03
subsystem: trivy-cron
tags: [trivy, security, cron, db-prewarm]
requires: [03-01]
provides: [trivy-db-cache, rate-limit-prevention]
affects: [workflows/trivy-cron.yml]
tech-stack.added: [actions/cache@v5 for Trivy DB]
patterns: [cron-schedule, cache-persistence]
key-files.created: [.github/workflows/trivy-cron.yml]
key-files.modified: []
key-decisions: [Daily 06:00 UTC cron, cache key includes workflow hash, failure is non-blocking]
requirements: [REQ-SEC-001]
duration: ~5min
completed: 2026-04-20
---

# Phase 3 Plan 03: Trivy DB Pre-Warm Cron Summary

## One-Liner

Daily cron job at 06:00 UTC pre-warms Trivy vulnerability database using actions/cache to prevent GitHub API rate limits on first build of each day.

## Tasks Executed

| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 | Create `.github/workflows/trivy-cron.yml` | Complete | `eb93d73` |

## Files Created

- `.github/workflows/trivy-cron.yml` (55 lines) — Daily cron workflow for Trivy DB pre-warming

## Key Features

- **Schedule**: `cron: '0 6 * * *'` (daily at 06:00 UTC)
- **Manual trigger**: `workflow_dispatch` for testing
- **Cache**: `actions/cache@v5` with key `trivy-db-${{ runner.os }}-${{ hashFiles(...) }}`
- **DB download**: Runs `trivy image alpine:latest` to populate cache
- **Non-blocking**: Failure step reports warning but doesn't fail workflow
- **Permissions**: `contents: read` only (minimal)

## Requirements Completed

- **REQ-SEC-001**: Trivy DB pre-warm prevents rate limits on first build of day

## Self-Check

- [x] `.github/workflows/trivy-cron.yml` exists and is valid YAML (55 lines >= 40 minimum)
- [x] Schedule is `cron: '0 6 * * *'` (daily at 06:00 UTC)
- [x] `workflow_dispatch` trigger present
- [x] Uses `actions/cache@v5` with OS and workflow hash in key
- [x] Runs `aquasecurity/trivy-action@v0.35.0` with `image-ref: alpine:latest`
- [x] `exit-code: "0"` — DB download failure doesn't block
- [x] Failure step reports warning but doesn't fail the workflow
- [x] Permissions: `contents: read` only
- [x] Cache path: `~/.cache/trivy`
