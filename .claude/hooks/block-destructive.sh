#!/bin/bash
# PreToolUse hook: Block destructive commands
# Returns JSON with permissionDecision for proper Claude Code integration

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Block destructive commands (case-insensitive)
if echo "$COMMAND" | grep -iE '\brm\s+-rf\s+/|\bgit\s+push\s+--force\b|\bgit\s+reset\s+--hard\b|\bDROP\s+|\bDELETE\s+FROM\b|\bTRUNCATE\b' > /dev/null; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Destructive command blocked. Requires explicit user approval per CLAUDE.md governance."
    }
  }'
else
  exit 0
fi
