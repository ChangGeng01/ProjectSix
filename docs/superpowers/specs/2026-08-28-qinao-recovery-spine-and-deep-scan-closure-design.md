# Qinao Recovery Spine A+ and Deep Scan Closure Design

Date: 2026-08-28

Status: user-approved design direction; written-spec review pending

Execution authority: none. Review, approval, or commit of this specification
does not admit it or authorize production changes.

## Decision

Project06 will complete Qinao Recovery Spine A+ before launching Deep Scan #3.
### A+ has all and only two inseparable outcomes

1. A0-A4 group the acceptance evidence for a durable, restartable runtime spine
   covering conversation, plan, Agent/Sub-agent, graph, context, and external-
   operation continuity.
2. R0-R3 optimize and close the separately preserved results of the successful
   Deep Scan #1 and the 68 non-authoritative candidates plus 41 E4 leads
   recovered from failed Deep Scan #2.

Only after both outcomes pass their gates may D0-D2 freeze a clean target and
launch Deep Scan #3. Deep Scan #1 is never mutated or renumbered, and failed
Deep Scan #2 is never represented as complete or reused as Deep Scan #3.

## Authority and execution ordering

This document is a non-authoritative design and acceptance supplement. A0-A4
are closure-gate labels, not Waves, owners, production slices, or an
implementation sequence that competes with the incumbent plan. Production
implementation continues to obey the sole active convergence master and its
fixed W0 → W1 → W2 → W3 → W4 → W5 → W6 dependency order.

### Before implementation planning, every requirement receives exactly one of the following four source dispositions


- `projectionOfControlledRequirement` with exact controlled path, stable
  requirement locator, source identity, and admission state;
- `forensicRiskInput` for frozen historical-scan evidence;
- `operationalScanGate` for non-production Deep Scan #3 controls; or
- `newControlDeltaPendingAdmission`.
### Adoption and execution boundary
Approval of this file grants no ambient adoption. A production-relevant delta
whose controlled source is still pending, or that is not already present in a
legally admitted controlled source, must pass the incumbent source-admission
and controlled-document process before use.
R0-R3 and D0-D2 must be transplanted into the sole active plan as governed risk
or operational gates; they do not become a second plan. The A labels may be
closed only after the corresponding W0-W6 work and receipts exist.

## Frozen inputs and evidence status

### Global recovery design candidate

The existing design candidate is:

`docs/superpowers/specs/2026-08-10-qinao-global-invariant-firewall-and-recovery-design.md` (`C08`)

`C08` currently observed protected identity:

- worktree:
  `/Users/changgeng/Project/Project06/Project06/.worktrees/qinao-dual-space-controlled-convergence`;
- branch: `codex/qinao-dual-space-controlled-convergence`;
- observed HEAD: `29d953a8ab7f1b8cfe83ae1f99c9ace620b2f895`;
- byte length: `233726`;
- line count: `3769`;
- SHA-256:
  `4eb06cde16e0cf5985c7272147ced9274dd83648a098772c8b5a06f7b3ebeab6`.

C08 bindings identify a design input; they do not admit it, make it production
authority, or authorize modification of the protected P0 worktree. A0 must
bind the exact eventual commit, tree, blob, length, and digest from outside
that design file before any production implementation consumes it.

### Sole active-plan candidate

Several exact frozen ABIs used below currently appear only in the protected
candidate overlay of the sole convergence master:

`docs/superpowers/plans/2026-07-29-qinao-dual-space-automation-controlled-convergence.md`

Its observed protected identity is 24,628 lines, 1,417,949 bytes, SHA-256
`fc17dc82afb4e2fbd1f8c4a6854afae090045ada3ae45184c82ec959584e3e10`,
under the same protected worktree and HEAD identified above. The matching
33-path preservation row is in
`.superpowers/sdd/2026-08-24-qinao-p0-execution-containment/protected-33-pre.tsv`,
whose SHA-256 is
`ecb8cbd1c54b05eb6a85f0dd6663fd04cf85e7cc25ec0b4d3cd27dc1a4f36d23`.
This overlay is protected pending intake, not ambient production authority.
Any source-disposition row that cites it remains non-executable until A0 gives
the exact path a lawful included/superseded/rejected disposition and the sole
controlled plan is fixed by an admitted commit/tree/blob.

### Deep Scan chronology and identity separation

The user-authoritative chronological naming is:

1. Deep Scan #1: `bcffa52e-53cf-4407-b216-14288ae07061`, the first successful
   Deep Scan;
2. Deep Scan #2: `3d22f697-0c9d-4dbb-8c6a-871a9cfbcca9`, the later failed
   Deep Scan; and
3. the not-yet-started run after A+ will be Deep Scan #3.

The contemporaneous, non-production transcription of that user decision is
`docs/superpowers/evidence/2026-08-28-qinao-deep-scan-numbering-user-decision.md`.
It binds the naming decision, while the independently observed scan records
bind IDs, targets, and official states; neither source is allowed to impersonate
the other.

The current public context for Deep Scan #1 reports mode `deep`, target revision
`c8f80486895e12e26d567e610c35a6e2141b3489`, progress status `complete`, 39
completed independent reviews through pass 35, and 111 findings: 30 high, 65
medium, and 16 low. The bounded context exposes only 20 findings and currently
reports `reportAvailable: false` with an empty artifact map,
`handoffClaimedAt: null`, no continuation thread, and no claim token. The
recorded temporary scan directory no longer exists. The official completed-scan
read currently fails with the exact error `Codex Security scan artifact root is
not a safe regular directory.` A claim cannot recreate the missing root.

The bounded read-only database observation is frozen at
`docs/superpowers/evidence/2026-08-28-project06-deep-scan-1-index-observation.md`
(6,034 bytes, 138 lines, SHA-256
`f86f739b51334b9f18b7fedda4aa3e87116f9c1f6c3421798242e735a1c2d668`).
At `2026-08-28T01:55:35Z`, its immutable read observed one `complete`/`deep`
scan row, 111 distinct occurrence rows for 111 distinct finding IDs, the exact
30/65/16 severity split, 2,716 location rows covering all occurrences, valid
indexed details JSON for all occurrences, and four artifact locators pointing
to the same missing temporary root. The observation copies no finding body and
is not a database backup; its live-database hash is explicitly point-in-time.

Deep Scan #1 therefore has two separate evidence states: an official completed/
indexed scan record, and currently unavailable sealed canonical manifest,
findings, and coverage JSON plus the separate official unsealed report
projection. Before any mutating remediation, R0 must use a bounded
read-only SQLite snapshot/backup or deterministic query serialization to build
a clearly non-canonical forensic inventory of all 111 indexed occurrences for
current-source remediation. It must not call that inventory the sealed report,
copy a live main database while a WAL may exist, or infer the missing 91 rows
from counts.
Canonical-document recovery remains an external availability blocker unless
the official service restores it.

The separate scan `dd2acd18-3ead-44fa-9c10-f8fd8c911aa7` is mode `standard`,
not Deep Scan #1. Its 63 findings (2 medium, 61 low), evidence token
`59ad886e-6663-4c74-9ac1-b85ec68c1a8e`, and evidence digest
`351ad8736ab263b314313e7fd497d21cbd638a93b92fad8811e7b4fd6f82f280`
remain a useful cross-check but never enter the Deep Scan numbering or silently
substitute for Deep Scan #1's 111 findings.

### Failed Deep Scan #2

The authoritative scan remains:

- scan ID: `3d22f697-0c9d-4dbb-8c6a-871a9cfbcca9`;
- target revision: `243c083f345f3586ef226020d42af4653b31a62a`;
- official state: `failed`, discovery pass 9;
- independent reviews completed: 10;
- files inventoried: 10,347;
- official findings: 0;
- report: unavailable;
- terminal fault: missing
  `discovery-0004/output/result.json` during `realpath`.

Commit `8ba2914dcaa2771051653609c96c6cd5e62914c0` preserves the separate
non-authoritative forensic recovery. Its 68-row aggregate is supported by a
successful reducer acceptance acknowledgement, 131 terminal source-finding
references, 452 source-location references, and SHA-256 identities for 65
session records. Aggregate-payload survival and canonical scan completion are
not established.

The six committed forensic source identities are:

- `docs/superpowers/evidence/2026-08-28-project06-failed-deep-scan-candidate-index.tsv`:
  blob
  `68285a42c36e3b659207f375b38aeb58fdb9a5a2`, 11,241 bytes, 69 lines,
  SHA-256 `9e281aa8d8b9f357867a40193e7ae8dcfe5ea0e215e5b80dc7e3efd42b3342db`;
- `docs/superpowers/evidence/2026-08-28-project06-failed-deep-scan-candidate-locations.tsv`:
  blob
  `c6255eb9c95da5be5b41458ced74af3b1227da44`, 38,182 bytes, 69 lines,
  SHA-256 `4cb0a86c87f0faa556a5e3432218220e226d79a1ec3657f9738a443c37e8aa10`;
- `docs/superpowers/evidence/2026-08-28-project06-failed-deep-scan-forensic-recovery.md`:
  blob
  `181d8e9ab08002fb7fb8b943ec8732f3c9387209`, 13,561 bytes, 273 lines,
  SHA-256 `4ef47d59f4eac040f99c8c2234675e32fe97b287dc015c10e716a7e6b4cdb350`;
- `docs/superpowers/evidence/2026-08-28-project06-failed-deep-scan-incomplete-draft-leads.md`:
  blob
  `0ec8c67cd039f0c860e9dd9404e8ec0b352ea72a`, 5,405 bytes, 112 lines,
  SHA-256 `88d5b4c4cb1c27cf330c824c66954bcbc1b2e229403ecfe36d1d36e04ea1cf3f`;
- `docs/superpowers/evidence/2026-08-28-project06-failed-deep-scan-session-sha256.txt`:
  blob
  `5cedf4b632404ba8edcc577b864a3d30b065a16a`, 11,942 bytes, 71 lines,
  SHA-256 `8e0992cbac6490575a98713f337bffeb3a222525efaf131839133a0dabf54fe6`;
  and
- `docs/superpowers/evidence/2026-08-28-project06-failed-deep-scan-worker-inventory.tsv`:
  blob
  `2e840228072ff7f8a508829c76318a4931fe750e`, 2,270 bytes, 15 lines,
  SHA-256 `b820383a5809f2253bd803f9d9f16fcb11667f8bcff0c6c47d84cf4bece8dccd`.

R0 reopens all six paths and verifies the 68 candidate rows, 452 location
references, 131 terminal source-finding references, 14 worker rows, 65 session
hashes, and 41-row source-prose domain in both directions. Reopening only the
aggregate and location files is incomplete.

The recovered labels are:

- 7 high, 43 medium, and 18 low;
- 64 high-confidence and 4 medium-confidence labels;
- 66 rows requiring current-source revalidation;
- 1 row overlapping the prior open W5 buffering residual; and
- 1 HumanEval row closed on the newer P0 branch.

