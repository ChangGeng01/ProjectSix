# Qinao Bootstrap Verifier and Admission Lineage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the externally anchored bootstrap trust root that freezes every gate needed through W6, evaluates exact Git payload objects without candidate-code trust, hands authoritative side effects to an authenticated external admission service, and reparents the finalized preW0 payload under a minimal single-parent `B0` without losing the existing 22 preparation commits.

**Architecture:** `B0` is a minimal one-parent child of approved base `59c26f508262d7c25869faac0ec0abf968ec1e02`; it contains only the immutable workflow, runner, verifier V0, complete gate catalog, 19 executable gate modules, contracts, corpora, schemas, and their closed helper set. The protected workflow has read-only repository permission plus OIDC and begins from an exact proposed `Pw`, never a prebuilt seal. It executes only byte-verified active bytes, uploads signed gate/evidence outputs, and the external service alone validates the closed `Cw` output allowlist, deterministically constructs and imports `Cw` plus one-receipt `Sw`, creates the immutable admission intent, performs canonical-ref CAS, and finalizes the attestation. This ordering removes the impossible cycle in which `Sw` would need current-run results before the run starts. After the authority plan imports the signed bootstrap projection and freezes its preparation tree, one local `git update-ref --stdin` transaction creates a fixed original-tip forensic ref plus a content-addressed final-preparation forensic ref, then moves only the candidate ref to a new `Pw` with that exact tree and sole parent `B0`.

**Tech Stack:** Python 3 standard library and `unittest`, Git object/index/ref plumbing, canonical JSON and closed JSON Schema, GitHub Actions OIDC with full-SHA Actions, an external append-only admission/CAS/attestation service, and existing Swift/Xcode/Rust gate commands invoked only through bootstrap-pinned modules.

## Global Constraints

- Implement in the existing clean candidate worktree `/Users/changgeng/.codex/worktrees/e4d7/Project06`; do not create a second clean worktree.
- Preserve branch `codex/qinao-w1-clean-candidate`, its 22 commits from approved base through baseline tip `486e1ec5983ad4390c5b07f04607f1345b912c4c`, and the pre-existing unstaged `scripts/check_qinao_owner_ledger.py` change.
- Approved base is exactly `59c26f508262d7c25869faac0ec0abf968ec1e02`; approved design SHA-256 is exactly `3af1067ad2c3d37c36d7613ad19d1dd035bb6f1c60f06b75d5d71de22874d1b4`.
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
  refs, deterministic `Cw/Sw` assembly/import, `AdmissionIntent`,
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
4. commit the complete indivisible authority preparation; and
5. export `/private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json` with exact fields:

