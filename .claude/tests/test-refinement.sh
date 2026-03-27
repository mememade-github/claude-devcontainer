#!/bin/bash
# test-refinement.sh — Refinement loop infrastructure tests (RF-1..RF-8)
# Sprint 1: data layer (memory-ops, score, trajectory)

set -euo pipefail

ROOT="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
SCRIPTS="$ROOT/scripts/refinement"
PASS=0; FAIL=0; SKIP=0

result() {
  local status="$1" id="$2" desc="$3" detail="${4:-}"
  case "$status" in PASS) PASS=$((PASS+1));; FAIL) FAIL=$((FAIL+1));; SKIP) SKIP=$((SKIP+1));; esac
  echo "$status: $id $desc${detail:+ ($detail)}"
}

# --- Temp directory for test isolation ---
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
export CLAUDE_AGENT_MEMORY="$TMPDIR/agent-memory"

# =============================================================================
# RF-1: memory-ops.sh exists + bash -n
# =============================================================================
if [ -f "$SCRIPTS/memory-ops.sh" ]; then
  if bash -n "$SCRIPTS/memory-ops.sh" 2>/dev/null; then
    result PASS RF-1 "memory-ops.sh exists + syntax OK"
  else
    result FAIL RF-1 "memory-ops.sh syntax error"
  fi
else
  result FAIL RF-1 "memory-ops.sh not found"
fi

# =============================================================================
# RF-2: memory-ops.sh CRUD cycle (add→list→best→count→clear)
# =============================================================================
TASK_TEST="test-crud-$$"

# add two entries
ADD1=$(bash "$SCRIPTS/memory-ops.sh" add --task "$TASK_TEST" --agent "tdd-guide" --score 0.3 --result "3 errors" --feedback "lint fail")
ADD2=$(bash "$SCRIPTS/memory-ops.sh" add --task "$TASK_TEST" --agent "tdd-guide" --score 0.7 --result "1 error" --feedback "partial")

# list
LIST=$(bash "$SCRIPTS/memory-ops.sh" list --task "$TASK_TEST")
LIST_COUNT=$(echo "$LIST" | jq 'length')

# best
BEST=$(bash "$SCRIPTS/memory-ops.sh" best --task "$TASK_TEST")
BEST_SCORE=$(echo "$BEST" | jq '.score')

# count
COUNT=$(bash "$SCRIPTS/memory-ops.sh" count --task "$TASK_TEST")

# clear
CLEAR=$(bash "$SCRIPTS/memory-ops.sh" clear --task "$TASK_TEST")
COUNT_AFTER=$(bash "$SCRIPTS/memory-ops.sh" count --task "$TASK_TEST")

if [ "$LIST_COUNT" = "2" ] && [ "$BEST_SCORE" = "0.7" ] && [ "$COUNT" = "2" ] && [ "$COUNT_AFTER" = "0" ]; then
  result PASS RF-2 "CRUD cycle (add×2→list=2→best=0.7→count=2→clear→count=0)"
else
  result FAIL RF-2 "CRUD cycle" "list=$LIST_COUNT best=$BEST_SCORE count=$COUNT after=$COUNT_AFTER"
fi

# =============================================================================
# RF-3: memory-ops.sh task_id injection rejection
# =============================================================================
REJECT_OK=true

# Path traversal
if bash "$SCRIPTS/memory-ops.sh" add --task "../inject" --agent "x" --score 0.5 --result "x" --feedback "x" 2>/dev/null; then
  REJECT_OK=false
fi

# Empty string
if bash "$SCRIPTS/memory-ops.sh" add --task "" --agent "x" --score 0.5 --result "x" --feedback "x" 2>/dev/null; then
  REJECT_OK=false
fi

# Spaces
if bash "$SCRIPTS/memory-ops.sh" add --task "bad id" --agent "x" --score 0.5 --result "x" --feedback "x" 2>/dev/null; then
  REJECT_OK=false
