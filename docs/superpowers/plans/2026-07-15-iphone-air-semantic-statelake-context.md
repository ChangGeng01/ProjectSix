# iPhone Air SemanticStateLake and Exact Context Convergence Implementation Plan

> **Forward development status (2026-08-29):** Superseded by [Qinao single-developer Git and lightweight PR design](../specs/2026-08-29-qinao-single-developer-git-and-lightweight-pr-design.md). External authority closure was never completed, and no historical authority is retroactively claimed. The single developer selected ordinary Git plus lightweight PR review; former source-admission, controlled-document, signer/trust-root, controller/CAS, authority-receipt, registry, and quorum gates are retired for forward development. Historical facts and hashes remain evidence; a historical non-authority limitation remains a forward gate only when the superseding design explicitly restates it.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the existing K3 event truth, scoped memory façade, L8 retrieval mechanisms, cache contract, and context compiler into one immutable, Artifact-Mesh-addressed L8→L7→L3 semantic state path with exactly one workspace/Attempt authority closure, one event sequence, one ordered lane watermark representation, one pre-query physical eligibility gate, one post-retrieval global hard gate, one erasure closure, and one token-packing owner.

**Architecture:** `BASEventLogEntry`/`BASEventLogStorage`/`BASSQLiteEventLogStorage` remain the only K3 event-order, integrity, authoritative-scope, deletion-epoch, and erasure-rank authority; production SQLite uses its one file/WAL with `synchronous=FULL`, while FTS/vector/temporal/entity/cache databases are watermark-bound replayable projections only. Every semantic snapshot carries the Contracts Task 2A `BASTurnOperationRef` already installed in the active Attempt head and the exact ordinary Artifact Mesh ID of one versioned calendar policy. `current`/`day`/`week`/`month`/`archival` memory is expressed by immutable projection manifests over EventLog ranges, one canonical bitemporal interval, and optional sealed lossless checkpoints—not by five mutable memories or a horizon-to-horizon truth chain. The EventLog `sessionID`/legacy `turnID` is only that root's bounded, reversible compatibility projection and must decode back to the same ref at open, reopen, lifecycle append, join, replay, and late-result gates. `QinaoMemory` becomes a scope-requiring façade over that K3/StateLake path and stores neither frontstage truth nor completed-looking deletion truth. Before any SQL/FTS/ANN/Rust/Metal/rerank/context/grounding mechanism is touched, L7's compiled eligibility constraints are validated and lowered into that lane's physical partition/predicate; candidate-specific hard eligibility runs before the bounded R5 grounding proposal and is deterministically revalidated in R6 after proposal validation and before conflict/State-Market scoring. The only new production owners remain the allowlisted immutable snapshot/barrier contracts, `BASStateRequirementPlanner`, snapshot coordination, and the cross-lane join/hard-gate/State-Market seam. Only after R6 completes may `BASContextCompiler` absorb the duplicate `CognitionKernel` compaction/render/fingerprint pass and perform exact tokenize-once packing; semantic/scoped/turn compilers only project inputs. All caches consume one exhaustive `BASCacheScopeContract` and remain derived, disposable projections.

**Tech Stack:** Swift 6, SwiftPM, Foundation concurrency, existing SQLite/WAL and event-log integrity chain, existing Artifact Mesh contracts, existing L8/RAG/vector/FTS/temporal/entity mechanisms, XCTest/Swift Testing.

## Prerequisites

- Before any task, run the machine OwnerLedger/CreateGate exactly as `python3 scripts/check_qinao_owner_ledger.py --root "$ROOT" --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"`. The ledger at `docs/superpowers/specs/qinao-owner-ledger-v1.json` and that verifier are the sole machine ownership gate; this plan extends only the four reviewed `M` rows declared below and may not add another ledger, CreateGate, or owner inventory.
- Implement Contracts Task 2A first. This plan consumes its canonical `BASTurnOperationRef`, `BASTurnBranchRef`, `BASProviderStepPurpose`, `BASProviderOutputRole`, complete exact-branch `BASProviderExecutionRef`, `BASProviderVisibilityMode`, installed `BASProviderBranchPolicy`, active-Attempt root installation, bounded legacy turn-ID encode/decode codec, and injected `BASProviderBranchControlPort` request/receipt API. Semantic code never redeclares those types, initializes an operation root from `String`/UUID/session/request text, or adds an operation/branch/ordinal/claim/source/visibility registry.
- Implement the Artifact Mesh contracts and `BASArtifactStorePort` from `2026-07-15-iphone-air-contracts-layercell.md` before Task 4. Snapshot, requirement-plan, lane-result, State-Market, budget-receipt, and compiled-descriptor domain payloads never contain their own artifact ID.
- The Silicon execution plan must expose one `executionBindingArtifactID: BASArtifactID` before Task 7 is wired to production. This plan does not accept a caller-supplied list of quality/profile/ABI/fallback digests.
- Complete the Silicon plan's `BASMemoryAdmissionContextVerificationPort`, `BASMemoryAdmissionContextGateway`, and `BASProcessMemoryLedger.processShared` before Task 5's W4 memory-admission substep and Task 8 production wiring—not before Task 5's pure W3 lane/FTS implementation or Task 6's W3 test-injected grounding contract. HostKit captures the turn's one capability-snapshot artifact in one per-turn resolver; semantic payloads never copy that ID, epoch, context version, cap, policy digest, or attestation merely to carry memory authority.
- The Runtime Replay plan and its replay-manifest payload carry only `semanticSnapshotArtifactID: BASArtifactID`, never a copied watermark field/vector. Replay reopens that Artifact Mesh payload and validates its sole canonical ordered `[BASLaneWatermark]` against the integrity-bound source event head; it may not embed snapshot bytes, use a raw manifest string reference, or introduce `BASReplayLaneWatermark`.

## Global Constraints

- The minimum deployment target is iOS 27 for every workspace-owned iOS package slice, app, and extension target touched by implementation.
- Every self-ID-free payload independently ordinary-put through Artifact Mesh must conform to `BASSchemaVersioned`, visibly store `schemaVersion`, and expose an explicit public initializer whose first parameter is `schemaVersion: String = Self.currentSchemaVersion`. Every payload byte used for ordinary put, Artifact identity, or reopen must pass through the Contracts-owned `BASGovernedArtifactPayloadCodec`; raw `JSONEncoder`/`JSONDecoder`, alternate canonical encoders, caller-selected accepted-version sets, and field access before version rejection are forbidden. Each such payload has exactly one `BASEBrainSchemaGovernanceRegistry` entry plus exact current round-trip, pinned first/current-v1 fixture, missing/future-version rejection, and cross-target default-version initializer fixtures. A first-governed 1.0.0 launch must not fabricate a migration. Embedded/transient values are unregistered and may persist only inside their one governed parent.
- `BASEventLogEntry`, `BASEventLogStorage`, and `BASSQLiteEventLogStorage` are the sole event sequence, high-water mark, replay order, integrity-chain, authoritative scope/deletion epoch, and erasure-rank owners. Production K3 uses one SQLite file, one WAL, the existing connection/write owner, and `synchronous=FULL`; do not create another event log, control WAL, cursor timeline, lifecycle ledger, erasure ledger, or hash chain. Projection WALs are rebuildable and cannot participate in authoritative commits.
- Semantic snapshot composition requires the existing SQLite row-integrity option (or the in-memory conformer's equivalent shared digest helper) to be available. Missing integrity is a typed failure; no caller may synthesize a head or start a parallel chain.
- Semantic snapshot lifecycle is represented by typed events in the existing event log. A derived lookup/index may be added only inside the existing storage transaction and must be rebuildable from event rows; it is never a second truth.
- A `BASStateReadSnapshot` is an unsigned Artifact Mesh payload. It carries the exact `turnOperationRef: BASTurnOperationRef` but has no `snapshotID`, `snapshotRoot`, `artifactID`, storage locator, signature, or self digest. Callers carry its envelope-supplied `semanticSnapshotArtifactID: BASArtifactID`.
- `BASCalendarPolicyPayload` is the only calendar/windowing policy identity. Its Artifact Mesh ID is bound into each snapshot and horizon manifest; a digest is derived only by reopening/canonical-encoding that artifact and is never accepted as a copied `calendarPolicyDigest` field. A timezone, locale, calendar, tzdb/ICU/OS rule-build, week-rule, day-boundary, or DST-resolution change creates a new artifact and invalidates affected projections without rewriting source events.
- `BASBitemporalInterval` is the only persisted temporal interval: valid time is `[worldFrom, worldTo)` and transaction time is `[eventOffsetStart, eventOffsetEnd)`. Candidates, temporal projections, horizon manifests, corrections, retractions, and replay reuse it; parallel `validFrom`, `validUntil`, `observedAt`, or wall-clock-as-transaction fields are forbidden. Observation time/revision remains provenance only.
- `BASMemoryHorizon` has exactly `current`, `day`, `week`, `month`, and `archival`. Every `BASMemoryHorizonManifestPayload` is an ordinary immutable Artifact Mesh projection over exact EventLog ranges/root, bitemporal coverage, provenance, loss, calendar policy, and epochs. Higher horizons replay the original EventLog range or a sealed lossless checkpoint with proven range/root and replay equivalence; lower-horizon manifests are discovery hints only. Pruning is denied without that checkpoint plus retention authorization.
- There is exactly one semantic read-version representation and storage location: `BASStateReadSnapshot.orderedLaneWatermarks: [BASLaneWatermark]`, canonically ordered by `BASSemanticLaneID.rawValue`. No lane-result, join, State-Market, audit/shadow, manifest, or replay payload may declare a watermark field/vector. Those consumers carry `semanticSnapshotArtifactID` plus lane/source IDs and, whenever they need a version, reopen that snapshot through the injected Artifact Mesh, verify the unique canonical ordering, and verify its integrity-bound source event head. `BASArtifactReadVersion`, projection-version vectors, dictionary watermarks, and replay-specific watermark wrappers are forbidden.
- Every new cross-plan reference to an artifact, snapshot, receipt, signature, manifest, plan, query, result, selection, budget receipt, or descriptor is `BASArtifactID`; operation/branch lineage is respectively `BASTurnOperationRef`/`BASTurnBranchRef`. A raw EventLog `sessionID`, `turnID`, or `branchID` remains only inside the Contracts Task 2A legacy codec and storage adapters, must round-trip to the exact typed ref, and cannot mint authority, select an Attempt, open a snapshot, accept a result, or define a cache/idempotency domain by itself.
- Existing `BASL8RoutedMemoryService`, `BASRAGRetriever`, vector stores, `BASMemoryUsageTracker.searchNotesFTS(query:)`, `BASTemporalMemoryField`, and `BASSharedStateGraph` remain retrieval/projection mechanisms. Every query first validates one canonical `BASCompiledLaneEligibilityPredicate` against the current workspace/window/Attempt, snapshot, purpose, sensitivity, authority, policy epoch, and deletion epoch, then lowers it into a non-empty physical partition and mechanism-native predicate. A denied/missing/empty partition returns before SQL/FTS/ANN/Rust/Metal/context construction/reranking/grounding and produces no membership-dependent timing. The repository currently has no standalone BM25 owner; Task 5 extends the existing FTS5 query in place by reading SQLite FTS5's hidden `rank` column only after that predicate is bound. It creates no BM25 ranker, engine, table, or index.
- Existing `BASMemoryEligibilityJudge`, `BASMemoryEligibilityDecision`, and `BASMemoryConflictCluster` are lane evidence only. They cannot admit a candidate, resolve a cross-lane conflict, or authorize an exact answer.
- New `BASStateCandidate`, `BASHardEligibilityDecision`, and `BASClaimConflictSet` are the canonical cross-lane global authority. Hard eligibility runs before market scoring and is non-compensable.
- The pre-query predicate is an executable projection of the same L7 policy, not a second eligibility owner. Post-retrieval `BASGlobalHardEligibilityGate` first produces the bounded R5 grounding-eligible reservoir, then R6 reopens the same snapshot and exact Provider proposal receipts and reruns that same hard gate against current consent/deletion/policy/freshness/governance facts before conflict resolution or State-Market scoring. Grounding is proposal-only; neither its initial input gate nor its output may substitute for R6 revalidation.
- `QinaoMemory` is a façade only. Admission, recall, `frontstageBundle`, and forget operations require the canonical authority/workspace/window/Attempt binding and delegate to the one K3/EventLog plus StateLake owner. Missing scope denies; a process-global dictionary, default-all frontstage recall, local deletion ledger, or hard-coded cache-ref completion claim is forbidden.
- Memory event truth carries an encrypted content `BASArtifactID`/content commitment bound to the winning event, never a process-only content cache that can combine winner metadata with loser bytes. Replay and restart reopen the same content artifact; an unavailable artifact fails closed rather than returning empty or hybrid content.
- Erasure is a monotonic K3 saga: the first transaction quarantines eligibility, advances `deletionEpoch`, fences old snapshots/Attempts/grants/caches, and appends the request. Completion requires one independently persisted purge-or-absence ACK for each exact owner: process RAM, frontstage, spill, compiled context, FTS, vector, temporal, entity, linguistic, session, KV, prefix, neural, verifier, result, Provider, artifact payload, controlled backup, and export; only then may a closure rescan run. An aggregate/fan-out ACK cannot stand in for any member. Missing owners, swallowed errors, wall-clock tombstone pruning, or unreachable Provider/backup yield permanent `erasure_indeterminate`, never `.completed`.
- Every cache uses one `BASCacheScopeContract = { BASPhysicalContentKey, BASAcquisitionScope }`. It binds model/modality/content/provenance/private compartment/storage domain/tokenizer/template/StateABI/position/token boundary plus authority/workspace incarnation/window/snapshot/session/role/Attempt generation/compartment/purpose/policy/capability/restoration/deletion/kill epochs and deadline. Scope validation happens before bytes, membership indexes, Rust/Metal state, or cache-hit timing are touched. Cross-window reuse requires an explicit shared compartment authorized to both windows; same session text or cache filename is never sufficient.
- Required-lane failure is typed and terminal for exact grounding. Optional degradation is represented by one canonical `BASCoverageVector`; late results may only enter a declared later logical epoch.
- `BASContextCompiler` in `ContextCompilerCore.swift` is the only component allowed to choose/drop/preserve final segments, compact, tokenize, allocate exact token budgets, render/order final prompt bytes, or hash/fingerprint the compiled token stream. `CognitionKernelCore.swift` must not perform a second retention/drop, render, policy/context signature, or fingerprint pass after calling it.
- `BASSemanticContextCompiler`, `BASScopedContextCompiler`, and `BASTurnContextCompiler` only project typed inputs into `BASContextCompiler`; they never invoke a tokenizer, own another packing policy, or persist a compiled descriptor.
- Canonical payloads use ordered arrays. Unordered source dictionaries/sets are normalized by UTF-8 raw-value ordering before canonical encoding; a `Dictionary` or `Set` is never encoded directly.
- No new package dependency, thread pool, blocking semaphore, timer system, SQLite wrapper, FTS engine, vector index, or ranking engine is introduced.
- Semantic retrieval and its Artifact Mesh buffers are ordinary `BASProcessMemoryLedger` clients by default. Only dense retrieval under an explicitly certified heavy profile may request `.heavy`; all five lanes still share the ledger's one process-wide heavy-owner CAS with neural work. HostKit reuses one internal generic scoped helper in an existing file—no new type, actor, reservation map, heavy-owner map, file, or raw-cap parameter.
- Every persisted `BASSchemaVersioned` semantic type is registered in `BASEBrainSchemaGovernanceRegistry` in the same task that adds it.
- Shadow integration cannot mutate the legacy request, selected result, release decision, state commit, tool/effect dispatch, or public `BASEBrainTurnResult`.

## Authority and File Map

| Classification | File | Responsibility after convergence |
|---|---|---|
| M — Create | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticStateLakeContracts.swift` | Only cross-target vocabulary for snapshot/barrier/watermark, bitemporal/calendar/horizon projection, requirement/query/result, canonical global candidate/coverage/conflict/selection, and typed lifecycle payloads |
| E — Modify | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLog.swift` | Expose typed event-log head and conditional append; add semantic lifecycle event kind; keep one sequence API |
| E — Modify | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift` | Keep the sole K3 file/WAL/write owner, set authoritative mode to `synchronous=FULL`, and atomically own scope/deletion epoch, erasure rank/ACK/rescan, head/CAS, lifecycle, and integrity advance |
| M — Create | `BehavioralAISubstrate/Sources/BASOrchestration/BASStateRequirementPlanner.swift` | Pure L7 requirement-plan and snapshot-bound query projection |
| M — Create | `BehavioralAISubstrate/Sources/BASMemory/BASSemanticSnapshotCoordinator.swift` | Freeze existing lane views, store the immutable snapshot through ordinary Artifact Mesh `put(identityCore:headUpdate:)`, and append lifecycle events to the existing event log |
| E — Modify | `BehavioralAISubstrate/Sources/BASMemory/BASMemoryUsageTracker+ReplayAuditFTS.swift` | Extend the current notes FTS5 query with hidden `rank`/built-in BM25 order and a bounded limit; no new lexical owner or index |
| A — Modify | `BehavioralAISubstrate/Sources/BASHostKit/BASL8RoutedMemoryService.swift` | One generic adapter over injected existing lane mechanisms plus the one internal HostKit memory-scope helper reused by Task 8/runtime; no indexing/ranking/storage/memory authority |
| A/E — Modify | `QinaoRuntimeSDK/Sources/QinaoMemory/QinaoMemory.swift` and `QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift` | Scope-requiring façade and auto-bundle adapter over the same K3/StateLake authority; no local truth or scope-free injection |
| E/A — Modify | current KV/prompt/session/cache files | Consume the canonical `BASCacheScopeContract`; retain bytes only as disposable projections and reject before lookup on scope mismatch |
| M — Create | `BehavioralAISubstrate/Sources/BASOrchestration/BASSemanticStateMarket.swift` | Only snapshot join, global hard eligibility, cross-lane conflict, coverage, and final State-Market seam |
| E — Modify | `BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift` | Only tokenize-once exact packing and compiled-context descriptor owner |
| A/E — Modify | `BehavioralAISubstrate/Sources/BASOrchestration/CognitionKernelCore.swift` | Delegates once to `BASContextCompiler`; owns no compaction, render, ordering, signature, or fingerprint policy |
| A — Modify | `BehavioralAISubstrate/Sources/BASOrchestration/SemanticCompilerCore.swift` | Semantic input projection only |
| A — Modify | `BehavioralAISubstrate/Sources/BASOrchestration/ScopedContextCore.swift` | Scoped input projection only |
| A — Modify | `BehavioralAISubstrate/Sources/BASHostKit/EBrainTurnContextCompiler.swift` | Turn-budget/request projection only |
| E/A — Modify | `BehavioralAISubstrate/Sources/BASMemory/MemoryHorizonPersistenceCore.swift` and `EBrainKnowledgePlaneCore.swift` | Adapt existing horizon classification and temporal records to the canonical horizon/bitemporal contracts; no new store or temporal authority |
| E/A — Modify | `BehavioralAISubstrate/Sources/BASHostKit/BASMemorySleepConsolidationPass.swift`, `BASSleepConsolidationDriver.swift`, and `BASConsolidationCheckpoint.swift` | Reuse the current off-turn pass to emit Artifact-Mesh horizon projections/checkpoint evidence over EventLog ranges; never become source truth or a second scheduler |
| E — Modify | `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator.swift` | Existing turn coordinator owns the opt-in integration mode and injected shadow dependencies |
| E/A — Modify | `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurnStagesMemoryRisk.swift` | Shadow composition through existing turn coordinator; no second authoritative result path |
| E — Modify | `BehavioralAISubstrate/Sources/BASOrchestration/BASRuntimeAuditProjectionsBundle.swift` | Existing audit bundle owns the observation-only semantic projection |

Production-file creates are limited to the four M rows above. Test files are allowed to be new. Horizon/calendar/bitemporal work is E/A over those existing files plus value declarations inside the already allowlisted contracts M; it creates no fifth M, production SQLite store, schema owner, horizon store, lane index, context compiler, replay watermark, or shadow coordinator.

## W0–W6 Delivery Placement

The implementation sequence follows the master specification's delivery waves, not this document's historical task numbering:

- **W0 — owner/write freeze:** run the shared OwnerLedger/CreateGate and make no semantic production edit.
- **W1 — contracts / TurnOperation / Provider inversion:** execute Task 1's value-contract work after the contracts plan's W1 prerequisites. Consume the exact `BASTurnOperationRef`/`BASTurnBranchRef` and legacy codec from Contracts Task 2A; TurnOperation and Provider inversion remain owned by their sibling plans and this plan neither redefines nor bypasses them.
- **W2 — K3 + memory + erasure:** execute Task 2, then Task 4A immediately, before Task 3. This is the only authoritative event/scope/deletion/erasure and Qinao-memory convergence wave.
- **W3 — StateLake + context:** execute Tasks 3, 4, 4B, Task 5's pure snapshot-bound lane/FTS work, Task 6's pure join/typed-grounding/test-injected port work, and Task 7 in dependency order. W3 neither creates nor consumes a production process ledger and never performs a physical Provider call.
- **W4 — silicon:** make no new semantic owner. Atomically install and reopen one Contracts `BASProviderBranchPolicy` plus the one Silicon `BASSiliconExecutionBinding` that references it, and require exact `stepRuleID` membership before enabling any production semantic Provider path. Only after that gate and the process-memory receipt may composition wire Task 5's sole `withProcessMemoryAdmission` helper and Task 6's production small-model grounding adapter over the shared `BASProviderBranchControlPort`. The W4 adapter adds no ordinal/claim/source/visibility map and no second Provider policy; partial policy/binding installation leaves production R5 disabled.
- **W5 — K4 / release / Zone C:** make no semantic owner change; consume the sovereign release plan's completed boundary.
- **W6 — runtime / certification:** first execute Task 8's audit-value-only prelude: freeze `BASSemanticStateShadowObservation` and the complete first-governed `BASRuntimeAuditProjectionsBundle` 1.0.0 shape/codec/registry, with no semantic execution or put. Commit that receipt before Runtime Task 1B freezes its final envelope reference field. Then execute Task 8's shadow-only coordinator integration and repeated closure suite; behavior only returns/populates the frozen bundle value.

`R0`–`R6` are logical retrieval/grounding subphases spanning W3 Tasks 5–6 and the same ordered W4 production-grounding wiring; they are never aliases for W0–W6 delivery waves, owner work, runtime work, or certification work. W3 proves the complete state machine with a bounded test-injected proposal port and performs no physical Provider call. W4 substitutes a thin proposal adapter that delegates planned execution to Silicon's sole K3-backed invocation seam while preserving identical R5/R6 contracts and order.

The retrieval phase machine is canonical and byte-matches the OwnerLedger; an implementation cannot flatten it into an unordered all-lane fan-out:

1. `R0 compiled_pre_physical_eligibility` freezes the snapshot/watermarks and lowers the exact authority/scope/sensitivity/policy/deletion predicate before any physical mechanism.
2. `R1 sql_metadata_exact_fts_bm25` executes the mandatory cheap lexical/metadata phase whenever state is required.
3. `R2 temporal_episode` executes or emits a deterministic skip receipt from the requirement-plan trigger.
4. `R3 entity_relation` executes or emits a deterministic skip receipt from the requirement-plan trigger.
5. `R4 dense_semantic` executes only for an explicit dense requirement or a still-open required-coverage deficit after the structured phases. It may overlap R2/R3 only when it was explicit at plan freeze and the certified MemoryLedger profile proves positive marginal value; it never starts speculatively.
6. `R5 dedupe_fusion_bounded_grounding_proposal` applies the pre-grounding hard-eligibility pass, then delegates lane-local dedupe, source/correlated-lane caps, finite-`k` reciprocal-rank fusion, and reservoir truncation to the existing pure Rust `bas-retrieval-ranker` RRF owner through its one extended narrow ABI/Swift bridge. `BASSemanticStateMarket` orchestrates and verifies canonical inputs/outputs but contains no Swift fusion formula/ranker. It builds the bounded grounding-eligible reservoir and invokes the bounded proposal port exactly once to produce a proposal-only value. W3 uses a deterministic test-injected conformer; W4's production conformer validates the semantic binding and delegates once to Silicon's existing planned-execution seam. Only Silicon's `BASProviderAttemptExecutor.executeExactlyOnce` over `BASOrganAdapter.executePlanned` may perform K3 allocation/claim and the physical Provider call. The proposal cannot admit a candidate, resolve a conflict, select context, open the `BASProviderVisibilityMode` UI gate, mutate state, or authorize an answer.
7. `R6 grounding_validation_hard_revalidation_conflict_market` first deterministically validates that proposal against the exact R5 reservoir, operation root, Attempt/generation, snapshot, model lineage, ordered candidate keys, byte/token bounds, and output schema; then it reopens the same snapshot, reruns global hard eligibility against current epochs, resolves conflicts, and runs State Market. Invalid/missing/late grounding evidence fails or degrades only according to the frozen requirement plan; it is never silently treated as validated.

Only after the R6 receipt is durable and still bound to the same `BASTurnOperationRef` may the one `BASContextCompiler.compileExact` call execute. Context compilation is a post-R6 consumer, not part of R6 and not callable from the grounder.

Every phase persists an `executed`, `skipped_not_required`, `denied`, or `failed` receipt in phase order. A required phase cannot be skipped because an earlier score looks good; a result arriving after its phase/Attempt/generation closes is evidence only and cannot mutate the snapshot, coverage, market, or context.

## Shared OwnerLedger M Rows and Candidate Manifests

The installed shared ledger already contains exactly these four granular `M` OwnerCards and `create_permissions`; implementation may update evidence/status but must not bundle them into one StateLake owner. Each permission contains the one exact workspace-relative path shown; no package-relative `Sources/...` abbreviation is valid.

| Owner ID | Authority symbol | Mutable-state owner | Storage/recovery owner | Exact create path | `create_proof_task` |
|---|---|---|---|---|---|
| `state.snapshot-contracts` | `BASSemanticStateLakeContracts` | `none (pure value contracts)` | ordinary Artifact Mesh/K3 references | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticStateLakeContracts.swift` | `semantic-statelake-context:Task 1` |
| `state.requirement-planner` | `BASStateRequirementPlanner` | `none (pure planner)` | ordinary Artifact Mesh plan payload | `BehavioralAISubstrate/Sources/BASOrchestration/BASStateRequirementPlanner.swift` | `semantic-statelake-context:Task 3` |
| `state.snapshot-coordinator` | `BASSemanticSnapshotCoordinator` | existing K3 lifecycle/Artifact Mesh heads | Artifact Mesh snapshot plus K3 watermarks | `BehavioralAISubstrate/Sources/BASMemory/BASSemanticSnapshotCoordinator.swift` | `semantic-statelake-context:Task 4` |
| `state.snapshot-market` | `BASSemanticStateMarket` | `none (pure join/gate/market)` | ordinary Artifact Mesh selection payload | `BehavioralAISubstrate/Sources/BASOrchestration/BASSemanticStateMarket.swift` | `semantic-statelake-context:Task 6` |

Before the RED step of Tasks 1, 3, 4, and 6, create an ephemeral candidate manifest and run `python3 scripts/check_qinao_owner_ledger.py --root "$ROOT" --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json" --candidate-manifest <manifest>`. Each manifest uses exact snake-case fields `schema_version`, `owner_id`, `classification`, `candidate_path`, `authority_symbol`, `create_proof_task`, and `create_proof`; the proof object has the installed eight exact non-empty fields. The verifier rejects a missing row, path abbreviation, owner/symbol/task drift, a fifth semantic `M`, or reuse of one path for another owner. Candidate manifests are ephemeral evidence, not another committed policy source.

For **each** of Tasks 1, 3, 4, and 6, add `docs/superpowers/specs/qinao-owner-ledger-v1.json`, `scripts/check_qinao_owner_ledger.py`, and `scripts/test_check_qinao_owner_ledger.py` to that task's Files and staging set. In the atomic change that creates its first allowlisted production path, append the path to the matching OwnerCard's `evidence_paths` and transition `approved_missing → converging`; append every later allowlisted path in its own creation change. Remove each `current_conflicts` item only with exact freeze/retirement source evidence and green tests; move a view to `allowed_projections` only after proving it has no authority, mutable state, or independent recovery. Run both checker scripts after every step. Transition `converging → implemented` only after every allowlisted path exists and is evidence-listed, every task gate passes, and `current_conflicts == []`. On failure, roll back code paths, evidence, conflict/projection changes, and status together; early `implemented` is forbidden.

---

### Task 1: Canonical Semantic Snapshot, Lane, and Global-Authority Contracts

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify: `/Users/changgeng/Project/Project06/Project06/scripts/check_qinao_owner_ledger.py`
- Modify: `/Users/changgeng/Project/Project06/Project06/scripts/test_check_qinao_owner_ledger.py`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticStateLakeContracts.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLog.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticStateLakeContractTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`

**Reuse Decision (M + E) — OwnerLedger `owner_id: state.snapshot-contracts`:** Current event, memory, eligibility, conflict, and cache types are source-specific and do not express an immutable multi-lane snapshot, a canonical cross-lane decision, one workspace/window/Attempt visibility closure, a pre-query physical predicate, an exhaustive cache scope, or an erasure-closure vocabulary. The new cross-target file remains the one allowlisted value-contract owner; adding these values does not add storage, retrieval, ranking, cache, erasure, signing, or event-sequencing authority.

Task-local M gate for `semantic-statelake-context:Task 1`: stage the ledger/checker/checker-test with the created source and tests; atomically add exact path permission/evidence and set `approved_missing → converging` on first create; remove conflicts only with proof; set `implemented` only after all declared paths/evidence/tests/gates exist and `current_conflicts == []`; roll back source, permission, evidence, conflicts/projections, and status together.

**Create Proof — `BASSemanticStateLakeContracts.swift`:**

1. Repository search: `rg -n 'StateReadSnapshot|LaneWatermark|StateRequirementPlan|BASHardEligibilityDecision|BASClaimConflictSet' BehavioralAISubstrate/Sources` finds no current immutable multi-lane owner; nearest candidates are `BASEventLogEntry`, `BASMemoryEligibilityDecision`, and `BASMemoryConflictCluster`.
2. Public/upstream search: Foundation supplies `Codable`, actors, collections, and clocks, but no domain snapshot/barrier or cross-lane eligibility contract.
3. Missing invariant: one Artifact-Mesh-addressed snapshot payload that is the sole owner of the ordered watermark vector, one global candidate/conflict/coverage vocabulary, one canonical bitemporal interval, one calendar policy, one five-case horizon vocabulary/manifest, and one typed scope/predicate/cache/erasure contract consumed by existing owners.
4. Extension alone is insufficient because putting cross-target semantic contracts into memory-specific files would invert `BASRuntimeCore ← BASMemory/BASOrchestration` dependencies; the new file contains values only.
5. Authority: contracts define values; mutable state remains in `BASEventLogStorage`; artifact storage remains in `BASArtifactStorePort`; failures are typed validation failures.
6. Dependency direction: `BASRuntimeCore` depends only on Foundation and its existing Artifact Mesh/event types; higher targets import it.
7. Compatibility: current memory candidate/eligibility/conflict types remain source evidence and are adapted once in Task 5/6; they are not deleted in this plan.
8. Duplicate-authority tests reject snapshot self IDs, any non-snapshot payload watermark field/vector, dictionary/replay watermarks, raw artifact references, duplicate lane watermarks, copied calendar digests, parallel validity/observation axes, a sixth horizon, a horizon manifest used as higher-horizon source truth, and any global allow derived solely from a lane-local allow.

**Interfaces:**
- Consumes: `BASArtifactID` and `BASSchemaVersioned` from RuntimeCore.
- Produces: `BASEventLogHead` in the existing event owner plus the nonempty canonical namespace/validator `BASSemanticStateLakeContracts`, `BASBitemporalInterval`, `BASCalendarPolicyPayload`, `BASMemoryHorizon`, `BASMemoryHorizonManifestPayload`, `BASAttemptVisibilityScope`, `BASCompiledLaneEligibilityPredicate`, `BASPhysicalContentKey`, `BASAcquisitionScope`, `BASCacheScopeContract`, `BASErasureRank`, `BASErasureProjectionOwner`, `BASErasureClosureReceipt`, `BASSemanticLaneID`, `BASLaneWatermark`, `BASStateReadSnapshot`, `BASStateRequirementPlan`, `BASLaneQuery`, `BASLaneResult`, `BASStateCandidate`, `BASHardEligibilityDecision`, `BASClaimConflictSet`, `BASCoverageVector`, `BASStateMarketSelection`, `BASStateSnapshotBarrierPort`, and `BASSemanticStateLane`.

- [ ] **Step 1: Write failing identity, ordering, and authority tests**

```swift
import XCTest
@testable import BASRuntimeCore

final class BASSemanticStateLakeContractTests: XCTestCase {
    func testCanonicalLedgerOwnerValidatesTheOnlyLaneOrder() throws {
        XCTAssertEqual(
            BASSemanticStateLakeContracts.canonicalLaneOrder,
            [.sqlMetadata, .exactLexical, .denseSemantic,
             .temporalEpisode, .entityRelation]
        )
        try BASSemanticStateLakeContracts.validateCanonicalLaneOrder(
            BASSemanticStateLakeContracts.canonicalLaneOrder
        )
        XCTAssertThrowsError(
            try BASSemanticStateLakeContracts.validateCanonicalLaneOrder(
                [.denseSemantic, .sqlMetadata]
            )
        )
    }

    func testSnapshotCanonicalizesOneOrderedWatermarkRepresentation() throws {
        let snapshot = try fixtureSnapshot(watermarks: [
            fixtureWatermark(.temporalEpisode, sequence: 8),
            fixtureWatermark(.sqlMetadata, sequence: 3),
        ])
        XCTAssertEqual(
            snapshot.orderedLaneWatermarks.map(\.laneID),
            [.sqlMetadata, .temporalEpisode]
        )
        XCTAssertThrowsError(try fixtureSnapshot(watermarks: [
            fixtureWatermark(.sqlMetadata, sequence: 3),
            fixtureWatermark(.sqlMetadata, sequence: 4),
        ]))
    }

    func testSnapshotPayloadHasNoSelfIdentityOrDictionaryWatermark() throws {
        let labels = Set(Mirror(reflecting: try fixtureSnapshot()).children.compactMap(\.label))
        XCTAssertFalse(labels.contains("artifactID"))
        XCTAssertFalse(labels.contains("snapshotID"))
        XCTAssertFalse(labels.contains("snapshotRoot"))
        XCTAssertFalse(labels.contains("laneWatermarks"))
        XCTAssertTrue(labels.contains("orderedLaneWatermarks"))
        XCTAssertTrue(labels.contains("calendarPolicyArtifactID"))
    }

    func testTemporalAndHorizonVocabularyHasOneCanonicalShape() throws {
        XCTAssertEqual(BASMemoryHorizon.allCases, [
            .current, .day, .week, .month, .archival,
        ])
        let candidateLabels = Set(
            Mirror(reflecting: fixtureCandidate()).children.compactMap(\.label)
        )
        XCTAssertTrue(candidateLabels.contains("bitemporalInterval"))
        XCTAssertTrue(candidateLabels.isDisjoint(with: [
            "validFromLogicalTime", "validUntilLogicalTime", "observedAtLogicalTime",
        ]))
        let interval = fixtureBitemporalInterval()
        XCTAssertLessThan(interval.validTime.worldFrom, try XCTUnwrap(interval.validTime.worldTo))
        XCTAssertLessThan(
            interval.transactionTime.eventOffsetStart,
            try XCTUnwrap(interval.transactionTime.eventOffsetEnd)
        )
    }

    func testCalendarPolicyAndManifestCarryArtifactIdentityNotCopiedDigest() throws {
        let calendar = fixtureCalendarPolicy()
        let calendarLabels = Set(Mirror(reflecting: calendar).children.compactMap(\.label))
        XCTAssertTrue([
            "calendarIdentifier", "localeIdentifier", "timeZoneIdentifier",
            "tzdbVersion", "icuVersion", "osTimeZoneRuleBuild",
            "firstWeekday", "minimumDaysInFirstWeek", "dayBoundary",
            "ambiguousLocalTimeResolution", "nonexistentLocalTimeResolution",
            "effectiveTransactionInterval",
        ].allSatisfy(calendarLabels.contains))
        XCTAssertFalse(calendarLabels.contains("calendarPolicyDigest"))

        let manifest = fixtureMemoryHorizonManifest()
        let manifestLabels = Set(Mirror(reflecting: manifest).children.compactMap(\.label))
        XCTAssertTrue([
            "horizon", "orderedSourceEventRanges", "sourceEventLogRootDigest",
            "bitemporalInterval", "orderedProvenanceArtifactIDs", "coverage", "loss",
            "calendarPolicyArtifactID", "policyEpoch", "deletionEpoch", "invalidationEpoch",
            "sealedLosslessCheckpointArtifactID", "checkpointReplayEquivalenceReceiptArtifactID",
            "orderedParentManifestHintArtifactIDs",
        ].allSatisfy(manifestLabels.contains))
        XCTAssertFalse(manifestLabels.contains("calendarPolicyDigest"))
        XCTAssertFalse(manifestLabels.contains("artifactID"))
    }

    func testOnlySnapshotPayloadDeclaresAWatermarkFieldOrVector() throws {
        let nonSnapshotPayloads: [Any] = [
            fixtureRequirementPlan(),
            fixtureLaneQuery(),
            fixtureLaneResult(),
            fixtureSelection(
                coverage: try fixtureCompleteCoverage(),
                conflictSets: []
            ),
        ]
        for payload in nonSnapshotPayloads {
            let labels = Mirror(reflecting: payload).children.compactMap(\.label)
            XCTAssertTrue(
                labels.allSatisfy { !$0.lowercased().contains("watermark") },
                "only BASStateReadSnapshot may declare a watermark field/vector"
            )
        }
    }

    func testEveryCrossPlanReferenceIsTypedArtifactID() throws {
        let query = fixtureLaneQuery()
        XCTAssertEqual(query.semanticSnapshotArtifactID, fixtureArtifactID("snapshot"))
        XCTAssertEqual(query.requirementPlanArtifactID, fixtureArtifactID("plan"))
        XCTAssertEqual(query.requestArtifactID, fixtureArtifactID("request"))
    }

    func testLaneQueryCarriesOneExactPreQueryEligibilityProjection() throws {
        let query = fixtureLaneQuery()
        XCTAssertEqual(query.compiledEligibility.laneID, query.laneID)
        XCTAssertEqual(
            query.compiledEligibility.semanticSnapshotArtifactID,
            query.semanticSnapshotArtifactID
        )
        XCTAssertFalse(query.compiledEligibility.allowedSensitivityLabels.isEmpty)
        XCTAssertTrue(query.compiledEligibility.requireGoverned)
    }

    func testCacheScopeContainsEveryPhysicalAndAcquisitionDimension() throws {
        let contract = fixtureCacheScopeContract()
        let physical = Set(Mirror(reflecting: contract.physicalContentKey).children.compactMap(\.label))
        let acquisition = Set(Mirror(reflecting: contract.acquisitionScope).children.compactMap(\.label))
        XCTAssertTrue([
            "modelIdentityArtifactID", "modality", "canonicalContentDigest",
            "orderedProvenanceArtifactIDs", "visibilityCompartmentID",
            "privateStorageDomainTag", "tokenizerDigest",
            "templateAndToolProtocolDigest", "stateABIDigest",
            "positionConvention", "acceptedTokenBoundary"
        ].allSatisfy(physical.contains))
        XCTAssertTrue([
            "authorityScopeArtifactID", "workspaceIncarnationID", "workspaceRefArtifactID",
            "windowRefArtifactID", "semanticSnapshotArtifactID", "attemptRefArtifactID",
            "generationVectorArtifactID", "sessionID", "sessionRole",
            "visibilityCompartmentID", "purpose", "restorationEpoch", "policyEpoch",
            "capabilityEpoch", "deletionEpoch", "killEpoch", "monotonicDeadlineNanos"
        ].allSatisfy(acquisition.contains))
    }

    func testErasureRanksAndProjectionOwnersAreClosedAndMonotonic() {
        XCTAssertEqual(BASErasureRank.allCases.map(\.rawValue), [
            "requested", "logically-quarantined", "key-destruction-pending",
            "key-absent", "projection-purge-pending", "projection-purge-acknowledged",
            "closure-rescanned", "completed", "erasure-indeterminate"
        ])
        XCTAssertEqual(Set(BASErasureProjectionOwner.allCases), Set([
            .processRAM, .frontstage, .spill, .compiledContext, .fts, .vector,
            .temporal, .entity, .linguistic, .session, .kv, .prefix, .neural,
            .verifier, .result, .provider, .artifactPayload, .controlledBackup, .export
        ]))
        XCTAssertTrue(BASErasureRank.projectionPurgePending.permitsTransition(to: .projectionPurgeAcknowledged))
        XCTAssertTrue(BASErasureRank.keyAbsent.permitsTransition(to: .erasureIndeterminate))
        XCTAssertFalse(BASErasureRank.completed.permitsTransition(to: .erasureIndeterminate))
        XCTAssertFalse(BASErasureRank.erasureIndeterminate.permitsTransition(to: .completed))
    }

    func testRequiredLaneFailureCannotBecomeExactGrounding() throws {
        let coverage = try BASCoverageVector(
            requiredLaneIDs: [.sqlMetadata],
            completedLaneIDs: [],
            failedLaneIDs: [.sqlMetadata],
            missingOptionalLaneIDs: [],
            failureReceiptArtifactIDs: [fixtureArtifactID("failure")]
        )
        let selection = fixtureSelection(coverage: coverage, conflictSets: [])
        XCTAssertEqual(coverage.terminalState, .requiredLaneFailed)
        XCTAssertFalse(selection.isGroundedForExactAnswer)
    }

    func testMaterialUnresolvedConflictBlocksExactGrounding() throws {
        let conflict = fixtureConflict(resolutionState: .unresolvedMaterial)
        XCTAssertFalse(
            fixtureSelection(coverage: try fixtureCompleteCoverage(), conflictSets: [conflict])
                .isGroundedForExactAnswer
        )
    }

    func testPersistedPayloadsHaveNoSelfIdentityDigestOrSignature() throws {
        assertNoSelfFields(try fixtureSnapshot(), forbidden: [
            "artifactID", "snapshotID", "snapshotArtifactID", "snapshotDigest", "signature",
        ])
        assertNoSelfFields(fixtureRequirementPlan(), forbidden: [
            "artifactID", "planArtifactID", "requirementPlanArtifactID", "planDigest", "signature",
        ])
        assertNoSelfFields(fixtureLaneQuery(), forbidden: [
            "artifactID", "laneQueryArtifactID", "queryArtifactID", "queryDigest", "signature",
        ])
        assertNoSelfFields(fixtureLaneResult(), forbidden: [
            "artifactID", "laneResultArtifactID", "resultArtifactID", "resultDigest", "signature",
        ])
        assertNoSelfFields(fixtureSelection(
            coverage: try fixtureCompleteCoverage(),
            conflictSets: []
        ), forbidden: [
            "artifactID", "selectionArtifactID", "selectionDigest", "signature",
        ])
        assertNoSelfFields(fixtureLifecyclePayload(), forbidden: [
            "artifactID", "lifecycleArtifactID", "lifecycleDigest", "signature",
        ])
    }

    private func assertNoSelfFields(
        _ value: Any,
        forbidden: Set<String>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let labels = Set(Mirror(reflecting: value).children.compactMap(\.label))
        XCTAssertTrue(labels.isDisjoint(with: forbidden), "self field found", file: file, line: line)
    }
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter BASSemanticStateLakeContractTests
```

Expected: FAIL at compile time with `cannot find 'BASSemanticLaneID' in scope` or `cannot find 'BASStateReadSnapshot' in scope`; no production file has been added yet.

- [ ] **Step 3: Add the canonical value contracts**

First add the event-position value to the existing owner in `BASEventLog.swift`; Task 2 adds storage methods around it:

```swift
public struct BASEventLogHead: Codable, Sendable, Equatable, Hashable {
    public let sessionID: String
    public let sequenceNumber: Int64
    public let eventID: String
    public let integrityDigest: String

    public init(
        sessionID: String,
        sequenceNumber: Int64,
        eventID: String,
        integrityDigest: String
    ) {
        self.sessionID = sessionID
        self.sequenceNumber = sequenceNumber
        self.eventID = eventID
        self.integrityDigest = integrityDigest
    }

    public static func genesis(sessionID: String) -> Self {
        Self(
            sessionID: sessionID,
            sequenceNumber: -1,
            eventID: "",
            integrityDigest: String(repeating: "0", count: 64)
        )
    }
}
```

Then add the following exact ownership shape to `BASSemanticStateLakeContracts.swift`. Every public struct receives an explicit public initializer; array-bearing initializers call the shown canonical-order helpers before assignment.

```swift
import Foundation

public enum BASSemanticLaneID: String, Codable, Sendable, Hashable, CaseIterable {
    case sqlMetadata = "sql-metadata"
    case exactLexical = "exact-fts-bm25"
    case denseSemantic = "dense-semantic"
    case temporalEpisode = "temporal-episode"
    case entityRelation = "entity-relation"
}

public enum BASSemanticStateContractError: Error, Equatable, Sendable {
    case duplicateLane(BASSemanticLaneID)
    case emptySourceRoot(BASSemanticLaneID)
    case watermarkBeyondEventHead(BASSemanticLaneID)
    case snapshotMismatch
    case requirementPlanMismatch
    case requiredLaneFailed(BASSemanticLaneID)
    case completedSnapshot
    case malformedCoverage
    case invalidVisibilityScope
    case invalidCompiledEligibility
    case invalidCacheScope
    case invalidErasureTransition
    case invalidBitemporalInterval
    case invalidCalendarPolicy
    case invalidMemoryHorizonManifest
}

/// Canonical owner namespace from the semantic M ledger row. This is not an
/// empty marker: every caller uses this validator instead of keeping a second
/// lane-order table or accepting a caller-defined subset/order.
public enum BASSemanticStateLakeContracts {
    public static let canonicalLaneOrder: [BASSemanticLaneID] =
        BASSemanticLaneID.allCases

    public static func validateCanonicalLaneOrder(
        _ lanes: [BASSemanticLaneID]
    ) throws {
        guard lanes == canonicalLaneOrder else {
            throw BASSemanticStateContractError.snapshotMismatch
        }
    }
}

public struct BASBitemporalInterval: Codable, Sendable, Equatable, Hashable {
    public struct ValidTime: Codable, Sendable, Equatable, Hashable {
        public let worldFrom: Int64
        public let worldTo: Int64?

        public init(worldFrom: Int64, worldTo: Int64?) throws {
            guard worldTo.map({ $0 > worldFrom }) ?? true else {
                throw BASSemanticStateContractError.invalidBitemporalInterval
            }
            self.worldFrom = worldFrom
            self.worldTo = worldTo
        }
    }

    public struct TransactionTime: Codable, Sendable, Equatable, Hashable {
        public let eventOffsetStart: Int64
        public let eventOffsetEnd: Int64?

        public init(eventOffsetStart: Int64, eventOffsetEnd: Int64?) throws {
            guard eventOffsetStart >= 0,
                  eventOffsetEnd.map({ $0 > eventOffsetStart }) ?? true else {
                throw BASSemanticStateContractError.invalidBitemporalInterval
            }
            self.eventOffsetStart = eventOffsetStart
            self.eventOffsetEnd = eventOffsetEnd
        }
    }

    public let validTime: ValidTime
    public let transactionTime: TransactionTime

    public init(validTime: ValidTime, transactionTime: TransactionTime) {
        self.validTime = validTime
        self.transactionTime = transactionTime
    }
}

public enum BASCalendarAmbiguousLocalTimeResolution:
    String, Codable, Sendable, Equatable
{
    case earlierOffset, laterOffset, reject
}

public enum BASCalendarNonexistentLocalTimeResolution:
    String, Codable, Sendable, Equatable
{
    case nextValidInstant, previousValidInstant, reject
}

public struct BASCalendarDayBoundary: Codable, Sendable, Equatable, Hashable {
    public let localSecondsFromMidnight: Int32

    public init(localSecondsFromMidnight: Int32) throws {
        guard (0 ..< 86_400).contains(localSecondsFromMidnight) else {
            throw BASSemanticStateContractError.invalidCalendarPolicy
        }
        self.localSecondsFromMidnight = localSecondsFromMidnight
    }
}

public struct BASCalendarPolicyPayload: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let calendarIdentifier: String
    public let localeIdentifier: String
    public let timeZoneIdentifier: String
    public let tzdbVersion: String
    public let icuVersion: String
    public let osTimeZoneRuleBuild: String
    public let firstWeekday: Int
    public let minimumDaysInFirstWeek: Int
    public let dayBoundary: BASCalendarDayBoundary
    public let ambiguousLocalTimeResolution: BASCalendarAmbiguousLocalTimeResolution
    public let nonexistentLocalTimeResolution: BASCalendarNonexistentLocalTimeResolution
    public let effectiveTransactionInterval: BASBitemporalInterval.TransactionTime

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        calendarIdentifier: String,
        localeIdentifier: String,
        timeZoneIdentifier: String,
        tzdbVersion: String,
        icuVersion: String,
        osTimeZoneRuleBuild: String,
        firstWeekday: Int,
        minimumDaysInFirstWeek: Int,
        dayBoundary: BASCalendarDayBoundary,
        ambiguousLocalTimeResolution: BASCalendarAmbiguousLocalTimeResolution,
        nonexistentLocalTimeResolution: BASCalendarNonexistentLocalTimeResolution,
        effectiveTransactionInterval: BASBitemporalInterval.TransactionTime
    ) throws {
        guard schemaVersion == Self.currentSchemaVersion,
              !calendarIdentifier.isEmpty, !localeIdentifier.isEmpty,
              !timeZoneIdentifier.isEmpty, !tzdbVersion.isEmpty,
              !icuVersion.isEmpty, !osTimeZoneRuleBuild.isEmpty,
              (1 ... 7).contains(firstWeekday),
              (1 ... 7).contains(minimumDaysInFirstWeek) else {
            throw BASSemanticStateContractError.invalidCalendarPolicy
        }
        self.schemaVersion = schemaVersion
        self.calendarIdentifier = calendarIdentifier
        self.localeIdentifier = localeIdentifier
        self.timeZoneIdentifier = timeZoneIdentifier
        self.tzdbVersion = tzdbVersion
        self.icuVersion = icuVersion
        self.osTimeZoneRuleBuild = osTimeZoneRuleBuild
        self.firstWeekday = firstWeekday
        self.minimumDaysInFirstWeek = minimumDaysInFirstWeek
        self.dayBoundary = dayBoundary
        self.ambiguousLocalTimeResolution = ambiguousLocalTimeResolution
        self.nonexistentLocalTimeResolution = nonexistentLocalTimeResolution
        self.effectiveTransactionInterval = effectiveTransactionInterval
    }
}

