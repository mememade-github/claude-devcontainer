# Iterative Retrieval Pattern

When retrieving context for subagent tasks, use progressive refinement:

## 4-Phase Loop (max 3 cycles)

1. **DISPATCH**: Broad keyword search (Grep/Glob)
2. **EVALUATE**: Score relevance (0-1) of each result
3. **REFINE**: Update search with learned terminology, exclude irrelevant
4. **LOOP**: Repeat until 3+ high-relevance (>0.7) files found

## When to Apply

- Subagent prompts that need codebase context
- Bug fixes where the root cause location is unknown
- Feature implementations spanning unknown files

## Key Principles

- Start broad, narrow progressively
- Learn codebase terminology in first cycle
- Track explicitly what context is missing
- Stop at "good enough" (3 high-relevance files > 10 mediocre ones)
