# Current-brain Atomic Writes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. This is one independently reviewable slice of the existing DS3-readiness goal, not a new scan or goal.

**Goal:** Current-brain and checkpoint writes propagate storage failures, preserve unrelated pending edits, and publish their combined result only after one successful owned-context save.

**Architecture:** Each public write owns a fresh, autosave-disabled context of the supplied container and returns immutable stored-field values. Combined commits stage both records in that same context and save once. The host continues to serialize writes; this slice does not promise cross-process serialization, cross-store transactions, hardware-loss survival, or restored-session fencing.

**Tech Stack:** Existing SwiftData, Swift Testing, SwiftPM and Xcode 27; no new dependency, provider or model invocation.

**Spec:** `docs/superpowers/specs/2026-09-10-qinao-approved-decisions.md`, choices 2A/3A/12A. Completed source verification and ownership analysis remain in `.superpowers/sdd/2026-09-09-qinao-ds3-readiness-solo/persistence-write-{fix-verification,design-preflight}-2026-09-10.md`.

## Global Constraints

- Preserve old databases, Git history, dirty drafts, and original DS1/DS2 evidence.
- Never save or roll back the caller's unrelated pending changes.
- Source compatibility may change; no swallowing errors into success-looking results.
- Keep 72-hour retention behavior, ordering, checkpoint deduplication, lineage/revocation matching and stable persisted schemas unchanged.
- No cloud/PCC/model use, scan, merge, paid runner, real-user database operation or cleanup of another task's scratch.
- Use the existing worktree and retained native build scratch only after Task 11 releases it. No cold rebuild or unchanged baseline rerun.
- This slice leaves governed-memory writes/projections, routed-memory durable intents, abrupt process interruption and actual host recovery isolation open. Do not close `occ_d728326c5cc2bd163518268e` or `occ_7a629c62101ee729248dbb21` in full.

## Task 15: Own and atomically publish current-brain writes

### File ownership

Modify under `BehavioralAISubstrate/Sources/`:

- `BASAppleLifecycleKit/AppleCurrentBrainUpdateWriterCore.swift`: strict read/stage/write and value receipt.
- `BASAppleLifecycleKit/AppleEvolutionCheckpointWriterCore.swift`: all public record/attach/set/revoke paths use the same strict owned transaction, with internal no-save staging for combined commit.
- `BASAppleLifecycleKit/AppleCurrentBrainCommitterCore.swift`: stage checkpoint and update then save once; return only after save.
- `BASAppleLifecycleKit/AppleCurrentBrainBootstrapHostCore.swift`: propagate `try`; migrate obsolete save-error callbacks coherently.
- `BASAppleAdapters/AppleCurrentBrainLifecycleCore.swift`, `AppleCurrentBrainHostLifecycleRuntimeCore.swift`, `AppleCurrentBrainHostSupportCore.swift`: propagate through the existing throwing chain, never build/publish current brain after failure.

Create `BehavioralAISubstrate/Sources/BASAppleLifecycleKit/AppleCurrentBrainPersistenceTransactionCore.swift` only for the small shared transaction/IO boundary below, not a generic persistence framework.

Modify existing tests under `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/`:

- `BASAppleCurrentBrainUpdateWriterTests.swift`
- `BASAppleEvolutionCheckpointWriterTests.swift`
- `BASAppleCurrentBrainCommitterTests.swift`
- `BASAppleCurrentBrainBootstrapTests.swift`
- `BASAppleCurrentBrainHostLifecycleRuntimeTests.swift`

Additional strictly necessary caller changes require recording the exact reference first; do not change similarly named projection/lifecycle APIs without a real call edge. Search all repository Swift callers before final build. Do not touch Task 11's files, manifests, entitlements, real stores or CI.

### Interfaces and rulings

- Keep entity protocols and generic result type parameters to identify schema types and preserve inference. Change `orderedUpdates` to `[BASCurrentBrainUpdateStoredFields]` and `orderedCheckpoints` to `[BASEvolutionCheckpointStoredFields]`. These are values, never live private-context models. Mark immutable where currently appropriate; no fake `basSnapshot` compatibility property.
- Make all writer and committer entry points `throws`. Remove the old optional save-error callbacks and their actual forwarding arguments; errors travel through existing throwing host methods. One atomic save cannot truthfully attribute failure to either half of the old two-save callback interface.
- Public `in context: ModelContext` remains a container selection, explicitly documented as committed-store input: its pending entities are neither included, saved nor rolled back. Callers that intend additional edits to participate must explicitly save them first; this method never does so implicitly.
- Scope combined atomicity to a single standard SwiftData store. Reject an observed multiple/empty standard configuration before staging; document that custom/mixed stores and external concurrent writers are not qualified by this slice. Do not infer hardware/crash guarantees from one `save()` return.
- Stage methods remain internal; public standalone writers own/save their own context, while combined commit calls the internal stages directly. Do not nest public writers or `transaction` calls and accidentally restore two-save behavior.
- Use a small internal typed IO seam for deterministic read/save faults. It delegates to actual SwiftData in production, has no global mutable test switch and is never a public bypass. For example:

