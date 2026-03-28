#!/bin/bash
# test-governance.sh — Governance, Knowledge Management, Evolution, Team Patterns checks
# GV-1..4, KM-1..6, EV-1..5, TP-1..2 + SKIPs

set -euo pipefail

ROOT="${1:-/workspaces}"
CLAUDE_DIR="$ROOT/.claude"
CLAUDE_MD="$ROOT/CLAUDE.md"
PASS=0; FAIL=0; SKIP=0

result() {
  local status="$1" id="$2" desc="$3" detail="${4:-}"
  if [ "$status" = "PASS" ]; then PASS=$((PASS + 1)); fi
  if [ "$status" = "FAIL" ]; then FAIL=$((FAIL + 1)); fi
  if [ "$status" = "SKIP" ]; then SKIP=$((SKIP + 1)); fi
  echo "$status: $id $desc ($detail)"
}

# Extract frontmatter from a file
get_frontmatter() {
  local file="$1"
  sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d'
}

get_field() {
  local fm="$1" field="$2"
  echo "$fm" | grep -E "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" || true
}

has_field() {
  local fm="$1" field="$2"
  echo "$fm" | grep -qE "^${field}:"
}

# ===== GOVERNANCE (GV-1..4) =====

# GV-1: 7 immutable principles in CLAUDE.md
if [ -f "$CLAUDE_MD" ]; then
  principles_found=0
  grep -qi 'INTEGRITY' "$CLAUDE_MD" && principles_found=$((principles_found + 1))
  grep -qi 'Destructive.*approval\|APPROVAL REQUIRED' "$CLAUDE_MD" && principles_found=$((principles_found + 1))
  grep -qi 'secrets\|credentials' "$CLAUDE_MD" && principles_found=$((principles_found + 1))
  grep -qi 'Read first' "$CLAUDE_MD" && principles_found=$((principles_found + 1))
  grep -qi 'Verify.*Build\|Build and test' "$CLAUDE_MD" && principles_found=$((principles_found + 1))
  grep -qi 'root cause\|Fix root' "$CLAUDE_MD" && principles_found=$((principles_found + 1))
  grep -qi 'Explicit failure\|arbitrary success' "$CLAUDE_MD" && principles_found=$((principles_found + 1))
  if [ "$principles_found" -ge 7 ]; then
    result "PASS" "GV-1" "7 immutable principles in CLAUDE.md" "$principles_found found"
  else
    result "FAIL" "GV-1" "7 immutable principles in CLAUDE.md" "only $principles_found found"
  fi
else
  result "FAIL" "GV-1" "7 immutable principles in CLAUDE.md" "CLAUDE.md not found"
fi

# GV-2: no secrets in git-tracked .claude/ files
gv2_fails=""
if command -v git &>/dev/null; then
  tracked_files=$(git -C "$ROOT" ls-files .claude/ 2>/dev/null || true)
  while IFS= read -r tf; do
    [ -z "$tf" ] && continue
    full="$ROOT/$tf"
    [ -f "$full" ] || continue
    # Check for actual long token patterns (not just mentions in docs)
    if grep -qE 'github_pat_[a-zA-Z0-9]{20,}|glpat-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{20,}' "$full" 2>/dev/null; then
      gv2_fails+=" $tf"
    fi
  done <<< "$tracked_files"
fi
if [ -z "$gv2_fails" ]; then
  result "PASS" "GV-2" "no secrets in git-tracked .claude/ files" "no PAT patterns found"
else
  result "FAIL" "GV-2" "no secrets in git-tracked .claude/ files" "found:${gv2_fails}"
fi

