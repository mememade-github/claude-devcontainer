#!/bin/bash
# PreToolUse hook (matcher: Bash): block direct Meta-Evolution agent launches.
# Any `docker exec ... claude ... -p ...` must go through scripts/meta/delegate-goal.sh.
# Reference: CLAUDE.md §6 Pre-action gate + Wrapper enforcement;
#            ARCHITECTURE.md §Role Relativity.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[ -z "$COMMAND" ] && exit 0

# Only inspect commands whose first executable token is docker (or sudo docker).
# Other commands (git, cat, echo, heredoc writers, etc.) may contain this text
# inside quoted arguments and must not false-positive.
FIRST=$(printf '%s\n' "$COMMAND" | sed 's/^[[:space:]]*//' | awk '{print $1}')
if [ "$FIRST" = "sudo" ]; then
  FIRST=$(printf '%s\n' "$COMMAND" | sed 's/^[[:space:]]*//' | awk '{print $2}')
fi
if [ "$FIRST" != "docker" ] && [ "$FIRST" != "podman" ]; then
  exit 0
fi

# Command starts with docker/podman. Block if it is an exec launching `claude -p`.
if echo "$COMMAND" | grep -qE '^[[:space:]]*(sudo[[:space:]]+)?(docker|podman)[[:space:]]+exec[[:space:]].*\bclaude\b.*[[:space:]]-p\b'; then
  cat >&2 <<'MSG'
BLOCKED: direct Meta-Evolution agent launch via `docker exec ... claude -p`.

Role Relativity requires the wrapper:

  scripts/meta/delegate-goal.sh <project-key> "<GOAL>"

The wrapper enforces:
  - GOAL-not-METHOD validation (rejects slash commands / imperative verbs)
  - Correct working directory (project ROOT, not sub-sub-project paths)
  - Auto-injected declaration header (role / layer / boundaries)
  - Launch audit log under .claude/.delegate-log/

If the wrapper lacks a needed project, extend its PROJECTS map — do not bypass.
Reference: ARCHITECTURE.md §Role Relativity, CLAUDE.md §6.
MSG
  exit 2
fi

exit 0
