# Commit Discipline

> Anti-pattern observed: commits bundling orthogonal changes (e.g.,
> a symlink fix + setup-env logic + README marketing + filemode chmod
> in a single commit) without justifying the coupling.
> Source: Karpathy-4-rule re-audit, finding (b) — "Bundled commits
> with unjustified coupling".

## 1. Default: one concern per commit

If two changes can be reverted independently with no breakage, they
belong in two commits. The test is reversibility, not file count.

Examples of orthogonal concerns to keep separate:
- runtime fix vs. documentation update;
- behavior change vs. style/format change;
- application code vs. test code (only when test is for the same
  behavior — fixture additions can ride along);
- one rule vs. another rule (each rule is its own concern).

## 2. Bundling allowed only with explicit coupling

A bundle is acceptable when:
- the changes are tightly coupled (revert of one breaks the other);
- the changes share a single end-state success criterion that fails
  if any sub-change is missing;
- the commit body explicitly states the coupling reason in a
  "Coupling:" line.

Without that line, the reviewer cannot tell whether bundling was
deliberate or an oversight.

## 3. Forbidden bundle patterns (from observed failures)

- **Multi-defect bundle**: bundling D2 (PATH symlink) + D3 (setup-env
  logic) + D4 (README marketing) + D5 (filemode chmod) when each was
  independently reversible. Revert of any one would have left the
  other three in place — proof of independence.
- **Drive-by docs**: editing README in a commit whose body is about a
  build-system change, without mentioning the README in the body.
- **Mixed scope across layers**: changing ROOT and projects/{a,b}
  Dockerfiles in one commit when each layer was an independent
  decision (acceptable when coupled, with explicit "Symmetric across
  layers" justification — see claude-meta-autoagent 3a21b65 as
  positive example).

## 4. Counter-test for this rule

For each commit, ask: "If I revert exactly this commit, what one
end-state changes?" If the answer is more than one independent
end-state, the commit should have been split.

For commits already in history, this is retrospective. The rule
applies to new commits.

---

*Source: 2026-04-30 polyagent-devcontainer audit cycle. Specifically:
commits 0d90d76 (force-pushed since), 5dc9045, 041f5ea each bundled
4 orthogonal changes — flagged by the Karpathy 4-rule self-audit.*
