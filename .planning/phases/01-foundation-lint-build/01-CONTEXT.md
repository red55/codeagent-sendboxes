# Phase 1: Foundation — Lint + Build - Context

**Gathered:** 2026-04-20  
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish a working GitHub Actions CI/CD pipeline that lints Dockerfiles and builds all 4 sandbox image variants. This phase creates the CI infrastructure — lint gates, build validation, and the workflow skeleton. Fixing broken builds and adding security scanning belong in later phases.

**Delivers:** Working `pr.yml` (lint + build validation) and `release.yml` (full pipeline with push) workflows.

</domain>

<decisions>
## Implementation Decisions

### Build Strategy
- **D-01:** Use existing `make all` as the build command in CI — do not replace Makefile with Docker bake. Matrix jobs run `make all` in the `base/` context directory.
- **D-02:** 4 separate matrix jobs: `oc-go`, `qc-go`, `oc-ansible`, `qc-ansible`. Each job builds all variants independently (redundant base builds, but simpler and more resilient).

### Workflow Structure
- **D-03:** Two separate workflow files:
  - `.github/workflows/pr.yml` — triggers on `pull_request` to `main`. Runs lint + build. Does NOT push images.
  - `.github/workflows/release.yml` — triggers on `push` to `main` and `tags[v*]`. Runs lint + build + push to ghcr.io + security scan.
- **D-04:** Both workflows share the same lint and build steps (DRY via `workflow_call` reusable workflows or copied steps).

### Linting
- **D-05:** Strict hadolint — fail on all warnings and errors. Use `.hadolint.yaml` to suppress known false positives (Yandex mirror, etc.) rather than loosening rules globally.
- **D-06:** actionlint for GitHub Actions workflow syntax validation, with reviewdog for PR comments.
- **D-07:** SARIF output from hadolint uploaded to GitHub Security tab.

### Caching
- **D-08:** Simple GHA cache (`cache-from: type=gha`, `cache-to: type=gha,mode=max`). No registry cache or PR-specific cache isolation — the 10GB per-repo limit is sufficient for this project.

### Registry
- **D-09:** Images published to `ghcr.io/red55/sandbox` using GITHUB_TOKEN with `packages: write` permission. Push only from `release.yml` (not `pr.yml`).

### Tags
- **D-10:** Tag scheme via `docker/metadata-action@v6`:
  - PR builds: `pr-<number>`
  - Main branch: `latest` + git SHA
  - Tags: semver (`v1.0.0`)

### Concurrency
- **D-11:** `concurrency` group per branch/PR to cancel stale runs. Group name: `ci-${{ github.ref }}`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Project vision, goals, scope, constraints, success criteria
- `.planning/REQUIREMENTS.md` — 23 requirements across 7 categories (CI, lint, build, test, security, publish, NFR)
- `.planning/ROADMAP.md` — 4-phase roadmap with tasks and acceptance criteria
- `.planning/STATE.md` — Project state, decisions, open questions

### Codebase Analysis
- `.planning/codebase/STACK.md` — Technology stack (Docker, Make, Node.js, Go, Python, OpenCode, Qwen Code)
- `.planning/codebase/ARCHITECTURE.md` — Layered image composition (base → variant → platform)
- `.planning/codebase/STRUCTURE.md` — Directory layout: `base/`, `golang/`, `ansible/`, `Makefile`
- `.planning/codebase/CONCERNS.md` — Known issues: Go 1.26.2 doesn't exist, no .dockerignore, @latest tags, plaintext token
- `.planning/codebase/CONVENTIONS.md` — Dockerfile patterns, Makefile conventions, agent markdown structure
- `.planning/codebase/TESTING.md` — No application tests; tooling-based validation via ansible-lint, pyright, gopls
- `.planning/codebase/INTEGRATIONS.md` — ghcr.io registry, Context7 MCP, Qwen-MBP provider

### Research
- `.planning/research/ci-cd-docker.md` — GitHub Actions Docker CI/CD patterns, hadolint, actionlint, Trivy, build caching, SBOM

### Build System (source of truth)
- `Makefile` — Build orchestration, targets: `all`, `base`, `base-opencode`, `base-qwencode`, `golang-opencode`, `golang-qwencode`, `ansible-opencode`, `ansible-qwencode`
- `base/Dockerfile` — Foundation image (Node.js 25, Docker, Go, Python, Bun)
- `base/opencode.Dockerfile` — OpenCode agent runtime + plugins
- `base/qwencode.Dockerfile` — Qwen Code agent runtime
- `golang/Dockerfile` — Go tooling (gopls, buf, protoc)
- `ansible/Dockerfile` — Ansible tooling (ansible-lint, mitogen)
- `base/.opencode/opencode.json` — Agent configuration (providers, plugins, agents, LSP, MCP)
- `base/agents/ansible-expert.md` — Sub-agent definition
- `base/agents/git-expert.md` — Sub-agent definition

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Makefile** — All build logic already defined. CI should call `make` targets, not reimplement Docker builds.
- **`EXTRA_ARGS` variable** in `Makefile` (line 8) — CI can pass `--build-arg` or other flags through this.
- **Image tagging pattern** — `$(CR)/sandbox` with variant suffixes (`-oc-go`, `-qc-go`, `-oc-ansible`, `-qc-ansible`) defined in `Makefile`.

### Established Patterns
- **Layered image composition** — `base/` → variant (`opencode.Dockerfile`/`qwencode.Dockerfile`) → platform (`golang/`/`ansible/`). Makefile encodes this dependency graph.
- **Build arg passthrough** — `ARG IMAGE=` in all Dockerfiles enables layering. CI must pass correct `--build-arg IMAGE=` for each layer.
- **Non-root agent user** — All containers run as `agent` (UID 1000) with sudo and Docker group access.

### Integration Points
- **`make all`** is the single entry point for building all 4 variants. CI matrix jobs should run `make all` from the repo root.
- **`make clean`** and **`make prune`** for cleanup between workflow runs.
- **`make pull`** to fetch upstream images before building.

</code_context>

<specifics>
## Specific Ideas

- CI should run `make pull` before `make all` to ensure upstream images are available.
- Each matrix job should set `EXTRA_ARGS` from GitHub secret or env var to allow custom build flags.
- The `gh` CLI is already installed in the base image — can be used for PR comments from CI.
- SARIF upload to GitHub Security tab requires `security-events: write` permission.

</specifics>

<deferred>
## Deferred Ideas

### Reviewed Todos (not folded)
None — no pending todos in this project.

### Deferred from Discussion
- **Test scope (health checks)** — User deferred build+health-check tests to Phase 2 (Fix Build Reliability). Phase 1 only validates that builds succeed.
- **Registry cache with PR isolation** — Rejected in favor of simple GHA cache. Can be revisited if cache limits become an issue.
- **Docker bake** — Rejected in favor of `make all` to preserve existing Makefile structure.
- **SBOM and provenance attestation** — Deferred to Phase 4 (Publish + Attestations).
- **Trivy secret scanning** — Deferred to Phase 3 (Security Scanning), though the workflow skeleton should include the job structure.
- **Workflow DRY via `workflow_call`** — Not decided. Could use reusable workflows for shared lint/build steps, or copy steps. Planner has discretion.

</deferred>

---

*Phase: 01-foundation-lint-build*
*Context gathered: 2026-04-20*
