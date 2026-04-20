# Project: Sandbox CI/CD Pipeline

**Project Code:** SANDBOX-CD  
**Title:** Build Reliable CI/CD for AI Agent Sandbox Images  
**Created:** 2026-04-20  
**Status:** Initializing  

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

**Registry:** `ghcr.io/red55/sandbox`

### Technology Stack

- **Languages:** Bash, TypeScript, Go, Python
- **Runtime:** Node.js 25, Docker CE, Bun
- **Build:** Make + Docker Buildx
- **CI/CD:** None (this is what we're adding)

### Existing Concerns

From `.planning/codebase/CONCERNS.md`:
- Context7 Bearer token committed in plaintext
- Go version `1.26.2` doesn't exist — builds will fail
- No `.dockerignore` — `.git/` bakes into image layers
- All packages pinned to `@latest` — non-reproducible builds
- No CI/CD, no image security scanning, no tests

## Goals

1. **Automate builds** — Replace manual `make all` with GitHub Actions workflow
2. **Catch errors early** — Add linting for Dockerfiles, Makefile, and agent configs
3. **Validate images** — Test that Docker images build successfully on every PR
4. **Publish reliably** — Push images to ghcr.io on merge to main
5. **Security scanning** — Add image vulnerability scanning (Trivy)
6. **Reproducible builds** — Pin all `@latest` tags to specific versions

## Scope

**In scope:**
- GitHub Actions workflow definition (`.github/workflows/`)
- Dockerfile linting (hadolint)
- Makefile validation
- Agent config JSON schema validation
- Full build pipeline (all 4 platform-variant combinations)
- Image push to ghcr.io
- Trivy vulnerability scanning
- `.dockerignore` file creation
- Go version fix (1.26.2 → valid version)
- Package version pinning

**Out of scope (for now):**
- Security hardening of NOPASSWD sudo
- Context7 token rotation (separate issue)
- Adding new agent capabilities
- Multi-platform builds (amd64 only initially)

## Success Criteria

- [ ] PR opens → lint passes, build succeeds, scan runs, results posted as PR comment
- [ ] Merge to main → images published to ghcr.io/red55/sandbox
- [ ] All 4 image variants build without errors
- [ ] No `@latest` tags in production Dockerfiles
- [ ] `.dockerignore` present and excludes `.git/`
- [ ] Go version is valid and downloads successfully
- [ ] Makefile targets validated by CI
- [ ] Agent config JSON validated against schema

## Team

- **Primary:** Developer maintaining the sandbox infrastructure
- **Subagents:** `ansible-expert`, `git-expert` (existing agent definitions)
- **CI Tooling:** GitHub Actions runners, hadolint, trivy, actionlint

## Constraints

- Must work with existing Makefile structure
- Must not break current local build workflow (`make all`)
- Images must publish to `ghcr.io/red55` registry
- GitHub Actions must use `gh` CLI for authentication
- Workflow must be configurable (allow `EXTRA_ARGS` passthrough)