```json
{
  "schema_version": 1,
  "preparation_tip_oid": "Git commit OID",
  "preparation_tree_oid": "Git tree OID",
  "wave_admission_projection_sha256": "64 lowercase hex",
  "owner_ledger_sha256": "64 lowercase hex",
  "authority_bundle_digest": "64 lowercase hex",
  "controlled_contract_catalog_digest": "64 lowercase hex"
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
5. import both objects through its authenticated Git-host integration and re-open them from the host;
6. persist an immutable object-import receipt before creating `AdmissionIntent`; and
7. only then attempt protected-ref CAS and final attestation.

The authority child owns the content schemas and parity compiler; this
bootstrap child owns the active-run protocol and external-service conformance
contract. A candidate-local `Cw`, `Sw`, proposal ref, commit timestamp,
evidence leaf, or receipt is never an admission input.

### Input E — externally pinned payload proposal

After a wave freezes `Pw`, an operator with separate user authorization makes
its objects available to the external service without touching the canonical
ref. The service verifies the object set, creates the immutable
content-addressed ref
`refs/heads/qinao-payload-proposals/<full-payload-oid>`, reopens
commit/tree/parents from the Git host, and returns a signed
`PayloadProposalReceiptV1` outside Git. The workflow receives no payload
input. A service-owned `EvaluationDispatchIntentV1` binds the proposal receipt
to one opaque create-once run ref
`refs/heads/qinao-admission-runs/<request-id>` at B0. The `push` event carries
only B0/ref/run metadata; the service derives the payload from the intent. No
upload branch, operator label, proposed wave, ref spelling, or event field is
authority.

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
and B0 contracts, then leaves all Cw/Sw object construction/import,
`AdmissionIntent`, CAS, and finalization inside the external service.

All four methods are recovery operations over immutable service records:

1. `reopen_admitted_predecessor()` is a pure authenticated query. Repeating it
   for the same finalized chain head returns a byte-identical
   `AdmittedWaveV1`; a changed head is a new caller operation, never mutation
   of the prior result.
2. `pin_payload_and_issue_lease(payload_oid)` is keyed by repository,
   predecessor-chain digest, payload commit/tree, active catalog digest, and
   dispatch intent. A retry returns the same proposal receipt and same
   `EvaluationLease`. While that evaluation is open or terminal, creation of a
   new lease or second evaluation for the same key is forbidden.
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
   identities, and intent key. It queries and resumes the same
   assembly/import/intent/CAS/attestation records. It never constructs a
   second Cw, Sw, import receipt, or intent. Repetition after success returns
   the byte-identical `AdmittedWaveV1` and program terminal `admitted`;
   successful CAS without the same-intent attestation returns
   `pendingAdmission`; any identity mismatch returns
   `quarantinedAdmission`.

An expired lease with no terminal bundle does not authorize a replacement
lease automatically: the operation returns `BLOCKED_EXTERNAL_BOOTSTRAP` with
a reason code `EVALUATION_LEASE_EXPIRED` until operator policy resolves the
original evaluation. Tests crash after every durable boundary and prove these
four retry laws, including “physical execution count remains one”.

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
- Create `docs/superpowers/specs/qinao-admission-service-state-v1.schema.json`: closed crash-recovery state projection.
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

Add exact tests for sorted UTF-8 output, duplicate keys, NaN/infinity, booleans-as-integers, unknown keys, uppercase digests, short/full Git OIDs, and a caller-supplied authority selector:

```python
class AdmissionProtocolV1Tests(unittest.TestCase):
    def test_canonical_json_is_stable_utf8(self) -> None:
        self.assertEqual(
            canonical_json_bytes({"z": "脑", "a": 1}),
            b'{"a":1,"z":"\\xe8\\x84\\x91"}',
        )

    def test_closed_json_rejects_duplicate_and_unknown_fields(self) -> None:
        with self.assertRaisesRegex(ProtocolError, "duplicate JSON key"):
            parse_closed_json(b'{"a":1,"a":2}', fields={"a"})
        with self.assertRaisesRegex(ProtocolError, "unknown fields"):
            parse_closed_json(b'{"a":1,"wave":"W0"}', fields={"a"})

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
an ambiguous transport failure. The RED fake exposes durable counters so
query/resume cannot masquerade as rerun.

- [ ] **Step 2: Run the focused RED suite**

Run:

```bash
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

`EvidenceAssemblyResult` is valid only after the service validates the complete `EvidenceOutput` exact set against `cw_output_contract_digest`, writes Cw/Sw objects with the lease-frozen identities, imports them through its authenticated Git-host integration, and reopens their commit/tree/blob topology from the host. The external object-import receipt binds repository, exact object OIDs, uploaded pack/object-set digest, host transaction/audit identity, and reopen observation. It is persisted before `AdmissionIntent`; no runner-local OID or ref proves import.

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
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_admission_protocol_v1 \
  scripts.test_check_qinao_wave_admission
```

Expected: positive discovery and all tests pass.

- [ ] **Step 5: Commit the protocol primitive**