public enum BASMemoryHorizon: String, Codable, Sendable, Equatable, CaseIterable {
    case current, day, week, month, archival
}

public struct BASMemoryHorizonEventRange: Codable, Sendable, Equatable {
    public let turnOperationRef: BASTurnOperationRef
    public let eventOffsetStart: Int64
    public let eventOffsetEnd: Int64
    public let rangeRootDigest: String
    public let sourceEndHead: BASEventLogHead

    public init(
        turnOperationRef: BASTurnOperationRef,
        eventOffsetStart: Int64,
        eventOffsetEnd: Int64,
        rangeRootDigest: String,
        sourceEndHead: BASEventLogHead
    ) throws {
        guard eventOffsetStart >= 0, eventOffsetEnd > eventOffsetStart,
              sourceEndHead.sequenceNumber == eventOffsetEnd - 1,
              !rangeRootDigest.isEmpty,
              try BASTurnOperationRef(
                validatingCanonicalLegacyProjection: sourceEndHead.sessionID
              ) == turnOperationRef else {
            throw BASSemanticStateContractError.invalidMemoryHorizonManifest
        }
        self.turnOperationRef = turnOperationRef
        self.eventOffsetStart = eventOffsetStart
        self.eventOffsetEnd = eventOffsetEnd
        self.rangeRootDigest = rangeRootDigest
        self.sourceEndHead = sourceEndHead
    }
}

public struct BASMemoryHorizonCoverage: Codable, Sendable, Equatable {
    public let sourceEventCount: UInt64
    public let representedEventCount: UInt64
    public let blindedTombstoneCount: UInt64
    public let isCompleteForDeclaredProjection: Bool

    public init(
        sourceEventCount: UInt64,
        representedEventCount: UInt64,
        blindedTombstoneCount: UInt64,
        isCompleteForDeclaredProjection: Bool
    ) throws {
        guard representedEventCount <= sourceEventCount,
              blindedTombstoneCount <= representedEventCount else {
            throw BASSemanticStateContractError.invalidMemoryHorizonManifest
        }
        self.sourceEventCount = sourceEventCount
        self.representedEventCount = representedEventCount
        self.blindedTombstoneCount = blindedTombstoneCount
        self.isCompleteForDeclaredProjection = isCompleteForDeclaredProjection
    }
}

public enum BASMemoryHorizonProjectionLoss: String, Codable, Sendable, Equatable {
    case lossless, lossySummary
}

public enum BASMemoryHorizonReplayBasis: String, Codable, Sendable, Equatable {
    case originalEventLog, sealedLosslessCheckpoint
}

public struct BASMemoryHorizonManifestPayload: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let horizon: BASMemoryHorizon
    public let orderedSourceEventRanges: [BASMemoryHorizonEventRange]
    public let sourceEventLogRootDigest: String
    public let bitemporalInterval: BASBitemporalInterval
    public let orderedProvenanceArtifactIDs: [BASArtifactID]
    public let coverage: BASMemoryHorizonCoverage
    public let loss: BASMemoryHorizonProjectionLoss
    public let calendarPolicyArtifactID: BASArtifactID
    public let policyEpoch: UInt64
    public let deletionEpoch: UInt64
    public let invalidationEpoch: UInt64
    public let replayBasis: BASMemoryHorizonReplayBasis
    public let sealedLosslessCheckpointArtifactID: BASArtifactID?
    public let checkpointReplayEquivalenceReceiptArtifactID: BASArtifactID?
    public let retentionAuthorizationReceiptArtifactID: BASArtifactID?
    public let orderedParentManifestHintArtifactIDs: [BASArtifactID]

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        horizon: BASMemoryHorizon,
        sourceEventRanges: [BASMemoryHorizonEventRange],
        sourceEventLogRootDigest: String,
        bitemporalInterval: BASBitemporalInterval,
        provenanceArtifactIDs: [BASArtifactID],
        coverage: BASMemoryHorizonCoverage,
        loss: BASMemoryHorizonProjectionLoss,
        calendarPolicyArtifactID: BASArtifactID,
        policyEpoch: UInt64,
        deletionEpoch: UInt64,
        invalidationEpoch: UInt64,
        replayBasis: BASMemoryHorizonReplayBasis,
        sealedLosslessCheckpointArtifactID: BASArtifactID?,
        checkpointReplayEquivalenceReceiptArtifactID: BASArtifactID?,
        retentionAuthorizationReceiptArtifactID: BASArtifactID?,
        parentManifestHintArtifactIDs: [BASArtifactID]
    ) throws {
        func orderedUniqueArtifactIDs(_ values: [BASArtifactID]) throws -> [BASArtifactID] {
            let keyed = try values.map { (try $0.storageScalar, $0) }.sorted {
                $0.0.utf8.lexicographicallyPrecedes($1.0.utf8)
            }
            guard zip(keyed, keyed.dropFirst()).allSatisfy({ $0.0.0 != $0.1.0 }) else {
                throw BASSemanticStateContractError.invalidMemoryHorizonManifest
            }
            return keyed.map(\.1)
        }
        let orderedRanges = sourceEventRanges.sorted {
            if $0.sourceEndHead.sessionID != $1.sourceEndHead.sessionID {
                return $0.sourceEndHead.sessionID.utf8
                    .lexicographicallyPrecedes($1.sourceEndHead.sessionID.utf8)
            }
            if $0.eventOffsetStart != $1.eventOffsetStart {
                return $0.eventOffsetStart < $1.eventOffsetStart
            }
            return $0.eventOffsetEnd < $1.eventOffsetEnd
        }
        guard zip(orderedRanges, orderedRanges.dropFirst()).allSatisfy({ pair in
            pair.0.sourceEndHead.sessionID != pair.1.sourceEndHead.sessionID
                || pair.0.eventOffsetStart != pair.1.eventOffsetStart
                || pair.0.eventOffsetEnd != pair.1.eventOffsetEnd
        }) else {
            throw BASSemanticStateContractError.invalidMemoryHorizonManifest
        }
        let sourceCount = try orderedRanges.reduce(UInt64.zero) { partial, range in
            let width = UInt64(range.eventOffsetEnd - range.eventOffsetStart)
            let (sum, overflow) = partial.addingReportingOverflow(width)
            guard !overflow else {
                throw BASSemanticStateContractError.invalidMemoryHorizonManifest
            }
            return sum
        }
        let orderedProvenance = try orderedUniqueArtifactIDs(provenanceArtifactIDs)
        let orderedHints = try orderedUniqueArtifactIDs(parentManifestHintArtifactIDs)
        let checkpointPairIsComplete =
            (sealedLosslessCheckpointArtifactID == nil)
            == (checkpointReplayEquivalenceReceiptArtifactID == nil)
        guard schemaVersion == Self.currentSchemaVersion,
              !orderedRanges.isEmpty, !sourceEventLogRootDigest.isEmpty,
              !orderedProvenance.isEmpty,
              coverage.sourceEventCount == sourceCount,
              loss != .lossless || (
                coverage.isCompleteForDeclaredProjection
                    && coverage.representedEventCount == coverage.sourceEventCount
              ),
              checkpointPairIsComplete,
              replayBasis != .sealedLosslessCheckpoint
                || sealedLosslessCheckpointArtifactID != nil else {
            throw BASSemanticStateContractError.invalidMemoryHorizonManifest
        }
        self.schemaVersion = schemaVersion
        self.horizon = horizon
        self.orderedSourceEventRanges = orderedRanges
        self.sourceEventLogRootDigest = sourceEventLogRootDigest
        self.bitemporalInterval = bitemporalInterval
        self.orderedProvenanceArtifactIDs = orderedProvenance
        self.coverage = coverage
        self.loss = loss
        self.calendarPolicyArtifactID = calendarPolicyArtifactID
        self.policyEpoch = policyEpoch
        self.deletionEpoch = deletionEpoch
        self.invalidationEpoch = invalidationEpoch
        self.replayBasis = replayBasis
        self.sealedLosslessCheckpointArtifactID = sealedLosslessCheckpointArtifactID
        self.checkpointReplayEquivalenceReceiptArtifactID =
            checkpointReplayEquivalenceReceiptArtifactID
        self.retentionAuthorizationReceiptArtifactID = retentionAuthorizationReceiptArtifactID
        self.orderedParentManifestHintArtifactIDs = orderedHints
    }
}

public struct BASAttemptVisibilityScope: Codable, Sendable, Equatable, Hashable {
    public let authorityScopeArtifactID: BASArtifactID
    public let workspaceIncarnationID: String
    public let workspaceRefArtifactID: BASArtifactID
    public let windowRefArtifactID: BASArtifactID
    public let attemptRefArtifactID: BASArtifactID
    public let generationVectorArtifactID: BASArtifactID
    public let visibilityCompartmentID: String
    public let purpose: String
    public let restorationEpoch: UInt64
    public let policyEpoch: UInt64
    public let capabilityEpoch: UInt64
    public let deletionEpoch: UInt64
    public let killEpoch: UInt64
}

public struct BASCompiledLaneEligibilityPredicate: Codable, Sendable, Equatable {
    public let laneID: BASSemanticLaneID
    public let visibilityScope: BASAttemptVisibilityScope
    public let semanticSnapshotArtifactID: BASArtifactID
    public let requestedProjectionDigest: String
    public let sourceRequirementDigest: String
    public let allowedSensitivityLabels: [String]
    public let minimumAuthority: Double
    public let requireGoverned: Bool
    public let denyTombstonedDeletedQuarantined: Bool
}

public struct BASPhysicalContentKey: Codable, Sendable, Equatable, Hashable {
    public let modelIdentityArtifactID: BASArtifactID
    public let modality: String
    public let canonicalContentDigest: String
    public let orderedProvenanceArtifactIDs: [BASArtifactID]
    public let visibilityCompartmentID: String
    public let privateStorageDomainTag: String
    public let tokenizerDigest: String
    public let templateAndToolProtocolDigest: String
    public let stateABIDigest: String
    public let positionConvention: String
    public let acceptedTokenBoundary: Int
}

public struct BASAcquisitionScope: Codable, Sendable, Equatable, Hashable {
    public let authorityScopeArtifactID: BASArtifactID
    public let workspaceIncarnationID: String
    public let workspaceRefArtifactID: BASArtifactID
    public let windowRefArtifactID: BASArtifactID
    public let semanticSnapshotArtifactID: BASArtifactID
    public let attemptRefArtifactID: BASArtifactID
    public let generationVectorArtifactID: BASArtifactID
    public let sessionID: String
    public let sessionRole: String
    public let visibilityCompartmentID: String
    public let purpose: String
    public let restorationEpoch: UInt64
    public let policyEpoch: UInt64
    public let capabilityEpoch: UInt64
    public let deletionEpoch: UInt64
    public let killEpoch: UInt64
    public let monotonicDeadlineNanos: UInt64
}

public struct BASCacheScopeContract: BASSchemaVersioned, Codable, Sendable, Equatable, Hashable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let physicalContentKey: BASPhysicalContentKey
    public let acquisitionScope: BASAcquisitionScope
}

public enum BASErasureRank: String, Codable, Sendable, Equatable, CaseIterable {
    case requested
    case logicallyQuarantined = "logically-quarantined"
    case keyDestructionPending = "key-destruction-pending"
    case keyAbsent = "key-absent"
    case projectionPurgePending = "projection-purge-pending"
    case projectionPurgeAcknowledged = "projection-purge-acknowledged"
    case closureRescanned = "closure-rescanned"
    case completed
    case erasureIndeterminate = "erasure-indeterminate"

    public var monotonicOrdinal: Int {
        switch self {
        case .requested: 0
        case .logicallyQuarantined: 1
        case .keyDestructionPending: 2
        case .keyAbsent: 3
        case .projectionPurgePending: 4
        case .projectionPurgeAcknowledged: 5
        case .closureRescanned: 6
        case .completed: 7
        case .erasureIndeterminate: 8
        }
    }

    public func permitsTransition(to next: Self) -> Bool {
        if self == next { return true }
        if self == .completed || self == .erasureIndeterminate { return false }
        if next == .erasureIndeterminate { return true }
        return next != .completed
            ? next.monotonicOrdinal == monotonicOrdinal + 1
            : self == .closureRescanned
    }
}

public enum BASErasureProjectionOwner: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case processRAM = "process-ram"
    case frontstage
    case spill
    case compiledContext = "compiled-context"
    case fts, vector, temporal
    case entity, linguistic
    case session, kv, prefix, neural
    case verifier, result
    case provider
    case artifactPayload = "artifact-payload"
    case controlledBackup = "controlled-backup"
    case export
}

public struct BASErasureClosureReceipt: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let erasureRequestArtifactID: BASArtifactID
    public let visibilityScope: BASAttemptVisibilityScope
    public let rank: BASErasureRank
    public let orderedAcknowledgedOwners: [BASErasureProjectionOwner]
    public let keyAbsenceReceiptArtifactID: BASArtifactID?
    public let closureRescanReceiptArtifactID: BASArtifactID?
    public let uncertaintyArtifactID: BASArtifactID?
}

public struct BASLaneWatermark: Codable, Sendable, Hashable {
    public let laneID: BASSemanticLaneID
    public let sourceSequence: UInt64
    public let sourceRootDigest: String
    public let asOfEventSequenceNumber: Int64
    public let provenanceArtifactID: BASArtifactID
    public let proofArtifactID: BASArtifactID?

    public init(
        laneID: BASSemanticLaneID,
        sourceSequence: UInt64,
        sourceRootDigest: String,
        asOfEventSequenceNumber: Int64,
        provenanceArtifactID: BASArtifactID,
        proofArtifactID: BASArtifactID? = nil
    ) throws {
        guard !sourceRootDigest.isEmpty else {
            throw BASSemanticStateContractError.emptySourceRoot(laneID)
        }
        self.laneID = laneID
        self.sourceSequence = sourceSequence
        self.sourceRootDigest = sourceRootDigest
        self.asOfEventSequenceNumber = asOfEventSequenceNumber
        self.provenanceArtifactID = provenanceArtifactID
        self.proofArtifactID = proofArtifactID
    }

    public static func canonicalOrder(_ values: [Self]) throws -> [Self] {
        let sorted = values.sorted { $0.laneID.rawValue.utf8.lexicographicallyPrecedes($1.laneID.rawValue.utf8) }
        for pair in zip(sorted, sorted.dropFirst()) where pair.0.laneID == pair.1.laneID {
            throw BASSemanticStateContractError.duplicateLane(pair.0.laneID)
        }
        return sorted
    }
}

public struct BASLaneRequirement: Codable, Sendable, Equatable {
    public let laneID: BASSemanticLaneID
    public let required: Bool
    public let requestedProjectionDigest: String
    public let sourceRequirementDigest: String
    public let minimumAuthority: Double
    public let maximumCandidates: Int
    public let maximumBytes: UInt64
    public let maximumTokens: Int
    public let deadlineSharePermille: UInt16
}

public struct BASStateRequirementPlan: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let requestArtifactID: BASArtifactID
    public let intentAndRiskArtifactID: BASArtifactID
    public let worldPriorProjectionArtifactID: BASArtifactID
    public let constitutionProjectionArtifactID: BASArtifactID
    public let coveragePolicyArtifactID: BASArtifactID
    public let purpose: String
    public let visibilityScope: BASAttemptVisibilityScope
    public let allowedSensitivityLabels: [String]
    public let orderedLaneRequirements: [BASLaneRequirement]
    public let totalCandidateBudget: Int
    public let totalByteBudget: UInt64
    public let totalTokenBudget: Int
    public let monotonicDeadlineNanos: UInt64
}

public struct BASStateReadSnapshot: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let logicalEpoch: UInt64
    public let requirementPlanArtifactID: BASArtifactID
    public let calendarPolicyArtifactID: BASArtifactID
    public let eventLogHead: BASEventLogHead
    public let orderedLaneWatermarks: [BASLaneWatermark]
    public let policyEpoch: UInt64
    public let schemaEpoch: UInt64
    public let openedLogicalTime: UInt64

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        turnOperationRef: BASTurnOperationRef,
        logicalEpoch: UInt64,
        requirementPlanArtifactID: BASArtifactID,
        calendarPolicyArtifactID: BASArtifactID,
        eventLogHead: BASEventLogHead,
        laneWatermarks: [BASLaneWatermark],
        policyEpoch: UInt64,
        schemaEpoch: UInt64,
        openedLogicalTime: UInt64
    ) throws {
        let ordered = try BASLaneWatermark.canonicalOrder(laneWatermarks)
        self.schemaVersion = schemaVersion
        self.turnOperationRef = turnOperationRef
        self.logicalEpoch = logicalEpoch
        self.requirementPlanArtifactID = requirementPlanArtifactID
        self.calendarPolicyArtifactID = calendarPolicyArtifactID
        self.eventLogHead = eventLogHead
        self.orderedLaneWatermarks = ordered
        self.policyEpoch = policyEpoch
        self.schemaEpoch = schemaEpoch
        self.openedLogicalTime = openedLogicalTime
        try validateComplete()
    }

    public func validateComplete() throws {
        let decodedSessionRoot = try BASTurnOperationRef(
            validatingCanonicalLegacyProjection: eventLogHead.sessionID
        )
        guard schemaVersion == Self.currentSchemaVersion,
              decodedSessionRoot == turnOperationRef,
              try BASLaneWatermark.canonicalOrder(orderedLaneWatermarks)
                == orderedLaneWatermarks else {
            throw BASSemanticStateContractError.snapshotMismatch
        }
        if let invalid = orderedLaneWatermarks.first(where: {
            $0.asOfEventSequenceNumber > eventLogHead.sequenceNumber
        }) {
            throw BASSemanticStateContractError.watermarkBeyondEventHead(invalid.laneID)
        }
    }
}

public struct BASLaneQuery: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let laneID: BASSemanticLaneID
    public let requestArtifactID: BASArtifactID
    public let requirementPlanArtifactID: BASArtifactID
    public let semanticSnapshotArtifactID: BASArtifactID
    public let compiledEligibility: BASCompiledLaneEligibilityPredicate
    public let requestedProjectionDigest: String
    public let sourceRequirementDigest: String
    public let minimumAuthority: Double
    public let maximumCandidates: Int
    public let maximumBytes: UInt64
    public let maximumTokens: Int
    public let monotonicDeadlineNanos: UInt64
}

public enum BASLaneResultStatus: String, Codable, Sendable, Equatable {
    case completed, missing, timedOut, failed
}

public enum BASLaneCompleteness: String, Codable, Sendable, Equatable {
    case complete, partial, unavailable
}

public enum BASEvidenceDirectness: String, Codable, Sendable, Equatable {
    case direct, derived, inferred
}

public enum BASCandidateGovernanceState: String, Codable, Sendable, Equatable {
    case active, consentMissing, consentInvalid, tombstoned, deleted, expired, quarantined
}

public struct BASStateCandidate: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let candidateKey: String
    public let claimKey: String
    public let sourceLaneID: BASSemanticLaneID
    public let sourceRecordKey: String
    public let payloadArtifactID: BASArtifactID
    public let orderedProvenanceArtifactIDs: [BASArtifactID]
    public let consentReceiptArtifactID: BASArtifactID?
    public let killAndRevocationEpochArtifactID: BASArtifactID?
    public let bitemporalInterval: BASBitemporalInterval
    public let visibilityScope: BASAttemptVisibilityScope
    public let sensitivityLabel: String
    public let authority: Double
    public let freshness: Double
    public let relevance: Double
    public let utility: Double
    public let tokenCost: Int
    public let byteCount: UInt64
    public let evidenceDirectness: BASEvidenceDirectness
    public let governanceState: BASCandidateGovernanceState
    public let policyEpoch: UInt64
    public let schemaEpoch: UInt64
}

public struct BASLaneEligibilityEvidence: Codable, Sendable, Equatable {
    public let candidateKey: String
    public let sourceRule: String
    public let sourceAllowed: Bool
    public let reasonCode: String
}

public struct BASLaneConflictEvidence: Codable, Sendable, Equatable {
    public let claimKey: String
    public let orderedCandidateKeys: [String]
    public let sourceConflictKind: String
    public let sourceMateriality: Double
}

public struct BASLaneResult: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let laneQueryArtifactID: BASArtifactID
    public let semanticSnapshotArtifactID: BASArtifactID
    public let laneID: BASSemanticLaneID
    public let completeness: BASLaneCompleteness
    public let status: BASLaneResultStatus
    public let orderedCandidates: [BASStateCandidate]
    public let orderedEligibilityEvidence: [BASLaneEligibilityEvidence]
    public let orderedConflictEvidence: [BASLaneConflictEvidence]
    public let terminalReceiptArtifactID: BASArtifactID
    public let completedLogicalTime: UInt64
}

public enum BASCoverageTerminalState: String, Codable, Sendable, Equatable {
    case complete, incomplete, requiredLaneFailed
}

public struct BASCoverageVector: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let requiredLaneIDs: [BASSemanticLaneID]
    public let completedLaneIDs: [BASSemanticLaneID]
    public let failedLaneIDs: [BASSemanticLaneID]
    public let missingOptionalLaneIDs: [BASSemanticLaneID]
    public let failureReceiptArtifactIDs: [BASArtifactID]

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        requiredLaneIDs: [BASSemanticLaneID],
        completedLaneIDs: [BASSemanticLaneID],
        failedLaneIDs: [BASSemanticLaneID],
        missingOptionalLaneIDs: [BASSemanticLaneID],
        failureReceiptArtifactIDs: [BASArtifactID]
    ) throws {
        func orderedUnique(_ values: [BASSemanticLaneID]) throws -> [BASSemanticLaneID] {
            let ordered = values.sorted {
                $0.rawValue.utf8.lexicographicallyPrecedes($1.rawValue.utf8)
            }
            for pair in zip(ordered, ordered.dropFirst()) where pair.0 == pair.1 {
                throw BASSemanticStateContractError.duplicateLane(pair.0)
            }
            return ordered
        }
        self.schemaVersion = schemaVersion
        self.requiredLaneIDs = try orderedUnique(requiredLaneIDs)
        self.completedLaneIDs = try orderedUnique(completedLaneIDs)
        self.failedLaneIDs = try orderedUnique(failedLaneIDs)
        self.missingOptionalLaneIDs = try orderedUnique(missingOptionalLaneIDs)
        self.failureReceiptArtifactIDs = failureReceiptArtifactIDs
    }

    public var terminalState: BASCoverageTerminalState {
        if !Set(requiredLaneIDs).intersection(Set(failedLaneIDs)).isEmpty { return .requiredLaneFailed }
        if Set(requiredLaneIDs).isSubset(of: Set(completedLaneIDs)) { return .complete }
        return .incomplete
    }
    public var isComplete: Bool { terminalState == .complete }
}

