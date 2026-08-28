# Project06 Deep Scan #1 encrypted snapshot core receipt

Date: 2026-08-28

This is the public, non-sensitive core receipt for the repository-external
encrypted forensic snapshot of the user's first successful Deep Scan. It does
not contain finding title, summary, remediation, `details_json`, raw row bytes,
raw plaintext equality digests, encryption keys, commitment keys, or Keychain
item locators.

This receipt intentionally does not name its containing Git commit or tree. A
separate postcommit receipt must bind those identities without creating a
self-hash cycle.

## Decision and boundary

- scan number: `1`
- scan kind: `deep`
- scan ID: `bcffa52e-53cf-4407-b216-14288ae07061`
- source target revision: `c8f80486895e12e26d567e610c35a6e2141b3489`
- indexed state at capture: `complete`
- capture ID: `d12eabe4-d0fe-48b6-b2e8-2c906c03607e`
- forensic status: `nonCanonicalForensicSnapshot`
- canonical artifact state remains: `canonicalUnavailable`
- capture time: `2026-08-28T11:56:04.973Z`
- retention: no automatic deletion; retain through R0-R3 and never less than
  72 hours; deletion or key erasure requires a separate explicit receipt

The snapshot preserves indexed SQLite evidence. It is not the missing sealed
manifest, findings JSON, coverage JSON, or generated report; it does not
restore official Codex Security artifact availability; it does not prove the
111 findings remediated; and it does not authorize Deep Scan #3.

## Capture contract actually exercised

1. The source was opened through ordinary SQLite WAL/SHM locking semantics.
   `immutable=1`, `nolock`, and naked main-file copy were not used for the
   accepted capture.
2. SQLite's Backup API copied the committed source view into an in-memory
   destination. The destination pager was normalized for sidecar-free
   serialized reopen before its bytes were accepted.
3. The complete serialized SQLite snapshot and private manifest stayed in
   process memory until Apple CryptoKit sealed the payload with AES-256-GCM.
   No plaintext snapshot file was created on the host filesystem.
4. Independent 256-bit encryption and commitment master keys were generated
   with `SecRandomCopyBytes` and stored as non-synchronizable,
   `AfterFirstUnlockThisDeviceOnly` Apple Keychain items. No secret entered
   argv, environment, shell output, receipt, or Git.
5. Public semantic commitments use domain-separated HKDF-SHA-256 plus
   HMAC-SHA-256. Only those keyed commitments and ciphertext fixity digests
   leave encrypted custody.
6. Publication used owner-only repository-external storage, exclusive
   no-replace creation, durability sync, regular-file and single-link checks.
   The ciphertext and receipts were then set to `0400` and `uchg`.

## Frozen cardinality and integrity result

- occurrences / distinct occurrence IDs / distinct finding IDs:
  `111 / 111 / 111`
- finding identity rows: `111`
- locations / covered occurrences: `2716 / 111`
- severity: `high=30`, `medium=65`, `low=16`
- artifact rows / registered dead locators: `4 / 4`
- artifact kinds: `coverage`, `findings`, `manifest`, `markdownReport`
- dead-locator check: every locator and their common root reopened as
  `ENOENT` through a no-follow component walk
- malformed `details_json`: `0`
- details byte range / total: `2351...703607 / 6453105`
- `PRAGMA quick_check`: exactly `ok`
- `PRAGMA foreign_key_check`: `0` rows

Six exact, parameter-bound, fully ordered query sets were committed inside the
private manifest: scan, progress, finding identities, occurrences, locations,
and artifacts. Every typed cell participates in injective, ordinal-bound row
serialization and the private ordered roots.

## Public cryptographic binding

- envelope: `qinao.ds1.envelope.v1`
- payload: `qinao.ds1.sqlite-backup-payload.v1`
- commitment suite:
  `qinao-ds1-keyed-commitment/v1/HKDF-SHA256/HMAC-SHA256`
- key epoch: `ds1-2026-08-28-v1`
- erasure scope: `project06-ds1-r0-through-r3`
- ciphertext bytes: `9380966`
- ciphertext SHA-256:
  `575246b8c765b82fd86bd8100bd9791e46030736f494364d9270ba3440b68f0a`
- ordered query-set commitment:
  `701f24d915078a07d099349cbf685dce866d6119de2efdbdaf1a1fdfd05cfeb9`
- SQLite schema commitment:
  `eff0c348fa5e930a1519f533606d85ef4bc937ba473a8b49263e520d4281d0e8`
- ordered raw-row-root commitment:
  `6409f03dc335a68322e6363b09efc1f37c438888a1d78a5cfdd66cbc86cfcf91`
- dead-locator-root commitment:
  `8af33d3b0d7e35ed4635837b53fd8554f153f15b0e7cd23b8a28533fbdd4b612`
- SQLite snapshot-bytes commitment:
  `deebde82022dcdb5826723fe9d8cb56174564cc87cd310e4da7b3de753ec28f5`
