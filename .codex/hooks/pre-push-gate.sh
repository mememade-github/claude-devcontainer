#!/bin/bash
# PreToolUse hook: git push safety gate for Codex harness

set -u

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // .toolInput.command // .command // .input.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

if ! echo "$COMMAND" | grep -qE '\bgit\s+push\b'; then
  exit 0
fi

PROJECT_DIR="${CODEX_PROJECT_DIR:-.}"
REPO_ROOT=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$PROJECT_DIR")
[ -z "$REPO_ROOT" ] && exit 0

PUSH_REMOTE=$(echo "$COMMAND" | sed -n 's/.*git\s\+push\s\+\(\S\+\).*/\1/p')
[ -z "$PUSH_REMOTE" ] && PUSH_REMOTE="origin"

ACTUAL_URL=$(git -C "$REPO_ROOT" config "remote.${PUSH_REMOTE}.url" 2>/dev/null)
[ -z "$ACTUAL_URL" ] && exit 0

if echo "$ACTUAL_URL" | grep -qE 'github_pat_[A-Za-z0-9_]+@|ghp_[A-Za-z0-9]+@|glpat-[A-Za-z0-9_]+@|ghs_[A-Za-z0-9]+@|oauth2:[^@]+@'; then
  MASKED_URL=$(echo "$ACTUAL_URL" | sed -E 's/(oauth2:|github_pat_|ghp_|glpat-|ghs_)[^@]*@/***@/g')
  echo "Push blocked: credential detected in remote URL." >&2
  echo "  Remote: $PUSH_REMOTE" >&2
  echo "  URL: $MASKED_URL" >&2
  echo "Fix: git remote set-url $PUSH_REMOTE <url-without-credentials>" >&2
  exit 2
fi

STATE_DIR="$REPO_ROOT/.codex/state"
BASELINE_FILE="$STATE_DIR/last-push-url.${PUSH_REMOTE}"
DECL_FILE="$REPO_ROOT/.codex/push-remote"
mkdir -p "$STATE_DIR"

if [ -f "$BASELINE_FILE" ]; then
  BASELINE_URL=$(cat "$BASELINE_FILE" 2>/dev/null)
  if [ -n "$BASELINE_URL" ] && [ "$ACTUAL_URL" != "$BASELINE_URL" ]; then
    echo "Warning: remote '$PUSH_REMOTE' URL changed since last push." >&2
    echo "  Previous: $BASELINE_URL" >&2
    echo "  Current:  $ACTUAL_URL" >&2
    echo "If intentional, baseline will update after this push." >&2
  fi
fi

printf '%s\n' "$ACTUAL_URL" > "$BASELINE_FILE"

if [ -f "$DECL_FILE" ]; then
  EXPECTED=$(grep "^${PUSH_REMOTE}=" "$DECL_FILE" 2>/dev/null | cut -d= -f2-)
  if [ -n "$EXPECTED" ]; then
    CLEAN_URL=$(echo "$ACTUAL_URL" | sed -E 's|https://[^@]+@|https://|')
    if ! echo "$CLEAN_URL" | grep -qF "$EXPECTED"; then
      echo "Push blocked: remote URL doesn't match declaration." >&2
      echo "  Expected: $EXPECTED" >&2
      echo "  Actual:   $CLEAN_URL" >&2
      echo "  Source:   $DECL_FILE" >&2
      exit 2
    fi
  fi
fi

exit 0