```bash
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
requires every path except the fixed map clean and the map at either the
embedded prior digest or the exact derived postimage, obtains the opaque
fixed verifier result, derives all review fields in memory, writes canonical
bytes through a same-directory `O_EXCL` temporary file plus file/directory
`fsync` and atomic replace, and immediately verifies preapply mode. If the map
already equals that postimage, it is an idempotent verify-only success; every
other state fails without overwrite.

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
dirty/staged/untracked path, caller path/key/row attempts, crash before and
after atomic replace, stale temporary-file cleanup without data adoption,
second identical application, and refusal to overwrite a non-prior,
non-postimage map.

- [ ] **Step 2: Run RED**

```bash
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
test -z "$(git status --porcelain=v1)"
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
python3 scripts/qinao_import_review_v1.py --verify-fixed-export C1
python3 scripts/check_qinao_import_map.py \
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
test -z "$(git status --porcelain=v1)"
python3 scripts/qinao_import_review_v1.py --freeze-fixed-context C2
python3 scripts/qinao_import_review_v1.py --verify-frozen-context C2
```

Stop here. This is a mandatory external hold: after fresh authorization, the
service obtains the two distinct role approvals, signs the self-contained C2
record, stores it append-only, appends its transparency entry, reopens the
content address, and exports the immutable record/receipt pair. Only after
that external operation completes run:

```bash
python3 scripts/qinao_import_review_v1.py --verify-fixed-export C2
python3 scripts/check_qinao_import_map.py \
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
test -z "$(git status --porcelain=v1)"
python3 scripts/qinao_import_review_v1.py --freeze-fixed-context C3
python3 scripts/qinao_import_review_v1.py --verify-frozen-context C3
```

Stop here. After fresh external authorization, the service performs the same
two-person signing, append-only storage, transparency append, immutable
reopen, and fixed-cache export as Step 6. Only after that external operation
has completed run:

```bash
python3 scripts/qinao_import_review_v1.py --verify-fixed-export C3
python3 scripts/check_qinao_import_map.py \
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
    predecessor_payload_root: Path | None
    predecessor_payload_commit_oid: str | None
    predecessor_payload_tree_oid: str | None
    derived_wave: str
    predecessor_chain_digest: str
    contract: Mapping[str, object]
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
never enter `sys.path`.

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
| `architecture-closure-v1` | exact non-empty owner/storage/recovery/entrypoint/test/status closure, prior-phase result set, 7+4 reciprocal document rows, and Ledger-derived active release-profile rows |
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
| `qinao.architecture-closure` | `architecture_closure_exact_set` requires non-empty owner/storage/recovery/entrypoint/test/status fields, reciprocal 7+4 refs, the exact Ledger-derived active shipping-profile set (empty at preW0), and byte-compared generated output |
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
and their test. `bootstrap-paths-v1.json` is not created or staged until Task
7.

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

Also test absolute/`..`/NUL/non-UTF8 paths, symlink escape, submodule mode, executable-mode drift, missing blob, wrong B0 commit, contract/module/corpus substitution, timeout, output flood, inherited proxy, socket use, current-wave proposal activation, and a module writing outside its output directory.

- [ ] **Step 2: Run the focused RED suite**

```bash
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
   row binds the exact program, output rows, and three corpus cases; and
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

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_wave_verifier_v0 \
  scripts.test_qinao_gate_catalog_v0
```

Expected: all tests pass; every one of the 42 programs executes exactly one
positive, one negative, and one mutation case, for 126 executions; every one
of the 19 module bundles is covered and no corpus program is unreachable.

- [ ] **Step 6: Commit verifier V0**

```bash
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
```

Also reject missing/extra profile fields, credentials/secrets/URLs with user-info, unknown external-evidence classes, an unsigned profile, profile in the blocked manifest, catalog/profile digest mismatch, external attestation encoded in the receipt schema, a payload proposal without host-side object reopen, caller-supplied proposal ref, nondeterministic/missing Cw/Sw commit identity, Cw/Sw object import without host reopen, and any `--wave`, `--ref`, `--profile`, `--verifier`, or `--module` flag.

- [ ] **Step 2: Run the focused RED suite**