```swift
protocol BASAppleCurrentBrainPersistenceIO {
    func fetch<Model: PersistentModel>(
        _ type: Model.Type, in context: ModelContext
    ) throws -> [Model]
    func save(_ context: ModelContext) throws
}

struct BASAppleCurrentBrainLivePersistenceIO: BASAppleCurrentBrainPersistenceIO {
    func fetch<Model: PersistentModel>(
        _ type: Model.Type, in context: ModelContext
    ) throws -> [Model] {
        try context.fetch(FetchDescriptor<Model>())
    }
    func save(_ context: ModelContext) throws { try context.save() }
}
```

- Owned execution follows this shape; define its concrete error and apply its standard-store restriction in the implementation. The result must contain only values:

```swift
let owned = ModelContext(caller.container)
owned.autosaveEnabled = false
do {
    let receipt = try stage(in: owned)
    if owned.hasChanges { try io.save(owned) }
    return receipt
} catch {
    owned.rollback() // Only this operation's private context.
    throw error      // No success receipt, retry or caller rollback.
}
```

- A thrown underlying save is not proof that durable storage is unchanged under every possible hardware fault. Tests assert absence only for deterministic pre-save faults or actual inspected reopened stores. Never automatically replay an uncertain result.

### Implementation and verification steps

- [x] **1. Preserve baseline source identities and write behavioral RED tests.** Reuse the existing nested fixture entities. For a successful isolated writer, insert an unrelated pending fixture in the caller context with `autosaveEnabled = false`, call the current public writer, then read through a fresh context. Old behavior wrongly saves that unrelated row; new behavior must leave it pending only in the caller. For combined atomicity, use a disposable file store plus deterministic IO failure at the update fetch after checkpoint staging. Before the IO seam exists, distinguish compilation RED from behavioral RED; do not call missing-symbol failures an exercised durability control.

```swift
@Test("writer does not commit an unrelated caller insert")
func writerDoesNotCommitCallerInsert() throws {
    func fields(_ label: String) -> BASCurrentBrainUpdateStoredFields {
        BASCurrentBrainUpdateStoredFields(
            id: UUID(), createdAt: Date(timeIntervalSince1970: 1_744_000_000),
            source: label, mode: "primary", dominantGoal: label,
            dominantReactionWeight: "brief_language", fingerprint: label,
            activeConstraints: [], activeTemplateIDs: [], failureGuardIDs: []
        )
    }
    let container = try ModelContainer(
        for: UpdateWriterFixture.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let caller = ModelContext(container)
    caller.autosaveEnabled = false
    let pending = UpdateWriterFixture(fields: fields("pending"))
    let committedFields = fields("committed")
    caller.insert(pending)
    let _: BASAppleCurrentBrainUpdateWriteResult<UpdateWriterFixture> =
        try BASAppleCurrentBrainUpdateWriter.persist(committedFields, in: caller)
    let independent = ModelContext(container)
    let stored = try independent.fetch(FetchDescriptor<UpdateWriterFixture>())
    #expect(stored.map(\.id) == [committedFields.id])
    #expect(caller.insertedModelsArray.contains { $0 === pending })
}
```

- [x] **2. Run only the new failing methods against unchanged production first.** Use the maintained Swift Testing filter and retained scratch. Capture real child exit status with pipefail if tee is used. Expect the unrelated-pending row to be incorrectly persisted; preserve raw logs even if unexpected setup/compiler diagnostics occur. Do not modify a real database or file mode to force failure.
- [x] **3. Implement the shared typed IO/owned context, strict standalone writers and no-save stages.** Replace all writer `try? fetch` and caught-save success fallthroughs. Apply to both lineage overloads, approval, revocation, dedup and no-target cases. No-op returns are allowed only after a successful authoritative fetch; no-op paths must not save unrelated edits. Existing transform/matching/retention algorithms remain unchanged.
- [x] **4. Implement combined commit and migrate callers/results together.** Stage checkpoint, calculate its value-derived evolution state, stage update in the same context, save once, then return. Use `try BASAppleCurrentBrainCommitter.commit(...)` in the runtime coordinator. Remove obsolete callback forwarding all the way through host support. Adapt test assertions on returned snapshots directly (`.id`, not `.basSnapshot.id`), while actual fetched fixture entities still use `basSnapshot`.
- [x] **5. Run and retain focused fault tests.** Use a test IO implementation that records fetch order/context identity/save count and delegates successes to real SwiftData. Cover each of: update fetch failure; checkpoint fetch failure; update fetch failure after checkpoint staging; sole save failure after both stages; standalone update/save failure; record and mutation/revocation save failure; failed read on would-be dedup/no-target; one successful combined save containing both types; immutable old receipt after later same-ID replacement; original caller pending insert/update/delete unaffected on success and failure. No fake store should return unconditional success or suppress real errors.

