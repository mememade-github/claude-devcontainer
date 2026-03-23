#!/bin/bash
# task-quality-gate.sh — Quality gate for completed agent team tasks
# Event: TaskCompleted
# Purpose: Verify task completion meets quality standards before accepting

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# read JSON from stdin
INPUT=$(cat)

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# log task completion
# Honest fallback: jq unavailable or parse failure → empty JSON (P-6)
TASK_INFO=$(echo "$INPUT" | jq -r '.tool_input // "{}"' 2>/dev/null || echo "{}")
if ! printf '{"ts":"%s","event":"task_completed","info":"%s"}\n' \
  "$TIMESTAMP" "$(echo "$TASK_INFO" | head -c 200)" \
  >> "$PROJECT_DIR/.claude/task-completions.log"; then
  echo "WARN: task completion log write failed: $PROJECT_DIR/.claude/task-completions.log" >&2
fi

# non-blocking: inject quality reminder
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "TaskCompleted",
    "additionalContext": "Task completed. Verify: (1) output meets acceptance criteria, (2) no regressions introduced, (3) changes are consistent with project standards."
  }
}
EOF
