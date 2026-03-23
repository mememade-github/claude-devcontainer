#!/bin/bash
# post-compact.sh — Restore context awareness after compaction
# Event: PostCompact
# Purpose: Re-inject critical context that may have been lost during compaction

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# read JSON from stdin
INPUT=$(cat)

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# log post-compaction event
if ! printf '{"ts":"%s","event":"post_compact"}\n' \
  "$TIMESTAMP" \
  >> "$PROJECT_DIR/.claude/compaction.log"; then
  echo "WARN: compaction log write failed: $PROJECT_DIR/.claude/compaction.log" >&2
fi

# check for active WIP
WIP_SUMMARY=""
if [ -d "$PROJECT_DIR/wip" ]; then
  # Optional: wip subdirectories may not exist (P-5)
  WIP_COUNT=$(find "$PROJECT_DIR/wip" -maxdepth 1 -type d 2>/dev/null | tail -n +2 | wc -l)
  if [ "$WIP_COUNT" -gt 0 ]; then
    WIP_SUMMARY="Active WIP tasks: $WIP_COUNT. Resume with wip-manager agent."
  fi
fi

# check for pending review
REVIEW_NOTE=""
if [ -f "$PROJECT_DIR/.claude/.pending-review" ]; then
  REVIEW_NOTE="Pending code review exists. Delegate to code-reviewer before committing."
fi

# Note: PostCompact does not support hookSpecificOutput JSON.
# Recovery context is logged above; WIP/review state is checked by session-start.sh.
exit 0
