#!/bin/bash
# score.sh — Hybrid quality score (D_score deterministic + L_score LLM rubric)
# Input: JSON on stdin with metrics (required) + llm_score (optional)
# Output: JSON with score, d_score, l_score, breakdown, weights on stdout
# Dependencies: jq only (no bc)
#
# Hybrid formula: score = d_score * 0.6 + l_score * 0.4
# If l_score is absent (null), score = d_score (pure deterministic fallback)

set -euo pipefail

INPUT=$(cat)

# Validate input is valid JSON
if ! echo "$INPUT" | jq empty 2>/dev/null; then
  echo '{"error":"invalid JSON input"}' >&2
  exit 1
fi

# Calculate score entirely in jq (no bc, no awk)
echo "$INPUT" | jq -c '
# Weights
def weights: {lint: 0.15, build: 0.25, test: 0.35, review: 0.25};

# Round to 4 decimal places (IEEE 754 artifact prevention)
def round4: ((. * 10000 | round) / 10000);

# Individual scores
def lint_score:
  if .lint_errors == null then null
  elif .lint_errors == 0 then 1.0
  else ([0, (1 - .lint_errors * 0.1)] | max) | round4
  end;

def build_score:
  if .build_ok == null then null
  elif .build_ok then 1.0
  else 0.0
  end;

def test_score:
  if .test_total == null then null
  elif .test_total == 0 then null
  else (.test_passed / .test_total) | round4
  end;

def review_score:
  if .mypy_errors == null then null
  elif .mypy_errors == 0 then 1.0
  else ([0, (1 - .mypy_errors * 0.02)] | max) | round4
  end;

# Compute
. as $input |
{
  lint: ($input | lint_score),
  build: ($input | build_score),
  test: ($input | test_score),
  review: ($input | review_score)
} as $breakdown |

# Weighted sum with null exclusion and weight redistribution
weights as $w |
(
  [
    if $breakdown.lint != null then {w: $w.lint, s: $breakdown.lint} else empty end,
    if $breakdown.build != null then {w: $w.build, s: $breakdown.build} else empty end,
    if $breakdown.test != null then {w: $w.test, s: $breakdown.test} else empty end,
    if $breakdown.review != null then {w: $w.review, s: $breakdown.review} else empty end
  ]
) as $active |

(if ($active | length) == 0 then 0
 else
   ($active | map(.w) | add) as $total_w |
   ($active | map(.s * .w / $total_w) | add) | round4
 end) as $d_score |

# hybrid scoring: integrate LLM rubric score if provided
(.llm_score // null) as $l_score |

(if $l_score != null then
   ($d_score * 0.6 + $l_score * 0.4) | round4
 else
   $d_score
 end) as $total |

{
  score: $total,
  d_score: $d_score,
  l_score: $l_score,
  breakdown: $breakdown,
  weights: $w,
  hybrid: ($l_score != null)
}
'