These are triage labels, not sealed vulnerability verdicts.

Discovery workers 0011-0014 also left segregated incomplete-draft leads. They
are not part of the terminal 68, cannot be promoted into that aggregate, and
cannot be discarded. R0-R3 maintain a separate lead crosswalk that maps every
distinct incomplete lead to a terminal candidate, a proven duplicate, an
evidence-backed non-applicable result, or an explicit unresolved blocker.

The mechanically bounded inventory is
`docs/superpowers/evidence/2026-08-28-project06-failed-deep-scan-incomplete-lead-inventory.tsv`:

- source prose SHA-256:
  `88d5b4c4cb1c27cf330c824c66954bcbc1b2e229403ecfe36d1d36e04ea1cf3f`;
- inventory file SHA-256:
  `5d97d0fba4071073521ce7cd17ed28be8cbd2fd3ac4fe928bdb394dac25d1b14`;
- data-row count: 41; and
- domain-prefixed data-row root (`qinao-incomplete-lead-inventory/v1\0`):
  `f6cc0b4793e18e6068af32ce8e328dfc5c45ef5a2179c9f8293a8a89e6068843`.

The 41 rows comprise 14 acknowledged `complete:false` draft findings, 4
acknowledged coverage signals, 10 emitted deferred leads, 11 raw-child
unreconciled leads, and 2 schema-rejected replacement additions. Each has a
stable ordinal/ID, exact source-line span and span SHA-256, E4 tier, and
acknowledgement state. Forward validation checks every row against its source
span; reverse validation checks that every acknowledged, coverage, deferred,
raw-child, and rejected-addition phrase in the frozen prose has exactly one
inventory interpretation. This inventory remains disjoint from terminal-68
ordinals and never upgrades E4 evidence.

### Deep Scan operational contract snapshot

The D gates are based on the observed repository-external proprietary Codex
Security plugin `0.1.22`, not on a Qinao runtime contract. The frozen source
identities used for this design review are:

- `.codex-plugin/plugin.json`:
  `97389533fa07f8b8367f0a2c79fc20b492898e0b1e5341d8b36af337cbf67a27`;
- `.mcp.json`:
  `0831865b9dc261b7a28fbef09f139a4214fac51fa711f531604977c48c6c08d0`;
- `mcp/server.mjs`:
  `c58624aa4c4bd3efbb67601c9c2e98759f167f608320a6cd342814b2f2e6a636`;
- `mcp/server.mjs.br.part-000` (140,000 bytes):
  `59f074501a4073fcc166aba60d713b3879cce6461b01585186523dcac70d600a`;
- `mcp/server.mjs.br.part-001` (80,603 bytes):
  `f7e00159df0da9fa5518b1efba17f3b3b4c23739cd491bbfd43aa23765724a75`;
- lexically sorted compressed-chunk concatenation (220,603 bytes):
  `6280608256f1e7a6fa423d0c1e129c278d732715f54544b11e24ea8ec59cb8b6`;
- Brotli-decompressed MCP runtime source (1,519,560 bytes):
  `5b092fbe6692c14a0d5cf41e356d3bfcccfd98693963ef5b09d689741649a9db`;
- `scripts/workbench_db.py`:
  `cff0fd90fbbd530c36b9d46343a192521c7b78c0c6f93f90ed2874ab2b204244`;
- `scripts/workbench_schema.py`:
  `361e0d1a0efa97e2c0f560b285d0d8c4492ad1d2dc192d057aeeff06169cd399`;
  and
- `scripts/deep_scan_workbench.py`:
  `ca30ff5fc1445be07de02759443397b7fd556e0150ea50919fae2d22d63a9253`;
- `skills/deep-security-scan/SKILL.md` (13,011 bytes):
  `cda41a088805a3c1b4c8b7e1927d57017351a594ac55a84e07b1aa8c519e443c`;
- `references/scan-prologue.md` (4,693 bytes):
  `a8320cd7244b689966496c294bd255910f8cceee8faec593ed5dc415955deea5`;
  and
- `references/core-scan.md` (19,006 bytes):
  `e8be71ca85643e9f31e0e8f6354551738ea2783afca72491535645dd83d63454`.
- `references/scan-contract.md` (11,369 bytes):
  `1cc5b5098d5b98e2090da7cfa7b49643eee0f245f1ca2d8b2ceb57a37331f162`;
- `schemas/scan-manifest.schema.json` (8,048 bytes):
  `265a48629113f77cd65a3127f1f7e95d3c39ae60e868685837a6aa31d4133310`;
- `schemas/findings.schema.json` (19,167 bytes):
  `a480337cc0fa4c48c44fc7be17c6c4348767815570775cda80f2aaf797b8e56c`;
- `schemas/coverage.schema.json` (4,670 bytes):
  `7964b132998ca4dcdd19c75f5d92483e1d44cb71462237709b968ec548c10652`;
- `scripts/finalize_scan_contract.py` (115,478 bytes):
  `c30dd1d26f2e775f4add54c9693b3e6fd5277460c955b4bf7a6a401e64d66918`;
- `scripts/report_projection.py` (41,677 bytes):
  `d7a90862f92c29e2eb30c36dfa52c6e01a7c53a6cfa6ed4866b1a58aadae34ed`;
  and
- `scripts/validate_scan_contract.py` (3,803 bytes):
  `38a5eb0126ea06b22eb82c5829e4ffcbebd2c1e55f99634454622fedd7b9e1a0`.

At that identity, the worker table stores result-manifest paths but no durable
payload blob/digest, and terminal failure is immutable. The public workflow can
rejoin an active/resumable scan by the same scan ID and handoff claim after a
detached waiter or MCP restart; it does not expose a terminal-failed-scan revive,
partial-aggregate import/export, or reconstruction API. The observed headless
start surface also exposes no per-run scan-root/vault parameter and may block
before a usable scan ID/path is available. D0 must re-read and rehash the
installed plugin, Deep Scan skill, three workflow/contract references, three
canonical schemas, finalizer, report projector, validator, and its live
callable schema. Any change reopens the D0 source-disposition review; this
snapshot is evidence, never permission to rely on an undocumented internal
API.

## Architectural constraints

### One authority per kind

A+ creates no second Conversation Store, Plan Store, checkpoint Store,
milestone Store, context compiler, task manager, recovery manager, mutable
head, scheduler, publication authority, or effect authority.

- Immutable bodies and structural payloads use the incumbent Artifact Mesh.
- Mutable currentness, operation identity, epochs, CAS, and logical heads use
  the sole K3 writer backed by the incumbent EventLog persistence boundary.
- K4 owns capability grants and uses, never domain state.
- `BASContextCompiler` remains the sole context compiler.
- Existing publication and effect owners retain their physical outbox and
  possible-start responsibilities.
- The single incumbent `ContextContinuityManifest` is the immutable recovery
  projection over owner evidence. No other recovery-manifest schema, registry
  row, Store, or authority is introduced.

### Truth versus acceleration

Recovery truth consists of committed message bodies, conversation and Mission
heads, accepted Solution artifacts, typed plan state, owner receipts, stable
operation identities, and the verified incumbent `ContextContinuityManifest` /
current `BASContinuationCheckpointRef` / K3 install-receipt chain.

Embeddings, reranker scores, summaries, FTS indexes, caches, local KV images,
and presentation projections remain rebuildable acceleration. Their loss must
not erase or rewrite source truth. Granite embedding and KaLM reranking retain
their distinct retrieval roles; an unavailable role produces a typed coverage
deficit rather than silently disappearing.

### Honest recovery levels

#### `RecoveryQualitySetV1` is exactly these five `BASRecoveryQuality` cases, the derived non-Codable UI projection over reopened evidence.


- `exactAppOwnedBytes`: required Qinao-owned committed bytes and receipts reopen
  byte-exactly;
- `deterministicReplay`: pure work re-executes from the same frozen inputs;
- `semanticReconstruction`: disposable execution state is reconstructed from
  accepted semantic truth;
- `externalReconciliation`: a possibly started external operation is queried
  or reconciled under its original identity; and
- `unavailable`: lawful recovery cannot be proven.
#### Recovery-quality invariants and non-persistable limits
`RecoveryQualitySetV1` is no reducer input, authority, or alias/compatibility
wire material.

A+ does not claim to persist unsent hidden reasoning, a dead Swift stack, an
arbitrary PTY/process handle, an open socket, remote Provider/PCC hidden state,
or OS-private memory. A dead PTY reopens its admitted invocation manifest and
accepted transcript prefix; it is not described as the same live process.

## Considered architectures

### Selected: layered Artifact/K3 Recovery Spine

Each incumbent owner emits only its already classified bounded Artifact or
receipt. The incumbent continuity manifest references that fixed evidence
matrix, while one K3 CAS chooses the active checkpoint Ref generation. Cross-
database writes are staged and reconciled; they are never misrepresented as
one physical transaction. This reuses incumbent authority, supports incremental
adoption, and permits crash testing at every boundary without a generic
participant protocol or registry.

### Rejected: EventLog-only recovery

The EventLog already provides useful ordering and replay, but it is not a safe
substitute for immutable bodies, large typed snapshots, retention receipts,
custody, or external-owner state. Making it contain everything would create a
second Artifact Store and enlarge the K3 writer into an unbounded bottleneck.

### Rejected: monolithic virtual-machine-style snapshot

A single giant snapshot couples every subsystem, requires global stop-the-
world behavior, cannot honestly capture remote or OS-private state, and makes
schema migration and partial degradation unsafe. It also encourages a false
promise of bit-identical recovery where only semantic reconstruction is
possible.

### Limited auxiliary: Deep Scan receipt vault

A repository-external, read-only receipt vault may mirror future Codex
Security worker and reducer evidence. It is operational insurance, not Qinao
runtime authority and not an official scan-restoration interface. It cannot
make a terminal failed proprietary scan resumable.

## A0 — Legal source admission and controlled-plan convergence

A0 admits the exact 2026-08-10 design through the incumbent controlled-source
protocol before any A1-A4 production code is written.

1. Freeze the complete protected 33-path P0 worktree as a preservation snapshot
   and path manifest without changing it. This snapshot prevents loss and
   supports later intake; it is not the V2 transition-02 candidate tree.
2. Construct the design-admission base from the exact admitted V1 state where
   the 2026-08-02 design edge is present and the 2026-08-10 design blob is
   absent. The V2 transition-02 candidate tree differs from that base by only
   the exact 2026-08-10 blob. None of the other 32 protected paths enters this
   transition.
3. Freeze the design-source identity separately: exact repository path,
   containing source commit/tree, Git blob, byte length, SHA-256, and the two
   ordered design tuples. The design blob cannot state or validate its own
   admission authority.
