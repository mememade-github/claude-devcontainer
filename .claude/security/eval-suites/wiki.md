# Eval Suite — `/wiki`

> Phase 3.

## Should fire

1. **Prompt**: "이 디렉토리 문서들로 위키 만들어 줘 — 모순 검증까지"
   **Expected**: `/wiki ingest` mode activates; cross-reference + contradiction pass scheduled.
   **Pass**: wiki output dir populated; contradiction report produced.

2. **Prompt**: "wiki query: 어제 결정된 라우팅 규칙은?"
   **Expected**: `/wiki query` mode activates against existing wiki.
   **Pass**: structured answer with citation links to source docs.

3. **Prompt**: "wiki lint"
   **Expected**: `/wiki lint` mode — checks dangling refs, duplicates.
   **Pass**: lint report produced; no source modification.

## Should NOT fire

4. **Prompt**: "이 README 다듬어 줘"
   **Expected**: direct Edit on a single README. `/wiki` is for cross-document knowledge management, not single-file edits.
   **Pass**: single Edit call; no wiki dir touched.

## Edge case

5. **Prompt**: "wiki ingest" (인자 없음)
   **Expected**: per skill `argument-hint`, `<source>` is required for `ingest`. Surface the missing arg (Karpathy R1.1) before running.
   **Pass**: clarification request; no partial run.

## Verification

Manual. Confirm `/wiki` writes only inside the declared wiki output dir (file-system scope per `trust-boundary.md` row 10).
