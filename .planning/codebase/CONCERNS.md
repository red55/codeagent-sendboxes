# Codebase Concerns

**Analysis Date:** 2026-04-20

## Tech Debt

### Hardcoded `@latest` Package Tags

**Issue:** Multiple packages use `@latest` tag across Dockerfiles, making builds non-reproducible and prone to breaking when upstream packages change.

**Files:**
- `base/opencode.Dockerfile` lines 2, 5-7, 11, 14 — `opencode-ai@latest`, `opencode-pty@latest`, `@franlol/opencode-md-table-formatter@latest`, `opencode-conductor-plugin@latest`, `@tarquinen/opencode-dcp@latest`, `opencode-websearch-cited@latest`
- `base/qwencode.Dockerfile` line 2 — `@qwen-code/qwen-code@latest`

**Impact:** A new major version of any of these packages can silently change behavior, introduce breaking changes, or become unavailable. Builds that passed yesterday may fail today.

**Fix approach:** Pin all packages to specific versions. Add a CI step that periodically checks for updates and creates PRs to bump versions. Consider using a lockfile strategy for bun/npm packages.

### Commented-Out Plugin Line

**Issue:** A commented-out plugin installation in `base/opencode.Dockerfile` line 13 indicates an abandoned or pending feature.

**Files:**
- `base/opencode.Dockerfile` line 13: `#RUN opencode plugin oh-my-openagent@latest -g`

**Impact:** Clutters the Dockerfile and may confuse future maintainers about whether this plugin should be re-enabled. The `@latest` tag is also present here, compounding the reproducible-build issue.

**Fix approach:** Remove the line if it's no longer needed, or uncomment and pin it to a specific version if it should be active.

### No .dockerignore File

**Issue:** The repository has no `.dockerignore` file, meaning the entire working directory (including `.git/`, `.planning/`, and any local files) is sent as the Docker build context.

**Files:**
- Missing: `.dockerignore`

**Impact:** 
- Bloated build context increases build time
- `.git/` directory (with full history) is sent to Docker daemon
- Sensitive local files may be accidentally included in image layers
- Docker build cache invalidation is less efficient

**Fix approach:** Create a `.dockerignore` that excludes `.git/`, `.planning/`, `node_modules/`, `*.md`, and any other non-essential files. At minimum, exclude `.git/`.

### Unnecessary `sudo` in Dockerfiles

**Issue:** The `golang/Dockerfile` and `ansible/Dockerfile` use `sudo` inside `RUN` instructions. Docker RUN commands execute as root by default, making `sudo` redundant.

**Files:**
- `golang/Dockerfile` lines 7, 9, 11, 14
- `ansible/Dockerfile` line 3

**Impact:** 
- Adds unnecessary overhead to each RUN command
- Obscures the fact that Docker RUN already runs as root
- If the Dockerfile ever switches to a non-root user mid-build, `sudo` commands would fail silently or cause errors

**Fix approach:** Remove `sudo` from all Dockerfile RUN instructions. Docker RUN always executes as root unless `USER` has been set.

### Debian Mirror Regional Dependency

**Issue:** The base Dockerfile hardcodes a Yandex mirror for Debian packages.

**Files:**
- `base/Dockerfile` line 7: `sed -i -E 's#https?://([a-z0-9.-]+.)?debian.org/debian#https://mirror.yandex.ru/debian#g'`

**Impact:** Users outside the Yandex mirror's region may experience slow or failed package downloads. This also means the build is dependent on a specific mirror's availability.

**Fix approach:** Either use the default Debian mirrors, make the mirror configurable via a build arg, or add a fallback mechanism.

---

## Known Bugs

### Hardcoded Go Version (1.26.2) May Not Exist

**Issue:** `golang/Dockerfile` line 4 specifies `GO_VERSION=1.26.2`. As of the current date, Go 1.26.x does not exist in the official Go release history (latest stable is in the 1.21-1.23 range).

**Files:**
- `golang/Dockerfile` line 4: `ARG GO_VERSION=1.26.2`
- `golang/Dockerfile` line 11: downloads from `go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz`

**Impact:** The Docker build will fail with a 404 error when trying to download the Go tarball. This is a silent build failure that only manifests during image construction.

**Trigger:** Run `make golang-opencode` or `make golang-qwencode`

**Workaround:** Update `GO_VERSION` to a valid Go release (e.g., `1.23.0` or whatever is current).

### Build Context Pollution via `.git/` in Image Layers

