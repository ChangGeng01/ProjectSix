# Qinao recovery-spine final forensic audit receipt

Date: 2026-08-28 (Australia/Melbourne)

Status: final non-production forensic evidence receipt for the A+ design and
source-disposition closure. This receipt grants no production implementation,
protected-worktree mutation, remediation, scan-launch, or Deep Scan #3
authority.

## Scan chronology is closed

The numbering source of truth is
`docs/superpowers/evidence/2026-08-28-qinao-deep-scan-numbering-user-decision.md`
(SHA-256 `ec8bad7e54a21d848bace04019ae02e37d3337f709fcd321fd49b7e0e07dd863`).
The final ledger reopens exactly this chronology:

1. Deep Scan #1 is the actual first successful Deep Scan:
   `bcffa52e-53cf-4407-b216-14288ae07061`, target
   `c8f80486895e12e26d567e610c35a6e2141b3489`, official state `complete`.
2. Deep Scan #2 is the later failed Deep Scan:
   `3d22f697-0c9d-4dbb-8c6a-871a9cfbcca9`, target
   `243c083f345f3586ef226020d42af4653b31a62a`, official state `failed`.
3. Deep Scan #3 is future-only: number `3`, state `notStarted`, scan ID `-`,
   target `pendingD0Freeze`, canonical state `canonicalPending`.
4. The Standard scan is separate and unnumbered: scan number `-`, kind
   `standard`, state `unknownFrozen`.

The Deep Scan #1 observation is frozen at
`docs/superpowers/evidence/2026-08-28-project06-deep-scan-1-index-observation.md`
(SHA-256 `f86f739b51334b9f18b7fedda4aa3e87116f9c1f6c3421798242e735a1c2d668`).
It records the official `complete` state, `111` findings, and `2,716`
locations while preserving `canonicalUnavailable`; it does not invent a
canonical artifact. The Deep Scan #2 incomplete inventory is frozen at
`docs/superpowers/evidence/2026-08-28-project06-failed-deep-scan-incomplete-lead-inventory.tsv`
(SHA-256 `5d97d0fba4071073521ce7cd17ed28be8cbd2fd3ac4fe928bdb394dac25d1b14`),
with `41` data rows. Neither evidence source is treated as a successful new
scan.

## Final specification and verifier

- specification path:
  `docs/superpowers/specs/2026-08-28-qinao-recovery-spine-and-deep-scan-closure-design.md`
- specification: `92,869` bytes, `1,556` LF lines, SHA-256
  `d2c7f8954d8559e8277a184035da1e76acf378475e630e4aadfa4b86268fa21b`,
  Git blob `84346d35c8f366dca792f0c2e9fdbfb5161dc584`
- verifier path:
  `docs/superpowers/evidence/2026-08-28-qinao-source-disposition-ledger-v1.py`
- verifier: `128,454` bytes, SHA-256
  `96ab8a3bdb9d7b87a8554ca6e83125ad7985a9936b49d558dbce2c8f578a21a7`,
  Git blob `5a5100a367b6061c195e45040a77ae48cb222a5e`
- named contracts: `7`, root
  `585e14ab6e320f55d4fa768ac7c3f7044eb81581410c17218007a2814ac2daee`

The final specification is the exact forward result of the three permanent
refreeze manifests and reverses through their declared predecessors:

- named-reference manifest SHA-256
  `38df28e67229a8e5e0b708202783ea33b2857d632dc35ef356bf4e7c614bd9bb`
- recovery-quality manifest SHA-256
  `9cceb52ea602306092d7c843378ccfeadbb14bd12b2cf1592c10db17328aa6d2`
- cross-UNIT self-containment manifest SHA-256
  `1eeac5177fdd551abf824ae8043031c2f270cd64cb1f8ea57d187106535eb0ee`

## Final formal ledger

- path:
  `docs/superpowers/evidence/2026-08-28-qinao-recovery-spine-source-disposition.tsv`
