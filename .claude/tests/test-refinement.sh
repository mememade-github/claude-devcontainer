#!/bin/bash
# test-refinement.sh — Refinement loop infrastructure tests (RF-1..RF-14)
# v6: thin orchestrator — inline JSONL, no external scripts

set -euo pipefail

ROOT="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
SCRIPTS="$ROOT/.claude/skills/refine"
PASS=0; FAIL=0; SKIP=0

result() {
  local status="$1" id="$2" desc="$3" detail="${4:-}"
  case "$status" in PASS) PASS=$((PASS+1));; FAIL) FAIL=$((FAIL+1));; SKIP) SKIP=$((SKIP+1));; esac
  echo "$status: $id $desc${detail:+ ($detail)}"
}

# --- Temp directory for test isolation ---
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# =============================================================================
# RF-1: JSONL inline add works
# =============================================================================
TASK_TEST="test-inline-$$"
TEST_FILE="$TMPDIR/$TASK_TEST.jsonl"
echo '{"score":0.3,"result":"Baseline","feedback":"initial"}' >> "$TEST_FILE"
echo '{"score":0.7,"result":"KEEP: improved","feedback":"partial"}' >> "$TEST_FILE"

if [ -f "$TEST_FILE" ] && [ "$(wc -l < "$TEST_FILE")" -eq 2 ]; then
  result PASS RF-1 "JSONL inline add (echo >> file, 2 lines)"
else
  result FAIL RF-1 "JSONL inline add"
fi

# =============================================================================
# RF-2: JSONL inline best score extraction
# =============================================================================
BEST=$(jq -s 'sort_by(.score)|last|.score//0' "$TEST_FILE" 2>/dev/null || echo "0")
if [ "$BEST" = "0.7" ]; then
  result PASS RF-2 "JSONL inline best (jq sort → 0.7)"
else
  result FAIL RF-2 "JSONL inline best" "got=$BEST"
fi

# =============================================================================
# RF-3: JSONL inline count
# =============================================================================
COUNT=$(wc -l < "$TEST_FILE" 2>/dev/null || echo "0")
if [ "$COUNT" -eq 2 ]; then
  result PASS RF-3 "JSONL inline count (wc -l → 2)"
else
  result FAIL RF-3 "JSONL inline count" "got=$COUNT"
fi

# =============================================================================
# RF-4: refinement-gate.sh exists + bash -n
# =============================================================================
GATE="$ROOT/.claude/hooks/refinement-gate.sh"
if [ -f "$GATE" ]; then
  if bash -n "$GATE" 2>/dev/null; then
    result PASS RF-4 "refinement-gate.sh exists + syntax OK"
  else
    result FAIL RF-4 "refinement-gate.sh syntax error"
  fi
else
  result FAIL RF-4 "refinement-gate.sh not found"
fi

# =============================================================================
# RF-5: refinement-gate.sh — no marker -> exit 0
# =============================================================================
GATE_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR" "$GATE_TMPDIR"' EXIT
GATE_OUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$GATE_TMPDIR" bash "$GATE" 2>/dev/null)
GATE_EXIT=$?
if [ "$GATE_EXIT" -eq 0 ] && [ -z "$GATE_OUT" ]; then
  result PASS RF-5 "gate: no marker -> exit 0 (silent pass)"
else
  result FAIL RF-5 "gate: no marker" "exit=$GATE_EXIT out=$GATE_OUT"
fi

# =============================================================================
# RF-6: refinement-gate.sh — marker + score below threshold -> block
# =============================================================================
GATE_DIR_6=$(mktemp -d)
mkdir -p "$GATE_DIR_6/.claude"
mkdir -p "$GATE_DIR_6/.claude/agent-memory/refinement/attempts"
echo '{"task_id":"test-rf6","threshold":0.9,"max_iterations":5}' > "$GATE_DIR_6/.claude/.refinement-active"
echo '{"score":0.3,"result":"Baseline","feedback":"initial"}' > "$GATE_DIR_6/.claude/agent-memory/refinement/attempts/test-rf6.jsonl"

