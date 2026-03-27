#!/bin/bash
# verify-score.sh — Deterministic verification pipeline (the ONLY score source)
# Runs lint/build/test tools, produces metrics + structural feedback
# Usage: verify-score.sh --project <path> [--score]

set -euo pipefail

PROJECT=""
WITH_SCORE=false

while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --score)   WITH_SCORE=true; shift ;;
    *)         echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$PROJECT" ]; then
  echo '{"error":"--project required"}' >&2
  exit 1
fi

if [ ! -d "$PROJECT" ]; then
  echo '{"error":"project not found"}' >&2
  exit 1
fi

# --- ANSI escape code removal (Poetiq _build_feedback() produces pure text) ---
strip_ansi() {
  sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g'
}

# --- PAT masking (observe.sh 4-pattern) ---
mask_secrets() {
  sed -E \
    -e 's/github_pat_[A-Za-z0-9_]{10,}/github_pat_***MASKED***/g' \
    -e 's/ghp_[A-Za-z0-9]{10,}/ghp_***MASKED***/g' \
    -e 's/glpat-[A-Za-z0-9_]{10,}/glpat-***MASKED***/g' \
    -e 's/ghs_[A-Za-z0-9]{10,}/ghs_***MASKED***/g'
}

# --- Project type detection (completion-checker.sh pattern) ---
detect_type() {
  local dir="$1"
  if [ -f "$dir/pyproject.toml" ] || [ -f "$dir/setup.py" ]; then echo "python"
  elif [ -f "$dir/package.json" ]; then echo "typescript"
  else echo "unknown"; fi
}

PROJECT_TYPE=$(detect_type "$PROJECT")

# --- Pre-validation (GAP-6) ---
HAS_PY_SRC=false
if [ -d "$PROJECT/src" ] && [ -n "$(find "$PROJECT/src" -name '*.py' -maxdepth 3 -print -quit 2>/dev/null)" ]; then
  HAS_PY_SRC=true
fi

HAS_PYTEST=false
if [ -x "$PROJECT/.venv/bin/pytest" ]; then
  HAS_PYTEST=true
fi

# --- Tool detection ---
TOOLS_JSON='{}'

# --- Lint (ruff) ---
LINT_ERRORS="null"
LINT_FEEDBACK=""

if $HAS_PY_SRC && command -v ruff &>/dev/null; then
  TOOLS_JSON=$(echo "$TOOLS_JSON" | jq '.ruff = "available"')
  LINT_RAW=$(cd "$PROJECT" && ruff check src/ 2>&1 | strip_ansi || true)
  if echo "$LINT_RAW" | grep -q 'All checks passed'; then
    LINT_ERRORS=0
  else
    LINT_ERRORS=$(echo "$LINT_RAW" | grep -oP 'Found \K\d+(?= error)' || echo "0")
    [ -z "$LINT_ERRORS" ] && LINT_ERRORS=0
  fi
  LINT_FEEDBACK=$(echo "$LINT_RAW" | head -c 2000)
else
  TOOLS_JSON=$(echo "$TOOLS_JSON" | jq '.ruff = "unavailable"')
fi

# --- Type check (mypy) ---
MYPY_ERRORS="null"
MYPY_FEEDBACK=""

if $HAS_PY_SRC && command -v mypy &>/dev/null; then
  TOOLS_JSON=$(echo "$TOOLS_JSON" | jq '.mypy = "available"')
  MYPY_RAW=$(cd "$PROJECT" && mypy src/ --ignore-missing-imports 2>&1 | strip_ansi || true)
  if echo "$MYPY_RAW" | grep -q 'Success: no issues'; then
    MYPY_ERRORS=0
  else
    MYPY_ERRORS=$(echo "$MYPY_RAW" | grep -oP 'Found \K\d+(?= error)' || echo "0")
    [ -z "$MYPY_ERRORS" ] && MYPY_ERRORS=0
  fi
  MYPY_FEEDBACK=$(echo "$MYPY_RAW" | tail -20 | head -c 2000)
else
  TOOLS_JSON=$(echo "$TOOLS_JSON" | jq '.mypy = "unavailable"')
fi

# --- Build check ---
BUILD_OK="null"
BUILD_FEEDBACK=""

if [ "$PROJECT_TYPE" = "python" ]; then
  # Python: build = ruff + mypy pass (no separate build step)
  if [ "$LINT_ERRORS" != "null" ] || [ "$MYPY_ERRORS" != "null" ]; then
    BUILD_OK=true
    TOOLS_JSON=$(echo "$TOOLS_JSON" | jq '.build = "available"')
  else
    TOOLS_JSON=$(echo "$TOOLS_JSON" | jq '.build = "unavailable"')
  fi