```bash
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
the blocked projection contains no profile; exactly thirteen paths are staged.

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
`BLOCKED_EXTERNAL_BOOTSTRAP`; clearing environment variables alone is not an
isolation proof.

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
service assembly returns deterministic Cw/Sw plus a host-reopened object-import receipt
runner invokes no git commit-tree, hash-object -w, update-index, update-ref, GitHub ref API, intent API, or attestation signer
service final/pending/quarantine state maps to distinct exit codes
```

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_protected_admission_runner \
  scripts.test_qinao_external_physical_gate_v0 \
  scripts.test_qinao_wave_verifier_v0
```

Expected: all tests pass.

- [ ] **Step 6: Commit protected runner and workflow**

```bash
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
- Consumes: signed payload-proposal receipt, immutable evaluation/assembly/import records, authenticated object/ref observations, immutable intent record, Git-host CAS audit, attestation record, and observation freshness.
- Produces: one pure `RecoveryDecision`; the external service implementation must pass this conformance suite before ceremony.

The state enum is exact:

```python
class AdmissionState(Enum):
    PAYLOAD_PINNED = "payloadPinned"
    EVALUATION_OPEN = "evaluationOpen"
    ASSEMBLY_READY = "assemblyReady"
    OBJECT_IMPORT_UNKNOWN = "objectImportUnknown"
    OBJECTS_IMPORTED = "objectsImported"
    INTENT_OPEN = "intentOpen"
    CAS_OUTCOME_UNKNOWN = "casOutcomeUnknown"
    PENDING_ADMISSION = "pendingAdmission"
    FINALIZED = "finalized"
    SUPERSEDED = "superseded"
    QUARANTINED = "quarantined"
```

The decision enum is exact:

```python
class RecoveryAction(Enum):
    ISSUE_EVALUATION_LEASE = "issueEvaluationLease"
    RETRY_SAME_EVALUATION = "retrySameEvaluation"
    ASSEMBLE_BYTE_IDENTICAL_OBJECTS = "assembleByteIdenticalObjects"
    IMPORT_OR_REOPEN_OBJECTS = "importOrReopenObjects"
    CREATE_INTENT = "createIntent"
    RETRY_SAME_INTENT = "retrySameIntent"
    QUERY_HOST_AUDIT = "queryHostAudit"
    CREATE_SUPERSEDING_INTENT = "createSupersedingIntent"
    FINALIZE_BYTE_IDENTICAL_ATTESTATION = "finalizeByteIdenticalAttestation"
    RETURN_EXISTING_ATTESTATION = "returnExistingAttestation"
    BLOCK_NEXT_WAVE = "blockNextWave"
    QUARANTINE = "quarantine"
```

- [ ] **Step 1: Write the exhaustive RED transition table**

Tests cover every row:

| Proposal/evaluation state | Evidence/assembly state | Host object observation | Decision |
|---|---|---|---|
| exact pinned payload, no evaluation | absent | n/a | `issueEvaluationLease` |
| same open evaluation | incomplete/no terminal results | n/a | `retrySameEvaluation` |
| same open evaluation | exact complete passing outputs | absent | `assembleByteIdenticalObjects` |
| same evaluation | exact assembly record | absent or unknown | `importOrReopenObjects` |
| same evaluation | exact assembly/import receipt | exact Cw/Sw reopened | `createIntent` |
| missing/mismatched proposal, lease, output allowlist, commit identity, receipt bytes, Cw/Sw topology, import receipt, or host object | any | any | `quarantine` |

Only after the exact `objectsImported → createIntent` row does the post-intent table apply:

