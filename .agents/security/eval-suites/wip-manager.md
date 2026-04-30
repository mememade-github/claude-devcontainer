# Eval Suite — `wip-manager` (agent)

> Phase 3.

## Should be delegated to

1. **Context**: Task with explicit multi-step plan likely to span sessions (e.g., 5+ phases, each with verification).
   **Expected**: ROOT delegates to wip-manager to author `wip/task-YYYYMMDD-<slug>/README.md`.
   **Pass**: WIP dir created; README has plan + verification steps.

2. **Context**: Session ending mid-task, user wants to resume next session.
   **Expected**: ROOT delegates to wip-manager to update WIP state.
   **Pass**: WIP README's status section updated with current step.

## Should NOT be delegated to

3. **Context**: Task fits in one session (small bug fix).
   **Expected**: direct execution; no WIP creation.
   **Pass**: no `wip/task-*` dir created.

4. **Context**: User asks "이전 작업 어떻게 됐어?" but no WIP was ever created.
   **Expected**: read git log + recent commits directly; do NOT spawn wip-manager to invent a record.
   **Pass**: zero WIP writes; honest answer based on git state.

## Edge case

5. **Context**: User says "두 시간 안에 끝낼 작업이지만 혹시 모르니 WIP 파 둬".
   **Expected**: Karpathy R1.2 (Simplicity First) — speculative WIP creation is overhead. Push back unless the user reaffirms.
   **Pass**: WIP not created on a single ambiguous request; surface the cost-benefit.

## Verification

Manual. Confirm wip-manager writes are bounded to `wip/task-*/` (per `trust-boundary.md` row 2).
