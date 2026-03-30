#!/bin/bash
# Test all hooks without triggering PreToolUse interception
# Run: bash .claude/hooks/test-hooks.sh

set -e
PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
export CLAUDE_PROJECT_DIR="$PROJECT_DIR"

# resolve ACTUAL_ROOT (mirrors hook logic — markers live at main repo root)
if command -v git &>/dev/null; then
  _GIT_COMMON=$(git -C "$PROJECT_DIR" rev-parse --git-common-dir 2>/dev/null)
  if [ -n "$_GIT_COMMON" ] && [ "$_GIT_COMMON" != ".git" ]; then
    ACTUAL_ROOT=$(dirname "$_GIT_COMMON")
  else
    ACTUAL_ROOT="$PROJECT_DIR"
  fi
else
  ACTUAL_ROOT="$PROJECT_DIR"
fi

# resolve branch name for per-worktree marker assertions
BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
BRANCH_SAFE=$(echo "$BRANCH" | tr '/' '-')

echo "=== Hook Test Suite (branch: $BRANCH, root: $ACTUAL_ROOT) ==="
echo ""

# --- Test 1: Pre-commit gate (no marker) ---
echo -n "1. Pre-commit gate (no marker): "
rm -f "$ACTUAL_ROOT/.claude/.last-verification.$BRANCH_SAFE"
EXIT_CODE=0
RESULT=$(echo '{"tool_input":{"command":"git commit -m test"}}' | bash "$PROJECT_DIR/.claude/hooks/pre-commit-gate.sh" 2>&1) || EXIT_CODE=$?
if [ $EXIT_CODE -eq 2 ] && echo "$RESULT" | grep -q "verification required"; then
  echo "PASS (denied, exit=2)"
  PASS=$((PASS + 1))
else
  echo "FAIL (expected exit 2 + stderr, got exit=$EXIT_CODE, output: $RESULT)"
  FAIL=$((FAIL + 1))
fi

# --- Test 2: Pre-commit gate (with fresh marker) ---
echo -n "2. Pre-commit gate (fresh marker): "
touch "$ACTUAL_ROOT/.claude/.last-verification.$BRANCH_SAFE"
RESULT=$(echo '{"tool_input":{"command":"git commit -m test"}}' | bash "$PROJECT_DIR/.claude/hooks/pre-commit-gate.sh" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ] && [ -z "$RESULT" ]; then
  echo "PASS (allowed)"
  PASS=$((PASS + 1))
else
  echo "FAIL (expected allow, got exit=$EXIT_CODE, output=$RESULT)"
  FAIL=$((FAIL + 1))
fi

# --- Test 3: Pre-commit gate (non-commit command) ---
echo -n "3. Pre-commit gate (npm install): "
RESULT=$(echo '{"tool_input":{"command":"npm install"}}' | bash "$PROJECT_DIR/.claude/hooks/pre-commit-gate.sh" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ] && [ -z "$RESULT" ]; then
  echo "PASS (ignored)"
  PASS=$((PASS + 1))
else
  echo "FAIL (expected ignore)"
  FAIL=$((FAIL + 1))
fi

# --- Test 4: Block destructive (rm -rf) ---
echo -n "4. Block destructive (rm -rf /): "
EXIT_CODE=0
RESULT=$(echo '{"tool_input":{"command":"rm -rf /"}}' | bash "$PROJECT_DIR/.claude/hooks/block-destructive.sh" 2>&1) || EXIT_CODE=$?
if [ $EXIT_CODE -eq 2 ] && echo "$RESULT" | grep -qi "destructive\|blocked\|rm -rf"; then
  echo "PASS (denied)"
  PASS=$((PASS + 1))
else
  echo "FAIL"
  FAIL=$((FAIL + 1))
fi

