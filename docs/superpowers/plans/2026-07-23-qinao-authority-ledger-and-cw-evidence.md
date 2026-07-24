# Qinao Authority Ledger and Cw Evidence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Atomically converge Qinao's exact 7 controlled documents plus 4 governing addenda, activate the sole Owner Ledger's schema-v2 authority/catalog/profile contracts, and form the evidence-only `Cw` plus one-receipt `Sw` without allowing candidate bytes or evidence to authorize themselves.

**Architecture:** Work is prepared and reviewed on an unadmitted preparation branch, but the authoritative preW0 payload is one immutable `Pw` commit whose sole parent is the externally attested bootstrap `B0`. `Pw` contains only authority/source bytes, schemas, parsers, fixture identities, future-wave E/A identity templates, and compare-only tools. The predecessor-derived protected runner starts from exact `Pw`, emits a closed verified evidence bundle, and has no Git-write authority. Only the authenticated external admission service validates that bundle, deterministically assembles and imports the evidence-only child `Cw` plus one-receipt child `Sw`, persists the host object-import receipt, performs protected-ref CAS, and finalizes the attestation. Candidate builders and checkers remain disposable parity diagnostics and never supply a Git object, ref, timestamp, receipt, or authority input to that service.

**Tech Stack:** Python 3.12 standard-library `unittest`, canonical JSON, JSON Schema 2020-12, Git object/index plumbing, Swift 6 source/build graph inspection, Xcode 27, XcodeGen semantic regeneration, Swift AST/SIL/index/link projections, and the externally attested Qinao wave-admission runner.

## Global Constraints

- Execute in the clean candidate worktree `/Users/changgeng/.codex/worktrees/e4d7/Project06`, never in the dirty forensic worktree.
- Approved design base is exactly `59c26f508262d7c25869faac0ec0abf968ec1e02`.
- Approved correction design is `docs/superpowers/specs/2026-07-23-qinao-convergence-correction-and-clean-candidate-design.md` with SHA-256 `3af1067ad2c3d37c36d7613ad19d1dd035bb6f1c60f06b75d5d71de22874d1b4`.
- Approved dynamic-graph amendment: commit `9d484befb4a4593d93789457ebddfd7cde358e3b`, path `docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md`, blob `e2c59656f9eb184efc3ab933fe442c9dd0b7d507`, SHA-256 `5f36d0b04579f805a3a69254325e62e22625f4ddd31663e03cbf78b1a39460d5`.
- The minimum deployment target is iOS 27 for every package, project, generated project, build script, test host, archive, and selected-release profile.
- preW0 has zero active shipping-release profiles. Its Xcode 27/iOS 27
  evaluation uses only the separately signed, non-shipping
  `verification_toolchain_profile` in `wave_admission_v1`; that value cannot
  populate selected-release evidence or make a product profile active.
- Preserve exactly 14 Semantic LayerCores, 4 Physical Kernels, 4 ControlRings, 7 orthogonal planes, 29 Owner Ledger owner cards, 7 controlled documents, and 4 governing addenda.
- The stable path `docs/superpowers/specs/qinao-owner-ledger-v1.json` and stable `ledger_id = qinao-owner-ledger-v1` remain the sole Owner Ledger when `schema_version` moves from integer `1` to integer `2`.
- Do not add a manager, mutable owner, authority, registry, database, scheduler, compiler, State Market, EventLog, WAL, K4 ledger, publication journal, recovery store, ring, kernel, or plane.
- `qinao-authority-corruption-recovery-v1.md` becomes a non-authoritative companion. Its valid rules move into the mapped existing owner/domain texts; it never becomes an eighth controlled document, fifth addendum, or recovery authority.
- Content-free is the default. Durable raw/content materialization requires the current signed exact-class/exact-purpose Decision Gate; encryption alone does not authorize persistence.
- `Pw` contains no finding disposition, test/gate result, release projection, reachability result, ArchitectureClosureReport, V2 result, or ledger row that claims `Pw`.
- The three Task-9 schema-v1 finding source records may exist only in their
  isolated reviewed C1 import commit; the final Task-9 tree deletes all three,
  and `Pw` purity rejects them. Only the derived content-free identity set
  crosses into `Pw`.
- The immutable Task-3 authority draft may remain in `Pw` only as the
  schema-typed non-authoritative historical Input A bound by the ceremony. It
  is not final authority, Cw evidence, a gate result, or an admission claim
  and is never regenerated after Output B.
- `Cw` has exactly one parent, `Pw`, and changes only the schema-frozen evidence allowlist. Every evidence leaf binds the already-existing `Pw` commit and tree.
- `Sw` has exactly one parent, `Cw`, and changes exactly one regular mode-`100644` file: `docs/superpowers/evidence/qinao-wave-admission/preW0.json`.
- The manifest in `Cw` lists every other Git evidence leaf and its indexed blob digest, but excludes itself. The `Sw` receipt binds the complete existing `Cw` tree.
- Raw archives, Mach-O files, CMS/signing chains, provisioning profiles, device identifiers, container copies, `devicectl` output, model packages, link maps, build plans, symbol/index stores, secrets, and privacy-bearing physical traces never enter Git.
- An authoritative wave is derived only from the externally attested predecessor chain. No CLI, environment variable, branch name, worktree name, candidate manifest, report, or release projection may supply `wave`.
- Candidate-local scripts and checkers, including
  `scripts/check_qinao_wave_admission.py`, remain diagnostics/parity only.
  `.github/workflows/qinao-wave-admission.yml` is the separately protected,
  B0-pinned OIDC admission client defined by the Bootstrap plan. Its
  `contents: read` plus `id-token: write` permission may request the protected
  service identity, but it has no contents/ref write, caller-selected
  authority, or same-wave verifier/module activation.
- Every RED must discover and execute at least one intended test and fail for the asserted semantic reason. Import failure, syntax failure, absent fixture, empty discovery, or arbitrary nonzero exit is not RED evidence.
- When a task introduces a new module/schema/catalog, its first RED step also
  creates the smallest importable, syntactically valid, fail-closed stub with
  the final callable/CLI surface. The stub returns that task's exact
  `*.unimplemented` diagnostic; tests assert that diagnostic and positive
  discovery. A missing file/import is never used as RED, and no stub may be
  committed or treated as GREEN.
- Preparation commits are review conveniences only. They are not protected ancestry. Final `Pw` is formed from the reviewed preparation tree with sole parent `B0`.
- Do not cover C0/bootstrap internals, C3 W0 freezes, K4 platform proof, or Artifact Mesh W1 implementation in this plan. Use the named sibling plans at the handoff points.

## Approved Dynamic Graph Authority Amendment

Task 1 must merge the pinned graph vocabulary and invariants into the existing
seven controlled documents and four governing addenda. It must not create a
twelfth authority document or a graph owner. The exact responsibility map is:

| Existing authority | Graph responsibility |
|---|---|
| Architecture | G0-G4 and exact 14/4/4/7 topology |
| Master | W0-W6 placement, dependency/cutover order, proof order |
| Contracts | Immutable graph wires, enums, bounds, canonical fixtures |
| Runtime | Readiness, barriers, replay, recovery, retirement, terminal seal inputs |
| Semantic | Retrieval, grounding, context and logical semantic execution |
| Silicon | Provider physical execution and envelopes only; no graph authority |
| Sovereign | Authorization, effects, recovery boundaries, terminal seal |
| K3/Provider addendum | Attempt roots, CAS, physical bindings, branch identity, unknown effects |
| Agent/Context/RSI addendum | Delegation, independent contexts, continuity, bounded loops |
| App-Agent Session addendum | App identity, persona, writable-state isolation |
| Governed Learning addendum | Evidence flywheel, candidate strategies, operator adoption |

Task 1 also carries forward graph contracts that exist only in the
2026-07-19 controlled-convergence source, but rehomes each contract into the
table above and renders that source non-executable traceability. No text may
name it as graph authority.

### Existing-owner pins

- `runtime.semantic-dag` is the sole G1 topology owner. Its one M/Create root
  is `BASSemanticTurnDAG` at
  `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticTurnDAG.swift`.
  It owns graph input/applicability/join/delegation, semantic-Attempt terminal
  receipt, and complete G2 values. There is no `TaskNode`, patch, join, or
  graph-manager owner.
- `runtime.turn-operation` owns Attempt references and
  `BASSemanticTurnEdgeBinding`.
- `state.snapshot-contracts` owns continuity; `state.context-compiler` owns
  compilation. K3 owns only physical execution rows and CAS.
- G0 is derived read-only; G1 is immutable per Attempt; G2 changes only by
  immutable root replacement/CAS; G3 is a receipt projection of the four
  existing ControlRings; G4 is read-only trace projection.

Task 3's Owner-Ledger draft must encode the `runtime.semantic-dag` M/Create
transition and reciprocal catalog references under these incumbent owners,
without changing the 29-owner cardinality. Task 4's source/entrypoint
classifier and Task 5's reachability closure must identify every production
graph writer, executor, direct peer path, shared scratchpad, legacy loop
authority, and graph-shaped Swift source. Task 7's incumbent convergence
checker must enforce the root path, owner pins, G0-G4 mutability, exact
14/4/4/7/W0-W6 counts, and absence of duplicate authority. Its mutant corpus
must include second writer, reverse absence query, mutable G2 update, fifth
ring, peer call, shared scratchpad, wrong execution shape, invalid
source-zero-join, missing control-ring join, and unauthorized graph owner.

These checks extend `scripts/check_qinao_owner_ledger.py`,
`scripts/test_check_qinao_owner_ledger.py`, the existing candidate-side
production-reachability/parity helpers, and their existing corpora. They do
not create a graph checker. Candidate-side results remain non-authoritative;
Bootstrap independently evaluates the corresponding existing gate IDs.

Required graph contract tests cover: one logical Main Agent with independent
model/provider contexts; no code/weight/schema/policy self-adoption; fixed
Provider pre-call/completion/recovery order; no blind retry; pure-DAG remand
only to a successor Attempt; ControlRing remand only through a real ring
invocation; exact completion and cancellation bases; the 1,018/1,024 bounds;
and W6's pinned dependency order. Run them through the existing nonempty
`unittest` and Swift-filter mechanisms already specified in Tasks 7-9.

## Interleaved Plan Interfaces

This plan interleaves with
`2026-07-23-qinao-c0-provenance-and-safe-import.md` and
`2026-07-23-qinao-bootstrap-verifier-and-admission-lineage.md` without
duplicating their C0/bootstrap implementation.

### Mandatory lineage-disposition guard

The C0-owned `scripts/qinao_execution_root.py` is the only root/lineage
classifier consumed here. Run it at clean entry to each of Tasks 1-9 and Task
10, after every task-local commit before advancing, immediately before Task
10 Step 6's external finalization write, and immediately before returning
that finalized handoff to Bootstrap Tasks 9-10 for Bootstrap Task 10's sole
lineage transaction:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --expect-candidate-lineage prebootstrapPreparation \
  --require-clean
```

`prebootstrapPreparation` means the audited tip
`486e1ec5983ad4390c5b07f04607f1345b912c4c` remains an ancestor and both
forensic-ref classes are absent. The command emits one canonical JSON line
whose exact key set is
`candidate_lineage,head_commit,head_tree,schema_version`, whose
`candidate_lineage` is `prebootstrapPreparation`, and whose
`schema_version` is integer `1`. A mismatch exits `2` and prints
`qinao-execution-root: expected candidate lineage` to stderr; no worker may
continue by replacing that guard with ad hoc Git tests.

Immediately after Bootstrap Task 10 applies the one atomic reparent
transaction, and before every post-reparent operation in Authority Task 10
Step 8 and Tasks 11-12, run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --expect-candidate-lineage reparentedProgram \
  --require-clean
```

`reparentedProgram` means the audited tip is no longer a candidate ancestor;
the fixed original forensic ref equals that exact audited tip; exactly one
ref formed as
`"refs/qinao-forensics/prew0-preparation/" + preparation_tip_oid` exists,
its suffix equals its target OID, and its target descends from the audited tip
and approved base; and the tree-identical one-parent `Pw` boundary above `B0`
is valid. The same four-key canonical JSON and exit-2 contract applies.
Neither lineage state is inferred from a branch name alone.

Do not rerun `--require-clean` between a task's RED and GREEN edits while its
explicit path set is intentionally dirty. If a session is interrupted there,
make no new edit: rerun the same classifier without `--require-clean`, prove
`HEAD` is the expected last task-local commit, require every dirty/staged path
to be a subset of that task's declared files, run `git diff --check` and the
last completed focused test, then resume at the first unproved checkbox. A
path outside that set, unknown `HEAD`, incomplete external write, or
unreproducible test state is a fail-closed operator hold; never reset,
recapture Input A, choose a newer ref, or manufacture a completion receipt.

### Preparation Z — non-circular schema/catalog schedule

The pre-ceremony order is exact:

```text
C0 Tasks 1-7 (all-hold inventory/map plus SourceProvenance)
→ Bootstrap Task 1 and Task 1A Steps 1-4
→ Authority Task 1
→ Bootstrap Task 1A Steps 5-6 (fixed C1 context, external signed record,
  immutable reopen receipt)
→ Authority Task 2 (unique map-only C1 postimage, history reopen, C1 apply)
→ Bootstrap Task 1A Step 7 (fixed 32-path C2 helper/test/dependency context, external
  signed record, immutable reopen receipt)
→ Authority Task 2A (unique map-only C2 postimage, history reopen, exact C2
  apply)
→ Bootstrap Tasks 2 and 4 schema/catalog-only slices
→ Authority Task 3
→ Bootstrap Tasks 3 and 5-7, then Task 7A, Task 8, and Task 9 Steps 1-2
  through Output B / Hold C
→ Authority Tasks 4-9 and Task 10 Steps 1-6, including external Hold 5A
→ Bootstrap Task 9 Steps 3-4 resume, then Bootstrap Task 10 alone forms Pw
→ Authority Task 10 Steps 7-8 consume and verify that one transaction
→ Bootstrap Task 11 completes the full verification matrix
→ Authority Tasks 11-12 use the protected evaluation/service path
```

Bootstrap Task 1/1A is committed before Authority Task 1, but freezes no live
C1 context until that checker-only Authority commit exists. Bootstrap Task 2
must already have frozen and indexed
`scripts/qinao_gate_modules/v0/catalog-v1.json` plus its immutable gate
contracts before Authority Task 3. Bootstrap Task 4 must already have frozen
the indexed bootstrap projection schema, while its concrete signed projection
and external profiles remain absent until the ceremony. Authority Task 3
computes `wave_admission_contract_digest` and
`required_gate_contracts_digest` directly from those already-indexed frozen
bytes. It does not predict a catalog, digest a future path, or wait for a
catalog whose digest is part of Input A. Bootstrap Tasks 3 and 5-7, then
Task 7A, Task 8, and Task 9 Steps 1-2 may bind those exact digests into B0 and Output B
without a digest cycle.

Separately, Authority Task 2 has already installed the complete controlled
contract rows in the sole Ledger, and Task 2A has installed the exact helper
closure needed to evaluate those rows, while that Ledger remains explicit
schema-v1/transitional/unadmitted Input-A material. Its reciprocal 7+4 refs
are generated from those indexed rows. Authority Task 3 digests the raw draft
Ledger and those contained rows. Task 4 never generates a catalog after
Output B; it upgrades the same Ledger around the byte-identical row array.
Thus neither the bootstrap gate catalog nor the controlled-contract catalog
depends on a future Task-4 output.

The active preW0 `qinao.owner-ledger` gate is deliberately independent of the
later candidate checker. B0's frozen `runtime.py` implements
`owner_ledger_v2_exact_set` plus `authority_anchor_bijection` internally and
freezes exact counts `owners=29`, `controlled=7`, `addenda=4`,
`semantic_layer_cores=14`, `physical_kernels=4`, `control_rings=4`,
`orthogonal_planes=7`, together with the exact eleven `document_id/path`
rows from Task 1. It never imports or executes candidate
`scripts/check_qinao_owner_ledger.py`. Tasks 4-10 make that candidate checker
an independently tested parity/proposed-next implementation; agreement is a
cross-check, never current-wave authority.

### Authority-to-bootstrap handoff A

After the 7+4 text draft is internally consistent, this plan emits:

`docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json`

with exactly:

```json
{
  "schema_version": 1,
  "authority_bundle_digest": "64-lowercase-hex",
  "owner_ledger_draft_digest": "64-lowercase-hex",
  "controlled_contract_catalog_digest": "64-lowercase-hex",
  "document_digests": [
    {
      "document_id": "stable-document-id",
      "path": "workspace/relative/path",
      "sha256": "64-lowercase-hex"
    }
  ],
  "wave_admission_contract_digest": "64-lowercase-hex",
  "required_gate_contracts_digest": "64-lowercase-hex"
}
```

`document_digests` has exact cardinality 11, is uniquely sorted by `(document_id, path)`, and contains the exact 7+4 map. This object contains no bootstrap projection, external attestation, candidate commit/tree, gate result, or admission claim.
Its `owner_ledger_draft_digest` binds the complete raw
schema-v1/`transitional_unadmitted_input_a` Ledger blob; its
`controlled_contract_catalog_digest` independently binds the canonical row
array already contained in that same blob. There is no second catalog file.

### Bootstrap-to-authority handoff B

The bootstrap sibling returns externally authenticated `B0`, runner/verifier
identities, complete through-W6 gate catalog and phase DAGs, required-gate
contract set, non-shipping verification-toolchain profile, build-evidence
storage profile, repository/workflow/OIDC/protection identities, and finalized
bootstrap attestation. Every one of the 19 gate contracts retains its literal
`program_by_wave` plus closed `programs` table. In particular, the six
staged domain gates use the master-aligned current-wave slice, require all
earlier slices, and prove later slices absent; they never collapse to a W6
final-state program or compile/filter a future suite as an expected failure.
Artifact- and K4-sensitive paths use the bootstrap sibling's deterministic
predecessor-proof reuse-or-current-payload-refresh rule, never a caller flag.
This plan:

1. reopens those exact external outputs under the sibling plan's authenticated read interface;
2. byte-matches them into `wave_admission_v1`;
3. rejects copied, incomplete, stale, locally signed, or candidate-authored substitutes;
4. finalizes the reviewed preparation tree; and
5. hands that exact tree OID back to the bootstrap sibling for one-parent `Pw` construction.

The authenticated export envelope is exactly:

```text
/private/tmp/qinao-bootstrap-ceremony-v1/export/export-envelope-v1.json
```

It binds these exact sibling exports:

```text
/private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json
/private/tmp/qinao-bootstrap-ceremony-v1/export/bootstrap-attestation-v1.json
/private/tmp/qinao-bootstrap-ceremony-v1/export/bootstrap-bundle-manifest-v1.json
/private/tmp/qinao-bootstrap-ceremony-v1/export/operator-approvals-v1.json
```

This plan imports only `wave-admission-v1.json` into the Owner Ledger, byte for
byte. It verifies the envelope and other exports externally but never copies
their private authentication material into the Ledger.

`wave-admission-v1.json` contains the closed
`bootstrap_attestation_policy`, but no concrete bootstrap attestation,
attestation digest, attestation status, approval, signature, or transparency
entry. The separate `bootstrap-attestation-v1.json` binds
`wave_admission_projection_sha256` plus
bundle/approval/repository/ref observations in one
direction; `export-envelope-v1.json` binds all four sibling exports. This
authenticated-envelope side channel validates the projection without making
the projection hash an input to its own attestation.

The bootstrap sibling exclusively owns and schemas
`PayloadProposalReceiptV1`, `EvaluationLease`, the service-internal
`EvidenceAssemblyResult`, `GitObjectImportReceipt`, and the runner-visible
`AdmittedWaveV1`. This authority plan consumes the exact four-method client
interface and must not redeclare, narrow, or create candidate-local
substitutes. In particular, `EvidenceAssemblyResult` never crosses that client
boundary.

### Authority-to-bootstrap handoff C

After `Pw` exists, the predecessor-derived protected runner uses the active
B0 verifier/modules and storage profile to create a verified evidence bundle,
not a Git commit. Gate results arrive only under the following closed
path grammar, where `evaluation_lease` is the typed, externally authenticated
lease already held by the protected runner:

```python
run_root = (
    Path("/private/tmp/qinao-admission-run-v1")
    / evaluation_lease.lease_id
)
gate_result_path = run_root / "gate-results" / f"{gate_id}.json"
gate_result_index_path = run_root / "gate-results" / "index.json"
```

`lease_id` and `gate_id` must each match
`[a-z0-9][a-z0-9._-]{0,127}`; neither value may come from candidate data,
the environment, a branch name, or a path supplied by a caller.

The runner uploads the exact closed bundle:

```text
lease_id
payload_commit_oid
payload_tree_oid
authority_bundle_digest
owner_ledger_digest
controlled_contract_catalog_digest
cw_output_contract_digest
gate_result_index_digest
evidence_output_rows
verified_evidence_bundle_digest
active_verifier_bundle_digest
```

Every `evidence_output_rows` item has exactly `path`, `mode = "100644"`,
`blob_sha256`, and `size_bytes`; the exact path set is the schema-frozen Cw
allowlist. The bundle contains no Cw/Sw OID, receipt, commit identity,
candidate-local object, or proposal ref. The external service reopens exact
`Pw`, validates the complete bundle against the lease-bound
`cw_output_contract_digest`, and later creates the bootstrap sibling's signed,
service-internal `EvidenceAssemblyResult` with exactly:

```text
lease_id
payload_commit_oid
payload_tree_oid
evidence_commit_oid
evidence_tree_oid
seal_commit_oid
seal_tree_oid
receipt_blob_sha256
git_object_import_receipt_digest
admission_intent_id
```

Those OIDs are authoritative only after the service has imported and
host-reopened both commits, durably persisted the immutable object-import
receipt, completed the matching intent/CAS/attestation, and returned an
authenticated `AdmittedWaveV1`. Candidate preflight can compare only
non-authoritative parity topology and bytes, reports only `preflight`, and
never receives `EvidenceAssemblyResult` or supplies an object to CAS.

Before lineage construction, this plan returns:

```text
/private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json
```

with exactly `schema_version`, `preparation_tip_oid`,
`preparation_tree_oid`, `wave_admission_projection_sha256`,
`owner_ledger_sha256`, `authority_bundle_digest`, and
`controlled_contract_catalog_digest`.

## File Responsibility Map

### Authority text and traceability

- Modify: `docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md`
- Modify: `docs/superpowers/plans/2026-07-15-iphone-air-architecture-convergence-master.md`
- Modify: `docs/superpowers/plans/2026-07-15-iphone-air-contracts-layercell.md`
- Modify: `docs/superpowers/plans/2026-07-15-iphone-air-silicon-execution-spine.md`
- Modify: `docs/superpowers/plans/2026-07-15-iphone-air-semantic-statelake-context.md`
- Modify: `docs/superpowers/plans/2026-07-15-iphone-air-sovereign-release-effects.md`
- Modify: `docs/superpowers/plans/2026-07-15-iphone-air-runtime-replay-certification.md`
- Modify: `docs/superpowers/specs/2026-07-17-k3-budget-provider-contract-addendum-design.md`
- Modify: `docs/superpowers/specs/2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md`
- Modify: `docs/superpowers/specs/2026-07-22-qinao-model-independent-app-agent-self-design.md`
- Modify: `docs/superpowers/specs/2026-07-23-qinao-governed-learning-plane-data-flywheel-thinking-design.md`
- Import then modify: `docs/superpowers/specs/qinao-authority-corruption-recovery-v1.md`
- Modify: `docs/superpowers/plans/2026-07-19-qinao-coreai-agent-controlled-document-convergence.md`
- Modify transitionally: `docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify: `scripts/check_qinao_owner_ledger.py`
- Modify: `scripts/test_check_qinao_owner_ledger.py`
- Delete: `docs/superpowers/plans/2026-07-23-qinao-clean-candidate-controlled-convergence.md`
- Import the exact six-plan executable program set:
  - `docs/superpowers/plans/2026-07-23-qinao-clean-candidate-reconstruction-and-controlled-convergence.md`
  - `docs/superpowers/plans/2026-07-23-qinao-c0-provenance-and-safe-import.md`
  - `docs/superpowers/plans/2026-07-23-qinao-bootstrap-verifier-and-admission-lineage.md`
  - `docs/superpowers/plans/2026-07-23-qinao-authority-ledger-and-cw-evidence.md`
  - `docs/superpowers/plans/2026-07-23-qinao-w0-safety-and-k4-proof.md`
  - `docs/superpowers/plans/2026-07-23-qinao-artifact-mesh-w1-task0.md`
- Create: `docs/superpowers/specs/qinao-authority-convergence-draft-v1.schema.json`
- Create: `docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json`
- Create: `scripts/check_qinao_authority_convergence.py`
- Create: `scripts/test_check_qinao_authority_convergence.py`
- Create: `scripts/build_qinao_authority_draft.py`
- Create: `scripts/test_build_qinao_authority_draft.py`

### Owner Ledger v2 and extension identities

- Modify: `docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify: `scripts/check_qinao_owner_ledger.py`
- Modify: `scripts/test_check_qinao_owner_ledger.py`
- Create: `scripts/qinao_owner_ledger_v2.py`
- Create: `scripts/test_qinao_owner_ledger_v2.py`
- Read without modifying:
  `docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json`
- Create: `docs/superpowers/specs/qinao-extension-slice-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-schema-fixture-manifest-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-extension-identity-catalog-v1.json`
- Create: `scripts/check_qinao_ea_extensions.py`
- Create: `scripts/test_check_qinao_ea_extensions.py`

### Production graph, closure, and V2 quarantine

- Create: `docs/superpowers/specs/qinao-production-reachability-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-architecture-closure-report-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-v2-quarantine-v1.schema.json`
- Create: `scripts/qinao_build_graph.py`
- Create: `scripts/test_qinao_build_graph.py`
- Create: `scripts/generate_qinao_production_reachability.py`
- Create: `scripts/check_qinao_production_reachability.py`
- Create: `scripts/test_check_qinao_production_reachability.py`
- Create: `scripts/generate_qinao_architecture_closure.py`
- Create: `scripts/check_qinao_architecture_closure.py`
- Create: `scripts/test_check_qinao_architecture_closure.py`
- Create: `scripts/generate_qinao_v2_quarantine.py`
- Create: `scripts/check_qinao_v2_quarantine.py`
- Create: `scripts/test_check_qinao_v2_quarantine.py`

### Finding identities and evidence-only Cw

- Create in `Pw`: `docs/superpowers/specs/qinao-finding-ledger-v2.schema.json`
- Create in `Pw`: `docs/superpowers/specs/qinao-finding-proof-leaf-v2.schema.json`
- Create in `Pw`: `docs/superpowers/specs/qinao-cw-evidence-manifest-v1.schema.json`
- Create in `Pw`: `docs/superpowers/specs/qinao-finding-identity-set-v2.json`
- Create in `Pw`: `scripts/build_qinao_cw_evidence.py`
- Create in `Pw`: `scripts/check_qinao_cw_evidence.py`
- Create in `Pw`: `scripts/test_qinao_cw_evidence.py`
- Import as reviewed preparation-only C1 inputs, then delete before `Pw`:
  `docs/superpowers/evidence/qinao-plan-remediation-2026-07-18.json`,
  `docs/superpowers/evidence/qinao-review-closure-2026-07-18.json`, and
  `docs/superpowers/evidence/qinao-review-findings-source-2026-07-18.txt`.
- Recreate from authenticated `Pw` gate results only by the external service
  in `Cw`: `docs/superpowers/evidence/qinao-plan-remediation-2026-07-18.json`
  and `docs/superpowers/evidence/qinao-review-closure-2026-07-18.json`.
- Create only in `Cw`: `docs/superpowers/evidence/qinao-finding-closure-v2/children/*.json` with exact cardinality 113
- Create only in `Cw`: `docs/superpowers/evidence/qinao-finding-closure-v2/aggregate.json`
- Create only in `Cw`: `docs/superpowers/evidence/qinao-production-reachability-v1.json`
- Create only in `Cw`: `docs/superpowers/evidence/qinao-architecture-closure-report-v1.json`
- Create only in `Cw`: `docs/superpowers/evidence/qinao-v2-quarantine-v1.json`
- Create only in `Cw`: `docs/superpowers/evidence/qinao-selected-release/preW0-index.json`
- Create only in `Cw`: `docs/superpowers/evidence/qinao-gate-results/preW0/index.json` plus exactly the 9 required preW0 `{gate_id}.json` projections
- Create only in `Cw`: `docs/superpowers/evidence/qinao-external-bundles/preW0/index.json`
- Create only in `Cw`: `docs/superpowers/evidence/qinao-wave-admission/preW0-cw-manifest.json`
- Create only by the external service in `Sw`: `docs/superpowers/evidence/qinao-wave-admission/preW0.json`

Every other `Create only in Cw` row above has the same external-service-only
ownership. Candidate tools may write byte-identical disposable parity copies
only below `/private/tmp/qinao-cw-parity-v1/`; they never write these paths in
the worktree, index, object database, or any ref.

### CI

- Modify: `.github/workflows/test.yml`
- Retain without editing or invoking here: the separately protected,
  B0-pinned OIDC admission client
  `.github/workflows/qinao-wave-admission.yml`
- Create: `scripts/run_nonempty_python_unittest.py`
- Create: `scripts/test_run_nonempty_python_unittest.py`
- Create: `scripts/check_qinao_payload_purity.py`
- Create: `scripts/test_check_qinao_payload_purity.py`

---

### Task 1: Freeze the Exact Authority Surface and Write the Failing Convergence Checker

**Files:**
- Verify without modifying:
  `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-provenance-v1.json`
- Create: `scripts/check_qinao_authority_convergence.py`
- Create: `scripts/test_check_qinao_authority_convergence.py`
- Create: `docs/superpowers/specs/qinao-authority-convergence-draft-v1.schema.json`