- `16,953,466` bytes; `10,294` physical lines: one header plus `10,293`
  data rows
- SHA-256
  `08927cf99433267ee5a1e602dfb3ae225cf6393426aa53c5188839c917228cb1`
- Git blob `696e18f7250e8f102d0734c88c60c7f1625e6c31`
- canonical row root
  `bfd2c4c5807008510299514fae32d1a1edf8154f0fbb874adba00b1d1e87a461`
- installed filesystem state at audit: regular file, mode `0600`, UID `501`,
  link count `1`

Record counts are exact:

- `325` UNIT
- `1,127` REQUIREMENT
- `2,073` CLAUSE
- `5,444` SOURCE
- `1,324` TARGET

The UNIT class partition is `238` normative-bearing, `63` evidence, `6`
introductory, and `18` mixed. The REQUIREMENT disposition partition is `531`
`projectionOfControlledRequirement`, `280` `newControlDeltaPendingAdmission`,
`217` `operationalScanGate`, and `99` `forensicRiskInput`. All `1,127`
REQUIREMENT rows and all `1,324` TARGET rows are `nonExecutable`.

The three stable projection roots are:

- UNIT class-set: `325`, root
  `3129b6e700aa67202d46688384d04d95ea0fb8cf43f5e9e0c8392a1a9eec1c70`
- REQUIREMENT semantic-set: `1,127`, root
  `93e3fe0dec5c8837643b2b838773f921ea2a06ecde307438b6cdec24a40d2a23`
- provenance mapping: `325 + 1,127`, root
  `402ea7a7e903aa2054c4fcb16fb66b3b22ee1804f8165e5e1b31607e3a577d5e`

The stable provenance projection deliberately excludes the verifier's exact
file identity to avoid a self-cycle. No identity is weakened: the full ledger
file and row roots commit the exact `VERIFIER28` SOURCE projection, and the
permanent integration contract independently binds that projection to the
verifier's path, locator, kind, byte length, SHA-256, Git blob, and admission
state.

## Permanent final correction layers

The two audit inputs are permanent exact-byte evidence, not hidden TEMP files:

- `docs/superpowers/evidence/2026-08-28-qinao-final-requirement-semantic-corrections.tsv`:
  `195` rows, `336,660` bytes, SHA-256
  `ec2d42d5871efc50b780d1d1a75ccb5afff40518100b903d746c4e4ec259d3fc`,
  Git blob `2293501d3842049f7fd645d5f165ba5a2a9b5e85`
- `docs/superpowers/evidence/2026-08-28-qinao-final-source-target-mapping.tsv`:
  `125` rows, `187,835` bytes, SHA-256
  `66bbe9246cff6ee338234cd4a91610b9ef6212faf9cb39297cc74739e51dc548`,
  Git blob `435a790f5c2137fa437486f44dfd45a2bc7769d5`

Both manifests have unique keys and are consumed exactly once. Their final
coverage partitions into `29` intersecting semantic-and-mapping rows, `166`
semantic-only rows, and `96` mapping-only rows. The mapping layer contains
`123` source-set changes, `2` source-order-only changes, `5` target changes,
and `2` disposition changes. The permanent test contract pins both manifest
byte hashes and directly compares all `166 + 125` applicable final projections:
disposition, execution state, ordered SOURCE IDs, ordered
`sourceID:sourceKind:admissionState` classes, and ordered seven-field TARGET
tuples.

## Independent semantic and graph audit

Independent reconstruction, without trusting the generator report, found:

- exact reverse coverage of all `1,127` REQUIREMENT IDs
- `668` REQUIREMENTs with explicit shared context and `0` context-only atoms
- `0` within-REQUIREMENT clause overlaps
- `0` illegal cross-REQUIREMENT partial overlaps
- `2,061` exact and `433` containment relationships, all closed as declared
  matrix reuse or complete-antecedent reuse
