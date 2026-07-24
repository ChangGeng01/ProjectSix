# Qinao Clean Candidate Reconstruction and Controlled Convergence Program Plan

> **For agentic workers:** This file is the program-order authority, not a code task list. Execute the linked child implementation plans with `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans`. Never execute two child steps that write the same candidate tree at the same time.

**Goal:** Preserve every existing byte, reconstruct one non-circular clean candidate, admit preW0 through W6 through predecessor-derived gates, and hand off one verified model-independent Qinao SDK without creating duplicate authority.

**Architecture:** Five executable child plans own focused, independently reviewable subsystems: forensic provenance/import, bootstrap verification/admission, controlled authority and evidence, W0/K4 safety, and Artifact Mesh W1 Task 0. This program plan owns only their dependency graph, immutable handoff types, wave ordering, terminal states, and the exact mapping back to the five incumbent owner/domain plans.

**Tech Stack:** Git object/index/ref transactions, Python 3 standard-library `unittest`, canonical JSON and JSON Schema, Swift 6 and SwiftPM, Xcode 27/iOS 27, SQLite, Security/Keychain, `xcodebuild`, structured `xcrun devicectl`, and externally anchored immutable evidence/admission services.

## Global Constraints

- The approved design commit is exactly `59c26f508262d7c25869faac0ec0abf968ec1e02`.
- The approved design path is `docs/superpowers/specs/2026-07-23-qinao-convergence-correction-and-clean-candidate-design.md`.
- The approved design SHA-256 is `3af1067ad2c3d37c36d7613ad19d1dd035bb6f1c60f06b75d5d71de22874d1b4`.
- The approved dynamic-graph amendment is commit `9d484befb4a4593d93789457ebddfd7cde358e3b`, path `docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md`, Git blob `e2c59656f9eb184efc3ab933fe442c9dd0b7d507`, SHA-256 `5f36d0b04579f805a3a69254325e62e22625f4ddd31663e03cbf78b1a39460d5`.
- The architecture remains exactly 14 Semantic LayerCores, 4 Physical Kernels, 4 bounded ControlRings, and 7 orthogonal planes.
- The minimum deployment target is iOS 27 for every package, project, generated project, script, test host, XCFramework slice, archive, and selected release profile.
- Models and APIs remain outside Qinao SDK behind value-only Provider/Proposal boundaries and have equal authority ceilings.
- Qwen 3.5 4B and AFM may be Main Providers; MiniCPM5-1B, MiniCPM-V 4.6, Granite 97M, or later local/API models may be bounded Sub Providers. Provider capability never becomes App-Agent identity or state authority.
- One Session has one App Agent, one logical Main Agent, independently budgeted Sub-Agent contexts, read-only shared compartments, and no peer calls or shared scratchpad.
- No step may add a mutable owner, manager, scheduler, compiler, State Market, EventLog, K3 WAL, K4 ledger, publication journal, recovery registry, release mouth, promotion mouth, retry truth, ring, kernel, or plane.
- The exact two new immutable value-contract families are `BASContentIntakeProfilePayload`/`BASContentIntakeReceiptPayload` and `BASAuthorizedInputEffectPredecessorPayload`.
- V1 visible output is exactly `bufferedUntilVerified`; incremental/provisional visibility and cross-process heavy Provider execution remain V2-quarantined.
- One K3-allocated Provider branch performs at most one physical invocation. Unknown external state is query/reconcile-only and is never blindly replayed.
- Candidate code, tests, manifests, workflows, and checkers cannot select or activate the verifier or gate module that judges their own wave.
- Protected evaluation starts from an externally pinned exact `Pw`, never a
  prebuilt `Sw`; current-run gate results are validated before the external
  service deterministically assembles `Cw/Sw` in non-host quarantine, and no
  target-host import occurs until the exact fresh advance authorization is
  reopened.
- `wave`, repository, protected ref, verifier, gate module, release profile, Team identity, and protection policy are predecessor/authority derived; they are never caller CLI, environment, branch-name, worktree-name, or candidate-manifest inputs.
- `Pw` contains source, authority, schema, checker, test, fixture, and build-input bytes but no result that claims `Pw`.
- `Cw` is the one-parent evidence-only child of `Pw`. It may add only schema-allowlisted privacy-clean evidence and one self-excluding evidence manifest.
- `Sw` is the one-parent child of `Cw` and adds exactly one regular mode-`100644` receipt at the wave's fixed path.
- The post-CAS admission attestation and through-admission chain digest remain outside `Pw`, `Cw`, and `Sw`.
- C1 and C2 are one indivisible preW0 admission payload. Preparation commits are not authority and cannot be admitted separately.
- The bootstrap commit `B0` has the approved design base as its sole parent and differs from it by exactly the externally reviewed bootstrap path set.
- The preW0 `Pw` has `B0` as its sole parent and has a tree byte-identical to the final reviewed preparation tree.
- No merge parent, graft, replace object, ambiguous ancestry, current-wave verifier, or current-wave gate module is admissible.
- Raw secrets, device identifiers, archives, Mach-O files, CMS/signing chains, profiles, model packages, link maps, build plans, symbol/index stores, and privacy-bearing traces never enter Git.
- 40 cold tok/s and 30 sustained tok/s are optional profile-qualified claims, never unconditional architecture completion gates.
- When no performance claim is requested, W6 records the closed `.notRequested` disposition. Only a separately requested claim executes the complete two-device protocol.
- Every filtered test proves positive discovery before execution. Every named scan first proves the exact path is a readable regular file. Exit 2 is failure.
- Authority Task 2 must make every executable path in the exact seven
  controlled documents repository-relative before any incumbent W1-W6 task
  may run. The controlled bytes may not contain a developer-specific source
  root, the adopted candidate's absolute root, or a `file://` repository
  locator; commands either run under the permanent Root Guard or derive
  `ROOT="$(git rev-parse --show-toplevel)"` only after that guard succeeds.
- Python governance and domain gates are hermetic. They use the standard
  library plus byte-pinned checked-in helpers only; no controlled document or
  B0 program may invoke `uv run --with`, `pip`, `pipx`, `poetry`, `conda`,
  `python -m pytest`, or another runtime dependency installer/resolver.
- Every child plan begins by proving the exact clean-candidate root and branch; no relative command may run from the preserved dirty source worktree. Before P4 the Root Guard must report `prebootstrapPreparation`; after P4 it must report `reparentedProgram`, and the consuming child must additionally verify the signed bootstrap/predecessor handoff appropriate to its wave.
- Never reset, clean, checkout-overwrite, normalize, delete, stage, or commit the preserved dirty source worktree.
- Never use broad `git add`. Stage only literal reviewed paths and compare the staged set before each commit.
- Do not push, create a pull request, update a protected ref, or claim a wave
  complete without separate user authorization and fresh required evidence.
  Payload-object pinning plus one create-once evaluation dispatch is one
  narrowly scoped authorization; protected canonical-ref CAS/finalization is
  a second, later authorization over the exact service-derived `Sw`. Neither
  authorization is implied by approval to implement, test, or execute a
  candidate-local plan.

---

## Approved Dynamic Graph Program Amendment

This amendment changes the work performed inside the existing five children
and five incumbent W1-W6 plans. It does not create a sixth child, W7, gate 20,
graph authority document, graph owner, graph store, fifth ring, fifth kernel,
or eighth plane. If graph language conflicts with the pinned 2026-07-24
specification, the pinned specification controls only the graph delta; the
2026-07-23 correction design continues to control reconstruction, provenance,
admission, and evidence.

The program must preserve five distinct projections:

| Projection | Authority and mutability |
|---|---|
| G0 capability graph | Derived, read-only authority/capability view |
| G1 semantic execution graph | Immutable per semantic Attempt; one stored `BASSemanticTurnDAG` root plus eight embedded topology values |
| G2 Mission Task Graph | Workspace/Mission-scoped immutable root replacement through K3 CAS; exactly two stored roots plus twelve embedded values; never in-place mutation |
| G3 control projection | Receipt projection of the four incumbent `ControlRing`s; never a fifth ring |
| G4 observability graph | Read-only trace projection; never scheduling or state authority |