**Interfaces:**
- Consumes: the byte-verified C0 `SourceProvenanceV1` handoff, then
  candidate-index bytes for the exact 7 controlled documents, 4 governing
  addenda, recovery companion, CoreAI execution plan, old/new
  convergence-plan paths, and Owner Ledger.
- Produces: `validate_authority_tree(root: Path, ledger: dict) -> list[str]` and a read-only CLI whose only success grammar is `qinao-authority-convergence: PASS documents=11 controlled=7 addenda=4`.

- [ ] **Step 0: Consume the durable C0 handoff before any authority edit**

At Task-1 entry, discover—not “choose latest”—the unique commit that added the
fixed handoff path:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --expect-candidate-lineage prebootstrapPreparation \
  --require-clean
C0_HANDOFF_PATH=docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-provenance-v1.json
C0_HANDOFF_COMMIT="$(
  git log --format=%H --diff-filter=A -- "$C0_HANDOFF_PATH"
)"
test -n "$C0_HANDOFF_COMMIT"
test "$C0_HANDOFF_COMMIT" = "$(printf '%s' "$C0_HANDOFF_COMMIT" | head -n 1)"
git merge-base --is-ancestor "$C0_HANDOFF_COMMIT" HEAD
git diff --quiet "$C0_HANDOFF_COMMIT" HEAD -- "$C0_HANDOFF_PATH"
python3 scripts/qinao_source_provenance_v1.py verify \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --handoff-commit "$C0_HANDOFF_COMMIT"
```

Reopen the handoff's sole parent and require its inventory/map blobs,
canonical digests, source identities, and candidate destination tip/tree
byte-match all 12 `SourceProvenanceV1` fields. The `git log` output must be one
line exactly; zero or multiple creation commits fail. Between that commit and
current `HEAD`, only the already scheduled Bootstrap Task-1/1A commits may be
present, and the handoff path must be unchanged. Any wrong parent, extra
handoff diff, changed pair/path, noncanonical byte, unexpected intervening
commit, or source verification drift stops before Task 1 with
`BLOCKED_SOURCE_DRIFT` or `BLOCKED_DESTINATION_DRIFT`; Authority cannot
reconstruct the handoff from scattered files.

- [ ] **Step 1: Write RED tests for membership, status, and CoreAI traceability**

Add this exact test inventory to `scripts/test_check_qinao_authority_convergence.py`:

```python
EXPECTED_TESTS = {
    "test_repository_authority_tree_passes",
    "test_controlled_document_set_is_exactly_seven",
    "test_governing_addendum_set_is_exactly_four",
    "test_recovery_companion_is_non_authoritative",
    "test_recovery_companion_cannot_enter_seven_or_four",
    "test_recovery_rules_are_mapped_to_existing_owner_texts",
    "test_raw_content_defaults_content_free",
    "test_encryption_cannot_replace_decision_gate",
    "test_coreai_plan_is_non_executable_and_digest_pinned",
    "test_coreai_plan_rejects_unconditional_raw_persistence",
    "test_old_clean_candidate_plan_is_absent",
    "test_new_reconstruction_master_is_present",
    "test_contract_reference_block_is_unique_per_authority_text",
    "test_required_term_anchor_is_unique",
    "test_document_digest_uses_indexed_raw_bytes",
    "test_symlink_or_nonregular_authority_path_fails",
    "test_documented_gates_assert_named_files_before_scan",
    "test_documented_presence_gates_do_not_use_rg_dash_L",
    "test_documented_test_filters_require_nonempty_discovery",
    "test_ios27_floor_includes_rust_xcframework_script",
    "test_schema_v1_catalog_draft_is_explicitly_transitional",
    "test_schema_v1_catalog_rows_equal_reciprocal_authority_refs",
}
```

Fixture mutation helpers must copy only the exact authority paths into a temporary Git repository, use `git add` plus `git write-tree`, and mutate one predicate at a time. Assert the semantic diagnostic, including:

```python
self.assertIn(
    "recovery companion status must be exactly non-authoritative companion",
    result.stderr,
)
self.assertIn(
    "CoreAI plan must state that it cannot authorize execution",
    result.stderr,
)
self.assertIn(
    "unconditional durable raw-content persistence is forbidden",
    result.stderr,
)
```

Create the importable checker and syntactically valid schema stubs in this
same RED step. The checker exposes the final CLI/function signatures and
returns only `qinao.authority-convergence.unimplemented`; the schema rejects
the positive fixture with that same diagnostic.

- [ ] **Step 2: Run the focused RED and prove discovery**

Run:

```bash
python3 -m unittest -v \
  scripts.test_check_qinao_authority_convergence.QinaoAuthorityConvergenceTests
```

Expected: 22 tests discovered; the repository fixture fails on
`qinao.authority-convergence.unimplemented` and mutation cases remain RED on
their asserted semantics. No failure is an import, syntax, or missing-fixture
error.

- [ ] **Step 3: Add the exact authority constants and read-only indexed-byte loader**

Add to `scripts/check_qinao_authority_convergence.py`:

```python
CONTROLLED_DOCUMENTS = (
    ("architecture", "docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md"),
    ("convergence-master", "docs/superpowers/plans/2026-07-15-iphone-air-architecture-convergence-master.md"),
    ("contracts", "docs/superpowers/plans/2026-07-15-iphone-air-contracts-layercell.md"),
    ("silicon", "docs/superpowers/plans/2026-07-15-iphone-air-silicon-execution-spine.md"),
    ("semantic", "docs/superpowers/plans/2026-07-15-iphone-air-semantic-statelake-context.md"),
    ("sovereign", "docs/superpowers/plans/2026-07-15-iphone-air-sovereign-release-effects.md"),
    ("runtime", "docs/superpowers/plans/2026-07-15-iphone-air-runtime-replay-certification.md"),
)

GOVERNING_ADDENDA = (
    ("k3-provider-addendum", "docs/superpowers/specs/2026-07-17-k3-budget-provider-contract-addendum-design.md"),
    ("agent-context-addendum", "docs/superpowers/specs/2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md"),
    ("app-agent-addendum", "docs/superpowers/specs/2026-07-22-qinao-model-independent-app-agent-self-design.md"),
    ("governed-learning-addendum", "docs/superpowers/specs/2026-07-23-qinao-governed-learning-plane-data-flywheel-thinking-design.md"),
)

RECOVERY_COMPANION = "docs/superpowers/specs/qinao-authority-corruption-recovery-v1.md"
COREAI_PLAN = "docs/superpowers/plans/2026-07-19-qinao-coreai-agent-controlled-document-convergence.md"
OLD_PLAN = "docs/superpowers/plans/2026-07-23-qinao-clean-candidate-controlled-convergence.md"
NEW_MASTER = "docs/superpowers/plans/2026-07-23-qinao-clean-candidate-reconstruction-and-controlled-convergence.md"
EXECUTABLE_CHILD_PLAN_PATHS = (
    "docs/superpowers/plans/2026-07-23-qinao-c0-provenance-and-safe-import.md",
    "docs/superpowers/plans/2026-07-23-qinao-bootstrap-verifier-and-admission-lineage.md",
    "docs/superpowers/plans/2026-07-23-qinao-authority-ledger-and-cw-evidence.md",
    "docs/superpowers/plans/2026-07-23-qinao-w0-safety-and-k4-proof.md",
    "docs/superpowers/plans/2026-07-23-qinao-artifact-mesh-w1-task0.md",
)
PROGRAM_PLAN_PATHS = (NEW_MASTER, *EXECUTABLE_CHILD_PLAN_PATHS)

REFERENCE_PREFIX = "<!-- qinao-contract-catalog-refs-v1:"
REFERENCE_SUFFIX = " -->"
TERM_PREFIX = "<!-- qinao-required-term-v1:"
TERM_SUFFIX = " -->"
TERM_ID = re.compile(r"[a-z0-9][a-z0-9._-]{0,127}")

FORBIDDEN_RAW_DEFAULTS = (
    "canonical encrypted raw content is durable",
    "forbid `Decision Gate`",
    "forbid Decision Gate",
    "raw content is always persisted",
    "raw content must always be persisted",
)

REQUIRED_COREAI_TRACEABILITY = (
    "non-authoritative execution artifact",
    "cannot authorize execution",
    "current signed exact-purpose Decision Gate",
    "content-free is the default",
)
```

Use only these Git reads:

```python
def indexed_blob(root: Path, path: str) -> bytes:
    stage = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--stage", "--", path],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.splitlines()
    if len(stage) != 1:
        raise ValueError(f"{path}: expected exactly one indexed entry")
    mode, oid, stage_number, indexed_path = stage[0].split(maxsplit=3)
    if mode != "100644" or stage_number != "0" or indexed_path != path:
        raise ValueError(f"{path}: expected regular stage-0 mode-100644")
    return subprocess.run(
        ["git", "-C", str(root), "cat-file", "blob", oid],
        check=True,
        capture_output=True,
    ).stdout
```

The checker never invokes a shell, follows no symlink, writes no path, runs no generated candidate script, and never reads an authority decision from the worktree when indexed bytes differ.

- [ ] **Step 4: Add exact reference-block and companion/CoreAI validation**

Implement these closed functions:

```python
def parse_reference_block(text: str, path: str) -> tuple[tuple[str, str, str], ...]:
    lines = [line for line in text.splitlines() if line.startswith(REFERENCE_PREFIX)]
    if len(lines) != 1 or not lines[0].endswith(REFERENCE_SUFFIX):
        raise ValueError(f"{path}: expected exactly one canonical contract reference block")
    raw = lines[0][len(REFERENCE_PREFIX):-len(REFERENCE_SUFFIX)]
    value = json.loads(raw, object_pairs_hook=reject_duplicate_keys)
    if not isinstance(value, list) or not value:
        raise ValueError(f"{path}: reference block must be a non-empty array")
    rows: list[tuple[str, str, str]] = []
    for row in value:
        if not isinstance(row, dict) or set(row) != {
            "contract_id", "version", "required_term_id"
        }:
            raise ValueError(f"{path}: malformed contract reference row")
        key = (row["contract_id"], row["version"], row["required_term_id"])
        if not all(isinstance(item, str) and item for item in key):
            raise ValueError(f"{path}: contract reference values must be non-empty strings")
        if TERM_ID.fullmatch(key[2]) is None:
            raise ValueError(f"{path}: invalid required_term_id {key[2]!r}")
        rows.append(key)
    if rows != sorted(set(rows)):
        raise ValueError(f"{path}: contract references must be uniquely sorted")
    return tuple(rows)

def validate_recovery_companion(text: str) -> list[str]:
    errors: list[str] = []
    if "Status: non-authoritative companion, fail-closed" not in text:
        errors.append(
            "recovery companion status must be exactly non-authoritative companion"
        )
    forbidden = (
        "surviving external recovery registry",
        "RecoveryAuthority",
        "RecoveryRegistry",
        "global recovery database",
        "global incident-record store",
    )
    for phrase in forbidden:
        if phrase in text:
            errors.append(f"recovery companion retains forbidden authority phrase: {phrase}")
    return errors

def validate_coreai_plan(text: str) -> list[str]:
    errors = [
        f"CoreAI plan missing required traceability term: {term}"
        for term in REQUIRED_COREAI_TRACEABILITY
        if term not in text
    ]
    for phrase in FORBIDDEN_RAW_DEFAULTS:
        if phrase.casefold() in text.casefold():
            errors.append(
                f"unconditional durable raw-content persistence is forbidden: {phrase}"
            )
    return errors
```

Also require `OLD_PLAN` absent from the index and every member of
`PROGRAM_PLAN_PATHS` present through `indexed_blob` as a regular stage-0
mode-`100644` file. Parse only the `## Executable Child Plans` section of
`NEW_MASTER`: its first numbered list must equal
`EXECUTABLE_CHILD_PLAN_PATHS` in exact order with no missing, extra,
duplicate, or aliased path. Extend the existing path-boundary test with
subtests that delete/rename each child, change its index mode, add a sixth
child, duplicate a child, and point the master at an unindexed lookalike; all
must fail while the total authority-test discovery count remains 22.

- [ ] **Step 5: Run the test module and commit the checker slice**

Run:

```bash
python3 -m unittest -v \
  scripts.test_check_qinao_authority_convergence.QinaoAuthorityConvergenceTests
```

Expected: all checker-unit fixtures pass; repository-positive remains RED until Task 2 changes the authority bytes.

Commit only:

```bash
git add \
  scripts/check_qinao_authority_convergence.py \
  scripts/test_check_qinao_authority_convergence.py \
  docs/superpowers/specs/qinao-authority-convergence-draft-v1.schema.json
git commit -m "test(qinao): specify authority convergence boundary"
```

Expected: one preparation commit with exactly three paths.

---

### Task 2: Draft the Exact 7+4 Authority Correction and Demote the Recovery Companion

**Files:**
- Modify the exact 7 controlled documents and 4 governing addenda in the File Responsibility Map.
- Import then modify: `docs/superpowers/specs/qinao-authority-corruption-recovery-v1.md`
- Modify: `docs/superpowers/plans/2026-07-19-qinao-coreai-agent-controlled-document-convergence.md`
- Modify: `docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify: `scripts/check_qinao_authority_convergence.py`
- Modify: `scripts/test_check_qinao_authority_convergence.py`
- Modify: `scripts/check_qinao_owner_ledger.py`
- Modify: `scripts/test_check_qinao_owner_ledger.py`
- Delete: `docs/superpowers/plans/2026-07-23-qinao-clean-candidate-controlled-convergence.md`
- Import in Step 0: the exact six-member `PROGRAM_PLAN_PATHS` set from
  Task 1, with the reconstruction master first and its five executable
  children in the frozen order.

**Interfaces:**
- Consumes: Task 1 checker and the approved correction design's Sections 3-13.
- Produces: one internally consistent authority draft with exact 7+4
  membership, owner-private recovery, Decision-Gate precedence,
  non-executable CoreAI traceability, and one schema-v1 transitional
  non-authoritative catalog installed in the sole Ledger for Input A.

- [ ] **Step 0: Review and import the complete non-reusable C1 source slice**

The C0 handoff is deliberately all-`hold`; therefore no Task-2 “Import” path
exists until Bootstrap Task 1A Steps 5-6 have frozen the clean C1 context,
obtained the two-person external review, reopened its append-only record, and
returned the opaque `VerifiedImportReviewV1`. First run the fixed verifier;
it accepts no caller path, key, context, or bypass:

```bash
test -z "$(git status --porcelain=v1)"
python3 scripts/qinao_import_review_v1.py --verify-fixed-export C1
```

Expected: exactly one authenticated C1 record with ten rows and its immutable
reopen receipt. Review these ten literal source paths as one indivisible C1
slice:

```text
docs/superpowers/evidence/qinao-plan-remediation-2026-07-18.json
docs/superpowers/evidence/qinao-review-closure-2026-07-18.json
docs/superpowers/evidence/qinao-review-findings-source-2026-07-18.txt
docs/superpowers/plans/2026-07-23-qinao-artifact-mesh-w1-task0.md
docs/superpowers/plans/2026-07-23-qinao-authority-ledger-and-cw-evidence.md
docs/superpowers/plans/2026-07-23-qinao-bootstrap-verifier-and-admission-lineage.md
docs/superpowers/plans/2026-07-23-qinao-c0-provenance-and-safe-import.md
docs/superpowers/plans/2026-07-23-qinao-clean-candidate-reconstruction-and-controlled-convergence.md
docs/superpowers/plans/2026-07-23-qinao-w0-safety-and-k4-proof.md
docs/superpowers/specs/qinao-authority-corruption-recovery-v1.md
```

For each decoded raw-path row, compare the frozen C0 inventory bytes and
require the opaque verified record's signed decision-row projection to equal:

```text
decision = import
destination_batch = C1
source_stratum =
  worktree for qinao-plan-remediation-2026-07-18.json
  untracked for qinao-review-closure-2026-07-18.json
  untracked for qinao-review-findings-source-2026-07-18.txt
  head for all six 2026-07-23 executable program-plan files
  index for qinao-authority-corruption-recovery-v1.md
source_sha256/source_mode = exact values copied from that inventory stratum
rationale =
  authority-input-a-finding-identity-source-only for the three finding rows
  executable-child-plan-source-only for the five child-plan rows
  program-master-source-only for the reconstruction master row
  authority-companion-source-only for the recovery companion row
```

Do not edit the map or copy any field manually. Bootstrap's fixed
materializer derives `review_record_digest = verified.record_digest`,
`reviewer_identity_digest = verified.reviewer_principal_digest`, and
`reviewed_at = verified.reviewed_at` in-process, then atomically writes the
only legal complete C1 postimage. Those values are never typed from console
output, read through an unverified record parser, or recovered from an old
map.

The three finding-source SHA-256 values must additionally equal, in the same
path order:

```text
58853885646f4d09c17aae8d29e2ad0cd236dadf785bb7335a7663a2fc16b389
b65ff9e0069c445941bcd936829d07070a7d84cb4ac81de6772e93832343e27e
cfaa56dae40624b78fac5b45dc00dc8b957aada83904de7e0f45ed31fbd61dd5
```

No member of the six-plan program set embeds its own future source digest.
Each `head` digest/mode comes only from the already-frozen C0 inventory after
this six-plan planning commit and is then bound by the reviewed map and apply
plan. A missing stratum, changed source byte, absent authenticated review, or
any eleventh C1 row stops
`BLOCKED_IMPORT_REVIEW`.

Validate the unique preapply postimage, commit only the map as the next
candidate commit after the context HEAD, immediately reopen its history
transition, and only then prepare/apply one fresh C1 plan:

```bash
python3 scripts/capture_qinao_candidate_inventory.py \
  --root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --verify docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json
python3 scripts/qinao_import_review_v1.py --apply-fixed-map-postimage C1
python3 scripts/check_qinao_import_map.py \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
git add docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
test "$(git diff --cached --name-only)" = \
  docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
git commit -m "docs(qinao): review complete authority c1 source slice"
python3 scripts/qinao_import_review_v1.py --verify-fixed-export C1
python3 scripts/check_qinao_import_map.py \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json

test ! -e /private/tmp/qinao-c1-authority-source-import-plan.json
python3 scripts/apply_qinao_import_map.py \
  --candidate-root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --source-root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json \
  --prepare-batch C1 \
  --output-plan /private/tmp/qinao-c1-authority-source-import-plan.json
python3 scripts/apply_qinao_import_map.py \
  --candidate-root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --source-root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json \
  --apply-plan /private/tmp/qinao-c1-authority-source-import-plan.json
```

Decode the apply-plan `path_b64` rows and byte-compare their sorted raw-path
set with the ten literal paths above before committing. Require exactly ten
stage-0 regular mode-`100644` postimages and no other staged path, then:

```bash
git diff --cached --check
git commit -m "docs(qinao): import complete authority c1 source slice"
test -z "$(git status --porcelain=v1)"
```

This is the only C1 prepare/apply in the program. The three finding inputs
remain temporary and Task 9 must delete them; the companion and exact
six-plan executable program set remain. Later tasks only verify these C1 rows
and may not select them again.
Any commit between the frozen C1 context and the map-only commit, any
non-map diff in that commit, a missing `review_record_digest`, or a
postcommit/history reopen mismatch is
`BLOCKED_IMPORT_REVIEW/IMPORT_REVIEW_CONTEXT_MISMATCH`; C1 is not applied.

- [ ] **Step 1: Add one RED test per required authority delta**

Add parameterized cases to `scripts/test_check_qinao_authority_convergence.py` for this exact matrix:

| Document ID | Required correction terms |
|---|---|
| `architecture` | `L7/R0 → L8 LaneQuery → R1-R4 → L8 LaneResult → R5 → R6`; one final State Market; permit Artifact versus K3 row; K3-only semantic-snapshot currentness; `BASAuthorizedInputEffectPredecessorPayload`; `BASContentIntakeProfilePayload`; coordinator-owned sink handoff; neural-state reader; `bufferedUntilVerified`; preserved hyphenated RSI terminal wires |
| `convergence-master` | indivisible C1+C2; `Pw → evidence-only Cw → receipt-only Sw`; no caller wave; B0 predecessor; explicit preW0 implementation base; `executeAtMostOnce`; Artifact Mesh Task 0 before W1 consumers; non-vacuous gates; B0-self-contained 13-suite/16-ID W0 open-set authority; no latest-series/successor/raw-log gate; explicit roll-forward-only option |
| `contracts` | exactly two new immutable families; vNext StatePrepare/outbox source ref; current/missing/future fixtures; no fictional backward fixture; hyphenated `needs-confirmation`; owner-private recovery values; buffered-only reachability |
| `silicon` | one physical call per branch; `executeAtMostOnce`; Provider-specific context/cache; host-only HeavyPhase V1; honest AFM; nonsecret remote M; post-handoff exact-version secret resolution; neural-reader rename; imported sequence-zero rows are history only and no latest-series/successor/raw-log W0 authority remains |
| `semantic` | L8 query/result around R1-R4; one compiler `BASContextCompiler`; no self-pop; K3 currentness; Web/content untrusted; invalidation fanout |
| `sovereign` | buffered publication/effect/state/Web; two typed causal predecessor families; vNext source ref; nonoptional state prepare/stage/seal/activate; coordinator-owned sink handoff; owner-private recovery; real K4 proof |
| `runtime` | root/Session activation; continuity; information sufficiency; content intake; NextQuestion; recognition union; legacy-mouth reachability; rollback compatibility; Artifact Mesh recovery; correct `QinaoRuntimeSDKTests` target; conditional 40/30; imported sequence-zero rows are history only and no latest-series/successor/raw-log W0 authority remains |
| `k3-provider-addendum` | master included in normative priority; A→M; four-ref `BASSiliconExecutionBinding`; M has no `materializationContractArtifactID`/fourth parent; permit→K3 prepare→K4 anchor→K3 arm→fresh handoff; two-family source ref; remote credential-version binding; K3 snapshot currentness; incremental rows unreachable |
| `agent-context-addendum` | “State Compiler” and “Context Budget Allocator” are phases of sole `BASContextCompiler`; `knownIssueSetDigest`; canonical terminal set with hyphenated `needs-confirmation`; Decision-Gate precedence; references-only continuity; Agent correlation rules; model-context adaptation; intake consumption |
| `app-agent-addendum` | root genesis/reopen/currentness; Session CAS; deletion fences; idle NextQuestion; Recognition union; contamination cleaning; no deterministic public terminal; buffered visibility |
| `governed-learning-addendum` | complete causal partial order; Experience-or-ineligible; 12-row legacy-mouth retirement; presentation cadence; Web/content cleaning; buffered-only |

Each case deletes one term from a copied document and asserts the exact document ID in the diagnostic.

For the controlled convergence master, Silicon plan, and Runtime plan, the
correction is an exact authority migration, not additive prose: remove every
ordinary-CI or completion-gate invocation of
`check_w0_expected_open_set.py`, every `--latest-series` and
`--emit-successor-from` command, every requirement to commit a sequence-1
receipt or raw `qinao-w0-probe-logs` transcript, and every claim that either
sequence-zero JSON is current authority. Replace the shared completion
contract with the B0 `w0_open_set_v1_exact_set` 13-suite/16-ID program and
non-empty suite execution. The convergence checker tests both positive terms
and the complete negative token/command set in each of these three exact
documents; a comment-shaped or disabled legacy command still fails.

Also add exactly one method to the incumbent Owner-Ledger suite:
`test_schema_v1_transitional_catalog_requires_closed_unadmitted_shape`. It
uses subtests to reject the catalog under ordinary schema-v1 status, the
transitional status without a catalog, missing/extra/duplicate rows or
fields, noncanonical order, empty refs, and any prematurely present
`governing_addenda_v1`, `shipping_release_profiles_v1`, or
`wave_admission_v1`. Its repository fixture also requires exactly one
`owners[]` row with `owner_id = artifact.mesh`, requires that row's
implementation-health `status = converging`, and rejects the original false
`implemented` value, a missing/duplicate row, or any non-status change from
the reviewed owner-row preimage. This is separate from contract-lifecycle
status validation. Before Step 6, run this single method and require its
positive fixture to fail on
`schema-v1 transitional catalog support is unimplemented`, not on import,
syntax, or fixture construction.

- [ ] **Step 2: Apply the canonical pipeline and terminal-path wording**

In every affected flow block, use exactly:

```text
Input Event
→ Input Normalizer
→ Intent + Risk Router
→ State Requirement Planner
→ L7 requirements
→ R0 compiled pre-physical eligibility
→ L8 snapshot-bound LaneQuery
→ R1-R4 retrieval mechanisms
→ L8 snapshot-bound LaneResult
→ R5 bounded dedupe/fusion/grounding proposal
→ R6 hard revalidation/conflict resolution/one final State Market
→ Context Budget Allocator bound to BASContextCompiler
→ BASContextCompiler for the selected Provider/tokenizer/accounting profile
→ Prefill Router
→ Decode Router
→ Output Verifier
→ branch-specific final response, external effect, or internal-state terminal path
```

Do not introduce classes for these shorthand phase labels. Preserve the existing branch-specific owners and terminal contracts.

Apply the correction design's immutable RSI wire decision across the
architecture, Contracts plan, and Agent/Context addendum. Preserve Swift case
names, but replace the underscore wire aliases with exactly
`needs-confirmation`, `degraded-with-coverage`,
`indeterminate-needs-reconciliation`, `cycle-detected`,
`budget-exhausted`, and `no-progress` wherever the corresponding frozen value
is named. This is a documentation/fixture correction to the already-existing
hyphenated wire, not a production migration or a new terminal state.

Correct the sole Owner Ledger's false Artifact Mesh health claim in the same
reviewed C1/C2 authority draft. In the unique owner row whose `owner_id` is
`artifact.mesh`, change only its implementation-health `status` from
`implemented` to `converging`; preserve every other owner-row field and do
not confuse this owner-health value with a controlled-contract lifecycle
status. The Artifact Mesh sibling Task 10 is the sole later writer allowed to
propose the exact reverse transition after a passing Task-0 candidate. That
proposal remains non-authoritative until the final W1 `Pw` passes the active
B0 Owner-Ledger and physical gates and W1 admission finalizes. No other W1
task may consume the repaired store before the post-transition Task-0
handoff, and no task may mutate the Ledger after final W1 `Pw` is frozen.

Resolve the K3/Silicon materialization conflict atomically. The final
`BASSiliconExecutionBinding` step mapping contains exactly
model/profile/plan-template/budget Artifact references, matching the Silicon
owner. `BASMaterializedProviderRequestPayload` contains exactly execution ref,
execution-plan Artifact ID, selected persisted-Provider-descriptor Artifact
ID, and request bytes; its ordered outer parents are exactly allocation
receipt, `BASExecutionPlan`, and `BASPersistedOrganDescriptorPayload`.
Materialization rules remain inside the referenced execution-plan/template
mechanism. Delete `materializationContractArtifactID` and every implied fourth
parent/standalone materialization-contract artifact; do not register a third
new immutable family. The K3 addendum's normative-priority clause explicitly
includes the convergence master and correction design, and every 7+4
occurrence of `executeExactlyOnce` atomically becomes `executeAtMostOnce`.

Replace the W1 QinaoRuntimeSDK model-boundary raw-byte regex with the existing
build-graph Swift import/declaration/reference projection: CoreAI,
FoundationModels, and MLX are rejected as parsed imports; Qwen, MiniCPM, and
Granite are rejected only when they resolve in code/declaration/reference
positions. Comments, doc comments, and string literals are excluded by the
parser, while aliases, typealiases, callbacks, reflection, and linked symbols
remain conservatively covered. A free-text mention cannot fail the gate, and
a renamed code alias cannot evade it.

Repair every documented mechanical gate in the 7+4 texts at the same time:
each named input first proves regular stage-0 indexed existence and rejects
symlinks before searching; no `if rg ...` may turn ripgrep exit `2` into
success; no presence gate uses ripgrep's follow option as a
files-without-match substitute. Use an explicit per-file `rg -q`/failure
loop or the typed Python checker. Every focused Swift
filter first enumerates the exact package test target/suite, proves at least
one discovered test, then runs it; zero matches cannot exit successfully.
Use the real `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests` target, require the
W0 freeze test there, and make
`BehavioralAISubstrate/scripts/build-rust-xcframework.sh` declare/check
`IPHONEOS_DEPLOYMENT_TARGET=27.0` with no stale iOS-18 comment. Record the
preW0 implementation base explicitly as the then-current reviewed
preparation/Pw lineage rather than ambiguously choosing between the W0 branch
and its three already-landed W0 commits.

Also remove cross-wave compile dependencies from baseline tests and exits:
W0 freezes only APIs present at W0 and does not call future
`adapter(providerID:)`, `operation.stream().final()`, or spool fields; future
API contracts remain schema/fixture identities until their owning wave makes
them compilable. First-wire 1.0.0 types receive no fictional
`.backward_v1`; existing governed cardinality is derived as prior count plus
the exact additions instead of hard-coding 276. In W4, define
`HardCapDerivationSource` before any consumer task. Do not require W5 spool
behavior in a W4 exit gate. Treat `cold ≥ 40 tok/s` and
`sustained ≥ 30 tok/s` only as conditional device-profile targets with
measured fallback/Pareto evidence, never unconditional W6 completion gates.

- [ ] **Step 3: Fold recovery into each existing owner and demote the companion**

Replace the companion header exactly with:

```text
# Qinao Authority Corruption Recovery Companion v1

Status: non-authoritative companion, fail-closed

