# Codebase Structure

**Analysis Date:** 2026-04-20

## Directory Layout

```
[project-root]/
├── .git/                  # Git repository metadata
├── .gitignore             # Ignores node_modules/
├── .planning/             # Planning artifacts (codebase docs)
│   └── codebase/          # Architecture/structure/convention docs
├── ansible/               # Ansible platform Docker image
│   └── Dockerfile         # Installs Ansible + linting + mitogen
├── base/                  # Base sandbox image and agent config
│   ├── .opencode/         # OpenCode agent configuration
│   │   └── opencode.json  # Plugins, providers, agents, LSP, MCP
│   ├── agents/            # Sub-agent role definitions
│   │   ├── ansible-expert.md  # Ansible playbook/role expert agent
│   │   └── git-expert.md      # Git version control expert agent
│   ├── Dockerfile         # Foundation image: Node, Python, Go, Docker, tools
│   ├── opencode.Dockerfile  # OpenCode agent runtime + plugins
│   └── qwencode.Dockerfile  # Qwen Code agent runtime
├── bun.lock               # Bun package manager lockfile
├── golang/                # Go platform Docker image
│   └── Dockerfile         # Go 1.26.2, gopls, buf, protobuf
├── Makefile               # Build orchestration for all Docker images
└── package.json           # Single dependency: get-shit-done SDK
```

## Directory Purposes

### `base/`
- **Purpose:** Foundation layer for all sandbox images. Contains the base Dockerfile that installs common tooling, plus agent configuration and variant Dockerfiles.
- **Contains:** Dockerfiles, OpenCode config, agent markdown definitions
- **Key files:**
  - `Dockerfile` — Base image with Node 25, Python 3, Go, Docker CE, gh, ripgrep, bun
  - `opencode.Dockerfile` — OpenCode agent runtime with plugins and tool extensions
  - `qwencode.Dockerfile` — Qwen Code agent runtime
  - `.opencode/opencode.json` — Agent config (providers, plugins, agents, LSP, MCP)
  - `agents/ansible-expert.md` — Sub-agent definition for Ansible expertise
  - `agents/git-expert.md` — Sub-agent definition for Git expertise

### `golang/`
- **Purpose:** Go development platform layer. Adds Go toolchain, language server, and protobuf tooling on top of a base variant image.
- **Contains:** Single Dockerfile
- **Key files:**
  - `Dockerfile` — Installs Go 1.26.2, gopls, buf, protobuf compiler

### `ansible/`
- **Purpose:** Ansible infrastructure automation platform layer. Adds Ansible runtime, linter, and Mitogen parallel execution on top of a base variant image.
- **Contains:** Single Dockerfile
- **Key files:**
  - `Dockerfile` — Installs ansible, ansible-lint, mitogen, pylibssh, netaddr

### `.planning/codebase/`
- **Purpose:** Stores architecture and structure analysis documents consumed by GSD (Get Shit Done) command pipeline.
- **Contains:** Markdown documentation files
- **Key files:**
  - `ARCHITECTURE.md` — This file
  - `STRUCTURE.md` — This file
  - `STACK.md` — Technology stack analysis (existing)
  - `INTEGRATIONS.md` — External integration audit (existing)

### Root-level files
- **Purpose:** Build orchestration and dependency management
- **Key files:**
  - `Makefile` — Target graph for building and cleaning all Docker images
  - `package.json` — Declares `get-shit-done` SDK dependency
  - `bun.lock` — Bun lockfile for deterministic dependency resolution

## Key File Locations

### Entry Points

**Build Entry:**
- `Makefile`: Defines all Docker image build targets and their dependency graph. Entry commands: `make all`, `make base`, `make golang-opencode`, `make ansible-qwencode`, `make clean`

**Runtime Entry:**
- `base/opencode.Dockerfile` (line 21): `CMD ["opencode"]` — launches the OpenCode agent CLI
- `base/qwencode.Dockerfile` (line 3): installs qwencode runtime — entry point is the image's CMD from parent

**Agent Config Entry:**
- `base/.opencode/opencode.json`: Main configuration for the OpenCode agent runtime — providers, plugins, agent roles, LSP servers, MCP tools

### Configuration