- `8,841` unique child rows, continuous ordinals, `0` duplicate consumption,
  `0` orphan rows, and `0` child-root errors
- `11` pending gates, `293` gated TARGET rows, and `0` scope conflicts
- `3` exact selector tuples under pending gate
  `Ledger.sourceDispositionAdmission`, covering `232` TARGET rows in one
  declared `reviewArtifact` scope

Old temporary coverage or roots receipts containing candidate identities
`7f30...` / `b71a...` were intentionally not permanentized. They are
superseded by this receipt's final `08927...` / `bfd2...` identities and named
root `585e...`.

## Adversarial generation and permanent-contract closure

The non-permanent generation harness was independently frozen during review at
SHA-256 `7c78813305ca041e7b6f27161e0c7c527d164405226ae8627e01b64a55353f56`;
its final contract was frozen at SHA-256
`cdb01270d0dcf14ce68f42f3c487f5af6c4ad8a79847b9c33581147d123962b8`.
They were removed with all other `.qinao-*` TEMP artifacts after successful
publication. They are audit history, not repository sources of truth.

The review reproduced and then closed these failures before publication:

- concurrent calls cross-contaminating global `SOURCES["VERIFIER28"]`
- two nominal verifier reopens trusting one monkeypatched function
- a report that did not freeze file SHA-256 and row root
- direct terminal writes leaving partial poison on failure
- concurrent publishers observing incomplete terminal bytes
- symbolic-link, weak-permission, wrong-byte, and foreign-shape terminal inputs
- process interruption after atomic link but before staging unlink
- verifier and manifest authenticate-then-reopen TOCTOU swaps

The final generator used a per-call source snapshot, a separately compiled
verifier from exact pinned bytes, frozen file and row identities, verified
private staging, and atomic no-overwrite publication. The permanent tests use
single-read authenticated byte snapshots for verifier execution and manifest /
ledger parsing.

Fresh pre-cleanup results were `8/8` final-generator contracts, `13/13`
historical override contracts, `2/2` presemantic contracts, and an independent
provenance projection pass. After TEMP cleanup, the permanent verifier suite
was `76/76 OK`, and the official verifier CLI returned `ok: true` with all
counts and roots above. The permanent test file at receipt creation has
SHA-256 `bc267400ff9fbea6ce15e4e77ec058f8603237ae199f75c72a84ad1c97df84b1`
and Git blob `269dfb7448158ec41cd9727b05e825708e33e34c`.

CodeRabbit was not authenticated, so no CodeRabbit result is claimed. The
review conclusions above come from independent local adversarial replay.

## Protected A worktree non-interference

The protected worktree
`.worktrees/qinao-dual-space-controlled-convergence` was read only. Its final
pre-commit audit fingerprint remained:

- HEAD `29d953a8ab7f1b8cfe83ae1f99c9ace620b2f895`
- HEAD tree `1f1efdf28bd31bb8fd5ec043e1f4f44fa11f6d01`
- `33` dirty or untracked status records
- NUL-delimited status SHA-256
  `45faece29aad471828a39eef3acc600d8828bf0e45133ad72ce83b76a1a6c875`
- no index lock

No production file, index entry, branch pointer, commit, or worktree state in
that protected checkout was changed by this forensic closure.

## Scope boundary and next gate

This receipt closes the A+ design / forensic source-disposition ledger and
repairs the durable evidence treatment of Deep Scan #1 and failed Deep Scan #2.
It does **not** claim that all `111` Deep Scan #1 findings have been remediated,
does **not** implement production A, and does **not** launch Deep Scan #3.

The next authorized sequence remains: obtain the required external encrypted
Deep Scan #1 snapshot approval, implement and verify A against the frozen
design, close and optimize the admitted Deep Scan #1 / #2 historical findings,
freeze the D0 launch boundary, and only then run the future full Deep Scan #3.