# GV-3: no project-specific refs in portable rules (rules/*.md, NOT rules/project/*)
gv3_fails=""
for rf in "$CLAUDE_DIR"/rules/*.md; do
  [ -f "$rf" ] || continue
  fname=$(basename "$rf")
  if grep -iE '\bmememade\b|<internal-rag>|<internal-web>|<internal-leaf>|<internal-root>' "$rf" > /dev/null 2>&1; then
    gv3_fails+=" $fname"
  fi
done
# Note: rules/standards/ is NOT checked — it is being replaced by tests/
# and will be deleted. Only portable rules (rules/*.md) are checked.
if [ -z "$gv3_fails" ]; then
  result "PASS" "GV-3" "no project-specific refs in portable rules" "clean"
else
  result "FAIL" "GV-3" "no project-specific refs in portable rules" "found:${gv3_fails}"
fi

# GV-4: block-destructive.sh registered in settings.json
if [ -f "$CLAUDE_DIR/settings.json" ]; then
  if grep -q 'block-destructive' "$CLAUDE_DIR/settings.json"; then
    result "PASS" "GV-4" "block-destructive.sh registered in settings.json" "found"
  else
    result "FAIL" "GV-4" "block-destructive.sh registered in settings.json" "not registered"
  fi
else
  result "FAIL" "GV-4" "block-destructive.sh registered in settings.json" "settings.json not found"
fi

# ===== KNOWLEDGE MANAGEMENT (KM-1..6) =====

# KM-1: CLAUDE.md exists
if [ -f "$CLAUDE_MD" ]; then
  result "PASS" "KM-1" "CLAUDE.md exists" "at $CLAUDE_MD"
else
  result "FAIL" "KM-1" "CLAUDE.md exists" "not found"
fi

# KM-2: CLAUDE.md under 200 lines
if [ -f "$CLAUDE_MD" ]; then
  line_count=$(wc -l < "$CLAUDE_MD")
  if [ "$line_count" -le 200 ]; then
    result "PASS" "KM-2" "CLAUDE.md under 200 lines" "${line_count} lines"
  else
    result "FAIL" "KM-2" "CLAUDE.md under 200 lines" "${line_count} lines"
  fi
else
  result "FAIL" "KM-2" "CLAUDE.md under 200 lines" "file not found"
fi

# KM-3: all agents with memory:project have agent-memory/NAME/MEMORY.md
km3_fails=""
for af in "$CLAUDE_DIR"/agents/*.md; do
  [ -f "$af" ] || continue
  fm=$(get_frontmatter "$af")
  mem_val=$(get_field "$fm" "memory")
  if [ "$mem_val" = "project" ]; then
    aname=$(get_field "$fm" "name")
    if [ ! -f "$CLAUDE_DIR/agent-memory/$aname/MEMORY.md" ]; then
      km3_fails+=" $aname"
    fi
  fi
done
if [ -z "$km3_fails" ]; then
  result "PASS" "KM-3" "agents with memory:project have MEMORY.md" "all agents"
else
  result "FAIL" "KM-3" "agents with memory:project have MEMORY.md" "missing:${km3_fails}"
fi

# KM-4: rules single-topic (count H1 headers outside code blocks per file)
km4_fails=""
for rf in "$CLAUDE_DIR"/rules/*.md "$CLAUDE_DIR"/rules/project/*.md; do
  [ -f "$rf" ] || continue
  fname=$(basename "$rf")
  # Count H1 headers (^# ) outside code blocks
  h1_count=$(sed '/^```/,/^```/d' "$rf" | grep -cE '^# ' || true)
  if [ "$h1_count" -gt 1 ]; then
    km4_fails+=" $fname(${h1_count}H1)"
  fi
done
if [ -z "$km4_fails" ]; then
  result "PASS" "KM-4" "rules are single-topic (1 H1 max)" "all rules"
else
  result "FAIL" "KM-4" "rules are single-topic (1 H1 max)" "multiple H1:${km4_fails}"
fi

# KM-5: all skills have SKILL.md with description
km5_fails=""
for skill_dir in "$CLAUDE_DIR"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  sname=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"
  if [ ! -f "$skill_file" ]; then
    km5_fails+=" $sname(no SKILL.md)"
  else
    fm=$(get_frontmatter "$skill_file")
    desc=$(get_field "$fm" "description")
    if [ -z "$desc" ]; then
      km5_fails+=" $sname(no description)"
    fi
  fi
done
if [ -z "$km5_fails" ]; then
  result "PASS" "KM-5" "all skills have SKILL.md with description" "all skills"
else
  result "FAIL" "KM-5" "all skills have SKILL.md with description" "issues:${km5_fails}"
fi

# KM-6: instincts dirs exist (personal, inherited, archive)
km6_missing=""
for subdir in personal inherited archive; do
  if [ ! -d "$CLAUDE_DIR/instincts/$subdir" ]; then
    km6_missing+=" $subdir"
  fi
done
if [ -z "$km6_missing" ]; then
  result "PASS" "KM-6" "instincts dirs exist" "personal, inherited, archive"
else
  result "FAIL" "KM-6" "instincts dirs exist" "missing:${km6_missing}"
fi

# ===== EVOLUTION (EV-1..5) =====

# EV-1: instinct frontmatter has id, trigger, confidence, domain
ev1_fails=""
instinct_count=0
for inst in "$CLAUDE_DIR"/instincts/personal/*.md "$CLAUDE_DIR"/instincts/inherited/*.md; do
  [ -f "$inst" ] || continue
  instinct_count=$((instinct_count + 1))
  fm=$(get_frontmatter "$inst")
  missing=""
  has_field "$fm" "id" || missing+="id,"
  has_field "$fm" "trigger" || missing+="trigger,"
  has_field "$fm" "confidence" || missing+="confidence,"
  has_field "$fm" "domain" || missing+="domain,"
  if [ -n "$missing" ]; then
    ev1_fails+=" $(basename "$inst")(${missing%,})"
  fi
done
if [ "$instinct_count" -eq 0 ]; then
  result "SKIP" "EV-1" "instinct frontmatter has required fields" "no instincts found"
else
  if [ -z "$ev1_fails" ]; then
    result "PASS" "EV-1" "instinct frontmatter has required fields" "$instinct_count instincts"
  else
    result "FAIL" "EV-1" "instinct frontmatter has required fields" "missing:${ev1_fails}"
  fi
fi

# EV-2: confidence in [0.0, 1.0]
ev2_fails=""
ev2_count=0
for inst in "$CLAUDE_DIR"/instincts/personal/*.md "$CLAUDE_DIR"/instincts/inherited/*.md; do
  [ -f "$inst" ] || continue
  fm=$(get_frontmatter "$inst")
  conf=$(get_field "$fm" "confidence")
  if [ -n "$conf" ]; then
    ev2_count=$((ev2_count + 1))
    in_range=$(python3 -c "c=float('$conf'); print('yes' if 0.0 <= c <= 1.0 else 'no')" 2>/dev/null || echo "no")
    if [ "$in_range" != "yes" ]; then
      ev2_fails+=" $(basename "$inst")($conf)"
    fi
  fi
done
if [ "$ev2_count" -eq 0 ]; then
  result "SKIP" "EV-2" "confidence in [0.0, 1.0]" "no instincts with confidence"
else
  if [ -z "$ev2_fails" ]; then
    result "PASS" "EV-2" "confidence in [0.0, 1.0]" "$ev2_count instincts"
  else
    result "FAIL" "EV-2" "confidence in [0.0, 1.0]" "out of range:${ev2_fails}"
  fi
fi

# EV-3: archived instincts below 0.2
ev3_fails=""
ev3_count=0
for inst in "$CLAUDE_DIR"/instincts/archive/*.md; do
  [ -f "$inst" ] || continue
  ev3_count=$((ev3_count + 1))
  fm=$(get_frontmatter "$inst")
  conf=$(get_field "$fm" "confidence")
  if [ -n "$conf" ]; then
    below=$(python3 -c "c=float('$conf'); print('yes' if c < 0.2 else 'no')" 2>/dev/null || echo "no")
    if [ "$below" != "yes" ]; then
      ev3_fails+=" $(basename "$inst")($conf)"
    fi
  fi
done
if [ "$ev3_count" -eq 0 ]; then
  result "PASS" "EV-3" "archived instincts below 0.2" "no archived instincts (vacuous pass)"
else
  if [ -z "$ev3_fails" ]; then
    result "PASS" "EV-3" "archived instincts below 0.2" "$ev3_count archived"
  else
    result "FAIL" "EV-3" "archived instincts below 0.2" "above threshold:${ev3_fails}"
  fi
fi

# EV-4: evolved artifact locations — mark-evolved.sh writes to .claude/ subdir
ev4_ok=true
MARK_EVOLVED="$CLAUDE_DIR/hooks/mark-evolved.sh"
if [ -f "$MARK_EVOLVED" ]; then
  # Verify marker path uses .claude/ prefix (not arbitrary location)
  if grep -q '\.claude/\.last-evolution' "$MARK_EVOLVED"; then
    # Verify it uses ACTUAL_ROOT resolution for worktree support
    if grep -q 'ACTUAL_ROOT' "$MARK_EVOLVED"; then
      result "PASS" "EV-4" "evolved artifact locations" ".claude/ subdir + worktree-aware"
    else
      ev4_ok=false
      result "FAIL" "EV-4" "evolved artifact locations" "no worktree resolution"
    fi
  else
    ev4_ok=false
    result "FAIL" "EV-4" "evolved artifact locations" "marker not in .claude/"
  fi
else
  result "FAIL" "EV-4" "evolved artifact locations" "mark-evolved.sh not found"
fi

# EV-5: mark-evolved.sh exists
if [ -f "$CLAUDE_DIR/hooks/mark-evolved.sh" ]; then
  result "PASS" "EV-5" "mark-evolved.sh exists" "found"
else
  result "FAIL" "EV-5" "mark-evolved.sh exists" "not found"
fi

# ===== TEAM PATTERNS (TP-1..2 + 4 SKIPs) =====

# TP-1: all agents have model
tp1_fails=""
for af in "$CLAUDE_DIR"/agents/*.md; do
  [ -f "$af" ] || continue
  fm=$(get_frontmatter "$af")
  if ! has_field "$fm" "model"; then
    tp1_fails+=" $(basename "$af" .md)"
  fi
done
if [ -z "$tp1_fails" ]; then
  result "PASS" "TP-1" "all agents have model" "all agents"
else
  result "FAIL" "TP-1" "all agents have model" "missing:${tp1_fails}"
fi

# TP-2: all agents have maxTurns
tp2_fails=""
for af in "$CLAUDE_DIR"/agents/*.md; do
  [ -f "$af" ] || continue
  fm=$(get_frontmatter "$af")
  if ! has_field "$fm" "maxTurns"; then
    tp2_fails+=" $(basename "$af" .md)"
  fi
done
if [ -z "$tp2_fails" ]; then
  result "PASS" "TP-2" "all agents have maxTurns" "all agents"
else
  result "FAIL" "TP-2" "all agents have maxTurns" "missing:${tp2_fails}"
fi

# TP-3: team lifecycle hooks registered (SubagentStart + SubagentStop + TaskCompleted)
tp3_missing=""
for event in SubagentStart SubagentStop TaskCompleted; do
  if ! python3 -c "
import json
with open('$CLAUDE_DIR/settings.json') as f:
    data = json.load(f)
assert '$event' in data.get('hooks', {}), 'missing'
" 2>/dev/null; then
    tp3_missing+=" $event"
  fi
done
if [ -z "$tp3_missing" ]; then
  result "PASS" "TP-3" "team lifecycle enforcement" "SubagentStart+SubagentStop+TaskCompleted registered"
else
  result "FAIL" "TP-3" "team lifecycle enforcement" "missing events:${tp3_missing}"
fi

# TP-4: team sizing — all agents in agent-overrides.md exist as files
tp4_fails=""
OVERRIDES="$CLAUDE_DIR/rules/project/agent-overrides.md"
if [ -f "$OVERRIDES" ]; then
  # Extract agent names from the inventory table (2nd column is a number = maxTurns)
  override_agents=$(grep -E '^\| [a-z]' "$OVERRIDES" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); if ($3 ~ /^[0-9]+$/) print $2}' | sort -u)
  while IFS= read -r aname; do
    [ -z "$aname" ] && continue
    if [ ! -f "$CLAUDE_DIR/agents/${aname}.md" ]; then
      tp4_fails+=" $aname"
    fi
  done <<< "$override_agents"
  agent_count=$(echo "$override_agents" | grep -c . || true)
  if [ -z "$tp4_fails" ]; then
    result "PASS" "TP-4" "team sizing compliance" "$agent_count agents in overrides, all exist"
  else
    result "FAIL" "TP-4" "team sizing compliance" "missing agent files:${tp4_fails}"
  fi
else
  result "FAIL" "TP-4" "team sizing compliance" "agent-overrides.md not found"
fi

# TP-5: task assignment — CLAUDE.md team table matches agent-overrides.md team table
tp5_ok=true
if [ -f "$CLAUDE_MD" ] && [ -f "$OVERRIDES" ]; then
  # Extract team names from CLAUDE.md delegation table
  claude_teams=$(grep -E '^\| (quality|build|testing|docs|workflow) ' "$CLAUDE_MD" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}' | sort)
  # Extract team names from agent-overrides.md team table
  override_teams=$(grep -E '^\| (quality|build|testing|docs|workflow) ' "$OVERRIDES" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}' | sort)
  if [ "$claude_teams" = "$override_teams" ] && [ -n "$claude_teams" ]; then
    team_count=$(echo "$claude_teams" | wc -l)
    result "PASS" "TP-5" "task assignment protocol" "$team_count teams consistent across CLAUDE.md and overrides"
  else
    tp5_ok=false
    result "FAIL" "TP-5" "task assignment protocol" "team tables diverge between CLAUDE.md and overrides"
  fi
else
  result "FAIL" "TP-5" "task assignment protocol" "CLAUDE.md or agent-overrides.md not found"
fi

# TP-6: communication protocol — SubagentStop hook has logging/reporting
tp6_ok=true
SUBAGENT_STOP_HOOK="$CLAUDE_DIR/hooks/subagent-stop-report.sh"
if [ -f "$SUBAGENT_STOP_HOOK" ]; then
  # Verify it logs agent info (agent_type, summary) and writes to log file
  has_agent_type=false; has_log_write=false
  grep -q 'agent_type' "$SUBAGENT_STOP_HOOK" && has_agent_type=true
  grep -q 'LOG_FILE\|subagent\.log\|>>' "$SUBAGENT_STOP_HOOK" && has_log_write=true
  if $has_agent_type && $has_log_write; then
    result "PASS" "TP-6" "communication protocol" "SubagentStop logs agent_type + writes log"
  else
    missing=""
    $has_agent_type || missing+=" agent_type"
    $has_log_write || missing+=" log_write"
    result "FAIL" "TP-6" "communication protocol" "missing:${missing}"
  fi
else
  result "FAIL" "TP-6" "communication protocol" "subagent-stop-report.sh not found"
fi

TOTAL=$((PASS + FAIL + SKIP))
echo "---"
echo "TOTAL: $TOTAL  PASS: $PASS  FAIL: $FAIL  SKIP: $SKIP"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