The fixed architecture is exactly 14 Semantic LayerCores, 4 Physical Kernels,
4 bounded ControlRings, 7 orthogonal planes, and waves W0-W6. G1 has
`executionShape = pureDAG | controlRing`; source zero-join requires `pureDAG`,
while `controlRing` requires a nonempty real join. Reverse consumer-keyed
absence queries, direct peer calls, shared scratchpads, mutable graph edits,
and a second graph writer are forbidden.

### Wave placement

| Wave | Graph work admitted by the existing owner/domain plan |
|---|---|
| W0 | Freeze second graph writers/schedulers, shared mutable Agent state, direct Provider scheduling, and legacy multi-round adoption paths; extend existing hazards only and create no future graph API or behavior |
| W1 | Complete the original `runtime.semantic-dag` M/Create with immutable G1 topology/join/delegation/terminal-receipt values and the complete G2 V1/task-join value set; bind Attempt/edge refs under `runtime.turn-operation`; freeze context/continuity/recovery and RSI contracts; atomically close Ledger/schema/fixture/consumer membership; perform no retrieval, execution, allocation, network, effect, or activation |
| W2 | Before any W2 mutation, materialize and verify the canonical signed durable-raw-content Decision Gate and exactly one approved/disapproved disposition; then install the sole K3 `FULL` nucleus with Workspace/Mission/Attempt roots, active-head and Provider/delegation allocation CAS, terminal facts, zero-allocation proofs, budgets, opaque continuity ordering, and the semantic-Attempt terminal receipt in the incumbent K3 receipt-factory/historical-put allowlist; retain W1 Runtime values as foreign contracts and keep production Provider allocation disabled |
| W3 | Integrate snapshot retrieval, grounding, State Market, context compilation, structured reasoning, graph fixtures, App-Agent/session isolation, and governed delegation in shadow/test-injected mode |
| W4 | Integrate Provider packages, execution plans, certified envelopes, K1/K2/K3 handoff, cache/prefill/decode, production grounding, and graph-bound values only; perform no semantic-DAG executor wiring, graph shadow parity, replay cutover, or activation |
| W5 | Complete K4, isolated/remote egress, authorized tools/effects/publication/erasure, successor-Attempt remand, unknown-effect reconciliation, and durable boundary recovery; never blindly retry |
| W6 | Install mechanical DAG wiring, two all-member barriers/per-member start gates, frozen joins, audit values, shadow parity, replay/recovery certification, intake/reachability-dark proof, retirement, and one sealed cutover in the exact dependency order below |

W6 executes in this exact dependency order:
Runtime Task 2 value prelude → Semantic Task 8 audit-value/schema prelude →
Runtime Task 1B outcome/final-audit-envelope → Semantic Task 8 behavior →
Runtime Tasks 2/3/4 plus Task 5 remainder → Runtime Task 6 → intake A and
reachability-dark → Runtime Task 7 sealed cutover. Cold 40/s and sustained
30/s remain optional profile-qualified claims, never structural completion
gates.

The terminal semantics are closed: a WorkUnit is complete only when the exact
current semantic-Attempt disposition is `completed`; terminal non-adoptable
sink receipts bind `designatedTerminalNoProgress` with a deadlocked basis.
Task-cancellation `JoinEvidence` binds the parent terminal outcome and parent
attempt basis `notApplicable | neverAdmitted | terminalAttempt`, where
`terminalAttempt` excludes `completed`. Aggregate bounds are 1,018 terminal
dispositions and 1,024 parent/input references.

All graph contracts, tests, fixtures, mutations, reachability results, and
cutover proof must flow through the existing child plans and existing gate
IDs. The five executable children and all existing terminal/handoff types
remain unchanged.

### Program-order acceptance crosswalk

Each child consumes this table rather than restating or reordering it:

| Obligation | Owning existing plan/task | Required existing gate |
|---|---|---|
| Six-plan source commit, held inventory, fixed C1 | C0 Tasks 3/6/7 plus Bootstrap Task 1A | `qinao.review-candidate` |
| G0-G4 authority, owner pins, 7+4 convergence | Authority Tasks 1-4/6/8 | `qinao.owner-ledger`, `qinao.architecture-closure` |
| Production graph/source/entrypoint closure | Authority Task 7 | `qinao.production-reachability` |
| W0 second-writer/shared-state freeze | W0 Tasks 2/4/11 | `qinao.w0-open-set` |
| G1/G2 wires and topology proof | Contracts and Semantic W1 tasks | `qinao.contracts-layercell`, `qinao.semantic-statelake-context` |
| Physical rows, Provider order, no W4 activation | Silicon W2-W4 tasks | `qinao.silicon-execution-spine` |
| Authorization, effects, unknown-state recovery | Sovereign W5 tasks | `qinao.sovereign-release-effects` |
| Barriers, replay, recovery, retirement, sealed cutover | Runtime W6 tasks | `qinao.runtime-replay-certification` |
| Ordinary durable storage only | Artifact Mesh Tasks 1-13 | incumbent Artifact Mesh gates |

Before any child executes a graph-bearing step it must reopen the pinned
specification and verify all three identities:

```bash
set -euo pipefail
test "$(git rev-parse 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md)" = e2c59656f9eb184efc3ab933fe442c9dd0b7d507
test "$(git show 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md | shasum -a 256 | awk '{print $1}')" = 5f36d0b04579f805a3a69254325e62e22625f4ddd31663e03cbf78b1a39460d5
```

Expected: both commands exit 0. A missing object, changed blob, changed
digest, or ambiguous replacement is `BLOCKED_SOURCE_DRIFT`; no task may
silently use the worktree copy or a newer similarly named specification.

The graph amendment is accepted only when the existing self-review can point
to all nine rows above, every graph-bearing filtered suite proves positive
discovery, every named scan proves a readable regular file, every candidate
parity result has an independent B0 verdict, and W6 proves there was no
dual-write, dual-scheduler, dual-adoption, or dual-state-writer interval.

### Complete graph proof-family assignment

The following closes specification §20 without inventing a generic
“graph tests” bucket:

| Proof family | Incumbent implementation owner | Required proof form |
|---|---|---|
| G1 acyclicity, canonical order, edge IDs, edge/input bijection, applicability, alternative groups | `runtime.semantic-dag`, Contracts W1 | boundary/plus-one fixtures, randomized bounded DAG property tests, independent mutation oracle |
| Join membership, exact received/missing partition, conflict vector, zero-join, frozen execution shape | `runtime.semantic-dag`, Contracts W1 | exhaustive policy matrix for `all`, `quorum`, `best-effort-with-coverage` |
| Semantic-Attempt terminal receipt, terminal-no-progress, remand precedence and historical reconstruction | `runtime.semantic-dag` plus sole K3 receipt factory, Contracts W1/Silicon W2 | canonical-byte fixtures, row-pinned reconstruction, orphan-artifact and future-version mutations |
| G2 Mission/Objective/WorkUnit hierarchy, two stored roots/twelve embedded values, completion/cancellation CAS | `runtime.semantic-dag`, Semantic W1-W3 | state-transition table, competing-CAS stress, cross-Attempt evidence rejection |
| Task Graph preimage/counters/transitive patch footprint/current child generation | `runtime.semantic-dag`, Semantic W1-W3 | initial/successor root tests, no-wrap boundary, simulated non-root recheck |
| K1/K3 concurrency, allocation, ABA, lost reply and durable row→Artifact recovery | K3/Provider, Silicon W2-W5 | duplicate/stale/ABA stress plus every-before/every-after crash cutpoint |
| Provider descriptor/reservation/allocation/materialization/call/completion order | K3/Provider and Silicon W4-W5 | exact ordered trace, route matrix, unknown-state query/reconcile-only mutations |
| Two all-member barriers, per-member start recheck, deterministic frontier, sibling non-rerun | Runtime W6 pre-cutover slices | differential scheduler, barrier mutation, restart/replay tests |
| Terminal prefix, verifier barrier, release/publication/continuity suffix | Runtime and Sovereign W5-W6 | exhaustive cutpoint/presence-shape oracle and byte-identical replay |
| ControlRing cycle/no-progress/budget/deadline/currentness | Agent/Context/RSI and Runtime W3-W6 | bounded loop property tests, v1→v2 migration, explicit-null/future-version rejection |
| Session Main Agent, App Agent, Sub-Agent attenuation, persona isolation | App-Agent and Agent/Context/RSI W1-W3 | cross-scope SQL/FTS/vector/cache/trace/Provider negative corpus |
| Per-model effective context ceiling and incompatible-profile rebuild | `state.context-compiler`, Semantic W2-W3 | exact min/reserve boundary tests, tokenizer/template/profile substitution |
| Source, CI, build/link/factory closure and no legacy production authority | Authority Task 7 and Bootstrap Task 2/3 | regular-file guards, nonempty discovery, exact-OID independent reachability |
| W6 activation and no dual interval | `production.cutover`, Runtime Task 7 | sealed cutover trace proving one writer/scheduler/adopter before and after CAS |
| Optional physical throughput | Silicon profile certification only | separately requested two-device/thermal/memory evidence; `.notRequested` otherwise |

