# Collaboration Protocol -- Multi-Worker Git Strategy

> Two or more workers (human or Claude sessions) working on the same repository.
> Details: `.claude/docs/hook-reference.md` ## Collaboration Details

## Fundamental Rules

1. **Never commit directly to `main`** -- all work on worker branches.
2. **One worker per worktree** -- never run two sessions in the same worktree.
3. **Check before editing** -- verify no other active session is working on the same files.

## Session Detection (Automatic)

- `worker-guard.sh` uses `git worktree list` + per-worktree `.claude/.heartbeat` mtime
- Active if `.heartbeat` modified within last 10 minutes
- `heartbeat.sh` touches `.heartbeat` on every PreToolUse/PostToolUse
- No registration/deregistration needed -- no stale files on crash

**Key distinction**: `.heartbeat` is per-worktree at `PROJECT_DIR` (isolated).

## Worker Lifecycle

### 1. Start: Create Worktree + Branch

```bash
WORKER_NAME="alpha"
git worktree add .claude/worktrees/${WORKER_NAME} -b worktree-${WORKER_NAME}
```

### 2. Sync: Rebase onto Main

```bash
git fetch origin main
git rebase origin/main
```

### 3. Finish: Merge + Cleanup

```bash
git rebase main
git checkout main
git merge --ff-only worktree-${WORKER_NAME}
git worktree remove .claude/worktrees/${WORKER_NAME}
git branch -d worktree-${WORKER_NAME}
```

## Worker Naming Convention

| Worker | Name | Branch |
|--------|------|--------|
| Human (primary) | `alpha` | `worktree-alpha` |
| Claude Code session 1 | `bravo` | `worktree-bravo` |
| Claude Code session 2 | `charlie` | `worktree-charlie` |

## Applicability

This protocol applies to **every project** with `.claude/` configuration.
