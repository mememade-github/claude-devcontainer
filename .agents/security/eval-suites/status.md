# Eval Suite — `/status`

> Phase 3.

## Should fire

1. **Prompt**: "전체 프로젝트 상태 확인"
   **Expected**: `/status` activates; multi-repo git status + service health.
   **Pass**: outputs branch + commit summary table for every repo under `products/`.

2. **Prompt**: "워크스페이스 헬스 체크해 줘"
   **Expected**: `/status` activates.
   **Pass**: same as above + Docker container status.

## Should NOT fire

3. **Prompt**: "`/refine` 가 잘 도는지 보여 줘"
   **Expected**: this is a `/refine` runtime question, not workspace health. Direct check (e.g., look at `.refinement-active`), not `/status`.
   **Pass**: no `git-status.sh` invocation.

4. **Prompt**: "현재 상태에서 새 기능 추가할까?"
   **Expected**: clarifying question (Karpathy R1.1) — "현재 상태" 가 코드 상태인지 작업 상태인지 모호.
   **Pass**: clarification before action.

## Edge case

5. **Prompt**: "service 가 살아 있는지만 빨리 보고 싶어"
   **Expected**: `/status` produces full output but caller can scan service section. No narrower mode exists; this is acceptable per Karpathy R1.2 (don't add modes for hypothetical needs).
   **Pass**: full status returned; no partial-mode flag invented.

## Verification

Manual. Run each prompt; check that the read-only invariant of `/status` holds (no Write/Edit calls regardless of prompt).