Every crash matrix row records the exact
`A/M/T/use/permit/pending/anchor/B/Q/P/O/At/C/Srow/S/R/lineage` presence
shape and selects only the incumbent continuation outcome
`restoreCompleted | resumeSameAttempt | reconcileSameOperation |
rebuildAfterTerminal | awaitUser | quarantine`. “Retry with a new
generation,” “run everything again,” absence-after-call as proof of no start,
and adoption of an orphan Artifact are invalid oracles.

## Current Reality

| Role | Exact value | Current disposition |
|---|---|---|
| Preserved source worktree | `/Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0` | Dirty forensic/source material; never mutate |
| Preserved source branch | `codex/qinao-w1` | Holds approved design/plan commits and existing staged, unstaged, untracked work |
| Approved design base | `59c26f508262d7c25869faac0ec0abf968ec1e02` | Immutable reconstruction base |
| Adopted candidate worktree | `/Users/changgeng/.codex/worktrees/e4d7/Project06` | Sole adopted candidate lineage; it carries only the frozen one-file delta until C0 Task 1 commits that repair, after which cleanliness is mandatory; do not create another |
| Adopted candidate branch | `codex/qinao-w1-clean-candidate` | Unadmitted preparation lineage |
| Audited candidate tip | `486e1ec5983ad4390c5b07f04607f1345b912c4c` | 22 preparation commits after approved base |
| Candidate worktree delta | `scripts/check_qinao_owner_ledger.py` | One deterministic symlink-diagnostic failure |
| Wave-admission tests | 20 discovered, 20 passed | Local preflight only |
| Owner-Ledger tests | 101 discovered, 100 passed, 1 failed | First local blocker |
| External bootstrap | Absent | `BLOCKED_EXTERNAL_BOOTSTRAP` |
| K4 production proof | Absent | `BLOCKED_K4` |

The 22 preparation commits are repairable unadmitted scaffold. Preserve their original tip under a create-once forensic ref before replacing the candidate ancestry. Do not discard them and do not mistake their existence for C0, preW0, or W0 admission.

## Executable Child Plans

Execute code only from these child plans:

1. `docs/superpowers/plans/2026-07-23-qinao-c0-provenance-and-safe-import.md`
2. `docs/superpowers/plans/2026-07-23-qinao-bootstrap-verifier-and-admission-lineage.md`
3. `docs/superpowers/plans/2026-07-23-qinao-authority-ledger-and-cw-evidence.md`
4. `docs/superpowers/plans/2026-07-23-qinao-w0-safety-and-k4-proof.md`
5. `docs/superpowers/plans/2026-07-23-qinao-artifact-mesh-w1-task0.md`

The five incumbent W1-W6 owner/domain plans remain executable after the authority child corrects and digest-pins them:

1. `docs/superpowers/plans/2026-07-15-iphone-air-contracts-layercell.md`
2. `docs/superpowers/plans/2026-07-15-iphone-air-semantic-statelake-context.md`
3. `docs/superpowers/plans/2026-07-15-iphone-air-silicon-execution-spine.md`
4. `docs/superpowers/plans/2026-07-15-iphone-air-sovereign-release-effects.md`
5. `docs/superpowers/plans/2026-07-15-iphone-air-runtime-replay-certification.md`

`docs/superpowers/plans/2026-07-19-qinao-coreai-agent-controlled-document-convergence.md` becomes non-executable traceability after correction. It cannot run its old Task 0, gateway, candidate, certification, raw-content, or Decision-Gate flow and is not a sixth owner/domain implementation plan.

## Immutable Cross-Plan Handoff Types

Every handoff is canonical JSON with sorted keys, compact separators, UTF-8, no duplicate keys, and a trailing LF only where its schema explicitly requires one.

### `SourceProvenanceV1`

Its exact Git path is:

```text
docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-provenance-v1.json
```

```text
schema_version
approved_base_commit
source_head_commit
source_head_tree
source_index_tree
source_status_sha256
staged_patch_sha256
unstaged_patch_sha256
inventory_sha256
approved_import_map_sha256
candidate_destination_tip
candidate_destination_tree
```

The file's one-path metadata commit has sole parent
`candidate_destination_tip`; that parent's tree is
`candidate_destination_tree`. This avoids self-reference while making the C0
handoff durable. Authority Task 1 must reopen and byte-verify this exact
parent/diff/field relation before changing the import map.

Each approved import row binds source stratum/blob/mode, destination preimage tree/blob/mode, intended postimage blob/mode, destination batch, and human-review identity. Destination drift invalidates the row.

### `AuthorityDraftHandoffV1`

The exact Git path is:

```text
docs/superpowers/evidence/qinao-authority-convergence-draft-v1.json
```

Its fields are exactly:

```text
schema_version
authority_bundle_digest
owner_ledger_draft_digest
controlled_contract_catalog_digest
document_digests[11]
wave_admission_contract_digest
required_gate_contracts_digest
```

It contains no predicted B0 OID, bootstrap attestation, Pw identity, or gate result.

### `BootstrapRootV1`

This is the canonical `wave_admission_v1` projection. It is authenticated by
a separate bootstrap attestation plus transparency-inclusion/export envelope
and contains exactly:

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

`build_evidence_storage_profile` has one canonical copy here. Catalog and Owner-Ledger projections bind its digest; they never contain a divergent second authority copy.

`expected_protection_policy_digest` is not a digest of an unbounded provider
response. It is SHA-256 over canonical JSON (UTF-8, sorted keys, no
insignificant whitespace, one LF) for exactly this closed
`AdmissionProtectionProjectionV1`:

```text
schema_version = 1
repository_identity
canonical_ref
runner_ref
run_ref_prefix
payload_proposal_ref_prefix
canonical_ref_policy_digest
runner_ref_policy_digest
run_ref_prefix_policy_digest
payload_proposal_ref_prefix_policy_digest
cas_service_principal_digest
force_update_forbidden = true
deletion_forbidden = true
non_service_bypass_actor_digests
```

Each of the four nested digests is SHA-256 over canonical
`RefProtectionPolicyProjectionV1` with exactly:

```text
schema_version = 1
selector_kind = exactRef | prefix
selector
rulesets
```

`rulesets` is a nonempty list sorted by `ruleset_id`, with no duplicate
`ruleset_id`; each closed row has exactly:

```text
ruleset_id
enforcement = active
provider_target_kind = exactRef | prefix
provider_target
allowed_writer_app_digests
bypass_actor_digests
force_update_forbidden = true
deletion_forbidden = true
```

