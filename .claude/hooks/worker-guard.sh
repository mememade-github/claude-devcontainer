#!/bin/bash
# worker-guard.sh — Detect other active workers at session start
# Called by session-start.sh to inject worker awareness into context.
# Outputs plain text (not JSON) — caller wraps into additionalContext.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Resolve actual project root (handle worktree)
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

PROJECT_KEY=$(echo "$ACTUAL_ROOT" | md5sum | cut -c1-12)
WORKER_DIR="$HOME/.claude/workers/${PROJECT_KEY}"

# No workers directory — nothing to report
[ -d "$WORKER_DIR" ] || exit 0

# Current branch
CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

# Detect current worker name from branch
CURRENT_WORKER=""
if [[ "$CURRENT_BRANCH" == worktree-* ]]; then
  CURRENT_WORKER="${CURRENT_BRANCH#worktree-}"
fi

# Collect other active workers
OUTPUT=""
WORKER_COUNT=0
SAME_WORKTREE_CONFLICT=false

CURRENT_WORKTREE=$(cd "$PROJECT_DIR" && pwd -P)

for f in "$WORKER_DIR"/worker-*.json; do
  [ -f "$f" ] || continue

  NAME=$(jq -r '.name // "unknown"' "$f" 2>/dev/null)
  BRANCH=$(jq -r '.branch // "unknown"' "$f" 2>/dev/null)
  WORKING_ON=$(jq -r '.working_on // ""' "$f" 2>/dev/null)
  FILES=$(jq -r '.files // [] | join(", ")' "$f" 2>/dev/null)
  STARTED=$(jq -r '.started // ""' "$f" 2>/dev/null)

  # Skip self
  [ "$NAME" = "$CURRENT_WORKER" ] && continue

  # Check if worker's worktree still exists
  WT_PATH=$(jq -r '.worktree // ""' "$f" 2>/dev/null)
  if [ -n "$WT_PATH" ] && [ ! -d "$WT_PATH" ]; then
    # Stale worker — worktree removed but not deregistered
    rm -f "$f"
    continue
  fi

  # Detect same-worktree conflict (critical)
  if [ -n "$WT_PATH" ]; then
    OTHER_WT=$(cd "$WT_PATH" 2>/dev/null && pwd -P)
    if [ "$OTHER_WT" = "$CURRENT_WORKTREE" ]; then
      SAME_WORKTREE_CONFLICT=true
      OUTPUT="${OUTPUT}  - ${NAME} (${BRANCH}) *** SAME WORKTREE ***"
      [ -n "$WORKING_ON" ] && OUTPUT="${OUTPUT}: ${WORKING_ON}"
      OUTPUT="${OUTPUT}\n"
      WORKER_COUNT=$((WORKER_COUNT + 1))
      continue
    fi
  fi

  WORKER_COUNT=$((WORKER_COUNT + 1))
  OUTPUT="${OUTPUT}  - ${NAME} (${BRANCH})"
  [ -n "$WORKING_ON" ] && OUTPUT="${OUTPUT}: ${WORKING_ON}"
  [ -n "$FILES" ] && OUTPUT="${OUTPUT} [files: ${FILES}]"
  OUTPUT="${OUTPUT}\n"
done

# Critical: same-worktree conflict
if [ "$SAME_WORKTREE_CONFLICT" = true ]; then
  echo "CRITICAL: Another worker is active in THIS worktree (${CURRENT_WORKTREE})."
  echo "Two sessions in one worktree cause file edit races and staging conflicts."
  echo "ACTION_REQUIRED: Create a separate worktree for this session, or wait for the other worker to finish."
  echo ""
fi

# Output if other workers found
if [ "$WORKER_COUNT" -gt 0 ]; then
  echo -e "Active workers in this project (${WORKER_COUNT}):"
  echo -e "$OUTPUT"
  echo "COLLABORATION: Per collaboration-protocol.md, check file ownership before editing shared files."
fi

# Check if current branch diverges from main
if [ "$CURRENT_BRANCH" != "main" ]; then
  BEHIND=$(git -C "$PROJECT_DIR" rev-list --count HEAD..main 2>/dev/null || echo "?")
  if [ "$BEHIND" != "0" ] && [ "$BEHIND" != "?" ]; then
    echo "SYNC_NEEDED: Current branch is ${BEHIND} commits behind main. Consider: git rebase main"
  fi
fi
