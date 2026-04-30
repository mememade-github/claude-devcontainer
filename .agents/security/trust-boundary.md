# Trust Boundary

> Phase 0 of the Anthropic-enterprise + karpathy-skills aligned security framework.
> Anchored in Karpathy R1.1 Think Before Coding — every assumption made about
> trust scope is surfaced explicitly here, not left implicit.

## Reference baseline — karpathy-skills

The reference repo (`forrestchang/andrej-karpathy-skills`) ships:

```
.claude-plugin/plugin.json   # name, description, version, author, license, keywords, skills[]
skills/karpathy-guidelines/SKILL.md   # name, description in frontmatter; pure prompt text
```

Risk dimensions (Anthropic enterprise §위험 등급):
- code execution: **0**  (no `*.py`, `*.sh`, `*.js`)
- command manipulation: **0**
- MCP references: **0**
- network access: **0**  (no `http`, `curl`, `fetch`, `requests`)
- hardcoded credentials: **0**
- file system scope: bounded to skill directory
- tool invocations: **0**  (no Bash / Edit / Agent calls)

Our system has higher capability than baseline by design. This document
records each component's deviation and its justification, per Karpathy R1.1.

---

## Components — 12 entities

### Agents (2)

#### 1. `agents/evaluator.md`
- **Role**: Context-isolated evaluation specialist. 1-pass review after code changes; scores against frozen Contract within `/refine`.
- **Trust scope (read)**: workspace files referenced by the caller's request.
- **Trust scope (write)**: evaluation report (path supplied by caller).
- **Tool scope**: `Read, Write, Edit, Bash, Grep, Glob, WebSearch, WebFetch`
- **Invocation**: invoked by `/refine` skill loop and by ROOT after code edits (CLAUDE.md §5.6). Does not invoke other agents.
- **Karpathy-baseline delta**: code execution + network present. Justification: must run tests/builds to score; may consult external docs to validate cross-references.

#### 2. `agents/wip-manager.md`
- **Role**: Manage WIP for multi-session tasks. Auto-invoked when tasks span sessions.
- **Trust scope (read)**: `wip/`, project files referenced by user request.
- **Trust scope (write)**: `wip/task-*/README.md`, `wip/task-*/`.
- **Tool scope**: `Read, Write, Edit, Bash, Grep, Glob, WebSearch, WebFetch`
- **Invocation**: ROOT invokes per CLAUDE.md §5.5. Does not invoke other agents.
- **Karpathy-baseline delta**: identical scope to evaluator. Justification: WIP auto-resume needs branch/file inventory; documentation tasks may consult external references.

### Hooks (6)

#### 3. `hooks/session-start.sh`
- **Role**: SessionStart hook. Injects project context + WIP auto-resume + env check.
- **Trust scope (read)**: `.git/`, `wip/`, `MEMORY.md`, branch state.
- **Trust scope (write)**: stdout JSON only (no filesystem writes).
- **Tool scope**: shell built-ins + `git`, `jq`. No network.
- **Invocation**: triggered automatically by Claude Code at session start.
- **Karpathy-baseline delta**: code execution present. Justification: read-only context aggregation; no decision authority.

#### 4. `hooks/meta-evolution-guard.sh`
- **Role**: PreToolUse hook (Bash matcher). Blocks direct `docker exec ... claude ... -p` so all Meta-Evolution delegation goes through `scripts/meta/delegate-goal.sh`.
- **Trust scope (read)**: hook input JSON.
- **Trust scope (write)**: stderr only.
- **Tool scope**: shell built-ins + `jq`. No network.
- **Invocation**: triggered for every Bash tool use.
- **Karpathy-baseline delta**: code execution present. Justification: enforcement-only, no productive side effects.

#### 5. `hooks/sub-project-edit-guard.sh`
- **Role**: PreToolUse hook (Edit/Write matcher). Blocks Edit/Write inside §6-bearing sub-projects per Role Relativity.
- **Trust scope (read)**: hook input JSON, target CLAUDE.md.
- **Trust scope (write)**: stderr only.
- **Tool scope**: shell built-ins + `jq`, `grep`. No network.
- **Invocation**: triggered for every Edit/Write tool use.
- **Karpathy-baseline delta**: same as meta-evolution-guard. Same justification.

#### 6. `hooks/pre-commit-gate.sh`
- **Role**: PreToolUse hook (Bash matcher, `git commit*`). Blocks commits unless completion-checker recently ran on the branch.
- **Trust scope (read)**: `.claude/.last-verification.<branch>`, hook input JSON.
- **Trust scope (write)**: stderr only.
- **Tool scope**: shell built-ins. No network.
- **Invocation**: triggered for `git commit` Bash calls.
- **Karpathy-baseline delta**: same as meta-evolution-guard. Same justification.

