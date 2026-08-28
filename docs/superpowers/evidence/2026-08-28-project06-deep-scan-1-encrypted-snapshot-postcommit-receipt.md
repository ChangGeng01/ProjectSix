# Project06 Deep Scan #1 encrypted snapshot postcommit receipt

Date: 2026-08-28

This receipt binds the already committed, non-sensitive encrypted-snapshot
core to Git object identities. It is deliberately a later file and therefore
does not create a self-hash cycle in the core commit.

## Core Git identity

- commit: `640f45ff2b5b02390ef23ba940f7aa351c7716cb`
- tree: `adde0221dc709fdd9754628a4ac0241ba2b70203`
- parent recovery-spine HEAD:
  `cc4a9b01ef3ac82bdb43de3061717e49f8b6a767`
- branch at capture:
  `codex/deep-scan-forensic-recovery-20260828`

## Historical capture-generation objects at `640f45ff2b5b02390ef23ba940f7aa351c7716cb`

These rows identify the exact objects used for capture-generation review. The
same paths in the final corrected/hardened checkout intentionally have new Git
blob and SHA-256 identities; that is successor hardening, not drift in the
historical capture objects.

| path | bytes | Git blob | SHA-256 |
| --- | ---: | --- | --- |
| `docs/superpowers/evidence/2026-08-28-project06-deep-scan-1-encrypted-snapshot-core-receipt.md` | 9093 | `ea184e283e322b478b28c6dc8b212cf2578051dc` | `ff18a5a985cab90d75434e8b176e1e9c2be6b01d7eb09c49b4fb42c71e959792` |
| `scripts/qinao_ds1_evidence_vault.swift` | 58722 | `0bcd30282f3814a70ac50108b367cfc5a61bc405` | `8cfae516625418f9cbd36dfef6adb6aeb9669e51e5eef06fe99d544d91094152` |
| `scripts/test_qinao_ds1_evidence_vault.py` | 5657 | `e030ebd358e95bca1c5c92e0f56a252208d463b5` | `dedeae4e64ed4882fde31e6917f0aa04b0e935d0b1a5bf3e3ca7b5de331a0a64` |

The CLI-supplied exporter source SHA is identical to the source identity
recorded inside the encrypted payload header and external public capture
receipt. This postcommit review independently recomputed and bound that source
path, Git blob, byte length, and SHA-256. The optimized binary SHA is identical
to the repository-external preserved verifier named in the core receipt.

## Independent Git-object reopen

The exact core commit was exported through `git archive` into a fresh private
temporary directory. No working-tree file was used for this check.

From that exported tree:

- the three path lengths and SHA-256 values above reopened exactly;
- the production Swift build completed;
- the separate test build completed;
- all four black-box tests passed;
- the production CLI still exposed no raw-key input surface;
- the in-process test still included a committed-WAL-only row through the
  Backup API;
- correct-key round trip and wrong-key, ciphertext, header, and truncation
  rejection remained green; and
- the public test output contained neither sensitive fixture plaintext nor raw
  plaintext equality digests.

## External custody rebind

The Git-object reopen does not substitute for ciphertext reopen. The accepted
external object remains:

- capture ID: `d12eabe4-d0fe-48b6-b2e8-2c906c03607e`
- ciphertext bytes: `9380966`
- ciphertext SHA-256:
  `575246b8c765b82fd86bd8100bd9791e46030736f494364d9270ba3440b68f0a`
- key epoch: `ds1-2026-08-28-v1`
- erasure scope: `project06-ds1-r0-through-r3`
- custody state: repository-external, owner-only, single-link, `0400`, `uchg`

The external ciphertext independently reopened three times, including after
`uchg` sealing and from the durably preserved exact binary path. Those passes
authenticated the private manifest, checked its scan binding, recomputed the
schema, six ordered query sets and roots, keyed public commitments,
`111/111/111`, `2716/111`, four dead locators and their common root,
`quick_check=ok`, and zero foreign-key rows without consulting the later live
workbench state. The capture-generation verifier established canonical JSON
object equivalence for the public receipt, not original raw-byte equivalence.
Its immutable historical labels are narrowed by the erratum in the core
receipt and must not be read more broadly.

## Acceptance statement

The time-sensitive encrypted-capture and same-device independently reopenable
snapshot portion of R0 / Acceptance condition 6 is evidence-backed, subject to
the independent repository-external final review after all corrections. This
receipt does not close the separate 111-row non-canonical inventory, per-row
R1 validation, R2 remediation, R3 closure, cross-device key recovery, official
canonical artifact restoration, or Deep Scan #3 readiness.
