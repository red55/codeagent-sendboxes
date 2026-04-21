---
phase: 02-fix-build-reliability
reviewed: 2026-04-20T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - .dockerignore
  - Makefile
  - ansible/Dockerfile
  - base/Dockerfile
  - base/opencode.Dockerfile
  - base/qwencode.Dockerfile
  - golang/Dockerfile
  - scripts/healthcheck.sh
  - scripts/validate-config.sh
findings:
  critical: 1
  warning: 2
  info: 3
  total: 6
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-04-20
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 02 makes solid improvements to build reliability: pinning package versions across Dockerfiles, removing unnecessary `sudo` usage, adding `.dockerignore`, and introducing healthcheck and config validation scripts. However, there is one **critical issue** with `.dockerignore` placement (it is effectively unused), two **warnings** about inconsistent version pinning, and three **info-level** observations about script improvements.

---

## Critical Issues

### CR-01: `.dockerignore` is placed at root but never used by Docker builds

**File:** `.dockerignore`
**Issue:** The `.dockerignore` file is at the repository root, but **none of the Docker build contexts in the Makefile use the root directory**. Docker only reads `.dockerignore` from the build context root:

```
docker build -t oc-sandbox-base:$(VER) ... base/        # looks for base/.dockerignore
docker build -t qc-sandbox-base:$(VER) ... base/        # looks for base/.dockerignore
docker build -t $(IMG)-oc-go:$(VER) ... golang/         # looks for golang/.dockerignore
docker build -t $(IMG)-oc-ansible:$(VER) ... ansible/   # looks for ansible/.dockerignore
```

The root `.dockerignore` is effectively dead code. While it doesn't cause functional harm (the build contexts are subdirectories that don't have extraneous files), it gives a false sense of security.

**Fix:** Copy `.dockerignore` into each build context directory, or add `.dockerignore` files to `base/`, `golang/`, and `ansible/`:

```
# base/.dockerignore
.planning/
*.md
*.txt
*.log
node_modules/
.bun.lock
```

---

## Warnings

### WR-01: `gopls` and `buf` still use `@latest` in `golang/Dockerfile`

**File:** `golang/Dockerfile:14`
**Issue:** The PR goal is to pin all versions for reproducible builds, but lines 14-15 still use `@latest`:

```dockerfile
RUN chown 1000:1000 -R $GOPATH && go install golang.org/x/tools/gopls@latest && \
    go install github.com/bufbuild/buf/cmd/buf@latest
```

This was changed in commit `f4c17cd` to `@v0.21.1` and `@v1.68.2` respectively, but the diff shows the current state uses `@latest`. Wait — re-reading the diff, the **new** code (after the change) shows `@v0.21.1` and `@v1.68.2`. I need to re-examine...

Actually, the diff shows the **old** (before) and **new** (after) correctly:
- Old: `go install golang.org/x/tools/gopls@latest`
- New: `go install golang.org/x/tools/gopls@v0.21.1`

The file I read shows `@v0.21.1` and `@v1.68.2`. So this is **correctly pinned**. My initial assessment was wrong — the current file content is correct. Removing this warning.

**Correction:** No issue found. The versions are properly pinned.

### WR-02: `check_tool` function has unused parameter

**File:** `scripts/healthcheck.sh:17-19`
**Issue:** The `check_tool` function accepts an `expected` parameter that is never used inside the function body. This is misleading — callers might expect it to validate the tool version, but it only checks existence via `which`.

```bash
check_tool() {
    local tool="$1"
    local expected="${2:-}"    # Never used
    if docker run --rm "$IMAGE" which "$tool" >/dev/null 2>&1; then
```

The `check_tool_version` function exists separately for version checks, so the `expected` parameter on `check_tool` appears to be leftover from a planned feature that was never implemented.

**Fix:** Remove the unused parameter:

```bash
check_tool() {
    local tool="$1"
    if docker run --rm "$IMAGE" which "$tool" >/dev/null 2>&1; then
```