public enum BASStateCandidateRejectionReason: String, Codable, Sendable, Equatable {
    case snapshotMismatch, schemaMismatch, scopeMismatch, consentMissing, consentInvalid
    case deleted, tombstoned, expired, quarantined, authorityInsufficient, provenanceMissing
    case policyEpochMismatch, killOrRevocationEpochMismatch, overByteBudget, overTokenBudget
    case duplicate, conflictMaterial, marketTruncated
}

public struct BASStateCandidateRejection: Codable, Sendable, Equatable {
    public let candidateKey: String
    public let reason: BASStateCandidateRejectionReason
    public let evidenceArtifactIDs: [BASArtifactID]
}

public struct BASHardEligibilityReceipt: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let semanticSnapshotArtifactID: BASArtifactID
    public let requirementPlanArtifactID: BASArtifactID
    public let candidateKey: String
    public let admitted: Bool
    public let reason: BASStateCandidateRejectionReason?
    public let evidenceArtifactIDs: [BASArtifactID]
}

public struct BASEligibleStateCandidate: Codable, Sendable, Equatable {
    public let candidate: BASStateCandidate
    public let eligibilityReceipt: BASHardEligibilityReceipt
}

public enum BASHardEligibilityDecision: Codable, Sendable, Equatable {
    case admitted(BASEligibleStateCandidate)
    case rejected(BASStateCandidateRejection)
}

public enum BASClaimConflictRelationship: String, Codable, Sendable, Equatable {
    case compatible, supersedes, contradicts, mutuallyExclusive
}

public enum BASClaimResolutionState: String, Codable, Sendable, Equatable {
    case resolved, unresolvedNonMaterial, unresolvedMaterial
}

public struct BASClaimConflictSet: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let claimKey: String
    public let orderedCandidateKeys: [String]
    public let relationship: BASClaimConflictRelationship
    public let resolutionState: BASClaimResolutionState
    public let explanationArtifactIDs: [BASArtifactID]
}

public struct BASStateMarketVector: Codable, Sendable, Equatable {
    public let relevance: Double
    public let authority: Double
    public let freshness: Double
    public let utility: Double
    public let diversityContribution: Double
    public let tokenCost: Int
    public let conflictRisk: Double
}

public struct BASStateMarketVectorEntry: Codable, Sendable, Equatable {
    public let candidateKey: String
    public let vector: BASStateMarketVector
}

public struct BASStateMarketBudgetReceipt: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let maximumBytes: UInt64
    public let usedBytes: UInt64
    public let maximumTokens: Int
    public let usedTokens: Int
    public let selectedCandidateCount: Int
    public let truncatedCandidateCount: Int
}

public struct BASStateMarketSelection: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let semanticSnapshotArtifactID: BASArtifactID
    public let requirementPlanArtifactID: BASArtifactID
    public let selected: [BASEligibleStateCandidate]
    public let rejected: [BASStateCandidateRejection]
    public let truncated: [BASStateCandidateRejection]
    public let conflictSets: [BASClaimConflictSet]
    public let orderedMarketVectors: [BASStateMarketVectorEntry]
    public let coverage: BASCoverageVector
    public let budgetReceipt: BASStateMarketBudgetReceipt

    public var isGroundedForExactAnswer: Bool {
        coverage.isComplete && conflictSets.allSatisfy { $0.resolutionState != .unresolvedMaterial }
    }
}

public protocol BASStateSnapshotBarrierPort: Sendable {
    var laneID: BASSemanticLaneID { get }
    func freeze(at eventLogHead: BASEventLogHead, schemaEpoch: UInt64) async throws -> BASLaneWatermark
}

public protocol BASSemanticStateLane: BASStateSnapshotBarrierPort {
    func query(
        _ query: BASLaneQuery,
        queryArtifactID: BASArtifactID,
        snapshotArtifactID: BASArtifactID
    ) async -> BASLaneResult
}
```

Add explicit public initializers to every declaration above. Normalize every lane/candidate/evidence/conflict/vector array by UTF-8 key order and reject duplicate keys. Authority, freshness, utility, diversity, conflict risk, and materiality values are finite and in `0...1`; relevance is finite and nonnegative because exact lexical candidates use the directly oriented negative of SQLite FTS5's hidden `rank` value (the default built-in BM25 mapping). Never persist derived `terminalState`, `isComplete`, or `isGroundedForExactAnswer`.

Add `BASSemanticSnapshotLifecycleTransition` (`opened`, `laneResultAccepted`, `completed`) and `BASSemanticSnapshotLifecyclePayload(snapshotArtifactID:relatedArtifactID:transition:)`. `snapshotArtifactID` is always a `BASArtifactID`; `relatedArtifactID` is `nil` for open/complete and is exactly the accepted lane-result `BASArtifactID` for `.laneResultAccepted`. The lifecycle value is encoded directly into the existing event log, contains no self ID, and is not stored through a second lifecycle ledger.

- [ ] **Step 4: Register every persisted semantic payload**

Add exact registry entries for `BASCalendarPolicyPayload`, `BASMemoryHorizonManifestPayload`, `BASCacheScopeContract`, `BASErasureClosureReceipt`, `BASStateRequirementPlan`, `BASStateReadSnapshot`, `BASLaneQuery`, `BASStateCandidate`, `BASLaneResult`, `BASCoverageVector`, `BASHardEligibilityReceipt`, `BASClaimConflictSet`, `BASStateMarketBudgetReceipt`, `BASStateMarketSelection`, and `BASSemanticSnapshotLifecyclePayload`. `BASBitemporalInterval`, `BASMemoryHorizon`, `BASMemoryHorizonEventRange`, `BASMemoryHorizonCoverage`, `BASAttemptVisibilityScope`, `BASCompiledLaneEligibilityPredicate`, `BASPhysicalContentKey`, `BASAcquisitionScope`, and `BASLaneWatermark` are nested `Codable` values versioned by their persisted enclosing payload and are not independently stored. Update the exact-count assertion and add this coverage assertion:

Every listed persisted payload, including `BASSemanticSnapshotLifecyclePayload`, conforms to `BASSchemaVersioned`, stores `schemaVersion`, declares `currentSchemaVersion = "1.0.0"`, and exposes an explicit public initializer with `schemaVersion: String = Self.currentSchemaVersion` first. Every ordinary put, `BASArtifactIdentityCore.canonicalPayloadBytes` construction, and reopen uses only `BASGovernedArtifactPayloadCodec.canonicalBytes(for:)`/`decodeCurrent`; no direct encoder/decoder, local accepted-version set, or read-before-version-check exists. Register each exact Swift basename once through the normal metatype registry entry. For every type, pin exact `schema.<Type>.current`, `schema.<Type>.backward_v1`, and `schema.<Type>.future_rejection` fixtures; test canonical current round-trip, v1 fixture decode, missing/future rejection before any EventLog/lane/coordinator/Market mechanism, exact-one object/test IDs, and registered-version parity. A cross-target compile fixture imports `BASRuntimeCore` and constructs every type through its public initializer while omitting `schemaVersion`. Nested values have no entry or independent put path.

```swift
func testEveryPersistedSemanticStateTypeIsRegistered() {
    let expected = Set([
        "BASCalendarPolicyPayload", "BASMemoryHorizonManifestPayload",
        "BASCacheScopeContract", "BASErasureClosureReceipt",
        "BASStateRequirementPlan", "BASStateReadSnapshot", "BASLaneQuery",
        "BASStateCandidate", "BASLaneResult", "BASCoverageVector",
        "BASHardEligibilityReceipt", "BASClaimConflictSet", "BASStateMarketBudgetReceipt",
        "BASStateMarketSelection",
        "BASSemanticSnapshotLifecyclePayload",
    ])
    XCTAssertTrue(expected.isSubset(
        of: Set(BASEBrainSchemaGovernanceRegistry.governedSchemas.map(\.objectID))))
}
```

- [ ] **Step 5: Run GREEN and existing schema regressions**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASSemanticStateLakeContractTests|BASEBrainSchemaGovernanceRegistryTests'
```

Expected: PASS; 0 failures. The contract test must show that only `BASStateReadSnapshot` declares the one ordered watermark array, that snapshot/candidate/calendar/horizon payloads have no self identity or copied calendar digest, and that every persisted temporal value reuses `BASBitemporalInterval`.

- [ ] **Step 6: Commit**

```bash
git add BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticStateLakeContracts.swift \
  docs/superpowers/specs/qinao-owner-ledger-v1.json \
  scripts/check_qinao_owner_ledger.py \
  scripts/test_check_qinao_owner_ledger.py \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLog.swift \
  BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticStateLakeContractTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift
git commit -m "feat: add canonical semantic state contracts"
```

### Task 2: Extend the Existing K3 FULL Nucleus with Head/CAS, Scope Epochs, and Erasure Rank

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLog.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEventLogSemanticSnapshotTests.swift`

**Reuse Decision (E):** `BASEventLogStorage` already owns append order and `BASSQLiteEventLogStorage` already owns the canonical database connection, sequence HWM, WAL transactions, `event_log_integrity(prev_hash,row_hash)`, and integrity verification. Extend that same file/WAL/transaction owner with authoritative scope/deletion epochs, the current calendar-policy Artifact ID inside the same scope row, and erasure rank/ACK/rescan; change authoritative durability from `synchronous=NORMAL` to `synchronous=FULL`. Do not add a semantic event store, calendar-policy table, erasure store, snapshot ledger, cursor table, second WAL, or second chain. The new test file is exempt from the production create gate.

**Interfaces:**
- Consumes: existing `append(_:)`, per-session sequence HWM, `verifyIntegrityChain(forSession:)`, integrity hash implementation, `BASAttemptVisibilityScope`, `BASErasureRank`, and the fixed `BASErasureProjectionOwner.allCases` closure.
- Produces: `BASEventLogHead`, `head(forSession:)`, `append(_:ifCurrentHead:)`, `currentCalendarPolicyArtifactID(for:)`, `BASEventLogKind.semanticSnapshotLifecycle`, and `BASErasureClosurePort` implemented only by the same `BASSQLiteEventLogStorage` K3 nucleus. Authoritative scope installation/supersession writes the calendar Artifact ID into the existing `k3_scope_epoch` row with its policy/invalidation epoch; there is no independently writable calendar binding.

- [ ] **Step 1: Write failing head, CAS, restart, and one-chain tests**

```swift
import XCTest
@testable import BASRuntimeCore

final class BASEventLogSemanticSnapshotTests: XCTestCase {
    func testHeadUsesExistingSequenceAndIntegrityChain() async throws {
        let store = try makeIntegrityEnabledSQLiteEventLog()
        _ = try await store.append(fixtureEvent(id: "e1", sessionID: "turn-1"))
        let optionalHead = try await store.head(forSession: "turn-1")
        let head = try XCTUnwrap(optionalHead)
        XCTAssertEqual(head.sequenceNumber, 0)
        XCTAssertEqual(head.eventID, "e1")
        XCTAssertFalse(head.integrityDigest.isEmpty)
        try await store.verifyIntegrityChain(forSession: "turn-1")
    }

    func testConditionalAppendRejectsMovedHeadWithoutWriting() async throws {
        let store = try makeIntegrityEnabledSQLiteEventLog()
        _ = try await store.append(fixtureEvent(id: "e1", sessionID: "turn-1"))
        let optionalStale = try await store.head(forSession: "turn-1")
        let stale = try XCTUnwrap(optionalStale)
        _ = try await store.append(fixtureEvent(id: "e2", sessionID: "turn-1"))
        do {
            _ = try await store.append(
                fixtureEvent(id: "semantic-open", sessionID: "turn-1"),
                ifCurrentHead: stale
            )
            XCTFail("stale head must fail")
        } catch BASStateRequirementPlanningError.compiledEligibilityMismatch {
            return await failedResult(
                query: query,
                queryArtifactID: queryArtifactID,
                snapshotArtifactID: snapshotArtifactID,
                reason: "semantic-state:pre-query-eligibility-mismatch"
            )
        } catch {
            XCTAssertEqual(error as? BASEventLogConditionalAppendError, .headMismatch)
        }
        let totalCount = await store.totalCount
        XCTAssertEqual(totalCount, 2)
    }

    func testRestartReturnsSameHeadAndNoSemanticLogTableExists() async throws {
        let url = temporaryDatabaseURL()
        let first = try makeIntegrityEnabledSQLiteEventLog(url: url)
        _ = try await first.append(fixtureEvent(id: "e1", sessionID: "turn-1"))
        let expected = try await first.head(forSession: "turn-1")
        let reopened = try makeIntegrityEnabledSQLiteEventLog(url: url)
        let reopenedHead = try await reopened.head(forSession: "turn-1")
        XCTAssertEqual(reopenedHead, expected)
        let tables = try sqliteTableNames(url)
        XCTAssertFalse(tables.contains("semantic_event_log"))
        XCTAssertFalse(tables.contains("semantic_snapshot_ledger"))
        XCTAssertFalse(tables.contains("semantic_integrity_chain"))
    }

    func testAuthoritativeSQLiteUsesOneWALAndSynchronousFull() async throws {
        let store = try makeIntegrityEnabledSQLiteEventLog()
        let journalMode = try await store.sqliteJournalModeForTesting()
        let synchronous = try await store.sqliteSynchronousForTesting()
        let openFileCount = try await store.openDatabaseFileCountForTesting()
        XCTAssertEqual(journalMode, "wal")
        XCTAssertEqual(synchronous, 2) // FULL
        XCTAssertEqual(openFileCount, 1)
    }

    func testCurrentCalendarPolicyIsPartOfTheSameK3ScopeRow() async throws {
        let store = try makeIntegrityEnabledSQLiteEventLog()
        let scope = fixtureVisibilityScope(policyEpoch: 9)
        let calendarID = fixtureArtifactID("calendar-policy")
        try await store.installScopeForTesting(
            scope,
            calendarPolicyArtifactID: calendarID,
            invalidationEpoch: 4
        )
        let currentCalendarID = try await store.currentCalendarPolicyArtifactID(
            for: scope)
        XCTAssertEqual(currentCalendarID, calendarID)
        await XCTAssertThrowsErrorAsync {
            _ = try await store.currentCalendarPolicyArtifactID(
                for: fixtureVisibilityScope(policyEpoch: 8)
            )
        }
    }

    func testErasureCannotCompleteUntilEveryOwnerACKAndClosureRescan() async throws {
        let store = try makeIntegrityEnabledSQLiteEventLog()
        let begun = try await store.beginErasure(
            requestArtifactID: fixtureArtifactID("erase-request"),
            scope: fixtureVisibilityScope(deletionEpoch: 7),
            event: fixtureErasureRequestedEvent()
        )
        XCTAssertEqual(begun.rank, .logicallyQuarantined)
        XCTAssertEqual(begun.visibilityScope.deletionEpoch, 8)

        for owner in BASErasureProjectionOwner.allCases.dropLast() {
            _ = try await store.acknowledgeErasureOwner(
                requestArtifactID: fixtureArtifactID("erase-request"),
                owner: owner,
                purgeOrAbsenceReceiptArtifactID: fixtureArtifactID("ack-\(owner.rawValue)")
            )
        }
        await XCTAssertThrowsErrorAsync {
            _ = try await store.completeErasure(
                requestArtifactID: fixtureArtifactID("erase-request"),
                keyAbsenceReceiptArtifactID: fixtureArtifactID("key-absent"),
                closureRescanReceiptArtifactID: fixtureArtifactID("rescan")
            )
        }
    }

    func testOneReceiptCannotAcknowledgeTwoProjectionOwners() async throws {
        let store = try makeIntegrityEnabledSQLiteEventLog()
        let requestID = fixtureArtifactID("erase-request")
        _ = try await store.beginErasure(
            requestArtifactID: requestID,
            scope: fixtureVisibilityScope(deletionEpoch: 7),
            event: fixtureErasureRequestedEvent()
        )
        let receiptID = fixtureArtifactID("single-owner-purge")
        _ = try await store.acknowledgeErasureOwner(
            requestArtifactID: requestID,
            owner: .processRAM,
            purgeOrAbsenceReceiptArtifactID: receiptID
        )
        await XCTAssertThrowsErrorAsync {
            _ = try await store.acknowledgeErasureOwner(
                requestArtifactID: requestID,
                owner: .frontstage,
                purgeOrAbsenceReceiptArtifactID: receiptID
            )
        }
    }

    func testErasureRankNeverRegressesAcrossCrashClockRollbackOrPrune() async throws {
        for failpoint in BASErasureNucleusFailpoint.allCases {
            let reopened = try await runErasureCrashAndReopen(failpoint: failpoint)
            XCTAssertTrue(reopened.rank == .requested || reopened.rank.monotonicOrdinal >= BASErasureRank.logicallyQuarantined.monotonicOrdinal)
            try await reopened.store.pruneEventsBefore(timestampMs: Int64.max)
            let erasureReceipt = try await reopened.store.erasureReceipt(
                requestArtifactID: reopened.requestID)
            XCTAssertNotNil(erasureReceipt)
        }
    }
}
```

- [ ] **Step 2: Run and verify RED**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter BASEventLogSemanticSnapshotTests
```

Expected: FAIL because `.semanticSnapshotLifecycle`, `head(forSession:)`, the conditional append overload, `BASErasureClosurePort`, and authoritative `synchronous=FULL` do not yet exist; `BASEventLogHead` and erasure value contracts already exist from Task 1.

- [ ] **Step 3: Extend the protocol and both existing conformers**

Extend the `BASEventLogHead` added in Task 1 with this exact conditional-append surface in `BASEventLog.swift`:

```swift
public enum BASEventLogConditionalAppendError: Error, Equatable, Sendable {
    case headMismatch
    case integrityUnavailable
}

public protocol BASEventLogStorage: Sendable {
    @discardableResult
    func append(_ entry: BASEventLogEntry) async throws
        -> (wasNew: Bool, assignedSequenceNumber: Int64)
    @discardableResult
    func append(
        _ entry: BASEventLogEntry,
        ifCurrentHead expectedHead: BASEventLogHead
    ) async throws -> (wasNew: Bool, assignedSequenceNumber: Int64)
    func head(forSession sessionID: String) async throws -> BASEventLogHead?
}

public protocol BASErasureClosurePort: Sendable {
    func beginErasure(
        requestArtifactID: BASArtifactID,
        scope: BASAttemptVisibilityScope,
        event: BASEventLogEntry
    ) async throws -> BASErasureClosureReceipt
    func acknowledgeErasureOwner(
        requestArtifactID: BASArtifactID,
        owner: BASErasureProjectionOwner,
        purgeOrAbsenceReceiptArtifactID: BASArtifactID
    ) async throws -> BASErasureClosureReceipt
    func completeErasure(
        requestArtifactID: BASArtifactID,
        keyAbsenceReceiptArtifactID: BASArtifactID,
        closureRescanReceiptArtifactID: BASArtifactID
    ) async throws -> BASErasureClosureReceipt
    func markErasureIndeterminate(
        requestArtifactID: BASArtifactID,
        uncertaintyArtifactID: BASArtifactID
    ) async throws -> BASErasureClosureReceipt
    func erasureReceipt(
        requestArtifactID: BASArtifactID
    ) async throws -> BASErasureClosureReceipt?
}
```

Keep the existing `events(forSession:)`, `events(sinceTimestampMs:limit:)`, `totalCount`, and `pruneEventsBefore(timestampMs:)` requirements byte-for-byte unchanged below these additions.

Add `.semanticSnapshotLifecycle = "semantic-snapshot-lifecycle"` to `BASEventLogKind`. Move the current SQLite `integrityHash(entry:prevHash:)` implementation into one shared `BASEventLogIntegrity.nextDigest(previousDigest:entry:)` helper in `BASEventLog.swift`; both in-memory and SQLite conformers call that helper, so there remains one hash algorithm.

Refactor the current SQLite `append(_:)` body into an actor-isolated `appendLocked(_:)` helper. Implement conditional append in the same database transaction:

```swift
public func append(
    _ entry: BASEventLogEntry,
    ifCurrentHead expectedHead: BASEventLogHead
) async throws -> (wasNew: Bool, assignedSequenceNumber: Int64) {
    guard let db else {
        throw StorageError.openFailed(code: -1, message: "db handle unavailable")
    }
    try Self.runExec(db: db, sql: "BEGIN IMMEDIATE;")
    do {
        let actual = try currentHeadLocked(forSession: entry.sessionID)
            ?? .genesis(sessionID: entry.sessionID)
        guard actual == expectedHead else {
            throw BASEventLogConditionalAppendError.headMismatch
        }
        let result = try appendLocked(entry)
        try Self.runExec(db: db, sql: "COMMIT;")
        return result
    } catch {
        try? Self.runExec(db: db, sql: "ROLLBACK;")
        throw error
    }
}
```

`appendLocked` performs only the row/HWM/existing-integrity-sidecar mutation and never begins or commits a transaction; both public append overloads wrap that helper exactly once. `currentHeadLocked(forSession:)` reads the latest `event_log` row and its matching `event_log_integrity.row_hash` inside that same transaction. Semantic mode requires the existing integrity-chain option; return `.integrityUnavailable` if the latest row lacks its current sidecar row. The in-memory conformer derives the current head from its existing ordered entries with the same shared digest helper inside its actor turn; it adds no independent sequence/head dictionary or second chain.

Change the existing production pragma to `PRAGMA synchronous=FULL`. In that same `BASSQLiteEventLogStorage` database/bootstrap owner, add only `k3_scope_epoch`, `k3_erasure_closure`, and `k3_erasure_owner_ack` control tables. They have no payload/blob column, event sequence, cursor, or hash chain. The one `k3_scope_epoch` row includes the ordinary `calendarPolicyArtifactID` storage scalar and `invalidationEpoch`; its existing authoritative install/supersede transaction exact-compares the complete scope, requires the referenced Artifact Mesh policy to have been put first, and advances policy/invalidation epoch with the binding. `currentCalendarPolicyArtifactID(for:)` exact-compares authority/workspace/window/Attempt/generation plus restoration/policy/deletion epochs before returning that ID. It never accepts or returns a copied digest. `beginErasure` runs one `BEGIN IMMEDIATE` transaction that exact-compares the supplied scope against the current authority/workspace/window/Attempt generation vector, increments `deletionEpoch` with checked arithmetic, appends the erasure-request/quarantine event and integrity row through `appendLocked`, and inserts the monotonic erasure row before commit. Therefore restart observes the entire old tuple or the entire new tuple, never a new event with an old epoch or vice versa.

Every rank write calls `BASErasureRank.permitsTransition(to:)`: ordinary progress is one declared step, exact repeats are idempotent, and `.completed` plus `.erasureIndeterminate` are terminal sibling outcomes with no transition between them. ACK rows are unique by both `(requestArtifactID, owner)` and `(requestArtifactID, purgeOrAbsenceReceiptArtifactID)` and bind an ordinary Artifact Mesh purge-or-absence receipt. Each enum case is one independently queryable projection owner; aggregate receipts, internal fan-out claims, bitmasks, reuse of one receipt for two cases, or one ACK covering multiple cases are rejected. `completeErasure` succeeds only when the persisted set equals `Set(BASErasureProjectionOwner.allCases)`, a key-absence receipt exists, and a post-ACK closure-rescan receipt exists; it appends the completion event and advances the row in the same K3 transaction. `pruneEventsBefore` never deletes the blinded request/tombstone, deletion epoch, rank, or ACK closure. A missing/unreachable owner calls `markErasureIndeterminate`; no best-effort `try?`, wall-clock expiry, or partial tier deletion returns `.completed`.

- [ ] **Step 4: Run GREEN and the existing event-log closure suite**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASEventLogSemanticSnapshotTests|BASEventLogTests|BASSQLiteEventLogDualWriteInvariantTests|BASEventLogTamperRedTeamTests|BASEventLogSeqHighWaterMarkTests|BASEventLogFailureInjectionTests'
```

Expected: PASS; 0 failures. Restart returns the identical head, stale CAS writes zero rows, K3 reports one WAL with `synchronous=FULL`, every crash observes an all-old/all-new scope+event+rank tuple, and erasure cannot complete without every ACK plus rescan.

- [ ] **Step 5: Commit**

```bash
git add BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLog.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEventLogSemanticSnapshotTests.swift
git commit -m "feat: expose event log integrity head"
```

### Task 3: Pure L7 State Requirement Planner

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify: `/Users/changgeng/Project/Project06/Project06/scripts/check_qinao_owner_ledger.py`
- Modify: `/Users/changgeng/Project/Project06/Project06/scripts/test_check_qinao_owner_ledger.py`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/BASStateRequirementPlanner.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASStateRequirementPlannerTests.swift`

**Reuse Decision (M) — OwnerLedger `owner_id: state.requirement-planner`:** Existing retrieval requests start at mechanism-specific APIs; no current owner validates L4/L5/L6 prerequisites and allocates one cross-lane candidate/byte/token/deadline plan. The planner is explicitly allowlisted as missing. It is pure and cannot call a store, rank candidates, create an artifact ID, or weaken a missing mandatory input.

Task-local M gate for `semantic-statelake-context:Task 3`: stage the ledger/checker/checker-test with the created source and tests; atomically add exact path permission/evidence and set `approved_missing → converging` on first create; remove conflicts only with proof; set `implemented` only after all declared paths/evidence/tests/gates exist and `current_conflicts == []`; roll back source, permission, evidence, conflicts/projections, and status together.

**Create Proof — `BASStateRequirementPlanner.swift`:**

1. Repository search: `rg -n 'RequirementPlanner|maximumCandidates|deadlineSharePermille' BehavioralAISubstrate/Sources` finds no cross-lane requirement owner; `BASRAGRetriever` and `BASL8RoutedMemoryService` are mechanism owners.
2. Public/upstream search: no Apple/Foundation primitive expresses product-specific lane necessity, authority, sensitivity, or coverage policy.
3. Missing invariant: one pure L7 plan that makes required/optional lanes and aggregate budgets explicit before any mechanism query.
4. Existing retrieval APIs cannot own it because that would let one lane decide requirements for its peers.
5. Authority: planner owns requirement selection only; its caller stores the returned payload through ordinary Artifact Mesh `put(identityCore:headUpdate:)`; lane mechanisms execute queries; State Market owns admission.
6. Dependency direction: `BASOrchestration → BASRuntimeCore`; no dependency on `BASMemory` or HostKit.
7. Compatibility: legacy callers continue to call current retrieval APIs until Task 8 shadow composition; the planner has no production default flip.
8. Tests prove missing mandatory inputs fail before retrieval, aggregate budgets are conserved, ordering is deterministic, and no storage/ranking symbol appears in the production file.

**Interfaces:**
- Consumes: `BASStateRequirementPlanningInput` with typed request/intent/world-prior/constitution/coverage-policy artifact IDs.
- Produces: `plan(_:) throws -> BASStateRequirementPlan`, `compileQueries(planArtifactID:plan:snapshotArtifactID:snapshot:) throws -> [BASLaneQuery]`, and `validateCompiledEligibility(query:plan:snapshot:) throws`, the sole full-field validator reused by every lane adapter.

- [ ] **Step 1: Write failing validation and conservation tests**

```swift
import XCTest
@testable import BASOrchestration

final class BASStateRequirementPlannerTests: XCTestCase {
    func testMissingConstitutionFailsBeforeAnyQueryExists() {
        XCTAssertThrowsError(
            try BASStateRequirementPlanner.plan(fixturePlanningInput(constitution: nil))
        ) { error in
            XCTAssertEqual(error as? BASStateRequirementPlanningError, .missingConstitutionProjection)
        }
    }

    func testPlanIsDeterministicAndConservesAllBudgets() throws {
        let first = try BASStateRequirementPlanner.plan(fixturePlanningInput())
        let second = try BASStateRequirementPlanner.plan(fixturePlanningInput())
        XCTAssertEqual(first.orderedLaneRequirements, second.orderedLaneRequirements)
        XCTAssertLessThanOrEqual(
            first.orderedLaneRequirements.reduce(0) { $0 + $1.maximumCandidates },
            first.totalCandidateBudget
        )
        XCTAssertLessThanOrEqual(
            first.orderedLaneRequirements.reduce(UInt64.zero) { $0 + $1.maximumBytes },
            first.totalByteBudget
        )
        XCTAssertLessThanOrEqual(
            first.orderedLaneRequirements.reduce(0) { $0 + $1.maximumTokens },
            first.totalTokenBudget
        )
        XCTAssertEqual(
            first.orderedLaneRequirements.reduce(0) { $0 + Int($1.deadlineSharePermille) },
            1_000
        )
    }

    func testQueriesBindTypedPlanAndSnapshotArtifacts() throws {
        let plan = try BASStateRequirementPlanner.plan(fixturePlanningInput())
        let planID = fixtureArtifactID("plan")
        let snapshotID = fixtureArtifactID("snapshot")
        let queries = try BASStateRequirementPlanner.compileQueries(
            planArtifactID: planID,
            plan: plan,
            snapshotArtifactID: snapshotID,
            snapshot: try fixtureSnapshot(requirementPlanArtifactID: planID)
        )
        XCTAssertTrue(queries.allSatisfy { $0.requirementPlanArtifactID == planID })
        XCTAssertTrue(queries.allSatisfy { $0.semanticSnapshotArtifactID == snapshotID })
        XCTAssertTrue(queries.allSatisfy {
            $0.compiledEligibility.semanticSnapshotArtifactID == snapshotID
                && $0.compiledEligibility.visibilityScope == plan.visibilityScope
        })
    }

    func testScopeOrEpochMismatchFailsBeforeAnyLaneQueryIsReturned() throws {
        let plan = try BASStateRequirementPlanner.plan(fixturePlanningInput())
        for mutation in BASAttemptVisibilityScopeMutation.allCases {
            XCTAssertThrowsError(try BASStateRequirementPlanner.compileQueries(
                planArtifactID: fixtureArtifactID("plan"),
                plan: plan,
                snapshotArtifactID: fixtureArtifactID("snapshot"),
                snapshot: try fixtureSnapshot(
                    requirementPlanArtifactID: fixtureArtifactID("plan"),
                    scopeMutation: mutation
                )
            ))
        }
    }

    func testEveryCompiledEligibilityFieldMutationFailsExactValidation() throws {
        let fixture = try makeCompiledEligibilityValidationFixture()
        for mutation in BASCompiledLaneEligibilityMutation.allCases {
            XCTAssertThrowsError(
                try BASStateRequirementPlanner.validateCompiledEligibility(
                    query: fixture.query.mutatingCompiledEligibility(mutation),
                    plan: fixture.plan,
                    snapshot: fixture.snapshot
                )
            )
        }
    }
}
```

- [ ] **Step 2: Run and verify RED**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter BASStateRequirementPlannerTests
```

Expected: FAIL at compile time with `cannot find 'BASStateRequirementPlanner' in scope`.

- [ ] **Step 3: Implement the pure planner**

```swift
import Foundation
import BASRuntimeCore

public enum BASStateRequirementPlanningError: Error, Equatable, Sendable {
    case missingIntentAndRisk
    case missingWorldPriorProjection
    case missingConstitutionProjection
    case missingCoveragePolicy
    case invalidAggregateBudget
    case snapshotPlanMismatch
    case compiledEligibilityMismatch
}

public struct BASStateRequirementPlanningInput: Codable, Sendable, Equatable {
    public let requestArtifactID: BASArtifactID
    public let intentAndRiskArtifactID: BASArtifactID?
    public let worldPriorProjectionArtifactID: BASArtifactID?
    public let constitutionProjectionArtifactID: BASArtifactID?
    public let coveragePolicyArtifactID: BASArtifactID?
    public let purpose: String
    public let visibilityScope: BASAttemptVisibilityScope
    public let allowedSensitivityLabels: [String]
    public let requestedLanes: [BASSemanticLaneID]
    public let requiredLanes: [BASSemanticLaneID]
    public let minimumAuthority: Double
    public let totalCandidateBudget: Int
    public let totalByteBudget: UInt64
    public let totalTokenBudget: Int
    public let monotonicDeadlineNanos: UInt64
}

public enum BASStateRequirementPlanner {
    public static func plan(
        _ input: BASStateRequirementPlanningInput
    ) throws -> BASStateRequirementPlan {
        guard let intent = input.intentAndRiskArtifactID else { throw BASStateRequirementPlanningError.missingIntentAndRisk }
        guard let world = input.worldPriorProjectionArtifactID else { throw BASStateRequirementPlanningError.missingWorldPriorProjection }
        guard let constitution = input.constitutionProjectionArtifactID else { throw BASStateRequirementPlanningError.missingConstitutionProjection }
        guard let coverage = input.coveragePolicyArtifactID else { throw BASStateRequirementPlanningError.missingCoveragePolicy }
        guard !input.requestedLanes.isEmpty || !input.requiredLanes.isEmpty,
              !input.allowedSensitivityLabels.isEmpty,
              !input.visibilityScope.workspaceIncarnationID.isEmpty,
              !input.visibilityScope.visibilityCompartmentID.isEmpty,
              input.totalCandidateBudget > 0, input.totalByteBudget > 0,
              input.totalTokenBudget > 0, input.monotonicDeadlineNanos > 0 else {
            throw BASStateRequirementPlanningError.invalidAggregateBudget
        }

        let lanes = Array(Set(input.requestedLanes).union(input.requiredLanes)).sorted {
            $0.rawValue.utf8.lexicographicallyPrecedes($1.rawValue.utf8)
        }
        let candidateShares = exactIntegerShares(total: input.totalCandidateBudget, count: lanes.count)
        let byteShares = exactUInt64Shares(total: input.totalByteBudget, count: lanes.count)
        let tokenShares = exactIntegerShares(total: input.totalTokenBudget, count: lanes.count)
        let deadlineShares = exactPermilleShares(count: lanes.count)
        let required = Set(input.requiredLanes)

        return BASStateRequirementPlan(
            requestArtifactID: input.requestArtifactID,
            intentAndRiskArtifactID: intent,
            worldPriorProjectionArtifactID: world,
            constitutionProjectionArtifactID: constitution,
            coveragePolicyArtifactID: coverage,
            purpose: input.purpose,
            visibilityScope: input.visibilityScope,
            allowedSensitivityLabels: input.allowedSensitivityLabels.sorted {
                $0.utf8.lexicographicallyPrecedes($1.utf8)
            },
            orderedLaneRequirements: lanes.enumerated().map { index, lane in
                BASLaneRequirement(
                    laneID: lane,
                    required: required.contains(lane),
                    requestedProjectionDigest: projectionDigest(for: lane),
                    sourceRequirementDigest: sourceRequirementDigest(for: lane),
                    minimumAuthority: input.minimumAuthority,
                    maximumCandidates: candidateShares[index],
                    maximumBytes: byteShares[index],
                    maximumTokens: tokenShares[index],
                    deadlineSharePermille: deadlineShares[index]
                )
            },
            totalCandidateBudget: input.totalCandidateBudget,
            totalByteBudget: input.totalByteBudget,
            totalTokenBudget: input.totalTokenBudget,
            monotonicDeadlineNanos: input.monotonicDeadlineNanos
        )
    }

    public static func compileQueries(
        planArtifactID: BASArtifactID,
        plan: BASStateRequirementPlan,
        snapshotArtifactID: BASArtifactID,
        snapshot: BASStateReadSnapshot
    ) throws -> [BASLaneQuery] {
        guard snapshot.requirementPlanArtifactID == planArtifactID,
              snapshot.policyEpoch == plan.visibilityScope.policyEpoch else {
            throw BASStateRequirementPlanningError.snapshotPlanMismatch
        }
        return plan.orderedLaneRequirements.map { requirement in
            BASLaneQuery(
                laneID: requirement.laneID,
                requestArtifactID: plan.requestArtifactID,
                requirementPlanArtifactID: planArtifactID,
                semanticSnapshotArtifactID: snapshotArtifactID,
                compiledEligibility: BASCompiledLaneEligibilityPredicate(
                    laneID: requirement.laneID,
                    visibilityScope: plan.visibilityScope,
                    semanticSnapshotArtifactID: snapshotArtifactID,
                    requestedProjectionDigest: requirement.requestedProjectionDigest,
                    sourceRequirementDigest: requirement.sourceRequirementDigest,
                    allowedSensitivityLabels: plan.allowedSensitivityLabels,
                    minimumAuthority: requirement.minimumAuthority,
                    requireGoverned: true,
                    denyTombstonedDeletedQuarantined: true
                ),
                requestedProjectionDigest: requirement.requestedProjectionDigest,
                sourceRequirementDigest: requirement.sourceRequirementDigest,
                minimumAuthority: requirement.minimumAuthority,
                maximumCandidates: requirement.maximumCandidates,
                maximumBytes: requirement.maximumBytes,
                maximumTokens: requirement.maximumTokens,
                monotonicDeadlineNanos: plan.monotonicDeadlineNanos
            )
        }
    }

