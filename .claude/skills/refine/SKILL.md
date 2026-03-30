---
name: refine
description: Autonomous iterative refinement loop — autoresearch pattern + poetiq feedback + Opus rubric evaluation
argument-hint: "<task-description> [--max-iter N] [--threshold 0.8] [--project PATH] [--agent TYPE] [--no-llm]"
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent
---

# /refine — Autonomous Iterative Refinement Loop

3-layer architecture:
- **Layer 1 (autoresearch)**: modify → run → measure → keep/discard → repeat
- **Layer 2 (poetiq)**: hierarchical feedback + trajectory injection
- **Layer 3 (Opus rubric)**: LLM evaluation with locked rubric for non-testable dimensions

## Arguments

- `<task-description>`: What to improve (required)
- `--max-iter N`: Maximum iterations (default: 10)
- `--threshold T`: Target score 0.0-1.0 (default: 0.85)
- `--project PATH`: Project path (default: CLAUDE_PROJECT_DIR)
- `--agent TYPE`: Agent to spawn for code changes (default: none — main agent acts directly)
- `--no-llm`: Disable Layer 3 (Opus rubric evaluation), use deterministic scoring only

## Protocol

### Step 0: Initialize

```bash
TASK_ID="refine-$(date +%Y%m%d-%H%M%S)"
PROJECT="${PROJECT:-$CLAUDE_PROJECT_DIR}"
THRESHOLD="${THRESHOLD:-0.85}"
MAX_ITER="${MAX_ITER:-10}"

# refinement-gate marker (Stop hook checks this)
echo "{\"task_id\":\"$TASK_ID\",\"threshold\":$THRESHOLD,\"max_iterations\":$MAX_ITER,\"started\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > .claude/.refinement-active
```

Verify infrastructure exists (scripts are co-located with this SKILL.md for portability):
```bash
REFINE_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/skills/refine"
[ -f "$REFINE_DIR/verify-score.sh" ] || { echo "Refinement infrastructure not found at $REFINE_DIR"; exit; }
```

### Step 1: Baseline

Run verification on the current state BEFORE any changes. This is attempt 0.

```bash
RESULT=$(bash "$REFINE_DIR/verify-score.sh" --project "$PROJECT" --score)
BASELINE_SCORE=$(echo "$RESULT" | jq -r '.score')
```

Record baseline:
```bash
bash "$REFINE_DIR/memory-ops.sh" add \
  --task "$TASK_ID" --agent "baseline" --score "$BASELINE_SCORE" \
  --result "Initial state" --feedback "$(echo "$RESULT" | jq -r '.feedback' | head -20)"
```

### Step 2: Modify (autoresearch pattern)

**If `--agent` specified**: Spawn the agent.
```
Agent(prompt="<task-description>\n\nProject: $PROJECT\n\nFix the issues and improve the code.",
      subagent_type=<agent-type>)
```

**If no `--agent`** (default): Act directly. Read the project code, understand the task,
make changes yourself. This is the autoresearch pattern — the agent IS the researcher.

After modification, `git add` changed files (do NOT commit yet — commit only on keep).

### Step 3: Score (3-layer)

#### 3a. D_score (deterministic — Layer 1)

```bash
RESULT=$(bash "$REFINE_DIR/verify-score.sh" --project "$PROJECT" --score)
D_SCORE=$(echo "$RESULT" | jq -r '.score')
```

#### 3b. Structured feedback (poetiq hierarchical — Layer 2)

```bash
FEEDBACK_XML=$(echo "$RESULT" | bash "$REFINE_DIR/feedback-builder.sh")
```

This produces 3-tier feedback:
- Tier 1 (Fatal): Build failures — fix these first
- Tier 2 (Structural): Type errors, lint violations
- Tier 3 (Behavioral): Test failures

#### 3c. L_score (Opus rubric — Layer 3, skip if --no-llm)

Read the locked rubric:
```bash
RUBRIC=$(cat "$REFINE_DIR/rubrics/default.yml")
```

Read the diff of changes made in this iteration:
```bash
DIFF=$(git diff HEAD)
```

Evaluate the DIFF against the rubric. For EACH dimension in the rubric:
1. Read the anchor criteria for that dimension
2. Examine the diff for evidence
3. Select the anchor level that matches (0.0, 0.25, 0.5, 0.75, 1.0)
4. Cite specific file:line as evidence