```swift
enum FixtureFault: Error { case fetch, save }
final class FaultIO: BASAppleCurrentBrainPersistenceIO {
    var failFetch: ((Any.Type) -> Bool)?
    var failSave = false
    var saveCallCount = 0
    var contexts: [ModelContext] = []

    func fetch<Model: PersistentModel>(
        _ type: Model.Type, in context: ModelContext
    ) throws -> [Model] {
        contexts.append(context)
        if failFetch?(type) == true { throw FixtureFault.fetch }
        return try context.fetch(FetchDescriptor<Model>())
    }
    func save(_ context: ModelContext) throws {
        contexts.append(context)
        saveCallCount += 1
        if failSave { throw FixtureFault.save }
        try context.save()
    }
}
```

Expose internal (not public) overloads of `persist`, `record`, the mutation paths,
and `commit` with an additional `using io: some BASAppleCurrentBrainPersistenceIO`
argument and otherwise the same defaults/result types. Public entry points call
these using `BASAppleCurrentBrainLivePersistenceIO()`. In combined-commit tests,
set `failFetch = { $0 == CommitterUpdateFixture.self }`; assert thrown
`FixtureFault.fetch`, zero save calls, and no checkpoint or update visible after
reopen. For the save fault set only `failSave = true`, assert one attempted save
and no committed half. On success assert one save and that every observed context
is identical and different from the supplied caller. This seam does not change
the supported public authority surface.

- [x] **6. Add actual file-backed save/reopen and host failure controls.** Run a successful pair and inspect both after close/reopen. Attempt a real read-only `ModelConfiguration(allowsSave: false)` fixture save if the framework returns a catchable error; preserve its exact behavior, do not label a seam fault an actual framework failure. Propagate a failing commit through the actual bootstrap/host chain and prove `buildCurrentBrain` was not called. Existing preparation callbacks are not rolled back by this storage transaction and must not be described as covered. A deterministic seam must not be exposed as a new public production authority surface merely to make a host test convenient.
- [x] **7. Run the covering native suite once after the final focused changes.** With Task 11 finished and scratch ownership released:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
swift test --package-path BehavioralAISubstrate --build-system native \
  --scratch-path /private/tmp/qinao-bas-native-test-1329bde3 \
  --filter 'BASAppleCurrentBrainUpdateWriterTests|BASAppleEvolutionCheckpointWriterTests|BASAppleCurrentBrainCommitterTests|BASAppleCurrentBrainBootstrapTests|BASAppleCurrentBrainHostLifecycleRuntimeTests'
```

Preserve existing retained native environment if required; don't invent a new MLX path or run models. Record platform/selection/skip counts. Source compatibility is also checked by compilation of the test target; search all actual callbacks/references afterwards. Existing retention file-reopen tests remain controls, not abrupt-kill evidence.

- [x] **8. Freeze one review candidate and get an independent scoped review.** Include exact source diff, file identities, changed-path RED/GREEN, raw logs, actual commands/terminal status, warnings, migration consequences and unverified limits. Reviewer checks the three writers, actual forwarding chain and specified fault controls, not a new general scan. Fix only reviewed defects and re-review the delta.
- [ ] **9. Commit reviewed code, this plan and a short evidence record.** Stage only Task 15 owned files; run staged diff check with hooks intact. Root commits after actual verification and review. Leave the old large solo-plan draft and unrelated edits alone. Record this partial repair in the recovery checkpoint; retain both broad finding rows open until their remaining consumer/durable-recovery paths are implemented and verified.

## Plan self-review

Choices 2A/3A are covered only for the checkpoint/current-brain ownership boundary, including their direct host consumers. Choice 12A's abrupt restart, routed-intent journal, minimum-lifetime universal coverage and permanent side chat are explicitly outside this bounded deliverable. Existing approved design already permits this API migration; no repeated user choice is required. Apple SDK declarations confirm `container`, `configurations`, `autosaveEnabled`, `save`, `rollback` and `allowsSave` exist; they do not prove crash atomicity. The documentation website's Markdown fetch failed during this preparation, so no new semantic guarantee is claimed from that fetch.
