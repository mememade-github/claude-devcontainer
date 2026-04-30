#!/bin/bash
# PreToolUse hook: enforce pre-commit verification gate for Codex harness

set -u

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // .toolInput.command // .command // .input.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

if ! echo "$COMMAND" | grep -qE '\bgit\s+commit\b'; then
  exit 0
fi

PROJECT_DIR="${CODEX_PROJECT_DIR:-.}"
ACTUAL_ROOT=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$PROJECT_DIR")
BRANCH=$(git -C "$ACTUAL_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
BRANCH_SAFE=$(echo "$BRANCH" | tr '/' '-')
STATE_DIR="$ACTUAL_ROOT/.codex/state"
MARKER="$STATE_DIR/last-verification.$BRANCH_SAFE"
CHECKER="$ACTUAL_ROOT/scripts/meta/completion-checker.sh"
MAX_AGE=600

mkdir -p "$STATE_DIR"

NEEDS_VERIFICATION=0
if [ ! -f "$MARKER" ]; then
  NEEDS_VERIFICATION=1
else
  MARKER_MTIME=$(stat -c %Y "$MARKER" 2>/dev/null) || NEEDS_VERIFICATION=1
  if [ "$NEEDS_VERIFICATION" -eq 0 ]; then
    MARKER_AGE=$(( $(date +%s) - MARKER_MTIME ))
    [ "$MARKER_AGE" -gt "$MAX_AGE" ] && NEEDS_VERIFICATION=1
  fi
fi

if [ "$NEEDS_VERIFICATION" -eq 1 ]; then
  if [ -x "$CHECKER" ]; then
    bash "$CHECKER" >&2
    VERIFY_EXIT=$?
    if [ "$VERIFY_EXIT" -eq 0 ]; then
      exit 0
    fi
    echo "Auto-verification failed (exit $VERIFY_EXIT). Fix issues before committing." >&2
    exit 2
  fi

  echo "Verification helper missing: $CHECKER" >&2
  exit 2
fi

SCORER="$ACTUAL_ROOT/.refine/score.sh"
REFINE_MARKER="$STATE_DIR/refinement-active"
if [ -f "$SCORER" ] && [ ! -f "$REFINE_MARKER" ]; then
  STAGED_COUNT=$(git -C "$ACTUAL_ROOT" diff --cached --name-only | wc -l | tr -d ' ')
  if [ "$STAGED_COUNT" -ge 2 ]; then
    echo "WARNING: $STAGED_COUNT files staged but refine loop marker is not active." >&2
    echo "AGENTS.md recommends refine for meaningful multi-file changes when scorer exists." >&2
  fi
fi

exit 0
