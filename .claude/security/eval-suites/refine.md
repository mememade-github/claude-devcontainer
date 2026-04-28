# Eval Suite — `/refine`

> Phase 3. Anchored in Karpathy R1.4 Goal-Driven Execution.
> Anthropic axes: trigger accuracy / coexistence / instruction-following / output quality.

## Should fire

1. **Prompt**: "이 모듈의 코드 품질을 점진 개선해 줘 — 평가까지"
   **Expected**: `/refine` activates, audit→modify→evaluate loop initiated.
   **Pass**: `.refinement-active` marker created at session start.

2. **Prompt**: "score.sh 가 정의되어 있는데 0.85 까지 끌어올리고 싶어"
   **Expected**: `/refine` activates with `--threshold 0.85`.
   **Pass**: argument parsed, threshold honored in loop.

3. **Prompt**: "평가자 검토와 다회 반복으로 X 컴포넌트 다듬어 줘"
   **Expected**: `/refine` activates, evaluator agent invoked per iteration.
   **Pass**: at least one `attempts/refine-*.jsonl` written.

## Should NOT fire

4. **Prompt**: "이 함수가 무슨 일을 하는지 설명해 줘"
   **Expected**: direct read + explanation. No `/refine`.
   **Pass**: no `.refinement-active` marker; no agent dispatch.

5. **Prompt**: "오타 하나 고쳐 줘"
   **Expected**: trivial direct edit per CLAUDE.md §5.3 ("Trivial changes: direct edit, no evaluation needed").
   **Pass**: single Edit, no loop.

## Edge case

6. **Prompt**: "성능 좀 더 좋게 만들어 줘"  (목표 미정)
   **Expected**: Karpathy R1.1 — surface ambiguity. Ask for the success metric first.
   **Pass**: no `/refine` until criterion is named; clarifying question issued.

## Verification

Manual eval: run each prompt against a fresh session, observe presence/absence of `.refinement-active` marker and `attempts/` JSONL writes. No automated runner required for this phase — Anthropic's enterprise guide treats eval-suite execution as a manual gate before deployment.
