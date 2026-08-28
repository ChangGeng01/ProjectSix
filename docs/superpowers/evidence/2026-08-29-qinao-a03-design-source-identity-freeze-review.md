# Qinao A0.3a design-source identity correction review

Date: 2026-08-29

Status: corrected local A0.3a precommit evidence verified; final postcommit
clean-capsule reopen and encrypted external snapshot remain pending. A0.3
authority remains blocked.

Semantic authority: none.

## Scope and disposition

This review binds the corrected deterministic, non-authoritative design-source
identity projection to exact implementation, tests, plan, frozen output,
append-only A0.2 erratum, predecessor search, and A0.2 dependency identities.
It does not admit a design edge, mint or accept a receipt, create a controller
claim, establish a private source-object epoch, commit authority state, move a
protected ref, install anything, open A0.4, or authorize Deep Scan 3.

The output remains:

- `semanticAuthority: none`;
- `nonAuthoritative: true`;
- `installable: false`;
- `a03Complete: false`;
- `phase.completion: partialBlocked`;
- `phase.opensA04: false`; and
- `deepScan3: notStartedAndNotAuthorized`.

## Superseded pre-correction release evidence

Commit `df88d7015532057c2f91db5e382d4f5e10306057`, tree
`2cfa5ee8f6ea4efd7b5b5aef606ad1dd82224881`, and its temporary bundle
SHA-256 `646f8ad69e89c9a8797a58730b43b8c49056fa3ad0be507e0d54d2b9cce3319a`
remain historical evidence, but their A0.3a release conclusion is superseded.
An independent clean-bundle reopen observed the source pack
`pack/pack-083393fc6fbdaf44baaeba720ea0b4f6155e8159.pack` retain byte length
327,731,909 while its `mtime_ns` changed from 1,787,933,439,701,397,000 to
1,787,933,448,606,299,000 during the alternate-backed A0.2 path.

That metadata write invalidates the unqualified historical A0.2 field
`/deterministicProjection/sharedObjectDatabaseWrites: 0`. The observation did
not establish pack byte equality and does not need to: one metadata write is
already a counterexample to the zero-writes claim. The previous review's
27/27 result, old hashes, object-inventory conclusion, and statement that no
P0/P1 remained must not be used as current release evidence.

The historical A0.2 commit, tree, source bytes, frozen JSON bytes, projection
digest, fixed source tuples, projected tree identities, one-path delta, zero
authority effects, and non-authority disposition were not rewritten. A new
append-only erratum invalidates only the overbroad semantic claim.

## Corrected frozen identities

- Implementation:
  - path: `scripts/qinao_a03_design_source_identity.py`
  - bytes: `61209`
  - SHA-256:
    `91e1f90e32fc8557604645c14bfaf2e7c02467df2bb9a6138ca0fbb5de7a95a0`
- Contract/integration tests:
  - path: `scripts/test_qinao_a03_design_source_identity.py`
  - bytes: `57712`
  - SHA-256:
    `209e9023a9889044c8d93c394b1d6f9b7435fd3c60c5b28f7ae23b603de3f734`
- Implementation plan:
  - path:
    `docs/superpowers/plans/2026-08-29-qinao-a03-source-identity-freeze-and-authority-gate.md`
  - bytes: `13730`
  - SHA-256:
    `a392ded3320a7a28ed089dc4e7176b9725b874dd9e39ecc0f2c3555d9dbab860`
- Append-only A0.2 semantic erratum:
  - path:
    `docs/superpowers/evidence/2026-08-29-qinao-a02-shared-object-database-writes-erratum.json`
  - bytes: `3446`
  - SHA-256:
    `4e51270815584488bbd33054ff7b61f2c4f7ea9040f98ed5e86aa1bf3ae8b93a`
- Corrected frozen canonical output:
  - path:
    `docs/superpowers/evidence/2026-08-29-qinao-a03-design-source-identity-freeze.json`
  - bytes: `7333`
  - SHA-256:
    `1d0d81ef032b5babb9f954ce1f3a6d98bb56c120011ea4aaa136e16a41568f17`
  - domain-separated identity digest:
    `6aa15376b40771ee9d90d269566e29a08a2f91dbeff7d44bb541be06f6298bc7`