    public static func validateCompiledEligibility(
        query: BASLaneQuery,
        plan: BASStateRequirementPlan,
        snapshot: BASStateReadSnapshot
    ) throws {
        guard snapshot.requirementPlanArtifactID == query.requirementPlanArtifactID,
              snapshot.policyEpoch == plan.visibilityScope.policyEpoch,
              let requirement = plan.orderedLaneRequirements.first(where: {
                  $0.laneID == query.laneID
              }) else {
            throw BASStateRequirementPlanningError.compiledEligibilityMismatch
        }
        let expectedPredicate = BASCompiledLaneEligibilityPredicate(
            laneID: requirement.laneID,
            visibilityScope: plan.visibilityScope,
            semanticSnapshotArtifactID: query.semanticSnapshotArtifactID,
            requestedProjectionDigest: requirement.requestedProjectionDigest,
            sourceRequirementDigest: requirement.sourceRequirementDigest,
            allowedSensitivityLabels: plan.allowedSensitivityLabels,
            minimumAuthority: requirement.minimumAuthority,
            requireGoverned: true,
            denyTombstonedDeletedQuarantined: true
        )
        guard query.requestArtifactID == plan.requestArtifactID,
              query.compiledEligibility == expectedPredicate,
              query.requestedProjectionDigest == requirement.requestedProjectionDigest,
              query.sourceRequirementDigest == requirement.sourceRequirementDigest,
              query.minimumAuthority == requirement.minimumAuthority,
              query.maximumCandidates == requirement.maximumCandidates,
              query.maximumBytes == requirement.maximumBytes,
              query.maximumTokens == requirement.maximumTokens,
              query.monotonicDeadlineNanos == plan.monotonicDeadlineNanos else {
            throw BASStateRequirementPlanningError.compiledEligibilityMismatch
        }
    }
}
```

Implement `exactIntegerShares`, `exactUInt64Shares`, and `exactPermilleShares` as quotient/remainder allocation in lane order, so sums equal their inputs exactly. `projectionDigest(for:)` and `sourceRequirementDigest(for:)` must use the repository canonical encoder, not `hashValue` or JSON. They commit to external projection requirements and are not the plan's self digest. `validateCompiledEligibility` exact-compares the entire predicate value—including full workspace/window/Attempt scope, both source digests, the canonical sensitivity set, minimum authority, snapshot binding, and both governance booleans—plus every duplicated query budget/binding. No downstream adapter is allowed to implement a partial copy of this validation.

- [ ] **Step 4: Run GREEN and source-ownership checks**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASStateRequirementPlannerTests|BASSemanticStateLakeContractTests'
if rg -n 'SQLite|BASRAGRetriever|BASVectorIndex|rank\(|select\(' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/BASStateRequirementPlanner.swift; then
  exit 1
fi
```

Expected: tests PASS with 0 failures; the inverted ownership scan emits no matches, proving the planner contains no store/retrieval/ranking mechanism.

- [ ] **Step 5: Commit**

```bash
git add BehavioralAISubstrate/Sources/BASOrchestration/BASStateRequirementPlanner.swift \
  docs/superpowers/specs/qinao-owner-ledger-v1.json \
  scripts/check_qinao_owner_ledger.py \
  scripts/test_check_qinao_owner_ledger.py \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASStateRequirementPlannerTests.swift
git commit -m "feat: plan bounded semantic state requirements"
```

### Task 4: Immutable Snapshot/Barrier Coordination over Artifact Mesh and the Existing Event Log

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify: `/Users/changgeng/Project/Project06/Project06/scripts/check_qinao_owner_ledger.py`
- Modify: `/Users/changgeng/Project/Project06/Project06/scripts/test_check_qinao_owner_ledger.py`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASSemanticSnapshotCoordinator.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticSnapshotCoordinatorTests.swift`

**Reuse Decision (M) — OwnerLedger `owner_id: state.snapshot-coordinator`:** The immutable multi-lane barrier is allowlisted as missing. This task adds a coordinator, not a store: Artifact Mesh owns immutable snapshot bytes/identity, `BASEventLogStorage` owns lifecycle order/integrity, and existing lane mechanisms own their frozen views. No `BASSemanticStateLake` actor, SQLite database, lifecycle table, head, or WAL is created.

Task-local M gate for `semantic-statelake-context:Task 4`: stage the ledger/checker/checker-test with the created source and tests; atomically add exact path permission/evidence and set `approved_missing → converging` on first create; remove conflicts only with proof; set `implemented` only after all declared paths/evidence/tests/gates exist and `current_conflicts == []`; roll back source, permission, evidence, conflicts/projections, and status together.

**Create Proof — `BASSemanticSnapshotCoordinator.swift`:**

1. Repository search: `rg -n 'freeze\(at:|openSnapshot|semanticSnapshotArtifactID' BehavioralAISubstrate/Sources` finds no multi-lane barrier coordinator; current snapshots are domain-specific.
2. Public/upstream search: `TaskGroup` supplies bounded fan-out, but no primitive coordinates application-specific lane proofs and Artifact Mesh persistence.
3. Missing invariant: one turn-scoped barrier that binds all required existing lane views to one event-log head, the current K3-bound calendar-policy artifact, and one immutable snapshot artifact.
4. Neither event storage nor one retrieval mechanism can coordinate all lanes without a dependency inversion; composition is required.
5. Authority: coordinator owns orchestration only; Artifact Mesh owns payload storage, event log owns lifecycle, lanes own view freezing; coordinator has no durable mutable state.
6. Dependency direction: `BASMemory → BASRuntimeCore`; barriers are injected through the RuntimeCore protocol.
7. Compatibility: legacy retrieval remains unchanged; Task 8 adds shadow-only composition. Orphaned content-addressed snapshot artifacts after a crash-before-event are safe and collectable because they were never referenced by event truth.
8. Crash/replay tests cover failure before/after artifact put, duplicate open, concurrent complete/late result, required barrier failure, restart, and proof tamper.

**Interfaces:**
- Consumes: `BASArtifactStorePort`, one Artifact-Mesh identity-core factory supplied by the canonical Artifact Mesh composition, `BASEventLogStorage`, its exact-scope `currentCalendarPolicyArtifactID(for:)` view, one same-store bounded `BASCalendarPolicyPayload` reopener, `[BASSemanticLaneID: any BASStateSnapshotBarrierPort]`, and a stored `BASStateRequirementPlan` plus its artifact ID.
- Produces: `open(turnOperationRef:logicalEpoch:requirementPlanArtifactID:calendarPolicyArtifactID:plan:policyEpoch:schemaEpoch:openedLogicalTime:) async throws -> BASSemanticSnapshotHandle`, `reopen(snapshotArtifactID:turnOperationRef:) async throws -> BASSemanticSnapshotHandle`, `activeSnapshot(turnOperationRef:) async throws -> BASSemanticSnapshotHandle?`, `acceptLaneResult(laneResultArtifactID:snapshotArtifactID:turnOperationRef:) async throws`, and `complete(snapshotArtifactID:turnOperationRef:) async throws`; every method derives the EventLog session lookup through the Contracts Task 2A codec and accepts no raw session/turn string or calendar digest.

- [ ] **Step 1: Write failing barrier, crash, late-result, and restart tests**

```swift
import XCTest
@testable import BASMemory

final class BASSemanticSnapshotCoordinatorTests: XCTestCase {
    func testRequiredBarrierFailureStoresNoSnapshotAndAppendsNoLifecycleEvent() async throws {
        let fixture = makeCoordinatorFixture(failingLane: .sqlMetadata)
        do {
            _ = try await fixture.coordinator.open(
                turnOperationRef: fixture.turnOperationRef,
                logicalEpoch: 7,
                requirementPlanArtifactID: fixture.planID,
                calendarPolicyArtifactID: fixture.calendarPolicyID,
                plan: fixture.plan,
                policyEpoch: 4,
                schemaEpoch: 2,
                openedLogicalTime: 11
            )
            XCTFail("required barrier failure must abort")
        } catch {
            XCTAssertEqual(error as? BASSemanticSnapshotError, .requiredBarrierFailed(.sqlMetadata))
        }
        let artifactPutCount = await fixture.artifactStore.putCount
        let eventCount = await fixture.eventLog.totalCount
        XCTAssertEqual(artifactPutCount, 0)
        XCTAssertEqual(eventCount, 0)
    }

    func testSnapshotArtifactSurvivesNewEventsWithoutChanging() async throws {
        let fixture = makeCoordinatorFixture()
        let opened = try await fixture.open()
        _ = try await fixture.eventLog.append(fixture.unrelatedEvent())
        let reopened = try await fixture.coordinator.reopen(
            snapshotArtifactID: opened.semanticSnapshotArtifactID,
            turnOperationRef: fixture.turnOperationRef
        )
        XCTAssertEqual(reopened, opened)
    }

    func testCalendarPolicyMustReopenAndMatchCurrentK3BindingBeforeBarrier() async throws {
        for mutation in BASCalendarPolicyBindingMutation.allCases {
            let fixture = makeCoordinatorFixture(calendarMutation: mutation)
            await XCTAssertThrowsErrorAsync { _ = try await fixture.open() }
            let barrierCalls = await fixture.barrierCalls.value
            let artifactPutCount = await fixture.artifactStore.putCount
            let eventCount = await fixture.eventLog.totalCount
            XCTAssertEqual(barrierCalls, 0)
            XCTAssertEqual(artifactPutCount, 0)
            XCTAssertEqual(eventCount, 0)
        }
    }

    func testCrashAfterArtifactPutBeforeLifecycleAppendLeavesNoOpenSnapshot() async throws {
        let fixture = makeCoordinatorFixture(failpoint: .afterArtifactPutBeforeEventAppend)
        await XCTAssertThrowsErrorAsync { _ = try await fixture.open() }
        let artifactPutCount = await fixture.artifactStore.putCount
        let activeSnapshot = try await fixture.coordinator.activeSnapshot(
            turnOperationRef: fixture.turnOperationRef)
        XCTAssertEqual(artifactPutCount, 1)
        XCTAssertNil(activeSnapshot)
    }

    func testCompletedSnapshotRejectsLateLaneResultUnderConcurrentAppend() async throws {
        let fixture = makeCoordinatorFixture()
        let opened = try await fixture.open()
        try await fixture.coordinator.complete(
            snapshotArtifactID: opened.semanticSnapshotArtifactID,
            turnOperationRef: fixture.turnOperationRef
        )
        do {
            try await fixture.coordinator.acceptLaneResult(
                laneResultArtifactID: fixtureArtifactID("late-result"),
                snapshotArtifactID: opened.semanticSnapshotArtifactID,
                turnOperationRef: fixture.turnOperationRef
            )
            XCTFail("late result must fail")
        } catch {
            XCTAssertEqual(error as? BASSemanticSnapshotError, .snapshotCompleted)
        }
    }

    func testLegacySessionAliasCannotOpenAnotherOperationRoot() async throws {
        let otherRoot = fixtureOtherOperationRef()
        let fixture = makeCoordinatorFixture(
            eventSessionID: try otherRoot.canonicalLegacyProjection()
        )
        await XCTAssertThrowsErrorAsync {
            _ = try await fixture.coordinator.open(
                turnOperationRef: fixture.turnOperationRef,
                logicalEpoch: 7,
                requirementPlanArtifactID: fixture.planID,
                calendarPolicyArtifactID: fixture.calendarPolicyID,
                plan: fixture.plan,
                policyEpoch: 4,
                schemaEpoch: 2,
                openedLogicalTime: 11
            )
        }
        let artifactPutCount = await fixture.artifactStore.putCount
        let eventCount = await fixture.eventLog.totalCount
        XCTAssertEqual(artifactPutCount, 0)
        XCTAssertEqual(eventCount, 0)
    }
}
```

- [ ] **Step 2: Run and verify RED**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter BASSemanticSnapshotCoordinatorTests
```

Expected: FAIL at compile time with `no such module member 'BASSemanticSnapshotCoordinator'` or `cannot find 'BASSemanticSnapshotError' in scope`.

- [ ] **Step 3: Implement the coordinator with no local durable state**

```swift
import Foundation
import BASRuntimeCore

public enum BASSemanticSnapshotError: Error, Equatable, Sendable {
    case operationRootMismatch
    case missingBarrier(BASSemanticLaneID)
    case requiredBarrierFailed(BASSemanticLaneID)
    case watermarkBeyondEventHead(BASSemanticLaneID)
    case lifecycleConflict
    case snapshotCompleted
    case snapshotNotOpened
    case corruptSnapshotArtifact
}

public struct BASSemanticSnapshotHandle: Sendable, Equatable {
    public let semanticSnapshotArtifactID: BASArtifactID
    public let snapshot: BASStateReadSnapshot
}

public struct BASSemanticSnapshotCoordinator: Sendable {
    public typealias SnapshotIdentityCoreFactory = @Sendable (BASStateReadSnapshot) throws -> BASArtifactIdentityCore
    public typealias ReopenCalendarPolicy =
        @Sendable (BASArtifactID) async throws -> BASCalendarPolicyPayload

    private let eventLog: any BASEventLogStorage
    private let artifactStore: any BASArtifactStorePort
    private let barriers: [BASSemanticLaneID: any BASStateSnapshotBarrierPort]
    private let makeSnapshotIdentityCore: SnapshotIdentityCoreFactory
    private let reopenCalendarPolicy: ReopenCalendarPolicy

    public init(
        eventLog: any BASEventLogStorage,
        artifactStore: any BASArtifactStorePort,
        barriers: [BASSemanticLaneID: any BASStateSnapshotBarrierPort],
        makeSnapshotIdentityCore: @escaping SnapshotIdentityCoreFactory,
        reopenCalendarPolicy: @escaping ReopenCalendarPolicy
    ) {
        self.eventLog = eventLog
        self.artifactStore = artifactStore
        self.barriers = barriers
        self.makeSnapshotIdentityCore = makeSnapshotIdentityCore
        self.reopenCalendarPolicy = reopenCalendarPolicy
    }

    public func open(
        turnOperationRef: BASTurnOperationRef,
        logicalEpoch: UInt64,
        requirementPlanArtifactID: BASArtifactID,
        calendarPolicyArtifactID: BASArtifactID,
        plan: BASStateRequirementPlan,
        policyEpoch: UInt64,
        schemaEpoch: UInt64,
        openedLogicalTime: UInt64
    ) async throws -> BASSemanticSnapshotHandle {
        let boundCalendarPolicyArtifactID = try await eventLog
            .currentCalendarPolicyArtifactID(for: plan.visibilityScope)
        guard boundCalendarPolicyArtifactID == calendarPolicyArtifactID else {
            throw BASSemanticSnapshotError.corruptSnapshotArtifact
        }
        let calendarPolicy = try await reopenCalendarPolicy(calendarPolicyArtifactID)
        let legacySessionID = try turnOperationRef.canonicalLegacyProjection()
        let head = try await eventLog.head(forSession: legacySessionID)
            ?? .genesis(sessionID: legacySessionID)
        guard try BASTurnOperationRef(
            validatingCanonicalLegacyProjection: head.sessionID
        ) == turnOperationRef else {
            throw BASSemanticSnapshotError.operationRootMismatch
        }
        let openingOffset = max(Int64.zero, head.sequenceNumber)
        guard calendarPolicy.schemaVersion == BASCalendarPolicyPayload.currentSchemaVersion,
              calendarPolicy.effectiveTransactionInterval.eventOffsetStart <= openingOffset,
              calendarPolicy.effectiveTransactionInterval.eventOffsetEnd
                .map({ openingOffset < $0 }) ?? true else {
            throw BASSemanticSnapshotError.corruptSnapshotArtifact
        }
        let required = Set(plan.orderedLaneRequirements.filter(\.required).map(\.laneID))
        let requested = plan.orderedLaneRequirements.map(\.laneID)
        for lane in requested where barriers[lane] == nil {
            if required.contains(lane) { throw BASSemanticSnapshotError.missingBarrier(lane) }
        }

        enum BarrierOutcome: Sendable {
            case frozen(BASLaneWatermark)
            case failed(BASSemanticLaneID, required: Bool)
        }
        let outcomes = await withTaskGroup(of: BarrierOutcome.self) { group in
            for lane in requested {
                guard let barrier = barriers[lane] else { continue }
                group.addTask {
                    do {
                        return .frozen(try await barrier.freeze(at: head, schemaEpoch: schemaEpoch))
                    } catch {
                        return .failed(lane, required: required.contains(lane))
                    }
                }
            }
            var values: [BarrierOutcome] = []
            for await value in group { values.append(value) }
            return values
        }
        let failedRequired = outcomes.compactMap { outcome -> BASSemanticLaneID? in
            guard case let .failed(lane, required: true) = outcome else { return nil }
            return lane
        }.sorted { $0.rawValue.utf8.lexicographicallyPrecedes($1.rawValue.utf8) }
        if let lane = failedRequired.first {
            throw BASSemanticSnapshotError.requiredBarrierFailed(lane)
        }
        let watermarks = try BASLaneWatermark.canonicalOrder(outcomes.compactMap { outcome in
            guard case let .frozen(watermark) = outcome else { return nil }
            return watermark
        })

        for watermark in watermarks where watermark.asOfEventSequenceNumber > head.sequenceNumber {
            throw BASSemanticSnapshotError.watermarkBeyondEventHead(watermark.laneID)
        }
        for lane in required where !watermarks.contains(where: { $0.laneID == lane }) {
            throw BASSemanticSnapshotError.requiredBarrierFailed(lane)
        }

        let snapshot = try BASStateReadSnapshot(
            turnOperationRef: turnOperationRef,
            logicalEpoch: logicalEpoch,
            requirementPlanArtifactID: requirementPlanArtifactID,
            calendarPolicyArtifactID: calendarPolicyArtifactID,
            eventLogHead: head,
            laneWatermarks: watermarks,
            policyEpoch: policyEpoch,
            schemaEpoch: schemaEpoch,
            openedLogicalTime: openedLogicalTime
        )
        let receipt = try await artifactStore.put(
            identityCore: makeSnapshotIdentityCore(snapshot),
            headUpdate: nil
        )
        try await appendLifecycle(
            .opened,
            snapshotArtifactID: receipt.body.artifactID,
            relatedArtifactID: nil,
            turnOperationRef: turnOperationRef
        )
        return BASSemanticSnapshotHandle(
            semanticSnapshotArtifactID: receipt.body.artifactID,
            snapshot: snapshot
        )
    }
}
```

Add `reopen(snapshotArtifactID:turnOperationRef:)`, `activeSnapshot(turnOperationRef:)`, `acceptLaneResult(laneResultArtifactID:snapshotArtifactID:turnOperationRef:)`, `complete(snapshotArtifactID:turnOperationRef:)`, and the private `appendLifecycle` helper with these exact rules:

- Decode snapshot/lane-result payloads only through Artifact Mesh after its integrity verification succeeds.
- Before freezing any lane on open, require the supplied `calendarPolicyArtifactID` to equal the current exact-scope K3 binding, reopen that ID through the same `BASArtifactStorePort`, bounded-decode `BASCalendarPolicyPayload`, canonical-byte-verify it, and require its effective half-open transaction interval to cover the opening EventLog offset. On every snapshot reopen/result/complete path, repeat the current K3-binding comparison and calendar-artifact reopen before returning or appending. A changed binding fences the old snapshot and drives deterministic rebuild; no raw `calendarPolicyDigest`, caller-created `Calendar`, current wall clock, or process locale can substitute.
- Before any EventLog `head(forSession:)`, `events(forSession:)`, genesis, or append call, derive the sole raw session key with `turnOperationRef.canonicalLegacyProjection()`. On every reopen/lifecycle/result boundary, decode that raw key with `BASTurnOperationRef(validatingCanonicalLegacyProjection:)` and require equality with both the caller's ref and `snapshot.turnOperationRef`. Branch compatibility uses only the corresponding `BASTurnBranchRef` methods with those same names. These are the exact bounded codec entrypoints delivered by Contracts Task 2A, not semantic-owned identity functions; failure is `.operationRootMismatch` before state is read or mutated.
- Reduce only `.semanticSnapshotLifecycle` events from `eventLog.events(forSession:)`; do not cache the reduced lifecycle.
- `appendLifecycle` reads the current event-log head, builds a typed `BASSemanticSnapshotLifecyclePayload`, encodes it as the existing event payload, and calls `append(_:ifCurrentHead:)`. On `.headMismatch`, reload and reduce lifecycle once, then retry only if the transition remains legal.
- `.opened` is idempotent for the same snapshot artifact and exact operation root; a second different active snapshot for the same `BASTurnOperationRef`/epoch fails closed.
- `.laneResultAccepted` is legal only after `.opened` and before `.completed`; reopen both artifacts through the injected Artifact Mesh, call `snapshot.validateComplete()`, verify its `eventLogHead` against the existing integrity-bound event log, and require the result's exact `semanticSnapshotArtifactID` plus `laneID` to match that snapshot and its requirement plan. A completed result requires exactly one matching lane inside the snapshot-owned `orderedLaneWatermarks`; failed/missing/timed-out results carry no watermark and are accepted only for a planned lane. No lifecycle or result payload copies a watermark field/vector.
- `.completed` is idempotent and terminal. Late results are never attached to this artifact; the caller must create a later epoch.
- The identity-core-factory closure is a dependency-boundary adapter whose only production wiring builds `BASArtifactIdentityCore` with canonical payload bytes and the exact verified `.attempt(attemptRefArtifactID)` `BASArtifactScopeBinding`; it resolves that Attempt artifact back to `snapshot.turnOperationRef` before put. Artifact identity contains no raw turn/branch compatibility projection. The injected `BASArtifactStorePort.put(identityCore:headUpdate:)` remains the only component that chooses the keyed ID and persists the snapshot. The adapter cannot choose IDs, persist elsewhere, sign the snapshot, or accept independent turn/branch strings; `canonicalLegacyProjection()` is used only at the EventLog storage boundary above.

- [ ] **Step 4: Run GREEN, event-log regressions, and the no-second-store check**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASSemanticSnapshotCoordinatorTests|BASEventLogSemanticSnapshotTests|BASEventLogTamperRedTeamTests|BASArtifactMeshTests|BASArtifactStoreTests'
if rg -n 'SQLite3|sqlite3_|CREATE TABLE|CREATE INDEX|journal_mode|(actor|class) BASSemanticStateLake[ :{]' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASSemanticSnapshotCoordinator.swift; then
  exit 1
fi
```

Expected: tests PASS with 0 failures; the ownership scan emits no matches and exits successfully through the inverted `if` guard.

- [ ] **Step 5: Commit**

```bash
git add BehavioralAISubstrate/Sources/BASMemory/BASSemanticSnapshotCoordinator.swift \
  docs/superpowers/specs/qinao-owner-ledger-v1.json \
  scripts/check_qinao_owner_ledger.py \
  scripts/test_check_qinao_owner_ledger.py \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticSnapshotCoordinatorTests.swift
git commit -m "feat: coordinate immutable semantic snapshots"
```

### Task 4A: Adapt QinaoMemory to the Scoped K3/StateLake Authority and Close Erasure

Task 4A is a hard prerequisite for Task 4B and every retrieval/context integration task. It extends existing owners and façades; it creates no memory database, EventLog, StateLake actor, erasure actor, or receipt authority.

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASMemoryAtomStore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASMemoryAtomEventPayload.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASEventSourcedMemoryAtomStore.swift`
- Modify migration-input retirement: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASSQLiteMemoryAtomStore.swift`
- Modify checkpoint/cutover owner: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLog.swift`
- Modify checkpoint/cutover owner: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoMemory/QinaoMemory.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoMemory/QinaoForgetReceipt.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEventSourcedMemoryAtomStoreTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASMemoryContentAuthorityMigrationTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASMemoryErasureClosureTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoMemoryTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoMemoryScopeIsolationTests.swift`

**Reuse Decision (E/A):** `BASEventLogStorage`/`BASSQLiteEventLogStorage` from Task 2 remain the sole K3 scope/deletion/erasure and memory-content cutover authority, `BASArtifactStorePort` remains the sole content-byte owner, and `BASEventSourcedMemoryAtomStore` remains the existing event-first memory projection. Extend its event payload with a content artifact reference and make `QinaoMemory` a forwarding façade. `BASSQLiteMemoryAtomStore` is a bounded read-only migration input only until one sealed K3 checkpoint flips all content authority; it is never a second writer or fallback. Do not create `QinaoMemoryStore`, `QinaoErasureSaga`, a second receipt ledger, a migration database, a local content truth, or a second frontstage ranker.

**Interfaces:**
- Consumes: `BASAttemptVisibilityScope`, one `BASArtifactStorePort`, one event-sourced `BASMemoryAtomStore`, the same K3 `BASErasureClosurePort`, K3's sealed integrity checkpoint/head, the legacy atom/event projection as a read-only migration input, and one snapshot reopener that validates `BASStateReadSnapshot` against that K3 head.
- Produces: scope-required Qinao admission/recall/frontstage/forget APIs, governed encrypted-at-rest `BASMemoryAtomContentPayload` artifacts, one governed `BASMemoryContentAuthorityCheckpointPayload`, current memory events bound to `contentArtifactID`, one atomic K3 all-old→all-new authority cutover, and compatibility forget receipts projected only from durable `BASErasureClosureReceipt`.

- [ ] **Step 1: Write failing scope, content-truth, and erasure tests**

```swift
func testMissingScopeTouchesNoMemoryOrProjectionOwner() async throws {
    let fixture = makeQinaoMemoryFixture(scope: nil)
    await XCTAssertThrowsErrorAsync { _ = try await fixture.memory.recallFrontstage(scope: nil) }
    let k3ReadCount = await fixture.k3.readCount
    let artifactReadCount = await fixture.artifacts.readCount
    let projectionCallCount = await fixture.projections.totalCallCount
    XCTAssertEqual(k3ReadCount, 0)
    XCTAssertEqual(artifactReadCount, 0)
    XCTAssertEqual(projectionCallCount, 0)
}

func testPrivateWindowMarkerNeverCrossesWindowOrLeaksMembershipTiming() async throws {
    let fixture = makeQinaoMemoryFixture()
    let windowA = fixtureScope(workspace: "w", window: "a", attempt: "a1")
    let windowB = fixtureScope(workspace: "w", window: "b", attempt: "b1")
    _ = try await fixture.memory.admit(fixtureAdmit("private-marker"), scope: windowA)

    let result = try await fixture.memory.recallFrontstage(scope: windowB)
    XCTAssertFalse(result.contains { $0.content.contains("private-marker") })
    let projectionCalls = await fixture.projections.snapshot()
    let membershipTiming = await fixture.membershipTiming.classification
    XCTAssertEqual(projectionCalls.sql, 0)
    XCTAssertEqual(projectionCalls.fts, 0)
    XCTAssertEqual(projectionCalls.ann, 0)
    XCTAssertEqual(projectionCalls.rust, 0)
    XCTAssertEqual(projectionCalls.metal, 0)
    XCTAssertEqual(projectionCalls.context, 0)
    XCTAssertEqual(projectionCalls.grounder, 0)
    XCTAssertEqual(membershipTiming, .constantDeniedPath)
}

func testReplayReopensWinnerContentArtifactAndNeverBuildsHybridAtom() async throws {
    let fixture = try await admitEqualConfidenceSameIDWithDifferentContent()
    let before = try await fixture.store.allAtoms(scope: fixture.scope)
    let reopened = try fixture.reopenProcess()
    let after = try await reopened.store.allAtoms(scope: fixture.scope)
    XCTAssertEqual(after, before)
    XCTAssertEqual(after.first?.content, fixture.winningContent)
    let cacheCount = await reopened.store.processContentCacheCountForTesting
    XCTAssertEqual(cacheCount, 0)
}

func testAdmittedEventCarriesArtifactReferenceAndCommitmentNotRawContent() throws {
    let payload = fixtureAdmittedMemoryEventPayload()
    XCTAssertEqual(payload.contentArtifactID, fixtureArtifactID("memory-content"))
    XCTAssertFalse(payload.contentCommitment.isEmpty)
    let labels = Set(Mirror(reflecting: payload).children.compactMap(\.label))
    XCTAssertFalse(labels.contains("content"))
    XCTAssertFalse(labels.contains("contentBytes"))
}

func testForgetCannotCompleteBeforeEveryProjectionACKAndRescan() async throws {
    let fixture = makeQinaoMemoryFixture()
    let requested = try await fixture.memory.forgetAll(scope: fixture.scope)
    XCTAssertNotEqual(requested.executionState, .completed)
    for owner in BASErasureProjectionOwner.allCases.dropLast() {
        try await fixture.ack(owner)
    }
    let beforeFinalACK = try await fixture.currentReceipt()
    XCTAssertNotEqual(beforeFinalACK.rank, .completed)
    let finalOwner = try XCTUnwrap(BASErasureProjectionOwner.allCases.last)
    try await fixture.ack(finalOwner)
    try await fixture.recordKeyAbsenceAndClosureRescan()
    let completed = try await fixture.currentReceipt()
    XCTAssertEqual(completed.rank, .completed)
}
```

Add crash/restart and logical-clock rollback at every `BASErasureRank`, plus old-snapshot/no-resurrection tests. An unavailable Provider or backup must end at `.erasureIndeterminate`, remain quarantined, and never be rendered as verified/completed erasure.

In `BASMemoryContentAuthorityMigrationTests`, pin a historical corpus containing admitted/update/remove events, duplicate/conflicting atom rows, private-window partitions, pending/completed erasure, and post-checkpoint tail mutations. Prove: before the authority flip every read is all-old; after it every read is all-new; no process can observe a row with new metadata and old/raw bytes or old metadata and a new artifact; crash/reopen at the sealed checkpoint, before/after every Artifact put, staged mapping, ordinary tail replay, durable finalizing-fence commit, fence→checkpoint put/reopen, final K3 commit, and legacy retirement resumes idempotently. Inject a real memory command at the old checkpoint-put-before-fence window and at both sides of the new fence transaction: it is either captured in the frozen head or rejected while finalizing, never omitted. Assert commands remain blocked across restart, the same fence epoch/head is reused, no checkpoint put occurs before the fence commit, and a parity failure leaves `.finalizing` installed. Migrated live count, canonical content digest, commitment, ordering, and scope partition must equal a cold replay of the old truth; a cold restart after flip reopens every winner Artifact with no loss; deletion epoch/tombstone always wins over staged/live content; and legacy write/read fallback is unreachable after cutover. The retirement gate fails if one live old row lacks a verified Artifact mapping, one deleted row can resurrect, any digest/count differs, or any migration source remains writable.

- [ ] **Step 2: Remove process-local content and deletion truth**

Extend `BASMemoryAtomEventPayload` admitted events with mandatory `contentArtifactID: BASArtifactID` and `contentCommitment: String`. Bind both to the admitted event and winning event identity. `BASEventSourcedMemoryAtomStore` reopens that artifact through its injected `BASArtifactStorePort` only after scope/snapshot eligibility succeeds; delete `contentCache`, ignore neither missing content nor winner mismatch, and fail closed rather than returning an empty string. Equal-confidence/same-ID conflicts select one exact event before reopening content, so metadata and bytes can never come from different contenders.

Extend the existing `BASMemoryAtomStore` surface with scope-required operations; the scope is the Task-1 `BASAttemptVisibilityScope`, not `BASMemoryScope`'s category enum and not a loose digest. `BASEventSourcedMemoryAtomStore` validates the current generation/deletion epoch through its injected K3 port before replay/materialization and again before returning bytes. Legacy row stores become explicit read-only migration projections in production composition and may not accept authoritative writes.

Declare `BASMemoryAtomContentPayload` beside the existing event payload as one self-ID-free `BASSchemaVersioned, Codable, Sendable, Equatable` value with `currentSchemaVersion = "1.0.0"`, visibly stored `schemaVersion`, canonical UTF-8 content bytes, plaintext content commitment, confidentiality label, and encryption-policy Artifact ID; its explicit public initializer has `schemaVersion: String = Self.currentSchemaVersion` first. It contains no Artifact ID, key bytes, storage locator, scope digest, or deletion authority. In that same existing file, declare `BASMemoryContentAuthorityCheckpointPayload` as the second self-ID-free governed parent, also current 1.0.0 with a schema-first public initializer. It binds migration epoch, sealed source head, `finalizationFenceEpoch`, frozen final/through-tail head including sequence/event ID/integrity digest/row hash, frozen authority/scope/deletion/policy epochs, ordered typed checkpoint entries, live/tombstone counts, canonical logical-key digest, and content-commitment aggregate digest. Each nested entry binds the exact logical scope/atom key, winning event identity, deletion epoch, optional content Artifact ID+commitment, and tombstone state; entries are canonically ordered and unregistered. Final K3 byte-validates every fence/head/epoch field against the persisted `.finalizing` row before cutover. Neither parent carries its own Artifact ID.

Every put, identity, and reopen of both parents uses only `BASGovernedArtifactPayloadCodec`; the existing Artifact store must return a storage envelope with the required nonnil encryption key ID/metadata and confidentiality label before an event/checkpoint can reference its receipt. Do not invent a BASMemory cipher/key manager or write plaintext into a migration control row. Register both types exactly once through BASAdmin's normal metatype entries with exact `schema.<Type>.current/backward_v1/future_rejection` IDs, current codec round-trip, pinned-v1 fixture, missing/future rejection, owner-version parity, and cross-target public-default-initializer fixtures.

Make the current admitted `BASMemoryAtomEventPayload` shape explicit and non-optional: add `eventPayloadVersion == "1.0.0"`, `contentArtifactID`, and `contentCommitment`, and require them for every new `.admitted` event; mutation/removal events keep those two fields absent under operation-specific validation. Do not teach its ordinary decoder to accept an old missing field. Historical pre-cutover EventLog JSON is decoded only by one private bounded `BASLegacyMemoryAtomEventPayloadV0` with the exact old CodingKeys and joined by exact atom/event identity to the matching raw row in read-only `BASSQLiteMemoryAtomStore`; missing, duplicate, digest-mismatched, cross-scope, or already-deleted raw rows fail the migration. That legacy decoder is callable only by the migration owner while authority is `.legacy`, `.copying`, or durably `.finalizing`, and in `.finalizing` only through the persisted frozen head. It is never callable after `.artifactV1`. New tail events always use the current shape.

Implement the migration as one resumable sealed-checkpoint algorithm split only across the existing owners. `BASEventSourcedMemoryAtomStore` owns deterministic enumeration/replay and Artifact transformation; `BASSQLiteEventLogStorage` owns the checkpoint, migration epoch, final write fence, EventLog append, and authority-head flip. Its K3 migration control row stores only status, checkpoint head/row hash, migration epoch, source/staged live counts and canonical aggregate digests, last verified logical key, and final cutover head—never content bytes. The exact sequence is:

1. In one K3 `BEGIN IMMEDIATE`, verify the EventLog integrity/HWM chain, capture one sealed checkpoint head plus deletion/policy epochs, install a unique migration epoch in `.copying`, and leave authority `.legacy`. New memory writes continue only through the old K3/event path and are therefore an ordered tail; the new projection is invisible and cannot serve reads.
2. Deterministically enumerate the complete historical atom/event truth at that checkpoint in canonical scope/atom/event order. For each replay-winning live content value, construct current `BASMemoryAtomContentPayload`, encode only through `BASGovernedArtifactPayloadCodec`, ordinary-put it with required Artifact-store encryption, reopen/identity/equality-check it, and stage only `(migrationEpoch, logical atom key, winning event identity, contentArtifactID, contentCommitment, source digest/deletion epoch)` in K3. Byte-identical repeats return the same staged mapping; a same key with different bytes fails closed. Removed, tombstoned, quarantined, or erasure-covered winners stage a tombstone and no readable content mapping.
3. Resume after any crash by reopening the same sealed checkpoint and verified staged prefix. Recompute and compare every staged mapping before advancing the canonical last-key cursor; never trust a count/cursor alone. Artifact puts are content-addressed and may leave harmless unreachable artifacts, but no staged or orphan artifact becomes readable authority before the final flip.
4. Replay the ordered post-checkpoint EventLog tail into the invisible new projection and finish ordinary catch-up. Then call `beginMemoryContentFinalization`. Its sole `BASSQLiteEventLogStorage` implementation starts K3 `BEGIN IMMEDIATE`, verifies the migration epoch, current source head/row hash, scope/deletion/policy epochs and staged parity, allocates one unique nonreusable finalization-fence epoch, persists status `.finalizing` plus the **frozen final head, row hash, and authority/scope/deletion/policy epochs**, switches every memory command admission path to fail/retry while that fence is installed, and commits. The durable fence survives process death. No checkpoint Artifact is constructed or put before this commit. A memory event injected in the former catch-up→checkpoint window must either precede and be included in the frozen head or lose to the fence; it can never appear between the checkpoint and authority flip.
5. With commands still blocked, resume or replay the invisible new projection **only through the frozen final head**. Recompute full source/staged live+tombstone counts, canonical ordered keys, row hashes, per-content commitments, and aggregate digests; construct, central-codec ordinary-put, reopen, identity/equality-check one governed `BASMemoryContentAuthorityCheckpointPayload` bound to that exact head/fence/epochs. Crash after the fence or any put resumes the same persisted fence epoch and frozen head; it never takes a new head, releases commands, or trusts an orphan checkpoint. In one final K3 `BEGIN IMMEDIATE`, require the identical `.finalizing` row, fence epoch, frozen head/row hash/epochs, full parity values, and exact reopened checkpoint ID/bytes. Atomically append `.memoryContentAuthorityCutover` through `appendLocked`, change authority `.legacy → .artifactV1`, bind checkpoint/cutover head, and release blocked commands in the same commit. A mismatch rolls back while leaving the durable finalizing fence installed for deterministic repair/resume. Readers therefore see all-old before the final commit or all-new after it—never a mixed epoch or dual writer. Post-cutover replay opens the governed checkpoint through the central codec and applies only current events strictly after its frozen through-tail head; it never double-applies the cutover row, decodes old admitted JSON, or queries a raw row.
6. After cold restart revalidates the cutover event/head and reopens every live Artifact, make `BASSQLiteMemoryAtomStore` permanently read-only/retired in production composition, remove raw content/cache material, and record its purge-or-absence receipt in the existing erasure closure. Retirement never precedes parity proof; after authority `.artifactV1`, legacy read fallback and every direct atom write throw even if physical rows remain for audited rollback evidence.

Raise the existing K3 SQLite schema version exactly once in Task 4A with the numbered `k3-memory-content-authority-v1` migration embedded in `BASSQLiteEventLogStorage.swift`. It creates only `k3_memory_content_migration` and `k3_memory_content_stage`. The migration row is unique per workspace-authority Artifact storage scalar and stores migration epoch, `legacy|copying|finalizing|artifact_v1|retired`, sealed and cutover EventLog head scalars/digests/row hashes, deletion/policy epoch, source/staged live+tombstone counts/digests, last verified canonical key, checkpoint Artifact storage scalar, and cutover event ID. Its finalizing columns additionally store the unique fence epoch, frozen final sequence/event ID/integrity digest/row hash, frozen authority/scope/deletion/policy epochs, and fence-installed flag; check constraints require those fields all-nil outside `.finalizing|artifact_v1|retired` and all-present while finalizing. The stage primary key is `(workspace_authority_artifact_id, migration_epoch, canonical_scope_key, atom_id)` and stores winning event ID, source digest, deletion epoch, tombstone bit, optional content Artifact storage scalar, and commitment; check constraints require tombstone XOR complete content pair. Both tables have no raw payload/content/key bytes and every Artifact ID bind/read uses the Contracts `storageScalar` codec.

Expose this only as the package `BASK3MemoryContentAuthorityPort` beside `BASEventLogStorage`, implemented solely by `BASSQLiteEventLogStorage`: `beginMemoryContentMigration(authorityArtifactID:expectedHead:)`, `stageMemoryContentRecord(migrationRef:record:)`, `memoryContentMigrationState(migrationRef:)`, `beginMemoryContentFinalization(migrationRef:expectedHead:verifiedTailParity:)`, `finalizeMemoryContentAuthority(migrationRef:finalizationFence:checkpointArtifactID:verifiedParity:cutoverEvent:)`, and `markLegacyMemoryContentRetired(migrationRef:purgeReceiptArtifactID:)`. The begin-finalization receipt carries the persisted fence epoch plus frozen final head/row hash/epochs; finalize accepts that exact typed receipt and no caller-selected replacement head. Low-entropy request/receipt values carry typed Artifact IDs, heads, epochs, counts, and digests only; no raw content or decoder closure crosses the port. Every memory command checks the same control row and is blocked while `.finalizing`; finalize calls `appendLocked`, flips authority, and releases the fence in one transaction. No other conformer is allowed in production, and no Qinao/public API exposes the migration port.

There is no time/percentage rollout, best-effort row skip, background dual-write window, mixed old/new read, migration-specific SQLite file, or reset-to-empty fallback. A failed or cancelled pass leaves authority `.legacy` and resumes the same migration epoch; after the head flip rollback requires a separately authorized forward migration, never reopening the raw writer.

- [ ] **Step 3: Make QinaoMemory a façade over those exact injected owners**

Remove `QinaoMemory.store`, `cascadeReceipts`, `defaultCacheRefs`, and every scope-optional recall/frontstage path. The production initializer requires the one scoped event-sourced memory port, the same K3 `BASErasureClosurePort`, Artifact Mesh, and snapshot reopener. `admit(_:scope:)` constructs current `BASMemoryAtomContentPayload`, encodes/ordinary-puts/reopens it only through `BASGovernedArtifactPayloadCodec`, verifies the encrypted storage envelope, then appends one current-version event with that receipt's Artifact ID and exact commitment. `recall(scope:...)`, `recallFrontstage(scope:)`, and `frontstageBundle(scope:activeHostVersion:)` reopen the current snapshot, validate exact workspace/window/Attempt plus policy/deletion epochs, and delegate once; they never rank a copied array.

Replace local forget completion with `forget(id:scope:)`, `forget(scope:)`, and `forgetAll(scope:)` that call K3 `beginErasure`. `QinaoForgetCascadeReceipt` becomes a compatibility projection of `BASErasureClosureReceipt`: `.completed` is representable only for rank `.completed`; `.erasureIndeterminate` is explicit; cache invalidations are derived from persisted owner ACK artifact IDs, never hard-coded strings. `cascadeLedger()` reads K3 receipts and owns no array.

In `QinaoRuntime.sendSession`, remove scope-free `memory.frontstageBundle()` injection. Production turn inputs must supply the canonical scope/snapshot closure; when a caller does not provide an explicit bundle, the runtime calls `frontstageBundle(scope:)` once. Missing or stale scope fails before K3/StateLake/projection/provider work. `QinaoSovereignHostAssembly` injects the same concrete K3/EventLog, Artifact Mesh, scoped event store, and snapshot reopener; it never constructs a second memory or erasure authority.

- [ ] **Step 4: Run GREEN and prove no local truth remains**

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter 'BASMemoryErasureClosureTests|BASMemoryContentAuthorityMigrationTests|BASEventSourcedMemoryAtomStoreTests|BASEventLogSemanticSnapshotTests|BASEBrainSchemaGovernanceRegistryTests'
swift test --package-path "$ROOT/QinaoRuntimeSDK" \
  --filter 'QinaoMemoryTests|QinaoMemoryScopeIsolationTests'
if rg -n 'private var store:|contentCache|cascadeReceipts|defaultCacheRefs|recallFrontstage\(\)|frontstageBundle\(\)' \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoMemory/QinaoMemory.swift" \
  "$ROOT/BehavioralAISubstrate/Sources/BASMemory/BASEventSourcedMemoryAtomStore.swift"; then
  exit 1
fi
rg -q 'CREATE TABLE IF NOT EXISTS k3_memory_content_migration' \
  "$ROOT/BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift"
rg -q 'CREATE TABLE IF NOT EXISTS k3_memory_content_stage' \
  "$ROOT/BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift"
test "$(rg -n 'struct BASLegacyMemoryAtomEventPayloadV0' \
  "$ROOT/BehavioralAISubstrate/Sources/BASMemory" --glob '*.swift' | wc -l | tr -d ' ')" = 1
! rg -n 'BASLegacyMemoryAtomEventPayloadV0' \
  "$ROOT/BehavioralAISubstrate/Sources/BASMemory" --glob '*.swift' \
  -g '!BASEventSourcedMemoryAtomStore.swift'
! rg -n 'JSON(Encoder|Decoder)' \
  "$ROOT/BehavioralAISubstrate/Sources/BASMemory/BASEventSourcedMemoryAtomStore.swift" \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoMemory/QinaoMemory.swift" | \
  rg 'BASMemoryAtomContentPayload|BASMemoryContentAuthorityCheckpointPayload'
test "$(rg -n 'BASMemoryAtomContentPayload|BASMemoryContentAuthorityCheckpointPayload' \
  "$ROOT/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift" | wc -l | tr -d ' ')" = 2
```

