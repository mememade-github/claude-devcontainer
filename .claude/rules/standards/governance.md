# Governance Standard

## Source
- Official: Claude Code constitutional governance model (2026)
- Official: Claude Code Best Practices — "Address root causes, not symptoms" (https://code.claude.com/docs/en/best-practices)
- Derived: CLAUDE.md governance principles
- Last verified: 2026-02-26

## Standard

### Constitutional Model

Three tiers of governance with different mutability:

| Tier | Content | Mutability | Changed By |
|------|---------|------------|------------|
| Immutable | Core principles | Never | Human only |
| Mutable | Agent definitions, rules, skills | Controlled | agent-evolver (with constraints) |
| Learned | Instincts | Automatic | Observation + confidence gates |

### Immutable Principles

These MUST NOT be modified by any automated process:

1. **INTEGRITY**: Every claim verified by execution before statement
2. **Destructive ops approval**: `rm -rf`, `git push --force`, `git reset --hard`, `DROP/DELETE` require human approval
3. **No secrets**: Never commit credentials or API keys
4. **Read first**: Read existing code before modifying
5. **Verify**: Build and test before claiming success
6. **Fix root causes**: Diagnose and fix root causes on error. No workarounds or silent bypass
7. **Explicit failure**: No form of arbitrary success is permitted. Every operation must genuinely succeed or explicitly fail. Prerequisite for #6 — errors must be visible before root causes can be fixed

### Mutable Artifacts (agent-evolver scope)

| Artifact | Location | Constraints |
|----------|----------|-------------|
| Agent definitions | `.claude/agents/*.md` | Must follow agent-definition standard |
| Rules | `.claude/rules/*.md` | Must be portable, single-topic |
| Skills | `.claude/skills/*/SKILL.md` | Must have required frontmatter |
| Agent memory | `.claude/agent-memory/*/MEMORY.md` | Per-agent only |

### Evolution Constraints

agent-evolver MUST:
- Never remove working rules without justification
- Never modify `settings.json` (flag for manual update)
- Apply minimal, targeted changes only
- Maintain backward compatibility
- Document reasoning for every change
- Not hardcode project-specific values in portable artifacts

### Prohibited Modifications

| Target | Reason |
|--------|--------|
| `settings.json` | Hooks registration — manual only |
| `CLAUDE.md` core principles | Constitutional immutability |
| Other agent's active memory | Agents own their memory |
| Production deployment files | Requires human approval |

### Audit and Accountability

- All evolution changes logged in agent-evolver MEMORY.md
- Evolution Report generated after each evolution cycle
- `/audit` skill available for standards compliance checking
- Self-audit capability: agent-evolver can audit itself

## Compliance Checks

- [ ] CLAUDE.md immutable principles are unchanged
- [ ] agent-evolver has not modified settings.json
- [ ] All evolved artifacts have documented reasoning
- [ ] No project-specific content in portable rules
- [ ] Evolution changes are logged in agent-evolver MEMORY.md
- [ ] Destructive operations are not automated without gates

## References

- `/workspaces/CLAUDE.md` (constitutional document)
- `.claude/agents/agent-evolver.md` (evolution agent constraints)
- `.claude/rules/standards/evolution-and-learning.md` (evolution pipeline)
- `.claude/rules/standards/explicit-failure.md` (operationalization of Principle #7)
