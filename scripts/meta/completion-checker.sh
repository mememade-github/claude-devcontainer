#!/bin/bash
# completion-checker.sh — Polyagent template pre-commit verification.
#
# Single-project template version. Delegates to verify-template.sh for
# the heavy template integrity checks, then writes the per-branch marker
# that pre-commit-gate.sh reads to allow git commit.
#
# For the multi-project ROOT version (which iterates products/* and
# performs cross-repo checks), see the consuming workspace's own
# scripts/meta/completion-checker.sh.
set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
VERIFY="$PROJECT_DIR/.devcontainer/verify-template.sh"

if [ ! -x "$VERIFY" ] && [ ! -f "$VERIFY" ]; then
    echo "ERROR: $VERIFY not found." >&2
    echo "Polyagent template completion-checker requires .devcontainer/verify-template.sh." >&2
    exit 2
fi

PROJECT_DIR="$PROJECT_DIR" bash "$VERIFY"
RC=$?

# Marker write — pre-commit-gate.sh reads .claude/.last-verification.<branch>.
if [ "$RC" -eq 0 ]; then
    BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    BRANCH_SAFE=$(echo "$BRANCH" | tr '/' '-')
    mkdir -p "$PROJECT_DIR/.claude"
    touch "$PROJECT_DIR/.claude/.last-verification.$BRANCH_SAFE"
fi

exit $RC
