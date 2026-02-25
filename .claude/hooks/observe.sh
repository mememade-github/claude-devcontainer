#!/bin/bash
# Instinct observation hook — records tool calls to observations.jsonl
# Called by PreToolUse/PostToolUse hooks. MUST complete in < 2 seconds.
# Part of continuous-learning-v2 (instinct-based learning system).

DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/instincts"
FILE="$DIR/observations.jsonl"

# Ensure directory exists (fast no-op after first call)
[ -d "$DIR" ] || mkdir -p "$DIR/personal" "$DIR/inherited" "$DIR/archive"

PHASE="${1:-unknown}"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Read tool info from stdin (Claude Code hook JSON)
# Use timeout to prevent hanging, read only first 1000 chars for speed
INPUT=$(head -c 1000 2>/dev/null || echo "{}")

# Extract tool name with sed (no python/jq dependency for speed)
TOOL=$(echo "$INPUT" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -z "$TOOL" ] && TOOL="unknown"

# Append observation (atomic write)
printf '{"ts":"%s","phase":"%s","tool":"%s"}\n' "$TS" "$PHASE" "$TOOL" >> "$FILE" 2>/dev/null

# Rotate at 10MB to prevent unbounded growth
if [ -f "$FILE" ]; then
  SIZE=$(stat -c%s "$FILE" 2>/dev/null || stat -f%z "$FILE" 2>/dev/null || echo 0)
  if [ "$SIZE" -gt 10485760 ]; then
    mv "$FILE" "$DIR/archive/observations.$(date +%Y%m%d%H%M%S).jsonl" 2>/dev/null
  fi
fi