Both digest arrays in every ruleset row are explicitly present, sorted,
duplicate-free arrays of nonempty lowercase SHA-256 identities; empty is
distinct from absent. `allowed_writer_app_digests` must be exactly the
single-element array containing the top-level
`cas_service_principal_digest`; the service principal is never represented as
a bypass actor. The top-level `non_service_bypass_actor_digests` is also an
explicit sorted, duplicate-free array of nonempty lowercase SHA-256
identities. It must equal the canonical sorted union of every nested
`bypass_actor_digests` row after excluding the service principal and, for
Qinao's service-only CAS policy, must be empty. An absent value, duplicate,
different union, service principal in a bypass row, or any nonempty
non-service bypass union is a protection mismatch.

The canonical and runner projections require
`selector_kind = exactRef` and an exact provider target byte-match.
Run/proposal projections require `selector_kind = prefix`, a selector ending
`/`, and provider starts-with semantics over that exact prefix; a broader,
narrower, glob, regex, branch name, or normalized alternative is invalid.
Every projected ruleset must match the same selector, be active, forbid
force/deletion, and authorize only the signed service writer policy; bypass
rows are explicit even when empty. Duplicate ruleset IDs are rejected before
canonicalization rather than collapsed by a map. Raw provider-response
digests remain separate audit fields.

The projection explicitly excludes default/development-branch CI
required-check context names. Authority Task 10 may migrate those contexts
only through a separate signed governance-migration observation and must prove
this admission projection is byte-identical before and after the migration.
No consumer may silently widen the projection, hash arbitrary provider JSON,
or reinterpret the required-check migration as a change to admission
protection.

It contains no bootstrap attestation digest, identifier, status, signature, or
transparency entry. `BootstrapExportV1` is separate and binds exactly:

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

The attestation is signed before append and therefore does not contain its
future transparency-entry identity. The export envelope authenticates the
post-append inclusion tuple without creating a digest fixed point. The older
aliases `b0_commit_oid`, `b0_tree_oid`, `runner_digest`, and
`bootstrap_attestation_digest` are forbidden.

### Payload identity has no standalone handoff

Do not create a `PayloadIdentityV1` file, schema, parser, or second payload
authority. The Bootstrap-owned `PayloadProposalReceiptV1` and
`EvaluationLease` carry the authenticated read-only payload/predecessor/build/
authority/profile projections through the exact opaque client boundary. For
preW0, the service proves `payload_commit_oid` has exactly one parent,
`BootstrapRootV1.bootstrap_commit_oid`. Every consumer validates those two
service envelopes; no consumer reconstructs a lookalike payload JSON.

### `AdmittedWaveV1`

```text
schema_version
repository_id
derived_wave
predecessor_seal_oid
predecessor_chain_digest
payload_commit_oid
payload_tree_oid
evidence_commit_oid
evidence_tree_oid
seal_commit_oid
seal_tree_oid
receipt_blob_sha256
admission_intent_id
cas_transaction_id
finalized_attestation_digest
admission_chain_digest
source_import_review_audit_root_digest
active_verifier_bundle_digest
active_gate_module_set_digest
selected_release_build_set_digest
envelope
```

`source_import_review_audit_root_digest` is the Bootstrap-service-derived,
privacy-clean root for the exact review records eligible at that wave:
sorted C1+C2 for preW0 and sorted C1+C2+C3 for W0 and later. No domain
consumer may reconstruct or replace it from map prose. The tuple is
authoritative for ordering only when the protected ref equals
`seal_commit_oid` and the external attestation validates the same CAS
transaction.

### Fresh external mutation authorizations

The Bootstrap service owns three opaque, append-only authorization records;
they are not candidate JSON, CLI parameters, public client methods, or new SDK
authority.

`GovernanceValidationAuthorizationV1` binds repository and development
branch, exact local preparation commit/tree, the UTF-8-byte-sorted
duplicate-free seven `{path,mode,blob_oid}` governance rows, its closed Git
object-set digest, workflow path/blob, `qinao-governance` job ID, the exact
checkout/setup-python action OIDs, Python version, the already-signed
`run_ref_prefix`, one create-once immutable validation ref and dispatch
intent, the admission-protection projection digest, operator principal/role,
issue/expiry instants, and nonce. It authorizes only target-host
import/reopen of that exact object closure, creation/reopen of that one
validation ref under the existing run prefix, and one execution of the bound
job. It cannot mutate the candidate, development/default branch, canonical
admission ref, workflow bytes, policy, or required checks. Only the
Bootstrap-owned signed `GovernanceValidationRunObservationV1` from that exact
successful run may feed the required-check migration; `noChangeRequired`
instead carries explicit `notApplicable`.

`PayloadDispatchAuthorizationV1` binds repository, admitted predecessor,
exact payload commit/tree, proposal object-set digest, intended immutable
proposal ref, one create-once run ref/dispatch intent, active B0 verifier,
operator principal/role, issue/expiry instants, and nonce. It authorizes only
host object import/reopen, immutable proposal pinning, and that one
evaluation dispatch.

`ProtectedRefAdvanceAuthorizationV1` is obtained only after the service has
deterministically derived exact `Cw/Sw` in its non-host quarantine but before
their target-repository import. It binds
repository, canonical ref, wave, expected-old seal, exact `Pw/Cw/Sw`, proposal
receipt, lease, authenticated gate-bundle digest, evidence object-set digest,
one intended create-once Git-object-import key, one immutable
admission-intent key, the fresh
`AdmissionProtectionProjectionV1` digest, operator principal/role,
issue/expiry instants, and nonce. It authorizes one non-force CAS plus
the exact target-host object import/reopen, its one signed receipt, and
same-intent finalization—nothing else.

All three records are signature- and role-verified, short-lived,
single-intent, reopened from the external append-only service, and rejected
on missing, expired, replayed, substituted, or live-policy-drifted bytes.
Governance validation first closes its local object set, then obtains its
authorization, then imports/reopens and creates the validation ref; a host
timeout is reconciled by exact intent/ref/run query and never by a second
push. Admission assembly may deterministically construct objects in a
non-host quarantine and expose the exact advance-authorization request, but
it performs no target-repository object import, intent, or CAS until the
advance record exists; retry resumes the same assembly identity. This
preserves the four-method client surface without treating process memory or a
local file as authorization.

### `ArtifactMeshW1Task0HandoffV1`

```text
schema_version
admitted_w0_chain_digest
pretransition_task0_commit_oid
pretransition_task0_tree_oid
status_transition_commit_oid
task0_code_tree_oid
ea_manifest_blob_sha256
unit_preflight_receipt_sha256
device_preflight_disposition
migration_disposition
historical_create_evidence_set_digest
artifact_mesh_owner_row_sha256
artifact_mesh_status_transition_sha256
status_transition_from
status_transition_to
```

The only allowed status tuple is
`artifact.mesh / converging / implemented`; `migration_disposition` is
exactly `anchorlessV1QuarantineRollForwardOnly`. The handoff is emitted only after
the candidate preflight passes, that proposed transition is indexed, and the
complete Phase-A gate set passes again over the resulting tree. It unlocks
later W1 compilation but does not admit W1: the indexed `implemented` byte is
a proposal until the final W1 `Pw` passes predecessor-derived B0 validation
and W1 admission finalizes.

## Program State Machine

### P0 — Repair and freeze C0 provenance

Execute the C0 child plan.

Required output:

- candidate baseline green;
- source unchanged;
- canonical all-`hold` import map with review-record digest slots still null;
- import apply tool green;
- durable `SourceProvenanceV1` whose one-path commit binds its exact parent
  candidate tip/tree plus the source inventory and all-hold map digests;
- no B0, authority, K4, or production import claim.

Failure terminal: `BLOCKED_SOURCE_DRIFT`, `BLOCKED_DESTINATION_DRIFT`, or `BLOCKED_IMPORT_REVIEW`.

### P1 — Prepare authority text, then freeze the bootstrap contracts

Use this exact cross-plan order:

1. After P0 has committed the all-hold inventory/map and
   `SourceProvenanceV1`, execute Bootstrap Task 1 and Task 1A Steps 1-4. They
   freeze the protocol plus the preparation-only signed `ImportReviewV1`
   verifier; they must not claim to run before C0 and must not yet freeze a C1
   live candidate context.
