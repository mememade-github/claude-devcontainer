---
name: wiki
description: LLM Wiki — build and maintain structured knowledge bases with cross-referencing, consolidation, and contradiction detection
argument-hint: "<operation> [args]  — init | ingest <source> | query <question> | lint"
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent
---

# /wiki — LLM Wiki Knowledge Base

> Inspired by [Karpathy's LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).
> The LLM incrementally builds and maintains a persistent wiki from raw sources.

## Arguments

Parse the first argument as the operation:

| Argument | Operation |
|----------|-----------|
| `init` | Initialize wiki directory structure |
| `ingest <path>` | Process source into wiki pages |
| `query <question>` | Search wiki and synthesize answer |
| `lint` | Health check for contradictions, orphans, gaps |

If no argument, default to `query` mode (interactive).

## Directory Structure

The wiki uses a three-layer architecture:

```
knowledge/                    # or .claude/agent-memory/wiki/ (when used by /refine)
├── raw/                      # Layer 1: Immutable sources
│   ├── sources/              # Ingested documents
│   └── imports/              # Migrated data (e.g., JSONL)
├── wiki/                     # Layer 2: LLM-maintained pages
│   ├── index.md              # Master catalog (one-line per page)
│   ├── log.md                # Append-only chronological record
│   ├── concepts/             # Domain concepts
│   ├── entities/             # Organizations, people, tools
│   ├── strategies/           # Successful approaches (cross-run learning)
│   ├── anti-patterns/        # Failed approaches (cross-run learning)
│   ├── scorer-insights/      # Scorer evolution context
│   └── sources/              # Individual source summaries
├── schema.md                 # Layer 3: Wiki rules and conventions
└── lint-report.md            # Latest lint results (generated)
```

## Page Format

Every wiki page MUST have YAML frontmatter:

```yaml
---
title: Page Title
type: concept | entity | strategy | anti-pattern | scorer-insight | source-summary
sources:
  - raw/sources/filename.md
related:
  - "[[related-page]]"
created: YYYY-MM-DD
updated: YYYY-MM-DD
confidence: high | medium | low
---
```

Cross-reference using `[[wikilinks]]`: `[[strategy-sanitizer-patterns]]`.

## Operations

### `/wiki init`

1. Determine wiki location:
   - If `.claude/agent-memory/` exists (inside a /refine-managed project): use `.claude/agent-memory/wiki/`
   - Otherwise: use `knowledge/` at project root

2. Create directory structure:
   ```bash
   WIKI_ROOT="<determined location>"
   mkdir -p "$WIKI_ROOT"/{raw/sources,raw/imports,wiki/{concepts,entities,strategies,anti-patterns,scorer-insights,sources}}
   ```

3. Create `wiki/index.md`:
   ```markdown
   # Wiki Index

   > Master catalog. Updated automatically on every ingest.

   ## Pages

   (empty — pages will be listed here as they are created)
   ```

4. Create `wiki/log.md`:
   ```markdown
   # Operation Log

   > Append-only chronological record.
   ```

5. Create `schema.md`:
   ```markdown
   # Wiki Schema

   ## Conventions
   - Filenames: kebab-case matching the concept
   - Cross-references: [[wikilinks]] for all internal links
   - Source references: link back to raw/ paths
   - Every page requires YAML frontmatter (title, type, sources, related, created, updated, confidence)

   ## Page Types
   - **concept**: Domain concept or technique
   - **entity**: Organization, person, tool, or project
   - **strategy**: Successful approach (from /refine KEEP)
   - **anti-pattern**: Failed approach (from /refine DISCARD)
   - **scorer-insight**: Scorer evolution observation
   - **source-summary**: Summary of an ingested source document

   ## Operations
   - **Ingest**: Read source → create/update 5-15 wiki pages → update index → append log
   - **Query**: Read index → load relevant pages → synthesize answer
   - **Lint**: Check contradictions, orphans, missing pages, stale claims
   ```

6. If existing JSONL data found, offer migration:
   ```
   Found strategies.jsonl (N entries) and anti-patterns.jsonl (M entries).
   Migrate to wiki pages? Each JSONL entry becomes a wiki page with cross-references.
   ```
   On confirmation: copy JSONL to `raw/imports/`, create one wiki page per entry.

### `/wiki ingest <source-path>`

1. Read the source document (from `raw/sources/` or the given path).
   If the source is outside `raw/`, copy it to `raw/sources/` first.

2. Create a source summary page:
   ```
   wiki/sources/<source-slug>.md
   ```
   Include: title, key takeaways, extracted entities and concepts.

3. For each concept/entity mentioned:
   - If page exists: update with new information, add source to frontmatter
   - If page doesn't exist: create new page in appropriate subdirectory

4. Add `[[wikilinks]]` between related pages (bidirectional where possible).

5. Update `wiki/index.md` — add new pages, update modified pages' descriptions.

6. Append to `wiki/log.md`:
   ```
   ## [YYYY-MM-DD] ingest | <source title>
   Pages created: N, Pages updated: M
   ```

### `/wiki query <question>`

1. Read `wiki/index.md` to identify relevant pages (selective retrieval).

2. Load only the relevant pages (do NOT scan entire wiki directory).

3. Synthesize answer with `[[wikilink]]` citations to source pages.

4. If the answer is novel and valuable:
   - Ask whether to persist as a new wiki page
   - If yes: create page, update index, append log

### `/wiki lint`

Scan the entire wiki for:

1. **Contradictions**: Pages making conflicting claims about the same subject.
   Detection: find pages sharing the same `related` links, compare assertions.

2. **Orphan pages**: Wiki pages with zero incoming `[[wikilinks]]` from other pages.
   Exception: index.md and log.md are not orphans.

3. **Missing pages**: `[[wikilinks]]` pointing to nonexistent files.

4. **Stale claims**: Pages whose `updated` date is older than related sources' ingest date.

5. **Duplicate patterns**: Strategy/anti-pattern pages with similar `domain` + `pattern` fields
   that should be consolidated into a single page.

Output results to `lint-report.md` and display summary:
```
Lint Results:
- Contradictions: N
- Orphan pages: N
- Missing pages: N
- Stale claims: N
- Duplicate patterns: N
```

## Integration with /refine

When `/refine` runs in a project with an initialized wiki (`.claude/agent-memory/wiki/index.md` exists):

- **Step 3 (Audit)**: Read `wiki/index.md` for selective strategy/anti-pattern retrieval
- **Step 7 KEEP**: Write JSONL (always) + create/update `wiki/strategies/<domain>-<slug>.md`
- **Step 7 DISCARD**: Write JSONL (always) + create `wiki/anti-patterns/<domain>-<slug>.md` with `[[wikilink]]` to attempted strategy
- **Step 9**: Create `wiki/scorer-insights/<task-id>.md` with run summary

JSONL remains the primary data format. Wiki is an additive layer for cross-referencing and selective retrieval. Projects without wiki work exactly as before.