fi

if $REJECT_OK; then
  result PASS RF-3 "task_id injection rejected (../inject, empty, spaces)"
else
  result FAIL RF-3 "task_id injection not rejected"
fi

# =============================================================================
# RF-4: score.sh perfect/lowest/partial input
# =============================================================================
SCORE_PERFECT=$(echo '{"lint_errors":0,"build_ok":true,"test_passed":10,"test_total":10,"mypy_errors":0}' | bash "$SCRIPTS/score.sh" | jq '.score')
SCORE_LOWEST=$(echo '{"lint_errors":100,"build_ok":false,"test_passed":0,"test_total":10,"mypy_errors":100}' | bash "$SCRIPTS/score.sh" | jq '.score')
SCORE_PARTIAL=$(echo '{"lint_errors":2,"build_ok":true,"test_passed":8,"test_total":10,"mypy_errors":5}' | bash "$SCRIPTS/score.sh" | jq '.score')

# Perfect should be 1.0, lowest should be 0.0, partial between 0 and 1
SCORE_OK=true
if ! awk "BEGIN{exit !($SCORE_PERFECT == 1.0)}" 2>/dev/null; then SCORE_OK=false; fi
if ! awk "BEGIN{exit !($SCORE_LOWEST == 0.0)}" 2>/dev/null; then SCORE_OK=false; fi
if ! awk "BEGIN{exit !($SCORE_PARTIAL > 0.0 && $SCORE_PARTIAL < 1.0)}" 2>/dev/null; then SCORE_OK=false; fi

if $SCORE_OK; then
  result PASS RF-4 "score.sh perfect=1.0 lowest=0.0 partial=$SCORE_PARTIAL"
else
  result FAIL RF-4 "score.sh" "perfect=$SCORE_PERFECT lowest=$SCORE_LOWEST partial=$SCORE_PARTIAL"
fi

# =============================================================================
# RF-5: score.sh zero division safety (test_total=0)
# =============================================================================
SCORE_ZERO=$(echo '{"lint_errors":0,"build_ok":true,"test_passed":0,"test_total":0,"mypy_errors":0}' | bash "$SCRIPTS/score.sh")
SCORE_ZERO_VAL=$(echo "$SCORE_ZERO" | jq '.score')
SCORE_ZERO_TEST=$(echo "$SCORE_ZERO" | jq '.breakdown.test')

# test should be null (excluded), score should still be valid number
if [ "$SCORE_ZERO_TEST" = "null" ] && awk "BEGIN{exit !($SCORE_ZERO_VAL > 0)}" 2>/dev/null; then
  result PASS RF-5 "zero division safe (test=null, score=$SCORE_ZERO_VAL)"
else
  result FAIL RF-5 "zero division" "test=$SCORE_ZERO_TEST score=$SCORE_ZERO_VAL"
fi

# =============================================================================
# RF-6: trajectory.sh worst-first sort
# =============================================================================
TASK_TRAJ="test-traj-$$"

bash "$SCRIPTS/memory-ops.sh" add --task "$TASK_TRAJ" --agent "ber" --score 0.8 --result "good" --feedback "almost" >/dev/null
bash "$SCRIPTS/memory-ops.sh" add --task "$TASK_TRAJ" --agent "ber" --score 0.2 --result "bad" --feedback "many errors" >/dev/null
bash "$SCRIPTS/memory-ops.sh" add --task "$TASK_TRAJ" --agent "ber" --score 0.5 --result "ok" --feedback "some errors" >/dev/null

TRAJ_XML=$(bash "$SCRIPTS/trajectory.sh" --task "$TASK_TRAJ")

# Extract scores in order from <attempt> tags only — should be 0.2, 0.5, 0.8 (worst first)
TRAJ_SCORES=$(echo "$TRAJ_XML" | grep '<attempt ' | grep -oP 'score="\K[0-9.]+' | tr '\n' ',')