### WR-03: `validate-config.sh` has inconsistent error counting for URL validation

**File:** `scripts/validate-config.sh:55-63`
**Issue:** The URL validation check adds to `ERRORS` but the `check_field` calls below it also add to `ERRORS`. If a provider has a missing `baseURL`, `check_field` catches it (line 53), but then the URL format validation (lines 55-63) is skipped because `base_url` is empty. This is actually correct behavior — but the logic is fragile. If someone changes the `check_field` to not fail on missing `baseURL`, the URL format check would silently pass with an empty string.

**Fix:** Consider combining these into a single validation function or adding a comment explaining the dependency.

---

## Info

### IN-01: `qwencode.Dockerfile` missing trailing newline

**File:** `base/qwencode.Dockerfile`
**Issue:** The file has no trailing newline. Git diff shows `\ No newline at end of file`. This is a minor POSIX violation and can cause issues with some tools that expect newline-terminated files.

**Fix:** Add a blank line at the end of the file.

### IN-02: `jq -e` usage in `validate-config.sh` is safe but could be clearer

**File:** `scripts/validate-config.sh:28`
**Issue:** `jq -e` returns exit code 1 when the result is `null` or `false`, which is used here to detect missing fields. With `set -e`, this would normally abort the script, but because it's inside an `if` condition, the exit code is consumed. This works correctly but is a subtle pattern that could confuse readers.

**Fix:** Add a comment explaining why `jq -e` is used and why `set -e` doesn't interfere:

```bash
# jq -e exits 1 for null/false values; safe inside if (set -e doesn't trigger)
```

### IN-03: `SOURCE_DATE_EPOCH` has a fixed timestamp

**File:** `Makefile:9`
**Issue:** `SOURCE_DATE_EPOCH := 1700000000` is hardcoded to a fixed value (Nov 14, 2023). This is correct for reproducible builds, but the comment should explain why a fixed value is used rather than `$(shell date +%s)`.

**Fix:** Add a comment:

```makefile
# Fixed epoch for reproducible builds — must not change between builds
SOURCE_DATE_EPOCH := 1700000000
export SOURCE_DATE_EPOCH
```

---

## Positive Observations

1. **Version pinning across all Dockerfiles** — `opencode.Dockerfile`, `qwencode.Dockerfile`, `golang/Dockerfile`, and `ansible/Dockerfile` all pin specific versions. This is the core improvement of this phase.

2. **`sudo` removal from Dockerfiles** — The `golang/Dockerfile` and `ansible/Dockerfile` correctly remove `sudo` since the `agent` user already has NOPASSWD sudoers configured. This reduces attack surface.

3. **`.dockerignore` content is well-structured** — Despite the placement issue, the patterns are appropriate: excludes VCS, planning docs, node_modules, IDE configs, build artifacts, and OS junk.

4. **`healthcheck.sh` is comprehensive** — Covers all 5 image variants (base, opencode, qwencode, golang, ansible) with appropriate tool checks per variant.

5. **`validate-config.sh` is thorough** — Validates JSON syntax, required fields, agent definitions, provider URLs, plugins, LSP configs, and file ownership.

6. **`set -euo pipefail`** — Both scripts correctly use strict bash mode.

---

## Verdict

The phase makes meaningful improvements to build reliability through version pinning, script creation, and Dockerfile cleanup. The `.dockerignore` placement issue (CR-01) should be addressed to ensure the file is actually effective. The remaining issues are minor code quality improvements.

**Recommended actions:**
1. [CRITICAL] Add `.dockerignore` to each build context directory (`base/`, `golang/`, `ansible/`)
2. [WARNING] Remove unused `expected` parameter from `check_tool` in `healthcheck.sh`
3. [INFO] Add trailing newline to `qwencode.Dockerfile`
4. [INFO] Add explanatory comments for `SOURCE_DATE_EPOCH` and `jq -e` usage

---

_Reviewed: 2026-04-20T00:00:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