2. Execute Authority Task 1. It discovers the unique immutable
   `SourceProvenanceV1` creation commit, proves it is an unchanged ancestor
   across the scheduled Bootstrap commits, verifies the handoff, then commits
   only its authority-checker slice.
3. From that exact post-Authority-Task-1 clean HEAD/tree/index/status, execute
   Bootstrap Task 1A Steps 5-6 to obtain and reopen the external service's
   authenticated C1 `ImportReviewV1`, binding the exact ten proposed map-row
   postimages, human principal/time, approval policy, and immutable external
   reopen receipt. Only then execute Authority Task 2 to
   apply that exact reviewed C1 slice, correct the exact seven controlled
   documents and four governing addenda, demote the recovery companion,
   reverse the durable-raw-content/Decision-Gate contradictions, and make the
   CoreAI plan traceability-only. In the same atomic correction, normalize
   every executable controlled-document path to repository-relative form,
   reject all developer/candidate absolute repository roots, and replace
   every dynamic Python dependency bootstrap with the standard-library
   nonempty-test mechanism. Before advancing, all six files in this
   executable program-plan set must be regular indexed C1 postimages whose
   raw digests equal the signed review rows; a master without any child is
   incomplete.
4. From the clean post-Authority-Task-2 tip, execute Bootstrap Task 1A Step 7
   to freeze, externally sign, persist, reopen, and verify the exact 32-path
   C2 helper/test closure. Then execute Authority Task 2A: materialize the
   unique signed C2 map postimage, commit only that map path, reopen its
   first-parent transition, import/commit exactly those 32 paths, then apply
   the exact three-path helper/test hardening child without relabeling its
   parent. C1 and C2 are now one indivisible preW0 payload; no preparation
   commit is authority and none may be admitted alone.
5. Execute Bootstrap Tasks 2 and 4 as `Preparation Z`. They freeze the
   protocol grammar, self-contained Owner-Ledger-v2 gate semantics, all 19
   through-W6 gate contracts/modules/corpora, and the closed bootstrap schema.
   They create no B0, profile value, evidence, result, or authority.
6. Return to Authority Task 3. It computes
   `wave_admission_contract_digest` and `required_gate_contracts_digest` from
   those exact indexed Preparation-Z bytes, then emits
   `AuthorityDraftHandoffV1`.

This order is mandatory: Input A cannot contain the digest of a gate catalog
that is supposedly built only after Input A. The draft and Preparation-Z bytes
remain unadmitted and may not activate schema v2 or wave admission. The signed
C1 review binds the post-Authority-Task-1 pre-map context; the distinct C2
review binds the clean post-Authority-Task-2 pre-map context. Each freezes
only its own exact permitted map-only postimage, so adding either record
digest creates no HEAD/map self-reference.

### P2 — Construct, import, and externally attest B0

Reopen the exact `AuthorityDraftHandoffV1`, prove its two bootstrap-contract
digests byte-match Preparation Z, then execute Bootstrap Tasks 3 and 5-7,
the pre-ceremony lineage-tool freeze in Bootstrap Task 7A, and Bootstrap
Task 8 in that order. Enter Bootstrap
Task 9 only through Step 2 and stop at Hold C; Steps 3-4 necessarily consume
the later authority-finalization handoff.

Required properties:

- `parents(B0) = [approved design base]`;
- `diffPaths(approved design base, B0)` equals the bootstrap path manifest;
- every through-W6 gate has an executable V0 module and positive/negative/mutation corpus in B0;
- after separate user authorization, the external service imports the exact
  B0 object closure into a host quarantine namespace, reopens its
  commit/tree/parent/path bytes, and signs one
  `BootstrapObjectImportReceiptV1` before either protected ref is created;
- the signed bootstrap projection freezes one non-shipping Xcode 27/iOS 27 verification-toolchain profile, distinct from the initially empty active product-release set;
- the projection freezes the controller-side external physical-gate broker
  protocol required by K4 and Artifact Mesh; the isolated evaluator retains no
  broker credential or network route;
- the protected workflow authenticates to the external admission service with least privilege;
- the external service owns intent persistence, live-policy observation, CAS, Git-host audit query, and final attestation;
- two operators only sign the same immutable bootstrap intent; one service
  principal reconciles create-or-reopen ref/policy/log effects and initializes
  the canonical and runner refs to B0;
- candidate/local code cannot produce `admitted`.

Failure terminal: `BLOCKED_EXTERNAL_BOOTSTRAP` (including the narrower pre-ceremony `BLOCKED_EXTERNAL_SERVICE_BINDING` reason).

### P3 — Finalize authority bytes against the attested bootstrap

Return to the authority child plan:

- after the exact seven-path governance commit exists locally, inspect the
  signed required-check before-observation. If either retiring context is
  active, close that commit/tree/object set and obtain a fresh
  `GovernanceValidationAuthorizationV1`; the Bootstrap service imports and
  reopens only those objects at the target host, creates/reopens one
  create-once immutable validation ref below the already-signed run prefix,
  and observes the exact `qinao-governance` job there before any
  required-check migration. If neither context is active, require a
  byte-identical signed after-observation and explicit `notApplicable`
  replacement-run disposition instead. Neither branch permits an implicit
  push or a development, canonical, or protected-ref mutation;
- insert `wave_admission_v1` that byte-matches the canonical Output-B
  `BootstrapRootV1` projection, while separately authenticating its
  attestation and transparency inclusion through `BootstrapExportV1`;
- bind the one canonical evidence-storage profile digest;
- finish all schema-v2 validators and reciprocal references;
- keep finding results, reachability results, release results, and gate results absent;
- run all candidate-local structure tests and actual CLIs;
- freeze one clean final preparation tree.

Any mismatch between the draft, B0 contracts, external attestation, or final Owner Ledger returns to P1/P2 review. It cannot be patched after preW0 admission.

### P4 — Form the single-parent preW0 Pw

Return to the bootstrap child plan.

First execute Bootstrap Task 9 Steps 3-4 with the now-frozen authority
handoff. The lineage verifier and transaction implementation were already
committed in Task 7A, before P3 froze the preparation tree; no source commit is
legal between that freeze and the following transaction.

The lineage transaction:

1. creates one previously absent fixed forensic ref at original adopted-candidate tip `486e1ec5983ad4390c5b07f04607f1345b912c4c`;
2. creates a second previously absent content-addressed forensic ref at the final preparation tip;
3. creates `Pw` with the final preparation tree and B0 as its sole parent;
4. atomically moves only `codex/qinao-w1-clean-candidate` from the final preparation tip to `Pw`;
5. leaves the protected ref, source branch, source worktree, index bytes, and worktree bytes unchanged;
6. accepts only exact already-applied state after a crash; every partial or divergent state quarantines.

The same atomic transition changes the permanent Root Guard disposition from `prebootstrapPreparation` to `reparentedProgram`; it must never create a moment in which old-tip ancestry and forensic refs are simultaneously accepted.

After that transaction, while both protected refs still resolve to B0 and
before any real preW0 evaluation, execute Authority Task 10 Steps 7-8 to
consume the one transaction return and verify exact `Pw` topology, bytes, and
purity. Then execute Bootstrap Task 11's complete
verification matrix. Its `final-verification-v1` summary is local readiness
evidence only: it cannot select a payload, create Cw/Sw, mutate a protected
ref, or claim admission. A missing/failed Task-11 row stops P4.

Failure terminal: `BLOCKED_LINEAGE_TRANSACTION`.

### P5 — Evaluate preW0 Pw, then externally assemble Cw/Sw and admit

Return to the authority child for evidence generation and the bootstrap child for protected admission.

After a fresh `PayloadDispatchAuthorizationV1` for the exact external object
write, immutable proposal pin, and one create-once run-ref/dispatch, the
admission service pins exact preW0 `Pw/PwTree` and returns a signed
payload-proposal receipt. The protected B0 runner starts from that `Pw`—never
from a prebuilt seal—and active B0 modules produce the gate/evidence bundle.
The service validates the B0-frozen output allowlist and deterministically
assembles `Cw`, which adds:

