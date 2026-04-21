# Architecture

**Analysis Date:** 2026-04-20

## Pattern Overview

**Overall:** Multi-stage Docker sandbox orchestration with layered image composition.

This project is a Docker image build system for AI agent sandboxes. It uses a hierarchical base → variant → platform image pattern, where each layer adds specific tooling and capabilities. The architecture is driven entirely by Makefile targets that compose Docker images through multi-stage builds.

**Key Characteristics:**
- Layered image composition: base → variant (opencode/qwencode) → platform (golang/ansible)
- Makefile-driven build orchestration with explicit dependency ordering
- Shared base image (`base/Dockerfile`) seeded from upstream AI coding tools
- Non-root `agent` user (UID 1000) with sudo and Docker access
- Persistent shell environment via `/etc/sandbox-persistent.sh`

## Layers

### Base Layer

**Purpose:** Foundation image with common tools, runtime, and user setup.

**Location:** `base/Dockerfile`

**Contains:**
- Node.js 25 (Trixie/Debian bookworm base)
- Python 3 with `pyright` and `uv`
- Go 1.x (system package)
- Bun runtime (installed via npm)
- Docker CE + CLI + Buildx + Compose
- GitHub CLI (`gh`), ripgrep, jq, make
- Non-root `agent` user with sudo and docker group access
- Proxy environment variable passthrough via sudoers
- Persistent shell hook (`/etc/sandbox-persistent.sh`)

**Depends on:** Upstream image passed via `--build-arg IMAGE=`

**Used by:** `base-opencode`, `base-qwencode`, and all platform variants

### Variant Layer (Agent Runtime)

**Purpose:** Installs the AI coding agent runtime and plugins on top of the base.

**Locations:**
- `base/opencode.Dockerfile` — OpenCode agent runtime
- `base/qwencode.Dockerfile` — Qwen Code agent runtime

**Contains (opencode.Dockerfile):**
- `opencode-ai` package (installed via bun)
- Plugins: `opencode-pty`, `opencode-md-table-formatter`, `opencode-conductor-plugin`, `opencode-dcp`, `opencode-websearch-cited`
- `get-shit-done-cc` SDK (global install)
- Config files from `base/.opencode/` → `/home/agent/.config/opencode/`
- Agent definitions from `base/agents/` → `/home/agent/.config/opencode/agents/`
- Volumes for config persistence

**Contains (qwencode.Dockerfile):**
- `@qwen-code/qwen-code` (installed via bun)
- `get-shit-done-cc` SDK (qwencode-specific)

**Depends on:** `oc-sandbox-base:latest` or `qc-sandbox-base:latest` (the intermediate base images built from `base/Dockerfile`)

**Used by:** `golang-opencode`, `golang-qwencode`, `ansible-opencode`, `ansible-qwencode`

### Platform Layer

**Purpose:** Adds language/platform-specific tooling on top of variant images.

**Locations:**
- `golang/Dockerfile` — Go development tooling
- `ansible/Dockerfile` — Ansible infrastructure automation tooling

**Contains (golang/Dockerfile):**
- Go 1.26.2 (custom version, installed from tarball)
- `build-essential` and `linux-source`
- Protocol Buffers v34.1
- `gopls` (Go language server)
- `buf` (protobuf build tool)
- GOPATH set to `/usr/local/go`

**Contains (ansible/Dockerfile):**
- `netaddr`, `ansible-pylibssh`, `mitogen`
- `ansible-lint` and `ansible`
- Python-based Ansible execution environment

**Depends on:** Variant layer image passed via `--build-arg IMAGE=`

## Data Flow

### Image Build Pipeline

```
Upstream Image (OC_IMAGE / QC_IMAGE)
    ↓ --build-arg IMAGE=
base/Dockerfile  →  oc-sandbox-base:latest / qc-sandbox-base:latest
    ↓ --build-arg IMAGE=
base/opencode.Dockerfile  →  opencode-sandbox-base:latest
base/qwencode.Dockerfile  →  qwencode-sandbox-base:latest
    ↓ --build-arg IMAGE=
golang/Dockerfile  →  $(IMG)-oc-go:latest / $(IMG)-qc-go:latest
ansible/Dockerfile →  $(IMG)-oc-ansible:latest / $(IMG)-qc-ansible:latest
```

