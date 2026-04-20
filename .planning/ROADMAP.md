# Roadmap: Sandbox CI/CD Pipeline

**Created:** 2026-04-20  
**Project:** SANDBOX-CD  
**Total Phases:** 4  

---

## Phase Overview

| Phase | Title | Status | Requirements |
|-------|-------|--------|--------------|
| 1 | Foundation — Lint + Build | Planned | REQ-CI-001, REQ-CI-002, REQ-LINT-001, REQ-LINT-002, REQ-BUILD-001, REQ-BUILD-002, REQ-BUILD-003, REQ-BUILD-004 |
| 2 | Fix Build Reliability | Planned | REQ-BUILD-005, REQ-LINT-003, REQ-TEST-001, REQ-TEST-002 |
| 3 | Security Scanning | Planned | REQ-SEC-001, REQ-SEC-002, REQ-SEC-003 |
| 4 | Publish + Attestations | Planned | REQ-PUB-001, REQ-PUB-002, REQ-PUB-003, REQ-NFR-001, REQ-NFR-002, REQ-NFR-003 |

---

## Phase 1: Foundation — Lint + Build

**Goal:** Establish a working GitHub Actions CI/CD pipeline that lints Dockerfiles and builds all 4 image variants.

**Duration:** ~2-3 hours  
**Risk:** Low  

### Tasks

1. **Create GitHub Actions workflow skeleton**
   - `.github/workflows/ci.yml` with lint, build, and security job structure
   - Define triggers (push to main, PRs, tags)
   - Set permissions (contents: read, packages: write, security-events: write)
   - Add concurrency group to cancel stale runs

2. **Implement lint job**
   - hadolint for all 5 Dockerfiles with SARIF output
   - actionlint for workflow syntax validation
   - Create `.hadolint.yaml` config with project overrides
   - Upload SARIF results to GitHub Security tab

3. **Implement build job — base images**
   - docker/setup-buildx-action@v4
   - docker/setup-qemu-action@v4
   - docker/metadata-action@v6 for tag extraction
   - Build `oc-sandbox-base` and `qc-sandbox-base` from `base/Dockerfile`
   - Build `opencode-sandbox-base` and `qwencode-sandbox-base` from variant Dockerfiles
   - Use GHA cache (`cache-from: type=gha`)

4. **Implement build job — platform images**
   - Build all 4 variants:
     - `sandbox-oc-go` (golang + opencode)
     - `sandbox-qc-go` (golang + qwencode)
     - `sandbox-oc-ansible` (ansible + opencode)
     - `sandbox-qc-ansible` (ansible + qwencode)
   - Tag with SHA, branch name, and latest (on main)
   - Push only on non-PR events

5. **Add GHCR login**
   - docker/login-action@v4 for ghcr.io
   - Use GITHUB_TOKEN
   - Conditional on non-PR events

**Acceptance Criteria:**
- [ ] PR opens → lint passes, all 4 images build successfully
- [ ] Build times < 10 minutes (with cache miss)
- [ ] Lint results visible in GitHub Security tab
- [ ] Images tagged correctly on main branch push
- [ ] PR builds do NOT push images

**Dependencies:** None (first phase)

---

## Phase 2: Fix Build Reliability

**Goal:** Fix the critical build issues identified in the codebase analysis so CI builds actually succeed.

**Duration:** ~1-2 hours  
**Risk:** Low  

### Tasks

1. **Create `.dockerignore`**
   - Exclude `.git/`, `.planning/`, `node_modules/`, `*.md`, `*.txt`
   - Prevent build context pollution

2. **Fix Go version in `golang/Dockerfile`**
   - Change `GO_VERSION=1.26.2` to `GO_VERSION=1.23.0` (valid version)
   - Verify download URL works

3. **Pin `@latest` package tags**
   - `base/opencode.Dockerfile`: Pin all opencode plugins to specific versions
   - `base/qwencode.Dockerfile`: Pin `@qwen-code/qwen-code` to specific version
   - `base/Dockerfile`: Pin `bun@latest` to specific version
   - Remove commented-out plugin line

4. **Remove unnecessary `sudo`**
   - `golang/Dockerfile`: Remove `sudo` from all RUN instructions
   - `ansible/Dockerfile`: Remove `sudo` from all RUN instructions

5. **Add agent config validation**
   - JSON schema validation for `base/.opencode/opencode.json`
   - Verify plugin references match Dockerfile

6. **Add image health check tests**
   - `docker run --rm` tests for each variant
   - Verify key tools are installed (`docker`, `node`, `python3`, `go`, `ansible`, `opencode`/`qwencode`)

7. **Set `SOURCE_DATE_EPOCH`** for reproducible builds

