# Qinao A0.3 design-source identity freeze and authority gate

Date: 2026-08-29

Status: implementation plan; A0.3 remains open until every external gate is
independently satisfied.

## Outcome

Build one deterministic, non-authoritative A0.3a identity projection over the
already frozen A0.2 facts. It must separately bind:

- the exact 2026-08-02 and 2026-08-10 source path/commit/tree/blob/length/
  SHA-256 tuples in their required order;
- the exact review base (whose authority remains unverified) and one-path
  candidate trees;
- the A0.2 projection digest;
- the repository-external A0.2 Git-object custody capsule and its manifest
  digests; and
- the fact that this local capability has no authority, install, signer,
  receipt-acceptance, claim, commit, ref-CAS, or protected-controller effect.

The result is source-identity evidence only. It does not create
`QinaoDesignEdgeAdmissionReceiptV2`, approve an amendment, turn the custody
capsule into authority, or open A0.4.

## Frozen inputs

- A0.2 commit:
  `bef9cea290d161da7510c6624bc676fd181cfd10`
- A0.2 tree:
  `26495bad43991149264c177fbb01212da952f464`
- A0.2 projection digest:
  `cf8290927c19deddc37938f7ded85a985a286923ab1501d5401879149fcb8298`
- A0.2 frozen JSON SHA-256:
  `cab70d307dd1e289850fe741b67ad64c9a252913ddccd9ba00c13d1b065f6f2b`
- non-authoritative custody bundle SHA-256:
  `3b29335f12ae680329e19723b1f292641a66358ae47a04a1ee996957b034b36f`
- custody manifest SHA-256:
  `674cb04da3d5ab80d3f22cb6a52494f4a6e8c36947a0755faff1ddf2b718fd70`
- custody review SHA-256:
  `5b01e9705e54a46699f77efa9f0a5bfa064ed8358b15399dbcec9c50037a7371`
- append-only A0.2 semantic erratum SHA-256:
  `4e51270815584488bbd33054ff7b61f2c4f7ea9040f98ed5e86aa1bf3ae8b93a`

The capsule is self-contained for the A0.2-required Git object closure. It is
not a complete offline mirror of external Git LFS payloads and is never an
authority receipt.

The first postcommit clean-capsule reopen invalidated one overbroad historical
A0.2 statement. A packed source object retained identical byte length but its
`mtime_ns` changed while A0.2 used the live source object database through
`GIT_ALTERNATE_OBJECT_DIRECTORIES`. Therefore
`/deterministicProjection/sharedObjectDatabaseWrites: 0` is not accepted as a
valid filesystem-wide claim. The historical A0.2 bytes, commit, tree, source
tuples, projected tree identities, and zero authority effects remain exact;
the false semantic scope is superseded by an append-only erratum rather than
silently rewriting history.

## Existing authority boundary

The incumbent authority family is the external design-edge admission
controller/verifier, the `design-edge-admission-signer` scope, its existing
durable claim/evidence transaction, and its protected-ref CAS broker.
`run_qinao_managed_convergence.py` remains a non-authoritative
`queryExisting -> invokeOnce -> verifyExisting` dispatcher.

Historical `QinaoDesignEdgeAdmissionReceiptV1` bytes must remain byte-exact
and cannot be extended or reinterpreted as V2. K3 owns runtime mutable state,
K4 owns capability grants/uses, and Artifact Mesh owns immutable bodies; none
may be reassigned controlled-source admission authority.

No currently visible repository or custody input has supplied a governed V1
transition-02 predecessor terminal and its complete trust chain.
Test-only signed vectors, local observations, user development authorization,
the 33-path preservation tree, and A0.2 outputs are explicitly insufficient.

The historical V1 transition has two legal terminal shapes: a signed design
edge receipt when the optional edge runs, or the exact already-present
terminal when the approved 2026-07-29 design is already in the base. Under the
historical verifier, the selected bootstrap's 2026-07-29 tuple corresponds
structurally to the latter variant. No governed raw terminal for that path is
bound to this capability, and no governed admission evidence for the later
2026-08-02 supplemental design is bound. This repository-scoped observation
does not claim that evidence cannot exist elsewhere. Local code must not
assert that either transition occurred, assume a V1 design-edge receipt
exists, or reinterpret the already-present terminal. The external amendment
must bind and resolve the exact predecessor terminal shape.

