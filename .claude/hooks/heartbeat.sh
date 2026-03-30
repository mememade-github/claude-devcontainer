#!/bin/bash
# Per-worktree heartbeat for session detection (worker-guard.sh reads this).
# Called by PreToolUse/PostToolUse hooks. MUST complete in < 1 second.

_HEARTBEAT="${CLAUDE_PROJECT_DIR:-.}/.claude/.heartbeat"
# Intentional: heartbeat must never block session — silent failure is correct (HK-11, HK-12 exempt)
touch "$_HEARTBEAT" 2>/dev/null || true