Expected: all tests pass; a denied window invokes no projection/provider path; crash injection always reopens the all-old or all-new authority; checkpoint/count/digest/commitment parity and cold-restart content are exact; tombstones never resurrect; legacy decode/write/read fallback is absent after cutover; every erasure owner ACKs before rescan/completion; the inverted scans find no local truth or ungoverned content/checkpoint path.

- [ ] **Step 5: Commit**

Commit only the files listed in Task 4A—including the K3 checkpoint/cutover owner, both schema-registry files, and `BASMemoryContentAuthorityMigrationTests.swift`—with message `feat: scope qinao memory and close erasure`. Do not split the governed payload/event shape, staged migration, atomic head flip, cold-restart proof, and raw-row retirement across commits; the candidate tree must expose either the complete legacy authority or the complete Artifact authority.

### Task 4B: Enforce One Complete CacheScopeContract Across Every Cache

Task 4B begins only after Task 4A's deletion epoch and erasure closure are green. It adds no cache owner; each current cache remains a disposable mechanism keyed and acquired through Task 1's canonical values.

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMLXAdapter/BASSessionKVStore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+SessionPersist.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrgan/BASLLMPromptCache.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASKVCacheRegistry.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASCacheScopeContractTests.swift`

**Reuse Decision (E/A):** extend current session/KV/prompt/prefix owners to consume one `BASCacheScopeContract`; do not create another cache registry, cache-key builder, session map, epoch map, or invalidation authority. `BASKVCacheRegistry` is compatibility plumbing only, and `BASLLMPromptCache` stays production-disabled until it accepts the full contract.

- [ ] **Step 1: Write exhaustive field-mutation and multi-window RED tests**

For every stored field in `BASPhysicalContentKey` and `BASAcquisitionScope`, mutate exactly that field and assert rejection occurs before cache metadata, bytes, MLX arrays, Rust/Metal state, or membership timing are touched. Add these named tests:

```swift
func testSameSessionAndContentInTwoPrivateWindowsNeverAlias() async throws
func testEveryPhysicalContentKeyMutationMissesBeforeStateBytesAreTouched() async throws
func testEveryAcquisitionScopeMutationMissesBeforeMembershipLookup() async throws
func testSameCompartmentCrossAttemptReuseRequiresFreshAcquisition() async throws
func testDecodeOnlySamplingChangeMayReuseExactPrefixButCreatesFreshDecodeState() async throws
func testAnyPrefillSemanticOrStateABIMutationForcesCanonicalRefill() async throws
func testDeletionRestorationOrPolicyEpochPurgesRAMAndSpill() async throws
func testPersistedSnapshotCannotBeRestoredUnderAnotherSessionRoleOrWindow() async throws
```

- [ ] **Step 2: Apply the contract before lookup in every current cache**

Persist the complete versioned `BASCacheScopeContract` beside session/KV/prefix bytes. Replace `sessionID#role`, model-only, filename-only, prefix/suffix-hash-only, and caller-selected restore URL admission with canonical `BASPhysicalContentKey` plus a freshly verified `BASAcquisitionScope`. The lookup order is fixed: bounded-decode metadata → canonical-field validation → exact current scope/generation/epoch comparison → authorized compartment comparison → only then open/read/mmap/deserialize state bytes. A denial executes a constant denied path and exposes neither membership nor candidate count.

The physical key may be shared across Attempts only inside one explicitly authorized visibility compartment. Every use still obtains a fresh Attempt-bound acquisition; full continuation checkpoints remain same-Attempt. Sampling/RNG/stop/max-output changes do not falsely invalidate immutable prompt-prefix bytes, but always create fresh decode-only state and a fresh full invocation contract. Any tokenizer/template/tool protocol, model image, modality, provenance, StateABI, token-boundary, position, compartment, or private-domain mutation misses and canonically re-prefills.

`MLXOrganAdapter+SessionPersist` must persist the exact token-history digest/count and refuse URL rebinding to another session/role/window. `BASKVCacheRegistry` accepts a prevalidated contract and owns no scope constructor. `BASLLMPromptCache` uses a cryptographic canonical-byte key over the complete physical key and stays unreachable from production until the acquisition checks are wired. Deletion/policy/restoration advances synchronously invalidate RAM index entries and spill files before returning the K3 ACKs required by Task 4A. Session, KV, prefix, neural, spill, and compiled-context owners each emit and persist their own purge-or-absence receipt; the adapter cannot coalesce them into one cache ACK.

- [ ] **Step 3: Run GREEN and the one-contract scan**

```bash
ROOT=/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate
swift test --package-path "$ROOT" \
  --filter 'BASCacheScopeContractTests|BASMLXSessionKVStoreTests|BASMLXUnifiedLeaseTests'
test "$(rg -n '^public struct BASCacheScopeContract' "$ROOT/Sources" --glob '*.swift' | wc -l | tr -d ' ')" = "1"
if rg -n 'sessionID \+ "#"|prefixHash.*suffixHash|restoreSession\([^)]*url[^)]*sessionID' \
  "$ROOT/Sources/BASMLXAdapter" "$ROOT/Sources/BASOrgan/BASLLMPromptCache.swift" "$ROOT/Sources/BASHostKit/BASKVCacheRegistry.swift"; then
  exit 1
fi
```

Expected: exhaustive mutations and two-window isolation pass, stale scope is rejected before bytes/membership timing, and only the Task-1 contract exists.

- [ ] **Step 4: Commit**

Commit only the files listed in Task 4B with message `feat: enforce complete cache scope`.

### Task 5: Adapt Existing SQL, RAG/Vector, FTS, Temporal, Entity, and Memory-Horizon Mechanisms into Snapshot-Bound Lanes [W3 Pure Lanes; W4 Production Memory Wiring]

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASMemoryAtomStore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASSQLiteMemoryAtomStore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASMemoryUsageTracker+ReplayAuditFTS.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASRAGRetriever.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASVectorIndex.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASSQLiteVectorIndexStorage.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASRoutedVectorIndexStorage.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASVectorReranker.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASSharedStateGraphStorage.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASSharedStateGraphSQLiteStorage.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/MemoryHorizonPersistenceCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/EBrainKnowledgePlaneCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASL8RoutedMemoryService.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntime+MemoryService.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASMemorySleepConsolidationPass.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASSleepConsolidationDriver.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASConsolidationCheckpoint.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASBlueprintHexagonalTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticStateLaneAdapterTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASMemoryHorizonProjectionTests.swift`

**Reuse Decision (E/A):** Retrieval mechanisms, temporal records, horizon persistence policy, and the off-turn sleep/consolidation pass already exist. Extend their current query/storage entrypoints to require and physically apply Task 3's `BASCompiledLaneEligibilityPredicate` before candidate enumeration, FTS, corpus construction, ANN/Rust/Metal, context construction, or reranking. Adapt temporal records to `BASBitemporalInterval`, and have the current consolidation pass emit ordinary Artifact Mesh `BASMemoryHorizonManifestPayload` projections over the one EventLog rather than copying memories. Then add one generic adapter in the current L8 composition file; do not create a BM25 owner, five lane classes, a horizon enum parallel to `BASMemoryHorizon`, a horizon store, another scheduler, another eligibility judge, or another memory owner. The pre-query value is an executable projection of L7 policy; Task 6's global hard gate remains the sole candidate-level admission authority. HostKit scopes the mechanism with the silicon plan's injected ledger/context seam; the adapter and consolidation adaptation have no independent ranking, persistence, retry, index-build, embedding-build, cache, reservation map, cap, EventLog pruning, or checkpoint-sealing authority.

The production composition reuses these owners unchanged:

| Lane | Existing mechanism owner |
|---|---|
| `sqlMetadata` | `BASMemoryAtomStore` / `BASSQLiteMemoryAtomStore.allAtoms()` and current governed-record projection |
| `exactLexical` | Extend `BASMemoryUsageTracker.searchNotesFTS(query:)` in `BASMemoryUsageTracker+ReplayAuditFTS.swift` with an additive bounded score-returning sibling that reads SQLite FTS5 `rank` (default `bm25(...)`) and orders by `rank`; route it through the existing usage-extras composition |
| `denseSemantic` | `BASRAGRetriever`, `BASVectorIndex`, `BASSQLiteVectorIndexStorage`, or `BASRoutedVectorIndexStorage` selected by current HostKit composition |
| `temporalEpisode` | `BASTemporalMemoryField`, `BASTemporalMemoryRecord`, episode arcs, and their existing stores/projections |
| `entityRelation` | `BASSharedStateGraph` and `BASSharedStateGraphStorage` read APIs |

**Interfaces:**
- W3 consumes only injected snapshot/requirement-plan reopeners over the same Artifact Mesh, Task 3's one full-field `validateCompiledEligibility`, and test-injected existing-view `freeze`/`query` closures; each query closure receives the already exact-validated `BASCompiledLaneEligibilityPredicate` and lowers it into the mechanism's physical partition/native predicate before touching that mechanism. W3 produces one pure `BASExistingSemanticLaneAdapter: BASSemanticStateLane` used for all five lane IDs and the existing FTS5 extension; it has no process-ledger dependency.
- W3 horizon projection additionally consumes the same EventLog read/integrity view, same Artifact Mesh, exact K3-bound `BASCalendarPolicyPayload`, existing `BASMemoryHorizonPersistencePolicy`, `BASTemporalMemoryField`/`BASTemporalMemoryRecord`, and current sleep pass/driver/checkpoint. It produces only manifest Artifact IDs and audit projection receipts. The current `BASConsolidationCheckpoint` remains a run/audit checkpoint and is explicitly ineligible for `sealedLosslessCheckpointArtifactID`; until an existing EventLog compaction owner can seal lossless bytes plus replay-equivalence and retention receipts, production uses `.originalEventLog` and pruning remains denied.
- W4 production composition additionally consumes the same injected `BASProcessMemoryLedger` actor, a per-turn `@Sendable (UInt64) async throws -> BASMemoryAdmissionContext` closure, the existing `BASSystemProbe` observation projection, and current owner-provided resident/transient estimates and dense-profile certification fact. This is wiring around the W3 adapter, not a change to its domain contract or a new owner.

- [ ] **Step 1: Write failing adapter-purity and snapshot-binding tests**

```swift
import XCTest
@testable import BASMemory
@testable import BASHostKit

final class BASSemanticStateLaneAdapterTests: XCTestCase {
    func testExistingFTSUsesHiddenRankWithBoundedStableBinaryTieBreak() async throws {
        let tracker = try makeSQLiteUsageTracker()
        try await tracker.attachNotes(recordID: "b", notes: "alpha")
        try await tracker.attachNotes(recordID: "a", notes: "alpha")
        try await tracker.attachNotes(recordID: "c", notes: "alpha alpha alpha")
        let searchMatches = try await tracker.searchNotesFTSRanked(
            query: "alpha", eligibleRecordIDs: ["a", "b", "c"], limit: 3
        )
        let matches = try XCTUnwrap(searchMatches)
        XCTAssertEqual(Set(matches.map(\.recordID)), Set(["a", "b", "c"]))
        XCTAssertTrue(matches.allSatisfy { $0.rankScore.isFinite && $0.rankScore <= 0 })
        XCTAssertTrue(zip(matches, matches.dropFirst()).allSatisfy { pair in
            let (left, right) = pair
            left.rankScore < right.rankScore
                || (left.rankScore == right.rankScore
                    && left.recordID.utf8.lexicographicallyPrecedes(right.recordID.utf8))
        })
        let boundedSearch = try await tracker.searchNotesFTSRanked(
            query: "alpha", eligibleRecordIDs: ["a", "b", "c"], limit: 2
        )
        let bounded = try XCTUnwrap(boundedSearch)
        XCTAssertEqual(
            bounded.map(\.recordID),
            matches.prefix(2).map(\.recordID))
        XCTAssertEqual(
            bounded.map(\.rankScore),
            matches.prefix(2).map(\.rankScore))
    }

    func testDenseLaneCallsExistingResolverOnceAndCanonicalizesPayloadOrder() async throws {
        let calls = CallCounter()
        let snapshotID = fixtureArtifactID("snapshot")
        let adapter = makeLaneAdapter(laneID: .denseSemantic) { _, _, _ in
            await calls.increment()
            return fixtureProjection(candidateKeys: ["dense-b", "dense-a"])
        }
        let result = await adapter.query(
            fixtureLaneQuery(laneID: .denseSemantic),
            queryArtifactID: fixtureArtifactID("query"),
            snapshotArtifactID: snapshotID
        )
        let callCount = await calls.value
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(result.orderedCandidates.map(\.candidateKey), ["dense-a", "dense-b"])
        XCTAssertEqual(result.semanticSnapshotArtifactID, snapshotID)
        XCTAssertEqual(result.laneID, .denseSemantic)
        XCTAssertTrue(
            Mirror(reflecting: result).children.compactMap(\.label)
                .allSatisfy { !$0.lowercased().contains("watermark") }
        )
    }

    func testAdapterReopensSnapshotAndRejectsTamperedWatermarkOrder() async throws {
        let fixture = makeLaneAdapterFixture(snapshotMutation: .reorderedWatermarks)
        let result = await fixture.adapter.query(
            fixtureLaneQuery(laneID: .denseSemantic),
            queryArtifactID: fixtureArtifactID("query"),
            snapshotArtifactID: fixture.snapshotArtifactID
        )
        let artifactReadCount = await fixture.artifactStore.readCount
        let mechanismCallCount = await fixture.mechanismCalls.value
        XCTAssertEqual(artifactReadCount, 1)
        XCTAssertEqual(mechanismCallCount, 0)
        XCTAssertEqual(result.status, .failed)
    }

    func testAdapterRejectsSnapshotMismatchBeforeMechanismRuns() async throws {
        let calls = CallCounter()
        let adapter = makeLaneAdapter(laneID: .sqlMetadata) { _, _, _ in
            await calls.increment()
            return fixtureProjection()
        }
        let result = await adapter.query(
            fixtureLaneQuery(
                laneID: .sqlMetadata,
                snapshotArtifactID: fixtureArtifactID("other-snapshot")
            ),
            queryArtifactID: fixtureArtifactID("query"),
            snapshotArtifactID: fixtureArtifactID("snapshot")
        )
        let callCount = await calls.value
        XCTAssertEqual(callCount, 0)
        XCTAssertEqual(result.status, .failed)
        XCTAssertTrue(result.orderedCandidates.isEmpty)
    }

    func testDeniedOrEmptyPhysicalPartitionCallsNoRetrievalMechanism() async throws {
        for lane in BASSemanticLaneID.allCases {
            let fixture = makeInstrumentedLaneFixture(
                laneID: lane,
                eligibilityMutation: .deniedWindowOrDeletionEpoch
            )
            let result = await fixture.adapter.query(
                fixture.query,
                queryArtifactID: fixture.queryID,
                snapshotArtifactID: fixture.snapshotID
            )
            XCTAssertEqual(result.status, .failed)
            XCTAssertTrue(result.orderedCandidates.isEmpty)
            let calls = await fixture.calls.snapshot()
            XCTAssertEqual(calls.sql, 0)
            XCTAssertEqual(calls.fts, 0)
            XCTAssertEqual(calls.ann, 0)
            XCTAssertEqual(calls.rust, 0)
            XCTAssertEqual(calls.metal, 0)
            XCTAssertEqual(calls.contextBuilder, 0)
            XCTAssertEqual(calls.reranker, 0)
            XCTAssertEqual(calls.grounder, 0)
        }
    }

    func testCompiledPredicateEqualsL7DecisionForEveryScopeMutation() async throws {
        for mutation in BASAttemptVisibilityScopeMutation.allCases {
            let fixture = makePredicateParityFixture(mutation: mutation)
            XCTAssertEqual(
                try fixture.adapter.compilePhysicalPredicateForTesting(
                    query: fixture.query,
                    snapshot: fixture.snapshot
                ).decision,
                fixture.l7ExpectedDecision
            )
        }
    }

    func testEveryCompiledPredicateFieldMutationStopsBeforeMechanism() async throws {
        for mutation in BASCompiledLaneEligibilityMutation.allCases {
            let fixture = makeInstrumentedLaneFixture(
                laneID: .denseSemantic,
                eligibilityMutation: mutation
            )
            _ = await fixture.adapter.query(
                fixture.query,
                queryArtifactID: fixture.queryID,
                snapshotArtifactID: fixture.snapshotID
            )
            let totalCalls = await fixture.calls.totalRetrievalAndContextCalls
            XCTAssertEqual(totalCalls, 0)
        }
    }

    func testLaneLocalEligibilityIsEvidenceNotGlobalAdmission() async throws {
        let result = await makeMemoryLaneAdapter(sourceAllowed: true).query(
            fixtureLaneQuery(laneID: .sqlMetadata),
            queryArtifactID: fixtureArtifactID("query"),
            snapshotArtifactID: fixtureArtifactID("snapshot")
        )
        XCTAssertTrue(result.orderedEligibilityEvidence.first?.sourceAllowed == true)
        XCTAssertFalse(result.orderedCandidates.isEmpty)
        // No BASHardEligibilityDecision is produced by the adapter.
    }
}
```

In `BASMemoryHorizonProjectionTests.swift`, make these RED cases use a fixed EventLog fixture and ordinary Artifact Mesh fixture—never the wall clock as ordering truth:

```swift
final class BASMemoryHorizonProjectionTests: XCTestCase {
    func testAmbiguousAndNonexistentDSTFollowSealedPolicy() async throws {
        let ambiguous = try await projectDay(
            localInstant: "2026-04-05T02:30:00",
            policy: fixtureMelbournePolicy(ambiguous: .laterOffset)
        )
        let nonexistent = try await projectDay(
            localInstant: "2026-10-04T02:30:00",
            policy: fixtureMelbournePolicy(nonexistent: .nextValidInstant)
        )
        XCTAssertEqual(ambiguous.resolvedOffsetChoice, .laterOffset)
        XCTAssertEqual(nonexistent.resolvedGapChoice, .nextValidInstant)
        await XCTAssertThrowsErrorAsync {
            _ = try await projectDay(
                localInstant: "2026-10-04T02:30:00",
                policy: fixtureMelbournePolicy(nonexistent: .reject)
            )
        }
    }

    func testCalendarTimezoneLocaleRuleOrWeekPolicyChangeInvalidatesNotRewrites() async throws {
        for mutation in BASCalendarPolicyMutation.allCases {
            let fixture = try await makeHorizonFixture(calendarMutation: mutation)
            XCTAssertNotEqual(fixture.oldCalendarArtifactID, fixture.newCalendarArtifactID)
            XCTAssertGreaterThan(fixture.rebuiltManifest.invalidationEpoch,
                                 fixture.oldManifest.invalidationEpoch)
            XCTAssertEqual(fixture.rebuiltManifest.orderedSourceEventRanges,
                           fixture.oldManifest.orderedSourceEventRanges)
            XCTAssertEqual(fixture.eventLogCanonicalBytesAfter,
                           fixture.eventLogCanonicalBytesBefore)
        }
    }

    func testClockRollbackCannotChangeTransactionOrderOrWindowMembership() async throws {
        let fixture = try await projectWithWallClockRollback()
        XCTAssertEqual(fixture.first.bitemporalInterval.transactionTime.eventOffsetStart, 40)
        XCTAssertEqual(fixture.second.bitemporalInterval.transactionTime.eventOffsetStart, 41)
        XCTAssertEqual(fixture.firstManifestID, fixture.replayedFirstManifestID)
        XCTAssertEqual(fixture.secondManifestID, fixture.replayedSecondManifestID)
    }

    func testErasureAndInvalidationRebuildBlindedTombstones() async throws {
        let fixture = try await projectThenEraseAndRebuild()
        XCTAssertGreaterThan(fixture.rebuilt.deletionEpoch, fixture.original.deletionEpoch)
        XCTAssertGreaterThan(fixture.rebuilt.invalidationEpoch, fixture.original.invalidationEpoch)
        XCTAssertEqual(fixture.rebuilt.coverage.blindedTombstoneCount, 1)
        XCTAssertFalse(fixture.rebuiltPayloadContainsErasedPlaintext)
    }

    func testWeekAndMonthReplayOriginalEventsNotLossyParentManifest() async throws {
        let fixture = try await makeDirectReplayEquivalenceFixture()
        XCTAssertEqual(fixture.weekFromOriginalEvents, fixture.weekExpected)
        XCTAssertEqual(fixture.monthFromOriginalEvents, fixture.monthExpected)
        XCTAssertEqual(fixture.weekManifest.replayBasis, .originalEventLog)
        XCTAssertEqual(fixture.monthManifest.replayBasis, .originalEventLog)
        XCTAssertThrowsError(try fixture.projectWeekUsingDayManifestAsTruth())
        XCTAssertThrowsError(try fixture.projectMonthUsingWeekManifestAsTruth())
    }

    func testPruningIsRejectedWithoutSealedLosslessCheckpointEquivalenceAndRetention() async throws {
        for missing in BASLosslessPruningEvidenceMutation.allCases {
            let fixture = makePruningFixture(missing: missing)
            await XCTAssertThrowsErrorAsync { try await fixture.pruneSourceRange() }
            let survivingCount = await fixture.eventLog.countInSourceRange
            XCTAssertEqual(survivingCount, fixture.originalCount)
        }
    }

    func testCrossWindowProjectionNeverAliasesPrivateScope() async throws {
        let fixture = try await makeTwoPrivateWindowHorizonFixture()
        XCTAssertNotEqual(fixture.windowAManifestID, fixture.windowBManifestID)
        XCTAssertTrue(fixture.windowARecords.isDisjoint(with: fixture.windowBRecords))
        XCTAssertThrowsError(try fixture.reopenAUnderWindowB())
    }
}
```

Keep W3 RED/GREEN limited to adapter purity, predicate lowering, FTS, snapshot binding, deterministic ordering, and test-injected mechanism closures. In the W4 wiring substep, add `testFiveOrdinaryLaneQueriesOverlapOnOneLedger`, `testDenseLaneIsHeavyOnlyForTheCertifiedProfile`, and `testRetrievalThrowCancellationAndContextDriftRetireTheExactReservation`. Suspend all five mechanism closures after compare-and-start and assert five active `.retrieval/.retrievalIndexAndLaneResult/.ordinary` reservations, no heavy owner, and zero reservations after release. Repeat with uncertified dense (ordinary), then certified dense competing with an already active neural heavy owner: dense must not start while the four ordinary lanes still progress, and the ledger must never expose more than one heavy activation. For throw, task cancellation, and changed epoch/context version between reserve and start, assert the mechanism is not called when start is denied and the isolated ledger ends with zero pending/active reservations.

- [ ] **Step 2: Run and verify RED**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASSemanticStateLaneAdapterTests|BASMemoryHorizonProjectionTests'
```

Expected: FAIL at compile time because `BASExistingSemanticLaneAdapter` and the horizon projection adaptation do not exist.

- [ ] **Step 3A [W3]: Extend the existing FTS5 query, then add one pure generic injected adapter**

In `BASMemoryUsageTracker+ReplayAuditFTS.swift`, preserve `searchNotesFTS(query:)` only as an explicit legacy/test surface. Add a non-persisted `BASMemoryNotesFTSMatch(recordID:rankScore:)` value and `searchNotesFTSRanked(query:eligibleRecordIDs:limit:) async throws -> [BASMemoryNotesFTSMatch]?`. Validate `limit > 0`, canonicalize a bounded duplicate-free eligible-ID partition from the pre-query predicate, and return an empty result without preparing/stepping FTS SQL when that partition is empty. Return `nil` when the tracker has no SQLite/FTS5 view. Its authoritative SQL binds every eligible ID before `MATCH`/ranking:

```sql
SELECT record_id,
       rank AS rank_score
 FROM memory_usage_record_notes_fts
 WHERE memory_usage_record_notes_fts MATCH ?
   AND record_id IN (<one bound placeholder per eligible record ID>)
 ORDER BY rank ASC,
          record_id COLLATE BINARY ASC
 LIMIT ?
```

Reject non-finite scores and assert the returned count never exceeds the bound. The exact-lexical projection uses `-rankScore` as the candidate's nonnegative relevance so the State Market's descending relevance order is exactly SQLite FTS5's ascending default BM25 order; it adds no weights, fusion, learned scorer, or ranker. A notes row enters `eligibleRecordIDs` only after the K3 scope/current-deletion-epoch comparison and governed-record mapping succeed. If the SQLite view is absent, the row cannot be governed/mapped, the partition is malformed, or only the in-memory substring fallback is available, return a typed `.unavailable` lane result; never query the broad FTS corpus and filter afterward.

Then add the adapter to the existing L8 composition file:

```swift
public struct BASExistingLaneProjection: Sendable, Equatable {
    public let orderedCandidates: [BASStateCandidate]
    public let orderedEligibilityEvidence: [BASLaneEligibilityEvidence]
    public let orderedConflictEvidence: [BASLaneConflictEvidence]
    public let completeness: BASLaneCompleteness
    public let status: BASLaneResultStatus
    public let terminalReceiptArtifactID: BASArtifactID
    public let completedLogicalTime: UInt64

    public init(
        orderedCandidates: [BASStateCandidate],
        orderedEligibilityEvidence: [BASLaneEligibilityEvidence],
        orderedConflictEvidence: [BASLaneConflictEvidence],
        completeness: BASLaneCompleteness,
        status: BASLaneResultStatus,
        terminalReceiptArtifactID: BASArtifactID,
        completedLogicalTime: UInt64
    ) {
        self.orderedCandidates = orderedCandidates
        self.orderedEligibilityEvidence = orderedEligibilityEvidence
        self.orderedConflictEvidence = orderedConflictEvidence
        self.completeness = completeness
        self.status = status
        self.terminalReceiptArtifactID = terminalReceiptArtifactID
        self.completedLogicalTime = completedLogicalTime
    }
}

public struct BASExistingSemanticLaneAdapter: BASSemanticStateLane {
    public typealias FreezeExistingView = @Sendable (BASEventLogHead, UInt64) async throws -> BASLaneWatermark
    public typealias ValidateCurrentScope = @Sendable (BASCompiledLaneEligibilityPredicate) async throws -> Void
    public typealias QueryExistingView = @Sendable (BASLaneQuery, BASStateReadSnapshot, BASCompiledLaneEligibilityPredicate) async throws -> BASExistingLaneProjection
    public typealias ReopenSnapshot = @Sendable (BASArtifactID) async throws -> BASStateReadSnapshot
    public typealias ReopenRequirementPlan = @Sendable (BASArtifactID) async throws -> BASStateRequirementPlan
    public typealias FailureArtifactWriter = @Sendable (BASLaneQuery, String) async -> BASArtifactID

    public let laneID: BASSemanticLaneID
    private let freezeExistingView: FreezeExistingView
    private let validateCurrentScope: ValidateCurrentScope
    private let queryExistingView: QueryExistingView
    private let reopenSnapshot: ReopenSnapshot
    private let reopenRequirementPlan: ReopenRequirementPlan
    private let failureArtifactWriter: FailureArtifactWriter

    public init(
        laneID: BASSemanticLaneID,
        freezeExistingView: @escaping FreezeExistingView,
        validateCurrentScope: @escaping ValidateCurrentScope,
        queryExistingView: @escaping QueryExistingView,
        reopenSnapshot: @escaping ReopenSnapshot,
        reopenRequirementPlan: @escaping ReopenRequirementPlan,
        failureArtifactWriter: @escaping FailureArtifactWriter
    ) {
        self.laneID = laneID
        self.freezeExistingView = freezeExistingView
        self.validateCurrentScope = validateCurrentScope
        self.queryExistingView = queryExistingView
        self.reopenSnapshot = reopenSnapshot
        self.reopenRequirementPlan = reopenRequirementPlan
        self.failureArtifactWriter = failureArtifactWriter
    }

    public func freeze(
        at eventLogHead: BASEventLogHead,
        schemaEpoch: UInt64
    ) async throws -> BASLaneWatermark {
        let watermark = try await freezeExistingView(eventLogHead, schemaEpoch)
        guard watermark.laneID == laneID else {
            throw BASSemanticStateContractError.snapshotMismatch
        }
        guard watermark.asOfEventSequenceNumber <= eventLogHead.sequenceNumber else {
            throw BASSemanticStateContractError.watermarkBeyondEventHead(laneID)
        }
        return watermark
    }

    public func query(
        _ query: BASLaneQuery,
        queryArtifactID: BASArtifactID,
        snapshotArtifactID: BASArtifactID
    ) async -> BASLaneResult {
        guard query.laneID == laneID,
              query.semanticSnapshotArtifactID == snapshotArtifactID else {
            return await failedResult(
                query: query,
                queryArtifactID: queryArtifactID,
                snapshotArtifactID: snapshotArtifactID,
                reason: "semantic-state:binding-mismatch"
            )
        }
        do {
            let snapshot = try await reopenSnapshot(snapshotArtifactID)
            try snapshot.validateComplete()
            guard query.requirementPlanArtifactID == snapshot.requirementPlanArtifactID,
                  snapshot.orderedLaneWatermarks.contains(where: { $0.laneID == laneID }) else {
                return await failedResult(
                    query: query,
                    queryArtifactID: queryArtifactID,
                    snapshotArtifactID: snapshotArtifactID,
                    reason: "semantic-state:snapshot-version-mismatch"
                )
            }
            let plan = try await reopenRequirementPlan(query.requirementPlanArtifactID)
            try BASStateRequirementPlanner.validateCompiledEligibility(
                query: query,
                plan: plan,
                snapshot: snapshot
            )
            let predicate = query.compiledEligibility
            try await validateCurrentScope(predicate)
            let projection = try await queryExistingView(query, snapshot, predicate)
            guard projection.orderedCandidates.count <= query.maximumCandidates,
                  projection.orderedCandidates.reduce(UInt64.zero, { $0 + $1.byteCount }) <= query.maximumBytes,
                  projection.orderedCandidates.reduce(0, { $0 + $1.tokenCost }) <= query.maximumTokens else {
                return await failedResult(
                    query: query,
                    queryArtifactID: queryArtifactID,
                    snapshotArtifactID: snapshotArtifactID,
                    reason: "semantic-state:lane-budget-exceeded"
                )
            }
            return BASLaneResult(
                laneQueryArtifactID: queryArtifactID,
                semanticSnapshotArtifactID: snapshotArtifactID,
                laneID: laneID,
                completeness: projection.completeness,
                status: projection.status,
                orderedCandidates: projection.orderedCandidates,
                orderedEligibilityEvidence: projection.orderedEligibilityEvidence,
                orderedConflictEvidence: projection.orderedConflictEvidence,
                terminalReceiptArtifactID: projection.terminalReceiptArtifactID,
                completedLogicalTime: projection.completedLogicalTime
            )
        } catch {
            return await failedResult(
                query: query,
                queryArtifactID: queryArtifactID,
                snapshotArtifactID: snapshotArtifactID,
                reason: "semantic-state:lane-error:\(String(describing: error))"
            )
        }
    }
}
```