Scope: explanatory recovery cross-reference for iOS 27+ owner-private stores
Authority: none; the mapped Owner Ledger cards and their controlled domain documents are authoritative
```

Replace the full sentence containing `in a surviving external recovery registry or operator incident record` with:

```text
Those identities remain blocked/query-only in the same mapped domain owner's verified owner-private recovery record.
```

In the relevant controlled documents, require the closed product:

```text
stateFacet = stateless | ephemeralDrop | rebuildableProjection | durableStore
boundaryFacet = none | externalEffect
```

For every `durableStore`, name its own lifecycle, external floor/anchor, sole writer, protection, lease, DB/WAL/SHM quarantine, reopen, corruption, and recovery. For every reachable possible-start boundary, require authenticated query/reconcile and forbid blind replay. Do not retain `RecoveryAuthority`, `RecoveryRegistry`, a shared recovery signer, or a global incident store.

- [ ] **Step 4: Reverse the CoreAI raw-content contradiction and make traceability non-executable**

Replace the complete row currently beginning `canonical encrypted raw content is durable` with:

```text
| content-free Experience Envelope is the default; durable raw/content materialization is permitted only by the current signed exact-class/exact-purpose Decision Gate | Master Decision-Gate and contamination rows; Semantic owning-wave content tasks | negative reachability proves no durable raw/content write without the gate; authorized cases bind class, purpose, policy epoch, expiry, deletion/erasure closure, and exact Artifact lineage |
```

Add this exact block before the CoreAI plan's first executable task:

```text
## Non-Authoritative Traceability Boundary

This plan is a non-authoritative execution artifact. It cannot authorize execution,
create an owner, select a wave, satisfy a gate, or amend a controlled document.
Execution requires the exact current Owner Ledger v2, its 7+4 candidate-byte digests,
the admitted convergence master, and the protected predecessor-derived wave receipt.
Content-free is the default. Encrypted durable raw/content materialization requires
the current signed exact-purpose Decision Gate; encryption cannot replace that gate.
If any referenced authority digest differs, this plan is stale and execution is blocked.
```

Add a machine-readable trace block with exact closed grammar:

```html
<!-- qinao-nonauthoritative-plan-trace-v1:{"authority_bundle_digest":"0000000000000000000000000000000000000000000000000000000000000000","controlled_contract_catalog_digest":"0000000000000000000000000000000000000000000000000000000000000000","owner_ledger_digest":"0000000000000000000000000000000000000000000000000000000000000000","status":"blocked-until-prew0-admitted"} -->
```

The three digest values are finalized in Task 6 after bootstrap handoff B. Until then the preparation tree carries the exact all-zero digest only inside this non-executable trace block and the checker requires `status = blocked-until-prew0-admitted`; the all-zero form cannot enter final `Pw`.

- [ ] **Step 5: Retire the superseded plan and verify the reviewed six-plan program**

Delete only:

```text
docs/superpowers/plans/2026-07-23-qinao-clean-candidate-controlled-convergence.md
```

Step 0 has already imported the reviewed program master at:

```text
docs/superpowers/plans/2026-07-23-qinao-clean-candidate-reconstruction-and-controlled-convergence.md
```

The authority checker requires the old path absent, all six
`PROGRAM_PLAN_PATHS` regular/indexed, and the master's exact five-child list
byte-equal to `EXECUTABLE_CHILD_PLAN_PATHS`. None enters the 7
controlled-document or 4 addendum maps. The new master and its children are
execution plans, not additional authority documents.

- [ ] **Step 6: Install the transitional catalog, then generate reciprocal 7+4 anchors**

Before generating a reference block, install the complete canonical
`controlled_contract_catalog_v1` row array directly in the sole indexed
`docs/superpowers/specs/qinao-owner-ledger-v1.json`. This is an Input-A
preparation state, not a second Ledger or an admissible schema v2:

```text
schema_version == 1
ledger_id == qinao-owner-ledger-v1
status == transitional_unadmitted_input_a
controlled_contract_catalog_v1 == complete canonical final row array
governing_addenda_v1 is absent
shipping_release_profiles_v1 is absent
wave_admission_v1 is absent
```

Every catalog row already has the final exact `CONTRACT_FIELDS` and
`AUTHORITY_REF_FIELDS` shape from Task 4. Build the incumbent row identities
from the indexed `BASEBrainSchemaGovernanceRegistry` plus the
release-condition-aware governed declaration scan, then add only the exact
new/vNext contract identities named by the correction design and this plan's
Task-5 E/A roster. Owner, version, declaration path/symbol, registry,
lifecycle waves/status, prelude flag, and authority refs are literal reviewed
values in the resulting indexed array; no later task is allowed to infer or
choose a replacement. Sort uniquely by `(contract_id, version)`, require the
row union to equal the independently derived incumbent-plus-exact-delta set,
and review the generated diff row by row.

Extend the incumbent Owner-Ledger checker with one fail-closed transitional
dispatch. It accepts the extra catalog field only for the exact status above,
validates the complete closed row/ref grammar, prints
`mode=transitional_unadmitted_input_a`, and never reports schema v2,
admitted, or active release. Any other schema-v1 root remains subject to the
original exact top-level set. This temporary dispatch is removed only when
Task 4 atomically upgrades the same file to schema v2.

Now generate every authority reference from those already-indexed Ledger
rows. Each authority text gets exactly one single-line block:

```python
refs = sorted(
    refs_by_document[document_id],
    key=lambda row: (
        row["contract_id"],
        row["version"],
        row["required_term_id"],
    ),
)
catalog_line = (
    "<!-- qinao-contract-catalog-refs-v1:"
    + canonical_json(refs).decode("utf-8")
    + " -->"
)
term_lines = [
    f"<!-- qinao-required-term-v1:{row['required_term_id']} -->"
    for row in refs
]
```

The final block entries sort uniquely by
`(contract_id, version, required_term_id)`, each `term_lines` value appears
exactly once in that document, and the Ledger-side refs sort by
`(document_id, required_term_id)`.

Run the two new Task-1 authority tests plus the one new incumbent-Ledger test.
Expected: 22 authority tests and 102 incumbent Ledger tests are discovered;
all pass, the Ledger reports only its transitional mode, and changing one
catalog/ref/anchor byte fails exact reciprocal equality.

- [ ] **Step 7: Run the authority checker against indexed bytes**

Stage only the 7+4 texts, companion, CoreAI plan, old-plan deletion, sole
Ledger, and the two authority/Owner-Ledger checker-test pairs. The six
program-plan paths were already committed by the C1 import and remain
verify-only here. Then run:

```bash
python3 scripts/check_qinao_authority_convergence.py \
  --root . \
  --ledger docs/superpowers/specs/qinao-owner-ledger-v1.json
python3 scripts/check_qinao_owner_ledger.py \
  --root . \
  --ledger docs/superpowers/specs/qinao-owner-ledger-v1.json
```

Expected: authority convergence passes
`documents=11 controlled=7 addenda=4`; the separate Owner-Ledger checker
passes only with `mode=transitional_unadmitted_input_a`. Neither checker may
report schema v2, admission, a shipping profile, or a bootstrap projection at
this point.

- [ ] **Step 8: Commit the reviewed text draft as preparation evidence**

Run:

```bash
git diff --exit-code -- \
  docs/superpowers/plans/2026-07-23-qinao-clean-candidate-reconstruction-and-controlled-convergence.md \
  docs/superpowers/plans/2026-07-23-qinao-c0-provenance-and-safe-import.md \
  docs/superpowers/plans/2026-07-23-qinao-bootstrap-verifier-and-admission-lineage.md \
  docs/superpowers/plans/2026-07-23-qinao-authority-ledger-and-cw-evidence.md \
  docs/superpowers/plans/2026-07-23-qinao-w0-safety-and-k4-proof.md \
  docs/superpowers/plans/2026-07-23-qinao-artifact-mesh-w1-task0.md
git diff --check -- \
  docs/superpowers/specs \
  docs/superpowers/plans \
  scripts/check_qinao_authority_convergence.py \
  scripts/test_check_qinao_authority_convergence.py \
  scripts/check_qinao_owner_ledger.py \
  scripts/test_check_qinao_owner_ledger.py
git add \
  docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md \
  docs/superpowers/plans/2026-07-15-iphone-air-architecture-convergence-master.md \
  docs/superpowers/plans/2026-07-15-iphone-air-contracts-layercell.md \
  docs/superpowers/plans/2026-07-15-iphone-air-silicon-execution-spine.md \
  docs/superpowers/plans/2026-07-15-iphone-air-semantic-statelake-context.md \
  docs/superpowers/plans/2026-07-15-iphone-air-sovereign-release-effects.md \
  docs/superpowers/plans/2026-07-15-iphone-air-runtime-replay-certification.md \
  docs/superpowers/specs/2026-07-17-k3-budget-provider-contract-addendum-design.md \
  docs/superpowers/specs/2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md \
  docs/superpowers/specs/2026-07-22-qinao-model-independent-app-agent-self-design.md \
  docs/superpowers/specs/2026-07-23-qinao-governed-learning-plane-data-flywheel-thinking-design.md \
  docs/superpowers/specs/qinao-authority-corruption-recovery-v1.md \
  docs/superpowers/specs/qinao-owner-ledger-v1.json \
  docs/superpowers/plans/2026-07-19-qinao-coreai-agent-controlled-document-convergence.md \
  docs/superpowers/plans/2026-07-23-qinao-clean-candidate-controlled-convergence.md \
  scripts/check_qinao_authority_convergence.py \
  scripts/test_check_qinao_authority_convergence.py \
  scripts/check_qinao_owner_ledger.py \
  scripts/test_check_qinao_owner_ledger.py
test "$(git diff --cached --name-only | wc -l | tr -d ' ')" -eq 19
git diff --cached --check
git commit -m "docs(qinao): draft atomic authority convergence"
```

Expected: one 19-path preparation commit containing the exact authority-text
set plus the sole transitional Ledger and its two checker/test pairs; it is
not `Pw`, is not admitted, reports no schema-v2 success, and is never pushed
to the protected ref.

---

### Task 2A: Import the Signed C2 Bootstrap/W0 Helper Closure

**Files:**
- Import exactly the 32 literal paths in the table below.
- Modify and commit before import:
  `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json`.
- Modify in one separate immediate child after the exact import commit:
  `scripts/run_nonempty_swift_filter.py`,
  `scripts/test_run_nonempty_swift_filter.py`, and
  `scripts/test_qinao_plan_remediation.py`.
- Create outside Git only:
  `/private/tmp/qinao-c2-helper-source-import-plan.json`.

**Interfaces:**
- Consumes: clean post-Task-2 candidate, Bootstrap Task 1A Step 7's opaque
  `VerifiedImportReviewV1`, the immutable C2 reopen receipt, and C0's frozen
  source inventory.
- Produces: one map-only C2 postimage commit, one exact 32-path import commit,
  then one exact-three-path helper/test hardening commit. The import parent
  permanently preserves the reviewed source bytes; the child hardens only a
  candidate diagnostic runner and its regressions, with no production
  runtime behavior. This task creates no B0, current verifier, gate result,
  evidence, owner, or admission authority.

The C2 closure is literal and closed. It is not “all helpers”, a glob, or
whatever the review checker happens to reference at execution time:

| Exact path | Source stratum | SHA-256 | Mode |
|---|---|---|---|
| `.gitattributes` | `index` | `55f220391ea5895f3cf06809fe95b5060652895c0e5b771fd74ac7ff2b462620` | `100644` |
| `.github/workflows/test.yml` | `worktree` | `72924b23d3e044d78e6e5e8b1f4be329758c8b190b57387f76ba25ce9d056eb4` | `100644` |
| `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactStoreTests.swift` | `worktree` | `1d39b9b369a124bc604cff44866d01c192d3759fe0c7a37b9ca4e76ed6022de5` | `100644` |
| `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASAsyncXCTestSupport.swift` | `untracked` | `f863784370a6c2c649e3723452a923f0a2f8bb4c447a1fcf1198d9532a3bf92f` | `100644` |
| `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASProviderBoundaryTests.swift` | `worktree` | `74446ac8d2c30cbc9cde1bbddec87cbbf4a8df7d9850dc09491e3e87650e9bce` | `100644` |
| `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSyntheticExecutionReceiptFreezeTests.swift` | `index` | `fbb159a75dbcefcf00f9081bb06d6001cb40cda967e7dd5fd5686beaa87b746c` | `100644` |
| `BehavioralAISubstrate/scripts/build-rust-xcframework.sh` | `index` | `4909f62b2d7a14c8bd977c40eb038d46b2ce96395970b1f19b6312b7e7da051f` | `100755` |
| `BehavioralAISubstrate/scripts/check-ios27-floor.sh` | `worktree` | `618009bb0bdde5a614791c5b44be33c6b35a8a4992a498826c111b757996e037` | `100755` |
| `BehavioralAISubstrate/scripts/test_check_ios27_floor.py` | `worktree` | `adeff8e76f2cbae5a006764e94c713a878486347524d681c3dca1a42a5a11bff` | `100644` |
| `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoEffectFacadeFreezeTests.swift` | `index` | `aae6083dbbfdef97d9b81b180f09ef2c51956acf27666c1fdd90d524794e9a6f` | `100644` |
| `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoProviderBoundaryTests.swift` | `index` | `87f9e29a88655b0957be2062336636ac1538bc872d1d8630a846336d826cf5e5` | `100644` |
| `docs/superpowers/evidence/qinao-owner-corrections/artifact-mesh-retrospective-create-correction-v1.json` | `index` | `1f76f03b44dd9a06c3d15eb4e78d59969b2ae506f0997f6d688a9eac14921da8` | `100644` |
| `docs/superpowers/evidence/qinao-owner-create/artifact-mesh--core.json` | `index` | `1229bb9699254b3df4cc8dc3ee803a0daf192694f6674effb39700ca143c3879` | `100644` |
| `docs/superpowers/evidence/qinao-owner-create/artifact-mesh--schema.json` | `index` | `dbbec0e77d8a19db8ff1d29c7fa144e771400a8ee57d53f31253af134d633044` | `100644` |
| `docs/superpowers/evidence/qinao-owner-create/artifact-mesh--sqlite-store.json` | `index` | `3d345a9b8629be39f77c7b9ac68c544fea2babd07ff70059216a48b4f78d0257` | `100644` |
| `docs/superpowers/evidence/qinao-runtime-w0-baseline-violations.json` | `index` | `12b351a8a408eb92a15efed9fdbad784ce65036dea203738cbd5c69ca05270f4` | `100644` |
| `docs/superpowers/evidence/qinao-silicon-w0-baseline-correction-2026-07-18.json` | `index` | `ce4da39703647d66f0a119290c0518f7ca070c3c9e73193902ce3188af3a0ce6` | `100644` |
| `scripts/check_bas_organ_descriptor_constructors.py` | `worktree` | `ce1604c6bfa7b5a5198cb9ab581fe3a67ee8914e98c47cd1ab09f56718b92736` | `100644` |
| `scripts/check_k4_platform_proof.py` | `worktree` | `248c5e48287c53bf5f3739e9d131ad1612d73ed7237a346686ac98134bc48044` | `100644` |
| `scripts/check_qinao_review_candidate.py` | `untracked` | `b74ccc2673e6960d4ad8ba261ebd4703d1611a8e62eb967febd45b4ccc2df1eb` | `100644` |
| `scripts/check_w0_expected_open_set.py` | `worktree` | `d7204d767d16ad4d55d45264e8dcebb68d0aeffa3a6496fad24410ad9730a1e7` | `100644` |
| `scripts/check_xcode27_toolchain.sh` | `worktree` | `3ab30acac79d762e2655aa3a945b3a75191a7ad30b41f769aa854b8dec772503` | `100644` |
| `scripts/run_nonempty_swift_filter.py` | `worktree` | `501ea323244b271a4b69fc973104d584531d4769e618ec4b41baf8e08fe00e9c` | `100644` |
| `scripts/test_check_bas_organ_descriptor_constructors.py` | `worktree` | `579d46f0ef24001b2113af55a7205d7136ec8dba00224a6786e12be931889a73` | `100644` |
| `scripts/test_check_k4_platform_proof.py` | `worktree` | `585815ea16f6e5ab4ed3e71b782fdd641079cfbb45132c5846ff254d10f11338` | `100644` |
| `scripts/test_check_qinao_review_candidate.py` | `untracked` | `e93c025160e77ff983d54d5bc0264a102c744fcac02e6c124eeb2592c456580f` | `100644` |
| `scripts/test_check_w0_expected_open_set.py` | `worktree` | `324f6a24921c65af43e97659b3a3d5548c6885d1dc97cc27ab7671a803283bab` | `100644` |
| `scripts/test_check_xcode27_toolchain.py` | `worktree` | `b3e698fc494c7cdc12219e20671630c03741f2e78c3047e667122d002c94eb04` | `100644` |
| `scripts/test_qinao_plan_remediation.py` | `worktree` | `f6798ba59e2f2caa0183aaee72a58657e2616df2fb4cd26eda5e8ffe5463f0ec` | `100644` |
| `scripts/test_qinao_review_closure.py` | `untracked` | `ec359a511527484903ac262a1cda6781e58a3fb106e67358480129f1f826b758` | `100644` |
| `scripts/test_run_nonempty_swift_filter.py` | `worktree` | `a166e8c69c37bd4241c521c4e19250c3ef36d1aa03b268d684deb1e1f9b9a024` | `100644` |
| `scripts/test_test_workflow_owner_ledger.py` | `worktree` | `f15fb428e68273fc5a1414ef5a1c2ec9edc02bf1ef74eecc6814c9077540d429` | `100644` |

The workflow, six Swift files, iOS-floor/Rust-XCFramework trio,
`.gitattributes`, four Artifact owner/correction records, and Xcode-toolchain
pair are part of the closure, not optional fixtures. The review checker and
its closure suite require the BAS/Qinao test postimages; the B0-self-contained
W0 open-set program requires the synthetic receipt freeze test and both
boundary suites. The plan-remediation suite directly reads `.gitattributes`
plus all four Artifact owner/correction records. The workflow-owner test requires the
imported workflow to invoke the matching Xcode checker/test bytes. The
preW0 iOS-floor program directly scans the Rust build script, while the W0
actual CLI and its unit suite require the matching floor checker/test bytes.
The K4 checker/test pair is required by W0 candidate parity and regression,
never as a B0 helper. The legacy open-set checker is retained as
non-authoritative parser tooling; its imported test is explicitly migrated in
Task 10. The two sequence-zero receipt JSON files and the superseded
non-series silicon baseline are immutable historical fixtures. B0 never
executes the legacy CLI, and its ten raw transcript dependencies are
deliberately excluded. Bootstrap's
`w0_open_set_v1_exact_set` owns the one active open-set authority, and Task 10
removes the premature legacy CI jobs. Dropping any of the 32 makes a required
preW0/W0 regression, parity check, or protected gate structurally unreachable.

- [ ] **Step 1: Freeze and obtain the external C2 review**

Execute Bootstrap Task 1A Step 7 in full. The proposal contains exactly the
32 table rows with `decision=import`, `destination_batch=C2`, the literal
stratum/SHA-256/mode values above, and rationale
`bootstrap-w0-helper-closure-source-only`. After the mandatory external hold,
run:

```bash
test -z "$(git status --porcelain=v1)"
python3 scripts/qinao_import_review_v1.py --verify-fixed-export C2
```

Expected: exactly one opaque C2 result with 32 rows and one authenticated
immutable reopen receipt. A missing/extra/reordered path, different source
stratum, byte or mode drift, one omit, or a record replayed at another
candidate context is `BLOCKED_IMPORT_REVIEW/IMPORT_REVIEW_ROWSET_MISMATCH`.

- [ ] **Step 2: Materialize and commit only the signed C2 map postimage**

```bash
python3 scripts/capture_qinao_candidate_inventory.py \
  --root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --verify docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json
python3 scripts/qinao_import_review_v1.py --apply-fixed-map-postimage C2
python3 scripts/check_qinao_import_map.py \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
git add docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
test "$(git diff --cached --name-only)" = \
  docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
git diff --cached --check
git commit -m "build(qinao): review fixed c2 helper closure"
python3 scripts/qinao_import_review_v1.py --verify-fixed-export C2
python3 scripts/check_qinao_import_map.py \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
```

The map commit must be the immediate child of the C2 context HEAD and its
diff must contain exactly the map path. The postcommit checker must locate
that unique earliest first-parent introduction and also prove every C1 row
unchanged. No candidate commit may be inserted between context freeze and
this map-only commit.

- [ ] **Step 3: Apply, test, and commit exactly the 32 reviewed bytes**

```bash
test ! -e /private/tmp/qinao-c2-helper-source-import-plan.json
python3 scripts/apply_qinao_import_map.py \
  --candidate-root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --source-root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json \
  --prepare-batch C2 \
  --output-plan /private/tmp/qinao-c2-helper-source-import-plan.json
python3 scripts/apply_qinao_import_map.py \
  --candidate-root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --source-root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json \
  --apply-plan /private/tmp/qinao-c2-helper-source-import-plan.json
```

Decode every `path_b64` from the apply plan and byte-compare its sorted raw
set with the literal table—do not compare display strings. Require exactly
32 stage-0 regular postimages with exactly thirty mode-`100644` and the two
table-declared mode-`100755` scripts, no symlink, no submodule, and no other
staged path. Then run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_bas_organ_descriptor_constructors \
  scripts.test_check_k4_platform_proof \
  scripts.test_check_qinao_review_candidate \
  scripts.test_check_xcode27_toolchain \
  scripts.test_qinao_review_closure \
  scripts.test_run_nonempty_swift_filter \
  scripts.test_test_workflow_owner_ledger
bash BehavioralAISubstrate/scripts/check-ios27-floor.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  BehavioralAISubstrate.scripts.test_check_ios27_floor
python3 scripts/check_qinao_review_candidate.py --root .
git diff --cached --check
git commit -m "build(qinao): import fixed c2 helper closure"
test -z "$(git status --porcelain=v1)"
```

Two imported test modules deliberately do not execute inside the exact-import
commit. `scripts/test_check_w0_expected_open_set.py` still describes the
legacy documents/workflow that Authority Task 2 corrected; its first required
GREEN is Task 10, after that task atomically migrates it to the B0-owned
open-set contract. `scripts/test_qinao_plan_remediation.py` contains two stale
spelling/diagram assertions and is migrated immediately in Step 4 below.
All other imported C2 regression modules run above. Neither deferral
authorizes an imported checker as a gate.

Before the commit, byte-compare `git diff --cached --name-only -z` with the
literal 32-path NUL set and fail on any mismatch. Afterward, reverify C1 and
C2 exports and require:

```text
source_import_review_audit_root_digest ==
  compile_review_audit_root((
    verify_fixed_c1_import_review_export(),
    verify_fixed_c2_import_review_export(),
  ))
```

The compiler canonicalizes by record digest; caller order is not authority.
The exact same sorted C1+C2 root must later appear in the preW0 lease, result
bundle, Sw receipt, admission intent, finalized attestation, and
`AdmittedWaveV1`.

- [ ] **Step 4: Harden the imported runner and migrate stale assertions**

Modify exactly `scripts/run_nonempty_swift_filter.py`,
`scripts/test_run_nonempty_swift_filter.py`, and
`scripts/test_qinao_plan_remediation.py`.

First harden the Swift runner without broadening its CLI or suite selectors:

1. Parse the `Module.Suite/` prefix and base method as identifier components,
   then preserve the complete Swift Testing argument-label suffix such as
   `()` or `(value:)` in the exact discovered identifier. An unrecognized
   nonblank identifier belonging to a selected suite is a typed failure,
   never a silently dropped row.
2. Keep XCTest identifiers as one escaped, anchored regex batch. Run every
   Swift Testing identifier, including parameterized identifiers, as its own
   exact raw filter batch. Never turn a mixed XCTest/Swift Testing selection
   into one unescaped raw union.
3. Require every batch to execute a positive exact count and require the sum
   of batch executions to equal the selected listing cardinality. Propagate
   the first test failure only after preserving the nonempty listing
   evidence; a count mismatch remains failure.
4. Add regressions for preserving `test(value:)`, rejecting an unsupported
   selected-suite suffix instead of dropping it, mixed XCTest/Swift Testing
   batch partitioning, regex-metacharacter non-broadening, and per-batch plus
   aggregate executed-count mismatch.

Then preserve every unrelated plan-remediation test and assertion byte. Only inside
`test_control_ring_swift_case_has_one_canonical_wire_spelling` and
`test_agent_context_addendum_binds_canonical_compiler_and_issue_digest`,
split the old shared mapping into the exact post-Task-2 sentences:
Contracts contains
`Swift case needsConfirmation has the canonical encoded spelling needs-confirmation`,
while the addendum contains
`Swift case needsConfirmation has the existing canonical encoded spelling needs-confirmation`
(with the existing Markdown backticks preserved). Assert the architecture
terminal block contains `degraded-with-coverage`, `needs-confirmation`, and
`indeterminate-needs-reconciliation` and no underscore alias; assert the
addendum contains all six hyphenated wire values listed in Task 2 Step 2 and
none of their underscore aliases. Preserve the separate QRM-060 raw imported
finding assertion containing `needs_confirmation` byte-for-byte: that token
describes immutable C1 source content and is removed only by Task 9's
raw-source migration.
Replace the stale diagram assertion
`→ L3 BASContextCompiler (context-budget allocation + State Compiler phase)`
with the controlled text's exact
`→ L3 BASContextCompiler finalization (context-budget allocation + State Compiler phase)`.
The test must continue rejecting the old unbound
`→ L3 context budget + State Compiler` form.

Run and commit only that compatibility migration:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_run_nonempty_swift_filter \
  scripts.test_qinao_plan_remediation
git add \
  scripts/run_nonempty_swift_filter.py \
  scripts/test_run_nonempty_swift_filter.py \
  scripts/test_qinao_plan_remediation.py
python3 -c 'import subprocess; actual=subprocess.check_output(["git","diff","--cached","--name-only"],text=True).splitlines(); expected=["scripts/run_nonempty_swift_filter.py","scripts/test_qinao_plan_remediation.py","scripts/test_run_nonempty_swift_filter.py"]; assert actual==expected, (actual,expected)'
git diff --cached --check
git commit -m "test(qinao): harden imported helper regressions"
test -z "$(git status --porcelain=v1)"
```

Expected: all discovered tests pass with zero skip. The commit has exactly
three paths and its parent is the exact 32-path C2 import commit. Reverify the
fixed C2 export and require the import commit's 32 raw postimages still match
the signed plan; the compatibility child is not relabeled as a reviewed C2
source postimage. C2's imported evaluators remain candidate bytes until their
exact admitted-predecessor versions are pinned in B0; this task does not let
them judge or activate themselves.

---

### Task 3: Build the Authority-to-Bootstrap Draft Handoff

**Files:**
- Create: `scripts/build_qinao_authority_draft.py`
- Create: `scripts/test_build_qinao_authority_draft.py`
- Create: `docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json`

**Interfaces:**
- Consumes: indexed 7+4 bytes, the exact schema-v1 transitional raw Owner
  Ledger and its already-installed catalog rows, the
  Preparation-Z-frozen bootstrap contract schema, and exact indexed
  `scripts/qinao_gate_modules/v0/catalog-v1.json`.
- Produces: the exact handoff-A object; it carries no bootstrap projection or candidate/evidence result.

- [ ] **Step 1: Write RED tests for the closed handoff grammar**

Add tests that reject:

```text
document_digests cardinality != 11
duplicate document_id or path
non-7+4 membership
worktree/index byte drift
symlink, executable, or non-stage-0 document
Ledger schema/status other than exact schema-v1 transitional Input-A state
catalog row missing/extra/reordered or different from reciprocal 7+4 refs
missing/extra top-level field
bootstrap projection or attestation field
candidate commit/tree field
gate result field
noncanonical JSON
digest mismatch
```

The positive fixture asserts the exact top-level key set:

```python
EXPECTED_FIELDS = {
    "schema_version",
    "authority_bundle_digest",
    "owner_ledger_draft_digest",
    "controlled_contract_catalog_digest",
    "document_digests",
    "wave_admission_contract_digest",
    "required_gate_contracts_digest",
}
```

The test module uses immutable fixture/index inputs. It does not require the
historical Input A to equal a later post-ceremony Ledger. Pre-ceremony
`--compare` proves current equality in Step 4; after Output B, the bootstrap
export verifier proves the draft's immutable ceremony binding. A separate
read-only `--compare-authority-only INPUT_A` mode accepts the later schema-v2
Ledger, but requires its contained catalog digest plus the exact ordered
11-document raw digest map and authority-bundle digest to equal immutable
Input A. Tests prove this mode ignores only the expected raw Ledger-blob
change, rejects any document/catalog drift, and writes no file.

Create an importable `build_authority_draft`/CLI typed RED seam in this step.
It exposes the final argument surface and fails closed with
`qinao.authority-draft.unimplemented`.

- [ ] **Step 2: Run RED**

Run:

```bash
python3 -m unittest -v \
  scripts.test_build_qinao_authority_draft.QinaoAuthorityDraftTests