**Docker Build Config:**
- `base/Dockerfile`: Base image setup — user creation, package installation, proxy config, persistent shell hook
- `golang/Dockerfile`: Go toolchain and language server installation
- `ansible/Dockerfile`: Ansible Python package installation

**Agent Runtime Config:**
- `base/.opencode/opencode.json`: Plugins, LSP, provider models, agent tools, MCP servers
- `base/agents/ansible-expert.md`: Ansible expert agent prompt and instructions
- `base/agents/git-expert.md`: Git expert agent prompt and instructions (includes Conventional Commits spec)

**Dependency Config:**
- `package.json`: Single dependency on `get-shit-done` SDK
- `bun.lock`: Lockfile for deterministic bun installs

### Core Logic

**Build Orchestration:**
- `Makefile`: Image build graph, tag management, cleanup, and Docker prune operations

**Agent Configuration:**
- `base/.opencode/opencode.json`: Defines the AI agent runtime configuration including:
  - Provider `qwen-mbp` with local LLM endpoint
  - Model definitions: `qwen-next` (262K context), `qwen-3.6` (1M context)
  - 5 plugins installed globally
  - 3 agent roles: `build` (primary), `ansible-expert` (subagent), `git-expert` (subagent with nested `gsd-executor` and `gsd-planner`)
  - 2 LSP servers: `ansible` (ansible-language-server), `golang` (gopls)
  - 1 MCP server: `context7` (remote)

## Naming Conventions

**Files:**
- Dockerfiles: `Dockerfile` (standard), `*-Dockerfile` for variants (e.g., `opencode.Dockerfile`, `qwencode.Dockerfile`)
- Agent definitions: `*-expert.md` (e.g., `ansible-expert.md`, `git-expert.md`)
- Config files: `*.json` (opencode.json), `Makefile` (no extension)
- Lockfiles: `bun.lock` (Bun package manager)
- Planning docs: UPPERCASE.md (e.g., `ARCHITECTURE.md`, `STRUCTURE.md`)

**Directories:**
- Lowercase, kebab-case not used; directory names are single words: `base/`, `golang/`, `ansible/`, `agents/`, `.opencode/`, `.planning/`

## Where to Add New Code

**New Platform Image (e.g., Rust, Python):**
- Create new directory: `rust/` or `python/`
- Add `Dockerfile` that extends a variant image via `ARG IMAGE=`
- Add Makefile target (e.g., `rust-opencode`, `rust-qwencode`)
- Add to `all` target and `.PHONY` declaration

**New Agent Role:**
- Add markdown file to `base/agents/` (e.g., `base/agents/docker-expert.md`)
- Add agent config entry in `base/.opencode/opencode.json` under `agent.*`
- Set `mode` to `subagent` or `primary`
- Define tool permissions

**New Plugin:**
- Add to `plugin` array in `base/.opencode/opencode.json`
- Add `RUN opencode plugin <name>` line in `base/opencode.Dockerfile`

**Build Target:**
- Add to `Makefile` `.PHONY` declaration
- Define target with dependency chain
- Follow naming convention: `{platform}-{variant}` (e.g., `golang-opencode`)

**New Configuration:**
- Update `base/.opencode/opencode.json` for agent/runtime config
- Update provider models for new LLM endpoints
- Update LSP config for new language servers

## Special Directories

### `base/.opencode/`
- **Purpose:** OpenCode agent configuration directory. Copied into container at `/home/agent/.config/opencode/`
- **Generated:** No — committed as source
- **Committed:** Yes

### `base/agents/`
- **Purpose:** Sub-agent role definition files. Copied into container at `/home/agent/.config/opencode/agents/`
- **Generated:** No — committed as source
- **Committed:** Yes

### `golang/` and `ansible/`
- **Purpose:** Platform-specific Docker image layers. Each contains a single Dockerfile.
- **Generated:** No — committed as source
- **Committed:** Yes

### `.planning/codebase/`
- **Purpose:** GSD codebase analysis documents consumed by `/gsd-plan-phase` and `/gsd-execute-phase`
- **Generated:** Yes — produced by codebase analysis commands
- **Committed:** Yes

### `node_modules/`
- **Purpose:** NPM/Bun dependency cache
- **Generated:** Yes — created by `bun install` / `npm install`
- **Committed:** No — listed in `.gitignore`

---

*Structure analysis: 2026-04-20*