4. In an external approval/amendment record, independently bind the amendment's
   own commit/tree, exact tool/controller identity, stable V2 operation identity,
   direct and immediate V1 transition-02 predecessor receipt, logical registry
   ordinal 02, signer scope, protected ref, and exact protected-policy
   predecessor. The stable V2 identity additionally binds both ordered design
   tuples, the exact V2 base tree that already contains 08-02, and the exact V2
   candidate tree that differs only by the pinned 08-10 blob. The 33-path
   preservation tree is never substituted for either tree. The V2 operation/
   receipt binds the amendment identity and the design-source identity from A0 step
   3; retry or lost reply looks up that complete identity, and changed bytes
   never mint another transition.
5. Version logical design transition 02 as the already designed V2 bundle;
   preserve historical V1 replay byte-for-byte.
6. After the design transition is accepted, route each of the other 32
   protected paths through its incumbent Tasks-0-2 intake and explicit
   included/superseded/rejected disposition. Preservation never grants ambient
   adoption.
7. Transplant every production-adopted requirement into the fixed seven
   controlled documents: the sole active convergence master plus six domain
   documents. The design remains evidence, not an eighth controlled document.
8. Recompute closed owner, path, selector, risk, Wave, and dependency
   inventories. No prose-only precedence or ambient adoption is legal.
9. Prove that admission alone changes no W1-W6 production behavior.

### All and only the following V2 transition-02 presence-matrix predicates must pass A0

1. exact 08-02 present and 08-10 absent admits only the pinned 08-10 blob;
2. Exact 08-02/08-10 pair plus matching V2 receipt returns byte-identical
   `alreadyPresent`;
3. Exact 08-02+08-10 state with a missing/stale/foreign V2 receipt quarantines
   as unadmitted foreign state;
4. absent or mismatched 08-02 fails as an invalid predecessor; and
5. any 08-10 path/blob/length/digest mismatch fails as foreign state.
### V2 lineage and fail-closed invariants
Historical V1 receipts replay byte-for-byte, transitions 03-19 retain their
logical names and relative order under V2, and no transition 20 or W0-W6 action
may precede the valid V2 transition-02 receipt.

Every V2 transition 03-19 operation key and receipt is schema-distinct from its
historical V1 counterpart and binds the exact V2 transition-02 candidate tree
as its immediate design-source predecessor. No V1 downstream receipt/key may
be reused, reinterpreted, or backfilled to continue a V2 chain. This preserves
historical V1 replay while preventing a valid V2 transition 02 from reconnecting
to a stale V1 downstream lineage.

A0 fails closed on changed bytes, missing predecessor evidence, a second
controlled plan, a new owner/Store/Manager, or a partially admitted design.
The forensic-recovery branch that contains this specification is evidence and
design review space, not an implicit implementation base. Implementation branch
selection occurs only after the preservation snapshot, V2 design-admission
tree, and every remaining-path intake disposition are fixed.

## A1 — Durable identity, receipt, retention, and head kernel

A1 groups the minimum common protocol evidence required by every later named
incumbent lineage.

### Immutable identity and receipts

- Payloads use strict versioned schemas and canonical injective bytes.
- Public build material may use a public SHA-256 digest. Confidential content
  uses a domain-separated keyed commitment with key epoch and erasure scope;
  raw plaintext equality digests do not escape custody.
- The common stable semantic operation identity binds only owner, Workspace/
  Session/incarnation, operation kind, and a caller-independent request/
  idempotency identity. It is not merely a content digest. Each operation kind
  then uses its incumbent closed presence matrix to decide which immutable
  predecessor or epoch coordinates are additionally bound in that row. Mutable
  physical CAS-attempt heads, high-water marks, retry counters, and generally
  changing epochs are never added to the common identity merely because they
  are current at first attempt; lost-reply and possible-start recovery must
  still find the original operation after those coordinates advance. A retry
  reopens that operation-kind-specific binding and rechecks currentness rather
  than minting a new semantic operation.
- Exact retry returns the originally committed byte-equal receipt.
- Same operation identity with different semantic bytes is corruption.
- The authoritative transaction first commits canonical receipt bytes and the
  incumbent pending-materialization fact. Any required historical postcommit
  receipt Artifact is then materialized and byte-equal reopened through the
  incumbent repair path before another owner may consume it or the operation
  may report final usable success. A crash or lost reply repairs/reopens the one
  committed decision; it never synthesizes a new receipt or exposes an
  uncommitted one.

### Pre-put reservation, claim, and binding

No independently persisted Artifact is written first and later registered with K3.
#### Every put must use all five ordered stages of the incumbent phased `BASRetentionAdmissionRequest` below

1. K3 enters `identityPreparing` before Artifact identity preparation and
   persists the semantic operation, Artifact-store incarnation, commitment-key
   epoch, erasure scope, purpose, deadline, and authenticated generation.
2. The sole Artifact actor returns a transient `BASPreparedArtifactIdentity`.
   K3 attaches its expected Artifact ID and typed commitments, then creates the
   stable `retentionAdmissionID` reservation and content-free precommit
   blueprint.
3. K3 transitions `reserveExpectedArtifact` to `claimReservedPut`, persists the
   claim generation and complete authenticated reserved-put authorization, and
   fixes `claimDeadline` plus
   `provisionalMinimumRetainUntil = claimDeadline + 259,200,000` using the
   rollback-protected K1 trusted-time coordinate.
4. The package-private put validates reserved-put authorization and, in the
   same Artifact transaction as the immutable record, appends the exact
   `artifact_put_claim_binding` and authenticated commit proof.
5. Outside all transactions, K3 reopens the body, binding, and proof; a short
   `bindAndAdmitReservedArtifact` transaction rechecks current epochs and binds
   final retention. It sets
   `minimumRetainUntil = max(provisionalMinimumRetainUntil,
   bindCommittedAt + 259,200,000)` on the rollback-protected K1 coordinate;
   addition is overflow-checked and rollback/boot-domain ambiguity fails
   closed. Exact retry reopens reserved ticket/proof/receipt.
#### Crash residue and orphan invariants
A pre-identity crash leaves a finite preparation row. A post-put/pre-bind crash
remains enumerable through `expectedArtifactID` and the claim binding, retains
its provisional horizon, and resumes without a second content put. An
unregistered accepted Artifact orphan is forbidden.

### K3 durability

- The owner connection must set and read back `journal_mode=WAL`,
  `synchronous=FULL`, and `foreign_keys=ON`.
- Foreground transactions are bounded and use `BEGIN IMMEDIATE` only after all
  Artifact and owner preflight I/O is complete.
- No K3 transaction awaits another actor, reads another database, performs
  filesystem/network I/O, or walks complete history.
- Logical heads carry bounded incremental dependency-closure commitments.

### Retention

- A lawfully persistable uncommitted body begins as `recovery72Hours`.
- `recovery72Hours` retention is >= 259,200,000 milliseconds after the trusted
  accepted-put boundary, subject only to higher-priority deletion, privacy,
  consent, secret, or security fences.
- The same logical-head transaction that adopts committed conversation,
  Mission, plan, Whisper, or Solution state promotes all required dependencies
  to `userDurable`.
- `userDurable` has no ordinary TTL. It ends only through explicit authorized
  deletion or a higher-priority lawful consent-withdrawal, secret-detection,
  privacy/security-reclassification, revocation, or erasure fence.
- Garbage collection proves unreachability from active/staged obligations and
  owner receipts before deleting content. System temporary directories and
  Caches are not retention authorities.

## A2 — Fixed recovery evidence matrix and semantic state

The first production generation uses a closed presence matrix of incumbent
Artifact fields, logical heads, and owner receipts. It adds no generic
`RecoveryParticipant`, participant registry, completeness bitmap, snapshot
family, or per-subsystem verification-receipt family. A named adapter may only
reopen or project already classified evidence. Any genuinely new wire first
receives an exact W1 governed/contained/transient classification and controlled
path/owner/test disposition.

### Conversation and plan

- Every Main conversation begins with at least a minimal durable Mission plan
  before Provider, tool, effect, or Sub-agent allocation.
- Main conversation and Mission remain separate logical heads updated
  atomically by the same K3 writer for turn admission and terminal outcome.
- The active objective, constraints, current node, completed nodes, blockers,
  pending obligations, next eligible node, and plan revision are durable.
- A plan change is an immutable successor plus CAS, never in-place prose
  mutation.

### Agent and Sub-agent

- One Session selects one App Agent and one logical Main.
- Depth-one Sub-agent slots are predeclared by the Mission graph and retain
  separate purpose-limited context capsules and budgets.
- Sub-agents ordinary-put structured non-CoT Solution artifacts containing
  claims, evidence, assumptions, uncertainty, counterexamples, and status.
- The Mission root is the only progress truth. There is no Sub-agent milestone
  head or majority-vote authority.
- Recovery reopens accepted solutions. It may recompute a node without a
  committed successor only when the node is pure/deterministic, its admitted
  inputs and implementation are frozen, and the incumbent recovery disposition
  permits it. Provider, tool/effect, publication, or any other possibly started
  operation instead uses the original owner receipt and same semantic identity
  to lookup, query/reconcile, await, or quarantine; it is never blindly rerun or
  redispatched.

### EventLog, legacy graph migration, and QinaoLoop

- EventLog continuity records an authenticated high-water coordinate and uses
  throwing, continuity-verifying recovery paths; read errors never become an
  empty log.
- The legacy Shared State Graph and its SQLite storage are W0 inventory and
  migration/test inputs only. Lawful durable facts migrate into incumbent
  Artifact/K3/Mission ownership with explicit provenance; the graph actors and
  storage then leave production reachability. They are not active recovery
  evidence sources and cannot remain as a second state Store or writer.
- Every current QinaoLoop path follows the incumbent W1 concrete-runtime
  migrate/delete/test union and receives no standalone session-state authority.
- This specification does not assume or authorize a QinaoLoop rehydration
  adapter. Any later proposal for such an adapter—including recovery of
  candidate, critique, or contradiction state—is a
  `newControlDeltaPendingAdmission` requiring exact W1 wire/owner/path/Wave/
  selector/test classification first.
- A+ recovery remains complete through the canonical conversation/Mission/
  Solution lineages even if QinaoLoop is retired. Its current in-memory
  dictionaries are caches and cannot override K3 heads or owner receipts.

### Whisper side conversation

- Whisper is admitted as `userDurable` read-only inquiry history with no
  ordinary TTL under the same Artifact/K3 authorities. It remains subject to
  the same higher-priority authorized deletion, consent, privacy/security,
  secret, revocation, and erasure fences as Main history.
- It may inspect a pinned Main read set and continue while Main runs.
- It cannot spawn, execute tools, publish externally, mutate Main, write memory,
  learn, or grant authority.
- Its durable inquiry intent/plan remains inside the branch envelope with zero
  executable/effect slots; Whisper mints no Mission root or Mission head.
- Promoting a Whisper message to Main requires explicit user authorization and
  creates a new ordinary Main input with provenance; heads never merge.

### Per-conversation context

- Main, Whisper, each Sub-agent, and each Provider attempt have distinct
  purpose-limited capsules, budgets, read sets, and currentness proofs.
