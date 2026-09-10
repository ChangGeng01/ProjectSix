# Governed memory transaction implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development for Task20.
> Preserve the existing solo recovery workspace. Task20 implementation and
> scoped fix review are complete; this does not authorize concurrent source work.

**Goal:** Stop authoritative governed-memory/projection paths from swallowing
storage failures or publishing fresh state after a failed write.

**Architecture:** Reuse the Task15 private-context transaction primitive, strict
complete reads and one conditional save. Return immutable values, then perform
dependent embedding/projection publication. Propagate failure through existing
host resolver callbacks, preserving the previous published state and dirty bit.

**Tech Stack:** Existing Swift6, SwiftData, BASAppleLifecycleKit/BASMemory/BASHostKit;
no new dependency, storage engine, real data migration or model invocation.

**Spec:** Approved decisions2/3/8/12 in
`docs/superpowers/specs/2026-09-10-qinao-approved-decisions.md`. Detailed retained
design: solo SDD `governed-write-design-handback-2026-09-10.md`, all499lines.
Its final addendum supersedes its obsolete Task17 naming and blanket committed
error label. This new implementation is Task20; Task17 remains completed StateLake.

## Global constraints

- Preserve all history, stores, keys, evidence, dirty drafts and completed fixes.
- Source API changes are authorized for strict errors/immutable results, not
  data deletion or automatic replay. Do not edit Archive or out-of-tree hosts.
- Caller pending inserts/updates/deletes must not be saved or rolled back by the
  owned operation. Existing Task15 one-standard-configuration limitation remains.
- Do not claim abrupt-kill, external/custom-writer, consistent MVCC snapshot,
  recovery quiescence or stale-execution isolation from one ModelContext.
- No real model/cloud/PCC/app/simulator/new scan/DS3/merge; no new harness framework.
- No parallel Swift source writer or competing CPU-heavy validation. Root owns
  commit/push/review and any whole-candidate CI run.

## Task 20: One strict governed-memory to host-publication slice

**Files / responsibilities (paths under BehavioralAISubstrate):**

- Rename `Sources/BASAppleLifecycleKit/AppleCurrentBrainPersistenceTransactionCore.swift`
  to `ApplePersistenceTransactionCore.swift`; reuse, do not copy, its implementation.
- Mechanical neutral-type references in `AppleCurrentBrainCommitterCore.swift`,
  `AppleCurrentBrainUpdateWriterCore.swift`, `AppleEvolutionCheckpointWriterCore.swift`
  and their current tests. Retain Task15 behavior.
- Governed write/strict read/value conversion: `AppleMemoryReconciliationWriterCore.swift`,
  `AppleMemoryGovernanceAdapterCore.swift`, context-backed/value-projection portions
  of `AppleMemoryAdapterCore.swift`, `AppleMemoryProjectionSelectionCore.swift`.
- Transaction-to-publication composition: `AppleMemoryProjectionRefreshCore.swift`.
- Throw propagation: `AppleMemoryProjectionLifecycleCore.swift`,
  `AppleCurrentBrainProjectionRuntimeCore.swift`, `Sources/BASHostKit/HostRuntimeCore.swift`.
- Direct projection-refresh callback continuations additionally require
  `AppleLifecycleBootstrapCore.swift`, `AppleAppLifecycleOrchestrationCore.swift`
  and `Sources/BASAppleAdapters/AppleCurrentBrainRuntimeBridgeCore.swift`.
  Limit their edits to throwing refresh/bootstrap callback propagation; no
  lifecycle ordering/trigger policy redesign.
- Reuse stored fields/snapshots in `Sources/BASMemory/MemoryPersistenceCore.swift`
  and `MemoryReconciliationCore.swift`; put total conversions in the Apple layer
  if no lower-layer change is necessary. No duplicate field mappings.
- Tests: existing `BASAppleMemoryProjectionRefreshAdapterTests.swift`,
  `BASAppleMemoryProjectionSelectionAdapterTests.swift`,
  `BASAppleMemoryProjectionLifecycleTests.swift`, `BASHostKitTests.swift`,
  `BASAppleCurrentBrainHostLifecycleRuntimeTests.swift`, and mechanical Task15
  test migrations; add coverage to `BASAppleLifecycleBootstrapExecutorTests.swift`
  and `BASAppleAppLifecycleOrchestrationTests.swift` as needed. A focused
  `BASAppleGovernedPersistenceTests.swift` plus one
  shared fixture/fault support file is allowed to prevent bloating/duplicating
  the six existing Refresh fixture entities. Preserve original test behaviors.
- Mechanical compiled consumer: `BASAppleMemoryDraftDerivationAdapterTests.swift`
  requires `try` for its context-backed deriveDrafts call. Root68e67b read that
  one-line amendment; it is in scope and included in final coverage. No change
  to its actual derivation assertions or pure-array API is authorized.