**Acceptance Criteria:**
- [ ] `.dockerignore` present and `.git/` excluded from build context
- [ ] Go 1.23.0 downloads and installs successfully
- [ ] All `@latest` tags replaced with specific versions
- [ ] No `sudo` in `golang/Dockerfile` or `ansible/Dockerfile`
- [ ] `opencode.json` validates against schema
- [ ] All 4 images pass health check tests
- [ ] `make golang-opencode` succeeds locally after fixes

**Dependencies:** Phase 1 (build pipeline must exist to test fixes)

---

## Phase 3: Security Scanning

**Goal:** Add vulnerability scanning and secret detection to prevent compromised images from being published.

**Duration:** ~1-2 hours  
**Risk:** Medium  

### Tasks

1. **Add Trivy vulnerability scanning**
   - `aquasecurity/trivy-action@v0.35.0` in security job
   - Scan all 4 built image variants
   - SARIF output format
   - Upload to GitHub Security tab
   - `exit-code: 1` for CRITICAL/HIGH severity
   - `ignore-unfixed: true`
   - `vuln-type: os,library`

2. **Add Trivy secret scanning**
   - Enable `scanners: secret`
   - Flag Context7 token as known issue (suppress in scan config)
   - Report as warnings, not build blockers

3. **Add Trivy misconfiguration scanning**
   - Enable `scan-type: config`
   - Check for NOPASSWD sudo, HTTP endpoints, missing HEALTHCHECK
   - Report findings without blocking

4. **Create `trivy.yaml` configuration**
   - Centralized scan configuration
   - Severity thresholds
   - Known false positive suppressions

5. **Add cron job for Trivy DB pre-warming**
   - Daily scan to avoid rate limits on first build
   - Cache Trivy DB between runs

**Acceptance Criteria:**
- [ ] Trivy scans all 4 image variants on every build
- [ ] CRITICAL/HIGH vulnerabilities cause build failure
- [ ] Secret scanning detects Context7 token (or confirms suppression)
- [ ] Misconfiguration findings reported but don't block
- [ ] SARIF results visible in GitHub Security tab
- [ ] Cron job runs daily and pre-warms Trivy DB

**Dependencies:** Phase 2 (images must be buildable and scanned)

---

## Phase 4: Publish + Attestations

**Goal:** Finalize the pipeline with image attestations, SBOM generation, and production-ready publishing.

**Duration:** ~1-2 hours  
**Risk:** Low  

### Tasks

1. **Enable SBOM generation**
   - `sbom: true` in docker/build-push-action
   - Generate CycloneDX or SPDX format
   - Attach to image as attestation

2. **Add build provenance attestation**
   - `provenance: mode=max` in build-push-action
   - `actions/attest@v4` for additional attestations
   - Include commit SHA, branch, trigger info

3. **Add PR build artifacts**
   - Save built images as workflow artifacts
   - `actions/upload-artifact@v4`
   - 7-day retention
   - Post download link as PR comment

4. **Add workflow documentation**
   - Update README with CI/CD section
   - Document how to trigger builds manually
   - Document how to view scan results
   - Document how to download PR build artifacts

5. **Add release workflow (optional)**
   - Separate workflow for `v*` tags
   - Semver tag management
   - Release notes generation

6. **Add environment protection rules (if needed)**
   - Require manual approval for production pushes
   - Define environments in GitHub Actions

**Acceptance Criteria:**
- [ ] SBOM attached to every published image
- [ ] Build provenance attestation available in ghcr.io
- [ ] PR artifacts downloadable from workflow UI
- [ ] README documents CI/CD usage
- [ ] Full pipeline completes in < 15 minutes
- [ ] All non-functional requirements met (performance, reliability, maintainability)

**Dependencies:** Phase 3 (security scanning must be working)

---

## Risk Register

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Trivy scans fail due to rate limits | High | Medium | Pre-warm DB via cron job |
| Go 1.23.0 download fails | High | Low | Use official Go Docker image as fallback |
| ghcr.io push fails on private repo | High | Medium | Verify GITHUB_TOKEN has packages:write permission |
| hadolint rules too strict | Medium | Medium | Configure `.hadolint.yaml` with project-specific ignores |
| Build times exceed 15 min | Medium | Low | Use registry cache instead of GHA cache for larger images |
| Context7 token false positive in Trivy | Low | High | Add to trivy.yaml ignore list |

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Pipeline completion time | < 15 min | GitHub Actions timing |
| Build success rate | > 95% | GitHub Actions run history |
| Cache hit rate | > 70% | Build time comparison |
| PR feedback time | < 5 min | Lint job duration |
| Security scan coverage | 100% of images | Trivy scan results |
| Image reproducibility | 100% | SOURCE_DATE_EPOCH enforced |
