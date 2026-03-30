# Hook & Lifecycle Reference

> Reference -- not auto-loaded into context. Read explicitly when needed.

---

## Hook JSON Protocol

**Input** (all events receive via stdin):
```json
{
  "session_id": "abc-123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/workspaces",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Edit",
  "tool_input": {"file_path": "...", "old_string": "...", "new_string": "..."}
}
```

**Exit codes** (command hooks):

| Exit Code | Meaning | Effect |
|-----------|---------|--------|
| 0 | Success/allow | Tool proceeds normally |
| 2 | Block with feedback | Tool blocked, **stderr** shown to agent |
| Any other | Non-blocking error | Logged as warning, tool proceeds |

> Exit code 2 blocks. Stderr (not stdout) is fed back on block.

---

## 9 Hook Scripts

### settings.json Event Mapping (6 direct registrations)

| Event | Matcher | Hook | Timeout | Category |
|-------|---------|------|---------|----------|
| SessionStart | (all) | session-start.sh | 15s | Context injection |
| PreToolUse | Bash | block-destructive.sh | 5s | Gate |
| PreToolUse | Bash | pre-commit-gate.sh | 5s | Gate |
| PreToolUse | Bash | pre-push-gate.sh | 5s | Gate |
| PreToolUse | (all) | heartbeat.sh | 1s | Session detection |
| PostToolUse | (all) | heartbeat.sh | 1s | Session detection |
| Stop | (all) | refinement-gate.sh | 10s | Gate |

### Utility Scripts (2) + Test (1)

| Hook | Called By | Purpose |
|------|----------|---------|
| worker-guard.sh | session-start.sh | Detect other active sessions via worktree heartbeat |
| mark-verified.sh | developer (after verification) | Create verification timestamp marker |
| test-hooks.sh | (test suite) | Automated hook testing |

---

## Hook Categories

### Gate Hooks (4)

| Hook | Event | Blocks When |
|------|-------|-------------|
| block-destructive.sh | PreToolUse (Bash) | `rm -rf`, `git push --force`, `DROP TABLE`, etc. |
| pre-commit-gate.sh | PreToolUse (Bash) | Verification marker stale before `git commit` |
| pre-push-gate.sh | PreToolUse (Bash) | PAT token in remote URL before `git push` |
| refinement-gate.sh | Stop | Active refinement loop in progress |

### Context Hook (1)

| Hook | Event | Action |
|------|-------|--------|
| session-start.sh | SessionStart | Inject git branch, WIP tasks, env status |

### Session Detection (1)

| Hook | Event | Action |
|------|-------|--------|
| heartbeat.sh | PreToolUse + PostToolUse | Touch .heartbeat for worker-guard detection |

---

## Permitted `2>/dev/null` Patterns (P-1 through P-5)

Each usage MUST have an adjacent comment stating intent.

- **P-1**: Capability detection (`command -v`)
- **P-2**: ACTUAL_ROOT resolution (`git rev-parse --git-common-dir`)
- **P-3**: Honest uncertainty fallback (`|| echo "unknown"`)
- **P-4**: Cross-platform compatibility (stat -c/-f chain)
- **P-5**: Optional resource probing (`ls ... 2>/dev/null`)

---

## Collaboration Details

### Session-Start Integration

At session start, `worker-guard` hook automatically:
1. Enumerates all worktrees via `git worktree list`
2. Checks each worktree's `.heartbeat` mtime for activity
3. Reports active sessions (within 10-minute heartbeat window)
4. Warns if current session's worktree branch diverges from main

---

*Last updated: 2026-03-31*