elif [ "$PROJECT_TYPE" = "typescript" ] && [ -f "$PROJECT/package.json" ]; then
  TOOLS_JSON=$(echo "$TOOLS_JSON" | jq '.build = "available"')
  BUILD_RAW=$(cd "$PROJECT" && npm run build 2>&1 || true)
  if echo "$BUILD_RAW" | grep -qE '(error|Error)'; then
    BUILD_OK=false
  else
    BUILD_OK=true
  fi
  BUILD_FEEDBACK=$(echo "$BUILD_RAW" | tail -20 | head -c 2000)
else
  TOOLS_JSON=$(echo "$TOOLS_JSON" | jq '.build = "unavailable"')
fi

# --- Tests (pytest) ---
TEST_PASSED="null"
TEST_TOTAL="null"
TEST_FEEDBACK=""

if $HAS_PYTEST; then
  TOOLS_JSON=$(echo "$TOOLS_JSON" | jq '.pytest = "available"')
  TEST_RAW=$(cd "$PROJECT" && .venv/bin/pytest tests/unit --tb=short -q --no-header 2>&1 | strip_ansi || true)
  if echo "$TEST_RAW" | grep -q 'no tests ran'; then
    TEST_PASSED=0; TEST_TOTAL=0
  else
    TEST_PASSED=$(echo "$TEST_RAW" | grep -oP '\d+(?= passed)' || echo "0")
    TEST_FAILED=$(echo "$TEST_RAW" | grep -oP '\d+(?= failed)' || echo "0")
    [ -z "$TEST_PASSED" ] && TEST_PASSED=0
    [ -z "$TEST_FAILED" ] && TEST_FAILED=0
    TEST_TOTAL=$((TEST_PASSED + TEST_FAILED))
  fi
  TEST_FEEDBACK=$(echo "$TEST_RAW" | tail -50 | head -c 2000)
else
  TOOLS_JSON=$(echo "$TOOLS_JSON" | jq '.pytest = "unavailable"')
fi

# --- Combine feedback ---
ALL_FEEDBACK=""
[ -n "$LINT_FEEDBACK" ] && ALL_FEEDBACK="${ALL_FEEDBACK}${LINT_FEEDBACK}\n"
[ -n "$MYPY_FEEDBACK" ] && ALL_FEEDBACK="${ALL_FEEDBACK}${MYPY_FEEDBACK}\n"
[ -n "$TEST_FEEDBACK" ] && ALL_FEEDBACK="${ALL_FEEDBACK}${TEST_FEEDBACK}\n"
[ -n "$BUILD_FEEDBACK" ] && ALL_FEEDBACK="${ALL_FEEDBACK}${BUILD_FEEDBACK}\n"

SAFE_FEEDBACK=$(printf '%b' "$ALL_FEEDBACK" | mask_secrets | jq -Rs '.')

# --- Build metrics JSON ---
METRICS=$(jq -n -c \
  --argjson lint "$LINT_ERRORS" \
  --argjson build "$BUILD_OK" \
  --argjson tp "${TEST_PASSED}" \
  --argjson tt "${TEST_TOTAL}" \
  --argjson mypy "$MYPY_ERRORS" \
  '{lint_errors:$lint, build_ok:$build, test_passed:$tp, test_total:$tt, mypy_errors:$mypy}')

# --- Output ---
if $WITH_SCORE; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  SCORE_RESULT=$(echo "$METRICS" | bash "$SCRIPT_DIR/score.sh")
  SCORE_VAL=$(echo "$SCORE_RESULT" | jq '.score')
  BREAKDOWN=$(echo "$SCORE_RESULT" | jq '.breakdown')

  jq -n -c \
    --argjson metrics "$METRICS" \
    --argjson feedback "$SAFE_FEEDBACK" \
    --argjson score "$SCORE_VAL" \
    --argjson breakdown "$BREAKDOWN" \
    --argjson tools "$TOOLS_JSON" \
    '{metrics:$metrics, feedback:$feedback, score:$score, breakdown:$breakdown, tools:$tools}'
else
  jq -n -c \
    --argjson metrics "$METRICS" \
    --argjson feedback "$SAFE_FEEDBACK" \
    --argjson tools "$TOOLS_JSON" \
    '{metrics:$metrics, feedback:$feedback, tools:$tools}'
fi