## A0.3a implementation

Add `scripts/qinao_a03_design_source_identity.py`.

The public callable and CLI accept only a repository containing the already
pinned implementation and a mode-restricted custody directory. They load A0.2
only from its exact sibling source bytes after checking byte length, Git blob,
and SHA-256, then require the entire canonical A0.2 output to match the frozen
output SHA-256. Top-level imports, `PYTHONPATH`, and a preloaded same-name
module cannot select the delegated implementation. The callable and CLI do
not gain receipt, signer, trust-root, claim, operation, controller,
output-ref, commit, or install inputs.

No write-capable A0.2 Git operation may receive the live repository or its
object database. After the custody bundle has been hashed, header/ref checked,
and verified through the same held file descriptor, a fixed allowlisted Git
process initializes an empty private SHA-1 bare repository and runs
`git bundle unbundle /dev/fd/N` against a duplicate of that held descriptor.
The custody pathname is never reopened. Any initialization, descriptor,
unbundle, exact-heads, object-format, object-inventory, or identity mismatch
fails closed; there is no ordinary-copy, hard-link, source-path reopen, or
live-object-database fallback. The private repository must be non-empty,
path-disjoint from the live object database, and free of `alternates` and
`http-alternates`.

The exact byte-pinned A0.2 module owns both the outer and inner scratch leases
through its existing janitor/lease protocol. The private repository and inner
runtime root are siblings. The module instance's `RUNTIME_ROOT` is temporarily
rebound to the inner root with the same frozen basename, restored in `finally`,
and the original `prepare_provisional(privateRepository)` executes unchanged.
Loading and execution are serialized by one reentrant lock held in a
versioned process-state module installed atomically with `sys.modules.setdefault`.
Every A0.3 alias or reload validates and reuses that same holder and lock; a
holder replacement or shape mismatch fails closed. The loader restores any
pre-existing private A0.2 `sys.modules` entry in `finally` so concurrent
embedded callers cannot leave or delete another caller's mapping.
Private ephemeral pack metadata may change. The live source object database's
complete bounded namespace and selected-metadata inventory (device, inode,
mode, owner, link count, size, mtime, ctime, and flags) must be identical at
the before/after sampling endpoints of both A0.2 execution and the whole A0.3
observation. This is an endpoint-equality observation only: it does not hash
all live object bytes, cover atime/birthtime/ACL/xattr, exclude a transient
change restored between samples, or establish continuous immutability, a
durable source epoch, or same-UID capability isolation.

The custody directory is observed rather than trusted by declaration. The
script opens the directory with `O_DIRECTORY | O_NOFOLLOW`, then proves that
its canonical path is disjoint from every NUL-safely enumerated registered
worktree, the selected worktree Git directory, Git common directory, and the
primary object database. Any primary-object-database `alternates` or
`http-alternates` file fails closed. The script holds all four file descriptors
for the complete observation and makes Git consume the same bundle file object
that was hashed through an inherited `/dev/fd` descriptor. It then rehashes all
content, repeats the repository-boundary inventory, and verifies the
directory/file generations did not change. It validates the closed manifest,
custody review non-authority fields, and the bundle's exact three refs plus
complete-history/object-format claims.
Missing, symlinked, hard-linked, mode/flag-drifted, truncated, extra,
generation-swapped, or inconsistent inputs fail closed.

The observed POSIX modes are 0700/0400, ownership is the current UID, and the
`UF_IMMUTABLE` flag is present. Canonical-path separation does not prove the
absence of every mount alias. These facts also do not prove ACL isolation or
same-UID capability isolation, so the artifact states all three limitations
explicitly. This is a local mode-restricted custody observation, not an
incumbent controller claim, authority receipt, or independent failure domain.

On exact input the script emits canonical JSON and a fixed non-zero blocked
exit. Its identity digest uses canonical JSON with a distinct domain and
length prefix. The document must contain:

- `semanticAuthority: none`;
- `nonAuthoritative: true`;
- `installable: false`;
- `a03Complete: false`;
- `derivationSource: A0.2.prepare_provisional`;
- `verificationInheritance: fixedIdentityFactsOnlyWithBoundErratum`;
- `independentFailureDomains: false`;
- `sourceObjectEpochBinding: notProven`;
- a content-addressed A0.2 erratum that rejects inheritance of the historical
  `sharedObjectDatabaseWrites` claim;