**Issue:** Without a `.dockerignore`, the `.git/` directory is included in every Docker build context. While the `rm -rf` in Dockerfile RUN layers may clean some things up, the `.git/` data passes through intermediate layers.

**Files:**
- `base/Dockerfile` — build context includes `.git/`
- All Dockerfiles — same issue

**Impact:** 
- Git history and refs are baked into intermediate Docker layers
- Sensitive commit metadata (author emails, commit messages) may leak into images
- Larger image layers and slower builds

**Fix approach:** Add `.dockerignore` to exclude `.git/` and other non-essential directories.

---

## Security Considerations

### Context7 Bearer Token Committed in Plaintext

**Issue:** A Context7 MCP Bearer token (`ctx7sk-a1c1beb1-b430-4f63-b8d3-abca285c6733`) is committed in plaintext in the repository configuration.

**Files:**
- `base/.opencode/opencode.json` lines 40-42

```json
"mcp": {
    "context7": {
        "type": "remote",
        "url": "https://mcp.context7.com/mcp",
        "headers": {
            "Authorization": "Bearer ctx7sk-a1c1beb1-b430-4f63-b8d3-abca285c6733"
        }
    }
}
```

**Risk:** Anyone with read access to this repository can use the token to access Context7's documentation lookup service. The token could be abused for rate limit exhaustion, billing abuse, or access to paid features.

**Current mitigation:** None — the token is publicly visible in the git history.

**Recommendations:**
1. **Rotate the token immediately** — generate a new token from the Context7 dashboard and revoke the existing one
2. **Move the token to an environment variable** — use `ENV CONTEXT7_API_KEY=...` and reference it via `${CONTEXT7_API_KEY}` in the config
3. **Use Docker build secrets or runtime env injection** — never bake secrets into image layers
4. **Remove the token from git history** — use `git filter-repo` or BFG Repo-Cleaner to purge it from all past commits, then force-push

### NOPASSWD Sudo for Agent User

**Issue:** The `agent` user has full passwordless sudo access.

**Files:**
- `base/Dockerfile` line 49: `echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent`

**Risk:** If the AI agent runtime is compromised (e.g., via a malicious plugin or prompt injection), the attacker gains full root access to the container with no authentication barrier.

**Current mitigation:** The agent runs as a non-root user by default (`USER agent` at line 122). Docker group membership is required for Docker-in-Docker operations.

**Recommendations:**
- Restrict sudo to only the commands the agent actually needs (e.g., `apt-get`, `pip3`, specific Docker commands)
- Use `sudoers` `!authenticate` sparingly and audit regularly
- Consider running the agent in a more restricted capability mode

### All Agent Permissions Set to Allow

**Issue:** Every agent role in `opencode.json` has `"*": "allow"` for all permissions.

**Files:**
- `base/.opencode/opencode.json` lines 33-34, 48-51, 74-77, etc.

**Risk:** No least-privilege enforcement. Any agent (including subagents) can execute any tool without restriction. If a subagent is compromised or behaves unexpectedly, it has full access.

**Recommendations:**
- Apply least-privilege principle — restrict tools to only what each agent role needs
- The `build` agent may need all tools, but subagents like `ansible-expert` and `git-expert` should be scoped to their specific domains
- Audit tool permissions periodically as new tools are added

### HTTP (Not HTTPS) for AI Provider

**Issue:** The Qwen-MBP AI provider connects over plain HTTP to an internal IP.

**Files:**
- `base/.opencode/opencode.json` line 177: `"baseURL": "http://192.168.151.31:8080/v1"`

**Risk:** All prompts and responses are transmitted unencrypted. On shared or compromised internal networks, this data can be intercepted.

**Current mitigation:** The IP `192.168.151.31` is on a private network, limiting exposure to the local subnet.

**Recommendations:**
- Use HTTPS with a self-signed or internal CA certificate if possible
- If HTTP is unavoidable, ensure the network is properly segmented and trusted
- Consider adding certificate validation via `NODE_EXTRA_CA_CERTS`

### Hardcoded Internal IP Address

**Issue:** The AI provider URL uses a hardcoded private IP address.

**Files:**
- `base/.opencode/opencode.json` line 177

**Risk:** The image is only usable on the specific network where `192.168.151.31` is reachable. Deploying to a different network requires rebuilding the image or manually editing the config.

**Recommendations:**
- Make the base URL configurable via environment variable: `ENV QWEN_MBP_BASE_URL=http://192.168.151.31:8080/v1`
- Reference it in the config as `${QWEN_MBP_BASE_URL}`