- Bounded maintenance runs after every committed turn rather than waiting for
  the context window to fill.
- Compaction replaces only derived projections and never deletes durable source
  history.

### Shell and model state

- Shell recovery persists a sanitized invocation identity, executable/argv/
  environment/cwd, admitted inputs, accepted transcript prefix, possible-start
  state, and owner receipt. Secrets and ambient handles are excluded.
- An exact local model cache is optional acceleration and must reopen the full
  incumbent `BASCacheCheckpointIdentity` / Ref / Provider-receipt closed matrix:
  cache-scope contract over Workspace, Window, App-Agent, Session/incarnation,
  Attempt and role; Provider execution and execution-plan refs; model material
  including tokenizer/vocab, prompt-template and State-ABI identities; Provider
  profile and compiled-context descriptor; sampler configuration and stochastic
  RNG-state commitment; accepted token-history and accepted visible-output
  prefix; `exactNative` cache body and generation; three distinct retention
  admissions; erasure/deletion scope; and restoration, capability, policy,
  deletion, revocation, kill, and deadline currentness. A missing or mismatched
  cache-only identity/body/exactness coordinate is a typed cache miss and may
  recompile only from separately verified accepted-prefix truth. A missing or
  mismatched accepted token/output prefix, Ref/plan, retention receipt, or
  required currentness coordinate is corruption/quarantine or typed unavailable,
  never hidden as a cache miss or partial restore. Lossy or remote hidden state
  is never recovery truth.

## A3 — Inert preparation, checkpoint install, and restore

### Prepare inert evidence

1. Allocate one stable checkpoint-install operation identity, idempotency key,
   and generation under the incumbent install ABI.
2. Capture a bounded dependency vector without holding a global lock across
   incumbent owner or Artifact I/O.
3. For every independently put body required by the closed checkpoint presence
   matrix, complete A1 identity preparation, expected-ID reservation, claim
   authorization, reserved put, claim binding, and final retention admission.
4. Materialize and reopen every required canonical postcommit retention receipt
   and its admitted body outside the later K3 install transaction. No new
   `staged` checkpoint state, participant row, provisional head, or second
   currentness authority is created. A crash here leaves only incumbent
   retention-addressable inert Artifacts, invisible to ordinary recovery.

### Verify and install

1. Reopen and verify every Artifact field and owner receipt required by the
   incumbent closed presence matrix outside the K3 transaction.
2. Construct the versioned incumbent `ContextContinuityManifest` recovery
   projection. Its optional target checkpoint coordinate may reference only a
   strictly older `BASContinuationCheckpointRef` generation; it never points to
   the current or future checkpoint.
3. Put and admit the manifest through the complete A1 pre-put protocol.
4. Construct and independently admit the current
   `BASContinuationCheckpointRef` through its incumbent versioned presence
   matrix. It binds only its frozen accepted-prefix recovery fields; no
   continuity-manifest field is added. `BASCacheCheckpointIdentity` and a cache
   body are present only for a verified `exactNative` cache lineage; a
   recompile-from-prefix path carries no cache identity/body/receipt.
5. Outside the K3 transaction, reopen the current Ref and the separately
   admitted current manifest, plus all required bodies, postcommit retention
   receipts, structural evidence, and budget/currentness evidence into one
   bounded validated snapshot.
6. In one short K3 transaction, recheck the complete revision/epoch vector,
   persist the incumbent canonical install row/receipt bytes that bind both the
   current Ref Artifact and current continuity-manifest Artifact, and publish
   the sole checkpoint head using the unchanged
   `BASAutomationCheckpointInstallRequest` / `Receipt` ABI.
7. Materialize and reopen the install receipt idempotently. A lost reply
   performs lookup, not a second activation.

The active install always names a byte-verified current Ref and a separately
byte-verified current manifest through the incumbent K3 install evidence; the
Ref does not point to that manifest. The manifest may reference only strictly
older checkpoint ancestry. A crash may leave enumerable reserved or invisible
inert Artifacts, but never an active half-checkpoint. Before the new install CAS
commits, the prior head remains the sole active head and may run only after all
current gates revalidate. After the new head commits, every older generation is
read-only forensic/recovery input, never directly executable. A rollback must
use the unchanged incumbent install ABI to create a new successor generation,
revalidate current consent/deletion/revocation/erasure-key/retention/K4/
`ContinuationPolicy`/epoch state, and win one new K3 CAS with a new canonical
install receipt. Only that newly current head may execute; a historical install
receipt never overrides currentness or a newer fence.

### Restore

1. Reopen the active K3 head and byte-equal install receipt. From the exact two
   Artifact coordinates bound by that incumbent receipt, separately reopen the
   current `BASContinuationCheckpointRef` and current continuity manifest.
2. Verify Ref/manifest schemas, commitments, strict ancestry, the incumbent
   required-field and `omissionCoverageManifestArtifactID` contracts, epochs,
   retention, and bounded dependency closure.
3. Reopen the exact `WorkUnitRecoveryCursor`, its L11/L14-produced
   `ContinuationPolicy` receipt, trusted-now/interruption/foreground/user-
   presence evidence, K4/currentness evidence, and any required one-use
   affirmative Input Event. Run the incumbent `ContinuationPolicy.validate`
   gate and derive exactly one existing `BASWorkUnitRecoveryDisposition`.
   `neverAutomatic` never mutates on relaunch.
4. Read-only reopen and integrity verification may proceed without execution
   authority. Rehydrate named runtime projections in the fixed incumbent
   dependency order only to the extent permitted by the derived disposition.
   No generic per-subsystem restore receipt is created; any required new receipt
   must first be classified in W1.
5. Install no externally visible, mutation-capable, or executable state until
   the recovery barrier, continuation policy, K4, and currentness gates all
   permit it. `awaitUser` and `quarantine` remain non-executing.
6. Rebuild derived indexes/caches after truth is available.
7. Query/reconcile possibly started operations under their original identities;
   never blind-resend them.
8. On corruption or missing required state, an older generation may be reopened
   read-only for diagnosis. To execute it, construct a new successor install
   request through the incumbent ABI, revalidate the complete A3 gate set, and
   win the sole-head K3 CAS; otherwise return typed unavailable. Direct
   rehydration from a non-current generation is forbidden.

## A4 — Crash, replay, and global-invariant certification

A4 uses real subprocess failure injection, not only orderly deinit/reopen. W6
reuses the incumbent `runtime.replay-manifest` owner, the existing
`BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainTurnResultReplayHarnessTests.swift`
suite, `BASAutomationReplayCertificationTests`, and
`BASAutomationFaultMatrixTests`. It creates no second runner, Store, progress
head, scheduler, or recovery authority. Task 2 adds exactly the incumbent
successor selector
`BehavioralAISubstrateTests.BASEBrainTurnResultReplayHarnessTests/testRepeatedInterruptArchiveCompactionAndRestartPreserveObjectivePlanHeadsContextIdentityAndNextEligibleWork`
to the canonical successor ledger and existing W6 nonempty command; it does not
replace or rename a predecessor selector.

### Required cut points

- before and after the `identityPreparing` COMMIT;
- before and after reservation/claim COMMIT;
- before and after the Artifact put COMMIT;
- before and after `bindAndAdmitReservedArtifact` COMMIT;
- before and after current manifest put/admission and current Ref put/admission;
- before and after checkpoint-install COMMIT;
- before, during, and after install-receipt materialization and byte-equal
  reopen, including COMMIT-to-reply loss;
- while WAL is not checkpointed;
- during restore and during a second consecutive restore;
- before and after publication, Provider, tool/effect, export, and Apple
  lifecycle possible-start boundaries;
- during retention promotion, deletion fencing, and garbage-collection pages.

### Fault classes

- `SIGKILL` of the child/process group;
- `SQLITE_FULL`, `SQLITE_BUSY`, truncated or stale WAL/DB, and read-only media;
- missing, swapped, duplicated, foreign, or tampered artifacts/receipts;
- clock rollback, boot-incarnation mismatch, key unavailability/rotation, and
  file-protection unavailability;
- lost reply, duplicate retry, changed-byte retry, stale CAS, and concurrent
  Sub-agent completion;
- context compaction, archive, repeated interruption, and total process-memory
  loss.

### Deterministic long-chain profile

The contract profile runs at least 128 committed turns and 32 cut/reopen
cycles, including consecutive cuts and every boundary class. Interrupted and
control runs use the same frozen input, trusted clock, entropy, Provider,
tool/effect, publication, and owner-observation tapes. Its preregistered
schedule includes Main input admission, Mission progress, two independent
Sub-agent completions and a losing adoption CAS, Whisper interleaving, per-turn
context maintenance, context compaction, checkpoint and archive receipt
materialization, publication and tool/effect possible-start, Apple lifecycle
background/foreground, and total process-memory loss.

Every post-cut test checks objective, constraints, conversation and Mission
heads, plan revision/current/next nodes, App-Agent/Workspace/Session/Attempt
identities, accepted Solution lineage and Agent/Sub-agent adoption, context
profile/read set, cache-scope identity plus eligibility/disposition,
user-visible transcript, pending obligations, uncertainty/blockers, and next
eligible work. At every Provider, publication, tool/effect, export, and Apple
possible-start boundary the test checks exact stable identity/state/owner-
receipt set, not only aggregate counts. Matching only final roots is
insufficient: the recovery suffix must be a legal deterministic fold with no
duplicate effect, publication, capability, retention decision, or budget
debit.

For every cut, recovered EventLog history through the last committed boundary
must equal the control run's byte- and receipt-verified pre-cut prefix. Before
the next ordinary operation, every divergent suffix row belongs to the closed
incumbent recovery-disposition set only: stable lookup/reopen, pending canonical
receipt materialization, same-identity external query/reconciliation, pure
rebuild from frozen admitted inputs, or typed unavailable. Each such row binds
the original semantic operation, logical predecessor, HWM/row-version/epoch
currentness vector, owner receipt, and exact-once fold position. An extra head
CAS, budget debit, K4 use, retention transition, publication, or effect outside
that closed suffix fails certification even if final roots later coincide.

## R0-R3 — Historical Deep Scan result closure

The official 111-finding result of Deep Scan #1 and the recovered Deep Scan #2
candidate/lead indexes are mandatory, disjoint risk inputs, not automatic patch
queues. A cross-scan root-cause cluster may share remediation, but it never
merges or renumbers source finding identities.

### R0: Freeze and normalize

- Preserve Deep Scan #1's official `complete`/111 indexed-record evidence and
  the exact canonical-document read error. Before the live workbench can age
  out or change those rows, create a repository-external, non-Git, encrypted,
  read-only frozen SQLite backup or lossless deterministic query snapshot using
  the SQLite Backup API or one consistent read transaction. Bind the snapshot
  bytes/digest, schema and export-tool identity, exact ordered query, raw-row
  commitments/root, 111/111/111 cardinality, four registered dead locators,
  dead-root probe, `quick_check`, foreign-key check, and encryption/custody
  receipt. Sensitive title/summary/remediation/details plaintext and its raw
  equality digest remain inside encrypted custody. Git and external receipts
  expose only domain-separated keyed commitments bound to key epoch/erasure
  scope, or ciphertext-fixity digests. A naked main-file copy while WAL may
  exist is forbidden.
