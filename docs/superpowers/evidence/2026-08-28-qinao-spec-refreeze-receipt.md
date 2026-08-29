# Qinao recovery-spine specification refreeze receipt

Date: 2026-08-28 (Australia/Melbourne)

Status: non-production forensic review receipt. This receipt grants no source
admission, implementation, remediation, scan-launch, or protected-worktree
mutation authority.

## Superseded candidate identity

- path:
  `docs/superpowers/specs/2026-08-28-qinao-recovery-spine-and-deep-scan-closure-design.md`
- byte length: `91804`
- LF line count: `1556`
- Git blob: `ff95a9cbd948c5b5eb20c12ce5f41ba3bec4867c`
- SHA-256:
  `7091b29c237fdaad6fc4218977a08709fe05d890f3ab51c2c483e2e6457b93b6`
- extracted UNIT count: `337`
- class partition:
  `250 normativeBearing / 63 evidence / 6 introductory / 18 mixed`

The superseded candidate is not the final frozen specification and its
generated source-disposition ledger is not admissible for review closure.

## First refrozen candidate identity

- same path as above
- byte length: `92869`
- LF line count: `1556`
- Git blob: `148d1f133ef863abee6d1287c465e7ff2a3694ef`
- SHA-256:
  `c2d08c2cc25a5861c8d0cc53e8abe867d3165c4f5e4e329e2feab1fc6b6df1ed`
- extracted UNIT count: `325`
- class partition:
  `238 normativeBearing / 63 evidence / 6 introductory / 18 mixed`

This identity closed the cross-UNIT guard-scope defect described below, but a
later whole-ledger self-containment review found three remaining bare pronoun
dependencies. It is therefore superseded for ledger generation.

## Second self-containment candidate identity

- same path as above
- byte length: `92869`
- LF line count: `1556`
- Git blob: `bbdd79913518c11f69e5dd815b5e0be6248d1f9d`
- SHA-256:
  `e5bb5098ce484f0d561aa96f7bfe42c07adbd4a26e690dc2e22c4a057cc32c89`
- extracted UNIT count: `325`
- class partition:
  `238 normativeBearing / 63 evidence / 6 introductory / 18 mixed`

The second repair is byte-length- and line-count-preserving. It names the
protected design-input tuple as `C08`, replaces L70's bare `These values` with
the self-contained subject `C08 bindings` so its same-UNIT `they` has a unique
antecedent, and replaces the L539 bare `Its`
with the exact retention-class subject `` `recovery72Hours` retention is >= ``.
The L57/L59 alias edits have net zero bytes, and the L70/L539 substitutions are
individually equal-length, so no later byte offset moved. Only the semantic
identities of the four affected UNITs at lines 57, 59, 70, and 539 changed.
Two independent reviews confirmed that `currently observed` remains explicit,
the 259,200,000-millisecond lower bound and higher-priority fences are
unchanged, and neither named entity substitutes for its exact SOURCE binding.

That candidate is superseded by the named-reference refreeze below. Its bytes
remain the mandatory reverse-replay base for the first named-reference repair.

## First named-reference refreeze identity

- same path as above
- byte length: `92869`
- LF line count: `1556`
- Git blob: `1b601fce9feb116d1b845d61aeabe0725ff62a56`
- SHA-256:
  `e52d6b0b8f2811c1c1b3ed1b339c4c85a45ac25e81e45537cc3e6158f76e7d41`
- extracted UNIT count: `325`
- class partition:
  `238 normativeBearing / 63 evidence / 6 introductory / 18 mixed`
- permanent replacement manifest:
  `docs/superpowers/evidence/2026-08-28-qinao-named-reference-refreeze-manifest.tsv`
- replacement-manifest SHA-256:
  `38df28e67229a8e5e0b708202783ea33b2857d632dc35ef356bf4e7c614bd9bb`
- replacement closure: `30` non-overlapping equal-byte/equal-LF replacements
  in exactly `29` UNITs; all other UNIT raw spans, locators, classes, IDs, span
  hashes, and semantic hashes are unchanged

Three independent read-only checks reconstructed this identity from the second
self-containment candidate, verified every old and new byte slice inside its
declared UNIT, reversed the first named-reference bytes exactly to
`e5bb5098ce484f0d561aa96f7bfe42c07adbd4a26e690dc2e22c4a057cc32c89`,
and found no structural, byte-offset, line-count, class-partition, self-hash, or
dependency-cycle drift. This identity is now the mandatory reverse-replay base
for the recovery-quality refreeze below.

The repair replaces residual cross-UNIT deixis with six typed names:
`ReportProjectionV1`, `VerifierV1`, `UnitNormV1`, `HeaderV1`,
`RecordShapeV1`, and `AuthoritySetV1`. Definitions precede their references.
`HeaderV1` uniquely resolves the 64-name fenced-code UNIT
`QUN-f72aa897afa9968903edcbab`; `VerifierV1` binds only its exact source path,
while verifier bytes remain ledger- and external-receipt-bound to avoid a
self-hash cycle. The repair also makes A0, A3, R1, R3, D0, D1, Deep Scan #1
snapshot, Deep Scan #2 lead-list, #3 handoff-claim, and R2 admission subjects
explicit without changing their underlying obligations.

## Recovery-quality named-set refreeze identity (superseded)

- same path as above
- byte length: `92869`
- LF line count: `1556`
- Git blob: `c9f76d21f10ec129636e8e7accb666fc17a5d9e6`
- SHA-256:
  `3d97a07187a9f61230ac248609f652db08662877e6203b54833c650c5fe9bf22`