- private-manifest commitment:
  `f7449568c0ab9fcb15cf79c2ee543576370667cbf7819bafa8dd1cf192bf0036`

These values are intentionally not raw plaintext equality digests.

## Repository-external custody identities

Custody root:
`~/Library/Application Support/Qinao/EvidenceVault/deep-scan-1/`

| object | bytes | SHA-256 | mode / links / flags |
| --- | ---: | --- | --- |
| `ds1-bcffa52e-c8f80486-20260828.qds1` | 9380966 | `575246b8c765b82fd86bd8100bd9791e46030736f494364d9270ba3440b68f0a` | `0400 / 1 / uchg` |
| `ds1-bcffa52e-c8f80486-20260828.capture-receipt.json` | 2636 | `d3961779d7aa5d9b17bb29d9b58446499d44648d9264a4f2a739d13ddc2ed675` | `0400 / 1 / uchg` |
| `ds1-bcffa52e-c8f80486-20260828.reopen-receipt.json` | 1206 | `dd13b688bd66f46af5098017dc17b244de5efff75d955041b00bd61c676bc35d` | `0400 / 1 / uchg` |
| `ds1-bcffa52e-c8f80486-20260828.postseal-reopen-receipt.json` | 1206 | `50fac7fb9af9b133c615b4607611836712353e4d21bd8b583eecd8f3e7f9afc5` | `0400 / 1 / uchg` |
| `qinao-ds1-evidence-vault-exporter-485f3a7b7ae57412` | 255480 | `485f3a7b7ae57412f803258f2b86e664794e1f118684ce22c8b045b90c446b1b` | `0500 / 1 / uchg` |
| `ds1-bcffa52e-c8f80486-20260828.preserved-binary-reopen-receipt.json` | 1206 | `abee644a40b1a50a9197fcd683fcfd6c03b48505090ddc48bd2491c12d7d241d` | `0400 / 1 / uchg` |

The exact optimized exporter/verifier binary is preserved outside the
repository so that loss of `/private/tmp` does not remove the accepted reopen
path.

## Independent reopen evidence

Three new-process reopen passes succeeded:

1. before `uchg`, at `2026-08-28T11:57:52.265Z`;
2. after ciphertext and receipt sealing, at `2026-08-28T11:58:35.717Z`;
3. from the preserved repository-external binary path, at
   `2026-08-28T12:00:19.269Z`.

Every pass authenticated AES-GCM before parsing, decrypted only in memory,
recomputed the private manifest, schema, six ordered query sets and roots,
re-established all frozen counts, reran `quick_check` and foreign-key checks,
re-probed all four dead locators plus their common root, and reproduced the
public receipt byte-for-byte. Each pass reported that it created no plaintext
file.

## Exporter and test identity

- exporter source:
  `scripts/qinao_ds1_evidence_vault.swift`
- exporter source SHA-256:
  `8cfae516625418f9cbd36dfef6adb6aeb9669e51e5eef06fe99d544d91094152`
- exporter binary SHA-256:
  `485f3a7b7ae57412f803258f2b86e664794e1f118684ce22c8b045b90c446b1b`
- SQLite runtime: `3.54.0`
- test source:
  `scripts/test_qinao_ds1_evidence_vault.py`
- test source SHA-256:
  `dedeae4e64ed4882fde31e6917f0aa04b0e935d0b1a5bf3e3ca7b5de331a0a64`
- black-box test result: `4/4 PASS`

The tests cover the production CLI secret-input boundary, production/test
surface separation, WAL-only committed-row inclusion, Backup API and
serialized reopen, deterministic typed-row encoding, correct-key round trip,
wrong-key rejection, ciphertext/header/truncation rejection, public-receipt
redaction, and no plaintext snapshot-file creation.

## Honest residual limits

1. A separately compiled verifier correctly did not receive silent access to
   the legacy creator-bound Keychain items; it waited for Keychain
   authorization and was terminated without publishing a receipt. The exact
   accepted binary was therefore preserved and independently reopened from
   its durable external path. A future signed helper/Data Protection Keychain
   migration remains hardening work; it must never rotate or delete this key
   epoch before a new generation independently reopens.
2. `ThisDeviceOnly` deliberately prevents cloud synchronization but also means
   device or Keychain loss is not recoverable from ciphertext alone. This
   generation satisfies same-device interruption recovery and the minimum
   retention gate, not cross-device disaster recovery. Any offline recovery
   envelope must be a separately reviewed generation and must not expose raw
   key material.
3. `uchg` and owner-only modes are operational hardening, not a cryptographic
   substitute for AEAD or an append-only external anchor.
4. The live workbench later advanced from the captured source state (its main
   file size and mtime changed after capture). The accepted evidence source is
   the frozen ciphertext, never a later live re-query.
5. This closes the time-sensitive encrypted snapshot and independent-reopen
   portion of R0 / Acceptance condition 6. It does not yet close the required
   versioned 111-row non-canonical forensic inventory, R1 validation, R2
   remediation, or R3 closure.