All unqualified source filenames above are in `Sources/BASAppleLifecycleKit`;
test filenames are in `Tests/BehavioralAISubstrateTests`.

**Exact interface requirements:**

```swift
// Neutral internal helper: retain original perform as a convenience over this.
struct BASApplePersistenceTransactionOutcome<Value> {
    let value: Value
    let didSave: Bool
}
// performReportingSave(selectedBy:using:_:) has one private context, autosave
// disabled; didSave becomes true only after io.save returns successfully.

public struct BASAppleMemoryReconciliationWriteResult: Sendable {
    public let orderedRecords: [BASGovernedMemoryStoredFields]
    public let candidates: [BASCandidateMemoryStoredFields]
    public let outcome: BASAppleMemoryPersistenceOutcome
}

public static func reconcile<Governed, Candidate>(
    _ request: BASAppleMemoryPersistenceRequest,
    recordType: Governed.Type,
    candidateType: Candidate.Type,
    in context: ModelContext
) throws -> BASAppleMemoryReconciliationWriteResult
where Governed: BASAppleGovernedMemoryEntity,
      Candidate: BASAppleCandidateMemoryEntity

public enum BASAppleMemoryProjectionPersistenceDisposition: Sendable {
    case readOnlyProjection
    case reconciliationEvaluatedNoWrite(BASAppleMemoryReconciliationWriteResult)
    case committedReconciliation(BASAppleMemoryReconciliationWriteResult)
}
```

- The explicit metatypes select actual fetched/staged entity types at every
  context-backed entry point. No inference-only unused argument or live-model
  receipt. Add internal staging/IO overloads without exposing production bypasses.
- Map all17 governed and21 candidate snapshot fields listed in design addendumB;
  convert after mutations and retain canonical order. Pin every field with an
  independent literal fixture equality test.
- Strictly fetch governed/candidate/cue/check-event/comparative/reflective inputs
  before mutation/publication. No try?-to-empty fallback, partial prefix, caller
  context live values or post-write best-effort refetch in authoritative paths.
  Keep pure array-based draft derivation nonthrowing. Existing selection names
  become throwing; do not add unused best-effort compatibility wrappers.
- If both governance counts are zero, stage derivation/reconciliation using the
  same owned context/read values, then one save only if it has changes. Otherwise
  publish from successful strict reads without a pretend write. This is complete
  read error handling, not protection from every concurrent external writer.
- Projection and embedding receive immutable stored/input arrays; preserve both
  memory and projection event representations when a custom entity maps them
  differently. No PersistentModel reference escapes the owned transaction.
- Rebuild embeddings only after successful transaction return. Its callback
  throws; wrap failure with disposition, stage and underlying error. A failed
  save returns no success/disposition receipt and is never automatically retried.
  Keep pure deterministic projection compilation nonthrowing if it cannot fail;
  do not invent a callback/error branch just to test an unreal failure mode.
- Resolver callback closures become throwing and failure propagates through the
  existing host chain. Use rethrows where it truthfully describes pure forwarding.
  Do not call projection commit, dirty=false, current-brain or session execution
  after a refresh error. Preserve cached/success behavior and previous values.
  This includes HostRuntime's resolveProjectionRefresh,
  resolveCurrentBrainProjection, resolveAndActivateSession and executeLifecyclePhase;
  the lifecycle-bootstrap/orchestration execute functions; and both primeSession /
  refreshActiveBrain functions in runtime and bridge executors. Their direct
  refreshMemoryProjection/bootstrapCurrentBrain/refreshCurrentBrain closures
  must accept and propagate relevant throwing operations. Other unrelated UI
  closures need no blanket throwing conversion.

Ruling: use actual-save disposition, not blanket committed-but-failed wording;
the helper may return without saving. Keep nonthrowing pure computation honest;
only actual throwing publication surfaces need typed failure stages. Cost if
wrong: an additional future fallible publication stage needs an explicit API
extension, not a fictitious success/error interpretation today.

Pre-dispatch source check57af7c/0126eb/6931d7 found those concrete lifecycle/bridge
callbacks beyond the original handback. Ruling: include their narrowly scoped
throw propagation in this vertical slice — otherwise the documented host-facing
refresh workflow still cannot accept the strict writer without swallowing errors
— cost: a few additional callback signatures/tests, not a new host framework.

- [x] Read exact existing callers/fixtures and the full design addendum. Verify
  owned-file coverage; raise any necessary compiled consumer outside this list
  before expanding. No broad repository security scan.
- [x] Add a behavioral RED on the old public writer using the real read-only
  SwiftData file configuration: a required mutation's save error must escape,
  while current code only calls onSaveError and returns. Keep the old generic
  contextual result spelling for the pre-fix test, then migrate it with the API.
  New-interface compile errors alone are not the required behavioral RED.
- [x] Implement the helper reuse, immutable receipts and strict read/stage paths;
  migrate compile-visible consumers and tests without archive edits.