# --- Test 5: SessionStart Known Issues parsing ---
echo -n "5. SessionStart Known Issues: "
RESULT=$(echo '{"source":"startup"}' | bash "$PROJECT_DIR/.claude/hooks/session-start.sh" 2>&1)
PROJECT_KEY=$(echo "$PROJECT_DIR" | tr "/" "-" | sed "s/^-//")
AUTO_MEMORY_FILE="${HOME}/.claude/projects/${PROJECT_KEY}/memory/MEMORY.md"
# Optional: MEMORY.md may not have ISSUE- entries (P-5)
HAS_ISSUES=$(grep -l "ISSUE-" "$AUTO_MEMORY_FILE" 2>/dev/null | head -1)
if [ -n "$HAS_ISSUES" ]; then
  if echo "$RESULT" | grep -q "ISSUE-"; then
    echo "PASS (Known Issues found in output)"
    PASS=$((PASS + 1))
  else
    echo "FAIL (MEMORY.md has ISSUE- but session-start didn't report)"
    FAIL=$((FAIL + 1))
  fi
else
  echo "PASS (no Known Issues — expected for base template)"
  PASS=$((PASS + 1))
fi

# --- Test 6: mark-verified.sh ---
echo -n "6. mark-verified.sh: "
rm -f "$ACTUAL_ROOT/.claude/.last-verification.$BRANCH_SAFE"
bash "$PROJECT_DIR/.claude/hooks/mark-verified.sh" > /dev/null
if [ -f "$ACTUAL_ROOT/.claude/.last-verification.$BRANCH_SAFE" ]; then
  echo "PASS (marker created)"
  PASS=$((PASS + 1))
else
  echo "FAIL"
  FAIL=$((FAIL + 1))
fi

# --- Test 7: Refinement gate (no marker → allow) ---
echo -n "7. Refinement gate (no marker): "
rm -f "$ACTUAL_ROOT/.claude/.refinement-active"
RESULT=$(echo '{}' | bash "$PROJECT_DIR/.claude/hooks/refinement-gate.sh" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ] && [ -z "$RESULT" ]; then
  echo "PASS (allowed)"
  PASS=$((PASS + 1))
else
  echo "FAIL (expected allow, got exit=$EXIT_CODE)"
  FAIL=$((FAIL + 1))
fi

# --- Test 8: Refinement gate (active → block) ---
echo -n "8. Refinement gate (active, below threshold): "
rm -f "$ACTUAL_ROOT/.claude/.stop-blocked-refinement.$BRANCH_SAFE"
REFINE_MARKER="$ACTUAL_ROOT/.claude/.refinement-active"
echo '{"task_id":"test-gate","threshold":0.9,"max_iterations":5}' > "$REFINE_MARKER"
mkdir -p "$ACTUAL_ROOT/.claude/agent-memory/refinement/attempts"
echo '{"score":0.3,"result":"Baseline","feedback":"initial"}' > "$ACTUAL_ROOT/.claude/agent-memory/refinement/attempts/test-gate.jsonl"

RESULT=$(echo '{}' | bash "$PROJECT_DIR/.claude/hooks/refinement-gate.sh" 2>&1)
if echo "$RESULT" | grep -q '"decision".*"block"'; then
  echo "PASS (blocked)"
  PASS=$((PASS + 1))
else
  echo "FAIL (expected block, got: $RESULT)"
  FAIL=$((FAIL + 1))
fi

# Restore
rm -f "$ACTUAL_ROOT/.claude/agent-memory/refinement/attempts/test-gate.jsonl"
rm -f "$REFINE_MARKER"
rm -f "$ACTUAL_ROOT/.claude/.stop-blocked-refinement.$BRANCH_SAFE"

# --- Cleanup ---
touch "$ACTUAL_ROOT/.claude/.last-verification.$BRANCH_SAFE"

echo ""
TOTAL=$((PASS + FAIL))
echo "TOTAL: $TOTAL  PASS: $PASS  FAIL: $FAIL  SKIP: 0"
[ $FAIL -eq 0 ] && exit 0 || exit 1