### No Input Validation or Rate Limiting on Agent Tools

**Issue:** The agent configuration grants unrestricted tool access with no rate limiting, input validation, or output sanitization.

**Files:**
- `base/.opencode/opencode.json` — agent tool permissions

**Risk:** A compromised or malicious agent could:
- Execute arbitrary shell commands (bash tool)
- Write arbitrary files (write/edit tools)
- Make unlimited external API calls (webfetch, websearch tools)
- Access the MCP server for documentation lookups

**Recommendations:**
- Implement rate limiting on tool usage
- Add input sanitization for shell commands
- Consider using a capabilities-based approach where tools are explicitly enabled/disabled

---

## Performance Bottlenecks

### Sequential Plugin Installation in OpenCode Dockerfile

**Issue:** Each `RUN opencode plugin ...` command in `base/opencode.Dockerfile` creates a separate Docker layer, with full plugin resolution and installation overhead.

**Files:**
- `base/opencode.Dockerfile` lines 5-14 (6 separate plugin installations)

**Impact:** 
- Each plugin install is a separate layer (no caching between plugins)
- Total build time is the sum of all individual plugin install times
- Network requests for each plugin are sequential

**Recommendations:**
- Batch plugin installations where possible: `RUN opencode plugin install plugin1 plugin2 plugin3`
- Or combine into a single RUN: `RUN opencode plugin opencode-pty@latest -g && opencode plugin @franlol/opencode-md-table-formatter@latest -g && ...`

### Multiple Separate RUN Layers in golang/Dockerfile

**Issue:** Each apt-get install, download, and extraction step is a separate RUN layer.

**Files:**
- `golang/Dockerfile` lines 7-15 (5 separate RUN commands)

**Impact:** 
- Each layer is built and cached independently
- Intermediate layers add to total image size
- No opportunity for apt-get to combine package installations

**Recommendations:**
- Combine related RUN commands into single layers where they share dependencies
- Example: combine apt-get install and cleanup into one RUN

### Duplicate apt-get cleanup

**Issue:** Both `base/Dockerfile` (line 114-115) and `golang/Dockerfile` (line 7) run `rm -rf /var/lib/apt/lists/*` and `apt-get clean`.

**Files:**
- `base/Dockerfile` lines 114-115
- `golang/Dockerfile` line 7

**Impact:** Minor — each cleanup only removes its own layer's apt cache. No cross-layer optimization.

**Recommendations:** This is acceptable as-is since Docker layers are isolated. No action needed unless image size becomes a concern.

---

## Fragile Areas

### OpenCode Plugin Dependencies

**Files:**
- `base/opencode.Dockerfile` lines 2-14
- `base/.opencode/opencode.json` lines 3-9

**Why fragile:** The entire agent runtime depends on 6+ external plugins, all using `@latest` tags. Any plugin can:
- Become unavailable (npm registry issue)
- Introduce breaking changes in a new version
- Depend on a specific OpenCode version that may not be installed

**Safe modification:**
- Pin plugin versions and test each update individually
- Add a health check that verifies all plugins load correctly
- Maintain a fallback configuration that works with a known-good plugin set

**Test coverage:** No automated tests for plugin compatibility or runtime health.

### Upstream Image Dependencies

**Files:**
- `Makefile` lines 5-6
- `base/opencode.Dockerfile` line 1
- `base/qwencode.Dockerfile` line 1

**Why fragile:** The base images (`oc-sandbox-base`, `qc-sandbox-base`) depend on upstream images (`docker/sandbox-templates:opencode-docker`, `ghcr.io/qwenlm/qwen-code:0.14`). If these upstream images change or are removed, all derived builds break.

**Safe modification:**
- Pin upstream image versions (not just `latest`)
- Monitor upstream image availability
- Maintain a local mirror or cache of upstream images

### Makefile Hardcoded Image Registry

**Files:**
- `Makefile` line 1: `CR := ghcr.io/red55`
- `Makefile` lines 2-3: `IMG := $(CR)/sandbox`, `VER := latest`

**Why fragile:** The registry and image name are hardcoded. Changing the registry requires editing the Makefile. The version is always `latest`, which provides no traceability.

**Safe modification:**
- Externalize registry and version via environment variables or a `.env` file
- Use semantic versioning for image tags
- Add a changelog or version manifest

---

## Scaling Limits

### Single-Provider Lock-In

**Current capacity:** The configuration is tightly coupled to the `qwen-mbp` provider at a specific internal IP.

**Limit:** Cannot easily switch to a different AI provider without modifying `opencode.json` and rebuilding the image.

