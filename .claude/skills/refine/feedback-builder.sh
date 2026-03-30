#!/bin/bash
# feedback-builder.sh — Poetiq-style hierarchical feedback generator
# Input: verify-score.sh JSON on stdin (or --raw file)
# Output: 3-tier structured XML feedback
#
# Tier 1 (Fatal):      Build failures, syntax errors — code doesn't run
# Tier 2 (Structural): Type errors (mypy), lint violations (ruff) — code runs but has defects
# Tier 3 (Behavioral): Test failures (pytest) — code runs but produces wrong results
#
# Mirrors poetiq's _build_feedback(): parse_failure > shape_mismatch > cell_diff

set -euo pipefail

INPUT=$(cat)

# extract metrics
BUILD_OK=$(echo "$INPUT" | jq -r 'if .metrics.build_ok == null then "null" elif .metrics.build_ok then "true" else "false" end')
LINT_ERRORS=$(echo "$INPUT" | jq -r '.metrics.lint_errors // "null"')
MYPY_ERRORS=$(echo "$INPUT" | jq -r '.metrics.mypy_errors // "null"')
TEST_PASSED=$(echo "$INPUT" | jq -r '.metrics.test_passed // "null"')
TEST_TOTAL=$(echo "$INPUT" | jq -r '.metrics.test_total // "null"')
RAW_FEEDBACK=$(echo "$INPUT" | jq -r '.feedback // ""')

# classify into tiers
TIER1="" # fatal
TIER2="" # structural
TIER3="" # behavioral

# tier 1: build failure = code doesn't execute
if [ "$BUILD_OK" = "false" ]; then
  TIER1="BUILD FAILED — code does not compile/execute.
Fix build errors before addressing any other issues."
fi

# tier 2: structural defects (code runs but has quality issues)
if [ "$LINT_ERRORS" != "null" ] && [ "$LINT_ERRORS" != "0" ]; then
  TIER2="${TIER2}LINT: $LINT_ERRORS violations found by ruff.
"
fi
if [ "$MYPY_ERRORS" != "null" ] && [ "$MYPY_ERRORS" != "0" ]; then
  TIER2="${TIER2}TYPE: $MYPY_ERRORS type errors found by mypy.
"
fi

# tier 3: behavioral (code runs, tests fail)
if [ "$TEST_TOTAL" != "null" ] && [ "$TEST_TOTAL" != "0" ]; then
  TEST_FAILED=$((TEST_TOTAL - TEST_PASSED))
  if [ "$TEST_FAILED" -gt 0 ]; then
    PASS_RATE=$(awk "BEGIN{printf \"%.2f\", $TEST_PASSED / $TEST_TOTAL}")
    TIER3="TESTS: $TEST_FAILED/$TEST_TOTAL failed (pass rate: $PASS_RATE).
"
  fi
fi

# build hierarchical XML (poetiq pattern: severity descending)
cat <<FEEDBACK_XML
<feedback>
  <tier1_fatal>
$(if [ -n "$TIER1" ]; then
  echo "    <![CDATA[$TIER1]]>"
else
  echo "    (none)"
fi)
  </tier1_fatal>
  <tier2_structural>
$(if [ -n "$TIER2" ]; then
  echo "    <![CDATA[${TIER2%$'\n'}]]>"
else
  echo "    (none)"
fi)
  </tier2_structural>
  <tier3_behavioral>
$(if [ -n "$TIER3" ]; then
  echo "    <![CDATA[${TIER3%$'\n'}]]>"
else
  echo "    (none)"
fi)
  </tier3_behavioral>
  <raw_output>
    <![CDATA[$(echo "$RAW_FEEDBACK" | head -c 3000)]]>
  </raw_output>
</feedback>
FEEDBACK_XML
