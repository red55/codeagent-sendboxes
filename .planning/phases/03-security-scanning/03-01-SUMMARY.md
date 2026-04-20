---
phase: 03
plan: 01
subsystem: trivy-configuration
tags: [trivy, security, configuration]
requires: [phase-02]
provides: [trivy-config, secret-suppression, severity-thresholds]
affects: [lint, workflows]
tech-stack.added: [trivy.yaml, trivy-secret.yaml, trivy-ignore]
patterns: [centralized-config, path-based-suppression]
key-files.created: [.github/lint/trivy.yaml, .github/lint/trivy-secret.yaml, .github/lint/trivy-ignore]
key-files.modified: []
key-decisions: [CRITICAL+HIGH block, MEDIUM warns, Context7 token suppressed by path, secrets/misconfigs warnings only]
requirements: [REQ-SEC-001, REQ-SEC-002, REQ-SEC-003]
duration: ~5min
completed: 2026-04-20
---

# Phase 3 Plan 01: Create Trivy Configuration Summary

## One-Liner

Centralized Trivy configuration with CRITICAL/HIGH severity blocking, path-based Context7 token suppression, and dedicated secret/misconfiguration scanning settings.

## Tasks Executed

| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 | Create `.github/lint/trivy.yaml` + secret/config files | Complete | `e6114e9` |

## Files Created

- `.github/lint/trivy.yaml` (44 lines) — Centralized Trivy config with severity thresholds, vulnerability/secret/config scanning settings
- `.github/lint/trivy-secret.yaml` — Secret scanner config with `ignored_paths` for `base/.opencode/opencode.json`
- `.github/lint/trivy-ignore` — Ignorefile for known false positives

## Requirements Completed

- **REQ-SEC-001**: Vulnerability scanning configured (`vuln-type: os,library`, `ignore-unfixed: true`)
- **REQ-SEC-002**: Secret scanning enabled with path-based suppression for Context7 token
- **REQ-SEC-003**: Misconfiguration scanning configured for Dockerfiles

## Self-Check

- [x] `.github/lint/trivy.yaml` exists and is valid YAML (44 lines >= 20 minimum)
- [x] Severity list contains CRITICAL and HIGH
- [x] `vulnerability.vuln-type` includes `os` and `library`
- [x] `vulnerability.ignore-unfixed` is `true`
- [x] Secret scanning config exists at `.github/lint/trivy-secret.yaml`
- [x] `ignored_paths` includes `base/.opencode/opencode.json`
- [x] Config/misconfiguration scanning section present
- [x] `.github/lint/trivy-ignore` exists