Output as JSON:
```json
{
  "documentation": {"score": 0.5, "evidence": "src/foo.py:42 — docstring exists but missing params"},
  "design": {"score": 0.75, "evidence": "src/bar.py:10-30 — follows existing factory pattern"},
  "completeness": {"score": 0.75, "evidence": "handles main case + 2 edge cases, missing timeout"},
  "consistency": {"score": 1.0, "evidence": "naming follows project snake_case convention throughout"}
}
```

Compute L_score as weighted average per rubric dimension weights.

#### 3d. Combined score

```bash
# Feed metrics + llm_score to score.sh for hybrid calculation
COMBINED=$(echo "$METRICS" | jq --argjson llm "$L_SCORE" '. + {llm_score: $llm}' | bash "$REFINE_DIR/score.sh")
SCORE=$(echo "$COMBINED" | jq -r '.score')
```

If `--no-llm`: L_score is null, score.sh falls back to pure D_score.

### Step 4: Keep or Discard (autoresearch pattern)

Compare against previous best:

```bash
PREV_BEST=$(bash "$REFINE_DIR/memory-ops.sh" best --task "$TASK_ID" | jq -r '.score // "0"')
```

**If SCORE > PREV_BEST** (improved):
```bash
git commit -m "refine: $TASK_ID iteration $ITERATION — score $SCORE"
```
→ Status: **KEEP** — branch advances (autoresearch pattern).

**If SCORE <= PREV_BEST** (same or worse — DEGRADATION):
```bash
git checkout -- .
```
→ Status: **DISCARD** — reset to last good state (autoresearch pattern). DEGRADATION detected, changes reverted.

**If SCORE >= THRESHOLD**:
→ Status: **ACCEPT** — target reached, exit loop.

### Step 5: Record

```bash
bash "$REFINE_DIR/memory-ops.sh" add \
  --task "$TASK_ID" --agent "${AGENT:-self}" --score "$SCORE" \
  --result "<one-line: what changed, keep/discard>" \
  --feedback "$FEEDBACK_XML"
```

### Step 6: Check Termination

```bash
ITERATION=$(bash "$REFINE_DIR/memory-ops.sh" count --task "$TASK_ID")
```

| Condition | Action |
|-----------|--------|
| `SCORE >= THRESHOLD` | **ACCEPT** — remove marker, report success |
| `ITERATION >= MAX_ITER` | **STOP** — remove marker, report best result |
| Otherwise | Continue to Step 7 |

On ACCEPT or STOP:
```bash
rm -f .claude/.refinement-active
bash "$REFINE_DIR/memory-ops.sh" best --task "$TASK_ID"
```

### Step 7: Trajectory + Next Iteration (poetiq pattern)

Build improvement trajectory (worst→best, max 5 — poetiq create_examples pattern):

```bash
TRAJECTORY=$(bash "$REFINE_DIR/trajectory.sh" --task "$TASK_ID" --max 5)
```

Return to **Step 2** with trajectory as context:

The trajectory shows past attempts with their scores and structured feedback.
Use it to:
- Avoid repeating failed approaches
- Build on partially successful attempts
- Focus on the specific tier (fatal → structural → behavioral) that needs fixing

**Continue iterating. Do not ask for permission to continue.**

## Design Principles

1. **autoresearch core**: modify → measure → keep/discard. No isolation. Git is the safety net.
2. **poetiq feedback**: 3-tier hierarchical, not flat pass/fail. Trajectory worst→best.
3. **Opus rubric**: locked anchors + evidence citation. Defends against self-preference bias.
4. **Hybrid scoring**: D_score * 0.6 + L_score * 0.4. D_score is the foundation.
5. **NEVER STOP**: iterate until threshold or max_iter. Do not pause for confirmation.
6. **Any agent or self**: no restriction on who makes changes. Main agent can act directly.
7. **Self-contained skill**: All scripts (verify-score, memory-ops, score, feedback-builder,
   trajectory) and rubrics live in this directory alongside SKILL.md. This ensures portability —
   any project that syncs `.claude/skills/` automatically receives the full /refine infrastructure.
   `$REFINE_DIR` resolves to `$CLAUDE_PROJECT_DIR/.claude/skills/refine` in every context.
