# Testing Patterns

**Analysis Date:** 2026-04-20

## Test Framework

**No application-level test framework is present.** This repository contains no test files (no `*.test.*`, `*.spec.*`, or test directories). It is a Docker-based sandbox environment with no application source code — only infrastructure definitions (Dockerfiles, Makefile, agent prompts, and configuration files).

Testing is instead delegated to **tooling installed within the container images**, which agents can use to validate code quality:

| Tool | Purpose | Installed In |
|------|---------|-------------|
| `ansible-lint` | Lint Ansible playbooks and roles | `ansible/Dockerfile` |
| `pyright` | Python type checking | `base/Dockerfile` |
| `gopls` | Go language server (includes vet/staticcheck) | `golang/Dockerfile` |

## Test File Organization

**No test files exist in the repository.** All testing is performed by agents inside the containerized sandbox environment using the tools listed above.

## Test Structure

N/A — no test infrastructure exists in this repository. Testing is performed by AI agents at runtime using the tools installed in the Docker images.

## Mocking

N/A — no test framework, no mocks.

## Fixtures and Factories

N/A — no test data infrastructure.

## Coverage

**No coverage requirements are defined.** There are no tests, so no coverage metrics are tracked or enforced.

## Test Types

### Infrastructure Validation (by tooling)

**Ansible Linting:**
- Tool: `ansible-lint` (installed in `ansible/Dockerfile`)
- Purpose: Validate Ansible playbooks and roles against best practices
- Usage: Agents run `ansible-lint` on Ansible files to catch style and correctness issues
- Per agent instructions: `base/agents/ansible-expert.md` line 37 — "Use `ansible-lint` to validate playbook quality"

**Python Type Checking:**
- Tool: `pyright` (installed in `base/Dockerfile` line 116)
- Purpose: Static type checking for Python code
- Usage: Agents run `pyright` on Python files to catch type errors

**Go Language Server:**
- Tool: `gopls` (installed in `golang/Dockerfile` line 14)
- Purpose: Go language analysis including staticcheck, govet, and diagnostics
- Usage: LSP integration via `base/.opencode/opencode.json` lines 22-28

### Docker Build Validation

**Build-time verification:**
- `docker build` itself acts as a test — failed builds indicate broken Dockerfiles
- `docker buildx prune` and `docker image prune -f` (Makefile lines 48-49) serve as cleanup/verification targets
- `Makefile` target `clean` validates that known images exist before removal (`Makefile` lines 42-45)

## Common Patterns

### Agent-Driven Testing

The project relies on **AI agents** to perform testing indirectly:

1. **Ansible Expert** (`base/agents/ansible-expert.md`) runs `ansible-lint` and validates:
   - Idempotency issues
   - Missing error handling
   - Variable scope/precedence
   - Security concerns
   - Performance issues
   - Linting violations and YAML formatting

2. **Git Expert** (`base/agents/git-expert.md`) enforces:
   - Conventional Commits format (`base/agents/git-expert.md` lines 33-46)
   - Atomic commits with clear messages
   - Branch protection practices

### Container Health Checks

**Docker Compose / Build Validation:**
- `Makefile` provides `all` target that builds all sandbox variants (`Makefile` line 12)
- `make clean` verifies all known images exist before removal (`Makefile` lines 41-45)
- `make pull` validates upstream base images (`Makefile` lines 14-16)

## Security Testing

**Built-in security practices:**
- Non-root user (`agent`, UID 1000) in all runtime containers (`base/Dockerfile` lines 41, 122)
- Sudoers configured with `NOPASSWD` for `agent` user (`base/Dockerfile` line 49)
- Proxy environment variables preserved through sudoers (`base/Dockerfile` line 50)
- Docker socket mounted via group (`usermod -aG docker agent` — `base/Dockerfile` line 44)

## Linting Configuration

**No linting config files are present in the repository.** Linting is configured through:

1. **OpenCode LSP config** (`base/.opencode/opencode.json` lines 10-29):
   - `ansible` LSP: `ansible-language-server --stdio` for `.yaml`, `.yml` files
   - `golang` LSP: `gopls serve` for `.go` files

2. **Agent instructions** (`base/agents/ansible-expert.md`, `base/agents/git-expert.md`):
   - Conventions enforced through prompt instructions rather than tooling configs

## CI/CD

**No CI/CD pipeline is defined in the repository.** Build orchestration is handled via `Makefile`:

```bash
make all              # Build all sandbox variants
make base             # Build base images only
make opencode         # Build OpenCode images
make qwencode         # Build Qwen Code images
make clean            # Remove all built images
make prune            # Prune Docker build cache
make pull             # Pull upstream base images
```

Image registry: `ghcr.io/red55/sandbox` (configured in `Makefile` line 1-2)

---

*Testing analysis: 2026-04-20*