- [x] Cover each of six fetch failures, later-prefix failure, failed/successful
  caller pending insert/update/delete isolation, immutable old receipt,
  one-save empty-governance and zero-save nonempty/no-mutation paths, real
  read-only save error, complete field/order file-store reopen, all three
  embedding-failure dispositions, no host publication/downstream execution,
  cached/success behavior and unsupported configuration refusal. Distinguish
  injected control-flow failures from actual SwiftData errors and ordinary reopen
  from abrupt termination. No internal save fault is proof of global rollback.
- [x] Run focused new cases while iterating, then one final covering native
  invocation using the retained BAS scratch and same-source metallib. Inspect
  selected test bodies first to ensure no real model/inference is invoked.

```sh
# cwd: BehavioralAISubstrate; parent must release Swift scratch before dispatch.
/usr/bin/env \
  -u QINAO_JOURNAL_GROUND -u QINAO_JOURNAL_GROUND_REPO \
  -u QINAO_JOURNAL_GROUND_SEMANTIC \
  -u BAS_ENDURANCE_AUTOSTART -u BAS_V12_PROBE \
  -u BAS_FUZZ_BENCH_RUN -u QINAO_MLX_E2E -u QINAO_MLX_BENCH \
  -u QINAO_FM_E2E -u BAS_T5_XCTEST -u BAS_AGENT_FABRIC \
  MLX_METAL_PATH=/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib \
swift test --build-system native \
  --scratch-path /private/tmp/qinao-bas-native-test-1329bde3 \
  --filter 'BASAppleGovernedPersistenceTests|BASAppleMemoryDraftDerivationAdapterTests|BASAppleMemoryProjection(RefreshAdapter|SelectionAdapter|Lifecycle)Tests|BASAppleCurrentBrain(Committer|UpdateWriter|Bootstrap|HostLifecycleRuntime)Tests|BASAppleEvolutionCheckpointWriterTests|BASAppleLifecycleBootstrapExecutorTests|BASAppleAppLifecycleOrchestrationTests|BASHostKitTests/test.*(Projection|ActivateSession|LifecyclePhase)'
```

- [x] Report counts/actual selected suites, full commands/logs/source hashes,
  warnings, genuine RED, limitations and self-review. Freeze the task-only diff
  for independent review; no staging/commit/push/subagents by implementer.

## Consistency checks

| Boundary | Required result |
|---|---|
| Task15 / neutral helper | same ownership/fetch/save semantics; one implementation |
| Generic entities / immutable results | explicit concrete metatypes; total17/21fields |
| Six reads / stage/save | no mutation from failed or incomplete enumeration |
| Optional save / publication error | exact three dispositions; no invented commit |
| Refresh / host state | old projection and dirty flag survive failure |
| Private context / recovery | caller edits isolated; stale writers still separate |
| Tests / product claim | real save+reopen only; no abrupt-kill or out-of-tree host proof |
| Task19 / Task20 | separate source paths, implementations serialized |

## Queue status

Task20 initial candidate passed106selectedtests, then independent review found
two Important and two Minor issues. Fix1 passed its39case covering selection;
fresh scoped re-review ACCEPTED all four findings with0new C/I/M. Root read the
complete reports and covering logs and matched all30extant source/test hashes.
The writer and scratch are released; ordinary scoped commit precedes Task21.
See the matching governed-memory-transactions evidence document for precise
test/candidate identities and retained limits. No full-product green is claimed.

## Review correction — fix round1

Root verified all four findings against the actual source/test bodies. Add one
lossless snapshot initializer per BASMemory stored-field type and make existing
write-normalizing methods reuse those mappings while retaining normalization.
Receipts/read-only projection use lossless conversion. This explicitly includes
`MemoryPersistenceCore.swift` and `BASMemoryPersistenceCoreTests.swift` in scope.

Retain the prior persistent-model-ID tie breaker for comparative/reflective
records before limiting, using one shared internal array selection helper if
needed; keep the six authoritative reads and private-context ownership intact.
Tests pin noncanonical tag preservation, tied restrictive selection, complete
reopened ID sets/deletion/order and a file reopen after committed reconciliation
followed by embedding failure with unchanged host publication/dirty state.

Ruling: lossless snapshots and normalized write inputs are distinct contracts;
share field mapping but not implicit policy. Cost: two additive conversion APIs,
not changed stored data, legacy write policy or receipt semantics. Temporal
selection restores existing behavior rather than selecting a new ordering.

Final amendment coverage selects BASMemoryPersistenceCoreTests,
BASAppleGovernedPersistenceTests, the memory projection refresh/selection/
lifecycle suites and relevant BASHostKit projection/activation/lifecycle tests.
The original106case evidence remains; do not rerun unchanged portions merely
for recovery. Independent re-review inspects only the four findings/fix diff.