`reopenRequirementPlan` reads the exact query-bound plan through the same `BASArtifactStorePort`, bounded-decodes it, and returns no process cache. The adapter then calls the Task-3 planner's one `validateCompiledEligibility` implementation; it never carries a second partial field checklist. Only after that full-value comparison succeeds may `validateCurrentScope` call Task 2's K3 scope/deletion/generation comparison. Both checks return before `withProcessMemoryAdmission` or a mechanism closure on mismatch. Each production query closure then lowers the exact same predicate into its current owner:

- SQL metadata binds workspace incarnation/window/visibility-compartment/current-deletion-epoch columns in the existing query before row enumeration; `allAtoms()` is never used for authoritative retrieval.
- FTS first derives the governed, scope-eligible record-ID partition without reading FTS membership, then binds that non-empty partition inside the FTS query together with `MATCH` and `LIMIT`; an empty partition returns without issuing FTS SQL.
- Dense entries persist the same mandatory physical partition fields. `BASVectorIndex.topK`, Rust batched fusion, and Metal scoring receive only the already partitioned corpus; excluded or empty domains are rejected before corpus allocation/scoring, never filtered afterward.
- `BASRAGRetriever` performs no embedding lookup, candidate-context build, rerank, or grounder call until the physical partition is accepted. Quarantined/deleted entries are absent from the eligible index projection, while Task 6 still rechecks candidate-specific governance.
- Temporal and entity mechanisms bind the same scope/snapshot/deletion predicate before traversal. All lane receipts record the predicate artifact/query reference and whether the physical partition was opened or denied, without copying scope into a second mutable tuple.

Implement `failedResult` by returning `.failed/.unavailable`, zero candidates/evidence, the exact `semanticSnapshotArtifactID` and `laneID`, and the failure payload artifact ID returned by `failureArtifactWriter`; it never carries a watermark field. Production wiring for that closure builds a canonical failure payload identity core, calls ordinary `put(identityCore:headUpdate:)`, and returns only `storeReceipt.body.artifactID`; it defines no lane-specific store receipt. The injected `reopenSnapshot` closure reads exactly that ID from the same `BASArtifactStorePort`, bounded-decodes `BASStateReadSnapshot`, calls `validateComplete()`, and verifies the embedded `eventLogHead` through the existing integrity-capable event log before returning it. The production composition supplies five instances of this same adapter over the current owners listed above. Current `BASMemoryEligibilityJudge.decide` and `BASMemoryConflictCluster` are translated to `BASLaneEligibilityEvidence` and `BASLaneConflictEvidence`; their allow/preferred values are never mapped to `BASHardEligibilityDecision` or `BASClaimResolutionState` here.

- [ ] **Step 3B [W4]: Add the sole production process-memory admission wrapper**

Only after the Silicon W4 ledger receipt is green, add one `internal` generic `withProcessMemoryAdmission` async function to this existing HostKit file and reuse it from Task 8 and the runtime plan; do not add a helper type/file. Its fixed order is: resolve verified context and sample a fresh `BASMemoryAdmissionObservation` → `reserve` → cancellation check → resolve the same per-turn capability snapshot again and resample observation → `compareAndStart` → operation → `complete` the exact activation. A pre-start throw/cancellation/context drift calls `cancelPending` with the exact reservation token; an active throw/cancellation calls `complete` with the exact activation. No async `defer` and no `try?` cleanup is permitted: a cleanup CAS error is surfaced as its typed ledger error (with the primary error retained in the existing failure artifact/audit), and a successful operation cannot be returned unless `complete` wins. W3 tests inject query closures directly and do not reference this helper or `BASProcessMemoryLedger`.

For every lane query, construct exactly one request with `workRootArtifactID = queryArtifactID`, `ownerID` deterministically derived from turn/snapshot/lane (never from an admission token), `phase = .retrieval`, `category = .retrievalIndexAndLaneResult`, `activationClass = .ordinary` except certified dense heavy, and the query deadline. Already-resident long-lived indexes contribute `residentBytes = 0`; a lazy not-yet-resident index load reserves only the incremental resident bytes. `maxTransientBytes` bounds source copies, mechanism scratch, and the lane-result value using current owner/query-plan estimates. The scoped operation contains the existing `queryExistingView` call and result construction. The five per-turn adapter values may capture the one resolver closure, but `BASLaneQuery`, `BASLaneResult`, projection, failure, lifecycle, and audit payloads gain no capability/admission field.

- [ ] **Step 3C [W3 E/A]: Adapt the existing temporal/horizon and sleep-consolidation files into EventLog projections**

Keep this slice entirely inside the five existing production files listed above; the only new file is the focused test. Implement the following ownership-preserving adaptation:

1. In `MemoryHorizonPersistenceCore.swift`, keep `BASMemoryHorizonPersistencePolicy` as the current claim-stability/contamination/evidence classifier. Add only pure mapping functions that return the canonical RuntimeCore `BASMemoryHorizon` and projection eligibility. Do not add another horizon enum, store, actor, timer, retention policy, or projection head. Cognitive kind, temporal horizon, physical tier, governance state, and authority scope remain orthogonal dimensions rather than one combinatorial enum.
2. In `EBrainKnowledgePlaneCore.swift`, make authoritative temporal records/candidate projection carry `BASBitemporalInterval`. Existing `timestamp` decoding is retained only as provenance observation metadata for old fixtures; it cannot determine valid time, transaction order, correction, retraction, supersession, or horizon membership. Corrections append at a new EventLog offset and close/supersede the previous transaction interval; they never rewrite `worldFrom/worldTo` or create another `validFrom`/`observedAt` axis.
3. Extend the current `BASMemorySleepConsolidationPass` with injected read-only EventLog range/integrity access, same-store Artifact Mesh put/reopen closures, and current exact-scope calendar-policy resolver. After its existing score/tier/quarantine stages, it may deterministically project the requested `current|day|week|month|archival` range and ordinary-put one self-ID-free `BASMemoryHorizonManifestPayload`. The pass reads source events or a separately certified sealed lossless checkpoint, preserves the canonical bitemporal intervals/provenance/blinded tombstones, records exact coverage/loss and policy/deletion/invalidation epochs, reopens the put artifact, and returns only its Artifact ID plus store receipt evidence. It never writes a memory copy, advances K3, prunes EventLog, or treats output text as source truth.
4. `BASSleepConsolidationDriver` remains the sole existing foreground/background gate. It passes a fixed EventLog high-water mark and current calendar Artifact ID into the same pass; it cannot create another schedule, infer a calendar from process defaults, use wall-clock order, or promote a manifest to authority. Task cancellation or a closed maintenance window leaves either no manifest or a fully stored immutable manifest, never a partial visible projection.
5. Extend `BASConsolidationCheckpoint` only with canonical ordered horizon-manifest Artifact IDs and their projection receipt IDs. This struct remains off-turn audit evidence, not the `sealedLosslessCheckpointArtifactID` payload and not a pruning permit. Dictionary-bearing legacy recommendation fields stay compatibility/audit-only and are never canonical horizon data.
6. For `.day`, compute boundaries only from the reopened `BASCalendarPolicyPayload`; for `.week`, use its `firstWeekday` and `minimumDaysInFirstWeek`; `.month` uses the same calendar identifier/rule build. Ambiguous and nonexistent local times follow the sealed enum cases. Timezone/locale/calendar/tzdb/ICU/OS-rule/week/day-boundary changes install a new policy Artifact ID, increment invalidation, and rebuild the same source events. Logical transaction order always comes from EventLog offsets, so wall-clock rollback is inert.
7. `.week`, `.month`, and `.archival` must set `replayBasis` from the actual direct source. With `.originalEventLog`, read and integrity-check every declared range. With `.sealedLosslessCheckpoint`, require the paired checkpoint and replay-equivalence receipt IDs, reopen and verify their exact source ranges/root, and reject a mismatch before projection. `orderedParentManifestHintArtifactIDs` may accelerate discovery/provenance only; no day/week/month manifest bytes may enter the reducer as source events.
8. No currently identified owner can seal a lossless EventLog checkpoint and retention authorization, so this plan ships the original-EventLog route and fail-closed optional checkpoint verifier only. `pruneEventsBefore` is never called by these five files. Any future pruning path must be E-in-place on the existing EventLog owner and require a sealed lossless checkpoint, exact range/root replay-equivalence receipt, retention-authorization receipt, current deletion/invalidation epochs, and a rebuild that preserves erased content as blinded tombstones. Missing one proof rejects without deleting a row.
9. Before query or reopen, exact-compare workspace incarnation, private window, Attempt generation, calendar policy Artifact ID, policy/deletion/invalidation epochs, EventLog ranges/root, and bitemporal interval. Cross-window use fails before manifest bytes or membership timing unless the canonical shared compartment explicitly authorizes both windows.

The production manifest factory takes the source range plus reopeners and derives all ordered arrays internally; it accepts no caller-provided coverage, loss, root, provenance, calendar digest, checkpoint-equivalence claim, or parent-as-source flag. Ordinary Artifact Mesh receipts remain the only manifest identity evidence, and no horizon-specific receipt/store protocol is introduced.

- [ ] **Step 4A [W3]: Run pure retrieval regressions and enforce the no-index rule**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASSemanticStateLaneAdapterTests|BASMemoryHorizonProjectionTests|BASMemorySleepConsolidationPassTests|BASSleepConsolidationDriverTests|BASBlueprintHexagonalTests|BASL8RoutedMemoryServiceTests|BASL8RoutedMemoryServiceVectorIndexTests|BASRAGRetrieverTests|BASSQLiteVectorIndexStorageTests|BASRankFuseSeamGateTests|BASTemporalMemoryFieldSchemaTests|BASSharedStateGraphTests'
if git diff -- BehavioralAISubstrate/Sources/BASMemory/BASMemoryUsageTracker+ReplayAuditFTS.swift \
  BehavioralAISubstrate/Sources/BASMemory/BASRAGRetriever.swift \
  BehavioralAISubstrate/Sources/BASMemory/BASVectorIndex.swift \
  BehavioralAISubstrate/Sources/BASMemory/BASSQLiteVectorIndexStorage.swift \
  BehavioralAISubstrate/Sources/BASMemory/BASRoutedVectorIndexStorage.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASL8RoutedMemoryService.swift | \
  rg 'CREATE (TABLE|INDEX|VIRTUAL TABLE)|sqlite3_open|Domain filtering is applied AFTER|filter.*after.*scor'; then
  exit 1
fi
HOST="$PWD/BehavioralAISubstrate/Sources/BASHostKit/BASL8RoutedMemoryService.swift"
if rg -n 'BASProcessMemoryLedger|withProcessMemoryAdmission|hardCapBytes:|private var .*([Rr]eservation|[Hh]eavy)' "$HOST"; then
  exit 1
fi
if rg -n 'CREATE (TABLE|INDEX)|sqlite3_open|pruneEventsBefore|calendarPolicyDigest|enum BASMemoryHorizon[ :{]' \
  BehavioralAISubstrate/Sources/BASMemory/MemoryHorizonPersistenceCore.swift \
  BehavioralAISubstrate/Sources/BASMemory/EBrainKnowledgePlaneCore.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASMemorySleepConsolidationPass.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASSleepConsolidationDriver.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASConsolidationCheckpoint.swift; then
  exit 1
fi
```

Expected: W3 tests PASS with 0 failures; denied predicates cause zero SQL/FTS/ANN/Rust/Metal/context/rerank/grounder calls, predicate parity matches L7 for every scope mutation, every horizon direct-replays EventLog under the sealed calendar/bitemporal policy, DST/rule-change/rollback/erasure/pruning/cross-window cases fail or rebuild exactly as specified, the diff scan finds no new index/store/horizon enum/pruning call/copied calendar digest/filter-after-score path, and the pure adapter has no ledger symbol.

- [ ] **Step 4B [W4]: Run production memory-wiring regressions**

Run `BASSemanticStateLaneAdapterTests|BASProcessMemoryLedgerTests` including the three W4 tests named in Step 1, require exactly one `withProcessMemoryAdmission` declaration in `BASL8RoutedMemoryService.swift`, and retain the source rejection of any ledger constructor, raw `hardCapBytes`, reservation map, or heavy-owner map. This gate is forbidden before the Silicon W4 ledger receipt.

- [ ] **Step 5: Commit W3 pure lanes, then a separate W4 production-wiring change**

```bash
git add BehavioralAISubstrate/Sources/BASHostKit/BASL8RoutedMemoryService.swift \
  BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntime+MemoryService.swift \
  BehavioralAISubstrate/Sources/BASMemory/BASMemoryAtomStore.swift \
  BehavioralAISubstrate/Sources/BASMemory/BASSQLiteMemoryAtomStore.swift \
  BehavioralAISubstrate/Sources/BASMemory/BASMemoryUsageTracker+ReplayAuditFTS.swift \
  BehavioralAISubstrate/Sources/BASMemory/BASRAGRetriever.swift \
  BehavioralAISubstrate/Sources/BASMemory/BASVectorIndex.swift \
  BehavioralAISubstrate/Sources/BASMemory/BASSQLiteVectorIndexStorage.swift \
  BehavioralAISubstrate/Sources/BASMemory/BASRoutedVectorIndexStorage.swift \
  BehavioralAISubstrate/Sources/BASMemory/BASVectorReranker.swift \
  BehavioralAISubstrate/Sources/BASMemory/BASSharedStateGraphStorage.swift \
  BehavioralAISubstrate/Sources/BASMemory/BASSharedStateGraphSQLiteStorage.swift \
  BehavioralAISubstrate/Sources/BASMemory/MemoryHorizonPersistenceCore.swift \
  BehavioralAISubstrate/Sources/BASMemory/EBrainKnowledgePlaneCore.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASMemorySleepConsolidationPass.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASSleepConsolidationDriver.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASConsolidationCheckpoint.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASBlueprintHexagonalTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticStateLaneAdapterTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASMemoryHorizonProjectionTests.swift
git commit -m "feat: adapt existing retrieval into semantic lanes"
```

After W4 Step 4B passes, commit only the HostKit process-memory wiring and its focused tests as a distinct W4 commit; do not amend the W3 lane/FTS commit or mix Provider grounding wiring into the pure adapter owner.

### Task 6: Canonical R5 Grounding Proposal, R6 Validation/Revalidation, Conflict Sets, and State Market [W3 Contract; W4 Production Provider Wiring]

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify: `/Users/changgeng/Project/Project06/Project06/scripts/check_qinao_owner_ledger.py`
- Modify: `/Users/changgeng/Project/Project06/Project06/scripts/test_check_qinao_owner_ledger.py`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/BASSemanticStateMarket.swift`
- Modify existing Rust RRF owner: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Cargo/bas-retrieval-ranker/src/fuser.rs`
- Modify existing narrow C ABI only: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Cargo/bas-retrieval-ranker/src/lib.rs`
- Modify existing force-link owner if the new symbol requires it: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Cargo/bas-memory-usage-tracker/src/force_link.rs`
- Modify existing Swift rank-fusion bridge: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASAutoRouteRanker+RankFuse.swift`
- Modify existing schema registry: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Modify [W4 adapter only; no new production file]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASL8RoutedMemoryService.swift`
- Modify [W4 composition only]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntime+MemoryService.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticStateMarketTests.swift`
- Modify Rust/Swift ABI and canonical-byte parity tests: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASRankFuseSeamGateTests.swift`
- Modify schema parity/fixture tests: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`
- Create [W4 tests]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASGroundingProposalIntegrationTests.swift`

**Reuse Decision (M + E):** Current rerankers rank inside one retrieval mechanism, while current memory eligibility/conflict types govern one memory model. No current owner joins heterogeneous lanes under one snapshot or supplies a non-compensable global gate, so the join/gate/R5-proposal-validation/R6-market seam is allowlisted as missing. Deterministic rank fusion is **not** missing: the pure Rust `bas-retrieval-ranker/src/fuser.rs` owner already implements RRF. Extend that owner and its existing narrow Swift/C bridge with bounded dedupe/cap/finite-`k` ABI; never add a Swift RRF, another ranker, or a second fusion owner. State Market owns cross-lane hard eligibility/conflict/budget decisions and treats Rust output as a bounded mechanism result. Provider branch policy, allocation, claim, event-head seal, terminal-source pin, and visibility remain exclusively in Contracts/K3; this owner stores and validates proposal-domain values and receipts but adds no Provider state.

Task-local M gate for `semantic-statelake-context:Task 6`: stage the ledger/checker/checker-test with the created source and tests; atomically add exact path permission/evidence and set `approved_missing → converging` on first create; remove conflicts only with proof; set `implemented` only after all declared paths/evidence/tests/gates exist and `current_conflicts == []`; roll back source, permission, evidence, conflicts/projections, and status together.

**Create Proof — `BASSemanticStateMarket.swift`:**

1. Repository search: `rg -n 'BASHardEligibilityDecision|BASClaimConflictSet|StateMarket|snapshot.*join' BehavioralAISubstrate/Sources` finds no global owner; `BASMemoryEligibilityJudge`, `BASMemoryConflictCluster`, and vector rerankers are nearest source-local candidates.
2. Public/upstream search: Swift sorting/collections supply mechanics, not policy-specific global admission or claim conflict semantics.
3. Missing invariant: one snapshot-bound join followed by one non-compensable global gate and one deterministic cross-lane budget selection.
4. Extending a lane-local ranker would let that lane authorize other lanes and would violate the dependency/authority boundary.
5. Authority: this file owns only join/global decision; it has no actor/store/cache/clock and receives one injected read-only snapshot reopener over Artifact Mesh, then returns Artifact Mesh payload values for external persistence.
6. Dependency direction: `BASOrchestration → BASRuntimeCore`; lane-specific memory types are converted before this seam and are not imported.
7. Compatibility: legacy memory eligibility and conflict remain unchanged as evidence producers. Shadow mode compares selections without replacing legacy output.
8. Tests permute inputs, maximize denied scores, inject conflicting local allow/preferred evidence, omit required lanes, and prove a single deterministic global result.

**Interfaces:**
- W3 consumes exact operation-root/plan/snapshot/reservoir artifact IDs, the Contracts Task 2A `BASProviderStepPurpose`, `BASProviderOutputRole`, exact-branch `BASProviderExecutionRef`, and shared `BASProviderBranchChainPayload` types; one injected read-only snapshot reopener backed by Artifact Mesh/integrity-bound K3; `[BASLaneResult]`; `BASGroundingEligibilityContext`; the existing bounded Rust RRF bridge; and a bounded test-injected `BASGroundingProposalPort`. R5/R6 never create a Provider chain: semantic contributes only proposal/validation receipt artifacts; Silicon/K3 later forms terminal-prefix and through-visibility chain payloads from the complete shared lineage.
- W3 produces `BASSemanticSnapshotJoiner.join`, `BASGlobalHardEligibilityGate.evaluate`, `BASSemanticStateMarket.prepareGrounding`, governed self-ID-free `BASGroundingEligibleReservoir`/`BASBoundedGroundingProposal`/`BASGroundingProposalReceipt`, `BASGroundingProposalValidator.validate`, typed `BASValidatedGroundingResult`, `BASGlobalClaimConflictResolver.build`, and `BASSemanticStateMarket.select(join:validatedGrounding:context:)`. There is deliberately no `select(join:context:)` or reservoir-direct Market overload.
- W4 production composition consumes the installed `BASProviderBranchPolicy`, one frozen Silicon execution-binding root, and the already-composed Silicon planned-execution delegate—never an external Provider endpoint or a second branch-control adapter. It implements `BASGroundingProposalPort` by validating the exact R5 plan request, delegating once to `BASOrganAdapter.executePlanned` through `BASProviderAttemptExecutor.executeExactlyOnce`, and then validating/storing the returned bounded proposal/receipt. The sole Silicon path owns preflight, allocation, claim, physical invocation, event-sequence validation, and head seal. Semantic code never calls `BASProviderBranchControlPort`, owns ordinals/claims/source pins, or invokes a Provider.

- [ ] **Step 1: Write failing non-compensation, conflict, coverage, and permutation tests**

```swift
import XCTest
@testable import BASOrchestration

final class BASSemanticStateMarketTests: XCTestCase {
    func testLaneAllowAndMaximumScoresCannotCompensateForInvalidConsent() async throws {
        let candidate = fixtureCandidate(
            key: "denied",
            governanceState: .consentInvalid,
            relevance: 1,
            authority: 1,
            utility: 1
        )
        let lane = fixtureLaneResult(
            candidates: [candidate],
            eligibilityEvidence: [fixtureLaneEligibility(candidateKey: "denied", allowed: true)]
        )
        let selection = try await select(results: [lane])
        XCTAssertTrue(selection.selected.isEmpty)
        XCTAssertEqual(selection.rejected.first?.reason, .consentInvalid)
    }

    func testLanePreferredConflictDoesNotResolveGlobalMaterialConflict() async throws {
        let results = fixtureContradictoryLaneResults(localPreferredCandidate: "a")
        let selection = try await select(results: results)
        XCTAssertEqual(selection.conflictSets.count, 1)
        XCTAssertEqual(selection.conflictSets[0].resolutionState, .unresolvedMaterial)
        XCTAssertFalse(selection.isGroundedForExactAnswer)
    }

    func testRequiredLaneFailureIsTerminalBeforeMarketScoring() async throws {
        let selection = try await select(results: [fixtureFailedRequiredLaneResult()])
        XCTAssertEqual(selection.coverage.terminalState, .requiredLaneFailed)
        XCTAssertTrue(selection.selected.isEmpty)
        XCTAssertFalse(selection.isGroundedForExactAnswer)
    }

    func testJoinCarriesOnlySnapshotIdentityNotWatermarks() async throws {
        let join = try await fixtureJoin(results: fixtureCompleteLaneResults())
        XCTAssertEqual(join.semanticSnapshotArtifactID, fixtureArtifactID("snapshot"))
        XCTAssertTrue(
            Mirror(reflecting: join).children.compactMap(\.label)
                .allSatisfy { !$0.lowercased().contains("watermark") }
        )
    }

    func testEveryInputPermutationProducesIdenticalSelection() async throws {
        let results = fixtureCompleteLaneResults()
        let expected = try await select(results: results)
        for permutation in results.permutations() {
            let actual = try await select(results: permutation)
            XCTAssertEqual(actual, expected)
        }
    }

    func testHardDeniedCandidateNeverReachesGroundingConsumer() async throws {
        let grounder = RecordingGrounder()
        let reservoir = try await eligibleReservoir(
            results: [fixtureLaneResult(candidates: [
                fixtureCandidate(key: "allowed", governanceState: .active),
                fixtureCandidate(key: "denied", governanceState: .quarantined),
            ])]
        )
        _ = try await grounder.propose(from: reservoir)
        let receivedCandidateKeys = await grounder.receivedCandidateKeys
        XCTAssertEqual(receivedCandidateKeys, ["allowed"])
        XCTAssertFalse(receivedCandidateKeys.contains("denied"))
    }

    func testMarketCannotConsumeReservoirOrUnvalidatedProposalDirectly() throws {
        XCTAssertFalse(try productionSource().contains("select(join:context:)"))
        XCTAssertFalse(try productionSource().contains("select(reservoir:"))
    }

    func testWrongPolicyRuleRootBranchRoleOrExecutionRefStopsBeforeMarket() async throws {
        for mutation in BASGroundingProposalBindingMutation.allCases {
            let fixture = makeGroundingValidationFixture(mutation: mutation)
            await XCTAssertThrowsErrorAsync {
                _ = try await fixture.validator.validate(
                    receipt: fixture.proposalReceipt,
                    allocationReceipt: fixture.allocationReceipt,
                    claimReceipt: fixture.claimReceipt,
                    eventHeadSealReceipt: fixture.eventHeadSealReceipt,
                    reservoir: fixture.reservoir,
                    reopenedSnapshot: fixture.snapshot,
                    context: fixture.context
                )
            }
            let marketCalls = await fixture.marketCalls.value
            let compilerCalls = await fixture.contextCompilerCalls.value
            XCTAssertEqual(marketCalls, 0)
            XCTAssertEqual(compilerCalls, 0)
        }
    }

    func testR6RevalidationDropsCandidateRevokedAfterR5() async throws {
        let fixture = makeGroundingValidationFixture(mutation: .none)
        let validated = try await fixture.validateProposal()
        await fixture.currentAuthority.revokeConsentAndAdvanceDeletionEpoch("allowed")
        let selection = try await fixture.market.select(
            join: fixture.join,
            validatedGrounding: validated,
            context: try await fixture.currentContext()
        )
        XCTAssertTrue(selection.selected.isEmpty)
        XCTAssertEqual(selection.rejected.first?.reason, .deleted)
        let conflictResolverCalls = await fixture.conflictResolverCalls.value
        XCTAssertEqual(conflictResolverCalls, 0)
    }

    func testGroundingProposalIsInternalAndCannotOpenVisibility() async throws {
        let receipt = try await makeGroundingValidationFixture().propose()
        XCTAssertEqual(
            receipt.providerBranchPolicyArtifactID,
            fixtureArtifactID("installed-provider-policy"))
        XCTAssertEqual(receipt.stepRuleID, "grounding-r5")
        XCTAssertEqual(receipt.providerStepPurpose, .groundingProposal)
        XCTAssertEqual(receipt.providerOutputRole, .internalProposal)
        XCTAssertEqual(receipt.providerExecutionRef.providerEgressBranchRef,
                       receipt.providerEgressBranchRef)
        let visibilityGateCalls = await receipt.visibilityGateCalls
        XCTAssertEqual(visibilityGateCalls, 0)
    }
}
```

`BASGroundingProposalBindingMutation.allCases` must include wrong/missing `turnOperationRef`, installed `providerBranchPolicyArtifactID`, branch root/kind/ordinal, `stepRuleID`, caller-requested/receipt role, K3-derived purpose, allocation receipt, claim receipt, complete `BASProviderExecutionRef` (Attempt/lease/execution ID/acceptance generation/request sequence/exact egress branch), event-head seal, proposal receipt artifact, snapshot/requirement/reservoir/execution-binding/plan/model/profile/budget artifacts, ordered candidate keys, candidate digest, byte/token bound, output schema, causal receipt order, and stale Attempt/policy/deletion generation. Every mutation fails before conflict resolution, State Market, ContextCompiler, spool, state commit, or UI visibility. Add a source guard proving the production port adapter contains no rule scan, “matching rule,” default rule, first-rule, or purpose-based template selection.

- [ ] **Step 2: Run and verify RED**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter BASSemanticStateMarketTests
```

Expected: FAIL at compile time because `BASSemanticSnapshotJoiner`, `BASGlobalHardEligibilityGate`, and `BASSemanticStateMarket` do not exist.

- [ ] **Step 3: Implement the pure, ordered global seam**

```swift
import Foundation
import BASRuntimeCore

public struct BASGroundingEligibilityContext: Codable, Sendable, Equatable {
    public let semanticSnapshotArtifactID: BASArtifactID
    public let requirementPlanArtifactID: BASArtifactID
    public let purpose: String
    public let visibilityScope: BASAttemptVisibilityScope
    public let allowedSensitivityLabels: [String]
    public let minimumAuthority: Double
    public let policyEpoch: UInt64
    public let schemaEpoch: UInt64
    public let killAndRevocationEpochArtifactID: BASArtifactID
    public let maximumBytes: UInt64
    public let maximumTokens: Int
}

public enum BASGroundingEligibleReservoirError: Error, Sendable, Equatable {
    case duplicateCandidateKey(String)
    case invalidLimit
    case integerOverflow
    case byteLimitExceeded
    case tokenLimitExceeded
}

public struct BASGroundingEligibleReservoir:
    BASSchemaVersioned, Codable, Sendable, Equatable
{
    public static let currentSchemaVersion = "1.0.0"

    public let schemaVersion: String
    public let orderedCandidates: [BASEligibleStateCandidate]
    public let admittedByteCount: UInt64
    public let admittedTokenCount: Int

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        candidates: [BASEligibleStateCandidate],
        maximumBytes: UInt64,
        maximumTokens: Int
    ) throws {
        self.schemaVersion = schemaVersion
        guard maximumTokens >= 0 else {
            throw BASGroundingEligibleReservoirError.invalidLimit
        }
        let ordered = candidates.sorted {
            $0.candidate.candidateKey.utf8.lexicographicallyPrecedes(
                $1.candidate.candidateKey.utf8
            )
        }
        var bytes: UInt64 = 0
        var tokens = 0
        var seen = Set<String>()
        for admitted in ordered {
            guard seen.insert(admitted.candidate.candidateKey).inserted else {
                throw BASGroundingEligibleReservoirError.duplicateCandidateKey(
                    admitted.candidate.candidateKey
                )
            }
            let byteSum = bytes.addingReportingOverflow(admitted.candidate.byteCount)
            let tokenSum = tokens.addingReportingOverflow(admitted.candidate.tokenCost)
            guard !byteSum.overflow, !tokenSum.overflow else {
                throw BASGroundingEligibleReservoirError.integerOverflow
            }
            bytes = byteSum.partialValue
            tokens = tokenSum.partialValue
        }
        guard bytes <= maximumBytes else {
            throw BASGroundingEligibleReservoirError.byteLimitExceeded
        }
        guard tokens <= maximumTokens else {
            throw BASGroundingEligibleReservoirError.tokenLimitExceeded
        }
        self.orderedCandidates = ordered
        self.admittedByteCount = bytes
        self.admittedTokenCount = tokens
    }
}

public struct BASSemanticSnapshotJoin: Sendable, Equatable {
    public let semanticSnapshotArtifactID: BASArtifactID
    public let orderedCandidates: [BASStateCandidate]
    public let orderedLaneEligibilityEvidence: [BASLaneEligibilityEvidence]
    public let orderedLaneConflictEvidence: [BASLaneConflictEvidence]
    public let coverage: BASCoverageVector
}

public enum BASSemanticSnapshotJoiner {
    public static func join(
        plan: BASStateRequirementPlan,
        snapshotArtifactID: BASArtifactID,
        reopenSnapshot: @Sendable (BASArtifactID) async throws -> BASStateReadSnapshot,
        results: [BASLaneResult]
    ) async throws -> BASSemanticSnapshotJoin {
        let snapshot = try await reopenSnapshot(snapshotArtifactID)
        try snapshot.validateComplete()
        let ordered = results.sorted {
            $0.laneID.rawValue.utf8.lexicographicallyPrecedes($1.laneID.rawValue.utf8)
        }
        var seen = Set<BASSemanticLaneID>()
        let planned = Set(plan.orderedLaneRequirements.map(\.laneID))
        for result in ordered {
            guard seen.insert(result.laneID).inserted else {
                throw BASSemanticStateContractError.duplicateLane(result.laneID)
            }
            let snapshotContainsLane = snapshot.orderedLaneWatermarks.contains {
                $0.laneID == result.laneID
            }
            guard planned.contains(result.laneID),
                  result.semanticSnapshotArtifactID == snapshotArtifactID,
                  result.status != .completed || snapshotContainsLane else {
                throw BASSemanticStateContractError.snapshotMismatch
            }
        }

        let required = plan.orderedLaneRequirements.filter(\.required).map(\.laneID)
        let completed = ordered.filter { $0.status == .completed }.map(\.laneID)
        let failed = ordered.filter { $0.status != .completed }.map(\.laneID)
        let optional = plan.orderedLaneRequirements.filter { !$0.required }.map(\.laneID)
        let missingOptional = optional.filter { !completed.contains($0) }
        let coverage = try BASCoverageVector(
            requiredLaneIDs: required,
            completedLaneIDs: completed,
            failedLaneIDs: failed,
            missingOptionalLaneIDs: missingOptional,
            failureReceiptArtifactIDs: ordered
                .filter { $0.status != .completed }
                .map(\.terminalReceiptArtifactID)
        )
        return BASSemanticSnapshotJoin(
            semanticSnapshotArtifactID: snapshotArtifactID,
            orderedCandidates: ordered.flatMap(\.orderedCandidates).sorted {
                $0.candidateKey.utf8.lexicographicallyPrecedes($1.candidateKey.utf8)
            },
            orderedLaneEligibilityEvidence: ordered.flatMap(\.orderedEligibilityEvidence).sorted {
                $0.candidateKey.utf8.lexicographicallyPrecedes($1.candidateKey.utf8)
            },
            orderedLaneConflictEvidence: ordered.flatMap(\.orderedConflictEvidence).sorted {
                $0.claimKey.utf8.lexicographicallyPrecedes($1.claimKey.utf8)
            },
            coverage: coverage
        )
    }
}

public enum BASGlobalHardEligibilityGate {
    public static func evaluate(
        candidate: BASStateCandidate,
        context: BASGroundingEligibilityContext,
        sourceEvidence: [BASLaneEligibilityEvidence]
    ) -> BASHardEligibilityDecision {
        let reject: (BASStateCandidateRejectionReason) -> BASHardEligibilityDecision = { reason in
            .rejected(BASStateCandidateRejection(
                candidateKey: candidate.candidateKey,
                reason: reason,
                evidenceArtifactIDs: candidate.orderedProvenanceArtifactIDs
            ))
        }
        guard candidate.visibilityScope == context.visibilityScope else { return reject(.scopeMismatch) }
        guard candidate.policyEpoch == context.policyEpoch else { return reject(.policyEpochMismatch) }
        guard candidate.visibilityScope.deletionEpoch == context.visibilityScope.deletionEpoch else { return reject(.deleted) }
        guard context.allowedSensitivityLabels.contains(candidate.sensitivityLabel) else { return reject(.scopeMismatch) }
        guard candidate.schemaEpoch == context.schemaEpoch else { return reject(.schemaMismatch) }
        guard candidate.authority >= context.minimumAuthority else { return reject(.authorityInsufficient) }
        guard !candidate.orderedProvenanceArtifactIDs.isEmpty else { return reject(.provenanceMissing) }
        guard candidate.byteCount <= context.maximumBytes else { return reject(.overByteBudget) }
        guard candidate.tokenCost <= context.maximumTokens else { return reject(.overTokenBudget) }
        switch candidate.governanceState {
        case .active: break
        case .consentMissing: return reject(.consentMissing)
        case .consentInvalid: return reject(.consentInvalid)
        case .tombstoned: return reject(.tombstoned)
        case .deleted: return reject(.deleted)
        case .expired: return reject(.expired)
        case .quarantined: return reject(.quarantined)
        }
        // Lane-local allow is evidence only. It can never skip a global check.
        _ = sourceEvidence
        return .admitted(BASEligibleStateCandidate(
            candidate: candidate,
            eligibilityReceipt: BASHardEligibilityReceipt(
                semanticSnapshotArtifactID: context.semanticSnapshotArtifactID,
                requirementPlanArtifactID: context.requirementPlanArtifactID,
                candidateKey: candidate.candidateKey,
                admitted: true,
                reason: nil,
                evidenceArtifactIDs: candidate.orderedProvenanceArtifactIDs
            )
        ))
    }
}

/// Canonical stateless authority declared by the `state.snapshot-market`
/// owner-ledger row. The injected closure is only the existing narrow Swift
/// bridge to Rust `bas-retrieval-ranker`; there is no Swift RRF fallback.
public struct BASSemanticStateMarket: Sendable {
    public typealias BoundedRustRRF = @Sendable (
        _ admitted: [BASEligibleStateCandidate],
        _ finiteK: Double,
        _ maximumResults: Int
    ) throws -> [String]

    private let boundedRustRRF: BoundedRustRRF
    private let finiteK: Double
    private let maximumResults: Int

    public init(
        finiteK: Double,
        maximumResults: Int,
        boundedRustRRF: @escaping BoundedRustRRF
    ) throws {
        guard finiteK.isFinite, finiteK > 0, maximumResults > 0 else {
            throw BASGroundingEligibleReservoirError.invalidLimit
        }
        self.boundedRustRRF = boundedRustRRF
        self.finiteK = finiteK
        self.maximumResults = maximumResults
    }

    public func prepareGrounding(
        join: BASSemanticSnapshotJoin,
        context: BASGroundingEligibilityContext
    ) throws -> BASGroundingEligibleReservoir {
        let admitted = try hardEligibleCandidates(join: join, context: context)
        let orderedKeys = try boundedRustRRF(admitted, finiteK, maximumResults)
        let bounded = try validateRustRRFOutput(
            orderedKeys,
            domain: admitted,
            finiteK: finiteK,
            maximumResults: maximumResults
        )
        return try BASGroundingEligibleReservoir(
            candidates: bounded,
            maximumBytes: context.maximumBytes,
            maximumTokens: context.maximumTokens
        )
    }

    public func select(
        join: BASSemanticSnapshotJoin,
        validatedGrounding: BASValidatedGroundingResult,
        context: BASGroundingEligibilityContext
    ) throws -> BASStateMarketSelection {
        let revalidated = try revalidateCurrentGlobalEligibility(
            join: join,
            validatedGrounding: validatedGrounding,
            context: context
        )
        let conflicts = try BASGlobalClaimConflictResolver.build(
            admitted: revalidated,
            laneEvidence: join.orderedLaneConflictEvidence
        )
        return try selectWithinCanonicalBudgets(
            admitted: revalidated,
            conflicts: conflicts,
            coverage: join.coverage,
            context: context
        )
    }
}
```

