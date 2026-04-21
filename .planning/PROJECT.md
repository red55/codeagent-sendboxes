# Project: Sandbox CI/CD Pipeline

**Project Code:** SANDBOX-CD
**Title:** Build Reliable CI/CD for AI Agent Sandbox Images
**Created:** 2026-04-20
**Status:** Milestone v0.35.0 shipped

## Current State

**Shipped:** v0.35.0 (2026-04-21) — Complete CI/CD pipeline for sandbox Docker images.

4 phases, 11 plans executed. Pipeline includes lint gates (hadolint + actionlint), 4-variant builds (opencode/qwencode × golang/ansible), Trivy security scanning, SBOM/provenance attestations, and fork PR support.

## Idea

Add a full CI/CD pipeline using GitHub Actions to automate Docker image builds, linting, testing, and publishing to ghcr.io for the AI agent sandbox infrastructure.

## Context

### What Is This Codebase?

This repository defines Docker-based sandbox images for AI coding agents (OpenCode, Qwen Code). It uses a layered image composition pattern:

```
Upstream Image → Base Layer → Variant Layer → Platform Layer
```

**Key files:**
- `Makefile` — Build orchestration for Docker images
- `base/Dockerfile` — Foundation image (Node.js, Python, Go, Docker, tools)
- `base/opencode.Dockerfile` — OpenCode agent runtime + plugins
- `base/qwencode.Dockerfile` — Qwen Code agent runtime
- `golang/Dockerfile` — Go tooling extension
- `ansible/Dockerfile` — Ansible tooling extension
- `base/.opencode/opencode.json` — Agent configuration
- `base/agents/` — Sub-agent role definitions
- `.github/workflows/pr.yml` — PR build validation (lint + build, no push)
- `.github/workflows/release.yml` — Release pipeline (lint + build + security + push + attestations)
- `.github/workflows/trivy-cron.yml` — Daily Trivy DB pre-warm
- `README.md` — CI/CD documentation

**Registry:** `ghcr.io/red55/sandbox`

### Technology Stack

- **Languages:** Bash, TypeScript, Go, Python
- **Runtime:** Node.js 25, Docker CE, Bun
- **Build:** Make + Docker Buildx
- **CI/CD:** GitHub Actions (pr.yml, release.yml, trivy-cron.yml)
- **Security:** Trivy (vulnerability, secret, misconfiguration scanning)
- **Attestations:** CycloneDX SBOM, build provenance (mode=max)

### Known Issues

- healthcheck.sh not integrated into `make check` (requires pre-built images)
- Multi-platform (arm64) support deferred
- cosign image signing deferred
- Environment protection rules deferred

## Goals

1. **Automate builds** — Replace manual `make all` with GitHub Actions workflow ✅
2. **Catch errors early** — Add linting for Dockerfiles, Makefile, and agent configs ✅
3. **Validate images** — Test that Docker images build successfully on every PR ✅
4. **Publish reliably** — Push images to ghcr.io on merge to main ✅
5. **Security scanning** — Add image vulnerability scanning (Trivy) ✅
6. **Reproducible builds** — Pin all `@latest` tags to specific versions ✅

## Scope

**Delivered in v0.35.0:**
- GitHub Actions workflows (pr.yml + release.yml + trivy-cron.yml)
- Dockerfile linting (hadolint) with project-specific overrides
- Workflow syntax validation (actionlint)
- Agent config JSON schema validation
- Full build pipeline (all 4 platform-variant combinations)
- Image push to ghcr.io with SBOM + provenance attestations
- Trivy vulnerability/secret/misconfiguration scanning
- `.dockerignore` file creation
- Go version pinning (1.26.2)
- 16 package version pins (all `@latest` → specific versions)
- Fork PR-gated registry push

**Out of scope (deferred):**
- cosign image signing
- Multi-platform builds (arm64)
- Environment protection rules
- Context7 token rotation
- Offline mode

## Success Criteria

- [x] PR opens → lint passes, build succeeds, scan runs ✅
- [x] Merge to main → images published to ghcr.io/red55/sandbox ✅
- [x] All 4 image variants build without errors ✅
- [x] No `@latest` tags in production Dockerfiles ✅
- [x] `.dockerignore` present and excludes `.git/` ✅
- [x] Go version is valid and downloads successfully ✅
- [x] Makefile targets validated by CI ✅
- [x] Agent config JSON validated against schema ✅

## Team

- **Primary:** Developer maintaining the sandbox infrastructure
- **CI Tooling:** GitHub Actions runners, hadolint, trivy, actionlint, reviewdog

## Constraints

- Must work with existing Makefile structure
- Must not break current local build workflow (`make all`)
- Images must publish to `ghcr.io/red55` registry
- Workflow must be configurable (allow `EXTRA_ARGS` passthrough)

---
*Last updated: 2026-04-21 after v0.35.0 milestone*