if [ "$TRAJ_SCORES" = "0.2,0.5,0.8," ]; then
  result PASS RF-6 "trajectory worst→best sort (0.2→0.5→0.8)"
else
  result FAIL RF-6 "trajectory sort" "got: $TRAJ_SCORES"
fi

# =============================================================================
# RF-7: trajectory.sh --max limit
# =============================================================================
TRAJ_MAX=$(bash "$SCRIPTS/trajectory.sh" --task "$TASK_TRAJ" --max 2)
TRAJ_MAX_COUNT=$(echo "$TRAJ_MAX" | grep '<previous_attempts' | grep -oP 'count="\K[0-9]+')
# --max 2 should select top 2 by score (0.5, 0.8), display worst→best
TRAJ_MAX_SCORES=$(echo "$TRAJ_MAX" | grep '<attempt ' | grep -oP 'score="\K[0-9.]+' | tr '\n' ',')

if [ "$TRAJ_MAX_COUNT" = "2" ] && [ "$TRAJ_MAX_SCORES" = "0.5,0.8," ]; then
  result PASS RF-7 "trajectory --max 2 (top-2 by score: 0.5→0.8)"
else
  result FAIL RF-7 "trajectory --max" "count=$TRAJ_MAX_COUNT scores=$TRAJ_MAX_SCORES"
fi

# =============================================================================
# RF-8: trajectory.sh CDATA format
# =============================================================================
if echo "$TRAJ_XML" | grep -q '<!\[CDATA\['; then
  if echo "$TRAJ_XML" | grep -q '</previous_attempts>'; then
    result PASS RF-8 "trajectory CDATA + XML structure"
  else
    result FAIL RF-8 "trajectory missing closing tag"
  fi
else
  result FAIL RF-8 "trajectory CDATA not found"
fi

# =============================================================================
# RF-9: refinement-gate.sh exists + bash -n
# =============================================================================
GATE="$ROOT/.claude/hooks/refinement-gate.sh"
if [ -f "$GATE" ]; then
  if bash -n "$GATE" 2>/dev/null; then
    result PASS RF-9 "refinement-gate.sh exists + syntax OK"
  else
    result FAIL RF-9 "refinement-gate.sh syntax error"
  fi
else
  result FAIL RF-9 "refinement-gate.sh not found"
fi

# =============================================================================
# RF-10: refinement-gate.sh — no marker → exit 0
# =============================================================================
GATE_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR" "$GATE_TMPDIR"' EXIT
# Run gate with no marker in a clean project dir
GATE_OUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$GATE_TMPDIR" bash "$GATE" 2>/dev/null)
GATE_EXIT=$?
if [ "$GATE_EXIT" -eq 0 ] && [ -z "$GATE_OUT" ]; then
  result PASS RF-10 "gate: no marker → exit 0 (silent pass)"
else
  result FAIL RF-10 "gate: no marker" "exit=$GATE_EXIT out=$GATE_OUT"
fi

# =============================================================================
# RF-11: refinement-gate.sh — marker + score below threshold → block
# =============================================================================
GATE_DIR_11=$(mktemp -d)
mkdir -p "$GATE_DIR_11/.claude"
mkdir -p "$GATE_DIR_11/scripts/refinement"
# Create marker
echo '{"task_id":"test-rf11","threshold":0.9,"max_iterations":5}' > "$GATE_DIR_11/.claude/.refinement-active"
# Create memory-ops.sh stub that returns low score
cat > "$GATE_DIR_11/scripts/refinement/memory-ops.sh" <<'STUB'
#!/bin/bash
case "$1" in
  best)  echo '{"score":0.3}' ;;
  count) echo "1" ;;
esac
STUB
chmod +x "$GATE_DIR_11/scripts/refinement/memory-ops.sh"