```

Expected: tests discover, fixture construction succeeds, and the positive
case fails only on `qinao.authority-draft.unimplemented`.

- [ ] **Step 3: Implement canonical digest construction**

Add these exact functions:

```python
def canonical_json(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")

def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def framed_digest(domain: bytes, rows: list[bytes]) -> str:
    framed = bytearray(domain)
    framed.extend(len(rows).to_bytes(8, "big"))
    for row in rows:
        framed.extend(len(row).to_bytes(8, "big"))
        framed.extend(row)
    return sha256(bytes(framed))

def authority_bundle_digest(rows: list[dict[str, str]]) -> str:
    return framed_digest(
        b"QINAO-AUTHORITY-BUNDLE-V1\0",
        [canonical_json(row) for row in rows],
    )
```

`document_digests` comes from `CONTROLLED_DOCUMENTS + GOVERNING_ADDENDA`
and indexed raw bytes. Require the indexed Ledger to remain
`schema_version = 1`, `status = transitional_unadmitted_input_a`, and to
contain the exact reciprocal catalog installed by Task 2.
`owner_ledger_draft_digest` is raw SHA-256 of that complete indexed Ledger
blob. `controlled_contract_catalog_digest` is computed from the rows inside
that same blob as
`SHA256("QINAO-CONTROLLED-CONTRACT-CATALOG-V1\0" ||
uint64be(rowCount) || each uint64be(rowLength) || canonicalRowBytes)`.
It is not read from a second catalog, synthesized from Task 4, or regenerated
after Output B. The two admission digests use the exact indexed
contract/canonical gate-catalog bytes returned by the bootstrap sibling's
preparation interface.

The output selector is a closed mutually exclusive group:
`--output PATH`, `--compare PATH`, or `--compare-authority-only INPUT_A`.
The first two require the exact transitional schema-v1 Ledger.
`--compare-authority-only` requires schema v2, validates Input A's schema and
canonical bytes, performs only the three equality checks above, and cannot
write.

- [ ] **Step 4: Generate to a temporary path and compare before install**

Run:

```bash
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
python3 scripts/build_qinao_authority_draft.py \
  --root . \
  --ledger docs/superpowers/specs/qinao-owner-ledger-v1.json \
  --wave-admission-schema docs/superpowers/specs/qinao-wave-admission-bootstrap-v1.schema.json \
  --gate-contract-catalog scripts/qinao_gate_modules/v0/catalog-v1.json \
  --output "$tmp/qinao-authority-convergence-draft-v1.json"
test ! -e docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json
install -m 0644 \
  "$tmp/qinao-authority-convergence-draft-v1.json" \
  docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json
python3 scripts/build_qinao_authority_draft.py \
  --root . \
  --ledger docs/superpowers/specs/qinao-owner-ledger-v1.json \
  --wave-admission-schema docs/superpowers/specs/qinao-wave-admission-bootstrap-v1.schema.json \
  --gate-contract-catalog scripts/qinao_gate_modules/v0/catalog-v1.json \
  --compare docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json
```

Expected on first generation: a canonical file ending with one LF. Expected
after the exclusive first install:
`qinao-authority-draft: PASS documents=11 controlled=7 addenda=4`. The
compare mode never overwrites the expected file.

- [ ] **Step 5: Run GREEN and commit the handoff-A preparation slice**

Run:

```bash
python3 -m unittest -v scripts.test_build_qinao_authority_draft
git add \
  scripts/build_qinao_authority_draft.py \
  scripts/test_build_qinao_authority_draft.py \
  docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json
git commit -m "build(qinao): emit authority bootstrap handoff"
```

Expected: all tests pass; commit contains exactly three paths.

- [ ] **Step 6: Pause for bootstrap handoff B**

Supply the indexed blob digest of
`qinao-authority-convergence-draft-v1.json` to the bootstrap sibling plan.
Do not modify/substitute the already frozen gate catalog/schema, or synthesize
`B0`, a concrete profile, repository identity, OIDC identity, protection
digest, or external attestation. Resume only after that plan returns
authenticated handoff B.

---

### Task 4: Complete Owner Ledger Schema v2, Reciprocal Grammar, and Append-Only Lifecycle

**Files:**
- Modify: `docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify: `scripts/check_qinao_owner_ledger.py`
- Modify: `scripts/test_check_qinao_owner_ledger.py`
- Create: `scripts/qinao_owner_ledger_v2.py`
- Create: `scripts/test_qinao_owner_ledger_v2.py`

**Interfaces:**
- Consumes: authenticated bootstrap handoff B, indexed 7+4 authority bytes, `BASEBrainSchemaGovernanceRegistry`, independently derived declared-contract and production-reachable sets, and the prior finalized Ledger for W0-W6 transitions.
- Consumes additionally: immutable Input A and its exact schema-v1
  transitional raw-Ledger/catalog digests.
- Produces: one valid Ledger v2 whose catalog row bytes are identical to
  Input A, `validate_v2_ledger -> list[str]`,
  `expected_contract_sets`, `active_shipping_profiles`, and a
  schema-v2 dispatch in the existing Owner-Ledger CLI.

- [ ] **Step 1: Preserve and repair the existing 102-test baseline**

First repair the current final-target versus parent-component symlink diagnostic in `validate_schema_v2_raw_document_digest`:

```text
candidate = root / document_path
if candidate.is_symlink():
    errors.append(f"{label} target must not be a symlink: {document_path}")
    return errors

path_component = root
for component in PurePosixPath(document_path).parts[:-1]:
    path_component /= component
    if path_component.is_symlink():
        errors.append(
            f"{label} target path must not contain symlink components: "
            f"{document_path}"
        )
        return errors
```

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_owner_ledger.QinaoOwnerLedgerCLITests
```

Expected: 102 tests discovered and all pass before adding new REDs, including
the exact transitional schema-v1 catalog case from Task 2.

- [ ] **Step 2: Write RED tests for every v2 machine section**

Add these test groups to `scripts/test_qinao_owner_ledger_v2.py`:

```python
DOCUMENT_TESTS = (
    "seven controlled rows have exact fields and candidate-byte digests",
    "four addendum rows have exact fields and candidate-byte digests",
    "document IDs and paths are globally unique across 7+4",
    "correction, companion, and execution plans are excluded from 7+4",
)

CATALOG_TESTS = (
    "catalog rows have exactly eleven fields and byte-equal Input-A projection",
    "row identity is exactly contract_id plus version",
    "rows and authority refs are uniquely sorted",
    "every owner_id resolves one incumbent owner",
    "every declaration path is normalized",
    "every authority ref resolves one 7+4 document",
    "ledger refs equal document refs as exact quadruples",
    "every ref has exactly one required-term anchor",
    "the referenced row union equals the complete catalog",
)

LIFECYCLE_TESTS = (
    "baseline freezes all non-status bytes",
    "same-version identity mutation fails",
    "authority-ref expansion or shrink fails",
    "only closed status edges pass",
    "two-hop transition in one seal fails",
    "absent-row insertion follows the closed protocol",
    "retired insertion fails",
    "replacement activation and prior retirement are atomic",
)

EQUALITY_TESTS = (
    "actual declared equals expected introduced through derived wave",
    "actual production reachable equals expected active through derived wave",
    "future declaration appearing early fails",
    "due declaration missing fails",
    "declared inert reachability fails",
    "approved missing cannot satisfy a due introduction",
)

PROFILE_TESTS = (
    "release profile rows have the exact field set",
    "profile non-status bytes are append-only",
    "active family has exactly one active version",
    "future family has zero active versions",
    "selected release evidence cannot select a profile",
    "Package.resolved roots are explicit",
)

RECOVERY_TESTS = (
    "recovery profile has exact fields and closed two-facet product",
    "durable store requires owner-private paths and stateless forbids them",
    "external effect is query-reconcile-only with no shared registry",
)

CREATE_GATE_TESTS = (
    "candidate authority discovery is derived from indexed predecessor delta",
    "new production owner or authority without exact M admission fails",
    "missing or renamed discovery anchor fails instead of yielding zero",
    "comments strings and documentation names are not authority candidates",
)

ADMISSION_TESTS = (
    "wave_admission_v1 byte matches projection with policy but no attestation instance digest or status",
    "verification toolchain profile is non-shipping and requires fresh host quote beyond labels",
    "verification toolchain profile cannot populate selected release",
    "storage profile contains every required field and no credential",
    "gate program_by_wave maps and execution DAG are exact for each wave",
    "architecture closure is the sole final phase and has no self dependency",
    "wave cannot come from CLI environment branch or manifest",
    "force update and deletion flags are literal true",
)
```

Every string above maps to one concrete `test_...` method; the test module
asserts its discovered method-name set equals the derived 48-case set.
Create the importable `qinao_owner_ledger_v2.py` final-signature stub in this
same RED step; every new entry point returns
`qinao.owner-ledger-v2.unimplemented`.

- [ ] **Step 3: Run the new RED suite**

Run:

```bash
python3 -m unittest -v scripts.test_qinao_owner_ledger_v2
```

Expected: 48 tests discovered and fail on the specific asserted predicate or
`qinao.owner-ledger-v2.unimplemented`; the existing 102-test module remains
green. No new-test import or fixture is missing.

- [ ] **Step 4: Freeze the exact v2 field sets**

Add to `scripts/qinao_owner_ledger_v2.py`:

```python
V2_ADDED_TOP_LEVEL_FIELDS = {
    "governing_addenda_v1",
    "controlled_contract_catalog_v1",
    "shipping_release_profiles_v1",
    "wave_admission_v1",
}

CONTROLLED_DOCUMENT_FIELDS = {
    "document_id", "path", "sha256", "required_terms", "forbidden_terms"
}
GOVERNING_ADDENDUM_FIELDS = {"document_id", "path", "sha256"}

CONTRACT_FIELDS = {
    "contract_id",
    "version",
    "owner_id",
    "declaration_path",
    "declaration_symbol",
    "registry_id",
    "status",
    "introduction_wave",
    "activation_wave",
    "schema_only_prelude_allowed",
    "authority_refs",
}
AUTHORITY_REF_FIELDS = {"document_id", "required_term_id"}

SHIPPING_PROFILE_FIELDS = {
    "profile_id",
    "version",
    "status",
    "introduction_wave",
    "activation_wave",
    "project_workspace_path",
    "build_targets",
    "configuration",
    "sdk",
    "architectures",
    "deployment_target",
    "compilation_conditions",
    "feature_flags",
    "entitlement_template_paths",
    "package_resolution_roots",
}
BUILD_TARGET_FIELDS = {"scheme", "product"}

WAVES = ("preW0", "W0", "W1", "W2", "W3", "W4", "W5", "W6")
CONTRACT_STATUSES = {
    "planned", "approved_missing", "declared_inert", "active", "retired"
}
PROFILE_STATUSES = {"planned", "approved_missing", "active", "retired"}
```

The schema-v2 root key set is exactly the original pre-transitional
schema-v1 root key set union `V2_ADDED_TOP_LEVEL_FIELDS`; no incumbent root
field may be deleted, renamed, or implicitly accepted as unknown.
`controlled_contract_catalog_v1` already exists in the transitional Input-A
blob, so migration retains that exact canonical array rather than adding or
regenerating it. `schema_version` changes value from integer `1` to integer
`2`, transitional `status` returns to
`planning_contract_approved`, and stable `ledger_id` remains unchanged.
`version` matches `[0-9]+(?:\.[0-9]+){0,2}`. Stable IDs match
`[a-z0-9][a-z0-9._-]{0,127}`. Every object rejects unknown keys and duplicate
JSON keys; booleans are not accepted as integers.

Before the first mutation, require raw SHA-256 of the indexed transitional
Ledger to equal Input A's `owner_ledger_draft_digest`; extract and
canonicalize its catalog rows once, and require their domain-separated digest
to equal Input A's `controlled_contract_catalog_digest`. After every
schema-v2 edit and again before commit, require the catalog array to be
value- and canonical-byte-identical to that frozen projection and recompute
the same digest. A missing Input A, stale raw Ledger, or one-byte catalog
change is a ceremony restart, never a regenerate-and-continue path.

- [ ] **Step 5: Add the exact 29-owner recovery mapping**

Each schema-v2 owner card gains exactly one field:

```json
{
  "recovery_profile_v1": {
    "state_facet": "stateless|ephemeralDrop|rebuildableProjection|durableStore",
    "boundary_facet": "none|externalEffect",
    "state_rule_id": "stable-rule-id",
    "boundary_rule_id": "stable-rule-id-or-none",
    "owner_private_paths": ["workspace-relative-path"],
    "external_floor_or_source": "closed-description",
    "unknown_boundary_disposition": "notApplicable|queryReconcileOnly"
  }
}
```

The exact field set is:

```python
RECOVERY_PROFILE_FIELDS = {
    "state_facet",
    "boundary_facet",
    "state_rule_id",
    "boundary_rule_id",
    "owner_private_paths",
    "external_floor_or_source",
    "unknown_boundary_disposition",
}
```

Validation rules are exact:

```python
def validate_recovery_profile(profile: dict) -> list[str]:
    errors: list[str] = []
    state = profile.get("state_facet")
    boundary = profile.get("boundary_facet")
    paths = profile.get("owner_private_paths")
    if set(profile) != RECOVERY_PROFILE_FIELDS:
        errors.append("recovery_profile_v1 fields are not exact")
    if state not in {"stateless", "ephemeralDrop", "rebuildableProjection", "durableStore"}:
        errors.append("invalid recovery state_facet")
    if boundary not in {"none", "externalEffect"}:
        errors.append("invalid recovery boundary_facet")
    if not isinstance(paths, list) or paths != sorted(set(paths)):
        errors.append("owner_private_paths must be a sorted unique array")
    if state == "stateless" and paths:
        errors.append("stateless owner cannot declare mutable recovery paths")
    if state == "durableStore" and not paths:
        errors.append("durableStore owner requires owner-private durable paths")
    if boundary == "externalEffect":
        if profile.get("unknown_boundary_disposition") != "queryReconcileOnly":
            errors.append("externalEffect must be queryReconcileOnly")
    elif profile.get("unknown_boundary_disposition") != "notApplicable":
        errors.append("boundary none must be notApplicable")
    return errors
```

No recovery profile changes `authority_owner`, `mutable_state_owner`, `storage_owner`, or `recovery_owner`. The mapping documents existing responsibility; it does not create a runtime wire or owner.

- [ ] **Step 6: Implement exact reciprocal document/catalog equality**

Build Ledger quadruples:

```python
ledger_refs = {
    (
        row["contract_id"],
        row["version"],
        ref["document_id"],
        ref["required_term_id"],
    )
    for row in catalog
    for ref in row["authority_refs"]
}
```

Build document quadruples by mapping the containing indexed path to its immutable `document_id`, parsing its one canonical reference block, and requiring the exact anchor once:

```python
document_refs = {
    (contract_id, version, document_id, required_term_id)
    for document_id, path in document_map.items()
    for contract_id, version, required_term_id in parse_reference_block(
        indexed_text(root, path), path
    )
}
```

Then require:

```python
if ledger_refs != document_refs:
    errors.append(
        "ledger/document contract reference quadruples differ: "
        f"missing={sorted(ledger_refs - document_refs)!r} "
        f"extra={sorted(document_refs - ledger_refs)!r}"
    )
if {
    (contract_id, version) for contract_id, version, _, _ in ledger_refs
} != {
    (row["contract_id"], row["version"]) for row in catalog
}:
    errors.append("document reference union must equal the complete contract catalog")
```

Never use a loose substring scan for this equality.

- [ ] **Step 7: Implement closed lifecycle transitions and absent-row insertion**

Add:

```python
CONTRACT_TRANSITIONS = {
    ("planned", "approved_missing"),
    ("planned", "declared_inert"),
    ("approved_missing", "declared_inert"),
    ("planned", "active"),
    ("approved_missing", "active"),
    ("declared_inert", "active"),
    ("active", "retired"),
}
PROFILE_TRANSITIONS = {
    ("planned", "approved_missing"),
    ("planned", "active"),
    ("approved_missing", "active"),
    ("active", "retired"),
}

def immutable_projection(row: dict) -> dict:
    return {key: value for key, value in row.items() if key != "status"}
```

For an incumbent key, `immutable_projection(before) == immutable_projection(after)` is mandatory. A status change must be one transition edge and obey its frozen wave predicate.

For an absent contract row at derived `W`:

```python
def legal_contract_insertion(row: dict, wave: str) -> bool:
    intro = row["introduction_wave"]
    activation = row["activation_wave"]
    status = row["status"]
    if wave_index(intro) > wave_index(wave):
        return status == "planned"
    if intro != wave:
        return False
    if status == "approved_missing":
        return activation == "never" or wave_index(activation) > wave_index(wave)
    if status == "declared_inert":
        return (
            row["schema_only_prelude_allowed"] is True
            and activation != "never"
            and wave_index(activation) > wave_index(wave)
        )
    if status == "active":
        return activation == wave
    return False
```

Profiles use the same logic without `declared_inert` or `activation = never`. `retired` is never an insertion state.

- [ ] **Step 8: Derive cumulative declared and reachable exact sets**

Add:

```python
def expected_introduced_through(catalog: list[dict], wave: str) -> set[tuple[str, str]]:
    return {
        (row["contract_id"], row["version"])
        for row in catalog
        if wave_index(row["introduction_wave"]) <= wave_index(wave)
    }

def expected_active_through(catalog: list[dict], wave: str) -> set[tuple[str, str]]:
    return {
        (row["contract_id"], row["version"])
        for row in catalog
        if row["activation_wave"] != "never"
        and wave_index(row["activation_wave"]) <= wave_index(wave)
        and row["status"] == "active"
    }
```

`actual_declared` is independently derived from:

1. exact entries in `BASEBrainSchemaGovernanceRegistry`;
2. release-condition-aware Swift declarations for governed payloads, receipts, permits, manifests, and owner wires; and
3. canonical version/tag constants.

`actual_production_reachable` is independently derived by Task 7's selected-product graph. Neither manifest may carry expected IDs, status, owner, or wave.

Require:

```python
actual_declared == expected_introduced_through(catalog, derived_wave)
actual_production_reachable == expected_active_through(catalog, derived_wave)
```

A `declared_inert` row must be in `actual_declared` and absent from `actual_production_reachable`. An `approved_missing` row due at the current introduction wave blocks.

- [ ] **Step 9: Freeze shipping profiles without caller selection**

At preW0, add only reviewed future shipping families whose actual production cutover occurs in W6. Each row is `planned`, `introduction_wave = W6`, `activation_wave = W6`; therefore preW0 has zero active shipping profiles and makes no production-release claim.

The exact initial families and frozen selection fields are:

| `profile_id` / version | `project_workspace_path` | exact `build_targets` | exact `package_resolution_roots` |
|---|---|---|---|
| `qinao.samplehost-ios` / `1.0.0` | `SampleHost/Package.swift` | `[{"scheme":"SampleHost","product":"SampleHost"}]` | `["BehavioralAISubstrate/Package.swift","SampleHost/Package.swift"]` |
| `qinao.runtime-sdk-ios` / `1.0.0` | `QinaoRuntimeSDK/Package.swift` | `[{"scheme":"QinaoRuntime","product":"QinaoRuntime"}]` | `["BehavioralAISubstrate/Package.swift","QinaoRuntimeSDK/Package.swift"]` |
| `qinao.behavioral-substrate-ios` / `1.0.0` | `BehavioralAISubstrate/Package.swift` | `[{"scheme":"BASHostKit","product":"BASHostKit"}]` | `["BehavioralAISubstrate/Package.swift"]` |

Each row uses `configuration = Release`, `sdk = iphoneos`,
`architectures = ["arm64"]`, `deployment_target = "27.0"`,
`compilation_conditions = []`, `feature_flags = []`, and
`entitlement_template_paths = []`. The W6 production-cutover amendment must
append a new profile version rather than mutate any of those frozen bytes if
its reviewed build differs. `BehavioralAISubstrate/DeviceTestApp/project.yml`
and
`BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj/project.pbxproj`
are classified as lab/evidence roots in Task 7, never silently inserted into
shipping profiles.

The checker derives:

```python
def active_shipping_profiles(rows: list[dict], wave: str) -> list[dict]:
    profiles = [
        row for row in rows
        if row["status"] == "active"
        and wave_index(row["activation_wave"]) <= wave_index(wave)
    ]
    by_family: dict[str, list[dict]] = collections.defaultdict(list)
    for row in profiles:
        by_family[row["profile_id"]].append(row)
    if any(len(versions) != 1 for versions in by_family.values()):
        raise ValidationError("each required active profile family needs one version")
    return sorted(profiles, key=lambda row: (row["profile_id"], row["version"]))
```

No selected-release result, report, CLI flag, or environment variable can add/remove a profile.

- [ ] **Step 10: Freeze the non-shipping verification and storage profiles**

`wave_admission_v1.verification_toolchain_profile` has exactly:

```python
VERIFICATION_TOOLCHAIN_PROFILE_FIELDS = {
    "xcode_version",
    "xcode_build_version",
    "iphoneos_sdk_version",
    "runner_image_identity",
    "runner_attestation_identity_digest",
    "runner_isolation_profile_digest",
    "toolchain_probe_contract_digest",
    "profile_digest",
}
```

The authenticated ceremony observes these values and requires Xcode major 27
plus an iOS 27 SDK; the plan never predicts a build number. The workflow is
routed only to the protected runner group and
`qinao-xcode27-arm64-v1` label, but labels are scheduling hints—not proof of
OS, architecture, image, or isolation. Before the Xcode gate runs, the
service verifies a fresh quote under
`runner_attestation_identity_digest` that binds Apple silicon, Xcode 27, the
iOS 27 SDK, `runner_image_identity`, and the controller/evaluator isolation
profile named by `runner_isolation_profile_digest`. Quote absence, staleness,
label/quote mismatch, or controller/evaluator co-tenancy fails. This profile
selects only the preW0 verifier environment. It is not a
`shipping_release_profiles_v1` row, never appears in
`selected_release_build_identities`, and cannot change preW0's derived active
shipping-profile count of zero.

`wave_admission_v1.build_evidence_storage_profile` has exactly:

```python
BUILD_EVIDENCE_STORAGE_PROFILE_FIELDS = {
    "provider_repository_identity",
    "region_endpoint_class",
    "client_aead_algorithm",
    "chunking_algorithm",
    "content_address_algorithm",
    "kms_key_custody_principal",
    "kms_key_epoch",
    "no_replace_versioning_policy",
    "write_principal",
    "read_grant_issuer",
    "retention_policy",
    "destruction_policy",
    "audit_transparency_root",
    "multipart_resume_identity",
    "reopen_availability_protocol",
}
```

Require each value to be the exact non-empty closed stable string/object
defined by the bootstrap schema, `kms_key_epoch` to be a positive bounded
integer, `no_replace_versioning_policy` to encode both no-replace and
versioning, and no key name/value containing `secret`, `token`, `password`,
`credential`, private key, raw credential-bearing endpoint, or key material.
Both profiles byte-match authenticated handoff B. The complete
`required_gates_by_wave` and `execution_phases_by_wave` maps also byte-match
handoff B; the latter is a closed acyclic partition, not a candidate-selected
ordering. For every required gate and wave, resolve exactly one literal
`program_by_wave[derived_wave]` into one closed `programs` row and reject an
unknown, duplicate, missing, or unused program. The six staged domain gates
must byte-match the sibling's master-derived wave slices: every current-wave
program proves all prior slices present and every later source/symbol/registry/
test identity absent. A test introduced in a later wave is never passed to a
filter or compiler in an earlier program. Artifact Mesh and K4 physical proof
may be reused only when the contract's literal sensitive-path set is
byte-identical to the predecessor; any sensitive-path delta deterministically
requires a fresh current-payload proof. No candidate value selects reuse.

- [ ] **Step 11: Remove v2 scaffold blockers only after all validators run**

Delete `SCHEMA_V2_PRE_ADOPTION_BLOCKERS` only when `validate_ledger` calls, in order:

```python
errors.extend(validate_schema_v2_documents(data, root))
errors.extend(validate_schema_v2_contract_catalog(data, root))
errors.extend(validate_schema_v2_reciprocal_refs(data, root))
errors.extend(validate_schema_v2_recovery_profiles(data))
errors.extend(validate_schema_v2_shipping_profiles(data, predecessor, derived_wave))
errors.extend(validate_schema_v2_wave_admission(data, authenticated_bootstrap))
errors.extend(validate_schema_v2_lifecycle(data, predecessor, derived_wave))
errors.extend(validate_schema_v2_candidate_authority_delta(
    data, root, predecessor, production_graph
))
errors.extend(validate_schema_v2_cumulative_sets(
    data, derived_wave, actual_declared, actual_production_reachable
))
```

In the same atomic edit, remove Task 2's schema-v1 transitional dispatch and
its transient status allowance. Preserve its regression fixture only as a
read-only predecessor/Input-A fixture proving byte-identical catalog
migration. The final checker must reject a live schema-v1 transitional Ledger
and must reject schema v2 if its catalog differs from that fixture/Input-A
digest. Update the one transitional test so its positive branch exercises
only the private `validate_transitional_input_a_predecessor` migration
reader, while a subtest proves the public `validate_ledger` dispatch rejects
that same schema-v1 value after migration; its method count remains one.

The dispatcher must not accept `shipping_release_profiles_v1` or
`wave_admission_v1` without semantic validation. Its exact new CLI surface is:

```python
parser.add_argument(
    "--bootstrap",
    required=True,
    help="authenticated external wave-admission projection",
)
parser.add_argument(
    "--declared-contracts",
    required=True,
    help="independently derived actual declared-contract set",
)
parser.add_argument(
    "--production-reachability",
    required=True,
    help="independently derived actual production-reachable set",
)
```

The CLI has no `--candidate-manifest`. It derives the exact predecessor from
the authenticated bootstrap/prior-finalized lineage, diffs indexed Git trees,
and runs AST/graph-aware authority-shaped declaration discovery over every
changed regular source. Every new production owner/authority/store/registry/
manager/writer-shaped declaration must match one exact schema-frozen
classification-M admission row; missing/renamed scan anchors are fatal. At
preW0 the authorized M set is empty, so a newly added
`BASStateCommitStore`-shaped production declaration is discovered and fails;
legitimate comments, strings, documentation, E/A templates, and test/lab-only
declarations do not count. Thus `candidates=0` is a derived checked result,
not an unfed gate.

- [ ] **Step 12: Run all Ledger tests**

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_owner_ledger \
  scripts.test_qinao_owner_ledger_v2
```

Expected: 150 tests discovered, 150 passed.

- [ ] **Step 13: Commit only the Ledger-v2 preparation slice**

Run:

```bash
git add \
  docs/superpowers/specs/qinao-owner-ledger-v1.json \
  scripts/check_qinao_owner_ledger.py \
  scripts/test_check_qinao_owner_ledger.py \
  scripts/qinao_owner_ledger_v2.py \
  scripts/test_qinao_owner_ledger_v2.py
git commit -m "feat(qinao): close owner ledger schema v2"
```

Expected: one preparation commit with exactly five paths.

---

### Task 5: Freeze Content-Intake and Seven Authorized-Input/Remote E/A Identity Templates

**Files:**
- Create: `docs/superpowers/specs/qinao-extension-slice-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-schema-fixture-manifest-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-extension-identity-catalog-v1.json`
- Create: `scripts/check_qinao_ea_extensions.py`
- Create: `scripts/test_check_qinao_ea_extensions.py`

**Interfaces:**
- Consumes: existing Owner Ledger owner IDs and controlled work-package sequence.
- Produces: schemas, parser, exact future identity/path/symbol/responsibility sets, and manifest templates only. It produces no current-wave E/A result and no production source.

The generic future-manifest path convention is:

```python
manifest_path = (
    Path("docs/superpowers/evidence/qinao-ea-extensions")
    / derived_wave
    / f"{manifest_id}.json"
)
```

`derived_wave` must be one of `W0,W1,W2,W3,W4,W5,W6`, and `manifest_id`
must match `[a-z0-9][a-z0-9._-]{0,127}` before joining the path.

The Artifact Mesh sibling plan consumes the same schema/checker and uses the
fixed path:

```text
docs/superpowers/evidence/qinao-ea-extensions/W1/artifact-mesh-task0.json
```

The checker API is exactly four required options:

```python
parser.add_argument("--root", type=Path, required=True)
parser.add_argument("--manifest", type=Path, required=True)
parser.add_argument("--payload-commit", required=True)
parser.add_argument("--payload-tree", required=True)
```

It has no `--wave`. For a realized manifest it derives the wave from the
protected predecessor/payload lineage and compares `workWave`; for the
identity-catalog form it validates future templates and forbids result fields.

- [ ] **Step 1: Write RED tests for exact ExtensionSlice grammar**

The outer manifest is exactly:

```json
{
  "schema_version": 1,
  "manifest_id": "stable-id",
  "manifest_kind": "ea_extensions",
  "workWave": "W1",
  "slices": []
}
```

Every non-empty future-wave manifest slice is exactly:

```json
{
  "sliceID": "stable-id",
  "existingOwnerID": "owner.id",
  "classification": "E",
  "introductionWave": "W1",
  "workWave": "W1",
  "path": "workspace/relative/path",
  "symbol": "Exact.Symbol",
  "responsibilityID": "stable-responsibility-id",
  "wireChange": true,
  "prerequisiteIDs": ["stable-prerequisite-id"],
  "currentFixtureIDs": ["stable-fixture-id"],
  "backwardFixture": {
    "disposition": "notApplicable",
    "fixtureIDs": [],
    "historyProofID": "stable-history-proof-id"
  },
  "futureFixtureIDs": ["stable-fixture-id"],
  "storageProofRuleID": "stable-rule-id",
  "replayProofRuleID": "stable-rule-id",
  "recoveryProofRuleID": "stable-rule-id",
  "ownerBefore": "owner.id",
  "ownerAfter": "owner.id"
}
```

Tests reject empty present manifests, M classification, zero/multiple owners, unknown owner, multiple path/symbol seams in one slice, `introductionWave`/`workWave` drift, cross-wave aggregation, missing prerequisite, first-wire fake backward fixture, candidate-selected wave, or owner movement.

Create the final CLI/parser signatures plus syntactically valid stub
schemas/catalog in this RED step. They fail closed with
`qinao.ea-extensions.unimplemented`.

- [ ] **Step 2: Run RED**

Run:

```bash
python3 -m unittest -v scripts.test_check_qinao_ea_extensions
```

Expected: tests discover and fail only on
`qinao.ea-extensions.unimplemented`; no schema, parser, catalog, fixture, or
import is absent.

- [ ] **Step 3: Freeze the content-intake identity set**

The catalog contains these exact five future manifest templates:

| Manifest ID | Wave | Existing owner | Exact slice count |
|---|---:|---|---:|
| `qinao.content-intake.w1.semantics-layercell.v1` | W1 | `semantics.layercell` | 2 |
| `qinao.content-intake.w1.artifact-mesh.v1` | W1 | `artifact.mesh` | 1 |
| `qinao.content-intake.w2.runtime-turn-operation.v1` | W2 | `runtime.turn-operation` | 2 |
| `qinao.content-intake.w5.semantics-layercell-authorization.v1` | W5 | `semantics.layercell` | 1 |
| `qinao.content-intake.w6.production-cutover.v1` | W6 | `production.cutover` | 1 |

Their exact seven singular slices are:

| `sliceID` | Manifest | Class | `wireChange` | Exact `path` | Exact `symbol` | `responsibilityID` |
|---|---|---:|---:|---|---|---|
| `content-intake.profile-contract` | W1 semantics | E | true | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASContentIntakeContracts.swift` | `BASContentIntakeProfilePayload` | `content-intake.profile-schema-and-bounds` |
| `content-intake.receipt-contract` | W1 semantics | E | true | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASContentIntakeContracts.swift` | `BASContentIntakeReceiptPayload` | `content-intake.receipt-schema-lineage-and-terminal` |
| `content-intake.artifact-storage` | W1 Artifact Mesh | A | false | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift` | `BASArtifactStorePort` | `content-intake.ordinary-put-read-reopen` |
| `content-intake.host-parser-containment` | W2 Runtime | A | false | `QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime+TurnInputs.swift` | `QinaoRuntime.parseContentIntake` | `content-intake.bounded-parser-and-containment` |
| `content-intake.host-receipt-production` | W2 Runtime | A | false | `QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime+TurnInputs.swift` | `QinaoRuntime.makeContentIntakeReceipt` | `content-intake.host-observation-to-receipt` |
| `content-intake.l14-current-policy-authorization` | W5 semantics | E | false | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASContentIntakeContracts.swift` | `BASContentIntakeAuthorizationRules.validate` | `content-intake.l14-current-policy-decision` |
| `content-intake.release-profile-selection` | W6 cutover | A | false | `BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeDefaultModeFlipReadinessGate.swift` | `BASTurnRuntimeDefaultModeFlipReadinessGate.requiredContentIntakeProfileArtifactID` | `content-intake.release-selected-profile` |

The exact first-authoritative-wire set consists of the two content-intake
payload slices above plus the authorized-input predecessor slice in Step 4;
current and future-rejection fixtures are mandatory, while backward is
`notApplicable` with repository-history proof. W1 freezes only the two pure
content-intake schema/value slices. L14/current-policy authorization therefore
lands in W5, never in the W1 schema manifest.
Production intake remains typed `unsupported` until all five content-intake
manifests, every fixture, and the W6 selected-profile reachability gate pass.

The profile freezes exact accepted type triples and all raw/decoded/decompression/nesting/archive/page/pixel/frame/duration/CPU/time/memory/child limits, active-content/external-reference/metadata/privacy/encoding policy, parser/containment identities, and closed disposition vocabulary. The receipt binds exactly one source variant, all observations/lineage/taint/coverage, and one terminal:

```text
accepted | acceptedPartial | quarantined | unsupported | limitExceeded | malformed | denied
```

No intake manifest is M/CreateGate input.

- [ ] **Step 4: Freeze exactly seven authorized-input/remote manifest templates**

The catalog contains exactly these seven manifest identities:

| Manifest ID | Work wave | Existing owner | Responsibility |
|---|---:|---|---|
| `qinao.authorized-input.w1.semantics-layercell.v1` | W1 | `semantics.layercell` | pure `BASAuthorizedInputEffectPredecessorPayload` value/validation |
| `qinao.authorized-input.w1.artifact-mesh.v1` | W1 | `artifact.mesh` | ordinary immutable storage/reopen of the predecessor payload |
| `qinao.authorized-input.w2.state-k3-control-nucleus.v1` | W2 | `state.k3-control-nucleus` | vNext `StatePrepareIntent.effectSourceRef`, outbox source ref, K3 reopen/dedupe/branch-ordinal-instance allocation |
| `qinao.remote.w4.execution-plan-provider-router.v1` | W4 | `execution.plan-provider-router` | vNext nonsecret descriptor/materialized-request identity |
| `qinao.remote.w5.sovereign-k4-durable-lifecycle.v1` | W5 | `sovereign.k4-durable-lifecycle` | exact credential-version use/anchor binding |
| `qinao.authorized-input.w5.effect-zone-c-saga.v1` | W5 | `effect.zone-c-saga` | outbox-only dispatch, terminal receipt, and query/reconcile |
| `qinao.remote.w5.provider-package-boundary.v1` | W5 | `provider.package-boundary` | post-Q+B one-shot exact-version secret injection plus remote O/At binding |

Those seven manifests contain exactly these eighteen singular slices:

| `sliceID` | Manifest | Class | Exact `path` | Exact `symbol` | `responsibilityID` |
|---|---|---:|---|---|---|
| `authorized-input.predecessor-contract` | W1 semantics | E | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASAuthorizedInputEffectContracts.swift` | `BASAuthorizedInputEffectPredecessorPayload` | `authorized-input.value-and-causality-validation` |
| `authorized-input.artifact-storage` | W1 Artifact Mesh | A | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift` | `BASArtifactStorePort` | `authorized-input.ordinary-put-read-reopen` |
| `authorized-input.state-prepare-source-ref` | W2 K3 | E | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASStateCommitContracts.swift` | `BASStatePreparePayload.effectSourceRef` | `authorized-input.prepare-typed-source-vnext` |
| `authorized-input.outbox-source-ref` | W2 K3 | E | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASStateCommitContracts.swift` | `BASStateEffectOutboxPayload.effectSourceRef` | `authorized-input.outbox-typed-source-vnext` |
| `authorized-input.k3-allocation-deduplication` | W2 K3 | E | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift` | `BASSQLiteEventLogStorage.prepareAndEnqueue` | `authorized-input.k3-reopen-dedupe-ordinal-instance` |
| `remote.k3-provider-boundary-row` | W2 K3 | E | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift` | `BASSQLiteEventLogStorage.prepareProviderEgressBoundary` | `remote.k3-content-free-binding-row-vnext` |
| `remote.k3-boundary-arm-contract` | W2 K3 | E | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASLowEntropyPrimitives.swift` | `BASBoundaryArmReceipt.credentialAuthorizationBinding` | `remote.k3-arm-binding-vnext` |
| `remote.persisted-descriptor-contract` | W4 plan/router | E | `BehavioralAISubstrate/Sources/BASOrgan/BASOrganAdapter.swift` | `BASPersistedOrganDescriptorPayload.credentialSlotID` | `remote.descriptor-nonsecret-slot-scheme-destination-vnext` |
| `remote.materialized-request-contract` | W4 plan/router | E | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASLowEntropyPrimitives.swift` | `BASMaterializedProviderRequestPayload.nonsecretRequestDigest` | `remote.materialized-request-nonsecret-template-vnext` |
| `remote.k4-use-contract` | W5 K4 | E | `BehavioralAISubstrate/Sources/BASRuntimeCore/EBrainControlPlaneCore.swift` | `BASCapabilityUseReceipt.credentialAuthorizationBinding` | `remote.k4-use-binding-vnext` |
| `remote.k4-anchor-contract` | W5 K4 | E | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASLowEntropyPrimitives.swift` | `BASBoundaryAnchorReceipt.credentialAuthorizationBinding` | `remote.k4-anchor-binding-vnext` |
| `remote.k4-claim-anchor-validation` | W5 K4 | E | `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignTokenAuthority.swift` | `BASSovereignTokenAuthority.claimAndAnchorBoundary` | `remote.k4-exact-version-use-anchor-validation` |
| `authorized-input.zone-c-outbox-dispatch` | W5 Zone C | E | `BehavioralAISubstrate/Sources/BASEffectBroker/BASEffectBroker.swift` | `BASEffectBroker.dispatchPreparedEffect` | `authorized-input.outbox-only-fenced-dispatch` |
| `authorized-input.zone-c-query-reconcile` | W5 Zone C | E | `BehavioralAISubstrate/Sources/BASEffectBroker/BASEffectBroker.swift` | `BASEffectBroker.reconcilePreparedEffect` | `authorized-input.unknown-query-reconcile-no-resend` |
| `remote.egress-permit-contract` | W5 Provider boundary | E | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASStateCommitContracts.swift` | `BASProviderEgressBoundaryPermit.credentialAuthorizationBinding` | `remote.permit-content-free-binding-vnext` |
| `remote.observation-contract` | W5 Provider boundary | E | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASLowEntropyPrimitives.swift` | `BASProviderObservedReceipt.credentialAuthorizationBinding` | `remote.observation-nonsecret-binding-vnext` |
| `remote.attestation-contract` | W5 Provider boundary | E | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift` | `BASArtifactAttestationPayload.providerCredentialBindingDigest` | `remote.attestation-nonsecret-binding-vnext` |
| `remote.one-shot-transport-injection` | W5 Provider boundary | A | `BehavioralAISubstrate/Sources/BASRuntimeCore/ProviderExecutionCore.swift` | `BASProviderAttemptExecutor.executeAtMostOnce` | `remote.post-handoff-exact-version-resolve-inject-call-zeroize` |

All eighteen use `wireChange = true` except
`authorized-input.artifact-storage`,
`authorized-input.k3-allocation-deduplication`,
`remote.k4-claim-anchor-validation`,
`authorized-input.zone-c-outbox-dispatch`,
`authorized-input.zone-c-query-reconcile`, and
`remote.one-shot-transport-injection`, which use `false`. The W2 K3 remote
row/arm slices are schema-inert until the W5 remote gate; they may store and
compare only the content-free binding projection and expose no transport call.
Their prerequisite is the W1 declared-inert embedded
`CredentialAuthorizationBinding` catalog row owned by
`provider.package-boundary`; that embedded value is not a standalone governed
payload, manifest, store, lease, or eighth authorized/remote manifest.

The W2 K3 manifest may contain multiple singular slices, but each slice has one path/symbol/responsibility. The W4/W5 remote slices cover the existing contract IDs for:

```text
BASPersistedOrganDescriptorPayload
BASMaterializedProviderRequestPayload
BASProviderEgressBoundaryPermit
BASCapabilityUseReceipt
K3 Provider-boundary row
BASBoundaryAnchorReceipt
BASBoundaryArmReceipt
remote O/At
```

Every vNext row retains its existing `contract_id` and changes `version`; only `BASAuthorizedInputEffectPredecessorPayload` receives one new stable contract ID. V1 remains decodable; future versions fail closed; raw-secret v1 rows are quarantined, never silently converted.

Every roster row expands to the remaining closed fields without implementer
choice:

```python
FIRST_WIRE_SLICE_IDS = {
    "content-intake.profile-contract",
    "content-intake.receipt-contract",
    "authorized-input.predecessor-contract",
}

BEHAVIOR_ONLY_SLICE_IDS = {
    "authorized-input.artifact-storage",
    "authorized-input.k3-allocation-deduplication",
    "remote.k4-claim-anchor-validation",
    "authorized-input.zone-c-outbox-dispatch",
    "authorized-input.zone-c-query-reconcile",
    "remote.one-shot-transport-injection",
}

PREREQUISITE_IDS_BY_WAVE = {
    "W1": (
        "authority.qinao-prew0-bundle",
        "ledger.qinao-owner-ledger-v2-prew0",
        "gate.qinao.ios27-floor.preW0",
        "gate.qinao.artifact-mesh-device-recovery.W1",
    ),
    "W2": (
        "admission.qinao.W1",
        "contract.BASAuthorizedInputEffectPredecessorPayload.1.0.0",
        "contract.BASContentIntakeProfilePayload.1.0.0",
        "contract.BASContentIntakeReceiptPayload.1.0.0",
        "contract.CredentialAuthorizationBinding.1.0.0-declared-inert",
    ),
    "W4": (
        "admission.qinao.W3",
        "contract.CredentialAuthorizationBinding.1.0.0-declared-inert",
        "contract.qinao-k3-provider-boundary.2.0.0-declared-inert",
    ),
    "W5": (
        "admission.qinao.W4",
        "gate.qinao.k4-platform-proof.W4",
        "contract.CredentialAuthorizationBinding.1.0.0-declared-inert",
        "contract.BASPersistedOrganDescriptorPayload.2.0.0",
        "contract.BASMaterializedProviderRequestPayload.2.0.0",
    ),
    "W6": (
        "admission.qinao.W5",
        "profile.qinao.samplehost-ios.1.0.0",
        "gate.qinao.production-reachability.W6",
    ),
}

def fixture_projection(slice_id: str, wire_change: bool) -> dict:
    first_wire = slice_id in FIRST_WIRE_SLICE_IDS
    behavior_only = slice_id in BEHAVIOR_ONLY_SLICE_IDS
    if wire_change == behavior_only:
        raise ValueError(
            "slice must be exactly one of wire-change or behavior-only"
        )
    backward_required = wire_change and not first_wire
    return {
        "currentFixtureIDs": [f"ea.{slice_id}.current"],
        "backwardFixture": {
            "disposition": (
                "required" if backward_required else "notApplicable"
            ),
            "fixtureIDs": (
                [f"ea.{slice_id}.backward_v1"]
                if backward_required else []
            ),
            "historyProofID": (
                f"history.{slice_id}.v1"
                if backward_required
                else (
                    f"history.{slice_id}.no-prior-authoritative-wire"
                    if first_wire
                    else f"history.{slice_id}.behavior-only-no-wire-change"
                )
            ),
        },
        "futureFixtureIDs": [f"ea.{slice_id}.future_rejection"],
        "storageProofRuleID": f"ea.{slice_id}.storage",
        "replayProofRuleID": f"ea.{slice_id}.replay",
        "recoveryProofRuleID": f"ea.{slice_id}.recovery",
    }
```

For every slice, `introductionWave == workWave ==` its manifest wave,
`prerequisiteIDs` is exactly the sorted tuple for that wave above,
and `ownerBefore == ownerAfter == existingOwnerID`. `sliceID` and
`responsibilityID` are each globally unique. Each slice carries exactly one
scalar `path` and one scalar `symbol`, and the complete
`(sliceID, manifest_id, path, symbol, responsibilityID)` tuple set must equal
the literal 25-row roster above. A path or `(path, symbol)` seam may
intentionally serve multiple distinct responsibilities—for example the two
`BASArtifactStorePort` storage slices—without merging those slices or moving
their owner. A `required` backward fixture must name the exact prior governed
v1 contract ID and source blob in its history proof; `notApplicable` must
prove either first wire or behavior-only adaptation and cannot hide a real
prior wire.

- [ ] **Step 5: Implement the parser and exact identity gate**

Add:

```python
CONTENT_INTAKE_MANIFEST_IDS = (
    "qinao.content-intake.w1.artifact-mesh.v1",
    "qinao.content-intake.w1.semantics-layercell.v1",
    "qinao.content-intake.w2.runtime-turn-operation.v1",
    "qinao.content-intake.w5.semantics-layercell-authorization.v1",
    "qinao.content-intake.w6.production-cutover.v1",
)

AUTHORIZED_REMOTE_MANIFEST_IDS = (
    "qinao.authorized-input.w1.artifact-mesh.v1",
    "qinao.authorized-input.w1.semantics-layercell.v1",
    "qinao.authorized-input.w2.state-k3-control-nucleus.v1",
    "qinao.authorized-input.w5.effect-zone-c-saga.v1",
    "qinao.remote.w4.execution-plan-provider-router.v1",
    "qinao.remote.w5.provider-package-boundary.v1",
    "qinao.remote.w5.sovereign-k4-durable-lifecycle.v1",
)

def validate_catalog(catalog: dict, owner_ids: set[str]) -> list[str]:
    errors: list[str] = []
    manifests = catalog.get("manifest_templates")
    if not isinstance(manifests, list):
        return ["manifest_templates must be a list"]
    ids = tuple(row.get("manifest_id") for row in manifests if isinstance(row, dict))
    expected = tuple(sorted(CONTENT_INTAKE_MANIFEST_IDS + AUTHORIZED_REMOTE_MANIFEST_IDS))
    if ids != expected:
        errors.append(f"manifest template IDs differ: expected={expected!r} found={ids!r}")
    for manifest in manifests:
        errors.extend(validate_manifest(manifest, owner_ids, template_mode=True))
    return errors
```

`template_mode=True` permits future paths not yet present and forbids
result/test/commit/tree/receipt fields. `template_mode=False` requires each
named source path to be an indexed regular blob, resolves the named symbol
through the appropriate source/build projection, resolves every fixture and
prerequisite ID through the authenticated current-wave catalog/result set,
and requires a non-empty executed fixture receipt supplied by the active
external gate module. A symbol or abstract identity is never treated as a
filesystem path merely because it is named in a slice.

- [ ] **Step 6: Prove schemas, manifests, and gates are non-vacuous**

Add negative cases for:

```text
delete one of 5 content-intake IDs
delete one of 7 authorized/remote IDs
add a sixth content-intake ID
add an eighth authorized/remote ID
delete or add one of the exact 25 slice IDs
swap two owners
merge two owners into one slice
move W2 work to W1 or W5
emit content intake as M
make backward fixture present without real prior wire
set ownerBefore != ownerAfter
use empty current/future fixture arrays
add candidate commit/tree/result fields to a template
```

Run:

```bash
python3 -m unittest -v scripts.test_check_qinao_ea_extensions
python3 scripts/check_qinao_ea_extensions.py \
  --root . \
  --manifest docs/superpowers/specs/qinao-extension-identity-catalog-v1.json \
  --payload-commit "$(git rev-parse HEAD)" \
  --payload-tree "$(git rev-parse HEAD^{tree})"
```

Expected:

```text
qinao-ea-extensions: PASS kind=identity-catalog content_intake=5 authorized_remote=7 manifests=12 slices=25
```

- [ ] **Step 7: Commit only template/schema/parser bytes**

Run:

```bash
git add \
  docs/superpowers/specs/qinao-extension-slice-v1.schema.json \
  docs/superpowers/specs/qinao-schema-fixture-manifest-v1.schema.json \
  docs/superpowers/specs/qinao-extension-identity-catalog-v1.json \
  scripts/check_qinao_ea_extensions.py \
  scripts/test_check_qinao_ea_extensions.py
git commit -m "feat(qinao): freeze extension identity templates"
```

Expected: exactly five paths; no production Swift file and no current-wave result.

---

### Task 6: Import Authenticated Bootstrap Handoff B and Finalize Authority Digests

**Files:**
- Modify: `docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify: `docs/superpowers/plans/2026-07-19-qinao-coreai-agent-controlled-document-convergence.md`
- Read without modifying: the exact 11 authority texts.
- Read without modifying:
  `docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json`
- Defer creation until Task 10 Step 6:
  `/private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json`

**Interfaces:**
- Consumes: authenticated export-envelope handoff B.
- Produces: byte-matched `wave_admission_v1`, final 7+4 digests, and final
  CoreAI trace pins. Task 10 recomputes these values from the final indexed
  tree and creates the authority-finalization return object exactly once.

- [ ] **Step 1: Reopen every externally verified bootstrap export, then prove the candidate remains non-authoritative**

The bootstrap sibling's two-operator ceremony verifies
`export-envelope-v1.json` and the four bound export byte digests before
handoff B. This plan does not duplicate that external verifier or invent a
candidate-local substitute. After receiving the authenticated export receipt,
assert that all five regular files named in the handoff exist, reject symlinks,
and byte-compare their SHA-256 values with the authenticated envelope.

Reopen that external verification through the bootstrap sibling's exact
read-only command, then run the existing candidate preflight and assert its
intentionally blocked exit contract:

```bash
python3 scripts/verify_qinao_bootstrap_export.py \
  --request /private/tmp/qinao-bootstrap-ceremony-v1/ceremony-request-v1.json \
  --export-directory /private/tmp/qinao-bootstrap-ceremony-v1/export

set +e
PREFLIGHT_OUTPUT="$(
  python3 scripts/check_qinao_wave_admission.py \
    --mode preflight \
    --bootstrap /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json \
    --repository-root .
)"
PREFLIGHT_STATUS="$?"
set -e
test "$PREFLIGHT_STATUS" -eq 2
QINAO_PREFLIGHT_OUTPUT="$PREFLIGHT_OUTPUT" python3 -c '
import json
import os

