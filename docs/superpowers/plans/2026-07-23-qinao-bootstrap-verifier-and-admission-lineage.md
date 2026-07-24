# Qinao Bootstrap Verifier and Admission Lineage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the externally anchored bootstrap trust root that freezes every gate needed through W6, evaluates exact Git payload objects without candidate-code trust, hands authoritative side effects to an authenticated external admission service, and reparents the finalized preW0 payload under a minimal single-parent `B0` without losing the existing 22 preparation commits.

**Architecture:** `B0` is a minimal one-parent child of approved base `59c26f508262d7c25869faac0ec0abf968ec1e02`; it contains only the immutable workflow, runner, verifier V0, complete gate catalog, 19 executable gate modules, contracts, corpora, schemas, and their closed helper set. The protected workflow has read-only repository permission plus OIDC and begins from an exact proposed `Pw`, never a prebuilt seal. It executes only byte-verified active bytes and uploads signed gate/evidence outputs. The external service's first `assemble_import_and_finalize` pass validates the closed output allowlist, deterministically closes `Cw` plus one-receipt `Sw` and their object/import/intent identity in non-host quarantine, publishes the protected-advance authorization request, and stops with zero target-host effects. Only after one fresh `ProtectedRefAdvanceAuthorizationV1` is authenticated and reopened may the same method resume the same lease/bundle/assembly identity, import and reopen that authorized object set on the target host, persist its receipt, create the immutable admission intent, perform canonical-ref CAS, and finalize the attestation. This two-pass ordering removes the impossible cycle in which `Sw` would need current-run results before the run starts without collapsing authorization into object construction. After the authority plan imports the signed bootstrap projection and freezes its preparation tree, one local `git update-ref --stdin` transaction creates a fixed original-tip forensic ref plus a content-addressed final-preparation forensic ref, then moves only the candidate ref to a new `Pw` with that exact tree and sole parent `B0`.

**Tech Stack:** Python 3 standard library and `unittest`, Git object/index/ref plumbing, canonical JSON and closed JSON Schema, GitHub Actions OIDC with full-SHA Actions, an external append-only admission/CAS/attestation service, and existing Swift/Xcode/Rust gate commands invoked only through bootstrap-pinned modules.

## Global Constraints

- Implement in the existing clean candidate worktree `/Users/changgeng/.codex/worktrees/e4d7/Project06`; do not create a second clean worktree.
- Preserve branch `codex/qinao-w1-clean-candidate`, its 22 commits from approved base through baseline tip `486e1ec5983ad4390c5b07f04607f1345b912c4c`, and the pre-existing unstaged `scripts/check_qinao_owner_ledger.py` change.
- Approved base is exactly `59c26f508262d7c25869faac0ec0abf968ec1e02`; approved design SHA-256 is exactly `3af1067ad2c3d37c36d7613ad19d1dd035bb6f1c60f06b75d5d71de22874d1b4`.
- Approved dynamic-graph amendment is commit `9d484befb4a4593d93789457ebddfd7cde358e3b`, path `docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md`, blob `e2c59656f9eb184efc3ab933fe442c9dd0b7d507`, SHA-256 `5f36d0b04579f805a3a69254325e62e22625f4ddd31663e03cbf78b1a39460d5`.
- `B0` has exactly one parent, the approved base. Its diff from that base equals the canonical bootstrap-path manifest exactly; no plan, test harness, lineage builder, candidate evidence, authority draft, result, receipt, or external attestation enters `B0`.
- The bootstrap gate catalog is complete at genesis for `preW0,W0…W6`; no gate may first acquire executable semantics from the candidate it judges.
- `wave`, canonical ref, release profile, active verifier, active gate module, repository identity, and protection policy are derived from the external bootstrap/prior finalized tuple. They are never CLI flags, workflow inputs, environment overrides, candidate-manifest fields, or caller assertions.
- The workflow has no caller input. After separate user authorization, the
  external service persists an `EvaluationDispatchIntentV1` that binds one
  signed `PayloadProposalReceiptV1`, then creates a create-once opaque run ref
  at B0. The ref's `push` event starts the workflow. The service maps the
  authenticated OIDC ref/run tuple back to that intent and derives the payload
  OID; branch spelling is transport, never authority. `Cw` and `Sw` do not
  exist when evaluation starts.
- A concrete `build_evidence_storage_profile` value and the non-shipping `verification_toolchain_profile` appear only in the externally signed bootstrap projection and the byte-matching final Owner-Ledger `wave_admission_v1`. Their closed schema definitions are necessarily pinned in `B0`, but no profile instance appears in any `B0` catalog/module/corpus byte or in the checked-in blocked bootstrap-candidate projection. The verification profile selects the Xcode 27 runner/SDK used to judge preW0; it is never an active product release profile.
- The GitHub workflow has `contents: read` and `id-token: write`; it has no contents-write token, GitHub App private key, repository-admin credential, CAS credential, evidence-store credential, or attestation-signing key.
- The external service alone owns B0/object import, bootstrap intent
  reconciliation, proposal-object pinning, evaluation dispatch intents/run
  refs, the first-pass deterministic non-host `Cw/Sw` closure and
  protected-advance authorization request, the second-pass same-identity
  authorized target-host import/reopen and receipt, `AdmissionIntent`,
  protected-ref compare-and-swap, authenticated Git-host audit lookup,
  superseding-intent creation, final attestation publication, and quarantine.
- Candidate-local `scripts/check_qinao_wave_admission.py` remains diagnostic and can emit only `preflight`; it can never emit `admitted`, update a ref, authenticate an attestation, or activate a proposed verifier/module.
- V0 reads current payload, authenticated predecessor payload when a frozen
  primitive requires it, bootstrap, contract, module, and corpus bytes by
  exact Git OID. It never imports Python from the candidate tree, uses worktree bytes as
  proof input, invokes a shell, follows an escaping symlink, inherits an
  unrestricted environment, or obtains network access. Ordinary process
  primitives never execute candidate binaries. The sole exception is the
  controller-side `ExternalPhysicalGateBrokerV1`: outside the evaluator
  compartment it may build/install/run an exact-Pw subject under a
  lease-bound device policy, while an independent attester and external
  custody produce the only proof accepted by V0.
- The exact seven controlled documents are executable inputs only after
  Authority convergence has made their repository paths relative. B0
  ArchitectureClosure rejects developer-specific source/candidate roots,
  `file://` repository locators, or an executable path not rooted through the
  exact payload reader.
- Python gate execution is dependency-closed at B0. Neither a controlled
  command nor a ProgramSpec may invoke `uv run --with`, `pip`, `pipx`,
  `poetry`, `conda`, `python -m pytest`, or any runtime installer/resolver;
  Python helpers are standard-library-only bytes in the verified B0 closure.
- The master begins with the non-circular preparation order
  `C0 Tasks 1-7 (committed all-hold inventory/map/provenance) →
  Bootstrap Task 1 → Bootstrap Task 1A Steps 1-4 → Authority Task 1 →
  Bootstrap Task 1A Steps 5-6 (fixed C1 context, external review, immutable
  reopen receipt) → Authority Task 2 (map-only postimage commit, then C1
  apply) → Bootstrap Task 1A Step 7 (fixed C2 helper/test closure) →
  Authority Task 2A (map-only postimage commit, exact C2 apply, then the
  exact three-path helper/test hardening child)`.
  The 7+4 authority plan and this plan then use the explicit schedule
  `Bootstrap Tasks 2,4 → Authority Task 3 →
  Bootstrap Tasks 3,5-7 → Task 7A → Task 8 → Task 9 Steps 1-2 →
  Authority Tasks 4-9 plus Task 10 Steps 1-6, including external Hold 5A →
  Bootstrap Task 9 Steps 3-4 → Bootstrap Task 10 →
  Authority Task 10 Steps 7-8 → Bootstrap Task 11`.
  After preW0 admission, W0 Task 1 must execute Bootstrap Task 1A Step 8 for
  the distinct C3 record before it writes or applies any C3 map row. C1, C2,
  and C3 are append-only records and never overwrite one another.
  The pre-Input-A bootstrap slice freezes only schemas, protocol semantics, gate
  contracts, corpora, modules, and structural diagnostics; it creates no B0,
  profile value, service authority, payload, result, or admission claim.
- This plan does not implement C0 source-inventory/import-map internals, edit the 7+4 authority prose, implement W0/K4, or implement Artifact Mesh.
- Every code change follows RED → focused GREEN → full relevant suite → isolated commit. Never use a zero-match test/filter or a command whose missing path is treated as success.
- All repository edits use exact paths. All external ceremony artifacts remain outside Git under `/private/tmp/qinao-bootstrap-ceremony-v1/export` and in the authenticated external transparency store.

Before the first executable step of this child and again before every real B0
proposal, ceremony request, lineage plan, or ref transaction, run:

```bash
set -euo pipefail
cd /Users/changgeng/.codex/worktrees/e4d7/Project06
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py \
  --root . \
  --expect-candidate-lineage prebootstrapPreparation \
  --require-clean
```

The sole exception is after the Task-10 transaction, where the same command
uses `--expect-candidate-lineage reparentedProgram`. A missing guard tool,
dirty source bytes, or unreadable guard input stops
`BLOCKED_SOURCE_DRIFT/SOURCE_BYTES_CHANGED`; a wrong
root/branch/lineage/HEAD transaction stops
`BLOCKED_LINEAGE_TRANSACTION/LINEAGE_TRANSACTION_DIVERGENCE`. No later
command in the block may mask either failure.

## Approved Dynamic Graph Bootstrap Amendment

Bootstrap retains exactly 19 gate contracts/modules/corpora and the existing
152-cell matrix. There is no gate 20. The predecessor-derived active module
and verifier judge the candidate; candidate bytes cannot select or implement
the module that judges their wave. Every graph check has positive discovery,
nonempty fixtures, at least one valid specimen, and at least one rejecting
mutant.

| Existing gate ID | Graph coverage |
|---|---|
| `qinao.owner-ledger` | Existing-owner pins, reciprocal catalog closure, no graph owner |
| `qinao.production-reachability` | Production graph writers/executors/peer paths/scratchpads and shipping entrypoints |
| `qinao.architecture-closure` | G0-G4 plus exact 14/4/4/7 topology |
| `qinao.w0-open-set` | Closed W0 shared-agent-state hazard extension |
| `qinao.contracts-layercell` | Immutable wires, execution shape, joins, terminal bases and bounds |
| `qinao.semantic-statelake-context` | G1/G2, retrieval, grounding, independent context and compiler ownership |
| `qinao.silicon-execution-spine` | Physical Provider rows/CAS/envelopes only |
| `qinao.sovereign-release-effects` | Authorization, effects, remand boundaries and no blind retry |
| `qinao.runtime-replay-certification` | Replay/recovery, retirement, W6 ordering and cutover proof |

Bootstrap owns the authoritative B0 contracts, modules, corpora, verifier,
fixed module selection, anti-vacuity, evidence admission, and independent
`production_graph_reachability`. Authority owns only candidate-side evidence
classification and parity helpers. Each incumbent domain plan owns its own
suite, fixtures, output schema, and mutations.

`production_graph_reachability` must start from authority-selected
Package.swift, Xcode, XcodeGen, workspace, product and entrypoint roots; walk
source membership, imports, AST/SIL/index and linked-symbol closure; classify
every discovered writer/executor and indirect edge; and fail on zero roots,
unclassified projects/edges, a second G1/G2 writer, direct peer calls, shared
scratchpads, legacy loop authority, lab/shadow leakage, or an unclassified
`BASAppleTaskGraphLifecycleExecutor.refresh`. Candidate paths and candidate
reports are inputs to classification only, never authority.

The fixed corpora must reject at least: fifth ring/kernel/plane, mutable G1 or
G2, reverse absence query, invalid execution shape, zero-join ControlRing,
nonzero source join in pure DAG, graph owner/manager/store, blind Provider
retry, self-adoption, completed parent used as cancellation basis, completion
without the current semantic Attempt, over-1,018 dispositions, over-1,024
parent/input refs, W4 executor/cutover wiring, and reordered W6 cutover.
These mutations are added to existing gate corpora and matrix rows; the
catalog cardinalities remain 19 modules and 152 cells.

### Exact Bootstrap task insertion and anti-vacuity contract

The master order is consumed unchanged. Bootstrap performs graph work only in
Tasks 2-7/11 and returns the same signed projection, B0, admission and lineage
handoffs already defined by this plan.

| Existing task | Graph-specific insertion |
|---|---|
| Task 2 | Freeze `production_graph_reachability` in `runtime.py`; extend nine existing contract/corpus/program rows and their existing 8-wave cells; assert 19 rows and 152 cells after generation |
| Task 3 | Supply the exact-OID reader/materialized views to the already-frozen runtime primitive and prove candidate/helper independence |
| Task 4 | Include amended contract/module/corpus digests in the same signed Bootstrap projection |
| Task 5 | Run predecessor-selected modules with no workflow input or candidate module import |
| Task 6 | Recover the same evaluation; never rerun a physical boundary or select a replacement module |
| Task 7 | Include the amended nine rows in the same minimal B0 path closure |
| Task 11 | Execute catalog, isolation, mutant, cardinality, output-schema, and selection tests before handoff |

The `production_graph_reachability` primitive is implemented only in
`scripts/qinao_gate_modules/v0/runtime.py` with this closed ABI:

```text
production_graph_reachability(
  *,
  payload_tree_oid: str,
  read_tree_entry: Callable[[str], bytes],
  authority_roots: tuple[str, ...],
  build_graph_contract_bytes: bytes,
  corpus_bytes: bytes
) -> dict[str, object]
```

The declaration above freezes the signature; Task 2 Step 3 supplies its full
body and registers it in `run_primitive`. The generated
`scripts/qinao_gate_modules/v0/modules/production_reachability.py` remains the
same strict two-symbol wrapper as the other eighteen modules: only `GATE_ID`
and `evaluate` are legal module-level symbols.

`read_tree_entry` is supplied only by V0's exact-OID materializer and rejects
absent, nonregular, symlinked, escaping, or wrong-mode entries before returning
bytes. The primitive consumes no worktree path, shell command, candidate report, environment
selector, branch name, or candidate Python module. Its result uses the
existing gate-output schema and reports the complete discovered/classified
root, project, product, entrypoint, writer, executor, call-edge and linked
symbol sets plus corpus case IDs. Zero authority roots, zero production
entrypoints, zero positive cases, zero negative cases, or an unclassified
item is an error result, never a pass.

Add these exact tests to `scripts/test_qinao_gate_catalog_v0.py`:

```text
test_graph_amendment_keeps_nineteen_gates_and_152_cells
test_nine_graph_gate_ids_are_existing_rows
test_every_graph_row_has_positive_negative_and_mutation_corpus
test_every_graph_program_has_nonempty_discovery
test_candidate_cannot_select_graph_module_or_verifier
test_production_graph_reachability_is_independent_of_candidate_helper
test_w4_cells_reject_executor_shadow_and_cutover
test_w6_cells_preserve_exact_dependency_order
```

Add exact-OID isolation and substitution cases to
`scripts/test_qinao_wave_verifier_v0.py`: changed candidate helper with
unchanged B0 module, replaced corpus, replaced contract, wrong predecessor
catalog, module digest substitution, symlink/nonregular root, and an
attempted candidate import. Every mutation must fail for its named diagnostic,
not due to import or fixture absence.

Run:

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_gate_catalog_v0 \
  scripts.test_qinao_wave_verifier_v0 \
  scripts.test_qinao_protected_admission_runner \
  scripts.test_qinao_admission_recovery_oracle
```

Expected: positive discovery for all four modules, 19 catalog rows, 152
program cells, all nine existing graph-mapped gate IDs present exactly once,
and all tests pass. A twentieth row, a 153rd cell, empty corpus, candidate
selection input, candidate helper execution, or graph-specific admission
path fails closed.

### Program terminal envelope

This child emits only the master-owned program terminals:

```text
BLOCKED_SOURCE_DRIFT
BLOCKED_DESTINATION_DRIFT
BLOCKED_IMPORT_REVIEW
BLOCKED_EXTERNAL_BOOTSTRAP
BLOCKED_LINEAGE_TRANSACTION
BLOCKED_PAYLOAD_OBJECT_AVAILABILITY
BLOCKED_PREW0_EVIDENCE
BLOCKED_K4
BLOCKED_ARTIFACT_MESH_DEVICE_RECOVERY
pendingAdmission
quarantinedAdmission
admitted
```

Bootstrap-local diagnostics are `reason_code` values inside one of those
terminals, never additional top-level terminals.
`BLOCKED_EXTERNAL_SERVICE_BINDING`,
`BLOCKED_BOOTSTRAP_CONTRACT_HANDOFF`, and
`BLOCKED_NON_LITERAL_GATE_PROGRAM` map to
`terminal = BLOCKED_EXTERNAL_BOOTSTRAP`. A gate's missing evidence maps to the
owning master terminal (`BLOCKED_PREW0_EVIDENCE`, `BLOCKED_K4`, or
`BLOCKED_ARTIFACT_MESH_DEVICE_RECOVERY`). Internal service record state
`finalized` is not a program terminal: successful recovery returns the same
`AdmittedWaveV1` and emits `terminal = admitted`. Internal `quarantined`
becomes `quarantinedAdmission`; a completed CAS lacking its same-intent
attestation becomes `pendingAdmission`. No `blocked`, `quarantined`, or
`finalized` alias appears in a program-terminal schema.

---

## Inter-plan Contract and Hold Points

### Preparation R — non-circular, batch-scoped signed import review

C0 runs first. Its Tasks 1-7 commit the structural inventory/import tools,
the canonical source inventory, the all-`hold` import map, and the
SourceProvenance pair. No review record, reviewer value, selected row, or
source postimage exists in that commit. The all-hold checker accepts this
state only when every row's `review_record_digest`,
`reviewer_identity_digest`, and `reviewed_at` is null.

Bootstrap Task 1 and Task 1A Steps 1-4 then freeze the protocol, the
enterprise-managed trust-anchor adapter, the opaque verified-review type,
and the import-map integration. Authority Task 1 may then commit its
checker-only preparation. At that resulting clean candidate tip, Task 1A
Step 5 freezes a C1 expected context containing the exact HEAD/tree/index/
status observations, frozen inventory and prior all-hold map digests, and
the ten exact proposed C1 decision-row postimages. Only then may the
external service sign and append the C1 `ImportReviewV1` plus its immutable
reopen/transparency receipt. Authority Task 2 is the first step allowed to
change the map: its first commit changes only the map to the uniquely
derivable C1 postimage, and its next commit applies the ten reviewed source
postimages. At that new clean tip, Task 1A Step 7 repeats the same ceremony
for the exact 32-path C2 helper/test/dependency/evidence closure. Authority
Task 2A alone may materialize its map-only postimage and then apply those 32 reviewed
bytes before its exact three-path helper/test hardening child.
C1 and C2 together are the indivisible preW0 import payload.

The current local files are caches, never the trust root:

```text
/private/tmp/qinao-c0-import-review-v1/proposals/c1-decision-rows-v1.json
/private/tmp/qinao-c0-import-review-v1/contexts/c1-expected-context-v1.json
/private/tmp/qinao-c0-import-review-v1/export/c1/import-review-v1.json
/private/tmp/qinao-c0-import-review-v1/export/c1/import-review-reopen-receipt-v1.json
/private/tmp/qinao-c0-import-review-v1/proposals/c2-decision-rows-v1.json
/private/tmp/qinao-c0-import-review-v1/contexts/c2-expected-context-v1.json
/private/tmp/qinao-c0-import-review-v1/export/c2/import-review-v1.json
/private/tmp/qinao-c0-import-review-v1/export/c2/import-review-reopen-receipt-v1.json
/private/tmp/qinao-c0-import-review-v1/proposals/c3-decision-rows-v1.json
/private/tmp/qinao-c0-import-review-v1/contexts/c3-expected-context-v1.json
/private/tmp/qinao-c0-import-review-v1/export/c3/import-review-v1.json
/private/tmp/qinao-c0-import-review-v1/export/c3/import-review-reopen-receipt-v1.json
```

The cache root and every descendant directory are code-owned: open or create
the root with effective-UID ownership and mode `0700`, then descriptor-walk
each literal `proposals`, `contexts`, `export`, and batch component with
`O_DIRECTORY|O_NOFOLLOW`, owner equality, and mode `0700`. Every leaf is a
regular owner-only mode-`0600` canonical JSON file opened with
`O_NOFOLLOW`. No final proposal, context, record, or receipt leaf is ever
opened with `O_CREAT`, truncated, renamed over, or replaced. All local writers,
including the authenticated service-export adapter, use one shared
descriptor-relative create-once installer:

1. derive the deterministic same-operation temp basename
   `.qinao-install-<64-lowercase-hex>.tmp` by domain-separated SHA-256 over
   the final basename, canonical-value SHA-256, and the fixed operation intent
   (`freeze-proposal`, `freeze-context`, `export-record`, or
   `export-receipt`); reject every temp name outside that closed regex;
2. create that code-owned temp in the same verified directory with
   `openat(O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW, 0600)`;
3. `fchmod` the open descriptor to exact `0600`, write the complete canonical
   bytes, verify the byte count, and `fsync` the file;
4. install the final name only with same-directory
   `linkat(temp, final, flags=0)`, whose existing-target failure is the
   no-replace decision;
5. `fsync` the directory, unlink only the verified same-operation temporary
   name, and `fsync` the directory again.

On an existing final name or a lost reply after `linkat`, recovery opens the
final with `O_NOFOLLOW`, verifies owner/mode/regular type, exact canonical
bytes, and the expected inode/link relation, and treats only an
identical-final value as success. If the verified same-operation temporary
link remains, recovery proves it names the same inode, removes that temp link,
directory-`fsync`s, and then requires final `st_nlink == 1`; no unrelated temp
is cleaned up. A stale temp for another final/value/intent causes a
fail-closed diagnostic and is left byte-for-byte in place. A foreign owner,
broader mode, parent/final symlink, special
file, unexpected hard link, divergent preexisting value, or repository/source
descendant stops
`BLOCKED_IMPORT_REVIEW/IMPORT_REVIEW_CONTEXT_MISMATCH` without overwrite or
cleanup.

The import-review tests cover safe first creation, byte-identical cache
re-export, every parent/final symlink, foreign owner where the platform
permits the fixture, broad mode, hard-link substitution, divergent bytes, and
crash before/after temp `fsync`, `linkat`, each directory `fsync`, and temp
unlink. They prove the final name is never an `O_CREAT` target, a preexisting
final is never replaced, an identical-final lost reply succeeds, a divergent
final survives byte-for-byte, and only a verified same-operation temp link is
removed. A stale other-intent temp must cause failure and remain present with
the same inode and bytes. Recovery reopens the content-addressed external
record; it never deletes a suspicious cache to retry.

Each signed record embeds the complete canonical `ImportReviewContextV1`,
including its proposed decision rows. The external service persists that
self-contained record content-addressed and append-only under
`(review_record_id, review_record_digest)` and may re-export identical bytes
to its fixed batch cache after a process, session, or machine restart. Once
the signed record exists, the proposal/context files are disposable caches:
the verifier reconstructs and authenticates `bound_context` from the record
and may restore those caches only as byte-identical conveniences. It
authenticates both record and reopen receipt against the OS/enterprise-managed
trust anchor; it never accepts a caller path, caller public key,
candidate-provided anchor, or unsigned local fixture.

After preW0 is admitted, the same mechanism freezes a new C3 context at its
own clean tip, signs exactly the twenty proposed C3 row postimages, and
persists a distinct C3 record/receipt before W0 Task 1 writes the map-only C3
postimage commit. C3 does not replace, weaken, or re-sign C1 or C2. Each
non-hold map row stores its own record digest. The checker groups rows by that
digest, reopens the code-owned C1/C2/C3 cache and immutable service receipt,
and proves the group is bijective with the record's batch-specific decision
rows.

The record is external review evidence, not product authority, wave
authority, a fifth `ProtectedAdmissionClient` method, or a B0 member.
Missing verifier bytes, self-contained record, receipt, anchor, signature,
embedded context, or exact row-set equality stops before map/apply at
`BLOCKED_IMPORT_REVIEW` with the matching closed reason. A missing local
proposal/context cache after record creation is not a blocker if the external
service reopens and re-exports the same authenticated record. Preparation Z
reuses the already committed Task-1 protocol bytes and never regenerates a
review.

The privacy-clean import-review audit root contains only sorted
`(destination_batch, review_record_digest, reopen_receipt_digest,
transparency_checkpoint_digest, transparency_inclusion_proof_digest)` rows.
It is bound by the later bootstrap/admission attestation, not emitted as a
new preW0 `Cw` path; the fixed 132-path preW0 transport allowlist is
unchanged.

### Preparation Z — bootstrap contract freeze before Input A

After Authority Tasks 1-2 have produced the internally consistent indexed 7+4
draft and Authority Task 2A has committed the reviewed C2 helper closure,
reopen the already committed Task-1 protocol bytes and execute Bootstrap
Tasks 2 and 4. Together they freeze the protocol grammar,
the self-contained gate semantics, the complete through-W6 catalog, and the
closed bootstrap schema. The exact indexed digest inputs returned to Authority
Task 3 are:

```text
docs/superpowers/specs/qinao-wave-admission-bootstrap-v1.schema.json
scripts/qinao_gate_modules/v0/catalog-v1.json
```

This preparation handoff is not signed and is not authority. Authority Task 3
computes `wave_admission_contract_digest` and
`required_gate_contracts_digest` from those exact indexed bytes and emits Input
A. Before Task 3 of this bootstrap plan may run, it reopens Input A and requires
both digests to equal the already frozen bytes. This breaks the otherwise
circular instruction in which Input A would need a catalog that supposedly
could not be built until after Input A.

### Input A — authority draft, before `B0`

This plan consumes exactly:

`docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json`

Its closed top-level fields are:

```text
{
  "schema_version": 1,
  "authority_bundle_digest": "64 lowercase hex",
  "owner_ledger_draft_digest": "64 lowercase hex",
  "controlled_contract_catalog_digest": "64 lowercase hex",
  "document_digests": [
    {
      "document_id": "stable-id",
      "path": "repository-relative path",
      "sha256": "64 lowercase hex"
    }
  ],
  "wave_admission_contract_digest": "64 lowercase hex",
  "required_gate_contracts_digest": "64 lowercase hex"
}
```

`document_digests` has exact cardinality 11: seven controlled documents and four governing addenda. It is sorted by `document_id`; every path and digest must byte-match the candidate index. This draft is review input only. It contains no `B0` OID, bootstrap projection digest, attestation digest, profile, candidate commit/tree, receipt, or completion claim.

### Output B — external ceremony, returned to the authority plan

The external two-operator ceremony exports these canonical files:

```text
/private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json
/private/tmp/qinao-bootstrap-ceremony-v1/export/bootstrap-attestation-v1.json
/private/tmp/qinao-bootstrap-ceremony-v1/export/bootstrap-bundle-manifest-v1.json
/private/tmp/qinao-bootstrap-ceremony-v1/export/operator-approvals-v1.json
/private/tmp/qinao-bootstrap-ceremony-v1/export/export-envelope-v1.json
```

`wave-admission-v1.json` is the sole canonical bootstrap projection and the
sole ceremony export containing `build_evidence_storage_profile` and
`verification_toolchain_profile`. It contains only a closed
`bootstrap_attestation_policy`, never the digest, signature, status, or bytes
of the attestation that authenticates it. `bootstrap-attestation-v1.json`
binds the projection's SHA-256 in one direction and contains no future
transparency-entry identity. After the signed attestation is appended,
`export-envelope-v1.json` binds the byte digests of the other four files plus
the log entry ID, signed checkpoint digest, and inclusion-proof digest. This
acyclic order prevents projection/attestation/log fixed points. No file is
copied into Git by this plan.

The bundle manifest and bootstrap attestation each contain the exact field
`source_import_review_audit_root_digest`, equal to the verified sorted C1+C2
privacy-clean audit root at Output B. The attestation signature covers it and
the unchanged eight-field `BootstrapExportV1` covers both enclosing file
digests. No exact `BootstrapRoot` or `BootstrapExportV1` field is added. For
the later W0 run, the signed lease/result bundle, existing Sw receipt, intent,
and finalized admission attestation carry the sorted C1+C2+C3 audit root. These
are signature/receipt fields, not Cw files; preW0 remains 132 paths and W0
remains 16.

Here “sorted” means the Bootstrap compiler's canonical record-digest order,
not caller tuple order. Output B computes exactly:

```text
compile_review_audit_root((
  verify_fixed_c1_import_review_export(),
  verify_fixed_c2_import_review_export(),
))
```

`export-envelope-v1.json` is the canonical `BootstrapExportV1` closed object
with exactly these eight fields:

```text
wave_admission_projection_sha256
bootstrap_attestation_sha256
bootstrap_bundle_manifest_sha256
operator_approvals_sha256
transparency_entry_id
transparency_checkpoint_digest
transparency_inclusion_proof_digest
export_envelope_signature
```

Its `required` and `properties` sets are identical and
`additionalProperties` is false. `export_envelope_signature` domain-separates
and covers the other seven fields. The alias `attestation_sha256` is rejected;
the projection, bundle-manifest, approvals, and envelope-signature fields are
never optional.

### Hold C — authority finalization

After Output B validates, stop. The authority plan must:

1. import `wave-admission-v1.json` byte-for-byte as the final Owner-Ledger `wave_admission_v1`;
2. recompute the 7+4, Owner-Ledger, authority-bundle, and controlled-contract-catalog digests;
3. remove the pre-ceremony draft handoff from the intended `Pw` tree or classify it as non-authoritative preparation evidence outside the Cw/Sw evidence sets;
4. commit the complete indivisible authority preparation;
5. verify the fixed external
   `/private/tmp/qinao-bootstrap-ceremony-v1/required-checks-migration-v1.json`
   service record and prove its admission-protection projection equals the
   signed bootstrap projection; and
6. invoke Task 7A's code-owned `--write-authority-finalization` mode to export
   `/private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json`
   with exact fields:

```json
{
  "schema_version": 1,
  "preparation_tip_oid": "Git commit OID",
  "preparation_tree_oid": "Git tree OID",
  "wave_admission_projection_sha256": "64 lowercase hex",
  "owner_ledger_sha256": "64 lowercase hex",
  "authority_bundle_digest": "64 lowercase hex",
  "controlled_contract_catalog_digest": "64 lowercase hex",
  "governance_required_checks_migration_digest": "64 lowercase hex",
  "admission_protection_projection_sha256": "64 lowercase hex"
}
```

Only then may Task 10 create the reparented `Pw`.

### Output D — protected evaluation and assembly input

The authority plan later consumes V0 gate results from:

```text
/private/tmp/qinao-admission-run-v1/<lease-id>/gate-results/<gate-id>.json
/private/tmp/qinao-admission-run-v1/<lease-id>/gate-results/index.json
```

Every gate result binds the externally derived wave, exact `Pw` commit/tree, immutable contract/module/corpus digests, non-zero discovery/execution counts, and a closed set of privacy-clean evidence-output path/blob rows. Candidate-side builders may reproduce those bytes only as parity diagnostics.

The protected runner uploads the complete result/evidence bundle to the external service. The service must then:

1. reopen the active B0/prior-wave assembly contract and exact `Pw`;
2. reject any missing, extra, noncanonical, privacy-bearing, executable, symlink, or non-allowlisted output;
3. use the commit identity and receipt timestamp frozen in the signed evaluation lease to build one-parent evidence-only `Cw`;
4. canonicalize the one receipt from service-derived values and build one-parent `Sw`;
5. close the exact `Cw/Sw` object set, import key, intent key, and live-protection projection in the non-host quarantine, persist the corresponding authorization request, and stop at `BLOCKED_EXTERNAL_BOOTSTRAP/CEREMONY_UNAVAILABLE`;
6. obtain, authenticate, and reopen one exact fresh
   `ProtectedRefAdvanceAuthorizationV1` before any target-host object import,
   intent, or CAS;
7. only under that authorization, import the exact object set through the
   authenticated Git-host integration and reopen commit/tree/parent/blob
   topology from the target host;
8. persist the immutable same-authorization object-import receipt before
   creating the bound `AdmissionIntent`; and
9. only then attempt its non-force protected-ref CAS and same-intent final
   attestation.

An unknown authorization-persistence result queries the append-only service;
an unknown target-host import queries/reopens the exact object set; and an
unknown CAS queries host audit. None reissues the corresponding effect.
Re-entry preserves the same lease, authenticated bundle, deterministic
assembly, authorization request, object set, import key, intent key, and
live-protection projection.

The authority child owns the content schemas and parity compiler; this
bootstrap child owns the active-run protocol and external-service conformance
contract. A candidate-local `Cw`, `Sw`, proposal ref, commit timestamp,
evidence leaf, or receipt is never an admission input.

### Input E — externally pinned payload proposal

After a wave freezes `Pw`, the service may close its exact proposal object set
only in a non-host quarantine. Before any target-host import, proposal-ref
creation, dispatch intent, or run-ref creation, an operator with separate user
authorization must cause one exact, fresh
`PayloadDispatchAuthorizationV1` to be persisted, authenticated, and reopened
from the append-only service. That record binds the predecessor chain,
payload commit/tree, proposal object set, content-addressed proposal ref,
dispatch intent, create-once B0 run ref, active verifier bundle, operator,
expiry, nonce, and signature.

Only then may the service import and reopen the exact payload objects through
its authenticated Git-host integration. After host reopen it creates the
immutable content-addressed ref
`refs/heads/qinao-payload-proposals/<full-payload-oid>` once, reopens
commit/tree/parents/ref audit from the Git host, and returns a signed
`PayloadProposalReceiptV1` outside Git. Only that host-reopened receipt may be
bound into the service-owned `EvaluationDispatchIntentV1`; the service then
creates its one opaque run ref
`refs/heads/qinao-admission-runs/<request-id>` at B0. The `push` event carries
only B0/ref/run metadata; the service derives the payload from the intent. No
upload branch, operator label, proposed wave, ref spelling, or event field is
authority.

Unknown authorization, payload import, proposal-ref create, or
dispatch/run-ref create outcomes are queried and reopened under the same
authorization and intent, never blindly repeated. A failed effect consumes
that authorization and terminates the operation; a new attempt requires a
new authorization rather than reusing a proposal receipt digest.
`PayloadDispatchAuthorizationV1` cannot authorize Cw/Sw import, an admission
intent, or canonical-ref CAS. Conversely,
`ProtectedRefAdvanceAuthorizationV1` cannot import/pin `Pw`, create a payload
proposal, or start an evaluation.

An absent upload authorization, missing object, mismatched content-addressed
ref, non-fast-forward replacement, deleted proposal ref, or failed host reopen
stops as `BLOCKED_PAYLOAD_OBJECT_AVAILABILITY` with reason code
`PAYLOAD_OBJECT_NOT_HOST_REOPENED`. No plan may substitute a local commit
object or candidate-authored receipt. The service-owned proposal ref is
immutable evidence availability, not an admitted branch; it cannot become a
predecessor or release source.

### Bootstrap-owned downstream client

Authority, W0, and Artifact Mesh import, but never redeclare, this opaque
client surface:

```text
ProtectedAdmissionClient.reopen_admitted_predecessor()
  -> AdmittedWaveV1
ProtectedAdmissionClient.pin_payload_and_issue_lease(payload_oid: str)
  -> tuple[PayloadProposalReceiptV1, EvaluationLease]
ProtectedAdmissionClient.run_active_gates(lease: EvaluationLease)
  -> AuthenticatedGateResultBundle
ProtectedAdmissionClient.assemble_import_and_finalize(
    lease: EvaluationLease,
    gate_results: AuthenticatedGateResultBundle
) -> AdmittedWaveV1
```

The protocol module also owns six closed external-service records without
adding any public client method:

```text
AdmissionProtectionProjectionV1 =
  {schema_version, repository_identity, canonical_ref, runner_ref,
   run_ref_prefix, payload_proposal_ref_prefix,
   canonical_ref_policy_digest, runner_ref_policy_digest,
   run_ref_prefix_policy_digest,
   payload_proposal_ref_prefix_policy_digest,
   cas_service_principal_digest, force_update_forbidden,
   deletion_forbidden, non_service_bypass_actor_digests}

PayloadDispatchAuthorizationV1 =
  {schema_version, repository_identity, predecessor_chain_digest,
   payload_commit_oid, payload_tree_oid, proposal_object_set_digest,
   proposal_ref, dispatch_intent_id, run_ref, active_verifier_bundle_digest,
   operator_principal_digest, operator_role_digest, authorized_at, expires_at,
   nonce, signature}

ProtectedRefAdvanceAuthorizationV1 =
  {schema_version, repository_identity, protected_ref, wave,
   expected_old_oid, payload_commit_oid, evidence_commit_oid, seal_commit_oid,
   payload_proposal_receipt_digest, evaluation_lease_id,
   authenticated_gate_bundle_digest, evidence_object_set_digest,
   intended_git_object_import_key, admission_intent_key,
   live_protection_projection_sha256,
   operator_principal_digest, operator_role_digest, authorized_at, expires_at,
   nonce, signature}

GovernanceValidationAuthorizationV1 =
  {schema_version, repository_identity, development_branch,
   preparation_commit_oid, preparation_tree_oid, preparation_path_rows,
   preparation_object_set_digest, workflow_path, workflow_blob_oid, job_id,
   checkout_action_oid, setup_python_action_oid, python_version,
   run_ref_prefix, validation_ref, dispatch_intent_id,
   admission_protection_projection_sha256,
   operator_principal_digest, operator_role_digest, authorized_at, expires_at,
   nonce, signature}

GovernanceValidationRunObservationV1 =
  {schema_version, repository_identity, development_branch,
   governance_validation_authorization_digest, validation_ref,
   dispatch_intent_id, preparation_commit_oid, preparation_tree_oid,
   preparation_object_set_digest, workflow_path, workflow_blob_oid, job_id,
   github_app_id, checkout_action_oid, setup_python_action_oid, python_version,
   run_id, run_attempt, conclusion, host_response_digest, observed_at,
   service_signature}

GovernanceRequiredChecksMigrationV1 =
  {schema_version, repository_identity, development_branch,
   before_observation_digest, after_observation_digest,
   migration_disposition, retired_contexts, replacement_context,
   replacement_run_observation_digest, operator_principal_digests,
   unchanged_unrelated_policy_projection_digest,
   admission_protection_projection_sha256, service_signature}
```

`AdmissionProtectionProjectionV1` uses canonical JSON with the exact field set
above and the master plan's closed nested policy projections. Required-check
contexts on the development/default branch are explicitly outside it.
`PayloadDispatchAuthorizationV1` permits only host import/reopen, immutable
proposal pinning, and its one create-once B0 run-ref/dispatch.
`ProtectedRefAdvanceAuthorizationV1` is issued only after deterministic
`Cw/Sw` derivation in the service's non-host quarantine and before target-host
import. It permits only the bound object-set import/reopen, its one signed
receipt, non-force CAS, and same-intent finalization. These two admission
authorizations are externally signed, short-lived, nonce-bound, role-checked,
create-once, and reopened from the append-only service. Candidate files,
environment variables, CLI values, prior authorizations, and process memory
cannot satisfy either record.

`GovernanceValidationAuthorizationV1` is a separate opaque, one-use service
authorization, not a fifth `ProtectedAdmissionClient` method and not SDK
authority exposed to Authority. Its `preparation_path_rows` is the
UTF-8-byte-sorted, duplicate-free tuple of exactly seven
`{path,mode,blob_oid}` rows:

```text
.github/workflows/test.yml
scripts/check_qinao_payload_purity.py
scripts/run_nonempty_python_unittest.py
scripts/test_check_qinao_payload_purity.py
scripts/test_check_w0_expected_open_set.py
scripts/test_run_nonempty_python_unittest.py
scripts/test_test_workflow_owner_ledger.py
```

Every mode is `100644`; each blob is reopened from
`preparation_commit_oid`, whose tree equals `preparation_tree_oid`.
`preparation_object_set_digest` covers the canonical sorted exact Git-object
closure required to import and reopen that commit, tree, parents, and seven
rows. The fixed workflow/job/toolchain bindings are
`.github/workflows/test.yml`, `qinao-governance`,
`actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683`,
`actions/setup-python@a309ff8b426b58ec0e2a45f0f869d46889d02405`, and
Python `3.12`. `run_ref_prefix` and
`admission_protection_projection_sha256` must byte-match the existing signed
bootstrap projection; `validation_ref` is exactly
`<run_ref_prefix>governance-validation/<opaque-request-id>`, is created once
by the bound service principal, and can never be updated or deleted.

The service may prepare the exact object pack only in a non-host quarantine.
It must persist and reopen the valid, unexpired authorization before the
first target-host write. It then imports only the authorized object set,
reopens the commit/tree/parents/path rows from the target host, persists the
same-intent import observation, and only then creates the bound validation ref
for the bound dispatch intent. Ref creation triggers the one validation run;
there is no implicit `git push`, caller credential, or mutation of the
canonical, development, runner, payload-proposal, or any existing run ref.
Unknown import, ref-create, or run outcomes are queried and reopened from host
audit under the same dispatch intent; they are never blindly replayed. A
failed/cancelled run consumes that authorization and leaves the migration
hold in place. A new attempt requires a new externally approved
authorization, nonce, intent, and create-once validation ref.

Only an exact successful host run produces
`GovernanceValidationRunObservationV1`. Its `conclusion` is literally
`success`; every commit/tree/object/workflow/blob/job/pin/Python/ref/intent
binding must match the authorization, and the GitHub App, run ID/attempt, raw
host-response digest, time, and service signature are provider-authenticated.
`GovernanceRequiredChecksMigrationV1.replacement_run_observation_digest`
must equal the domain-separated digest of that reopened observation. A
caller retry can reopen the same immutable authorization, intent, ref, and
observation, but cannot consume the authorization for a second host effect.

`GovernanceRequiredChecksMigrationV1.migration_disposition` is exactly
`noChangeRequired | atomicallyReplaced | requireThenRemove`;
`operator_principal_digests` is a sorted pair of distinct authorized
principals. The provider-authenticated before/after observations bind raw
response digests, ruleset IDs, app IDs, exact context names, bypass actors,
enforcement, and the replacement job observation. Unrelated policy projects
to the same digest, and the master-defined
`AdmissionProtectionProjectionV1` must be byte-identical before and after.
The record is an external service observation, not a candidate claim or a new
Owner-Ledger authority.

`assemble_import_and_finalize` may prepare exact objects only in a non-host
quarantine and expose an external authorization request through the service
control plane, but missing or expired
`ProtectedRefAdvanceAuthorizationV1` stops before target-host import,
intent, or CAS with
`BLOCKED_EXTERNAL_BOOTSTRAP/CEREMONY_UNAVAILABLE`. Retrying after the
authorization exists resumes the same lease/bundle/object/import identity and
does not construct a second object, intent, or authorization request.

`assemble_import_and_finalize` retains that non-union return type. Only
`admitted` returns `AdmittedWaveV1`. Every non-final result raises or
transports this closed typed terminal:

```python
class AdmissionTerminalError(ProtocolError):
    terminal: Literal[
        "BLOCKED_SOURCE_DRIFT",
        "BLOCKED_DESTINATION_DRIFT",
        "BLOCKED_IMPORT_REVIEW",
        "BLOCKED_EXTERNAL_BOOTSTRAP",
        "BLOCKED_LINEAGE_TRANSACTION",
        "BLOCKED_PAYLOAD_OBJECT_AVAILABILITY",
        "BLOCKED_PREW0_EVIDENCE",
        "BLOCKED_K4",
        "BLOCKED_ARTIFACT_MESH_DEVICE_RECOVERY",
        "pendingAdmission",
        "quarantinedAdmission",
    ]
    reason_code: str | None
```

Its serialized field set is exactly `{terminal,reason_code}`. Validation uses
this closed map; no arbitrary reason string is accepted:

```text
BLOCKED_SOURCE_DRIFT -> SOURCE_BYTES_CHANGED
BLOCKED_DESTINATION_DRIFT -> DESTINATION_PREIMAGE_CHANGED
BLOCKED_IMPORT_REVIEW -> BLOCKED_C3_REVIEW | IMPORT_REVIEW_VERIFIER_MISSING | IMPORT_REVIEW_RECORD_MISSING | IMPORT_REVIEW_REOPEN_RECEIPT_MISSING | IMPORT_REVIEW_TRUST_ANCHOR_INVALID | IMPORT_REVIEW_SIGNATURE_INVALID | IMPORT_REVIEW_ROWSET_MISMATCH | IMPORT_REVIEW_CONTEXT_MISMATCH
BLOCKED_EXTERNAL_BOOTSTRAP -> BLOCKED_EXTERNAL_SERVICE_BINDING | BLOCKED_BOOTSTRAP_CONTRACT_HANDOFF | BLOCKED_NON_LITERAL_GATE_PROGRAM | EVALUATION_LEASE_EXPIRED | CEREMONY_UNAVAILABLE | RUNNER_ATTESTATION_UNAVAILABLE
BLOCKED_LINEAGE_TRANSACTION -> LINEAGE_TRANSACTION_DIVERGENCE
BLOCKED_PAYLOAD_OBJECT_AVAILABILITY -> PAYLOAD_OBJECT_NOT_HOST_REOPENED
BLOCKED_PREW0_EVIDENCE -> PREW0_GATE_EVIDENCE_INCOMPLETE
BLOCKED_K4 -> RELEASE_PROFILE_BINDING_UNAVAILABLE | RELEASE_XCODE27_UNAVAILABLE | ENHANCED_SECURITY_HOST_PROFILE_UNAVAILABLE | ENHANCED_SECURITY_HELPER_PROFILE_UNAVAILABLE | PRODUCT_SIGNING_IDENTITY_UNAVAILABLE | PHYSICAL_IOS27_DEVICE_UNAVAILABLE | EXTERNAL_ENCRYPTED_CUSTODY_UNAVAILABLE | INDEPENDENT_ATTESTER_UNAVAILABLE | SHORT_LIVED_REOPEN_UNAVAILABLE | RETENTION_DESTRUCTION_POLICY_UNAVAILABLE | EPHEMERAL_ENCRYPTED_STORAGE_UNAVAILABLE | RAW_CLEANUP_UNVERIFIED
BLOCKED_ARTIFACT_MESH_DEVICE_RECOVERY -> TASK0_DRIFT | PROTECTED_DATA_UNAVAILABLE | MATRIX_ROW_MISSING | TIMING_OR_TERMINAL_MISMATCH | FIXTURE_SUBSTITUTION | RAW_REOPEN_FAILED | SHIPPING_REACHABILITY_VIOLATION | CANDIDATE_MODULE_ONLY_PROOF | CUSTODY_CLEANUP_UNVERIFIED
pendingAdmission -> null
quarantinedAdmission -> IDENTITY_MISMATCH | HOST_AUDIT_DIVERGENCE | BUNDLE_SUBSTITUTION | DUPLICATE_EFFECT | ATTESTATION_MISMATCH
```

`reason_code` is null only for `pendingAdmission`; every blocked or
quarantined terminal requires exactly one listed code.
`admitted`, internal `finalized`, and lower-case `blocked`/`quarantined` are
invalid error terminals. An error never carries a partial `AdmittedWaveV1`.

`pin_payload_and_issue_lease` is unavailable before the distinct external
object-write authorization and host reopen. `run_active_gates` owns the
controller-side physical-broker phase and returns one service-envelope-bound
bundle; candidate code cannot construct or supplement it.
`assemble_import_and_finalize` derives every evidence leaf from that bundle
and B0 contracts. Its first invocation closes the deterministic `Cw/Sw`
object/import/intent identity only in non-host quarantine, publishes the
advance-authorization request, and waits with zero target-host effects. After
the fresh authorization is authenticated and reopened, the same method and
same lease/bundle/assembly identity resume target-host import/reopen, receipt,
`AdmissionIntent`, CAS, and finalization inside the external service.

All four methods are recovery operations over immutable service records:

1. `reopen_admitted_predecessor()` is a pure authenticated query. Repeating it
   for the same finalized chain head returns a byte-identical
   `AdmittedWaveV1`; a changed head is a new caller operation, never mutation
   of the prior result.
2. `pin_payload_and_issue_lease(payload_oid)` is keyed by repository,
   predecessor-chain digest, payload commit/tree, active catalog digest, and
   dispatch intent. Before payload host import it reopens the one
   `PayloadDispatchAuthorizationV1`; every unknown authorization/import/
   proposal-ref/dispatch/run-ref outcome is queried. A retry returns the same
   proposal receipt and same `EvaluationLease`, and each host/service effect
   count remains one. A failed effect consumes the authorization; its receipt
   digest cannot authorize a new attempt. While that evaluation is open or
   terminal, creation of a new lease or second evaluation for the same key is
   forbidden.
3. `run_active_gates(same_evaluation_lease)` means query/resume, not rerun. It
   reopens the one append-only evaluation record, resumes only missing
   non-effectful predicates, and uses create-once per-program execution keys.
   If a terminal authenticated gate bundle already exists, every retry returns
   those exact canonical bytes. A completed or audit-ambiguous physical
   request is queried through broker/custody/attester records; it is never
   driven a second time. Lease substitution, a second evaluation, or a
   different bundle for the same lease maps to
   `quarantinedAdmission`.
4. `assemble_import_and_finalize(same_lease,same_bundle)` is keyed by lease,
   authenticated-bundle digest, assembly-contract digest, deterministic Cw/Sw
   identities, advance-authorization request, object-set/import/intent keys,
   protection projection, and intent key. It waits for or queries the one
   `ProtectedRefAdvanceAuthorizationV1` before target-host import, then queries
   and resumes the same import/intent/CAS/attestation records. It never
   constructs a second Cw, Sw, import receipt, or intent under a consumed
   authorization. Repetition after success returns the byte-identical
   `AdmittedWaveV1` and program terminal `admitted`; successful CAS without
   the same-intent attestation returns `pendingAdmission`; any authorization,
   assembly, binding, count, or lineage mismatch returns
   `quarantinedAdmission`.

An expired lease with no terminal bundle does not authorize a replacement
lease automatically: the operation returns `BLOCKED_EXTERNAL_BOOTSTRAP` with
a reason code `EVALUATION_LEASE_EXPIRED` until operator policy resolves the
original evaluation. Tests crash after every durable boundary and prove these
four retry laws, including “physical execution count remains one”.

The existing protocol/recovery test methods add subtests that round-trip all
six external-service records above and reject every missing/extra field,
duplicate key, noncanonical byte sequence, invalid signature/role/nonce,
expired-before-effect or cross-intent replayed authorization, wrong
proposal/run ref, a dispatch reused for a second evaluation, advance
authorization issued before deterministic
quarantine-object closure or after an unauthorized target-host import,
wrong old/new OID or bundle/object-set/import-key/intent digest, protection
drift, and a CAS
attempt with no fresh advance authorization. Crash immediately before and
after both authorization requests and persistence, both object imports,
proposal-ref/dispatch/run-ref creation, intent creation, CAS, and final
attestation; re-entry must resume one identity and every physical/ref/import/
intent/CAS effect count remains one.
The governance-validation cases additionally reject any non-seven-row,
unordered, duplicate, wrong-mode, or wrong-blob preparation set; altered
commit/tree/object-set, workflow path/blob, job, pin, Python, signed prefix,
projection, validation ref, intent, operator, expiry, nonce, or signature;
authorization after target-host import; implicit push; canonical/development/
runner/proposal/existing-ref mutation; a second ref or run under one
authorization; and a success observation with any changed host binding.
Crashes at authorization persistence, object import, ref creation, and run
observation query must reopen the same operation. Unknown host outcomes cause
queries, never another import/ref/run effect. The required-check migration
cases cover all three dispositions, two distinct operators, exact
before/after provider observations, the exact successful
`GovernanceValidationRunObservationV1` digest, unchanged unrelated policy,
and byte-identical admission protection.

Every Authority/W0/Artifact consumer performs this exact three-branch
re-entry before any pre-final ref guard:

1. If the authenticated protected ref still equals the prior admitted `Sw`,
   reopen the same-Pw proposal/evaluation key. Idempotent pin returns the
   original receipt and opaque lease, active-gate recovery returns the
   original bundle or resumes its missing non-effectful work, and finalization
   resumes the same intent.
2. If `reopen_admitted_predecessor()` returns a fully authenticated
   `AdmittedWaveV1` whose `payload_commit_oid` equals this exact `Pw` and whose
   seal, successful CAS audit, and finalized attestation all verify, the
   operation already completed. Return/adopt those byte-identical admitted
   bytes immediately; do not repin, issue a lease, rerun a gate/physical
   effect, or create another intent.
3. Any other protected head, payload, predecessor chain, seal, CAS, or
   attestation relation raises
   `AdmissionTerminalError(terminal="quarantinedAdmission",
   reason_code="HOST_AUDIT_DIVERGENCE")`.

Therefore no consumer may hard-assert “protected ref still equals old Sw”
before querying the service's authenticated recovery state. A crash after CAS
or attestation but before the caller receives the return value deterministically
takes branch 2.

---

## File Responsibility Map

### Candidate diagnostic and checked-in contracts

- Modify `.github/workflows/qinao-wave-admission.yml`: immutable OIDC client workflow, no authority selection and no repository write permission.
- Modify `scripts/check_qinao_wave_admission.py`: structural/offline preflight only; validate the new closed schemas and refuse authoritative claims.
- Modify `scripts/test_check_qinao_wave_admission.py`: candidate-preflight, schema, workflow-permission, no-selection, and non-authoritative tests.
- Modify `docs/superpowers/specs/qinao-wave-admission-bootstrap-v1.schema.json`: signed bootstrap projection, including the closed evidence-storage profile and external runner/service identity.
- Modify `docs/superpowers/specs/qinao-wave-admission-receipt-v1.schema.json`: keep exact `Pw/Cw/Sw` bindings, add the privacy-clean `source_import_review_audit_root_digest`, and add no external post-CAS attestation payload.
- Create `docs/superpowers/specs/qinao-payload-proposal-receipt-v1.schema.json`: externally signed content-addressed proposal-object availability; no caller wave/ref authority.
- Create `docs/superpowers/specs/qinao-evaluation-dispatch-intent-v1.schema.json`: append-only mapping from one signed payload proposal to one opaque create-once B0 run ref; no workflow input.
- Create `docs/superpowers/specs/qinao-external-physical-gate-binding-v1.schema.json`: signed producer/attester/custody/device/retention/broker contract for active physical gates.
- Create `docs/superpowers/specs/qinao-physical-evidence-request-v1.schema.json`: B0-generated, lease/Pw/challenge-bound controller request.
- Create `docs/superpowers/specs/qinao-physical-evidence-projection-receipt-v1.schema.json`: privacy-clean independently attested external result reopened from custody.
- Create `docs/superpowers/specs/qinao-evidence-assembly-v1.schema.json`: active contract/output allowlist, deterministic commit identities, exact Cw/Sw topology, and receipt construction.
- Create `docs/superpowers/specs/qinao-git-object-import-receipt-v1.schema.json`: immutable host-side reopen proof for Cw/Sw objects before CAS.
- Create `docs/superpowers/specs/qinao-bootstrap-object-import-receipt-v1.schema.json`: externally authorized import/reopen proof for the previously local-only B0 object closure.
- Create `docs/superpowers/specs/qinao-gate-program-spec-v1.schema.json`: closed 152-cell/42-program source grammar with primitive-discriminated exact inventories.
- Create `docs/superpowers/specs/qinao-gate-catalog-v1.schema.json`: closed 19-row catalog, phase, assembly, digest, and generated-artifact grammar.
- Create `docs/superpowers/specs/qinao-gate-contract-v1.schema.json`: closed per-gate eight-wave program projection and output contract.
- Create `docs/superpowers/specs/qinao-gate-corpus-v1.schema.json`: closed three-class expanded fixture grammar.
- Create `docs/superpowers/specs/qinao-import-review-v1.schema.json`: preparation-only, batch-scoped, signed two-operator C0 review record; not B0/product authority.
- Create `docs/superpowers/specs/qinao-import-review-reopen-receipt-v1.schema.json`: immutable content-addressed service reopen/transparency receipt for one C1, C2, or C3 record.
- Modify `scripts/check_qinao_import_map.py`: preserve the pre-verifier all-hold structural path; atomically require fixed-path verified records for every non-hold digest group.
- Modify `scripts/test_qinao_import_map.py`: all-hold compatibility, opaque-verifier integration, C1/C2/C3 coexistence, exact postimage, and substitution tests.
- Modify `docs/superpowers/evidence/qinao-wave-admission/bootstrap-candidate-manifest.json`: retain the typed `external_bootstrap_unavailable` projection without profile or authority.

### Immutable bootstrap runtime

- Create `scripts/qinao_admission_protocol_v1.py`: canonical JSON, closed dataclasses, digest/domain-separation helpers, signed lease/result/envelope validation.
- Create `scripts/test_qinao_admission_protocol_v1.py`: protocol typing, canonicalization, duplicate/unknown-field, signature-envelope, and no-selection tests.
- Create `scripts/qinao_wave_verifier_v0.py`: exact-OID tree materialization, B0 bundle verification, isolated module execution, output quotas.
- Create `scripts/test_qinao_wave_verifier_v0.py`: disposable-repository isolation, symlink/mode/OID, candidate-import, timeout/output/network, and substitution tests.
- Create `scripts/qinao_protected_admission_runner.py`: no-argument OIDC client, payload-proposal lease loop, V0 invocation, closed evidence-bundle upload, and assembly/admission recovery polling.
- Create `scripts/test_qinao_protected_admission_runner.py`: fake HTTPS service and fake OIDC endpoint tests; prove runner cannot construct/import Cw/Sw, perform Git CAS, or select authority inputs.
- Create `scripts/qinao_external_physical_gate_v0.py`: controller-only signed request/broker/receipt verifier; it is never imported into the isolated evaluator.
- Create `scripts/test_qinao_external_physical_gate_v0.py`: producer/attester separation, custody reopen, stale challenge, policy/profile substitution, privacy projection, and crash-resume tests.
- Create `scripts/build_qinao_gate_catalog_v0.py`: one-way deterministic program-source projector and read-only byte verifier; not active B0 runtime.
- Create `scripts/qinao_import_review_v1.py`: managed-anchor loader, fixed-batch ImportReviewV1/reopen verifier, opaque verified-record type, exact map-postimage validator, and privacy-clean audit-root compiler.
- Create `scripts/test_qinao_import_review_v1.py`: closed shape, managed-anchor/signature substitution, two-person policy, context/postimage equality, append-only reopen, restart, C1/C2/C3 coexistence, and no-authority tests.

### Complete through-W6 gate set

- Create `scripts/qinao_gate_modules/bootstrap-paths-v1.json`: exact regular-file set extracted into `B0`.
- Create `scripts/qinao_gate_modules/v0/program-spec-v1.json`: sole literal 19×8 program, inventory, output, and corpus source.
- Create `scripts/qinao_gate_modules/v0/catalog-v1.json`: 19 stable rows and exact required-gate sets for all eight admissions.
- Create `scripts/qinao_gate_modules/v0/service-binding-v1.json`: immutable nonsecret service-origin/TLS/signing/OIDC/runner-ref binding whose bytes and `import_review_trust_anchor_digest` must match the enterprise-managed Preparation-R anchor before B0 proposal.
- Create `scripts/qinao_gate_modules/v0/runtime.py`: only module ABI and bounded bootstrap-helper invocation.
- Create `scripts/qinao_gate_modules/v0/contracts/<stem>.json`: one closed immutable contract for each gate.
- Create `scripts/qinao_gate_modules/v0/modules/<stem>.py`: one executable wrapper for each gate.
- Create `scripts/qinao_gate_modules/v0/corpora/<stem>.json`: non-empty positive, negative, and mutation corpus for each gate.
- Create `scripts/test_qinao_gate_catalog_v0.py`: exact catalog/path/digest/cardinality/module-ABI/corpus tests.

The 19 stems are:

```text
owner_ledger
review_candidate
review_closure
plan_remediation
xcode27_toolchain
ios27_floor
production_reachability
architecture_closure
v2_quarantine
provider_boundary
w0_open_set
k4_platform_proof
samplehost_ios
contracts_layercell
artifact_mesh_device_recovery
semantic_statelake_context
silicon_execution_spine
sovereign_release_effects
runtime_replay_certification
```

### External-service conformance and crash recovery

- Create `docs/superpowers/specs/qinao-admission-evaluation-lease-v1.schema.json`: service-derived immutable evaluation lease.
- Create `docs/superpowers/specs/qinao-admission-intent-v1.schema.json`: immutable intent and supersession lineage.
- Create `docs/superpowers/specs/qinao-admission-attestation-v1.schema.json`: finalized post-CAS attestation.
- Create `docs/superpowers/specs/qinao-bootstrap-attestation-v1.schema.json`: two-operator bootstrap root attestation.
- Create `docs/superpowers/specs/qinao-bootstrap-intent-v1.schema.json`: two-approval, single-service, append-only create-or-reopen ceremony transaction.
- Create `docs/superpowers/specs/qinao-admission-service-state-v1.schema.json`: closed crash-recovery state projection, including the internal governance-validation authorization/object-import/dispatch/ref/run/migration records.
- Create `docs/superpowers/specs/qinao-admission-service-binding-v1.schema.json`: closed public service/OIDC/runner binding; contains no credential.
- Create `scripts/qinao_admission_recovery_oracle.py`: pure reference transition function used to conformance-test the external service.
- Create `scripts/test_qinao_admission_recovery_oracle.py`: exhaustive legal/illegal state-event matrix.

### B0 proposal, ceremony verification, and lineage

- Create `scripts/build_qinao_bootstrap_lineage.py`: deterministic temporary-index B0 builder, exact minimality proof, `Pw` reparent builder, and atomic three-ref transaction (two creates plus one expected-old update).
- Create `scripts/test_build_qinao_bootstrap_lineage.py`: disposable-repository B0/lineage/ref-transaction tests.
- Create `scripts/prepare_qinao_bootstrap_ceremony.py`: consume Input A and produce a canonical unsigned external ceremony request.
- Create `scripts/verify_qinao_bootstrap_export.py`: validate Output B against B0, Input A, Git-host identity, two independent approvals, catalog, runner, and profile.
- Create `scripts/test_qinao_bootstrap_ceremony.py`: request/export substitution, stale authority, one-operator, profile-placement, and self-reference tests.

---

### Task 1: Freeze Strict Admission Protocol Primitives

**Files:**
- Create: `scripts/qinao_admission_protocol_v1.py`
- Create: `scripts/test_qinao_admission_protocol_v1.py`

**Interfaces:**
- Consumes: UTF-8 JSON bytes, Git OIDs, SHA-256 digests, and external-service envelopes.
- Produces: `canonical_json_bytes`, `sha256_hex`, `parse_closed_json`,
  `EvaluationLease`, `ExternalPhysicalGateBinding`,
  `PayloadProposalReceiptV1`, `GateResult`,
  `AuthenticatedGateResultBundle`, `ImportedCommit`, `AdmittedWaveV1`,
  `PayloadDispatchAuthorizationV1`,
  `ProtectedRefAdvanceAuthorizationV1`,
  `GovernanceValidationAuthorizationV1`,
  `GovernanceValidationRunObservationV1`,
  `ServiceEnvelope`, `ServiceBinding`, `AdmissionTerminalError`,
  `ProtectedAdmissionClient`, a
  preparation-only `canonicalize-service-binding` CLI, and domain-separated
  digest functions used by Tasks 2, 3, 5, 6, 8, and 9.

- [ ] **Step 1: Write RED canonical and closed-object tests**

First create an importable `scripts/qinao_admission_protocol_v1.py` typed RED
seam containing the final class/function names below. Every parser and client
operation raises `ProtocolError("qinao.admission-protocol.unimplemented")`;
tests import normally, discover the named methods, and assert that exact
diagnostic. A `_FailedTest` import placeholder is not discovery.

Add `import inspect` and `from dataclasses import fields`, then add exact tests
for sorted UTF-8 output, duplicate keys, NaN/infinity, booleans-as-integers,
unknown keys, uppercase digests, short/full Git OIDs, and a caller-supplied
authority selector:

```python
class AdmissionProtocolV1Tests(unittest.TestCase):
    def test_canonical_json_is_stable_utf8(self) -> None:
        self.assertEqual(
            canonical_json_bytes({"z": "脑", "a": 1}),
            b'{"a":1,"z":"\xe8\x84\x91"}',
        )

    def test_closed_json_rejects_duplicate_and_unknown_fields(self) -> None:
        with self.assertRaisesRegex(ProtocolError, "duplicate JSON key"):
            parse_closed_json(b'{"a":1,"a":2}', fields={"a"})
        with self.assertRaisesRegex(ProtocolError, "unknown fields"):
            parse_closed_json(b'{"a":1,"wave":"W0"}', fields={"a"})

    def test_external_authorization_records_are_closed_and_not_client_authority(
        self,
    ) -> None:
        self.assertEqual(
            {
                field.name
                for field in fields(PayloadDispatchAuthorizationV1)
            },
            {
                "schema_version", "repository_identity",
                "predecessor_chain_digest", "payload_commit_oid",
                "payload_tree_oid", "proposal_object_set_digest",
                "proposal_ref", "dispatch_intent_id", "run_ref",
                "active_verifier_bundle_digest",
                "operator_principal_digest", "operator_role_digest",
                "authorized_at", "expires_at", "nonce", "signature",
            },
        )
        self.assertEqual(
            {
                field.name
                for field in fields(ProtectedRefAdvanceAuthorizationV1)
            },
            {
                "schema_version", "repository_identity", "protected_ref",
                "wave", "expected_old_oid", "payload_commit_oid",
                "evidence_commit_oid", "seal_commit_oid",
                "payload_proposal_receipt_digest", "evaluation_lease_id",
                "authenticated_gate_bundle_digest",
                "evidence_object_set_digest",
                "intended_git_object_import_key", "admission_intent_key",
                "live_protection_projection_sha256",
                "operator_principal_digest", "operator_role_digest",
                "authorized_at", "expires_at", "nonce", "signature",
            },
        )
        self.assertEqual(
            {
                field.name
                for field in fields(GovernanceValidationAuthorizationV1)
            },
            {
                "schema_version", "repository_identity",
                "development_branch", "preparation_commit_oid",
                "preparation_tree_oid", "preparation_path_rows",
                "preparation_object_set_digest", "workflow_path",
                "workflow_blob_oid", "job_id", "checkout_action_oid",
                "setup_python_action_oid", "python_version",
                "run_ref_prefix", "validation_ref", "dispatch_intent_id",
                "admission_protection_projection_sha256",
                "operator_principal_digest", "operator_role_digest",
                "authorized_at", "expires_at", "nonce", "signature",
            },
        )
        self.assertEqual(
            {
                field.name
                for field in fields(GovernanceValidationRunObservationV1)
            },
            {
                "schema_version", "repository_identity",
                "development_branch",
                "governance_validation_authorization_digest",
                "validation_ref", "dispatch_intent_id",
                "preparation_commit_oid", "preparation_tree_oid",
                "preparation_object_set_digest", "workflow_path",
                "workflow_blob_oid", "job_id", "github_app_id",
                "checkout_action_oid", "setup_python_action_oid",
                "python_version", "run_id", "run_attempt", "conclusion",
                "host_response_digest", "observed_at", "service_signature",
            },
        )
        public_methods = {
            name
            for name, value in inspect.getmembers(
                ProtectedAdmissionClient, inspect.isfunction
            )
            if not name.startswith("_")
        }
        self.assertEqual(
            public_methods,
            {
                "reopen_admitted_predecessor",
                "pin_payload_and_issue_lease",
                "run_active_gates",
                "assemble_import_and_finalize",
            },
        )

    def test_evaluation_lease_has_no_caller_selection_fields(self) -> None:
        forbidden = {
            "requested_wave", "repository_ref", "release_profile",
            "verifier_path", "gate_module_path", "protection_policy",
        }
        self.assertTrue(forbidden.isdisjoint(EvaluationLease.FIELD_NAMES))

    def test_release_profile_binding_is_closed_and_prew0_has_none(self) -> None:
        self.assertEqual(
            ReleaseProfileBinding.FIELD_NAMES,
            {
                "schema_version", "profile_id", "profile_version",
                "project_or_package_path", "scheme", "product",
                "configuration", "sdk", "architectures",
                "deployment_target", "selected_xcode_identity",
                "build_settings_digest",
                "host_entitlement_template_digest",
                "helper_entitlement_template_digest", "public_team_id",
                "profile_class", "host_bundle_id", "helper_bundle_id",
                "allowed_device_platform", "allowed_device_os_major",
                "allowed_device_os_build_policy",
            },
        )
        lease = parse_evaluation_lease(valid_prew0_lease_bytes())
        self.assertEqual(lease.derived_wave, "preW0")
        self.assertEqual(lease.selected_release_profiles, ())

    def test_same_lease_returns_identical_bundle_without_second_physical_effect(self) -> None:
        client, lease = durable_client_with_one_physical_gate()
        first = client.run_active_gates(lease)
        crash_and_reopen(client)
        second = client.run_active_gates(lease)
        self.assertEqual(first.canonical_bytes, second.canonical_bytes)
        self.assertEqual(client.physical_execution_count(lease.lease_id), 1)
        self.assertEqual(client.evaluation_count(lease.evaluation_key), 1)

    def test_same_payload_and_prior_reopen_original_receipt_and_opaque_lease(self) -> None:
        client = durable_client_with_admitted_predecessor()
        first_receipt, first_lease = client.pin_payload_and_issue_lease(
            PAYLOAD_OID
        )
        crash_and_reopen(client)
        second_receipt, second_lease = client.pin_payload_and_issue_lease(
            PAYLOAD_OID
        )
        self.assertEqual(
            first_receipt.canonical_bytes,
            second_receipt.canonical_bytes,
        )
        self.assertEqual(
            first_lease.canonical_bytes,
            second_lease.canonical_bytes,
        )
        self.assertEqual(client.evaluation_count(first_lease.evaluation_key), 1)

    def test_same_lease_and_bundle_resume_one_intent(self) -> None:
        client, lease, bundle = durable_client_after_cas_before_attestation()
        first = client.assemble_import_and_finalize(lease, bundle)
        second = client.assemble_import_and_finalize(lease, bundle)
        self.assertEqual(first.canonical_bytes, second.canonical_bytes)
        self.assertEqual(client.intent_count(lease.lease_id), 1)
        self.assertEqual(client.program_terminal, "admitted")

    def test_crash_after_cas_and_attestation_before_return_adopts_existing_wave(self) -> None:
        client, expected = durable_client_crashed_after_final_attestation()
        recovered = recover_consumer_operation(client=client, payload_oid=PAYLOAD_OID)
        self.assertEqual(recovered.canonical_bytes, expected.canonical_bytes)
        self.assertEqual(client.pin_call_count, 0)
        self.assertEqual(client.lease_issue_count, 0)
        self.assertEqual(client.gate_run_count, 0)
        self.assertEqual(client.physical_execution_count_total, 0)
        self.assertEqual(client.intent_create_count, 0)

    def test_reentry_with_unrelated_head_quarantines_before_repin(self) -> None:
        client = durable_client_with_other_authenticated_head()
        with self.assertRaises(AdmissionTerminalError) as caught:
            recover_consumer_operation(client=client, payload_oid=PAYLOAD_OID)
        self.assertEqual(caught.exception.terminal, "quarantinedAdmission")
        self.assertEqual(
            caught.exception.reason_code,
            "HOST_AUDIT_DIVERGENCE",
        )
        self.assertEqual(client.pin_call_count, 0)

    def test_pending_is_typed_and_never_returns_partial_admitted_wave(self) -> None:
        with self.assertRaises(AdmissionTerminalError) as caught:
            client_after_cas_without_attestation().assemble_import_and_finalize(
                lease,
                bundle,
            )
        self.assertEqual(caught.exception.terminal, "pendingAdmission")
        self.assertIsNone(caught.exception.reason_code)

    def test_quarantine_is_typed_and_closed(self) -> None:
        with self.assertRaises(AdmissionTerminalError) as caught:
            client_with_bundle_substitution().assemble_import_and_finalize(
                lease,
                bundle,
            )
        self.assertEqual(caught.exception.terminal, "quarantinedAdmission")
        self.assertEqual(caught.exception.reason_code, "BUNDLE_SUBSTITUTION")

    def test_blocked_is_typed_and_closed(self) -> None:
        with self.assertRaises(AdmissionTerminalError) as caught:
            client_without_runner_quote().run_active_gates(lease)
        self.assertEqual(
            caught.exception.terminal,
            "BLOCKED_EXTERNAL_BOOTSTRAP",
        )
        self.assertEqual(
            caught.exception.reason_code,
            "RUNNER_ATTESTATION_UNAVAILABLE",
        )

    def test_every_terminal_reason_pair_round_trips_and_no_other_pair_parses(self) -> None:
        for terminal, reasons in ADMISSION_REASON_CODES_BY_TERMINAL.items():
            for reason_code in reasons:
                encoded = canonical_terminal_error_bytes(
                    AdmissionTerminalError(
                        terminal=terminal,
                        reason_code=reason_code,
                    )
                )
                decoded = parse_admission_terminal_error(encoded)
                self.assertEqual(
                    (decoded.terminal, decoded.reason_code),
                    (terminal, reason_code),
                )
        with self.assertRaisesRegex(ProtocolError, "unknown terminal/reason"):
            AdmissionTerminalError(
                terminal="BLOCKED_K4",
                reason_code="arbitrary-detail",
            )
        with self.assertRaisesRegex(ProtocolError, "unknown fields"):
            parse_admission_terminal_error(
                b'{"terminal":"pendingAdmission","reason_code":null,'
                b'"detail":"hidden"}'
            )
```

Also reject a replacement lease while the first evaluation is open or
terminal, a different bundle for the same lease, a bundle reused under another
lease, second Cw/Sw bytes, second intent, and a second physical execution after
an ambiguous transport failure. For both admission authorization records,
mutate/omit/add each field, invalidate signature/role/nonce/expiry, substitute
one bound digest/ref/key, and try to construct a verified value from only a
digest or reopened Boolean. For the governance records, mutate each field
individually; omit/add a field; reorder, duplicate, remove, or add a
preparation row; change one mode/blob; move the validation ref outside the
signed prefix; change one workflow/job/pin/Python/object binding; expire or
replay the nonce; and attempt a second ref/run under the same authorization.
Every mutation must fail before a target-host effect. The RED fake exposes
durable counters so query/resume cannot masquerade as rerun.

- [ ] **Step 2: Run the focused RED suite**

Run:

```bash
set -euo pipefail
cd /Users/changgeng/.codex/worktrees/e4d7/Project06
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_admission_protocol_v1
```

Expected: at least three named methods are discovered and fail only on
`qinao.admission-protocol.unimplemented`; syntax/import failure is not RED.

- [ ] **Step 3: Implement the strict value types and digest domains**

Use frozen dataclasses and exact field sets:

```python
@dataclass(frozen=True)
class CommitIdentity:
    author_name: str
    author_email: str
    authored_at: str
    committer_name: str
    committer_email: str
    committed_at: str
    message: str

@dataclass(frozen=True)
class VerificationToolchainBinding:
    xcode_version: str
    xcode_build_version: str
    iphoneos_sdk_version: str
    runner_image_identity: str
    runner_attestation_identity_digest: str
    runner_isolation_profile_digest: str
    toolchain_probe_contract_digest: str
    profile_digest: str

@dataclass(frozen=True)
class GateBinding:
    gate_id: str
    gate_contract_digest: str
    module_bundle_digest: str
    corpus_digest: str
    evidence_output_contract_digest: str

@dataclass(frozen=True)
class ReleaseProfileBinding:
    schema_version: Literal[1]
    profile_id: str
    profile_version: str
    project_or_package_path: str
    scheme: str
    product: str
    configuration: Literal["Release"]
    sdk: Literal["iphoneos"]
    architectures: tuple[Literal["arm64"], ...]
    deployment_target: Literal["27.0"]
    selected_xcode_identity: str
    build_settings_digest: str
    host_entitlement_template_digest: str
    helper_entitlement_template_digest: str
    public_team_id: str
    profile_class: str
    host_bundle_id: str
    helper_bundle_id: str
    allowed_device_platform: Literal["iOS"]
    allowed_device_os_major: Literal[27]
    allowed_device_os_build_policy: str

@dataclass(frozen=True)
class ExternalPhysicalGateBinding:
    schema_version: Literal[1]
    gate_id: str
    evidence_class_id: str
    broker_capability_identity_digest: str
    producer_principal_digest: str
    attester_principal_digest: str
    custody_profile_digest: str
    device_policy_digest: str
    retention_policy_digest: str
    destruction_policy_digest: str
    request_contract_digest: str
    private_evidence_contract_digest: str
    projection_contract_digest: str
    toolchain_profile_digest: str

@dataclass(frozen=True)
class EvaluationLease:
    lease_id: str
    evaluation_subject_oid: str
    repository_id: str
    derived_wave: str
    prior_seal_oid: str
    payload_proposal_receipt_digest: str
    payload_object_ref: str
    payload_commit_oid: str
    payload_tree_oid: str
    bootstrap_commit_oid: str
    active_verifier_bundle_digest: str
    required_gate_rows: tuple[GateBinding, ...]
    active_gate_rows: tuple[GateBinding, ...]
    verification_toolchain: VerificationToolchainBinding
    selected_release_profiles: tuple[ReleaseProfileBinding, ...]
    external_physical_gate_bindings: tuple[
        ExternalPhysicalGateBinding, ...
    ]
    predecessor_admission_chain_digest: str
    source_import_review_audit_root_digest: str
    live_policy_observation_digest: str
    cw_output_contract_digest: str
    cw_commit_identity: CommitIdentity
    sw_commit_identity: CommitIdentity
    receipt_created_at: str
    challenge: str
    expires_at: str

@dataclass(frozen=True)
class EvidenceOutput:
    path: str
    mode: Literal["100644"]
    producer_step_id: str
    schema_digest: str
    evidence_class_id: str
    maximum_bytes: int
    blob_sha256: str
    size_bytes: int

@dataclass(frozen=True)
class GateResult:
    lease_id: str
    gate_id: str
    derived_wave: str
    payload_commit_oid: str
    payload_tree_oid: str
    gate_contract_digest: str
    module_bundle_digest: str
    corpus_digest: str
    discovered_subject_count: int
    executed_predicate_count: int
    positive_case_count: int
    negative_case_count: int
    mutation_case_count: int
    result: Literal["passed", "failed"]
    evidence_outputs: tuple[EvidenceOutput, ...]
    evidence_bundle_digest: str

@dataclass(frozen=True)
class EvidenceAssemblyResult:
    lease_id: str
    payload_commit_oid: str
    payload_tree_oid: str
    evidence_commit_oid: str
    evidence_tree_oid: str
    seal_commit_oid: str
    seal_tree_oid: str
    receipt_blob_sha256: str
    git_object_import_receipt_digest: str
    admission_intent_id: str

@dataclass(frozen=True)
class PayloadProposalReceiptV1:
    schema_version: Literal[1]
    repository_id: str
    payload_commit_oid: str
    payload_tree_oid: str
    service_owned_ref: str
    object_set_digest: str
    uploader_authorization_digest: str
    host_transaction_id: str
    host_reopen_observation_digest: str
    issued_at: str
    signing_identity_digest: str
    signature: str

@dataclass(frozen=True)
class PayloadDispatchAuthorizationV1:
    schema_version: Literal[1]
    repository_identity: str
    predecessor_chain_digest: str
    payload_commit_oid: str
    payload_tree_oid: str
    proposal_object_set_digest: str
    proposal_ref: str
    dispatch_intent_id: str
    run_ref: str
    active_verifier_bundle_digest: str
    operator_principal_digest: str
    operator_role_digest: str
    authorized_at: str
    expires_at: str
    nonce: str
    signature: str

@dataclass(frozen=True)
class ProtectedRefAdvanceAuthorizationV1:
    schema_version: Literal[1]
    repository_identity: str
    protected_ref: str
    wave: Literal["preW0", "W0", "W1", "W2", "W3", "W4", "W5", "W6"]
    expected_old_oid: str
    payload_commit_oid: str
    evidence_commit_oid: str
    seal_commit_oid: str
    payload_proposal_receipt_digest: str
    evaluation_lease_id: str
    authenticated_gate_bundle_digest: str
    evidence_object_set_digest: str
    intended_git_object_import_key: str
    admission_intent_key: str
    live_protection_projection_sha256: str
    operator_principal_digest: str
    operator_role_digest: str
    authorized_at: str
    expires_at: str
    nonce: str
    signature: str

@dataclass(frozen=True)
class GovernancePreparationPathRow:
    path: str
    mode: Literal["100644"]
    blob_oid: str

@dataclass(frozen=True)
class GovernanceValidationAuthorizationV1:
    schema_version: Literal[1]
    repository_identity: str
    development_branch: str
    preparation_commit_oid: str
    preparation_tree_oid: str
    preparation_path_rows: tuple[GovernancePreparationPathRow, ...]
    preparation_object_set_digest: str
    workflow_path: Literal[".github/workflows/test.yml"]
    workflow_blob_oid: str
    job_id: Literal["qinao-governance"]
    checkout_action_oid: Literal[
        "11bd71901bbe5b1630ceea73d27597364c9af683"
    ]
    setup_python_action_oid: Literal[
        "a309ff8b426b58ec0e2a45f0f869d46889d02405"
    ]
    python_version: Literal["3.12"]
    run_ref_prefix: Literal["refs/heads/qinao-admission-runs/"]
    validation_ref: str
    dispatch_intent_id: str
    admission_protection_projection_sha256: str
    operator_principal_digest: str
    operator_role_digest: str
    authorized_at: str
    expires_at: str
    nonce: str
    signature: str

@dataclass(frozen=True)
class GovernanceValidationRunObservationV1:
    schema_version: Literal[1]
    repository_identity: str
    development_branch: str
    governance_validation_authorization_digest: str
    validation_ref: str
    dispatch_intent_id: str
    preparation_commit_oid: str
    preparation_tree_oid: str
    preparation_object_set_digest: str
    workflow_path: Literal[".github/workflows/test.yml"]
    workflow_blob_oid: str
    job_id: Literal["qinao-governance"]
    github_app_id: int
    checkout_action_oid: Literal[
        "11bd71901bbe5b1630ceea73d27597364c9af683"
    ]
    setup_python_action_oid: Literal[
        "a309ff8b426b58ec0e2a45f0f869d46889d02405"
    ]
    python_version: Literal["3.12"]
    run_id: str
    run_attempt: int
    conclusion: Literal["success"]
    host_response_digest: str
    observed_at: str
    service_signature: str

@dataclass(frozen=True)
class ServiceEnvelope:
    schema_version: Literal[1]
    message_type: str
    message_digest: str
    service_identity: str
    signing_identity_digest: str
    issued_at: str
    signature_algorithm: str
    signature: str

@dataclass(frozen=True)
class AuthenticatedGateResultBundle:
    schema_version: Literal[1]
    lease_id: str
    derived_wave: str
    payload_commit_oid: str
    payload_tree_oid: str
    ordered_gate_result_digests: tuple[str, ...]
    gate_results_index_digest: str
    evidence_output_contract_digest: str
    physical_projection_receipt_digests: tuple[str, ...]
    source_import_review_audit_root_digest: str
    runner_bundle_digest: str
    envelope: ServiceEnvelope

@dataclass(frozen=True)
class ImportedCommit:
    schema_version: Literal[1]
    commit_oid: str
    tree_oid: str
    parent_oids: tuple[str, ...]
    commit_identity_digest: str
    object_pack_digest: str
    imported_object_oids: tuple[str, ...]
    repository_object_database_identity: str
    host_reopen_observation_digest: str
    object_import_receipt_digest: str
    envelope: ServiceEnvelope

@dataclass(frozen=True)
class AdmittedWaveV1:
    schema_version: Literal[1]
    repository_id: str
    derived_wave: str
    predecessor_seal_oid: str
    predecessor_chain_digest: str
    payload_commit_oid: str
    payload_tree_oid: str
    evidence_commit_oid: str
    evidence_tree_oid: str
    seal_commit_oid: str
    seal_tree_oid: str
    receipt_blob_sha256: str
    admission_intent_id: str
    cas_transaction_id: str
    finalized_attestation_digest: str
    admission_chain_digest: str
    source_import_review_audit_root_digest: str
    active_verifier_bundle_digest: str
    active_gate_module_set_digest: str
    selected_release_build_set_digest: str
    envelope: ServiceEnvelope

@dataclass(frozen=True)
class EvaluationDispatchIntentV1:
    schema_version: Literal[1]
    dispatch_intent_id: str
    repository_id: str
    payload_proposal_receipt_digest: str
    run_ref: str
    bootstrap_commit_oid: str
    expected_workflow_identity: str
    created_at: str
    expires_at: str
    status: Literal[
        "prepared", "refCreated", "runObserved", "leased",
        "superseded", "quarantined"
    ]
    predecessor_dispatch_intent_id: str | None
    service_signature: str

@dataclass(frozen=True)
class ServiceBinding:
    schema_version: Literal[1]
    admission_service_identity: str
    admission_service_origin: str
    admission_service_tls_identity_digest: str
    admission_service_signing_identity_digest: str
    runner_oidc_issuer: str
    runner_oidc_subject: str
    runner_oidc_audience: str
    runner_environment: Literal["self-hosted"]
    runner_group: Literal["qinao-admission-protected"]
    runner_label: Literal["qinao-xcode27-arm64-v1"]
    runner_ref: Literal["refs/heads/qinao-admission-bootstrap-v1"]
    run_ref_prefix: Literal["refs/heads/qinao-admission-runs/"]
    payload_proposal_ref_prefix: Literal[
        "refs/heads/qinao-payload-proposals/"
    ]
    runner_workflow_identity: str
    runner_attestation_identity_digest: str
    runner_isolation_profile_digest: str
    physical_evidence_broker_identity_digest: str
    provider_metadata_attestation_digest: str
    import_review_trust_anchor_digest: str

ADMISSION_REASON_CODES_BY_TERMINAL = {
    "BLOCKED_SOURCE_DRIFT": frozenset({"SOURCE_BYTES_CHANGED"}),
    "BLOCKED_DESTINATION_DRIFT": frozenset(
        {"DESTINATION_PREIMAGE_CHANGED"}
    ),
    "BLOCKED_IMPORT_REVIEW": frozenset({
        "BLOCKED_C3_REVIEW",
        "IMPORT_REVIEW_VERIFIER_MISSING",
        "IMPORT_REVIEW_RECORD_MISSING",
        "IMPORT_REVIEW_REOPEN_RECEIPT_MISSING",
        "IMPORT_REVIEW_TRUST_ANCHOR_INVALID",
        "IMPORT_REVIEW_SIGNATURE_INVALID",
        "IMPORT_REVIEW_ROWSET_MISMATCH",
        "IMPORT_REVIEW_CONTEXT_MISMATCH",
    }),
    "BLOCKED_EXTERNAL_BOOTSTRAP": frozenset({
        "BLOCKED_EXTERNAL_SERVICE_BINDING",
        "BLOCKED_BOOTSTRAP_CONTRACT_HANDOFF",
        "BLOCKED_NON_LITERAL_GATE_PROGRAM",
        "EVALUATION_LEASE_EXPIRED",
        "CEREMONY_UNAVAILABLE",
        "RUNNER_ATTESTATION_UNAVAILABLE",
    }),
    "BLOCKED_LINEAGE_TRANSACTION": frozenset(
        {"LINEAGE_TRANSACTION_DIVERGENCE"}
    ),
    "BLOCKED_PAYLOAD_OBJECT_AVAILABILITY": frozenset(
        {"PAYLOAD_OBJECT_NOT_HOST_REOPENED"}
    ),
    "BLOCKED_PREW0_EVIDENCE": frozenset(
        {"PREW0_GATE_EVIDENCE_INCOMPLETE"}
    ),
    "BLOCKED_K4": frozenset({
        "RELEASE_PROFILE_BINDING_UNAVAILABLE",
        "RELEASE_XCODE27_UNAVAILABLE",
        "ENHANCED_SECURITY_HOST_PROFILE_UNAVAILABLE",
        "ENHANCED_SECURITY_HELPER_PROFILE_UNAVAILABLE",
        "PRODUCT_SIGNING_IDENTITY_UNAVAILABLE",
        "PHYSICAL_IOS27_DEVICE_UNAVAILABLE",
        "EXTERNAL_ENCRYPTED_CUSTODY_UNAVAILABLE",
        "INDEPENDENT_ATTESTER_UNAVAILABLE",
        "SHORT_LIVED_REOPEN_UNAVAILABLE",
        "RETENTION_DESTRUCTION_POLICY_UNAVAILABLE",
        "EPHEMERAL_ENCRYPTED_STORAGE_UNAVAILABLE",
        "RAW_CLEANUP_UNVERIFIED",
    }),
    "BLOCKED_ARTIFACT_MESH_DEVICE_RECOVERY": frozenset({
        "TASK0_DRIFT",
        "PROTECTED_DATA_UNAVAILABLE",
        "MATRIX_ROW_MISSING",
        "TIMING_OR_TERMINAL_MISMATCH",
        "FIXTURE_SUBSTITUTION",
        "RAW_REOPEN_FAILED",
        "SHIPPING_REACHABILITY_VIOLATION",
        "CANDIDATE_MODULE_ONLY_PROOF",
        "CUSTODY_CLEANUP_UNVERIFIED",
    }),
    "pendingAdmission": frozenset({None}),
    "quarantinedAdmission": frozenset({
        "IDENTITY_MISMATCH",
        "HOST_AUDIT_DIVERGENCE",
        "BUNDLE_SUBSTITUTION",
        "DUPLICATE_EFFECT",
        "ATTESTATION_MISMATCH",
    }),
}

class AdmissionTerminalError(ProtocolError):
    FIELD_NAMES = frozenset({"terminal", "reason_code"})

    def __init__(self, *, terminal: str, reason_code: str | None) -> None:
        validate_admission_terminal_pair(
            terminal=terminal,
            reason_code=reason_code,
        )
        self.terminal = terminal
        self.reason_code = reason_code
        super().__init__(f"{terminal}:{reason_code or 'none'}")

def canonical_terminal_error_bytes(error: AdmissionTerminalError) -> bytes:
    return canonical_json_bytes({
        "terminal": error.terminal,
        "reason_code": error.reason_code,
    })

def parse_admission_terminal_error(data: bytes) -> AdmissionTerminalError:
    value = parse_closed_json(data, fields={"terminal", "reason_code"})
    return AdmissionTerminalError(
        terminal=require_string(value, "terminal"),
        reason_code=require_optional_string(value, "reason_code"),
    )

class ProtectedAdmissionClient(Protocol):
    def reopen_admitted_predecessor(self) -> AdmittedWaveV1:
        raise NotImplementedError

    def pin_payload_and_issue_lease(
        self,
        payload_oid: str,
    ) -> tuple[PayloadProposalReceiptV1, EvaluationLease]:
        raise NotImplementedError

    def run_active_gates(
        self,
        lease: EvaluationLease,
    ) -> AuthenticatedGateResultBundle:
        raise NotImplementedError

    def assemble_import_and_finalize(
        self,
        lease: EvaluationLease,
        gate_results: AuthenticatedGateResultBundle,
    ) -> AdmittedWaveV1:
        raise NotImplementedError

def admission_intent_key(
    repository_id: str,
    canonical_ref: str,
    derived_wave: str,
    prior_oid: str,
    seal_oid: str,
    receipt_blob_digest: str,
    active_verifier_digest: str,
    live_policy_observation_digest: str,
) -> str:
    parts = (
        repository_id, canonical_ref, derived_wave, prior_oid, seal_oid,
        receipt_blob_digest, active_verifier_digest,
        live_policy_observation_digest,
    )
    return sha256_hex(
        b"qinao-admission-intent-v1\0"
        + b"\0".join(part.encode("ascii") for part in parts)
)
```

The payload and advance authorization parsers require their exact field sets,
canonical bytes, closed wave/ref grammar, full lowercase OIDs/digests,
authorized operator role, unique nonce, and
`authorized_at <= now < expires_at`, then verify the external signature in
domains `qinao-payload-dispatch-authorization-v1` and
`qinao-protected-ref-advance-authorization-v1`. They expose frozen typed
records only after those checks; there is no unchecked constructor or
digest-only “verified” value.

The governance authorization parser requires `required == properties.keys()`
for its closed service-state schema, exactly seven path rows equal to the
literal set above, UTF-8 byte sorting, unique paths/blobs, mode `100644`,
full lowercase Git OIDs, and nonempty opaque identity fields. It reopens the
signed bootstrap projection and requires the record's repository,
`run_ref_prefix`, and projection digest to match. It proves
`workflow_blob_oid` is the blob at `workflow_path` in
`preparation_commit_oid`, recomputes the tree, exact changed-path rows, and
domain-separated object-set digest, and requires
`authorized_at <= now < expires_at`. Its signature domain is
`qinao-governance-validation-authorization-v1`.

The run-observation parser requires positive non-Boolean `github_app_id` and
`run_attempt`, a nonempty opaque decimal `run_id`, literal `success`,
domain-separated authorization digest, byte-identical authorization
bindings, and a verified service signature in domain
`qinao-governance-validation-run-observation-v1`. Neither parser performs a
host write. `ProtectedAdmissionClient` retains exactly the four methods shown
above; governance validation is an external control-plane transaction
conformance-tested by this module, not a caller capability.

`EvidenceOutput` is the exact closed program-output receipt. Its
`producer_step_id`, `schema_digest`, `evidence_class_id`, and
`maximum_bytes` byte-match the selected program output row, and
`size_bytes <= maximum_bytes`; `blob_sha256` binds the emitted bytes. It never
represents a service-generated index or manifest. Those rows are created only
after the authenticated union of program receipts is complete and use the
fixed `bootstrap.*` assembly producers below.

`EvaluationLease.from_json_bytes` requires the exact server-signed field set,
sorted unique gate/profile/physical rows, `derived_wave` in
`preW0,W0…W6`, and a future expiry. Every `GateBinding` byte-matches one B0
catalog row and binds its closed contract, executable module bundle,
three-class corpus, and exact Cw-output contract; the runner rejects a
required/active set or phase schedule that differs from B0.
`ReleaseProfileBinding`, `ExternalPhysicalGateBinding`, and the opaque client
types are owned here; W0 and Artifact Mesh import them and must not redeclare
them. Producer and attester digests in one physical binding must differ.
preW0 has no physical binding; W0 has exactly the K4 row; W1 and later have
the B0-derived active K4/Artifact rows dictated by their current programs.
Neither caller nor candidate can add, omit, or select a row.

Each release-profile row is closed, `schema_version = 1`,
`configuration = Release`, `sdk = iphoneos`, `architectures = ("arm64",)`,
`deployment_target = 27.0`, `allowed_device_platform = iOS`, and
`allowed_device_os_major = 27`. `selected_xcode_identity` binds the canonical
Xcode application path plus the digests of `xcodebuild -version`, the SDK
path, and the SDK version. Host/helper identifiers, entitlement-template
digests, and provisioning-profile classes remain separate. preW0 has exactly
zero release rows; W0 has exactly one authority-derived row selected by the
service, not the caller. Before issuing the lease, the service reopens the
signed payload-proposal receipt and content-addressed service-owned proposal
ref, proves both equal the payload OID/tree bound by the dispatch intent, and
derives the wave from the finalized protected predecessor.
`payload_object_ref` is therefore a service output, never workflow input.
Commit identities and receipt time are stable idempotency inputs. Parsers
accept no selector-shaped aliases. Signature verification accepts only the
public-key identity digest frozen in the B0 service binding; tests use an
injected verifier function, never a production bypass flag.

`source_import_review_audit_root_digest` is service-derived and never a
caller selector. preW0 binds the verified sorted C1+C2 audit root; W0 binds
the sorted C1+C2+C3 audit root and every later wave preserves that root unless
a separately governed future batch extends it. The lease, authenticated
result bundle, canonical Sw
receipt, admission intent, and finalized attestation must all carry that same
value. A mismatch is
`BLOCKED_IMPORT_REVIEW/IMPORT_REVIEW_CONTEXT_MISMATCH`. This adds no Cw
output path and therefore changes neither the preW0 132-file nor W0 16-file
transport set.

`EvidenceAssemblyResult` is valid only after the service validates the
complete `EvidenceOutput` exact set against `cw_output_contract_digest`,
writes and closes the lease-frozen Cw/Sw object identity in non-host
quarantine, persists its advance-authorization request, authenticates and
reopens the fresh `ProtectedRefAdvanceAuthorizationV1`, imports that same
authorized object set through its Git-host integration, and reopens the
commit/tree/blob topology from the host. The external object-import receipt
binds repository, exact object OIDs, uploaded pack/object-set digest, host
transaction/audit identity, and reopen observation. It is persisted before
`AdmissionIntent`; the internal result is persisted only after both that
receipt and intent exist, and no runner-local OID or ref proves import.

The preparation-only CLI is exactly:

```text
python3 -m scripts.qinao_admission_protocol_v1 canonicalize-service-binding \
  --input '/Library/Application Support/Qinao/Bootstrap/import-review-service-binding-v1.json' \
  --output scripts/qinao_gate_modules/v0/service-binding-v1.json
```

It requires the exact `ServiceBinding` fields, HTTPS origin without user-info/query/fragment, lowercase digests, the fixed runner ref, no credential-shaped key/value, and canonical output. It never runs in the protected workflow and does not make the input authoritative; B0 minimality plus the later two-operator attestation supplies authority.
`import_review_trust_anchor_digest` is required. Task 1 performs only closed
shape/canonicalization; Task 1A independently proves the source bytes and
digest against the enterprise-managed trust anchor. A caller-provided
`authenticated-service-binding-v1.json` is never a Preparation-R trust root.

- [ ] **Step 4: Run focused and baseline tests**

Run:

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_admission_protocol_v1 \
  scripts.test_check_qinao_wave_admission
```

Expected: positive discovery and all tests pass.

- [ ] **Step 5: Commit the protocol primitive**

```bash
set -euo pipefail
git add scripts/qinao_admission_protocol_v1.py \
  scripts/test_qinao_admission_protocol_v1.py
git diff --cached --name-only
git commit -m "feat(qinao): freeze admission protocol primitives"
```

Expected staged paths: exactly the two listed files.

---

### Task 1A: Freeze Batch-Scoped Import Review Without a Self-Reference

**Files:**
- Create: `docs/superpowers/specs/qinao-import-review-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-import-review-reopen-receipt-v1.schema.json`
- Create: `scripts/qinao_import_review_v1.py`
- Create: `scripts/test_qinao_import_review_v1.py`
- Modify: `scripts/check_qinao_import_map.py`
- Modify: `scripts/test_qinao_import_map.py`

**Interfaces:**
- Consumes: the committed C0 all-hold inventory/map, Task-1 canonical JSON and
  envelope primitives, the enterprise-managed trust anchor and service
  binding, one clean review-base candidate observation, one exact
  batch-specific selected-row proposal, two distinct operator approvals, and
  one immutable service reopen/transparency receipt.
- Produces: an opaque read-only `VerifiedImportReviewV1`, an atomic
  map-postimage proof, one fixed-path crash-safe map-postimage materializer,
  and a privacy-clean review-audit-root digest. The verification APIs create
  no edit; the explicit materializer may change only the code-owned import
  map to the uniquely signed postimage. Nothing here creates product/wave
  authority, a Git object/ref, or a fifth admission-client method.
- Supports exactly C1 with ten selected rows, C2 with thirty-two selected rows,
  and C3 with twenty selected rows. C4 remains all-hold until a future
  controlled plan freezes its count and fixed path; a non-hold C4 row fails
  closed.

#### Managed trust root and fixed paths

Preparation R does not trust a caller-exported binding. An enterprise/MDM
profile owns this regular, root-owned, non-group/world-writable plist:

```text
/Library/Managed Preferences/com.qinao.bootstrap.trust.plist
```

It has exactly:

```text
SchemaVersion = 1
PolicyID = qinao-import-review-enterprise-anchor-v1
ImportReviewAnchorCertificateSHA256 = 64 lowercase hex
ImportReviewServiceBindingSHA256 = 64 lowercase hex
```

The anchor certificate is selected by that digest from
`/Library/Keychains/System.keychain` and must pass the system trust evaluation.
The fixed canonical binding is:

```text
/Library/Application Support/Qinao/Bootstrap/import-review-service-binding-v1.json
```

It is a root-owned regular file with mode `0444`, its raw SHA-256 must equal
the managed preference, and its `import_review_trust_anchor_digest` must equal
the selected certificate digest. The record service signature and both
operator signatures must chain to that anchor and cover their declared roles.
Production verification uses the fixed system-keychain adapter; signature
injection exists only in a module-private disposable-test seam. Replacing the
binding and all record/receipt bytes together still fails if the managed
preference and System-keychain anchor are unchanged.

The batch table is a code-owned constant and accepts no caller path:

```text
C1:
  rows = 10
  proposal = /private/tmp/qinao-c0-import-review-v1/proposals/c1-decision-rows-v1.json
  context = /private/tmp/qinao-c0-import-review-v1/contexts/c1-expected-context-v1.json
  record = /private/tmp/qinao-c0-import-review-v1/export/c1/import-review-v1.json
  receipt = /private/tmp/qinao-c0-import-review-v1/export/c1/import-review-reopen-receipt-v1.json
C2:
  rows = 32
  proposal = /private/tmp/qinao-c0-import-review-v1/proposals/c2-decision-rows-v1.json
  context = /private/tmp/qinao-c0-import-review-v1/contexts/c2-expected-context-v1.json
  record = /private/tmp/qinao-c0-import-review-v1/export/c2/import-review-v1.json
  receipt = /private/tmp/qinao-c0-import-review-v1/export/c2/import-review-reopen-receipt-v1.json
C3:
  rows = 20
  proposal = /private/tmp/qinao-c0-import-review-v1/proposals/c3-decision-rows-v1.json
  context = /private/tmp/qinao-c0-import-review-v1/contexts/c3-expected-context-v1.json
  record = /private/tmp/qinao-c0-import-review-v1/export/c3/import-review-v1.json
  receipt = /private/tmp/qinao-c0-import-review-v1/export/c3/import-review-reopen-receipt-v1.json
```

The three records and receipts coexist. No later-batch operation may truncate,
replace, rename, or reinterpret an earlier record.

#### Closed context, record, and receipt

`ImportReviewContextV1` is canonical JSON with exactly:

```text
schema_version
context_id
repository_identity
approved_base_oid
source_inventory_digest
prior_import_map_sha256
candidate_head_oid
candidate_tree_oid
candidate_index_digest
candidate_clean_state_digest
destination_batch
expected_selected_row_count
proposed_decision_rows
proposed_decision_rows_digest
allowed_map_path
allowed_transition
import_review_trust_anchor_digest
service_binding_digest
```

`allowed_map_path` is exactly
`docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json`;
`allowed_transition` is exactly
`one-first-parent-map-only-postimage-commit-v1`.
`candidate_index_digest` domain-separates canonical raw
`git ls-files --stage -z` rows.
`candidate_clean_state_digest` domain-separates canonical raw
porcelain-v2/untracked bytes; its bound bytes must represent a clean state,
not a caller Boolean. `proposed_decision_rows` is the exact selected subset,
sorted by raw `path_b64`, and has cardinality 10 for C1, 32 for C2, or 20 for
C3.

`ImportReviewV1` has exactly these top-level fields:

```text
schema_version
review_record_id
repository_identity
approved_base_oid
destination_batch
source_inventory_digest
expected_context_digest
expected_context
candidate_head_oid
candidate_tree_oid
candidate_index_digest
candidate_clean_state_digest
decision_rows
decision_rows_digest
reviewer_principal_digest
reviewed_at
approval_policy
operator_approvals
reopen_policy_id
import_review_trust_anchor_digest
service_binding_digest
envelope
```

`schema_version = 1`; top-level `destination_batch` is the fixed review
ceremony batch C1, C2, or C3. It is distinct from a map row's destination:
an `import` row carries that C1/C2/C3 value, while an `omit` row carries
`destination_batch = hold`. `expected_context_digest` is:

```text
sha256("qinao-import-review-context-v1\0" + canonical context bytes)
```

`expected_context` is the complete closed `ImportReviewContextV1` object,
not a path or digest-only reference. Its canonical bytes produce
`expected_context_digest`. The record's repository/base/batch/inventory,
four candidate observation fields, trust anchor, and service binding all
byte-match the corresponding embedded-context fields. `decision_rows`
byte-match its proposed rows and contain no hold row. The embedded context and
decision rows contain no review-record digest, reviewer identity, review
time, receipt identity, or envelope, so the record has no digest fixed point.
Each closed row is exactly:

```text
path_b64
display_path
decision
source_stratum
source_sha256
source_mode
destination_batch
rationale
```

`decision = import | omit`;
`source_stratum = null | base | head | index | worktree | untracked | deletion`;
`source_mode = null | 100644 | 100755 | 120000`.
For `import`, destination batch equals the record's C1/C2/C3 batch and the
stratum/hash/mode values equal the selected C0 inventory stratum; a deletion
has null hash/mode only when the selected postimage is absent. For `omit`,
destination batch is exactly `hold`, the stratum/hash/mode triple is null,
and rationale is nonempty/non-`unreviewed`; the signed record still binds the
complete source-inventory digest and path identity. These bytes deliberately
match C0's canonical omit postimage. `display_path` is non-authoritative;
`path_b64` is identity. `decision_rows_digest` domain-separates the canonical
row array.

`approval_policy` is closed:

```text
policy_id = qinao-c0-import-review-two-person-v1
minimum_distinct_operator_approvals = 2
required_roles = [import-approver, import-reviewer]
```

`operator_approvals` has exactly two rows sorted by role, each closed
`{role,principal_digest,review_payload_digest,approved_at,
signature_algorithm,certificate_chain_digest,signature}`. Principals differ.
The reviewer row equals top-level `reviewer_principal_digest`/`reviewed_at`;
both sign the same domain-separated payload covering every field through
`import_review_trust_anchor_digest` and `service_binding_digest`.
`reopen_policy_id` is
`qinao-import-review-append-only-content-addressed-reopen-v1`.
The service envelope has message type `qinao.import-review-v1`, matches the
managed binding identity, and signs every non-envelope field. The record
digest is:

```text
sha256("qinao-import-review-record-v1\0" + canonical complete record bytes)
```

`ImportReviewReopenReceiptV1` has exactly:

```text
schema_version
receipt_id
review_record_id
review_record_digest
destination_batch
content_object_id
content_object_digest
service_binding_digest
import_review_trust_anchor_digest
append_sequence
stored_at
reopened_at
transparency_entry_id
transparency_checkpoint_digest
transparency_inclusion_proof_digest
envelope
```

The service stores raw record bytes under the content address
`(review_record_id, review_record_digest)`. `content_object_digest` equals the
raw self-contained record SHA-256; the signed receipt proves immutable append,
exact reopen, and transparency inclusion. A local export is only a cache.
Missing record/receipt cache bytes block until the external service re-exports
the same content-addressed object and receipt; missing proposal/context caches
do not, because their complete authoritative bytes are embedded in that
record. The checker never silently trusts an older digest-only map row.

Both schemas use `additionalProperties: false` recursively and require
exactly their listed properties.

- [ ] **Step 1: Write typed RED seams and integration tests**

Create these final public interfaces:

```python
class VerifiedImportReviewV1:
    """Opaque, immutable; only this module's successful verifier can create it."""
    @property
    def record_digest(self) -> str: ...
    @property
    def destination_batch(self) -> Literal["C1", "C2", "C3"]: ...
    @property
    def decision_rows(self) -> tuple[Mapping[str, object], ...]: ...
    @property
    def reviewer_principal_digest(self) -> str: ...
    @property
    def reviewed_at(self) -> str: ...
    @property
    def bound_context(self) -> Mapping[str, object]: ...
    @property
    def reopen_receipt_digest(self) -> str: ...
    @property
    def import_review_trust_anchor_digest(self) -> str: ...
    @property
    def service_binding_digest(self) -> str: ...

def parse_import_review(data: bytes) -> ImportReviewV1: ...
def parse_import_review_reopen_receipt(
    data: bytes,
) -> ImportReviewReopenReceiptV1: ...
def verify_fixed_c1_import_review_export() -> VerifiedImportReviewV1: ...
def verify_fixed_c2_import_review_export() -> VerifiedImportReviewV1: ...
def verify_fixed_c3_import_review_export() -> VerifiedImportReviewV1: ...
def apply_fixed_map_postimage(
    batch: Literal["C1", "C2", "C3"],
) -> VerifiedImportReviewV1: ...
def verify_map_postimage(
    *,
    inventory: Mapping[str, object],
    mapping: Mapping[str, object],
    repository_root: Path,
) -> tuple[VerifiedImportReviewV1, ...]: ...
def compile_review_audit_root(
    verified: tuple[VerifiedImportReviewV1, ...],
) -> str: ...
```

`VerifiedImportReviewV1` uses a module-private construction token, immutable
slots, immutable nested row/context projections, no public initializer, and
no subclassing/pickle reconstruction. Callers cannot construct a “verified”
value from a digest. The fixed-export APIs have no path, public-key, binding,
context, signature-verifier, or bypass argument. RED operations raise only
`ImportReviewError("qinao.import-review.unimplemented")`.
`bound_context` is always the authenticated immutable
`ImportReviewV1.expected_context` projection; it is never loaded from a
required `/private/tmp` context file after the signed record exists.
`apply_fixed_map_postimage` accepts only the C1/C2/C3 enum and no root, map,
record, key, context, row, reviewer, timestamp, output, force, or bypass
argument. It runs the permanent execution-root/repository-identity guard,
using only the shared C0 mapping
`C1/C2 → prebootstrapPreparation; C3 → reparentedProgram`,
and takes an exclusive advisory lock on the fixed
`$GIT_DIR/qinao-import-map-postimage.lock` opened
`O_RDWR|O_CREAT|O_NOFOLLOW`, then `fchmod`ed on its open descriptor and
required effective-UID-owned, regular, exact mode `0600`, and link-count one.
The lock is held through verification, content-CAS, and post-verification; it
coordinates all code-owned writers but is never treated as sufficient against
an uncooperative writer.

Under that one lock, the materializer captures and then immediately before
the write revalidates the exact HEAD OID/tree, raw index identity and
`write-tree` OID, complete NUL-delimited worktree/status bytes, and the fixed
map's `lstat`/open-`fstat` device+inode+mode+link-count+size plus raw bytes.
Every non-map path must remain clean. The map must be the same regular inode
and byte-for-byte equal either to the signed context's exact prior bytes or to
the uniquely derived postimage. It obtains the opaque fixed verifier result
and derives every review field in memory while still holding that lock.

If the map is at the prior bytes, the implementation performs one exact
preimage content-CAS with a generated single-path patch through argv-only
`git apply --index` (or an equivalently atomic no-overwrite primitive). The
patch binds the prior and postimage blob OIDs, mode, full prior content, and
full postimage; the actual applying invocation—not a preceding
`--check`—must reject any HEAD/index/worktree/map byte or inode drift. The
implementation must not use check-then-rename, `os.replace`, plain `rename`,
truncate, or a rollback overwrite. It then reopens and verifies under the
same lock that HEAD is unchanged, the index and worktree contain exactly the
postimage for the one map path, every other path/status byte is unchanged,
and no unexpected inode/type/mode/link transition occurred. If the map
already equals that exact postimage with the matching index/status state,
this is an idempotent verify-only lost-reply success. Every other state fails
without writing or replacing any competing bytes.

The fixed-context freeze, fixed-export verification, map checker, and
`apply_fixed_map_postimage` all call the same
`candidate_lineage_for_import_batch` helper. Tests execute C1/C2 against a
reparented fixture and C3 against a prebootstrap fixture and require failure
before any cache/map write; they also prove the correct inverse cases pass.
No caller-provided lineage, branch spelling, or current-HEAD heuristic may
override the batch mapping.

Tests reject duplicate/unknown/missing fields, a publicly constructible or
mutable verified value, arbitrary reviewer/time, one operator, duplicate
principal/role, changed approval payload, service/binding/anchor substitution,
binding-plus-record simultaneous substitution, another repository/base/
inventory/context, an embedded-context/digest mismatch, top-level/context
projection mismatch, candidate HEAD/tree/index/status drift, changed row
order/count/value, wrong batch, an eleventh C1, thirty-third C2, or twenty-first C3
row, reuse of an earlier-batch path in a later batch,
missing/forged/replayed reopen receipt, receipt content mismatch,
transparency mismatch, and a map group not bijective with its signed rows.
Positive recovery tests delete both local proposal and context, simulate a
new process and a machine-local cache loss, re-export only the authenticated
self-contained record plus receipt, and still prove the same opaque
`bound_context`, postimage history, and audit root.
Materializer tests cover wrong repository/context/prior-map bytes, another
dirty/staged/untracked path, caller path/key/row attempts, wrong lock
owner/mode/type/link count, map symlink/hard-link/special-file substitution,
and second identical application. Deterministic race hooks mutate HEAD,
index, another worktree path, map path entry, map inode, and map bytes after
the first snapshot and immediately before the content-CAS. Every race must
fail, preserve the competing bytes byte-for-byte, leave no intended
postimage/staged residue, and never invoke a replace/rename fallback. Tests
also cover a crash before CAS, successful CAS with reply loss, exact
postimage verify-only recovery, and refusal to overwrite a non-prior,
non-postimage map.

- [ ] **Step 2: Run RED**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_import_review_v1 \
  scripts.test_qinao_import_map
```

Expected: named new behavioral cases fail only on
`qinao.import-review.unimplemented`; existing all-hold tests remain green.
Import failure, missing discovery, or a zero-test run is not RED.

- [ ] **Step 3: Implement the two-mode atomic checker**

`scripts/check_qinao_import_map.py` keeps a structural all-hold path that does
not import `qinao_import_review_v1`; every hold row must have all three review
fields null. If any row is non-hold, a missing verifier maps to
`BLOCKED_IMPORT_REVIEW/IMPORT_REVIEW_VERIFIER_MISSING`. The checker groups
every non-hold row by `review_record_digest` and resolves that digest against
exactly the three code-owned fixed C1/C2/C3 records; zero or multiple matches
fail, and no map `destination_batch` selects a verifier. It rejects an
imported C4 row and any group in which an import row differs from the record's
fixed batch; a signed omit row remains canonically `destination_batch = hold`.
The three entries are fixed resolver slots, not a requirement that future
records already exist: an absent slot is valid only while that batch has no
non-hold map group. Once a group claims its digest, the matching
self-contained record and reopen receipt are mandatory. Thus the C1
postimage can be verified before C2/C3 ceremonies, while no future-batch row
can exploit an absent record.
It then atomically proves:

1. each group path set is exactly the record's selected decision-row set;
2. decision/stratum/hash/mode/batch/rationale bytes equal the signed row,
   including the null/hold canonical omit form;
3. every group row carries the same verified record digest, reviewer
   principal digest, and reviewed-at value;
4. no signed row is absent, no extra map row claims the digest, and no path
   belongs to two records; and
5. C1 remains byte-identical when C2 and C3 are introduced, and C2 remains
   byte-identical when C3 is introduced.

The candidate-state proof has exactly two modes:

1. **preapply:** live HEAD/tree/index/status equal the record context; the
   only permitted index/worktree difference is the code-owned map path whose
   raw bytes equal the uniquely derived postimage produced by
   `apply_fixed_map_postimage` from the verified record and
   `prior_import_map_sha256`; or
2. **postcommit/reopen:** walk first-parent history from the context head and
   locate exactly one *earliest* commit that first introduces this
   `review_record_digest`. Its parent/tree/index baseline equals the record
   context, its diff has exactly the map path, and its map blob is the unique
   derived postimage. The current HEAD may be any descendant, but its map
   rows for that digest must remain byte-identical. It is invalid to compare
   an old context with current HEAD directly, to accept the latest matching
   commit, or to accept two introduction commits.

This admits the one reviewed map-only commit without a digest fixed point:
the signed decision row excludes `review_record_digest`,
`reviewer_identity_digest`, and `reviewed_at`; those three values are uniquely
derived from the already signed record. It admits no other postimage.
All failures serialize through the closed reason registry:

```text
missing module -> IMPORT_REVIEW_VERIFIER_MISSING
missing record -> IMPORT_REVIEW_RECORD_MISSING
missing receipt -> IMPORT_REVIEW_REOPEN_RECEIPT_MISSING
managed anchor/binding mismatch -> IMPORT_REVIEW_TRUST_ANCHOR_INVALID
record/operator/service/receipt signature failure -> IMPORT_REVIEW_SIGNATURE_INVALID
signed/map group mismatch -> IMPORT_REVIEW_ROWSET_MISMATCH
context/history/transition mismatch -> IMPORT_REVIEW_CONTEXT_MISMATCH
```

- [ ] **Step 4: Run tests, validate schemas, and commit the verifier slice**

```bash
set -euo pipefail
python3 -m json.tool \
  docs/superpowers/specs/qinao-import-review-v1.schema.json >/dev/null
python3 -m json.tool \
  docs/superpowers/specs/qinao-import-review-reopen-receipt-v1.schema.json \
  >/dev/null
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_import_review_v1 \
  scripts.test_qinao_import_map \
  scripts.test_qinao_admission_protocol_v1
git add \
  docs/superpowers/specs/qinao-import-review-v1.schema.json \
  docs/superpowers/specs/qinao-import-review-reopen-receipt-v1.schema.json \
  scripts/qinao_import_review_v1.py \
  scripts/test_qinao_import_review_v1.py \
  scripts/check_qinao_import_map.py \
  scripts/test_qinao_import_map.py
test "$(git diff --cached --name-only)" = "$(printf '%s\n' \
  docs/superpowers/specs/qinao-import-review-reopen-receipt-v1.schema.json \
  docs/superpowers/specs/qinao-import-review-v1.schema.json \
  scripts/check_qinao_import_map.py \
  scripts/qinao_import_review_v1.py \
  scripts/test_qinao_import_map.py \
  scripts/test_qinao_import_review_v1.py)"
git diff --cached --check
git commit -m "feat(qinao): authenticate batch-scoped import reviews"
```

Expected: all tests pass and exactly the six sorted paths are committed. The
managed anchor, contexts, proposals, records, and receipts remain outside
Git.

- [ ] **Step 5: Freeze the C1 pre-context after Authority Task 1**

At this point C0 Tasks 1-7, Bootstrap Tasks 1/1A implementation, and Authority
Task 1 are committed and the candidate is clean. Two operators first inspect
the ten literal C1 proposal rows owned by Authority Task 2 and place their
canonical exact subset at the code-owned proposal cache. Then run:

```bash
set -euo pipefail
set +e
STATUS_BYTES="$(git status --porcelain=v1)"
STATUS_RC="$?"
set -euo pipefail
test "$STATUS_RC" -eq 0
test -z "$STATUS_BYTES"
python3 scripts/qinao_import_review_v1.py --freeze-fixed-context C1
python3 scripts/qinao_import_review_v1.py --verify-frozen-context C1
```

The first command refuses an existing context, recomputes the live candidate
HEAD/tree/index/status and managed anchor/binding, verifies exactly ten
proposal rows against the frozen source inventory and prior all-hold map, and
writes only the fixed C1 context. The second independently reopens and
byte-compares it. Neither command edits Git.

- [ ] **Step 6: Obtain, persist, reopen, and verify C1**

After fresh external authorization, the service reads the fixed context and
proposal, obtains two distinct role approvals, signs the C1 record, stores it
append-only by record ID/digest, appends the immutable receipt to
transparency, and exports both current-cache files. Then run:

```bash
set -euo pipefail
python3 scripts/qinao_import_review_v1.py --verify-fixed-export C1
python3 scripts/check_qinao_import_map.py \
  --operation-batch C1 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
```

The first prints only
`verified qinao import review: batch=C1 record_digest=<64 lowercase hex> rows=10 reopen_receipt_digest=<64 lowercase hex>`.
The second still reports a valid all-hold map. Authority Task 2 may now
invoke only
`python3 scripts/qinao_import_review_v1.py --apply-fixed-map-postimage C1`,
commit the resulting unique C1 map-only postimage, immediately rerun the
checker in postcommit mode, and only then prepare/apply C1. No field is copied
from output and no other candidate commit may occur between the frozen context
and that map-only commit. If a session or machine interruption deletes the
proposal/context caches after the record was stored, the service re-exports
the self-contained record and receipt; verification resumes from its embedded
context without refreezing, re-signing, or selecting a newer candidate state.

- [ ] **Step 7: Freeze, externally review, reopen, and verify the exact C2 closure**

After Authority Task 2 has committed C1 and the candidate is clean, operators
must compare the source inventory with Authority Task 2A's literal 32-row
path/stratum/SHA-256/mode table and place exactly those import rows in the
fixed C2 proposal cache. No wildcard, directory expansion, transitive
discovery, or “current helper set” alias is permitted. Then run:

```bash
set -euo pipefail
set +e
STATUS_BYTES="$(git status --porcelain=v1)"
STATUS_RC="$?"
set -euo pipefail
test "$STATUS_RC" -eq 0
test -z "$STATUS_BYTES"
python3 scripts/qinao_import_review_v1.py --freeze-fixed-context C2
python3 scripts/qinao_import_review_v1.py --verify-frozen-context C2
```

Stop here. This is a mandatory external hold: after fresh authorization, the
service obtains the two distinct role approvals, signs the self-contained C2
record, stores it append-only, appends its transparency entry, reopens the
content address, and exports the immutable record/receipt pair. Only after
that external operation completes run:

```bash
set -euo pipefail
python3 scripts/qinao_import_review_v1.py --verify-fixed-export C2
python3 scripts/check_qinao_import_map.py \
  --operation-batch C2 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
```

The first command prints exactly one opaque verification line with
`batch=C2`, `rows=32`, and both record/receipt digests. The second proves the
existing C1 map rows remain byte-identical and all proposed C2 rows remain
unapplied. Authority Task 2A may then invoke only
`--apply-fixed-map-postimage C2`, commit the unique map-only postimage as the
immediate child of the frozen context HEAD, reopen its first-parent history,
and apply exactly the 32 reviewed paths. Tests cover restart/re-export,
C1+C2 coexistence, C1 overwrite attempts, wrong count/path/stratum/hash/mode,
map-only commit interruption, and replay against a later candidate. The
preW0 privacy-clean root is now and remains sorted C1+C2.

- [ ] **Step 8: Repeat for C3 only after preW0 admission**

W0 Task 1 first requires the authenticated admitted preW0 handoff. At the
resulting clean candidate tip, operators place exactly twenty C3 proposal rows
in the distinct fixed cache, then execute:

```bash
set -euo pipefail
set +e
STATUS_BYTES="$(git status --porcelain=v1)"
STATUS_RC="$?"
set -euo pipefail
test "$STATUS_RC" -eq 0
test -z "$STATUS_BYTES"
python3 scripts/qinao_import_review_v1.py --freeze-fixed-context C3
python3 scripts/qinao_import_review_v1.py --verify-frozen-context C3
```

Stop here. After fresh external authorization, the service performs the same
two-person signing, append-only storage, transparency append, immutable
reopen, and fixed-cache export as Step 6. Only after that external operation
has completed run:

```bash
set -euo pipefail
python3 scripts/qinao_import_review_v1.py --verify-fixed-export C3
python3 scripts/check_qinao_import_map.py \
  --operation-batch C3 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
```

W0 Task 1 then invokes only
`python3 scripts/qinao_import_review_v1.py --apply-fixed-map-postimage C3`.
The C3 map-only commit must be the next commit and introduces only the twenty
C3 rows. Tests cover process
and machine restart, later-HEAD C1/C2 revalidation, C1+C2+C3 coexistence,
attempted C3 overwrite of C1 or C2, deleted/tampered
proposal/context/record/receipt caches, service re-export of identical
self-contained record/receipt bytes, and unique-first-introduction history.
The privacy-clean audit root is sorted C1+C2 before C3 and sorted C1+C2+C3
afterward.

---

### Task 2: Freeze the Complete Through-W6 Gate Catalog

**Files:**
- Create: `docs/superpowers/specs/qinao-gate-program-spec-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-gate-catalog-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-gate-contract-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-gate-corpus-v1.schema.json`
- Create: `scripts/build_qinao_gate_catalog_v0.py`
- Create: `scripts/qinao_gate_modules/v0/program-spec-v1.json`
- Create: `scripts/qinao_gate_modules/v0/catalog-v1.json`
- Create: `scripts/qinao_gate_modules/v0/service-binding-v1.json`
- Create: `scripts/qinao_gate_modules/v0/runtime.py`
- Create: `scripts/qinao_gate_modules/v0/contracts/*.json` for the exact 19 stems
- Create: `scripts/qinao_gate_modules/v0/modules/*.py` for the exact 19 stems
- Create: `scripts/qinao_gate_modules/v0/corpora/*.json` for the exact 19 stems
- Create: `docs/superpowers/specs/qinao-admission-service-binding-v1.schema.json`
- Create: `scripts/test_qinao_gate_catalog_v0.py`

**Interfaces:**
- Consumes: the indexed 7+4 draft from Authority Task 2, Authority Task 2A's
  exact reviewed C2 helper/test closure, and the approved correction design.
  It does not consume Input A, because its catalog digest is an input to
  Input A.
- Produces: one exact 19-row catalog, eight literal required-gate sets, one
  closed 152-cell gate/wave matrix, exactly 42 distinct program rows, 19 module
  bundles, 19 immutable contracts, 19 non-empty three-class corpora, a literal
  helper/argv/suite/path/symbol/output/corpus inventory, the reviewed helper
  paths consumed by Task 7, and a deterministic generator whose regenerated
  bytes must equal every checked-in catalog/contract/module/corpus byte.

The catalog IDs and first-required admission are fixed. Catalog rows use the
single canonical order `(first_required_wave_rank, gate_id)`, where
`preW0 < W0 < W1`; every `required_gates_by_wave` array is separately sorted
by `gate_id`.

| Gate ID | Stem | First required |
|---|---|---|
| `qinao.architecture-closure` | `architecture_closure` | `preW0` |
| `qinao.ios27-floor` | `ios27_floor` | `preW0` |
| `qinao.owner-ledger` | `owner_ledger` | `preW0` |
| `qinao.plan-remediation` | `plan_remediation` | `preW0` |
| `qinao.production-reachability` | `production_reachability` | `preW0` |
| `qinao.review-candidate` | `review_candidate` | `preW0` |
| `qinao.review-closure` | `review_closure` | `preW0` |
| `qinao.v2-quarantine` | `v2_quarantine` | `preW0` |
| `qinao.xcode27-toolchain` | `xcode27_toolchain` | `preW0` |
| `qinao.k4-platform-proof` | `k4_platform_proof` | `W0` |
| `qinao.provider-boundary` | `provider_boundary` | `W0` |
| `qinao.samplehost-ios` | `samplehost_ios` | `W0` |
| `qinao.w0-open-set` | `w0_open_set` | `W0` |
| `qinao.artifact-mesh-device-recovery` | `artifact_mesh_device_recovery` | `W1` |
| `qinao.contracts-layercell` | `contracts_layercell` | `W1` |
| `qinao.runtime-replay-certification` | `runtime_replay_certification` | `W1` |
| `qinao.semantic-statelake-context` | `semantic_statelake_context` | `W1` |
| `qinao.silicon-execution-spine` | `silicon_execution_spine` | `W1` |
| `qinao.sovereign-release-effects` | `sovereign_release_effects` | `W1` |

Required sets and execution phases are literal, sorted arrays:

```text
preW0 = first 9 rows
W0    = first 13 rows
W1    = all 19 rows
W2    = all 19 rows
W3    = all 19 rows
W4    = all 19 rows
W5    = all 19 rows
W6    = all 19 rows
```

For each wave, `execution_phases_by_wave` partitions its required set exactly once. A phase may run independent gates concurrently, but a later phase receives one immutable canonical index of all prior-phase results. `qinao.review-closure` runs after review-candidate/remediation inputs; `qinao.v2-quarantine` runs after production reachability; `qinao.architecture-closure` is the sole final-phase gate for every wave and consumes all earlier active-gate results, never its own result or the not-yet-sealed final index. The final gate-result index is canonicalized only after ArchitectureClosure passes. Tests prove exact coverage, dependency satisfaction, no cycle, no same-phase dependency, and no candidate-selected reordering.

The literal phases are:

```text
preW0.phase0 =
  qinao.ios27-floor
  qinao.owner-ledger
  qinao.plan-remediation
  qinao.production-reachability
  qinao.review-candidate
  qinao.xcode27-toolchain
preW0.phase1 =
  qinao.review-closure
  qinao.v2-quarantine
preW0.phase2 =
  qinao.architecture-closure

W0.phase0 =
  qinao.ios27-floor
  qinao.owner-ledger
  qinao.plan-remediation
  qinao.production-reachability
  qinao.provider-boundary
  qinao.review-candidate
  qinao.samplehost-ios
  qinao.w0-open-set
  qinao.xcode27-toolchain
W0.phase1 =
  qinao.k4-platform-proof
  qinao.review-closure
  qinao.v2-quarantine
W0.phase2 =
  qinao.architecture-closure

W1...W6.phase0 =
  qinao.contracts-layercell
  qinao.ios27-floor
  qinao.owner-ledger
  qinao.plan-remediation
  qinao.production-reachability
  qinao.provider-boundary
  qinao.review-candidate
  qinao.samplehost-ios
  qinao.semantic-statelake-context
  qinao.silicon-execution-spine
  qinao.w0-open-set
  qinao.xcode27-toolchain
W1...W6.phase1 =
  qinao.artifact-mesh-device-recovery
  qinao.k4-platform-proof
  qinao.review-closure
  qinao.v2-quarantine
W1...W6.phase2 =
  qinao.sovereign-release-effects
W1...W6.phase3 =
  qinao.runtime-replay-certification
W1...W6.phase4 =
  qinao.architecture-closure
```

`W1...W6` above is plan notation only; the JSON repeats six literal keys with byte-identical phase arrays and contains no range expansion.

#### Normative program source and closed row grammar

`program-spec-v1.json` is the sole human-reviewed source for executable gate
semantics. `catalog-v1.json`, all 19 contracts, all 19 wrappers, and all 19
corpora are generated projections; nobody edits a projection by hand. The
source has exactly these top-level keys and no others:

```text
schema_version
program_spec_id
wave_order
primitive_registry
gate_rows
transport_caps_by_evidence_class
matrix_cells
programs
dependencies_by_gate
execution_phases_by_wave
cw_assembly_contracts_by_wave
```

`schema_version` is integer `1` and `program_spec_id` is exactly
`qinao-gate-program-spec-v1`.
`wave_order` is literally
`["preW0","W0","W1","W2","W3","W4","W5","W6"]`.
`gate_rows` has exactly the 19 sorted
`{gate_id,stem,first_required_wave,subject_roots}` rows from the catalog table;
`subject_roots` is a literal sorted path array, not a directory discovery
instruction.
`transport_caps_by_evidence_class` is Bootstrap admission-contract authority,
not domain path/semantic authority. It has these exact byte caps:

```text
architecture-closure-report = 2097152
cw-manifest = 4194304
external-bundle-index = 1048576
finding-aggregate = 2097152
finding-proof-leaf = 65536
finding-source-ledger = 2097152
gate-result-index = 1048576
k4-privacy-projection = 1048576
learning-reachability-report = 1048576
privacy-clean-gate-result = 1048576
production-reachability-report = 2097152
selected-release-index = 1048576
selected-release-profile = 1048576
v2-quarantine-report = 2097152
```

Every literal output row repeats the value for its class; the generator
byte-compares it with this map and the runtime requires actual
`size_bytes <= maximum_bytes`. A new output class first requires a reviewed
ProgramSpec/schema change. If an owner later states a tighter cap it must
match after controlled reconciliation. Domain plans remain authoritative for
semantic output identity, producer, and schema; Bootstrap ProgramSpec is the
sole admission-transport authority for repository path, mode, byte cap,
assembly membership, and transport digest.
`dependencies_by_gate` has all 19 literal gate keys and all eight wave keys
under each. An inactive cell is null. A phase-0 cell is `[]`; every gate in
phase N>0 lists, sorted by gate ID, the exact union of all active gates in
phases 0 through N-1. Thus review closure, quarantine, Sovereign, Runtime, and
ArchitectureClosure cannot run without the complete prior-phase result index,
and the dependency table is byte-compared with—not inferred from—the phase
table. `execution_phases_by_wave` repeats the eight literal phase arrays above; and
`cw_assembly_contracts_by_wave` has all eight literal self-excluding output
unions, service-generated index/receipt rows, byte/file caps, and privacy
exclusions. preW0/W0 adopt their owner-frozen sets. W1-W6 are generated only
by the closed normalization rule below from the literal matrix and three
frozen W6 profile identities; neither an implementer nor runtime supplies a
path, class, cap, or optional row.

Each Cw assembly row has the exact closed fields
`wave,cw_output_rows,cw_manifest_path,sw_receipt_path,
maximum_cw_file_count,maximum_cw_aggregate_bytes,
cw_output_contract_digest,privacy_exclusion_ids`.
`cw_output_rows` is the complete sorted literal union of the selected
program's concrete `output_rows_by_wave` plus the explicitly
service-generated index/manifest rows. Every semantic projection is owned by
one active program output; the assembler cannot invent it. It never adds a
second copy of a gate-result row. Every row is closed
`{path,mode,producer_id,evidence_class_id,maximum_bytes}` with
`mode = "100644"`. The manifest path itself is one Cw row but its canonical
content excludes its own row. `sw_receipt_path` is the sole Sw tree member.
The program/assembly producer projection is unique and explicit:

```text
program output path/mode/class/cap = assembly path/mode/class/cap
assembly producer_id = owning ProgramSpec program.gate_id
program output producer_step_id ∈ that program's ordered_steps.step_id
```

`producer_step_id` identifies the exact step that emitted and schema-checked
the file inside one gate; it is not copied into assembly `producer_id`.
`producer_id` identifies the sole gate-level semantic owner. The generator,
contract, runtime file receipt, `GateResult.evidence_outputs`, and tests all
enforce this projection. Service-generated rows instead carry their literal
`bootstrap.*` producer IDs. A missing step, a step owned by another program,
or copying a step ID into `producer_id` is
`BLOCKED_EXTERNAL_BOOTSTRAP/BLOCKED_NON_LITERAL_GATE_PROGRAM`.
The generator requires
`maximum_cw_file_count == len(cw_output_rows)` and
`maximum_cw_aggregate_bytes == sum(row.maximum_bytes)`; it never invents a
default cap. `cw_output_contract_digest` is the lowercase hex result of:

```text
SHA256(
  "qinao-cw-output-contract-v1\0"
  || canonical_json(assembly row with cw_output_contract_digest omitted)
)
```

The checked-in ProgramSpec and catalog store the computed hex value; the
generator and verifier independently recompute it. No `64 lowercase hex`
placeholder is legal in checked-in JSON.

The preW0 Bootstrap transport row adopts and byte-matches the incumbent
Authority plan's reviewed 132-file constraints:

```text
docs/superpowers/evidence/qinao-plan-remediation-2026-07-18.json
docs/superpowers/evidence/qinao-review-closure-2026-07-18.json
113 literal docs/superpowers/evidence/qinao-finding-closure-v2/children/<finding-id>.json rows
docs/superpowers/evidence/qinao-finding-closure-v2/aggregate.json
docs/superpowers/evidence/qinao-production-reachability-v1.json
docs/superpowers/evidence/qinao-architecture-closure-report-v1.json
docs/superpowers/evidence/qinao-v2-quarantine-v1.json
docs/superpowers/evidence/qinao-selected-release/preW0-index.json
docs/superpowers/evidence/qinao-gate-results/preW0/index.json
9 literal docs/superpowers/evidence/qinao-gate-results/preW0/<gate-id>.json rows
docs/superpowers/evidence/qinao-external-bundles/preW0/index.json
docs/superpowers/evidence/qinao-wave-admission/preW0-cw-manifest.json
```

The 113 finding IDs and nine gate IDs are expanded as literal rows in the
source; the explanatory family lines above never enter JSON. Its
`cw_manifest_path` is
`docs/superpowers/evidence/qinao-wave-admission/preW0-cw-manifest.json`, its
`sw_receipt_path` is
`docs/superpowers/evidence/qinao-wave-admission/preW0.json`, and
`maximum_cw_file_count` is exactly 132. Under the literal Bootstrap transport
cap map its `maximum_cw_aggregate_bytes` is exactly 36765696.
The nine active programs produce 128 of those rows: nine primary gate
results; `qinao.plan-remediation` produces the remediation source ledger;
`qinao.review-closure` produces the review source ledger, 113 child proofs,
and aggregate; and the production-reachability, architecture-closure, and
v2-quarantine programs produce their three named reports. Bootstrap generates
only the gate-result index, empty selected-release index, external-bundle
index, and self-excluding manifest. Contract tests require that exact
128+4 partition and reject an unowned or multiply owned leaf.

The W0 Bootstrap transport row adopts and byte-matches the incumbent W0
plan's reviewed 16-file constraints:

```text
docs/superpowers/evidence/qinao-gate-results/W0/qinao.architecture-closure.json
docs/superpowers/evidence/qinao-gate-results/W0/qinao.ios27-floor.json
docs/superpowers/evidence/qinao-gate-results/W0/qinao.k4-platform-proof.json
docs/superpowers/evidence/qinao-gate-results/W0/qinao.owner-ledger.json
docs/superpowers/evidence/qinao-gate-results/W0/qinao.plan-remediation.json
docs/superpowers/evidence/qinao-gate-results/W0/qinao.production-reachability.json
docs/superpowers/evidence/qinao-gate-results/W0/qinao.provider-boundary.json
docs/superpowers/evidence/qinao-gate-results/W0/qinao.review-candidate.json
docs/superpowers/evidence/qinao-gate-results/W0/qinao.review-closure.json
docs/superpowers/evidence/qinao-gate-results/W0/qinao.samplehost-ios.json
docs/superpowers/evidence/qinao-gate-results/W0/qinao.v2-quarantine.json
docs/superpowers/evidence/qinao-gate-results/W0/qinao.w0-open-set.json
docs/superpowers/evidence/qinao-gate-results/W0/qinao.xcode27-toolchain.json
docs/superpowers/evidence/qinao-k4-platform-proof-W0.json
docs/superpowers/evidence/qinao-learning-legacy-reachability-W0.json
docs/superpowers/evidence/qinao-wave-admission/W0-cw-manifest.json
```

Its `sw_receipt_path` is
`docs/superpowers/evidence/qinao-wave-admission/W0.json`, and
`maximum_cw_file_count` is exactly 16; its
`maximum_cw_aggregate_bytes` is exactly 19922944. W0 has no invented selected-release,
external-projection, or gate-index file beyond those 16 rows.
The 13 active programs produce 15 rows: their 13 primary gate results,
`qinao.k4-platform-proof` additionally produces the privacy-clean K4
projection, and `qinao.w0-open-set` additionally produces the learning
reachability report. Bootstrap generates only the self-excluding manifest.
Tests require the exact 15+1 producer partition.

For W1-W6, the ProgramSpec/assembly catalog is the sole admission-transport
path/mode/cap authority and uses this closed normalization—there is no
implementer choice.

For each active matrix cell, the selected program always has this primary
output:

```text
docs/superpowers/evidence/qinao-gate-results/<literal-wave>/<literal-gate-id>.json
mode = 100644
producer_id = <literal-gate-id>
evidence_class_id = privacy-clean-gate-result
maximum_bytes = 1048576
```

Each checked-in program row carries literal `output_rows_by_wave` arrays for
its active waves. The primary rule above is present once in every active
cell. Additionally, for W1-W6 the production-reachability,
architecture-closure, and v2-quarantine programs each produce their one named
semantic projection; at W6 the production-reachability program also produces
the three frozen selected-profile/target projections. During generation, the
literal 152-cell matrix expands every output to a concrete row; generated
contracts, catalog assembly rows, and runtime inputs contain no
`{derived_wave}`, `<literal-wave>`, brace token, wildcard, or path template.
Exactly one program owns every semantic row and exactly one program is active
for each gate/wave, so variants never create a duplicate Cw path.

For each of W1-W5, the exact sorted Cw union is:

```text
19 concrete docs/superpowers/evidence/qinao-gate-results/<wave>/<gate-id>.json rows
docs/superpowers/evidence/qinao-gate-results/<wave>/index.json
docs/superpowers/evidence/qinao-production-reachability-<wave>.json
docs/superpowers/evidence/qinao-architecture-closure-report-<wave>.json
docs/superpowers/evidence/qinao-v2-quarantine-<wave>.json
docs/superpowers/evidence/qinao-selected-release/<wave>-index.json
docs/superpowers/evidence/qinao-external-bundles/<wave>/index.json
docs/superpowers/evidence/qinao-wave-admission/<wave>-cw-manifest.json
```

The explanatory family line expands from the literal 19-gate catalog and the
JSON stores all 26 concrete rows for each literal wave. The three independent
projection rows use producers `qinao.production-reachability`,
`qinao.architecture-closure`, and `qinao.v2-quarantine` and evidence classes
`production-reachability-report`, `architecture-closure-report`, and
`v2-quarantine-report`. The index/manifest producers are respectively
`bootstrap.gate-result-index`, `bootstrap.selected-release-index`,
`bootstrap.external-bundle-index`, and `bootstrap.cw-manifest`. The
selected-release index is schema-valid and empty for W1-W5. Each row's class
selects its exact cap from `transport_caps_by_evidence_class`.
Thus active programs produce 22 rows and Bootstrap produces only the four
indexes/manifest rows; the authenticated `GateResult.evidence_outputs` union
must equal those 22 program-owned paths and their schema digests before
assembly begins.
Therefore:

```text
W1 maximum_cw_file_count = 26
W2 maximum_cw_file_count = 26
W3 maximum_cw_file_count = 26
W4 maximum_cw_file_count = 26
W5 maximum_cw_file_count = 26
W1...W5 maximum_cw_aggregate_bytes = 33554432
```

W6 contains the same 26 concrete W6 rows, but its selected-release index has
exactly these three sorted active rows and the Cw adds their three
privacy-clean profile/target projections:

```text
docs/superpowers/evidence/qinao-selected-release/W6/qinao.behavioral-substrate-ios-1.0.0.json
docs/superpowers/evidence/qinao-selected-release/W6/qinao.runtime-sdk-ios-1.0.0.json
docs/superpowers/evidence/qinao-selected-release/W6/qinao.samplehost-ios-1.0.0.json
```

Each projection is mode `100644`, producer
`qinao.production-reachability`, evidence class
`selected-release-profile`, cap `1048576`, and binds the exact Authority
profile/target row. W6 active programs therefore produce 25 rows and
Bootstrap produces only the same four indexes/manifest rows. Thus:

```text
W6 maximum_cw_file_count = 29
W6 maximum_cw_aggregate_bytes = 36700160
```

The generator expands all six literal waves into checked-in concrete arrays,
sorts by raw UTF-8 path, computes the digest formula above, and byte-compares
the result with ProgramSpec and catalog. Across all eight waves, the 136
active gate cells produce 136 primary results plus 142 supplemental outputs,
for exactly 278 program-owned concrete projections; the remaining Cw rows
are only the fixed service-generated indexes/manifests described above. Two
operators review the six
canonical arrays, counts, caps, and computed digests. Runtime only indexes
the externally derived wave; it cannot select, add, remove, rename, or
re-cap a row. The absence of a pre-existing domain Cw path table creates no
second semantic authority: domain plans own semantic meaning/schema while
this closed rule owns transport. Any conflict with an owner-frozen semantic
identity stops `BLOCKED_EXTERNAL_BOOTSTRAP/BLOCKED_NON_LITERAL_GATE_PROGRAM`;
it never authorizes an inferred exception.

Every complete row repeats exactly these privacy exclusion IDs, sorted:

```text
broker-capability
credential
device-identifier
key-material
oidc-token
provisioning-profile
raw-container-path
raw-custody-path
raw-device-log
raw-signing-chain
raw-user-path
```

`matrix_cells` has exactly 152 rows in `(gate_id,wave_order)` order: one for
each of the 19 gate IDs at each of the eight waves. A cell has the closed
shape:

```json
{
  "gate_id": "qinao.owner-ledger",
  "wave": "preW0",
  "required": true,
  "program_id": "owner-ledger-v2",
  "inapplicable_reason_id": null
}
```

Before a gate's first-required wave, `required` is `false`, `program_id` is
`null`, and `inapplicable_reason_id` is exactly
`gate-not-yet-introduced`; afterward, `required` is `true`, `program_id` is a
non-empty reference to exactly one row in `programs`, and
`inapplicable_reason_id` is `null`. No omitted cell, inherited/default
program, range, alias, wildcard, fallback, or “latest” resolution exists.

There are exactly 42 distinct `programs` rows, sorted by
`(gate_id,program_id)`. Every row has this closed shape:

```text
{
  "gate_id": "qinao.owner-ledger",
  "program_id": "owner-ledger-v2",
  "active_waves": ["preW0", "W0", "W1", "W2", "W3", "W4", "W5", "W6"],
  "ordered_steps": [
    {
      "step_id": "owner-ledger-v2",
      "primitive": "owner_ledger_v2_exact_set",
      "helper": null,
      "helper_closure": [],
      "argv": [],
      "required_paths": [
        {
          "path": "docs/superpowers/specs/qinao-owner-ledger-v1.json",
          "mode": "100644"
        }
      ],
      "forbidden_paths": [],
      "required_symbols": [],
      "forbidden_symbols": [],
      "suite_rows": [],
      "parameters": {
        "expected_schema_version": 2,
        "expected_ledger_id": "qinao-owner-ledger-v1",
        "expected_owner_count": 29,
        "expected_document_ids_digest": SHA256(
          canonical sorted controlled-document and addendum ID rows
        ),
        "expected_controlled_document_count": 7,
        "expected_governing_addendum_count": 4,
        "expected_semantic_layer_count": 14,
        "expected_physical_kernel_count": 4,
        "expected_control_ring_count": 4,
        "expected_orthogonal_plane_count": 7,
        "w1_owner_health_transition": {
          "owner_id": "artifact.mesh",
          "predecessor_status": "converging",
          "payload_status": "implemented",
          "mutable_owner_row_fields": ["status"],
          "transition_path":
            "docs/superpowers/specs/qinao-owner-ledger-v1.json",
          "require_exactly_one_first_parent_transition_commit": true,
          "require_transition_commit_one_path": true,
          "forbid_post_transition_owner_row_drift": true
        }
      },
      "minimum_discovered": 1,
      "minimum_executed": 1,
      "maximum_output_bytes": 1048576
    },
    {
      "step_id": "authority-anchor-bijection",
      "primitive": "authority_anchor_bijection",
      "helper": null,
      "helper_closure": [],
      "argv": [],
      "required_paths": [
        {
          "path": "docs/superpowers/specs/qinao-owner-ledger-v1.json",
          "mode": "100644"
        }
      ],
      "forbidden_paths": [],
      "required_symbols": [],
      "forbidden_symbols": [],
      "suite_rows": [],
      "parameters": {
        "expected_document_count": 11,
        "expected_controlled_document_count": 7,
        "expected_governing_addendum_count": 4
      },
      "minimum_discovered": 11,
      "minimum_executed": 11,
      "maximum_output_bytes": 1048576
    }
  ],
  "output_rows_by_wave": "closed concrete mapping described below",
  "corpus_cases": {
    "positive": [],
    "negative": [],
    "mutation": []
  }
}
```

The quoted `output_rows_by_wave` value above is schema notation, not a
checked-in value. In the checked-in source it is an exact object whose keys
equal `active_waves`; every value is a sorted, nonempty array of closed
`{path,mode,producer_step_id,schema_digest,maximum_bytes,evidence_class_id}`
rows with concrete paths. The owner-ledger row has one primary gate-result row
under every active wave. The special producers have the supplemental rows
and ownership frozen above. The generator asserts that the complete
`(gate_id,program_id)` set equals the 42 distinct pairs referenced by
`matrix_cells`, every Cw semantic row has exactly one active producer, and
the complete program-output union has exactly 278 concrete projections.
Schema digest, producer step, class, mode, and cap are non-placeholder literal
values in every checked-in row. Contracts retain the complete program-output
tuple; assembly retains path/mode/class/cap and performs only the normative
`producer_id = program.gate_id` projection defined above. No projection
re-derives a field from its digest.

The example abbreviates only the three corpus arrays; the checked-in source
does not. Each array contains exactly one complete case for this distinct
program and uses the exact IDs specified below. A case is a closed object
`{case_id,input_tree_patch,canonical_input,expected_result,
expected_diagnostic_id,minimum_discovered,minimum_executed}`. Exactly one of
`input_tree_patch` and `canonical_input` is non-null. A tree patch is a sorted
array of closed `{operation,path,mode,content_base64}` rows; `operation` is
one of `add`, `replace`, or `delete`, and `content_base64` is null only for
`delete`. Thus a corpus never names an informal fixture for an implementer to
invent later.

Every `ordered_steps` row always carries all fourteen keys shown above. A
non-process primitive has `helper = null`, `helper_closure = []`, and
`argv = []`. A process primitive has one literal entrypoint row in `helper`,
plus a sorted non-empty `helper_closure` containing the entrypoint and every
transitive imported/sourced helper byte. Each helper row is
`{"path": repository-relative regular B0 path, "mode": "100644"|"100755",
sha256 = SHA256(raw indexed helper bytes)}`. The checked-in value is the
computed lowercase hex digest, never descriptive placeholder text. The argv token array begins with the entrypoint
path. The only variable tokens are the complete tokens `{payload_root}` and
`{derived_wave}`; substring interpolation is invalid. A Swift/Xcode test is a
literal `suite_rows` entry:

For a Python process primitive, the entrypoint is the B0-pinned interpreter
wrapper and every import resolves inside its byte-verified standard-library
or helper closure. Program/argv/source validation rejects `uv`, `pip`,
`pipx`, `poetry`, `conda`, `pytest`, an installer alias, `-m pytest`, dynamic
requirements/lock resolution, and any child process that could acquire a
dependency. This is checked structurally before execution and again under the
network-denied runtime; network denial is not used as the first proof of
hermeticity.

```json
{
  "package_or_project_path": "repository-relative regular path",
  "test_source_path": "repository-relative regular path",
  "test_symbol": "fully qualified test suite or test method",
  "filter_argv": ["--filter", "exact Suite or Suite/method selector"],
  "minimum_discovered": 1,
  "minimum_executed": 1
}
```

`required_paths`, `forbidden_paths`, `required_symbols`, and
`forbidden_symbols` are sorted exact sets. A symbol row is
`{path,language,symbol,kind,minimum_occurrences,maximum_occurrences}`; a
forbidden row has both occurrence bounds equal to zero. No row may contain a
glob, directory path, regex, free-form shell, unresolved Task/Step prose, or
an identity such as “all tests”/“all findings”. Families such as the 39
review sources and 113 closure children are expanded to literal rows and bind
their sorted-list digest in `parameters`.

The four schemas use `additionalProperties: false` recursively and a
primitive-discriminated `oneOf`: each primitive has an exact parameter schema,
an exact helper policy, and exact allowed non-empty/empty inventory fields.
For example, `python_checker_argv` requires a helper, a byte-closed helper
closure, and argv but forbids suite rows; `swiftpm_filter_nonempty` requires
at least one suite row; `w0_open_set_v1_exact_set` requires the exact
13-suite/16-safety-ID parameter rows plus the exact two
`aggregate_execution_constraints` rows, rejects unknown aggregate fields,
and forbids helper/argv/receipt/log fields;
`physical_evidence_external_root` and
`physical_proof_reuse_or_refresh` forbid helper/argv and require the physical
request/projection contract digests. Unknown primitive-specific parameters
cannot hide in a generic mapping.

If a controlling domain plan does not provide a literal path, symbol, suite,
registry ID, fixture ID, or expected diagnostic needed by one of these rows,
Task 2 stops with program terminal `BLOCKED_EXTERNAL_BOOTSTRAP` and reason
code
`BLOCKED_NON_LITERAL_GATE_PROGRAM`; the signed diagnostic separately binds
`gate_id`, `program_id`, and `field`. The
implementer may not infer, glob, rename, or “reasonably choose” the value; the
owning controlled plan must first be corrected and re-approved. This is a
deliberate hard stop, not permission to leave a placeholder.

- [ ] **Step 0: Freeze the literal source before writing runtime code**

Generate `program-spec-v1.json` only through the code-owned normalization
above. The builder expands the already literal 152-cell matrix into all 42
program rows, 136 primary gate results, and 142 supplemental semantic outputs
for exactly 278 program-owned concrete projections; it then emits the
six concrete W1-W6 assembly arrays with counts 26/26/26/26/26/29 and caps
33554432/33554432/33554432/33554432/33554432/36700160. It accepts no path,
class, cap, row, profile ID, or digest override. The three W6 profile IDs and
versions are the exact Authority rows named above.

Before any runtime implementation, the read-only closure compiler must prove:

```text
program rows = 42
program output mappings = 42 non-empty closed mappings
primary gate-result projections = 136
supplemental semantic projections = 142
program-owned concrete output projections = 278
assembly rows = 8
W1-W6 assembly row counts = 26,26,26,26,26,29
W1-W6 aggregate caps = 33554432,33554432,33554432,33554432,33554432,36700160
W1-W6 digest fields = six recomputed non-placeholder lowercase SHA-256 values
matrix cells = 152
reachable programs = 42
unreachable programs = 0
generated contract/catalog/assembly paths containing "{" or "}" = 0
```

It also validates all four schemas and proves every helper, current-or-prior
required path, test source, program-owned symbol, output schema, and assembly
row exists in the indexed preparation fixture. Later-wave identities are
proved against their checked-in fixture patches, not current worktree bytes.
The resolver emits no repository file. Both operators review the canonical
ProgramSpec SHA-256, six W1-W6 row arrays/counts/caps/digests, and the empty
list of `BLOCKED_NON_LITERAL_GATE_PROGRAM` diagnostics before implementation.
An owner-semantic conflict still stops that closed diagnostic; it never
reopens transport choice.

- [ ] **Step 1: Write RED exact-set and bundle-closure tests**

The tests assert:

```python
EXPECTED_COUNTS = {
    "catalog": 19,
    "matrix_cells": 152,
    "active_matrix_cells": 136,
    "inactive_matrix_cells": 16,
    "programs": 42,
    "preW0": 9,
    "W0": 13,
    "W1": 19,
    "W2": 19,
    "W3": 19,
    "W4": 19,
    "W5": 19,
    "W6": 19,
}
EXPECTED_CW_COUNTS = {
    "preW0": 132,
    "W0": 16,
    "W1": 26,
    "W2": 26,
    "W3": 26,
    "W4": 26,
    "W5": 26,
    "W6": 29,
}
EXPECTED_W1_W5_CW_AGGREGATE_BYTES = 33554432
EXPECTED_W6_CW_AGGREGATE_BYTES = 36700160

EXPECTED_W1_W6_GATE_IDS = (
    "qinao.architecture-closure",
    "qinao.artifact-mesh-device-recovery",
    "qinao.contracts-layercell",
    "qinao.ios27-floor",
    "qinao.k4-platform-proof",
    "qinao.owner-ledger",
    "qinao.plan-remediation",
    "qinao.production-reachability",
    "qinao.provider-boundary",
    "qinao.review-candidate",
    "qinao.review-closure",
    "qinao.runtime-replay-certification",
    "qinao.samplehost-ios",
    "qinao.semantic-statelake-context",
    "qinao.silicon-execution-spine",
    "qinao.sovereign-release-effects",
    "qinao.v2-quarantine",
    "qinao.w0-open-set",
    "qinao.xcode27-toolchain",
)

GRAPH_GATE_IDS = (
    "qinao.owner-ledger",
    "qinao.production-reachability",
    "qinao.architecture-closure",
    "qinao.w0-open-set",
    "qinao.contracts-layercell",
    "qinao.semantic-statelake-context",
    "qinao.silicon-execution-spine",
    "qinao.sovereign-release-effects",
    "qinao.runtime-replay-certification",
)
GRAPH_TEST_METHODS = {
    "test_graph_amendment_keeps_nineteen_gates_and_152_cells",
    "test_nine_graph_gate_ids_are_existing_rows",
    "test_every_graph_row_has_positive_negative_and_mutation_corpus",
    "test_every_graph_program_has_nonempty_discovery",
    "test_candidate_cannot_select_graph_module_or_verifier",
    "test_production_graph_reachability_is_independent_of_candidate_helper",
    "test_w4_cells_reject_executor_shadow_and_cutover",
    "test_w6_cells_preserve_exact_dependency_order",
}

def independently_expected_w1_w6_cw_tuples(
    wave: str,
) -> tuple[tuple[str, str, str, str, int], ...]:
    # This oracle is test-owned literal policy. It must not read ProgramSpec,
    # catalog, generated contracts, transport_caps_by_evidence_class, or a
    # computed output-contract digest.
    assert wave in ("W1", "W2", "W3", "W4", "W5", "W6")
    rows = [
        (
            f"docs/superpowers/evidence/qinao-gate-results/{wave}/{gate_id}.json",
            "100644",
            gate_id,
            "privacy-clean-gate-result",
            1048576,
        )
        for gate_id in EXPECTED_W1_W6_GATE_IDS
    ]
    rows.extend(
        (
            (
                f"docs/superpowers/evidence/qinao-production-reachability-{wave}.json",
                "100644",
                "qinao.production-reachability",
                "production-reachability-report",
                2097152,
            ),
            (
                f"docs/superpowers/evidence/qinao-architecture-closure-report-{wave}.json",
                "100644",
                "qinao.architecture-closure",
                "architecture-closure-report",
                2097152,
            ),
            (
                f"docs/superpowers/evidence/qinao-v2-quarantine-{wave}.json",
                "100644",
                "qinao.v2-quarantine",
                "v2-quarantine-report",
                2097152,
            ),
        )
    )
    if wave == "W6":
        for profile_id in (
            "qinao.behavioral-substrate-ios-1.0.0",
            "qinao.runtime-sdk-ios-1.0.0",
            "qinao.samplehost-ios-1.0.0",
        ):
            rows.append(
                (
                    "docs/superpowers/evidence/qinao-selected-release/"
                    f"W6/{profile_id}.json",
                    "100644",
                    "qinao.production-reachability",
                    "selected-release-profile",
                    1048576,
                )
            )
    rows.extend(
        (
            (
                f"docs/superpowers/evidence/qinao-gate-results/{wave}/index.json",
                "100644",
                "bootstrap.gate-result-index",
                "gate-result-index",
                1048576,
            ),
            (
                f"docs/superpowers/evidence/qinao-selected-release/{wave}-index.json",
                "100644",
                "bootstrap.selected-release-index",
                "selected-release-index",
                1048576,
            ),
            (
                f"docs/superpowers/evidence/qinao-external-bundles/{wave}/index.json",
                "100644",
                "bootstrap.external-bundle-index",
                "external-bundle-index",
                1048576,
            ),
            (
                f"docs/superpowers/evidence/qinao-wave-admission/{wave}-cw-manifest.json",
                "100644",
                "bootstrap.cw-manifest",
                "cw-manifest",
                4194304,
            ),
        )
    )
    return tuple(sorted(rows, key=lambda row: row[0].encode("utf-8")))

def test_every_gate_has_one_contract_module_and_three_class_corpus(self) -> None:
    catalog = load_catalog()
    for row in catalog["gate_catalog"]:
        contract = load_json(row["contract_path"])
        corpus = load_json(row["corpus_path"])
        self.assertEqual(contract["gate_id"], row["gate_id"])
        self.assertEqual(corpus["gate_id"], row["gate_id"])
        self.assertGreater(len(corpus["positive_cases"]), 0)
        self.assertGreater(len(corpus["negative_cases"]), 0)
        self.assertGreater(len(corpus["mutation_cases"]), 0)
        self.assertEqual(sha256_file(row["contract_path"]), row["gate_contract_digest"])
        self.assertEqual(bundle_digest(row), row["bootstrap_module_bundle_digest"])
        self.assertEqual(sha256_file(row["corpus_path"]), row["bootstrap_corpus_digest"])

def test_generator_reproduces_every_semantic_byte(self) -> None:
    source = load_and_validate_program_spec(PROGRAM_SPEC)
    rendered = render_gate_artifacts(
        source=source,
        repository_root=REPOSITORY_ROOT,
    )
    self.assertEqual(sorted(rendered), checked_in_semantic_paths())
    for path, data in sorted(rendered.items()):
        self.assertEqual(data, Path(path).read_bytes(), path)

def test_all_42_programs_have_closed_concrete_output_ownership(
    self,
) -> None:
    spec = load_and_validate_program_spec(PROGRAM_SPEC)
    referenced = {
        (cell.gate_id, cell.program_id)
        for cell in spec.matrix_cells
        if cell.required
    }
    self.assertEqual(len(referenced), 42)
    self.assertEqual(
        {(row.gate_id, row.program_id) for row in spec.programs},
        referenced,
    )
    owned: list[tuple[str, str, str]] = []
    for row in spec.programs:
        self.assertEqual(
            set(row.output_rows_by_wave),
            set(row.active_waves),
        )
        for wave, outputs in row.output_rows_by_wave.items():
            self.assertGreater(len(outputs), 0)
            primary = (
                "docs/superpowers/evidence/qinao-gate-results/"
                f"{wave}/{row.gate_id}.json"
            )
            self.assertEqual(
                sum(output.path == primary for output in outputs),
                1,
            )
            owned.extend(
                (wave, output.path, row.gate_id)
                for output in outputs
            )
    self.assertEqual(len(owned), 278)
    self.assertEqual(len({(wave, path) for wave, path, _ in owned}), 278)
    self.assertEqual(
        sum(
            path.startswith(
                f"docs/superpowers/evidence/qinao-gate-results/{wave}/"
            )
            and not path.endswith("/index.json")
            for wave, path, _ in owned
        ),
        136,
    )
    self.assertEqual(len(owned) - 136, 142)
    for contract in generated_contracts():
        encoded = canonical_json_bytes(contract)
        self.assertNotIn(b"{derived_wave}", encoded)
        self.assertNotIn(b"{gate_id}", encoded)

def test_all_cw_unions_are_concrete_and_exact(self) -> None:
    spec = load_and_validate_program_spec(PROGRAM_SPEC)
    for wave, count in EXPECTED_CW_COUNTS.items():
        row = spec.cw_assembly_contracts_by_wave[wave]
        program_paths = {
            output.path
            for program in active_programs(spec, wave)
            for output in program.output_rows_by_wave[wave]
        }
        cw_paths = {output.path for output in row.cw_output_rows}
        self.assertEqual(
            cw_paths - program_paths,
            expected_service_generated_paths(wave),
        )
        self.assertEqual(
            program_paths & expected_service_generated_paths(wave),
            set(),
        )
        self.assertEqual(len(row.cw_output_rows), count)
        self.assertEqual(row.maximum_cw_file_count, count)
        self.assertEqual(
            row.maximum_cw_aggregate_bytes,
            sum(item.maximum_bytes for item in row.cw_output_rows),
        )
        self.assertNotIn("{", canonical_json_bytes(row).decode("utf-8"))
        self.assertEqual(
            recompute_cw_output_contract_digest(row),
            row.cw_output_contract_digest,
        )
    for wave in ("W1", "W2", "W3", "W4", "W5"):
        self.assertEqual(
            spec.cw_assembly_contracts_by_wave[
                wave
            ].maximum_cw_aggregate_bytes,
            EXPECTED_W1_W5_CW_AGGREGATE_BYTES,
        )
    self.assertEqual(
        spec.cw_assembly_contracts_by_wave[
            "W6"
        ].maximum_cw_aggregate_bytes,
        EXPECTED_W6_CW_AGGREGATE_BYTES,
    )
    self.assertEqual(
        spec.cw_assembly_contracts_by_wave["preW0"].sw_receipt_path,
        "docs/superpowers/evidence/qinao-wave-admission/preW0.json",
    )
    self.assertEqual(
        spec.cw_assembly_contracts_by_wave["W0"].sw_receipt_path,
        "docs/superpowers/evidence/qinao-wave-admission/W0.json",
    )

def test_w1_w6_cw_rows_equal_the_independent_full_tuple_oracle(self) -> None:
    spec = load_and_validate_program_spec(PROGRAM_SPEC)
    for wave in ("W1", "W2", "W3", "W4", "W5", "W6"):
        actual = tuple(
            (
                output.path,
                output.mode,
                output.producer_id,
                output.evidence_class_id,
                output.maximum_bytes,
            )
            for output in spec.cw_assembly_contracts_by_wave[
                wave
            ].cw_output_rows
        )
        self.assertEqual(
            actual,
            independently_expected_w1_w6_cw_tuples(wave),
            wave,
        )

def test_program_step_to_assembly_producer_projection_is_exact(self) -> None:
    spec = load_and_validate_program_spec(PROGRAM_SPEC)
    for wave in spec.wave_order:
        assembly = {
            output.path: output
            for output in spec.cw_assembly_contracts_by_wave[
                wave
            ].cw_output_rows
        }
        for program in active_programs(spec, wave):
            step_ids = {step.step_id for step in program.ordered_steps}
            for output in program.output_rows_by_wave[wave]:
                self.assertIn(output.producer_step_id, step_ids)
                projected = assembly[output.path]
                self.assertEqual(projected.mode, output.mode)
                self.assertEqual(projected.producer_id, program.gate_id)
                self.assertEqual(
                    projected.evidence_class_id,
                    output.evidence_class_id,
                )
                self.assertEqual(
                    projected.maximum_bytes,
                    output.maximum_bytes,
                )
```

Add one `QinaoGraphAmendmentCatalogTests` class whose discovered
`test_*` method-name set equals `GRAPH_TEST_METHODS` exactly. Its first two
tests independently reconstruct the full catalog/matrix and require
`set(GRAPH_GATE_IDS)` to be an existing nine-row subset while total
cardinality remains 19/152. Its corpus/discovery tests execute every active
program belonging to those nine rows against its literal valid specimen,
rejecting specimen, and mutation set and require each observation's
discovered/executed counts to meet the non-zero contract minimum. The last
four tests mutate candidate selector/helper bytes, W4 execution/cutover
wiring, and the W6 dependency order one at a time and assert the stable
diagnostic IDs frozen in Step 5.

Add a coupled-mutation table test for each W1-W6 wave. In separate subtests,
mutate exactly one row's `path`, `mode`, `producer_id`/owning
`producer_step_id`, `evidence_class_id`, or `maximum_bytes`; update the
ProgramSpec, every generated contract/catalog projection, aggregate cap, and
`cw_output_contract_digest` consistently so all self-derived checks would
otherwise pass. The independent literal oracle above must still fail with
`BLOCKED_NON_LITERAL_GATE_PROGRAM`. Include primary gate rows, each of the
three report rows, one W6 profile row, and every service-generated row class.
This oracle is intentionally not generated by
`build_qinao_gate_catalog_v0.py`; changing it requires a separately reviewed
test-policy edit.

Also reject duplicate IDs, unsorted rows, missing W2-W6 arrays, a missing or
extra literal matrix cell, an unmapped/duplicate program ID, a contract whose
literal `program_by_wave` projection differs from the 152-cell source, a
future-wave test path or symbol in an earlier-wave program, a
`build_evidence_storage_profile` or product `selected_release_profiles` value
in catalog/contract/corpus/service binding, an unlisted helper import, an
executable/data mode mismatch, a zero corpus class for any active program,
unknown check primitive, a mutable runner ref, a payload-proposal prefix other
than `refs/heads/qinao-payload-proposals/`, a non-HTTPS service origin, or
credential-shaped service-binding data. For every derived wave, expand the
active contracts' literal evidence identities and assert one exact
collision-free `100644` Cw output set, one self-excluding manifest path, one
fixed receipt path, non-zero size/file bounds, and a stable
`cw_output_contract_digest`. Reject a glob, duplicate path,
candidate-selected identity, result path in Pw, manifest self-entry,
raw-evidence class, executable mode, or a required active gate/program with
zero output rows. Tests independently reconstruct all 152 matrix cells from
the literal full map below, assert 136 active plus 16 inactive cells, assert
exactly 42 reachable distinct programs and no unreachable program, and
byte-compare the checked-in program source SHA-256 against
`catalog.program_spec_sha256`.

- [ ] **Step 2: Run the focused RED suite**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_gate_catalog_v0
```

Expected: failure because catalog/runtime files do not exist; test discovery is non-zero.

- [ ] **Step 2A: Implement the one-way deterministic projection**

`scripts/build_qinao_gate_catalog_v0.py` exposes exactly:

```text
load_and_validate_program_spec(path: Path) -> ProgramSpec
render_gate_artifacts(*, source: ProgramSpec, repository_root: Path) -> Mapping[str, bytes]
verify_checked_in_projection(*, source_path: Path, repository_root: Path) -> None
```

and a CLI with exactly one mode:

```bash
set -euo pipefail
python3 scripts/build_qinao_gate_catalog_v0.py \
  --verify-projection scripts/qinao_gate_modules/v0/program-spec-v1.json
```

It writes nothing in verification mode. Tests call `render_gate_artifacts`
into a temporary directory and compare bytes. The renderer uses canonical
UTF-8 JSON (`sort_keys=True`, separators `(",",":")`, one trailing LF), fixed
wrapper templates, and no clock, locale, filesystem enumeration, environment,
network, Git ref, or candidate command. Projection paths are computed only
from the literal 19 stems. It emits exactly the catalog, 19 contracts, 19
wrappers, and 19 corpora; a missing, extra, or pre-existing hand-edited output
fails.

The catalog is a closed object containing:

```text
schema_version = 1
catalog_id = qinao-gate-catalog-v1
program_spec_path
program_spec_sha256
program_graph_digest
gate_catalog
required_gates_by_wave
execution_phases_by_wave
cw_assembly_contracts_by_wave
bootstrap_helper_paths
gate_schema_rows
generated_artifact_rows
```

Each of its 19 `gate_catalog` rows is closed and contains exactly
`gate_id,stem,first_required_wave,contract_path,module_path,corpus_path,
gate_contract_digest,bootstrap_module_bundle_digest,
bootstrap_corpus_digest,evidence_output_contract_digest`. Each
`generated_artifact_rows` row binds literal path, mode, SHA-256, and byte
length for one of the 57 generated gate files. `bootstrap_helper_paths` is the
sorted union of every `helper_closure` and binds the same four values.
`gate_schema_rows` contains the same four-value lock row for each of the four
literal gate schemas.
`program_graph_digest` domain-separates and hashes the canonical 19 gate rows,
transport-cap map, 152 cells, 42 program rows, primitive registry, phases,
dependencies, four schema rows, and eight Cw assembly contracts. The generator rejects a helper referenced by
argv but absent from the step closure or catalog helper union, an entrypoint
not equal to argv token zero, an unresolved Python import/Bash `source` edge,
an unresolved repository-relative executable edge, an extra closure row, or
an indexed helper whose bytes/mode differ from its source row.

`qinao-gate-contract-v1.schema.json` requires every contract to contain all
eight literal `program_by_wave` keys. Inactive cells are JSON `null`; active
cells exactly reproduce their matrix program IDs. `programs` contains the
reachable rows for that gate only, with no extra or missing row. The corpus
projection contains exactly the three expanded cases for each distinct
program row of that gate; therefore the 19 files together contain exactly
126 cases (42 positive, 42 negative, 42 mutation).

The lock chain is acyclic and exact:

```text
program-spec raw SHA-256
  -> catalog.program_spec_sha256 + program_graph_digest
  -> catalog raw-byte digest in Input A.required_gate_contracts_digest
  -> signed BootstrapRootV1.gate_catalog
  -> EvaluationLease GateBinding rows
  -> every GateResult
```

No generated artifact contains the catalog's own digest. The catalog binds the
57 generated artifacts; Input A and the signed bootstrap projection bind the
catalog raw bytes.

- [ ] **Step 3: Implement the closed module ABI and primitive registry**

`runtime.py` exposes only:

```python
@dataclass(frozen=True)
class GateContext:
    payload_root: Path
    payload_commit_oid: str
    payload_tree_oid: str
    read_tree_entry: Callable[[str], bytes]
    predecessor_payload_root: Path | None
    predecessor_payload_commit_oid: str | None
    predecessor_payload_tree_oid: str | None
    derived_wave: str
    predecessor_chain_digest: str
    contract_bytes: bytes
    contract: Mapping[str, object]
    corpus_bytes: bytes
    corpus: Mapping[str, object]
    prior_gate_results: Mapping[str, object]
    bootstrap_helper_root: Path
    output_directory: Path
    external_physical_projection: Mapping[str, object] | None

    def evaluate_declared_gate(self, *, gate_id: str) -> dict[str, object]:
        return evaluate_gate(gate_id=gate_id, context=self)

def evaluate_gate(*, gate_id: str, context: GateContext) -> dict[str, object]:
    contract_gate_id = require_string(context.contract, "gate_id")
    if contract_gate_id != gate_id:
        raise GateFailure("module/contract gate_id mismatch")
    program_id = require_wave_program_id(
        context.contract,
        derived_wave=context.derived_wave,
    )
    program = require_exact_program(
        context.contract,
        program_id=program_id,
    )
    steps = require_closed_step_array(program)
    observations = tuple(run_primitive(context, step) for step in steps)
    corpus_result = execute_corpus(
        context,
        gate_id=gate_id,
        program_id=program_id,
    )
    return canonical_gate_result(context, observations, corpus_result)
```

For `preW0`, all three `predecessor_payload_*` values are exactly null. For
W0 and later, the external service derives them only from the authenticated
prior `AdmittedWaveV1`, host-reopens that admitted payload commit/tree, and
mounts its tree as a second read-only object view. The evaluator verifies the
three values against the authenticated predecessor before constructing
`GateContext`; a caller path, current-worktree path, seal-tree substitution,
or lease-supplied lookalike is impossible. No primitive receives a Git
credential or arbitrary object reader.

The only allowed primitive IDs are:

```text
regular_path_exact_set
canonical_json_exact_set
owner_ledger_v2_exact_set
review_candidate_v2_exact_set
w0_open_set_v1_exact_set
authority_anchor_bijection
wave_slice_exact_set
future_slice_absence
python_unittest_nonempty
python_checker_argv
bash_checker_argv
swiftpm_filter_nonempty
xcodebuild_ios_scheme
indexed_blob_digest
git_diff_exact_set
ast_symbol_reachability
linked_symbol_reachability
physical_evidence_external_root
physical_proof_reuse_or_refresh
xcode_toolchain_probe
deployment_floor_scan
production_graph_reachability
architecture_closure_exact_set
v2_quarantine_exact_set
source_import_boundary_scan
```

`run_primitive` dispatches `production_graph_reachability` only for the
literal primitive ID of the same spelling and passes exactly
`context.payload_tree_oid`, `context.read_tree_entry`, the contract's frozen
`authority_roots`, `context.contract_bytes`, and `context.corpus_bytes`.
Before dispatch it requires both byte arrays to parse as the already-validated
closed objects in `context.contract`/`context.corpus` and requires their raw
SHA-256 values to equal the predecessor-selected catalog binding. No other
primitive receives `read_tree_entry`.

The runtime implementation is pure and fail-closed. It:

1. requires the exact non-empty, sorted, duplicate-free authority-root array;
2. opens every declared Package.swift/Xcode/XcodeGen/workspace/product/
   entrypoint root only through `read_tree_entry`;
3. constructs source membership, import, declaration/reference, call, and
   linked-symbol edges from those bytes with token-aware Swift/manifest
   parsing, never from comments, strings, a candidate report, or directory
   enumeration;
4. follows every reachable regular source and classifies each project,
   product, entrypoint, writer, executor, call edge, linked symbol, lab root,
   and shadow root against the closed contract rows;
5. requires the one incumbent `runtime.semantic-dag` mechanism to be the sole
   writer of the G1 topology root and both named G2 stored roots, treats
   `BASAppleTaskGraphLifecycleExecutor.refresh` only as explicitly read-only
   or production-unreachable, and rejects a direct peer call, shared
   scratchpad, legacy loop authority, lab/shadow shipping edge, or unknown
   edge; and
6. evaluates every literal nested graph corpus row and returns the existing
   gate-result schema with sorted complete discovered/classified sets plus
   the exact executed case IDs and non-zero discovery/execution counts.

The graph-specific diagnostics are closed:

```text
graph-zero-authority-roots
graph-zero-production-entrypoints
graph-zero-positive-cases
graph-zero-negative-cases
graph-unclassified-project
graph-unclassified-edge
graph-second-topology-writer
graph-direct-peer-call
graph-shared-scratchpad
graph-legacy-loop-authority
graph-lab-shadow-leakage
graph-unclassified-refresh
graph-candidate-selector
graph-owner-closure-partial
graph-owner-cardinality-drift
graph-topology-cardinality-drift
graph-mutable-wire
graph-invalid-execution-shape
graph-join-boundary
graph-aggregate-bound
graph-input-bound
graph-reverse-absence-query
graph-self-adoption
graph-parent-basis
graph-current-attempt-required
graph-provider-retry
graph-envelope-mismatch
graph-silicon-authority
graph-remand-boundary
graph-direct-effect
graph-blind-retry
graph-w4-executor-or-cutover
graph-w6-order-drift
```

The returned detail object has exactly
`authority_roots,projects,products,entrypoints,sources,writers,executors,
call_edges,linked_symbols,lab_roots,shadow_roots,classified_items,
executed_case_ids,discovered_count,executed_count`. Every collection is
canonically sorted and duplicate-free. Zero roots, entrypoints, positive
cases, negative cases, discovery, or execution is an error. The function
never imports a module, invokes a helper, shells out, reads the worktree,
accepts a selector, or writes a path.

`owner_ledger_v2_exact_set`, `review_candidate_v2_exact_set`,
`w0_open_set_v1_exact_set`, and `authority_anchor_bijection` are pure,
self-contained `runtime.py` semantics frozen in B0. They parse indexed
payload data (and, only where its frozen rule requires it, the authenticated
read-only predecessor payload) but invoke no candidate checker.
This is required because the authority draft handoff precedes final Ledger-v2
and persistent finding-identity materialization: freezing either then-current
candidate checker would freeze old raw-source semantics or create an
authority/bootstrap ordering cycle. The later candidate checkers are
parity-only and must agree with these B0 semantics.

At derived W1, `owner_ledger_v2_exact_set` additionally enforces the distinct
owner-implementation-health transition; it does not reuse controlled-contract
or shipping-profile lifecycle rules. It opens the unique regular indexed
Ledger from both authenticated predecessor payload and current `Pw`, requires
exactly one `owners[]` row with `owner_id = artifact.mesh` in each, requires
predecessor `status = converging` and current `status = implemented`, and
requires their canonical rows to be identical after normalizing only that
`status` field. It walks the first-parent commit interval from the authenticated
predecessor seal to current `Pw` and requires exactly one commit at which that
canonical owner row changes. That commit has one parent, changes exactly the
Ledger path, changes no owner-row field except `status`, and is an ancestor of
every later-W1 consumer commit. The row must remain byte-identical after that
commit even when later W1 tasks lawfully change other Ledger/catalog rows.
The primitive consumes no Task-0 handoff file.

The B0 runtime/unit matrix covers: the exact passing transition; missing or
duplicate `artifact.mesh` rows; predecessor already `implemented`; zero,
duplicate, or non-first-parent transition commits; a transition commit with
another path; an extra owner-row field change; post-Task10 owner-row drift;
current status still `converging`; and a handoff-only spoof with no indexed
transition. Each mutation has a stable non-zero diagnostic.

`review_candidate_v2_exact_set` has no helper, argv, glob, or caller-selected
path. Its B0-frozen parameters are the exact identity-set path and mode,
`schema_version = 2`, identity-set ID, admitted count `113`, review source-set
ID, review count `39`, the literal sorted `(finding_id, source_item_digest)`
rows and their list digest, the literal required candidate-path/mode rows, and
the three forbidden temporary C1 paths. The required candidate-path set is
the same exact sorted 29-path set frozen by the Task-9 parity checker; B0
stores the literal rows and digest rather than trusting the candidate tuple.
Runtime reopens those indexed blobs
from exact `Pw`, requires the 74-QRM/39-review partition, and rejects a
missing/extra/reordered identity, digest substitution, result/status field,
raw-source survivor, non-stage-0 entry, symlink, or executable mode. The
candidate parity checker and its tests are required indexed subjects but are
not imported or spawned.

`w0_open_set_v1_exact_set` likewise has no helper, argv, history directory,
receipt-series selector, log path, or caller-selected path. Its B0-frozen
positive parameters are exactly these 13 suite rows; the five columns are
literal B0 data, not documentation aliases:

| Fully qualified suite | Package | Regular indexed source path | Exact filter | Minimum |
|---|---|---|---|---:|
| `BehavioralAISubstrateTests.BASProviderBoundaryTests` | `BehavioralAISubstrate` | `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASProviderBoundaryTests.swift` | `BASProviderBoundaryTests` | 2 |
| `QinaoRuntimeSDKTests.QinaoProviderBoundaryTests` | `QinaoRuntimeSDK` | `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoProviderBoundaryTests.swift` | `QinaoProviderBoundaryTests` | 3 |
| `BehavioralAISubstrateTests.BASNativeStageExecutorTests` | `BehavioralAISubstrate` | `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASNativeStageExecutorTests.swift` | `BASNativeStageExecutorTests` | 1 |
| `BehavioralAISubstrateTests.BASTurnRuntimeNativeV2DispatchTests` | `BehavioralAISubstrate` | `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeNativeV2DispatchTests.swift` | `BASTurnRuntimeNativeV2DispatchTests` | 1 |
| `BehavioralAISubstrateTests.BASSyntheticExecutionReceiptFreezeTests` | `BehavioralAISubstrate` | `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSyntheticExecutionReceiptFreezeTests.swift` | `BASSyntheticExecutionReceiptFreezeTests` | 1 |
| `BehavioralAISubstrateTests.BASSovereignReceiptHonestyTests` | `BehavioralAISubstrate` | `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSovereignReceiptHonestyTests.swift` | `BASSovereignReceiptHonestyTests` | 1 |
| `BehavioralAISubstrateTests.BASRoutedMemoryFlipTests` | `BehavioralAISubstrate` | `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASRoutedMemoryFlipTests.swift` | `BASRoutedMemoryFlipTests` | 1 |
| `QinaoRuntimeSDKTests.QinaoRuntimeGateTests` | `QinaoRuntimeSDK` | `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeGateTests.swift` | `QinaoRuntimeGateTests` | 1 |
| `QinaoRuntimeSDKTests.QinaoTokenSigningTests` | `QinaoRuntimeSDK` | `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoTokenSigningTests.swift` | `QinaoTokenSigningTests` | 1 |
| `QinaoRuntimeSDKTests.QinaoSovereignHostAssemblyTests` | `QinaoRuntimeSDK` | `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSovereignHostAssemblyTests.swift` | `QinaoSovereignHostAssemblyTests` | 1 |
| `QinaoRuntimeSDKTests.QinaoEffectFacadeFreezeTests` | `QinaoRuntimeSDK` | `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoEffectFacadeFreezeTests.swift` | `QinaoEffectFacadeFreezeTests` | 1 |
| `BehavioralAISubstrateTests.BASW0SafetyFreezeTests` | `BehavioralAISubstrate` | `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASW0SafetyFreezeTests.swift` | `BASW0SafetyFreezeTests` | 5 |
| `QinaoRuntimeSDKTests.QinaoW0SafetyFreezeTests` | `QinaoRuntimeSDK` | `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoW0SafetyFreezeTests.swift` | `QinaoW0SafetyFreezeTests` | 6 |

All 13 rows execute independently through the closed `suite_rows` schema.
`w0_open_set_v1_exact_set.parameters` additionally has the closed
`aggregate_execution_constraints` array:

```text
bas-runtime-five:
  members = BASNativeStageExecutorTests,
            BASTurnRuntimeNativeV2DispatchTests,
            BASSyntheticExecutionReceiptFreezeTests,
            BASSovereignReceiptHonestyTests,
            BASRoutedMemoryFlipTests
  minimum_executed = 18
qinao-runtime-four:
  members = QinaoRuntimeGateTests,
            QinaoTokenSigningTests,
            QinaoSovereignHostAssemblyTests,
            QinaoEffectFacadeFreezeTests
  minimum_executed = 26
```

The B0 runtime accumulates the independently authenticated suite observations
and fails the gate unless both exact sums pass; the W0 child's two grouped
reruns are parity diagnostics only. Unknown/duplicate member IDs, overlap
between the two groups, an unobserved member, or another aggregate field is
schema failure. No directory inventory or receipt may supply a suite row. The
same parameters freeze these exact 16 safety IDs in sorted byte order:

```text
app-agent.raw-app-agent-continuity
app-agent.raw-main-agent-continuity
app-agent.raw-persona-authority
app-agent.recognition-unproven
effect.direct-production-dispatch
learning.direct-adopt-distill-export-promote-write
memory.self-populating-authority
model.false-afm-certification-accounting
provider.argv-or-raw-header-secret
provider.concrete-runtime-in-qinao-sdk
provider.same-call-fallback
release.stream-then-regenerate
runtime.raw-unbounded-public-stream
runtime.synthetic-execution-success
runtime.untyped-shared-agent-state
state.split-brain-authority
```

The positive `w0_open_set` corpus object additionally freezes this exact
ordered array under `graph_freeze_cases`; every row has exactly
`case_id,fixture_id,hazard_id,mutation,expected`:

```json
[
  {
    "case_id": "test_graph_freeze_reuses_runtime_untyped_shared_agent_state_id",
    "fixture_id": "graph.incumbent-owner.v1",
    "hazard_id": "runtime.untyped-shared-agent-state",
    "mutation": "all graph tokens and reachability predicates are attached to runtime.untyped-shared-agent-state",
    "expected": "pass; graph hazard IDs equal [\"runtime.untyped-shared-agent-state\"]"
  },
  {
    "case_id": "test_graph_freeze_keeps_exact_sixteen_ids",
    "fixture_id": "graph.seventeenth-id.v1",
    "hazard_id": "runtime.untyped-shared-agent-state",
    "mutation": "append only runtime.graph-authority",
    "expected": "reject qinao.w0-safety.safety-id-set-drift"
  },
  {
    "case_id": "test_second_g1_writer_is_rejected",
    "fixture_id": "graph.second-g1-writer.v1",
    "hazard_id": "runtime.untyped-shared-agent-state",
    "mutation": "activate symbol BASW0SecondG1Writer and call qinaoW0CommitSemanticGraph in the shipping fixture",
    "expected": "reject runtime.untyped-shared-agent-state:second-g1-writer"
  },
  {
    "case_id": "test_second_g2_writer_is_rejected",
    "fixture_id": "graph.second-g2-writer.v1",
    "hazard_id": "runtime.untyped-shared-agent-state",
    "mutation": "activate symbol BASW0SecondG2Writer and call qinaoW0CommitTaskGraph in the shipping fixture",
    "expected": "reject runtime.untyped-shared-agent-state:second-g2-writer"
  },
  {
    "case_id": "test_main_sub_peer_call_is_rejected",
    "fixture_id": "graph.main-sub-direct-peer.v1",
    "hazard_id": "runtime.untyped-shared-agent-state",
    "mutation": "activate call qinaoW0MainCallsSubDirectly",
    "expected": "reject runtime.untyped-shared-agent-state:main-sub-direct-peer-call"
  },
  {
    "case_id": "test_sub_sub_peer_call_is_rejected",
    "fixture_id": "graph.sub-sub-direct-peer.v1",
    "hazard_id": "runtime.untyped-shared-agent-state",
    "mutation": "activate call qinaoW0SubCallsPeerSubDirectly",
    "expected": "reject runtime.untyped-shared-agent-state:sub-sub-direct-peer-call"
  },
  {
    "case_id": "test_shared_mutable_scratchpad_is_rejected",
    "fixture_id": "graph.shared-scratchpad.v1",
    "hazard_id": "runtime.untyped-shared-agent-state",
    "mutation": "activate mutable symbol BASW0SharedMutableAgentScratchpad",
    "expected": "reject runtime.untyped-shared-agent-state:shared-mutable-agent-scratchpad"
  },
  {
    "case_id": "test_legacy_loop_authority_is_rejected",
    "fixture_id": "graph.legacy-loop-authority.v1",
    "hazard_id": "runtime.untyped-shared-agent-state",
    "mutation": "activate BASW0LegacyLoopAuthority.qinaoW0RetryOutsideAttempt",
    "expected": "reject runtime.untyped-shared-agent-state:legacy-loop-authority"
  },
  {
    "case_id": "test_refresh_must_be_read_only_or_production_unreachable",
    "fixture_id": "graph.refresh-classification.v1",
    "hazard_id": "runtime.untyped-shared-agent-state",
    "mutation": "remove the sole classification from the incumbent BASAppleTaskGraphLifecycleExecutor.refresh edge",
    "expected": "reject runtime.untyped-shared-agent-state:unclassified-task-graph-refresh; accept exact read-only or production-unreachable classification"
  },
  {
    "case_id": "test_future_graph_contract_is_rejected_at_w0",
    "fixture_id": "graph.future-contract.v1",
    "hazard_id": "runtime.untyped-shared-agent-state",
    "mutation": "activate declaration BASSemanticTurnDAG in a shipping source root",
    "expected": "reject runtime.untyped-shared-agent-state:future-graph-contract-at-w0"
  }
]
```

The same positive object contains
`graph_freeze_cases_sha256 =
SHA256(canonical_json(graph_freeze_cases))`, where `canonical_json` is UTF-8,
sorted-key, compact JSON with the array order retained and no trailing LF.
The corpus schema requires the ten rows and digest together; changing a byte,
reordering a row, adding/removing a key, or moving the array into the outer
negative/mutation object fails. This augments only the incumbent
`runtime.untyped-shared-agent-state` safety row: the gate still has exactly
16 safety IDs and 13 suites.

The positive case requires all 13 non-empty suite rows, all 16 IDs exactly
once in the regular indexed
`docs/superpowers/specs/qinao-w0-safety-freeze-v1.json`, every row's literal
production/source roots and allowed/forbidden seam sets, and zero
shipping-reachable forbidden seam. The negative corpus deletes only
`BASRoutedMemoryFlipTests` and must return exactly `missing-freeze-suite`.
The mutation corpus retains its source path but substitutes the exact filter
`__QINAO_W0_INTENTIONAL_ZERO_MATCH__` and must return exactly
`zero-match-filter`. The primitive additionally forbids
`docs/superpowers/evidence/qinao-w0-probe-logs/`, any post-sequence-zero W0
open-set receipt, and any legacy receipt/checker-derived suite substitution.
The two sequence-zero JSON files and
`scripts/check_w0_expected_open_set.py` pair may remain indexed solely for
non-authoritative parser regression; the primitive never opens or executes
them.

`runtime.py` does not import or redeclare the controller-owned
`VerifiedPhysicalProjection` type. It receives its canonical closed JSON
mapping, validates the exact field set and request/projection digests against
the contract, and exposes no broker/custody operation.

Every process primitive receives an argv array from the contract, resolves its executable/helper only inside the byte-verified B0 helper root, uses the exact read-only payload root as data, clears `PYTHONPATH`, `PYTHONHOME`, proxy variables, dynamic-loader variables, `ACTIONS_ID_TOKEN_REQUEST_URL`, `ACTIONS_ID_TOKEN_REQUEST_TOKEN`, `GITHUB_TOKEN`, every credential-helper variable, and every host-broker variable, closes inherited nonessential descriptors, sets a bounded timeout/output limit, and never invokes `sh -c`, `bash -c`, `eval`, or a candidate executable. Environment stripping is defense in depth; the externally attested evaluator compartment supplies the actual network/socket/UID boundary.

`run_required_gates` follows only the B0-frozen `execution_phases_by_wave`. Before each phase it canonicalizes the completed-result index, checks every declared dependency, and supplies that read-only index through `prior_gate_results`. A gate cannot read same-phase or future results. ArchitectureClosure's contract requires the exact active set minus itself; its output cannot name its own result digest. Only after it passes does the runner create the complete final index.

- [ ] **Step 4: Generate and verify all 19 thin executable module wrappers**

Each module has the same complete shape with its own literal ID and no import statement. For `owner_ledger.py`:

```python
GATE_ID = "qinao.owner-ledger"

def evaluate(*, context):
    return context.evaluate_declared_gate(gate_id=GATE_ID)
```

The Step 2A renderer creates this byte template for all 19 literal
`(stem,gate_id)` rows; no one hand-edits a wrapper. The B0-pinned `runtime.py`
is executed by absolute verified path with `python3 -I -S`; it loads each
wrapper by exact blob-verified file path and supplies the closed context.
Tests call `evaluate(context=verified_context)` and reject any module-level
symbol other than `GATE_ID` and `evaluate`. Every wrapper is mode `100644`;
only reviewed standalone entrypoints are `100755`. Candidate source paths
never enter `sys.path`. The same assertion is applied explicitly to
`modules/production_reachability.py`; defining/importing
`production_graph_reachability`, a reader, parser, helper, or selector in
that wrapper is a test failure.

- [ ] **Step 5: Create the exact contract and corpus matrix**

Every generated contract is a closed canonical JSON projection with:

```text
{
  "schema_version": 1,
  "gate_id": "qinao.owner-ledger",
  "first_required_wave": "preW0",
  "required_through_wave": "W6",
  "subject_roots": ["docs/superpowers/specs", "scripts"],
  "program_by_wave": {
    "preW0": "owner-ledger-v2",
    "W0": "owner-ledger-v2",
    "W1": "owner-ledger-v2",
    "W2": "owner-ledger-v2",
    "W3": "owner-ledger-v2",
    "W4": "owner-ledger-v2",
    "W5": "owner-ledger-v2",
    "W6": "owner-ledger-v2"
  },
  "programs": [
    {
      "gate_id": "qinao.owner-ledger",
      "program_id": "owner-ledger-v2",
      "active_waves": ["preW0", "W0", "W1", "W2", "W3", "W4", "W5", "W6"],
      "ordered_steps": [
        {
          "step_id": "owner-ledger-v2",
          "primitive": "owner_ledger_v2_exact_set",
          "helper": null,
          "helper_closure": [],
          "argv": [],
          "required_paths": [
            {
              "path": "docs/superpowers/specs/qinao-owner-ledger-v1.json",
              "mode": "100644"
            }
          ],
          "forbidden_paths": [],
          "required_symbols": [],
          "forbidden_symbols": [],
          "suite_rows": [],
          "parameters": {
            "expected_schema_version": 2,
            "expected_ledger_id": "qinao-owner-ledger-v1",
            "expected_owner_count": 29,
            "expected_document_ids_digest": SHA256(
              canonical sorted controlled-document and addendum ID rows
            ),
            "expected_controlled_document_count": 7,
            "expected_governing_addendum_count": 4,
            "expected_semantic_layer_count": 14,
            "expected_physical_kernel_count": 4,
            "expected_control_ring_count": 4,
            "expected_orthogonal_plane_count": 7,
            "w1_owner_health_transition": {
              "owner_id": "artifact.mesh",
              "predecessor_status": "converging",
              "payload_status": "implemented",
              "mutable_owner_row_fields": ["status"],
              "transition_path":
                "docs/superpowers/specs/qinao-owner-ledger-v1.json",
              "require_exactly_one_first_parent_transition_commit": true,
              "require_transition_commit_one_path": true,
              "forbid_post_transition_owner_row_drift": true
            }
          },
          "minimum_discovered": 1,
          "minimum_executed": 1,
          "maximum_output_bytes": 1048576
        },
        {
          "step_id": "authority-anchor-bijection",
          "primitive": "authority_anchor_bijection",
          "helper": null,
          "helper_closure": [],
          "argv": [],
          "required_paths": [
            {
              "path": "docs/superpowers/specs/qinao-owner-ledger-v1.json",
              "mode": "100644"
            }
          ],
          "forbidden_paths": [],
          "required_symbols": [],
          "forbidden_symbols": [],
          "suite_rows": [],
          "parameters": {
            "expected_document_count": 11,
            "expected_controlled_document_count": 7,
            "expected_governing_addendum_count": 4
          },
          "minimum_discovered": 11,
          "minimum_executed": 11,
          "maximum_output_bytes": 1048576
        }
      ],
      "output_rows_by_wave": {
        "preW0": [{path:"docs/superpowers/evidence/qinao-gate-results/preW0/qinao.owner-ledger.json",mode:"100644",producer_step_id:"owner-ledger-v2",schema_digest:SHA256("qinao-gate-result-schema-v1\0" || canonical_json(GateResult.FIELD_SCHEMA)),maximum_bytes:1048576,evidence_class_id:"privacy-clean-gate-result"}],
        "W0": [{path:"docs/superpowers/evidence/qinao-gate-results/W0/qinao.owner-ledger.json",mode:"100644",producer_step_id:"owner-ledger-v2",schema_digest:SHA256("qinao-gate-result-schema-v1\0" || canonical_json(GateResult.FIELD_SCHEMA)),maximum_bytes:1048576,evidence_class_id:"privacy-clean-gate-result"}],
        "W1": [{path:"docs/superpowers/evidence/qinao-gate-results/W1/qinao.owner-ledger.json",mode:"100644",producer_step_id:"owner-ledger-v2",schema_digest:SHA256("qinao-gate-result-schema-v1\0" || canonical_json(GateResult.FIELD_SCHEMA)),maximum_bytes:1048576,evidence_class_id:"privacy-clean-gate-result"}],
        "W2": [{path:"docs/superpowers/evidence/qinao-gate-results/W2/qinao.owner-ledger.json",mode:"100644",producer_step_id:"owner-ledger-v2",schema_digest:SHA256("qinao-gate-result-schema-v1\0" || canonical_json(GateResult.FIELD_SCHEMA)),maximum_bytes:1048576,evidence_class_id:"privacy-clean-gate-result"}],
        "W3": [{path:"docs/superpowers/evidence/qinao-gate-results/W3/qinao.owner-ledger.json",mode:"100644",producer_step_id:"owner-ledger-v2",schema_digest:SHA256("qinao-gate-result-schema-v1\0" || canonical_json(GateResult.FIELD_SCHEMA)),maximum_bytes:1048576,evidence_class_id:"privacy-clean-gate-result"}],
        "W4": [{path:"docs/superpowers/evidence/qinao-gate-results/W4/qinao.owner-ledger.json",mode:"100644",producer_step_id:"owner-ledger-v2",schema_digest:SHA256("qinao-gate-result-schema-v1\0" || canonical_json(GateResult.FIELD_SCHEMA)),maximum_bytes:1048576,evidence_class_id:"privacy-clean-gate-result"}],
        "W5": [{path:"docs/superpowers/evidence/qinao-gate-results/W5/qinao.owner-ledger.json",mode:"100644",producer_step_id:"owner-ledger-v2",schema_digest:SHA256("qinao-gate-result-schema-v1\0" || canonical_json(GateResult.FIELD_SCHEMA)),maximum_bytes:1048576,evidence_class_id:"privacy-clean-gate-result"}],
        "W6": [{path:"docs/superpowers/evidence/qinao-gate-results/W6/qinao.owner-ledger.json",mode:"100644",producer_step_id:"owner-ledger-v2",schema_digest:SHA256("qinao-gate-result-schema-v1\0" || canonical_json(GateResult.FIELD_SCHEMA)),maximum_bytes:1048576,evidence_class_id:"privacy-clean-gate-result"}]
      }
    }
  ],
  "required_evidence_classes": ["privacy-clean-gate-result"],
  "cw_output_contract_id": "qinao-cw-output.owner-ledger.v1"
}
```

For every generated contract, the generator must byte-normalize the
corresponding ProgramSpec `ordered_steps` and require deep equality with the
contract's `programs[].ordered_steps`; projection is selection, never
re-authoring. For `owner-ledger-v2`, the normalized two-step array above is
therefore identical in the ProgramSpec and contract, including both
`expected_document_ids_digest` and the complete
`w1_owner_health_transition`. Generator tests delete or mutate each of those
two fields independently, delete/reorder `authority-anchor-bijection`, and
substitute `true`/`1.0` for integer schema/count fields; every mutation must
fail before any contract or corpus is written.

The generator byte-compares each concrete `output_rows_by_wave` value with
the normalized ProgramSpec rule expanded through the literal matrix; it never
unions mutually exclusive program variants. At runtime exactly one selected
program contributes the already concrete row for the externally derived
wave. No output-path substitution exists at runtime and the caller cannot
supply a path. Any identity family
such as the 113 finding leaves carries its complete literal ID list and its
list digest in B0, so path expansion is exact and non-empty rather than a
candidate-controlled glob. The catalog also freezes one cross-gate assembly
contract per wave: exact union of the active programs' output rows, service-generated
selected-release/external-bundle indexes, the self-excluding Cw manifest, the
fixed receipt path, maximum aggregate bytes/file count, and privacy
exclusions. The union digest is `cw_output_contract_digest` in the lease.

The complete 152-cell matrix is the Cartesian expansion of this literal map;
the JSON source repeats all eight values for every gate and no implementation
may collapse a repeated or staged gate to one final-state program:

```json
{
  "qinao.architecture-closure": {
    "preW0": "architecture-closure-v1",
    "W0": "architecture-closure-v1",
    "W1": "architecture-closure-v1",
    "W2": "architecture-closure-v1",
    "W3": "architecture-closure-v1",
    "W4": "architecture-closure-v1",
    "W5": "architecture-closure-v1",
    "W6": "architecture-closure-v1"
  },
  "qinao.artifact-mesh-device-recovery": {
    "preW0": null,
    "W0": null,
    "W1": "artifact.w1-task0-final-pw",
    "W2": "artifact.post-w1",
    "W3": "artifact.post-w1",
    "W4": "artifact.post-w1",
    "W5": "artifact.post-w1",
    "W6": "artifact.post-w1"
  },
  "qinao.contracts-layercell": {
    "preW0": null,
    "W0": null,
    "W1": "contracts.w1-complete",
    "W2": "contracts.post-w1",
    "W3": "contracts.post-w1",
    "W4": "contracts.post-w1",
    "W5": "contracts.post-w1",
    "W6": "contracts.post-w1"
  },
  "qinao.ios27-floor": {
    "preW0": "ios27-floor-v1",
    "W0": "ios27-floor-v1",
    "W1": "ios27-floor-v1",
    "W2": "ios27-floor-v1",
    "W3": "ios27-floor-v1",
    "W4": "ios27-floor-v1",
    "W5": "ios27-floor-v1",
    "W6": "ios27-floor-v1"
  },
  "qinao.k4-platform-proof": {
    "preW0": null,
    "W0": "k4.w0-external-root",
    "W1": "k4.post-w0",
    "W2": "k4.post-w0",
    "W3": "k4.post-w0",
    "W4": "k4.post-w0",
    "W5": "k4.post-w0",
    "W6": "k4.post-w0"
  },
  "qinao.owner-ledger": {
    "preW0": "owner-ledger-v2",
    "W0": "owner-ledger-v2",
    "W1": "owner-ledger-v2",
    "W2": "owner-ledger-v2",
    "W3": "owner-ledger-v2",
    "W4": "owner-ledger-v2",
    "W5": "owner-ledger-v2",
    "W6": "owner-ledger-v2"
  },
  "qinao.plan-remediation": {
    "preW0": "plan-remediation-v1",
    "W0": "plan-remediation-v1",
    "W1": "plan-remediation-v1",
    "W2": "plan-remediation-v1",
    "W3": "plan-remediation-v1",
    "W4": "plan-remediation-v1",
    "W5": "plan-remediation-v1",
    "W6": "plan-remediation-v1"
  },
  "qinao.production-reachability": {
    "preW0": "production-reachability-v1",
    "W0": "production-reachability-v1",
    "W1": "production-reachability-v1",
    "W2": "production-reachability-v1",
    "W3": "production-reachability-v1",
    "W4": "production-reachability-v1",
    "W5": "production-reachability-v1",
    "W6": "production-reachability-v1"
  },
  "qinao.provider-boundary": {
    "preW0": null,
    "W0": "provider-boundary-v1",
    "W1": "provider-boundary-v1",
    "W2": "provider-boundary-v1",
    "W3": "provider-boundary-v1",
    "W4": "provider-boundary-v1",
    "W5": "provider-boundary-v1",
    "W6": "provider-boundary-v1"
  },
  "qinao.review-candidate": {
    "preW0": "review-candidate-v2",
    "W0": "review-candidate-v2",
    "W1": "review-candidate-v2",
    "W2": "review-candidate-v2",
    "W3": "review-candidate-v2",
    "W4": "review-candidate-v2",
    "W5": "review-candidate-v2",
    "W6": "review-candidate-v2"
  },
  "qinao.review-closure": {
    "preW0": "review-closure-v2",
    "W0": "review-closure-v2",
    "W1": "review-closure-v2",
    "W2": "review-closure-v2",
    "W3": "review-closure-v2",
    "W4": "review-closure-v2",
    "W5": "review-closure-v2",
    "W6": "review-closure-v2"
  },
  "qinao.runtime-replay-certification": {
    "preW0": null,
    "W0": null,
    "W1": "runtime.w1-task1a",
    "W2": "runtime.w2-intake-parser",
    "W3": "runtime.w3-dark",
    "W4": "runtime.w4-dark",
    "W5": "runtime.w5-effect-retirement",
    "W6": "runtime.w6-replay-cutover"
  },
  "qinao.samplehost-ios": {
    "preW0": null,
    "W0": "samplehost-ios-v1",
    "W1": "samplehost-ios-v1",
    "W2": "samplehost-ios-v1",
    "W3": "samplehost-ios-v1",
    "W4": "samplehost-ios-v1",
    "W5": "samplehost-ios-v1",
    "W6": "samplehost-ios-v1"
  },
  "qinao.semantic-statelake-context": {
    "preW0": null,
    "W0": null,
    "W1": "semantic.w1-values",
    "W2": "semantic.w2-k3-memory",
    "W3": "semantic.w3-statelake-context",
    "W4": "semantic.w4-production-grounding",
    "W5": "semantic.w5-l14-intake",
    "W6": "semantic.w6-audit-cutover"
  },
  "qinao.silicon-execution-spine": {
    "preW0": null,
    "W0": null,
    "W1": "silicon.w1-contract",
    "W2": "silicon.w2-dark",
    "W3": "silicon.w3-prephysical-dark",
    "W4": "silicon.w4-execution",
    "W5": "silicon.w5-spool",
    "W6": "silicon.w6-retained"
  },
  "qinao.sovereign-release-effects": {
    "preW0": null,
    "W0": null,
    "W1": "sovereign.w1-dark",
    "W2": "sovereign.w2-k3",
    "W3": "sovereign.w3-dark",
    "W4": "sovereign.w4-pre-k4",
    "W5": "sovereign.w5-k4-effects",
    "W6": "sovereign.w6-retained"
  },
  "qinao.v2-quarantine": {
    "preW0": "v2-quarantine-v1",
    "W0": "v2-quarantine-v1",
    "W1": "v2-quarantine-v1",
    "W2": "v2-quarantine-v1",
    "W3": "v2-quarantine-v1",
    "W4": "v2-quarantine-v1",
    "W5": "v2-quarantine-v1",
    "W6": "v2-quarantine-v1"
  },
  "qinao.w0-open-set": {
    "preW0": null,
    "W0": "w0-open-set-v1",
    "W1": "w0-open-set-v1",
    "W2": "w0-open-set-v1",
    "W3": "w0-open-set-v1",
    "W4": "w0-open-set-v1",
    "W5": "w0-open-set-v1",
    "W6": "w0-open-set-v1"
  },
  "qinao.xcode27-toolchain": {
    "preW0": "xcode27-toolchain-v1",
    "W0": "xcode27-toolchain-v1",
    "W1": "xcode27-toolchain-v1",
    "W2": "xcode27-toolchain-v1",
    "W3": "xcode27-toolchain-v1",
    "W4": "xcode27-toolchain-v1",
    "W5": "xcode27-toolchain-v1",
    "W6": "xcode27-toolchain-v1"
  }
}
```

Every program is cumulative: it requires all earlier legally introduced slices,
the listed current-wave delta, and exact absence of every later slice. Its
`wave_slice_exact_set` step contains literal Task/Step IDs, source paths,
registry IDs, fixture IDs, and test paths. Its `future_slice_absence` step
contains the literal later-wave source/symbol/registry/test identities. A
`swiftpm_filter_nonempty` step may name only a test path introduced at or before
that program's wave, first proves every named file is a regular indexed blob,
then proves positive suite discovery. It is forbidden to compile or filter a
future suite merely to obtain an expected RED result.

The exact current-wave deltas are:

| Program | Newly required delta; all prior deltas remain required |
|---|---|
| `architecture-closure-v1` | exact non-empty owner/storage/recovery/entrypoint/test/status closure, prior-phase result set, 7+4 reciprocal document rows, repository-relative controlled-document execution surfaces with zero developer/candidate absolute roots or `file://` locators, zero dynamic Python dependency bootstrap, and Ledger-derived active release-profile rows |
| `ios27-floor-v1` | three literal Package.swift paths, every literal governed project/configuration row from the production graph, and `BehavioralAISubstrate/scripts/build-rust-xcframework.sh` at deployment floor 27 |
| `owner-ledger-v2` | schema-v2 Ledger, 29 owner rows, 7 controlled documents, 4 governing addenda, 14+4+4+7 topology, candidate creation-gate rows, reciprocal document/catalog digests, and at W1 the predecessor-derived one-commit/one-field `artifact.mesh / converging → implemented` owner-health transition with no later row drift |
| `plan-remediation-v1` | exactly 39 literal remediation source identities, non-empty test command/suite rows, and terminal negative/mutation identities |
| `production-reachability-v1` | exact package/Xcode/XcodeGen/workspace/product roots, all shipping entrypoint rows, and all classified indirect factory/callback/reflection/linked-symbol edges |
| `review-candidate-v2` | B0-self-contained exact 39-ID/source-item-digest projection from the persistent schema-v2 finding identity set, plus the literal regular indexed candidate-path closure; the three temporary C1 raw sources are forbidden and no candidate checker is executed |
| `review-closure-v2` | 74 literal `QRM-*` leaves plus the 39 source identities, exactly 113 schema-v2 children, and exact Pw binding for every child |
| `v2-quarantine-v1` | exactly seven feature IDs, 21 rule IDs, one execution receipt and mutation per predicate, explicit lab-only sets, and zero shipping reachability |
| `xcode27-toolchain-v1` | selected Xcode major 27, iOS 27 SDK/runtime inventory, signed non-shipping toolchain identity, and compatibility with every then-active release profile |
| `k4.w0-external-root` | fresh current-Pw external producer/attester/custody/device proof under the W0 K4 request/projection contracts |
| `k4.post-w0` | deterministic sensitive-path comparison followed by exact predecessor-proof reopen or mandatory fresh current-Pw proof |
| `provider-boundary-v1` | import/declaration/string-comment-safe/linked/factory/callback/reflection scan with zero runtime model implementation leakage |
| `samplehost-ios-v1` | checked-in shared SampleHost iOS project/scheme, signed destination, Release/iphoneos/arm64/iOS-27 build settings, and non-empty build result |
| `w0-open-set-v1` | B0-frozen exact 13-suite/16-safety-ID contract with regular indexed paths, positive non-empty discovery/execution, and fixed missing-suite/zero-match mutations; no receipt series or candidate checker |
| `contracts.w1-complete` | Contracts Tasks 1, 2, 2A, 3, 4, and 5 |
| `artifact.w1-task0-final-pw` | Artifact child Tasks 1–13 (Phase A Tasks 1–10; Phase B Tasks 11–13), exact four predecessor-bound E/A rows, final-W1-Pw 26+14 device matrix, lab exclusion, owner-row transition revalidation, and operator-visible `migration_disposition = anchorlessV1QuarantineRollForwardOnly`; Phase B is read-only and admission alone makes the indexed proposal authoritative |
| `semantic.w1-values` | Semantic Task 1 value-contract slice and two content-intake schema/value E slices |
| `semantic.w2-k3-memory` | Semantic Tasks 2 and 4A |
| `semantic.w3-statelake-context` | Semantic Tasks 3, 4, 4B pure slice, 5 Steps 3A/3C, 6 Step 3A, and 7 |
| `semantic.w4-production-grounding` | Semantic Task 4B production slice, Task 5 Step 3B, and Task 6 Step 3B |
| `semantic.w5-l14-intake` | one `semantics.layercell` L14/current-policy content-intake E slice |
| `semantic.w6-audit-cutover` | Semantic Task 8 schema/value prelude followed by its coordinator behavior, in the master-ordered split |
| `silicon.w1-contract` | Silicon Task 1 and Task 7 Step 0 plus W1 portions of Steps 1, 2, 4, 5, 7, and 7A |
| `silicon.w2-dark` | no new Silicon behavior; W1 contracts retained and production Provider allocation absent |
| `silicon.w3-prephysical-dark` | no new actuation; prephysical test seam only and production Provider path absent |
| `silicon.w4-execution` | Silicon Tasks 2→3→4→5→6, then Task 7 W4 Steps 4/5B/3/6/8/9 and one binding/policy install |
| `silicon.w5-spool` | Silicon Task 7 Step 5C and Step 10 |
| `silicon.w6-retained` | no new Silicon authority; exact W5 implementation retained |
| `sovereign.w1-dark` | no Sovereign runtime behavior; future K3/K4/release/effect symbols absent |
| `sovereign.w2-k3` | Sovereign Task 4 K3 control-nucleus slice |
| `sovereign.w3-dark` | no new Sovereign behavior and K4/release/effect paths absent |
| `sovereign.w4-pre-k4` | W2 K3 retained; K4/release/Zone-C behavior still absent |
| `sovereign.w5-k4-effects` | Sovereign Task 6 pre-gate, then Tasks 2→3→1→5→remaining 6 |
| `sovereign.w6-retained` | no new Sovereign authority; exact W5 implementation retained |
| `runtime.w1-task1a` | Runtime Task 1 Part A declarations only |
| `runtime.w2-intake-parser` | two `runtime.turn-operation` content-intake A slices for parser/containment and receipt production |
| `runtime.w3-dark` | no new Runtime behavior; W4-W6 executors and outcomes absent |
| `runtime.w4-dark` | no new Runtime behavior; spool/effect/cutover paths absent |
| `runtime.w5-effect-retirement` | Runtime Task 5 Steps 5A and 5B |
| `runtime.w6-replay-cutover` | Runtime Task 2 value prelude → Semantic Task 8 value-prelude dependency → Runtime Task 1B → Semantic behavior dependency → Runtime Tasks 2/3/4/5 → Task 6 → exact content-intake selected profile/all-seven reachability → Task 7 |

`contracts.post-w1` requires byte/semantic compatibility of the admitted W1
contracts and only the later lifecycle transitions authorized by the Ledger.
`artifact.post-w1` uses `physical_proof_reuse_or_refresh`: if the exact
Artifact-sensitive path set is byte-identical to the predecessor payload, it
reopens the prior admitted physical proof; any sensitive-path delta requires a
fresh current-Pw 26+14 proof. The same deterministic reuse-or-refresh rule
applies to K4-sensitive changes after W0. Candidate flags cannot choose reuse.

The exact corpus ID bases are:

| Stem | Positive | Negative | Mutation |
|---|---|---|---|
| `owner_ledger` | `ledger-v2-7-plus-4-bijection-and-artifact-transition` | `missing-artifact-owner-transition` | `artifact-owner-row-extra-field-drift` |
| `review_candidate` | `review-identity-set-39-identities` | `missing-review-identity` | `review-source-item-digest-substitution` |
| `review_closure` | `closure-113-children` | `missing-closure-child` | `closure-payload-oid-substitution` |
| `plan_remediation` | `remediation-39-nonempty` | `zero-test-filter` | `renamed-test-suite` |
| `xcode27_toolchain` | `xcode-27-selected` | `older-xcode-selected` | `toolchain-output-forgery` |
| `ios27_floor` | `all-owned-targets-ios27` | `rust-floor-18` | `missing-package-file` |
| `production_reachability` | `all-shipping-entrypoints-classified` | `unclassified-xcode-project` | `indirect-callback-edge` |
| `architecture_closure` | `owner-storage-recovery-entrypoint-closure` | `empty-entrypoint-set` | `hand-edited-expected-output` |
| `v2_quarantine` | `seven-features-21-rules` | `missing-rule-receipt` | `shipping-alias-link` |
| `provider_boundary` | `provider-import-boundary-closed` | `runtime-model-import` | `comment-safe-symbol-alias` |
| `w0_open_set` | `bas-and-qinao-open-sets-nonempty` | `missing-freeze-suite` | `zero-match-filter` |
| `k4_platform_proof` | `external-root-bound-when-required` | `marker-shaped-proof` | `caller-challenge` |
| `samplehost_ios` | `samplehost-ios-scheme-builds` | `macos-swiftpm-substitution` | `scheme-rename` |
| `contracts_layercell` | `fourteen-layercells-contract-complete` | `missing-layercell` | `cross-layer-authority-alias` |
| `artifact_mesh_device_recovery` | `forty-row-matrix-and-roll-forward-disposition` | `missing-roll-forward-migration-disposition` | `migration-disposition-substitution` |
| `semantic_statelake_context` | `r0-through-r6-one-market` | `second-context-compiler` | `lane-order-swap` |
| `silicon_execution_spine` | `one-physical-call-per-branch` | `same-call-fallback` | `predicted-descriptor-id` |
| `sovereign_release_effects` | `k3-k4-k3-publication-binding` | `direct-effect-dispatch` | `synthetic-success-alias` |
| `runtime_replay_certification` | `replay-retirement-exact-order` | `legacy-mouth-reachable` | `conditional-build-reenable` |

Each corpus JSON has one literal object per distinct `program_id`. Its three
case IDs are exactly
`<table-positive>--<program_id>`,
`<table-negative>--<program_id>`, and
`<table-mutation>--<program_id>`; the checked-in JSON expands those strings and
contains no runtime concatenation. Each entry contains one complete
wave-appropriate fixture patch or canonical input, exact expected result, exact
expected diagnostic ID, and exact minimum discovery/execution count. A W1
positive cannot contain a W6 symbol, and a later negative cannot be reused as
an earlier “missing future suite” success. A mutation cannot merely rename the
negative case; its byte patch must differ and tests assert all three class
digests are distinct.

The existing top-level 126-case count does not change. For the eight
graph-mapped gates other than `qinao.w0-open-set`, each program's existing
positive/negative/mutation canonical input gains a `graph_case_rows` array.
Every nested row has exactly
`case_id,class,first_wave,fixture_tree,expected_pass,
expected_diagnostic_id,minimum_discovered,minimum_executed`; `fixture_tree`
is a complete sorted path-to-regular-blob fixture map, not a prose selector
or candidate report. The renderer includes a row only when the program wave
is at or after `first_wave`, places it in the same named outer class, and
retains it in every later program. The exact semantic inventory is:

| Existing gate | Class / first wave | `case_id` | Exact accepted fact or single mutation | Expected diagnostic |
|---|---|---|---|---|
| `qinao.owner-ledger` | positive / preW0 | `graph.owner.closed-create.v1` | one `runtime.semantic-dag` Create with one G1 root/eight embedded, two evidence payloads, two G2 roots/twelve embedded, five governed members and byte-identical manifest/Ledger/receipt closure | pass |
| `qinao.owner-ledger` | negative / preW0 | `graph.owner.partial-closure.v1` | delete only `BASTaskGraphPatchPayload` from the planned-member closure | `graph-owner-closure-partial` |
| `qinao.owner-ledger` | mutation / preW0 | `graph.owner.second-task-owner.v1` | add only owner `runtime.task-graph` for the G2 values | `graph-owner-cardinality-drift` |
| `qinao.production-reachability` | positive / preW0 | `graph.reachability.sole-writer-classified-refresh.v1` | every present/future G1/G2 writer maps only to the incumbent mechanism and `BASAppleTaskGraphLifecycleExecutor.refresh` is read-only or production-unreachable | pass |
| `qinao.production-reachability` | negative / preW0 | `graph.reachability.second-writer.v1` | add one shipping-reachable second G1/G2 writer | `graph-second-topology-writer` |
| `qinao.production-reachability` | negative / preW0 | `graph.reachability.direct-peer-call.v1` | add one Main→Sub direct peer call | `graph-direct-peer-call` |
| `qinao.production-reachability` | negative / preW0 | `graph.reachability.shared-scratchpad.v1` | add one shipping-reachable shared mutable Agent scratchpad | `graph-shared-scratchpad` |
| `qinao.production-reachability` | negative / preW0 | `graph.reachability.legacy-loop.v1` | add one retry/loop authority outside Attempt/RSI | `graph-legacy-loop-authority` |
| `qinao.production-reachability` | negative / preW0 | `graph.reachability.refresh-unclassified.v1` | remove both legal classifications from `BASAppleTaskGraphLifecycleExecutor.refresh` | `graph-unclassified-refresh` |
| `qinao.production-reachability` | mutation / preW0 | `graph.reachability.lab-shadow-leak.v1` | link one lab/shadow target into a shipping product | `graph-lab-shadow-leakage` |
| `qinao.production-reachability` | mutation / preW0 | `graph.reachability.candidate-selector.v1` | add a candidate-selected project/root/module field | `graph-candidate-selector` |
| `qinao.architecture-closure` | positive / preW0 | `graph.architecture.g0-g4-14-4-4-7.v1` | exact G0-G4 ownership and 14 semantic layers/four ControlRings/four kernels/seven planes | pass |
| `qinao.architecture-closure` | negative / preW0 | `graph.architecture.fifth-ring.v1` | add one fifth ControlRing | `graph-topology-cardinality-drift` |
| `qinao.architecture-closure` | negative / preW0 | `graph.architecture.fifth-kernel.v1` | add one fifth kernel | `graph-topology-cardinality-drift` |
| `qinao.architecture-closure` | mutation / preW0 | `graph.architecture.eighth-plane.v1` | add one eighth plane | `graph-topology-cardinality-drift` |
| `qinao.contracts-layercell` | positive / W1 | `graph.contracts.immutable-shape-join-bounds.v1` | immutable G1/G2, valid pure-DAG shape/join, 1,018 dispositions and 1,024 refs | pass |
| `qinao.contracts-layercell` | negative / W1 | `graph.contracts.mutable-g1.v1` | make one G1 topology field mutable inside an Attempt | `graph-mutable-wire` |
| `qinao.contracts-layercell` | negative / W1 | `graph.contracts.mutable-g2.v1` | mutate one admitted G2 root in place | `graph-mutable-wire` |
| `qinao.contracts-layercell` | negative / W1 | `graph.contracts.invalid-execution-shape.v1` | substitute a ControlRing envelope for pure DAG | `graph-invalid-execution-shape` |
| `qinao.contracts-layercell` | negative / W1 | `graph.contracts.zero-join-control-ring.v1` | admit a ControlRing source with zero joins | `graph-join-boundary` |
| `qinao.contracts-layercell` | mutation / W1 | `graph.contracts.nonzero-source-join-pure-dag.v1` | give a pure-DAG source a nonzero input join | `graph-join-boundary` |
| `qinao.contracts-layercell` | mutation / W1 | `graph.contracts.dispositions-1019.v1` | encode 1,019 terminal dispositions | `graph-aggregate-bound` |
| `qinao.contracts-layercell` | mutation / W1 | `graph.contracts.refs-1025.v1` | encode 1,025 parent/input refs | `graph-input-bound` |
| `qinao.semantic-statelake-context` | positive / W1 | `graph.semantic.one-compiler-wave-slice.v1` | one incumbent compiler owner with exact wave-appropriate absence/presence of retrieval, grounding, context, and graph slices | pass |
| `qinao.semantic-statelake-context` | negative / W3 | `graph.semantic.reverse-absence-query.v1` | infer truth from absence by reverse query | `graph-reverse-absence-query` |
| `qinao.semantic-statelake-context` | negative / W3 | `graph.semantic.self-adoption.v1` | let candidate output adopt itself | `graph-self-adoption` |
| `qinao.semantic-statelake-context` | mutation / W3 | `graph.semantic.completed-parent-cancellation.v1` | use completed parent as cancellation basis | `graph-parent-basis` |
| `qinao.semantic-statelake-context` | mutation / W3 | `graph.semantic.completion-without-current-attempt.v1` | complete a WorkUnit without the current semantic-Attempt completed receipt | `graph-current-attempt-required` |
| `qinao.silicon-execution-spine` | positive / W1 | `graph.silicon.no-graph-authority.v1` | Silicon owns physical Provider rows/envelopes only and never owns or writes G1/G2 | pass |
| `qinao.silicon-execution-spine` | positive / W4 | `graph.silicon.one-call-bound-envelope.v1` | one physical Provider call with row/CAS/envelope binding and no graph authority | pass |
| `qinao.silicon-execution-spine` | negative / W4 | `graph.silicon.blind-retry.v1` | retry Provider without a successor Attempt | `graph-provider-retry` |
| `qinao.silicon-execution-spine` | negative / W4 | `graph.silicon.envelope-shape-mismatch.v1` | mismatch execution shape and invocation envelope | `graph-envelope-mismatch` |
| `qinao.silicon-execution-spine` | mutation / W4 | `graph.silicon.claims-graph-authority.v1` | make Silicon a G1/G2 owner or writer | `graph-silicon-authority` |
| `qinao.sovereign-release-effects` | positive / W1 | `graph.sovereign.no-direct-boundary.v1` | future effect/remand mouths are absent until their owning slice and no direct boundary exists | pass |
| `qinao.sovereign-release-effects` | positive / W5 | `graph.sovereign.authorized-effect-remand.v1` | effect and remand cross only their authorized K4/K3/Attempt boundaries | pass |
| `qinao.sovereign-release-effects` | negative / W5 | `graph.sovereign.control-ring-remand-without-ring.v1` | emit ControlRing remand before a real ring invocation | `graph-remand-boundary` |
| `qinao.sovereign-release-effects` | negative / W5 | `graph.sovereign.direct-effect.v1` | dispatch effect outside prepared outbox/authorization | `graph-direct-effect` |
| `qinao.sovereign-release-effects` | mutation / W5 | `graph.sovereign.blind-retry.v1` | resend an unknown effect instead of query/reconcile | `graph-blind-retry` |
| `qinao.runtime-replay-certification` | positive / W1 | `graph.runtime.mechanical-owner-only.v1` | Runtime retains mechanical readiness/replay ownership with no duplicate graph authority and exact wave-slice absence/presence | pass |
| `qinao.runtime-replay-certification` | positive / W6 | `graph.runtime.replay-recovery-w6-order.v1` | replay/recovery and cutover follow the exact master W6 dependency order | pass |
| `qinao.runtime-replay-certification` | negative / W4 | `graph.runtime.w4-executor-wiring.v1` | wire the semantic DAG executor during W4 | `graph-w4-executor-or-cutover` |
| `qinao.runtime-replay-certification` | negative / W4 | `graph.runtime.w4-shadow-cutover.v1` | add graph shadow parity or production cutover during W4 | `graph-w4-executor-or-cutover` |
| `qinao.runtime-replay-certification` | mutation / W6 | `graph.runtime.reordered-w6.v1` | move any Runtime Task 1B/Task 2/semantic-prelude/cutover dependency out of the frozen sequence | `graph-w6-order-drift` |
| `qinao.runtime-replay-certification` | mutation / W6 | `graph.runtime.legacy-mouth-retained.v1` | retain one legacy execution/loop mouth at sealed cutover | `graph-legacy-loop-authority` |

All rows use `minimum_discovered = 1` and `minimum_executed = 1`; positive
rows use `expected_pass = true` and
`expected_diagnostic_id = null`, while all other rows use
`expected_pass = false` and the literal diagnostic above. For
`qinao.w0-open-set`, the ten-row `graph_freeze_cases` plus its canonical
digest frozen in Step 3 is the graph inventory; its existing missing-suite
and zero-match objects remain the sole outer negative/mutation objects.
Tests require one accepted graph-freeze row and all nine rejecting rows to
execute, while preserving exactly 16 safety IDs, 13 suites, 19 gates, 42
programs, 126 outer corpus cases, and 152 matrix cells.

The Artifact W1 runtime/unit matrix additionally retains independent
`missing-fault-row` and `fixture-mode-as-device-proof` failures while its
single executable negative/mutation corpus pair is reserved for omission and
substitution of the required migration disposition. The Owner-Ledger
runtime/unit matrix likewise covers every transition mutation enumerated
above in addition to its one executable negative and one mutation corpus
case.

The 19 contracts freeze these exact evaluation programs; no implementer chooses a command later:

| Gate ID | Ordered primitives and frozen subject |
|---|---|
| `qinao.owner-ledger` | B0-self-contained `owner_ledger_v2_exact_set` parses the indexed current Ledger and enforces its closed schema/cardinalities/lifecycle rules; at W1 it also reopens the authenticated predecessor Ledger and enforces the exact one-commit/one-field `artifact.mesh` owner-health transition plus no post-transition row drift. `authority_anchor_bijection` proves 7 controlled + 4 addenda, indexed document digests, and exact reciprocal catalog refs. Candidate `check_qinao_owner_ledger.py` and Task-0 handoff bytes are never executed or trusted by this gate. |
| `qinao.review-candidate` | B0-self-contained `review_candidate_v2_exact_set` requires the persistent schema-v2 identity set, selects exactly the literal 39 review IDs/source-item digests frozen from C1, verifies the literal regular indexed checker/test/schema/compiler path closure, and forbids all three temporary C1 raw paths. Candidate `check_qinao_review_candidate.py` is never executed by this gate. |
| `qinao.review-closure` | `canonical_json_exact_set` requires 74 `QRM-*` plus 39 source IDs and exactly 113 schema-v2 children; `indexed_blob_digest` proves each child binds `Pw` |
| `qinao.plan-remediation` | `canonical_json_exact_set` requires exactly 39 non-empty remediation rows and terminal negative-mutation IDs; `git_diff_exact_set` rejects renamed/missing suites |
| `qinao.xcode27-toolchain` | `xcode_toolchain_probe` requires selected Xcode major 27, iOS 27 SDK/runtime inventory, and the lease's signed non-shipping verification-toolchain identity; when active release profiles exist it additionally proves their declared build toolchains are compatible |
| `qinao.ios27-floor` | `deployment_floor_scan` reads all three `Package.swift`, every governed Xcode project/configuration, and `BehavioralAISubstrate/scripts/build-rust-xcframework.sh`; every owned deployment floor is 27 |
| `qinao.production-reachability` | `production_graph_reachability` traverses the authority-selected package/Xcode/XcodeGen/workspace/product graph, AST/SIL/index and linked-symbol closure; every discovered project and indirect edge is classified |
| `qinao.architecture-closure` | `architecture_closure_exact_set` requires non-empty owner/storage/recovery/entrypoint/test/status fields, reciprocal 7+4 refs, repository-relative Files/link/command surfaces in all seven controlled documents, zero developer/candidate absolute repository locators, zero dynamic Python dependency bootstrap, the exact Ledger-derived active shipping-profile set (empty at preW0), and byte-compared generated output |
| `qinao.v2-quarantine` | `v2_quarantine_exact_set` requires exactly seven feature IDs, 21 rule IDs, one execution receipt/mutation per predicate, explicit lab sets, and zero shipping reachability |
| `qinao.provider-boundary` | `source_import_boundary_scan` covers imports, declarations, strings/comments-safe symbol positions, linked symbols, factories/callbacks/reflection; no CoreAI/FoundationModels/MLX/Qwen/MiniCPM/Granite implementation leaks into QinaoRuntimeSDK |
| `qinao.w0-open-set` | B0-self-contained `w0_open_set_v1_exact_set` enforces the literal 13-suite/16-safety-ID contract and its fixed negative/mutation cases; `swiftpm_filter_nonempty` discovers and executes every exact suite. Candidate `check_w0_expected_open_set.py`, sequence receipts, and probe logs are never gate inputs. |
| `qinao.k4-platform-proof` | W0 uses B0-runtime-built-in `physical_evidence_external_root` with the signed request/projection contracts and empty helper/argv; W1-W6 use the frozen `physical_proof_reuse_or_refresh` rule. Candidate `check_k4_platform_proof.py` is parity-only and never loaded. Marker/fixture/caller challenge and candidate-selected reuse fail. |
| `qinao.samplehost-ios` | `xcodebuild_ios_scheme` runs the checked-in shared SampleHost iOS scheme from `SampleHost/` against the signed release destination; macOS SwiftPM substitution is failure |
| `qinao.contracts-layercell` | Resolves `contracts.w1-complete` or `contracts.post-w1`; only W1-introduced suites are eligible, and later programs prove compatibility/lifecycle rather than inventing future tests. |
| `qinao.artifact-mesh-device-recovery` | Resolves `artifact.w1-task0-final-pw` or `artifact.post-w1`; W1 runs its exact unit/26+14 physical program, independently proves lab exclusion and the anchorless-v1 quarantine behavior, and emits the privacy-clean operator projection `migration_disposition = anchorlessV1QuarantineRollForwardOnly`; omission/substitution is a corpus failure. Later waves deterministically reuse or refresh from sensitive-path diff and retain that roll-forward-only disposition until a separately admitted bridge changes it. |
| `qinao.semantic-statelake-context` | Resolves the literal W1-W6 semantic program above; `R0→R1-R4→R5→R6`, one compiler, and one final market are required only when their owning W3 slice exists, then retained through later programs. |
| `qinao.silicon-execution-spine` | Resolves the literal W1-W6 Silicon program; one physical call/no same-call fallback is required at W4 and later, while W1-W3 require the exact contract/dark/prephysical state instead of a future execution suite. |
| `qinao.sovereign-release-effects` | Resolves the literal W1-W6 Sovereign program; K3 is required at W2, K4→K3/publication/effect behavior at W5, and earlier programs positively prove those future mouths absent. |
| `qinao.runtime-replay-certification` | Resolves the literal W1-W6 Runtime program; W1 requires only Task 1A, W5 requires effect retirement, and the final replay/cutover suites and zero legacy mouths become required only at W6. |

`{payload_root}` and `{derived_wave}` are the only schema-defined runtime
substitution tokens. Both are filled only from the signed lease; contracts
contain no other variable expansion. Every suite name is paired with a regular
indexed-path assertion and non-empty discovery assertion in
`swiftpm_filter_nonempty`. A suite missing in its owning/current-or-prior wave
fails. A suite assigned to a later wave is absent from the current program and
is tested through source/registry absence, never invoked.

- [ ] **Step 6: Build catalog digests and freeze the public service binding**

Use the deterministic projection builder from Step 2A to canonicalize every
JSON file, hash regular indexed bytes, and compute each module bundle over:

```text
qinao-module-bundle-v1\0
runtime.py blob digest
module wrapper blob digest
contract blob digest
corpus blob digest
sorted helper path + blob digest pairs
```

Before finalizing `bootstrap-paths-v1.json`, reopen the enterprise-managed
Preparation-R binding. Run:

```bash
set -euo pipefail
python3 -m scripts.qinao_admission_protocol_v1 canonicalize-service-binding \
  --input '/Library/Application Support/Qinao/Bootstrap/import-review-service-binding-v1.json' \
  --output scripts/qinao_gate_modules/v0/service-binding-v1.json
python3 -m json.tool \
  scripts/qinao_gate_modules/v0/service-binding-v1.json >/dev/null
```

Expected: one canonical credential-free binding whose raw input digest and
`import_review_trust_anchor_digest` have already been independently checked
by Task 1A against the managed preference/System keychain and are later
frozen by B0. If enterprise setup has not produced the input, Task 2 stops
with program terminal
`BLOCKED_EXTERNAL_BOOTSTRAP` and reason code
`BLOCKED_EXTERNAL_SERVICE_BINDING`; no example origin, key digest, OIDC
identity, or local substitute is committed. Its complete canonical bytes,
service/signing identities, and anchor digest must byte-match the binding that
signed Preparation-R `ImportReviewV1`; substitution uses the same
terminal/reason.

The catalog stores the exact sorted `bootstrap_helper_paths` used by its 19 contracts. At this task boundary, every helper path must be a regular indexed file and every helper digest must match; Task 7 later forms the full B0 path manifest after Tasks 3–6 have created the verifier, workflow, runner, and remaining schemas.

- [ ] **Step 7: Run exact-set tests and commit**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_gate_catalog_v0 \
  scripts.test_qinao_admission_protocol_v1
python3 scripts/build_qinao_gate_catalog_v0.py \
  --verify-projection scripts/qinao_gate_modules/v0/program-spec-v1.json
for document in \
  docs/superpowers/specs/qinao-gate-program-spec-v1.schema.json \
  docs/superpowers/specs/qinao-gate-catalog-v1.schema.json \
  docs/superpowers/specs/qinao-gate-contract-v1.schema.json \
  docs/superpowers/specs/qinao-gate-corpus-v1.schema.json \
  scripts/qinao_gate_modules/v0/program-spec-v1.json \
  scripts/qinao_gate_modules/v0/catalog-v1.json
do
  test -f "$document" || exit 1
  python3 -m json.tool "$document" >/dev/null || exit 1
done
python3 - <<'PY'
import subprocess

stems = (
    "owner_ledger",
    "review_candidate",
    "review_closure",
    "plan_remediation",
    "xcode27_toolchain",
    "ios27_floor",
    "production_reachability",
    "architecture_closure",
    "v2_quarantine",
    "provider_boundary",
    "w0_open_set",
    "k4_platform_proof",
    "samplehost_ios",
    "contracts_layercell",
    "artifact_mesh_device_recovery",
    "semantic_statelake_context",
    "silicon_execution_spine",
    "sovereign_release_effects",
    "runtime_replay_certification",
)
paths = [
    "docs/superpowers/specs/qinao-admission-service-binding-v1.schema.json",
    "docs/superpowers/specs/qinao-gate-catalog-v1.schema.json",
    "docs/superpowers/specs/qinao-gate-contract-v1.schema.json",
    "docs/superpowers/specs/qinao-gate-corpus-v1.schema.json",
    "docs/superpowers/specs/qinao-gate-program-spec-v1.schema.json",
    "scripts/build_qinao_gate_catalog_v0.py",
    "scripts/qinao_gate_modules/v0/catalog-v1.json",
    "scripts/qinao_gate_modules/v0/program-spec-v1.json",
    "scripts/qinao_gate_modules/v0/service-binding-v1.json",
    "scripts/qinao_gate_modules/v0/runtime.py",
    "scripts/test_qinao_gate_catalog_v0.py",
]
for stem in stems:
    paths.extend(
        (
            f"scripts/qinao_gate_modules/v0/contracts/{stem}.json",
            f"scripts/qinao_gate_modules/v0/modules/{stem}.py",
            f"scripts/qinao_gate_modules/v0/corpora/{stem}.json",
        )
    )
paths = sorted(paths)
assert len(paths) == 68 and len(paths) == len(set(paths))
subprocess.run(["git", "add", "--", *paths], check=True)
staged = subprocess.check_output(
    ["git", "diff", "--cached", "--name-only", "--"],
    text=True,
).splitlines()
assert staged == paths, (staged, paths)
PY
git diff --cached --check
git commit -m "feat(qinao): freeze complete bootstrap gate catalog"
```

Expected: all tests pass; exactly 68 paths are staged and one commit contains
only the four gate schemas, service-binding schema/value, literal program
source, deterministic generator, catalog/runtime/module/contract/corpus files,
and their test. The exact eight graph catalog tests pass; all nine mapped
gate IDs are existing rows; `w0_open_set` retains 16 safety IDs/13 suites and
its exact ten-row graph-case digest; totals remain 19 gates, 42 programs, 126
outer corpus cases, and 152 matrix cells. `bootstrap-paths-v1.json` is not
created or staged until Task 7.

---

### Task 3: Implement Verifier V0 Exact-OID Isolation

**Files:**
- Create: `scripts/qinao_wave_verifier_v0.py`
- Create: `scripts/test_qinao_wave_verifier_v0.py`

**Interfaces:**
- Consumes: a server-signed `EvaluationLease`, Git object database, externally verified B0 binding, and output directory.
- Produces: one canonical `GateResult` per exact required gate, every
  program-owned canonical semantic projection in that gate's concrete
  `output_rows_by_wave`, and `gate-results/index.json`; never produces an
  admission decision.

- [ ] **Step 0: Reopen Input A and close Preparation Z**

Read indexed `docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json`.
Require its `wave_admission_contract_digest` to equal the indexed raw-byte
digest of
`docs/superpowers/specs/qinao-wave-admission-bootstrap-v1.schema.json`, and its
`required_gate_contracts_digest` to equal the domain-separated digest of
`scripts/qinao_gate_modules/v0/catalog-v1.json` defined by Bootstrap Task 2
and digest-bound by Authority Task 3.
Also revalidate all 11 document ID/path/blob rows against indexed bytes. A
missing handoff, changed schema/catalog, or draft-byte drift stops
with program terminal `BLOCKED_EXTERNAL_BOOTSTRAP` and reason code
`BLOCKED_BOOTSTRAP_CONTRACT_HANDOFF`; it never triggers regeneration.

- [ ] **Step 1: Write RED object-isolation and hostile-tree tests**

Use disposable SHA-1 and, when installed Git supports it, SHA-256 repositories. Cover:

First create `scripts/qinao_wave_verifier_v0.py` as an importable typed seam
containing the final dataclasses and public signatures specified in Steps 3
and 4. Each public operation raises
`VerificationError("qinao.wave-verifier.unimplemented")`. The RED suite must
reach those named operations; syntax, import, or attribute failure is invalid
RED.

```python
def test_payload_bytes_come_from_lease_oid_not_worktree(self) -> None:
    fixture = GitFixture()
    payload = fixture.commit_file("value.txt", b"indexed\n")
    fixture.write_worktree("value.txt", b"untrusted worktree\n")
    entries = verify_commit_tree(
        git_dir=fixture.git_dir,
        commit_oid=payload.commit,
        expected_tree_oid=payload.tree,
    )
    snapshot = materialize_tree(
        git_dir=fixture.git_dir,
        commit_oid=payload.commit,
        tree_oid=payload.tree,
        destination=fixture.materialization_root,
    )
    self.assertEqual(entries, snapshot.entries)
    self.assertEqual((snapshot.root / "value.txt").read_bytes(), b"indexed\n")

def test_candidate_python_cannot_shadow_bootstrap_runtime(self) -> None:
    fixture = malicious_candidate_with(
        "scripts/qinao_gate_modules/v0/runtime.py",
        b"raise SystemExit('candidate runtime executed')\n",
    )
    result = run_fixture(fixture)
    self.assertEqual(result, fixture.expected_b0_result)

def test_commit_tree_mismatch_fails_before_module_load(self) -> None:
    with self.assertRaisesRegex(VerificationError, "payload tree OID mismatch"):
        verify_payload_tree(git_dir, commit_oid, other_tree_oid)
```

Add one `QinaoGraphExactOIDIsolationTests` class whose discovered method set
is exactly:

```python
GRAPH_EXACT_OID_TESTS = {
    "test_graph_candidate_helper_change_does_not_change_b0_result",
    "test_graph_contract_substitution_fails_before_runtime",
    "test_graph_corpus_substitution_fails_before_runtime",
    "test_graph_authority_root_symlink_is_rejected",
    "test_graph_authority_root_nonregular_entry_is_rejected",
    "test_graph_authority_root_wrong_mode_is_rejected",
    "test_graph_candidate_import_attempt_is_rejected",
    "test_graph_reader_uses_exact_payload_tree_oid",
}
```

Each fixture changes only the named dimension. The helper-differential case
requires the same canonical B0 result; contract/corpus substitution requires
the corresponding digest diagnostic; symlink/nonregular/wrong-mode cases
fail before parser/discovery; candidate import fails even when it would
return a forged pass; and the reader test commits different bytes at the same
path in two trees and requires only the lease-bound tree bytes.

Also test absolute/`..`/NUL/non-UTF8 paths, symlink escape, submodule mode, executable-mode drift, missing blob, wrong B0 commit, contract/module/corpus substitution, timeout, output flood, inherited proxy, socket use, current-wave proposal activation, and a module writing outside its output directory.

- [ ] **Step 2: Run the focused RED suite**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_wave_verifier_v0
```

Expected: non-zero discovery and named behavioral failures only on
`qinao.wave-verifier.unimplemented`; syntax/import/attribute failure is not
accepted.

- [ ] **Step 3: Implement safe Git object enumeration and materialization**

Use `git ls-tree -rz --full-tree "$PAYLOAD_TREE_OID"` and `git cat-file blob "$ENTRY_OID"` through argv-only `subprocess.run`, where both variables have already passed the lowercase full-OID parser. Parse each NUL-delimited row as raw bytes, reject unsafe paths before decoding, verify mode/type, and write with `os.open(destination_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, mode)`. The public data types are:

```python
@dataclass(frozen=True)
class TreeEntry:
    mode: Literal["100644", "100755", "120000"]
    object_type: Literal["blob"]
    oid: str
    path_bytes: bytes

@dataclass(frozen=True)
class MaterializedSnapshot:
    commit_oid: str
    tree_oid: str
    root: Path
    entries: tuple[TreeEntry, ...]

```

Implement these two exact public call signatures, with no alternate overload:

```text
verify_commit_tree(*, git_dir: Path, commit_oid: str, expected_tree_oid: str) -> tuple of TreeEntry
materialize_tree(*, git_dir: Path, commit_oid: str, tree_oid: str, destination: Path) -> MaterializedSnapshot
```

Safe relative symlinks are created only after resolving the lexical target under the snapshot root; absolute, empty, NUL, or escaping targets fail. Submodules and special modes always fail. After creation, directories become `0555`, regular data becomes `0444`, and bootstrap executables become `0555`.

Build one private `ExactOIDTreeReader` from the verified
`MaterializedSnapshot.entries` tuple. It accepts only normalized UTF-8
repository-relative paths present in that exact tuple, requires the
contract-declared mode, reopens the bound blob OID with argv-only
`git cat-file blob`, and verifies byte length plus SHA-256 before returning
bytes. It never enumerates a worktree or follows a filesystem lookup. The
runtime child receives a closed reader manifest and read-only exact-tree
view; while constructing `GateContext`, the B0 runtime creates the sole
`read_tree_entry` callable from that manifest. A path absent from the
manifest, symlink/submodule/special entry, mode mismatch, OID mismatch, or
post-materialization byte drift fails before
`production_graph_reachability`.

- [ ] **Step 4: Implement B0 bundle verification and isolated module execution**

```python
@dataclass(frozen=True)
class VerifierInvocation:
    git_dir: Path
    bootstrap_commit_oid: str
    lease: EvaluationLease
    output_directory: Path

@dataclass(frozen=True)
class VerifiedBootstrapPath:
    path: str
    mode: Literal["100644", "100755"]
    blob_oid: str
    blob_sha256: str
    size_bytes: int

@dataclass(frozen=True)
class BootstrapBundle:
    bootstrap_commit_oid: str
    bootstrap_tree_oid: str
    approved_base_oid: str
    bootstrap_paths_digest: str
    catalog_digest: str
    program_spec_sha256: str
    program_graph_digest: str
    service_binding_digest: str
    runtime_blob_digest: str
    active_gate_bindings: tuple[GateBinding, ...]
    verified_paths: tuple[VerifiedBootstrapPath, ...]

@dataclass(frozen=True)
class PhysicalGateResolutionRequest:
    lease_id: str
    gate_id: str
    program_id: str
    payload_commit_oid: str
    payload_tree_oid: str
    build_identity_digest: str
    prior_gate_result_index_digest: str
    output_contract_digest: str

@dataclass(frozen=True)
class VerifiedPhysicalProjection:
    lease_id: str
    gate_id: str
    program_id: str
    payload_commit_oid: str
    payload_tree_oid: str
    request_digest: str
    projection_receipt_digest: str
    coverage_digest: str
    privacy_projection_digest: str
    issued_at: str
    expires_at: str

class PhysicalProjectionResolver(Protocol):
    def resolve(
        self,
        request: PhysicalGateResolutionRequest,
    ) -> VerifiedPhysicalProjection:
        raise NotImplementedError

```

Implement exactly:

```text
verify_bootstrap_bundle(invocation: VerifierInvocation) -> BootstrapBundle
run_required_gates(*, invocation: VerifierInvocation, physical_projection_resolver: PhysicalProjectionResolver) -> tuple of GateResult
```

The resolver is constructed by the protected B0 controller from the verified
service binding and signed lease; no CLI/environment/candidate object can
supply it. Neither function accepts caller-supplied module paths, profile
values, gate IDs, programs, or a wave label. `run_required_gates` derives the
phase DAG, constructs each `PhysicalGateResolutionRequest` only when an active
contract requires a physical primitive, verifies the returned projection, and
passes that privacy-clean value into the one matching `GateContext`.
Nonphysical gates receive `None`; a missing, extra, replayed, stale, or
cross-gate projection fails before module execution.

Before loading Python:

1. prove `parents(B0) == [approved base]`;
2. prove `diffPaths(approved base,B0)` equals `bootstrap-paths-v1.json`;
3. reopen the program source, catalog, every contract/module/corpus/helper blob,
   and the four closed gate schemas from `B0`;
4. recompute `program_spec_sha256`, the domain-separated
   `program_graph_digest`, all 57 generated-artifact rows, every helper row,
   and every module-bundle/output-contract digest without executing the
   generator;
5. derive the one cell for every `(gate_id,derived_wave)`, prove the 19
   contract `program_by_wave` projections and phase DAG are byte-equivalent to
   those cells, and reject any inactive/extra/unreachable program;
6. recompute every digest in the signed lease and bootstrap projection;
7. prove required rows equal the literal derived-wave set and every active
   row binds the exact program, output rows, three outer corpus cases, and
   for the nine mapped gates the exact nested graph-case rows/digests frozen
   by Task 2; and
8. compare B0 for `preW0`, or the authenticated predecessor seal tree for a
   later wave, to exact `Pw`; preserve every inherited prior-wave evidence
   blob/mode byte-for-byte, and reject
   any derived-current-wave result/Cw/Sw/self-claim, legacy successor, or raw
   probe-log class already present in the payload delta; and
9. prove active modules come from bootstrap for `preW0` or the prior finalized attestation for later waves.

After each module returns, require its gate-specific writable directory to
contain exactly that program's `output_rows_by_wave[derived_wave]`: the
primary gate result plus every owned supplemental projection, with canonical
schema bytes, path, mode, digest, cap, and producer step matching the contract.
`GateResult.evidence_outputs` is a bijection over those files and the final
authenticated bundle is a bijection over the union for all active programs.
A program output receipt carries its literal `producer_step_id`; when the
service validates the bundle against the assembly contract it projects that
row to `producer_id = program.gate_id` and byte-preserves path, mode, class,
and cap. It rejects a receipt whose step is absent from that program's
`ordered_steps`, a bundle whose gate-level producer differs, or a coupled
ProgramSpec/catalog/digest mutation that disagrees with the independent
W1-W6 full-tuple oracle.
A missing/extra semantic projection, a correct digest at the wrong path, a
producer substitution, or any assembler-created semantic row fails before
bundle signing. Only the four explicitly service-generated index/manifest
paths for that wave are absent from this program-owned union.

Execute B0's verified `runtime.py` by absolute path in a fresh child process with `python3 -I -S`, a minimal environment, fixed locale/time zone, bounded CPU/wall/output/file count, read-only payload/bootstrap trees, writable gate-specific output only, and runner-level network denial. Runtime loads the verified wrapper by explicit file location rather than package import. Invocation JSON goes over stdin; canonical result JSON is the only stdout. A noncanonical result, stderr overflow, signal, timeout, undeclared file, zero applicable predicate, or network attempt fails the gate.

- [ ] **Step 5: Prove candidate independence with differential tests**

For every one of the 42 reachable program rows in every gate corpus:

1. run its positive case and require `passed`;
2. run its negative case and require its exact diagnostic;
3. run its mutation case and require failure;
4. place a forged passing checker/test in `Pw`; and
5. prove the active B0 module result is unchanged;
6. delete or mutate each owned supplemental output and require bundle
   rejection; and
7. ask the service assembler to synthesize one missing semantic row and
   require conformance rejection.

For the nine graph-mapped rows, also execute the exact nested inventory. The
test-owned oracle derives 110 executions from the literal task table:
3 owner-ledger + 8 reachability + 4 architecture + 10 W0 freeze +
16 contracts + 22 semantic + 18 Silicon + 14 Sovereign + 15 Runtime. It
requires every expected case ID once in each eligible distinct program,
non-zero discovery/execution, the exact diagnostic, and no candidate helper
import. A 109th/111th row, changed first-wave placement, or case hidden behind
an outer expected failure is rejected.

Run:

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_wave_verifier_v0 \
  scripts.test_qinao_gate_catalog_v0
```

Expected: all tests pass; every one of the 42 programs executes exactly one
outer positive, one outer negative, and one outer mutation case, for 126
outer executions, plus exactly 110 nested graph-case executions; every one
of the 19 module bundles is covered and no corpus program is unreachable.

- [ ] **Step 6: Commit verifier V0**

```bash
set -euo pipefail
git add scripts/qinao_wave_verifier_v0.py \
  scripts/test_qinao_wave_verifier_v0.py
git diff --cached --check
git commit -m "feat(qinao): isolate verifier v0 from candidate bytes"
```

Expected: exactly two staged paths.

---

### Task 4: Close the Signed Bootstrap Projection and Local Preflight

**Files:**
- Modify: `docs/superpowers/specs/qinao-wave-admission-bootstrap-v1.schema.json`
- Modify: `docs/superpowers/specs/qinao-wave-admission-receipt-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-payload-proposal-receipt-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-evaluation-dispatch-intent-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-external-physical-gate-binding-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-physical-evidence-request-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-physical-evidence-projection-receipt-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-evidence-assembly-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-git-object-import-receipt-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-bootstrap-object-import-receipt-v1.schema.json`
- Modify: `docs/superpowers/evidence/qinao-wave-admission/bootstrap-candidate-manifest.json`
- Modify: `scripts/check_qinao_wave_admission.py`
- Modify: `scripts/test_check_qinao_wave_admission.py`

**Interfaces:**
- Consumes: complete catalog and protocol value types.
- Produces: a closed schema for external `wave_admission_v1`, a still-blocked candidate projection, and structural-only local diagnostics.

- [ ] **Step 1: Add RED profile-placement and no-authority tests**

Add:

```python
def test_profile_exists_only_in_signed_bootstrap_projection_schema(self) -> None:
    schema = load_json(BOOTSTRAP_SCHEMA)
    self.assertIn("build_evidence_storage_profile", schema["required"])
    self.assertIn("build_evidence_storage_profile", schema["properties"])
    self.assertIn("verification_toolchain_profile", schema["required"])
    self.assertIn("verification_toolchain_profile", schema["properties"])
    blocked = load_json(BLOCKED_PROJECTION)
    self.assertNotIn("build_evidence_storage_profile", blocked)
    self.assertNotIn("verification_toolchain_profile", blocked)
    catalog = load_json(GATE_CATALOG)
    self.assertNotIn("build_evidence_storage_profile", catalog)
    self.assertNotIn("verification_toolchain_profile", catalog)

def test_projection_contains_policy_not_its_own_attestation(self) -> None:
    schema = load_json(BOOTSTRAP_SCHEMA)
    self.assertIn("bootstrap_attestation_policy", schema["required"])
    self.assertNotIn("external_attestation", schema["properties"])
    self.assertNotIn("bootstrap_attestation_digest", schema["properties"])

def test_bootstrap_root_uses_the_canonical_38_field_projection(self) -> None:
    schema = load_json(BOOTSTRAP_SCHEMA)
    expected = {
        "schema_version", "repository_identity", "protected_ref",
        "approved_base_oid", "bootstrap_commit_oid", "bootstrap_tree_oid",
        "bootstrap_paths_digest", "runner_ref", "run_ref_prefix",
        "payload_proposal_ref_prefix", "runner_workflow_identity",
        "runner_bundle_digest", "runner_oidc_issuer", "runner_oidc_subject",
        "runner_oidc_audience", "runner_environment", "runner_group",
        "runner_label", "runner_attestation_identity_digest",
        "runner_isolation_profile_digest", "admission_service_identity",
        "admission_service_origin", "admission_service_tls_identity_digest",
        "admission_service_signing_identity_digest", "gate_catalog",
        "required_gates_by_wave", "verification_toolchain_profile",
        "build_evidence_storage_profile", "bootstrap_attestation_policy",
        "evaluation_dispatch_contract_digest",
        "external_physical_gate_contract_digest",
        "physical_evidence_request_contract_digest",
        "physical_evidence_projection_receipt_contract_digest",
        "payload_proposal_contract_digest",
        "evidence_assembly_contract_digest",
        "git_object_import_contract_digest",
        "bootstrap_object_import_contract_digest",
        "expected_protection_policy_digest",
    }
    self.assertEqual(len(expected), 38)
    self.assertEqual(set(schema["required"]), expected)
    self.assertEqual(set(schema["properties"]), expected)
    self.assertFalse(schema["additionalProperties"])
    forbidden_aliases = {
        "repository", "workflow_identity", "oidc_subject",
        "verifier_v0_bundle_digest", "wave_order",
        "force_updates_forbidden", "deletion_forbidden",
        "external_attestation", "b0_commit_oid", "b0_tree_oid",
        "runner_digest", "bootstrap_attestation_digest",
    }
    self.assertTrue(forbidden_aliases.isdisjoint(schema["properties"]))

def test_local_checker_never_emits_admitted(self) -> None:
    completed = run_checker("--mode", "preflight", "--bootstrap", str(valid_signed))
    document = json.loads(completed.stdout)
    self.assertEqual(document["status"], "preflight")
    self.assertEqual(document["result"], "blocked")
    self.assertNotIn("admitted", completed.stdout)

def test_receipt_binds_import_review_audit_root_without_new_cw_path(self) -> None:
    receipt = load_json(RECEIPT_SCHEMA)
    self.assertIn(
        "source_import_review_audit_root_digest", receipt["required"]
    )
    self.assertIn(
        "source_import_review_audit_root_digest", receipt["properties"]
    )
    self.assertEqual(
        load_program_spec()["cw_assembly_contracts_by_wave"]["preW0"][
            "maximum_cw_file_count"
        ],
        132,
    )
    self.assertEqual(
        load_program_spec()["cw_assembly_contracts_by_wave"]["W0"][
            "maximum_cw_file_count"
        ],
        16,
    )

def test_signed_projection_binds_nine_graph_rows_without_new_field(self) -> None:
    catalog = load_and_validate_gate_catalog()
    by_id = {row["gate_id"]: row for row in catalog["gate_catalog"]}
    graph_rows = tuple(
        (
            row["gate_id"],
            row["gate_contract_digest"],
            row["bootstrap_module_bundle_digest"],
            row["bootstrap_corpus_digest"],
            row["evidence_output_contract_digest"],
        )
        for row in (by_id[gate_id] for gate_id in GRAPH_GATE_IDS)
    )
    self.assertEqual(tuple(row[0] for row in graph_rows), GRAPH_GATE_IDS)
    projection = valid_signed_projection_fixture(catalog=catalog)
    self.assertEqual(
        projection["gate_catalog"]["catalog_digest"],
        raw_catalog_digest(catalog),
    )
    self.assertEqual(
        projection["gate_catalog"]["program_graph_digest"],
        catalog["program_graph_digest"],
    )
    self.assertTrue(
        {
            "graph_gate_rows", "graph_contract_digest",
            "graph_module_digest", "graph_corpus_digest",
        }.isdisjoint(projection),
    )
```

Also reject missing/extra profile fields, credentials/secrets/URLs with
user-info, unknown external-evidence classes, an unsigned profile, profile in
the blocked manifest, catalog/profile digest mismatch, external attestation
encoded in the receipt schema, a payload proposal without host-side object
reopen, caller-supplied proposal ref, nondeterministic/missing Cw/Sw commit
identity, target-host Cw/Sw import before a fresh reopened
`ProtectedRefAdvanceAuthorizationV1`, Cw/Sw object import without host reopen,
and any `--wave`, `--ref`, `--profile`, `--verifier`, or `--module` flag.
The test-owned `GRAPH_GATE_IDS` tuple is the exact nine IDs frozen in Task 2.
Mutating any one of their contract/module/corpus/program digests while
updating only a candidate or local projection must fail through the existing
catalog/program-graph digest chain. No graph-specific root field, schema,
gate, selector, or attestation field is added.

- [ ] **Step 2: Run the focused RED suite**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_wave_admission
```

Expected: failures for the absent profile and signed service/runner fields.

- [ ] **Step 3: Add the closed profile only to the signed projection schema**

The exact verification-toolchain profile fields are:

```text
xcode_version
xcode_build_version
iphoneos_sdk_version
runner_image_identity
runner_attestation_identity_digest
runner_isolation_profile_digest
toolchain_probe_contract_digest
profile_digest
```

The ceremony requires Xcode major 27 and an iOS 27 SDK on an externally
attested Apple-silicon runner. `runner_image_identity` binds the sealed host
image; `runner_attestation_identity_digest` binds the host broker/quote signer;
and `runner_isolation_profile_digest` binds the controller/evaluator UID split,
read-only payload mount, output-only evidence mount, stripped credential/OIDC
environment, closed inherited file descriptors, and network-denied evaluator
policy. GitHub runner labels are routing hints only and cannot satisfy these
fields. The profile records observed, authenticated values rather than
predicted build numbers. It selects only the bootstrap verifier environment;
it cannot populate `selected_release_profiles`.

The exact profile fields are:

```text
provider_repository_identity
region_endpoint_class
client_aead_algorithm
chunking_algorithm
content_address_algorithm
kms_key_custody_principal
kms_key_epoch
no_replace_versioning_policy
write_principal
read_grant_issuer
retention_policy
destruction_policy
audit_transparency_root
multipart_resume_identity
reopen_availability_protocol
```

Every field is a non-empty closed object or stable string with explicit
version/algorithm/policy identity. Credentials, access tokens, raw endpoints
with credentials, device IDs, raw paths, and key material are forbidden. The
bootstrap-root schema has exactly these 38 required/properties fields:

```text
schema_version
repository_identity
protected_ref
approved_base_oid
bootstrap_commit_oid
bootstrap_tree_oid
bootstrap_paths_digest
runner_ref
run_ref_prefix
payload_proposal_ref_prefix
runner_workflow_identity
runner_bundle_digest
runner_oidc_issuer
runner_oidc_subject
runner_oidc_audience
runner_environment
runner_group
runner_label
runner_attestation_identity_digest
runner_isolation_profile_digest
admission_service_identity
admission_service_origin
admission_service_tls_identity_digest
admission_service_signing_identity_digest
gate_catalog
required_gates_by_wave
verification_toolchain_profile
build_evidence_storage_profile
bootstrap_attestation_policy
evaluation_dispatch_contract_digest
external_physical_gate_contract_digest
physical_evidence_request_contract_digest
physical_evidence_projection_receipt_contract_digest
payload_proposal_contract_digest
evidence_assembly_contract_digest
git_object_import_contract_digest
bootstrap_object_import_contract_digest
expected_protection_policy_digest
```

`required` and `properties.keys()` equal that set, and the root plus every
nested object has `additionalProperties: false`. The obsolete aliases
`repository`, `workflow_identity`, `oidc_subject`,
`verifier_v0_bundle_digest`, `wave_order`, `force_updates_forbidden`,
`deletion_forbidden`, `external_attestation`, `b0_commit_oid`, `b0_tree_oid`,
`runner_digest`, and `bootstrap_attestation_digest` are invalid rather than
silently translated.

`expected_protection_policy_digest` is recomputed only from the exact
13-field `AdmissionProtectionProjectionV1` and exact
`RefProtectionPolicyProjectionV1`/ruleset-row field sets frozen in the master
and protocol module. Provider adapters retain raw response digests separately.
Development/default-branch required-check contexts are never projected into
this value. Extend the existing projection test method with subtests for
missing/extra fields, absent-vs-empty arrays, unordered arrays, duplicate
writer/bypass identities, raw-response hashing, context-name inclusion, each
nested policy mutation, inactive enforcement, false force/deletion flags,
exact-ref/prefix confusion, non-slash prefix, broader/narrower/glob/regex
target, selector normalization, unauthorized writer, and noncanonical JSON.

`bootstrap_attestation_policy` has exactly
`schema_version`, `signature_algorithm`, `signing_identity_digest`,
`transparency_store_identity_digest`, and
`minimum_distinct_operator_approvals`; the last value is integer `2`. It is a
verification policy, not proof that a ceremony occurred. The separately
exported `bootstrap-attestation-v1.json` authenticates this projection and is
never embedded back into it.

The repository object retains canonical ref `refs/heads/qinao-admitted`; `runner_ref` is exactly `refs/heads/qinao-admission-bootstrap-v1`. Both are create-once, force-update-forbidden, deletion-forbidden, and initially point to `B0`.

Close every companion schema with `additionalProperties: false` and exact
required fields. `qinao-evaluation-dispatch-intent-v1` binds one proposal
receipt digest to one opaque run-ref suffix, B0, workflow identity,
created/expiry times, predecessor/supersession, and append-only status; it
contains no caller-selected payload field. `qinao-external-physical-gate-
binding-v1` exactly mirrors `ExternalPhysicalGateBinding`.
`qinao-physical-evidence-request-v1` binds lease/gate/program/Pw/build,
one fresh challenge, exact matrix/subject identity, and output contract.
`qinao-physical-evidence-projection-receipt-v1` binds that request, distinct
producer/attester principals, custody/reopen receipt, policy/toolchain/archive
digests, executed coverage, privacy-clean projection digest, retention and
destruction obligations, issued/expiry times, and external signature. It
contains no raw device ID, log, container, profile, CMS chain, key, or secret.

`qinao-payload-proposal-receipt-v1` binds repository, payload commit/tree,
content-addressed service-owned proposal ref, Git-host transaction/audit
identity, uploader authorization digest, object-set digest, and host-side
reopen observation. The ref's final component equals the payload OID, but the
receipt—not its spelling—proves availability.
`qinao-evidence-assembly-v1` binds lease, active output-contract digest, exact
sorted evidence outputs, frozen Cw/Sw commit identities, canonical receipt
bytes, `source_import_review_audit_root_digest`, and derived Pw/Cw/Sw
topology. `qinao-wave-admission-receipt-v1` carries the same digest: sorted
C1+C2 for preW0 and sorted C1+C2+C3 for W0 and later. The digest is metadata inside the already
allowlisted sole Sw receipt, not a new Cw leaf.
`qinao-git-object-import-receipt-v1` binds the same repository/object set,
imported pack/object-set digest, host transaction identity, and post-import
reopen observation. `qinao-bootstrap-object-import-receipt-v1` does the same
for approved base plus exact B0 commit/tree/parent/path closure before
protected refs exist. None accepts a wave, canonical ref, release profile,
verifier, gate module, success Boolean, or attestation from the caller.

- [ ] **Step 4: Keep local validation structural and fail-closed**

`check_qinao_wave_admission.py` may validate canonical shape, exact sorting, chain topology, OID/blob equality available in the local repository, and digest consistency. Even with a syntactically valid external bootstrap file it returns:

```json
{
  "status": "preflight",
  "result": "blocked",
  "blocker": {
    "code": "external_attestation_authentication_unavailable"
  }
}
```

It does not read GitHub environment identity, call the external service, query live protection, obtain OIDC, run CAS, or verify an external signature with a caller key.

- [ ] **Step 5: Preserve the blocked candidate projection**

Keep its exact fields:

```text
approved_base_commit
approved_design_sha256
authority
blocker
external_bootstrap_attestation
external_bootstrap_bundle
production_admission
projection_type
schema_version
status
```

Its values remain `authority = "none"`, `production_admission = "blocked"`, `status = "blocked"`, both external fields `null`, and blocker `external_bootstrap_unavailable`.

- [ ] **Step 6: Run schemas and tests, then commit**

```bash
set -euo pipefail
python3 -m json.tool \
  docs/superpowers/specs/qinao-wave-admission-bootstrap-v1.schema.json
python3 -m json.tool \
  docs/superpowers/specs/qinao-wave-admission-receipt-v1.schema.json
python3 -m json.tool \
  docs/superpowers/specs/qinao-payload-proposal-receipt-v1.schema.json
python3 -m json.tool \
  docs/superpowers/specs/qinao-evaluation-dispatch-intent-v1.schema.json
python3 -m json.tool \
  docs/superpowers/specs/qinao-external-physical-gate-binding-v1.schema.json
python3 -m json.tool \
  docs/superpowers/specs/qinao-physical-evidence-request-v1.schema.json
python3 -m json.tool \
  docs/superpowers/specs/qinao-physical-evidence-projection-receipt-v1.schema.json
python3 -m json.tool \
  docs/superpowers/specs/qinao-evidence-assembly-v1.schema.json
python3 -m json.tool \
  docs/superpowers/specs/qinao-git-object-import-receipt-v1.schema.json
python3 -m json.tool \
  docs/superpowers/specs/qinao-bootstrap-object-import-receipt-v1.schema.json
python3 -m json.tool \
  docs/superpowers/evidence/qinao-wave-admission/bootstrap-candidate-manifest.json
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_wave_admission \
  scripts.test_qinao_admission_protocol_v1
git add docs/superpowers/specs/qinao-wave-admission-bootstrap-v1.schema.json \
  docs/superpowers/specs/qinao-wave-admission-receipt-v1.schema.json \
  docs/superpowers/specs/qinao-payload-proposal-receipt-v1.schema.json \
  docs/superpowers/specs/qinao-evaluation-dispatch-intent-v1.schema.json \
  docs/superpowers/specs/qinao-external-physical-gate-binding-v1.schema.json \
  docs/superpowers/specs/qinao-physical-evidence-request-v1.schema.json \
  docs/superpowers/specs/qinao-physical-evidence-projection-receipt-v1.schema.json \
  docs/superpowers/specs/qinao-evidence-assembly-v1.schema.json \
  docs/superpowers/specs/qinao-git-object-import-receipt-v1.schema.json \
  docs/superpowers/specs/qinao-bootstrap-object-import-receipt-v1.schema.json \
  docs/superpowers/evidence/qinao-wave-admission/bootstrap-candidate-manifest.json \
  scripts/check_qinao_wave_admission.py \
  scripts/test_check_qinao_wave_admission.py
git commit -m "feat(qinao): close signed bootstrap projection"
```

Expected: all ten schemas and the blocked projection parse; all tests pass;
the blocked projection contains no profile; the signed-fixture test binds all
nine amended rows through the existing catalog/program-graph digests; exactly
thirteen paths are staged.

This completes Preparation Z. Return the two indexed paths and their digest
algorithms to Authority Task 3; do not execute Bootstrap Task 3 until Input A
has been generated, committed, and reopened successfully.

---

### Task 5: Implement the Protected OIDC Runner and External Handoff

**Files:**
- Create: `scripts/qinao_protected_admission_runner.py`
- Create: `scripts/test_qinao_protected_admission_runner.py`
- Create: `scripts/qinao_external_physical_gate_v0.py`
- Create: `scripts/test_qinao_external_physical_gate_v0.py`
- Modify: `.github/workflows/qinao-wave-admission.yml`

**Interfaces:**
- Consumes: GitHub OIDC environment, one create-once B0 run-ref push event,
  immutable B0 service binding, service-side dispatch intent and payload
  proposal receipt, server-signed evaluation lease, and controller-only
  external physical-gate capability.
- Produces: authenticated evaluation/evidence messages and an internal service
  projection whose durable state is mapped to the master program terminal:
  finalized plus valid attestation → `admitted`, CAS without attestation →
  `pendingAdmission`, lineage disagreement → `quarantinedAdmission`, and
  missing external prerequisites → the applicable master `BLOCKED_*` terminal
  plus reason code. It owns no Cw/Sw construction, object import, intent, CAS,
  attestation, ref, or authority selection.

- [ ] **Step 1: Write RED no-selection and permission tests**

```python
def test_runner_cli_accepts_no_arguments(self) -> None:
    completed = subprocess.run(
        [sys.executable, str(RUNNER), "--wave", "W0"],
        text=True, capture_output=True,
    )
    self.assertNotEqual(completed.returncode, 0)
    self.assertIn("accepts no command-line arguments", completed.stderr)

def test_workflow_has_oidc_but_no_repository_write(self) -> None:
    workflow = WORKFLOW.read_text(encoding="utf-8")
    self.assertIn("contents: read", workflow)
    self.assertIn("id-token: write", workflow)
    self.assertNotIn("contents: write", workflow)
    self.assertIn("group: qinao-admission-protected", workflow)
    self.assertIn("labels: qinao-xcode27-arm64-v1", workflow)
    self.assertIn("persist-credentials: false", workflow)
    self.assertIn("qinao-admission-runs/**", workflow)
    self.assertNotIn("workflow_dispatch", workflow)
    self.assertNotIn("inputs:", workflow)
    self.assertNotIn("runs-on: macos-15", workflow)
    for forbidden in ("wave:", "ref:", "profile:", "verifier:", "module:"):
        self.assertNotIn(forbidden, workflow)
```

Add one exact graph-selection class with only:

```python
GRAPH_RUNNER_SELECTION_TESTS = {
    "test_runner_cannot_select_graph_module",
    "test_lease_reopens_predecessor_selected_nine_graph_bindings",
    "test_graph_amendment_does_not_create_gate_twenty",
}
```

The first test injects module/verifier/gate selector data through the event,
environment, candidate manifest, proposal receipt, and fake service response;
every form fails before evaluation. The second requires all nine exact
contract/module/corpus/program bindings to byte-match B0 at preW0 or the
authenticated predecessor's finalized binding at later waves. The third
reconstructs the complete lease set and requires 19 unique gates/152 cells
with no twentieth gate or graph-specific admission path.

Also test a non-create run-ref event, run-ref/dispatch-intent mismatch,
payload-shaped event field, OIDC subject/audience or `runner_environment`
mismatch, workflow SHA
not `B0`, unpinned action, mutable runner ref, a group/label substitution, label
without a valid host quote, replayed/wrong-challenge quote, runner-image,
attestation-identity, isolation-profile, Xcode, or SDK mismatch, evaluator
network/broker/OIDC-token access, environment-supplied service origin,
authorization-header logging, lease signature mismatch, result replay,
caller-supplied proposal ref, payload object/ref mismatch, a prebuilt `Cw` or
`Sw` in the request, an evidence output outside the signed allowlist,
nondeterministic commit identity, missing object-import receipt, and a fake
service asking the runner to construct a commit or update a ref.
Assert the public envelope never emits `finalized`, `quarantined`, or
`blocked`; those internal states map only to `admitted`,
`quarantinedAdmission`, or an exact master `BLOCKED_*` terminal.

- [ ] **Step 2: Run focused RED tests**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_protected_admission_runner
```

Expected: both modules import through typed RED seams; named methods fail only
with `qinao.protected-runner.unimplemented` or
`qinao.external-physical-gate.unimplemented`. Import/file failure is not RED.

- [ ] **Step 3: Implement a no-argument two-phase runner**

The runner entry point is:

```python
def main(argv: Sequence[str] = sys.argv[1:]) -> int:
    if argv:
        raise RunnerError("protected admission runner accepts no command-line arguments")
    binding = load_b0_service_binding()
    event = load_closed_github_event(Path(require_env("GITHUB_EVENT_PATH")))
    run_ref = require_create_once_b0_run_ref(
        event=event,
        expected_prefix=binding.run_ref_prefix,
        github_ref=require_env("GITHUB_REF"),
        github_sha=require_env("GITHUB_SHA"),
    )
    oidc_token = obtain_github_oidc_token(
        audience=binding.runner_oidc_audience
    )
    client_nonce = fresh_client_nonce()
    challenge_envelope = post_json(
        binding.admission_service_origin + "/v1/runner-challenges",
        authorization=oidc_token,
        body=canonical_runner_challenge_request(
            run_ref=run_ref,
            github_run_id=require_env("GITHUB_RUN_ID"),
            github_run_attempt=require_env("GITHUB_RUN_ATTEMPT"),
            client_nonce=client_nonce,
        ),
    )
    challenge = verify_runner_challenge(
        challenge_envelope,
        binding=binding,
    )
    runner_quote = obtain_host_runner_quote(
        challenge=challenge,
        expected_attestation_identity_digest=(
            binding.runner_attestation_identity_digest
        ),
        expected_isolation_profile_digest=(
            binding.runner_isolation_profile_digest
        ),
    )
    lease_envelope = post_json(
        binding.admission_service_origin + "/v1/evaluations",
        authorization=oidc_token,
        body=canonical_evaluation_request(
            client_nonce=client_nonce,
            runner_challenge_id=challenge.challenge_id,
            runner_quote=runner_quote,
        ),
    )
    lease = verify_evaluation_lease(lease_envelope, binding=binding)
    git_dir = resolve_git_dir()
    verify_bootstrap_execution_identity(
        binding=binding,
        lease=lease,
        github_sha=require_env("GITHUB_SHA"),
        git_dir=git_dir,
    )
    fetch_and_verify_service_owned_payload_object(
        git_dir=git_dir,
        object_ref=lease.payload_object_ref,
        expected_commit_oid=lease.payload_commit_oid,
        expected_tree_oid=lease.payload_tree_oid,
    )
    physical_controller = ExternalPhysicalGateController(
        binding=binding,
        lease=lease,
        git_dir=git_dir,
    )
    results = run_required_gates(
        invocation=VerifierInvocation(
            git_dir=git_dir,
            bootstrap_commit_oid=lease.bootstrap_commit_oid,
            lease=lease,
            output_directory=run_output_directory(lease.lease_id),
        ),
        physical_projection_resolver=physical_controller,
    )
    evidence_bundle = collect_closed_evidence_bundle(
        lease=lease,
        results=results,
    )
    service_projection = post_results_and_poll(
        binding,
        lease,
        results,
        evidence_bundle,
    )
    terminal = map_service_projection_to_program_terminal(
        service_projection,
        lease=lease,
    )
    print(canonical_json_bytes(terminal).decode("utf-8"))
    return terminal_exit_code(terminal)
```

The challenge request contains only protocol version, opaque run ref,
GitHub run ID/attempt, and fresh client nonce. The service authenticates OIDC,
reopens the append-only dispatch intent whose run ref matches exactly, then
derives its signed payload-proposal receipt. The evaluation request adds only
the service challenge ID and host-broker quote over that nonce, immutable
runner-image/toolchain observations, and isolation-profile digest. Payload
OID, wave, profile, verifier, modules, policy, prior OID, expected canonical
OID, Cw, Sw, receipt, and status are absent. The service derives them from the
intent, proposal receipt, finalized chain, and verified quote.

`ServiceBinding` deliberately has no `bootstrap_commit_oid`: that JSON blob
lives inside B0 and cannot contain B0's own OID. The signed lease supplies the
externally attested B0 OID. `verify_bootstrap_execution_identity` requires
`GITHUB_SHA == lease.bootstrap_commit_oid`, proves that commit is the checked
out workflow commit with the approved base as sole parent, re-hashes every
bootstrap-path blob from that commit, and only then loads verifier/runtime
bytes. Any plan or implementation that reads `binding.bootstrap_commit_oid`
reintroduces an impossible Git-object self-reference.

Before calling `run_required_gates`, the runner reopens the predecessor-
selected catalog, selects the nine `GRAPH_GATE_IDS` rows from that catalog
only, and requires each lease binding's contract/module/corpus/program
digests to match. Candidate bytes may be subjects of those programs but
cannot add, remove, rename, reorder, or select a graph binding. The complete
active set remains the existing 19-row/152-cell matrix; there is no graph
gate 20, graph workflow input, or graph-specific lease field.

- [ ] **Step 4: Convert the workflow into a zero-input B0 push client**

`workflow_dispatch` is forbidden because GitHub only delivers that event when
the workflow file exists on the default branch, while this trust root exists
only in B0. GitHub documents that `push` workflows can run before merge to the
default branch. The service therefore creates one opaque create-once run ref
at B0 after persisting the dispatch intent. The immutable workflow is:

```yaml
name: Qinao protected wave admission

on:
  push:
    branches:
      - 'qinao-admission-runs/**'

permissions:
  contents: read
  id-token: write

jobs:
  protected-admission-client:
    environment: qinao-admission-protected
    runs-on:
      group: qinao-admission-protected
      labels: qinao-xcode27-arm64-v1
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          fetch-depth: 0
          persist-credentials: false
      - name: Execute B0-pinned admission client
        run: python3 scripts/qinao_protected_admission_runner.py
```

Before the external service grants a lease, it requires the direct push
workflow's
OIDC claims `repository`, `repository_id`, `workflow_ref`, `workflow_sha`,
`sha`, `ref`, `environment`, `runner_environment`, `run_id`, and `run_attempt`
to byte-match the signed bootstrap projection, with
`runner_environment = self-hosted` and both `workflow_sha` and `sha` equal to
B0. It does not require `job_workflow_ref` or `job_workflow_sha`: GitHub emits
those custom claims for reusable-workflow jobs, while this immutable entrypoint
is a direct `push` workflow. `ref` must be exactly the intent's create-once
`refs/heads/qinao-admission-runs/<opaque-request-id>` and Git-host audit must
show the service principal created it at B0; `workflow_ref` names the same ref.
The fixed group/label route only
schedules the job; it is not proof of OS, architecture, Xcode, or isolation.
The service separately verifies the fresh host-broker quote against the signed
runner-image, attestation-identity, isolation-profile, Xcode-27, and
iOS-27-SDK bindings. It then reopens the payload-proposal receipt and its
content-addressed service-owned ref from the Git host. `runner_ref` remains the
create-once attested B0 anchor; execution occurs only on an audited run ref
whose target equals that anchor. A request from the candidate, canonical, or
arbitrary branch is denied. The runner fetches only the
service-derived proposal ref after lease verification, checks exact commit/tree,
and never treats that ref as wave or authority. Checkout credentials are not
persisted. For a private repository, the controller obtains payload objects
through a single-use, read-only host-broker fetch bound to the signed proposal
receipt and exact object set; no credential enters the environment, Git config,
payload mount, evaluator principal, output bundle, or log.

Before any candidate compiler, build script, plugin, test, or binary runs, the
attested host broker switches the evaluator compartment to the frozen isolation
profile. The B0 controller retains only a broker channel; the evaluator runs as
a distinct unprivileged principal with a read-only exact-Pw mount, one bounded
output mount, no network route, no broker socket, no inherited OIDC/request
token, no Git credential, no service credential, and closed nonessential file
descriptors. The controller validates outputs after the evaluator exits. If the
host cannot attest and enforce that split, the run stops
`BLOCKED_EXTERNAL_BOOTSTRAP` with reason code
`RUNNER_ATTESTATION_UNAVAILABLE`; clearing environment variables alone is not
an isolation proof.

`ExternalPhysicalGateController` implements
`PhysicalProjectionResolver.resolve(request:
PhysicalGateResolutionRequest) -> VerifiedPhysicalProjection` and is the only
controlled exception to
the evaluator's no-candidate-executable rule. When the active B0 program
contains `physical_evidence_external_root` or
`physical_proof_reuse_or_refresh`, it:

1. builds a canonical `PhysicalEvidenceRequestV1` from lease, B0 contract,
   exact Pw/build/archive identity, prior-phase result index, matrix/subject
   identity, and a fresh service challenge;
2. checks the matching signed `ExternalPhysicalGateBinding`;
3. sends the request over the controller's short-lived broker capability;
4. has the broker build/install/run the exact-Pw subject under the bound
   Xcode/device policy while raw output streams directly into encrypted
   external custody;
5. requires distinct producer and attester principals plus an independent
   custody reopen;
6. verifies a signed, unexpired, privacy-clean
   `PhysicalEvidenceProjectionReceiptV1`; and
7. serializes only the canonical `VerifiedPhysicalProjection` value into the
   isolated gate invocation JSON; no broker descriptor, custody path, raw
   artifact, or controller capability crosses the compartment boundary.

The candidate K4/Artifact controller, result JSON, environment, or FD can
never substitute for this receipt. No raw device ID, log, container,
provisioning profile, signing chain, key, or broker capability enters
`GateContext`, Cw, or logs. Missing broker/profile/device/custody/attester
returns the owning gate's closed blocked terminal; it is not a skip.

- [ ] **Step 5: Test the full authenticated handoff with a fake service**

Use a localhost TLS server only in tests, inject it through a test-only constructor rather than environment/CLI, and assert:

```text
OIDC requested for the exact pinned audience
Authorization token never appears in stdout/stderr/files
evaluation request contains no authority selectors
challenge/evaluation request contains no payload OID and no prebuilt Cw/Sw/receipt
service derives Pw only from dispatch intent plus signed proposal receipt
lease signature is verified before any Git object is opened
every result binds exact lease/Pw/contract/module/corpus
physical request is B0-generated and exact-Pw-bound
producer and attester differ; custody reopen precedes projection acceptance
candidate result/FD/environment cannot satisfy a physical primitive
raw physical material never enters evaluator output or Git
evidence outputs equal the active signed path/mode/blob allowlist
first same-identity service call closes deterministic Cw/Sw in non-host quarantine, publishes the advance-authorization request, returns the expected hold, and has zero target-host effects
after a fresh ProtectedRefAdvanceAuthorizationV1 is authenticated and reopened, the second same-identity call imports/reopens exactly that object set and persists its receipt before intent/CAS
runner invokes no git commit-tree, hash-object -w, update-index, update-ref, GitHub ref API, intent API, or attestation signer
service final/pending/quarantine state maps to distinct exit codes
```

The fake-service matrix runs all three exact graph-selection tests and proves
the nine bindings survive event→lease→verifier unchanged. A candidate module
selector, missing/replacement graph binding, twentieth gate, or 153rd matrix
cell fails before module execution.

Run:

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_protected_admission_runner \
  scripts.test_qinao_external_physical_gate_v0 \
  scripts.test_qinao_wave_verifier_v0
```

Expected: all tests pass.

- [ ] **Step 6: Commit protected runner and workflow**

```bash
set -euo pipefail
git add .github/workflows/qinao-wave-admission.yml \
  scripts/qinao_protected_admission_runner.py \
  scripts/test_qinao_protected_admission_runner.py \
  scripts/qinao_external_physical_gate_v0.py \
  scripts/test_qinao_external_physical_gate_v0.py
git diff --cached --check
git commit -m "feat(qinao): add protected oidc admission client"
```

Expected: exactly five staged paths.

---

### Task 6: Freeze the External Admission Crash-Recovery State Machine

**Files:**
- Create: `docs/superpowers/specs/qinao-admission-evaluation-lease-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-admission-intent-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-admission-attestation-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-bootstrap-attestation-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-bootstrap-intent-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-admission-service-state-v1.schema.json`
- Create: `scripts/qinao_admission_recovery_oracle.py`
- Create: `scripts/test_qinao_admission_recovery_oracle.py`

**Interfaces:**
- Consumes: payload-dispatch and protected-advance authorization requests plus
  opaque signed authorizations, signed payload-proposal receipt, immutable
  evaluation/assembly/import records, authenticated object/ref observations,
  immutable intent record, Git-host CAS audit, attestation record, effect
  counts, and observation freshness.
- Produces: one pure `RecoveryDecision` for admission and one pure
  `GovernanceValidationRecoveryDecision` for the pre-migration validation
  run; the external service implementation must pass both conformance suites
  before ceremony.

The state enum is exact:

```python
class AdmissionState(Enum):
    PAYLOAD_AUTHORIZATION_REQUIRED = "payloadAuthorizationRequired"
    PAYLOAD_AUTHORIZED = "payloadAuthorized"
    PAYLOAD_OBJECT_IMPORT_UNKNOWN = "payloadObjectImportUnknown"
    PAYLOAD_OBJECTS_REOPENED = "payloadObjectsReopened"
    PAYLOAD_PROPOSAL_REF_CREATE_UNKNOWN = "payloadProposalRefCreateUnknown"
    PAYLOAD_PROPOSAL_REOPENED = "payloadProposalReopened"
    PAYLOAD_DISPATCH_INTENT_CREATE_UNKNOWN = "payloadDispatchIntentCreateUnknown"
    PAYLOAD_DISPATCH_INTENT_REOPENED = "payloadDispatchIntentReopened"
    PAYLOAD_RUN_REF_CREATE_UNKNOWN = "payloadRunRefCreateUnknown"
    PAYLOAD_PINNED = "payloadPinned"
    PAYLOAD_FAILED_HOLD = "payloadFailedHold"
    EVALUATION_OPEN = "evaluationOpen"
    ASSEMBLY_READY = "assemblyReady"
    ADVANCE_AUTHORIZATION_REQUIRED = "advanceAuthorizationRequired"
    ADVANCE_AUTHORIZED = "advanceAuthorized"
    OBJECT_IMPORT_UNKNOWN = "objectImportUnknown"
    OBJECTS_IMPORTED = "objectsImported"
    INTENT_OPEN = "intentOpen"
    CAS_OUTCOME_UNKNOWN = "casOutcomeUnknown"
    ADVANCE_FAILED_HOLD = "advanceFailedHold"
    PENDING_ADMISSION = "pendingAdmission"
    FINALIZED = "finalized"
    SUPERSEDED = "superseded"
    QUARANTINED = "quarantined"
```

The decision enum is exact:

```python
class RecoveryAction(Enum):
    WAIT_FOR_PAYLOAD_AUTHORIZATION = "waitForPayloadAuthorization"
    QUERY_PAYLOAD_AUTHORIZATION = "queryPayloadAuthorization"
    IMPORT_PAYLOAD_OBJECTS = "importPayloadObjects"
    QUERY_PAYLOAD_OBJECTS = "queryPayloadObjects"
    CREATE_PAYLOAD_PROPOSAL_REF = "createPayloadProposalRef"
    QUERY_PAYLOAD_PROPOSAL_REF = "queryPayloadProposalRef"
    CREATE_PAYLOAD_DISPATCH_INTENT = "createPayloadDispatchIntent"
    QUERY_PAYLOAD_DISPATCH_INTENT = "queryPayloadDispatchIntent"
    CREATE_PAYLOAD_RUN_REF = "createPayloadRunRef"
    QUERY_PAYLOAD_RUN_REF = "queryPayloadRunRef"
    RETURN_PAYLOAD_HOLD = "returnPayloadHold"
    ISSUE_EVALUATION_LEASE = "issueEvaluationLease"
    RETRY_SAME_EVALUATION = "retrySameEvaluation"
    ASSEMBLE_BYTE_IDENTICAL_OBJECTS = "assembleByteIdenticalObjects"
    WAIT_FOR_ADVANCE_AUTHORIZATION = "waitForAdvanceAuthorization"
    QUERY_ADVANCE_AUTHORIZATION = "queryAdvanceAuthorization"
    IMPORT_AUTHORIZED_OBJECTS = "importAuthorizedObjects"
    QUERY_HOST_OBJECTS = "queryHostObjects"
    CREATE_INTENT = "createIntent"
    RETRY_SAME_INTENT = "retrySameIntent"
    QUERY_HOST_AUDIT = "queryHostAudit"
    CREATE_SUPERSEDING_INTENT = "createSupersedingIntent"
    RETURN_ADVANCE_HOLD = "returnAdvanceHold"
    FINALIZE_BYTE_IDENTICAL_ATTESTATION = "finalizeByteIdenticalAttestation"
    RETURN_EXISTING_ATTESTATION = "returnExistingAttestation"
    BLOCK_NEXT_WAVE = "blockNextWave"
    QUARANTINE = "quarantine"
```

Governance validation uses a disjoint state/action vocabulary so it can never
be mistaken for protected admission or create SDK authority:

```python
class GovernanceValidationState(Enum):
    AUTHORIZATION_REQUIRED = "authorizationRequired"
    AUTHORIZATION_PERSISTENCE_UNKNOWN = "authorizationPersistenceUnknown"
    AUTHORIZED = "authorized"
    OBJECT_IMPORT_UNKNOWN = "objectImportUnknown"
    OBJECTS_REOPENED = "objectsReopened"
    REF_CREATE_UNKNOWN = "refCreateUnknown"
    REF_REOPENED = "refReopened"
    RUN_OUTCOME_UNKNOWN = "runOutcomeUnknown"
    RUN_SUCCEEDED = "runSucceeded"
    RUN_FAILED_HOLD = "runFailedHold"
    QUARANTINED = "quarantined"

class GovernanceValidationAction(Enum):
    WAIT_FOR_AUTHORIZATION = "waitForAuthorization"
    QUERY_AUTHORIZATION = "queryAuthorization"
    IMPORT_EXACT_OBJECTS = "importExactObjects"
    QUERY_HOST_OBJECTS = "queryHostObjects"
    CREATE_VALIDATION_REF = "createValidationRef"
    QUERY_HOST_REF = "queryHostRef"
    QUERY_HOST_RUN = "queryHostRun"
    RETURN_SUCCESS_OBSERVATION = "returnSuccessObservation"
    RETURN_FAILED_HOLD = "returnFailedHold"
    QUARANTINE = "quarantine"
```

- [ ] **Step 1: Write the exhaustive RED transition table**

Tests first cover the complete `PayloadDispatchAuthorizationV1` operation.
“Exact payload authorization” means the opaque signed record is persisted,
authenticated, reopened, fresh for a new effect, and byte-matches the one
authorization request and all payload/proposal/dispatch bindings. Expiry
after an effect starts permits only query/reopen:

| Payload authorization | Target payload objects | Proposal ref/receipt | Dispatch intent | Run ref | Decision |
|---|---|---|---|---|---|
| absent/pending, or expired before any effect | known absent | absent | absent | absent | `waitForPayloadAuthorization` |
| persistence unknown or persisted but not reopened | no effect | absent | absent | absent | `queryPayloadAuthorization` |
| exact and fresh | known absent, import count 0 | absent | absent | absent | `importPayloadObjects` |
| same operation | import outcome unknown | absent | absent | absent | `queryPayloadObjects` |
| exact and fresh | exact objects host-reopened | known absent, create count 0 | absent | absent | `createPayloadProposalRef` |
| same operation | exact objects host-reopened | create outcome unknown | absent | absent | `queryPayloadProposalRef` |
| exact and fresh | exact objects host-reopened | exact ref/receipt reopened | known absent, create count 0 | absent | `createPayloadDispatchIntent` |
| same operation | exact objects host-reopened | exact ref/receipt reopened | persistence outcome unknown | absent | `queryPayloadDispatchIntent` |
| exact and fresh | exact objects host-reopened | exact ref/receipt reopened | exact intent reopened | known absent, create count 0 | `createPayloadRunRef` |
| same operation | exact objects host-reopened | exact ref/receipt reopened | exact intent reopened | create outcome unknown | `queryPayloadRunRef` |
| same operation consumed by this exact completed chain | exact host-reopened | exact host-reopened | exact intent reopened | exact B0 run ref reopened | `issueEvaluationLease` |
| any authorized payload host effect failed/cancelled | any | any | any | any | `returnPayloadHold` |
| invalid/mismatched/cross-intent replay, receipt digest without fresh authorization, effect before authorization/reopen, or any effect count greater than one | any | any | any | any | `quarantine` |

The payload authorization cannot be replaced by
`PayloadProposalReceiptV1`, its digest, a host object that happens to exist,
or a prior consumed authorization. Known-absent plus exact fresh reopened
authorization is the only state that selects a create/import action; every
unknown state selects its corresponding query.

The evaluation and protected-advance rows are then exhaustive:

| Payload/evaluation state | Assembly/advance authorization | Target Cw/Sw objects | Decision |
|---|---|---|---|
| exact pinned payload, no evaluation | absent | n/a | `issueEvaluationLease` |
| same open evaluation | incomplete/no terminal results | n/a | `retrySameEvaluation` |
| same open evaluation | exact complete passing outputs, no assembly | absent | `assembleByteIdenticalObjects` |
| same evaluation and exact assembly | absent/pending, or expired before effect | absent | `waitForAdvanceAuthorization` |
| same assembly identity | authorization persistence unknown or not reopened | no target effect | `queryAdvanceAuthorization` |
| exact assembly plus exact fresh reopened authorization | bound objects known absent, import count 0 | absent | `importAuthorizedObjects` |
| same authorized assembly | target import outcome unknown | unknown | `queryHostObjects` |
| same authorized assembly/import receipt | exact Cw/Sw host-reopened | exact bound import/intent/protection values | `createIntent` |
| authorized import/intent/CAS effect failed with a known terminal outcome | any | any | `returnAdvanceHold` |
| missing/mismatched lease, output allowlist, assembly, authorization request/record, object-set/import-key/intent-key/protection projection, receipt, Cw/Sw topology, host object, same-assembly identity, or any target-host effect count greater than one | any | any | `quarantine` |

Only after the exact `objectsImported → createIntent` row does the post-intent table apply:

| Ref | Host audit | Intent | Advance authorization | Attestation | Decision |
|---|---|---|---|---|---|
| `prior` | `noCAS` | absent | exact fresh, intent count 0 | absent | `createIntent` |
| `prior` | `noCAS` | same open | exact fresh, CAS count 0 | absent | `retrySameIntent` |
| `prior` | `noCAS` | same open expired | no fresh replacement | absent | `waitForAdvanceAuthorization` |
| `prior` | `noCAS` | same open expired | exact fresh replacement bound to same assembly and predecessor intent | absent | `createSupersedingIntent` |
| `prior` | `unknown` | any | same operation, even if now expired | absent | `queryHostAudit` |
| `Sw` | same-intent success | same open | same consumed operation | absent | `finalizeByteIdenticalAttestation` |
| `Sw` | same-intent success | same open | same consumed operation | identical finalized | `returnExistingAttestation` |
| `Sw` | same-intent success | same open | same consumed operation | any next-wave request | `blockNextWave` |
| other | any | any | any | any | `quarantine` |
| `Sw` | different transaction | any | any | any | `quarantine` |
| `Sw` | same transaction | different lineage/assembly/authorization | any | any | `quarantine` |
| `Sw` | same transaction | same intent | any | mismatched attestation | `quarantine` |

Also test evaluation retry after runner loss, partial result upload, assembly
crash after Cw but before Sw, authorization-request crash/reopen, unknown
authorization persistence, import timeout followed by exact host reopen,
import receipt without authorization or objects, objects without the same
assembly/authorization digest, competing successor CAS loss, repeated
finalization, two superseders, changed repository/wave/prior/Sw/receipt/
verifier bytes, stale live-policy observation, and an audit timeout.

The focused admission-authorization classes contain:

```python
PAYLOAD_AUTHORIZATION_RECOVERY_TESTS = {
    "test_payload_pending_waits_without_host_effect",
    "test_payload_unknown_authorization_only_queries_service",
    "test_payload_import_requires_fresh_reopened_authorization",
    "test_payload_unknown_import_ref_intent_and_run_ref_only_query",
    "test_payload_reopen_precedes_each_later_effect",
    "test_payload_failure_consumes_authorization_and_terminates",
    "test_payload_receipt_digest_cannot_replace_new_authorization",
    "test_payload_digest_or_reopened_bool_without_typed_record_quarantines",
    "test_payload_every_effect_count_is_at_most_one",
}

ADVANCE_AUTHORIZATION_RECOVERY_TESTS = {
    "test_advance_request_precedes_authorization_and_target_import",
    "test_advance_pending_waits_and_unknown_only_queries",
    "test_advance_import_requires_exact_fresh_reopened_authorization",
    "test_advance_unknown_import_only_queries_host",
    "test_advance_reentry_preserves_same_assembly_and_binding_digests",
    "test_advance_intent_and_cas_require_bound_authorization",
    "test_advance_failure_consumes_authorization_and_terminates",
    "test_advance_digest_or_reopened_bool_without_typed_record_quarantines",
    "test_advance_crash_matrix_keeps_every_effect_at_most_one",
}
```

Crash immediately before and after each payload/advance authorization
request, authorization persistence/reopen, object import, host reopen,
proposal-ref create, dispatch-intent persist, run-ref create, import receipt,
intent, CAS, and attestation boundary. Mutation subtests independently change
each request/authorization digest, freshness/expiry/consumed bit, payload or
evidence object-set digest, proposal/import/intent key, live-protection
projection, assembly identity, ref, receipt, or effect count. Every changed
binding quarantines before a new effect. Separate fixtures set
`*_authorization_reopened = true` and supply plausible digests/expanded
fields while omitting the typed authorization, or supply a typed record with
an invalid signature/role/nonce/expiry; all quarantine. Same-operation
re-entry always returns the existing record or a query action.

Add this separate governance-validation recovery table. “Exact
authorization” means the signed record was reopened from the append-only
service and its dispatch intent is the same durable operation. It must be
unexpired before either new host effect. Once an authorized effect has
started, later expiry cannot authorize replay and cannot suppress the
query/reopen needed to resolve its outcome:

| Authorization | Target-host objects | Validation ref | Host job | Decision |
|---|---|---|---|---|
| absent/pending, or expired before any effect | absent | absent | absent | `waitForAuthorization` |
| persistence unknown or persisted but not reopened | no effect | absent | absent | `queryAuthorization` |
| exact fresh and reopened | known absent | absent | absent | `importExactObjects` |
| exact | import outcome unknown | absent | absent | `queryHostObjects` |
| exact | exact reopened | known absent | absent | `createValidationRef` |
| exact | exact reopened | create outcome unknown | absent | `queryHostRef` |
| exact | exact reopened | exact reopened | absent/queued/in-progress/unknown | `queryHostRun` |
| exact | exact reopened | exact reopened | exact success observation | `returnSuccessObservation` |
| exact | exact reopened | exact reopened | failed/cancelled/timed-out | `returnFailedHold` |
| invalid/mismatched/cross-intent replay, or any effect before authorization | any | any | any | `quarantine` |

The focused class has exactly these methods:

```python
GOVERNANCE_VALIDATION_RECOVERY_TESTS = {
    "test_authorization_waits_or_queries_before_target_host_import",
    "test_unknown_import_queries_objects_without_reimport",
    "test_unknown_ref_create_queries_ref_without_second_create",
    "test_unknown_run_queries_same_dispatch_without_second_ref",
    "test_exact_success_returns_one_observation_for_migration",
    "test_failed_run_consumes_authorization_and_preserves_hold",
    "test_governance_validation_mutation_matrix_quarantines",
}
```

The mutation matrix changes each closed authorization/observation field,
removes/adds/reorders/duplicates a preparation row, changes one row's
mode/blob, substitutes the commit/tree/object-set, workflow path/blob, job,
action pin, Python version, signed prefix/projection, validation ref, dispatch
intent, GitHub App, head/run attempt, operator, expiry, nonce, or signature,
and attempts authorization reuse, a second ref/run, implicit push, ref
update/delete, or canonical/development/runner/proposal-ref mutation. Every
case quarantines before a new host effect. A plausible authorization digest
or `authorization_reopened = true` without the actual typed signed record
also quarantines. The fake adapter counts object
imports, ref creates, and provider runs and requires each to remain at most
one across a crash after every durable boundary.

Add one schema identity regression:

```python
def test_bootstrap_attestation_uses_canonical_bootstrap_oid_names(self) -> None:
    schema = load_json(BOOTSTRAP_ATTESTATION_SCHEMA)
    self.assertIn("bootstrap_commit_oid", schema["required"])
    self.assertIn("bootstrap_tree_oid", schema["required"])
    self.assertNotIn("b0_commit_oid", schema["properties"])
    self.assertNotIn("b0_tree_oid", schema["properties"])
    self.assertEqual(set(schema["required"]), set(schema["properties"]))
    self.assertFalse(schema["additionalProperties"])
```

Add one exact graph-recovery class with:

```python
GRAPH_RECOVERY_TESTS = {
    "test_retry_reuses_same_nine_graph_bindings_and_pw",
    "test_retry_rejects_replacement_graph_module_contract_or_corpus",
    "test_retry_does_not_rerun_completed_physical_boundary",
    "test_recovery_cannot_create_graph_gate_twenty",
}
```

The passing retry reopens the identical Pw, predecessor-selected verifier,
nine module/contract/corpus/program bindings, result-bundle digest, and
ordered graph-case evidence. Any replacement or added gate quarantines.
When a completed physical projection is present, recovery reopens that exact
receipt and never invokes the device boundary again.

- [ ] **Step 2: Run focused RED tests**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_admission_recovery_oracle
```

Expected: the importable typed RED seam discovers every table method and
fails only with `qinao.admission-recovery.unimplemented`; import failure is not
RED.

- [ ] **Step 3: Implement the pure transition oracle**

```python
@dataclass(frozen=True)
class RecoveryObservation:
    canonical_ref_oid: str
    expected_prior_oid: str
    payload_dispatch_authorization: PayloadDispatchAuthorizationV1 | None
    payload_authorization_request_digest: str | None
    payload_dispatch_authorization_digest: str | None
    payload_authorization_status: Literal[
        "absent", "pending", "unknown", "reopened", "expired",
        "consumed", "failed", "invalid"
    ]
    payload_authorization_persisted: bool
    payload_authorization_reopened: bool
    payload_authorization_fresh: bool
    payload_authorization_consumed: bool
    payload_authorization_expires_at: str | None
    payload_bound_predecessor_chain_digest: str | None
    payload_bound_commit_oid: str | None
    payload_bound_tree_oid: str | None
    payload_bound_object_set_digest: str | None
    payload_bound_proposal_ref: str | None
    payload_bound_dispatch_intent_id: str | None
    payload_bound_run_ref: str | None
    payload_bound_active_verifier_digest: str | None
    payload_host_import_state: Literal[
        "absent", "unknown", "reopened", "failed", "mismatch"
    ]
    payload_proposal_ref_state: Literal[
        "absent", "unknown", "reopened", "failed", "mismatch"
    ]
    payload_dispatch_intent_state: Literal[
        "absent", "unknown", "reopened", "failed", "mismatch"
    ]
    payload_run_ref_state: Literal[
        "absent", "unknown", "reopened", "failed", "mismatch"
    ]
    payload_object_import_effect_count: int
    payload_proposal_ref_create_effect_count: int
    payload_dispatch_intent_effect_count: int
    payload_run_ref_create_effect_count: int
    payload_proposal: PayloadProposalReceiptV1 | None
    evaluation: EvaluationRecord | None
    gate_result_bundle: AuthenticatedGateResultBundle | None
    assembly: EvidenceAssemblyResult | None
    protected_ref_advance_authorization: (
        ProtectedRefAdvanceAuthorizationV1 | None
    )
    advance_authorization_request_digest: str | None
    protected_ref_advance_authorization_digest: str | None
    advance_authorization_status: Literal[
        "absent", "pending", "unknown", "reopened", "expired",
        "consumed", "failed", "invalid"
    ]
    advance_authorization_persisted: bool
    advance_authorization_reopened: bool
    advance_authorization_fresh: bool
    advance_authorization_consumed: bool
    advance_authorization_expires_at: str | None
    advance_bound_assembly_digest: str | None
    advance_bound_object_set_digest: str | None
    advance_bound_import_key: str | None
    advance_bound_intent_key: str | None
    advance_bound_protection_projection_digest: str | None
    advance_target_object_state: Literal[
        "absent", "unknown", "reopened", "failed", "mismatch"
    ]
    advance_target_object_import_effect_count: int
    admission_intent_create_effect_count: int
    protected_ref_cas_effect_count: int
    attestation_finalize_effect_count: int
    object_import_receipt: GitObjectImportReceipt | None
    host_object_observation: HostObjectObservation | None
    proposed_seal_oid: str | None
    intent: IntentRecord | None
    host_audit: HostAudit | None
    attestation: AttestationRecord | None
    attestation_draft: AttestationDraft | None
    decision_time: str
    intent_expires_at: str | None
    policy_observed_at: str | None
    policy_valid_until: str | None
    next_wave_requested: bool

@dataclass(frozen=True)
class RecoveryDecision:
    state: AdmissionState
    action: RecoveryAction
    intent_id: str | None
    predecessor_intent_id: str | None
    diagnostic_id: str

@dataclass(frozen=True)
class GovernanceValidationRecoveryObservation:
    authorization: GovernanceValidationAuthorizationV1 | None
    authorization_request_digest: str | None
    authorization_digest: str | None
    authorization_status: Literal[
        "absent", "pending", "unknown", "reopened", "expired",
        "consumed", "failed", "invalid"
    ]
    authorization_persisted: bool
    authorization_reopened: bool
    authorization_fresh: bool
    authorization_consumed: bool
    authorization_expires_at: str | None
    operation_dispatch_intent_id: str | None
    decision_time: str
    target_object_state: Literal["absent", "unknown", "reopened", "mismatch"]
    target_object_set_digest: str | None
    validation_ref_state: Literal["absent", "unknown", "reopened", "mismatch"]
    validation_ref_oid: str | None
    host_run_state: Literal[
        "absent", "queued", "inProgress", "unknown", "succeeded",
        "failed", "cancelled", "timedOut", "mismatch"
    ]
    run_observation: GovernanceValidationRunObservationV1 | None
    object_import_effect_count: int
    validation_ref_create_effect_count: int
    provider_run_effect_count: int

@dataclass(frozen=True)
class GovernanceValidationRecoveryDecision:
    state: GovernanceValidationState
    action: GovernanceValidationAction
    dispatch_intent_id: str | None
    validation_ref: str | None
    run_observation_digest: str | None
    diagnostic_id: str

```

Implement exactly
`decide_recovery(observation: RecoveryObservation) -> RecoveryDecision` as a
total, side-effect-free function over the closed enums and fields above. It
first validates that every Boolean/status combination is consistent, every
effect count is a non-Boolean integer in `0...1`, and every reopened record
byte-matches its request, authorization, predecessor, payload/assembly, and
host observation. It never trusts an authorization digest, status, or Boolean
alone: a create/import/CAS action requires the corresponding frozen typed
`PayloadDispatchAuthorizationV1` or
`ProtectedRefAdvanceAuthorizationV1` imported from the Task-1 protocol
module. The oracle re-verifies its closed fields, signature, operator role,
nonce uniqueness, and expiry, derives the authorization digest and all
expanded binding projections from that typed record, and requires exact
equality with the durable reopen observation. A digest-only, Boolean-only, or
locally redeclared lookalike is `QUARANTINE`.

For payload dispatch, absent/pending/expired-before-effect returns
`WAIT_FOR_PAYLOAD_AUTHORIZATION`; an unknown persistence outcome or a
persisted-but-not-reopened record returns `QUERY_PAYLOAD_AUTHORIZATION`.
Only a fresh reopened `PayloadDispatchAuthorizationV1` with zero corresponding
effect count can select payload import, proposal-ref create, dispatch-intent
persist, or run-ref create, in that order. Each later action requires an exact
durable reopen of the prior effect: target-host reopen for imported objects
and the proposal ref, then append-only-service reopen for the dispatch intent,
before run-ref creation. An unknown effect selects only its matching query.
Failure marks the authorization consumed and returns
`RETURN_PAYLOAD_HOLD`; consumed authorization plus the exact completed chain
may return the existing proposal/dispatch, but can never create another
effect. A receipt or receipt digest without the current authorization is
`QUARANTINE`.

For protected advance, deterministic non-host assembly first freezes
`advance_authorization_request_digest` from the same assembly identity,
object-set digest, import key, intent key, and live-protection projection.
Absent/pending/expired-before-effect returns
`WAIT_FOR_ADVANCE_AUTHORIZATION`; unknown or not-yet-reopened persistence
returns `QUERY_ADVANCE_AUTHORIZATION`. Only the exact fresh reopened
`ProtectedRefAdvanceAuthorizationV1` with zero target-import effect count can
select `IMPORT_AUTHORIZED_OBJECTS`; unknown import selects only
`QUERY_HOST_OBJECTS`. Intent and CAS actions require the same authorization,
host-reopened objects, immutable import receipt, and exact bound keys/
projection. A known failed effect consumes the authorization and returns
`RETURN_ADVANCE_HOLD`. Expiry after a possibly completed effect never permits
replay; it permits only query/reopen. Any re-entry with a different assembly,
request, authorization, object set, import key, intent key, protection
projection, or an effect count above one is `QUARANTINE`.

Implement
`decide_governance_validation_recovery(observation:
GovernanceValidationRecoveryObservation) ->
GovernanceValidationRecoveryDecision` as a second total, side-effect-free
function over the table above. It validates every authorization binding and
requires the actual typed authorization to derive
`authorization_request_digest`, `authorization_digest`, expiry, and the
signed dispatch intent before choosing a host action. Absent/pending or
expired-before-effect selects `waitForAuthorization`; unknown persistence or
a persisted-but-not-reopened record selects only `queryAuthorization`.
`operation_dispatch_intent_id` must equal the signed intent.
`importExactObjects` is legal only for authenticated known-absent objects, an
unexpired reopened authorization, and zero prior import effect;
`createValidationRef` is legal only after exact host reopen, while the
authorization remains unexpired, and with zero prior ref/run effect.
Expiration after either effect begins still permits only its matching query
action. Every unknown state chooses its query action. No decision
reissues an import, creates a second ref, requests a second run, updates or
deletes a ref, or touches the canonical/development/runner/proposal refs.
Success returns only the digest of the exact reopened
`GovernanceValidationRunObservationV1`; failure returns the persistent hold
and requires a fresh authorization for any later attempt.

Freeze these supporting records in the same module; no caller supplies them:

```python
@dataclass(frozen=True)
class EvaluationRecord:
    lease_digest: str
    result_bundle_digest: str | None
    state: Literal["open", "complete", "failed", "expired"]
    opened_at: str
    expires_at: str

@dataclass(frozen=True)
class GitObjectImportReceipt:
    repository_id: str
    assembly_digest: str
    object_pack_digest: str
    imported_object_oids: tuple[str, ...]
    host_transaction_id: str
    host_reopen_observation_digest: str
    issued_at: str
    signature: str

@dataclass(frozen=True)
class HostObjectObservation:
    repository_id: str
    observed_object_oids: tuple[str, ...]
    topology_digest: str
    observed_at: str

@dataclass(frozen=True)
class IntentRecord:
    intent_id: str
    idempotency_key: str
    repository_id: str
    canonical_ref: str
    derived_wave: str
    prior_oid: str
    seal_oid: str
    receipt_blob_digest: str
    active_verifier_digest: str
    source_import_review_audit_root_digest: str
    live_policy_observation_digest: str
    policy_observed_at: str
    policy_valid_until: str
    predecessor_intent_id: str | None
    attestation_id: str
    attestation_created_at: str
    attestation_signing_policy_digest: str
    status: str
    created_at: str
    expires_at: str

@dataclass(frozen=True)
class HostAudit:
    canonical_ref: str
    prior_oid: str
    observed_oid: str
    transaction_id: str | None
    transaction_result: Literal["noCAS", "success", "lost", "unknown"]
    intent_id: str | None
    observed_at: str

@dataclass(frozen=True)
class AttestationDraft:
    attestation_id: str
    intent_id: str
    created_at: str
    signing_policy_digest: str
    unsigned_field_digest: str

@dataclass(frozen=True)
class AttestationRecord:
    attestation_id: str
    intent_id: str
    unsigned_field_digest: str
    cas_transaction_id: str
    signature: str
```

`assembleByteIdenticalObjects` is legal only for one complete passing
result/evidence exact set under the signed output contract. Its Cw/Sw
identity, receipt bytes, and timestamps come only from the immutable
evaluation record. It produces the immutable advance-authorization request
but no target-host effect. `createIntent` is legal only after the same
assembled Cw/Sw have a fresh reopened
`ProtectedRefAdvanceAuthorizationV1`, an immutable same-authorization
object-import receipt, a host-side reopen observation, and a policy
observation satisfying
`policy_observed_at <= decision_time < policy_valid_until` and
`decision_time < intent_expires_at`. It freezes the attestation ID,
attestation creation time, signing policy, and unsigned-field digest before
CAS. `createSupersedingIntent` is legal only after authenticated `noCAS`, only
when `decision_time >= intent_expires_at` or the policy observation is
expired, and only after a fresh reopened replacement
`ProtectedRefAdvanceAuthorizationV1` binds the identical repository/wave/
prior/assembly/object-set/import-key/protection bytes plus the superseding
intent key and predecessor intent. It names the old intent as
`predecessorIntentID` and never mutates it. The prior authorization or object
import receipt cannot authorize that new intent. After same-intent CAS
success, deterministic signing over the frozen draft plus the audited CAS
transaction makes retries byte-identical.
`pendingAdmission` never activates the next verifier/module or permits another
wave.

`retrySameEvaluation` and every later recovery action preserve the exact nine
graph bindings and the same Pw; graph binding substitution, case-set drift,
gate 20, matrix cell 153, or a second physical execution for an already
completed request returns `QUARANTINE`. Recovery may resume missing logical
steps only from the immutable result/assembly record; it cannot select a
replacement module or rerun an external effect.

- [ ] **Step 4: Close all six schemas**

Every schema uses `additionalProperties: false`, exact required fields, lowercase digests/OIDs, sorted unique arrays, and explicit state enums. The intent schema freezes:

In `qinao-admission-service-state-v1.schema.json`, the existing closed
`PayloadDispatchAuthorizationV1` and
`ProtectedRefAdvanceAuthorizationV1` definitions use the exact field sets
from the protocol section and have
`additionalProperties: false` plus `required == properties.keys()`. The root
adds immutable payload-authorization-request, payload authorization,
payload-object-import, proposal-ref, proposal receipt, dispatch-intent,
run-ref, advance-authorization-request, advance authorization, Cw/Sw import,
intent, CAS, and attestation record digests/states/effect counts. Every
authorization-request → authorization → effect record names the same
operation identity; absent, pending, unknown, reopened, expired, consumed,
failed, and invalid are distinct closed states. Each effect count is exactly
zero or one and JSON Boolean is rejected as integer.

The payload transition is exactly:

```text
payloadAuthorizationRequired -> payloadAuthorized
payloadAuthorized -> payloadObjectImportUnknown | payloadObjectsReopened
payloadObjectImportUnknown -> payloadObjectsReopened | payloadFailedHold | quarantined
payloadObjectsReopened -> payloadProposalRefCreateUnknown | payloadProposalReopened
payloadProposalRefCreateUnknown -> payloadProposalReopened | payloadFailedHold | quarantined
payloadProposalReopened -> payloadDispatchIntentCreateUnknown | payloadDispatchIntentReopened
payloadDispatchIntentCreateUnknown -> payloadDispatchIntentReopened | payloadFailedHold | quarantined
payloadDispatchIntentReopened -> payloadRunRefCreateUnknown | payloadPinned
payloadRunRefCreateUnknown -> payloadPinned | payloadFailedHold | quarantined
payloadPinned -> evaluationOpen
```

After `assemblyReady`, the protected-advance transition is exactly:

```text
assemblyReady -> advanceAuthorizationRequired
advanceAuthorizationRequired -> advanceAuthorized
advanceAuthorized -> objectImportUnknown | objectsImported
objectImportUnknown -> objectsImported | advanceFailedHold | quarantined
objectsImported -> intentOpen
intentOpen -> casOutcomeUnknown | pendingAdmission | advanceFailedHold | superseded
casOutcomeUnknown -> pendingAdmission | advanceFailedHold | quarantined
pendingAdmission -> finalized | advanceFailedHold | quarantined
finalized -> immutable finalized
```

Missing/pending authorization produces a wait action without changing state;
unknown authorization/import/ref/dispatch/CAS outcomes produce only their
query action. No transition skips host reopen, goes backward to reissue an
effect, or substitutes a proposal/import receipt for a fresh authorization.

In `qinao-admission-service-state-v1.schema.json`, add closed `$defs` for
`GovernancePreparationPathRow`,
`GovernanceValidationAuthorizationV1`, and
`GovernanceValidationRunObservationV1` with field sets exactly matching Task
1; each definition has `additionalProperties: false` and
`required == properties.keys()`. The authorization definition fixes the seven
literal paths, mode `100644`, exact row cardinality, UTF-8 byte order and
uniqueness, workflow/job/action/Python literals, signed
`refs/heads/qinao-admission-runs/` prefix, validation-ref subprefix,
lowercase full OIDs/digests, positive non-Boolean times/counts where
applicable, and a domain-separated signature over the canonical object with
only `signature` omitted. The run-observation
definition fixes `conclusion = success`, positive non-Boolean GitHub App and
run-attempt values, and byte equality to the authorization through its
domain-separated digest.

The service-state root retains the immutable governance-authorization request
digest, authorization persistence/reopen/freshness/consumption status, the
actual typed authorization and its derived digest, plus append-only
identities/digests for exactly one target-host object-import observation,
dispatch intent, create-once validation-ref observation, provider-run
observation, and resulting required-check migration per operation. Absent is
distinct from empty. Each later record names the prior record and the same
dispatch intent; no field can encode a generic push, ref update/delete,
canonical/default/runner/proposal-ref mutation, or a second use of one
authorization.

The exact governance-validation state transitions are:

```text
authorizationRequired -> authorizationPersistenceUnknown | authorized
authorizationPersistenceUnknown -> authorized | quarantined
authorized -> objectImportUnknown | objectsReopened
objectImportUnknown -> objectsReopened | quarantined
objectsReopened -> refCreateUnknown | refReopened
refCreateUnknown -> refReopened | quarantined
refReopened -> runOutcomeUnknown | runSucceeded | runFailedHold
runOutcomeUnknown -> runSucceeded | runFailedHold | quarantined
runSucceeded -> immutable success observation
runFailedHold -> immutable failed hold
```

No transition goes backward or produces a second target-host effect.

```text
intent_id
idempotency_key
repository_id
canonical_ref
derived_wave
prior_oid
seal_oid
receipt_blob_digest
active_verifier_digest
source_import_review_audit_root_digest
live_policy_observation_digest
policy_observed_at
policy_valid_until
predecessor_intent_id
attestation_id
attestation_created_at
attestation_signing_policy_digest
status
created_at
expires_at
```

The finalized attestation freezes:

```text
attestation_id
intent_id
repository_id
canonical_ref
derived_wave
oidc_issuer
oidc_subject
workflow_identity
workflow_sha
runner_bundle_digest
active_verifier_digest
live_policy_digest
prior_oid
new_oid
receipt_blob_digest
source_import_review_audit_root_digest
cas_transaction_id
cas_result
created_at
signature
```

The bootstrap-root attestation is a separate closed object with exactly:

```text
schema_version
attestation_id
repository_id
canonical_ref
runner_ref
approved_base_oid
bootstrap_commit_oid
bootstrap_tree_oid
bootstrap_paths_digest
wave_admission_projection_sha256
bootstrap_bundle_manifest_sha256
operator_approvals_sha256
service_binding_digest
source_import_review_audit_root_digest
protection_policy_observation_digest
canonical_ref_observation_digest
runner_ref_observation_digest
created_at
signing_identity_digest
signature_algorithm
signature
```

Its domain-separated signature covers every field except `signature`.
`wave_admission_projection_sha256` authenticates the already canonical
projection. The projection contains only `bootstrap_attestation_policy` and
must not contain this attestation's digest, identifier, signature, status, or
transparency entry. The bootstrap attestation itself likewise contains no
entry ID: the append operation happens after signing. The separately signed
export envelope is the exact eight-field `BootstrapExportV1` frozen in Output
B; in particular it uses `bootstrap_attestation_sha256`, carries the
projection/bundle/approvals digests and envelope signature, and rejects the
short alias `attestation_sha256`. The verifier reopens the bound inclusion.
The bootstrap bundle manifest excludes the attestation and export envelope,
so no object participates in a digest cycle.

The service-state schema freezes append-only identities/digests for bootstrap
object import/intent, payload and advance authorization requests/records,
payload proposal, evaluation dispatch/run ref,
evaluation lease/result bundle, external physical request/private-custody
receipt/privacy-clean projection, assembly record, object-import receipt,
intent/supersession, CAS audit, final attestation, governance validation, and
required-check migration. A later phase references the exact prior record; it
never overwrites it. No schema permits a caller-selected
wave/ref/profile/verifier field or raw secret.

- [ ] **Step 5: Run conformance and JSON checks**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_admission_recovery_oracle \
  scripts.test_qinao_admission_protocol_v1 \
  scripts.test_qinao_protected_admission_runner
for schema in \
  docs/superpowers/specs/qinao-admission-evaluation-lease-v1.schema.json \
  docs/superpowers/specs/qinao-admission-intent-v1.schema.json \
  docs/superpowers/specs/qinao-admission-attestation-v1.schema.json \
  docs/superpowers/specs/qinao-bootstrap-attestation-v1.schema.json \
  docs/superpowers/specs/qinao-bootstrap-intent-v1.schema.json \
  docs/superpowers/specs/qinao-admission-service-state-v1.schema.json
do
  python3 -m json.tool "$schema" >/dev/null || exit 1
done
```

Expected: all tests and schema parses pass.

- [ ] **Step 6: Commit the external-service contract**

```bash
set -euo pipefail
git add docs/superpowers/specs/qinao-admission-evaluation-lease-v1.schema.json \
  docs/superpowers/specs/qinao-admission-intent-v1.schema.json \
  docs/superpowers/specs/qinao-admission-attestation-v1.schema.json \
  docs/superpowers/specs/qinao-bootstrap-attestation-v1.schema.json \
  docs/superpowers/specs/qinao-bootstrap-intent-v1.schema.json \
  docs/superpowers/specs/qinao-admission-service-state-v1.schema.json \
  scripts/qinao_admission_recovery_oracle.py \
  scripts/test_qinao_admission_recovery_oracle.py
git commit -m "feat(qinao): freeze admission recovery protocol"
```

Expected: exactly eight staged paths.

---

### Task 7: Build a Deterministic Minimal `B0` Proposal

**Files:**
- Create: `scripts/qinao_gate_modules/bootstrap-paths-v1.json`
- Create: `scripts/build_qinao_bootstrap_lineage.py`
- Create: `scripts/test_build_qinao_bootstrap_lineage.py`

**Interfaces:**
- Consumes: approved base OID, finalized bootstrap-source tree OID, exact bootstrap-path manifest, deterministic commit identity.
- Produces: unreachable proposal objects plus canonical proposal JSON; moves no ref and touches no index/worktree.

- [ ] **Step 1: Write RED minimality and no-ref-mutation tests**

Create an importable lineage-builder seam with the final dataclasses and
callable signatures before the tests. Every operation raises
`LineageError("qinao.bootstrap-lineage.unimplemented")`; named methods must be
discovered. Import failure is not RED.

Tests use disposable repositories and assert:

```python
def test_b0_has_approved_base_as_sole_parent_and_exact_diff(self) -> None:
    proposal = build_b0_proposal(fixture.inputs)
    self.assertEqual(
        fixture.parents(proposal.bootstrap_commit_oid),
        [APPROVED_BASE],
    )
    self.assertEqual(
        fixture.diff_paths(APPROVED_BASE, proposal.bootstrap_commit_oid),
        fixture.bootstrap_paths(),
    )

def test_proposal_changes_no_ref_index_or_worktree(self) -> None:
    before = fixture.snapshot_repository_state()
    build_b0_proposal(fixture.inputs)
    after = fixture.snapshot_repository_state()
    self.assertEqual(before.refs, after.refs)
    self.assertEqual(before.index_digest, after.index_digest)
    self.assertEqual(before.worktree_digest, after.worktree_digest)
```

Add one exact graph-minimality class with:

```python
GRAPH_B0_MINIMALITY_TESTS = {
    "test_b0_runtime_contains_production_graph_reachability_primitive",
    "test_b0_production_reachability_module_is_two_symbol_thin_wrapper",
    "test_b0_contains_all_nine_amended_gate_bundles",
    "test_b0_graph_amendment_keeps_nineteen_gates_and_152_cells",
}
```

The tests inspect exact B0 blobs, not source-worktree paths. They require the
primitive only in `runtime.py`, require every one of the 19 wrappers
(explicitly including `production_reachability.py`) to expose only
`GATE_ID/evaluate`, recompute all nine bundle/corpus/program digests, and
reject gate 20/cell 153.

Reject extra/missing path, path mode mismatch, symlink/special file, source-tree drift, merge base, wrong parent, test/plan/authority/evidence path in manifest, a concrete provider/profile instance in B0 runtime data, catalog digest mismatch, nondeterministic author/time, and a pre-existing protected ref with the wrong OID.

- [ ] **Step 2: Run focused RED tests**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_build_qinao_bootstrap_lineage
```

Expected: named tests fail only on
`qinao.bootstrap-lineage.unimplemented`.

- [ ] **Step 3: Implement temporary-index tree construction**

```python
@dataclass(frozen=True)
class B0Proposal:
    approved_base_oid: str
    source_tree_oid: str
    bootstrap_paths_digest: str
    bootstrap_tree_oid: str
    bootstrap_commit_oid: str
    parent_oids: tuple[str, ...]
    diff_paths: tuple[str, ...]
    path_blobs: tuple[PathBlob, ...]
    commit_identity: CommitIdentity

```

`PathBlob` is frozen here, not left to implementation inference:

```python
@dataclass(frozen=True)
class PathBlob:
    path: str
    mode: Literal["100644", "100755"]
    blob_oid: str
    blob_sha256: str
    size_bytes: int
```

Implement exactly these two call signatures:

```text
build_bootstrap_tree(*, git_dir: Path, approved_base_oid: str, source_tree_oid: str, bootstrap_paths: tuple of str) -> str
create_single_parent_commit(*, git_dir: Path, tree_oid: str, parent_oid: str, identity: CommitIdentity) -> str
```

Use a private `GIT_INDEX_FILE` under `tempfile.TemporaryDirectory`, `git read-tree "$APPROVED_BASE_OID"`, `git update-index --cacheinfo` for each verified source-tree blob, `git write-tree`, and `git commit-tree`. `APPROVED_BASE_OID` is the fixed approved base after full-OID validation. Never run `git add`, `checkout`, `switch`, `reset`, or `update-ref` in proposal mode.

The B0 identity is literal and code-owned:

```python
B0_COMMIT_IDENTITY = CommitIdentity(
    author_name="Qinao Bootstrap Ceremony",
    author_email="qinao-bootstrap@example.invalid",
    authored_at="2026-07-23T00:00:00+00:00",
    committer_name="Qinao Bootstrap Ceremony",
    committer_email="qinao-bootstrap@example.invalid",
    committed_at="2026-07-23T00:00:00+00:00",
    message="qinao: bootstrap verifier v0",
)
```

The production CLI has no identity/time option. Tests rebuild twice under
different locale, wall clock, Git config, and timezone and require identical
tree/commit OIDs.

- [ ] **Step 4: Implement exact minimality verification**

Create `scripts/qinao_gate_modules/bootstrap-paths-v1.json` with the closed
shape `{"schema_version":1,"paths":[...]}`. `paths` is a strictly sorted,
duplicate-free array of literal repository-relative regular-file paths. Its
contents are the exact expansion of:

```text
.github/workflows/qinao-wave-admission.yml
scripts/check_qinao_wave_admission.py
scripts/qinao_admission_protocol_v1.py
scripts/qinao_wave_verifier_v0.py
scripts/qinao_protected_admission_runner.py
scripts/qinao_external_physical_gate_v0.py
scripts/qinao_gate_modules/bootstrap-paths-v1.json
scripts/qinao_gate_modules/v0/catalog-v1.json
scripts/qinao_gate_modules/v0/program-spec-v1.json
scripts/qinao_gate_modules/v0/service-binding-v1.json
scripts/qinao_gate_modules/v0/runtime.py
all 19 literal contract paths enumerated in the File Responsibility Map
all 19 literal module paths enumerated in the File Responsibility Map
all 19 literal corpus paths enumerated in the File Responsibility Map
the exact sorted helper paths already frozen in catalog-v1.json
docs/superpowers/specs/qinao-admission-service-binding-v1.schema.json
docs/superpowers/specs/qinao-gate-program-spec-v1.schema.json
docs/superpowers/specs/qinao-gate-catalog-v1.schema.json
docs/superpowers/specs/qinao-gate-contract-v1.schema.json
docs/superpowers/specs/qinao-gate-corpus-v1.schema.json
docs/superpowers/specs/qinao-admission-evaluation-lease-v1.schema.json
docs/superpowers/specs/qinao-admission-intent-v1.schema.json
docs/superpowers/specs/qinao-admission-attestation-v1.schema.json
docs/superpowers/specs/qinao-bootstrap-attestation-v1.schema.json
docs/superpowers/specs/qinao-bootstrap-intent-v1.schema.json
docs/superpowers/specs/qinao-admission-service-state-v1.schema.json
docs/superpowers/specs/qinao-wave-admission-bootstrap-v1.schema.json
docs/superpowers/specs/qinao-wave-admission-receipt-v1.schema.json
docs/superpowers/specs/qinao-payload-proposal-receipt-v1.schema.json
docs/superpowers/specs/qinao-evaluation-dispatch-intent-v1.schema.json
docs/superpowers/specs/qinao-external-physical-gate-binding-v1.schema.json
docs/superpowers/specs/qinao-physical-evidence-request-v1.schema.json
docs/superpowers/specs/qinao-physical-evidence-projection-receipt-v1.schema.json
docs/superpowers/specs/qinao-evidence-assembly-v1.schema.json
docs/superpowers/specs/qinao-git-object-import-receipt-v1.schema.json
docs/superpowers/specs/qinao-bootstrap-object-import-receipt-v1.schema.json
```

After literal expansion, the non-helper set above has exactly 89 unique paths,
including exactly 21 closed machine-schema paths and exactly 57 generated
contract/module/corpus paths. The test owns an 89-string
`EXPECTED_NON_HELPER_B0_PATHS` constant. The final manifest set is exactly:

```text
EXPECTED_NON_HELPER_B0_PATHS
union
catalog.bootstrap_helper_paths
```

and its cardinality is
`89 + count(helper paths not already in EXPECTED_NON_HELPER_B0_PATHS)`.
The builder and tests compute that set union and compare literal strings; they
do not accept a directory, glob, count-only match, or a catalog-provided
replacement for one of the 89 fixed paths.

The JSON file contains only the two fields above and the literal expanded
paths, never glob syntax, directory entries, or the explanatory `all 19`
lines. The builder derives the 57 contract/module/corpus paths from the
catalog's exact 19 stems and byte-compares that derived set with the 57 literal
manifest entries; it does not generate or repair the manifest. It similarly
byte-compares the literal helper subset with
`catalog.bootstrap_helper_paths`. It also proves the program source and four
gate schemas are literal manifest members, their bytes match the catalog
digests, and all 57 generated-artifact rows are manifest members. It excludes
every `test_*.py` **except** a test that is itself a literal
digest/mode-locked `catalog.bootstrap_helper_paths` member. Thus only the
exact helper tests required by an active B0 program enter; directory-wide
test discovery cannot enlarge B0. It also excludes
`scripts/build_qinao_gate_catalog_v0.py`, plan/spec prose other than the
listed machine schemas,
`docs/superpowers/specs/qinao-import-review-v1.schema.json`,
`scripts/qinao_import_review_v1.py`, authority draft, Owner Ledger,
candidate evidence, ceremony/lineage tool, receipt, and signed external
export. The included B0 copy of `scripts/check_qinao_wave_admission.py` remains
structural/offline-only; its presence follows the approved design's
minimal-path requirement and does not make it an authoritative runner.

Verify:

```text
parents(B0) = [59c26f508262d7c25869faac0ec0abf968ec1e02]
diffPaths(approvedBase,B0) = bootstrap-paths-v1.json
all B0 paths are regular 100644 or reviewed executable 100755
catalog has 19 rows
all eight required-wave sets have exact cardinality
program source has exactly 152 cells, 136 active cells, 16 inactive cells,
and 42 reachable program rows
program source/catalog/program-graph digests and all 57 generated-artifact
rows reopen from B0
all module/contract/corpus/helper digests reopen from B0
runtime.py contains the sole production_graph_reachability implementation
all 19 module files, including production_reachability.py, are strict
two-symbol GATE_ID/evaluate wrappers
all nine graph-mapped rows and their nested graph-case digests reopen from B0
with totals still 19 gates, 42 programs, 126 outer cases, 110 nested graph
executions, and 152 cells
no concrete model-Provider instance or product release-profile value exists in
the exact bootstrap diff/active bundle closure; the credential-free admission
service public binding is the sole service-instance exception and is checked
against its closed schema; inherited approved-base bytes are outside this
negative scan and cannot become active bootstrap data
authority draft and external export paths are absent from B0
```

The builder writes proposal JSON only to an explicit output path and refuses a path under the repository root.
For the one production proposal path, it also owns the complete parent
contract. `/private/tmp/qinao-bootstrap-ceremony-v1` is opened/created with
`O_DIRECTORY|O_NOFOLLOW`, owner equal to the current effective UID, and mode
exactly `0700`; an existing symlink, foreign owner, broader mode, or
non-directory fails. The final proposal name is never an `O_CREAT`, rename,
truncate, or replace target. The builder derives the deterministic
same-operation basename `.qinao-install-<64-lowercase-hex>.tmp` with
domain-separated SHA-256 over final basename, canonical proposal SHA-256, and
fixed intent `b0-proposal`; any temp outside that closed regex is invalid. It
creates that same-directory temporary with
`openat(O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW, 0600)`, `fchmod`s its open
descriptor to exact `0600`, writes and byte-count checks the complete
canonical JSON, file-`fsync`s, then installs the final name only with
same-directory `linkat(..., flags=0)`. It directory-`fsync`s the new link,
unlinks only the verified same-operation temp, and directory-`fsync`s again.

An existing-final error or lost reply reopens the final with `O_NOFOLLOW` and
requires effective-UID ownership, regular type, exact mode `0600`, canonical
byte identity, and link count one. A crash after `linkat` but before temp
unlink may be recovered only when the operation-specific temp exists and
provably names the same inode; remove that temp, directory-`fsync`, and then
require final link count one. Exact byte-identical final is the sole retry
success; a stale temp for another final/value/intent fails and remains
byte-for-byte present. A divergent or suspicious final/temp is never
unlinked, truncated, renamed over, or overwritten. Disposable tests cover
absent parent, safe
creation under restrictive umask, parent/leaf symlink, foreign-owner fixture
where supported, broad mode, crash before/after temp `fsync`, `linkat`, each
directory `fsync`, and temp unlink, byte-identical-final lost reply,
same-inode temp cleanup, unexpected hard link, divergent-final survival, and
stale-other-intent-temp failure without deletion.

- [ ] **Step 5: Run tests and commit the builder**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_build_qinao_bootstrap_lineage \
  scripts.test_qinao_gate_catalog_v0 \
  scripts.test_qinao_wave_verifier_v0
python3 scripts/build_qinao_gate_catalog_v0.py \
  --verify-projection scripts/qinao_gate_modules/v0/program-spec-v1.json
git add scripts/build_qinao_bootstrap_lineage.py \
  scripts/test_build_qinao_bootstrap_lineage.py \
  scripts/qinao_gate_modules/bootstrap-paths-v1.json
git commit -m "feat(qinao): build deterministic minimal bootstrap commit"
```

Expected: all tests pass; exactly three files committed.

- [ ] **Step 6: Generate and inspect the real proposal without moving refs**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py \
  --root . \
  --expect-candidate-lineage prebootstrapPreparation \
  --require-clean
python3 scripts/build_qinao_bootstrap_lineage.py \
  --proposal-only \
  --git-dir "$(git rev-parse --absolute-git-dir)" \
  --approved-base 59c26f508262d7c25869faac0ec0abf968ec1e02 \
  --source-tree "$(git rev-parse HEAD^{tree})" \
  --bootstrap-paths scripts/qinao_gate_modules/bootstrap-paths-v1.json \
  --output /private/tmp/qinao-bootstrap-ceremony-v1/b0-proposal-v1.json
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-proposal /private/tmp/qinao-bootstrap-ceremony-v1/b0-proposal-v1.json
```

Expected:
`verified B0 proposal: parent_count=1 catalog=19 matrix=152 programs=42 refs_changed=0`;
current branch, index, worktree, and all refs remain byte-identical.

---

### Task 7A: Freeze Authority-Finalization Verification and Atomic Reparenting Before Hold C

**Files:**
- Modify: `scripts/build_qinao_bootstrap_lineage.py`
- Modify: `scripts/test_build_qinao_bootstrap_lineage.py`
- Consume without modifying: `scripts/qinao_execution_root.py`

**Interfaces:**
- Consumes during tests: disposable B0/preparation/finalization fixtures.
- Produces before the external ceremony: the final
  `verify-authority-finalization`, reparent builder, exact-state inspector, and
  atomic ref-transaction implementation. No real ref moves in this task.

This task must be committed before Task 8 and before the authority plan freezes
its final preparation tree. After Hold C, no source commit is permitted.

- [ ] **Step 1: Add RED finalization/reparent/transaction tests**

Tests require:

```python
def test_payload_reparent_preserves_tree_and_uses_only_b0_parent(self) -> None:
    pw = build_reparented_payload(
        git_dir=fixture.git_dir,
        preparation_tip_oid=fixture.preparation_tip,
        bootstrap_oid=fixture.b0,
    )
    self.assertEqual(fixture.tree(pw), fixture.tree(fixture.preparation_tip))
    self.assertEqual(fixture.parents(pw), [fixture.b0])

def test_ref_transaction_is_create_once_and_all_or_nothing(self) -> None:
    plan = fixture.unapplied_plan()
    fixture.make_candidate_ref_stale()
    with self.assertRaisesRegex(LineageError, "stale candidate ref"):
        apply_lineage_transaction(
            git_dir=fixture.git_dir,
            plan=plan,
            root_contract=fixture.root_contract,
            authority_finalization_path=fixture.authority_finalization_path,
            signed_projection_path=fixture.signed_projection_path,
            governance_migration_path=fixture.governance_migration_path,
            b0_proposal_path=fixture.b0_proposal_path,
        )
    self.assertFalse(fixture.ref_exists(ORIGINAL_FORENSIC_REF))
    self.assertFalse(fixture.ref_exists(plan.preparation_forensic_ref))

def test_exact_already_applied_state_is_idempotently_recognized(self) -> None:
    plan = fixture.applied_plan()
    self.assertEqual(
        inspect_lineage_state(git_dir=fixture.git_dir, plan=plan),
        LineageDisposition.ALREADY_APPLIED,
    )

def test_partial_or_divergent_state_is_quarantined(self) -> None:
    plan = fixture.unapplied_plan()
    fixture.create_ref(plan.original_forensic_ref, plan.original_tip_oid)
    with self.assertRaisesRegex(LineageQuarantine, "partial lineage state"):
        apply_lineage_transaction(
            git_dir=fixture.git_dir,
            plan=plan,
            root_contract=fixture.root_contract,
            authority_finalization_path=fixture.authority_finalization_path,
            signed_projection_path=fixture.signed_projection_path,
            governance_migration_path=fixture.governance_migration_path,
            b0_proposal_path=fixture.b0_proposal_path,
        )
```

Also cover finalization tree/digest/projection mismatch; either forensic ref
already present; either forensic ref symbolic; wrong candidate branch/ref;
candidate, preparation, B0, or signed-projection drift; merge-parent Pw;
protected canonical/runner/run/proposal ref in the transaction; non-descendant
preparation; exact already-applied retry; and a second retry with any changed
byte. Named methods fail on the typed RED seam, not import failure.

- [ ] **Step 2: Freeze the exact types, identity, and operations**

```python
@dataclass(frozen=True)
class RefTransactionPlan:
    candidate_ref: str
    expected_old_tip: str
    new_payload_oid: str
    original_forensic_ref: str
    original_tip_oid: str
    preparation_forensic_ref: str
    preparation_tip_oid: str
    bootstrap_oid: str
    preparation_tree_oid: str
    payload_commit_identity: CommitIdentity
    authority_finalization_sha256: str
    signed_projection_sha256: str
    b0_proposal_sha256: str
    governance_required_checks_migration_sha256: str
    expected_wave_admission_projection_sha256: str

class LineageDisposition(Enum):
    READY_TO_APPLY = "readyToApply"
    ALREADY_APPLIED = "alreadyApplied"
    QUARANTINED = "quarantined"

PW_COMMIT_IDENTITY = CommitIdentity(
    author_name="Qinao Bootstrap Ceremony",
    author_email="qinao-bootstrap@example.invalid",
    authored_at="2026-07-23T00:00:01+00:00",
    committer_name="Qinao Bootstrap Ceremony",
    committer_email="qinao-bootstrap@example.invalid",
    committed_at="2026-07-23T00:00:01+00:00",
    message="qinao: preW0 payload preparation",
)
```

Implement exactly:

```text
write_authority_finalization(*, candidate_root: Path, output_path: Path, signed_projection_path: Path, governance_migration_path: Path) -> AuthorityFinalization
verify_authority_finalization(*, handoff_path: Path, signed_projection_path: Path, governance_migration_path: Path) -> AuthorityFinalization
build_reparented_payload(*, git_dir: Path, preparation_tip_oid: str, bootstrap_oid: str) -> str
plan_lineage_transaction(*, git_dir: Path, authority_finalization_path: Path, signed_projection_path: Path, governance_migration_path: Path, b0_proposal_path: Path, candidate_ref: str, expected_old_tip: str, new_payload_oid: str, original_forensic_ref: str, original_tip_oid: str, preparation_forensic_prefix: str) -> RefTransactionPlan
inspect_lineage_state(*, git_dir: Path, plan: RefTransactionPlan) -> LineageDisposition
apply_lineage_transaction(*, git_dir: Path, plan: RefTransactionPlan, root_contract: RootContract, authority_finalization_path: Path, signed_projection_path: Path, governance_migration_path: Path, b0_proposal_path: Path) -> None
verify_governance_required_checks_migration(*, migration_path: Path, signed_projection_path: Path) -> GovernanceRequiredChecksMigrationV1
write_final_verification(*, output_path: Path, authority_finalization_path: Path, signed_projection_path: Path, governance_migration_path: Path, b0_proposal_path: Path, lineage_plan_path: Path, bootstrap_export_path: Path) -> FinalVerificationV1
```

`build_reparented_payload` uses exact preparation tree, B0 as sole parent, and
`PW_COMMIT_IDENTITY`; no CLI identity/time option exists. Two rebuilds under
different clock/locale/timezone/Git config must yield one OID.
`verify_authority_finalization` checks commit/tree, final Owner Ledger,
byte-matched signed projection, 7+4/catalog digests, ancestry, and absence of
raw exports/self-claiming evidence.
`write_authority_finalization` derives the current clean candidate
commit/tree and every digest itself after the permanent Root Guard; it accepts
no caller OID/digest. It first verifies the signed
`GovernanceRequiredChecksMigrationV1`, proves its admission-protection digest
equals the signed projection, and emits exactly:

```text
schema_version
preparation_tip_oid
preparation_tree_oid
wave_admission_projection_sha256
owner_ledger_sha256
authority_bundle_digest
controlled_contract_catalog_digest
governance_required_checks_migration_digest
admission_protection_projection_sha256
```

`FinalVerificationV1` has exactly
`schema_version,status,b0_commit_oid,b0_tree_oid,preparation_tip_oid,
preparation_tree_oid,payload_commit_oid,payload_tree_oid,
authority_finalization_sha256,signed_projection_sha256,
governance_required_checks_migration_sha256,
bootstrap_export_envelope_sha256,lineage_plan_sha256`, with
`status = bootstrap_ready_for_prew0_gate_evaluation`.

Every plan/verify/apply/recovery mode reopens all four fixed artifacts,
recomputes their canonical SHA-256 values, proves the signed projection digest
and governance-migration digest inside authority finalization, re-verifies the
migration service signature and unchanged protection projection, and compares
them to the five immutable plan
fields before inspecting or moving a ref. Mutation, replacement, symlink,
wrong mode, or disappearance between dry-run and apply quarantines without a
partial transaction.

The ref transaction bytes are exactly:

```python
transaction_input = (
    "start\n"
    f"create {plan.original_forensic_ref} {plan.original_tip_oid}\n"
    f"create {plan.preparation_forensic_ref} {plan.preparation_tip_oid}\n"
    f"update {plan.candidate_ref} {plan.new_payload_oid} {plan.expected_old_tip}\n"
    "prepare\n"
    "commit\n"
).encode("ascii")
```

Both forensic refs must be direct refs. The only updated ref is
`refs/heads/codex/qinao-w1-clean-candidate`; canonical, runner, run, proposal,
tag, symbolic, index, and worktree state is out of scope and rejected.

The CLI parser is frozen in this task. It has one mutually exclusive mode
from `--proposal-only`, `--verify-proposal`,
`--write-authority-finalization`, `--verify-authority-finalization`,
`--verify-required-checks-migration`, `--plan-payload-lineage`,
`--verify-lineage-plan`, `--apply-lineage-plan`,
`--verify-applied-lineage`, or `--write-final-verification`. Each mode accepts
only the fixed inputs shown in Tasks 7-11, rejects irrelevant/duplicate
arguments, refuses repository-contained output artifacts, and emits one
closed status line. Every external JSON output uses the same secure
mode-`0700` parent/mode-`0600` leaf, canonical byte, atomic install,
file/directory `fsync`, byte-identical reopen, and divergent-reopen refusal
contract frozen in Task 7.

Add parser/contract tests for every mode, missing/extra/cross-mode arguments,
each exact output field set, artifact mutation between plan/verify/apply,
authority-finalization writer derivation (no caller digest), governance
migration signature/projection mismatch, symlink/mode substitution, and
final-summary idempotent/divergent reopen. These are subtests under the
existing lineage-builder test methods; do not hide them behind a zero-match
selector.

- [ ] **Step 3: Run GREEN and commit before ceremony**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_build_qinao_bootstrap_lineage
git add scripts/build_qinao_bootstrap_lineage.py \
  scripts/test_build_qinao_bootstrap_lineage.py
test "$(git diff --cached --name-only)" = "$(printf '%s\n' \
  scripts/build_qinao_bootstrap_lineage.py \
  scripts/test_build_qinao_bootstrap_lineage.py)"
git commit -m "feat(qinao): freeze atomic prew0 lineage transaction"
set +e
STATUS_BYTES="$(git status --porcelain=v1)"
STATUS_RC="$?"
set -euo pipefail
test "$STATUS_RC" -eq 0
test -z "$STATUS_BYTES"
```

Expected: all tests pass and exactly two paths commit. Task 8 may now begin;
Task 10 later performs only the already-implemented operational transaction.

---

### Task 8: Prepare and Complete the External Two-Operator Ceremony

**Files:**
- Create: `scripts/prepare_qinao_bootstrap_ceremony.py`
- Create: `scripts/verify_qinao_bootstrap_export.py`
- Create: `scripts/test_qinao_bootstrap_ceremony.py`

**Interfaces:**
- Consumes: Input A, verified local B0 proposal, separately authorized
  host-import/reopen receipt for that exact B0 closure, authenticated
  provider/service metadata supplied outside Git, and two distinct operator
  approvals over one immutable bootstrap intent.
- Produces: Output B under `/private/tmp/qinao-bootstrap-ceremony-v1/export` plus immutable external transparency entries; it does not modify repository files or candidate refs.

- [ ] **Step 1: Write RED authority-digest and ceremony-substitution tests**

Cover:

```text
Input A cardinality not 11
authority draft digest changed after operator 1 review
wave_admission_v1 projection present before B0 OID exists
B0 parent/tree/path/catalog mismatch
B0 object-import receipt absent, wrong, or not host-reopened
same operator signs twice
operator role lacks repository-admin or admission-bootstrap approval
runner/OIDC/service/protection identity mismatch
profile missing any of its 15 closed fields
concrete model-Provider or product release-profile values appear in catalog,
module, corpus, or any path in `diffPaths(approvedBase,B0)` other than closed
schema field definitions; the authenticated, credential-free admission
service public binding is allowed only at
`scripts/qinao_gate_modules/v0/service-binding-v1.json`
one unpinned Action SHA
canonical ref or runner ref already exists at another OID
only one protected ref exists after a recovered partial ceremony
ref exists but protection observation is absent or stale
transparency append outcome is unknown
bootstrap export missing one of five files
export envelope digest substitution
export envelope missing/adding one of the exact eight fields
export envelope uses forbidden `attestation_sha256` alias
attestation not found in authenticated transparency store
```

Add:

```python
def test_bootstrap_export_v1_has_exact_closed_fields(self) -> None:
    expected = {
        "wave_admission_projection_sha256",
        "bootstrap_attestation_sha256",
        "bootstrap_bundle_manifest_sha256",
        "operator_approvals_sha256",
        "transparency_entry_id",
        "transparency_checkpoint_digest",
        "transparency_inclusion_proof_digest",
        "export_envelope_signature",
    }
    envelope = parse_bootstrap_export(valid_export_envelope_bytes())
    self.assertEqual(envelope.FIELD_NAMES, expected)
    self.assertNotIn("attestation_sha256", envelope.FIELD_NAMES)
```

- [ ] **Step 2: Run focused RED tests**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_bootstrap_ceremony
```

Expected: both tools have importable typed RED seams and named methods fail
only with `qinao.bootstrap-ceremony.unimplemented`; import failure is not RED.

- [ ] **Step 3: Implement canonical ceremony request generation**

```python
@dataclass(frozen=True)
class CeremonyRequest:
    schema_version: Literal[1]
    approved_base_oid: str
    approved_design_sha256: str
    authority_draft_sha256: str
    authority_bundle_digest: str
    owner_ledger_draft_digest: str
    controlled_contract_catalog_digest: str
    wave_admission_contract_digest: str
    required_gate_contracts_digest: str
    bootstrap_commit_oid: str
    bootstrap_tree_oid: str
    bootstrap_paths_digest: str
    gate_catalog_digest: str
    verifier_bundle_digest: str
    runner_bundle_digest: str
    bootstrap_object_set_digest: str

@dataclass(frozen=True)
class BootstrapExportV1:
    wave_admission_projection_sha256: str
    bootstrap_attestation_sha256: str
    bootstrap_bundle_manifest_sha256: str
    operator_approvals_sha256: str
    transparency_entry_id: str
    transparency_checkpoint_digest: str
    transparency_inclusion_proof_digest: str
    export_envelope_signature: str

```

Implement exactly
`build_ceremony_request(authority_draft_path: Path, b0_proposal_path: Path) ->
CeremonyRequest`. `authority_draft_path` must equal the one literal indexed
path
`docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json` and is
reopened from the candidate index after the execution-root guard.
`b0_proposal_path` must equal the one fixed external path
`/private/tmp/qinao-bootstrap-ceremony-v1/b0-proposal-v1.json`; it is never a
repository or candidate-index path. Neither argument is a free-form selector.

The generator reopens Input A from the candidate index, requires exact 7+4 cardinality/digests, re-verifies B0, and writes canonical bytes only to `/private/tmp/qinao-bootstrap-ceremony-v1/ceremony-request-v1.json`. Provider endpoint, OIDC issuer/subject/audience, service signing identity, branch-protection digest, evidence-storage profile, and operator approvals are added only by the authenticated external ceremony, never by candidate CLI values.
It reuses Task 7's exact code-owned mode-`0700` parent and mode-`0600`
atomic-leaf contract; it never assumes the parent exists and never creates it
through a shell command or permissive default umask.

The only CLI is:

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 \
  scripts/prepare_qinao_bootstrap_ceremony.py \
  --authority-draft \
  docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json \
  --b0-proposal \
  /private/tmp/qinao-bootstrap-ceremony-v1/b0-proposal-v1.json
```

It accepts no output path, root, repository, B0 OID, profile, service, or
operator argument. It obtains the candidate root from the permanent guard,
reopens Input A from the index, and opens the B0 proposal by its exact fixed
external path with `O_NOFOLLOW`. The request is installed atomically at the
code-owned output path with file and directory `fsync`. An absent output is
created; an existing byte-identical regular mode-`0600` output is an
idempotent reopen; a symlink, other mode, noncanonical value, or differing
byte is `CEREMONY_UNAVAILABLE` and is never overwritten.

The existing ceremony substitution test methods gain subtests for a wrong
authority path, worktree-vs-index substitution, a B0 proposal under the
repository, a second external proposal path, an output-path flag, symlinked
input/output, an existing different output, and byte-identical crash re-entry.
No new test-method cardinality is introduced.

- [ ] **Step 4: Import B0 objects, then run one recoverable two-operator ceremony**

Stop for fresh, explicit user authorization before uploading/importing B0
objects, creating or protecting a remote ref, installing a Git-host policy, or
publishing an external attestation. Approval to implement or test this plan is
not approval for those external mutations.

First, the service receives the exact local B0 object closure through an
authorized quarantine upload. It runs host `fsck`, re-derives the sole parent,
tree, exact bootstrap-path/mode/blob set and object closure from the approved
base, imports only the missing objects, reopens every object from the target
repository, and returns signed `BootstrapObjectImportReceiptV1`. Missing
authorization/object, a thin/extra pack, local-only OID, wrong parent/path, or
failed host reopen stops `BLOCKED_EXTERNAL_BOOTSTRAP` with reason code
`CEREMONY_UNAVAILABLE` before approvals or refs.

Operator 1 and Operator 2 independently authenticate and review the exact same
request, B0 import receipt, Input A, all 19 programs/corpora, runner/workflow,
full-SHA Actions, profiles, external-physical broker policy, run/proposal ref
policies, and expected protection digest. They sign approvals only. They do
not each execute side effects.

The external service persists one signed append-only `BootstrapIntentV1`
before effects. It binds request/import/approval digests, canonical and runner
refs, run/proposal prefixes, B0, desired protection/policies, projection,
attestation draft identity/time/signing policy, and exact ordered operations:

```text
importReceiptReopened
canonicalRefCreateOrReopen
runnerRefCreateOrReopen
canonicalProtectionInstallOrReopen
runnerProtectionInstallOrReopen
proposalPrefixPolicyInstallOrReopen
runPrefixPolicyInstallOrReopen
bundleManifestFrozen
attestationSigned
transparencyAppendOrReopen
exportEnvelopeFrozen
completed
```

One designated service principal executes the list. Before every write it
queries the Git host/transparency store; exact already-applied state advances
the immutable observation index, absent state performs one effect, and any
divergence quarantines. This covers crashes after only one ref, after a ref but
before protection, after one prefix policy, and an unknown transparency
append. It never deletes/replaces a partial output to “retry.”

The service signs `bootstrap-attestation-v1.json` over the fixed projection,
bundle-manifest, approval, B0-import, and fresh ref/policy observation digests.
The attestation contains no transparency entry ID. After signing, the service
appends or reopens the identical attestation in the transparency store, obtains
entry/checkpoint/inclusion proof, and freezes
`export-envelope-v1.json` over the other four file digests plus that inclusion
tuple. Only then is the intent `completed` and Output B exportable.

The candidate tool does not perform these operations. If the external
service, authenticated metadata, second operator, or actual profile is
unavailable, stop with `BLOCKED_EXTERNAL_BOOTSTRAP` and reason code
`CEREMONY_UNAVAILABLE`; do not write example identities, predicted digests,
or a local success projection.

- [ ] **Step 5: Implement export verification**

The module exposes exactly
`parse_bootstrap_export(data: bytes) -> BootstrapExportV1` and rejects
duplicate, missing, unknown, noncanonical, or alias fields before signature
verification.
`verify_qinao_bootstrap_export.py` has one allowed command:

```bash
set -euo pipefail
python3 scripts/verify_qinao_bootstrap_export.py \
  --request /private/tmp/qinao-bootstrap-ceremony-v1/ceremony-request-v1.json \
  --export-directory /private/tmp/qinao-bootstrap-ceremony-v1/export
```

It authenticates the transparency-store lookup using the pinned provider verifier, then proves:

```text
two distinct authorized approvals
attestation signature and transparency inclusion
B0 object-import receipt signature and host reopen
one two-approval BootstrapIntent with complete effect observations
B0/base/tree/path/catalog/verifier/runner exact match
canonical and runner refs both equal B0
live protection equals frozen digest
workflow/OIDC/service identities exact match
catalog has 19 immutable rows and exact wave sets
profile exists only in signed wave-admission-v1.json
export envelope required/properties set equals BootstrapExportV1's exact eight fields
export envelope byte-digests projection, attestation, bundle manifest, and approvals
export envelope signature binds those four digests plus entry/checkpoint/inclusion proof
`attestation_sha256` and every unknown alias are rejected
no secret/private key/access token/raw device identity appears
```

- [ ] **Step 6: Run ceremony tests and commit tooling**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_bootstrap_ceremony \
  scripts.test_build_qinao_bootstrap_lineage \
  scripts.test_qinao_admission_recovery_oracle
git add scripts/prepare_qinao_bootstrap_ceremony.py \
  scripts/verify_qinao_bootstrap_export.py \
  scripts/test_qinao_bootstrap_ceremony.py
git commit -m "feat(qinao): verify external bootstrap ceremony"
```

Expected: all local conformance tests pass; exactly three files committed.

- [ ] **Step 7: Execute the ceremony checkpoint**

Run the exact request command from Step 3, then:

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 \
  scripts/verify_qinao_bootstrap_export.py \
  --request \
  /private/tmp/qinao-bootstrap-ceremony-v1/ceremony-request-v1.json \
  --export-directory \
  /private/tmp/qinao-bootstrap-ceremony-v1/export
```

Expected
verification output:

```text
verified external bootstrap:
  operators=2
  catalog=19
  canonical_ref=B0
  runner_ref=B0
  profile=signed-projection-only
  transparency=included
```

If that output is unavailable, stop at Hold C with program terminal
`BLOCKED_EXTERNAL_BOOTSTRAP` and reason code `CEREMONY_UNAVAILABLE`. Do not
continue to Task 9 or Task 10.

---

### Task 9: Hand the Signed Projection Back to Authority Finalization

**Files:**
- Read only: `/private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json`
- Read only: `/private/tmp/qinao-bootstrap-ceremony-v1/export/export-envelope-v1.json`
- Read only after authority completion: `/private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json`
- Read only: `docs/superpowers/specs/qinao-owner-ledger-v1.json`

**Interfaces:**
- Consumes: verified Output B.
- Produces: a hard pause and then a validated authority-finalization handoff; no repository edit in this task.

- [ ] **Step 1: Record the exact external output digests**

```bash
set -euo pipefail
shasum -a 256 \
  /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json \
  /private/tmp/qinao-bootstrap-ceremony-v1/export/bootstrap-attestation-v1.json \
  /private/tmp/qinao-bootstrap-ceremony-v1/export/bootstrap-bundle-manifest-v1.json \
  /private/tmp/qinao-bootstrap-ceremony-v1/export/operator-approvals-v1.json \
  /private/tmp/qinao-bootstrap-ceremony-v1/export/export-envelope-v1.json
```

Expected: five lowercase SHA-256 digests; these are communicated to the authority plan and not committed here.

- [ ] **Step 2: Pause for the authority plan**

The authority plan imports the signed projection into final `wave_admission_v1`, performs its own RED/GREEN and exact 7+4/Owner-Ledger checks, finalizes the complete preparation tree, and writes `authority-finalization-v1.json`. This plan performs no authority-text or Owner-Ledger edit.

- [ ] **Step 3: Use the already-frozen verifier on the final authority handoff**

Task 7A already committed the mode. Do not edit or commit any repository byte;
run:

```bash
set -euo pipefail
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-authority-finalization \
  /private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json \
  --signed-projection \
  /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json \
  --governance-migration \
  /private/tmp/qinao-bootstrap-ceremony-v1/required-checks-migration-v1.json
```

It proves the preparation tip exists, its tree matches the handoff, its Owner Ledger byte-matches the signed projection, the 7+4 digests are final, the tree descends from baseline `486e1ec5983ad4390c5b07f04607f1345b912c4c`, and no draft handoff or external raw export is included as authoritative Cw/Sw evidence.

Expected: `verified authority finalization: tree stable, wave_admission_v1 byte-matched`.

- [ ] **Step 4: Double-read the preparation tree before lineage**

```bash
set -euo pipefail
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-authority-finalization \
  /private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json \
  --signed-projection \
  /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json \
  --governance-migration \
  /private/tmp/qinao-bootstrap-ceremony-v1/required-checks-migration-v1.json
sleep 1
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-authority-finalization \
  /private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json \
  --signed-projection \
  /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json \
  --governance-migration \
  /private/tmp/qinao-bootstrap-ceremony-v1/required-checks-migration-v1.json
```

Expected: both runs report identical preparation commit/tree and projection digest. Any drift returns to Hold C.

---

### Task 10: Atomically Preserve Forensics and Reparent the preW0 Payload

**Files:**
- Verify without modifying: `scripts/build_qinao_bootstrap_lineage.py`
- Verify without modifying: `scripts/test_build_qinao_bootstrap_lineage.py`
- Consume without modifying: `scripts/qinao_execution_root.py`
- Ref transaction only:
  - Create once at audited original tip `486e1ec5983ad4390c5b07f04607f1345b912c4c`: `refs/qinao-forensics/clean-candidate-22-commit-tip-20260723`
  - Create once at final preparation tip: `refs/qinao-forensics/prew0-preparation/<full-preparation-tip-oid>`
  - Update with expected old OID: `refs/heads/codex/qinao-w1-clean-candidate`

**Interfaces:**
- Consumes: verified `B0`, final authority preparation tip/tree, exact current candidate ref, the fixed audited original tip, and two absent forensic refs.
- Produces: one new `Pw` object whose tree equals the final preparation tree and whose sole parent is `B0`; one atomic three-ref transaction. It does not touch `refs/heads/qinao-admitted`.
- Task 7A already committed every implementation byte. This task creates no
  source commit before or after the authority-finalization handoff.

- [ ] **Step 1: Re-run the frozen transaction suite without editing**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_build_qinao_bootstrap_lineage
set +e
STATUS_BYTES="$(git status --porcelain=v1)"
STATUS_RC="$?"
set -euo pipefail
test "$STATUS_RC" -eq 0
test -z "$STATUS_BYTES"
```

Expected: Task 7A tests remain green and the final authority preparation tree is unchanged. Any source diff or new commit invalidates Hold C.

- [ ] **Step 2: Produce a dry-run transaction plan**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --expect-candidate-lineage prebootstrapPreparation \
  --require-clean
python3 scripts/build_qinao_bootstrap_lineage.py \
  --plan-payload-lineage \
  --authority-finalization /private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json \
  --signed-projection /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json \
  --governance-migration /private/tmp/qinao-bootstrap-ceremony-v1/required-checks-migration-v1.json \
  --b0-proposal /private/tmp/qinao-bootstrap-ceremony-v1/b0-proposal-v1.json \
  --candidate-ref refs/heads/codex/qinao-w1-clean-candidate \
  --original-forensic-ref refs/qinao-forensics/clean-candidate-22-commit-tip-20260723 \
  --original-tip 486e1ec5983ad4390c5b07f04607f1345b912c4c \
  --preparation-forensic-prefix refs/qinao-forensics/prew0-preparation \
  --output /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-lineage-plan /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json \
  --authority-finalization /private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json \
  --signed-projection /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json \
  --governance-migration /private/tmp/qinao-bootstrap-ceremony-v1/required-checks-migration-v1.json \
  --b0-proposal /private/tmp/qinao-bootstrap-ceremony-v1/b0-proposal-v1.json
```

Expected:

```text
verified lineage plan:
  original_forensic_ref=absent
  preparation_forensic_ref=absent
  candidate_ref=expected preparation tip
  new_payload_tree=preparation tree
  new_payload_parents=[B0]
  protected_refs_changed=0
```

- [ ] **Step 3: Apply the one atomic local ref transaction**

Run only after the dry-run output and both operator artifacts remain current:

```bash
set -euo pipefail
python3 scripts/build_qinao_bootstrap_lineage.py \
  --apply-lineage-plan /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json \
  --authority-finalization /private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json \
  --signed-projection /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json \
  --governance-migration /private/tmp/qinao-bootstrap-ceremony-v1/required-checks-migration-v1.json \
  --b0-proposal /private/tmp/qinao-bootstrap-ceremony-v1/b0-proposal-v1.json
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --expect-candidate-lineage reparentedProgram \
  --require-clean
```

Expected: `lineage transaction committed atomically`, followed by a canonical Root Guard JSON line whose `candidate_lineage` is `reparentedProgram`.

- [ ] **Step 4: Verify the post-transaction invariants**

```bash
set -euo pipefail
PREP_OID="$(python3 -c 'import json; print(json.load(open("/private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json"))["preparation_tip_oid"])')"
PW_OID="$(git rev-parse refs/heads/codex/qinao-w1-clean-candidate)"
B0_OID="$(python3 -c 'import json; print(json.load(open("/private/tmp/qinao-bootstrap-ceremony-v1/b0-proposal-v1.json"))["bootstrap_commit_oid"])')"
test "$(git rev-parse refs/qinao-forensics/clean-candidate-22-commit-tip-20260723)" = "486e1ec5983ad4390c5b07f04607f1345b912c4c"
test "$(git rev-parse "refs/qinao-forensics/prew0-preparation/$PREP_OID")" = "$PREP_OID"
test "$(git rev-parse "$PW_OID^{tree}")" = "$(git rev-parse "$PREP_OID^{tree}")"
test "$(git rev-list --parents -n 1 "$PW_OID")" = "$PW_OID $B0_OID"
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --expect-candidate-lineage reparentedProgram \
  --require-clean
python3 scripts/verify_qinao_bootstrap_export.py \
  --request /private/tmp/qinao-bootstrap-ceremony-v1/ceremony-request-v1.json \
  --export-directory /private/tmp/qinao-bootstrap-ceremony-v1/export
```

Expected: every local `test` exits 0, and authenticated external verification still proves both protected refs equal B0. The fixed forensic ref retains the audited 22-commit tip; the content-addressed forensic ref retains the complete final preparation ancestry.

---

### Task 11: Run the Bootstrap and Handoff Verification Matrix

**Files:**
- Verify only: all files listed in this plan.
- Produce only outside Git: `/private/tmp/qinao-bootstrap-ceremony-v1/final-verification-v1.json`

**Interfaces:**
- Consumes: completed Tasks 1–10.
- Produces: one privacy-clean local verification summary and the exact gate/evidence-bundle interface consumed by later external Cw/Sw assembly.

- [ ] **Step 1: Run all Python suites with non-zero discovery**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_admission_protocol_v1 \
  scripts.test_qinao_import_review_v1 \
  scripts.test_qinao_gate_catalog_v0 \
  scripts.test_qinao_wave_verifier_v0 \
  scripts.test_check_qinao_wave_admission \
  scripts.test_qinao_protected_admission_runner \
  scripts.test_qinao_external_physical_gate_v0 \
  scripts.test_qinao_admission_recovery_oracle \
  scripts.test_build_qinao_bootstrap_lineage \
  scripts.test_qinao_bootstrap_ceremony
```

Expected: every named module reports discovered tests and the aggregate exits
0. The graph assertions report exactly 19 gates, 152 cells, nine mapped rows,
eight catalog tests, eight exact-OID tests, three runner-selection tests,
four graph-recovery tests, nine payload-authorization recovery tests, nine
advance-authorization recovery tests, seven governance-validation recovery
tests, four B0-minimality tests, 126 outer corpus executions, and 110 nested
graph-case executions. `w0_open_set` reports exactly 16 safety IDs, 13 suites,
ten ordered graph-freeze rows, and a matching canonical digest. There is no
gate 20.

- [ ] **Step 2: Re-run baseline Owner-Ledger tests without absorbing its dirty change**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_owner_ledger
```

Expected: all tests pass after the authority plan's separate owner-ledger repair. Do not stage or commit `scripts/check_qinao_owner_ledger.py` from this plan.

- [ ] **Step 3: Validate every JSON and workflow guard**

```bash
set -euo pipefail
python3 - <<'PY'
import json
from pathlib import Path

manifest_path = Path("scripts/qinao_gate_modules/bootstrap-paths-v1.json")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
assert manifest == {
    "schema_version": 1,
    "paths": sorted(manifest["paths"]),
}
assert len(manifest["paths"]) == len(set(manifest["paths"]))

json_paths = {
    Path(path)
    for path in manifest["paths"]
    if path.endswith(".json")
}
json_paths.add(manifest_path)
json_paths.add(
    Path("docs/superpowers/specs/qinao-import-review-v1.schema.json")
)
json_paths.add(
    Path(
        "docs/superpowers/evidence/qinao-wave-admission/"
        "bootstrap-candidate-manifest.json"
    )
)
assert json_paths
for path in sorted(json_paths):
    assert path.is_file() and not path.is_symlink(), path
    with path.open("r", encoding="utf-8") as handle:
        json.load(handle)

workflow_path = Path(".github/workflows/qinao-wave-admission.yml")
assert workflow_path.is_file() and not workflow_path.is_symlink()
text = workflow_path.read_text(encoding="utf-8")
assert "contents: read" in text
assert "id-token: write" in text
assert "contents: write" not in text
assert "actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683" in text
assert "workflow_dispatch" not in text
assert "inputs:" not in text
assert "push:" in text
assert "qinao-admission-runs/**" in text
PY
```

Expected: all JSON parses and workflow assertions pass.

- [ ] **Step 4: Re-verify B0, external export, and lineage**

```bash
set -euo pipefail
python3 scripts/build_qinao_gate_catalog_v0.py \
  --verify-projection scripts/qinao_gate_modules/v0/program-spec-v1.json
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-proposal /private/tmp/qinao-bootstrap-ceremony-v1/b0-proposal-v1.json
python3 scripts/verify_qinao_bootstrap_export.py \
  --request /private/tmp/qinao-bootstrap-ceremony-v1/ceremony-request-v1.json \
  --export-directory /private/tmp/qinao-bootstrap-ceremony-v1/export
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-applied-lineage /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json \
  --authority-finalization /private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json \
  --signed-projection /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json \
  --governance-migration /private/tmp/qinao-bootstrap-ceremony-v1/required-checks-migration-v1.json \
  --b0-proposal /private/tmp/qinao-bootstrap-ceremony-v1/b0-proposal-v1.json
```

Expected: all four commands exit 0 and report the same B0/Pw identities.

- [ ] **Step 5: Prove protected-runner authority separation**

Run the mutation bundle that attempts to:

```text
supply wave/ref/profile/verifier/module
start evaluation from a prebuilt Cw/Sw/seal
substitute a local-only Pw for the signed proposal receipt
load a checker from Pw
change workflow SHA/ref/environment
grant contents:write
perform CAS from the runner
construct/import Cw/Sw from the runner or candidate
create intent before host-side object reopen
forge an intent or attestation
activate a current-wave proposal
advance while pendingAdmission
replace a finalized attestation
replace one of the nine predecessor-selected graph bindings
move production_graph_reachability into its module wrapper
delete/reorder one W0 graph_freeze_cases row or its digest
wire the graph executor/shadow/cutover in W4
reorder the exact W6 dependency sequence
add gate 20 or matrix cell 153
```

Command:

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_protected_admission_runner \
  scripts.test_qinao_external_physical_gate_v0 \
  scripts.test_qinao_admission_recovery_oracle \
  scripts.test_qinao_wave_verifier_v0
```

Expected: all mutation cases are discovered and rejected.

- [ ] **Step 6: Emit the local handoff summary outside Git**

```bash
set -euo pipefail
python3 scripts/build_qinao_bootstrap_lineage.py \
  --write-final-verification \
  /private/tmp/qinao-bootstrap-ceremony-v1/final-verification-v1.json \
  --authority-finalization /private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json \
  --signed-projection /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json \
  --governance-migration /private/tmp/qinao-bootstrap-ceremony-v1/required-checks-migration-v1.json \
  --b0-proposal /private/tmp/qinao-bootstrap-ceremony-v1/b0-proposal-v1.json \
  --lineage-plan /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json \
  --bootstrap-export /private/tmp/qinao-bootstrap-ceremony-v1/export/export-envelope-v1.json
```

Expected summary status: `bootstrap_ready_for_prew0_gate_evaluation`. It is not an admission receipt and does not claim `preW0` admitted.

---

## Completion and Scope Boundary

This plan is complete when all of the following are true:

1. Preparation R verifies distinct signed two-operator C1 and C2
   `ImportReviewV1` records whose digests and exact decision rows bind C0,
   while the same fixed mechanism remains ready for the later distinct C3
   ceremony;
2. the existing 22 candidate commits remain reachable from the fixed create-once forensic ref, and the complete final preparation ancestry remains reachable from its separate content-addressed forensic ref;
3. `B0` is a minimal single-parent child of the approved base with an exact manifest-equal diff;
4. `B0` contains the closed 152-cell/42-program source and all 19 through-W6 gate contracts/modules/corpora, and no profile, authority payload, evidence result, receipt, or attestation;
5. the external signed projection alone carries the closed `build_evidence_storage_profile`;
6. two independent operators have established and attested the canonical and runner refs at B0;
7. verifier V0 proves candidate/worktree/import/network isolation over exact payload OIDs;
8. the protected workflow can authenticate by OIDC but cannot write refs or select wave/ref/profile/verifier/module;
9. the external service passes the complete payload-proposal/evaluation/non-host-assembly/advance-authorization/authorized-object-import/intent/CAS/attestation crash-recovery conformance matrix;
10. the authority plan byte-matches final `wave_admission_v1` and freezes one final preparation tree;
11. the local atomic transaction produces a `Pw` with that exact tree and sole parent B0; and
12. active B0 modules can emit the exact `Pw`-bound gate/evidence bundle, and service conformance proves the same-identity sequence of deterministic non-host evidence-only `Cw` plus one-receipt `Sw` closure/request, fresh reopened advance authorization, authorized host import/reopen and receipt, then intent/CAS/finalization without a prebuilt seal.

Not completed here:

- C0 forensic inventory/import-map implementation beyond the signed
  preparation-only ImportReviewV1 verifier owned here;
- 7+4 authority prose or Owner-Ledger implementation;
- the later real preW0 evaluation and construction of its concrete `Cw` or `Sw`;
- protected canonical-ref admission of preW0;
- W0 source freezes, K4 physical proof, or Artifact Mesh;
- deployment/operation of the external admission service itself.

The unavoidable external interface is the real provider/service deployment
plus its authenticated service metadata, two authorized operators,
branch-protection controls, KMS/evidence-store profile, and transparency
store. Until those exist and Output B validates, the correct terminal is
`BLOCKED_EXTERNAL_BOOTSTRAP` with reason code `CEREMONY_UNAVAILABLE`, not a
locally fabricated substitute.

## Self-Review Checklist

- [x] Every requirement in the delegated scope maps to a task or an explicit external hold.
- [x] B0 single-parent/minimality, exact 22-commit preservation, content-addressed preparation preservation, atomic three-ref transaction, exact already-applied recovery, and partial/divergent-state quarantine are specified and tested.
- [x] All 19 gates, eight literal wave sets, 19 contracts, 19 modules, and 19 three-class corpora are enumerated.
- [x] All 42 programs have closed concrete `output_rows_by_wave`; the literal
  matrix expands to 136 primary plus 142 supplemental program-owned
  projections, and W1-W6 freeze concrete 26/26/26/26/26/29 Cw arrays with
  exact caps, unique producers, and recomputed digests, without
  runtime/caller choice; an independent literal full-tuple oracle rejects
  coupled ProgramSpec/projection/digest mutations.
- [x] `build_evidence_storage_profile` appears only in the signed projection/Owner-Ledger handoff, never in B0 catalog or blocked candidate projection.
- [x] Protected runner and external service responsibilities are non-overlapping and testable.
- [x] Crash recovery covers payload authorization and import plus the distinct deterministic non-host Cw/Sw closure/request → pending/unknown/persisted/reopened/fresh/expired/consumed advance authorization → same-identity authorized target-host import/reopen and receipt → intent/CAS/finalization sequence, together with proposal-ref, dispatch-intent, run-ref, lost evaluation, partial upload, supersession, pending attestation, idempotent finalization, competing successors, and quarantine.
- [x] Same-payload pin, same-lease gate recovery, same-assembly advance authorization, same-intent finalization, every host/service effect at-most-once, receipt-not-authorization rejection, and the three-branch consumer re-entry contract are explicit and tested.
- [x] Non-admitted outcomes use closed `AdmissionTerminalError`; exact W0/Artifact reason registries have no arbitrary detail channel.
- [x] Preparation-only ImportReviewV1 binds
  repository/base/inventory/candidate state, the exact batch row set, two
  operators, service envelope, and one batch-specific record digest; C1,
  C2, and later C3 remain distinct append-only records.
- [x] No caller-selected wave/ref/profile/verifier/module is accepted by authoritative paths.
- [x] Input A, Output B, Hold C, and Output D are exact cross-plan interfaces.
- [x] C0 internals, authority content edits, W0/K4, and Artifact Mesh remain outside this plan; domain plans own output semantics/producers/schemas, while Bootstrap alone freezes Cw/Sw admission-transport paths, modes, caps, unions, and the two-pass non-host-closure/authorization/authorized-import mechanism.
- [x] Commands use exact paths and expected terminals; code steps include concrete signatures or complete closed data shapes.
- [x] No step stages or commits the pre-existing dirty Owner-Ledger checker change.