GATE_OUT_11=$(echo '{}' | CLAUDE_PROJECT_DIR="$GATE_DIR_11" bash "$GATE" 2>/dev/null)
if echo "$GATE_OUT_11" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  result PASS RF-11 "gate: below threshold → block"
else
  result FAIL RF-11 "gate: expected block" "out=$GATE_OUT_11"
fi
rm -rf "$GATE_DIR_11"

# =============================================================================
# RF-12: refinement-gate.sh — score meets threshold → exit 0
# =============================================================================
GATE_DIR_12=$(mktemp -d)
mkdir -p "$GATE_DIR_12/.claude"
mkdir -p "$GATE_DIR_12/scripts/refinement"
echo '{"task_id":"test-rf12","threshold":0.8,"max_iterations":5}' > "$GATE_DIR_12/.claude/.refinement-active"
cat > "$GATE_DIR_12/scripts/refinement/memory-ops.sh" <<'STUB'
#!/bin/bash
case "$1" in
  best)  echo '{"score":0.85}' ;;
  count) echo "2" ;;
esac
STUB
chmod +x "$GATE_DIR_12/scripts/refinement/memory-ops.sh"

GATE_OUT_12=$(echo '{}' | CLAUDE_PROJECT_DIR="$GATE_DIR_12" bash "$GATE" 2>/dev/null)
GATE_EXIT_12=$?
# exit 0 + no block decision = allow stop (empty output or no "block" in output)
if [ "$GATE_EXIT_12" -eq 0 ] && ! echo "$GATE_OUT_12" | grep -q '"decision".*"block"'; then
  result PASS RF-12 "gate: score >= threshold → exit 0"
else
  result FAIL RF-12 "gate: expected pass" "exit=$GATE_EXIT_12 out=$GATE_OUT_12"
fi
rm -rf "$GATE_DIR_12"

# =============================================================================
# RF-13: refinement-gate.sh — symlink marker rejected
# =============================================================================
GATE_DIR_13=$(mktemp -d)
mkdir -p "$GATE_DIR_13/.claude"
# Create symlink marker (should be rejected)
ln -sf /etc/passwd "$GATE_DIR_13/.claude/.refinement-active"

GATE_OUT_13=$(echo '{}' | CLAUDE_PROJECT_DIR="$GATE_DIR_13" bash "$GATE" 2>/dev/null)
GATE_EXIT_13=$?
if [ "$GATE_EXIT_13" -eq 0 ] && [ ! -L "$GATE_DIR_13/.claude/.refinement-active" ]; then
  result PASS RF-13 "gate: symlink marker rejected + removed"
else
  result FAIL RF-13 "gate: symlink" "exit=$GATE_EXIT_13 link_exists=$(test -L "$GATE_DIR_13/.claude/.refinement-active" && echo yes || echo no)"
fi
rm -rf "$GATE_DIR_13"

# =============================================================================
# RF-14: task-quality-gate.sh — no marker → existing behavior
# =============================================================================
TQG="$ROOT/.claude/hooks/task-quality-gate.sh"
if [ -f "$TQG" ]; then
  TQG_DIR_14=$(mktemp -d)
  mkdir -p "$TQG_DIR_14/.claude"
  TQG_OUT=$(echo '{"tool_input":"{}"}' | CLAUDE_PROJECT_DIR="$TQG_DIR_14" bash "$TQG" 2>/dev/null)
  if echo "$TQG_OUT" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
    # Check it does NOT contain refinement info when no marker
    if echo "$TQG_OUT" | grep -q 'Refinement active'; then
      result FAIL RF-14 "task-quality-gate shows refinement without marker"
    else
      result PASS RF-14 "task-quality-gate: no marker → existing behavior"
    fi
  else
    result FAIL RF-14 "task-quality-gate: no hookSpecificOutput"
  fi
  rm -rf "$TQG_DIR_14"
else
  result SKIP RF-14 "task-quality-gate.sh not found"
fi

