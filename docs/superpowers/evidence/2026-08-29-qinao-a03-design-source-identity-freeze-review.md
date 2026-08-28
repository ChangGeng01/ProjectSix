# Qinao A0.3a design-source identity freeze review

Date: 2026-08-29

Status: local A0.3a release evidence complete; A0.3 authority remains blocked.

Semantic authority: none.

## Scope and disposition

This review binds one deterministic, non-authoritative design-source identity
projection to exact implementation, test, plan, frozen-output, predecessor-
search, and A0.2 dependency identities. It does not admit a design edge, mint
or accept a receipt, create a controller claim, establish a private
source-object epoch, commit an authority state, move a protected ref, install
anything, open A0.4, or authorize Deep Scan 3.

The output disposition remains:

- `semanticAuthority: none`;
- `nonAuthoritative: true`;
- `installable: false`;
- `a03Complete: false`;
- `phase.completion: partialBlocked`;
- `phase.opensA04: false`; and
- `deepScan3: notStartedAndNotAuthorized`.

## Frozen identities

- Implementation:
  - path: `scripts/qinao_a03_design_source_identity.py`
  - bytes: `42899`
  - SHA-256:
    `4e5e64f2bd62ce5cd26e5296e6f9d1913a60de471fb04ebdcc67231580535971`
- Contract/integration tests:
  - path: `scripts/test_qinao_a03_design_source_identity.py`
  - bytes: `39924`
  - SHA-256:
    `449ea55bf1ded4574c444803572c08737dcd9edf575fa1062b8f799697727613`
- Implementation plan:
  - path:
    `docs/superpowers/plans/2026-08-29-qinao-a03-source-identity-freeze-and-authority-gate.md`
  - bytes: `9097`
  - SHA-256:
    `8d5c8b1638d2b3ad23b5dcfa9f870d42ff0996985df2f70da119847f509b489b`
- Frozen canonical output:
  - path:
    `docs/superpowers/evidence/2026-08-29-qinao-a03-design-source-identity-freeze.json`
  - bytes: `6110`
  - SHA-256:
    `60de9cca81f6363941dc51062bc7335bfc55fc91b19e044e9f37a4c503ab63a7`
  - domain-separated identity digest:
    `eac4f5dbe9e7b041733b4777f4167112c9a14c153fc31aec693b1dcc1996d6b3`
- Capability-scoped predecessor search:
  - path:
    `docs/superpowers/evidence/2026-08-29-qinao-a03-v1-predecessor-repository-observation.json`
  - bytes: `9609`
  - SHA-256:
    `5a6793768810380fcb8729ede51ee7cea29f7deb77ed039e0da580f439ef6a85`
  - `semanticAuthority: none`
  - `globalNonexistenceClaimed: false`
  - repository-external evidence may exist outside the observed scope.

The delegated A0.2 implementation is executed per invocation only after its
exact sibling source is checked as 51,142 bytes, Git blob
`75f7ef3a7a05b06d454d49ec407a14034bdfd9e6`, and SHA-256
`9229f962f9581f7f942b5f08838f0f9199810dc366e62b03cc0206fe68f09f0d`.
The complete canonical A0.2 output must reproduce SHA-256
`cab70d307dd1e289850fe741b67ad64c9a252913ddccd9ba00c13d1b065f6f2b`.

## Custody observation

The A0.2 repository-external capsule is re-opened, re-hashed, and checked
rather than trusted by declaration. Its bundle SHA-256 is
`3b29335f12ae680329e19723b1f292641a66358ae47a04a1ee996957b034b36f`.
All four custody files remain open by descriptor for the complete observation;
Git consumes the same open bundle object through `/dev/fd`, and all content is
rechecked afterward.

The canonical custody path is checked against every registered linked
worktree, the selected Git directory, Git common directory, and primary object
database. Any primary `alternates` or `http-alternates` file fails closed, and
the repository-boundary inventory must be unchanged at the end.

Observed 0700/0400 POSIX modes, current-UID ownership, single-link files, and
`UF_IMMUTABLE` do not prove ACL, mount-alias, or same-UID capability isolation.
Those limitations remain explicitly unproven boundaries. The A0.2 custody
capsule was observed with owner-only POSIX mode bits and `UF_IMMUTABLE`, but is
not described as encrypted; only the separately preserved DS1 vault is an
encrypted snapshot.

## Verification evidence

- A0.3a focused contract/integration suite: 27/27 passed.
- A0.2 regression suite: 35/35 passed.
- Python compilation checks: passed.
- Two concurrent independent CLI replays were byte-exact matches for the
  frozen JSON.
- Successful projection exit remains the fixed blocked exit `41`.
- Evaluation-unavailable exit remains the distinct fail-closed exit `42`.
- Negative coverage includes module-cache pollution, A0.2 source/output drift,
  authority-effect drift, malformed custody semantics, symlink/hardlink/mode/
  flag failures, directory-generation replacement, linked-worktree overlap,
  ancestor overlap, real shared-clone alternate ODB, typed symlink-loop
  failure, and repository HEAD/ref/index/status/object-inventory invariance.
- Independent implementation/concurrency reviews found no remaining P0 or P1.
- Independent predecessor-evidence review found no incorrect OID, count,
  authority elevation, or global-nonexistence claim.

## Protected state invariance

The protected worktree remains untouched at:
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
avoid a self-hash cycle. A postcommit repository-external custody record must
bind those identities after commit and clean-capsule reopen. Until then, A0.3
is not complete, A0.4 remains closed, and Deep Scan 3 remains neither started
nor authorized.