GATE_OUT_6=$(echo '{}' | CLAUDE_PROJECT_DIR="$GATE_DIR_6" bash "$GATE" 2>/dev/null)
if echo "$GATE_OUT_6" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  result PASS RF-6 "gate: below threshold -> block"
else
  result FAIL RF-6 "gate: expected block" "out=$GATE_OUT_6"
fi
rm -rf "$GATE_DIR_6"

# =============================================================================
# RF-7: refinement-gate.sh — score meets threshold -> exit 0
# =============================================================================
GATE_DIR_7=$(mktemp -d)
mkdir -p "$GATE_DIR_7/.claude"
mkdir -p "$GATE_DIR_7/.claude/agent-memory/refinement/attempts"
echo '{"task_id":"test-rf7","threshold":0.8,"max_iterations":5}' > "$GATE_DIR_7/.claude/.refinement-active"
echo '{"score":0.85,"result":"KEEP: improved","feedback":"good"}' > "$GATE_DIR_7/.claude/agent-memory/refinement/attempts/test-rf7.jsonl"

GATE_OUT_7=$(echo '{}' | CLAUDE_PROJECT_DIR="$GATE_DIR_7" bash "$GATE" 2>/dev/null)
GATE_EXIT_7=$?
if [ "$GATE_EXIT_7" -eq 0 ] && ! echo "$GATE_OUT_7" | grep -q '"decision".*"block"'; then
  result PASS RF-7 "gate: score >= threshold -> exit 0"
else
  result FAIL RF-7 "gate: expected pass" "exit=$GATE_EXIT_7 out=$GATE_OUT_7"
fi
rm -rf "$GATE_DIR_7"

# =============================================================================
# RF-8: refinement-gate.sh — symlink marker rejected
# =============================================================================
GATE_DIR_8=$(mktemp -d)
mkdir -p "$GATE_DIR_8/.claude"
ln -sf /etc/passwd "$GATE_DIR_8/.claude/.refinement-active"

GATE_OUT_8=$(echo '{}' | CLAUDE_PROJECT_DIR="$GATE_DIR_8" bash "$GATE" 2>/dev/null)
GATE_EXIT_8=$?
if [ "$GATE_EXIT_8" -eq 0 ] && [ ! -L "$GATE_DIR_8/.claude/.refinement-active" ]; then
  result PASS RF-8 "gate: symlink marker rejected + removed"
else
  result FAIL RF-8 "gate: symlink" "exit=$GATE_EXIT_8"
fi
rm -rf "$GATE_DIR_8"

# =============================================================================
# RF-9: settings.json has refinement-gate registered
# =============================================================================
SETTINGS="$ROOT/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
  if jq -r '.hooks.Stop[0].hooks[].command' "$SETTINGS" 2>/dev/null | grep -q 'refinement-gate'; then
    result PASS RF-9 "settings.json: refinement-gate in Stop hooks"
  else
    result FAIL RF-9 "settings.json: refinement-gate not found in Stop hooks"
  fi
else
  result FAIL RF-9 "settings.json not found"
fi

# =============================================================================
# RF-10: SKILL.md contains autoresearch evaluation protocol
# =============================================================================
SKILL="$ROOT/.claude/skills/refine/SKILL.md"
if [ -f "$SKILL" ]; then
  HAS_EVAL=$(grep -c 'immutable\|calibrat\|rubrics/default.yml\|evaluator' "$SKILL" || true)
  HAS_BINARY=$(grep -c 'KEEP\|DISCARD' "$SKILL" || true)
  if [ "$HAS_EVAL" -ge 2 ] && [ "$HAS_BINARY" -ge 2 ]; then
    result PASS RF-10 "SKILL.md: autoresearch pattern (eval=$HAS_EVAL, binary=$HAS_BINARY)"
  else
    result FAIL RF-10 "SKILL.md: autoresearch markers" "eval=$HAS_EVAL binary=$HAS_BINARY"
  fi
else
  result FAIL RF-10 "SKILL.md not found"
fi

