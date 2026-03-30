#!/bin/bash
# memory-ops.sh — Refinement attempt CRUD (JSONL storage)
# Usage: memory-ops.sh add   --task <id> --agent <name> --score <n> [--feedback <text>] [--result <text>] [--metric-type <type>] [--metric-raw <raw>]
#        memory-ops.sh {list|best|count|clear} --task <id>

set -euo pipefail

# --- PAT masking (observe.sh 4-pattern) ---
mask_secrets() {
  sed -E \
    -e 's/github_pat_[A-Za-z0-9_]{10,}/github_pat_***MASKED***/g' \
    -e 's/ghp_[A-Za-z0-9]{10,}/ghp_***MASKED***/g' \
    -e 's/glpat-[A-Za-z0-9_]{10,}/glpat-***MASKED***/g' \
    -e 's/ghs_[A-Za-z0-9]{10,}/ghs_***MASKED***/g'
}

# --- Defaults ---
COMMAND="${1:-}"
shift 2>/dev/null || true

TASK_ID=""
AGENT=""
SCORE=""
RESULT_TEXT=""
FEEDBACK=""
METRIC_TYPE=""
METRIC_RAW=""

# --- Parse args ---
while [ $# -gt 0 ]; do
  case "$1" in
    --task)   TASK_ID="$2"; shift 2 ;;
    --agent)  AGENT="$2"; shift 2 ;;
    --score)  SCORE="$2"; shift 2 ;;
    --result) RESULT_TEXT="$2"; shift 2 ;;
    --feedback) FEEDBACK="$2"; shift 2 ;;
    --metric-type) METRIC_TYPE="$2"; shift 2 ;;
    --metric-raw)  METRIC_RAW="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# --- Validate task_id ---
if [ -z "$TASK_ID" ]; then
  echo "Error: --task required" >&2
  exit 1
fi
if ! [[ "$TASK_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "Error: invalid task_id (alphanumeric, dash, underscore only)" >&2
  exit 1
fi

# --- Storage path ---
STORE_DIR="${CLAUDE_AGENT_MEMORY:-${CLAUDE_PROJECT_DIR:-.}/.claude/agent-memory}/refinement/attempts"
FILE="$STORE_DIR/$TASK_ID.jsonl"

# --- Commands ---
case "$COMMAND" in
  add)
    [ -z "$AGENT" ] && { echo "Error: --agent required" >&2; exit 1; }
    [ -z "$SCORE" ] && { echo "Error: --score required" >&2; exit 1; }

    mkdir -p "$STORE_DIR"

    # Count existing attempts
    ATTEMPT=$({ wc -l < "$FILE" || echo 0; } 2>/dev/null)
    ATTEMPT=$((ATTEMPT + 1))

    # Safe JSON encoding via jq + PAT masking
    SAFE_RESULT=$(printf '%s' "$RESULT_TEXT" | mask_secrets | jq -Rs '.')
    SAFE_FEEDBACK=$(printf '%s' "$FEEDBACK" | mask_secrets | jq -Rs '.')
    SAFE_METRIC_RAW=$(printf '%s' "${METRIC_RAW:-}" | mask_secrets | jq -Rs '.')
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    LINE=$(jq -n -c \
      --arg tid "$TASK_ID" \
      --arg agt "$AGENT" \
      --argjson att "$ATTEMPT" \
      --argjson scr "$SCORE" \
      --argjson res "$SAFE_RESULT" \
      --argjson fb "$SAFE_FEEDBACK" \
      --arg mt "${METRIC_TYPE:-rubric}" \
      --argjson mr "$SAFE_METRIC_RAW" \
      --arg ts "$TIMESTAMP" \
      '{task_id:$tid,attempt:$att,agent:$agt,result_summary:$res,feedback:$fb,score:$scr,metric_type:$mt,metric_raw:$mr,timestamp:$ts}')

    if ! printf '%s\n' "$LINE" >> "$FILE"; then
      echo "Error: failed to write to $FILE" >&2
      exit 1
    fi

    echo "$LINE"
    ;;

  list)
    if [ ! -f "$FILE" ]; then
      echo "[]"
      exit 0
    fi
    jq -s '.' "$FILE"
    ;;

  best)
    if [ ! -f "$FILE" ]; then
      echo "null"
      exit 0
    fi
    jq -s 'sort_by(.score) | last' "$FILE"
    ;;

  count)
    COUNT=$({ wc -l < "$FILE" || echo 0; } 2>/dev/null)
    echo "$COUNT"
    ;;

  clear)
    rm -f "$FILE"
    echo "cleared"
    ;;

  *)
    echo "Usage: memory-ops.sh {add|list|best|count|clear} --task <id> [options]" >&2
    exit 1
    ;;
esac