- Capability-scoped predecessor search:
  - path:
    `docs/superpowers/evidence/2026-08-29-qinao-a03-v1-predecessor-repository-observation.json`
  - bytes: `9609`
  - SHA-256:
    `5a6793768810380fcb8729ede51ee7cea29f7deb77ed039e0da580f439ef6a85`
  - `semanticAuthority: none`
  - `globalNonexistenceClaimed: false`
  - repository-external evidence may exist outside the observed scope.

The byte-pinned A0.2 implementation is loaded per invocation only after its
exact sibling source is checked as 51,142 bytes, Git blob
`75f7ef3a7a05b06d454d49ec407a14034bdfd9e6`, and SHA-256
`9229f962f9581f7f942b5f08838f0f9199810dc366e62b03cc0206fe68f09f0d`.
The complete canonical historical A0.2 output must reproduce SHA-256
`cab70d307dd1e289850fe741b67ad64c9a252913ddccd9ba00c13d1b065f6f2b`,
but A0.3 accepts only its fixed identity facts under the bound erratum and
inherits none of the superseded write claim.

## Corrected execution isolation

The A0.2 custody bundle is opened with the other three custody files and held
by descriptor for the complete observation. Before execution, the same open
bundle object is hashed, header/ref checked, and processed by `git bundle
verify` and `list-heads` through `/dev/fd`.

A separate 0700 scratch lease receives an empty SHA-1 bare repository created
with an empty template. Git then performs `bundle unbundle /dev/fd/N` using a
duplicate of the already verified bundle descriptor. It does not reopen the
custody pathname. The unbundled heads must equal the three exact frozen heads;
the resulting private object database must be non-empty, path-disjoint from the
live object database, and contain no `alternates` or `http-alternates`.

Only that private repository is passed to the exact A0.2
`prepare_provisional` implementation. The private repository and A0.2 inner
runtime root are siblings under the outer lease. The same byte-pinned A0.2
scratch/janitor protocol owns both leases; the module instance's
`RUNTIME_ROOT` is rebound to the inner root with the original basename and
restored in `finally`. A versioned process-state module, atomically installed
with `sys.modules.setdefault`, owns the one re-entrant lock used by every A0.3
alias or reload. Each caller validates the shared holder before entering; a
holder replacement or shape mismatch fails closed. The loader restores any
prior private A0.2 `sys.modules` mapping even when loading fails. Private
ephemeral object metadata may change. There is no source-path reopen,
ordinary-copy, hard-link, live-ODB, or live-source alternate fallback.

The live source object database is sampled before and after the inner A0.2
execution and again around the whole A0.3 observation. The bounded inventory
compares namespace plus device, inode, mode, UID, GID, link count, size, mtime,
ctime, and flags at those endpoints. Endpoint equality does not hash every
live object byte, cover atime/birthtime/ACL/xattr, exclude a transient mutation
restored between samples, prove continuous immutability, bind a durable source
epoch, or establish same-UID capability isolation.

## Custody observation

The A0.2 repository-external capsule is re-opened and re-hashed rather than
trusted by declaration. Its bundle SHA-256 is
`3b29335f12ae680329e19723b1f292641a66358ae47a04a1ee996957b034b36f`.
After private execution, every held custody file is re-read or re-hashed, the
bundle Git checks are complete, and pathname/open-generation identities are
reconfirmed.

The canonical custody path is checked against every registered linked
worktree, the selected Git directory, Git common directory, and primary object
database. Any primary `alternates` or `http-alternates` file fails closed, and
the repository storage-boundary snapshot must be equal at its endpoints.

Observed 0700/0400 POSIX modes, current-UID ownership, single-link files, and
`UF_IMMUTABLE` do not prove ACL, mount-alias, or same-UID capability isolation.
Those remain explicitly unproven. The A0.2 input vault is not described as
encrypted; only the separately preserved DS1 vault is already encrypted.

## Verification evidence

- Corrected A0.3a focused contract/integration suite: 33/33 passed.
- Frozen A0.2 regression suite: 35/35 passed.
- Python compilation and Ruff static checks: passed.
- Two independent CLI replays both exited `41`, emitted no stderr, and were
  byte-exact matches for the 7,333-byte corrected frozen JSON.
