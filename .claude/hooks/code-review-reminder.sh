#!/bin/bash
# PostToolUse hook (matcher: Edit|Write): Track file modifications in products/
# When files under products/ are modified, creates a pending-review marker
# and injects a reminder into Claude's context.
#
# Marker file: $CLAUDE_PROJECT_DIR/.claude/.pending-review
# Cleared by: review-complete.sh (called after code-reviewer agent finishes)

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Only track changes in products/ directory (relative to project root)
RELATIVE_PATH=$(echo "$FILE_PATH" | sed "s|^$PROJECT_DIR/||")
if ! echo "$RELATIVE_PATH" | grep -q '^products/'; then
  exit 0
fi

MARKER="$PROJECT_DIR/.claude/.pending-review"
if [ -f "$MARKER" ]; then
  if ! grep -qF "$RELATIVE_PATH" "$MARKER"; then
    echo "$RELATIVE_PATH" >> "$MARKER"
  fi
else
  echo "$RELATIVE_PATH" > "$MARKER"
fi

FILE_COUNT=$(wc -l < "$MARKER")

jq -n --arg count "$FILE_COUNT" --arg file "$RELATIVE_PATH" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ("products/ file modified: " + $file + " (" + $count + " file(s) pending review). Per CLAUDE.md §2: delegate to code-reviewer agent before committing. After review, mark complete to clear the pending-review marker.")
  }
}'
