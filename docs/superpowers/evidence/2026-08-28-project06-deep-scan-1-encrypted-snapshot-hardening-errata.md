# Project06 Deep Scan #1 encrypted snapshot hardening and errata

Date: 2026-08-28

This record separates the immutable capture-generation evidence from the
hardened successor implementation. It contains no finding body, private
manifest, raw SQLite digest, raw row root, key material, or Keychain locator.

## Lineage boundary

- capture-generation commit:
  `640f45ff2b5b02390ef23ba940f7aa351c7716cb`
- capture-generation tree:
  `adde0221dc709fdd9754628a4ac0241ba2b70203`
- capture-generation source SHA-256:
  `8cfae516625418f9cbd36dfef6adb6aeb9669e51e5eef06fe99d544d91094152`
- capture-generation binary SHA-256:
  `485f3a7b7ae57412f803258f2b86e664794e1f118684ce22c8b045b90c446b1b`
- capture ID: `d12eabe4-d0fe-48b6-b2e8-2c906c03607e`
- ciphertext SHA-256:
  `575246b8c765b82fd86bd8100bd9791e46030736f494364d9270ba3440b68f0a`
- `ciphertextRecaptured=false`
- `historicalCaptureModified=false`
- `actualDS1ReopenWithHardenedBinary=false`
- `keychainAuthorizationPending=true`

The historical ciphertext, capture receipt, three reopen receipts, preserved
binary, key epoch, and erasure scope were not changed. The hardened successor
has not been granted silent access to the historical creator-bound Keychain
items and therefore is not represented as having reopened or recovered the
real Deep Scan #1 ciphertext.

## Historical wording correction

For the three capture-generation reopen passes:

- `privateManifestRecomputed=true` means that AES-GCM authenticated the private
  manifest, its scan binding was checked, and audit evidence plus public
  commitments were recomputed. The old verifier did not semantically compare a
  newly built private audit fragment with the stored fragment.
- `publicReceiptByteEquivalent=true` means canonical JSON object equivalence.
  The old verifier did not compare the original receipt's raw bytes.
- file `fsync` was mandatory. Parent-directory open and `fsync` were
  best-effort in the capture-generation publisher and their failure was not
  fatal.

The immutable external receipts are not rewritten. The corrected core and
postcommit receipts narrow their interpretation.

## Hardened successor identity before final Git binding

- hardened source:
  `scripts/qinao_ds1_evidence_vault.swift`
- hardened source SHA-256:
  `28738b81c5f8219b598b64873ae1da70056c067b5b5f84fa57346df223a2bf81`
- hardened test source:
  `scripts/test_qinao_ds1_evidence_vault.py`
- hardened test SHA-256:
  `cf6d9249f6639e34a165a5cc0e618d111cdf6b831efca1e0bd6d2ae903e3fdad`
- corrected core receipt SHA-256:
  `18e09a9c2b5d11e332eae6b631bc9d8940dbcbd5773455fd702f56aa93a8fd12`
- historical-object postcommit receipt SHA-256:
  `b9000c9d54f1930758c3e801d87a344ea8a3a45f97288cdadc2131f1b04155c1`
- hardened verification receipt schema:
  `qinao.ds1-independent-reopen-receipt.v2`
- frozen public-receipt-v1 golden SHA-256:
  `368d6d696dc778753930be828f62df04297e15683eb192b3a5b5b4538e3cc1f6`

These identities are rebound to final Git blobs, commit, tree, independently
compiled binary, and final test results by the later repository-external final
review receipt. This document does not name its own containing final commit or
tree and therefore creates no self-hash cycle.

## Successor hardening implemented

1. The running executable digest uses `_NSGetExecutablePath`, `realpath`,
   `O_NOFOLLOW`, a retained file descriptor, pre/post `fstat`, and streaming
   SHA-256. A forged `argv[0]` no longer controls the recorded binary digest.
2. Destination, receipt, verification, source-lease, and historical dead-path
   operations use canonical absolute paths and component-wise descriptor
   traversal. Intermediate symlinks, output collisions, hardlinks, unsafe
   modes, and repository-internal custody fail closed.
3. Publication retains and verifies the renamed temporary-file descriptor,
   compares the final name's device/inode, makes file and directory `fsync`
   fatal, serializes cooperating publishers with a directory lock, and safely
   cleans a deterministic owner-only stale staging file after interruption.
