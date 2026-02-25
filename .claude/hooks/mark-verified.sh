#!/bin/bash
# Utility: Create verification timestamp marker.
# Called after pre-commit verification passes (ruff, mypy, pnpm build, etc.)
#
# Usage: .claude/hooks/mark-verified.sh
# Creates .last-verification marker that pre-commit-gate.sh checks.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
MARKER="$PROJECT_DIR/.claude/.last-verification"

touch "$MARKER"
echo "Verification marker created at $(date). Commits allowed for 10 minutes."
