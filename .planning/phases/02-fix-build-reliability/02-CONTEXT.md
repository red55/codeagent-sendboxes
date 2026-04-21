# Phase 2: Fix Build Reliability - Context

**Gathered:** 2026-04-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix the critical build issues identified in the codebase analysis so CI builds actually succeed. This phase addresses Dockerfile correctness, dependency pinning, build context hygiene, and adds validation tests. It does NOT add new image features or change the build pipeline structure (that's Phase 1's job).

**Delivers:** All 4 image variants build successfully with `make all`, passing hadolint strict mode and health checks.

</domain>

<decisions>
## Implementation Decisions

### Go Installation
- **D-01:** Go 1.26.2 is valid and is the current latest stable release — keep it as-is.
- **D-02:** Remove `golang` from the apt-get install list in `base/Dockerfile` (line 106). The golang tarball install in `golang/Dockerfile` is the authoritative source. apt's golang package is redundant and may conflict.

### Package Version Pinning
- **D-03:** Pin ALL `@latest` tags to specific versions across all Dockerfiles:
  - `base/Dockerfile`: `bun@1.3.13`
  - `base/opencode.Dockerfile`: Pin all opencode plugins to specific versions
  - `base/qwencode.Dockerfile`: Pin `@qwen-code/qwen-code` to specific version
  - `golang/Dockerfile`: Pin `gopls` and `buf` to specific versions
  - `ansible/Dockerfile`: Pin `ansible`, `ansible-lint`, `ansible-pylibssh`, `mitogen` to specific versions
- **D-04:** Remove commented-out plugin line (`#RUN opencode plugin oh-my-openagent@latest -g`) from `base/opencode.Dockerfile` (line 17).

### Docker Mirror
- **D-05:** Keep the Yandex Debian mirror in `base/Dockerfile`. Suppress hadolint DL3039 for this specific rule in `.hadolint.yaml` (already configured in Phase 1).

### Build Context
- **D-06:** Create `.dockerignore` at project root. Exclude: `.git/`, `.planning/`, `node_modules/`, `*.md`, `*.txt`, `*.log`, `.opencode/` (except Dockerfiles reference it via COPY). Must NOT exclude `Dockerfile`, `Makefile`, or `base/` directories that are build contexts.

### Reproducible Builds
- **D-07:** Set `SOURCE_DATE_EPOCH=1700000000` (or similar fixed timestamp) in the Makefile or workflow environment for reproducible build timestamps.

### Health Checks
- **D-08:** Health check tests verify:
  - **Tool presence:** Key tools installed in each variant (`docker`, `node`, `python3`, `go`, `ansible`, `opencode`/`qwencode`, `bun`, `gopls`, `buf`, `ansible-lint`)
  - **Config validation:** `base/.opencode/opencode.json` validates against JSON schema (required fields: name, mode, tools for agents; valid provider URLs; plugin references match Dockerfile)
  - **Ownership:** Files copied via `COPY --chown=agent:agent` have correct ownership
- **D-09:** Health checks FAIL the build on:
  - Missing tools (any tool that should be present is not found)
  - Config validation errors (opencode.json is malformed or missing required fields)
  - File ownership issues (root-owned files where agent should own them)

### sudo Removal
- **D-10:** Remove all `sudo` from `golang/Dockerfile` (lines 7, 9, 11, 14) — Dockerfile RUN commands execute as root by default.
- **D-11:** Remove `sudo` from `ansible/Dockerfile` (line 1) — same reason.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Context
- `.planning/phases/01-foundation-lint-build/01-CONTEXT.md` — Phase 1 decisions (lint config, workflow structure, build strategy)
- `.planning/ROADMAP.md` — Phase 2 task list and acceptance criteria
- `.planning/REQUIREMENTS.md` — REQ-BUILD-005 (build fixes), REQ-TEST-001/002 (health/config validation)

### Source Files (must be modified)
- `base/Dockerfile` — Foundation image, contains `golang` apt package (to remove), `bun@latest` (to pin)
- `base/opencode.Dockerfile` — OpenCode agent, all plugins at `@latest` (to pin), commented line (to remove)
- `base/qwencode.Dockerfile` — Qwen agent, package at `@latest` (to pin)
- `golang/Dockerfile` — Go tooling, `sudo` usage (to remove), `@latest` pins (to pin), GO_VERSION (keep 1.26.2)
- `ansible/Dockerfile` — Ansible tooling, `sudo` usage (to remove), `@latest` pins (to pin)
- `base/.opencode/opencode.json` — Agent config (to validate in health checks)
- `Makefile` — Build orchestration (may need SOURCE_DATE_EPOCH)

### Lint Config (from Phase 1)
- `.github/lint/.hadolint.yaml` — DL3039 suppression for Yandex mirror already configured

</canonical_refs>

<code_context>
## Existing Code Insights

### Build System
- **Makefile dependency graph:** `base` → `base-opencode`/`base-qwencode` → `golang-opencode`/etc. Each variant inherits from its parent.
- **`EXTRA_ARGS` variable** (line 8): CI passes build args through this. Any new build args (like `SOURCE_DATE_EPOCH`) should flow through here or be set as environment variables.
- **External upstream images:** `OC_IMAGE` and `QC_IMAGE` are pulled from ghcr.io/qwenlm and docker.io. `make pull` fetches these before building.

### Dockerfile Patterns
- **Layered builds:** All Dockerfiles use `ARG IMAGE=` and `FROM ${IMAGE}` for layering.
- **Non-root user:** All containers switch to `agent` (UID 1000) via `USER agent`. Base image creates this user.
- **COPY --chown=agent:agent:** Used in opencode.Dockerfile and qwencode.Dockerfile for config files.
- **Multi-stage not used:** Each Dockerfile is a single stage building on top of its parent.

### Agent Config
- **opencode.json (200 lines):** Contains providers (Context7, Qwen-MBP), plugins (7 opencode plugins), LSP config, MCP servers, and agent definitions (opencode, git-expert, ansible-expert).
- **Sub-agents:** `base/agents/ansible-expert.md` and `base/agents/git-expert.md` define specialized sub-agent roles.

</code_context>

<specifics>
## Specific Ideas

- Health checks should run as a CI job that does `docker run --rm <image> <command>` for each variant.
- The `opencode.json` validation can use `jq` (already in base image) with a simple schema check: verify required fields exist, provider URLs are valid, plugin names match installed packages.
- Consider running health checks from within the CI workflow (as a separate job after build) rather than as a Makefile target.
- The `.dockerignore` must NOT exclude files needed by Docker builds (Dockerfiles, Makefile, `.opencode/` for COPY commands).

</specifics>

<deferred>
## Deferred Ideas

### Reviewed Todos (not folded)
None — no pending todos in this project.

### Deferred from Discussion
- **Multi-platform builds (arm64):** Explicitly out of scope. amd64 only.
- **Image signing (cosign):** Belongs in a future phase beyond Phase 4.
- **Notification integrations (Slack, email):** Out of scope.
- **Automated semver tagging:** Out of scope for CI/CD pipeline.

</deferred>

---

*Phase: 02-fix-build-reliability*
*Context gathered: 2026-04-20*