value = json.loads(os.environ["QINAO_PREFLIGHT_OUTPUT"])
assert value["status"] == "preflight"
assert value["result"] == "blocked"
assert value["authority"] == "none"
assert (
    value["blocker"]["code"]
    == "external_attestation_authentication_unavailable"
)
'
```

Expected: the external ceremony has already authenticated the envelope; the
candidate checker reports `status = preflight`, exits `2`, and retains
`external_attestation_authentication_unavailable`. Candidate output of
`admitted`, exit `0`, or absence of that blocker is failure.

- [ ] **Step 2: Canonically byte-match the projection into the Ledger**

Use duplicate-key-rejecting JSON parsing. Require:

```python
external_bytes = external_path.read_bytes()
external_value = json.loads(
    external_bytes.decode("utf-8"),
    object_pairs_hook=reject_duplicate_keys,
)
if canonical_json(external_value) + b"\n" != external_bytes:
    raise ValidationError("external wave_admission_v1 is not canonical JSON")
ledger["wave_admission_v1"] = external_value
if canonical_json(ledger["wave_admission_v1"]) != canonical_json(external_value):
    raise ValidationError("Ledger wave_admission_v1 is not byte-equivalent")
```

Do not copy `bootstrap-attestation-v1.json`, operator approvals, signatures, transparency proof, or secret-bearing provider material into the Ledger.
Reject concrete `bootstrap_attestation`, `bootstrap_attestation_digest`,
`bootstrap_attestation_status`, approval/signature, or transparency-entry
fields inside `wave_admission_v1`; only its closed
`bootstrap_attestation_policy` is legal. Authenticate the separate
attestation and its one-way `wave_admission_projection_sha256` binding through
the already verified export envelope. The shorter `projection_sha256` alias is
forbidden.

- [ ] **Step 3: Finalize all document and catalog digests in dependency order**

Use this order:

```text
1. reopen Input A and prove every catalog row/authority_ref is byte-identical; never edit it
2. recompute all 11 indexed raw-byte digests and require the exact ordered map to equal Input A document_digests
3. verify the already-indexed canonical reference block and required-term anchors in all 11 texts
4. write those already-frozen hashes into controlled_documents[7].sha256 and governing_addenda_v1[4].sha256
5. recompute controlled_contract_catalog_digest and require equality with Input A
6. recompute authority_bundle_digest from the exact 11-row map and require equality with Input A
7. compute owner_ledger_digest from the final Ledger bytes
8. write authority_bundle_digest, owner_ledger_digest, and controlled_contract_catalog_digest into the CoreAI non-authoritative trace
9. prove the 11 authority texts and Ledger bytes/digests did not change during step 8
```

The CoreAI plan is outside the 7+4 set and no Ledger field digests it, so its
one-way trace can bind final digests without a fixed-point/self-hash. If any
7+4 text embeds the Owner Ledger or authority-bundle digest, or any Ledger
row embeds the CoreAI plan digest, fail: authority texts may reference stable
IDs/terms, not their container's future digest.

- [ ] **Step 4: Prove immutable handoff A still matches the ceremony**

Run:

```bash
git diff --quiet -- \
  docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json
git diff --cached --quiet -- \
  docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json
python3 scripts/verify_qinao_bootstrap_export.py \
  --request /private/tmp/qinao-bootstrap-ceremony-v1/ceremony-request-v1.json \
  --export-directory /private/tmp/qinao-bootstrap-ceremony-v1/export
```

Expected: the Task-3 draft remains byte-identical to the immutable ceremony
request and Output B. Its `owner_ledger_draft_digest` intentionally names the
pre-ceremony draft; final Ledger/authority digests travel only in
`authority-finalization-v1.json`. Any attempt to regenerate or “refresh”
handoff A after Output B is a digest-cycle violation and restarts the external
ceremony.

- [ ] **Step 5: Run the full authority/Ledger/extension gate set**

Run:

```bash
python3 -m unittest -v \
  scripts.test_check_qinao_authority_convergence \
  scripts.test_build_qinao_authority_draft \
  scripts.test_check_qinao_owner_ledger \
  scripts.test_qinao_owner_ledger_v2 \
  scripts.test_check_qinao_ea_extensions

python3 scripts/check_qinao_authority_convergence.py \
  --root . \
  --ledger docs/superpowers/specs/qinao-owner-ledger-v1.json

python3 scripts/check_qinao_ea_extensions.py \
  --root . \
  --manifest docs/superpowers/specs/qinao-extension-identity-catalog-v1.json \
  --payload-commit "$(git rev-parse HEAD)" \
  --payload-tree "$(git rev-parse HEAD^{tree})"
```

Expected: every suite non-empty and green; authority reports
`documents=11 controlled=7 addenda=4`; extension catalog reports
`content_intake=5 authorized_remote=7 manifests=12 slices=25`; the authority
draft tests validate immutable fixture/ceremony grammar and do not regenerate
Input A from the now-final Ledger.

- [ ] **Step 6: Commit the final authority preparation slice**

Stage only the changed Ledger and CoreAI trace. Assert that the Input-A draft
and all 11 authority texts are unstaged and still byte-match Input A. Run:

```bash
git add \
  docs/superpowers/specs/qinao-owner-ledger-v1.json \
  docs/superpowers/plans/2026-07-19-qinao-coreai-agent-controlled-document-convergence.md
test "$(git diff --cached --name-only | wc -l | tr -d ' ')" -eq 2
git diff --cached --quiet -- \
  docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json
python3 scripts/build_qinao_authority_draft.py \
  --root . \
  --ledger docs/superpowers/specs/qinao-owner-ledger-v1.json \
  --compare-authority-only \
  docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json
git diff --cached --check
git commit -m "docs(qinao): finalize prew0 authority identities"
```

`--compare-authority-only` reopens the exact 11 indexed paths and compares
their ordered raw digest map, authority bundle digest, and contained catalog
digest to immutable Input A; it does not require the now-schema-v2 Ledger blob
to equal the old raw draft digest and writes nothing.

Expected: one exact two-path preparation commit, not `Pw`.

- [ ] **Step 7: Freeze reproducible finalization inputs without exporting a partial handoff**

Recompute the four final digest values from indexed bytes, compare them to
the Ledger/CoreAI trace and authenticated handoff B, then discard the
in-memory projection. Assert that
`/private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json`
does not yet exist. The only recovery exception is an already-completed,
byte-identical Task-10 export that bootstrap Task 9 has authenticated; that
state resumes at Task 10 Step 7 and must not rerun Task 6. Do not write a
provisional object: Tasks 7-10 still change the preparation tip/tree, and
bootstrap Task 9 accepts only the final complete preparation tree.

Expected: the digest values are reproducible, no handoff file exists, and
bootstrap remains paused at Hold C.

---

### Task 7: Derive the Complete Production Build and Reachability Graph

**Files:**
- Create: `docs/superpowers/specs/qinao-production-reachability-v1.schema.json`
- Create: `scripts/qinao_build_graph.py`
- Create: `scripts/test_qinao_build_graph.py`
- Create: `scripts/generate_qinao_production_reachability.py`
- Create: `scripts/check_qinao_production_reachability.py`
- Create: `scripts/test_check_qinao_production_reachability.py`

**Interfaces:**
- Consumes: indexed candidate tree, exact three package roots, every
  Ledger-declared shipping profile, all governed
  Xcode/XcodeGen/workspace roots, and the signed non-shipping
  `verification_toolchain_profile`. If a later wave has active shipping
  profiles, it additionally consumes their external
  AST/SIL/index/link projections; preW0 has none.
- Produces: a compare-only actual graph, actual declared-contract set, actual
  production-reachable contract set, and an empty preW0 selected-release
  projection template. It supplies no owner/status/policy/wave/expected-set
  decision and never reclassifies the verification toolchain as a release.

- [ ] **Step 1: Write RED tests for root discovery and non-vacuity**

Add tests for:

```text
all three package roots are mandatory
every project.yml, .xcodeproj, and .xcworkspace is classified
BASDeviceTest project.yml and generated pbxproj are both visible
future ArtifactMeshDeviceLab is explicit lab-only, never omitted by path
private/package/internal/public factories and entry points are traversed
protocol/callback/generic/ObjC/reflection/dynamic edges expand or fail closed
vendored linked symbols remain in the graph
zero entry points cannot support implemented
missing or renamed root fails
caller root/profile/wave/status fields fail
generated Xcode semantic drift fails
generator cannot overwrite expected output
remote dependency without indexed Package.resolved fails
local-only dependency graph needs no fake Package.resolved
```

Create importable final-signature graph/generator/checker stubs in this RED
step. Each returns
`qinao.production-reachability.unimplemented` after validating its required
argument surface.

- [ ] **Step 2: Run RED**

Run:

```bash
python3 -m unittest -v \
  scripts.test_qinao_build_graph \
  scripts.test_check_qinao_production_reachability
```

Expected: tests discover and fail only on
`qinao.production-reachability.unimplemented`; no module or fixture is
absent.

- [ ] **Step 3: Freeze the root and graph data types**

Add to `scripts/qinao_build_graph.py`:

```python
MANDATORY_PACKAGE_ROOTS = (
    "BehavioralAISubstrate/Package.swift",
    "QinaoRuntimeSDK/Package.swift",
    "SampleHost/Package.swift",
)

KNOWN_GENERATED_PROJECTS = (
    (
        "BehavioralAISubstrate/DeviceTestApp/project.yml",
        "BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj/project.pbxproj",
        "lab-evidence",
    ),
)

@dataclasses.dataclass(frozen=True, order=True)
class BuildTarget:
    root: str
    scheme: str
    product: str
    classification: str
    configuration: str
    sdk: str
    architectures: tuple[str, ...]
    compilation_conditions: tuple[str, ...]
    feature_flags: tuple[str, ...]

@dataclasses.dataclass(frozen=True, order=True)
class ReachabilityEdge:
    source: str
    target: str
    edge_kind: str
    evidence_digest: str
```

`classification` is exactly `shipping | lab-evidence | test | build-tool`.
Directory names never supply it; a declared shipping profile or explicit
governed exclusion does. The non-shipping verification-toolchain profile
selects the evaluator toolchain only and supplies no graph root or shipping
classification.

- [ ] **Step 4: Regenerate XcodeGen projects into a temporary directory and compare semantics**

For each indexed `project.yml`:

```python
with tempfile.TemporaryDirectory() as temporary:
    generated = Path(temporary) / "Generated"
    subprocess.run(
        [
            "xcodegen", "generate",
            "--spec", str(root / spec_path),
            "--project", str(generated),
        ],
        check=True,
        cwd=root,
    )
    expected_model = semantic_pbx_model(root / indexed_pbxproj)
    generated_model = semantic_pbx_model(
        generated
        / Path(indexed_pbxproj).parent.name
        / Path(indexed_pbxproj).name
    )
    if expected_model != generated_model:
        raise ValidationError(
            f"generated Xcode semantic drift: {spec_path} -> {indexed_pbxproj}"
        )
