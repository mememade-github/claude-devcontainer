# DevContainer Development Patterns

> **CRITICAL**: This rule prevents incorrect DevContainer usage patterns like Docker-in-Docker (DinD)
> and defines the **external Docker testing protocol** for CI-safe container validation.

## Core Principle: DevContainers Run on Host

DevContainers are **NOT** designed to be started from inside another container.

### CORRECT Approach
```
Host Machine (Windows/Mac/Linux)
    │
    └── VS Code (or CLI: `devcontainer open`)
            │
            └── Opens DevContainer via Docker Desktop
                    │
                    └── Workspace mounted from HOST filesystem
```

### INCORRECT Approach (DinD - AVOID)
```
Host Machine
    │
    └── Container A (e.g., existing DevContainer)
            │
            └── Attempt to start Container B (e.g., another DevContainer)
                    │
                    └── ❌ Workspace mount fails (no access to HOST paths)
```

## External Docker Testing (docker.sock)

From inside a DevContainer, you can use the **host Docker daemon** to build/test other images.
This is NOT DinD — commands are sent directly to the host Docker daemon via the mounted socket.

### How It Works
```
Host Machine
    │
    ├── Docker Desktop (daemon)
    │       ▲
    │       │ docker.sock
    │       ▼
    └── DevContainer A (currently running)
            │
            └── docker compose build   ← Host Docker daemon performs the build
                docker images           ← Lists host images
                docker inspect          ← Inspects image metadata
```

### Prerequisites
- `docker-compose.yml` must mount `/var/run/docker.sock:/var/run/docker.sock`
- Container user must belong to `docker` group (configured in Dockerfile)

### Allowed Operations (External Docker)

| Operation | Command | Safety |
|-----------|---------|--------|
| Build image | `docker compose build` | OK |
| List images | `docker images` | OK |
| Inspect image | `docker inspect <image>` | OK |
| Remove image | `docker rmi <image>` | Caution (host images) |
| Run container | `docker compose up -d` | Limited (mount path issues) |

### Not Possible

| Operation | Reason |
|-----------|--------|
| Open DevContainer | Requires VS Code + HOST filesystem |
| Test volume mounts | Cannot reference HOST paths |
| Run postCreateCommand | Requires VS Code lifecycle |

## DevContainer Testing Protocol

### Phase 1: External Docker Build Verification (inside container)

```bash
# 1. Build image
cd /path/to/.devcontainer
docker compose build --no-cache 2>&1

# 2. Verify build result
docker images | grep <image-name>

# 3. Inspect image layers
docker inspect <image-name>:latest --format '{{.Config.User}}'
docker inspect <image-name>:latest --format '{{range .Config.Env}}{{println .}}{{end}}'
```

### Phase 2: Configuration File Validation (inside container)

| Item | Method |
|------|--------|
| settings.json | `jq . < .claude/settings.json` (JSON validity) |
| devcontainer.json | JSONC parsing (comments allowed) |
| docker-compose.yml | `docker compose config` (YAML validity) |
| Dockerfile | `docker compose build` success |
| hooks/*.sh | `bash -n <file>` (syntax check) + shebang verification |
| agents/*.md | YAML frontmatter parsing (name, tools fields) |
| skills/*/SKILL.md | Required fields exist |
| .env / .env.example | Variable consistency |

### Phase 3: Functional Tests (inside container)

```bash
# Run hook test suite
bash .claude/hooks/test-hooks.sh

# Individual hook syntax check
for f in .claude/hooks/*.sh; do bash -n "$f" && echo "OK: $f" || echo "FAIL: $f"; done
```

### Phase 4: HOST Integration Test (HOST VS Code only)

| Step | Action | Location |
|------|--------|----------|
| 1 | "Reopen in Container" | HOST VS Code |
| 2 | Verify postCreateCommand | DevContainer terminal |
| 3 | Check `/workspaces/` mount | DevContainer terminal |
| 4 | Verify VS Code extensions | HOST VS Code |
| 5 | Verify `claude` CLI works | DevContainer terminal |

## Verification Checklist

### Inside Container (Phase 1-3)

- [ ] `docker compose build` succeeds
- [ ] Image exists in `docker images`
- [ ] `settings.json` is valid JSON
- [ ] All hooks `.sh` have no syntax errors
- [ ] `test-hooks.sh` all PASS
- [ ] All agents `.md` have YAML frontmatter
- [ ] All skills have `SKILL.md`
- [ ] `.env.example` has PORT_* variables

### From HOST (Phase 4)

- [ ] "Reopen in Container" succeeds
- [ ] `/workspaces/` contains project files
- [ ] `postCreateCommand` executed successfully
- [ ] VS Code extensions loaded
- [ ] `claude` CLI works

## Why DinD Fails for DevContainers

1. **Mount paths**: DevContainer mounts reference HOST filesystem paths
2. **docker.sock**: Shared socket doesn't translate container paths
3. **VS Code integration**: Requires HOST VS Code Remote - Containers extension

## Detection Patterns

If you observe these symptoms, DinD is likely the cause:

| Symptom | Cause |
|---------|-------|
| Empty `/workspaces/` | Mount path doesn't exist in nested container |
| Missing VS Code extensions | VS Code not properly connected |
| "Cannot find workspace" | Path resolution failure |
| Container starts but "doesn't work" | Context mismatch |

## Agent Guidance

When asked to test a DevContainer:

1. **Run Phase 1-3 first**: External Docker build + config validation + hook tests
2. **Report results**: Record PASS/FAIL for each verification item
3. **Delegate Phase 4**: HOST integration test must be performed by user

### Phase 4 Handoff Template

> "Phase 1-3 verification complete. HOST integration test required.
>
> **From HOST VS Code:**
> 1. Open the project folder
> 2. Run 'Reopen in Container'
> 3. Verify `claude --version` in terminal
> 4. Verify MCP servers (`claude` then `/mcp`)"

## References

- [Microsoft Dev Containers Specification](https://containers.dev/)
- [VS Code Dev Containers Extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- [Dev Container CLI](https://github.com/devcontainers/cli)