#### 7. `hooks/pre-push-gate.sh`
- **Role**: PreToolUse hook (Bash matcher, `git push*`). 3-layer progressive hardening — Layer 1 blocks PAT residue in remote URL; Layer 2 warns on remote URL drift; Layer 3 (opt-in) blocks `.push-remote` declaration mismatch.
- **Trust scope (read)**: `git remote -v` output, hook input JSON, optional `.push-remote` file.
- **Trust scope (write)**: stderr only.
- **Tool scope**: shell built-ins + `git`, `grep`. No network.
- **Invocation**: triggered for `git push` Bash calls.
- **Karpathy-baseline delta**: same as meta-evolution-guard. Same justification. Note: Layer 1 already covers credential-residue at push time — additional runtime credential-mask hook would duplicate this control (Karpathy R1.3 surgical avoidance).

#### 8. `hooks/refinement-gate.sh`
- **Role**: Stop hook. Prevents session stop during active `/refine` iteration when score < threshold.
- **Trust scope (read)**: `.refinement-active` marker, score files.
- **Trust scope (write)**: stdout JSON decision only.
- **Tool scope**: shell built-ins + `jq`. No network.
- **Invocation**: triggered at every Stop event.
- **Karpathy-baseline delta**: same as meta-evolution-guard. Same justification.

### Skills (4)

#### 9. `skills/refine/SKILL.md`
- **Role**: Autonomous exploratory improvement loop — thin orchestrator with fresh-context agents.
- **Trust scope (read)**: project source per task scope.
- **Trust scope (write)**: project source per task scope; `.refinement-active`, `.refine-output`, `attempts/*.jsonl`.
- **Tool scope**: `Bash, Read, Write, Edit, Grep, Glob, Agent`
- **Invocation**: user-invocable via `/refine`.
- **Karpathy-baseline delta**: code execution + Agent recursion (highest autonomy). Justification: by-design exploratory loop; recursion is the loop mechanism, not a side channel.

#### 10. `skills/wiki/SKILL.md`
- **Role**: LLM Wiki — build and maintain structured knowledge bases with cross-referencing, consolidation, contradiction detection.
- **Trust scope (read)**: wiki source dirs.
- **Trust scope (write)**: wiki output dirs.
- **Tool scope**: `Bash, Read, Write, Edit, Grep, Glob, Agent`
- **Invocation**: user-invocable via `/wiki`.
- **Karpathy-baseline delta**: same as `/refine`. Justification: ingestion + contradiction detection requires multi-file traversal + sub-agent dispatch.

#### 11. `skills/status/SKILL.md`
- **Role**: Show workspace status — all git repos, services, WIP tasks, environment health.
- **Trust scope (read)**: workspace, `.git/` dirs, service ports.
- **Trust scope (write)**: stdout only.
- **Tool scope**: `Bash, Read, Glob, Grep`
- **Invocation**: user-invocable via `/status`.
- **Karpathy-baseline delta**: code execution present, **no Write/Edit/Agent**. Closest to baseline.

#### 12. `skills/verify/SKILL.md`
- **Role**: Run pre-commit verification checks on a product.
- **Trust scope (read)**: target product source.
- **Trust scope (write)**: marker file `.last-verification.<branch>`.
- **Tool scope**: `Bash, Read`
- **Invocation**: user-invocable via `/verify`.
- **Karpathy-baseline delta**: narrowest of all skills. Code execution present (must run tests). Closest to baseline along with `/status`.

### Wiring — `settings.json`

`settings.json` declares the hook bindings. It is the trust-boundary integration point — every PreToolUse / Stop / SessionStart hook listed above is registered there. Hooks not listed in `settings.json` do not fire even if present in `hooks/`.

| Trigger | Matcher | Hook |
|---------|---------|------|
| SessionStart | — | session-start.sh |
| PreToolUse | Bash + `git commit*` | pre-commit-gate.sh |
| PreToolUse | Bash + `git push*` | pre-push-gate.sh |
| PreToolUse | Bash | meta-evolution-guard.sh |
| PreToolUse | Edit \| Write | sub-project-edit-guard.sh |
| Stop | — | refinement-gate.sh |

---

## Verification — end-state for Phase 0

This document is correct iff:

1. Every file under `.claude/agents/`, `.claude/hooks/`, `.claude/skills/` has a section here.
2. Every section has all five fields: Role / Trust scope (read) / Trust scope (write) / Tool scope / Invocation / Karpathy-baseline delta.
3. Every hook listed in `settings.json` is present here.

Check command:

```bash
# Component count match (expect: 2 + 6 + 4 = 12)
expected=$(( $(ls /workspaces/.claude/agents/*.md 2>/dev/null | wc -l) \
          + $(ls /workspaces/.claude/hooks/*.sh 2>/dev/null | wc -l) \
          + $(ls -d /workspaces/.claude/skills/*/ 2>/dev/null | wc -l) ))
documented=$(grep -cE '^#### [0-9]+\.' /workspaces/.claude/security/trust-boundary.md)
[ "$expected" -eq "$documented" ] && echo "OK ($documented)" || echo "MISMATCH (expected=$expected, documented=$documented)"
```

---

*Created: 2026-04-28. Phase 0 of Alt B (karpathy-skills aligned).*