```

`semantic_pbx_model` includes target/product type, configuration, deployment target, compilation conditions, source membership, package/product dependencies, entitlements, build phases, schemes, and test-host relation. It removes only Xcode object IDs and ordering that the parser proves semantically irrelevant. Never compare a project after writing generated bytes over the expected path.

- [ ] **Step 5: Enforce Package.resolved as a closed tagged rule**

The output contains exactly one package-resolution record per package/profile root:

```json
{
  "kind": "localOnly",
  "package_root": "SampleHost/Package.swift",
  "local_dependency_roots": ["BehavioralAISubstrate/Package.swift"],
  "resolved_path": null,
  "resolved_sha256": null
}
```

or:

```json
{
  "kind": "resolvedRemote",
  "package_root": "path/Package.swift",
  "local_dependency_roots": [],
  "resolved_path": "path/Package.resolved",
  "resolved_sha256": "64-lowercase-hex"
}
```

Use `swift package dump-package` plus recursive local-package traversal to derive dependency kinds. If any remote dependency is reachable from an active shipping target, `resolvedRemote` and a regular stage-0 indexed `Package.resolved` are mandatory. A documentation/plugin/developer-only remote dependency may be excluded only by a graph path proving it cannot reach an active shipping product.

- [ ] **Step 6: Derive declarations and reachability without expected values**

The generator emits:

```json
{
  "schema_version": 1,
  "payload_commit_oid": "git-oid",
  "payload_tree_oid": "git-tree-oid",
  "input_root_digests": [],
  "build_targets": [],
  "entry_points": [],
  "factories": [],
  "declarations": [],
  "edges": [],
  "linked_symbols": [],
  "package_resolutions": [],
  "actual_declared_contracts": [],
  "actual_production_reachable_contracts": [],
  "lab_only_paths": [],
  "unresolved_edges": []
}
```

It contains no `expected_*`, `owner_id`, owner status, contract status, supplied wave, profile-selection decision, or completion Boolean. Unknown compatible indirect targets expand conservatively; an unresolved edge remains non-empty and makes the checker fail.

- [ ] **Step 7: Generate to temporary files against the future payload tree**

Before `Pw`, use the preparation tree only for diagnostic tests:

```bash
mkdir -p /private/tmp/qinao-prew0
python3 scripts/generate_qinao_production_reachability.py \
  --root . \
  --ledger docs/superpowers/specs/qinao-owner-ledger-v1.json \
  --bootstrap /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json \
  --payload-commit "$(git rev-parse HEAD)" \
  --payload-tree "$(git rev-parse HEAD^{tree})" \
  --output /private/tmp/qinao-prew0/qinao-production-reachability-v1.json \
  --declared-contracts-output /private/tmp/qinao-prew0/declared-contracts.json
```

After Bootstrap Task 10 forms `Pw` and Authority Task 10 Step 8 verifies the
returned transaction, rerun with exact `Pw` OIDs. The generator writes no Git
evidence path.

- [ ] **Step 8: Check non-vacuity and exact payload binding**

Run:

```bash
python3 scripts/check_qinao_production_reachability.py \
  --root . \
  --ledger docs/superpowers/specs/qinao-owner-ledger-v1.json \
  --bootstrap /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json \
  --payload-commit "$(git rev-parse HEAD)" \
  --payload-tree "$(git rev-parse HEAD^{tree})" \
  --manifest /private/tmp/qinao-prew0/qinao-production-reachability-v1.json
```

Expected: all mandatory roots are scanned; targets/entry points/declarations
are nonzero; active shipping profile count is derived from Ledger and is zero
at preW0; the Xcode/SDK identity byte-matches the signed non-shipping
verification profile; no selected release is fabricated; and no implemented
production capability is accepted with zero reachable entry points.

Run the Owner-Ledger CLI against those independently derived files:

```bash
python3 scripts/check_qinao_owner_ledger.py \
  --root . \
  --ledger docs/superpowers/specs/qinao-owner-ledger-v1.json \
  --bootstrap /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json \
  --declared-contracts /private/tmp/qinao-prew0/declared-contracts.json \
  --production-reachability /private/tmp/qinao-prew0/qinao-production-reachability-v1.json
```

Expected output matches this anchored regular expression:

```text
^owner-ledger: PASS schema=2 owners=29 controlled=7 addenda=4 contracts=[1-9][0-9]* active_profiles=0 candidates=0 mode=preflight$
```

No `--wave` or `--candidate-manifest` exists. The reported `candidates=0`
comes from the checker-derived indexed predecessor delta; preW0 authorizes no
classification-M production owner, while E/A identity templates are validated
by their dedicated generic checker.

- [ ] **Step 9: Run GREEN and commit graph tools/schemas only**

Run:

```bash
python3 -m unittest -v \
  scripts.test_qinao_build_graph \
  scripts.test_check_qinao_production_reachability
git add \
  docs/superpowers/specs/qinao-production-reachability-v1.schema.json \
  scripts/qinao_build_graph.py \
  scripts/test_qinao_build_graph.py \
  scripts/generate_qinao_production_reachability.py \
  scripts/check_qinao_production_reachability.py \
  scripts/test_check_qinao_production_reachability.py
git commit -m "feat(qinao): derive production reachability graph"
```

Expected: exactly six paths; no generated result enters this commit.

---

### Task 8: Generate Architecture Closure and the Exact Seven-Feature/21-Rule V2 Quarantine

**Files:**
- Create: `docs/superpowers/specs/qinao-architecture-closure-report-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-v2-quarantine-v1.schema.json`
- Create: `scripts/generate_qinao_architecture_closure.py`
- Create: `scripts/check_qinao_architecture_closure.py`
- Create: `scripts/test_check_qinao_architecture_closure.py`
- Create: `scripts/generate_qinao_v2_quarantine.py`
- Create: `scripts/check_qinao_v2_quarantine.py`
- Create: `scripts/test_check_qinao_v2_quarantine.py`

**Interfaces:**
- Consumes: valid Owner Ledger v2, indexed 7+4 digests, exact production
  graph, the frozen prior-phase gate-result index, and the Ledger-derived
  release index (empty at preW0). Each gate result's contract digest is
  reopened against the authenticated catalog, and its `derived_wave`
  deterministically resolves that contract's literal `program_by_wave`; no
  report substitutes a final-state program.
- Produces: non-authoritative compare-only closure and V2 projections.
  ArchitectureClosure is the sole final-phase gate; its report cannot consume
  its own result or the final gate-result index. Neither projection can change
  owner/status/policy/expected set.

- [ ] **Step 1: Write RED closure tests**

For every controlled contract and production capability, require exactly:

```text
contract identity/schema
authority owner
mutable writer
storage owner
recovery profile/rule
production constructors/entry points
allowed reachability
forbidden reachability
positive non-vacuous tests
negative mutation/crash terminals
release gate
current status
source digests
```

Tests reject a missing field, unknown entry point, unclassified writer,
recovery omission, zero-test claim, implemented-with-zero-reachability,
hand-edited output, report-supplied owner/status/policy, input digest mismatch,
an ArchitectureClosure self-result, a final index containing that self-result,
or a prior-phase set other than the exact lease-bound predecessor set. Also
reject a gate result whose contract digest is unknown, whose derived wave
does not select exactly one closed program, whose earlier required slice is
missing, or whose later-wave identity is present.

Create importable final-signature ArchitectureClosure stubs and a
syntactically valid closed schema in this RED step. They fail closed with
`qinao.architecture-closure.unimplemented`.

- [ ] **Step 2: Write RED V2 tests for exact identities**

Freeze:

```python
V2_RULES = {
    "v2.incremental-visible-streaming": (
        "v2q.stream.public-async-sequence",
        "v2q.stream.preterminal-release",
        "v2q.stream.visible-dataflow",
    ),
    "v2.cross-device-root-merge": (
        "v2q.root.remote-writer",
        "v2q.root.merge-cas",
        "v2q.root.external-anchor",
    ),
    "v2.cross-process-heavy": (
        "v2q.heavy.extension-link",
        "v2q.heavy.extension-call",
        "v2q.heavy.cross-process-lease",
    ),
    "v2.federated-dp-learning": (
        "v2q.fldp.learning-egress",
        "v2q.fldp.model-delta",
        "v2q.fldp.privacy-accountant",
    ),
    "v2.realtime-voice-barge-in": (
        "v2q.voice.audio-capture-link",
        "v2q.voice.partial-transcript-flow",
        "v2q.voice.barge-in-cancel",
    ),
    "v2.provider-backed-question-studio": (
        "v2q.studio.provider-purpose",
        "v2q.studio.automatic-trigger",
        "v2q.studio.preview-provider-flow",
    ),
    "v2.optimistic-context-rebase": (
        "v2q.rebase.epoch-mismatch-reuse",
        "v2q.rebase.optimistic-cas-bypass",
        "v2q.rebase.stale-cache-flow",
    ),
}
```

Assert exactly 7 feature IDs, 21 rule IDs, one execution receipt and one direct/alias/indirect shipping-link mutation terminal per rule.

Create importable final-signature V2 generator/checker stubs and a
syntactically valid closed schema in this same RED step. They fail closed with
`qinao.v2-quarantine.unimplemented`.

- [ ] **Step 3: Run RED**

Run:

```bash
python3 -m unittest -v \
  scripts.test_check_qinao_architecture_closure \
  scripts.test_check_qinao_v2_quarantine
```

Expected: both non-empty suites discover and fail only on their exact
`qinao.architecture-closure.unimplemented` or
`qinao.v2-quarantine.unimplemented` diagnostic.

- [ ] **Step 4: Implement ArchitectureClosureReport as a pure projection**

The generator reads owner/status/policy only from Ledger/authority bytes and
joins actual graph/test/release facts by stable IDs. Its CLI is exactly:

```python
parser.add_argument("--root", type=Path, required=True)
parser.add_argument("--ledger", type=Path, required=True)
parser.add_argument("--authority-draft", type=Path, required=True)
parser.add_argument("--reachability", type=Path, required=True)
parser.add_argument("--prior-gate-index", type=Path, required=True)
parser.add_argument("--release-index", type=Path, required=True)
parser.add_argument("--payload-commit", required=True)
parser.add_argument("--payload-tree", required=True)
parser.add_argument("--output", type=Path, required=True)
```

It writes only `--output`, requires that output not be an indexed expected
path, and never changes an input. For preW0,
`--prior-gate-index` contains exactly the six phase-0 plus two phase-1 results.
The generator rejects `qinao.architecture-closure` in that index. The final
nine-row gate index is created only after this output passes its final-phase
module. For each prior result it validates the authenticated contract digest,
resolves `program_by_wave[result.derived_wave]`, and proves the closed program
observations satisfy prior-slice presence and later-slice absence. It neither
infers a program from current source contents nor rewrites a current-wave
result as the W6 program.

- [ ] **Step 5: Implement V2 predicates and conservative edge handling**

Every rule object has exact arrays:

```text
ruleIDs
predicateExecutionReceipts
forbiddenShippingProducts
forbiddenShippingSymbols
forbiddenShippingFields
forbiddenShippingEntryPoints
allowedLabProducts
allowedLabTargets
detectedSourceBytes
shippingReachabilityPaths
labReachabilityPaths
mutationTerminalIDs
```

Allowed-lab sets are explicit and wildcard-free. `shippingReachabilityPaths` is empty. An unresolved alias, selector, protocol erasure, callback, reflection, or dynamic edge expands to all compatible targets or fails; it never becomes a nonmatch by renaming.

- [ ] **Step 6: Add exact mutation coverage**

For each of the 21 rules, create fixtures that:

1. add the direct forbidden declaration/call/dataflow;
2. rename it to a non-keyword alias;
3. route it through protocol erasure/callback/reflection/indirect factory;
4. link it toward one shipping product; and
5. require the checker to fail.

Add global mutations deleting a feature/rule/receipt, adding an unclassified public graph delta, widening a lab root, changing a compilation condition, or substituting a smaller graph root.

- [ ] **Step 7: Exercise only the projection that has complete preparation inputs**

Run:

```bash
python3 scripts/generate_qinao_v2_quarantine.py \
  --root . \
  --reachability /private/tmp/qinao-prew0/qinao-production-reachability-v1.json \
  --payload-commit "$(git rev-parse HEAD)" \
  --payload-tree "$(git rev-parse HEAD^{tree})" \
  --output /private/tmp/qinao-prew0/qinao-v2-quarantine-v1.json

python3 -m unittest -v \
  scripts.test_check_qinao_architecture_closure.QinaoArchitectureClosureTests.test_generator_rejects_unexecuted_gate_index
```

Expected: the V2 preparation projection is written only under `/private/tmp`
and binds the preparation commit/tree; the focused architecture test discovers
one test and proves that an unexecuted/empty gate index is rejected. Task 11
is the first authoritative ArchitectureClosureReport invocation because it
is the first point where exact `Pw`, the eight immutable prior-phase B0 gate
results, and the Ledger-derived empty preW0 release index coexist. That
protected invocation uses only the B0-pinned active module; it does not
import or execute this candidate generator. The candidate tool remains
compare-only proposed-next/parity code. The protected report's own ninth
result and the final nine-row index are created afterward. Do not copy either
preparation output into Git.

- [ ] **Step 8: Run GREEN and commit only schemas/tools/tests**

Run:

```bash
python3 -m unittest -v \
  scripts.test_check_qinao_architecture_closure \
  scripts.test_check_qinao_v2_quarantine
git add \
  docs/superpowers/specs/qinao-architecture-closure-report-v1.schema.json \
  docs/superpowers/specs/qinao-v2-quarantine-v1.schema.json \
  scripts/generate_qinao_architecture_closure.py \
  scripts/check_qinao_architecture_closure.py \
  scripts/test_check_qinao_architecture_closure.py \
  scripts/generate_qinao_v2_quarantine.py \
  scripts/check_qinao_v2_quarantine.py \
  scripts/test_check_qinao_v2_quarantine.py
git commit -m "feat(qinao): derive architecture closure and v2 quarantine"
```

Expected: exactly eight paths; no report/result in the commit.

---

### Task 9: Freeze the 113 Finding Identities and the Evidence-Only Cw Compiler

**Files:**
- Verify without modifying:
  `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json`
- Consume the three temporary Task-2 C1 imports, then delete them in the final
  Task-9 commit:
  - `docs/superpowers/evidence/qinao-plan-remediation-2026-07-18.json`
  - `docs/superpowers/evidence/qinao-review-closure-2026-07-18.json`
  - `docs/superpowers/evidence/qinao-review-findings-source-2026-07-18.txt`
- Create: `docs/superpowers/specs/qinao-finding-ledger-v2.schema.json`
- Create: `docs/superpowers/specs/qinao-finding-proof-leaf-v2.schema.json`
- Create: `docs/superpowers/specs/qinao-cw-evidence-manifest-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-finding-identity-set-v2.json`
- Create: `scripts/build_qinao_cw_evidence.py`
- Create: `scripts/check_qinao_cw_evidence.py`
- Create: `scripts/test_qinao_cw_evidence.py`
- Modify: `scripts/check_qinao_review_candidate.py`
- Modify: `scripts/test_check_qinao_review_candidate.py`
- Modify: `scripts/test_qinao_plan_remediation.py`
- Modify: `scripts/test_qinao_review_closure.py`

**Interfaces:**
- Consumes: exact 74 `QRM-*` source identities, 39 source-block review
  identities, active B0 gate outputs whose contract digests resolve the
  derived-wave `program_by_wave` entries, generated
  reachability/closure/V2/release projections, and exact `Pw` OIDs.
- Produces in `Pw`: identity/schema/parser/compiler bytes plus parity tests that
  consume only the persistent identity projection. Produces after `Pw`: two
  v2 ledgers, 113 proof leaves, aggregate, projections, and self-excluding Cw
  manifest.

- [ ] **Step 0: Reopen the already-reviewed C1 identity sources and make their deletion mandatory**

Task 2 already reviewed and imported the complete ten-row C1 source slice.
Do not edit the map and do not run `--prepare-batch C1` or `--apply-plan`
again. Reverify the frozen source inventory and map, require exactly ten C1
imports, and select the three finding inputs by their decoded raw paths—not
`display_path`.

The three rows must retain:

| Exact path | `source_stratum` | `source_sha256` | `source_mode` | `destination_batch` | `rationale` |
|---|---|---|---|---|---|
| `docs/superpowers/evidence/qinao-plan-remediation-2026-07-18.json` | `worktree` | `58853885646f4d09c17aae8d29e2ad0cd236dadf785bb7335a7663a2fc16b389` | `100644` | `C1` | `authority-input-a-finding-identity-source-only` |
| `docs/superpowers/evidence/qinao-review-closure-2026-07-18.json` | `untracked` | `b65ff9e0069c445941bcd936829d07070a7d84cb4ac81de6772e93832343e27e` | `100644` | `C1` | `authority-input-a-finding-identity-source-only` |
| `docs/superpowers/evidence/qinao-review-findings-source-2026-07-18.txt` | `untracked` | `cfaa56dae40624b78fac5b45dc00dc8b957aada83904de7e0f45ed31fbd61dd5` | `100644` | `C1` | `authority-input-a-finding-identity-source-only` |

Each row must also carry the non-null 64-hex
`reviewer_identity_digest` and canonical UTC `reviewed_at` installed in Task
2. Run:

```bash
python3 scripts/capture_qinao_candidate_inventory.py \
  --root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --verify docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json
python3 scripts/check_qinao_import_map.py \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
git cat-file -e HEAD:docs/superpowers/evidence/qinao-plan-remediation-2026-07-18.json
git cat-file -e HEAD:docs/superpowers/evidence/qinao-review-closure-2026-07-18.json
git cat-file -e HEAD:docs/superpowers/evidence/qinao-review-findings-source-2026-07-18.txt
```

Require all three indexed blobs to be regular mode `100644` with the frozen
SHA-256 values above. Any map/source/digest/reviewer drift stops; it never
triggers a second import.

Cross-validate the review pair before deriving an identity:

```text
closure.source == exact review-findings-source path
closure.source_repository_sha256 == SHA256(raw source bytes)
closure.source_sha256 == SHA256(raw source bytes without exactly one final LF)
closure.source_finding_count == 39
source IDs == B1...B11, M1...M11, m1...m17 in exact order
every closure source_block_sha256 == recomputed exact source-block digest
```

The source-block parser rejects CR, NUL, invalid UTF-8, duplicate/missing/
reordered headers, and extra preamble findings. It splits only at exact
line-start `[ID] ` headers and uses this exact already-reviewed block
projection:

```python
EXPECTED_REVIEW_IDS = (
    "B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8", "B9", "B10", "B11",
    "M1", "M2", "M3", "M4", "M5", "M6", "M7", "M8", "M9", "M10", "M11",
    "m1", "m2", "m3", "m4", "m5", "m6", "m7", "m8", "m9", "m10",
    "m11", "m12", "m13", "m14", "m15", "m16", "m17",
)
if not source_bytes.endswith(b"\n") or source_bytes.endswith(b"\n\n"):
    raise ValidationError("review source must add exactly one terminal LF")
source_text = source_bytes.decode("utf-8")
matches = list(re.finditer(r"(?m)^\[(B\d+|M\d+|m\d+)\] ", source_text))
ids = tuple(match.group(1) for match in matches)
if ids != EXPECTED_REVIEW_IDS:
    raise ValidationError("review source IDs/order differ")
for index, match in enumerate(matches):
    end = matches[index + 1].start() if index + 1 < len(matches) else len(source_text)
    block = source_text[match.start():end]
    block = re.sub(r"(?m)^MAJORS\(11\)\s*$", "", block)
    block = re.sub(r"(?m)^MINORS\(17\)\s*$", "", block).strip()
    digest = hashlib.sha256(block.encode("utf-8")).hexdigest()
    if digest != closure_by_id[ids[index]]["source_block_sha256"]:
        raise ValidationError(f"review source block digest differs: {ids[index]}")
```

One mismatched source, count, ID, or block digest stops the task.

These three imported files are temporary provenance inputs, not `Pw` content
and not Cw results. Step 9 must delete all three in the same commit that adds
the seven final identity/schema/compiler files and migrates all four legacy
checker/test consumers to the persistent identity projection. Later, the
protected runner generates the two same-named JSON result ledgers anew from
exact `Pw` gate results; it never copies these temporary schema-v1 bytes.

- [ ] **Step 1: Write RED tests for identity preservation**

The identity set has exactly:

```json
{
  "schema_version": 2,
  "identity_set_id": "qinao-prew0-findings-v2",
  "source_sets": [
    {
      "source_set_id": "qinao-plan-remediation-2026-07-18",
      "source_digest": "64-lowercase-hex",
      "finding_ids": ["QRM-001"],
      "source_item_digests": [
        {"finding_id": "QRM-001", "source_item_digest": "64-lowercase-hex"}
      ]
    },
    {
      "source_set_id": "qinao-review-closure-2026-07-18",
      "source_digest": "64-lowercase-hex",
      "finding_ids": ["B1"],
      "source_item_digests": [
        {"finding_id": "B1", "source_item_digest": "64-lowercase-hex"}
      ]
    }
  ],
  "admitted_identity_count": 113,
  "unverified_external_report": {
    "reported_count": 45,
    "disposition": "unverified_external_identity",
    "counted_in_admitted_identities": false
  }
}
```

Tests require `QRM-001...QRM-074` exactly, the exact 39 IDs/source-block digests from the immutable review source, global uniqueness, count 113, and external 45 outside every `finding_ids` array. The identity set has no status, disposition per admitted finding, repair, test result, payload OID, or proof leaf.

The QRM `source_digest` is the frozen raw SHA-256
`58853885646f4d09c17aae8d29e2ad0cd236dadf785bb7335a7663a2fc16b389`.
The review `source_digest` is
`framed_digest(b"QINAO-REVIEW-SOURCE-SET-V2\0", [rawClosureBytes,
rawSourceTextBytes])` using Task 3's length framing; before computing it,
raw closure/text SHA-256 must equal
`b65ff9e0069c445941bcd936829d07070a7d84cb4ac81de6772e93832343e27e`
and
`cfaa56dae40624b78fac5b45dc00dc8b957aada83904de7e0f45ed31fbd61dd5`
respectively. Tests mutate each raw source, the terminal LF, every review
header/marker/block, and every closure digest independently.

Create importable final-signature builder/checker stubs plus syntactically
valid closed schema/identity-set stubs in this RED step. Both tools fail
closed with `qinao.cw-evidence.unimplemented`; later RED steps extend tests
against those same stubs.

- [ ] **Step 2: Write RED tests for proof-leaf disposition and Pw binding**

Every child leaf is exactly:

```json
{
  "schema_version": 2,
  "finding_id": "stable-finding-id",
  "source_set_id": "stable-source-set-id",
  "source_item_digest": "64-lowercase-hex",
  "payload_commit_oid": "git-oid",
  "payload_tree_oid": "git-tree-oid",
  "build_identity": "64-lowercase-hex",
  "disposition": {
    "kind": "confirmed",
    "target_finding_id": null
  },
  "positive_discovery": {
    "command_id": "stable-command-id",
    "discovered_count": 1,
    "executed_count": 1,
    "terminal_digest": "64-lowercase-hex"
  },
  "regression_terminal_ids": ["stable-terminal-id"],
  "mutation_terminal_ids": ["stable-terminal-id"],
  "repair_blob_digests": ["64-lowercase-hex"],
  "owner_evidence_ids": ["stable-evidence-id"],
  "privacy_class": "repositorySafe"
}
```

Disposition is the closed tagged union:

```text
confirmed(target_finding_id = null)
duplicateOf(target_finding_id = admitted finding ID)
notReproduced(target_finding_id = null)
supersededBy(target_finding_id = admitted finding ID)
```

All four require non-empty positive discovery/execution, regression terminals, and negative mutation terminals. `confirmed` and `supersededBy` require non-empty repair blob digests and owner evidence. `duplicateOf` targets an earlier canonical admitted identity and independently proves equivalence. `notReproduced` requires an independent negative reproduction terminal in `owner_evidence_ids`; it cannot use an empty scan.

- [ ] **Step 3: Write RED tests for the Cw allowlist and self-exclusion**

Freeze these exact allowed files/prefixes:

```python
EXACT_EVIDENCE_FILES = {
    "docs/superpowers/evidence/qinao-plan-remediation-2026-07-18.json",
    "docs/superpowers/evidence/qinao-review-closure-2026-07-18.json",
    "docs/superpowers/evidence/qinao-finding-closure-v2/aggregate.json",
    "docs/superpowers/evidence/qinao-production-reachability-v1.json",
    "docs/superpowers/evidence/qinao-architecture-closure-report-v1.json",
    "docs/superpowers/evidence/qinao-v2-quarantine-v1.json",
    "docs/superpowers/evidence/qinao-selected-release/preW0-index.json",
    "docs/superpowers/evidence/qinao-gate-results/preW0/index.json",
    "docs/superpowers/evidence/qinao-external-bundles/preW0/index.json",
    "docs/superpowers/evidence/qinao-wave-admission/preW0-cw-manifest.json",
}
ALLOWED_EVIDENCE_PREFIXES = (
    "docs/superpowers/evidence/qinao-finding-closure-v2/children/",
    "docs/superpowers/evidence/qinao-gate-results/preW0/",
)
CW_MANIFEST = (
    "docs/superpowers/evidence/qinao-wave-admission/"
    "preW0-cw-manifest.json"
)
```

Tests reject a source/authority/test/checker change, executable/symlink/non-stage-0 evidence, missing/extra leaf, child count other than 113, a leaf that claims `Cw`, the manifest listing itself, raw external-evidence classes in Git, or evidence binding any payload other than exact `Pw`.

For preW0, the gate-result path set is exactly
`index.json` plus one filename for each of the nine gate IDs obtained from the
authenticated B0 `required_gates_by_wave.preW0` set; filename, internal
`gate_id`, and index row must agree bijectively. The selected-release index has
zero projections because Ledger-derived active profile count is zero. The
external-bundle index has exact
`{"schema_version":1,"payload_commit_oid":PW,"payload_tree_oid":PW_TREE,
"bundle_count":0,"projections":[]}` content because the nine frozen preW0
contracts require only `privacy-clean-gate-result`; a contract that names any
external raw-evidence class makes this zero-bundle construction fail rather
than silently dropping it.

Every projected gate result retains the authenticated `gate_contract_digest`
and `derived_wave`. The compiler reopens that exact contract, resolves its
literal `program_by_wave[derived_wave]`, and rejects an absent/unknown/
ambiguous program, a final-W6 program substituted into an earlier wave, a
missing earlier slice, or a present later-wave identity. It does not rerun,
filter, or compile candidate suites while compiling evidence. Artifact/K4
proof outputs are accepted only when the active contract's deterministic
sensitive-path reuse-or-refresh predicate passed.

The empty selected-release index does not include
`verification_toolchain_profile`: that signed non-shipping value belongs to
the evaluation lease/Xcode27 gate input, not release evidence.

- [ ] **Step 4: Run RED**

Run:

```bash
python3 -m unittest -v scripts.test_qinao_cw_evidence
```

Expected: all intended cases discover and fail only on the asserted semantic
or `qinao.cw-evidence.unimplemented`; no schema, compiler, checker, fixture,
or import is absent.

- [ ] **Step 5: Build the identity set from immutable source records**

The builder reads reviewed source inputs outside the future payload result set, strips remediation/result fields, and computes each source-item digest from canonical identity material:

```python
def qrm_identity(row: dict) -> dict:
    return {
        "finding_id": row["id"],
        "title": row["title"],
        "scope": row["scope"],
    }

def review_identity(row: dict) -> dict:
    return {
        "finding_id": row["id"],
        "source_block_sha256": row["source_block_sha256"],
        "severity": row["severity"],
        "title": row["title"],
        "plan": row["plan"],
    }

def identity_digest(value: dict) -> str:
    return hashlib.sha256(
        b"QINAO-FINDING-IDENTITY-V2\0"
        + len(canonical_json(value)).to_bytes(8, "big")
        + canonical_json(value)
    ).hexdigest()
```

`qrm_identity` is the only QRM projection: it deliberately strips
`status`, `remediation`, and `verification` and admits only
`id/title/scope`. `review_identity` is admitted only after Step 0 has
recomputed the source-file digests and all 39 block digests; it strips
`status`, `remediation`, and `verification` while retaining only the five
fields shown above. Review the generated identity set line by line. No
finding result or claimed repair crosses into `Pw`.

Actual-source ingestion is a preparation-only builder mode with three exact
path arguments and exclusive-create/compare output semantics. Persistent
unit tests exercise the same parser with embedded synthetic fixtures and
verify the committed identity set/digests; they never require the three raw
repository paths to remain present. The ordinary Cw compiler has no source
path argument and consumes only the committed identity set plus protected
gate proof inputs.

Before deleting the raw inputs, run the four C2-era consumers unchanged and
require GREEN:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_review_candidate \
  scripts.test_qinao_plan_remediation \
  scripts.test_qinao_review_closure
python3 scripts/check_qinao_review_candidate.py --root .
```

Then migrate, without weakening their unrelated regressions:

1. `check_qinao_review_candidate.py` replaces the two raw review paths with
   the persistent identity-set/schema/compiler/checker/test paths. It checks
   only regular stage-0 indexed closure and delegates identity semantics to
   the same importable parser used by `check_qinao_cw_evidence.py`; it is
   parity-only because B0's `review_candidate_v2_exact_set` never imports or
   executes it. Its sorted required-path tuple has exactly 29 members: the
   existing 24-member C2 tuple minus the two raw review paths, plus the four
   new schema/identity paths and three Cw builder/checker/test paths.