# =============================================================================
# RF-15: settings.json has refinement-gate registered
# =============================================================================
SETTINGS="$ROOT/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
  if jq -r '.hooks.Stop[0].hooks[].command' "$SETTINGS" 2>/dev/null | grep -q 'refinement-gate'; then
    result PASS RF-15 "settings.json: refinement-gate in Stop hooks"
  else
    result FAIL RF-15 "settings.json: refinement-gate not found in Stop hooks"
  fi
else
  result FAIL RF-15 "settings.json not found"
fi

# =============================================================================
# RF-16: SKILL.md contains DEGRADATION check (v3.1)
# =============================================================================
SKILL="$ROOT/.claude/skills/refine/SKILL.md"
if [ -f "$SKILL" ]; then
  if grep -q 'DEGRADATION' "$SKILL"; then
    result PASS RF-16 "SKILL.md: DEGRADATION check present"
  else
    result FAIL RF-16 "SKILL.md: DEGRADATION not found"
  fi
else
  result FAIL RF-16 "SKILL.md not found"
fi

# =============================================================================
# RF-17: SKILL.md references scripts/refinement (infrastructure detection v3.1)
# =============================================================================
if [ -f "$SKILL" ]; then
  if grep -q 'scripts/refinement' "$SKILL"; then
    result PASS RF-17 "SKILL.md: scripts/refinement reference present"
  else
    result FAIL RF-17 "SKILL.md: scripts/refinement not found"
  fi
else
  result FAIL RF-17 "SKILL.md not found"
fi

# =============================================================================
# RF-18: verify-score.sh — ruff unavailable → valid JSON
# =============================================================================
VS="$SCRIPTS/verify-score.sh"
if [ -f "$VS" ]; then
  # Use a temp dir with no tools installed as project
  VS_DIR=$(mktemp -d)
  mkdir -p "$VS_DIR/src"
  echo "x = 1" > "$VS_DIR/src/dummy.py"
  echo '[project]' > "$VS_DIR/pyproject.toml"
  VS_OUT=$(bash "$VS" --project "$VS_DIR" --score 2>/dev/null)
  if echo "$VS_OUT" | jq -e '.metrics' >/dev/null 2>&1; then
    RUFF_STATUS=$(echo "$VS_OUT" | jq -r '.tools.ruff // "missing"')
    if [ "$RUFF_STATUS" = "unavailable" ] || [ "$RUFF_STATUS" = "available" ]; then
      result PASS RF-18 "verify-score.sh: ruff status=$RUFF_STATUS, valid JSON"
    else
      result FAIL RF-18 "verify-score.sh: unexpected ruff status=$RUFF_STATUS"
    fi
  else
    result FAIL RF-18 "verify-score.sh: invalid JSON output" "$VS_OUT"
  fi
  rm -rf "$VS_DIR"
else
  result FAIL RF-18 "verify-score.sh not found"
fi

# =============================================================================
# RF-19: verify-score.sh — all tools unavailable → valid JSON with score
# =============================================================================
if [ -f "$VS" ]; then
  # Empty project with no Python, no npm, no tools
  VS_DIR_19=$(mktemp -d)
  VS_OUT_19=$(bash "$VS" --project "$VS_DIR_19" --score 2>/dev/null)
  if echo "$VS_OUT_19" | jq -e '.score' >/dev/null 2>&1; then
    VS_SCORE=$(echo "$VS_OUT_19" | jq '.score')
    result PASS RF-19 "verify-score.sh: all tools unavailable → valid JSON (score=$VS_SCORE)"
  else
    result FAIL RF-19 "verify-score.sh: invalid JSON when no tools" "$VS_OUT_19"
  fi
  rm -rf "$VS_DIR_19"
else
  result FAIL RF-19 "verify-score.sh not found"
fi

# =============================================================================
# Summary
# =============================================================================
TOTAL=$((PASS + FAIL + SKIP))
echo "---"
echo "TOTAL: $TOTAL  PASS: $PASS  FAIL: $FAIL  SKIP: $SKIP"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