- the two migrated schema-v2 finding ledgers;
- exact 74 QRM plus 39 source-review proof leaves;
- no itemized synthetic representation of the unverified external 45;
- release projections;
- production reachability;
- ArchitectureClosureReport;
- V2 quarantine projection;
- gate evidence;
- one self-excluding evidence manifest.

The service canonicalizes the receipt from its lease/result values and builds `Sw`, which adds only `docs/superpowers/evidence/qinao-wave-admission/preW0.json`.

The service first derives exact Cw/Sw objects in a non-host quarantine and
stops for a fresh `ProtectedRefAdvanceAuthorizationV1` over those exact bytes,
their object-set/import key, and a fresh live admission-protection projection.
Only after that record is authenticated may it import/reopen the objects at
the target Git host, persist the one object-import receipt, and execute
intent/CAS/finalize. Candidate-side Cw/Sw builders are parity tools only. Only
the finalized `AdmittedWaveV1` output unlocks W0.

Evaluation launch is not `workflow_dispatch`. The workflow exists only in B0,
so the service persists an append-only dispatch intent and creates one
create-once immutable branch
`refs/heads/qinao-admission-runs/<opaque-service-request-id>` at B0. Its `push`
event starts the B0 workflow with no caller inputs. The service maps the
authenticated OIDC ref/run tuple back to the intent and derives the payload
OID from its signed proposal receipt. Candidate, branch spelling, and workflow
event data cannot select wave, payload, profile, verifier, or gate.

### P6 — Form W0 Pw before K4

Execute the W0 child plan:

- obtain and verify the separate fixed-path, externally signed C3
  `ImportReviewV1` by executing Bootstrap Task 1A Step 8 for exactly the 20
  K4 public-source postimages, bind its record digest into those rows, prove
  the unique map-only postimage commit by history reopen, and import only
  that reviewed C3 slice with destination CAS; the earlier C1 and C2 records
  remain independently bound to their ten- and thirty-two-row sets;
- freeze Provider, effect, memory, App-Agent, recognition, learning, RSI, Main/Sub, and split-brain hazards;
- add the exact 12-row transitive legacy-learning reachability manifest;
- prove the full causal-root, split, evaluator firewall, holdout, canary, field, and adoption order;
- prove one K3 invalidation CAS and complete fanout;
- reopen the B0-self-contained 13-suite/16-safety-ID W0 program, run every
  exact non-empty suite, and emit no legacy successor receipt or probe log;
- commit and freeze immutable W0 `Pw/PwTree/build`.

K4 has not yet passed at this point. W0 is not admitted.

### P7 — Run K4 against W0 Pw, then admit W0

Continue the W0 child plan.

The production K4 driver derives release profile, Team, archive, product, and entitlement expectations from the admitted predecessor plus indexed Owner Ledger. It binds the archive and physical iOS 27 device before generating its unpredictable challenge, drives structured `devicectl`, publishes raw evidence only to the encrypted immutable external bundle, reopens it under an independent short-lived grant, and emits only a privacy-clean W0-Pw-bound projection.

If the platform, device, signing, custody, evidence store, or re-open path is absent, the exact terminal is `BLOCKED_K4`.

Only after K4 passes may the external service validate the fixed W0 output
allowlist and deterministically derive/assemble exact `Cw/Sw` in non-host
quarantine. That first same-intent call performs zero target-host
object/ref/intent effect and stops for a fresh
`ProtectedRefAdvanceAuthorizationV1` binding the exact object closure,
import key, intent key, and live protection projection. Only the second
same-identity call, after the record is persisted and reopened, may
import/reopen at the target host, emit its signed receipt, perform protected
CAS, and finalize the attestation.
After independently reopening that finalized `AdmittedWaveV1`, fast-forward
only `codex/qinao-w1-clean-candidate` from the exact W0 `Pw` to its
authenticated W0 `Sw`; require a clean tree, no merge commit, and a second
byte-identical service reopen. Artifact Phase A cannot begin from the earlier
W0 `Pw`.

### P8 — Execute Artifact Mesh W1 Task 0 preflight

Execute the first phase of the Artifact Mesh child plan immediately after admitted W0:

- repair the existing three M paths without extending the historical M manifest;
- add exactly four payload-index-bound E/A slices;
- exclude `ArtifactMeshDeviceLab` from `SampleHost/Package.swift`;
- implement owner-private SQLite/Keychain durability;
- run unit/crash tests and a candidate-local device preflight to a full pass;
- commit the sole reviewed `artifact.mesh` owner-row proposal
  `converging → implemented`, then rerun the complete Phase-A gate set over
  that new tree;
- produce `ArtifactMeshW1Task0HandoffV1` in a code-owned
  transition-OID-scoped external directory.

Only that post-transition handoff permits later W1 consumers to compile
against the repaired mechanism. Phase A does not admit W1 or make the
proposed `implemented` row authoritative. A typed device/preflight block
produces no transition and no handoff.

The JSON handoff is transport, never capability. Every P8/P9 consumer calls
the B0-pinned handoff validator in its own process. That validator freshly
reopens authenticated admitted W0, exact current HEAD/tree, the sole
one-parent/one-path mode-`100644` status transition, admitted-W0 authority
blob IDs, the unit-preflight receipt, migration disposition, and every
handoff digest, then returns an opaque process-local
`ValidatedArtifactMeshTask0Handoff`. File existence, a previously successful
shell, an environment variable, or a stale fixed `/private/tmp` path cannot
unlock work.

### P9 — Execute W1 owner work and rebind Artifact Mesh to final W1 Pw

Before the first incumbent W1 task, rerun the B0-pinned Authority and
ArchitectureClosure programs over the exact indexed seven-document set.
Require repository-relative execution surfaces, zero forbidden absolute
repository prefixes/locators, and zero dynamic Python dependency bootstrap
commands. A path or hermeticity regression is
`BLOCKED_PREW0_EVIDENCE`; it is not repaired ad hoc inside a domain task.
In the same process, require a freshly returned
`ValidatedArtifactMeshTask0Handoff`; never deserialize or trust the transport
record directly.

Execute the corrected W1 slices in the exact mapping below. Freeze final W1 `Pw`.

Return to the Artifact Mesh child plan and rerun:

- all 26 no-fault rows from 13 operations times two cuts;
- exactly 14 named fault rows;
- the production device controller;
- external raw evidence reopen;
- shipping reachability and lab exclusion;
- the four-row E/A manifest gate.

All evidence binds final W1 `Pw`, not the earlier Task-0 tree. The active B0
Owner-Ledger gate revalidates the already-indexed
`artifact.mesh / converging → implemented` proposal and the Artifact Mesh
gate revalidates its physical evidence. No Ledger or status byte may change
after final `Pw` is frozen. Only successful W1 admission makes the proposed
row authoritative; the external service first assembles exact W1 `Cw/Sw` in
non-host quarantine, then crosses the fresh
`ProtectedRefAdvanceAuthorizationV1` boundary before target-host
import/reopen, receipt, intent, CAS, and finalization. Neither phase mutates
`Pw`.

Failure terminal: `BLOCKED_ARTIFACT_MESH_DEVICE_RECOVERY`.

### P10 — Execute W2 through W6

Before W2 and before every later wave, synchronize the implementation branch
to the prior admitted seal before writing that wave:

1. call `ProtectedAdmissionClient.reopen_admitted_predecessor()` and
   authenticate the prior `AdmittedWaveV1`, its finalized attestation, and
   `refs/heads/qinao-admitted == prior.seal_commit_oid`;
2. require a clean candidate tree and no in-progress merge, rebase, or
   cherry-pick;
3. if candidate `HEAD == prior.payload_commit_oid`, fast-forward only to
   `prior.seal_commit_oid`; if `HEAD == prior.seal_commit_oid`, treat the step
   as an idempotent re-entry; every other `HEAD` is
   `BLOCKED_LINEAGE_TRANSACTION`;