- Recover all 111 indexed occurrences from DS1 snapshot bytes into a versioned
  non-canonical forensic inventory, binding occurrence/finding IDs, source
  target revision, exact raw-row/detail commitments, locations, severity,
  provenance, database-snapshot identity, and any public per-occurrence reopen
  evidence. Sensitive titles, summaries, remediation, and details remain out
  of Git. The 20-row context prefix alone is never treated as the full set.
- Track canonical-document availability as a separate external gate: only an
  official API/service restoration may re-establish the three sealed canonical
  JSON documents and separately regenerate the official unsealed report
  projection. The forensic 111-row inventory permits risk remediation but
  never claims to recreate those canonical files or the official projection.
- Preserve the original 68 rows, titles, labels, provenance, and 452 location
  references byte-for-byte.
- Preserve the separate 0011-0014 incomplete-draft evidence byte-for-byte and
  verify the exact 41-row lead inventory, source-span hashes, category counts,
  and lead-list root. It never changes the recovered terminal aggregate count.
- Generate a separate versioned closure ledger; never rewrite forensic
  evidence.
- Bind target revision, current candidate revision, relevant P0 commits,
  source-location digest, validator identity, and validation time.

### R1: Validate current reality

#### Every following predicate applies to every Deep Scan #1 finding, every Deep Scan #2 terminal candidate, and every Deep Scan #2 incomplete-lead row


1. bind `(sourceScanNumber, scanId, sourceTargetRevision,
   findingID/terminalOrdinal/leadID)` and reopen every cited location at that
   row's own source tree: `c8f80486895e12e26d567e610c35a6e2141b3489` for
   Deep Scan #1, or `243c083f345f3586ef226020d42af4653b31a62a` for Deep
   Scan #2 terminal candidates and leads;
2. map per-row control/data paths at the current candidate revision;
3. establish entry point, trust boundary, preconditions, reachability, sink,
   impact, counterevidence, and remaining uncertainty;
4. distinguish active production, optional production, sample/dev-only,
   excluded archive/legacy, and unreachable code;
5. record one closed disposition:
   `confirmedOpen`, `fixedByRecoverySpine`, `fixedBySeparateChange`,
   `alreadyFixedWithEvidence`, `notApplicableWithEvidence`, or
   `deferredExternalBlocker`.
#### Per-row preservation and cross-scan evidence boundaries
No row may disappear through deduplication. A merged root cause retains the
scan number plus every official finding identity, terminal ordinal, lead ID,
and proves why one fix covers each instance.

The separate Standard scan's 63 rows may supply counterevidence or an overlap
link only. Its revision and identities never substitute for either Deep Scan
source binding.

Each of the 41 incomplete-draft inventory rows follows R1's own current-source
validation method. Its crosswalk must identify the exact terminal row/root-
cause cluster it duplicates or retain its own stable lead identity and
evidence-backed disposition. Many rows may share one frozen prose span, but no
row may disappear through prose regrouping.

### R2: Root-cause remediation

Confirmed rows are grouped by shared cause rather than patched one title at a
time.
#### The following list is the non-exhaustive set of expected R2 root-cause families
- authority, permit, replay, and possible-start identity;
- persistence, retention, deletion, and data protection;
- bounds, batching, fan-out, buffering, and parser allocation;
- FFI and wire-format validation;
- evaluation sandbox, fixture, dataset, and checkpoint supply chain;
- ledger, canonicalization, cache-scope, and integrity;
- model/context/session lifetime and degradation.
#### Remediation and recertification invariants
Each remediation begins with a failing regression, modifies the narrowest
incumbent owner, and proves package/owner/dependency cardinalities remain
closed. Fixes that introduce a second Store/Manager/head, move authority into a
model, or weaken another global invariant are rejected even when they close a
local test.

Every R2 change is also a recovery-certification invalidation event. Its exact
path/owner/selector/dependency impact is evaluated against the closed
inventory; every affected A1-A4 gate is reopened, and A0 is reopened if the
change alters a governed source or admitted requirement. A prior receipt from
another tree cannot close a reopened gate. This prevents a locally correct
security patch from bypassing recovery, replay, retention, or long-chain
certification.

The known checkpoint correction is explicit: P0 hardened the distinct
`Tools/mamba3_deploy.py` path, but the recovered
`supply-chain.unsafe-checkpoint-deserialization` row points to the PhaseB
conversion scripts, which still require revalidation and must not be marked
closed by association.

### R3: Closure gate

#### The following list is the complete conjunctive set of predicates, and every predicate must hold before Deep Scan #3 launch

- all 111 Deep Scan #1 indexed occurrences appear exactly once in a verified,
  explicitly non-canonical forensic inventory and have one reviewed current-
  source terminal disposition; the canonical-document availability/error state
  remains separate, the frozen encrypted source snapshot and raw-row root
  reopen, and the bounded 20-row context prefix is never called the full set;
- all 68 rows have exactly one reviewed terminal disposition;
- all 41 frozen 0011-0014 inventory rows pass forward source-span verification
  and reverse source-category completeness, then receive an independently
  checked crosswalk or their own reviewed terminal disposition without being
  counted as a terminal-68 row;
- every confirmed reachable finding is fixed and independently verified, or a
  genuine repository-external blocker is explicitly accepted by the user;
- no `confirmedOpen`, unowned row, evidence-free suppression, or silent
  severity downgrade remains;
- each root-cause change has focused, regression, integration, mutation, and
  relevant crash/replay coverage;
- independent review confirms the closure ledger against the frozen evidence;
- current-source validation reruns after the final merge/freeze; and
- on the exact R3 final-freeze commit/tree, the impact matrix is recomputed and
  every reopened A0-A4 gate is recertified, including the A4 128-turn/32-cut
  long-chain profile and global owner/path/selector/invariant checks.
#### Historical scan identity preservation
R3 preserves that Deep Scan #1 was the successful first run and does not claim
Deep Scan #2 completed. It proves only that the complete 111/68/41 historical
result domains received auditable current-source dispositions.

## D0-D2 — Deep Scan #3

### D0: Freeze and preflight

0. Before mode selection, reopen the callable plugin schema and supported
   documentation, freeze their exact identities, and attempt admission of a
   callable precreate surface plus stable observation ABI and authoritative
   source sequence. This prerequisite freezes capability evidence only, not the
   final scan target/material root. If any required supported surface is absent
   or not admitted, record that negative result and make
   `appPrecreatedMonitored` ineligible for this run.
1. Select and record exactly one launch mode from the closed set
   {`appPrecreatedMonitored`, `headlessUnmonitoredResidual`}.
   `appPrecreatedMonitored` means the app exposes the new scan ID and scan
   directory before discovery begins. `headlessUnmonitoredResidual` means the
   initial headless start blocks until the aggregate is ready or failed and does
   not guarantee a usable scan ID/path before worker execution.

The frozen public plugin contract presently exposes neither a supported
repository-controlled precreate/vault-observation API nor a stable per-
worker/reducer observation schema or authoritative source sequence. Therefore
`appPrecreatedMonitored` is currently an `operationalScanGate`, `nonExecutable`
design branch. It becomes selectable only if D0 prerequisite 0 has already
frozen and admitted an explicitly supported precreate surface, observation ABI,
and authoritative source sequence. Reverse-engineered internal objects are
evidence, never API permission. A monitor without that admitted ABI may blindly
preserve safely opened bytes and report coverage `unknown`, but it may not
semantically label internal acknowledgements, reducer mappings, pass accounting,
or vault health as supported or complete.
2. For `appPrecreatedMonitored`, finish and test any repository-owned receipt-
   vault source before target freeze. Its exact commit, tree path, blob, digest,
   dependencies, test receipt, and launch identity enter the frozen material
   root. Its source disposition is `operationalScanGate`; it is an explicit
   non-shipping script/tool target with zero application-bundle, entitlement,
   product-target, runtime-selector, or reverse dependency reachability. A
   machine-derived reachability test proves those zeros. The frozen contract
   includes maximum object bytes, object count, total encrypted bytes, scratch/
   metadata overhead, ingest rate, and a fail-closed no-eviction policy; same-
   directory temporary write, file `fsync`, atomic no-replace publish, and
   parent-directory `fsync`; authenticated encryption under a non-exportable
   platform-Keychain key with locked-key typed failure; file/Data Protection
   posture; append-only integrity chaining; and minimum three-day post-terminal
   retention with explicit authorized deletion and higher-priority privacy/
   security/secret/erasure fences. The capacity proof freezes the actual Deep
   Scan configuration, including maximum run hours, pass and worker concurrency,
   per-object/output upper bounds, tool timeout, and monitor-ingest bound; it
   never substitutes an optimistic average. The read side pins the authoritative
   scan-root directory descriptor and a closed relative-path allowlist; every
   open is descriptor-relative/no-follow, bounded before read, and accepts only
   a same-root regular file with one link. Absolute/traversal paths, symlinks,
   hardlinks, FIFOs, devices, sockets, and changed inode/device/size/mtime across
   a bounded pre/post `fstat` stable read fail closed and permanently gap that
   interval. Workbench reads use a SQLite consistent transaction or Backup API,
   never a naked main file or `immutable=1` when WAL may exist. Sensitive worker
   drafts/plaintext digests stay inside encrypted custody; outside receipts use
   a key-epoch/erasure-scope-bound keyed commitment or ciphertext digest. For
   `headlessUnmonitoredResidual`, record that the current public start
   schema exposes no scan-root/vault parameter and cannot promise per-worker or
   per-reducer mirroring. A persistent root may be configured only outside this
   repository before the MCP server starts. The user must explicitly accept
   this external residual before launch.
3. Build and test a clean candidate commit with no unrelated dirty state.
4. Freeze commit, tree, dependency/material roots, generated-source state, and
   exact scan scope. Rebind any prerequisite-0 supported ABI identity into this
   final material root; a changed ABI reopens mode selection. No repository or
   target-tree write is permitted after this point.
5. Reopen and verify A0-A4 and R0-R3 acceptance artifacts against D0's exact
   tree, and rerun any acceptance check whose receipt does not bind it. A
   receipt produced for a pre-R2 or otherwise different tree is stale and
   cannot pass preflight.
