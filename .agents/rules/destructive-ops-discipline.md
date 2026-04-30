# Destructive Operations Discipline

> Anti-pattern: invoking the most powerful destructive tool by default
> when narrower alternatives exist. Source: Karpathy-4-rule re-audit,
> finding E1 — D1 (filter-repo full-history rewrite for a single leaked
> token across 147 commits) failed R2 (Simplicity) and R3 (Surgical)
> because narrower alternatives (BFG, single-commit revert + secret
> rotation, .gitattributes-driven LFS strip) were never surfaced in
> the plan.

## 1. Surface alternatives before any destructive operation

The destructive operations already requiring approval per CLAUDE.md
§4.1 (`rm -rf`, `mv`/`cp` overwrite, `git push --force`,
`git reset --hard`, `DROP`/`DELETE`) plus the irreversible class
(`git filter-repo`, `git rebase --root`, repository-wide search-and-
replace, `docker volume rm`, etc.) **must** be preceded by an
explicit alternatives list.

Minimum content of the alternatives list:
- the proposed operation;
- at least one narrower alternative if any plausibly exists;
- the cost/blast-radius asymmetry between them;
- the reason the broader operation was chosen (or the reason no
  narrower alternative is sufficient).

Without this list, the agent has not satisfied Karpathy R1
("present multiple interpretations — don't pick silently") or R2
("minimum code that solves the problem").

## 2. Concrete narrower alternatives by operation

| Operation | Narrower alternatives to consider first |
|-----------|------------------------------------------|
| `git filter-repo --replace-text` | BFG Repo-Cleaner (line-level, idempotent); single-commit revert + secret rotation when leak is recent; selective `git filter-repo --path` |
| `git push --force` | `--force-with-lease` (preserves concurrent commits); coordinate timing with collaborators |
| `git reset --hard` | `git reset --soft` then selective `git checkout`; create a recovery branch first |
| `rm -rf <dir>` | `rm <files>` enumerated; move to a `.trash/` for review window; verify nothing references the path first |
| repository-wide regex replace | path-scoped replace; one-by-one Edit with context |
| `docker volume rm` | inspect volume contents first; rename the volume to `<name>-archived-YYYYMMDD` instead |
| `DROP TABLE` / `DELETE` (bulk) | soft-delete column; archive table to `<name>_archived_YYYYMMDD`; verify backups exist and are restorable |

The list is illustrative, not exhaustive. The principle is: ask
"what's the smallest action that achieves the end-state?" before
running the largest.

## 3. Token rotation precedes scrub

When the destructive operation is for credential leak removal, the
correct first step is *rotating the leaked credential*. History scrub
is forensic cleanup for an already-mitigated leak. Reversing this
order leaves the token live while you spend time on the rewrite.

## 4. Counter-test

Before proceeding with a destructive operation, the plan should
contain a sentence that names a narrower alternative and explains
why it was rejected. If no such sentence exists, the plan is
incomplete; do not proceed with execution.

---

*Source: 2026-04-30 polyagent-devcontainer audit cycle, D1 (147-commit
filter-repo for a single internal-name leak that could have been
addressed by a single revert + token rotation, since no live secret
was involved). Karpathy 4-rule re-audit assigned R2/R3 FAIL.*
