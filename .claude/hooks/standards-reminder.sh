#!/bin/bash
# PostToolUse hook (matcher: Edit|Write): Remind agent to consult standards when modifying .claude/ files.
# Context-injection hook (non-blocking). Uses jq for JSON I/O.
#
# Source: Anthropic Best Practices — "Address root causes, not symptoms"
# Reference: https://code.claude.com/docs/en/hooks (PostToolUse, hookSpecificOutput)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
RELATIVE_PATH=$(echo "$FILE_PATH" | sed "s|^$PROJECT_DIR/||")

# Only activate for .claude/ subtree and CLAUDE.md
case "$RELATIVE_PATH" in
  .claude/agents/*) STANDARD="agent-definition.md" ;;
  .claude/hooks/*) STANDARD="hooks-and-lifecycle.md" ;;
  .claude/settings.json) STANDARD="hooks-and-lifecycle.md, governance.md" ;;
  .claude/rules/*) STANDARD="knowledge-management.md, governance.md" ;;
  .claude/skills/*) STANDARD="knowledge-management.md" ;;
  .claude/instincts/*) STANDARD="evolution-and-learning.md" ;;
  CLAUDE.md) STANDARD="governance.md, knowledge-management.md" ;;
  *) exit 0 ;;
esac

jq -n --arg file "$RELATIVE_PATH" --arg std "$STANDARD" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: (".claude/ system file modified: " + $file + ". Consult standard before further changes: .claude/rules/standards/" + $std + ". Verify: Source section has external references, compliance checks pass.")
  }
}'