- Evaluation-unavailable exit remains the distinct fail-closed exit `42`.
  Its machine-readable document explicitly repeats `a03Complete: false`,
  `phase.opensA04: false`, and
  `deepScan3: notStartedAndNotAuthorized` in addition to the blocked gate and
  zero authority effects.
- New regression coverage proves held-descriptor unbundle still works after
  the original bundle pathname moves, invalid bundle input has no source
  fallback, unbundled heads are exact, live source objects are never the A0.2
  alternate, private pack metadata mutation leaves the live repository's
  sampled endpoints unchanged, the runtime root is restored, and concurrent
  fixed-name module loads preserve the prior process mapping. A separate
  deterministic interleaving test loads A0.3 under two aliases, proves both
  instances share the same process-state lock, prevents overlapping A0.2
  compilation, and restores the original private mapping. A holder-replacement
  test proves mapping drift fails closed before loading A0.2.
- Existing negative coverage retains module-cache/source/output drift,
  authority-effect drift, malformed custody semantics, symlink/hardlink/mode/
  flag failures, directory-generation replacement, linked-worktree/ancestor
  overlap, shared-clone alternate ODB, typed symlink-loop failure, and
  repository HEAD/ref/index/status/object-inventory checks.
- Independent direct-unbundle release and semantic reviews found no remaining
  P0/P1 at the precommit candidate boundary. Residual P2 boundaries remain
  explicit: an endpoint-observation failure in `finally` can become the
  surface exception while retaining the primary exception as context; Git
  subprocess output budgets are checked after collection and no parent-SIGKILL
  supervisor or resource-limited helper is yet installed; the historical A0.2
  suite's global-session assertion can false-red under a legitimate concurrent
  A0.3 run; and endpoint path sampling does not bind a continuous source epoch.

This is not yet the final release closure. The corrected files must be
committed, bundled, reopened in an independent clean clone, re-run there, and
bound by a repository-external postcommit record. The previous clean-reopen
failure makes that postcommit step mandatory rather than ceremonial.

## Protected state invariance

The protected worktree remains at:
`/Users/changgeng/Project/Project06/Project06/.worktrees/qinao-dual-space-controlled-convergence`.

- HEAD: `29d953a8ab7f1b8cfe83ae1f99c9ace620b2f895`
- tree: `1f1efdf28bd31bb8fd5ec043e1f4f44fa11f6d01`
- dirty-path cardinality: exactly 33
- A0.1 preservation ref:
  `refs/heads/codex/qinao-p0-preservation-20260828`
- preservation commit:
  `4a9298db261bcfda97ea1748baad65649156ba66`
- preservation tree:
  `22382c1de6680a263ec4a2f4a6c989c0f0e6e220`

The statement above is limited to the listed HEAD/tree/status/ref facts. It is
not a retrospective claim that the shared live object database experienced no
metadata write during the superseded execution.

## Authorized encrypted postcommit snapshot boundary

The user has authorized encryption of the corrected postcommit A0.3 evidence
snapshot. After commit and independent clean reopen pass, the final external
capsule and postcommit receipt will be encrypted at rest with a separately
managed recovery secret. Encryption is custody protection only: it will not
upgrade semantic authority, prove a controller-owned source epoch, provide
same-UID runtime isolation, include unclaimed external Git LFS payloads, open
A0.4, or authorize Deep Scan 3. No completed-encryption claim is made in this
precommit review.

## Remaining non-waivable gates

1. Governed raw V1 transition-02 immediate-predecessor terminal bytes and
   complete trust chain are not bound.
2. The V1 terminal shape ambiguity requires an external normative amendment.
3. Externally governed V2 design-edge schema, signer scope, operation domain,
   and trust-root amendment are not bound.
4. Exact protected ref, expected-old commit, and protected-policy predecessor
   are not bound.
5. Incumbent-controller durable claim, private source-object epoch, attempt,
   fencing, finalization, and retention evidence are not bound.
6. External helper supervision and same-UID capability isolation are not
   proven.

This repository review intentionally omits its containing commit and tree to
avoid a self-hash cycle. A postcommit repository-external record must bind
those identities after clean-capsule reopen. Until then, A0.3 is not complete,
A0.4 remains closed, and Deep Scan 3 remains neither started nor authorized.
