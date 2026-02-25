# Agent Memory

## Key Notes

- Agent threads always have their cwd reset between bash calls; always use absolute file paths.
- In final response, share relevant file names and code snippets with absolute paths only.
- Avoid emojis in all outputs.
- Do not use a colon before tool calls.

## Evolution Thresholds

- Instinct creation requires 3+ observations of the same pattern.
- Confidence scoring: 1-2 obs = 0.3, 3-5 = 0.5, 6-10 = 0.7, 11+ = 0.85
- Domain cluster for evolution: 3+ instincts, avg confidence > 0.5

## Observed Patterns (Pending Instinct — needs more observations)

### Serena MCP Init Sequence (1 obs, 2026-02-25)
- Sequence: `mcp__serena__read_memory` → `mcp__serena__get_current_config` → `mcp__serena__activate_project`
- Seen in: new workspace / session-start context
- Next step: confirm in 2+ more sessions before creating instinct

## Session History Summary

| Date | Total Obs | New Instincts | Changes |
|------|-----------|---------------|---------|
| 2026-02-25 | 25 | 0 | none — new workspace, single-session diagnosis |