4. reject a wrong expected-old OID, wrong target OID, merge commit,
   non-fast-forward, dirty tree, or prior seal not descended from the exact
   prior payload; and
5. reopen the predecessor a second time and require a byte-identical
   `AdmittedWaveV1` whose seal is now candidate `HEAD`.

This is the mandatory W1→W2, W2→W3, W3→W4, W4→W5, and W5→W6 handoff. The
branch may also be synchronized immediately after each admission, but the next
wave still executes the same idempotent Step 0. Tests cover exact-old success,
already-at-seal re-entry, wrong-old refusal, wrong-new refusal, divergence,
dirty state, and a forged or changed reopen. No wave begins from its prior
`Pw`.

After that Step 0, each wave repeats:

1. derive wave and active modules from the protected predecessor;
2. execute only the exact mapped domain slices;
3. freeze immutable `Pw`;
4. obtain one fresh `PayloadDispatchAuthorizationV1`, then service-side
   payload-object pinning, one create-once evaluation dispatch, and a signed
   proposal receipt;
5. run predecessor-derived active modules over exact `Pw`;
6. let the external service validate the frozen evidence-output allowlist and
   deterministically derive/assemble evidence-only `Cw` plus one
   fixed-receipt `Sw` entirely in non-host quarantine; close the exact object
   set and publish the bound advance-authorization request, with zero
   target-host import, receipt, intent, CAS, or attestation;
7. obtain and reopen a distinct fresh
   `ProtectedRefAdvanceAuthorizationV1`, then resume the same assembly
   identity to import/reopen at the target Git host, persist its one signed
   receipt, and run same-intent CAS, audit, and final attestation;
8. stop on any unresolved true finding, later-wave dependency, missing recovery proof, object-availability/import uncertainty, or external unknown.

## Correct W1-W6 Owner/Domain Mapping

### W1 — Contracts, values, TurnOperation, Provider inversion

Execute in this order:

1. Artifact Mesh W1 Task 0 from P8, including the passing candidate
   preflight, indexed proposed owner-row transition, post-transition rerun,
   and handoff; no later W1 task starts before that handoff.
2. Contracts Tasks 1, 2, 2A, 3, 4, and 5.
3. Semantic Task 1 value-contract slice only.
4. Silicon Task 1.
5. Silicon Task 7 Step 0; the W1-owned slices of Steps 1, 2, 4, and 7;
   Step 5A only; and Step 7A. Steps 5B and 5C remain exclusively in W4 and
   W5 below.
6. Runtime Task 1 Part A immutable semantic-DAG and typed boundary declarations only.
7. Freeze final W1 `Pw`.
8. Run Artifact Mesh final-W1-Pw device/reachability rebind from P9.
9. Form W1 `Cw/Sw` and admit.

W1 must include the content-intake family's two `semantics.layercell` schema/value `E` slices and one `artifact.mesh` storage `A` slice, plus Artifact Mesh Task 0's separate exact four-slice E/A manifest and every other W1-owned E/A slice. These are singular records under the generic E/A manifest schema; they cannot be merged across owners. W1 activates no W2-W6 intake mechanism, policy, or profile-selection behavior.

### W2 — K3, memory, erasure, authorized-input state

Execute in this order:

1. Materialize and independently verify the Semantic plan's canonical W2
   durable-raw-content Decision Gate artifact before any W2 source, schema,
   store, or migration mutation. Require the exact class/purpose, coverage
   digest, authorized operator role, issue/expiry window, and deletion/
   erasure closure, then freeze exactly one signed `approved | disapproved`
   disposition. Missing, stale, mismatched, or unauthorized bytes stop the
   wave; encryption alone is not authorization.
2. Semantic Task 2.
3. Semantic Task 4A immediately after Task 2 and before Task 3, executing
   exactly the branch selected by that reopened disposition. The approved
   branch may materialize only its enumerated coverage; the disapproved
   branch keeps digest/commitment-only truth and proves the durable writer
   unreachable.
4. Sovereign Task 4 K3 control-nucleus slice only.
5. Content intake's two `runtime.turn-operation` `A` slices for Host parser/containment and receipt production.
6. Authorized-input and remote-contract K3 E/A slices assigned to W2.

No process MemoryLedger, StateABI, production grounding Provider, K4 helper, release, effect broker, or runtime executor is enabled in W2.

### W3 — StateLake, retrieval, grounding contract, context

Execute in dependency order:

1. Semantic Task 3.
2. Semantic Task 4 snapshot/barrier work.
3. Semantic Task 4B Steps 1-4, completing the pure cache-scope RED, contract,
   GREEN, and W3 receipt without pulling in the W4 process-ledger suite.
4. Semantic Task 5 Steps 1, 2, 3A, 3C, and 4A, followed only by the W3
   pure-lane half of Step 5.
5. Semantic Task 6 Steps 1, 2, 3A, and 4A, followed only by the W3
   contract/test-conformer half of Step 5.
6. Semantic Task 7.

The exact flow is L7/R0 eligibility → L8 LaneQuery → R1-R4 mechanisms → L8 LaneResult → R5 bounded proposal → R6 validation/revalidation, conflict resolution, and one State Market → sole `BASContextCompiler`.

W3 uses a bounded test-injected grounding proposal port and performs no physical Provider call.

### W4 — Silicon actuation and production grounding

Execute in this order:

1. Silicon Task 2 `BASStateABI`.
2. Silicon Task 3 evidence adapters.
3. Silicon Task 4 capability/thermal `HardCapDerivationSource`.
4. Silicon Task 5 `BASProcessMemoryLedger`.
5. Silicon Task 6.
6. Silicon Task 7's W4 slice of Step 1, then its W4 RED execution in Step 2.
7. Silicon Task 7 Step 3.
8. Silicon Task 7's W4 K3-production-wiring portion of Step 4.
9. Atomically store, jointly validate, install, and independently reopen one
   Contracts `BASProviderBranchPolicy` artifact and the one Silicon
   `BASSiliconExecutionBinding` that references it. No production initializer,
   allocation, grounding Provider, or physical call is reachable before this
   barrier.
10. Silicon Task 7 Step 5B.
11. Silicon Task 7 Step 6.
12. Silicon Task 7's W4 shared-resource portion of Step 7.
13. Silicon Task 7 Steps 8 and 9.
14. Semantic Task 5 Steps 2B, 3B, and 4B, followed only by the W4
    production-wiring half of Step 5.
15. Semantic Task 6 Steps 2B, 3B, and 4B, followed only by the W4
    production-grounding half of Step 5.

W4 creates no response spool, W5 effect/release behavior, content-intake L14 authorization, final intake profile selection, or W6 certification. Foreground fairness uses the one K1 finite-delay admission rule and one host HeavyPhase.

### W5 — K4, exact release, Zone C

Execute in this order:

1. Sovereign Task 6 pre-W5 platform proof gate.
2. Sovereign Task 2.
3. Sovereign Task 3.
4. Sovereign Task 1.
5. Sovereign Task 5.
6. Remaining Sovereign Task 6 integration.
7. Silicon Task 7's W5-only cases from Step 1.
8. Silicon Task 7's W5 RED execution from Step 2.
9. Silicon Task 7 Step 5C.
10. Silicon Task 7 Step 10 spool/release handoff.
11. Runtime Task 5 Steps 5A and 5B direct/synthetic-effect retirement.
12. Content intake's one `semantics.layercell` `E` slice for L14/current-policy authorization.

The generic boundary order remains permit → anchor → arm → one crossing. Unknown state remains query/reconcile-only. No W4 spool back-reference is legal, and content intake remains production-dark until W6 selects the exact release profile.

### W6 — Runtime, replay, certification, cutover

Execute in this order:

1. Runtime Task 2 value-declaration prelude.
2. Semantic Task 8 audit-value/schema prelude.
3. Runtime Task 1 Part B outcome contract and final audit-envelope freeze.
4. Semantic Task 8 coordinator outcome behavior.
5. Runtime Tasks 2, 3, 4, and Task 5 remainder.
6. Runtime Task 6 aggregate certification.
7. Content intake's one `production.cutover` `A` slice that freezes the exact release-selected profile Artifact ID.
8. Prove final all-seven-slice content-intake production reachability while visibility remains dark.
9. Runtime Task 7 authoritative outcome cutover.

