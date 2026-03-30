---
name: refine
description: Autonomous iterative refinement loop — autoresearch pattern with Discovery Phase
argument-hint: "<task-description> [--max-iter N] [--threshold 0.85] [--project PATH] [--agent TYPE]"
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent
---

# /refine — Autonomous Iterative Refinement Loop

Autoresearch pattern: discover → modify → verify → keep/discard → repeat.

Core mapping from [autoresearch](https://github.com/karpathy/autoresearch):

| autoresearch | /refine v3 | /refine v4 |
|---|---|---|
| agent reads `prepare.py` + `train.py` | — | **Discovery Phase** (reads project → builds Contract) |
| `prepare.py` (immutable evaluation) | `rubrics/default.yml` (rubric) | **Verification Contract** (immutable, per-run) |
| `val_bpb` (single scalar metric) | Opus 4-dim weighted score | **Contract metric** (test pass rate, error count, etc.) |
| `uv run train.py > run.log 2>&1` | Claude runs tools | **Contract.verify_cmd** execution |
| `grep "^val_bpb:" run.log` | Claude interprets evidence | **Contract.parse** — mechanical extraction, no judgment |
| `new < old` → keep | `new > prev_best` → keep | `new > prev_best` → keep (unchanged) |
| `git reset` → discard | `git checkout -- .` → discard | `git checkout -- .` → discard (unchanged) |

## Arguments

- `<task-description>`: What to improve (required)
- `--max-iter N`: Maximum iterations (default: 10)
- `--threshold T`: Target score 0.0-1.0 (default: 0.85)
- `--project PATH`: Project path (default: CLAUDE_PROJECT_DIR)
- `--agent TYPE`: Agent to spawn for code changes (default: none — main agent acts directly)

## Protocol

### Step 0: Initialize

```bash
TASK_ID="refine-$(date +%Y%m%d-%H%M%S)"
PROJECT="${PROJECT:-$CLAUDE_PROJECT_DIR}"
THRESHOLD="${THRESHOLD:-0.85}"
MAX_ITER="${MAX_ITER:-10}"
REFINE_DIR="${PROJECT}/.claude/skills/refine"
```

### Step 1: Discover (zero-memory ground-truth discovery)

Read the project and construct a Verification Contract. This is the autoresearch equivalent of the agent reading `prepare.py` and `train.py` to understand the experiment setup.

**Every /refine run rediscovers from scratch. No cached config. No --verify flag. Ground truth only.**

1. **Read the project** — Glob, Read, Grep to understand structure.
2. **Find verification infrastructure** — use your intelligence to discover:
   - Test suites (any framework, any language)
   - Build systems (any tool)
   - Linters, type checkers
   - Existing verification scripts
   - Any command that produces objective, repeatable output
3. **Construct the Verification Contract**:

```json
{
  "mode": "objective|generated|rubric",
  "verify_cmd": "<command that produces measurable output>",
  "parse": "<how to extract the metric from verify_cmd output>",
  "metric": "<metric name — e.g. pass_rate, error_count, exit_code>",
  "direction": "higher|lower|zero",
  "discovery_log": "<what you found and why you chose this>"
}
```

**Contract modes**:

| Mode | When | How score is produced |
|---|---|---|
| `objective` | Project has tests/build/lint | verify_cmd output → mechanical parsing → number |
| `generated` | No infra exists; agent writes tests/scripts | Same as objective, but verification was created in this step |
| `rubric` | No objective metric possible (last resort) | rubrics/default.yml 4-dim scoring (v3 behavior) |

4. **If no verification infrastructure exists** (generated mode):
   - Write tests or a verification script appropriate for the task
   - Tests MUST fail on at least one case in the current state (TDD RED principle)
   - These tests become the Contract's verify_cmd
   - Once written, the tests are FROZEN — treat them as part of the Contract

5. **If no objective metric is possible** (rubric fallback):
   - Use `rubrics/default.yml` with v3 evaluation protocol
   - This is the last resort, not the default

6. **Validate the Contract**:
   - Run `verify_cmd` once. It must produce parseable output.
   - The baseline score must NOT be perfect. If it is, the Contract cannot distinguish improvement.
   - If validation fails, reconstruct the Contract.

7. **Freeze the Contract** — write to `.refinement-active` marker:

```bash
cat > .claude/.refinement-active <<MARKER
{
  "task_id": "$TASK_ID",
  "threshold": $THRESHOLD,
  "max_iterations": $MAX_ITER,
  "started": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "contract": {
    "mode": "<mode>",
    "verify_cmd": "<command>",
    "parse": "<extraction method>",
    "metric": "<name>",
    "direction": "<higher|lower|zero>"
  }
}
MARKER
```

**After this point, the Contract is IMMUTABLE for the rest of the loop.**

### Step 2: Baseline (attempt 0)

Run the Contract to establish the baseline score.

1. **Execute**: `bash -c "<Contract.verify_cmd>" 2>&1`
2. **Parse**: Extract the metric using Contract.parse
3. **Normalize**: Convert to a 0.0-1.0 score:
   - `pass_rate`: passed / total (e.g., "8 passed, 2 failed" → 0.8)
   - `error_count`: 1.0 - min(errors / baseline_errors, 1.0) (fewer errors = higher score)
   - `exit_code`: 1.0 if 0, else 0.0
   - Custom: define normalization in Contract.parse
4. **Record**:

```bash
bash "$REFINE_DIR/memory-ops.sh" add \
  --task "$TASK_ID" --agent "baseline" --score "$BASELINE_SCORE" \
  --metric-type "<mode>" --metric-raw "<raw verify_cmd output>" \
  --result "Baseline" --feedback "<one-line: what the metric shows>"
```

### Step 3: Modify

**If `--agent` specified**: Spawn the agent with the task description + trajectory context.
**If no `--agent`** (default): Act directly — read code, make changes with Edit/Write.

After modification, `git add` changed files. Do NOT commit yet — commit only on keep.

### Step 4: Evaluate

Run the Contract again. This is the `grep "^val_bpb:" run.log` equivalent.

**For objective/generated mode** (no agent judgment):
1. Execute: `bash -c "<Contract.verify_cmd>" 2>&1`
2. Parse: Same method as baseline
3. Normalize: Same method as baseline
4. The number IS the score. No interpretation. No judgment.

**For rubric mode** (fallback only):
1. Run verification tools appropriate for the project
2. Read `cat "$REFINE_DIR/rubrics/default.yml"`
3. Score each dimension (0.0, 0.25, 0.5, 0.75, 1.0) citing evidence
4. Weighted average → score

### Step 5: Keep or Discard (binary decision)

```bash
PREV_BEST=$(bash "$REFINE_DIR/memory-ops.sh" best --task "$TASK_ID" | jq -r '.score // "0"')
```

| Condition | Action | autoresearch analog |
|-----------|--------|---------------------|
| `SCORE > PREV_BEST` | **KEEP** — `git commit -m "refine: $TASK_ID iteration $N — score $SCORE"` | `val_bpb` improved → keep commit |
| `SCORE <= PREV_BEST` | **DISCARD** — `git checkout -- .` | `val_bpb` worse → `git reset` |
| `SCORE >= THRESHOLD` | **ACCEPT** — exit loop | N/A (autoresearch runs forever) |

### Step 6: Record

```bash
bash "$REFINE_DIR/memory-ops.sh" add \
  --task "$TASK_ID" --agent "${AGENT:-self}" --score "$SCORE" \
  --metric-type "<mode>" --metric-raw "<raw output>" \
  --result "<one-line: what changed, KEEP/DISCARD>" \
  --feedback "<metric summary>"
```

### Step 7: Check Termination

```bash
ITERATION=$(bash "$REFINE_DIR/memory-ops.sh" count --task "$TASK_ID")
```

| Condition | Action |
|-----------|--------|
| `SCORE >= THRESHOLD` | **ACCEPT** — remove marker, report success |
| `ITERATION >= MAX_ITER` | **STOP** — remove marker, report best result |
| Otherwise | Continue to Step 8 |

On ACCEPT or STOP:
```bash
rm -f .claude/.refinement-active
bash "$REFINE_DIR/memory-ops.sh" best --task "$TASK_ID"
```

### Step 8: Trajectory + Next Iteration

```bash
TRAJECTORY=$(bash "$REFINE_DIR/trajectory.sh" --task "$TASK_ID" --max 5)
```

Return to **Step 3** with trajectory as context. Use it to:
- Avoid repeating failed approaches (DISCARD entries)
- Build on successful attempts (KEEP entries)
- Focus on what the metric reveals as weakest

**Continue iterating. Do not ask for permission to continue.**

## Discovery Protocol

These rules govern Step 1 (Discover). They replace v3's Evaluation Protocol.

1. **Zero-memory** — every /refine run rediscovers from scratch. Do not rely on prior sessions, config files, or cached knowledge. Read the project's current state as ground truth.
2. **Contract is immutable** — once frozen (end of Step 1), verify_cmd, parse, metric, and direction cannot be modified for the rest of the loop. This is the autoresearch `prepare.py` principle.
3. **Metric over judgment** — if an objective metric exists (tests, build, lint), use it. Agent judgment (rubric scoring) is the last resort, not the default.
4. **Baseline must not be perfect** — if the baseline score is already 1.0 or at threshold, the Contract cannot distinguish improvement. Reconstruct with a more discriminating metric.
5. **Generated tests must fail** — when writing tests in `generated` mode, at least one test must fail in the current state (TDD RED). Tests that all pass cannot drive improvement.
6. **Parse failure = score 0** — if verify_cmd output cannot be parsed into a number, treat as crash (score 0, DISCARD). Same as autoresearch treating OOM as failure.

## Design Principles

1. **autoresearch core**: discover → modify → verify → keep/discard. Git is the safety net.
2. **Contract as prepare.py**: Discovery builds it, loop uses it immutably. Agent cannot manipulate evaluation.
3. **Zero-memory discovery**: every run reads project ground truth. No config files, no --verify flags.
4. **Metric over judgment**: numbers from tools, not scores from LLM. Rubric is fallback only.
5. **NEVER STOP**: iterate until threshold or max_iter. Do not pause for confirmation.
6. **Self-contained**: SKILL.md + rubric(fallback) + memory-ops + trajectory. Portable with `.claude/`.