2. `test_check_qinao_review_candidate.py` freezes that exact new sorted path
   set and proves all three raw paths are forbidden.
3. `test_qinao_plan_remediation.py` retains every controlled-plan and
   mechanical regression, but replaces its schema-v1 status/remediation
   source assertions with exact QRM source-set digest, 74 IDs, and
   source-item-digest projection assertions over the persistent identity
   set. It preserves Task 2A's canonical `needs-confirmation` and
   `BASContextCompiler finalization` assertions and must not infer “fixed”
   from identity presence.
4. `test_qinao_review_closure.py` retains every domain-plan regression, but
   replaces its schema-v1 raw source/closure test with the exact 39-ID,
   source-set digest, source-item-digest, severity/title/plan identity
   projection. No post-migration test opens either deleted JSON or the
   deleted text source.

The preparation-only CLI is exact and has no generic input list:

```text
build_qinao_cw_evidence.py --build-identity-set \
  --qrm-source docs/superpowers/evidence/qinao-plan-remediation-2026-07-18.json \
  --review-closure-source docs/superpowers/evidence/qinao-review-closure-2026-07-18.json \
  --review-text-source docs/superpowers/evidence/qinao-review-findings-source-2026-07-18.txt \
  --identity-set-output docs/superpowers/specs/qinao-finding-identity-set-v2.json
```

It refuses any alternate source path, existing divergent output, missing
terminal LF, or source digest mismatch. An existing byte-identical output is
verify-only success.

- [ ] **Step 6: Implement the two v2 ledger aggregates**

Each v2 ledger contains source identity metadata plus sorted:

```json
{
  "finding_id": "stable-id",
  "proof_leaf_path": "docs/superpowers/evidence/qinao-finding-closure-v2/children/stable-id.json",
  "proof_leaf_blob_sha256": "64-lowercase-hex",
  "disposition_kind": "confirmed"
}
```

The QRM ledger alone retains:

```json
{
  "reported_external_count": 45,
  "count_disposition": "unverified_external_identity"
}
```

The 45 count is not added to `findings`, total, aggregate, or proof leaves.

- [ ] **Step 7: Implement Cw compilation into a temporary tree**

`build_qinao_cw_evidence.py` takes:

```text
--root
--payload-commit
--payload-tree
--identity-set
--finding-proof-input-directory
--reachability
--architecture-closure
--v2-quarantine
--selected-release-index
--gate-results-index
--external-bundle-index
--output-directory
```

It:

1. verifies `payload_commit^{tree} == payload_tree`;
2. reopens every identity/schema/tool from `Pw`;
3. validates exactly 113 proof inputs;
4. reopens every gate contract digest, validates its derived-wave program,
   then canonicalizes two ledgers, 113 leaves, aggregate, and projections;
5. rejects raw external classes and privacy-bearing fields;
6. writes only under a new temporary output directory;
7. creates a self-excluding manifest whose `leaves` list covers every other output path/blob digest;
8. does not compute or serialize a `Cw` commit/tree; and
9. does not touch the Git index.

The aggregate is exact: `schema_version = 2`; the supplied `Pw` commit/tree
OIDs; the compiled identity-set digest; `finding_count = 113`; exact
`source_set_counts = {"qinao-plan-remediation-2026-07-18": 74,
"qinao-review-closure-2026-07-18": 39}`; and
`disposition_counts` with exactly the four keys `confirmed`, `duplicateOf`,
`notReproduced`, and `supersededBy`. Each count is a derived nonnegative
integer, their sum is exactly 113, `unresolved_confirmed_count = 0`, and
`proof_leaf_root` is the Merkle root over the 113 canonical leaf identities.
No example zero-count object is accepted as a substitute for derivation.

- [ ] **Step 8: Implement compare-only Cw validation**

`check_qinao_cw_evidence.py` has two mutually exclusive compare-only modes.
Directory parity accepts exact `Pw` plus disposable bytes:

```text
--root
--payload-commit
--payload-tree
--evidence-directory
```

It validates the closed output set, canonical bytes, payload bindings,
113-leaf aggregate, and self-excluding manifest without writing or computing
a Git object. Imported-object inspection accepts exact `Pw` and
external-service-returned `Cw` OIDs:

```text
--root
--payload-commit
--payload-tree
--evidence-commit
--evidence-tree
```

The imported-object mode uses
`git diff-tree --root --no-renames -r -z`, `git ls-tree -r -z`, and
`git cat-file blob`; it does not read result authority from the worktree. It
is a diagnostic recheck after authenticated host import, never an object or
CAS source. It proves:

```text
parents(cw) == [pw]
tree(pw) == payload_tree
tree(cw) == evidence_tree
changed_paths(cw, pw) == manifest_leaf_paths | {CW_MANIFEST}
manifest_leaf_paths == actual_evidence_paths - {CW_MANIFEST}
all evidence mode == "100644"
all evidence stage/type == regular blob
all leaf payload IDs == (pw, payload_tree)
```

- [ ] **Step 9: Run GREEN and commit identity/schema/compiler bytes only**

Run:

```bash
python3 scripts/build_qinao_cw_evidence.py --build-identity-set \
  --qrm-source docs/superpowers/evidence/qinao-plan-remediation-2026-07-18.json \
  --review-closure-source docs/superpowers/evidence/qinao-review-closure-2026-07-18.json \
  --review-text-source docs/superpowers/evidence/qinao-review-findings-source-2026-07-18.txt \
  --identity-set-output docs/superpowers/specs/qinao-finding-identity-set-v2.json
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_cw_evidence \
  scripts.test_check_qinao_review_candidate \
  scripts.test_qinao_plan_remediation \
  scripts.test_qinao_review_closure
git rm \
  docs/superpowers/evidence/qinao-plan-remediation-2026-07-18.json \
  docs/superpowers/evidence/qinao-review-closure-2026-07-18.json \
  docs/superpowers/evidence/qinao-review-findings-source-2026-07-18.txt
git add \
  docs/superpowers/specs/qinao-finding-ledger-v2.schema.json \
  docs/superpowers/specs/qinao-finding-proof-leaf-v2.schema.json \
  docs/superpowers/specs/qinao-cw-evidence-manifest-v1.schema.json \
  docs/superpowers/specs/qinao-finding-identity-set-v2.json \
  scripts/build_qinao_cw_evidence.py \
  scripts/check_qinao_cw_evidence.py \
  scripts/test_qinao_cw_evidence.py \
  scripts/check_qinao_review_candidate.py \
  scripts/test_check_qinao_review_candidate.py \
  scripts/test_qinao_plan_remediation.py \
  scripts/test_qinao_review_closure.py
test "$(git diff --cached --name-status | wc -l | tr -d ' ')" -eq 14
git diff --cached --name-status
git diff --cached --check
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_cw_evidence \
  scripts.test_check_qinao_review_candidate \
  scripts.test_qinao_plan_remediation \
  scripts.test_qinao_review_closure
python3 scripts/check_qinao_review_candidate.py --root .
git commit -m "feat(qinao): freeze prew0 evidence compiler"
test -z "$(git ls-tree -r --name-only HEAD -- \
  docs/superpowers/evidence/qinao-plan-remediation-2026-07-18.json \
  docs/superpowers/evidence/qinao-review-closure-2026-07-18.json \
  docs/superpowers/evidence/qinao-review-findings-source-2026-07-18.txt)"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_cw_evidence \
  scripts.test_check_qinao_review_candidate \
  scripts.test_qinao_plan_remediation \
  scripts.test_qinao_review_closure
python3 scripts/check_qinao_review_candidate.py --root .
```

Expected: the staged set is exactly three deletions, seven
schema/identity/tool/test creations, and four checker/test migrations. The
commit tree contains none of the three temporary source records; no v2 result
ledger, proof leaf, aggregate, reachability result, closure report, V2 result,
release projection, or gate result. Both post-deletion runs pass without
skipping, reopening a forensic/source worktree, or reading a deleted raw path.

---

### Task 10: Make Governance CI Non-Vacuous and Hand Off Immutable-`Pw` Formation

**Files:**
- Modify: `.github/workflows/test.yml`
- Modify: `scripts/test_check_w0_expected_open_set.py`
- Modify: `scripts/test_test_workflow_owner_ledger.py`
- Create: `scripts/run_nonempty_python_unittest.py`
- Create: `scripts/test_run_nonempty_python_unittest.py`
- Create: `scripts/check_qinao_payload_purity.py`
- Create: `scripts/test_check_qinao_payload_purity.py`
- Create exactly once outside Git:
  `/private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json`
- Create outside Git by read-only host inspection:
  `/private/tmp/qinao-bootstrap-ceremony-v1/required-checks-before-v1.json`
  and `/private/tmp/qinao-bootstrap-ceremony-v1/required-checks-after-v1.json`

**Interfaces:**
- Consumes: all preparation tasks, authenticated B0 proposal, and the
  Task-6-finalized indexed authority bytes.
- Produces: non-vacuous candidate CI and the final authority-finalization
  handoff; Bootstrap Task 10 alone forms the clean `Pw` whose sole parent is
  `B0`, and this task later verifies the returned transaction.

- [ ] **Step 1: Write RED tests for CI discovery and failure propagation**

`run_nonempty_python_unittest.py` accepts repeated `--module` and
`--minimum-tests`. The minimum applies independently to every named module,
not merely to their aggregate. It loads/counts each module, rejects any empty
member before execution, then executes the combined suite once and propagates
every failure/error:

```python
loader = unittest.TestLoader()
module_suites = [
    (name, loader.loadTestsFromName(name))
    for name in modules
]
module_counts = {
    name: module_suite.countTestCases()
    for name, module_suite in module_suites
}
empty = {
    name: count
    for name, count in module_counts.items()
    if count < minimum_tests
}
if empty:
    raise SystemExit(
        "nonempty-unittest: ERROR insufficient="
        + repr(sorted(empty.items()))
        + f" minimum_per_module={minimum_tests}"
    )
suite = unittest.TestSuite(
    module_suite for _, module_suite in module_suites
)
count = sum(module_counts.values())
result = unittest.TextTestRunner(verbosity=2).run(suite)
if not result.wasSuccessful():
    raise SystemExit(1)
print(
    f"nonempty-unittest: PASS modules={len(module_counts)} "
    f"discovered={count} minimum_per_module={minimum_tests}"
)
```

Tests cover zero discovery, one passing test, one failing test, module-load
exception propagation, multiple non-empty modules, and one zero-test module
hidden beside a non-empty module.

First create the final-CLI typed RED seam, then run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_run_nonempty_python_unittest
```

Expected: the suite is discovered and its positive case fails only on
`qinao.nonempty-unittest.unimplemented`. Then replace the stub with the
algorithm above; the import-failure row remains a controlled child-process
fixture, not the RED mechanism.

- [ ] **Step 2: Atomically retire the two premature jobs and add one pinned governance job**

Extend `scripts/test_run_nonempty_python_unittest.py` with a repository
workflow-contract fixture. It extracts the indentation-bounded
`qinao-governance` job from `.github/workflows/test.yml` and requires exactly
one such job, `runs-on: macos-15`, job permissions exactly
`contents: read`, the exact full-length checkout and setup-python action
commit pins shown below, quoted `python-version: "3.12"`, the runtime-version
assertion, and each required governance module exactly once. The extractor
rejects a duplicate job/key, a floating action tag, a broader permission, a
missing module, and a lookalike occurrence outside that job. It uses only the
standard library and treats malformed indentation as failure.

In the same edit, locate the exact indentation-bounded top-level jobs
`owner-ledger` and `k4-platform-proof`, require exactly one of each before the
edit, and delete both complete blocks. Do not retain an alias, disabled copy,
conditional copy, comment-shaped command, or renamed equivalent. The former
owner job executes the non-authoritative sequence-zero open-set machinery,
and the former K4 job asks ordinary CI for a protected physical proof before
W0 has a signed lease; neither has a truthful preW0 success state.

Before changing the workflow, use the authenticated Git-host/ruleset API in
read-only mode to freeze the default branch, every matching protected
ruleset, required-check app IDs/context names, bypass actors, enforcement
state, and raw response digests in
`required-checks-before-v1.json`. No local YAML inference may claim a context
is or is not required. If neither retiring job context is required, two
operators sign that exact observation and the later policy-migration hold is
already satisfied. Otherwise record the exact affected ruleset IDs and stop
before Step 6 until Step 5A completes.

Rewrite `scripts/test_test_workflow_owner_ledger.py` as the workflow
retirement/closure regression. It must assert that both old job IDs are
absent, `qinao-governance` occurs exactly once with the exact pins,
permissions, runtime assertion, and module set below, and no ordinary-CI job
contains a direct invocation of `check_w0_expected_open_set.py` or
`check_k4_platform_proof.py`. The legacy Python unit modules may remain
non-authoritative parser tests; no workflow may treat their CLIs as an
admission gate. K4 runs only through the W0 protected B0
`qinao.k4-platform-proof` program.

Migrate `scripts/test_check_w0_expected_open_set.py` in the same task. Preserve
all synthetic parser, duplicate-key, schema, sequence-zero fixture,
path-containment, log-digest, and mutation coverage. Remove the repository
assertions that require `test.yml` to invoke either latest-series CLI or
require the controlled master/W0 plan to emit successors. Replace them with
the opposite closure assertions: both sequence-zero JSON files remain
readable immutable compatibility fixtures; `test.yml` contains neither old
job nor direct checker CLI; the candidate-indexed 2026-07-23 program master
and the three Task-2-controlled 2026-07-15 convergence-master/Runtime/Silicon
documents name the B0-self-contained 13-suite/16-ID program and forbid
successor/log emission. The sibling 2026-07-23 W0 child is validated by this
program-plan review outside the clean candidate; this repository test must
not read it from the preserved source worktree. No parser predicate is
weakened, and no test treats a sequence-zero fixture as current authority.

Add to `.github/workflows/test.yml`:

```yaml
  qinao-governance:
    name: Qinao authority and evidence contracts
    runs-on: macos-15
    timeout-minutes: 15
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
      - uses: actions/setup-python@a309ff8b426b58ec0e2a45f0f869d46889d02405
        with:
          python-version: "3.12"
      - name: Verify pinned Python runtime
        run: >-
          python3 -c
          'import sys; assert sys.version_info[:2] == (3, 12), sys.version'
      - name: Run non-empty Qinao governance tests
        run: >-
          python3 scripts/run_nonempty_python_unittest.py
          --minimum-tests 1
          --module scripts.test_run_nonempty_python_unittest
          --module scripts.test_check_qinao_authority_convergence
          --module scripts.test_build_qinao_authority_draft
          --module scripts.test_check_qinao_owner_ledger
          --module scripts.test_qinao_owner_ledger_v2
          --module scripts.test_check_qinao_ea_extensions
          --module scripts.test_check_w0_expected_open_set
          --module scripts.test_qinao_build_graph
          --module scripts.test_check_qinao_production_reachability
          --module scripts.test_check_qinao_architecture_closure
          --module scripts.test_check_qinao_v2_quarantine
          --module scripts.test_check_qinao_review_candidate
          --module scripts.test_qinao_plan_remediation
          --module scripts.test_qinao_review_closure
          --module scripts.test_test_workflow_owner_ledger
          --module scripts.test_qinao_cw_evidence
          --module scripts.test_check_qinao_payload_purity
      - name: Check persistent review candidate closure
        run: python3 scripts/check_qinao_review_candidate.py --root .
      - name: Check authority convergence
        run: >-
          python3 scripts/check_qinao_authority_convergence.py
          --root .
          --ledger docs/superpowers/specs/qinao-owner-ledger-v1.json
```

This job has no ref-write, OIDC, signing, device, secret, or admission
permission. The separate `.github/workflows/qinao-wave-admission.yml`
remains the protected B0-pinned OIDC admission client with `contents: read`
and `id-token: write`; this task neither edits nor invokes it, and it still
has no contents/ref write or caller authority. The `test.yml` rewrite is one
atomic tree edit: a state containing any old job beside the new job is
invalid.
Run the focused module once after editing the workflow and require all
workflow-retirement, workflow-contract, and runner cases to pass:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_run_nonempty_python_unittest \
  scripts.test_check_w0_expected_open_set \
  scripts.test_test_workflow_owner_ledger
```

