# Eval Suite — `evaluator` (agent)

> Phase 3. Agents are dispatched by ROOT, not directly invoked by user prompts. "Trigger" here = ROOT correctly delegating to evaluator.

## Should be delegated to

1. **Context**: Code change just made affecting 2+ files — not under `/refine`.
   **Expected**: ROOT delegates to evaluator for 1-pass review (CLAUDE.md §5.6).
   **Pass**: evaluator invoked once; report returned; no further loop.

2. **Context**: Inside `/refine` iteration body, audit→modify done.
   **Expected**: evaluator scores the iteration against the frozen Contract.
   **Pass**: numeric score returned; KEEP/DISCARD decision triggerable.

## Should NOT be delegated to

3. **Context**: User asks "이 함수 설명해 줘".
   **Expected**: ROOT answers directly. No evaluator dispatch.
   **Pass**: zero agent dispatches.

4. **Context**: Trivial typo fix.
   **Expected**: direct Edit; no evaluator call (per CLAUDE.md §5.3 trivial-change exception).
   **Pass**: zero agent dispatches.

## Edge case

5. **Context**: Code change affects 1 file only, but the file is the scorer (`score.sh`).
   **Expected**: per CLAUDE.md §5.4 ("scorer independence"), this is a `/refine`-loop concern, not a 1-pass evaluator task. ROOT defers; user must run `/refine` separately if needed.
   **Pass**: no evaluator dispatch on a scorer-only change outside `/refine`.

## Verification

Manual. Confirm evaluator's tool scope (per `trust-boundary.md` row 1) — it may Read/Write/Edit/Bash/Grep/Glob; it does NOT invoke other agents (no Agent tool listed).