6. For `appPrecreatedMonitored`, create only the data root after freeze. It is
   repository-external, persistent, outside the system temporary directory,
   and 0700/0600. Before launch, prove worst-case free space for the frozen total
   plus scratch/SQLite/WAL margin and reopen the key, protection, durability,
   limit, retention, and deletion-policy receipts. Start the already frozen and
   tested monitor before rejoining discovery. It is encrypted, content-
   addressed, append-only, and read-only with respect to the repository, scan
   directory, and Codex workbench database. Its health is a separate monotonic
   `healthy | gapped | failed` evidence receipt; limit, disk, key, integrity, or
   I/O failure is visible and never silently downgrades the run into an
   unmonitored mode or evicts older evidence. `healthy` additionally requires a
   contiguous authoritative source sequence plus a reverse inventory proving no
   create/delete escaped between observations. If the plugin exposes neither,
   or any sequence/object cannot be proven, health becomes `gapped` from the
   first unverifiable interval; polling success alone can never claim complete
   observation.
7. For an app-precreated native scan, load its authoritative context once and,
   before discovery, inspect `otherRunningDeepScans` exactly once. If another
   Deep Scan is running, show only target, plain-language phase, and friendly
   start time, then continue only after the user's explicit Cancel/Continue
   decision with Cancel recommended. Cancellation stops only the new scan. A
   first target-based headless call has no pre-existing native context and does
   not fabricate this guard.
8. Read the frozen `scan-prologue.md` exactly once. Immediately before D1's
   initial coordinator invocation, obtain one TAC-status advisory and report its exact status
   and grants; `not_granted`, `unknown`, or unavailable produces the prescribed
   display warning but never grants authority, blocks the scan, or becomes a
   capability preflight.
9. Freeze exactly one invocation envelope: mode, target/scope or authoritative
   scan ID/claim, expected target identity, and exact bounded initial
   `userContext`. A native continuation preserves the complete authoritative
   value; a headless launch uses one reviewed bounded value or explicit absent
   state. User-supplied URLs remain untrusted and are read only with explicit
   authorization, at most once. D0 performs no coordinator start call.

The current proprietary plugin supports same-ID/handoff-claim rejoin only while
the official scan remains active or resumable. It has no public terminal-failed-
scan revive, partial-aggregate import/export, or reconstruction API. A local
vault may preserve forensic semantics but cannot repair official plugin state
or make a terminal failed scan resumable.

### D1: Run under the selected evidence mode

D1 creates or continues exactly one semantic Deep Scan #3 identity and makes
one initial blocking `start_codex_security_deep_scan` invocation, waiting on
that invocation. `appPrecreatedMonitored` continues the already-created #3 by
its unchanged authoritative scan ID/claim; `headlessUnmonitoredResidual` uses
the frozen target form to create or idempotently join #3. No later invocation
may create another semantic scan.

If and only if D1's waiter is proven detached while official state remains
active/resumable, a later turn may make a serial idempotent rejoin invocation
for the same semantic scan using the unchanged ID/claim, or the identical
target form where that is the only public headless join surface. There is never
a concurrent second waiter. Rejoin invocations do not repeat prologue/TAC/
concurrent-scan guard, do not widen context/scope, and are not counted as a new
scan/create. Terminal failure is not detachment; after terminal state no rejoin
or automatic replacement is legal.

Never mutate Deep Scan #1 or resume, complete, replace, or mutate terminal-
failed Deep Scan #2. Do not launch remediation while Deep Scan #3 discovery,
validation, attack-path analysis, or reporting is incomplete.

If the user adds, edits, clears, or replaces scan context while #3 is running,
persist the complete replacement immediately with
`update_codex_security_scan_context` and the #3 handoff claim when required.
Workers keep the immutable context captured when they started; at each genuine
later forward phase transition, the coordinator uses only the official returned
complete context for that phase. It never repeats a completed phase or publishes
progress while the coordinator call is pending.

#### Every following predicate applies only to `appPrecreatedMonitored`

- mirror each observable worker draft, successful acknowledgement, reducer
  input mapping, reducer aggregate, coverage inventory, and progress receipt as
  it appears;
- validate mirrored digests and source-ref accounting after every observable
  reducer pass; and
- treat a missing temporary output as a local alert and forensic-preservation
  event. The monitor cannot command official recovery and never writes an
  official result.

If the monitor becomes `gapped` or `failed`, the selected monitored-assurance
gate fails permanently for this run; it is never relabeled headless. The
official coordinator nevertheless continues under its own contract. If it
returns valid canonical unsealed artifacts, this thread still completes that
same scan exactly once. The product displays official scan state and local
vault coverage as two independent dimensions. A later replacement scan requires
new explicit user authorization; monitor failure never starts one.

#### Every following predicate applies only to `headlessUnmonitoredResidual`

- make no claim of continuous or per-pass mirroring;
- after the blocking call returns or fails, immediately snapshot every exposed
  canonical artifact, context result, surviving scan-directory file, and
  matching session receipt; and
- retain the explicit unmonitored interval as a verification limitation even
  if the official scan later completes.

### D2: Official completion gate

When the coordinator returns `{ manifestPath }`, verify that the authoritative
unsealed `scan-manifest.json`, `findings.json`, and `coverage.json` all exist,
then call `complete_codex_security_scan` for the same scan exactly once. Do not
retry completion in the same response, write a report, rerun workers, or start
another scan. Completion failure preserves the claim and resumable state and is
reported exactly as returned.

#### Both following official-state predicates are independently necessary for Deep Scan completion

- `scanContext.progress.status == "complete"` and
  `reportAvailable == true`; and
- the sealed `scan-manifest.json` passes its frozen schema and has
  `scan.status == "completed"`; its `scan.artifacts` records verify the exact
  `findings.json`, `coverage.json`, and referenced coverage-receipt bytes; and,
  when the workbench exposes `scans.seal_manifest_digest`, that external field
  matches the manifest bytes.
#### Canonical report projection and failure-state invariants
The manifest never binds its own digest. `report.md` is not in the canonical
seal: verify it separately as present and byte-equal to ReportProjectionV1 derived from the
three canonical JSON documents under the frozen report-
projection implementation. Regenerating that projection must not change the
canonical JSON or seal.

Recovered drafts, reducer acknowledgements, review counts, an unsealed/failed
empty result, or a locally generated report do not satisfy completion. A zero-
finding result is valid only when the official completed state, canonical JSON
seal, referenced receipt bytes, and ReportProjectionV1's exact bytes verify.
If official completion fails, preserve the
handoff claim plus every officially exposed or locally mirrored durable
artifact, and retain the exact official status/error without flattening the
evidence into “no findings.” Report `failed` only when the workbench exposes a
terminal failed state; otherwise report `incomplete` or `resumable` according
to the official state. The local vault never claims to equal the proprietary
control plane's last durable checkpoint.

## User-visible state

### All and only the following tokens are permitted product recovery-state values

- checking;
- ready;
- running;
- can continue;
- recovering;
- waiting;
- needs confirmation;
- blocked;
- complete.
### Recovery-state presentation boundary
Internal paths, nonces, K3 rows, scan tokens, receipt-vault mechanics, and
runner flags remain evidence rather than user chores. “Recovered evidence” and
“official scan complete” are always displayed as different states.

This vocabulary is a semantic acceptance contract, not UI implementation
authority. The exact incumbent production renderer owner, repository path, and
selector are not yet frozen in an admitted controlled source. Any production-
visible rendering delta in this section remains
`newControlDeltaPendingAdmission` and `nonExecutable` until A0/W0 admits and
reopens that exact consumer; this design authorizes no UI-code change.

## Source-disposition completeness contract

The generated ledger path is
`docs/superpowers/evidence/2026-08-28-qinao-recovery-spine-source-disposition.tsv`.
The closed VerifierV1 source path is:
`docs/superpowers/evidence/2026-08-28-qinao-source-disposition-ledger-v1.py`.
Both are non-shipping review artifacts, not production authority. They must be
committed together with this specification. The ledger binds the verifier's
path, pre-commit Git blob, byte length, and SHA-256; the post-commit external
receipt independently reopens the verifier, ledger, specification, final
commit, and tree.
### Every following condition must hold before implementation planning

1. Bind the final exact specification repository path, Git blob, byte length,
   line count, and SHA-256. The containing commit/tree is bound only by the
   post-commit external review receipt, because writing it into the ledger would
   create a commit-identity cycle.
2. Use the closed `qinao-markdown-unit-extractor/v1` profile implemented by VerifierV1's
   source code over UTF-8, LF-only, no-BOM bytes. Structural ATX heading
   lines and blank lines are excluded but bind `headingPath`. An ATX heading is
   an outside-fence physical line whose LF-stripped bytes begin with one through
   six `#` bytes followed by one or more SPACE/TAB bytes. Its heading text is the
   remaining decoded UTF-8 after removing an optional trailing sequence of one
   or more SPACE/TAB bytes, one or more `#` bytes, then optional SPACE/TAB bytes;
   apply NFC and no other normalization. Maintain the ordinary ATX level stack.
   Encode the active path as `qhp1:` followed by lowercase hex of
   `uint32be(activeHeadingCount) || (uint8(level) || LP(headingText))*` from the
   outermost active heading through the current heading. The root path uses a
   zero count. Every other byte belongs to exactly one non-overlapping unit:
   a list-leader unit is its first direct paragraph including continuation lines
   but excluding nested child lists; each nested child is its own unit; an
   additional list paragraph is a prose unit; a prose unit is a maximal
   remaining paragraph; a fenced-code block includes opener through closer;
   and a contiguous Markdown table is one table unit. Unterminated fences,
   unowned nonblank bytes, overlap, or parser ambiguity fails closed. Offsets
   use original UTF-8 bytes and an end-exclusive boundary. Each UNIT starts at
   byte zero of its first owned physical line and ends immediately after the LF
   of its last owned physical line, or at EOF when that final line has no LF.
   Excluded heading and blank physical lines exclude their LF too; no excluded
   line byte enters an adjacent UNIT. `unitStartByte/unitEndByteExclusive` are
   absolute spec-byte offsets, and `unitSpanSHA256` covers exactly that nonempty
   `[start,end)` slice. `unitStartLine/unitEndLine` are one-based inclusive
   physical lines derived uniquely from those offsets: start is one plus the LF
   count before `start`; end is one plus the LF count before `end`, minus one
   when the last included byte is LF. Clause offsets are likewise absolute
   original-spec byte offsets, nonempty, end-exclusive, wholly inside the UNIT,
   and `clauseSHA256` covers exactly their `[start,end)` bytes. Clause spans
   exclude leading/trailing ASCII whitespace while retaining any internal
   whitespace and punctuation. The closed, case-
   sensitive `anchorKind` enum is `prose | listLeader | fencedCode | table`.
   Outside a fence, a physical list leader is recognized only by raw-byte regex
   `^([ \\t]*)([-+*]|[0-9]{1,9}[.)])[ \\t]+`; indentation width is the byte
   count of group 1, and direct/nested ownership is determined from those widths
   with equal width as siblings and greater width as descendants. A fence opener
   has zero through three leading SPACE bytes, then at least three identical
   backticks or tildes; a closer has the same marker byte, at least the opener
   length, and only SPACE/TAB through LF. A v1 table is recognized only when a
   nonblank line containing an unescaped `|` is immediately followed by a
   delimiter row whose `|`-separated, optionally outer-piped cells, after
   SPACE/TAB trim, each match `^:?-{3,}:?$`; it continues through consecutive
   nonblank lines containing an unescaped `|`. Anything ambiguous fails closed.
   `anchorLocator` is exactly
   `qinao-unit-locator/v1:<headingPath>:<anchorKind>:<ordinal>`, where ordinal is
   the one-based base-10 source-order ordinal among units with the identical
   `headingPath` and `anchorKind`, with no leading zero.