Implement the displayed `hardEligibleCandidates`, `validateRustRRFOutput`, `revalidateCurrentGlobalEligibility`, and `selectWithinCanonicalBudgets` as `private` methods on this same stateless `BASSemanticStateMarket`; they are not new owners or free functions. The only R5 grounding-input value is `BASGroundingEligibleReservoir`, whose initializer accepts `[BASEligibleStateCandidate]` rather than raw `BASStateCandidate`. `BASSemanticStateMarket.prepareGrounding(join:context:)` performs required-lane failure handling and the initial candidate-by-candidate hard gate, canonicalizes only admitted candidates into the existing bridge input, invokes the bounded Rust RRF seam once, validates its canonical output, and returns the bounded reservoir. The Rust owner performs deterministic lane-local dedupe, source/correlated-lane caps, finite positive `k` validation, reciprocal-rank fusion, UTF-8 tie-breaking, and maximum-result truncation. Swift/Rust canonical input bytes and decoded output bytes must match golden vectors byte-for-byte; NaN/Inf, zero/negative/non-finite `k`, duplicate output keys, out-of-domain keys, over-bound output, malformed bytes, or Rust/Swift parity drift fails closed. No Swift production function contains `1 / (k + rank)`, weighted-fusion fallback, independent dedupe/cap logic, or another ranker. No overload accepts a rejected/raw candidate. Persist the self-ID-free reservoir once through ordinary Artifact Mesh and carry its returned ID externally; the test grounder therefore records zero Rust/grounder calls or bytes for hard-denied evidence by construction.

Add these self-ID-free values beside the new market owner. They consume shared Contracts types and do not redeclare Provider policy/control authority:

```swift
public struct BASBoundedGroundingProposal:
    BASSchemaVersioned, Codable, Sendable, Equatable
{
    public static let currentSchemaVersion = "1.0.0"

    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let providerBranchPolicyArtifactID: BASArtifactID
    public let stepRuleID: String
    public let providerEgressBranchRef: BASTurnBranchRef
    public let providerExecutionRef: BASProviderExecutionRef
    public let providerStepPurpose: BASProviderStepPurpose
    public let providerOutputRole: BASProviderOutputRole
    public let semanticSnapshotArtifactID: BASArtifactID
    public let requirementPlanArtifactID: BASArtifactID
    public let groundingReservoirArtifactID: BASArtifactID
    public let executionBindingArtifactID: BASArtifactID
    public let executionPlanArtifactID: BASArtifactID
    public let modelManifestArtifactID: BASArtifactID
    public let backendProfileArtifactID: BASArtifactID
    public let budgetPolicyArtifactID: BASArtifactID
    public let orderedCandidateDecisions: [BASGroundingCandidateDecision]
    public let terminalEventHeadDigest: String
}

public struct BASGroundingProposalReceipt:
    BASSchemaVersioned, Codable, Sendable, Equatable
{
    public static let currentSchemaVersion = "1.0.0"

    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let providerBranchPolicyArtifactID: BASArtifactID
    public let stepRuleID: String
    public let providerEgressBranchRef: BASTurnBranchRef
    public let providerExecutionRef: BASProviderExecutionRef
    public let providerStepPurpose: BASProviderStepPurpose
    public let providerOutputRole: BASProviderOutputRole
    public let proposalArtifactID: BASArtifactID
    public let allocationReceiptArtifactID: BASArtifactID
    public let claimReceiptArtifactID: BASArtifactID
    public let eventHeadSealReceiptArtifactID: BASArtifactID
    public let groundingReservoirArtifactID: BASArtifactID
    public let executionBindingArtifactID: BASArtifactID
    public let executionPlanArtifactID: BASArtifactID
    public let orderedCausalInputArtifactIDs: [BASArtifactID]
}

public struct BASValidatedGroundingResult: Sendable, Equatable {
    public let turnOperationRef: BASTurnOperationRef
    public let providerBranchPolicyArtifactID: BASArtifactID
    public let stepRuleID: String
    public let semanticSnapshotArtifactID: BASArtifactID
    public let requirementPlanArtifactID: BASArtifactID
    public let groundingReservoirArtifactID: BASArtifactID
    public let providerEgressBranchRef: BASTurnBranchRef
    public let providerExecutionRef: BASProviderExecutionRef
    public let proposalReceiptArtifactID: BASArtifactID
    public let orderedValidatedCandidates: [BASEligibleStateCandidate]
}

public protocol BASGroundingProposalPort: Sendable {
    func proposeGrounding(
        turnOperationRef: BASTurnOperationRef,
        providerBranchPolicyArtifactID: BASArtifactID,
        stepRuleID: String,
        requestedProviderOutputRole: BASProviderOutputRole,
        semanticSnapshotArtifactID: BASArtifactID,
        requirementPlanArtifactID: BASArtifactID,
        groundingReservoirArtifactID: BASArtifactID,
        executionBindingArtifactID: BASArtifactID,
        executionPlanArtifactID: BASArtifactID,
        orderedCausalInputArtifactIDs: [BASArtifactID]
    ) async throws -> BASGroundingProposalReceipt
}
```

Give every public value an explicit initializer in displayed-field order. For each of the three independently persisted grounding values, the initializer's first parameter is `schemaVersion: String = Self.currentSchemaVersion`; it stores that value before the displayed domain fields. `BASBoundedGroundingProposal` contains the exact installed policy ID, caller-selected frozen `stepRuleID`, complete branch-bound `BASProviderExecutionRef`, and proposal data, but no self ID, allocation authority, selection, context, visibility receipt, spool, or state mutation. `BASGroundingProposalReceipt` references the ordinary Artifact-Mesh proposal, the exact binding/step plan/causes, and the exact K3 allocation/claim/event-head-seal receipts. Its `providerStepPurpose` and `providerOutputRole` are checked receipt projections only: K3 must derive `.groundingProposal` from the reopened policy rule and equality-check the caller's requested `.internalProposal` role. Branch kind `.providerEgress` and operation root/branch/request ordinal must agree everywhere. A grounding branch is never a `terminalAnswerCandidate`, never calls `designateTerminalSource` or `openProviderVisibilityGate`, and is unaffected by the answer's `BASProviderVisibilityMode` except that it must complete before any terminal source may be pinned.

All ordinary puts and reopens of `BASGroundingEligibleReservoir`, `BASBoundedGroundingProposal`, and `BASGroundingProposalReceipt` must call the Contracts-owned `BASGovernedArtifactPayloadCodec`; raw `JSONEncoder`/`JSONDecoder`, a caller-selected accepted-version set, or decoding before version rejection is forbidden. Register each type exactly once in the existing `BASEBrainSchemaGovernanceRegistry` through its metatype entry (BASAdmin already depends on BASOrchestration), with object IDs equal to the Swift basenames and test IDs `schema.<Type>.current`, `schema.<Type>.backward_v1`, and `schema.<Type>.future_rejection`. `BASEBrainSchemaGovernanceRegistryTests` must prove exact-one entry/version parity, current codec round-trip, pinned v1 fixture decode, missing/future-version rejection before any validator/Market mechanism, and no second alias entry. A BehavioralAISubstrateTests compile fixture imports the owner module and constructs all three via their explicit public default-version initializers. `BASEligibleStateCandidate`, candidate decisions, and other embedded values are not separately registered unless they independently become ordinary-put payloads.

In W3, a bounded deterministic test conformer produces the same proposal/receipt shapes without any physical Provider side effect. The canonical R5 caller explicitly chooses the one frozen grounding `stepRuleID`, asks Silicon to materialize that exact rule's plan, ordinary-puts the plan, and passes the exact installed policy ID, `stepRuleID`, requested role, plan ID, binding ID, and canonical causes to the port. In W4, implement the production conformer as a stateless semantic adapter over one injected Silicon planned-execution closure. It reopens the exact policy/rule, reservoir/snapshot/requirement plan, execution binding, and already-materialized step plan; it may validate but never search for, infer, or choose a “matching” rule/template/plan. It passes those values unchanged to Silicon's existing `BASOrganAdapter.executePlanned` path, which alone performs value-only preflight, `allocateProviderBranch → claimProviderExecution`, and `BASProviderAttemptExecutor.executeExactlyOnce`; the latter is the sole physical invocation primitive and returns the complete branch-bound ref plus allocation/claim/event-head-seal/proposal receipts. The semantic adapter validates and ordinary-stores the proposal, then returns its receipt. It has no Provider endpoint, branch-control port, ordinal/claim/receipt/source/visibility map, direct `allocateProviderBranch`/`claimProviderExecution` call, or invocation primitive. A possible-start/indeterminate result remains query/reconcile-only inside Silicon rather than retried/replaced here.

`BASGroundingProposalValidator.validate(...)` is the first R6 operation. It reopens the exact proposal, allocation/claim/head-seal receipts, installed branch policy, execution binding/step plan, reservoir, requirement plan, and same semantic snapshot. It validates exact policy ID + `stepRuleID` equality across caller, proposal, receipt, allocation, claim, plan, and binding; root, `.providerEgress` kind, K3-only non-reused ordinal, K3-derived `.groundingProposal`, requested/receipt `.internalProposal`, complete `BASProviderExecutionRef`, active Attempt/lease/acceptance generation, exact causal IDs, model/profile/plan/budget membership, event-head digest, output schema, canonical candidate order, absence of invented/reordered candidates, and exact byte/token bounds. Only then may it return `BASValidatedGroundingResult`; invalid/missing/late evidence returns a typed frozen-plan failure/degradation and makes zero conflict/Market/compiler calls.

Implement `BASGlobalClaimConflictResolver.build(admitted:laneEvidence:)` by grouping admitted candidates by `claimKey`, sorting candidate keys by UTF-8, and deriving the canonical relationship/materiality from the complete payload/provenance set. A lane-local `preferredRef` or `sourceAllowed` may be cited as evidence but cannot set `.resolved`. Conflicting material claims remain `.unresolvedMaterial` until an explicit global resolution artifact is present.

Implement `BASSemanticStateMarket.select(join:validatedGrounding:context:)` in this fixed R6 order; do not implement a two-argument or reservoir-direct overload:

1. If `join.coverage.terminalState == .requiredLaneFailed`, reject all candidates before vector calculation.
2. Require the already-returned `BASValidatedGroundingResult` to equal the same root/snapshot/requirement/reservoir and exact candidate-key domain. Reopen the same snapshot and current K3 scope; stale/mismatched validation never reaches scoring.
3. Re-evaluate every validated candidate through `BASGlobalHardEligibilityGate` against current consent, deletion, policy, kill/revocation, schema, freshness, authority, and provenance facts. Grounder allow/rank cannot compensate. A candidate invalidated after R5 is removed before conflict resolution.
4. Build global conflict sets only from R6-admitted candidates and reserve mandatory conflict-disclosure tokens.
5. Compute `BASStateMarketVector` only for R6-admitted candidates, then sort by descending utility, authority, freshness, relevance, and ascending UTF-8 candidate key.
6. Admit within exact byte/token/source/lane/entity concentration budgets; record every truncation reason.
7. Derive one inline `BASStateMarketBudgetReceipt` from the same selected/truncated values and return one `BASStateMarketSelection` whose selected/rejected/truncated/conflict/vector arrays are canonically ordered. The selection payload may later be stored as one Artifact Mesh object; the pure market does not accept or invent a receipt artifact ID. Do not mutate lane results or call a lane ranker. `BASContextCompiler` is not part of R6 and may run only after this selection/receipt is durably stored.

- [ ] **Step 4A [W3]: Run pure R5/R6 GREEN and legacy-evidence regressions**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASSemanticStateMarketTests|BASMemoryCognitionCoreTests|BASTemporalMemoryFieldSchemaTests|BASL8HippocampalWellWhitepaperTests|BASRankFuseSeamGateTests|BASEBrainSchemaGovernanceRegistryTests'
swift package --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate dump-package >/dev/null
```

Expected: PASS; 0 failures with the test-injected proposal port and zero physical Provider calls. Every permutation returns byte-identical canonical selection; finite-`k`, dedupe/source-cap, Rust/Swift canonical-byte, malformed-output, and no-Swift-RRF tests pass; local allow/preferred or proposal evidence cannot create global admission/resolution; every proposal binding mutation stops before Market/ContextCompiler.

- [ ] **Step 4B [W4]: Wire and verify one production grounding branch**

After Contracts W2 and Silicon W4 receipts are green, run focused integration tests with the production `BASGroundingProposalPort`. Observe this exact end-to-end sequence while asserting ownership: caller materializes the exact frozen `stepRuleID` plan → semantic adapter delegates unchanged → Silicon preflight with no branch → K3 `allocateProviderBranch` with policy ID + `stepRuleID` + requested `.internalProposal` role + causes/plan proof, while K3 derives `.groundingProposal` → one durable `claimProviderExecution` → sole `BASProviderAttemptExecutor.executeExactlyOnce` invokes `BASOrganAdapter.executePlanned` once with the complete exact-branch ref → bounded terminal `sealProviderEventHead` → semantic proposal validation/ordinary put/receipt → R6 validation/reopen → hard revalidation → conflict/Market. Mutate policy ID, `stepRuleID`, requested/receipt role, plan, binding, or causes independently and assert failure before allocation/Provider/Market as appropriate. Crash before/after claim, wrong allocation/claim/seal receipt, unsealed tail, stale Attempt/generation, duplicate response, and reconstructed handle issue no second call and no sibling branch. Add a source scan proving semantic production files contain no Provider endpoint, `allocateProviderBranch`, `claimProviderExecution`, `executeExactlyOnce` implementation, or direct physical-call closure. Assert zero terminal-source/visibility calls and no local branch map.

- [ ] **Step 5: Commit W3 contract/pure seam, then separate W4 production wiring**

```bash
git add BehavioralAISubstrate/Cargo/bas-retrieval-ranker/src/fuser.rs \
  docs/superpowers/specs/qinao-owner-ledger-v1.json \
  scripts/check_qinao_owner_ledger.py \
  scripts/test_check_qinao_owner_ledger.py \
  BehavioralAISubstrate/Cargo/bas-retrieval-ranker/src/lib.rs \
  BehavioralAISubstrate/Cargo/bas-memory-usage-tracker/src/force_link.rs \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASAutoRouteRanker+RankFuse.swift \
  BehavioralAISubstrate/Sources/BASOrchestration/BASSemanticStateMarket.swift \
  BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASRankFuseSeamGateTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticStateMarketTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift
git commit -m "feat: add canonical semantic state market"
```

Commit the W4 production proposal adapter/composition and focused tests separately after Step 4B using only `BASL8RoutedMemoryService.swift`, `EBrainHostRuntime+MemoryService.swift`, and `BASGroundingProposalIntegrationTests.swift`. The stateless adapter is an A/E extension in the existing HostKit lane/composition seam; do not create a production adapter file, amend the W3 market commit, redeclare Contracts types, or add a fifth semantic M owner.

```bash
git add BehavioralAISubstrate/Sources/BASHostKit/BASL8RoutedMemoryService.swift \
  BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntime+MemoryService.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASGroundingProposalIntegrationTests.swift
git commit -m "feat: wire bounded grounding proposal branch"
```

### Task 7: Make `BASContextCompiler` the Only Compaction, Render, Fingerprint, and Exact Token-Packing Owner

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/CognitionKernelCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/SemanticCompilerCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/ScopedContextCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainTurnContextCompiler.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASExactContextCompilerOwnershipTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASContextCompilerTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASCognitionKernelTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnContextCompilerTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASFrontstageAndScopedContextTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`

**Reuse Decision (E/A):** `BASContextCompiler` already owns prompt retention, rendering, and fingerprints, while `CognitionKernelCore.swift` currently calls it and then performs a second drop/render/signature/fingerprint pass. Merge that duplicated policy into the existing compiler before adding exact token packing. `CognitionKernel`, `BASSemanticContextCompiler`, `BASScopedContextCompiler`, and `BASTurnContextCompiler` retain source compatibility as callers/input projections only. Do not create `BASL3ExactContextCompiler.swift`, another compiler enum, another compiled-context store, or another wrapper-owned prompt constructor.

**Interfaces:**
- Consumes: only market-admitted projection artifacts, `semanticSnapshotArtifactID`, `stateMarketSelectionArtifactID`, `executionBindingArtifactID`, exact tokenizer identity, and turn-budget projections.
- Produces: one synchronous `BASContextCompiler.compile` path and `BASContextCompiler.compileExact(_:tokenizer:) async throws -> BASExactCompiledContext`; every wrapper delegates exactly once and returns/projects the compiler's prompt, ordering, preservation, signatures, and fingerprint unchanged.

- [ ] **Step 1: Write failing tokenize-once, segment-geometry, owner, and projection-only tests**

```swift
import XCTest
@testable import BASOrchestration
@testable import BASHostKit

final class BASExactContextCompilerOwnershipTests: XCTestCase {
    func testExactCompilationTokenizesExactlyOnce() async throws {
        let tokenizer = CountingContextTokenizer(result: fixtureTokenization())
        let result = try await BASContextCompiler.compileExact(
            fixtureExactCompilationRequest(),
            tokenizer: tokenizer
        )
        let callCount = await tokenizer.callCount
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(result.canonicalTokens, fixtureTokenization().canonicalTokens)
    }

    func testMalformedOrOverBoundSpanFailsWithoutRetokenizing() async throws {
        for mutation in BASContextSpanMutation.allCases {
            let tokenizer = CountingContextTokenizer(result: fixtureTokenization(mutation: mutation))
            await XCTAssertThrowsErrorAsync {
                _ = try await BASContextCompiler.compileExact(
                    fixtureExactCompilationRequest(),
                    tokenizer: tokenizer
                )
            }
            let callCount = await tokenizer.callCount
            XCTAssertEqual(callCount, 1)
        }
    }

    func testMandatoryClassesAreReservedBeforeOptionalEvidence() async throws {
        let result = try await BASContextCompiler.compileExact(
            fixtureOversubscribedExactRequest(),
            tokenizer: CountingContextTokenizer(result: fixtureOversubscribedTokenization())
        )
        XCTAssertEqual(try XCTUnwrap(result.budgetReceipt.allocation(for: .systemSovereign)).truncated, 0)
        XCTAssertEqual(try XCTUnwrap(result.budgetReceipt.allocation(for: .constitution)).truncated, 0)
        XCTAssertGreaterThan(try XCTUnwrap(result.budgetReceipt.allocation(for: .groundedEvidence)).truncated, 0)
    }

    func testDescriptorUsesTypedBindingArtifactsAndHasNoSelfDigest() async throws {
        let result = try await BASContextCompiler.compileExact(
            fixtureExactCompilationRequest(),
            tokenizer: CountingContextTokenizer(result: fixtureTokenization())
        )
        XCTAssertEqual(result.descriptor.semanticSnapshotArtifactID, fixtureArtifactID("snapshot"))
        XCTAssertEqual(result.descriptor.executionBindingArtifactID, fixtureArtifactID("execution-binding"))
        let labels = Set(Mirror(reflecting: result.descriptor).children.compactMap(\.label))
        XCTAssertFalse(labels.contains("descriptorDigest"))
        XCTAssertFalse(labels.contains("artifactID"))
    }

    func testCognitionKernelCannotDropAPreservedPreferredBlockBeforePreservationApplies() throws {
        let preserved = fixturePreferredBlock(id: "preserve-me", size: .nearBudget)
        let result = try fixtureCognitionKernel().compile(
            blocks: [fixtureRequiredBlock(), preserved, fixtureOptionalOverflow()],
            preservedBlockIDs: [preserved.id]
        )
        XCTAssertTrue(result.selectedBlockIDs.contains(preserved.id))
        XCTAssertEqual(result.prompt, result.compilerPrompt)
        XCTAssertEqual(result.fingerprint, result.compilerFingerprint)
    }

    func testEveryWrapperProducesByteIdenticalPromptOrderAndFingerprint() throws {
        let request = fixtureSharedContextRequest()
        let direct = try BASContextCompiler.compile(request.compilerInput)
        let cognition = try fixtureCognitionKernel().compile(request)
        let semantic = try fixtureSemanticProjection().compile(request)
        XCTAssertEqual(cognition.prompt, direct.prompt)
        XCTAssertEqual(semantic.prompt, direct.prompt)
        XCTAssertEqual(cognition.selectedBlockIDs, direct.selectedBlockIDs)
        XCTAssertEqual(semantic.selectedBlockIDs, direct.selectedBlockIDs)
        XCTAssertEqual(cognition.fingerprint, direct.fingerprint)
        XCTAssertEqual(semantic.fingerprint, direct.fingerprint)
    }
}
```

Add source-ownership assertions that only `ContextCompilerCore.swift` contains `.tokenize(`, `canonicalTokenDigest`, final block dropping/compaction, render, policy/context signature, and fingerprint helpers. `CognitionKernelCore.swift` must contain exactly one compiler delegation and no `BASCompiledPrompt(` construction.

- [ ] **Step 2: Run and verify RED**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASExactContextCompilerOwnershipTests|BASContextCompilerTests|BASCognitionKernelTests|BASTurnContextCompilerTests|BASFrontstageAndScopedContextTests'
```

Expected: FAIL at compile time because `BASContextCompiler.compileExact`, `BASExactContextCompilationRequest`, and exact descriptor types do not exist.

- [ ] **Step 3: Add exact request/result values next to the existing compiler owner**

```swift
public enum BASContextBudgetClass: String, Codable, Sendable, Hashable, CaseIterable {
    case systemSovereign, constitution, userConversation, conflictDisclosure
    case groundedEvidence, toolProtocol, generationReserve
}

public struct BASContextCompilationSegment: Codable, Sendable, Equatable {
    public let projectionArtifactID: BASArtifactID
    public let budgetClass: BASContextBudgetClass
    public let canonicalProjectionBytes: Data
    public let projectionDigest: String
    public let required: Bool
    public let certifiedMaximumTokens: Int
    public let certificationTokenizerDigest: String
}

public struct BASContextSegmentTokenSpan: Codable, Sendable, Equatable {
    public let segmentOrdinal: Int
    public let startTokenIndex: Int
    public let tokenCount: Int
}

public struct BASContextTokenizationResult: Codable, Sendable, Equatable {
    public let canonicalTokens: [Int32]
    public let orderedSegmentSpans: [BASContextSegmentTokenSpan]
    public let tokenizerDigest: String
}

public protocol BASContextTokenizer: Sendable {
    var tokenizerDigest: String { get }
    func tokenize(_ orderedCanonicalSegments: [Data]) async throws -> BASContextTokenizationResult
}

public struct BASContextBudgetAllocationEntry: Codable, Sendable, Equatable {
    public let budgetClass: BASContextBudgetClass
    public let requested: Int
    public let admitted: Int
    public let truncated: Int
    public let compressed: Int
    public let reserved: Int
}

public struct BASContextBudgetReceipt: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let totalLimit: Int
    public let orderedAllocations: [BASContextBudgetAllocationEntry]
    public let orderedCompressionArtifactIDs: [BASArtifactID]

    public func allocation(for budgetClass: BASContextBudgetClass) -> BASContextBudgetAllocationEntry? {
        orderedAllocations.first { $0.budgetClass == budgetClass }
    }
}

public struct BASCompiledContextDescriptor: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let semanticSnapshotArtifactID: BASArtifactID
    public let stateMarketSelectionArtifactID: BASArtifactID
    public let executionBindingArtifactID: BASArtifactID
    public let orderedProjectionArtifactIDs: [BASArtifactID]
    public let canonicalTokenDigest: String
    public let canonicalTokenCount: Int
    public let orderedSegmentTokenSpanDigest: String
    public let tokenizerDigest: String
    public let templateAndToolProtocolDigest: String
    public let policyEpoch: UInt64
    public let positionConvention: String
}

public struct BASExactContextCompilationRequest: Codable, Sendable, Equatable {
    public let semanticSnapshotArtifactID: BASArtifactID
    public let stateMarketSelectionArtifactID: BASArtifactID
    public let executionBindingArtifactID: BASArtifactID
    public let orderedSegments: [BASContextCompilationSegment]
    public let requestedBudgetEntries: [BASContextBudgetAllocationEntry]
    public let totalContextTokenLimit: Int
    public let tokenizerDigest: String
    public let templateAndToolProtocolDigest: String
    public let policyEpoch: UInt64
    public let positionConvention: String
}

public struct BASExactCompiledContext: Sendable, Equatable {
    public let canonicalTokens: [Int32]
    public let orderedSegmentTokenSpans: [BASContextSegmentTokenSpan]
    public let descriptor: BASCompiledContextDescriptor
    public let budgetReceipt: BASContextBudgetReceipt
}

public enum BASContextCompilationError: Error, Equatable, Sendable {
    case emptyArtifactBinding
    case tokenizerDigestMismatch
    case invalidSegmentSpanGeometry
    case segmentCertifiedBoundExceeded(ordinal: Int)
    case totalTokenLimitExceeded
    case mandatoryBudgetExceeded(BASContextBudgetClass)
    case integerOverflow
}
```

Give every public type an explicit initializer. Budget request/allocation arrays are unique and sorted by `BASContextBudgetClass.rawValue`; segment order is semantic and preserved.

In the same task, add exact schema-governance entries for the two persisted payloads `BASContextBudgetReceipt` and `BASCompiledContextDescriptor`, update the registry's exact-count fixture, and assert both schema IDs are present. Do not register the tokenizer protocol, compilation request, in-memory tokenization result, or `BASExactCompiledContext` aggregate.

Both persisted types must also be `Codable, Sendable, Equatable`, visibly store `schemaVersion`, keep `currentSchemaVersion = "1.0.0"`, and expose explicit public initializers with `schemaVersion: String = Self.currentSchemaVersion` first. The compiler's ordinary put/identity construction and every replay/reopen call only `BASGovernedArtifactPayloadCodec`; raw encoder/decoder and field access before `decodeCurrent` succeeds are source-gate failures. Register the two normal metatype entries exactly once with `schema.BASContextBudgetReceipt.current/backward_v1/future_rejection` and `schema.BASCompiledContextDescriptor.current/backward_v1/future_rejection`. Tests cover current codec bytes, pinned-v1 decode, missing/future rejection before budget allocation/render/token packing, exact-one IDs/version parity, and a cross-target fixture that imports `BASOrchestration` and invokes both public initializers without spelling `schemaVersion`.

- [ ] **Step 4: Extend `BASContextCompiler` with the only tokenizer call**

Add `compileExact` to the existing `BASContextCompiler` enum. The complete algorithm is:

```swift
public extension BASContextCompiler {
static func compileExact(
    _ request: BASExactContextCompilationRequest,
    tokenizer: any BASContextTokenizer
) async throws -> BASExactCompiledContext {
    guard tokenizer.tokenizerDigest == request.tokenizerDigest,
          request.orderedSegments.allSatisfy({
              $0.certificationTokenizerDigest == request.tokenizerDigest
          }) else {
        throw BASContextCompilationError.tokenizerDigestMismatch
    }

    let selected = try selectSegmentsWithoutTokenizing(request)
    let tokenization = try await tokenizer.tokenize(selected.map(\.canonicalProjectionBytes))
    guard tokenization.tokenizerDigest == request.tokenizerDigest else {
        throw BASContextCompilationError.tokenizerDigestMismatch
    }
    try validateExactSpans(
        tokenization.orderedSegmentSpans,
        segmentCount: selected.count,
        tokenCount: tokenization.canonicalTokens.count
    )
    for (ordinal, span) in tokenization.orderedSegmentSpans.enumerated()
        where span.tokenCount > selected[ordinal].certifiedMaximumTokens {
        throw BASContextCompilationError.segmentCertifiedBoundExceeded(ordinal: ordinal)
    }
    guard tokenization.canonicalTokens.count <= request.totalContextTokenLimit else {
        throw BASContextCompilationError.totalTokenLimitExceeded
    }

    let receipt = try exactBudgetReceipt(
        request: request,
        selected: selected,
        spans: tokenization.orderedSegmentSpans
    )
    let descriptor = BASCompiledContextDescriptor(
        semanticSnapshotArtifactID: request.semanticSnapshotArtifactID,
        stateMarketSelectionArtifactID: request.stateMarketSelectionArtifactID,
        executionBindingArtifactID: request.executionBindingArtifactID,
        orderedProjectionArtifactIDs: selected.map(\.projectionArtifactID),
        canonicalTokenDigest: canonicalTokenDigest(
            tokens: tokenization.canonicalTokens,
            spans: tokenization.orderedSegmentSpans
        ),
        canonicalTokenCount: tokenization.canonicalTokens.count,
        orderedSegmentTokenSpanDigest: canonicalSpanDigest(tokenization.orderedSegmentSpans),
        tokenizerDigest: request.tokenizerDigest,
        templateAndToolProtocolDigest: request.templateAndToolProtocolDigest,
        policyEpoch: request.policyEpoch,
        positionConvention: request.positionConvention
    )
    return BASExactCompiledContext(
        canonicalTokens: tokenization.canonicalTokens,
        orderedSegmentTokenSpans: tokenization.orderedSegmentSpans,
        descriptor: descriptor,
        budgetReceipt: receipt
    )
}
}
```

`selectSegmentsWithoutTokenizing` reserves conservative certified bounds in this order: system/sovereign, constitution, user conversation, conflict disclosure, tool protocol, generation reserve, then optional grounded evidence. `validateExactSpans` requires exactly one span per selected segment, ordinal order, start at zero, nonnegative contiguous nonoverlapping ranges, checked end-index arithmetic, and final end equal to token count. `canonicalTokenDigest` commits once to fixed-width tokens plus ordered spans using the repository canonical encoder. Compression is allowed only through a provenance-preserving child Artifact Mesh payload named in `orderedCompressionArtifactIDs`; it cannot silently replace source artifacts.

First remove the second owner from `CognitionKernelCore.swift`: pass `preservedBlockIDs` and all retention inputs into `BASContextCompiler` before compaction; use the one returned `BASCompiledPrompt` unchanged; delete the kernel's second capacity/drop loop plus its duplicate `render`, retention-order, policy-signature, context-signature, and fingerprint helpers. The kernel may attach downstream cognition metadata but cannot reorder selected IDs or reconstruct prompt/fingerprint bytes.

Modify the three compatibility compilers as follows:

- `BASSemanticContextCompiler` may produce ordered semantic `BASContextCompilationSegment` inputs but must call neither `BASContextCompiler.compileExact` nor a tokenizer.
- `BASScopedContextCompiler` may produce scoped segment inputs/JSON projections but cannot compact or count tokens independently.
- `BASTurnContextCompiler` continues mapping `BASBudgetFrame → BASTurnContextPlan`; add only a pure method that maps that plan and typed Artifact IDs into `BASExactContextCompilationRequest`.
- Preserve the existing synchronous `BASContextCompiler.compile(_:)` legacy API until Task 8 shadow evidence permits a later cutover; do not fork its render/fingerprint helpers.

- [ ] **Step 5: Run GREEN and the single-owner source gate**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASExactContextCompilerOwnershipTests|BASContextCompilerTests|BASCognitionKernelTests|BASTurnContextCompilerTests|BASFrontstageAndScopedContextTests|BASEBrainSchemaGovernanceRegistryTests'
test "$(rg -l '\.tokenize\(' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/CognitionKernelCore.swift \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/SemanticCompilerCore.swift \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/ScopedContextCore.swift \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainTurnContextCompiler.swift | wc -l | tr -d ' ')" = "1"
test "$(rg -l '\.tokenize\(' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/CognitionKernelCore.swift \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/SemanticCompilerCore.swift \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/ScopedContextCore.swift \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainTurnContextCompiler.swift)" = "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift"
test "$(rg -l 'func (render|policySignature|contextSignature|fingerprint)|BASCompiledPrompt\(' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/CognitionKernelCore.swift | sort -u)" = "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift"
test "$(rg -n 'BASContextCompiler\.compile' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/CognitionKernelCore.swift | wc -l | tr -d ' ')" = "1"
```

Expected: tests PASS with 0 failures; preserved blocks survive before compaction, all wrappers return byte-identical prompt/order/fingerprint, and only `ContextCompilerCore.swift` contains packing/render/hash ownership.

- [ ] **Step 6: Commit**

```bash
git add BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift \
  BehavioralAISubstrate/Sources/BASOrchestration/CognitionKernelCore.swift \
  BehavioralAISubstrate/Sources/BASOrchestration/SemanticCompilerCore.swift \
  BehavioralAISubstrate/Sources/BASOrchestration/ScopedContextCore.swift \
  BehavioralAISubstrate/Sources/BASHostKit/EBrainTurnContextCompiler.swift \
  BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASExactContextCompilerOwnershipTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASContextCompilerTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASCognitionKernelTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnContextCompilerTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASFrontstageAndScopedContextTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift
git commit -m "feat: extend the canonical context compiler"
```

