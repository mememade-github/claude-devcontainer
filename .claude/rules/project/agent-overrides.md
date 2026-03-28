# Agent System — Project Overrides

> Project-specific agent policies. Compliance verified by `.claude/tests/test-agents.sh`.

## Model Policy

All agents in this workspace use the top-tier model:

```yaml
model: opus    # ALL agents — no exceptions
```

Rationale: consistency and maximum capability across all agent operations.

## Tool Access Policy

All agents have full tool access. Behavioral boundaries are enforced at the prompt level, not by tool restriction. This aligns with the autoresearch principle: maximize agent capability, control via measurement.

```yaml
tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "WebSearch", "WebFetch"]
```

Each agent's prompt defines a **Behavioral Boundary** section specifying its operational scope (e.g., "you REVIEW and REPORT — you do not fix code"). This preserves full diagnostic capability while establishing clear role expectations.

**Exception — agent-evolver**: May modify rules/ and skills/ directly, but agents/*.md changes must be proposed (not applied) to prevent self-referential modification loops.

## Effort Policy

Global `effortLevel: high` in `settings.json`. Per-agent `effort` field not used.

## Team Structure

| Team | Agents | Auto-trigger |
|------|--------|-------------|
| quality | code-reviewer, security-reviewer, database-reviewer, environment-checker, agent-evolver | After code changes; on env issues; before session end |
| build | build-error-resolver, tdd-guide, refactor-cleaner | On build failure; on new feature; on maintenance |
| testing | e2e-runner, tdd-guide | On feature completion; on regression check |
| docs | doc-updater | On system changes (agents, services, scripts) |
| workflow | wip-manager | When tasks span sessions |

## Frontmatter Reference

**Required fields** (all agents):

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | kebab-case, must match filename |
| `description` | string | One-line purpose statement |
| `tools` | array | `["Read", "Write", "Edit", "Bash", "Grep", "Glob", "WebSearch", "WebFetch"]` |
| `model` | string | `opus` (this workspace) |

**Common optional fields**:

| Field | Type | Description |
|-------|------|-------------|
| `maxTurns` | int | Safety/cost gate (8-20) |
| `memory` | string | `project` — only for agents needing cross-session state |
| `isolation` | string | `worktree` — run in temporary git worktree |
| `background` | bool | Always run as background task |
| `mcpServers` | array | MCP servers available to subagent |
| `skills` | array | Skills available to agent |
| `hooks` | object | Lifecycle hooks scoped to subagent |
| `color` | string | Display color in CLI |

> Verified by: `bash .claude/tests/test-agents.sh`

## Agent Inventory (14)

All agents: `model: opus`, full tools, `maxTurns` 8-20.

| Agent | maxTurns | Boundary | Skills | Color | MCP | Extra | Purpose |
|-------|----------|----------|--------|-------|-----|-------|---------|
| agent-evolver | 15 | — | verify, audit | magenta | — | background, memory | Session analysis, agent/rule/skill evolution |
| architect | 20 | analyze/recommend | — | cyan | serena | — | Architecture patterns and design review |
| build-error-resolver | 15 | — | verify, build-fix | red | — | — | Fix build/type errors with minimal diffs |
| code-reviewer | 15 | review/report | verify | green | serena | hooks | Code review with severity framework |
| database-reviewer | 15 | audit/recommend | — | blue | serena | hooks | PostgreSQL optimization, schema design |
| debugger | 15 | diagnose/delegate | — | yellow | serena | — | Root cause analysis for runtime errors |
| doc-updater | 15 | docs only | — | cyan | context7 | background | Documentation and codemap specialist |
| e2e-runner | 15 | — | verify | green | — | isolation | E2E testing (curl, Playwright) |
| environment-checker | 10 | diagnose/env-fix | status | yellow | — | background | Workspace health verification |
| planner | 20 | plan/document | — | cyan | serena, context7 | — | Implementation planning specialist |
| refactor-cleaner | 15 | — | verify | magenta | — | isolation | Dead code cleanup and consolidation |
| security-reviewer | 15 | detect/report | verify | red | serena | — | Security vulnerability detection (OWASP) |
| tdd-guide | 20 | — | verify | green | serena | isolation | TDD: RED→GREEN→REFACTOR cycle |
| wip-manager | 8 | wip/ dir only | status | blue | — | memory | Multi-session task tracking |
