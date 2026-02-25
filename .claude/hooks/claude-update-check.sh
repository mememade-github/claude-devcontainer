#!/bin/bash
# Claude Code auto-update check (daily, non-blocking)
# Called from session-start.sh. Caches result for 24 hours.

CACHE_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/.update-check-cache"
CURRENT=$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")

if [ "$CURRENT" = "unknown" ]; then
  echo "Claude Code: not found"
  exit 0
fi

# Check cache (avoid network call if checked within 24h)
if [ -f "$CACHE_FILE" ]; then
  CACHE_AGE=$(( $(date +%s) - $(stat -c%Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if [ "$CACHE_AGE" -lt 86400 ]; then
    CACHED=$(cat "$CACHE_FILE" 2>/dev/null)
    if [ -n "$CACHED" ]; then
      echo "$CACHED"
    fi
    exit 0
  fi
fi

# Background update check (non-blocking)
(
  LATEST=$(npm view @anthropic-ai/claude-code version 2>/dev/null || echo "")
  if [ -n "$LATEST" ] && [ "$CURRENT" != "$LATEST" ]; then
    echo "UPDATE_AVAILABLE: Claude Code $CURRENT → $LATEST (run: claude update)" > "$CACHE_FILE"
  else
    echo "" > "$CACHE_FILE"
  fi
) &

echo "Claude Code: v$CURRENT"