- direct `git bundle unbundle` from the held descriptor, with no pathname
  reopen or fallback;
- `writeCapableGitInput` restricted to the ephemeral private bare repository;
- unchanged live source-object metadata inventory before/after;
- `privateEphemeralObjectMetadataMayChange: true`;
- no live source ODB alternate and no copy/hard-link/live-ODB fallback;
- exact source tuples and source observations;
- exact base/candidate identities;
- content-addressed custody evidence with
  `controllerDurableClaimBound: false`;
- zero authority side effects; and
- the following non-waivable blockers:
  - a governed V1 transition-02 predecessor terminal is not bound to this
    capability;
  - the V1 predecessor terminal shape requires an external amendment;
  - externally governed V2 schema/signer scope absent;
  - controller-persisted durable claim and private source-object epoch absent;
  - same-UID capability isolation not proven.

Missing, changed, unreadable, or semantically inconsistent A0.2 evidence emits
a typed `evaluationUnavailable` document. That failure document repeats
`a03Complete: false`, `phase.opensA04: false`,
`deepScan3: notStartedAndNotAuthorized`, the blocked authority gate, and zero
authority effects so downstream machines never need to infer closure from an
exceptional path. It never degrades to absent, admitted, or already-present.

Freeze one byte-exact JSON output and one review receipt. Neither artifact
contains its own containing commit/tree; the postcommit external receipt binds
those identities without a self-hash cycle.

## TDD order

1. Add failing contract tests for file/import existence and a public surface
   with no authority-bearing argument.
2. Add failing tests for exact ordered source identities, base/candidate trees,
   projection digest, custody digests, and closed blocker set.
3. Add failing tests proving no terminal authority words or nonzero authority
   effects can appear.
4. Add failing tests for deterministic canonical bytes and a domain-separated
   identity digest.
5. Add failing tests for A0.2 projection drift, custody drift, and a
   missing-object `evaluationUnavailable` response that explicitly keeps A0.3,
   A0.4, and DS3 closed.
6. Add a clean packed-object regression for the observed source-pack mtime
   mutation, plus tests proving `unbundle` consumes the still-open file object
   after its pathname moves, invalid bundles fail closed, exact heads match,
   no source path/copy/hard-link/live-ODB fallback exists, execution is
   private-only, the runtime root is restored, and live ODB sampling endpoints
   remain equal. Add concurrent loader tests that prove every call receives a
   distinct module object, the prior private `sys.modules` mapping is restored,
   and separately loaded A0.3 aliases share the same process-state lock rather
   than racing through module-instance-local locks. Prove that replacing the
   versioned process-state holder fails closed before any A0.2 load.
7. Execute the byte-pinned A0.2 implementation only against the private bare
   repository materialized from the verified custody bundle; bind the
   append-only erratum and reject inheritance of its superseded claim.
8. Run the focused suite, A0.2 regression suite, compile checks, two independent
   CLI byte comparisons, and protected-worktree identity checks.
9. Freeze JSON/receipt, independently review, commit, reopen from a clean
   capsule-backed clone, and publish a repository-external postcommit receipt.

## Hard stop before A0.3 authority closure

A0.3 is not complete and A0.4 cannot open until an independent external
governance ceremony supplies all of:

1. canonical raw V1 transition-02 immediate-predecessor terminal bytes, its
   exact V1 terminal shape, and full trust chain;
2. a formally versioned V2 design-edge bundle/receipt schema, operation-key
   domain, signer schema scope, and trust-root amendment;
3. exact protected ref, expected-old commit, and protected-policy predecessor;
4. controller-minted durable claim, attempt/fencing/finalization/retention
   evidence;
5. a controller-owned private source-object epoch stored through incumbent
   evidence/Artifact Mesh boundaries;
6. controller-owned external process supervision and a separately confined
   resource-bounded helper; and
7. an explicit solution for the same-UID capability-isolation boundary.

Local code must not synthesize, backfill, guess, or waive any item. DS3 remains
not started and requires a new explicit authorization after A0-A4 and R0-R3.
