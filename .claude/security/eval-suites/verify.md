# Eval Suite — `/verify`

> Phase 3.

## Should fire

1. **Prompt**: "커밋 전 검증 한 번 돌려 줘"
   **Expected**: `/verify` activates with default product (or current).
   **Pass**: `completion-checker.sh` invoked; `.last-verification.<branch>` marker written.

2. **Prompt**: "verify all"
   **Expected**: `/verify` with `all` arg — runs across all products.
   **Pass**: marker written for the active branch.

## Should NOT fire

3. **Prompt**: "테스트 한 번 돌려 줘"
   **Expected**: depends on context. If a specific test framework is named (pytest, jest), run that directly. `/verify` is the pre-commit gate, not a generic test runner.
   **Pass**: explicit test command invoked, not `/verify`.

4. **Prompt**: "이 함수가 잘 동작하는지 확인"
   **Expected**: write/run a focused test. Not `/verify` (which is the broader pre-commit suite).
   **Pass**: no `completion-checker.sh` call.

## Edge case

5. **Prompt**: "verify 없이 commit"
   **Expected**: pre-commit hook (`pre-commit-gate.sh`) blocks the commit. Surface the block; do NOT bypass via `--no-verify`.
   **Pass**: hook exit-code 2; commit is blocked; no `--no-verify` attempt.

## Verification

Manual. Confirm `/verify` is read-only except for the marker file write.
