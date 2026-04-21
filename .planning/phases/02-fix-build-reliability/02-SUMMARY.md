---
phase: 02
plan: 02
subsystem: docker-build-reliability
tags: [docker, build, ci-cd, reliability]
requires: [phase-01]
provides: [build-reliability, health-checks]
affects: [base, golang, ansible, workflows]
tech-stack.added: [scripts/healthcheck.sh, scripts/validate-config.sh]
patterns: [docker-layering, version-pinning, health-checks]
key-files.created: [scripts/healthcheck.sh, scripts/validate-config.sh, .dockerignore]
key-files.modified: [base/Dockerfile, base/opencode.Dockerfile, base/qwencode.Dockerfile, golang/Dockerfile, ansible/Dockerfile, Makefile]
key-decisions: [Go 1.26.2 kept, golang removed from apt, all @latest pinned, sudo removed, Yandex mirror kept]
requirements: [REQ-BUILD-005, REQ-TEST-001, REQ-TEST-002]
duration: ~15min
completed: 2026-04-20
---

# Phase 2 Plan 02: Fix Build Reliability Summary

## One-Liner

Pinned all Docker image dependencies to specific versions, removed redundant `golang` apt package and unnecessary `sudo` usage, created `.dockerignore` for build context hygiene, and added health check + config validation scripts.

## Tasks Executed

| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 | Create `.dockerignore` + `SOURCE_DATE_EPOCH` | Complete | `017284e` |
| 2 | Fix `base/Dockerfile` — remove golang, pin bun | Complete | `22196d7` |
| 3 | Fix agent Dockerfiles — pin packages, remove commented line | Complete | `6f1e433` |
| 4 | Fix tooling Dockerfiles — remove sudo, pin versions | Complete | `f4c17cd` |
| 5 | Create health check + config validation scripts | Complete | `c2438e5` |

## Files Modified

### Created
- `.dockerignore` — Excludes `.git/`, `*.md`, `*.log`, `.planning/`, `node_modules/`, `.opencode/` from build contexts
- `scripts/healthcheck.sh` — Verifies tool presence in Docker image variants (base, opencode, qwencode, golang, ansible)
- `scripts/validate-config.sh` — Validates `base/.opencode/opencode.json` against required schema (agents, providers, LSP, plugins)

### Modified
- `Makefile` — Added `SOURCE_DATE_EPOCH=1700000000` export, added `check` target
- `base/Dockerfile` — Removed `golang` from apt-get install list, pinned `bun@latest` → `bun@1.3.13`
- `base/opencode.Dockerfile` — Pinned 9 packages (`opencode-ai@1.14.19`, `opencode-pty@0.3.4`, etc.), removed commented-out plugin line
- `base/qwencode.Dockerfile` — Pinned 2 packages (`@qwen-code/qwen-code@0.14.5`, `get-shit-done-cc@1.38.1`)
- `golang/Dockerfile` — Removed 6 `sudo` usages, pinned `gopls@v0.21.1`, `buf@v1.68.2`
- `ansible/Dockerfile` — Removed `sudo`, pinned `ansible@13.5.0`, `ansible-lint@26.4.0`, `ansible-pylibssh@1.4.0`, `mitogen@0.3.47`

## Version Pins Applied (16 total)

| Package | Old | New |
|---------|-----|-----|
| bun | `@latest` | `1.3.13` |
| opencode-ai | `@latest` | `1.14.19` |
| opencode-pty | `@latest` | `0.3.4` |
| @franlol/opencode-md-table-formatter | `@latest` | `0.0.6` |
| opencode-conductor-plugin | `@latest` | `1.32.0` |
| @tarquinen/opencode-dcp | `@latest` | `3.1.9` |
| opencode-websearch-cited | `@latest` | `1.2.0` |
| opencode-qwencode-auth | `@latest` | `1.3.0` |
| get-shit-done-cc | `@latest` | `1.38.1` |
| @qwen-code/qwen-code | `@latest` | `0.14.5` |
| gopls | `@latest` | `v0.21.1` |
| buf | `@latest` | `v1.68.2` |
| ansible | `@latest` | `13.5.0` |
| ansible-lint | `@latest` | `26.4.0` |
| ansible-pylibssh | `@latest` | `1.4.0` |
| mitogen | `@latest` | `0.3.47` |

## Requirements Completed

- **REQ-BUILD-005**: Build reproducibility fixes — `.dockerignore` created, all `@latest` pinned, `sudo` removed, `SOURCE_DATE_EPOCH` added
- **REQ-TEST-001**: Docker build validation — `scripts/healthcheck.sh` verifies key tools in each image variant
- **REQ-TEST-002**: Agent config validation — `scripts/validate-config.sh` validates opencode.json schema

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] `.dockerignore` present, `.git/` excluded from build context
- [x] Go 1.26.2 kept (verified valid on go.dev)
- [x] All 16 `@latest` tags replaced with specific versions
- [x] No `sudo` in `golang/Dockerfile` or `ansible/Dockerfile`
- [x] `golang` removed from base/Dockerfile apt-get list
- [x] Commented-out plugin line removed from opencode.Dockerfile
- [x] `opencode.json` validates against schema (tested with validate-config.sh)
- [x] Health check script created and executable
- [x] `make check` target added to Makefile

## Next Steps

Phase 2 complete. Ready for Phase 3: Security scanning (Trivy vulnerability/secret/misconfiguration scans).