| Ref | Host audit | Intent | Attestation | Observation | Decision |
|---|---|---|---|---|---|
| `prior` | `noCAS` | absent | absent | fresh | `createIntent` |
| `prior` | `noCAS` | same open | absent | fresh | `retrySameIntent` |
| `prior` | `noCAS` | same open | absent | expired | `createSupersedingIntent` |
| `prior` | `unknown` | any | absent | any | `queryHostAudit` |
| `Sw` | same-intent success | same open | absent | any | `finalizeByteIdenticalAttestation` |
| `Sw` | same-intent success | same open | identical finalized | any | `returnExistingAttestation` |
| `Sw` | same-intent success | same open | absent | any next-wave request | `blockNextWave` |
| other | any | any | any | any | `quarantine` |
| `Sw` | different transaction | any | any | any | `quarantine` |
| `Sw` | same transaction | different lineage | any | any | `quarantine` |
| `Sw` | same transaction | same intent | mismatched attestation | any | `quarantine` |

Also test evaluation retry after runner loss, partial result upload, assembly crash after Cw but before Sw, import timeout followed by exact host reopen, import receipt without objects, objects without the same assembly digest, competing successor CAS loss, repeated finalization, two superseders, changed repository/wave/prior/Sw/receipt/verifier bytes, stale live-policy observation, and an audit timeout.

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

- [ ] **Step 2: Run focused RED tests**

```bash
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
    payload_proposal: PayloadProposalReceiptV1 | None
    evaluation: EvaluationRecord | None
    gate_result_bundle: AuthenticatedGateResultBundle | None
    assembly: EvidenceAssemblyResult | None
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

```

Implement exactly `decide_recovery(observation: RecoveryObservation) -> RecoveryDecision` as a total, side-effect-free function over the closed enums and fields above.

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
evaluation record. `createIntent` is legal only after the same assembled Cw/Sw
have an immutable object-import receipt, a host-side reopen observation, and a
policy observation satisfying
`policy_observed_at <= decision_time < policy_valid_until` and
`decision_time < intent_expires_at`. It freezes the attestation ID,
attestation creation time, signing policy, and unsigned-field digest before
CAS. `createSupersedingIntent` is legal only after authenticated `noCAS`, only
when `decision_time >= intent_expires_at` or the policy observation is
expired, and only when repository/wave/prior/Sw/receipt/verifier bytes are
identical. It names the old intent as `predecessorIntentID` and never mutates
it. After same-intent CAS success, deterministic signing over the frozen draft
plus the audited CAS transaction makes retries byte-identical.
`pendingAdmission` never activates the next verifier/module or permits another
wave.

- [ ] **Step 4: Close all six schemas**

Every schema uses `additionalProperties: false`, exact required fields, lowercase digests/OIDs, sorted unique arrays, and explicit state enums. The intent schema freezes:

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
object import/intent, payload proposal, evaluation dispatch/run ref,
evaluation lease/result bundle, external physical request/private-custody
receipt/privacy-clean projection, assembly record, object-import receipt,
intent/supersession, CAS audit, and final attestation. A later phase references
the exact prior record; it never overwrites it. No schema permits a
caller-selected wave/ref/profile/verifier field or raw secret.

- [ ] **Step 5: Run conformance and JSON checks**