### Task 8: Shadow-Only Turn Integration and Anti-Duplication Closure

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator.swift`
- Modify exact public/core factoring owner: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurn.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurnStagesMemoryRisk.swift`
- Modify in the audit-value-only prelude; behavior later consumes without editing: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/BASRuntimeAuditProjectionsBundle.swift`
- Modify in the audit-value-only prelude; behavior later consumes without editing: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticStateShadowIntegrationTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticStateAntiDuplicationTests.swift`
- Modify schema fixtures in the audit-value-only prelude; behavior later verifies without editing: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`

**Reuse Decision (E/A):** `BASEBrainRuntimeCoordinator` remains the sole turn coordinator and public-result authority. Add a shadow-only composition branch inside the existing memory/risk stage; do not create a `BASSemanticStateCoordinator`, second run loop, second result, independent retry state, mutable `lastAudit`, callback sink, or memory owner. In a contract-only prelude, extend the existing `BASRuntimeAuditProjectionsBundle` value in place to its complete **first-governed 1.0.0** shape, including the optional nested semantic observation. It is the one ordinary-put audit-projection parent and has no self ID; there is no fabricated 1.0→1.1 history. The coordinator never persists it. HostKit reuses Task 5's one scoped memory helper around existing Artifact Mesh operations.

**Interfaces:**
- Consumes: current typed `BASTurnOperationRef`, turn input/projections, the planner, snapshot coordinator, five adapters, `BASSemanticStateMarket`, `BASGroundingProposalValidator`, the injected W3-test/W4-production `BASGroundingProposalPort`, `BASArtifactStorePort`, the canonical Attempt-`BASArtifactScopeBinding` identity-core factory, existing event log, existing post-R6 `BASContextCompiler`, installed `BASProviderBranchPolicy`, canonical execution-binding artifact ID, and the same injected ledger/per-turn memory-context resolver used by Task 5. The W4 production proposal port uses only the already-composed Silicon planned-execution delegate; the coordinator never receives `BASProviderBranchControlPort` and never does branch bookkeeping. These are source-compatible optional shadow dependencies until wired as one complete set; `.shadowCompare` with any missing dependency emits a typed observation failure and performs no material semantic allocation.
- Produces: a prelude receipt freezing one observation-only `BASSemanticStateShadowObservation` nested in first-governed `BASRuntimeAuditProjectionsBundle` 1.0.0, then one package owner-returned same-run outcome containing the existing authoritative result plus the immutable updated bundle value. The legacy authoritative result remains byte-identical; neither coordinator nor outcome owns an Artifact ID/store receipt.

- [ ] **Prelude [before Runtime Task 1B]: Freeze the final audit value and first-governed parent only**

Add `import BASRuntimeCore` to `BASRuntimeAuditProjectionsBundle.swift`, then declare the exact observation and bundle shapes shown immediately below, conform the bundle to `BASSchemaVersioned`, set `currentSchemaVersion = "1.0.0"`, and give it one schema-first public initializer. Register only the parent once through the normal metatype registry because BASAdmin already depends on BASOrchestration. The exact IDs are `schema.BASRuntimeAuditProjectionsBundle.current`, `schema.BASRuntimeAuditProjectionsBundle.backward_v1`, and `schema.BASRuntimeAuditProjectionsBundle.future_rejection`; `backward_v1` pins the first/current v1 fixture and performs no migration. Add current codec round-trip, first-v1 fixture equality, missing/future rejection, exact-one registry/owner parity, and cross-target default-init tests. The nested observation remains unregistered/unversioned and has no standalone put. This prelude changes no coordinator behavior and performs no ordinary put; commit the value, codec/registry entry, and schema tests as one receipt before Runtime Task 1B.

```swift
public struct BASSemanticStateShadowObservation: Codable, Sendable, Equatable {
    public let turnOperationRef: BASTurnOperationRef?
    public let semanticSnapshotArtifactID: BASArtifactID?
    public let requirementPlanArtifactID: BASArtifactID?
    public let coverageTerminalState: BASCoverageTerminalState
    public let groundingProposalBranchRef: BASTurnBranchRef?
    public let groundingProposalReceiptArtifactID: BASArtifactID?
    public let validatedGroundingReceiptArtifactID: BASArtifactID?
    public let stateMarketSelectionArtifactID: BASArtifactID?
    public let conflictSetArtifactIDs: [BASArtifactID]
    public let contextBudgetReceiptArtifactID: BASArtifactID?
    public let compiledDescriptorArtifactID: BASArtifactID?
    public let executionBindingArtifactID: BASArtifactID?
    public let failureReceiptArtifactIDs: [BASArtifactID]

    public init(
        turnOperationRef: BASTurnOperationRef?,
        semanticSnapshotArtifactID: BASArtifactID?,
        requirementPlanArtifactID: BASArtifactID?,
        coverageTerminalState: BASCoverageTerminalState,
        groundingProposalBranchRef: BASTurnBranchRef?,
        groundingProposalReceiptArtifactID: BASArtifactID?,
        validatedGroundingReceiptArtifactID: BASArtifactID?,
        stateMarketSelectionArtifactID: BASArtifactID?,
        conflictSetArtifactIDs: [BASArtifactID],
        contextBudgetReceiptArtifactID: BASArtifactID?,
        compiledDescriptorArtifactID: BASArtifactID?,
        executionBindingArtifactID: BASArtifactID?,
        failureReceiptArtifactIDs: [BASArtifactID]
    ) {
        self.turnOperationRef = turnOperationRef
        self.semanticSnapshotArtifactID = semanticSnapshotArtifactID
        self.requirementPlanArtifactID = requirementPlanArtifactID
        self.coverageTerminalState = coverageTerminalState
        self.groundingProposalBranchRef = groundingProposalBranchRef
        self.groundingProposalReceiptArtifactID =
            groundingProposalReceiptArtifactID
        self.validatedGroundingReceiptArtifactID =
            validatedGroundingReceiptArtifactID
        self.stateMarketSelectionArtifactID = stateMarketSelectionArtifactID
        self.conflictSetArtifactIDs = conflictSetArtifactIDs
        self.contextBudgetReceiptArtifactID = contextBudgetReceiptArtifactID
        self.compiledDescriptorArtifactID = compiledDescriptorArtifactID
        self.executionBindingArtifactID = executionBindingArtifactID
        self.failureReceiptArtifactIDs = failureReceiptArtifactIDs
    }
}

public struct BASRuntimeAuditProjectionsBundle:
    BASSchemaVersioned, Codable, Equatable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    // Existing five slots remain in their exact 1.0.0 order.
    public let kunlun: BASKunlunAuditProjections
    public let abyssal: BASAbyssalAuditProjections
    public let cthulhu: BASCthulhuAuditProjections
    public let tribunal: BASTribunalAuditProjections
    public let riskCalibration: BASRiskCalibrationProjections
    public let semanticStateShadowObservation: BASSemanticStateShadowObservation?

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        kunlun: BASKunlunAuditProjections = .none(),
        abyssal: BASAbyssalAuditProjections = .none(),
        cthulhu: BASCthulhuAuditProjections = .none(),
        tribunal: BASTribunalAuditProjections = .none(),
        riskCalibration: BASRiskCalibrationProjections = .none(),
        semanticStateShadowObservation: BASSemanticStateShadowObservation? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.kunlun = kunlun
        self.abyssal = abyssal
        self.cthulhu = cthulhu
        self.tribunal = tribunal
        self.riskCalibration = riskCalibration
        self.semanticStateShadowObservation =
            semanticStateShadowObservation
    }
}
```

- [ ] **Step 1: Write failing shadow-inert and source-ownership tests**

```swift
import XCTest
@testable import BASHostKit

final class BASSemanticStateShadowIntegrationTests: XCTestCase {
    func testShadowModeCannotChangeAuthoritativeResultOrReleaseInputs() async throws {
        let legacy = try await runFixture(mode: .legacyOnly)
        let shadow = try await runFixture(mode: .shadowCompare)
        XCTAssertEqual(legacy.result.replayDigest, shadow.result.replayDigest)
        XCTAssertEqual(legacy.releaseRequestDigest, shadow.releaseRequestDigest)
        XCTAssertEqual(legacy.stateCommitCount, shadow.stateCommitCount)
        XCTAssertEqual(legacy.toolDispatchCount, shadow.toolDispatchCount)
        XCTAssertNotNil(shadow.audit.semanticStateShadowObservation)
    }

    func testRequiredBarrierFailureIsObservedButCannotTriggerFallbackAnswer() async throws {
        let run = try await runFixture(mode: .shadowCompare, failingRequiredLane: .sqlMetadata)
        let baseline = try await runFixture(mode: .legacyOnly)
        XCTAssertEqual(
            run.audit.semanticStateShadowObservation?.coverageTerminalState,
            .requiredLaneFailed
        )
        XCTAssertEqual(run.result.replayDigest, baseline.result.replayDigest)
    }

    func testShadowDescriptorBindsSnapshotSelectionAndExecutionArtifacts() async throws {
        let run = try await runFixture(mode: .shadowCompare)
        let observation = try XCTUnwrap(run.audit.semanticStateShadowObservation)
        XCTAssertNotNil(observation.semanticSnapshotArtifactID)
        XCTAssertNotNil(observation.stateMarketSelectionArtifactID)
        XCTAssertNotNil(observation.compiledDescriptorArtifactID)
        XCTAssertNotNil(observation.executionBindingArtifactID)
        XCTAssertTrue(
            Mirror(reflecting: observation).children.compactMap(\.label)
                .allSatisfy { !$0.lowercased().contains("watermark") }
        )
    }

    func testLaneResultArtifactIOFailureCleansMemoryBeforeLifecycleAccept() async throws {
        let fixture = makeShadowFixture(artifactFailpoint: .laneResultPut)
        _ = try await fixture.run()
        let acceptCount = await fixture.snapshotCoordinator.acceptCount
        let ledgerSnapshot = await fixture.memoryLedger.snapshot()
        XCTAssertEqual(acceptCount, 0)
        XCTAssertTrue(ledgerSnapshot.reservations.isEmpty)
    }

    func testDeniedCompiledPredicateTouchesNoRetrievalOrContextMechanism() async throws {
        let fixture = makeShadowFixture(eligibility: .denyCurrentScope)
        _ = try await fixture.run()
        let calls = await fixture.mechanismCalls.snapshot()
        XCTAssertEqual(calls.sql, 0)
        XCTAssertEqual(calls.fts, 0)
        XCTAssertEqual(calls.ann, 0)
        XCTAssertEqual(calls.rust, 0)
        XCTAssertEqual(calls.metal, 0)
        XCTAssertEqual(calls.reranker, 0)
        XCTAssertEqual(calls.contextCompiler, 0)
        XCTAssertEqual(calls.grounder, 0)
        XCTAssertEqual(calls.membershipTiming, .constantDeniedPath)
    }

    func testR5R6AndPostR6CompilerOrderIsExact() async throws {
        let run = try await runFixture(mode: .shadowCompare)
        XCTAssertEqual(run.semanticTrace, [
            .r5InitialHardGate, .r5ReservoirPut,
            .r5GroundingProposalReceipt, .r6ProposalValidation,
            .r6SnapshotReopen, .r6CurrentHardRevalidation,
            .r6ConflictResolution, .r6StateMarket,
            .postR6ContextCompile,
        ])
    }

    func testCorruptGroundingReceiptBlocksMarketAndCompiler() async throws {
        let fixture = makeShadowFixture(
            groundingMutation: .wrongProviderExecutionBranch
        )
        _ = try await fixture.run()
        let calls = await fixture.calls.snapshot()
        XCTAssertEqual(calls.market, 0)
        XCTAssertEqual(calls.contextCompiler, 0)
        XCTAssertEqual(calls.release, 0)
    }

    func testProductionGrounderUsesOneK3BranchAndNeverVisibility() async throws {
        let fixture = makeProductionGroundingFixture()
        _ = try await fixture.runShadowSemanticPath()
        let branchCounts = await fixture.branchControl.snapshot()
        let physicalCalls = await fixture.provider.physicalCalls
        XCTAssertEqual(branchCounts.allocations, 1)
        XCTAssertEqual(branchCounts.claims, 1)
        XCTAssertEqual(physicalCalls, 1)
        XCTAssertEqual(branchCounts.terminalSourcePins, 0)
        XCTAssertEqual(branchCounts.visibilityGateOpens, 0)
    }
}
```

Also add `testSemanticArtifactIOUsesTheTurnResolverWithoutPayloadCapabilityFields`: capture each memory request and assert the root/phase/category sequence described below, then reflect plan/snapshot/query/result/selection/budget/descriptor/audit payloads and reject capability-snapshot, admission-context, context-version, cap, reservation-token, or activation-token fields. Inject context drift before a query/result put and cancellation during put/reopen; each must leave zero reservations and must not call the later lifecycle transition.

Add schema tests for the parent—not the nested observation: current 1.0.0 codec round-trip; a pinned first/current-1.0.0 six-slot fixture with the observation both nil and populated; missing/future-version rejection before any projection field is read; exact registry current/backward-v1/future fixture IDs; registered/current-version parity; and a cross-target initializer fixture that imports `BASOrchestration`, omits `schemaVersion`, and supplies or omits the observation. A source gate rejects a `BASSemanticStateShadowObservation` registry entry, standalone ordinary put/identity, type-local decoder, raw Artifact-payload encoder, or any migration path.

Add anti-duplication tests that read production sources and fail if they find any of these declarations or mechanisms:

```swift
func testForbiddenParallelOwnersDoNotExist() throws {
    let sources = try productionSwiftSource()
    for forbidden in [
        "actor BASSemanticStateLake",
        "enum BASL3ExactContextCompiler",
        "BASArtifactReadVersion",
        "BASProjectionVersion",
        "orderedProjectionVersions",
        "struct BASReplayLaneWatermark",
        "protocol BASReplayManifestStorePort", // immutable manifest storage belongs to Artifact Mesh
        "actor QinaoMemoryStore",
        "actor BASErasureSaga",
        "protocol QinaoErasureAuthority",
        "struct BASCacheScopeKey",
        "enum BASCacheScopeKey",
        "laneWatermarks: [BASSemanticLaneID:",
    ] {
        XCTAssertFalse(sources.contains(forbidden), forbidden)
    }
}

func testQinaoAndEventProjectionOwnNoLocalContentOrCompletionTruth() throws {
    let sources = try productionSwiftSource(paths: [
        "QinaoRuntimeSDK/Sources/QinaoMemory/QinaoMemory.swift",
        "BehavioralAISubstrate/Sources/BASMemory/BASEventSourcedMemoryAtomStore.swift",
    ])
    for forbidden in [
        "private var store:",
        "contentCache",
        "cascadeReceipts",
        "defaultCacheRefs",
        "var completedErasure",
    ] {
        XCTAssertFalse(sources.contains(forbidden), forbidden)
    }
}

func testExactlyOneCompleteCacheScopeContractExists() throws {
    let sources = try productionSwiftSource()
    XCTAssertEqual(
        sources.components(separatedBy: "public struct BASCacheScopeContract").count - 1,
        1
    )
}

func testOnlyStateReadSnapshotDeclaresWatermarkStorage() throws {
    let sources = try productionSwiftSource()
    let legal = "public let orderedLaneWatermarks: [BASLaneWatermark]"
    let watermarkStoredProperties = sources.split(whereSeparator: \.isNewline)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { $0.hasPrefix("public let ") || $0.hasPrefix("public var ") }
        .filter { $0.lowercased().contains("watermark") }
    XCTAssertEqual(watermarkStoredProperties, [legal])
}

func testOnlyExistingEventLogOwnsSemanticLifecyclePersistence() throws {
    let changed = try semanticStateProductionSource()
    XCTAssertFalse(changed.contains("CREATE TABLE semantic"))
    XCTAssertFalse(changed.contains("PRAGMA journal_mode"))
    XCTAssertFalse(changed.contains("sqlite3_open"))
    XCTAssertTrue(changed.contains("BASEventLogStorage"))
    XCTAssertTrue(changed.contains("BASArtifactStorePort"))
}
```

- [ ] **Step 2: Run and verify RED**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASSemanticStateShadowIntegrationTests|BASSemanticStateAntiDuplicationTests'
```

Expected: FAIL at compile time because `.shadowCompare` and `BASSemanticStateShadowObservation` are not wired; ownership tests may also find legacy plan names until all tasks are implemented.

- [ ] **Step 3: Wire an observation-only branch using the prelude-frozen audit values**

Add only the integration mode and coordinator behavior here, not a new production file. Consume and populate the exact observation and parent values already declared and committed by the prelude; Step 3 contains no reference-copy declaration and must not redeclare or edit either type:

```swift
public enum BASSemanticStateIntegrationMode: String, Codable, Sendable {
    case legacyOnly
    case shadowCompare
}
```

The prelude already gave the observation its only explicit initializer in exact displayed-field order. Its optional typed root/branch and proposal/validation receipt IDs are observation-only equality evidence; no raw ID, Provider claim, visibility receipt, or branch-control capability enters the audit payload. This nested value remains unregistered, has no `schemaVersion`, and has no standalone ordinary-put/identity/reopen path.

Every `none()`/`with(...)` path consumes the prelude-frozen parent initializer, preserves all other fields and `schemaVersion`, and changes only its named slot; add `with(semanticStateShadowObservation:)` under the same immutable-accumulator rule. The parent has no self Artifact ID/digest/signature. This complete six-slot declaration is the first governed wire; there was no authoritative persisted five-slot baseline. Before landing, a source/evidence test inventories every Artifact Mesh put/identity/reopen and registry reference and must prove no prior authoritative `BASRuntimeAuditProjectionsBundle` instance exists; any counterexample stops implementation for a real migration design rather than silently rewriting history.

Current ordinary put, identity bytes, and reopen use only `BASGovernedArtifactPayloadCodec.canonicalBytes(for:)`/`decodeCurrent`; missing or future versions fail before projection access. There is no custom `init(from:)`, raw Artifact-payload encoder/decoder, missing-version compatibility, caller-selected accepted-version set, or migration table. Existing general-purpose JSON proof tests may still test `Codable` as values, but cannot be used for Artifact Mesh bytes or authority.

Register only `BASRuntimeAuditProjectionsBundle` once through the normal metatype registry entry because BASAdmin already depends on BASOrchestration. Its exact test IDs are `schema.BASRuntimeAuditProjectionsBundle.current`, `schema.BASRuntimeAuditProjectionsBundle.backward_v1`, and `schema.BASRuntimeAuditProjectionsBundle.future_rejection`; `backward_v1` is the pinned first/current v1 fixture, not a migration. Assert exact-one entry/test IDs, `currentVersion == BASRuntimeAuditProjectionsBundle.currentSchemaVersion`, current canonical round-trip, first-v1 equality, missing/future rejection, and the cross-target public-default-initializer fixture. `BASSemanticStateShadowObservation` has no registry object ID.

Use the one package `BASSameRunAuditOutcome` contract declared by Runtime Task 1B in the existing BASHostKit owner. It contains exactly `result: BASEBrainTurnResult` and `auditProjections: BASRuntimeAuditProjectionsBundle`; it contains no Artifact ID, store receipt, closure, mutable reference, or second result. Preserve the actual synchronous public ABI by factoring the existing ordered stage functions in `EBrainRuntimeCoordinator+RunTurn.swift`, not by running a complete core and adding shadow work afterward. Public synchronous `runTurn(_:) -> BASEBrainTurnResult` executes the legacy-only stage chain once and projects its result. Package async `runTurnWithAuditOutcome(_:) async -> BASSameRunAuditOutcome` executes the same prefix once, awaits the shadow R0–R6 branch at the existing memory/risk seam **before** terminal-source/release/commit/effect suffix stages, then executes that suffix once and returns the immutable updated bundle beside the same result. It never runs the full synchronous core first, blocks on a Task bridge, re-enters a completed Attempt, or executes a second prefix/suffix/result core. Default legacy callers remain source-compatible; `.shadowCompare` production composition uses the async package route, while a sync caller configured for async shadow gets a typed unavailable diagnostic and executes zero semantic mechanisms. At authoritative cutover, `BASTurnRuntimeEngine` produces the same outcome contract directly from its own same-run typed stage/result evidence, and Runtime Task 7 removes the coordinator production call without losing bundle production. A source/runtime gate forbids `lastAudit`, actor-local bundle caches, callback/sink closures, second execution, result fields carrying the bundle, caller-supplied bundle parameters, and coordinator/engine return values containing an Artifact ID.

Extend the existing coordinator initializer/decode path with source-compatible defaults: integration mode defaults to `.legacyOnly`, and all shadow dependencies remain optional until explicitly wired together. Selecting `.shadowCompare` without the complete Artifact Mesh/event-log/planner/lane/market/tokenizer/ledger/per-turn-context-resolver bindings emits a typed observation failure and leaves the legacy path untouched; it never silently fabricates coverage, a memory context, or an in-process default service.

The existing memory/risk stage performs this exact shadow sequence:

1. Resolve and validate the current non-empty `BASAttemptVisibilityScope` (authority, workspace incarnation/ref, private window ref, Attempt ref, generation vector, compartment, purpose, restoration/policy/capability/deletion/kill epochs) plus the same K3 row's current `calendarPolicyArtifactID` before any semantic allocation. Reopen/canonical-byte-validate that `BASCalendarPolicyPayload`, then build `BASStateRequirementPlanningInput` from the exact scope, explicit allowed-sensitivity set, already-admitted request, intent/risk, world-prior, constitution, and coverage-policy artifact IDs. No process-default calendar/locale/timezone or caller digest is accepted.
2. Call `BASStateRequirementPlanner.plan`, then wrap identity-core encoding plus ordinary `put(identityCore:headUpdate:)` in Task 5's helper with root = admitted request artifact ID, `.artifactIO/.retrievalIndexAndLaneResult/.ordinary`; retain only `receipt.body.artifactID`.
3. Call `BASSemanticSnapshotCoordinator.open` with that exact current `calendarPolicyArtifactID`, then wrap snapshot encode/put/reopen and open event with root = requirement-plan artifact ID and the same Artifact-I/O phase/category/class. The coordinator repeats K3 binding plus policy-artifact validation before lane freeze. No lane runs before the snapshot artifact exists and its open lifecycle event is appended.
4. Call `compileQueries`, but feed its queries to the canonical progressive phase machine above rather than one all-lane `TaskGroup`. R0 validates the complete predicate against the reopened plan/snapshot and current K3 scope; a denied/missing/empty physical partition emits the constant-path terminal receipt and invokes zero SQL/FTS/ANN/Rust/Metal/RAG/temporal/entity/rerank/context/grounding mechanisms. R1 completes before trigger evaluation for optional structured/dense work. R2 and R3 each execute or persist their deterministic skip receipt in order. R4 starts only from its frozen explicit trigger or a coverage-deficit receipt produced after the structured phases; the sole exception is certified overlap for an already-explicit dense query. Within one activated phase, independent physically eligible queries may use a bounded `TaskGroup`, but children never put or accept results. The parent collects, sorts by `BASSemanticLaneID.rawValue`, and scopes each query/result/phase receipt encode-put-reopen-accept operation to the same snapshot/query root. It closes the phase before starting the next, rejects late results by Attempt/generation/phase epoch, and completes the snapshot once after R4. A failed result already references the scoped failure artifact created by `failureArtifactWriter`; do not put it twice. No child appends an event, and no semantic-specific put, receipt, sequence, lifecycle, memory-token, or memory-context API exists.
5. Execute canonical R5 through the one join/market owner. Reopen and integrity-check `semanticSnapshotArtifactID`; join the lane results; run initial candidate hard eligibility; canonicalize only admitted candidate/rank/source facts; delegate dedupe/fusion/caps/finite-`k` to the one existing Rust RRF bridge; verify bounded canonical output; build and ordinary-put the self-ID-free `BASGroundingEligibleReservoir`. No Swift fusion/ranker exists. Select the one exact grounding `stepRuleID` from frozen semantic composition, then materialize and ordinary-put that rule's grounding plan bound to the exact `BASTurnOperationRef`, semantic snapshot, requirement plan, reservoir, execution-binding root, installed `BASProviderBranchPolicy`, and requested `.internalProposal` role. Invoke the injected `BASGroundingProposalPort` exactly once with those exact policy/rule/role/cause/plan/binding values. In W3 tests this is a deterministic bounded conformer. Production W4 validates and forwards those values unchanged to the sole Silicon planned-execution delegate; only Silicon may preflight, allocate, claim, invoke through `BASProviderAttemptExecutor.executeExactlyOnce`/`BASOrganAdapter.executePlanned`, and seal the event head. The semantic adapter validates and ordinary-puts the returned proposal/receipt. K3 derives `.groundingProposal`; the adapter cannot scan/select a rule, own an endpoint/branch-control call, designate a terminal source, form a `BASProviderBranchChainPayload`, open either `BASProviderVisibilityMode` gate, stream to UI, compile context, or write state. Semantic proposal/validation receipts are later consumed as causal inputs by the Silicon/K3 shared chain; a possible-start/indeterminate branch is query/reconcile-only and cannot be replaced by another grounding branch.
6. Execute canonical R6 before any conflict/market/compiler operation. Reopen the same snapshot, requirement plan, reservoir, proposal, installed policy, execution binding/step plan, and exact K3 allocation/claim/head-seal receipts. Call `BASGroundingProposalValidator.validate` and require exact policy ID/`stepRuleID` across every artifact and receipt, root, branch kind/ordinal, K3-derived purpose, caller-requested/receipt role, complete `BASProviderExecutionRef`, active Attempt/lease/generation, plan/model/profile/budget, causal receipt order, candidate domain/order/digests, schema, and bounds. Then reopen current K3 scope and rerun `BASGlobalHardEligibilityGate` against current consent/deletion/policy/kill/freshness/governance facts. Only the resulting `BASValidatedGroundingResult` may enter global conflict resolution and `BASSemanticStateMarket.select(join:validatedGrounding:context:)`; no reservoir/direct-proposal Market overload exists. Scope selection encode/put/reopen with root = semantic-snapshot artifact ID and retain only the receipt Artifact ID. Join, proposal, validated result, selection, and audit values never copy a watermark or memory-authority field.
7. Only after the R6 selection/receipt is durable, project selected R6-admitted evidence into context segments and call `BASContextCompiler.compileExact` once. Scope budget-receipt and descriptor encode/put/reopen with root = State-Market selection artifact ID and the same Artifact-I/O mapping; retain only their receipt artifact IDs. Neither payload contains those IDs or any capability/admission fact. ContextCompiler is a post-R6 consumer, never part of R6 or callable by the proposal adapter.
8. Create `BASSemanticStateShadowObservation`, including proposal/validation failure receipt references when R5/R6 fails but never branch-control authority, and immutably update the already-frozen 1.0.0 bundle value. Return that exact value beside the same run's unchanged result in `BASSameRunAuditOutcome`. The coordinator performs zero bundle puts and returns/guesses no Artifact ID. The Runtime engine is the sole later owner allowed to central-codec put once, take the receipt ID, same-store reopen/byte-equality-check, and place that ID in its final governed envelope; never put or reopen the nested observation alone.
9. Discard the shadow prompt/result as an authority input. Continue the existing legacy request, generation, release, commit, and effect path unchanged. Public `runTurn` projects the exact outcome result once; the package outcome is the only transport for the immutable same-run bundle.

Do not add a catch-all fallback that treats semantic failure as complete coverage. Every failure produces typed coverage/failure artifacts and an observation; shadow mode remains inert.

- [ ] **Step 4: Run the closure suite three times**

Run:

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
cd "$ROOT"
python3 scripts/check_qinao_owner_ledger.py --root "$ROOT" --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"
for run in 1 2 3; do
  swift test --package-path "$ROOT/BehavioralAISubstrate" \
    --filter 'BASSemanticStateShadowIntegrationTests|BASSemanticStateAntiDuplicationTests|BASSemanticSnapshotCoordinatorTests|BASStateRequirementPlannerTests|BASSemanticStateLaneAdapterTests|BASSemanticStateMarketTests|BASMemoryErasureClosureTests|BASCacheScopeContractTests|BASExactContextCompilerOwnershipTests|BASCognitionKernelTests|BASEventLogSemanticSnapshotTests|BASContextCompilerTests|BASTurnContextCompilerTests|BASProcessMemoryLedgerTests|BASEBrainSchemaGovernanceRegistryTests|BASRuntimeAuditProjectionsBundleCodableDoctrineTests' || exit 1
done
```

Expected: three PASS runs with 0 failures; every shadow-enabled fixture has the same authoritative replay/release digest and mutation counts as legacy-only mode.

- [ ] **Step 5: Run the full ownership and no-parallel-store scan**

Run:

```bash
if rg -n 'actor BASSemanticStateLake|enum BASL3ExactContextCompiler|BASArtifactReadVersion|BASProjectionVersion|orderedProjectionVersions|struct BASReplayLaneWatermark|laneWatermarks: \[BASSemanticLaneID:' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources; then
  exit 1
fi
test "$(rg -n 'public let .*BASLaneWatermark' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources | wc -l | tr -d ' ')" = "1"
rg -n 'public let orderedLaneWatermarks: \[BASLaneWatermark\]' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticStateLakeContracts.swift
test "$(rg -l '\.tokenize\(' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/SemanticCompilerCore.swift \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/ScopedContextCore.swift \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainTurnContextCompiler.swift | wc -l | tr -d ' ')" = "1"
if git diff -- BehavioralAISubstrate/Sources | rg 'CREATE (TABLE|INDEX|VIRTUAL TABLE).*semantic|semantic.*PRAGMA journal_mode'; then
  exit 1
fi
HOST_ROOT=/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit
test "$(rg -n '^(internal[[:space:]]+)?func withProcessMemoryAdmission' "$HOST_ROOT" --glob '*.swift' | wc -l | tr -d ' ')" = "1"
if rg -n 'BASProcessMemoryLedger[[:space:]]*\(|hardCapBytes:|private var .*([Rr]eservation|[Hh]eavy)' \
  "$HOST_ROOT/BASL8RoutedMemoryService.swift" \
  "$HOST_ROOT/EBrainRuntimeCoordinator.swift" \
  "$HOST_ROOT/EBrainRuntimeCoordinator+RunTurnStagesMemoryRisk.swift"; then
  exit 1
fi
test "$(rg -n '^public struct BASCacheScopeContract' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources --glob '*.swift' | wc -l | tr -d ' ')" = "1"
test "$(rg -n 'BASRuntimeAuditProjectionsBundle' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift | wc -l | tr -d ' ')" = "1"
! rg -n 'BASSemanticStateShadowObservation' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift
! rg -n 'JSON(Encoder|Decoder)|init\(from:' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/BASRuntimeAuditProjectionsBundle.swift
if rg -n 'private var store:|contentCache|cascadeReceipts|defaultCacheRefs|recallFrontstage\(\)|frontstageBundle\(\)' \
  /Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoMemory/QinaoMemory.swift \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASEventSourcedMemoryAtomStore.swift; then
  exit 1
fi
```

Expected: all commands exit 0 with no forbidden owner/store output; only `ContextCompilerCore.swift` contains a tokenizer call.

- [ ] **Step 6: Commit**

```bash
git add BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator.swift \
  BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurn.swift \
  BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurnStagesMemoryRisk.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticStateShadowIntegrationTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticStateAntiDuplicationTests.swift
git commit -m "feat: shadow semantic state convergence"
```

## Completion Gate

Implementation is complete only when all of the following are true:

- Exactly four production creates from this plan exist, and each is one of the M owners proved above.
- The exact shared gate `python3 scripts/check_qinao_owner_ledger.py --root "$ROOT" --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"` passes before RED and at closure; no second ledger, CreateGate, runtime owner, or unallowlisted production Create exists.
- The shared ledger contains exactly the four reviewed semantic M responsibilities and workspace-relative paths declared in this plan; each Task-1/3/4/6 candidate manifest independently passes with its own eight-part proof, and a fifth row, path abbreviation, or cross-task proof reuse fails.
- K3 remains the one `BASEventLogStorage`/`BASSQLiteEventLogStorage` authority with one SQLite file/WAL/write owner and `synchronous=FULL`. Only its scoped epoch/erasure extensions were added; no second semantic store, event log, cursor timeline, control WAL, integrity chain, FTS/vector index, or retrieval cache exists, and all projection stores remain rebuildable.
- `QinaoMemory` is scope-required façade plumbing over the unique K3/EventLog, Artifact Mesh, and existing event-sourced StateLake projection. It owns no local store, content cache, cascade receipt ledger, default cache references, scope-free recall/frontstage path, or second ranking/deletion authority.
- Every admitted memory event binds one `contentArtifactID` and commitment; replay/restart reopens only the winning Artifact Mesh object and can never form a metadata/content hybrid or treat a process cache as truth.
- Historical raw-content/event truth crosses one sealed K3 checkpoint only: governed content/checkpoint parents, invisible deterministic staging, typed legacy-v0 migration decode, final-tail parity, and one atomic EventLog/head flip yield all-old or all-new replay. Cold restart proves every live Artifact before legacy raw rows/cache are retired; no mixed epoch, dual writer, missing-row skip, tombstone resurrection, or post-cutover legacy decoder/fallback remains.
- Erasure rank is monotonic across crash and logical-clock rollback. `.completed` is impossible until key absence plus separate durable ACKs from process RAM, frontstage, spill, compiled context, FTS, vector, temporal, entity, linguistic, session, KV, prefix, neural, verifier, result, Provider, artifact payload, controlled backup, and export, followed by a closure rescan; no aggregate ACK is accepted, and an unreachable owner is `.erasureIndeterminate`, never completed-looking.
- Exactly one exhaustive `BASCacheScopeContract` keys and acquires every session/KV/prompt/prefix cache. Mutating any physical-content or acquisition-scope field misses before membership/bytes, and two private windows never alias unless an explicit shared compartment authorizes it.
- Snapshot, requirement plan, lane query/result, selection, budget receipt, and compiled descriptor are Artifact Mesh payloads with no self IDs/digests/signatures.
- `BASRuntimeAuditProjectionsBundle` is the sole governed audit-projection parent at first/current 1.0.0. Its first-v1 fixture contains all five prior value slots plus the optional semantic observation; source evidence proves there was no earlier authoritative persisted baseline, and no migration is fabricated. The coordinator returns the same-run immutable value only; Runtime central-codec puts/reopens it once and references the receipt ID. The nested `BASSemanticStateShadowObservation` has no standalone put, version, identity, or registry entry.
- Every new cross-plan reference is `BASArtifactID`.
- Only the `BASStateReadSnapshot` Artifact Mesh payload owns the canonical ordered `[BASLaneWatermark]`. Lane results, joins, selections, audit/shadow observations, manifests, and replay carry `semanticSnapshotArtifactID` plus lane/source IDs and reopen that snapshot for version proof; no second watermark field/vector, `BASArtifactReadVersion`, projection-version vector, dictionary, or replay wrapper exists.
- `BASStateReadSnapshot` also binds exactly one `calendarPolicyArtifactID`; open and every reopen exact-match it to the current complete-scope K3 binding and reopen/canonical-byte-validate `BASCalendarPolicyPayload`. No payload or API accepts a copied calendar digest, process-default locale/timezone, or wall-clock-derived policy identity.
- `BASBitemporalInterval` is the sole valid/transaction interval across candidates, temporal records, horizon manifests, corrections/retractions, and replay. Its exact half-open axes are `validTime.worldFrom/worldTo` and `transactionTime.eventOffsetStart/eventOffsetEnd`; legacy observation timestamps are provenance only and no parallel `validFrom`/`observedAt` truth survives production composition.
- `BASMemoryHorizon` has exactly `current|day|week|month|archival`, and `BASMemoryHorizonManifestPayload` is an immutable Artifact Mesh projection over exact EventLog ranges/root, bitemporal interval, provenance, coverage/loss, calendar Artifact ID, policy/deletion/invalidation epochs, optional paired sealed-lossless-checkpoint/equivalence evidence, and parent hints. The existing temporal/horizon/sleep files were adapted E/A; no fifth M, horizon store, scheduler, WAL, or projection authority exists.
- Day/week/month boundaries are deterministic under the sealed calendar/DST/week rules; timezone/tzdb/ICU/OS-build/locale/calendar/week/day-boundary changes invalidate and rebuild without source rewrite, EventLog offsets defeat clock rollback, erasure rebuilds blinded tombstones, and private windows never alias. Higher horizons replay original EventLog or a range/root-equivalent sealed lossless checkpoint; parent manifests are hints only, and pruning without checkpoint + equivalence + retention authorization is rejected before row deletion.
- Every lane calls Task 3's one full-field validator over the reopened plan/snapshot and exact-compares scope, both source digests, canonical sensitivity set, minimum authority, governance booleans, snapshot/binding fields, and budgets before applying the predicate as a physical partition/filter ahead of SQL/FTS/ANN/Rust/Metal/RAG/temporal/entity work. A denied or empty partition causes zero retrieval, rerank, context-compile, grounding, and membership-timing calls; the global candidate hard gate still runs and cannot be compensated by local rank/evidence.
- Existing memory eligibility/conflict outputs appear only as lane evidence; only `BASHardEligibilityDecision` and `BASClaimConflictSet` decide globally, and only `[BASEligibleStateCandidate]` inside `BASGroundingEligibleReservoir` can reach a grounder.
- Only `BASContextCompiler` owns dropping/preservation/compaction/tokenization/render/order/signature/fingerprint and hashes the compiled token stream. `CognitionKernel` and all compatibility compilers delegate exactly once and return the compiler's bytes/order/fingerprint unchanged.
- All five lane queries and every material semantic Artifact Mesh encode/put/reopen are scoped through one injected process ledger and the turn's twice-resolved verified context; ordinary lanes overlap, dense is heavy only when certified, and throw/cancellation/context drift leaves zero pending/active reservations.
- No semantic payload stores capability-snapshot/admission/reservation/activation facts, and the three HostKit production files declare no ledger constructor, raw cap, reservation map, or heavy-owner map.
- Shadow mode changes no authoritative result, release input, commit, or effect count across three repeated closure runs.
