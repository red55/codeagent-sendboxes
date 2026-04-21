# Phase 3: Security Scanning - Context

**Gathered:** 2026-04-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Add Trivy vulnerability scanning, secret detection, and Dockerfile misconfiguration scanning to the existing CI pipeline. Scan all 4 image variants on both PR builds (for early feedback) and release builds (for production gates). Results upload to GitHub Security tab via SARIF. A daily cron job pre-warms the Trivy DB to avoid rate limits.

**Delivers:** `trivy.yaml` config, Trivy scanning in `pr.yml` and `release.yml`, PR comment posting for findings, `trivy-cron.yml` for DB pre-warming.

**Out of scope:** Image signing (cosign) — deferred to a future phase. Secret rotation (Context7 token) — separate issue. Custom scanner development.

</domain>

<decisions>
## Implementation Decisions

### Scan Scope
- **D-01:** Trivy scans run on **both PR builds and release builds**. PR builds scan the locally-loaded image (no push needed — `trivy image` can scan from Docker's local image store). Release builds scan pushed images from ghcr.io.
- **D-02:** PR build scans post findings as **PR comments** (via reviewdog or `gh pr comment`) so authors see security issues immediately. Matches the existing actionlint PR comment pattern in `pr.yml`.

### Severity Thresholds
- **D-03:** **CRITICAL + HIGH** vulnerabilities **block the build** (`exit-code: 1`). **MEDIUM** vulnerabilities are reported but do not block. This keeps scans practical — base images (Debian/Ubuntu) commonly have MEDIUM findings.
- **D-04:** Secret scanning findings are **warnings only** (never block). Misconfiguration findings are **warnings only** (never block).

### Context7 Token Suppression
- **D-05:** Suppress the Context7 Bearer token in `opencode.json` by **file path** in `trivy.yaml` config. Ignore all secrets found in `base/.opencode/opencode.json` — this file is known to contain a bearer token. More targeted and maintainable than pattern matching.

### Scan Targets
- **D-06:** **Two scan types per variant:**
  1. **Image scan** — scans built Docker images for OS/library vulnerabilities (`vuln-type: os,library`) and secrets embedded in image layers (`scanners: secret`)
  2. **Dockerfile scan** — scans Dockerfiles for misconfigurations (`scan-type: config`) including NOPASSWD sudo, missing HEALTHCHECK, HTTP endpoints

### Workflow Structure
- **D-07:** Modify **both existing workflow files** (`pr.yml` and `release.yml`) to add Trivy scanning jobs. Do NOT create a single monolithic `ci.yml`.
- **D-08:** Create a **separate workflow file** `.github/workflows/trivy-cron.yml` for the daily Trivy DB pre-warm job. Clean separation of concerns — this workflow only downloads/updates the Trivy DB cache, no builds or scans.

### Cron Job
- **D-09:** Daily cron at **06:00 UTC** (`schedule: cron: '0 6 * * *'`). Pre-warms the Trivy DB cache so the first build of each day doesn't hit GitHub API rate limits. Uses `actions/cache` to persist the Trivy DB between runs.

### SARIF Upload
- **D-10:** Trivy vulnerability scan results uploaded to GitHub Security tab via `github/codeql-action/upload-sarif@v4` (same pattern as hadolint in Phase 1). Separate SARIF uploads for image vulnerabilities and Dockerfile misconfigurations.
- **D-11:** Secret scan results uploaded as SARIF but with `if: failure()` condition (only upload when findings exist, to avoid empty SARIF files cluttering the Security tab).

### Trivy Version
- **D-12:** Use `aquasecurity/trivy-action@v0.35.0` (or latest stable at planning time). Version pinned in workflow files.

### Architecture Responsibility
- **Image vulnerability scanning** → API/Backend tier (runs after build, on built images)
- **Dockerfile misconfiguration scanning** → Browser/Client tier equivalent (runs on source files, before/during build)
- **Secret scanning** → API/Backend tier (runs on built images, checks layers)
- **SARIF upload** → Frontend Server tier (integrates with GitHub platform)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Context
- `.planning/phases/01-foundation-lint-build/01-CONTEXT.md` — Phase 1 decisions (workflow structure, lint config, build strategy)
- `.planning/phases/02-fix-build-reliability/02-CONTEXT.md` — Phase 2 decisions (build fixes, health checks)
- `.planning/ROADMAP.md` — Phase 3 task list and acceptance criteria
- `.planning/REQUIREMENTS.md` — REQ-SEC-001, REQ-SEC-002, REQ-SEC-003

### Existing Workflow Files (MUST modify)
- `.github/workflows/pr.yml` — Add Trivy scan job (runs after build, posts PR comments)
- `.github/workflows/release.yml` — Replace stub security job with real Trivy scanning (image + config + secret scans)

### New Files to Create
- `.github/workflows/trivy-cron.yml` — Daily cron for Trivy DB pre-warming
- `.github/lint/trivy.yaml` — Trivy configuration (severity thresholds, path-based ignorelist)

### Source Files Referenced by Scans
- `base/.opencode/opencode.json` — Context7 token location (suppress by file path in trivy.yaml)
- `base/Dockerfile`, `base/opencode.Dockerfile`, `base/qwencode.Dockerfile` — Dockerfile config scan targets
- `golang/Dockerfile`, `ansible/Dockerfile` — Dockerfile config scan targets

</canonical_refs>

<code_context>
## Existing Code Insights

### Workflow Integration Points
- **pr.yml** already has a `lint` job and a `build` job (matrix, 4 variants). Trivy scan job should be added as a **new job** that depends on `build` (`needs: build`). It can run in parallel across variants (same matrix pattern).
- **release.yml** already has a `security` job stub (lines 126-154) with `exit-code: "0"` and `continue-on-error: true`. This stub MUST be replaced with a real Trivy scan. The job structure (matrix, needs: build) is correct — keep it.
- Both workflows already use `docker/setup-buildx-action@v4`, `docker/metadata-action@v6`, and `github/codeql-action/upload-sarif@v4`. These are reusable patterns.

### Existing Patterns to Follow
- **hadolint SARIF upload** in release.yml (lines 61-67): `if: always()` condition, `category: hadolint`. Trivy SARIF upload should follow the same pattern.
- **reviewdog actionlint** in pr.yml (lines 63-69): `github-pr-review` reporter, `level: error`. Secret/misconfig PR comments can use the same reviewdog pattern or `gh pr comment`.
- **Matrix strategy** in both workflows: `fail-fast: false`, variants `[oc-go, qc-go, oc-ansible, qc-ansible]`. Trivy jobs should use the same matrix.

### Trivy Image Scanning
- For **release builds**: Trivy scans `ghcr.io/red55/sandbox-<variant>:<sha>` (image already pushed)
- For **PR builds**: Trivy scans the locally-built image. The build step uses `docker buildx build --load` (not `--push`). Trivy can scan from the Docker daemon using `image-ref: ghcr.io/red55/sandbox-<variant>:pr-<number>` or by saving to archive first.

### Known Security Concerns (from CONCERNS.md)
- Context7 Bearer token in plaintext in `base/.opencode/opencode.json` — suppress by file path
- No `.dockerignore` was present in Phase 1 (fixed in Phase 2) — Trivy secret scanning will now correctly exclude `.git/` from build context
- Go version 1.26.2 fixed in Phase 2 — no impact on security scanning

</code_context>

<specifics>
## Specific Ideas

- The `trivy.yaml` config should use `ignorefiles` or `severity` filters to exclude `base/.opencode/opencode.json` from secret scanning.
- For PR builds, Trivy can scan the image directly from the Docker daemon without needing a push. Use `trivy image` with the locally-tagged image reference.
- The cron job should use `actions/cache` to persist the Trivy DB between runs, avoiding repeated downloads.
- Consider using `--severity CRITICAL,HIGH` in the Trivy CLI to match the blocking threshold.
- Secret scanning results should be posted as PR comments with `level: warning` (not `error`) to avoid blocking PRs.
- Dockerfile misconfiguration scanning should use `--scanners config` flag and target all 5 Dockerfiles.

</specifics>

<deferred>
## Deferred Ideas

### Reviewed Todos (not folded)
None — no pending todos in this project.

### Deferred from Discussion
- **Image signing (cosign):** Belongs in a future phase beyond Phase 4. Not part of Trivy scanning scope.
- **SBOM generation:** Deferred to Phase 4 (Publish + Attestations).
- **Provenance attestation:** Deferred to Phase 4.
- **Slack/email notifications for scan results:** Out of scope.
- **Automated vulnerability patching:** Would be a future phase — scanning detects, patching modifies Dockerfiles.
- **Trivy cache for PR builds:** PR builds don't persist images between runs. Each PR build gets a fresh Trivy DB download. Consider caching the DB by commit SHA if PR scan speed becomes an issue.

</deferred>

---

*Phase: 03-security-scanning*
*Context gathered: 2026-04-20*