4. `recover-receipt` reconstructs only a missing local Qinao custody receipt
   from the AEAD-authenticated snapshot. It never accepts source SQLite or raw
   key input, never overwrites a different receipt, treats an exact receipt as
   idempotent success, and remains safe under a concurrent exact publisher.
5. Recovery and verification rebuild historical dead-locator commitments from
   authenticated capture evidence cross-checked against frozen SQLite. A later
   live locator change is reported as current-state drift and does not destroy
   historical recoverability.
6. Public-receipt v1 is a frozen byte contract with a golden digest. Recovery
   uses the capture-time SQLite runtime from the authenticated manifest rather
   than the current verifier runtime. The richer hardened reopen receipt uses
   schema v2 instead of changing the historical v1 shape.
7. Exact Deep Scan #1 progress, identities, relevant-table columns,
   cardinalities, severity totals, details JSON/byte totals, artifact kinds,
   `quick_check`, and foreign-key results fail closed. Untrusted envelope,
   manifest, SQLite, and receipt sizes are bounded before publication or
   allocation where the API exposes the size.
8. Core dumps are disabled at process start, secret-key `Data` receives
   best-effort zeroization at command exit, and audit results no longer retain
   unused full query-row copies. Swift copy-on-write and cryptographic-library
   internals prevent an absolute claim that every transient copy is erased.

`recover-receipt` restores only the local encrypted-custody sidecar after a
publisher interruption. It does not restore Codex Security canonical
manifest/findings/coverage/report artifacts, change official scan state,
remediate findings, or authorize Deep Scan #3.

## Verification actually completed for the successor

- warnings-as-errors production Swift build: `PASS`
- warnings-as-errors test Swift build: `PASS`
- ordinary black-box suite: `5 PASS / 1 SKIP`
- skipped ordinary item: opt-in real Keychain integration gate
- separately authorized sandbox-external synthetic Keychain integration:
  `1/1 PASS`
- integration flow: production-path freeze, new-process verify, ciphertext and
  receipt mutation rejection, missing epoch, symlink/hardlink custody,
  progress drift, collision and path rejection, direct process exit after
  durable snapshot publication, receipt reconstruction, new-process reopen,
  exact idempotent recovery, no stale staging file, and test-key erasure
- synthetic WAL proof: the final required progress/severity corrections existed
  only in committed WAL and were present in the accepted in-memory backup
- live-state drift proof: creating the four formerly dead synthetic artifacts
  after capture did not block receipt recovery; v2 verification reported drift
- historical Deep Scan #1 hardened reopen: `NOT RUN`

The synthetic integration created random `test-*` Keychain epochs and deleted
only those test epochs in its `finally` path. It did not read the real Deep
Scan #1 ciphertext or historical keys.

## Residual limits and next architecture step

1. Historical keys remain creator-binary-bound. The preserved exact v1 binary
   is the proven same-device reopen path. Durable cross-build access requires a
   stable signed helper and reviewed Keychain access group or ACL migration,
   followed by a non-destructive real-ciphertext reopen before any old key or
   binary retirement.
2. The retained no-follow source descriptor detects persistent path
   replacement before and after backup, but ordinary SQLite still opens the
   canonical pathname through its VFS. A malicious same-UID process with
   directory rename authority could theoretically swap another valid database
   only during SQLite's open and restore the original path before the final
   check. Removing that adversarial race requires a controlled SQLite VFS (or
   an equivalent descriptor-bound capture service), not another pathname
   check. The accepted historical source was a trusted local workbench, so this
   is recorded as successor hardening debt rather than retroactive evidence.
3. `ThisDeviceOnly` remains intentionally non-synchronizing. Device or Keychain
   loss is not recoverable from ciphertext alone. Cross-device/offline recovery
   must be a separately threat-modeled generation.
4. The two-file v1 shape is recoverable but not a single atomic filesystem
   object. A future v2 should stage ciphertext plus receipt inside one private
   bundle directory and atomically rename the complete bundle.

## Acceptance boundary

- `acceptance6SnapshotSameDeviceReopen=pendingFinalExternalReview`
- `r0Complete=false`
- `canonicalArtifactState=canonicalUnavailable`
- `deepScan3Authorized=false`

The next work remains: finalize external Git/custody binding, then implement A,
then complete the 111-row R0 inventory and R1-R3 closure. Deep Scan #3 remains
not started.