```bash
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

Reject extra/missing path, path mode mismatch, symlink/special file, source-tree drift, merge base, wrong parent, test/plan/authority/evidence path in manifest, a concrete provider/profile instance in B0 runtime data, catalog digest mismatch, nondeterministic author/time, and a pre-existing protected ref with the wrong OID.

- [ ] **Step 2: Run focused RED tests**

```bash
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
no concrete model-Provider instance or product release-profile value exists in
the exact bootstrap diff/active bundle closure; the credential-free admission
service public binding is the sole service-instance exception and is checked
against its closed schema; inherited approved-base bytes are outside this
negative scan and cannot become active bootstrap data
authority draft and external export paths are absent from B0
```

The builder writes proposal JSON only to an explicit output path and refuses a path under the repository root.

- [ ] **Step 5: Run tests and commit the builder**

```bash
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
- Verify without modifying: `scripts/build_qinao_bootstrap_lineage.py`
- Verify without modifying: `scripts/test_build_qinao_bootstrap_lineage.py`
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
verify_authority_finalization(*, handoff_path: Path, signed_projection_path: Path) -> AuthorityFinalization
build_reparented_payload(*, git_dir: Path, preparation_tip_oid: str, bootstrap_oid: str) -> str
plan_lineage_transaction(*, candidate_ref: str, expected_old_tip: str, new_payload_oid: str, original_forensic_ref: str, original_tip_oid: str, preparation_forensic_prefix: str) -> RefTransactionPlan
inspect_lineage_state(*, git_dir: Path, plan: RefTransactionPlan) -> LineageDisposition
apply_lineage_transaction(*, git_dir: Path, plan: RefTransactionPlan, root_contract: RootContract) -> None
```

`build_reparented_payload` uses exact preparation tree, B0 as sole parent, and
`PW_COMMIT_IDENTITY`; no CLI identity/time option exists. Two rebuilds under
different clock/locale/timezone/Git config must yield one OID.
`verify_authority_finalization` checks commit/tree, final Owner Ledger,
byte-matched signed projection, 7+4/catalog digests, ancestry, and absence of
raw exports/self-claiming evidence.

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

- [ ] **Step 3: Run GREEN and commit before ceremony**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_build_qinao_bootstrap_lineage
git add scripts/build_qinao_bootstrap_lineage.py \
  scripts/test_build_qinao_bootstrap_lineage.py
test "$(git diff --cached --name-only)" = "$(printf '%s\n' \
  scripts/build_qinao_bootstrap_lineage.py \
  scripts/test_build_qinao_bootstrap_lineage.py)"
git commit -m "feat(qinao): freeze atomic prew0 lineage transaction"
test -z "$(git status --porcelain=v1)"
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
CeremonyRequest`; the two paths are fixed candidate-index paths selected by
the caller only after the execution-root guard succeeds.

The generator reopens Input A from the candidate index, requires exact 7+4 cardinality/digests, re-verifies B0, and writes canonical bytes only to `/private/tmp/qinao-bootstrap-ceremony-v1/ceremony-request-v1.json`. Provider endpoint, OIDC issuer/subject/audience, service signing identity, branch-protection digest, evidence-storage profile, and operator approvals are added only by the authenticated external ceremony, never by candidate CLI values.

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
failed host reopen stops `BLOCKED_EXTERNAL_BOOTSTRAP` before approvals or
refs.

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

Run request generation and verification exactly as above. Expected
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
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-authority-finalization \
  /private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json \
  --signed-projection \
  /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json
```

It proves the preparation tip exists, its tree matches the handoff, its Owner Ledger byte-matches the signed projection, the 7+4 digests are final, the tree descends from baseline `486e1ec5983ad4390c5b07f04607f1345b912c4c`, and no draft handoff or external raw export is included as authoritative Cw/Sw evidence.

Expected: `verified authority finalization: tree stable, wave_admission_v1 byte-matched`.

- [ ] **Step 4: Double-read the preparation tree before lineage**

```bash
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-authority-finalization \
  /private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json \
  --signed-projection \
  /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json
sleep 1
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-authority-finalization \
  /private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json \
  --signed-projection \
  /private/tmp/qinao-bootstrap-ceremony-v1/export/wave-admission-v1.json
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
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_build_qinao_bootstrap_lineage
test -z "$(git status --porcelain=v1)"
```

Expected: Task 7A tests remain green and the final authority preparation tree is unchanged. Any source diff or new commit invalidates Hold C.

- [ ] **Step 2: Produce a dry-run transaction plan**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --expect-candidate-lineage prebootstrapPreparation \
  --require-clean
python3 scripts/build_qinao_bootstrap_lineage.py \
  --plan-payload-lineage \
  --authority-finalization /private/tmp/qinao-bootstrap-ceremony-v1/authority-finalization-v1.json \
  --b0-proposal /private/tmp/qinao-bootstrap-ceremony-v1/b0-proposal-v1.json \
  --candidate-ref refs/heads/codex/qinao-w1-clean-candidate \
  --original-forensic-ref refs/qinao-forensics/clean-candidate-22-commit-tip-20260723 \
  --original-tip 486e1ec5983ad4390c5b07f04607f1345b912c4c \
  --preparation-forensic-prefix refs/qinao-forensics/prew0-preparation \
  --output /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-lineage-plan /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
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
python3 scripts/build_qinao_bootstrap_lineage.py \
  --apply-lineage-plan /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --expect-candidate-lineage reparentedProgram \
  --require-clean
```

