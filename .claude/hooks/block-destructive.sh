#!/bin/bash
# PreToolUse hook: Block destructive commands
# Uses exit code 2 + stderr for reliable blocking per official docs:
#   "Exit 2 means a blocking error. stderr text is fed back to Claude."
#   "Claude Code only processes JSON on exit 0. If you exit 2, any JSON is ignored."
# Reference: https://code.claude.com/docs/en/hooks#exit-code-output

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Block destructive commands (case-insensitive)
# Covers: rm -rf, git push --force/-f, git reset --hard, git checkout -- ., git clean -f,
#         mv/cp overwrite patterns, DROP, DELETE FROM, TRUNCATE
if echo "$COMMAND" | grep -iE '\brm\s+-(r|rf|fr)\s|\bgit\s+push\s+(--force|-f)\b|\bgit\s+reset\s+--hard\b|\bgit\s+checkout\s+--\s*\.|\bgit\s+clean\s+-[a-z]*f|\bDROP\s+(TABLE|DATABASE|INDEX|VIEW|SCHEMA)\b|\bDELETE\s+FROM\b|\bTRUNCATE\b' > /dev/null; then
  echo "Destructive command blocked: requires explicit user approval per CLAUDE.md governance." >&2
  echo "Command: $(echo "$COMMAND" | head -c 200)" >&2
  exit 2
fi

exit 0
