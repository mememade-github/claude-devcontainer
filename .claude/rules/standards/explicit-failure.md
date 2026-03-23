# Explicit Failure Standard

## Source
- Derived: Operationalization of CLAUDE.md Coding Rule #7 and Governance Immutable
  Principle #7 ("No form of arbitrary success is permitted. Every operation must
  genuinely succeed or explicitly fail")
- Official: Claude Code Best Practices — "Address root causes, not symptoms"
  (https://code.claude.com/docs/en/best-practices)
- Derived: <internal-rag> explicit failure enforcement audit (2026-03)
- Last verified: 2026-03-23

## Relationship to Existing Standards

This standard operationalizes Governance Immutable Principle #7 into concrete,
checkable rules for shell scripts. It does NOT redefine:

- **Hook categories**: defined in hooks-and-lifecycle.md § Blocking vs Non-Blocking
- **Exit code semantics**: defined in hooks-and-lifecycle.md § Hook JSON Protocol
- **Blocking schemas**: defined in hooks-and-lifecycle.md § Stop Event Protocol
- **Hook event behavior**: defined in hooks-and-lifecycle.md § Hook Events

This standard ADDS: error visibility and honesty requirements per hook category.

## Standard

### Core Principle

**No form of arbitrary success is permitted.**

When an error occurs in a shell script:
1. Errors MUST be **visible** — stderr propagates naturally
2. Error state MUST be **honest** — no default-value injection to masquerade as success
3. Error paths MUST be **explicit** — fail toward safety under uncertainty

### Prohibited Patterns

| Pattern | Violation | Replacement |
|---------|-----------|-------------|
| `cmd 2>/dev/null` (data write) | Swallows diagnostic stderr on data loss | Remove; let stderr propagate |
| `cmd \|\| true` (log write) | Disguises write failure as success | Remove; use explicit error check |
| `cmd \|\| echo 0` (stat for arithmetic) | Injects epoch 0 or size 0, corrupts downstream calculations | Explicit error path per hook category |
| `exit 0` on error state | Reports error as success to caller | Appropriate exit code per hook category |

### Permitted Patterns

The following `2>/dev/null` usages are explicitly permitted as internal conventions.
Each MUST have an adjacent comment stating intent.

**P-1. Capability detection**
```bash
# Intentional: graceful fallback when git is not installed
if command -v git &>/dev/null; then
```

**P-2. ACTUAL_ROOT resolution** (hooks-and-lifecycle.md § Worktree Compatibility)
```bash
# Worktree resolution: may not be in a git repo
GIT_COMMON=$(git -C "$PROJECT_DIR" rev-parse --git-common-dir 2>/dev/null)
```

**P-3. Honest uncertainty fallback**
```bash
# Honest fallback: "unknown" explicitly signals uncertainty
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
```
The fallback value MUST be an honest signal of uncertainty ("unknown", "?", ""),
never a value that could be confused with valid data (0, "main", "success").

**P-4. Cross-platform compatibility (transition, not termination)**
```bash
# Cross-platform: Linux stat, then macOS stat
MTIME=$(stat -c '%Y' "$F" 2>/dev/null || stat -f '%m' "$F" 2>/dev/null)
```
The first `2>/dev/null` enables fallback to the next variant.
The chain MUST NOT end with `|| echo 0`; if all variants fail, handle explicitly.

**P-5. Optional resource probing**
```bash
# Optional: resource may not exist
WIP_DIRS=$(ls -d "$ROOT"/wip/*/ 2>/dev/null)
```

### Error Handling per Hook Category

Hook categories are defined in hooks-and-lifecycle.md § Blocking vs Non-Blocking.
Blocking schemas are defined in hooks-and-lifecycle.md § Hook Event table.

**Observation hooks** (exit 0 always, append-only):
```bash
# Data write failure: stderr warning, exit 0 preserved
if ! printf '%s\n' "$LINE" >> "$FILE"; then
  echo "WARN: observation write failed: $FILE" >&2
fi
```

**Gate hooks** — blocking mechanism depends on event type:

PreToolUse gates (exit 2 + stderr per hooks-and-lifecycle.md):
```bash
MTIME=$(stat -c %Y "$MARKER" 2>/dev/null) || {
  echo "FAIL: cannot read marker: $MARKER" >&2
  exit 2
}
```

Stop gates (JSON decision + exit 0 per hooks-and-lifecycle.md § Stop Event Protocol):
```bash
MTIME=$(stat -c %Y "$MARKER" 2>/dev/null) || {
  jq -n --arg m "$MARKER" '{
    decision: "block",
    reason: ("Cannot read marker: " + $m + ". Resolve before stopping.")
  }'
  exit 0
}
```

**Context-injection hooks** (exit 0 always, inject additionalContext):
```bash
# Log write failure: stderr warning, context injection independent
if ! printf '...\n' >> "$LOG"; then
  echo "WARN: log write failed: $LOG" >&2
fi
```

**Suggestion hooks** (exit 0 always, advisory):
```bash
# State read failure: stderr warning, explicit reset
if ! COUNT=$(cat "$COUNTER_FILE" 2>/dev/null); then
  echo "WARN: counter read failed: $COUNTER_FILE" >&2
  COUNT=0  # explicit reset with warning, not silent
fi
```

**Utility scripts** (not hooks; called by agent or other scripts):
```bash
set -euo pipefail
# Critical operations protected by set -e (auto exit 1 on failure)
touch "$MARKER"
```

**Helper scripts** (called by other hooks, not registered in settings.json):
- Follow error policy of caller's category
- MUST NOT swallow errors that affect caller's output

### Scope

This standard applies to:
- `.claude/hooks/*.sh` — per hook category above
- `scripts/**/*.sh` — as utility scripts
- Any new shell script added to `.claude/` or `scripts/`

## Compliance Checks

- [ ] No `2>/dev/null` on data write operations (printf >>, echo >>, touch)
- [ ] No `|| true` on log/state write operations
- [ ] No `|| echo 0` as arithmetic fallback (timestamps, sizes, counters)
- [ ] Every remaining `2>/dev/null` has adjacent comment citing permitted pattern (P-1..P-5)
- [ ] Gate hooks: state read failure → block via event-appropriate schema
      (PreToolUse: exit 2 + stderr; Stop: JSON decision block + exit 0)
- [ ] Observation hooks: write failure → stderr warning (exit 0 preserved)
- [ ] Context-injection hooks: log write failure → stderr warning (exit 0 preserved)
- [ ] Utility scripts: `set -euo pipefail` is set
- [ ] Cross-platform stat chains do NOT end with `|| echo 0`
- [ ] Helper scripts: errors propagate to caller, not swallowed

## References

- CLAUDE.md § Coding Rules #7 (explicit failure, no arbitrary success)
- `.claude/rules/standards/governance.md` § Immutable Principles #7
- `.claude/rules/standards/hooks-and-lifecycle.md` § Blocking vs Non-Blocking
- `.claude/rules/standards/hooks-and-lifecycle.md` § Hook JSON Protocol
- `.claude/rules/standards/hooks-and-lifecycle.md` § Stop Event Protocol
- `.claude/rules/standards/hooks-and-lifecycle.md` § Worktree Compatibility