The setup-python pin is the official
[v6.2.0 release commit](https://github.com/actions/setup-python/commit/a309ff8b426b58ec0e2a45f0f869d46889d02405),
cross-checked against its
[official release](https://github.com/actions/setup-python/releases/tag/v6.2.0).
The full-length OID, workflow-contract test, and runtime assertion are all
mandatory. A successful action setup without the exact runtime assertion is
not sufficient evidence.

- [ ] **Step 3: Write RED payload-purity tests and fail-closed stub**

The purity checker has one strict preW0 whole-tree operation and one
predecessor-aware successor-delta operation. It accepts no caller wave. The
strict operation rejects these temporary raw-source and result classes in
preW0 `Pw`:

```python
FORBIDDEN_PW_RESULTS = (
    "docs/superpowers/evidence/qinao-plan-remediation-2026-07-18.json",
    "docs/superpowers/evidence/qinao-review-closure-2026-07-18.json",
    "docs/superpowers/evidence/qinao-review-findings-source-2026-07-18.txt",
    "docs/superpowers/evidence/qinao-finding-closure-v2/",
    "docs/superpowers/evidence/qinao-production-reachability-v1.json",
    "docs/superpowers/evidence/qinao-architecture-closure-report-v1.json",
    "docs/superpowers/evidence/qinao-v2-quarantine-v1.json",
    "docs/superpowers/evidence/qinao-selected-release/",
    "docs/superpowers/evidence/qinao-gate-results/",
    "docs/superpowers/evidence/qinao-external-bundles/",
    "docs/superpowers/evidence/qinao-w0-probe-logs/",
    "docs/superpowers/evidence/qinao-wave-admission/preW0.json",
    "docs/superpowers/evidence/qinao-wave-admission/preW0-cw-manifest.json",
)

LEGACY_W0_PATH_PREFIXES = (
    "docs/superpowers/evidence/qinao-runtime-w0-",
    "docs/superpowers/evidence/qinao-silicon-w0-",
)

LEGACY_W0_FIXTURE_LOCKS = {
    "docs/superpowers/evidence/qinao-runtime-w0-baseline-violations.json":
        ("12b351a8a408eb92a15efed9fdbad784ce65036dea203738cbd5c69ca05270f4", "100644"),
    "docs/superpowers/evidence/qinao-silicon-w0-baseline-correction-2026-07-18.json":
        ("ce4da39703647d66f0a119290c0518f7ca070c3c9e73193902ce3188af3a0ce6", "100644"),
    "docs/superpowers/evidence/qinao-silicon-w0-baseline-violations.json":
        ("355fd3d8b673b8690ea61432bf4387b85b4605781fc1c31dd78d64ef002df3ba", "100644"),
}

LEGACY_W0_SERIES_IDS = frozenset({
    "qinao-runtime-w0-open-set-v1",
    "qinao-silicon-w0-open-set-v1",
})
```

Every path matching a legacy prefix must be one of the three locked rows with
the exact mode/digest, or it fails before parsing. The two first rows are the
sequence-zero compatibility fixtures; the third is the superseded non-series
baseline already present in the approved base. Independently, the checker
parses every bounded regular canonical JSON evidence candidate and rejects a
legacy `series_id` with integer `sequence > 0` at any path; a rename cannot
launder the class. A later task may not rewrite any locked row.

The importable operations are exact:

```text
check_pre_w0_payload_purity(
    root,
    candidate_commit,
    candidate_tree,
) -> PurityResult

check_successor_payload_delta_purity(
    root,
    candidate_commit,
    candidate_tree,
    admitted_predecessor: opaque Bootstrap AdmittedWaveV1,
) -> PurityResult
```

The CLI exposes only the strict first operation through the existing
`--root/--candidate-commit/--candidate-tree` arguments. The successor
operation is callable only in-process after
`ProtectedAdmissionClient.reopen_admitted_predecessor()` returns its opaque,
service-envelope-verified value; no commit, tree, wave, receipt, or result
field can be constructed by a public factory. The checker does not redeclare
that Bootstrap type.

Successor-delta purity derives the next wave from the authenticated
predecessor's closed wave transition, proves candidate commit/tree equality,
requires the candidate to descend from the exact admitted `seal_commit_oid`,
and computes the raw Git tree diff from that seal to the candidate. Every
inherited predecessor evidence path/mode/blob must remain byte-identical.
Strict preW0 forbidden classes are permitted only when they are inherited
unchanged from that authenticated predecessor; an add/modify/delete under
those classes fails. The checker then forbids all derived-current-wave result,
receipt, Cw/Sw, probe-log, external-bundle, selected-release, and
self-claiming payload classes in the delta, and scans the complete candidate
tree for a renamed current-wave self-claim or legacy sequence successor.
Thus an admitted preW0 `Cw/Sw` may be inherited into W0 `Pw`, but a W0 result
cannot pre-exist its evaluation. This operation is candidate preflight only;
the active B0 verifier independently derives the same predecessor/wave from
the lease.

Tests cover every strict forbidden class, all three exact fixture locks,
fixture byte/mode/post-C2 drift, a sequence-1 path under both prefixes, a
renamed successor, a raw probe-log path, inherited preW0 Cw/Sw success,
predecessor evidence modification/deletion, forged/unverified predecessor,
wrong ancestry/tree, current-W0 self-result, and caller-wave attempts.

Create the final-signature checker stub and run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_payload_purity
```

Expected: tests discover and the positive fixture fails only on
`qinao.payload-purity.unimplemented`; no import or fixture is absent.

- [ ] **Step 4: Run CI/purity GREEN**

Replace the payload-purity stub with the exact allow/deny implementation
above, then run:

```bash
python3 -m unittest -v \
  scripts.test_run_nonempty_python_unittest \
  scripts.test_check_qinao_payload_purity
python3 scripts/run_nonempty_python_unittest.py \
  --minimum-tests 1 \
  --module scripts.test_run_nonempty_python_unittest \
  --module scripts.test_check_qinao_authority_convergence \
  --module scripts.test_build_qinao_authority_draft \
  --module scripts.test_check_qinao_owner_ledger \
  --module scripts.test_qinao_owner_ledger_v2 \
  --module scripts.test_check_qinao_ea_extensions \
  --module scripts.test_check_w0_expected_open_set \
  --module scripts.test_qinao_build_graph \
  --module scripts.test_check_qinao_production_reachability \
  --module scripts.test_check_qinao_architecture_closure \
  --module scripts.test_check_qinao_v2_quarantine \
  --module scripts.test_check_qinao_review_candidate \
  --module scripts.test_qinao_plan_remediation \
  --module scripts.test_qinao_review_closure \
  --module scripts.test_test_workflow_owner_ledger \
  --module scripts.test_qinao_cw_evidence \
  --module scripts.test_check_qinao_payload_purity
python3 scripts/check_qinao_review_candidate.py --root .
```

Expected: positive discovered count and all tests pass.

- [ ] **Step 5: Commit CI and purity tools on the preparation branch**

Run:

```bash
git add \
  .github/workflows/test.yml \
  scripts/test_check_w0_expected_open_set.py \
  scripts/test_test_workflow_owner_ledger.py \
  scripts/run_nonempty_python_unittest.py \
  scripts/test_run_nonempty_python_unittest.py \
  scripts/check_qinao_payload_purity.py \
  scripts/test_check_qinao_payload_purity.py
git commit -m "ci(qinao): require non-vacuous governance gates"
```

Expected: exactly seven paths, including both migrated legacy regressions.

- [ ] **Step 5A: Clear the external required-check migration hold**

This is an external hold, not permission for an agent to mutate repository
policy. If the signed before-snapshot says either retiring context is
required, an authorized operator must first run the new pinned
`qinao-governance` job successfully against this exact seven-path commit.
The success observation binds repository, workflow path, job ID, GitHub App
ID, head OID, action pins, Python version, conclusion, run attempt, and host
response digest.

Only then may two separately authorized operators replace the affected old
required contexts with that exact new context in one provider-supported
ruleset transaction. If the host lacks atomic multi-context replacement,
require the new context first, verify it, and remove the old contexts second;
merges remain blocked during the interval, and no interval may have neither
old nor new governance context required. Reopen host policy into
`required-checks-after-v1.json` and prove every unrelated rule/bypass actor is
byte-identical, the new context is required exactly once, and both old
contexts are absent. If the old contexts were not required, prove the signed
before/after snapshots are policy-identical.

Until that proof exists, stop with
`BLOCKED_EXTERNAL_BOOTSTRAP/BRANCH_PROTECTION_CONTEXT_MIGRATION`; do not form
the authority-finalization handoff or admit preW0.

- [ ] **Step 6: Freeze the preparation tip and return its exact tree**

Require:

```bash
test -z "$(git status --porcelain=v1)"
python3 scripts/check_qinao_payload_purity.py \
  --root . \
  --candidate-commit "$(git rev-parse HEAD)" \
  --candidate-tree "$(git rev-parse HEAD^{tree})"
git fsck --no-reflogs --full
```

Recompute every digest from the final indexed bytes and authenticated Output
B; do not accept a value copied from a worker or an earlier Task-6 process.
Write a temporary canonical JSON value with one LF:

```json
{
  "schema_version": 1,
  "preparation_tip_oid": "git-oid",
  "preparation_tree_oid": "git-tree-oid",
  "wave_admission_projection_sha256": "64-lowercase-hex",
  "owner_ledger_sha256": "64-lowercase-hex",
  "authority_bundle_digest": "64-lowercase-hex",
  "controlled_contract_catalog_digest": "64-lowercase-hex"
}
```

Set `preparation_tip_oid` and `preparation_tree_oid` to this clean final
tip/tree. If the target is absent, exclusively install the file at the exact
path above with mode `0600`. If it already exists, require a regular,
non-symlink mode-`0600` file with byte-identical canonical contents and treat
that as the sole idempotent retry; never overwrite or delete a divergent
value. Reopen it and byte-compare all fields to the indexed tree and
authenticated export. Do not add it to Git.

Return this handoff to the program orchestrator and stop. The separately
scheduled Bootstrap Task 9 Steps 3-4 must perform the two protected reads and
return the same preparation commit/tree and projection digest. Any missing or
divergent file, digest mismatch, tree drift, or unequal double-read returns to
Hold C. This step does not invoke or resume Bootstrap code itself.

- [ ] **Step 7: Consume the sole lineage-transaction owner's verified return**

Stop this plan's mutation authority. The orchestrator must already have
scheduled Bootstrap Task 10 exactly once after Bootstrap Task 9 Steps 3-4
and returned here with its verified applied-lineage plan. Only Bootstrap Task
10 may build the reparented commit, create the two forensic refs, or update
`refs/heads/codex/qinao-w1-clean-candidate`. This plan must not call
`--plan-payload-lineage`, `--apply-lineage-plan`, `git update-ref`, or any
equivalent Git-ref operation.

Required return from Bootstrap Task 10:

```text
lineage disposition = reparentedProgram
authority-finalization input = byte-identical Step-6 handoff
original forensic ref = audited 22-commit tip
preparation forensic ref = final preparation tip
Pw tree = final preparation tree
parents(Pw) = [B0]
transaction application count = 1
```

Any `ALREADY_APPLIED` return is accepted only when Bootstrap's frozen
inspector proves the complete exact transaction state byte-for-byte. A partial
or divergent state remains quarantined. Step 7 only consumes and verifies the
immediately preceding return; it never invokes the transaction a second time.

- [ ] **Step 8: Verify `Pw` topology, bytes, and purity**

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --expect-candidate-lineage reparentedProgram \
  --require-clean
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-proposal /private/tmp/qinao-bootstrap-ceremony-v1/b0-proposal-v1.json
python3 scripts/verify_qinao_bootstrap_export.py \
  --request /private/tmp/qinao-bootstrap-ceremony-v1/ceremony-request-v1.json \
  --export-directory /private/tmp/qinao-bootstrap-ceremony-v1/export
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-authority-finalization \
  /private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json \
  --signed-projection \
  /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-applied-lineage \
  /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json

PW="$(git rev-parse refs/heads/codex/qinao-w1-clean-candidate)"
B0="$(git rev-parse "$PW^")"
test "$(git rev-list --parents -n 1 "$PW" | awk '{print NF}')" -eq 2
test "$(git rev-parse "$PW^")" = "$B0"
test "$(git rev-parse "$PW^{tree}")" = \
  "$(python3 -c 'import json; print(json.load(open("/private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json"))["preparation_tree_oid"])')"
python3 scripts/check_qinao_payload_purity.py \
  --root . \
  --candidate-commit "$PW" \
  --candidate-tree "$(git rev-parse "$PW^{tree}")"
```

Expected: the root guard reports `reparentedProgram`; the proposal, signed
bootstrap export, signed-projection authority handoff, and applied lineage
reopen to the same B0/Pw tuple; all topology/purity commands pass; and no
evidence result claims `Pw`.

---

### Task 11: Prove Disposable Parity, Then Run the Protected `Pw` Evaluation

**Files:**
- Create only outside Git: `/private/tmp/qinao-cw-parity-v1/{Pw}/`.
- Create only in the protected runner's private run directory: the exact
  result bundle described by handoff C.
- Create no Git commit, tree, blob, index, tag, branch, or proposal ref.

**Interfaces:**
- Candidate parity consumes exact `Pw`, synthetic/recorded non-authoritative
  fixtures, and the checked-in schemas/compiler. It produces only disposable
  bytes and a comparison report.
- The predecessor-derived protected runner consumes a server-signed
  `EvaluationLease` whose subject is exact `Pw`. It produces the closed
  verified evidence bundle; it does not produce `Cw`, `Sw`, a receipt, an
  admission intent, or a ref update.
- The external service consumes only that authenticated bundle plus values
  already frozen in the lease. Candidate parity output is never uploaded or
  consulted.

- [ ] **Step 1: Reopen exact `Pw` and prove the post-reparent boundary**

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --expect-candidate-lineage reparentedProgram \
  --require-clean
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-proposal /private/tmp/qinao-bootstrap-ceremony-v1/b0-proposal-v1.json
python3 scripts/verify_qinao_bootstrap_export.py \
  --request /private/tmp/qinao-bootstrap-ceremony-v1/ceremony-request-v1.json \
  --export-directory /private/tmp/qinao-bootstrap-ceremony-v1/export
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-applied-lineage \
  /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json

PW="$(git rev-parse refs/heads/codex/qinao-w1-clean-candidate)"
PW_TREE="$(git rev-parse "$PW^{tree}")"
test "$(git rev-list --parents -n 1 "$PW" | awk '{print NF}')" -eq 2
python3 scripts/check_qinao_payload_purity.py \
  --root . \
  --candidate-commit "$PW" \
  --candidate-tree "$PW_TREE"
```

Expected: all commands pass and no result byte claiming `Pw` exists in its
tree.

- [ ] **Step 2: Prove the candidate compiler in disposable parity mode**

The focused suite must build a complete synthetic 113-finding bundle twice
under two new temporary directories, require byte-identical output, and then
mutate every allowlisted class once:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_cw_evidence
```

Expected:

```text
qinao-cw-builder: PASS findings=113 qrm=74 review=39 unresolved_confirmed=0
qinao-cw-evidence: PASS mode=directory-parity findings=113 evidence_only=true self_excluding_manifest=true
```

`directory-parity` is a required separate checker mode:

```text
--root
--payload-commit
--payload-tree
--evidence-directory
```

It reads no result from the worktree and performs no Git write. Tests monkey
patch process execution and fail if the builder/checker invokes
`git hash-object -w`, `git mktree`, `git commit-tree`, `git update-ref`,
`git push`, or a Git-host API. A parity directory is deleted after the test
and cannot be an assembly, object-import, CAS, or attestation input.

- [ ] **Step 3: Start protected evaluation with `Pw`, never with a proposed seal**

Use only the four-method `ProtectedAdmissionClient` imported from the
bootstrap sibling. After separate authorization for the external payload
object write, the client asks the service to pin exact `Pw`; the service
reopens the commit/tree/object closure at the Git host and returns the signed
`PayloadProposalReceiptV1` plus signed `EvaluationLease`. It persists one
append-only dispatch intent and creates one opaque, create-once
`refs/heads/qinao-admission-runs/<service-request-id>` ref at B0. That
zero-input `push` event starts the immutable B0 workflow.

The event and runner request contain no payload OID. The service maps the
authenticated run ref/OIDC tuple back to the dispatch intent and derives exact
`Pw` only from its signed proposal receipt. It separately derives repository,
canonical ref, `preW0`, prior `B0`, profiles, verifier, modules, policy, and
output contract. `Cw` and `Sw` do not yet exist.

The only launch call is:

```text
proposal_receipt, evaluation_lease =
  ProtectedAdmissionClient.pin_payload_and_issue_lease(Pw)
```

Both returned envelopes, their identical payload commit/tree, the
content-addressed proposal ref, and host-reopen observation must validate
before the runner accepts the lease.

The opaque values are not candidate checkpoints. After a process/session
restart, rerun the permanent root guard, require the clean immutable
`Pw/Pw_TREE`, and invoke
`pin_payload_and_issue_lease(Pw)` again. For preW0, Bootstrap's
repository/B0/payload idempotency key must return the original authenticated
proposal receipt and original opaque lease/evaluation; the service itself
reopens the same authenticated `BootstrapRootV1`. The verification adapter
proves that existing record before any gate resume. No local serialization,
new lease, or new evaluation is legal.

Before any gate runs, the runner must independently prove:

```text
evaluation_lease.evaluation_subject_oid == Pw
evaluation_lease.payload_commit_oid == Pw
evaluation_lease.payload_tree_oid == Pw^{tree}
evaluation_lease.prior_seal_oid == B0
evaluation_lease.derived_wave == preW0
evaluation_lease.required_gate_rows == exact authenticated preW0 set
evaluation_lease.active_gate_rows == exact authenticated preW0 set
evaluation_lease.cw_output_contract_digest == authenticated closed contract
evaluation_lease.source_import_review_audit_root_digest ==
  authenticated_bootstrap_attestation.source_import_review_audit_root_digest
evaluation_lease.source_import_review_audit_root_digest ==
  authenticated_authority_output_b.source_import_review_audit_root_digest
```

Before issuing the lease, the external service alone recomputes this value
with its service-owned opaque C1/C2 verifier and audit-root compiler, then
compares it to authenticated Output B and the finalized bootstrap attestation.
The runner only compares the signed digest fields above. Neither B0 nor
candidate code imports `scripts/qinao_import_review_v1.py`, parses a record
into a second wire, or constructs an audit root from import-map fields. The
same digest must byte-match the authenticated gate-result bundle and the exact preW0 Sw
receipt.

The workflow has `contents: read` and `id-token: write` only. Its runner
accepts no CLI authority selector and has no repository-write, Git App,
evidence-store, CAS, or attestation credential.
Its protected group plus `qinao-xcode27-arm64-v1` label only routes the job;
the signed lease and fresh service-verified host quote independently bind the
exact verification profile and isolation before evaluation.

For this zero-input run-ref `push` path, the admission service requires this
closed authority-binding OIDC claim set:

```text
repository
repository_id
workflow_ref
workflow_sha
sha
ref
environment
runner_environment
run_id
run_attempt
```

It rejects a missing, extra-for-authority, differently normalized, or
lease-inconsistent authority-binding claim and requires
`workflow_sha == sha == B0`. `ref` is exactly the dispatch intent's opaque
create-once run ref, `workflow_ref` names the same B0 workflow at that ref,
and Git-host audit proves the service principal created it at B0.
Repository identity, environment, runner environment, run ID, and attempt
must equal the values frozen in the signed dispatch/lease chain. This direct
push workflow neither requires nor accepts reusable-workflow identity claims
as authority.

- [ ] **Step 4: Execute only predecessor-derived modules over exact `Pw`**

Call the exact bootstrap-owned method once for this evaluation:

```text
gate_results =
  ProtectedAdmissionClient.run_active_gates(evaluation_lease)
```

The returned `gate_results` is an opaque
`AuthenticatedGateResultBundle`. A same-lease recovery call is an idempotent
query/resume of this evaluation: once a terminal bundle exists it returns the
byte-identical authenticated bundle and never repeats a physical effect. A new
lease or second evaluation is forbidden. In a new process, first execute Step
3's idempotent pin/lease rehydration, then use only that service-recovered
`evaluation_lease` in this call.

The B0 verifier materializes exact Git objects in isolation and executes the
lease-bound preW0 DAG exactly. For each required gate it authenticates the
contract, resolves the literal `program_by_wave["preW0"]` to exactly one
closed program, and never substitutes that gate's W6/final program:

```text
phase0:
  qinao.ios27-floor
  qinao.owner-ledger
  qinao.plan-remediation
  qinao.production-reachability
  qinao.review-candidate
  qinao.xcode27-toolchain
phase1:
  qinao.review-closure
  qinao.v2-quarantine
phase2:
  qinao.architecture-closure
```

Gates within a phase may run concurrently. Each later phase consumes one
immutable canonical index of all prior-phase results. ArchitectureClosure is
the sole final phase: it consumes the eight prior gate results and their
outputs, never its own result and never a not-yet-created final gate-result
index. Only after ArchitectureClosure passes does the runner canonicalize the
final nine-row index. The runner rejects a missing/extra/reordered phase,
same-phase dependency, cycle, or candidate-supplied DAG.

The verifier emits one `GateResult` for every authenticated preW0 gate. Every
result must bind:

```text
lease_id
gate_id
derived_wave = preW0
payload_commit_oid = Pw
payload_tree_oid = Pw tree
gate_contract_digest
module_bundle_digest
corpus_digest
discovered_subject_count > 0
executed_predicate_count > 0
positive_case_count > 0
negative_case_count > 0
mutation_case_count > 0
result = passed
evidence_outputs
evidence_bundle_digest
```

For preW0, the authenticated required-gate cardinality is nine. The Xcode27
gate binds the signed non-shipping `verification_toolchain_profile`, not a
selected release, and requires its fresh host quote rather than trusting the
runner label. The runner rejects missing/extra/duplicate rows, zero
discovery/execution, a same-wave candidate module, a candidate import, wrong
`Pw`, wrong corpus, or any noncanonical/privacy-bearing output.

- [ ] **Step 5: Close the authoritative evidence-output set before upload**

The protected runner, using B0-pinned assembly code, derives:

```text
2 v2 source ledgers
113 proof leaves
1 finding aggregate
1 production-reachability projection
1 ArchitectureClosureReport
1 V2-quarantine projection
1 selected-release preW0 index with zero projections and no verification profile
1 gate-result preW0 index plus exactly 9 result projections
1 external-bundle preW0 index with zero projections
1 self-excluding Cw manifest
```

The Cw manifest covers every other output path/blob digest and excludes
itself. Every output binds exact `Pw/Pw_TREE`; no output names or predicts
`Cw` or `Sw`. Each upload row has exactly:

```text
path
mode = 100644
blob_sha256
size_bytes
```

This four-field row is only the content-upload manifest. It is not the
Bootstrap-owned `EvidenceOutput` receipt and cannot supply producer, step,
schema, class, or cap. The service joins it by exact path to the authenticated
`GateResult.evidence_outputs` row and active Cw assembly tuple, requires
blob/mode/size equality and `size_bytes <= maximum_bytes`, and rejects any
missing, duplicate, or conflicting join.

The runner computes `verified_evidence_bundle_digest` over the closed,
canonically sorted row set and uploads the row set plus corresponding bytes
under its authenticated lease. It uploads no local Git object or ref.

- [ ] **Step 6: Require the external service to reject candidate authority**

The service must reject an upload containing any of:

```text
candidate parity path or digest
candidate-created Cw/Sw/tree/blob/pack
proposal ref
caller commit identity or timestamp
caller receipt field
caller wave/ref/profile/verifier/module/policy
missing or extra evidence output
path/mode/size/digest mismatch
raw archive/device/CMS/profile/trace byte
```

Only a complete byte-valid bundle matching the lease-bound
`cw_output_contract_digest` may enter Task 12. A failed or interrupted run is
one exact master `BLOCKED_*` terminal or a recoverable same-lease evaluation
under the bootstrap sibling state machine; it does not produce a partial Cw.

---

### Task 12: Let the External Service Assemble `Cw/Sw`, Then Verify Admission

**Files:**
- Create only by the external service in Cw: the exact Cw output paths in the
  File Responsibility Map.
- Create only by the external service in Sw:
  `docs/superpowers/evidence/qinao-wave-admission/preW0.json`.
- Create no candidate-local Git object or ref.

**Interfaces:**
- Consumes: exact `Pw`, signed `EvaluationLease`, complete verified evidence
  bundle, active B0 bindings, and fresh authenticated live-protection
  observation.
- Produces externally: deterministic `Cw`, deterministic one-receipt `Sw`,
  immutable object-import receipt, immutable `AdmissionIntent`, protected CAS
  audit, and finalized admission attestation.
- Returns to the runner only an authenticated `AdmittedWaveV1` on the
  service's internal `finalized` state. Otherwise the client raises the
  Bootstrap-owned closed `AdmissionTerminalError`, carrying exactly
  `pendingAdmission`, `quarantinedAdmission`, or one master `BLOCKED_*`
  terminal. Every blocked/quarantined value carries one registry-closed reason
  code; only pending carries null. `EvidenceAssemblyResult`
  remains service-internal.

- [ ] **Step 1: Freeze the exact preW0 receipt value**

The receipt uses
`docs/superpowers/specs/qinao-wave-admission-receipt-v1.schema.json` and
contains exactly:

```text
schema_version
receipt_id
admitted_wave
predecessor_wave
predecessor_receipt_blob_digest
predecessor_seal_commit_oid
predecessor_admission_attestation_digest
predecessor_admission_chain_digest
payload_commit_oid
payload_tree_oid
evidence_candidate_commit_oid
evidence_candidate_tree_oid
authority_bundle_digest
owner_ledger_digest
controlled_contract_catalog_digest
source_import_review_audit_root_digest
selected_release_build_identities
active_gate_module_bundles
proposed_next_gate_module_bundles
gate_receipts
active_verifier_bundle_digest
proposed_next_verifier_bundle_digest
gate_result
created_at
```

For preW0, predecessor receipt/seal/attestation and predecessor wave are
`null`; predecessor chain digest is exactly 64 zeroes; selected-release
identities are the Ledger-derived empty set; every active module comes from
B0; every required gate receipt binds exact `Pw`; `gate_result = passed`;
`source_import_review_audit_root_digest` byte-equals the opaque read-only
projection carried by the authenticated lease and gate-result bundle; and
`created_at` equals the lease-frozen `receipt_created_at`. The service derives
every field; the runner/candidate supplies none. Authority code may compare
this digest but may not parse review records or build a competing audit root.

- [ ] **Step 2: Freeze deterministic service commit identities**

Consume, without redeclaring, the bootstrap sibling's closed
`CommitIdentity` value:

```text
author_name
author_email
authored_at
committer_name
committer_email
committed_at
message
```

The signed evaluation lease contains one `cw_commit_identity` and one
`sw_commit_identity`. Require:

```text
cw_commit_identity.message == "qinao preW0 evidence"
sw_commit_identity.message == "qinao preW0 admission seal"
within each identity, author/committer name and email equal the service identity frozen before lease issue
the four authored/committed timestamps across both identities are normalized Git timestamps frozen before gate execution
retry of the same lease returns byte-identical identities and receipt_created_at
```

Neither wall clock at assembly time, machine Git config, locale, runner
identity, candidate value, nor retry count may affect a commit byte. The
external service conformance suite constructs each object twice from the same
lease/bundle and requires byte-identical Cw tree/OID, receipt blob, Sw
tree/OID, and object-set digest.

- [ ] **Step 3: Assemble Cw and Sw only inside the external service**

The service performs this exact order:

1. reopens exact host-side `Pw` and proves `Pw^{tree} = payload_tree_oid`;
2. validates the complete upload against `cw_output_contract_digest`;
3. creates regular blobs for the exact Cw output set;
4. derives `Cw_TREE = Pw_TREE + exact evidence-only diff`;
5. creates one-parent `Cw(parent = Pw)` with lease
   `cw_commit_identity`;
6. canonicalizes the exact receipt using service-derived `Cw/Cw_TREE`;
7. derives `Sw_TREE = Cw_TREE + exactly preW0.json`;
8. creates one-parent `Sw(parent = Cw)` with lease
   `sw_commit_identity`; and
9. repeats the derivation and rejects any OID drift before import.

No candidate shell runs `git hash-object -w`, `git mktree`,
`git commit-tree`, `git update-ref`, or `git push`. A candidate-local parity
OID, if a test ever computes one in a disposable repository, is ignored and
cannot be an import or CAS input.

- [ ] **Step 4: Import and host-reopen both objects before creating intent**

Use only the bootstrap sibling's
`qinao-git-object-import-receipt-v1.schema.json`; do not create a shadow
receipt here. The immutable receipt must bind:

```text
repository identity
lease ID and exact Pw/Pw_TREE
exact Cw/Cw_TREE and Sw/Sw_TREE
receipt blob digest
uploaded pack/object-set digest
authenticated Git-host import transaction/audit identity
host reopen observation and timestamp
```

The service imports through its authenticated Git-host integration, reopens
all commits/trees/blobs from the host, recomputes the exact parent/diff/mode
constraints, and persists the signed append-only object-import receipt.
Only then is the tuple eligible for intent creation in Step 6; no
`EvidenceAssemblyResult` exists yet because its closed type contains the
not-yet-created `admission_intent_id`. Runner-local object availability, a
local ref, or successful parity comparison cannot replace host reopen.

- [ ] **Step 5: Run candidate diagnostics without fabricating authority**

The candidate can rerun directory parity and the existing offline admission
preflight:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_cw_evidence

set +e
QINAO_PREFLIGHT_OUTPUT="$(
  python3 scripts/check_qinao_wave_admission.py \
    --mode preflight \
    --bootstrap /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json \
    --repository-root .
)"
QINAO_PREFLIGHT_STATUS="$?"
set -e
test "$QINAO_PREFLIGHT_STATUS" -eq 2
QINAO_PREFLIGHT="$QINAO_PREFLIGHT_OUTPUT" python3 -c '
import json
import os

value = json.loads(os.environ["QINAO_PREFLIGHT"])
assert value["status"] == "preflight"
assert value["result"] == "blocked"
assert value["authority"] == "none"
assert value["blocker"]["code"] == "external_attestation_authentication_unavailable"
'
```

This blocker means the candidate process lacks external attestation
authentication; it does not claim the Cw allowlist is unavailable. If the
protected runner calls the service, internal `finalized` returns
`AdmittedWaveV1` and maps to `admitted`; an incomplete known CAS maps to
`AdmissionTerminalError(terminal="pendingAdmission", reason_code=None)`; a lineage disagreement
maps to the same error with `terminal = quarantinedAdmission`; and internal
`blocked` maps to the same error with one exact master `BLOCKED_*` terminal
plus a closed reason code. The runner cannot widen the return type or rewrite
any of those as candidate preflight.

- [ ] **Step 6: Create intent, CAS, and finalize only after object import**

Invoke only the bootstrap-owned final operation:

```text
admittedPreW0 =
  ProtectedAdmissionClient.assemble_import_and_finalize(
      evaluation_lease,
      gate_results
  )
```

If this step is entered in a new process, first rerun Step 3's exact
root/Pw/idempotent-pin sequence and Step 4's same-evaluation query/resume to
recover the original opaque `evaluation_lease` and byte-identical
`gate_results`. Candidate files or process memory can never rehydrate either
value.

This call is the sole owner of assembly, import, intent, CAS, reconciliation,
and finalization. Repeating it with the same lease and byte-identical bundle is
idempotent same-intent recovery; it cannot create a new object identity,
intent, CAS transaction, or attestation. A caller must not decompose or retry
its internal steps.

Before requiring expected-old `B0`, the service executes a closed recovery
oracle. If the canonical ref is still `B0`, it proceeds with the original
intent. If the current authenticated admission is already `preW0` with exact
`payload_commit_oid == Pw` and byte-valid seal/CAS/final attestation, it returns
that byte-identical `admittedPreW0` without another pin, assembly, intent, or
CAS. Any other current ref/payload/chain state raises
`AdmissionTerminalError(terminal = quarantinedAdmission,
reason_code = IDENTITY_MISMATCH)`. Thus a crash after CAS/final attestation but before client return is recoverable and no
candidate-side old-ref assertion can preempt service reconciliation.

The service obtains a fresh authenticated branch-protection observation,
creates one immutable `AdmissionIntent`, and freezes one fast-forward CAS
tuple:

```text
expected old OID = B0
new OID = Sw
canonical ref = refs/heads/qinao-admitted
```

The intent idempotency key binds repository, canonical ref, `preW0`, B0,
Sw, receipt blob, active verifier, and live-policy observation. After
durably creating that intent, the service persists the bootstrap sibling's
signed, internal-only `EvidenceAssemblyResult` with exactly:

```text
lease_id
payload_commit_oid
payload_tree_oid
evidence_commit_oid
evidence_tree_oid
seal_commit_oid
seal_tree_oid
receipt_blob_sha256
git_object_import_receipt_digest
admission_intent_id
```

The internal result is valid only when `admission_intent_id` identifies this
immutable intent and the already-persisted import receipt digest equals
`git_object_import_receipt_digest`. It is never returned through
`ProtectedAdmissionClient`. The service then attempts CAS. After successful
CAS, the Git host/OIDC issuer finalizes the same intent. Only
`canonical ref = Sw` plus its byte-matching finalized external attestation
causes the client to return `admittedPreW0: AdmittedWaveV1`. A crash after CAS
but before attestation is `pendingAdmission`; no next wave may derive until
deterministic same-intent recovery succeeds.

- [ ] **Step 7: Reopen the finalized tuple and preserve recovery semantics**

The protected service, not a candidate checker, verifies:

```text
canonical ref equals Sw
CAS audit matches the immutable intent
object-import receipt predates and binds the intent
final attestation repository/ref/wave/prior/new/receipt/verifier/policy match
Sw has one parent Cw
Sw differs by exactly one regular preW0 receipt
Cw has one parent Pw
Cw differs only by the closed evidence allowlist
every Cw leaf binds Pw and no leaf claims Cw
Pw has one parent B0
```

The runner then calls
`ProtectedAdmissionClient.reopen_admitted_predecessor()` and requires that
the reopened `AdmittedWaveV1` is byte-identical to `admittedPreW0`. Any
different envelope, seal, chain digest, intent, CAS transaction, or finalized
attestation raises `AdmissionTerminalError(terminal = quarantinedAdmission,
reason_code = ATTESTATION_MISMATCH)`, never a locally repaired success.

Then compute the through-admission digest externally:

```text
SHA256(
  "qinao-wave-admission-chain-v1\0"
  || predecessorDigest
  || "\0" || SwOID
  || "\0" || receiptBlobSHA256
  || "\0" || admissionAttestationSHA256
)
```

Do not write this digest into `Pw`, `Cw`, or `Sw`; it is input only to the
next candidate. Unknown CAS, competing successor, stale observation,
post-CAS pre-attestation crash, duplicate finalize, and mismatched host audit
follow the bootstrap sibling's total recovery oracle; mismatch quarantines
and never causes a fresh locally assembled seal.

---

## Exact Candidate and Protected Commands Summary

Candidate-local diagnostics:

```bash
python3 scripts/check_qinao_authority_convergence.py \
  --root . \
  --ledger docs/superpowers/specs/qinao-owner-ledger-v1.json

python3 scripts/check_qinao_owner_ledger.py \
  --root . \
  --ledger docs/superpowers/specs/qinao-owner-ledger-v1.json \
  --bootstrap /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json \
  --declared-contracts /private/tmp/qinao-prew0/declared-contracts.json \
  --production-reachability /private/tmp/qinao-prew0/qinao-production-reachability-v1.json

python3 scripts/check_qinao_ea_extensions.py \
  --root . \
  --manifest docs/superpowers/specs/qinao-extension-identity-catalog-v1.json \
  --payload-commit "$(git rev-parse HEAD)" \
  --payload-tree "$(git rev-parse HEAD^{tree})"
```

Run admission diagnostics only through Task 12 Step 5's status-capturing
wrapper: exit `2` plus
`external_attestation_authentication_unavailable` is the required
candidate-local result, not a shell-success command.

Only the external admission service may create/import `Cw/Sw`, persist the
object-import receipt, create the intent, perform CAS, or finalize the
attestation. The protected runner is read-only with respect to Git and only
evaluates/uploads/polls. Local success remains `preflight`.

## Plan Self-Review Results

- [x] **Spec coverage:** Sections 0, 2.5, 6.11, 11.1, 12.2 C1/C2, 13, 14.1-14.3, 16.1/11-13/20/22/28-29, and 17.1 of the approved correction design map to Tasks 1-12 including the explicit interposed Task 2A.
- [x] **Scope boundary:** C0/bootstrap internals remain in the bootstrap sibling; W0/K4 remain in their sibling; Artifact Mesh implementation remains in its W1 Task-0 sibling. This plan supplies their authority/E/A/Cw interfaces only.
- [x] **Authority membership:** exactly 7 controlled documents plus 4 addenda; correction/companion/CoreAI/new master remain outside those arrays.
- [x] **Input-A cycle:** the sole Ledger first carries the complete catalog as transitional, unadmitted schema-v1 input; Input A digests those exact bytes; schema v2 preserves the row array byte-for-byte and never regenerates it after Output B.
- [x] **Ledger dispatch:** all four schema-v2 machine sections plus 29 recovery profiles are semantically validated; no unconditional scaffold blocker remains.
- [x] **Catalog equality:** Ledger/document refs are exact reciprocal quadruples with one reference block and one term anchor per required ref.
- [x] **Lifecycle:** baseline freeze, closed transition graph, absent-row protocol, declared/active cumulative equalities, and active-profile uniqueness are explicit.
- [x] **Wave programs:** all 19 contracts retain literal `program_by_wave` mappings; every preW0 gate resolves one predecessor-authenticated program, the six staged domain gates use cumulative present/absent slices, and ArchitectureClosure is the sole final phase.
- [x] **E/A boundary:** five content-intake templates and exactly seven authorized-input/remote templates contain 25 singular slices under one generic schema/checker/path convention; no M/Create input exists.
- [x] **Reachability:** roots/profiles are internally derived; XcodeGen is semantically regenerated; remote dependency reachability requires indexed `Package.resolved`; generator never overwrites expected output.
- [x] **Finding provenance:** the 74+39 identity source records enter through one reviewed C1 import, bind three frozen raw digests plus every review block digest, project only content-free identity fields, and are deleted before `Pw`.
- [x] **Evidence boundary:** `Pw` has no self-claiming results; the protected runner emits only a closed `Pw`-bound bundle; the external service alone assembles/imports `Cw` with exactly 113 leaves and exact projections, then `Sw` with one receipt; the manifest excludes itself.
- [x] **One-way service order:** host import/reopen and immutable object-import receipt precede intent; intent precedes signed `EvidenceAssemblyResult`; only then may CAS and matching final attestation occur.
- [x] **OIDC boundary:** the zero-input create-once run-ref push uses the closed ten-claim authority set, binds `workflow_sha == sha == B0`, and neither accepts reusable-workflow identity claims nor grants the runner repository-write authority.
- [x] **Finalization timing:** no partial authority-finalization object exists; the clean final preparation tree is recomputed, exclusively installed or byte-identically reopened, double-read by bootstrap, and only then reparented.
- [x] **Non-vacuity:** every suite/checker asserts positive discovery/counts and propagates failures through CI; the governance job pins and runtime-checks Python 3.12.
- [x] **Raw-content posture:** content-free default and signed Decision-Gate precedence are enforced in authority, CoreAI traceability, tests, and negative checks.
- [x] **Unspecified-work scan:** no executable step depends on an unspecified path, interface, field set, command, wave argument, or future digest supplied by a worker.
- [x] **Type consistency:** `document_id`, `(contract_id, version)`, `required_term_id`, `introduction_wave`, `activation_wave`, `workWave`, payload OIDs, evidence OIDs, and manifest fields retain one spelling across every task.
- [x] **Final execution gate:** preparation/parity objects are never treated as authority; the only final preW0 lineage is external-service-assembled `B0 → Pw → Cw → Sw`, host-reopened under an immutable object-import receipt before protected CAS and external final attestation.

## Execution Handoff

Execute this plan only from
`/Users/changgeng/.codex/worktrees/e4d7/Project06`, with the lineage guard at
every mutation boundary. Use
`2026-07-23-qinao-c0-provenance-and-safe-import.md` first to establish the
reviewed import map and execution-root classifier. Then use this exact
stop/resume schedule; adjacent rows are serialization barriers, not merely
suggested ordering:

| Order | Owning plan and executable slice | Required output / stop condition |
|---|---|---|
| 1 | C0 provenance Tasks 1-7 | authenticated inventory/import map, reviewed candidate root, and passing `prebootstrapPreparation` guard |
| 2 | Bootstrap Task 1 and Task 1A Steps 1-4 | committed import-review protocol with the C1 context frozen but no external result predicted |
| 3 | Authority Task 1 | checker-only authority surface and fail-closed transitional stubs |
| 4 | Bootstrap Task 1A Steps 5-6 | externally signed C1 record plus immutable reopen receipt |
| 5 | Authority Task 2 | unique map-only C1 postimage, reviewed C1 apply, and exact transitional 7+4 authority draft |
| 6 | Bootstrap Task 1A Step 7 | fixed 32-path C2 review record plus immutable reopen receipt |
| 7 | Authority Task 2A | map-only C2 postimage, exact 32-path import parent, and exact-three-path helper/test hardening child |
| 8 | Bootstrap Tasks 2 and 4 schema/catalog-only slices | indexed schemas, immutable 19-contract catalog/program tables, and projection schema; no ceremony output predicted |
| 9 | Authority Task 3 | immutable Input A over exact indexed transitional Ledger/catalog bytes |
| 10 | Bootstrap Tasks 3 and 5-7, then Task 7A, Task 8, and Task 9 Steps 1-2 | authenticated `B0`, export envelope, projection, verifier/modules/profiles, precommitted lineage transaction, and explicit Hold C |
| 11 | Authority Tasks 4-9 and Task 10 Steps 1-6, including external Hold 5A | final clean preparation tip/tree plus exclusively installed or byte-identical authority-finalization handoff |
| 12 | Bootstrap Task 9 Steps 3-4, then Bootstrap Task 10 as the sole transaction owner | one tree-identical `Pw` with sole parent `B0`; original and preparation tips preserved under immutable forensic refs; no second plan/apply |
| 13 | Authority Task 10 Steps 7-8 | authenticated transaction return consumed and exact reparented lineage independently verified |
| 14 | Bootstrap Task 11 | privacy-clean bootstrap verification summary and exact later-wave protected interface |
| 15 | Authority Task 11 | predecessor-derived protected evaluation over exact `Pw`; complete authenticated evidence bundle only, with no Git write |
| 16 | Authority Task 12 | external-service host import/reopen, object receipt, intent, deterministic `Cw/Sw`, protected CAS, and finalized attestation |
| 17 | `2026-07-23-qinao-w0-safety-and-k4-proof.md` | W0 safety freeze and the required K4 platform proof; no paper substitute for a platform result |
| 18 | `2026-07-23-qinao-artifact-mesh-w1-task0.md`, then later-wave consumers | Artifact Mesh Task 0 before any W1 consumer; subsequent waves derive only from the admitted predecessor |

Do not parallelize rows that mutate the sole Ledger, Input A, Output B,
authority-finalization handoff, candidate lineage, or admitted ref. Work
inside one row may parallelize only when its task explicitly permits it and
all inputs are immutable. At any digest mismatch, unknown CAS, stale host
observation, absent platform capability, or non-byte-identical retry, stop at
the owning sibling plan's fail-closed state; do not repair authority by
recapturing input, rewriting an external output, or constructing a local
replacement.
