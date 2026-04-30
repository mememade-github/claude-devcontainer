#!/bin/bash
# Role Relativity — Edit/Write guard for §6-bearing sub-projects.
#
# ROOT Agent acts as Human for sub-projects that carry their own Meta-Evolution.
# Human role cannot modify sub-project files directly — only deliver STATE +
# GOAL via scripts/meta/delegate-goal.sh. This hook blocks Edit/Write tool
# calls targeting any file under a registered sub-project root.
#
# Self-disabling: if the current project has no §6 in CLAUDE.md, this is not
# a Meta-Evolution ROOT layer, so the hook exits 0 (no blocking). This lets
# the hook be portable via .claude/ sync without accidental effect downstream.
#
# Extend SUB_PROJECTS below when a new §6-bearing sub-project is added.
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

case "$TOOL_NAME" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

[ -z "$FILE_PATH" ] && exit 0

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-/workspaces}"
CLAUDE_MD="${PROJECT_ROOT}/CLAUDE.md"
if [ ! -f "$CLAUDE_MD" ] || ! grep -qE '^#+[[:space:]]*6\.?[[:space:]]*Meta-Evolution' "$CLAUDE_MD"; then
  exit 0
fi

case "$FILE_PATH" in
  /*) ;;
  *)  FILE_PATH="${PROJECT_ROOT}/$FILE_PATH" ;;
esac

# Register absolute paths of §6-bearing sub-projects below.
# This template ships empty; each consuming workspace adds its own entries.
SUB_PROJECTS=()

for sp in "${SUB_PROJECTS[@]}"; do
  case "$FILE_PATH" in
    "$sp"/*)
      cat >&2 <<EOF
Blocked: $TOOL_NAME on file inside §6-bearing sub-project.

Target:            $FILE_PATH
Sub-project root:  $sp

Per Role Relativity (ARCHITECTURE.md), the current project's ROOT Agent acts
as Human for this sub-project. Do not edit its files directly — deliver
STATE + GOAL to its ROOT Agent via the wrapper.

Delegation:
  scripts/meta/delegate-goal.sh $(basename "$sp") "<GOAL>"
EOF
      exit 2
      ;;
  esac
done

exit 0