**Flow:**
1. `make pull` downloads upstream agent runtime images
2. `make base` builds intermediate sandbox bases from upstream images
3. `make golang-opencode` composes golang tooling on top of opencode base
4. `make ansible-qwencode` composes ansible tooling on top of qwencode base
5. `make all` builds all four platform-variant combinations

### Runtime Configuration Flow

1. `/home/agent/.config/opencode/opencode.json` — Main agent config (plugins, providers, agents, MCP)
2. `/home/agent/.config/opencode/agents/` — Sub-agent definitions (`ansible-expert.md`, `git-expert.md`)
3. `/etc/sandbox-persistent.sh` — Shell environment hook loaded on every bash session
4. `/home/agent/.local/share/opencode/` — Runtime state (persisted via Docker volume)

## Key Abstractions

### Sandbox Image Composition

The project abstracts Docker image building into composable layers. Each layer is a self-contained Dockerfile that extends its parent. The Makefile encodes the build graph and dependency ordering.

**Pattern:** `IMAGE` build arg controls the parent image, enabling any Dockerfile to be reused across the hierarchy.

### Agent Configuration

The `.opencode/` directory abstracts the AI agent runtime configuration:

- **Providers** (`provider.qwen-mbp`): Local LLM endpoint with model definitions and context limits
- **Plugins** (`plugin`): Runtime extensions (PTY, web search, markdown formatting, etc.)
- **Agents** (`agent.*`): Named agent roles with tool permissions and nested subagents
- **LSP** (`lsp`): Language server protocol configuration for Ansible and Go

### Persistent Shell Environment

The `sandbox-persistent.sh` mechanism provides a hook for runtime environment customization:

```bash
# In Dockerfile:
touch /etc/sandbox-persistent.sh
echo 'if [ -f /etc/sandbox-persistent.sh ]; then . /etc/sandbox-persistent.sh; fi; export BASH_ENV=/etc/sandbox-persistent.sh' \
    | tee /etc/profile.d/sandbox-persistent.sh /tmp/sandbox-bashrc-prepend /home/agent/.bashrc
```

This ensures any script placed at `/etc/sandbox-persistent.sh` is loaded on every shell session.

## Entry Points

### Build Entry: `Makefile`

**Location:** `Makefile`

**Triggers:** `make` commands (e.g., `make all`, `make golang-opencode`)

**Responsibilities:**
- Define build targets and dependencies
- Manage image tags and versions
- Orchestrate Docker build and prune commands
- Control image registry (`ghcr.io/red55`)

### Runtime Entry: `base/opencode.Dockerfile` (CMD)

**Location:** `base/opencode.Dockerfile`, line 21

**Triggers:** Container start

**Responsibilities:** Launches the `opencode` CLI as the container's main process.

### Agent Config Entry: `base/.opencode/opencode.json`

**Location:** `base/.opencode/opencode.json`

**Triggers:** OpenCode agent runtime initialization

**Responsibilities:** Configures plugins, LSP, agent roles, MCP tools, and LLM provider connections.

## Error Handling

**Strategy:** Fail-fast Docker builds with no explicit error handling logic.

**Patterns:**
- Makefile uses `.PHONY` targets; failures propagate to the caller
- `docker rmi -f` in `clean` target uses `|| true` to tolerate missing images
- `apt-get clean && rm -rf /var/lib/apt/lists/*` in Dockerfiles to minimize image size
- `userdel node || true` to tolerate pre-existing user

## Cross-Cutting Concerns

**Proxy Configuration:**
- `NO_PROXY` / `no_proxy` environment variables set for internal networks
- Proxy vars preserved through sudo via `/etc/sudoers.d/proxyconfig`
- Applied to `NODE_EXTRA_CA_CERTS`, `REQUESTS_CA_BUNDLE`, `JAVA_TOOL_OPTIONS`

**User & Permissions:**
- Non-root `agent` user (UID 1000) created in base image
- Docker group membership for container-in-Docker (DinD)
- Sudo without password for all operations
- Ownership corrected for npm global packages and persistent directories

**Shell Environment:**
- `BASH_ENV=/etc/sandbox-persistent.sh` for interactive shell config
- `NPM_CONFIG_PREFIX=/usr/local/share/npm-global` for global npm packages
- `PATH` includes `~/.local/bin`, npm-global bin, and bun bin

---

*Architecture analysis: 2026-04-20*
