# AGENTS.md — Codex CLI governance (delta of CLAUDE.md)

> Codex CLI mirror of [CLAUDE.md](CLAUDE.md). All behavioral rules, coding rules, automated workflow, destructive-operation gates, and identity live in `CLAUDE.md`. This file documents only the Codex-specific paths and constraints.

Behavioral rules to load on session start (Codex CLI does not support `@import`, so load explicitly with the `Read` tool):

- [.agents/rules/behavioral-core.md](.agents/rules/behavioral-core.md) — Karpathy 4-rule guidance.
- [.agents/rules/devcontainer-patterns.md](.agents/rules/devcontainer-patterns.md) — DevContainer DinD avoidance and volume-mount path translation.

Skill mirror of Karpathy 4-rule: [.agents/skills/karpathy-guidelines/](.agents/skills/karpathy-guidelines/) (`SKILL.md` + `EXAMPLES.md`).

## Codex-specific paths

| Path | Purpose |
|------|---------|
| `.codex/config.toml` | MCP servers, sandbox/approval policy |
| `.codex/hooks.json` | Event hook registrations (SessionStart, PreToolUse, Stop) |
| `.codex/hooks/` | 4 hook shell scripts |
| `.codex/state/` | Runtime markers (gitignored) |
| `.agents/rules/` | Behavioral-rule mirror of `.claude/rules/` |
| `.agents/skills/` | Skill mirror of `.claude/skills/` plus Codex-side conversions of `.claude/agents/*` |
| `.agents/security/` | Trust boundary, registry mirror |

## Skill delegation

Codex CLI does not yet support file-based custom sub-agent declarations, so the responsibilities of Claude's sub-agents are absorbed as skills under `.agents/skills/`:

| Skill | When to invoke |
|-------|----------------|
| refine | Meaningful changes requiring iterative refinement |
| evaluator | After changes (1-pass review); within the `refine` loop |
| wip-manager | When a task spans sessions |
| status | Workspace status snapshot |
| verify | Pre-commit verification |

## Vendor constraints

| Constraint | Workaround |
|------------|------------|
| `Edit`/`Write` not available as PreToolUse matcher | Use `Bash(...)` patterns only |
| No sub-agent isolation | Absorb agents as skills (`.agents/skills/`) |
| `frontmatter.tools` / `model` / `color` ignored | Body is preserved; vendor ignores extras |
| No `@import` in AGENTS.md | Reference files explicitly; AI loads via `Read` |

## Mirror sync

`.claude/` is the ground truth. After editing it:

```bash
bash scripts/sync-agents-mirror.sh         # regenerate .agents/
bash scripts/sync-agents-mirror.sh --dry   # diff only
```

Do not edit `.agents/` by hand.

## Domain context

- [PROJECT.md](PROJECT.md) — domain context (services, infrastructure)
- [REFERENCE.md](REFERENCE.md) — commands, environment variables, ports, troubleshooting

---

*Last updated: 2026-04-30*