Task 6 records `.notRequested` when no 40/30 claim was requested. A requested claim must pass its complete two-device, two-block, two-sustained-run, rational-rank, 450-bin `phys_footprint`, and checked-integer-slope protocol before it may be reported.

## Cross-Domain Completion Gates

Every final W6 closure must prove:

| Area | Required terminal |
|---|---|
| Architecture | exactly 14 LayerCores, 4 Kernels, 4 ControlRings, 7 planes; no duplicate owner |
| Admission | exact predecessor-derived `Pw → Cw → Sw → CAS → attestation` chain through W6 |
| Owner Ledger | 7 controlled docs, 4 addenda, reciprocal anchors, append-only lifecycle, declared/active cumulative equality |
| Findings | exactly 74 QRM plus 39 source-review closures in Cw; external 45 remains unverified and non-counting |
| Retrieval | hard prephysical eligibility, snapshot-bound lanes, one R6 Market, one context compiler |
| Grounding | small-model proposal-only with deterministic validation and complete A/C/S/P/R lineage |
| Context | Provider/profile selection before exact compilation; adaptive local/API budgets; independent windows and epoch fences |
| Publication | buffered spool, full verifier suffix, pinned source, sink query/reconcile, once-only handoff |
| Effects | separate model/compensation and authorized-input causality; K3-only branch/ordinal/instance |
| State | prepare, optional effect continuation, invisible stage, L14/K4 attestation, expected-parent activation |
| Provider egress | nonsecret materialization, content-free credential version, one post-handoff resolution, unknown query/reconcile |
| App Agent | root/Session CAS, one App Agent and one logical Main per Session, model-independent identity |
| Recognition | exact guest-only mechanical enforcement or fully governed recognition; no middle state |
| Multi-agent | purpose-minimal capsules, no peer calls/shared scratchpad, correlated evidence not independent consensus |
| NextQuestion | closed source union, zero to five candidates, at most one card, explicit tap only |
| Studio/publication | Provider-backed Studio disabled; fixed deterministic Studio uses non-answer mini-release; zero-Provider output cannot become visible final publication |
| Web/intake | minimum disclosure, untrusted-source isolation, provenance/citation binding, bounded parser/containment receipt |
| Durable content | content-free default; W2 exact-purpose Decision Gate and one reopened approved/disapproved disposition; no encrypted-write exception without authorization |
| Reasoning | information-sufficiency phases, minimum clarification, deterministic cycle/budget termination |
| Learning/RSI | complete split/holdout/canary/field/adoption order, 12 legacy retirements, one K3 invalidation CAS, no self-adoption |
| Recovery | owner-private state facet plus boundary facet, no blind replay, no recovery super-owner |
| Artifact Mesh | exact four E/A slices, final-W1-Pw-bound 40-row device matrix, lab exclusion, honest status |
| Heavy work | one host HeavyPhase, finite delay, exact memory graph accounted once |
| V2 | exactly seven features and 21 rules; zero shipping reachability; every rule executes and mutates |
| Rollback | expand/contract round trip or explicit roll-forward-only operator contract |
| Performance | `.notRequested` or separately authorized complete claim protocol; never an unconditional gate |

## Terminal-State Rules

- `BLOCKED_SOURCE_DRIFT`: source changes during forensic capture.
- `BLOCKED_DESTINATION_DRIFT`: candidate destination preimage differs from a reviewed import row.
- `BLOCKED_IMPORT_REVIEW`: one production row remains unreviewed or ambiguous; `BLOCKED_C3_REVIEW` is a reason code beneath this terminal, never a new top-level terminal.
- `BLOCKED_EXTERNAL_BOOTSTRAP`: protected root, external service, catalog, profile, policy, or attestation is absent; `BLOCKED_EXTERNAL_SERVICE_BINDING`, `BLOCKED_BOOTSTRAP_CONTRACT_HANDOFF`, and `BLOCKED_NON_LITERAL_GATE_PROGRAM` are reason codes beneath this terminal, never new top-level terminals.
- `BLOCKED_LINEAGE_TRANSACTION`: candidate tree, parent, forensic ref, or atomic ref state differs.
- `BLOCKED_PAYLOAD_OBJECT_AVAILABILITY`: the immutable Pw object is not externally pinned and host-reopened under the signed proposal contract.
- `BLOCKED_PREW0_EVIDENCE`: one of 113 closures, release projections, reachability, closure, V2, or gate evidence is missing.
- `BLOCKED_K4`: real release/device/challenge/external-reopen proof is absent or invalid.
- `BLOCKED_ARTIFACT_MESH_DEVICE_RECOVERY`: any mandatory device matrix row is unexecuted, including protected-data unavailability.
- `pendingAdmission`: protected ref equals `Sw` but final attestation is absent; no next wave derives.
- `quarantinedAdmission`: ref, intent, CAS audit, attestation, or supersession lineage disagrees.
- `admitted`: protected ref equals `Sw`, receipt validates, and the same successful CAS has a valid finalized external attestation.

The external service's internal `finalized` state maps only to the program
terminal `admitted` and returns an authenticated `AdmittedWaveV1`.
Every nonfinal result raises the Bootstrap-owned
`AdmissionTerminalError`: `pendingAdmission` and `quarantinedAdmission`
remain those exact typed terminals, while internal `blocked` maps to one of
the exact `BLOCKED_*` terminals above plus one required closed reason code.
`quarantinedAdmission` also requires one closed reason; only
`pendingAdmission` carries null. The error cannot widen the four-method return
type or escape as a fifth spelling.
`EvidenceAssemblyResult` is service-internal and is never a runner-visible
success or terminal.

No blocked, pending, quarantined, local-preflight, unit-test, simulator, projection-only, or candidate-authored result may be relabeled admitted.

## Program Self-Review

- [x] The sole candidate lineage is adopted; its one frozen initial delta is
  committed by C0 Task 1, and no second candidate worktree is created.
- [x] Dirty source preservation and destination-preimage CAS are assigned to the C0 child.
- [x] B0 is minimal, externally attested, and the sole parent of preW0 Pw.
- [x] The authority/bootstrap dependency is explicitly interleaved and non-circular.
- [x] `Pw` contains no self-claiming result; all 113 and reachability/closure/V2 result evidence is in `Cw`.
- [x] W0 Pw is frozen before K4 runs.
- [x] K4 derives release identity from authority, never an environment variable.
- [x] Artifact Mesh has separate Task-0 preflight and final-W1-Pw proof phases.
- [x] `SampleHost/Package.swift` exclusion and the exact 26+14 matrix belong to the Artifact child.
- [x] CoreAI convergence is non-executable traceability, not a sixth domain plan.
- [x] The W1-W6 task/step mapping follows the incumbent plan schedules.
- [x] Semantic Task 1 W1; the canonical Decision Gate plus Task 2/4A W2;
  Task 4B W3; every W3/W4 RED, implementation, GREEN, and split-commit slice
  of Tasks 5/6; and Task 8 W6 are present.
- [x] Silicon W4 preserves Tasks 2→3→4→5→6 and Task 7's
  RED→3→4→policy/binding reopen→5B→6→7→8→9 order; W5 runs its own Task-7
  RED before Steps 5C/10.
- [x] Sovereign Task 4 W2 and the W5 pre-gate/2→3→1→5→6 order are present.
- [x] Runtime W6 prelude and final-envelope order is present.
- [x] The C3 learning/RSI/Main-Sub safety freeze is a W0 gate.
- [x] Provider-backed Studio and zero-Provider publication remain dark.
- [x] Performance is optional through a closed `.notRequested | requested` decision.
- [x] Authority convergence makes all seven controlled-document execution
  surfaces repository-relative and Python-hermetic before W1.
- [x] Five executable child plans own code-level TDD; this program file does not duplicate their implementation.