**Scaling path:** Externalize provider configuration to environment variables or a mountable config file that can be swapped at runtime.

### No Multi-Tenancy Support

**Current capacity:** Each container runs a single agent configuration.

**Limit:** Cannot run multiple agent configurations in the same image without rebuilding.

**Scaling path:** Support runtime configuration via mounted volumes or environment variables that override `opencode.json` settings.

---

## Dependencies at Risk

### `get-shit-done` Package

**Risk:** The package `get-shit-done@^0.0.2` is a very early version with an informal name. It has dependencies on outdated packages:
- `chalk@1.1.3` (current is v5.x)
- `commander@^2.9.0` (current is v12.x)
- `node-notifier@^4.5.0` (deprecated, archived on npm)

**Files:**
- `package.json` line 3: `"get-shit-done": "^0.0.2"`
- `bun.lock` line 41: dependency tree shows outdated packages

**Impact:** If the package is abandoned or its dependencies break, the entire sandbox build could fail. The `node-notifier` package is archived and may no longer install.

**Migration plan:** 
- Audit the package's maintenance status
- Consider replacing with a well-maintained alternative
- Pin the version and add a fallback build path

### OpenCode Plugins (Community-Maintained)

**Risk:** Several plugins are from third-party authors (`@franlol`, `@tarquinen`) and may not be actively maintained.

**Files:**
- `base/opencode.Dockerfile` lines 6, 11

**Impact:** Plugin install failures would break the entire image build. There's no graceful degradation.

**Migration plan:** 
- Monitor plugin repositories for activity
- Prepare alternative plugin configurations
- Consider vendoring critical plugins

### Node.js 25 Base Image

**Risk:** `node:25-trixie` references a future Node.js version (25). This may be a pre-release or the version number may be incorrect.

**Files:**
- `base/Dockerfile` line 2: `FROM docker.io/library/node:25-trixie`

**Impact:** If Node.js 25 doesn't exist or is unstable, the base image pull will fail or produce unpredictable behavior.

**Migration plan:** Verify the Node.js version tag. If it's a pre-release, pin to a specific pre-release version and monitor for stability.

---

## Missing Critical Features

### No CI/CD Pipeline

**Problem:** No GitHub Actions, GitLab CI, or other automated build/test pipeline.

**Blocks:** 
- No automated validation of Docker builds
- No linting of Makefiles or Dockerfiles
- No security scanning of images
- No automated testing of agent configurations

**Priority:** High — without CI, build regressions can go undetected until deployment.

### No Image Security Scanning

**Problem:** No vulnerability scanning (e.g., Trivy, Snyk, Docker Scout) for the built images.

**Blocks:** 
- Cannot detect known CVEs in installed packages
- Cannot verify that secrets aren't leaked into image layers
- No compliance reporting

**Priority:** High — especially given the hardcoded token and NOPASSWD sudo.

### No Build Reproducibility

**Problem:** Using `@latest` tags for multiple packages means builds are not reproducible.

**Blocks:** 
- Cannot guarantee the same image from the same commit
- Debugging build regressions is difficult
- Audit trails are unreliable

**Priority:** Medium — affects all build pipelines.

### No Documentation for Operators

**Problem:** No `README.md`, `CONTRIBUTING.md`, or operator documentation.

**Blocks:** 
- New developers don't know how to build or deploy images
- No troubleshooting guide
- No architecture overview beyond the generated codebase docs

**Priority:** Medium — impacts onboarding and maintenance.

---

## Test Coverage Gaps

### No Tests for Dockerfile Validity

**What's not tested:** Dockerfile syntax, layer ordering, base image availability, plugin installation success.

**Files:**
- `base/Dockerfile`
- `base/opencode.Dockerfile`
- `base/qwencode.Dockerfile`
- `golang/Dockerfile`
- `ansible/Dockerfile`

**Risk:** Syntax errors or missing dependencies are only caught at build time, with no automated feedback loop.

**Priority:** High

### No Tests for Agent Configuration

**What's not tested:** `opencode.json` schema validity, plugin references, provider connectivity, agent tool permissions.

**Files:**
- `base/.opencode/opencode.json`

**Risk:** Configuration errors silently break the agent runtime.

**Priority:** High

### No Tests for Makefile Targets

**What's not tested:** Make target dependencies, variable correctness, image build success.

**Files:**
- `Makefile`

**Risk:** Broken Make targets are only discovered when manually running `make all`.

**Priority:** Medium

---

*Concerns audit: 2026-04-20*
