# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v0.35.0 — Sandbox CI/CD Pipeline

**Shipped:** 2026-04-21
**Phases:** 4 | **Plans:** 11 | **Sessions:** 4

### What Was Built
- GitHub Actions workflows (pr.yml + release.yml + trivy-cron.yml) for CI/CD
- 4-variant Docker image build pipeline (opencode/qwencode × golang/ansible)
- Trivy security scanning (vulnerability, secret, misconfiguration)
- CycloneDX SBOM + provenance attestations on release images
- Fork PR-gated registry push with pr-<number> tags
- Health check and config validation scripts

### What Worked
- Wave-based planning (parallel plans within phases) kept execution efficient
- Phase-by-phase verification caught gaps early (Phase 04 had 2 gaps fixed in commit b30a412)
- Separate pr.yml + release.yml provided cleaner separation of concerns
- GHA cache (type=gha) was sufficient for project scale

### What Was Inefficient
- Phase 2 had 1 plan but covered many files (6 Dockerfiles + Makefile + 2 scripts) — should have been split into sub-plans
- Requirements document had unchecked checkboxes throughout — traceability was done in phase summaries, not REQUIREMENTS.md
- healthcheck.sh cannot run in `make check` without pre-built images — missed this constraint during planning

### Patterns Established
- `gsd-sdk query roadmap.analyze` for comprehensive phase readiness checks
- Phase summaries with frontmatter (requirements, key-files, tech-stack) for machine-readable tracking
- Verification files with structured gap tracking (status, score, gaps_fixed, overrides)

### Key Lessons
1. Split large phases into sub-plans when they touch many files — Phase 2 touched 6 Dockerfiles in 1 plan
2. Requirements traceability works better in phase VERIFICATION.md than in a global REQUIREMENTS.md with unchecked boxes
3. Document tooling constraints early (healthcheck.sh requires built images) to avoid partial implementations

### Cost Observations
- 4 phases executed in 1 milestone
- All phases completed within ~1 day (2026-04-20 to 2026-04-21)

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v0.35.0 | 4 | 11 | Full CI/CD pipeline from scratch |