# =============================================================================
# RF-11: SKILL.md does NOT reference deleted scripts
# =============================================================================
if [ -f "$SKILL" ]; then
  DELETED_REFS=$(grep -c 'verify-score\.sh\|score\.sh\|feedback-builder\.sh\|memory-ops\.sh\|trajectory\.sh' "$SKILL" || true)
  if [ "$DELETED_REFS" -eq 0 ]; then
    result PASS RF-11 "SKILL.md: no references to deleted scripts"
  else
    result FAIL RF-11 "SKILL.md: still references deleted scripts" "count=$DELETED_REFS"
  fi
else
  result FAIL RF-11 "SKILL.md not found"
fi

# =============================================================================
# RF-12: rubric file exists with required dimensions
# =============================================================================
RUBRIC="$ROOT/.claude/skills/refine/rubrics/default.yml"
if [ -f "$RUBRIC" ]; then
  HAS_DIMS=true
  for DIM in correctness improvement completeness consistency; do
    if ! grep -q "^    $DIM:" "$RUBRIC"; then
      HAS_DIMS=false
      break
    fi
  done
  HAS_ANCHORS=$(grep -c '"0\.\(0\|25\|5\|75\|0\)"' "$RUBRIC" || true)
  if $HAS_DIMS && [ "$HAS_ANCHORS" -ge 16 ]; then
    result PASS RF-12 "rubric: 4 dimensions + anchors present (anchors=$HAS_ANCHORS)"
  else
    result FAIL RF-12 "rubric structure" "dims=$HAS_DIMS anchors=$HAS_ANCHORS"
  fi
else
  result FAIL RF-12 "rubric not found"
fi

# =============================================================================
# RF-13: file inventory — 2 files (SKILL.md + rubrics/default.yml)
# =============================================================================
EXPECTED_FILES="SKILL.md rubrics/default.yml"
ACTUAL_COUNT=0
MISSING=""
for F in $EXPECTED_FILES; do
  if [ -f "$SCRIPTS/$F" ]; then
    ACTUAL_COUNT=$((ACTUAL_COUNT + 1))
  else
    MISSING="$MISSING $F"
  fi
done

GHOST=""
for G in verify-score.sh score.sh feedback-builder.sh memory-ops.sh trajectory.sh; do
  if [ -f "$SCRIPTS/$G" ]; then
    GHOST="$GHOST $G"
  fi
done

if [ "$ACTUAL_COUNT" -eq 2 ] && [ -z "$GHOST" ]; then
  result PASS RF-13 "file inventory: 2 expected files, 0 ghost files"
else
  result FAIL RF-13 "file inventory" "found=$ACTUAL_COUNT missing=$MISSING ghost=$GHOST"
fi

# =============================================================================
# RF-14: evaluator agent exists with required fields
# =============================================================================
EVAL_AGENT="$ROOT/.claude/agents/evaluator.md"
if [ -f "$EVAL_AGENT" ]; then
  HAS_NAME=$(grep -c '^name: evaluator' "$EVAL_AGENT" || true)
  HAS_MODEL=$(grep -c '^model: opus' "$EVAL_AGENT" || true)
  HAS_BOUNDARY=$(grep -c 'Behavioral Boundary\|EVALUATE and SCORE' "$EVAL_AGENT" || true)
  if [ "$HAS_NAME" -ge 1 ] && [ "$HAS_MODEL" -ge 1 ] && [ "$HAS_BOUNDARY" -ge 1 ]; then
    result PASS RF-14 "evaluator agent: exists, correct name/model, has boundary"
  else
    result FAIL RF-14 "evaluator agent fields" "name=$HAS_NAME model=$HAS_MODEL boundary=$HAS_BOUNDARY"
  fi
else
  result FAIL RF-14 "evaluator agent not found at agents/evaluator.md"
fi

# =============================================================================
# Summary
# =============================================================================
TOTAL=$((PASS + FAIL + SKIP))
echo "---"
echo "TOTAL: $TOTAL  PASS: $PASS  FAIL: $FAIL  SKIP: $SKIP"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