- extracted UNIT count: `325`
- class partition:
  `238 normativeBearing / 63 evidence / 6 introductory / 18 mixed`
- chained replacement manifest:
  `docs/superpowers/evidence/2026-08-28-qinao-recovery-quality-refreeze-manifest.tsv`
- chained-manifest SHA-256:
  `9cceb52ea602306092d7c843378ccfeadbb14bd12b2cf1592c10db17328aa6d2`
- replacement closure: `2` non-overlapping equal-byte/equal-LF replacements;
  all physical line numbers, byte offsets, UNIT locators, and the global
  byte/line shape remain unchanged

The first replacement turns the five ordered incumbent
`BASRecoveryQuality` cases into the closed named set
`RecoveryQualitySetV1`. The second replacement binds the reducer, authority,
and alias/wire prohibitions directly to that name. The heading-path change
updates exactly the five case UNIT identities at lines 341, 343, 344, 346, and
348; the direct reference updates exactly the prose UNIT at line 350. No other
UNIT raw span or identity changes. Independent reverse replay reconstructs the
first named-reference SHA-256
`e52d6b0b8f2811c1c1b3ed1b339c4c85a45ac25e81e45537cc3e6158f76e7d41`
exactly.

`RecoveryQualitySetV1` is the seventh typed name. Its contract is not satisfied
by occurrence count alone: validation must bind the definition heading, the
ordered exact five case UNITs, and the separate invariant reference. Any
renaming, reordering, added case, missing case, or unregistered heading
occurrence fails closed.

This identity is superseded only by the cross-UNIT self-containment refreeze
below. Its bytes remain the mandatory reverse-replay base for that repair.

## Final cross-UNIT self-containment refreeze identity

- same path as above
- byte length: `92869`
- LF line count: `1556`
- Git blob: `84346d35c8f366dca792f0c2e9fdbfb5161dc584`
- SHA-256:
  `d2c7f8954d8559e8277a184035da1e76acf378475e630e4aadfa4b86268fa21b`
- extracted UNIT count: `325`
- class partition:
  `238 normativeBearing / 63 evidence / 6 introductory / 18 mixed`
- chained replacement manifest:
  `docs/superpowers/evidence/2026-08-28-qinao-cross-unit-self-containment-refreeze-manifest.tsv`
- chained-manifest SHA-256:
  `1eeac5177fdd551abf824ae8043031c2f270cd64cb1f8ea57d187106535eb0ee`
- chained-manifest Git blob:
  `629ae85ef7d5cbb4be886b8b905d1711931c235c`
- replacement closure: `3` non-overlapping equal-byte/equal-LF replacements
  in exactly `2` UNITs; all physical line numbers, byte offsets, UNIT locators,
  the `325`-UNIT partition, and the global byte/line shape remain unchanged

The repair removes two residual cross-UNIT grammatical subjects without
changing any obligation: the line-798 deterministic-cut test UNIT now names
the post-cut test as the actor at both comparison boundaries, and the line-1525
acceptance UNIT names this specification as the review object. Their UNIT IDs
change respectively from `QUN-e7584eb8471e4f0e7d214d3b` to
`QUN-857fdfdd623962759da93688` and from
`QUN-4a5aabbd80052ba6b9a85a56` to
`QUN-04518c32fa5da203726e91bc`.

Two independent byte-slice replays validated all three manifest records,
non-overlap, equal byte and LF counts, exact forward reconstruction of this
identity, and exact reverse reconstruction of
`3d97a07187a9f61230ac248609f652db08662877e6203b54833c650c5fe9bf22`.
A separate semantic replay found exactly `37` REQUIREMENT IDs whose parent UNIT
identity changes while every declared CLAUSE span stays byte-identical inside
the replacement UNIT. No typed-name definition/reference, source authority,
scan number, scan state, or scan identity is touched. This is the final frozen
specification identity for all downstream ledger generation and verification.

## Closed reasons for refreeze

Independent semantic-forward-completeness review found that v1 CLAUSE rows may
refer only to bytes inside their own parent UNIT. Several prose or list-leader
lead-ins supplied a guard, conjunction, closed-set, or mode context to nested
child UNITs, but the closed v1 TSV schema has no parent-requirement/context-edge
field. Separate parent and child REQUIREMENT rows therefore committed adjacency,
not the required logical relationship.

The minimal repair converts those lead-ins into complete ATX headings. The v1
UNIT semantic identity already commits the full heading path, and each
REQUIREMENT semantic identity commits its UNIT ID, so every descendant atom now
reopens its guard or closed-set context without cross-UNIT CLAUSE spans. Explicit
sibling headings close each modified scope. The D0 launch-mode requirement was
folded into one list UNIT that names the exact two-value closed set and keeps the
two definitions in continuation prose.

No production owner, Wave, implementation sequence, scan launch, or remediation
was admitted by this repair. In particular, the refreeze preserves exactly:

1. Deep Scan #1 is the actual first successful Deep Scan;
2. Deep Scan #2 is the later failed Deep Scan;
3. Deep Scan #3 remains not started and has no scan ID; and
4. the Standard scan remains separate and unnumbered.

Every UNIT, REQUIREMENT, CLAUSE, SOURCE, TARGET, row commitment, ledger root,
and file digest derived from any superseded candidate must be regenerated and
independently reverified against the final cross-UNIT self-containment refreeze
identity above.