Expected: `lineage transaction committed atomically`, followed by a canonical Root Guard JSON line whose `candidate_lineage` is `reparentedProgram`.

- [ ] **Step 4: Verify the post-transaction invariants**

```bash
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

Expected: every named module reports discovered tests and the aggregate exits 0.

- [ ] **Step 2: Re-run baseline Owner-Ledger tests without absorbing its dirty change**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_owner_ledger
```

Expected: all tests pass after the authority plan's separate owner-ledger repair. Do not stage or commit `scripts/check_qinao_owner_ledger.py` from this plan.

- [ ] **Step 3: Validate every JSON and workflow guard**

```bash
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
python3 scripts/build_qinao_gate_catalog_v0.py \
  --verify-projection scripts/qinao_gate_modules/v0/program-spec-v1.json
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-proposal /private/tmp/qinao-bootstrap-ceremony-v1/b0-proposal-v1.json
python3 scripts/verify_qinao_bootstrap_export.py \
  --request /private/tmp/qinao-bootstrap-ceremony-v1/ceremony-request-v1.json \
  --export-directory /private/tmp/qinao-bootstrap-ceremony-v1/export
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-applied-lineage /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
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
```

Command:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_protected_admission_runner \
  scripts.test_qinao_external_physical_gate_v0 \
  scripts.test_qinao_admission_recovery_oracle \
  scripts.test_qinao_wave_verifier_v0
```

Expected: all mutation cases are discovered and rejected.

- [ ] **Step 6: Emit the local handoff summary outside Git**

```bash
python3 scripts/build_qinao_bootstrap_lineage.py \
  --write-final-verification \
  /private/tmp/qinao-bootstrap-ceremony-v1/final-verification-v1.json \
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
9. the external service passes the complete payload-proposal/evaluation/evidence-assembly/object-import/intent/CAS/attestation crash-recovery conformance matrix;
10. the authority plan byte-matches final `wave_admission_v1` and freezes one final preparation tree;
11. the local atomic transaction produces a `Pw` with that exact tree and sole parent B0; and
12. active B0 modules can emit the exact `Pw`-bound gate/evidence bundle, and service conformance proves deterministic evidence-only `Cw` plus one-receipt `Sw` assembly without a prebuilt seal.

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
- [x] Crash recovery covers payload pinning, lost evaluation, partial upload, deterministic assembly, unknown object import, unknown CAS, expired observations, supersession, pending attestation, idempotent finalization, competing successors, and quarantine.
- [x] Same-payload pin, same-lease gate recovery, same-intent finalization, physical-effect at-most-once, and the three-branch consumer re-entry contract are explicit and tested.
- [x] Non-admitted outcomes use closed `AdmissionTerminalError`; exact W0/Artifact reason registries have no arbitrary detail channel.
- [x] Preparation-only ImportReviewV1 binds
  repository/base/inventory/candidate state, the exact batch row set, two
  operators, service envelope, and one batch-specific record digest; C1,
  C2, and later C3 remain distinct append-only records.
- [x] No caller-selected wave/ref/profile/verifier/module is accepted by authoritative paths.
- [x] Input A, Output B, Hold C, and Output D are exact cross-plan interfaces.
- [x] C0 internals, authority content edits, W0/K4, and Artifact Mesh remain outside this plan; domain plans own output semantics/producers/schemas, while Bootstrap alone freezes Cw/Sw admission-transport paths, modes, caps, unions, and assembly/import mechanism.
- [x] Commands use exact paths and expected terminals; code steps include concrete signatures or complete closed data shapes.
- [x] No step stages or commits the pre-existing dirty Owner-Ledger checker change.