3. Give every extracted block exactly one structural `UNIT` row with class
   `normativeBearing`, `evidence`, `introductory`, or `mixed`. UNIT coverage is
   not requirement coverage. A normalized unit digest binds NFC text, collapsed
   ASCII whitespace, unit kind, and full heading path under domain
   `qinao-design-unit-semantic/v1\0`. Its exact preimage is
   `domain || LP(headingPath) || LP(anchorKind) || LP(normalizedUnitText)`, where
   `LP(x)=uint64be(len(UTF8(x))) || UTF8(x)`. UnitNormV1 applies Unicode NFC and
   removes only the first matched list marker plus following whitespace for a
   list unit, replaces each maximal ASCII whitespace run (`09-0D` or `20`) with
   one U+0020, and trims leading/trailing U+0020. The unit ID is `QUN-` plus the
   first 24 lowercase hex digits. A collision or two indistinguishable units in
   one heading fails and requires an explicit stable marker before refreeze.
4. Independently atomize every `normativeBearing` or `mixed` unit twice. Each
   distinct identity, ordering, prohibition, obligation, invariant, acceptance
   predicate, or failure disposition gets one `REQUIREMENT` row and one or more
   exact `CLAUSE` subspan rows. A requirement ID is `QRS-` plus the first 24 hex
   digits of its domain-separated semantic digest over unit ID and the complete
   ordered clause interpretation. Clause spans are end-exclusive, remain inside the parent
   UNIT, and are disjoint unless an explicitly labeled shared-context span is
   necessary. For each clause, reopen its exact spec slice and apply the UnitNormV1
   NFC/ASCII-whitespace profile, removing the list marker only when the
   clause starts at the parent list UNIT's start. The exact requirement semantic
   preimage is `"qinao-design-requirement-semantic/v1\0" || LP(unitID) ||
   uint64be(clauseCount) || (uint64be(clauseOrdinal) || LP(clauseRole) ||
   LP(normalizedClauseText))*` in ascending contiguous clause ordinal. Thus the
   verifier derives the digest only from committed spec bytes and CLAUSE rows;
   no free paraphrase or hidden atomizer text can alter identity. A unit
   containing assertions with different source disposition,
   owner, Wave, selector, or pending gate must split them into separate
   requirements. Independent atomizers must agree or review fails closed.
5. Give every `REQUIREMENT` exactly one disposition from
   `projectionOfControlledRequirement`, `forensicRiskInput`,
   `operationalScanGate`, or `newControlDeltaPendingAdmission`; then attach one
   or more separate `SOURCE` rows and one or more `TARGET` rows with contiguous
   ordinals. This represents multi-source and closed-set multi-owner/Wave/
   selector mappings without packing them into free text. Evidence and
   introductory UNITs have no REQUIREMENT/TARGET authority; mixed UNITs keep
   their evidence provenance at UNIT level while their normative assertions use
   REQUIREMENT children. All three still carry SOURCE provenance so omission is
   distinguishable from classification.
6. Each `SOURCE` binds source ID/kind/path/locator, revision, commit/tree/blob/
   byte length/SHA-256 or exact external frozen identity and admission state.
   Each `TARGET` binds incumbent owner, W0-W6 Wave or explicit non-production
   class, exact selector/path when known, execution state, and pending gate.
   Production Wave and non-production class are mutually exclusive. Every
   `newControlDeltaPendingAdmission` or pending-overlay requirement is
   `nonExecutable` even if its expected owner/Wave is known.
7. Define TSV HeaderV1 via QUN-f72aa897afa9968903edcbab names, TAB-joined; null
   is the single byte `-`, cells forbid
   TAB/CR/LF/NUL, file encoding is UTF-8 with LF and no BOM, and every unused
   field is `-`:

   ```text
   schemaVersion recordType subjectID unitID requirementID childID unitClass anchorKind specPath specBlob specByteLength specLineCount specSHA256 headingPath anchorLocator unitStartByte unitEndByteExclusive unitStartLine unitEndLine unitSpanSHA256 unitSemanticSHA256 requirementSemanticSHA256 disposition executionState clauseCount clauseRoot sourceBindingCount sourceBindingRoot targetBindingCount targetBindingRoot bindingOrdinal clauseOrdinal clauseRole clauseStartByte clauseEndByteExclusive clauseSHA256 clauseCommitment sourceID sourceKind sourcePath sourceLocator sourceRevision sourceCommit sourceTree sourceBlob sourceByteLength sourceSHA256 admissionState scanNumber scanKind scanID scanTargetRevision scanOfficialState canonicalArtifactState targetOrdinal governedOwner governedWave nonProductionClass selectorPath selectorID pendingGateID targetCommitment sourceBindingCommitment rowCommitment
   ```

   `schemaVersion` is exactly `1`; decimal numbers are unsigned with no leading
   zero except the value `0`. Define RecordShapeV1 as a closed matrix; every
   field is required, conditionally allowed, or `-`:

   The identifier languages are closed and case-sensitive. `unitID`,
   `requirementID`, and child IDs respectively match
   `QUN-[0-9a-f]{24}`, `QRS-[0-9a-f]{24}`,
   `QCL-[0-9a-f]{24}`, `QSC-[0-9a-f]{24}`, or `QTG-[0-9a-f]{24}`.
   `sourceID` matches `[A-Z][A-Z0-9-]{0,63}`. `governedOwner`, `selectorID`,
   `pendingGateID`, and `nonProductionClass` match
   `[A-Za-z0-9][A-Za-z0-9._:-]{0,127}` when present. A `sourceID` names exactly
   one immutable source identity ledger-wide; a `selectorID` has one selector
   path; and a `pendingGateID` has one semantic gate. Conflicting reuse fails.
   `clauseRole` is exactly `assertion | sharedContext`; every REQUIREMENT has at
   least one `assertion`, and only `sharedContext` spans may overlap another
   clause span. `sourceKind` is exactly `repositoryCommitted |
   repositoryPrecommit | externalFrozen | scanRecord | decisionReceipt`.
   `admissionState` is exactly `admittedControlled | pendingA0 |
   pendingProtectedIntake | uncommittedReviewOnly | forensicEvidenceOnly |
   operationalEvidenceOnly | userDecisionOnly | externalObservedOnly |
   notStarted`. `executionState` is exactly `sourceGoverned | nonExecutable`;
   `scanKind` is `deep | standard`; `scanOfficialState` is `complete | failed |
   notStarted | unknownFrozen`; `canonicalArtifactState` is
   `canonicalUnavailable | canonicalPending | unknownFrozen`; and
   `governedWave` is `W0` through `W6` when present.

   - Every row requires all specification/unit identity fields from `unitClass`
     through `unitSemanticSHA256`, and `unitID` is its `QUN-` parent.
   - `UNIT`: `subjectID=unitID`, `requirementID=-`, `childID=-`; it requires
     `sourceBindingCount/sourceBindingRoot` including the defined empty-set root
     when count is zero. Evidence, introductory, and mixed UNITs require count
     at least one. All requirement, clause, SOURCE-child, and TARGET-child fields
     are `-`.
   - `REQUIREMENT`: `subjectID=requirementID`, `childID=-`; it requires
     `requirementSemanticSHA256`, `disposition`, `executionState`, and all three
     positive child counts/roots. All child-specific fields are `-`.
   - `CLAUSE`: `subjectID=requirementID`, `childID=QCL-*`; only
     `clauseOrdinal`, `clauseRole`, clause span/hash, and `clauseCommitment` are
     additionally required. Parent semantic/disposition/execution/count/root,
     SOURCE, and TARGET fields are `-`.
   - `SOURCE`: `childID=QSC-*`; for requirement provenance,
     `subjectID=requirementID` and `requirementID` is required; for evidence or
     introductory or mixed UNIT provenance, `subjectID=unitID` and
     `requirementID=-`.
     It requires `bindingOrdinal`, `sourceID`, `sourceKind`, `sourceLocator`,
     `sourceRevision`, `admissionState`, and `sourceBindingCommitment`.
     `repositoryCommitted` additionally requires path, commit, tree, blob,
     byte length, and SHA-256. `repositoryPrecommit` requires path, pre-commit
     blob, byte length, and SHA-256 while commit/tree are `-`; its containing
     final commit/tree exist only in the external post-commit receipt.
     `decisionReceipt` has the same path/blob/length/SHA presence shape,
     commit/tree `-`, and `admissionState=userDecisionOnly`.
     `externalFrozen` requires an exact locator, revision, byte length, and
     SHA-256; path is required only for a directly reopenable file, while Git
     commit/tree/blob and path for a derived byte stream are `-`.
     `scanRecord` has path/commit/tree/blob/byte length/SHA-256 all `-` and uses
     the #1/#2/#3/Standard tuple. Every non-`scanRecord` has all scan fields `-`.
     Parent, clause, and TARGET fields are `-`. Protected dirty inputs and all
     same-commit inputs are `repositoryPrecommit`, never falsely described as
     committed.
   - `TARGET`: `subjectID=requirementID`, `childID=QTG-*`; only
     `executionState`, `targetOrdinal`, owner, exactly one of production Wave or
     non-production class, selector path/ID when frozen, singular
     `pendingGateID` when one applies, and `targetCommitment` are additionally
     required. Parent semantic/disposition/count/root, clause, and SOURCE fields
     are `-`. Multiple gates require separate TARGET rows; no cell packs a set.

   `rowCommitment` is required on every record. RecordShapeV1 validates every required
   and forbidden field; it is not merely documentation.

   REQUIREMENT `executionState` is the deterministic least-permissive fold of
   all its SOURCE admissions and TARGET states. It is `sourceGoverned` only for
   a `projectionOfControlledRequirement` whose authority-bearing SOURCEs are
   all `admittedControlled` and whose every TARGET is `sourceGoverned`, has an
   exact owner, W0-W6 Wave, selector path/ID, and no pending gate. The closed
   AuthoritySetV1 source-state set is `admittedControlled | pendingA0 |
   pendingProtectedIntake | uncommittedReviewOnly`; a projection requires at
   least one such SOURCE. Evidence-only SOURCEs may supplement but never satisfy,
   replace, or weaken the AuthoritySetV1. Otherwise the parent is
   `nonExecutable`. A TARGET is `sourceGoverned` only under that same complete
   production mapping. Any NCD, protected/pending source, absent selector,
   non-production class, or pending gate forces the TARGET and parent to
   `nonExecutable`. `sourceGoverned` says only that authority must be reopened
   from the admitted source; the ledger itself never grants it.

   Disposition/source compatibility is closed. A
   `projectionOfControlledRequirement` requires at least one authority-bearing
   SOURCE, and every SOURCE state is in the AuthoritySetV1 or
   `forensicEvidenceOnly | operationalEvidenceOnly | externalObservedOnly |
   userDecisionOnly`; `notStarted` is forbidden. `forensicRiskInput` requires at
   least one `forensicEvidenceOnly | externalObservedOnly` SOURCE, every SOURCE
   is in that set or `userDecisionOnly`, and it is always `nonExecutable`.
   `operationalScanGate` requires at least one `operationalEvidenceOnly |
   externalObservedOnly | notStarted` SOURCE, every SOURCE is in that set or
   `userDecisionOnly`, and it is always `nonExecutable`.
   `newControlDeltaPendingAdmission` requires at least one `pendingA0 |
   pendingProtectedIntake | uncommittedReviewOnly` SOURCE, every SOURCE is in
   that set or `userDecisionOnly`, and it is always `nonExecutable`. A
   `userDecisionOnly` SOURCE can never satisfy a required source class.
   In this ledger, `executionState` answers only whether the row may serve as
   source authority for a production implementation/code delta. An
   `operationalScanGate` being `nonExecutable` forbids it from authorizing such
   a delta; it does not itself prohibit a separate non-production scan operation
   after A0-A4/R0-R3, current explicit user scan authorization, the frozen plugin
   contract, and every D0-D2 gate supply that operation's authority. The app
   branch additionally requires the supported-ABI gate; the headless branch
   additionally requires explicit acceptance of its unmonitored residual.
   `decisionReceipt` pairs only with `userDecisionOnly`. Deep Scan #1, #2, and
   Standard `scanRecord` rows are `externalObservedOnly`; Deep Scan #3 is
   `notStarted`. The exact kind/state relation is: `admittedControlled` only
   with `repositoryCommitted`; `uncommittedReviewOnly` only with
   `repositoryPrecommit`; `pendingA0 | pendingProtectedIntake` with
   `repositoryCommitted | repositoryPrecommit`; `forensicEvidenceOnly |
   operationalEvidenceOnly` with `repositoryCommitted | repositoryPrecommit |
   externalFrozen`; `externalObservedOnly` with `externalFrozen | scanRecord`;
   `userDecisionOnly` only with `decisionReceipt`; and `notStarted` only with
   `scanRecord`. The exact four scan tuples further restrict `scanRecord`.
   Unknown sourceKind/admission/disposition combinations fail closed.

