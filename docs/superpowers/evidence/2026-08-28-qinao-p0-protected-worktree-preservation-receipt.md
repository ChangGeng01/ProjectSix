# Qinao P0 protected-worktree preservation receipt

Date: 2026-08-28

Schema: `qinao.p0-protected-worktree-preservation-receipt.v1`

## Decision and authority boundary

This receipt records A0.1 loss prevention only. The protected P0 authoring
worktree was frozen into a separate Git commit without changing its worktree,
index, branch, or HEAD. The preservation commit is non-authoritative forensic
and intake input. It is not the V2 transition-02 candidate, does not admit any
of the 33 paths, does not authorize A1-A4 production code, and does not create
a second controlled plan.

## Protected source before and after capture

- protected branch:
  `refs/heads/codex/qinao-dual-space-controlled-convergence`
- protected HEAD:
  `29d953a8ab7f1b8cfe83ae1f99c9ace620b2f895`
- protected HEAD tree:
  `1f1efdf28bd31bb8fd5ec043e1f4f44fa11f6d01`
- staged paths: `0`
- changed paths: `33`
- tracked modified paths: `22`
- previously untracked paths: `11`
- protected index SHA-256 before and after:
  `089b62d56244917e72b528d9bc832fcf9dceeb9ba37fe5016f503fbedcd67592`
- NUL-delimited porcelain-status SHA-256 before and after:
  `45faece29aad471828a39eef3acc600d8828bf0e45133ad72ce83b76a1a6c875`
- complete tracked binary-diff SHA-256 before and after:
  `92aecebc74d0ee11b05c75b1f36e149ad30eb8e4a344141b3eac4048d28db4fd`
- merge, cherry-pick, revert, and index-lock state: absent
- `git diff --check`: `PASS`

The exact three before/after digests above matched after the preservation ref
was installed. The protected branch and HEAD also remained byte-identical.

## Preservation identity

- preservation ref:
  `refs/heads/codex/qinao-p0-preservation-20260828`
- preservation commit:
  `4a9298db261bcfda97ea1748baad65649156ba66`
- preservation tree:
  `22382c1de6680a263ec4a2f4a6c989c0f0e6e220`
- sole parent:
  `29d953a8ab7f1b8cfe83ae1f99c9ace620b2f895`
- subject: `forensics: preserve Qinao P0 33-path worktree`

The tree was constructed through an isolated temporary index initialized from
the protected HEAD. The temporary index admitted exactly the current 22
tracked modifications and 11 non-ignored untracked files, wrote their Git
objects, and was discarded. The protected worktree's real index was never
used for staging. The ref was created with compare-and-swap against an absent
ref, so an existing or racing preservation identity could not be overwritten.

The parent-to-preservation diff contains exactly the 33 manifest paths. It has
no deletion, rename, submodule, symlink, or non-regular Git mode. Every row was
reopened from the preservation commit and matched its mode, blob, byte length,
and SHA-256.

## Machine-readable path manifest

- path:
  `docs/superpowers/evidence/2026-08-28-qinao-p0-protected-worktree-preservation-manifest.tsv`
- data rows: `33`
- distinct paths: `33`
- tracked-modified / previously-untracked: `22 / 11`
- bytes: `6437`
- SHA-256:
  `02192283eaf6ccbc7c75989eeba906dcfdd3aeedffd7a42ea24f42549009a84c`
- sorted-path-list SHA-256:
  `b0f536ffe3175ae8e990070019b240b7f70f4def12606992179722845730e061`
- encoding: ASCII-compatible UTF-8, TAB-separated, LF, no BOM

The header is closed as:

```text
schemaVersion	changeKind	path	gitMode	gitBlob	byteLength	sha256
```

`changeKind` is exactly `trackedModified` or `untrackedAdded`. The rows are
sorted by repository-relative path and contain no packed set or omitted field.

## 2026-08-10 design-source preservation boundary

The preservation tree contains this untracked review input:

- path:
  `docs/superpowers/specs/2026-08-10-qinao-global-invariant-firewall-and-recovery-design.md`
- Git blob: `887c23a28fb9098d86d252aa8b6dc9153380738b`
- bytes: `233726`
- SHA-256:
  `4eb06cde16e0cf5985c7272147ced9274dd83648a098772c8b5a06f7b3ebeab6`

This identity is preserved but remains unadmitted. A0.2 must independently
construct the exact V1 base in which the admitted 2026-08-02 edge is present
and this 2026-08-10 path is absent. Its candidate tree may add only the exact
blob above. The 33-path preservation tree must never substitute for either
the V2 base tree or the V2 candidate tree.

## Remaining A0.1 closure work

This repository receipt intentionally does not name its own containing commit
or tree. A separate repository-external review receipt must bind this receipt,
the TSV blob, the containing final Git commit/tree, a verified external Git
bundle of the preservation ref, and the unchanged protected-state witnesses.
Until that review succeeds, A0.1 is durable in local Git but is not marked
complete. A0.2-A0.5, A1-A4, R0-R3, and Deep Scan #3 remain unopened.
