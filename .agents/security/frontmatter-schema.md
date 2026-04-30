# Frontmatter Schema

> Phase 2. Anchored in Karpathy R1.3 Surgical Changes — the existing
> frontmatters are self-consistent; this document records the schema rather
> than refactoring it. New additions must conform.

## Why a schema doc, not edits

karpathy-skills' baseline frontmatter is minimal (`name`, `description` for
the SKILL.md; `name`, `description`, `version`, `author`, `license`,
`keywords`, `skills` at the package level). Auditing our current frontmatters
shows they are already consistent and minimal-by-purpose:

| Group | Field set | Count |
|-------|-----------|-------|
| agents (2) | name, description, tools, model, maxTurns, color | 6 keys, identical across files |
| skills (4) | name, description, user-invocable, allowed-tools, [argument-hint] | 4 keys + 1 conditional |

No structural drift. No missing fields. No speculative fields. Karpathy
R1.3 holds: nothing to refactor.

## Skill schema (`.claude/skills/<name>/SKILL.md`)

```yaml
---
name: <slug>                            # required, kebab-case
description: <single-line>              # required, 1 sentence describing trigger conditions
user-invocable: true | false            # required, true if reachable via /<name>
allowed-tools: <comma-separated list>   # required, every tool the skill may invoke
argument-hint: "<usage-string>"         # required iff skill accepts arguments
---
```

Governance metadata (version / owner / last-reviewed / risk-level) lives in
`registry.md` (Phase 4), not in the SKILL.md. This separates operational
config (what the skill needs to run) from governance config (who owns it,
when it was reviewed). karpathy-skills follows the same split — operational
fields in SKILL.md, package-level fields in `.claude-plugin/plugin.json`.

## Agent schema (`.claude/agents/<name>.md`)

```yaml
---
name: <slug>                                          # required
description: <single-line>                            # required
tools: ["<Tool1>", "<Tool2>", ...]                    # required, JSON array
model: opus | sonnet | haiku                          # required
maxTurns: <int>                                       # required
color: <name>                                         # required (UI hint)
---
```

Same split as skills — governance metadata is in `registry.md`.

## Field rules

1. **`name`** must equal the file basename (skill: dir name; agent: `<name>.md`).
2. **`description`** must answer "when does this fire" in one sentence. No marketing copy. No examples.
3. **`tools` / `allowed-tools`**: list the tools actually used by the body.
   Reserved-but-unused entries should be marked `declared` in
   `risk-registry.md` row A4 / A7, not silently included.
4. **No new optional fields without an entry in this schema.** A field that
   appears in one frontmatter but not its peers is drift — fix it in the
   registry, not by sprinkling fields.
5. **No nested objects in frontmatter.** Flat key-value only. karpathy-skills
   keeps this; we keep this.

## Verification — end-state for Phase 2

```bash
# All agents share the agent schema field set:
agent_keys() { awk '/^---$/{c++; next} c==1 && /^[a-z]/{sub(/:.*/,""); print}' "$1" | sort; }
ref=$(agent_keys /workspaces/.claude/agents/evaluator.md)
all_agents_match=true
for f in /workspaces/.claude/agents/*.md; do
  [ "$(agent_keys "$f")" = "$ref" ] || { all_agents_match=false; echo "DRIFT: $f"; }
done
$all_agents_match && echo "agents OK" || echo "agents FAIL"

# All skills share the skill schema's required keys (argument-hint is optional):
for d in /workspaces/.claude/skills/*/; do
  for k in allowed-tools description name user-invocable; do
    grep -q "^${k}:" "${d}SKILL.md" || { echo "MISSING $k in $d"; exit 1; }
  done
done
echo "skills OK"
```

## When to update this schema

Update this document whenever a new required field is introduced (e.g. if
Anthropic's enterprise checklist adds a new mandatory field). Do not add
fields ad-hoc to individual frontmatters — Karpathy R1.2 Simplicity First.

---

*Created: 2026-04-28. Phase 2 of Alt B (karpathy-skills aligned).*