8. Compute `clauseCommitment`, `sourceBindingCommitment`, and
   `targetCommitment` over their fixed typed fields with unsigned 64-bit big-
   endian UTF-8 length prefixes and respective domains
   `qinao-source-disposition-clause/v1\0`,
   `qinao-source-disposition-source/v1\0`, and
   `qinao-source-disposition-target/v1\0`. Sort each child set by numeric
   ordinal and its stable child ID, then compute the parent count/root as
   `SHA256(domain || uint64be(count) || raw32(childCommitment...))` under the
   corresponding literal domain:
   `qinao-source-disposition-clause-set/v1\0`,
   `qinao-source-disposition-source-set/v1\0`, or
   `qinao-source-disposition-target-set/v1\0`. The exact ordered field preimages after
   the domain are: CLAUSE=`schemaVersion, requirementID, clauseOrdinal,
   clauseRole, clauseStartByte, clauseEndByteExclusive, clauseSHA256`;
   SOURCE=`schemaVersion, subjectID, bindingOrdinal, sourceID, sourceKind,
   sourcePath, sourceLocator, sourceRevision, sourceCommit, sourceTree,
   sourceBlob, sourceByteLength, sourceSHA256, admissionState, scanNumber,
   scanKind, scanID, scanTargetRevision, scanOfficialState,
   canonicalArtifactState`; and TARGET=`schemaVersion, requirementID,
   targetOrdinal, governedOwner, governedWave, nonProductionClass,
   selectorPath, selectorID, executionState, pendingGateID`. Each field uses
   `LP`. `childID` is respectively `QCL-`, `QSC-`, or `QTG-` plus the first 24
   hex digits of that child commitment and is not in its own preimage. UNIT and
   REQUIREMENT rows use `childID=-`; CLAUSE/TARGET use `subjectID=requirementID`;
   SOURCE uses the REQUIREMENT ID, or the UNIT ID for evidence/intro/mixed
   provenance.
   Only the parent REQUIREMENT/UNIT stores the applicable count/root; child rows
   use `-` there.
9. Compute `rowCommitment` over every fixed column except `rowCommitment` with
   uint64be-prefixed UTF-8 fields, and domain
   `qinao-source-disposition-row/v1\0`. Sort data rows by
   `(recordTypeRank UNIT=0/REQUIREMENT=1/CLAUSE=2/SOURCE=3/TARGET=4, unitID raw
   UTF-8, requirementID raw UTF-8 with -=empty, selectedOrdinal, childID raw
   UTF-8, subjectID raw UTF-8)`. `selectedOrdinal` is numeric zero for UNIT and
   REQUIREMENT, `clauseOrdinal` for CLAUSE, `bindingOrdinal` for SOURCE, and
   `targetOrdinal` for TARGET; child ordinals are positive, contiguous base-10
   integers without leading zero, and `-` is never parsed as an ordinal. Compute
   the ledger root as
   `SHA256("qinao-source-disposition-ledger/v1\0" || uint64be(dataRowCount) ||
   raw32(rowCommitment...))`. File SHA-256 covers the complete TSV bytes. File
   digest/root are recorded in the external review receipt, never written back
   into the covered specification or ledger.
10. Treat Deep Scan #1, Deep Scan #2, future Deep Scan #3, and the separate
   Standard scan as four distinct source identities. The exact anchors are
   #1=`bcffa52e-53cf-4407-b216-14288ae07061` at
   `c8f80486895e12e26d567e610c35a6e2141b3489`, `deep`, `complete`,
   `canonicalUnavailable`; #2=`3d22f697-0c9d-4dbb-8c6a-871a9cfbcca9` at
   `243c083f345f3586ef226020d42af4653b31a62a`, `deep`, `failed`,
   `canonicalUnavailable`; #3 has `scanNumber=3`, `scanKind=deep`, `scanID=-`,
   `scanTargetRevision=pendingD0Freeze`, `scanOfficialState=notStarted`, and
   `canonicalArtifactState=canonicalPending`; and Standard has `scanNumber=-`,
   `scanKind=standard`, ID `dd2acd18-3ead-44fa-9c10-f8fd8c911aa7`, target and
   official state `unknownFrozen`, and canonical state `unknownFrozen`. A
   `decisionReceipt` SOURCE may establish this naming but never masquerades as
   any `scanRecord`.
11. Prove structural forward completeness (every extracted unit has one UNIT),
    semantic forward completeness (every independently identified normative
    assertion is covered by one REQUIREMENT and its CLAUSE set), reverse
    completeness, atomic-disposition uniqueness, contiguous child ordinals and
    roots, source/target closure, and exact scan separation. Unknown source,
    duplicate/missing assertion, unexplained normative bytes, stale digest,
    changed admission state, Standard with a Deep Scan number, #3 with a
    premature scan ID, #2 marked complete, or #1 renumbered fails closed. An
    unresolved production target also fails closed except for two closed NCD
    admission shapes, both with parent/TARGET `nonExecutable` and exactly one
    `pendingGateID`. If owner and Wave are both unknown, use
    `governedOwner=design.admission`, `governedWave=-`,
    `nonProductionClass=admissionTask`, and selector path/ID `-`. If exact
    incumbent owner and W0-W6 Wave are already frozen but only the selector is
    pending, preserve that owner/Wave, use `nonProductionClass=-`, and set only
    selector path/ID to `-`. Both shapes require parent disposition
    `newControlDeltaPendingAdmission` and may enter a plan only as the named
    admission task. The sole operational exception uses the first shape, has parent disposition
    `operationalScanGate`, applies only to the currently unavailable
    `appPrecreatedMonitored` supported surface, and uses the exact gate
    `D0.supportedPrecreateObservationABI` with the same placeholder shape. Every
    other unresolved owner/path/selector is invalid.
### Ledger invalidation and implementation-admission boundary
Any design text, ordering, source identity, plugin schema, or admission-state
change invalidates the ledger and requires regeneration plus independent
forward/reverse verification. A `newControlDeltaPendingAdmission` row may enter
an implementation plan only as an explicit pre-production admission task; it
cannot authorize its own production implementation.

## Acceptance boundary

### Every following condition must hold before this design is ready for implementation planning

1. the user reviews and approves this written specification;
2. self-review finds no TODO/TBD, unclassified or executable placeholder except in
   two NCD shapes, exactly one scan-gate reuse, or
   RecordShapeV1 scan-field nulls, contradictory authority, second Store or head, self-ID cycle,
   unbounded writer transaction, or partially enabled migration;
3. an independent reviewer validates this spec against the protected
   2026-08-10 design, the failed-scan forensic ledger, and the current source;
4. the specification, user scan-numbering decision receipt, exact Deep Scan #1
   read-only index observation, exact 41-row Deep Scan #2 incomplete-lead
   inventory, generated source-disposition ledger, and its closed extractor/
   verifier are committed in the same isolated clean tree/commit without
   changing the main or protected P0 worktrees;
5. review reopens each committed path/blob/byte length/file SHA-256, the
   incomplete-lead row count/root, and the source-disposition unit count/row
   root, then independently proves forward completeness, reverse completeness,
   normative uniqueness, exact scan-number separation, source admission state,
   clause/source/target binding roots, and owner/Wave/selector or non-production
   coverage; the external review receipt binds the final commit/tree without
   introducing a self-hash cycle;
6. before mutating remediation or implementation planning, the time-sensitive
   encrypted repository-external Deep Scan #1 SQLite backup/lossless snapshot,
   raw-row root, custody receipt, and 111/111/111 plus dead-locator checks in R0
   are independently reopened; sensitive finding bodies remain outside Git.
### Post-approval implementation and scan ordering
After conditions 1-6 permit planning, the resulting implementation plan is
ready for execution only after it treats A0 as a pre-W0 source-admission gate,
maps every A1-A4 requirement into the incumbent W0→W6 dependency order, routes
every R2 remediation through the exact active-plan Wave and owner, closes
A0-A4 plus R0-R3 before D0, and then orders D0→D1→D2.

No production delta begins before its source is admitted and its governed
incumbent Wave permits it. A1-A4 are acceptance groups distributed across
W0-W6, not a parallel implementation sequence. R0-R1 evidence analysis grants
no mutation authority; every R2 change must clear A0 source admission and active-plan
owner/Wave gates. R3 closes only after the relevant A0-A4 receipts exist.
Deep Scan #3 does not begin before A0-A4 and R0-R3 are complete. No local
evidence vault is represented as an official Codex Security recovery authority.
