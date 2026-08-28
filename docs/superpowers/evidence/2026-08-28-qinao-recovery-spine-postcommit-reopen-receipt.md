# Qinao recovery-spine post-commit reopen receipt

Date: 2026-08-28 (Australia/Melbourne)

Status: post-commit, non-production evidence-reopen receipt. This receipt
grants no production implementation, protected-worktree mutation, remediation,
or scan-launch authority.

## Frozen primary evidence commit

- branch: `codex/deep-scan-forensic-recovery-20260828`
- commit: `7ec02b4b875ecc3993519fdfc7f584939600f39b`
- commit tree: `4c149ed1aacd68be348f4506e008fd98348898d4`
- parent/base commit: `8ba2914dcaa2771051653609c96c6cd5e62914c0`
- subject: `docs: freeze Qinao recovery spine evidence`
- committed paths: `14`
- primary final-audit receipt SHA-256:
  `10fa6e02346322da53ecbcaa2284c2d2f22ada637a30a71d8ca7e08b67955a0d`

The forensic worktree was clean immediately after this commit. The commit
contains the final specification, verifier, permanent verifier tests, formal
ledger, Deep Scan #1 and #2 observation evidence, scan-numbering decision,
three refreeze manifests, two final correction manifests, specification
refreeze receipt, and final audit receipt.

## Reopen method

The commit object, not the working tree, was exported with `git archive` into
a new directory under `/private/tmp`. All commands below ran inside that
detached archive with `PYTHONDONTWRITEBYTECODE=1`; no repository path or hidden
TEMP generator was consulted.

Fresh archive results:

- permanent verifier suite: `76/76 OK`
- official verifier CLI: exit `0`, `ok: true`
- formal ledger data rows: `10,293`
- formal ledger SHA-256:
  `08927cf99433267ee5a1e602dfb3ae225cf6393426aa53c5188839c917228cb1`
- formal ledger row root:
  `bfd2c4c5807008510299514fae32d1a1edf8154f0fbb874adba00b1d1e87a461`
- named-contract root:
  `585e14ab6e320f55d4fa768ac7c3f7044eb81581410c17218007a2814ac2daee`
- UNIT class-set root:
  `3129b6e700aa67202d46688384d04d95ea0fb8cf43f5e9e0c8392a1a9eec1c70`
- REQUIREMENT semantic-set root:
  `93e3fe0dec5c8837643b2b838773f921ea2a06ecde307438b6cdec24a40d2a23`
- provenance-mapping root:
  `402ea7a7e903aa2054c4fcb16fb66b3b22ee1804f8165e5e1b31607e3a577d5e`

Exact archive file identities also reopened:

- semantic manifest SHA-256:
  `ec2d42d5871efc50b780d1d1a75ccb5afff40518100b903d746c4e4ec259d3fc`
- mapping manifest SHA-256:
  `66bbe9246cff6ee338234cd4a91610b9ef6212faf9cb39297cc74739e51dc548`
- verifier SHA-256:
  `96ab8a3bdb9d7b87a8554ca6e83125ad7985a9936b49d558dbce2c8f578a21a7`
- permanent-test SHA-256:
  `bc267400ff9fbea6ce15e4e77ec058f8603237ae199f75c72a84ad1c97df84b1`

## Protected-worktree non-interference

The protected `.worktrees/qinao-dual-space-controlled-convergence` checkout
was reopened read only after the primary evidence commit and remained:

- HEAD `29d953a8ab7f1b8cfe83ae1f99c9ace620b2f895`
- HEAD tree `1f1efdf28bd31bb8fd5ec043e1f4f44fa11f6d01`
- `33` dirty or untracked status records
- NUL-delimited status SHA-256
  `45faece29aad471828a39eef3acc600d8828bf0e45133ad72ce83b76a1a6c875`
- no index lock

No protected file, index entry, branch pointer, commit, or worktree state was
changed.

## Scope boundary

This receipt proves that the primary forensic commit is self-contained and
reopens from Git object state. It does not claim production A is implemented,
does not claim all `111` Deep Scan #1 findings are remediated, and does not
launch Deep Scan #3. The numbering remains: #1 first and successful, #2 later
and failed, #3 `notStarted`, Standard scan unnumbered.
