# Phase 1: Foundation — Lint + Build - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-20
**Phase:** 01-foundation-lint-build
**Areas discussed:** Build strategy, Workflow structure, Lint strictness, Cache strategy

---

## Build Strategy

| Option                        | Description                                                                            | Selected |
| ----------------------------- | -------------------------------------------------------------------------------------- | -------- |
| Docker bake (HCL)             | Single HCL file, efficient shared layer caching, mirrors Makefile structure            |          |
| GitHub Actions matrix         | Separate jobs per variant, more verbose but simpler YAML                               |          |
| Sequential builds             | Mirrors Makefile, simplest but slowest (no parallelism)                                |          |
| **make all + matrix push**    | Use existing Makefile in matrix jobs, push to ghcr.io                                  | ✓        |

**User's choice:** Use `make all` and GitHub matrix action to push built images to ghcr.

**Notes:** Hybrid approach — leverage existing Makefile (preserves dependency graph) while gaining CI parallelism through matrix. Each matrix job runs `make all` independently.

---

## Workflow Structure

| Option                                      | Description                                                  | Selected |
| ------------------------------------------- | ------------------------------------------------------------ | -------- |
| Single ci.yml with conditionals             | One file with `if: github.event_name == 'pull_request'`      |          |
| **Separate pr.yml + release.yml**           | Two focused files, cleaner separation of concerns            | ✓        |

**User's choice:** Separate `pr.yml` and `release.yml`.

**Notes:** Two workflows provide cleaner separation. PR workflow focuses on validation, release workflow handles publishing.

### Follow-up: pr.yml scope

| Option                                    | Description                                            | Selected |
| ----------------------------------------- | ------------------------------------------------------ | -------- |
| Lint + build only (no push)               | Validate syntax and builds succeed                     | ✓        |
| Lint + build + health check (no push)     | Build + run container, verify tools installed          |          |
| Lint only                                 | Fastest feedback, no build time                        |          |

**User's choice:** Lint + build only. Health checks deferred to Phase 2.

### Follow-up: release.yml scope

| Option                                      | Selected |
| ------------------------------------------- | -------- |
| **Lint + build + push + scan**              | ✓        |

**User's choice:** Full pipeline including security scan.

---

## Lint Strictness

| Option                           | Description                                                             | Selected |
| -------------------------------- | ----------------------------------------------------------------------- | -------- |
| Custom rules (.hadolint.yaml)    | Project-specific rules, fail on critical, ignore known false positives  |          |
| **Strict**                       | Fail on all warnings and errors                                         | ✓        |
| Lenient                          | Fail only on errors, warnings shown as comments                         |          |

**User's choice:** Strict hadolint. Known false positives (Yandex mirror) will be suppressed via `.hadolint.yaml` rather than loosening rules.

---

## Cache Strategy

| Option                                       | Description                                                        | Selected |
| -------------------------------------------- | ------------------------------------------------------------------ | -------- |
| **Simple GHA cache (type=gha)**              | Built-in, no extra actions, 10GB per-repo limit                    | ✓        |
| Registry cache with PR isolation             | Shared across branches, PR-specific cache, more complex setup      |          |

**User's choice:** Simple GHA cache. Aligns with prior PROJECT.md decision.

---

## Matrix Structure

| Option                                   | Description                                                     | Selected |
| ---------------------------------------- | --------------------------------------------------------------- | -------- |
| **4 separate matrix jobs**               | Each variant (oc-go, qc-go, oc-ansible, qc-ansible) is separate | ✓        |
| 2 matrix jobs (variant-level)            | Shared base builds, less redundant                              |          |
| Single job with make all                 | Simplest, slowest, no parallelism                               |          |

**User's choice:** 4 separate matrix jobs. Simpler configuration, redundant base builds are acceptable with GHA cache.

---

## the agent's Discretion

- **Workflow DRY approach** — Whether to use `workflow_call` reusable workflows or copy shared steps between pr.yml and release.yml. Planner decides based on complexity tradeoff.
- **actionlint configuration** — Whether to use reviewdog for PR comments or standalone SARIF upload.
- **Concurrency group naming** — Exact naming convention for `concurrency` groups.

---

## Deferred Ideas

- Health check tests for built images (deferred to Phase 2)
- Registry cache with PR isolation (rejected in favor of GHA cache)
- Docker bake HCL file (rejected in favor of existing Makefile)
- SBOM and provenance attestation (deferred to Phase 4)
- Trivy secret/misconfiguration scanning (deferred to Phase 3, but workflow skeleton should include job structure)
