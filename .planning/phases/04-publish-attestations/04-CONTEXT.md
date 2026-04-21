# Phase 4: Publish + Attestations - Context

**Gathered:** 2026-04-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Finalize the CI/CD pipeline with image attestations, SBOM generation, and production-ready publishing. This phase adds build provenance, CycloneDX SBOMs for release images, PR tag support for fork PRs, and a release workflow with auto-generated notes.

**Delivers:** SBOM attachment to release images, provenance attestations (`mode=max`), PR tag publishing for fork PRs, release workflow with auto-generated notes, and minimal README documentation.

**Out of scope:** Image signing (cosign) — deferred to a future phase. Environment protection rules — not needed for this project scale.

</domain>

<decisions>
## Implementation Decisions

### SBOM Generation
- **D-01:** Use **CycloneDX** format for SBOM generation (OWASP-favored, better tooling integration). SBOMs generated only for **release builds** (not PR builds).
- **D-02:** Use `sbom: true` in `docker/build-push-action@v7` — native SBOM generation, no separate action needed.

### Provenance Attestation
- **D-03:** Use `provenance: mode=max` for full build provenance (build config, source, dependencies included).
- **D-04:** Attestations pushed to ghcr.io via `docker/build-push-action@v7` (native support, no separate `actions/attest` action needed).

### PR Build Artifacts
- **D-05:** PR builds push to ghcr.io with `pr-<number>` tags for **fork PRs only** (safer — avoids running on untrusted code from any PR).
- **D-06:** PR builds require `packages: write` permission but are gated on `github.event.pull_request.head.repo.fork == true`.

### Release Workflow
- **D-07:** Include release workflow in Phase 4 (user explicitly requested).
- **D-08:** Auto-generate release notes from commit messages using `github/release-actions`.
- **D-09:** Release workflow triggers on `v*` tags, builds all 4 variants, pushes to ghcr.io with semver tags.

### Documentation
- **D-10:** Minimal README documentation — only how to trigger builds and view results (not a full CI/CD guide).

### Architecture Responsibility
- **SBOM generation** → API/Backend tier (runs during build, attaches to image)
- **Provenance attestation** → API/Backend tier (runs during build, pushes to registry)
- **PR tag publishing** → Frontend Server tier (runs on PR events, gated by fork check)
- **Release workflow** → Frontend Server tier (runs on tag events, generates release notes)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Context
- `.planning/phases/01-foundation-lint-build/01-CONTEXT.md` — Phase 1 decisions (workflow structure, lint config)
- `.planning/phases/02-fix-build-reliability/02-CONTEXT.md` — Phase 2 decisions (build fixes, health checks)
- `.planning/phases/03-security-scanning/03-CONTEXT.md` — Phase 3 decisions (Trivy scanning, SARIF upload)
- `.planning/ROADMAP.md` — Phase 4 task list and acceptance criteria
- `.planning/REQUIREMENTS.md` — REQ-PUB-001, REQ-PUB-002, REQ-PUB-003, REQ-NFR-003

### Existing Workflow Files (MUST modify)
- `.github/workflows/pr.yml` — Add fork PR check for registry push
- `.github/workflows/release.yml` — Add SBOM, provenance, and release notes generation

### Source Files Referenced
- `base/Dockerfile` — Foundation image (build context)
- `base/opencode.Dockerfile` — OpenCode agent image
- `base/qwencode.Dockerfile` — QWEN Code agent image
- `golang/Dockerfile` — Go tooling image
- `ansible/Dockerfile` — Ansible tooling image
- `Makefile` — Build orchestration (used by workflows)

</canonical_refs>

<code_context>
## Existing Code Insights

### Build System
- **Makefile dependency graph:** `base` → `base-opencode`/`base-qwencode` → `golang-opencode`/etc. Each variant inherits from its parent.
- **Image variants:** 4 total — `oc-go`, `qc-go`, `oc-ansible`, `qc-ansible`
- **Registry:** `ghcr.io/red55/sandbox`

### Existing Patterns to Follow
- **Matrix strategy:** Both workflows use `fail-fast: false` with 4 variants — reuse this pattern for release workflow.
- **docker/build-push-action@v7:** Already used in release.yml for build + push — extend with `sbom: true` and `provenance: mode=max`.
- **SARIF upload:** Phase 3 established pattern with `github/codeql-action/upload-sarif@v3` — follow same pattern for any new SARIF outputs.

### GitHub Actions Features to Use
- **`docker/build-push-action@v7`:** Supports `sbom: true` and `provenance: mode=max` natively (no separate actions needed).
- **`github/release-actions`:** Auto-generate release notes from PR titles/commits.
- **`actions/checkout@v4`:** Standard checkout action for all workflows.

</code_context>

<specifics>
## Specific Ideas

- Use `docker/build-push-action@v7` with `sbom: true` and `provenance: mode=max` — native support, no separate actions.
- PR builds gated on `github.event.pull_request.head.repo.fork == true` to prevent untrusted code from pushing to registry.
- Release notes auto-generated using `github/release-actions` with template based on PR titles.
- README updates minimal — only document how to trigger builds manually and where to view scan results.

</specifics>

<deferred>
## Deferred Ideas

### Reviewed Todos (not folded)
None — no pending todos in this project.

### Deferred from Discussion
- **Image signing (cosign):** Belongs in a future phase beyond Phase 4. Not part of publishing scope.
- **Environment protection rules:** Not needed for this project scale.
- **Full CI/CD guide documentation:** Out of scope — minimal README updates only.
- **SBOM for PR builds:** User chose release builds only to reduce build time and registry usage.

</deferred>

---

*Phase: 04-publish-attestations*
*Context gathered: 2026-04-20*
