#!/bin/bash
# PreToolUse hook (matcher: Bash): Enforce pre-commit verification gate
# Intercepts `git commit` commands and blocks unless verification was run recently.
#
# Flow:
#   git commit detected → check .claude/.last-verification timestamp
#   → within 10 min → ALLOW
#   → missing or stale → DENY with instruction to run verification
#
# Marker file: $CLAUDE_PROJECT_DIR/.claude/.last-verification

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Only intercept git commit commands (not git add, git status, etc.)
if ! echo "$COMMAND" | grep -qE '\bgit\s+commit\b'; then
  exit 0
fi

# Allow --amend with --no-edit (minor fixups)
# Block all other commits without verification
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Resolve actual project root (worktree → original repo root)
if command -v git &>/dev/null; then
  GIT_COMMON=$(git -C "$PROJECT_DIR" rev-parse --git-common-dir 2>/dev/null)
  if [ -n "$GIT_COMMON" ] && [ "$GIT_COMMON" != ".git" ]; then
    ACTUAL_ROOT=$(dirname "$GIT_COMMON")
  else
    ACTUAL_ROOT="$PROJECT_DIR"
  fi
else
  ACTUAL_ROOT="$PROJECT_DIR"
fi

MARKER="$ACTUAL_ROOT/.claude/.last-verification"
MAX_AGE=600  # 10 minutes

if [ ! -f "$MARKER" ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Pre-commit verification required. Run verification first:\n1. Python: ruff check src/ && mypy src/ --ignore-missing-imports\n2. TypeScript: pnpm build\n3. Or run: your project verification script (see CLAUDE.md §3)\nAfter verification passes, the commit will be allowed."
    }
  }'
  exit 0
fi

# Check if marker is recent enough
MARKER_AGE=$(( $(date +%s) - $(stat -c %Y "$MARKER" 2>/dev/null || echo 0) ))

if [ "$MARKER_AGE" -gt "$MAX_AGE" ]; then
  jq -n --arg age "${MARKER_AGE}s ago" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("Verification is stale (" + $age + "). Run verification again before committing:\n1. Python: ruff check src/ && mypy src/ --ignore-missing-imports\n2. TypeScript: pnpm build\n3. Or run: your project verification script (see CLAUDE.md §3)")
    }
  }'
  exit 0
fi

# Verification is recent — allow commit
exit 0
