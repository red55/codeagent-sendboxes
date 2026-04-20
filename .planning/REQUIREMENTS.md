# Requirements: Sandbox CI/CD Pipeline

**Created:** 2026-04-20  
**Status:** Draft  
**Type:** Feature  

---

## 1. GitHub Actions Workflow

### 1.1 Workflow Structure

**ID:** REQ-CI-001  
**Priority:** Must Have  
**Type:** Functional  

The project must have a GitHub Actions workflow at `.github/workflows/ci.yml` that triggers on:
- Push to `main` branch
- Pull requests to `main` branch
- Tags matching `v*`

**Acceptance Criteria:**
- [ ] Workflow file exists at `.github/workflows/ci.yml`
- [ ] Triggers on `push` (main, release/**), `pull_request` (main), and `tags` (v*)
- [ ] Sets `permissions: contents: read, packages: write, security-events: write`
- [ ] PR builds do NOT push images; only merge-to-main pushes

### 1.2 Workflow Jobs

**ID:** REQ-CI-002  
**Priority:** Must Have  
**Type:** Functional  

The workflow must contain three jobs in sequence:
1. `lint` — Validate Dockerfiles, Makefile, and workflow syntax
2. `build` — Build all 4 image variants, run tests, push to ghcr.io
3. `security` — Scan built images for vulnerabilities

**Acceptance Criteria:**
- [ ] `lint` job runs first and is independent
- [ ] `build` job depends on `lint` passing (`needs: lint`)
- [ ] `security` job depends on `build` passing (`needs: build`)
- [ ] All jobs run on `ubuntu-latest`

---

## 2. Linting Phase

### 2.1 Dockerfile Linting (hadolint)

**ID:** REQ-LINT-001  
**Priority:** Must Have  
**Type:** Functional  

All Dockerfiles must be linted with hadolint using SARIF output.

**Acceptance Criteria:**
- [ ] hadolint runs on all 5 Dockerfiles: `base/Dockerfile`, `base/opencode.Dockerfile`, `base/qwencode.Dockerfile`, `golang/Dockerfile`, `ansible/Dockerfile`
- [ ] Output format is SARIF
- [ ] Results uploaded to GitHub Security tab via `github/codeql-action/upload-sarif`
- [ ] `.hadolint.yaml` config file created with project-specific overrides
- [ ] Rules DL3006 (base image pinned), DL3018 (apt-get install pinned) enforced
- [ ] Known false positives suppressed with comments (e.g., Yandex mirror)

### 2.2 Workflow Linting (actionlint)

**ID:** REQ-LINT-002  
**Priority:** Must Have  
**Type:** Functional  

GitHub Actions workflow files must be linted for syntax and best practices.

**Acceptance Criteria:**
- [ ] actionlint runs as part of the lint job
- [ ] Reports errors as PR comments (via reviewdog)
- [ ] Configurable via `.github/actionlint.yaml`

### 2.3 Makefile Linting

**ID:** REQ-LINT-003  
**Priority:** Should Have  
**Type:** Functional  

The Makefile should be validated for syntax and target correctness.

**Acceptance Criteria:**
- [ ] ShellCheck runs on any inline bash in Makefile
- [ ] Make target dependencies are validated (no circular deps)
- [ ] `.PHONY` targets are declared

---

## 3. Build Phase

### 3.1 Docker Buildx Setup

**ID:** REQ-BUILD-001  
**Priority:** Must Have  
**Type:** Functional  

Docker Buildx must be configured with BuildKit for efficient builds.

**Acceptance Criteria:**
- [ ] `docker/setup-buildx-action@v4` used in build job
- [ ] `docker/setup-qemu-action@v4` included for potential multi-platform builds

### 3.2 GHCR Authentication

**ID:** REQ-BUILD-002  
**Priority:** Must Have  
**Type:** Functional  

Images must be pushed to ghcr.io with proper authentication.

**Acceptance Criteria:**
- [ ] `docker/login-action@v4` configured for `ghcr.io`
- [ ] Uses `${{ secrets.GITHUB_TOKEN }}` for authentication
- [ ] Login only on non-PR events (merge to main)
- [ ] `packages: write` permission set at job level

### 3.3 Image Building — All Variants

**ID:** REQ-BUILD-003  
**Priority:** Must Have  
**Type:** Functional  

All 4 platform-variant image combinations must be built:
1. `sandbox-oc-go` (golang + opencode)
2. `sandbox-qc-go` (golang + qwencode)
3. `sandbox-oc-ansible` (ansible + opencode)
4. `sandbox-qc-ansible` (ansible + qwencode)

**Acceptance Criteria:**
- [ ] Build uses `Makefile` targets or equivalent Docker commands
- [ ] Each variant builds from its correct base (base-opencode or base-qwencode)
- [ ] Build uses `cache-from: type=gha` for GitHub Actions cache
- [ ] Build uses `cache-to: type=gha,mode=max` for cache export
- [ ] Build succeeds for all 4 variants on main branch push
- [ ] Build runs in `load: true` mode for PR testing (no push)

### 3.4 Image Tagging

**ID:** REQ-BUILD-004  
**Priority:** Must Have  
**Type:** Functional  

Images must be tagged with appropriate version schemes.

**Acceptance Criteria:**
- [ ] `docker/metadata-action@v6` used for tag extraction
- [ ] Tags include:
  - Git SHA: `ghcr.io/red55/sandbox-oc-go:<sha>`
  - Branch name for PRs: `ghcr.io/red55/sandbox-oc-go:pr-<number>`
  - `latest` on main branch push
  - Semver tags for `v*` pushes: `ghcr.io/red55/sandbox-oc-go:1.0.0`
- [ ] Tags are consistent across all 4 variants

### 3.5 Build Reproducibility Fixes

**ID:** REQ-BUILD-005  
**Priority:** Must Have  
**Type:** Bug Fix  

The following build issues must be fixed as part of the CI implementation:

**Acceptance Criteria:**
- [ ] `.dockerignore` created — excludes `.git/`, `.planning/`, `node_modules/`, `*.md`
- [ ] Go version in `golang/Dockerfile` fixed from `1.26.2` to a valid version (e.g., `1.23.0`)
- [ ] All `@latest` package tags pinned to specific versions in Dockerfiles
- [ ] Unnecessary `sudo` removed from `golang/Dockerfile` and `ansible/Dockerfile`
- [ ] Commented-out plugin line removed from `base/opencode.Dockerfile`
- [ ] `SOURCE_DATE_EPOCH` set in workflow for reproducible timestamps

---

## 4. Test Phase

### 4.1 Docker Build Validation

**ID:** REQ-TEST-001  
**Priority:** Must Have  
**Type:** Functional  

Docker builds must be validated before pushing to registry.

**Acceptance Criteria:**
- [ ] Images built with `load: true` are tested before push
- [ ] Test step runs a container from each built image
- [ ] Container health check verifies key tools are installed:
  - `docker --version`
  - `node --version`
  - `python3 --version`
  - `go version` (for golang variants)
  - `ansible --version` (for ansible variants)
  - `opencode --version` or `qwencode --version`

### 4.2 Agent Config Validation

**ID:** REQ-TEST-002  
**Priority:** Should Have  
**Type:** Functional  

The OpenCode agent configuration must be validated.

**Acceptance Criteria:**
- [ ] `base/.opencode/opencode.json` validated against JSON schema
- [ ] Plugin references in config match those in Dockerfile
- [ ] Provider URLs are well-formed
- [ ] Agent definitions have required fields (name, mode, tools)

### 4.3 Makefile Target Validation

**ID:** REQ-TEST-003  
**Priority:** Should Have  
**Type:** Functional  

Makefile targets must be validated.

**Acceptance Criteria:**
- [ ] All `.PHONY` targets are tested (dry-run)
- [ ] Target dependencies are validated (no missing deps)
- [ ] Variable expansion is checked

---

## 5. Security Phase

### 5.1 Trivy Vulnerability Scanning

**ID:** REQ-SEC-001  
**Priority:** Must Have  
**Type:** Functional  

Built images must be scanned for vulnerabilities using Trivy.

**Acceptance Criteria:**
- [ ] `aquasecurity/trivy-action@v0.35.0` used for scanning
- [ ] Scans all 4 built image variants
- [ ] Output format: SARIF
- [ ] Results uploaded to GitHub Security tab
- [ ] `exit-code: 1` only for CRITICAL/HIGH severity (not ALL)
- [ ] `ignore-unfixed: true` to reduce noise
- [ ] `vuln-type: os,library` covers both system and application packages

### 5.2 Secret Scanning

**ID:** REQ-SEC-002  
**Priority:** Must Have  
**Type:** Functional  

Images must be scanned for accidentally committed secrets.

**Acceptance Criteria:**
- [ ] Trivy secret scanner enabled (`scanners: secret`)
- [ ] Scans image layers for API keys, tokens, passwords
- [ ] Reports findings as warnings (does not block build)
- [ ] Context7 token in `opencode.json` flagged as known issue (suppressed with comment)

### 5.3 Misconfiguration Scanning

**ID:** REQ-SEC-003  
**Priority:** Should Have  
**Type:** Functional  

Dockerfiles must be scanned for security misconfigurations.

**Acceptance Criteria:**
- [ ] Trivy config scanner enabled (`scan-type: config`)
- [ ] Checks for NOPASSWD sudo, HTTP endpoints, missing HEALTHCHECK
- [ ] Reports findings but does not block build

---

## 6. Publish Phase

### 6.1 Image Push to ghcr.io

**ID:** REQ-PUB-001  
**Priority:** Must Have  
**Type:** Functional  

Successfully built and scanned images must be pushed to ghcr.io.

**Acceptance Criteria:**
- [ ] Push only on merge to main or tag creation (not on PR)
- [ ] Uses `docker/build-push-action@v7` with `push: true`
- [ ] SBOM generated (`sbom: true`)
- [ ] Provenance attestation enabled (`provenance: mode=max`)
- [ ] All 4 variants pushed with consistent tags

### 6.2 Image Attestations

**ID:** REQ-PUB-002  
**Priority:** Should Have  
**Type:** Functional  

Images should have build attestations for supply chain security.

**Acceptance Criteria:**
- [ ] `actions/attest@v4` used to generate build provenance
- [ ] Attestations pushed to registry
- [ ] Attestations include build metadata (commit SHA, trigger, timestamps)

### 6.3 PR Build Artifacts

**ID:** REQ-PUB-003  
**Priority:** Should Have  
**Type:** Functional  

PR builds should publish image artifacts for review.

**Acceptance Criteria:**
- [ ] Built images saved as workflow artifacts (`actions/upload-artifact`)
- [ ] Artifacts available for 7 days
- [ ] Artifact download link posted as PR comment

---

## 7. Non-Functional Requirements

### 7.1 Performance

**ID:** REQ-NFR-001  
**Priority:** Must Have  

Build times should be reasonable with caching.

**Acceptance Criteria:**
- [ ] Full build pipeline (lint + build + security) completes in < 15 minutes
- [ ] Cache hit on subsequent builds reduces build time by > 50%
- [ ] Lint job completes in < 2 minutes

### 7.2 Reliability

**ID:** REQ-NFR-002  
**Priority:** Must Have  

CI/CD pipeline must be reliable and provide clear failure feedback.

**Acceptance Criteria:**
- [ ] Failed builds post clear error messages to PR comments
- [ ] Lint failures block build (gate check)
- [ ] Security scan failures post warnings but do not block (configurable threshold)
- [ ] Workflow has `concurrency` group to cancel stale PR runs

### 7.3 Maintainability

**ID:** REQ-NFR-003  
**Priority:** Should Have  

CI/CD configuration should be easy to maintain and extend.

**Acceptance Criteria:**
- [ ] Workflow uses reusable components where possible (composite actions)
- [ ] Configuration is externalized (env vars, not hardcoded)
- [ ] README updated with CI/CD documentation
- [ ] `.github/` directory has clear structure

---

## 8. Out of Scope

The following are explicitly out of scope for this phase:

- Multi-platform builds (arm64) — amd64 only
- Automated release management (semver tagging)
- Image signing (cosign) — planned for future phase
- Notification integrations (Slack, email)
- Custom agent runtime testing (only tool presence validation)
- Kubernetes deployment or orchestration
