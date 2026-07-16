# iPhone Air Sovereign Release and Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. The convergence master's `W0...W6` order overrides numeric task order in this domain plan; inside an activated work package, follow each task's checkbox steps in order.

**Goal:** Close the exact/provisional response release boundary and implement durable K4 authorization, signer custody, L13 prepare/commit, and Zone-C external-effect recovery without replacing the existing sovereign audit chain or pretending cross-process exactly-once.

**Architecture:** Extend the current L9 frontier, L12 rendered output, L10 verification, L11 risk, provider release gate, `BASSovereignTokenAuthority`, fingerprint store, SQLite audit storage, `BASEventLog`, and `BASToolDispatcher` payloads in place. Add only the missing Artifact-Mesh response spool/publication journal, algorithm-agile trust root, extension-private durable lifecycle behind the existing token authority, K3 lifecycle columns/tables inside the one existing event-log SQLite control nucleus, and one Zone-C effect saga. The same K3 nucleus also installs and atomically spends Contracts' `BASBudgetLeasePayload` through its narrow `BASBudgetLeaseControlPort`; this is an E extension of the existing writer, not another budget store or sovereign spend path. `QinaoRuntime.execute` remains the sole public SDK effect facade but becomes a thin client of the durable broker; its actor-local replay set and direct closure cease to be authority. The iOS 27 Enhanced Security extension is a real process adapter around that same K4 authority and communicates with public `ExtensionFoundation`/`XPCSession` using `BASFrameEnvelope`; it is not a second sovereign service or transport protocol.

**Tech Stack:** Swift 6, SwiftPM, SQLite/WAL with read-back-asserted `synchronous=FULL` at K3/K4/Zone C, Crypto/CryptoKit, Security/Keychain, Secure Enclave P-256 where supported, bounded Codable/XPC through an iOS 27 Enhanced Security extension, XCTest and crash/power-loss injection.

## Global Constraints

- The machine-readable authority contract is `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json`. Before and after every task run `python3 /Users/changgeng/Project/Project06/Project06/scripts/check_qinao_owner_ledger.py --root /Users/changgeng/Project/Project06/Project06 --ledger /Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json`; no implementation may create an `M` owner absent from its create allowlist.
- Before the RED step for every file marked `Create [M]` (including storage/schema files under the same owner), generate one ephemeral candidate manifest using exact fields `schema_version`, `owner_id`, `classification`, `candidate_path`, `authority_symbol`, `create_proof_task`, and the eight-field `create_proof`; pass it through the same command with repeatable `--candidate-manifest`. Exact permissions are already installed for `release.spool-publication`, `trust.algorithm-agile-manifest`, `sovereign.k4-durable-lifecycle`, and `effect.zone-c-saga`; a renamed path, bundled owner, or proof-task drift fails before file creation.
- `W0`–`W6` are implementation work packages and `R0`–`R6` are per-turn retrieval waves. Neither namespace adds a semantic layer, physical kernel, control ring, or plane.
- Reuse `BASSovereignCanonicalBytes`, Ed25519 compatibility verification, `BASSovereignAuditLedger`, and `BASEventLog`.
- Reuse `BASCandidateFrontier`, `BASRenderedOutput`, current L10/L11/provider release decisions, `BASSovereignTokenAuthority`, `BASSovereignCommitToken`/`BASSovereignWarrant`, `BASSovereignFingerprintManifest`, `BASSovereignLedgerSQLiteStorage`, `BASToolInvocation`, `BASToolResult`, and `BASToolDispatcher`; legacy credentials/manifests become frozen migration projections, not parallel authorities.
- A response spool is one ordinary Artifact Mesh object derived from `BASRenderedOutput`. Verification, risk, K4, publication, sink, finalization, and replay reference its `BASArtifactID`; no payload contains its own artifact ID, digest, locator, or signature.
- Signature bytes live only in an ordinary child-attestation payload stored through the same `put → BASArtifactStoreReceipt` path. There is no special attestation store or special `putAttestation` API.
- `BASCapabilityUseReceipt` is the one durable K4 consumption payload. `issueCapability` and `claimCapability` return only the ordinary `BASArtifactStoreReceipt`; the store receipt returned by claim has a `body.artifactID` that identifies that payload. No capability-specific issuance, reservation, claim, or transport receipt exists.
- State commit intent is a typed `BASEventLogEntry` payload and derives order/integrity from `BASSQLiteEventLogStorage`; K3 lifecycle, event append/integrity/HWM, Attempt/head, semantic budget-lease install/use rows, outbox reference, staged state, activation head, projector cursor, boundary permit, and deletion epoch share its one connection, one WAL, one writer, and one atomic transaction where required. This plan creates no `BASStateCommitStore`, second budget store, second database, second event cursor, second WAL, or second integrity chain.
- K3, the publication journal, helper-private K4, and Zone C are four deliberately independent local durability/failure domains with non-overlapping write authority. Each production handle sets `journal_mode=WAL`, sets `synchronous=FULL`, reads both pragmas back, and fails closed if the effective values differ; no transaction crosses those domains. Coordinator order plus stable typed evidence closes gaps conservatively—it is never described as one distributed transaction.
- Publication, K4, K3, and Zone-C tables may use operation-local compare-and-set revisions for crash recovery, but those values are never exposed as event sequence/time/integrity; auditable ordering is emitted only through `BASEventLogEntry` and replays only through the existing event-log storage.
- Current Ed25519 seed custody is Keychain `ThisDeviceOnly`, not non-exportable hardware custody.
- Unknown signature suite, downgrade, missing historical key, ledger rollback/corruption, or migration failure enters quarantine.
- L14 semantic core decides admission/authorization/revocation/seal. K4 only signs and persists issuance/reserve/claim/spend/seal mechanics.
- Provisional bytes are hash-chained, verified, UI-only, and incapable of tool, state, evolution, or exact-release use.
- Exact bytes follow L12 spool → L10 verify → L11 risk/confirmation → L14 exact digest authorization → L12 release.
- `BASStatePreparePayload` precedes dispatch and cannot guess provider result or new state identity. `BASStateCommitEventPayload` follows a terminal/indeterminate effect-receipt artifact.
- There is no cross-process transaction between K4 and Zone C and no general exactly-once external-effect promise.
- Every sink/transport/adapter crossing uses one common fence: K3 writes a non-usable pending permit and commits its EventLog source root; K4 revalidates the exact `BASTurnOperationRef`/`BASTurnBranchRef`, claim, epochs, ceiling, and root and stores one `BASBoundaryAnchorReceipt`; K3 alone CAS-arms that same permit and emits `BASBoundaryArmReceipt`; only the exact permit/anchor/arm tuple may cross once. Anchor or arm uncertainty is query/reconcile/finalize-only and never authorizes a replacement permit, sibling branch, or blind call.
- Irreversible non-queryable effects are never automatically retried after an ambiguous dispatch boundary.
- `QinaoRuntime.execute` is the only public SDK facade for external effects. It forwards the K3-installed `BASTurnOperationRef` and its exact `BASTurnBranchRef.effect[ordinal]` to the Zone-C broker, never invokes `ToolExecutor` directly in production, and owns no replay/claim/retry truth. Any legacy `operationID` is only versioned framing over Contracts' `effectBranchRef.canonicalLegacyProjection()` plus the K3-owned `effectBoundaryInstanceID`; decode must use `BASTurnBranchRef.init(validatingCanonicalLegacyProjection:)` and equality-check the expected parent/branch/instance before adapter use, and the string is never accepted as authority. `BASToolDispatcher` is mechanism behind a broker adapter only.
- No code may emit `.executed`, `succeeded`, or an equivalent success receipt without a durable receipt from the actual actuator/provider. Until the broker path is wired, a command with no actuator evidence is `.skipped` or `.blocked` with a stable reason code.
- State remains invisible until a matching terminal seal is durable.
- K3's reducer vocabulary is exactly prepare/stage/seal/activate (the outbox reference is persisted by prepare). Zone C's reducer vocabulary is exactly dispatch/ack/indeterminate/reconcile; compensation is a separately authorized effect saga using those same four transitions. Their reducers and schemas reject cross-domain transitions.
- CryptoKit/Security/Keychain/Secure Enclave own algorithms and custody; SQLite owns transactions/WAL; public `ExtensionFoundation.AppExtensionPoint`, `AppExtensionProcess`, `XPCSession`, `ConnectionHandler`, and `XPCPeerHandler` own extension discovery and IPC. Do not implement crypto, WAL, sockets, private Mach IPC, a daemon, or an in-process release fallback.
- Consume `BASArtifactID`, `BASArtifactStorePort`, `BASArtifactStoreReceipt`, `BASArtifactAttestationPayload`, `BASCapabilityGrant`, the self-ID-free `BASCapabilityUseReceipt`, `BASTurnOperationRef`, and `BASTurnBranchRef` exactly from `2026-07-15-iphone-air-contracts-layercell.md`; do not redeclare or rename them. The capability lifecycle API remains exactly `issueCapability`, `reserveCapability`, `claimCapability`, and `lookupCapabilityUseReceipt`. Task 3 extends that same K4 authority with only the two generic boundary operations `claimAndAnchorBoundary` and `anchorClaimedBoundary`; no publication-, stream-, Provider-, or effect-specific K4 API is allowed.
- Enhanced Security IPC carries one adapter command body in the existing `BASFrameEnvelope` and one adapter result body in the existing `BASResult`; do not create `BASK4TransportContracts`, another frame/result envelope, a socket protocol, or a helper-side authority facade.

## Reuse Ledger and Approved Missing Owners

| Work | Class | Canonical owner and convergence rule |
|---|---|---|
| candidate/render/verify/risk/release | E | extend `BASCandidateFrontier`, `BASRenderedOutput`, `BASExecutionGovernance`/`BASProviderReleaseGate`, and current L10/L11 owners; only durable spool/publication is M |
| signing/trust | E/A/M | keep Ed25519 and `BASSovereignFingerprintManifest` v1 readable; add one algorithm-agile trust manifest and optional Secure Enclave P-256 signer; signatures remain Artifact Mesh child attestations |
| authorization | E/M | `BASSovereignTokenAuthority` remains the only mint/reserve/claim/spend owner; extend `BASSovereignLedgerSQLiteStorage` and migrate SQL 009 instead of creating another token service/store |
| state commit | E | extend `BASSQLiteEventLogStorage` into the sole K3 control nucleus; one database/connection/WAL/writer/transaction owns event + invisible stage/seal/activate lifecycle, while a new protocol is only a port |
| external effects | E/A/M | retain `QinaoRuntime.execute` as the public facade, reuse `BASToolInvocation`/`BASToolResult`/`BASToolDispatcher` as payload/mechanism, and add one Zone-C saga as the only durable dispatch/recovery owner |
| extension process | A | public Enhanced Security extension/XPC adapts the same authority; `BASFrameEnvelope` is the transport envelope and the release build has no in-process K4 path |

Every task below records the repository search, Apple/upstream primitive, missing invariant, authority/storage/recovery owner, dependency direction, compatibility/retirement path, and duplicate-authority test before its red test. An incomplete `M` proof defaults to `E` or `A`.

### Exact OwnerLedger M Permissions

The four rows below are the only production `M` responsibilities consumed by this plan. Every created production file gets its own ephemeral candidate manifest; `owner_id`, `authority_symbol`, `create_proof_task`, and `candidate_path` must byte-match this table and `qinao-owner-ledger-v1.json`. A schema/storage file shares its logical owner row but still requires its own exact-path manifest.

| `owner_id` | `authority_symbol` | `create_proof_task` | Exact allowed `candidate_path` values |
|---|---|---|---|
| `release.spool-publication` | `BASResponseReleaseCoordinator` | `sovereign-release-effects:Task 1` | `BehavioralAISubstrate/Sources/BASHostKit/BASResponseReleaseCoordinator.swift`; `BehavioralAISubstrate/Sources/BASMemory/BASPublicationJournalSQLiteStorage.swift`; `BehavioralAISubstrate/Sources/BASMemory/SQL/028_response_publication.sql`; `BehavioralAISubstrate/Sources/BASRuntimeCore/BASResponsePublicationContracts.swift` |
| `trust.algorithm-agile-manifest` | `BASSovereignTrustManifestPayload` | `sovereign-release-effects:Task 2` | `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignTrustManifest.swift` |
| `sovereign.k4-durable-lifecycle` | `BASSovereignTokenAuthority` | `sovereign-release-effects:Task 3` | `BehavioralAISubstrate/Sources/BASSovereign/SQL/014_sovereign_capability_lifecycle.sql` |
| `effect.zone-c-saga` | `BASEffectBroker` | `sovereign-release-effects:Task 5` | `BehavioralAISubstrate/Sources/BASEffectBroker/BASEffectBroker.swift`; `BehavioralAISubstrate/Sources/BASEffectBroker/BASEffectBrokerSQLiteStorage.swift`; `BehavioralAISubstrate/Sources/BASEffectBroker/SQL/001_effect_saga_v1.sql` |

Each manifest uses exactly the seven top-level fields `schema_version`, `owner_id`, `classification`, `candidate_path`, `authority_symbol`, `create_proof_task`, and `create_proof`; the nested proof uses exactly `repository_search`, `public_primitive`, `missing_invariant`, `extension_insufficient`, `single_owner`, `dependency_direction`, `compatibility_retirement`, and `verification`. Use `schema_version: 1` and `classification: M`. Candidate manifests are temporary evidence, not another committed allowlist or policy source.

The OwnerLedger is also a modified/staged file in Tasks 1, 2, 3, and 5. In the same review unit that creates the first allowlisted path, append that exact workspace-relative path to the matching OwnerCard `evidence_paths`, change only its status from `approved_missing` to `converging`, and immediately rerun the checker; append every later created path to that same evidence list in its creation change. Before `implemented`, every allowlisted path must exist and appear in evidence, every task-local test/source/crash/retirement gate must pass, and `current_conflicts` must be exactly empty. Remove a conflict only in the same review unit as the exact source/retirement evidence that makes it false; if a compatibility view genuinely survives, move it to `allowed_projections` only after tests prove `authority == false`, `mutable == false`, rebuildability, and its source-watermark rule. Then change `converging` to `implemented`, rerun both checker suites, and stage the ledger. Classification, owner ID, authority symbol, permission paths, and work package never change. A failed/partial task remains `converging`; an early `implemented`, a created path missing from evidence, or an implemented owner with any unresolved conflict is forbidden.

### Persisted Payload Schema Closure

Every self-ID-free payload ordinary-put through Artifact Mesh is a real persisted contract: it conforms to `BASSchemaVersioned`, carries `schemaVersion`, uses `currentSchemaVersion = "1.0.0"`, bounded-decodes only a supported version, and is registered exactly once in the existing `BASEBrainSchemaGovernanceRegistry`. This plan adds no registry, schema manager, version map, or owner. The exact governed set is:

| Task | Independently persisted Artifact Mesh payloads |
|---|---|
| 1 | `BASResponseSpoolPayload`, `BASExactOutputVerificationPayload`, `BASChunkVerificationReceiptPayload`, `BASProvisionalDisplayReceiptPayload`, `BASExactReleasePreparationPayload`, `BASExactReleaseSinkReceiptPayload` |
| 2 | `BASSovereignTrustManifestPayload` |
| 3 | none; it consumes Contracts Task 2A's already-governed `BASBoundaryAnchorReceipt`/`BASBoundaryArmReceipt` and implements their port |
| 4 | `BASEffectCausalPredecessorPayload`, `BASStatePreparePayload`, `BASStateEffectOutboxPayload`, `BASStateCommitEventPayload`, `BASEffectDispatchReadyReceiptPayload`, `BASEffectReceiptPayload`, `BASProviderEgressBoundaryPermit`, `BASPublicationBoundaryPermit`, `BASStreamBatchBoundaryPermit`, `BASEffectBoundaryPermit` |
| 5 | `BASPersistedToolResultPayload` |

Embedded entries/bindings/enums, transient requests, `BASK3ActivatedStateEvidence`, `BASK3BoundarySourceCommit`, ports, adapters, and return-only projections are not registered separately; their persisted parent owns their wire version. Publication/K3/K4/Zone-C SQL rows are governed by their one numbered migration and explicit row-schema column, not double-registered as Artifact payloads. For types visible through BASAdmin's existing dependencies, use the existing metatype registry entry. `BASEffectBroker` must not become a BASAdmin dependency solely for governance; the BASOrgan-owned `BASPersistedToolResultPayload` uses Contracts Task 5's sole cycle-free `pinnedEntry`, and its owner-target test compares the pinned version to the type constant. Task 4's dispatch/effect receipts live in RuntimeCore and use normal metatype entries; the broker only produces them. Tasks 1, 2, 4, and 5 modify the existing registry/test; Task 3 consumes Contracts' exact-one boundary entries and asserts no duplicate. For every governed type, assert exact-one object ID and migration-test IDs, current encode/decode, a pinned backward fixture, and unknown-future-version rejection. Production enablement waits for those tests; a bare `Codable` ordinary-put is a gate failure.

The stored-shape declarations below are normative for conformance, version constants, and every persisted domain field; to avoid repeating hundreds of mechanical assignments, most blocks elide only the explicit public initializer body. The implementation still supplies that initializer with `schemaVersion: String = Self.currentSchemaVersion` first, and a cross-target compile fixture constructs every type—synthesized internal memberwise initialization cannot satisfy the gate. At the 1.0 launch, writes and reads use Contracts' sole `BASGovernedArtifactPayloadCodec`, whose accepted persisted-version set is exactly `{ "1.0.0" }` and which rejects a missing/different version before returning any value to a reducer. The pinned 1.0 canonical-byte fixture is the first backward-compatibility anchor; later versions require an explicit migration, registry IDs, and byte fixtures in the same review. Raw `JSONDecoder` use for a governed Artifact payload is forbidden.

## Work-Package Schedule

| Master package | This plan's executable slice | Gate |
|---|---|---|
| W0 | Task 0 safety freeze | false success and direct effect paths are unreachable; the facade may remain intentionally fail-closed until W5 |
| W2 | Task 4 K3 control-nucleus extension only | one `FULL` database/connection/WAL/writer atomically owns event, budget-lease CAS, and lifecycle; no sibling state-commit or budget store |
| W5 | Tasks 2, 3, 1, 5, and 6, in that dependency order | trust and generic boundary contracts, helper-private K4, spool/publication, independent Zone C, public facade cutover, and Enhanced Security boundary all close |
| W6 | consume the three-run closure and physical-device evidence | no legacy direct path, second truth, synthetic success, or runtime-selectable fallback survives |

Tasks 1–3 must not be production-enabled before Task 4's W2 gate even though they appear earlier for release-flow readability. Task 4 is cross-wave only in implementation, not in type dependency: Contracts Task 2A already supplies the generic boundary request/receipts/port; Task 4 declares all K3 permit/dispatch-ready values and compiles/tests the K3 state machine using a deterministic test-only anchoring conformer, while no production boundary caller/K4 implementation exists in W2. Within W5, execute Task 2 → Task 3 → Task 1 → Task 5 → Task 6; those tasks compose the already-compiled K3 methods with the real K4, release coordinator, and broker but do not introduce a later type that W2 source must import. W0 completes when unsafe production paths are frozen and the tests pass; Task 5 later restores effect functionality only through the durable broker.

---

### Task 0: W0 Safety Freeze Before Any New Authority Path

**Files:**
- Modify [E — honest projection only]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+SovereignCommit.swift`
- Modify [E — public facade, production implementation later in Task 5]: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift`
- Modify [E — dispatcher becomes broker-only mechanism]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrgan/BASToolDispatcher.swift`
- Create [test]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSyntheticExecutionReceiptFreezeTests.swift`
- Create [test]: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeTests/QinaoEffectFacadeFreezeTests.swift`

**Reuse Decision: E only; no new owner in W0**

**Observed production gaps at baseline `659e46576`:**

- `EBrainRuntimeCoordinator+SovereignCommit.swift:1794-1813` maps every command to `.executed` without calling an actuator; the comment asserts actuation but the function has no receipt input.
- `QinaoRuntime.swift:145-149,255-279` treats actor-local `consumedBundles` as replay truth and invokes `toolExecutor` directly after its last halt check.
- `BASToolDispatcher` can invoke its handler without the durable Zone-C claim/dispatch journal that Task 5 introduces.

- [ ] **Step 1: Write RED tests for the two forbidden successes**

```swift
func testNoActuatorEvidenceCannotProduceExecutedReceipt() throws {
    let receipts = BASEBrainRuntimeCoordinator.buildSovereignExecutionReceipts(
        sovereignActuationCommands: [fixtureCommand()],
        runtimeTrace: fixtureTrace()
    )
    XCTAssertEqual(receipts.map(\.status), [.skipped])
    XCTAssertTrue(receipts[0].reasonCodes.contains("actuator-evidence-unavailable"))
}

func testPublicEffectFacadeCannotReachLegacyClosureWithoutBrokerReceipt() async {
    let fixture = makeRuntimeWithLegacyExecutorSpyAndNoBroker()
    await XCTAssertThrowsErrorAsync {
        _ = try await fixture.runtime.execute(
            toolName: "calendar.write",
            payload: Data(),
            intent: fixture.intent,
            signatures: fixture.signatures
        )
    }
    XCTAssertEqual(fixture.legacyExecutorCallCount, 0)
}
```

- [ ] **Step 2: Apply the reversible freeze and prove no false claim remains**

Change the no-actuator projection to `.skipped` with `actuator-evidence-unavailable`; do not rename `.executed` or weaken its meaning. Mark the direct `ToolExecutor` initializer/path and direct dispatcher entry as explicit test/legacy-only, unavailable to the iOS 27 release composition. The public `QinaoRuntime.execute` signature remains stable but production composition fails closed until Task 5 injects `QinaoEffectExecuting`. This is a temporary freeze, not a second broker or receipt type.

```bash
python3 /Users/changgeng/Project/Project06/Project06/scripts/check_qinao_owner_ledger.py --root /Users/changgeng/Project/Project06/Project06 --ledger /Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter BASSyntheticExecutionReceiptFreezeTests
swift test --package-path /Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK --filter QinaoEffectFacadeFreezeTests
```

Expected: no path without actuator/provider evidence emits success; no release composition can call the closure or dispatcher directly. Do not begin `W1`–`W6` while this gate is red. W0 may complete with the effect facade deliberately fail-closed; Task 5 is the only authorized route for restoring production effect execution.

---

### Task 1: Converge Existing Release Owners onto One Spool and Publication Journal

**Files:**
- Modify [ownership lifecycle]: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify [schema governance]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Modify [schema governance tests]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`
- Modify [E]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/EBrainL3L12RenderingCore.swift`
- Modify [E]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/ExecutionGovernanceCore.swift`
- Modify [E]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/ProviderReleaseCore.swift`
- Modify [E]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASPolicy/EBrainRiskPlaneCore.swift`
- Create [M — spool/publication contracts]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASResponsePublicationContracts.swift`
- Create [M — sole publication state owner]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASPublicationJournalSQLiteStorage.swift`
- Create [schema for the same M owner]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/SQL/028_response_publication.sql`
- Create [M — missing release orchestration seam]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASResponseReleaseCoordinator.swift`
- Create [test]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASResponseReleaseOrderingTests.swift`

**Reuse Decision: E + M**

**Create Proof (production M — exactly eight gates):**

1. Repository search and existing candidates: run `rg -n 'BASCandidateFrontier|BASRenderedOutput|BASProviderReleaseGate|releaseDecision|publication|spool' BehavioralAISubstrate/Sources`; extend those decision owners and the prerequisite Artifact Mesh.
2. Apple/public/upstream primitives: SQLite transactions plus the existing Artifact Mesh provide storage, CAS, and recovery mechanisms; no object store, visibility cache, UI scheduler, or transaction framework is missing.
3. Absent invariant: the repository has no immutable response-spool artifact paired with one typed final-publication branch, durable reservation/finalization journal, and K3-pending → K4-anchor → K3-arm sink fence with lost-reply lookup.
4. Why E/composition/generics/A is insufficient: L9/L10/L11/L12 and provider-release owners decide or project bytes but own no durable publication state; `BASResult`, `BASFrameEnvelope`, composition, and a thin sink adapter cannot recover a crash between visible sink commit and reply.
5. Single authority/state/storage/failure boundary: current decision owners remain authoritative; Artifact Mesh alone stores spool bytes; the one publication journal owns only reservation/finalization/indeterminate recovery; the existing K3 control nucleus alone owns publication `prepared`, `publication_permit_pending`, and arm CAS; K4 alone claims/anchors; the sink alone owns external visibility. Conflicting rows, corrupt bindings, or missing sink evidence fail closed.
6. Dependency/no-second-truth proof: the coordinator is the existing HostKit release seam: `BASHostKit` coordinator → current decision owners → Artifact Mesh/publication journal → outer sink. The runtime plan—not this coordinator, K4, `BASSovereign`, `BASRuntimeCore`, the journal, or the sink—owns the outer process-memory publication scope, so no sovereign contract gains a ledger, admission-context, activation-token, or raw-cap dependency. No dependency points back to HostKit, and neither payloads nor the event log duplicate publication truth.
7. Compatibility/retirement: current `BASRenderedOutput` and provider gate remain public; legacy direct visibility is explicit V1 rollback/test-only after authoritative cutover and retires after release-cohort and crash-recovery gates.
8. Mutation/crash/replay/duplicate-authority tests: mutate every artifact/root/Attempt/generation/epoch/typed-branch/permit/anchor/arm binding, crash before/after every K3/K4/journal/sink boundary, replay the one key derived from final-publication branch + boundary instance + manifest, recover the one finalized row by replay-manifest artifact ID, and fail if a payload owns a spool identity, two rows bind one manifest, two journals reserve one key, a sink receives anything without the exact arm tuple, a sink displays twice, or provisional evidence authorizes exact/effect/state work.

**Interfaces:**

- Consumes: current `BASCandidateFrontier`, `BASRenderedOutput`, L10/L11 decisions, `BASProviderReleaseGate`, `BASArtifactStorePort`, canonical `BASTurnOperationRef`/`BASTurnBranchRef`, Task 4's one `BASK3ControlNucleusStorage` boundary port, Task 3's `BASSovereignBoundaryAnchoring`, and an injected stateless manifest-request resolver closure supplied after the runtime manifest contract exists. It deliberately consumes no `BASProcessMemoryLedger`, `BASMemoryAdmissionContext`, `BASMemoryReservationToken`, or `BASMemoryActivationToken`; the authoritative runtime holds that outer scope.
- Produces: a response spool rooted in the canonical turn, the sole non-authoritative four-ID `BASProviderReleaseEvidenceReference` declared in `BASResponsePublicationContracts.swift`, private journal storage with read-only `lookup(replayManifestArtifactID:)`, `BASPublicationFinalization`, `BASResponseReleaseCoordinator.publishExact(after:spoolArtifactID:) async throws -> BASPublicationFinalization`, and its sole public read-only recovery view `finalizedPublicationRecord(for:) async throws -> BASPublicationRecord`. Runtime receives the coordinator, never the journal. It creates no second boundary owner: pending/arm stay in K3 and claim/anchor stay in K4. Silicon and runtime may carry this exact reference group but cannot redeclare it or copy the Provider lineage it addresses.

- [ ] **Step 1: Write failing ordering and isolation tests**

```swift
func testResponseSpoolPayloadDoesNotOwnArtifactIdentity() throws {
    let data = try JSONEncoder().encode(fixtureSpoolPayload())
    let keys = Set(try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]).keys)
    XCTAssertTrue(keys.isDisjoint(with: [
        "spoolID", "artifactID", "digest", "signature", "storageLocator",
        "providerVisibilityReceiptArtifactID", "throughVisibilityProviderBranchChainArtifactID"
    ]))
}

func testProviderReleaseEvidenceReferenceContainsOnlyCanonicalArtifactIDs() throws {
    let encoded = try JSONEncoder().encode(fixtureProviderReleaseEvidenceReference())
    let keys = Set(
        try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any]).keys
    )
    XCTAssertEqual(keys, [
        "terminalPrefixProviderBranchChainArtifactID",
        "throughVisibilityProviderBranchChainArtifactID",
        "spoolArtifactID",
        "releasePreparationArtifactID"
    ])
}

func testResponseSpoolBindsSelectedProviderAndUniqueReleaseBranchesToOneRoot() throws {
    let spool = fixtureSpoolPayload(selectedProviderRequestOrdinal: 3)
    XCTAssertEqual(spool.terminalAnswerSourceProviderEgressBranchRef.kind, .providerEgress)
    XCTAssertEqual(spool.terminalAnswerSourceProviderEgressBranchRef.ordinal, 3)
    XCTAssertEqual(spool.provisionalStreamBranchRef.kind, .provisionalStream)
    XCTAssertEqual(spool.provisionalStreamBranchRef.ordinal, 0)
    XCTAssertEqual(spool.finalPublicationBranchRef.kind, .finalPublication)
    XCTAssertEqual(spool.finalPublicationBranchRef.ordinal, 0)
    XCTAssertEqual(spool.terminalAnswerSourceProviderEgressBranchRef.turnOperationRef, spool.turnOperationRef)
    XCTAssertEqual(spool.provisionalStreamBranchRef.turnOperationRef, spool.turnOperationRef)
    XCTAssertEqual(spool.finalPublicationBranchRef.turnOperationRef, spool.turnOperationRef)
    XCTAssertEqual(spool.terminalProviderExecutionRef.providerEgressBranchRef, spool.terminalAnswerSourceProviderEgressBranchRef)
    let terminalPrefix = try fixtureReopenProviderBranchChain(
        spool.terminalPrefixProviderBranchChainArtifactID
    )
    let pinnedSourceEntry = try XCTUnwrap(terminalPrefix.orderedEntries.last)
    XCTAssertEqual(spool.selectedCandidateArtifactID, pinnedSourceEntry.proposalArtifactID)
    XCTAssertEqual(
        spool.terminalSourceReceiptArtifactID,
        terminalPrefix.terminalSourceReceiptArtifactID
    )
    XCTAssertEqual(
        spool.terminalPrefixProviderBranchChainArtifactID,
        fixtureProviderBranchChainThroughTerminalSourceArtifactID()
    )
    XCTAssertThrowsError(try decodeSpool(spool.replacingTerminalSource(with: fixtureSiblingProviderBranchRef())))
    XCTAssertThrowsError(try decodeSpool(spool.replacingTerminalPrefixChain(with: fixtureRewrittenProviderBranchChainArtifactID())))
}

func testReleasePreparationPrecedesManifestAndHasNoFutureOrSelfIdentity() throws {
    let data = try JSONEncoder().encode(fixtureReleasePreparation())
    let keys = Set(try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]).keys)
    XCTAssertTrue(keys.isDisjoint(with: [
        "artifactID", "releasePreparationArtifactID", "replayManifestArtifactID",
        "idempotencyKey", "capabilityUseReceiptArtifactID", "sinkReceiptArtifactID",
        "digest", "signature", "storageLocator"
    ]))
    XCTAssertTrue(keys.contains("terminalSourceReceiptArtifactID"))
    XCTAssertTrue(keys.contains("providerVisibilityReceiptArtifactID"))
    XCTAssertTrue(keys.contains("throughVisibilityProviderBranchChainArtifactID"))
}

func testReleasePreparationAndPublicationRequestBindSameVisibilityClose() throws {
    let preparation = fixtureReleasePreparation()
    let request = fixturePublicationRequest()
    XCTAssertEqual(request.terminalSourceReceiptArtifactID, preparation.terminalSourceReceiptArtifactID)
    XCTAssertEqual(request.providerVisibilityReceiptArtifactID, preparation.providerVisibilityReceiptArtifactID)
    XCTAssertEqual(
        request.terminalPrefixProviderBranchChainArtifactID,
        preparation.terminalPrefixProviderBranchChainArtifactID
    )
    XCTAssertEqual(
        request.throughVisibilityProviderBranchChainArtifactID,
        preparation.throughVisibilityProviderBranchChainArtifactID
    )
}

func testExactReleaseRejectsCrossArtifactBinding() async throws {
    let coordinator = makeCoordinator()
    var request = fixturePublicationRequest()
    request = request.replacingVerification(with: artifactID("verification-for-another-spool"))
    await XCTAssertThrowsErrorAsync {
        _ = try await coordinator.publishExact(
            after: request.replayManifestArtifactID,
            spoolArtifactID: request.spoolArtifactID
        )
    } verify: { error in
        XCTAssertEqual(error as? BASResponseReleaseError, .artifactBindingMismatch)
    }
}

func testManifestResolverCannotRedirectOrForgePublicationBindings() async {
    for mutation in PublicationManifestResolverMutation.allCases {
        let fixture = makeCoordinatorFixture(resolverMutation: mutation)
        await XCTAssertThrowsErrorAsync {
            _ = try await fixture.coordinator.publishExact(
                after: fixture.manifestArtifactID,
                spoolArtifactID: fixture.spoolArtifactID
            )
        }
        let counts = await fixture.counters.snapshot()
        XCTAssertEqual(counts.manifestResolverCount, 1)
        XCTAssertEqual(counts.publicationReservationCount, 0)
        XCTAssertEqual(counts.k3PublicationPendingCount, 0)
        XCTAssertEqual(counts.capabilityClaimCount, 0)
        XCTAssertEqual(counts.boundaryAnchorCount, 0)
        XCTAssertEqual(counts.k3PublicationArmCount, 0)
        XCTAssertEqual(counts.sinkReleaseCount, 0)
    }
}

func testK3InstallsPreparationBeforeJournalReserveWithoutCrossStoreRead() async throws {
    let fixture = makeCoordinatorFixture(publicationJournalFailpoint: .beforeReserveCommit)
    await XCTAssertThrowsErrorAsync {
        _ = try await fixture.coordinator.publishExact(
            after: fixture.manifestArtifactID,
            spoolArtifactID: fixture.spoolArtifactID
        )
    }
    let publicationState = try await fixture.k3.publicationState(fixture.finalPublicationBranchRef)
    let counts = await fixture.counters.snapshot()
    XCTAssertEqual(counts.publicationReservationCount, 0)
    XCTAssertEqual(counts.k3PublicationPendingCount, 0)
    XCTAssertEqual(counts.boundaryAnchorCount, 0)
    XCTAssertEqual(counts.sinkReleaseCount, 0)
    let openedForeignDatabaseCount = try await fixture.k3.openedForeignDatabaseCountForTesting()
    XCTAssertEqual(publicationState, .prepared)
    XCTAssertEqual(openedForeignDatabaseCount, 0)
}

func testProvisionalReceiptCannotAuthorizeToolOrState() {
    let labels = Set(Mirror(reflecting: fixtureProvisionalDisplayReceipt()).children.compactMap(\.label))
    XCTAssertTrue(labels.isDisjoint(with: ["capabilityUseReceiptArtifactID", "effectAuthorization", "stateCommitAuthorization"]))
}

func testProvisionalPendingRequiresIncrementalVisibilityAndExactBatchVerificationReceipts() async throws {
    for mutation in StreamVisibilityEvidenceMutation.allCases {
        let fixture = try await makeIncrementalVisibilityStreamFixture(mutation: mutation)
        await XCTAssertThrowsErrorAsync {
            _ = try await fixture.k3.prepareStreamBatchBoundary(fixture.permit)
        }
        let pendingCount = await fixture.k3.streamPermitPendingCountForTesting()
        let anchorCount = await fixture.k4.boundaryAnchorCountForTesting()
        XCTAssertEqual(pendingCount, 0)
        XCTAssertEqual(anchorCount, 0)
    }
}

func testBufferedVisibilityModeCannotPrepareProvisionalBatch() async throws {
    let fixture = try await makeBufferedVisibilityStreamFixture()
    await XCTAssertThrowsErrorAsync {
        _ = try await fixture.k3.prepareStreamBatchBoundary(fixture.permit)
    }
    let pendingCount = await fixture.k3.streamPermitPendingCountForTesting()
    XCTAssertEqual(pendingCount, 0)
}

func testProvisionalBatchRequiresExactPendingAnchorArmAndContiguousRange() async throws {
    let fixture = try makeProvisionalStreamFixture(firstChunk: 8, lastChunk: 15)
    let source = try await fixture.k3.prepareStreamBatchBoundary(fixture.permit)
    let anchorStoreReceipt = try await fixture.k4.anchorClaimedBoundary(
        fixture.anchorRequest(source: source)
    )
    let anchor = try await fixture.artifacts.openBoundaryAnchor(anchorStoreReceipt.body.artifactID)
    let arm = try await fixture.k3.armBoundary(
        source: source,
        anchorReceiptArtifactID: anchorStoreReceipt.body.artifactID,
        anchor: anchor
    )
    let armStoreReceipt = try await fixture.artifacts.putBoundaryArmReceipt(arm)
    try await fixture.sink.releaseBatch(
        fixture.batch,
        permitArtifactID: source.permitArtifactID,
        anchorReceiptArtifactID: anchorStoreReceipt.body.artifactID,
        armReceiptArtifactID: armStoreReceipt.body.artifactID
    )
    let visibleRanges = await fixture.sink.visibleRanges
    let capabilityClaimCount = await fixture.k4.capabilityClaimCount
    XCTAssertEqual(visibleRanges, [8...15])
    XCTAssertEqual(capabilityClaimCount, 1) // branch claim, not per batch
}

func testProvisionalOverlapOrPostAnchorReplayNeverCallsSinkAgain() async throws {
    let fixture = try await makeAnchoredProvisionalBatchWithLostReply(range: 8...15)
    await XCTAssertThrowsErrorAsync {
        _ = try await fixture.k3.prepareStreamBatchBoundary(
            fixture.permit(replacingRange: 12...18)
        )
    }
    _ = try? await fixture.resume()
    let releaseCount = await fixture.sink.releaseCount
    let lookupCount = await fixture.sink.lookupCount
    XCTAssertEqual(releaseCount, 1)
    XCTAssertGreaterThanOrEqual(lookupCount, 1)
}

func testExactSinkLostReplyRecoversByStableIdempotencyKey() async throws {
    let sink = makeDurableSink(failpoint: .afterVisibleCommitBeforeReply)
    let coordinator = makeCoordinator(releaseSink: sink)
    let request = fixturePublicationRequest(publicationBoundaryInstanceID: "publication-1")
    let expectedKey = try BASPublicationReservationRequest.canonicalIdempotencyKey(
        finalPublicationBranchRef: request.finalPublicationBranchRef,
        publicationBoundaryInstanceID: request.publicationBoundaryInstanceID,
        replayManifestArtifactID: request.replayManifestArtifactID
    )
    XCTAssertEqual(request.idempotencyKey, expectedKey)
    do {
        _ = try await coordinator.publishExact(
            after: request.replayManifestArtifactID,
            spoolArtifactID: request.spoolArtifactID
        )
        XCTFail("injected lost reply must surface")
    } catch { }

    let recovered = try await sink.lookup(idempotencyKey: expectedKey)
    XCTAssertEqual(recovered?.spoolArtifactID, fixtureSpoolArtifactID())
    XCTAssertEqual(recovered?.destinationDigest, fixtureDestination().canonicalDestinationDigest)
    _ = try await coordinator.publishExact(
        after: request.replayManifestArtifactID,
        spoolArtifactID: request.spoolArtifactID
    )
    let visibleReleaseCount = await sink.visibleReleaseCount
    let capabilityClaimCount = try await capabilityAuthority.claimCount
    XCTAssertEqual(visibleReleaseCount, 1)
    XCTAssertEqual(capabilityClaimCount, 1)
    let permitCount = await k3.publicationPermitPendingCount
    let anchorCount = await capabilityAuthority.boundaryAnchorCount
    let armCount = await k3.publicationArmWinnerCount
    XCTAssertEqual(permitCount, 1)
    XCTAssertEqual(anchorCount, 1)
    XCTAssertEqual(armCount, 1)
}

func testCoordinatorOwnsTheOnlyReadOnlyFinalizationLookup() async throws {
    let fixture = try await makeFinalizedPublicationFixture()
    let before = await fixture.allMutationCounters.snapshot()
    let record = try await fixture.coordinator.finalizedPublicationRecord(
        for: fixture.replayManifestArtifactID
    )
    let after = await fixture.allMutationCounters.snapshot()
    XCTAssertEqual(record.state, .finalized)
    XCTAssertEqual(
        record.request.replayManifestArtifactID,
        fixture.replayManifestArtifactID
    )
    XCTAssertEqual(before, after)
    XCTAssertFalse(
        try coordinatorSource().contains("public let publicationJournal")
    )
}

func testPublicationKeyConsumesOnlyTheContractsTypedBranchCodec() throws {
    let branch = fixtureFinalPublicationBranchRef()
    let projection = try branch.canonicalLegacyProjection()
    let decoded = try BASTurnBranchRef(validatingCanonicalLegacyProjection: projection)
    XCTAssertEqual(decoded, branch)

    let key = try BASPublicationReservationRequest.canonicalIdempotencyKey(
        finalPublicationBranchRef: branch,
        publicationBoundaryInstanceID: fixturePublicationBoundaryInstanceID(),
        replayManifestArtifactID: fixtureReplayManifestArtifactID()
    )
    let siblingKey = try BASPublicationReservationRequest.canonicalIdempotencyKey(
        finalPublicationBranchRef: fixtureSiblingFinalPublicationBranchRef(),
        publicationBoundaryInstanceID: fixturePublicationBoundaryInstanceID(),
        replayManifestArtifactID: fixtureReplayManifestArtifactID()
    )
    XCTAssertNotEqual(key, siblingKey)
    XCTAssertThrowsError(
        try BASPublicationReservationRequest.canonicalIdempotencyKey(
            finalPublicationBranchRef: fixtureProviderEgressBranchRef(),
            publicationBoundaryInstanceID: fixturePublicationBoundaryInstanceID(),
            replayManifestArtifactID: fixtureReplayManifestArtifactID()
        )
    )
}

func testSinkNeverReceivesBytesBeforeExactPermitAnchorArmTuple() async throws {
    for failpoint in PublicationBoundaryFailpoint.beforeAndAfterEveryHandshakeStep {
        let fixture = makePublicationBoundaryFixture(failpoint: failpoint)
        _ = try? await fixture.coordinator.publishExact(
            after: fixture.manifestArtifactID,
            spoolArtifactID: fixture.spoolArtifactID
        )
        if await fixture.sink.releaseCount > 0 {
            let observedCall = await fixture.sink.onlyCall
            let call = try XCTUnwrap(observedCall)
            XCTAssertEqual(call.permitArtifactID, fixture.permitArtifactID)
            XCTAssertEqual(call.anchorReceiptArtifactID, fixture.anchorArtifactID)
            XCTAssertEqual(call.armReceiptArtifactID, fixture.armArtifactID)
            XCTAssertEqual(call.turnBranchRef, fixture.finalPublicationBranchRef)
        }
    }
}

func testAnchorOrArmUncertaintyIsQueryOnlyNeverSecondSinkCall() async throws {
    let fixture = try await makeAnchoredPublicationWithLostReply()
    _ = try? await fixture.coordinator.publishExact(
        after: fixture.manifestArtifactID,
        spoolArtifactID: fixture.spoolArtifactID
    )
    let lookupCount = await fixture.sink.lookupCount
    let releaseCount = await fixture.sink.releaseCount
    let permitCount = await fixture.k3.permitCount
    let anchorCount = await fixture.k4.anchorCount
    let armWinnerCount = await fixture.k3.armWinnerCount
    XCTAssertGreaterThanOrEqual(lookupCount, 1)
    XCTAssertEqual(releaseCount, 1)
    XCTAssertEqual(permitCount, 1)
    XCTAssertEqual(anchorCount, 1)
    XCTAssertEqual(armWinnerCount, 1)
}

func testFinalizedPublicationIsUniquelyRecoverableByReplayManifestArtifactID() async throws {
    let journal = try makePublicationJournal()
    let request = fixturePublicationRequest(publicationBoundaryInstanceID: "publication-by-manifest")
    let capabilityUseReceiptArtifactID = artifactID("capability-use")
    let sinkReceiptArtifactID = artifactID("sink-receipt")
    _ = try await journal.reserve(request)
    _ = try await journal.markSinkCommitted(
        idempotencyKey: request.idempotencyKey,
        capabilityUseReceiptArtifactID: capabilityUseReceiptArtifactID,
        permitArtifactID: artifactID("publication-permit"),
        boundaryAnchorReceiptArtifactID: artifactID("publication-anchor"),
        boundaryArmReceiptArtifactID: artifactID("publication-arm"),
        sinkReceiptArtifactID: sinkReceiptArtifactID
    )
    _ = try await journal.finalize(idempotencyKey: request.idempotencyKey)

    let recovered = try await journal.lookup(
        replayManifestArtifactID: request.replayManifestArtifactID
    )
    let record = try XCTUnwrap(recovered)
    XCTAssertEqual(record.request, request)
    XCTAssertEqual(record.state, .finalized)
    XCTAssertEqual(record.capabilityUseReceiptArtifactID, capabilityUseReceiptArtifactID)
    XCTAssertEqual(record.permitArtifactID, artifactID("publication-permit"))
    XCTAssertEqual(record.boundaryAnchorReceiptArtifactID, artifactID("publication-anchor"))
    XCTAssertEqual(record.boundaryArmReceiptArtifactID, artifactID("publication-arm"))
    XCTAssertEqual(record.sinkReceiptArtifactID, sinkReceiptArtifactID)

    var conflict = fixturePublicationRequest(publicationBoundaryInstanceID: "conflicting-publication")
    conflict = conflict.replacingReplayManifestArtifactID(
        request.replayManifestArtifactID
    )
    await XCTAssertThrowsErrorAsync {
        _ = try await journal.reserve(conflict)
    }
}

func testPublicationJournalIsOneIndependentFullRecoveryDomainNotK3Authority() async throws {
    let journal = try makePublicationJournal()
    let pragmas = try await journal.storagePragmasForTesting()
    let ownsBoundaryStates = try await journal.schemaContainsAny(of: [
        "publication_permit_pending", "sink_boundary_armed", "effect_permit_pending"
    ])
    let openedK3DatabaseCount = try await journal.openedK3DatabaseCountForTesting()
    XCTAssertEqual(pragmas.journalMode, "wal")
    XCTAssertEqual(pragmas.synchronous, 2) // FULL
    XCTAssertFalse(ownsBoundaryStates)
    XCTAssertEqual(openedK3DatabaseCount, 0)
}
```

- [ ] **Step 2: Run and verify RED**

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter BASResponseReleaseOrderingTests
```

- [ ] **Step 3: Add exact contracts and coordinator entry points**

```swift
public struct BASResponseSpoolPayload: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let terminalAnswerSourceProviderEgressBranchRef: BASTurnBranchRef
    public let provisionalStreamBranchRef: BASTurnBranchRef
    public let finalPublicationBranchRef: BASTurnBranchRef
    public let selectedCandidateArtifactID: BASArtifactID
    public let terminalProviderExecutionRef: BASProviderExecutionRef
    public let terminalSourceReceiptArtifactID: BASArtifactID
    public let terminalPrefixProviderBranchChainArtifactID: BASArtifactID
    public let presentationBytes: Data
    public let projectionPolicyDigest: String
    public let logicalEpoch: UInt64
}

/// Non-authoritative grouping only. Each consumer reopens and validates all four
/// Artifact Mesh payloads; this value owns no lineage, policy, state, or identity.
public struct BASProviderReleaseEvidenceReference: Codable, Sendable, Equatable {
    public let terminalPrefixProviderBranchChainArtifactID: BASArtifactID
    public let throughVisibilityProviderBranchChainArtifactID: BASArtifactID
    public let spoolArtifactID: BASArtifactID
    public let releasePreparationArtifactID: BASArtifactID
}

public struct BASExactOutputVerificationPayload: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let spoolArtifactID: BASArtifactID
    public let verifierContractArtifactID: BASArtifactID
    public let constraintArtifactID: BASArtifactID
    public let passed: Bool
}

public struct BASExactOutputRiskBinding: Codable, Sendable, Equatable {
    public let spoolArtifactID: BASArtifactID
    public let verificationArtifactID: BASArtifactID
    public let confirmationArtifactID: BASArtifactID?
    public let policyEpoch: UInt64
}

public struct BASProvisionalChunk: Codable, Sendable, Equatable {
    public let turnOperationRef: BASTurnOperationRef
    public let provisionalStreamBranchRef: BASTurnBranchRef
    public let logicalEpoch: UInt64
    public let sequence: UInt32
    public let bytes: Data
}

public struct BASChunkVerificationReceiptPayload: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let terminalAnswerSourceProviderEgressBranchRef: BASTurnBranchRef
    public let provisionalStreamBranchRef: BASTurnBranchRef
    public let terminalSourceReceiptArtifactID: BASArtifactID
    public let providerVisibilityReceiptArtifactID: BASArtifactID
    public let chunkIndex: UInt32
    public let chunkBytes: Data
    public let priorChainDigest: String
    public let resultingChainDigest: String
    public let verificationContractArtifactID: BASArtifactID
    public let constraintArtifactID: BASArtifactID
    public let passed: Bool
}

public struct BASProvisionalDisplayReceiptPayload: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let provisionalStreamBranchRef: BASTurnBranchRef
    public let streamBoundaryInstanceID: String
    public let streamBatchBoundaryPermitArtifactID: BASArtifactID
    public let boundaryAnchorReceiptArtifactID: BASArtifactID
    public let boundaryArmReceiptArtifactID: BASArtifactID
    public let firstChunkIndex: UInt32
    public let lastChunkIndex: UInt32
    public let priorChainDigest: String
    public let resultingChainDigest: String
    public let displaySinkReceipt: String
}

public enum BASExactReleaseDestinationKind: String, Codable, Sendable {
    case applicationUI, extensionUI, networkReply
}

public struct BASExactReleaseDestinationBinding: Codable, Sendable, Equatable {
    public let kind: BASExactReleaseDestinationKind
    public let canonicalDestinationDigest: String
}

public struct BASExactReleasePreparationPayload: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let terminalAnswerSourceProviderEgressBranchRef: BASTurnBranchRef
    public let terminalProviderExecutionRef: BASProviderExecutionRef
    public let terminalSourceReceiptArtifactID: BASArtifactID
    public let providerVisibilityReceiptArtifactID: BASArtifactID
    public let terminalPrefixProviderBranchChainArtifactID: BASArtifactID
    public let throughVisibilityProviderBranchChainArtifactID: BASArtifactID
    public let finalPublicationBranchRef: BASTurnBranchRef
    public let spoolArtifactID: BASArtifactID
    public let verificationArtifactID: BASArtifactID
    public let riskPermitArtifactID: BASArtifactID
    public let exactGrantArtifactID: BASArtifactID
    public let destination: BASExactReleaseDestinationBinding
}

public enum BASResponsePublicationContractError: Error, Sendable, Equatable {
    case invalidFinalPublicationBranch
    case legacyBranchRoundTripMismatch
}

public struct BASPublicationReservationRequest: Codable, Sendable, Equatable {
    public let idempotencyKey: String
    public let turnOperationRef: BASTurnOperationRef
    public let terminalAnswerSourceProviderEgressBranchRef: BASTurnBranchRef
    public let terminalProviderExecutionRef: BASProviderExecutionRef
    public let terminalSourceReceiptArtifactID: BASArtifactID
    public let providerVisibilityReceiptArtifactID: BASArtifactID
    public let terminalPrefixProviderBranchChainArtifactID: BASArtifactID
    public let throughVisibilityProviderBranchChainArtifactID: BASArtifactID
    public let finalPublicationBranchRef: BASTurnBranchRef
    public let publicationBoundaryInstanceID: String
    public let spoolArtifactID: BASArtifactID
    public let releasePreparationArtifactID: BASArtifactID
    public let replayManifestArtifactID: BASArtifactID
    public let verificationArtifactID: BASArtifactID
    public let riskPermitArtifactID: BASArtifactID
    public let exactGrantArtifactID: BASArtifactID
    public let destination: BASExactReleaseDestinationBinding
    public let sinkProfileDigest: String
    public let attemptRefArtifactID: BASArtifactID
    public let generationVectorArtifactID: BASArtifactID
    public let policyEpoch: UInt64
    public let deletionEpoch: UInt64

    public static func canonicalIdempotencyKey(
        finalPublicationBranchRef: BASTurnBranchRef,
        publicationBoundaryInstanceID: String,
        replayManifestArtifactID: BASArtifactID
    ) throws -> String {
        guard finalPublicationBranchRef.kind == .finalPublication,
              finalPublicationBranchRef.ordinal == 0
        else { throw BASResponsePublicationContractError.invalidFinalPublicationBranch }
        let branch = try finalPublicationBranchRef.canonicalLegacyProjection()
        guard try BASTurnBranchRef(validatingCanonicalLegacyProjection: branch)
            == finalPublicationBranchRef
        else { throw BASResponsePublicationContractError.legacyBranchRoundTripMismatch }
        let manifest = try replayManifestArtifactID.storageScalar
        return BASSovereignCanonicalBytes.lengthPrefixed([
            "qinao.publication.v1",
            branch,
            publicationBoundaryInstanceID,
            manifest
        ]).base64EncodedString()
    }
}

public enum BASPublicationState: String, Codable, Sendable, Equatable {
    case reserved, sinkCommitted, finalized, publicationIndeterminate
}

public struct BASPublicationRecord: Codable, Sendable, Equatable {
    public let request: BASPublicationReservationRequest
    public let state: BASPublicationState
    public let capabilityUseReceiptArtifactID: BASArtifactID?
    public let permitArtifactID: BASArtifactID?
    public let boundaryAnchorReceiptArtifactID: BASArtifactID?
    public let boundaryArmReceiptArtifactID: BASArtifactID?
    public let sinkReceiptArtifactID: BASArtifactID?
}

public struct BASExactReleaseSinkReceiptPayload: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let idempotencyKey: String
    public let turnOperationRef: BASTurnOperationRef
    public let finalPublicationBranchRef: BASTurnBranchRef
    public let publicationBoundaryInstanceID: String
    public let permitArtifactID: BASArtifactID
    public let boundaryAnchorReceiptArtifactID: BASArtifactID
    public let boundaryArmReceiptArtifactID: BASArtifactID
    public let spoolArtifactID: BASArtifactID
    public let destinationDigest: String
    public let providerReceipt: String
}

public struct BASPublicationFinalization: Codable, Sendable, Equatable {
    public let turnOperationRef: BASTurnOperationRef
    public let finalPublicationBranchRef: BASTurnBranchRef
    public let publicationBoundaryInstanceID: String
    public let replayManifestArtifactID: BASArtifactID
    public let spoolArtifactID: BASArtifactID
    public let capabilityUseReceiptArtifactID: BASArtifactID
    public let publicationBoundaryPermitArtifactID: BASArtifactID
    public let boundaryAnchorReceiptArtifactID: BASArtifactID
    public let boundaryArmReceiptArtifactID: BASArtifactID
    public let sinkReceiptArtifactID: BASArtifactID
}

package protocol BASPublicationJournal: Sendable {
    func reserve(_ request: BASPublicationReservationRequest) async throws -> BASPublicationRecord
    func lookup(idempotencyKey: String) async throws -> BASPublicationRecord?
    func lookup(replayManifestArtifactID: BASArtifactID) async throws -> BASPublicationRecord?
    func markSinkCommitted(
        idempotencyKey: String,
        capabilityUseReceiptArtifactID: BASArtifactID,
        permitArtifactID: BASArtifactID,
        boundaryAnchorReceiptArtifactID: BASArtifactID,
        boundaryArmReceiptArtifactID: BASArtifactID,
        sinkReceiptArtifactID: BASArtifactID
    ) async throws -> BASPublicationRecord
    func markIndeterminate(
        idempotencyKey: String,
        permitArtifactID: BASArtifactID,
        boundaryAnchorReceiptArtifactID: BASArtifactID?,
        boundaryArmReceiptArtifactID: BASArtifactID?
    ) async throws -> BASPublicationRecord
    func finalize(idempotencyKey: String) async throws -> BASPublicationRecord
}

public protocol BASExactReleaseSink: Sendable {
    func lookup(idempotencyKey: String) async throws -> BASExactReleaseSinkReceiptPayload?
    func release(
        presentationBytes: Data,
        spoolArtifactID: BASArtifactID,
        destination: BASExactReleaseDestinationBinding,
        turnOperationRef: BASTurnOperationRef,
        finalPublicationBranchRef: BASTurnBranchRef,
        publicationBoundaryInstanceID: String,
        permitArtifactID: BASArtifactID,
        boundaryAnchorReceiptArtifactID: BASArtifactID,
        boundaryArmReceiptArtifactID: BASArtifactID,
        idempotencyKey: String
    ) async throws -> BASExactReleaseSinkReceiptPayload
}
```

Add explicit public initializers and bounded decode checks for every cross-target value. Every spool/preparation/permit/receipt artifact carries the Contracts-owned `BASArtifactScopeBinding` appropriate to its public, workspace-authority, Attempt, or durable-warrant semantics; release code never substitutes raw turn/branch scope strings. `BASResponseSpoolPayload` deliberately has no `spoolID`, presentation digest, storage locator, signature, visibility receipt, future through-visibility chain, or ambiguous terminal-execution receipt: `ArtifactStore.put` derives the ID and returns the ordinary `BASArtifactStoreReceipt`. After the K3-pinned terminal-answer-source Provider egress is sealed, the spool binds that branch, the complete branch-bound `BASProviderExecutionRef`, exact `BASProviderTerminalSourceReceipt` artifact reference, and one immutable `terminalPrefixProviderBranchChainArtifactID`. That ID must reopen the shared Contracts Task 2A `BASProviderBranchChainPayload` with `cut == .terminalPrefix`: its `orderedEntries` contain only the canonical Provider allocation/claim/proposal/event-head lineage through the source (whose stable non-reused ordinal need not be last), while the spool separately binds the unique ordinal-zero provisional-stream and final-publication branches. The pinned source entry supplies the only proposal and seal receipts: `selectedCandidateArtifactID` must equal its `proposalArtifactID`, its complete execution ref must equal `terminalProviderExecutionRef`, and the chain-level `terminalSourceReceiptArtifactID` must equal the spool field. Consumers reopen that entry's `proposalReceiptArtifactID` and `eventHeadSealReceiptArtifactID` rather than introducing a fourth “execution receipt.” In buffered mode this prefix/spool precedes visibility; in incremental mode visibility already opened from frozen pre-call policy evidence, but the prefix cut still has empty visibility evidence and a nil visibility receipt. Decoder/replay reopens `BASProviderBranchControlPort` state and the active Attempt head, equality-checks every execution-ref/source-receipt/prefix field and root/head, and rejects an omitted/rewritten prior branch or intermediate/sibling Provider proposal even if its bytes or score match; only the pinned terminal source may feed `selectedCandidateArtifactID`.

`BASProviderReleaseEvidenceReference` is declared exactly once beside those publication contracts. A publishable authoritative result and its replay manifest carry this same four-ID value; early refusal, defer, cancel, or reconciliation-only results carry `nil` rather than fabricated artifact IDs. The value is neither an Artifact Mesh payload nor a new owner: validation reopens both canonical `BASProviderBranchChainPayload` cuts, the spool, and release preparation and then proves their exact root/source/visibility/prefix relation.

The spool intentionally precedes buffered L10 acceptance and `openProviderVisibilityGate`, avoiding a spool→visibility→spool cycle. Incremental mode instead follows `pin + frozen incremental-verifier policy → visibility → terminal execution/seal → terminal-prefix/spool`; buffered mode follows `terminal execution/seal → terminal-prefix/spool → verifier/L10 → visibility`. Only after both the terminal-prefix artifact and all mode-required visibility evidence exist, store one separate self-ID-free shared `BASProviderBranchChainPayload` with `cut == .throughVisibility`, identified externally as `throughVisibilityProviderBranchChainArtifactID`. It repeats the exact prefix entries, appends only policy-authorized post-pin verifier entries, and binds the canonical ordered incremental-policy or buffered verifier/L10 evidence plus the exact winning `BASProviderVisibilityReceipt`; it copies no `BASProviderVisibilityMode` or policy fields. Validation reopens K3's latest coverage head that proves both the terminal prefix and visibility evidence—this is the visibility-close head only in buffered mode. `BASExactReleasePreparationPayload` is then stored once and binds the spool, both chain artifact IDs, exact terminal-source and visibility receipt IDs, canonical root, and `.finalPublication` branch, but no manifest ID, idempotency key, boundary instance, future capability-use/anchor/arm/sink receipt, or self identity. Every typed branch is decoded through Task 2A and must equality-check its parent root and kind/ordinal. The only branch compatibility codec is Contracts Task 2A's `BASTurnBranchRef.canonicalLegacyProjection()` paired with `BASTurnBranchRef.init(validatingCanonicalLegacyProjection:)`; release code does not define a codec. Its bounded projection is used only inside the versioned publication idempotency projection and must round-trip to the exact typed branch and equality-check the expected parent root before lookup/release. Extend `BASRenderedOutput` with the sole canonical presentation-byte projection; extend the current L10 verification function and `BASActionPermit`/L11 decision with the exact typed binding above; extend `BASProviderReleaseGate` to reject a missing or mismatched binding in authoritative mode. Do not add `BASResponseProjectionAndVerificationCore`, `BASL11OutputPolicyCore`, a second candidate portfolio, or a second risk authority.

Both executable preparation/request structs repeat and equality-check the pinned terminal source branch, complete `BASProviderExecutionRef`, exact terminal-source receipt, terminal-prefix chain, exact visibility receipt, and through-visibility chain before manifest reservation; proposal and seal receipts are reopened only from the pinned source entry. The manifest resolver reopens the mode-specific K3 visibility row plus the latest K3 coverage head proving both visibility and the sealed terminal prefix, then validates complete mode-specific evidence without copying mode authority. A buffered request is rejected if any post-pin verifier branch, event-head seal, or L10 acceptance is omitted/reordered; an incremental request is rejected if its pre-call policy evidence, terminal seal, or ordered per-batch verification lineage is foreign or missing. The manifest therefore cannot substitute an internal branch or bypass logical visibility by merely pointing at the same spool bytes. Since `.finalPublication` is non-streaming, `publicationBoundaryInstanceID` must be the versioned canonical instance-zero projection of that exact branch; K3 recomputes it before installing `prepared`, so a free caller string is never authority.

Implement `BASPublicationJournalSQLiteStorage` with one transaction per compare-and-set transition and uniqueness constraints on both `idempotency_key` and the reversible scalar `replay_manifest_artifact_id`. Add this exact same-table index in `028_response_publication.sql`:

```sql
CREATE UNIQUE INDEX response_publication_manifest_unique
    ON response_publication_journal(replay_manifest_artifact_id);
```

Every Artifact-ID TEXT bind in `BASPublicationJournalSQLiteStorage`, including `replay_manifest_artifact_id` and permit/anchor/arm/sink receipt references, calls `try artifactID.storageScalar`; every read calls `try BASArtifactID(storageScalar:)`. `lookup(replayManifestArtifactID:)` queries only `response_publication_journal`, bounded-decodes the complete `BASPublicationRecord`, and returns `nil` for no row. Add a storage-parity test that reads the raw replay-manifest scalar from SQLite, requires byte equality with `try request.replayManifestArtifactID.storageScalar`, and round-trips it through the canonical initializer. Duplicate rows, malformed artifact/typed-branch scalars, impossible state/evidence combinations, or conflicting immutable request fields are corruption and fail closed; the method never repairs, arms, finalizes, or synthesizes evidence. It stores linked evidence projections only: K3 remains sole pending/arm truth and K4 remains sole claim/anchor truth. Journal rows contain artifact-ID strings and state only, never spool, permit, anchor, arm, or manifest bytes. Apply the existing BAS SQLite file-protection, integrity, secure-delete, WAL, and WAL/SHM sidecar policy.

Because this task precedes the runtime manifest type, declare this typealias inside `BASResponseReleaseCoordinator`; its initializer accepts one value of that type and stores no resolver state beyond the closure reference:

```swift
public typealias PublicationManifestRequestResolver = @Sendable (
    _ replayManifestArtifactID: BASArtifactID,
    _ spoolArtifactID: BASArtifactID
) async throws -> BASPublicationReservationRequest
```

The runtime-replay plan supplies the closure after its manifest contract exists. Host composition captures only the injected read-only K3 publication-context lookup and immutable configured sink profile alongside Artifact Mesh. The closure reopens the manifest, `BASProviderReleaseEvidenceReference`, spool, preparation, and both chain payloads; queries K3 only for the active Attempt/generation/policy/deletion plus exact root/pinned-source/final-branch/visibility/joint-coverage facts; derives the canonical instance-zero boundary from the reopened `.finalPublication/0` branch; exact-checks the configured sink profile; and returns the complete reservation request value. No publication-preparation row exists yet: only the coordinator's subsequent `installPublicationPreparation` call may create it. None of those authority facts is copied into a replay-owned snapshot. Do not add a resolver actor, protocol, cache, store, or alternate request type. The closure cannot receive the journal, token authority, mutable sink, or coordinator and cannot reserve, claim, release, mark, or finalize.

Implement `BASResponseReleaseCoordinator.publishExact(after:spoolArtifactID:)`, whose full signature remains `publishExact(after replayManifestArtifactID: BASArtifactID, spoolArtifactID: BASArtifactID) async throws -> BASPublicationFinalization`, in this strict order:

1. Call `publicationManifestRequestResolver(replayManifestArtifactID, spoolArtifactID)` exactly once. Require the returned manifest/spool IDs to equal the supplied IDs; require `finalPublicationBranchRef.kind == .finalPublication`, ordinal zero, and `finalPublicationBranchRef.turnOperationRef == turnOperationRef`; project with Contracts Task 2A's sole `BASTurnBranchRef.canonicalLegacyProjection()`, immediately reconstruct with `init(validatingCanonicalLegacyProjection:)`, and require exact branch and expected-parent equality; then rederive `idempotencyKey` from exactly `(finalPublicationBranchRef, publicationBoundaryInstanceID, replayManifestArtifactID)` using versioned `BASSovereignCanonicalBytes`. A caller-supplied free string is rejected.
2. Load and validate the one spool artifact; require its root, pinned terminal source/receipt, terminal-prefix chain, and selected Provider/stream/final branches to match. Reopen the release-preparation artifact, exact mode-specific K3 `BASProviderVisibilityReceipt`/visibility row, through-visibility chain, L10 verification, L11 risk permit, exact final-release grant, and destination. Separately query the same K3 owner for the active Attempt/generation/policy/deletion tuple and compare the host's immutable configured sink profile; neither fact comes from a manifest-owned snapshot. Require the through-visibility chain to extend the spool prefix and contain every mode-required receipt/evidence item. Reopen the latest K3 coverage head proving both that exact terminal prefix and exact visibility evidence; it equals the visibility-close head only in buffered mode. Before touching the separate journal, call K3 `installPublicationPreparation` with that entire release-preparation/manifest/spool/root/source/final/visibility tuple. Its one transaction equality-checks the active coverage head and idempotently installs K3-local `prepared`. Then reserve the independent journal row in `reserved`. A crash between these operations leaves only a non-usable prepared row and is resumed with the same manifest; K3 never reads the journal and the journal cannot create a permit or mark a boundary armed.
3. Materialize one self-ID-free `BASPublicationBoundaryPermit` including that exact release-preparation/manifest tuple, terminal source/receipt, visibility receipt, and through-visibility chain, store it through ordinary Artifact Mesh `put`, and call K3 `preparePublicationBoundary`. In one K3-local conditional transaction it reopens the exact mode-specific visibility row/receipt, the same latest coverage head, and the chain; it requires the active Attempt/generation/epochs/root/source/final-branch attachment, installed preparation tuple, policy-derived mode evidence, current owner/boot epoch, and unused boundary instance. It advances `prepared → publication_permit_pending`, references that permit artifact, and returns `BASK3BoundarySourceCommit`. The pending permit is non-usable and sink call count remains zero. The coordinator separately requires its journal reservation before making this call, but no K3 SQL or API observes that other WAL.
4. Build one `BASBoundaryAnchorRequest` from the exact permit/source tuple with `capabilityUseReceiptArtifactID == nil` and call K4 `claimAndAnchorBoundary`. K4 atomically claims the one-shot final-publication grant for that exact branch, records the sole canonical `BASCapabilityUseReceipt`, covers the committed source root, charges the exact instance, and returns the ordinary store receipt identifying `BASBoundaryAnchorReceipt`. Reopen and equality-check every field; anchor issuance makes visibility conservatively possible but does not itself authorize the sink call.
5. Present that exact anchor artifact/payload to K3 `armBoundary`. K3 performs the sole live Attempt/generation/epoch/owner/boot/deadline CAS `publication_permit_pending → sink_boundary_armed`, durably records canonical `BASBoundaryArmReceipt` bytes in its row, and returns them. Store/reopen that receipt through ordinary Artifact Mesh `put`; crash between K3 commit and `put` reprojects the identical durable bytes and never reruns the CAS. Only the in-flight CAS winner, still before `monotonicCallHandoffDeadline`, may continue.
6. The CAS winner first queries the sink with the one derived idempotency key. If a matching receipt already exists, verify its exact typed root/branch/instance/permit/anchor/arm tuple. Otherwise call `release` once with identical bytes and that entire tuple. Store the sink receipt through ordinary Artifact Mesh `put`, mark sink committed, finalize the journal, and return `BASPublicationFinalization` carrying the same typed lineage.

The write-capable `BASPublicationJournal` protocol is package-only and the coordinator keeps its injected conformer private; no public initializer/property/return type exposes it. The coordinator's exact public read-only method `public func finalizedPublicationRecord(for replayManifestArtifactID: BASArtifactID) async throws -> BASPublicationRecord` delegates to the private journal lookup, requires exactly one row in `.finalized`, and requires all immutable request fields plus nonnil use/permit/anchor/arm/sink evidence to form a legal finalized shape. It returns that decoded record without reserving, marking, finalizing, arming, claiming, querying the sink, or writing any store. Missing, nonfinal, malformed, duplicate, or mismatched rows throw. `publishExact` calls this same method before reporting success. No Runtime/replay initializer, dependency bundle, or test fixture receives the journal directly; source and dependency tests reject a `public protocol BASPublicationJournal`, public journal property, or any `publicationJournal` field outside the coordinator and its SQLite implementation.

Recovery is deliberately at-most-once. Before a K4 anchor exists, the same still-live owner may resume only the byte-identical claim-and-anchor request for the existing pending permit. Immediately after a returned anchor, only that same in-flight owner may attempt the one K3 arm CAS. At or after anchor uncertainty, owner/boot loss, arm issuance, handoff-deadline expiry, or a possible sink crossing, recovery may only query/reconcile/finalize the same publication identity. It never creates another permit/instance, claims a sibling branch, arms again, or blindly calls `release`; an unqueryable or contradictory outcome is durably `publication_indeterminate`, even if that under-delivers. The manifest contains the pre-claim grant ID, never a future use/anchor/arm/sink receipt; the linked K3/K4/journal finalization records are the sole later facts.

Keep that signature and order unchanged. In production, the runtime-replay plan calls it only while holding one outer ordinary `.responsePublication/.responseSpoolAndArtifactBuffer` activation rooted at the replay-manifest artifact; no memory token or context crosses into `publishExact` or is persisted in a publication/K4 payload. If outer admission or compare-and-start fails, the runtime must not call this method, so resolver, journal reserve, K3 pending, K4 claim/anchor, K3 arm, sink lookup/release, mark, and finalization counts all remain zero. Lost-reply recovery remains inside the same outer activation. The successful path completes that activation only after its final journal lookup reaches a known terminal state; a thrown/cancelled recovery retires the exact activation before returning the runtime's typed reconciliation disposition. The coordinator never calls a result-producing runtime or constructs `BASEBrainTurnResult`; the runtime-replay plan returns its existing public result only after finalization succeeds.

Pin test-only `PublicationManifestResolverMutation.allCases` to `.throwsBeforeDecode`, `.redirectedManifest`, `.redirectedSpool`, `.turnOperationMismatch`, `.finalPublicationBranchMismatch`, `.boundaryInstanceMismatch`, `.attemptGenerationMismatch`, `.idempotencyKeyMismatch`, `.missingReleasePreparation`, `.releasePreparationSpoolMismatch`, `.terminalSourceReceiptMismatch`, `.visibilityReceiptMismatch`, `.terminalPrefixChainMismatch`, `.throughVisibilityChainMismatch`, `.omittedPostPinVerifier`, `.visibilityModeEvidenceMismatch`, `.verificationMismatch`, `.riskPermitMismatch`, `.exactGrantMismatch`, and `.destinationMismatch`; every case must leave reservation, K3 pending, K4 claim/anchor, K3 arm, and sink release counts at zero.

The provisional path extends the existing streaming/provisional verdict path with an L10 hash-chain fold and an L14 UI-only grant. It is legal only when the installed `BASProviderBranchPolicy` derives `.incrementalVerified`; `.bufferedUntilVerified` cannot create a provisional batch and reaches bytes only through final publication after its complete verifier/L10 visibility close. The incremental path uses the same parent `BASTurnOperationRef`, K3-pinned terminal-source branch/receipt, exact K3 `BASProviderVisibilityReceipt`, and unique `.provisionalStream` ordinal-zero branch attached to that source; legacy `turnID`/`branchID` values are reversible display/debug projections only. K4 reserves/claims that branch once and returns its canonical use-receipt artifact. L10 creates one self-ID-free governed `BASChunkVerificationReceiptPayload` per chunk and ordinary-puts/reopens it through `BASGovernedArtifactPayloadCodec`; it binds exact bytes, index, prior/result chain digests, verifier contract/constraint, pinned source, visibility receipt, and stream branch. A failed receipt can be audited but is ineligible. L12 groups only passed receipts into bounded contiguous batches. For every batch, the permit carries the ordered receipt Artifact IDs for exactly its range. K3 `prepareStreamBatchBoundary` reopens the visibility-open row/receipt and every governed batch receipt, equality-checks their root, pinned source, stream attachment, byte range, prior/result chain digests, and exact chunk bytes, then checks the active Attempt/generation/epochs, use receipt, unused instance, non-overlap, byte/token counts, and cumulative ceilings. Missing, reordered, sibling, failed, or range/digest/byte-mismatched verification evidence fails before pending. Only then does K3 advance that range to `stream_permit_pending` and commit the source root. K4 `anchorClaimedBoundary` covers that root, equality-checks the already-claimed branch, and atomically charges the exact range/instance/byte/token deltas without another grant use. K3 `armBoundary` performs the sole CAS to `visible_or_unknown` and returns `BASBoundaryArmReceipt`. Only that in-flight winner may call the provisional sink once before its handoff deadline with `(turnOperationRef, provisionalStreamBranchRef, streamBatchBoundaryInstanceID, range, chainDigest, permit, anchor, arm)`.

The sink queries/deduplicates that whole tuple. Before anchor, only the same pending permit may resume its anchor request. At or after anchor uncertainty, owner/boot loss, arm issuance, deadline expiry, or possible visibility, recovery only queries/finalizes that batch; it never creates an overlapping/replacement batch or calls the sink again. An unqueryable ambiguous batch terminates streaming as visibility-indeterminate. `BASProvisionalDisplayReceiptPayload` binds the exact range and permit/anchor/arm evidence and has no tool/state/evolution/exact-authority protocol conformance. A remand stores a new spool artifact and invalidates the old grant by artifact ID. Exactly-once visibility is claimed only for a sink implementing durable lookup/deduplication, never as a distributed transaction.

Pin `StreamVisibilityEvidenceMutation.allCases` to missing/foreign terminal-source receipt, missing/foreign visibility receipt, wrong policy-derived mode, sibling source/stream attachment, missing/reordered/duplicate batch-verification receipt, and verification root/range/byte/resulting-chain-digest mismatch. Every mutation and every buffered-mode provisional attempt must leave stream-pending, K4 anchor, K3 arm, and sink counts at zero.

- [ ] **Step 4: Run release and legacy rendering/risk regressions**

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASResponseReleaseOrderingTests|BASChapter748DreamLoopTests|BASMLTriSelfServiceTests|BASL12GentleHandWhitepaperTests|BASProviderReleaseCoreTests|BASProvisionalVerdictTests|BASEBrainSchemaGovernanceRegistryTests'
ROOT=/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate
if rg -n 'BASProcessMemoryLedger|BASMemoryAdmissionContext|BASMemoryReservationToken|BASMemoryActivationToken|hardCapBytes:' \
  "$ROOT/Sources/BASRuntimeCore/BASResponsePublicationContracts.swift" \
  "$ROOT/Sources/BASMemory/BASPublicationJournalSQLiteStorage.swift" \
  "$ROOT/Sources/BASHostKit/BASResponseReleaseCoordinator.swift" \
  "$ROOT/Sources/BASSovereign" --glob '*.swift'; then
  exit 1
fi
```

The cross-plan runtime fixture additionally denies the outer memory scope and asserts zero manifest-request resolver, publication-journal reserve, K4 claim, sink lookup/release, mark, and finalization calls. Keep that integration test in Runtime Task 5 so this Task 1 and all K4 tests remain memory-neutral.

- [ ] **Step 5: Commit**

After every preceding Task 1 gate proves the old stream-then-second-generation path unreachable, remove exactly that `retire` entry from `release.spool-publication.current_conflicts`, transition its status from `converging` to `implemented`, and run the shared checker plus checker unit tests. Do not continue to `git add` while either is red.

```bash
python3 scripts/check_qinao_owner_ledger.py --root "$PWD" --ledger "$PWD/docs/superpowers/specs/qinao-owner-ledger-v1.json"
python3 scripts/test_check_qinao_owner_ledger.py -v
git add docs/superpowers/specs/qinao-owner-ledger-v1.json BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift BehavioralAISubstrate/Sources/BASRuntimeCore/BASResponsePublicationContracts.swift BehavioralAISubstrate/Sources/BASMemory/BASPublicationJournalSQLiteStorage.swift BehavioralAISubstrate/Sources/BASMemory/SQL/028_response_publication.sql BehavioralAISubstrate/Sources/BASOrchestration/EBrainL3L12RenderingCore.swift BehavioralAISubstrate/Sources/BASOrchestration/ExecutionGovernanceCore.swift BehavioralAISubstrate/Sources/BASOrchestration/ProviderReleaseCore.swift BehavioralAISubstrate/Sources/BASPolicy/EBrainRiskPlaneCore.swift BehavioralAISubstrate/Sources/BASHostKit/BASResponseReleaseCoordinator.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASResponseReleaseOrderingTests.swift
git commit -m "feat: enforce provisional and exact response release order"
```

### Task 2: Algorithm-Agile Signature Envelope and Honest Custody

**Files:**
- Modify [ownership lifecycle]: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify [schema governance]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Modify [schema governance tests]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`
- Modify [E]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASSovereign/BASSovereignFingerprintStore.swift`
- Modify [E]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASSovereign/BASSovereignEd25519Signing.swift`
- Modify [E/A]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASSovereign/BASSovereignKeychainBinding.swift`
- Create [M — algorithm-agile trust owner and signer port]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASSovereign/BASSovereignTrustManifest.swift`
- Create [A — Secure Enclave boundary]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASSovereign/BASSecureEnclaveP256Signer.swift`
- Create [test]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSovereignSignerSuiteTests.swift`

**Reuse Decision: E + A + M**

**Create Proof (production M — exactly eight gates):**

1. Repository search and existing candidates: run `rg -n 'BASSovereignEd25519|BASSovereignKeychainBinding|BASSovereignFingerprintManifest|BASArtifactAttestationPayload' BehavioralAISubstrate/Sources`; preserve Ed25519 bytes, v1 verification, and the prerequisite generic attestation payload.
2. Apple/public/upstream primitives: use CryptoKit Ed25519/P-256, Security/Keychain, `SecureEnclave.P256.Signing.PrivateKey`, and system randomness; implement no algorithm, key store, or canonical encoder.
3. Absent invariant: the repository has no single algorithm-agile historical trust manifest or honest optional non-exportable P-256 signing root.
4. Why E/composition/generics/A is insufficient: the v1 fingerprint manifest cannot represent suite/custody/rotation status without changing its persisted byte contract, and signer adapters alone cannot provide an ordered historical trust root.
5. Single authority/state/storage/failure boundary: K4 alone selects a manifest-approved signer; Keychain/Secure Enclave alone hold keys; the one trust manifest owns suite/key status; Artifact Mesh alone stores the existing `BASArtifactAttestationPayload`; unknown suite, missing key, or broken history quarantines.
6. Dependency/no-second-truth proof: K4 → signer port → CryptoKit/Security and v1 manifest → deterministic migration projection → trust manifest; neither signer nor attestation storage owns authorization or a second trust registry.
7. Compatibility/retirement: Ed25519 verification remains for persisted v1 records; `BASSovereignFingerprintManifest` becomes a read-only v1 projection and cannot mutate independently after migration.
8. Mutation/crash/replay/duplicate-authority tests: mutate every signed statement field and manifest link, crash around rotation persistence, replay historical attestations, and fail on downgrade, false custody, two active roots for one role/epoch, target-embedded signature bytes, or a special attestation store/API.

**Interfaces:**

- Consumes: existing canonical bytes, Ed25519/Keychain implementations, `BASArtifactAttestationPayload`, `BASArtifactStorePort`, and `BASArtifactStoreReceipt`.
- Produces: `BASSovereignTrustManifestPayload`, `BASSovereignSignatureStatement`, and a `BASSovereignSigner` that returns proof bytes only; K4 constructs and stores the one generic attestation payload.

- [ ] **Step 1: Write custody, downgrade, and rotation tests**

```swift
func testEd25519CompatibilitySignerReportsExportableKeychainCustody() async throws {
    let signer = makeEdSigner()
    let entry = await signer.trustManifestEntry
    let statement = fixtureSignatureStatement(for: entry, targetArtifactID: fixtureArtifactID())
    let proofBytes = try await signer.signCanonicalStatement(statement)
    let attestation: BASArtifactAttestationPayload = fixtureArtifactAttestation(
        statement: statement,
        proofBytes: proofBytes
    )
    XCTAssertEqual(entry.signatureSuite, .ed25519)
    XCTAssertEqual(entry.custodyClass, .keychainThisDeviceOnlyExportableSeed)
    XCTAssertEqual(attestation.targetArtifactID, fixtureArtifactID())
}

func testP256NeverSilentlyFallsBackToSoftware() async {
    do {
        _ = try await BASSecureEnclaveP256Signer(requireHardware: true, availability: false)
        XCTFail("required hardware custody must fail closed")
    } catch {
        XCTAssertEqual(error as? BASSovereignSignerError, .secureEnclaveUnavailable)
    }
}

func testUnknownSuiteAndRevokedKeyFailClosed() throws {
    XCTAssertThrowsError(try verifier.decodeAndVerify(fixtureWireAttestation(signatureSuiteRaw: "unknown")))
    XCTAssertThrowsError(try verifier.verify(fixtureAttestation(keyStatus: .revoked)))
}


func testEverySignedStatementMetadataTamperFails() throws {
    let signed = try fixtureSignedStatement()
    for mutation in BASSignatureStatementFixture.everySingleFieldMutation {
        XCTAssertThrowsError(try verifier.verify(mutation(signed)))
    }
}
```

- [ ] **Step 2: Run RED against the existing sovereign target**

Keep signer/trust code in the existing `BASSovereign` target. Guard Security/Secure Enclave implementations with the package's Apple-platform compilation pattern; non-Apple builds retain verification and explicitly test-only signers, never a production fallback labeled as Secure Enclave. Then run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter BASSovereignSignerSuiteTests
```

- [ ] **Step 3: Implement exact envelope and signer protocol**

```swift
public enum BASSignatureSuite: String, Codable, Sendable, CaseIterable {
    case ed25519
    case secureEnclaveP256SHA256
}

public enum BASKeyCustodyClass: String, Codable, Sendable {
    case keychainThisDeviceOnlyExportableSeed
    case secureEnclaveNonExportableP256
    case testOnlyEphemeral
}

public enum BASKeyManifestStatus: String, Codable, Sendable {
    case active, verifyOnly, revoked
}

public struct BASSovereignTrustManifestEntry: Codable, Sendable, Equatable {
    public let keyID: String
    public let keyEpoch: UInt64
    public let signatureSuite: BASSignatureSuite
    public let publicKeyBytes: Data
    public let publicKeyDigest: String
    public let custodyClass: BASKeyCustodyClass
    public let status: BASKeyManifestStatus
    public let validFromLogicalTime: UInt64
    public let verifyUntilLogicalTime: UInt64?
    public let revocationReasonDigest: String?
}

public struct BASSovereignTrustManifestPayload: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let manifestEpoch: UInt64
    public let previousManifestArtifactID: BASArtifactID?
    public let orderedEntries: [BASSovereignTrustManifestEntry]
}

public struct BASSovereignSignatureStatement: Codable, Sendable, Equatable {
    public let targetArtifactID: BASArtifactID
    public let signatureSuite: BASSignatureSuite
    public let hashSuite: String
    public let signatureEncoding: String
    public let canonicalizationVersion: String
    public let keyID: String
    public let keyEpoch: UInt64
    public let publicKeyDigest: String
    public let custodyClass: BASKeyCustodyClass
    public let authorizationContextArtifactID: BASArtifactID?
}

public protocol BASSovereignSigner: Sendable {
    var trustManifestEntry: BASSovereignTrustManifestEntry { get async }
    func signCanonicalStatement(_ statement: BASSovereignSignatureStatement) async throws -> Data
}
```

The signer canonicalizes the entire `BASSovereignSignatureStatement` with existing `BASSovereignCanonicalBytes`, signs it with CryptoKit/Security, and returns proof bytes only. `BASSovereignTokenAuthority` constructs the prerequisite `BASArtifactAttestationPayload` with that statement digest and proof, stores it with the ordinary Artifact Mesh `put`, and uses the returned `BASArtifactStoreReceipt`; there is no sovereign-specific attestation payload, method, store, or identity function. The target and trust-manifest payloads contain no self ID/digest/signature, and no transport wrapper becomes canonical artifact identity.

Keep raw suite/hash/encoding strings until validation so unknown wire values reject instead of normalizing. Extend the existing Ed25519 key-pair/Keychain path to conform to the port and report `keychainThisDeviceOnlyExportableSeed`. P-256 uses `SecureEnclave.P256.Signing.PrivateKey` only when available and explicitly policy-selected, never software fallback under a hardware custody label. `BASSovereignFingerprintManifest` v1 deterministically projects into one `BASSovereignTrustManifestPayload`; after migration it remains verify-only and cannot be separately mutated. Trust manifests chain by prior artifact ID and support active/verify-only/revoked entries with uninterrupted historical verification.

- [ ] **Step 4: Run compatibility and signer tests, then commit**

Run the Swift tests first. This owner starts with no conflict entries; after PASS, require `trust.algorithm-agile-manifest.current_conflicts` to remain empty, transition its status from `converging` to `implemented`, run the shared checker and its unit tests, and only then stage/commit.

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASSovereignSignerSuiteTests|BASSovereignCommitTokenEd25519Tests|BASSovereignKeychainBindingTests|BASSovereignAuditLedgerEd25519Tests|BASEBrainSchemaGovernanceRegistryTests'
python3 scripts/check_qinao_owner_ledger.py --root "$PWD" --ledger "$PWD/docs/superpowers/specs/qinao-owner-ledger-v1.json"
python3 scripts/test_check_qinao_owner_ledger.py -v
git add docs/superpowers/specs/qinao-owner-ledger-v1.json BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift BehavioralAISubstrate/Sources/BASSovereign/BASSovereignFingerprintStore.swift BehavioralAISubstrate/Sources/BASSovereign/BASSovereignEd25519Signing.swift BehavioralAISubstrate/Sources/BASSovereign/BASSovereignKeychainBinding.swift BehavioralAISubstrate/Sources/BASSovereign/BASSovereignTrustManifest.swift BehavioralAISubstrate/Sources/BASSovereign/BASSecureEnclaveP256Signer.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSovereignSignerSuiteTests.swift
git commit -m "feat: add algorithm agile sovereign signer suites"
```

### Task 3: Durable K4 Issuance, Reserve, Claim, Spend, and Recovery

**Files:**
- Modify [ownership lifecycle]: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify [E — sole authority]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASSovereign/BASSovereignTokenAuthority.swift`
- Modify [E — existing SQLite owner]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASSovereign/BASSovereignLedgerStorage.swift`
- Modify [E — persistent anchor projection]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASSovereign/BASSovereignSnapshotManager.swift`
- Modify [E — persistent version-to-anchor projection]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASSovereign/BASSovereignCleanRebootCoordinator.swift`
- Create [migration for the same E/M owner]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASSovereign/SQL/014_sovereign_capability_lifecycle.sql`
- Create [test]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASK4AuthorizationLedgerTests.swift`

**Reuse Decision: E + M**

**Create Proof (production M — exactly eight gates):**

1. Repository search and existing candidates: run `rg -n 'actor BASSovereignTokenAuthority|BASSovereignCommitToken|BASSovereignWarrant|009_sovereign_tokens|BASSovereignLedgerSQLiteStorage' BehavioralAISubstrate/Sources`; extend this one authority/storage/schema lineage.
2. Apple/public/upstream primitives: SQLite `BEGIN IMMEDIATE`, uniqueness constraints, WAL, and transactions provide atomic reserve/claim/spend; no custom log, WAL, transaction manager, or helper service is needed.
3. Absent invariant: the live authority lacks extension-private crash-durable issue/reserve/atomic claim-and-spend, nonce tombstones, durable halt/anchor/version state, K3-root anchoring, exact `BASTurnOperationRef`/`BASTurnBranchRef` boundary anchoring, and idempotent lost-reply recovery.
4. Why E/composition/generics/A is insufficient: actor-memory maps and SQL 009 cannot survive termination or atomically bind one persisted `BASCapabilityUseReceipt`; composing the audit ledger, snapshot manager, clean-reboot actor, or an XPC adapter would create neither durable CAS nor tombstones and would leave halt/rollback truth volatile.
5. Single authority/state/storage/failure boundary: `BASSovereignTokenAuthority` remains the sole mint/revoke/reserve/claim/spend/halt/boundary-anchor authority; extended helper-private `BASSovereignLedgerSQLiteStorage` is its only mutable truth for grants, reservations, claims, spent receipts, nonce tombstones, halt epochs, version bindings, root anchors, boundary-instance anchors, and the last accepted K3 root tuple; Artifact Mesh stores receipt facts; corruption, rollback, or incomplete migration quarantines.
6. Dependency/no-second-truth proof: Enhanced Security adapter → `BASSovereignTokenAuthority` → existing SQLite storage + signer + Artifact Mesh; host code never opens the K4 database, and audit observations are not lifecycle truth.
7. Compatibility/retirement: commit tokens/warrants decode and verify as v1 projections; new issuance uses canonical `BASCapabilityGrant`; actor-only production initialization is unavailable on iOS 27 release builds.
8. Mutation/crash/replay/duplicate-authority tests: mutate every binding, crash before/after every transaction/reply, replay the same `(grantArtifactID, boundSubjectArtifactID, requestID)` and `(permitArtifactID, boundaryInstanceID, turnBranchRef, requestID)` tuples, and prove concurrent claims/anchors resolve to one identical fact, validation never consumes, tombstones/halt/anchor/version/K3-root bindings survive rotation/restart, stale or forked K3 roots quarantine, and no second claim/use/anchor receipt exists.

**Interfaces:**

- Consumes: the Contracts plan's exact `BASCapabilityGrant`, self-ID-free `BASCapabilityUseReceipt`, `BASTurnOperationRef`, `BASTurnBranchRef`, `BASArtifactID`, ordinary `BASArtifactStoreReceipt`, injected `BASArtifactStorePort`, plus the existing signer, audit ledger, and SQL 009 lineage.
- Produces: durable implementations behind the exact existing `issueCapability`, `reserveCapability`, `claimCapability`, and `lookupCapabilityUseReceipt` methods and the Contracts Task 2A `BASSovereignBoundaryAnchoring` port. It consumes the common request/receipt values unchanged and creates no domain-specific K4 API, alternate authority, caller-minted operation ID, reservation permit, or capability-specific receipt wrapper.

- [ ] **Step 1: Write crash, duplicate, lost-reply, and corruption tests**

```swift
func testIssueIsDurableBeforeSignatureReply() async throws {
    let grant = fixtureGrant(nonce: "nonce-1")
    let authority = try makePersistentAuthority(failpoint: .afterIssueCommitBeforeReply)
    do {
        _ = try await authority.issueCapability(grant, requestID: "issue-1")
        XCTFail("injected lost reply must surface")
    } catch {
        XCTAssertEqual(error as? BASK4InjectedFailure, .replyLost)
    }
    let reopened = try reopenPersistentAuthority()
    let recovered = try await reopened.issueCapability(grant, requestID: "issue-1")
    XCTAssertEqual(recovered, fixtureGrantArtifactStoreReceipt())
}

func testLostClaimReplyRecoversSameReceipt() async throws {
    let authority = try makePersistentAuthority(failpoint: .afterClaimCommitBeforeReply)
    let issued = try await authority.issueCapability(
        fixtureGrant(nonce: "nonce-1"),
        requestID: "issue-1"
    )
    let grantArtifactID = issued.body.artifactID
    let boundSubjectArtifactID = fixtureBoundSubjectArtifactID()
    try await authority.reserveCapability(
        grantArtifactID: grantArtifactID,
        boundSubjectArtifactID: boundSubjectArtifactID,
        requestID: "claim-1"
    )
    do {
        _ = try await authority.claimCapability(
            grantArtifactID: grantArtifactID,
            boundSubjectArtifactID: boundSubjectArtifactID,
            requestID: "claim-1"
        )
        XCTFail("injected lost claim reply must surface")
    } catch {
        XCTAssertEqual(error as? BASK4InjectedFailure, .replyLost)
    }
    let restarted = try reopenPersistentAuthority()
    let receipt = try await restarted.lookupCapabilityUseReceipt(
        grantArtifactID: grantArtifactID,
        boundSubjectArtifactID: boundSubjectArtifactID,
        requestID: "claim-1"
    )
    XCTAssertEqual(receipt, fixtureCapabilityUseArtifactStoreReceipt())
}

func testClaimBeforeReserveAndNonceReplayFailClosed() async throws {
    let authority = try makePersistentAuthority()
    let issued = try await authority.issueCapability(
        fixtureGrant(nonce: "nonce-1"),
        requestID: "issue-1"
    )
    let grantArtifactID = issued.body.artifactID
    let boundSubjectArtifactID = fixtureBoundSubjectArtifactID()
    do {
        _ = try await authority.claimCapability(
            grantArtifactID: grantArtifactID,
            boundSubjectArtifactID: boundSubjectArtifactID,
            requestID: "claim-1"
        )
        XCTFail("claim before reserve must fail")
    } catch {
        XCTAssertEqual(error as? BASK4AuthorizationError, .notReserved)
    }
    try await authority.reserveCapability(
        grantArtifactID: grantArtifactID,
        boundSubjectArtifactID: boundSubjectArtifactID,
        requestID: "claim-1"
    )
    _ = try await authority.claimCapability(
        grantArtifactID: grantArtifactID,
        boundSubjectArtifactID: boundSubjectArtifactID,
        requestID: "claim-1"
    )
    do {
        _ = try await authority.issueCapability(
            fixtureGrant(nonce: "nonce-1"),
            requestID: "issue-2"
        )
        XCTFail("nonce replay must fail")
    } catch {
        XCTAssertEqual(error as? BASK4AuthorizationError, .nonceReplay)
    }
}

func testProductionK4OwnsOneFullDurabilityHandleAndSurvivesRestart() async throws {
    let authority = try makePersistentAuthority()
    let pragmas = try await authority.storagePragmasForTesting()
    XCTAssertEqual(pragmas.journalMode, "wal")
    XCTAssertEqual(pragmas.synchronous, 2) // FULL
    try await authority.markHalted(sessionID: "session-1", haltEpoch: 9)
    try await authority.bindVersion(
        "host-v3",
        to: fixtureSnapshotAnchor(),
        k3: .init(
            databaseEpoch: 4,
            highWaterMark: 91,
            rootArtifactID: artifactID("k3-root-91"),
            deletionEpoch: 12,
            schemaVersion: 7
        )
    )

    let reopened = try reopenPersistentAuthority()
    let isHalted = try await reopened.isHalted(sessionID: "session-1", minimumEpoch: 9)
    let anchor = try await reopened.anchor(forVersion: "host-v3")
    XCTAssertTrue(isHalted)
    XCTAssertEqual(anchor?.k3.highWaterMark, 91)
}

func testInMemoryAndNullK4CannotEnterReleaseComposition() throws {
    XCTAssertThrowsError(try makeIOS27ReleaseComposition(k4: .inMemoryForTesting()))
    XCTAssertThrowsError(try makeIOS27ReleaseComposition(k4: .nullForTesting()))
}

func testClaimAndAnchorIsAtomicForOneExactFinalPublicationBranch() async throws {
    let authority = try makePersistentAuthority()
    let request = fixtureBoundaryAnchorRequest(
        turnOperationRef: fixtureTurnOperationRef(),
        turnBranchRef: fixtureFinalPublicationBranchRef(),
        capabilityUseReceiptArtifactID: nil
    )
    let anchorStoreReceipt = try await authority.claimAndAnchorBoundary(request)
    let anchor = try await reopenBoundaryAnchor(anchorStoreReceipt.body.artifactID)
    XCTAssertEqual(anchor.turnOperationRef, request.turnOperationRef)
    XCTAssertEqual(anchor.turnBranchRef, request.turnBranchRef)
    XCTAssertEqual(anchor.permitArtifactID, request.permitArtifactID)
    XCTAssertNotNil(anchor.capabilityUseReceiptArtifactID)
    let claimCount = try await authority.claimCount(for: request.turnBranchRef)
    let anchorCount = try await authority.anchorCount(for: request.boundaryInstanceID)
    XCTAssertEqual(claimCount, 1)
    XCTAssertEqual(anchorCount, 1)
}

func testBoundaryAnchorReplayReturnsSameReceiptAndMutationFailsClosed() async throws {
    let authority = try makePersistentAuthority(failpoint: .afterBoundaryAnchorCommitBeforeReply)
    let request = fixtureAlreadyClaimedBoundaryAnchorRequest()
    do {
        _ = try await authority.anchorClaimedBoundary(request)
        XCTFail("injected lost reply must surface")
    } catch { }
    let reopened = try reopenPersistentAuthority()
    let recovered = try await reopened.anchorClaimedBoundary(request)
    XCTAssertEqual(recovered, fixtureBoundaryAnchorArtifactStoreReceipt())

    await XCTAssertThrowsErrorAsync {
        _ = try await reopened.anchorClaimedBoundary(
            request.replacing(turnBranchRef: fixtureSiblingEffectBranchRef())
        )
    }
}
```

- [ ] **Step 2: Run RED, then implement transactional storage**

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter BASK4AuthorizationLedgerTests
```

Keep the Contracts plan's exact authority methods, arguments, and return types; do not add a second lookup or convenience overload:

```swift
public func issueCapability(
    _ grant: BASCapabilityGrant,
    requestID: String
) async throws -> BASArtifactStoreReceipt

public func reserveCapability(
    grantArtifactID: BASArtifactID,
    boundSubjectArtifactID: BASArtifactID,
    requestID: String
) async throws

public func claimCapability(
    grantArtifactID: BASArtifactID,
    boundSubjectArtifactID: BASArtifactID,
    requestID: String
) async throws -> BASArtifactStoreReceipt

public func lookupCapabilityUseReceipt(
    grantArtifactID: BASArtifactID,
    boundSubjectArtifactID: BASArtifactID,
    requestID: String
) async throws -> BASArtifactStoreReceipt?
```

Consume Contracts Task 2A's exact `BASBoundaryAnchorRequest`, governed `BASBoundaryAnchorReceipt`, governed `BASBoundaryArmReceipt`, and `BASSovereignBoundaryAnchoring` port without redeclaration. Task 3 implements that port inside the existing K4 authority; it does not register either receipt again. Every K4 API still returns an ordinary `BASArtifactStoreReceipt` whose `body.artifactID` identifies the payload, and every put/reopen goes through Contracts' `BASGovernedArtifactPayloadCodec`.

`claimAndAnchorBoundary` requires `capabilityUseReceiptArtifactID == nil`; in one K4 SQLite transaction it revalidates and claims the one-shot grant for the exact `turnBranchRef`, records the resulting canonical use-receipt artifact ID, covers the committed K3 source root, charges the exact boundary instance/ceilings, and records the anchor. `anchorClaimedBoundary` requires a non-optional use-receipt ID previously claimed for the same exact branch and performs only root/permit/instance anchoring; it cannot claim or widen a sibling branch. Canonical self-ID-free use/anchor payload bytes are put through ordinary Artifact Mesh before that K4 CAS; an unreferenced artifact is harmless, while the K4 row is the sole committed claim/anchor truth and idempotently returns those same ordinary store receipts after restart. No transaction spans Artifact Mesh and K4. Both methods require `request.turnBranchRef.turnOperationRef == request.turnOperationRef`, byte-identical replay returns the same anchor store receipt, and same request/permit/instance with any changed root, branch, grant, owner epoch, or boot session is corruption. Once the exact anchor row exists, re-entry is a read-only equality check plus return of the stored receipt—it performs no second claim, charge, anchor mutation, or boundary widening, so lost-reply recovery has query semantics even though it uses the same bounded API. They never arm a boundary; only K3 can create `BASBoundaryArmReceipt`.

Implement all bodies inside the existing actor over exactly one helper-private SQLite connection. At open, set `journal_mode=WAL`, set `synchronous=FULL`, read both effective values back (`wal`, integer `2`), and quarantine on mismatch; never silently inherit the repository's current `NORMAL` defaults. Validate and canonicalize the supplied `BASCapabilityGrant`; store the unsigned grant through ordinary Artifact Mesh `put`; create the one generic `BASArtifactAttestationPayload` from Task 2 proof bytes and store it through the same `put`; persist the grant/attestation artifact IDs and nonce tombstone before replying with the ordinary store receipt. Reserve reopens `boundSubjectArtifactID`, compares every grant binding including the exact typed turn/branch, records an actor-owned non-transferable reservation under the stable tuple `(grantArtifactID, boundSubjectArtifactID, requestID)`, and returns `Void`. Claim accepts only that tuple, creates the single canonical self-ID-free `BASCapabilityUseReceipt`, stores it once through ordinary Artifact Mesh `put`, atomically records its store-receipt artifact ID as spent, and returns that ordinary `BASArtifactStoreReceipt`. `lookupCapabilityUseReceipt` returns the same stored receipt after a lost reply and never creates another payload. There is no capability-specific request envelope, issuance receipt, reservation permit, claim receipt, transport receipt, or caller-visible reservation ID.

Keep legacy `issueCommitToken`, `issueWarrant`, verification, revocation, and Codable bytes as v1 projections over the same authority; add a storage-backed production initializer and make actor-memory/null initializers test-only so they cannot satisfy the iOS 27 release composition protocol. Extend `BASSovereignLedgerSQLiteStorage` rather than adding a K4 service/store. Migration 014 is append-only after SQL 009 and creates lifecycle/tombstone/halt/anchor/version/K3-root tables plus one generic boundary-instance anchor table in that same database lineage. Enforce unique request ID, global nonce tombstone, grant/subject/exact-turn-branch reservation, one use-receipt artifact ID, unique `(permitArtifactID, boundaryInstanceID)`, non-overlapping monotonic branch-instance ranges/ceilings, monotonic halt epoch, and one current signed anchor per host version. Never delete tombstones, boundary anchors, or halt evidence during revoke, expiry, compaction, key rotation, or migration.

The K4 rollback anchor binds the exact K3 control-nucleus tuple `(databaseEpoch, highWaterMark, rootArtifactID, deletionEpoch, schemaVersion)`. K4 does not own K3 rows and K3 does not open K4 storage: the Enhanced Security request presents a signed/canonical tuple, K4 rejects HWM/root/deletion/schema regression or a same-epoch fork, and accepted anchor state is committed under `FULL` before reply. `BASSovereignSnapshotManager` and `BASSovereignCleanRebootCoordinator` become cache/projection APIs over this storage; their current dictionaries cannot remain restart authority.

Add failpoints immediately before and after every issue/reserve/claim/boundary-anchor/halt/root-anchor/rotate/migrate commit and reply; include power-loss tests, not only orderly process restart. Cover v1 upgrade, schema downgrade refusal, rollback, missing historical key, audit-link discontinuity, reboot/expiry, cross-grant nonce reuse, exact-branch mismatch, duplicate boundary instance, owner/boot loss, K3 fork/regression, and a failed `FULL` read-back. Corruption or incomplete history quarantines the authority. `BASSovereignAuditLedger` remains unchanged and receives lifecycle observations; it is not the mutable lifecycle store.

- [ ] **Step 3: Run K4 and existing ledger/token regressions**

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASK4AuthorizationLedgerTests|BASSovereignTokenAuthorityTests|BASSovereignLedgerAtomicityTests|BASSovereignLedgerSQLiteStorageTests|BASSovereignAuditLedgerReloadVerifyTests|BASEBrainSchemaGovernanceRegistryTests'
```

- [ ] **Step 4: Commit**

After Task 3's storage-backed production initializer and source gates prove null/actor-memory K4 state is test-only and unreachable in shipping composition, remove exactly that `retire` entry from `sovereign.k4-durable-lifecycle.current_conflicts`, transition its status from `converging` to `implemented`, and run the shared checker plus checker unit tests before staging.

```bash
python3 scripts/check_qinao_owner_ledger.py --root "$PWD" --ledger "$PWD/docs/superpowers/specs/qinao-owner-ledger-v1.json"
python3 scripts/test_check_qinao_owner_ledger.py -v
git add docs/superpowers/specs/qinao-owner-ledger-v1.json BehavioralAISubstrate/Sources/BASSovereign/BASSovereignTokenAuthority.swift BehavioralAISubstrate/Sources/BASSovereign/BASSovereignLedgerStorage.swift BehavioralAISubstrate/Sources/BASSovereign/BASSovereignSnapshotManager.swift BehavioralAISubstrate/Sources/BASSovereign/BASSovereignCleanRebootCoordinator.swift BehavioralAISubstrate/Sources/BASSovereign/SQL/014_sovereign_capability_lifecycle.sql BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASK4AuthorizationLedgerTests.swift
git commit -m "feat: persist k4 authorization lifecycle"
```

### Task 4: L13 StatePrepare, StateCommit, Staging, and Sealed Activation

**Files:**
- Modify [schema governance]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Modify [schema governance tests]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`
- Modify [E — typed discriminator only]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventPayloadKind.swift`
- Modify [E — sole event truth and base port]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLog.swift`
- Modify [E — sole K3 database/connection/WAL/writer]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift`
- Create [E — typed payloads plus specialized port, no mutable owner]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASStateCommitContracts.swift`
- Modify [E — K4 creates seal attestation, not K3 state]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASSovereign/BASSovereignTokenAuthority.swift`
- Create [test]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASStateCommitActivationTests.swift`
- Create [test]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASBudgetLeaseControlTests.swift`

**Reuse Decision: E only. OwnerLedger explicitly forbids an independent `BASStateCommitStore` M owner.**

**Extension Proof (E — exactly eight reuse gates; no production M owner):**

1. Repository search and existing candidates: run `rg -n 'BASEventLogEntry|BASEventLogStorage|BASSQLiteEventLogStorage|BASMemoryMutationEventEmitter|stage|activate' BehavioralAISubstrate/Sources`; event order and integrity remain in the existing log lineage.
2. Apple/public/upstream primitives: reuse the existing SQLite/WAL transaction, file-protection, secure-delete, and CAS policy; no new WAL, event cursor, hash chain, or transaction engine is needed.
3. Absent invariant: the repository lacks an atomic K3 operation that appends the canonical event and updates invisible staged/head/outbox/projector lifecycle under the same SQLite commit, and it lacks crash-durable compare-and-swap consumption of the already-declared turn budget lease; it does not lack another store.
4. Why a new M owner is wrong: an independent staging database would split event truth from state truth and make the event-append/stage gap unrecoverable without a second cursor or compensating protocol. The correct seam is a specialized port over the existing event-log owner.
5. Single authority/state/storage/failure boundary: L13/L14 decide content/seal; one `BASSQLiteEventLogStorage` connection owns exactly prepare/stage/seal/activate transitions plus event/integrity/HWM, Attempt/head, Contracts Task 2A's `BASBudgetLeaseControlPort` install/use/digest/witness rows and `BASProviderBranchControlPort` allocation/claim/event-head/terminal-source/visibility rows, outbox reference, projector cursor, boundary permit, and deletion epoch. K4 owns only capability use/anchor receipts plus generic seal attestation; it never spends semantic budget. Conflict/corruption fails closed.
6. Dependency/no-second-truth proof: runtime → `BASK3ControlNucleusStorage` port → existing `BASSQLiteEventLogStorage`; K4 and Zone C cannot mutate K3 rows, K3 cannot write Zone-C rows, and there is no BASMemory state-commit database, second writer, second WAL, or second transaction coordinator.
7. Compatibility/retirement: current memory mutation projections remain readers; direct mutation becomes explicit V1 rollback/test-only after cutover and retires after replay/crash gates.
8. Mutation/crash/replay/duplicate-authority tests: mutate every budget lease/use/envelope/invocation/witness/digest/edge/depth/revision/epoch plus artifact/seal/head/provider-branch/terminal-source binding; inject failure before/after every statement, commit, and reply boundary; hard-kill/reopen the one database; replay identical events/claims; and fail if budget double-spends, a stopped loop reaches any mechanism, event exists without its required staged lifecycle, staged lifecycle exists without its event, an unclaimed/nonterminal Provider proposal becomes spool source, unsealed bytes are visible, a second database/writer orders commit, Zone C activates state, or K3 represents dispatch/ack/indeterminate/reconcile.

**Interfaces:**

- Consumes: `BASArtifactID`, `BASArtifactStorePort`, `BASTurnOperationRef`, `BASTurnBranchRef`, Task 2A's self-ID-free `BASBudgetLeasePayload`/`BASBudgetUseReceipt`/control-loop evidence values and `BASBudgetLeaseControlPort`, its `BASProviderBranchControlPort` and canonical `BASProviderBranchPolicy`/`BASProviderBranchStepRule` artifact values, existing `BASEventLogEntry`/`BASEventLogStorage`, one terminal-or-indeterminate effect-receipt artifact ID plus the shared low-entropy `BASEffectTerminalOutcome` declared in this task (Task 5's `BASEffectReceiptPayload` uses that same enum), the sole `BASCapabilityUseReceipt` artifact ID, `BASBoundaryAnchorReceipt`, and one generic `BASArtifactAttestationPayload`.
- Produces: typed budget-use rows/recovered outcomes plus state/outbox payloads rooted in one turn operation, one immutable `BASEffectCausalPredecessorPayload` referenced once by each model-originated effect outbox, the one K3-pinned terminal-answer-source Provider receipt consumed by `BASResponseSpoolPayload`, `BASProviderEgressBoundaryPermit`, `BASStreamBatchBoundaryPermit`, `BASPublicationBoundaryPermit`, `BASEffectBoundaryPermit`, `BASK3BoundarySourceCommit`, `BASBoundaryArmReceipt`, the transient query-only `BASK3ActivatedStateEvidence`, and `BASK3ControlNucleusStorage: BASEventLogStorage, BASBudgetLeaseControlPort, BASProviderBranchControlPort`; `BASSQLiteEventLogStorage` is the only production conformer of all three public views plus the package-only egress-handoff view. State-commit transition vocabulary remains exactly prepare/stage/seal/activate; budget, Provider branch, and boundary-fence rows are the existing K3 owner's orthogonal guards, not extra global reducers or another event sequence.

- [ ] **Step 1: Write prepare/commit/CAS/seal tests**

```swift
func testPrepareEncodingCannotContainUnknownResultOrNewStateIdentity() throws {
    let encoded = try JSONEncoder().encode(fixtureStatePreparePayload())
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    XCTAssertNil(object["providerResultDigest"])
    XCTAssertNil(object["newStateDigest"])
    XCTAssertNil(object["newStateArtifactID"])
}

func testPrepareAndOutboxSurviveAsOneTransaction() async throws {
    let k3 = try makeK3ControlNucleus(failpoint: .afterPrepareAndOutboxCommitBeforeReply)
    do {
        _ = try await k3.prepareAndEnqueue(
            prepareArtifactID: fixtureStatePrepareArtifactID(),
            prepare: fixtureStatePreparePayload(),
            outboxArtifactID: fixtureStateEffectOutboxArtifactID(),
            outbox: fixtureStateEffectOutboxPayload()
        )
        XCTFail("injected reply loss must surface")
    } catch { }
    let reopened = try reopenK3ControlNucleus()
    let recovered = try await reopened.preparedOutbox(
        turnOperationRef: fixtureTurnOperationRef(),
        effectBranchRef: fixtureEffectBranchRef(ordinal: 0)
    )
    XCTAssertEqual(recovered, fixtureStateEffectOutboxPayload())
}

func testStateLifecycleInputsRequireExactStoredArtifactBodiesAndPairedOutbox() async throws {
    for mutation in StateLifecycleArtifactHandleMutation.allCases {
        let fixture = try await makeStateLifecycleFixture(mutation: mutation)
        await XCTAssertThrowsErrorAsync {
            try await fixture.k3.prepareAndEnqueue(
                prepareArtifactID: fixture.prepareArtifactID,
                prepare: fixture.prepare,
                outboxArtifactID: fixture.outboxArtifactID,
                outbox: fixture.outbox
            )
        }
        let preparedCount = await fixture.k3.preparedStateCountForTesting()
        XCTAssertEqual(preparedCount, 0)
    }
}

func testNoEffectPrepareUsesNilOutboxIDAndBodyTogether() async throws {
    let fixture = try await makeNoEffectStateLifecycleFixture()
    try await fixture.k3.prepareAndEnqueue(
        prepareArtifactID: fixture.prepareArtifactID,
        prepare: fixture.prepare,
        outboxArtifactID: nil,
        outbox: nil
    )
    let prepared = try await fixture.k3.preparedState(
        turnOperationRef: fixture.turnOperationRef
    )
    XCTAssertNil(prepared.outboxArtifactID)
}

func testStageRequiresExactStoredCommitHandleAndEventReference() async throws {
    for mutation in StateStageArtifactHandleMutation.allCases {
        let fixture = try await makePreparedStateLifecycleFixture(
            stageMutation: mutation
        )
        await XCTAssertThrowsErrorAsync {
            try await fixture.k3.appendAndStage(
                event: fixture.event,
                commitArtifactID: fixture.commitArtifactID,
                commit: fixture.commit
            )
        }
        let stagedCount = await fixture.k3.stagedStateCountForTesting()
        XCTAssertEqual(stagedCount, 0)
    }
}

func testSealRequiresExactStoredAttestationHandleAndCommitBinding() async throws {
    for mutation in StateSealArtifactHandleMutation.allCases {
        let fixture = try await makeStagedStateLifecycleFixture(
            sealMutation: mutation
        )
        await XCTAssertThrowsErrorAsync {
            try await fixture.k3.seal(
                attestationArtifactID: fixture.attestationArtifactID,
                attestation: fixture.attestation
            )
        }
        let sealedCount = await fixture.k3.sealedStateCountForTesting()
        let visibleHead = try await fixture.k3.visibleHead()
        XCTAssertEqual(sealedCount, 0)
        XCTAssertEqual(visibleHead, fixture.parentVersion)
    }
}

func testEffectPrepareReopensExactProviderCausalPredecessorBeforeAllocatingEffect() async throws {
    for mutation in EffectCausalPredecessorMutation.allCases {
        let fixture = try await makeSealedProviderEffectFixture(causalMutation: mutation)
        await XCTAssertThrowsErrorAsync {
            _ = try await fixture.k3.prepareAndEnqueue(
                prepareArtifactID: fixture.prepareArtifactID,
                prepare: fixture.prepare,
                outboxArtifactID: fixture.outboxArtifactID,
                outbox: fixture.outbox
            )
        }
        let effectAllocationCount = await fixture.k3.effectAllocationCountForTesting()
        let handedOffCount = await fixture.k3.effectHandOffCountForTesting()
        XCTAssertEqual(effectAllocationCount, 0)
        XCTAssertEqual(handedOffCount, 0)
    }
}

func testEffectOutboxReferencesOneCausalArtifactWithoutCopyingProviderTruth() throws {
    let encoded = try JSONEncoder().encode(fixtureStateEffectOutboxPayload())
    let keys = Set(try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any]).keys)
    XCTAssertTrue(keys.contains("effectCausalPredecessorArtifactID"))
    XCTAssertTrue(keys.isDisjoint(with: [
        "sourceProviderEgressBranchRef", "sourceProviderExecutionRef",
        "sourceProviderProposalArtifactID", "sourceProviderEventHeadSealReceiptArtifactID",
        "completeProviderBranchChainArtifactID"
    ]))
}

func testRemoteProviderEgressNeedsExactK3K4K3Fence() async throws {
    for mutation in ProviderEgressBoundaryMutation.allCases {
        let fixture = try await makeRemoteProviderEgressFixture(mutation: mutation)
        await XCTAssertThrowsErrorAsync {
            let source = try await fixture.k3.prepareProviderEgressBoundary(
                fixture.permit
            )
            let anchorReceipt = try await fixture.k4.anchorClaimedBoundary(
                fixture.anchorRequest(source: source)
            )
            _ = try await fixture.k3.armBoundary(
                source: source,
                anchorReceiptArtifactID: anchorReceipt.body.artifactID,
                anchor: try await fixture.reopenAnchor(anchorReceipt)
            )
        }
        let transportCallCount = await fixture.transport.callCount
        XCTAssertEqual(transportCallCount, 0)
    }
}

func testK3CannotArmBoundaryWithoutExactAnchorAndLiveAttempt() async throws {
    let k3 = try makeK3ControlNucleus()
    let pending = try await k3.prepareEffectBoundary(
        fixtureEffectBoundaryPermit(state: .handedToZoneC)
    )
    await XCTAssertThrowsErrorAsync {
        _ = try await k3.armBoundary(
            source: pending,
            anchorReceiptArtifactID: artifactID("wrong-anchor"),
            anchor: fixtureBoundaryAnchorReceipt(turnBranchRef: fixtureSiblingEffectBranchRef())
        )
    }
    let boundaryState = try await k3.boundaryState(pending.permitArtifactID)
    let adapterCallCount = await fixtureAdapterCallCount()
    XCTAssertEqual(boundaryState, .effectPermitPending)
    XCTAssertEqual(adapterCallCount, 0)
}

func testK3ArmCASHasExactlyOneWinnerAndBindsOwnerBootDeadline() async throws {
    let fixture = try await makePendingAnchoredEffectBoundary()
    async let first: BASBoundaryArmReceipt? = try? fixture.k3.armBoundary(
        source: fixture.source,
        anchorReceiptArtifactID: fixture.anchorArtifactID,
        anchor: fixture.anchor
    )
    async let second: BASBoundaryArmReceipt? = try? fixture.k3.armBoundary(
        source: fixture.source,
        anchorReceiptArtifactID: fixture.anchorArtifactID,
        anchor: fixture.anchor
    )
    let winners = await [first, second].compactMap { $0 }
    XCTAssertEqual(winners.count, 1)
    let boundaryState = try await fixture.k3.boundaryState(fixture.source.permitArtifactID)
    XCTAssertEqual(boundaryState, .effectBoundaryPossible)
}

func testProviderBranchControlSharesK3FullWALAndPinsOneTerminalSource() async throws {
    let k3 = try makeK3ControlNucleus()
    let root = fixtureTurnOperationRef()
    let firstAllocation = try await k3.allocateProviderBranch(
        fixtureProviderBranchAllocationRequest(
            turnOperationRef: root,
            providerBranchPolicyArtifactID: fixtureProviderBranchPolicyArtifactID(),
            stepRuleID: "grounding-step",
            requestedOutputRole: .internalProposal
        )
    )
    let secondAllocation = try await k3.allocateProviderBranch(
        fixtureProviderBranchAllocationRequest(
            turnOperationRef: root,
            providerBranchPolicyArtifactID: fixtureProviderBranchPolicyArtifactID(),
            stepRuleID: "answer-step",
            requestedOutputRole: .terminalAnswerCandidate,
            causalArtifactIDs: [firstAllocation.receiptArtifactID]
        )
    )
    let first = firstAllocation.providerEgressBranchRef
    let second = secondAllocation.providerEgressBranchRef
    let executionRef = fixtureProviderExecutionRef(branchRef: second)
    let terminal = try await k3.designateTerminalSource(
        fixtureProviderTerminalSourceRequest(
            branchRef: second,
            providerExecutionRef: executionRef
        )
    )
    _ = try await k3.claimProviderExecution(
        fixtureProviderExecutionClaimRequest(
            allocation: secondAllocation,
            providerExecutionRef: executionRef
        )
    )
    let terminalHead = try await k3.sealProviderEventHead(
        fixtureProviderEventHeadSealRequest(
            branchRef: second,
            eventHead: fixtureTerminalProviderEventHead()
        )
    )
    _ = try await k3.openProviderVisibilityGate(
        fixtureProviderVisibilityRequest(
            mode: .bufferedUntilVerified,
            terminalSource: terminal,
            sealedEventHead: terminalHead,
            requiredVerifierProposalReceiptArtifactIDs: fixtureVerifierProposalReceiptArtifactIDs(),
            l10AcceptanceReceiptArtifactID: fixtureL10AcceptanceReceiptArtifactID()
        )
    )

    let firstState = try await k3.providerBranchState(turnOperationRef: root, branchRef: first)
    let secondState = try await k3.providerBranchState(turnOperationRef: root, branchRef: second)
    let databaseCount = try await k3.databaseURLsForTesting().count
    let synchronous = try await k3.storagePragmasForTesting().synchronous
    XCTAssertNotEqual(first, second)
    XCTAssertEqual(firstAllocation.policyDerivedPurpose, .groundingProposal)
    XCTAssertEqual(secondAllocation.policyDerivedPurpose, .turnStep)
    XCTAssertEqual(terminal.providerEgressBranchRef, second)
    XCTAssertEqual(firstState, .allocated)
    XCTAssertEqual(secondState, .terminalSource)
    XCTAssertEqual(databaseCount, 1)
    XCTAssertEqual(synchronous, 2)
}

func testProductionProviderAllocationRequiresAtomicPolicyAndBindingAttachment() async throws {
    for attachment in ProviderHeadAttachmentFixture.invalidCases {
        let fixture = try await makeK3ProviderBranchFixture(headAttachment: attachment)
        await XCTAssertThrowsErrorAsync {
            _ = try await fixture.k3.allocateProviderBranch(fixture.nextAllocationRequest())
        }
        let rejectedAllocationCount = await fixture.k3.providerAllocationCountForTesting()
        XCTAssertEqual(rejectedAllocationCount, 0)
    }

    let fixture = try await makeK3ProviderBranchFixture(
        headAttachment: .atomicallyInstalledMatchingPolicyAndBinding
    )
    _ = try await fixture.k3.allocateProviderBranch(fixture.nextAllocationRequest())
    let acceptedAllocationCount = await fixture.k3.providerAllocationCountForTesting()
    XCTAssertEqual(acceptedAllocationCount, 1)
}

func testProviderBranchAllocationClaimAndTerminalPinRejectEveryAuthorityMutation() async throws {
    for mutation in ProviderBranchAuthorityMutation.allCases {
        let fixture = try await makeClaimedProviderBranchFixture()
        await XCTAssertThrowsErrorAsync {
            switch mutation {
            case .providerBranchPolicy, .stepRuleID, .requestedOutputRole, .causality, .planRootProof, .budget, .expectedHead:
                _ = try await fixture.k3.allocateProviderBranch(
                    mutation.apply(to: fixture.replayedAllocationRequest)
                )
            case .secondClaim:
                _ = try await fixture.k3.claimProviderExecution(fixture.claimRequest)
            case .nonTerminalPin, .siblingPin:
                _ = try await fixture.k3.designateTerminalSource(
                    mutation.apply(to: fixture.terminalSourceRequest)
                )
            case .visibilityBeforePin:
                _ = try await fixture.k3.openProviderVisibilityGate(fixture.visibilityRequest)
            case .missingIncrementalPolicy, .missingVerifierReceipt, .missingL10Acceptance:
                _ = try await fixture.k3.openProviderVisibilityGate(
                    mutation.apply(to: fixture.visibilityRequest)
                )
            case .allocationAfterVisibility:
                _ = try await fixture.k3.allocateProviderBranch(fixture.nextAllocationRequest)
            }
        }
    }
}

func testConcurrentProviderAllocationIsGaplessAndCallerCannotChooseOrdinal() async throws {
    let fixture = try makeK3ProviderBranchFixture()
    let requestA = fixture.nextAllocationRequest(requestID: "allocation-a")
    let requestB = fixture.nextAllocationRequest(requestID: "allocation-b")
    async let a = fixture.k3.allocateProviderBranch(requestA)
    async let b = fixture.k3.allocateProviderBranch(requestB)
    let (first, second) = try await (a, b)
    let ordinals = [first, second].map(\.providerEgressBranchRef.ordinal).sorted()
    XCTAssertEqual(ordinals, [0, 1])
    let encoded = try JSONEncoder().encode(requestA)
    let keys = Set(try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any]).keys)
    XCTAssertTrue(keys.isDisjoint(with: ["ordinal", "requestOrdinal", "purpose", "maximumInstances"]))
}

func testProviderBranchPolicyEnforcesMaximumAndAnswerOnlyWithoutCopiedPolicyFields() async throws {
    let fixture = try await makeProviderPolicyFixture(totalMaximumBranchCount: 2)
    _ = try await fixture.k3.allocateProviderBranch(
        fixture.allocationRequest(stepRuleID: "grounding-step", requestedOutputRole: .internalProposal)
    )
    let terminal = try await fixture.k3.allocateProviderBranch(
        fixture.allocationRequest(stepRuleID: "answer-step", requestedOutputRole: .terminalAnswerCandidate)
    )
    await XCTAssertThrowsErrorAsync {
        _ = try await fixture.k3.allocateProviderBranch(
            fixture.allocationRequest(stepRuleID: "verifier-step", requestedOutputRole: .internalProposal)
        )
    }
    await XCTAssertThrowsErrorAsync {
        _ = try await fixture.k3.sealProviderEventHead(
            fixture.toolProposalEventHeadRequest(branchRef: terminal.providerEgressBranchRef)
        )
    }
}

func testIncrementalVisibilityRequiresFrozenPolicyAndPerChunkVerificationEvidence() async throws {
    let fixture = try await makePinnedIncrementalProviderBranchFixture()
    await XCTAssertThrowsErrorAsync {
        _ = try await fixture.k3.openProviderVisibilityGate(
            fixture.visibilityRequest(removing: .incrementalVerificationPolicyReceipt)
        )
    }
    _ = try await fixture.k3.openProviderVisibilityGate(
        fixture.visibilityRequest(
            mode: .incrementalVerified,
            incrementalVerificationPolicyReceiptArtifactID: fixture.policyReceiptArtifactID
        )
    )
    await XCTAssertThrowsErrorAsync {
        _ = try await fixture.k3.allocateProviderBranch(fixture.nextAllocationRequest)
    }
    XCTAssertEqual(fixture.streamSinkCallCount, 0) // stream permit/anchor/arm still gates physical visibility
}

func testPublicationPendingRequiresExactVisibilityCloseAndThroughVisibilityChain() async throws {
    for mutation in PublicationVisibilityCloseMutation.allCases {
        let fixture = try await makeInstalledPublicationPreparationFixture(mutation: mutation)
        await XCTAssertThrowsErrorAsync {
            _ = try await fixture.k3.preparePublicationBoundary(fixture.permit)
        }
        let pendingCount = await fixture.k3.publicationPermitPendingCountForTesting()
        let anchorCount = await fixture.k4.boundaryAnchorCountForTesting()
        XCTAssertEqual(pendingCount, 0)
        XCTAssertEqual(anchorCount, 0)
    }
}

func testK3VocabularyAndSchemaRejectEveryZoneCTransition() throws {
    XCTAssertEqual(
        Set(BASK3StateCommitTransition.allCases.map(\.rawValue)),
        Set(["prepare", "stage", "seal", "activate"])
    )
    for forbidden in ["dispatch", "ack", "indeterminate", "reconcile"] {
        let encoded = try JSONEncoder().encode(forbidden)
        XCTAssertThrowsError(
            try JSONDecoder().decode(BASK3StateCommitTransition.self, from: encoded)
        )
        XCTAssertFalse(BASSQLiteEventLogStorage.k3SchemaSQLForTesting.contains(forbidden))
    }
}

func testStagedStateIsInvisibleUntilMatchingSeal() async throws {
    let k3 = try makeK3ControlNucleus()
    _ = try await k3.prepareAndEnqueue(
        prepareArtifactID: fixtureStatePrepareArtifactID(),
        prepare: fixtureStatePreparePayload(expectedVersion: 4),
        outboxArtifactID: fixtureStateEffectOutboxArtifactID(),
        outbox: fixtureStateEffectOutboxPayload()
    )
    _ = try await k3.appendAndStage(
        event: fixtureStateCommitEventEntry(
            eventID: "event-1",
            commitArtifactID: fixtureCommitArtifactID()
        ),
        commitArtifactID: fixtureCommitArtifactID(),
        commit: fixtureStateCommitEventPayload(
            expectedVersion: 4,
            newStateArtifactID: fixtureStateArtifactID(version: 5)
        )
    )
    let headBeforeSeal = try await k3.visibleHead()
    XCTAssertEqual(headBeforeSeal, 4)
    try await k3.seal(
        attestationArtifactID: fixtureSealAttestationArtifactID(),
        attestation: fixtureSealAttestation(
            targetArtifactID: fixtureCommitArtifactID()
        )
    )
    let headBeforeActivation = try await k3.visibleHead()
    XCTAssertEqual(headBeforeActivation, 4)
    try await k3.activate(commitArtifactID: fixtureCommitArtifactID())
    let headAfterActivation = try await k3.visibleHead()
    XCTAssertEqual(headAfterActivation, 5)
    let recoveredStateEvidence = try await k3.lookupActivatedStateEvidence(
        turnOperationRef: fixtureTurnOperationRef(),
        commitArtifactID: fixtureCommitArtifactID()
    )
    let stateEvidence = try XCTUnwrap(recoveredStateEvidence)
    XCTAssertEqual(stateEvidence.prepareArtifactID, fixtureStatePrepareArtifactID())
    XCTAssertEqual(stateEvidence.commitArtifactID, fixtureCommitArtifactID())
    XCTAssertEqual(
        stateEvidence.attestationArtifactID,
        fixtureSealAttestationArtifactID()
    )
    let foreignEvidence = try await k3.lookupActivatedStateEvidence(
        turnOperationRef: fixtureSiblingTurnOperationRef(),
        commitArtifactID: fixtureCommitArtifactID()
    )
    XCTAssertNil(foreignEvidence)
}

func testSameEventDifferentPayloadConflictsAndAppendFailureCannotFold() async throws {
    let k3 = try makeK3ControlNucleus()
    _ = try await k3.appendAndStage(
        event: fixtureStateCommitEventEntry(
            eventID: "event-1",
            commitArtifactID: fixtureCommitArtifactID(named: "commit-a")
        ),
        commitArtifactID: fixtureCommitArtifactID(named: "commit-a"),
        commit: fixtureStateCommitEventPayload(named: "commit-a")
    )
    do {
        _ = try await k3.appendAndStage(
            event: fixtureStateCommitEventEntry(
                eventID: "event-1",
                commitArtifactID: fixtureCommitArtifactID(named: "commit-b")
            ),
            commitArtifactID: fixtureCommitArtifactID(named: "commit-b"),
            commit: fixtureStateCommitEventPayload(named: "commit-b")
        )
        XCTFail("same event ID with different payload must conflict")
    } catch {
        XCTAssertEqual(error as? BASK3ControlNucleusError, .eventIdentityConflict)
    }
    let failing = try makeK3ControlNucleus(failpoint: .beforeEventAppendCommit)
    do {
        _ = try await failing.appendAndStage(
            event: fixtureStateCommitEventEntry(),
            commitArtifactID: fixtureCommitArtifactID(),
            commit: fixtureStateCommitEventPayload()
        )
        XCTFail("injected append failure must surface")
    } catch {
        XCTAssertEqual(error as? BASK3ControlNucleusError, .injectedFailure)
    }
    let stagedHead = try await failing.stagedHead()
    XCTAssertNil(stagedHead)
}

func testEventAppendAndStageAreOneFullTransactionInOneDatabase() async throws {
    let k3 = try makeK3ControlNucleus(failpoint: .afterEventInsertBeforeStageInsert)
    let pragmas = try await k3.storagePragmasForTesting()
    let connectionCount = try await k3.openConnectionCountForTesting()
    let databaseCount = try await k3.databaseURLsForTesting().count
    XCTAssertEqual(pragmas.journalMode, "wal")
    XCTAssertEqual(pragmas.synchronous, 2) // FULL
    XCTAssertEqual(connectionCount, 1)
    XCTAssertEqual(databaseCount, 1)

    await XCTAssertThrowsErrorAsync {
        _ = try await k3.appendAndStage(
            event: fixtureStateCommitEventEntry(eventID: "event-atomic"),
            commitArtifactID: fixtureCommitArtifactID(),
            commit: fixtureStateCommitEventPayload()
        )
    }
    let reopened = try reopenK3ControlNucleus()
    let entry = try await reopened.entry(eventID: "event-atomic")
    let stagedHead = try await reopened.stagedHead()
    XCTAssertNil(entry)
    XCTAssertNil(stagedHead)
}

func testEveryK3BoundaryPowerLossReopensToOldOrCompleteState() async throws {
    for boundary in BASK3Failpoint.everyStatementAndCommitBoundary {
        let recovered = try await runK3PowerLossAndReopen(failpoint: boundary)
        XCTAssertTrue(recovered.isOldStateOrFullyCommittedState)
        XCTAssertFalse(recovered.hasEventStageSplit)
        XCTAssertFalse(recovered.exposesUnsealedState)
        XCTAssertEqual(recovered.databaseFileCount, 1)
    }
}

func testConcurrentBudgetClaimsHaveOneWinnerAndNoLocalCounterCanSpend() async throws {
    let k3 = try await makeK3WithInstalledOneUseLoopLease()
    async let first = k3.claimBudgetUse(fixtureBudgetUseRequest(requestID: "use-a"))
    async let second = k3.claimBudgetUse(fixtureBudgetUseRequest(requestID: "use-b"))
    let outcomes = try await [first, second]
    XCTAssertEqual(outcomes.filter(\.isNewlyWonReceipt).count, 1)
    XCTAssertEqual(outcomes.filter(\.isBudgetExhaustedTerminal).count, 1)
    let state = try await k3.budgetLeaseState(turnOperationRef: fixtureTurnOperationRef())
    XCTAssertEqual(state.cumulativeBranches, 1)
    XCTAssertEqual(state.revision, 1)
}

func testBudgetClaimLostReplyReopensByteEqualWithoutDoubleSpend() async throws {
    let k3 = try makeK3ControlNucleus(failpoint: .afterBudgetUseCommitBeforeReply)
    let request = fixtureBudgetUseRequest(requestID: "stable-use")
    await XCTAssertThrowsErrorAsync { _ = try await k3.claimBudgetUse(request) }
    let reopened = try reopenK3ControlNucleus()
    let recovered = try await reopened.claimBudgetUse(request)
    XCTAssertTrue(recovered.isIdempotentlyRecoveredReceipt)
    let state = try await reopened.budgetLeaseState(turnOperationRef: request.turnOperationRef)
    XCTAssertEqual(state.cumulativeBranches, 1)
    XCTAssertEqual(state.revision, 1)
}

func testInvalidLoopEvidenceTerminatesBeforeAnyMechanismOrExternalOwner() async throws {
    for mutation in BASControlLoopBudgetMutation.allCases {
        let fixture = try await makeLoopBudgetFixture(mutation: mutation)
        let outcome = try await fixture.k3.claimBudgetUse(fixture.request)
        XCTAssertTrue(outcome.isProposalOnlyTerminal)
        XCTAssertEqual(fixture.layerCellCalls, 0)
        XCTAssertEqual(fixture.providerCalls, 0)
        XCTAssertEqual(fixture.k4Calls, 0)
        XCTAssertEqual(fixture.effectCalls, 0)
        XCTAssertEqual(fixture.stateActivationCalls, 0)
    }
}
```

The W2 boundary tests use a test-target-only `BASDeterministicBoundaryAnchoringConformer` of the Contracts W1 port. It returns ordinary governed anchor receipts from fixed fixtures and owns no SQLite, grant, claim, nonce, retry, sink, or production composition. A source/package test rejects any W2 reference to the later concrete K4 storage/initializer and proves every production boundary call site count is zero. W5 Task 3 replaces only that test conformer at composition with the real `BASSovereignTokenAuthority`; no Task 4 type or K3 method signature changes.

- [ ] **Step 2: Run RED, then extend the one K3 control nucleus**

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASStateCommitActivationTests|BASBudgetLeaseControlTests'
```

```swift
public enum BASEffectTerminalOutcome: String, Codable, Sendable, CaseIterable {
    case succeeded, failedBeforeDispatch, failedFinal, partial
    case cancelled, indeterminate, compensated
}

public struct BASEffectCausalPredecessorPayload: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let effectRequestArtifactID: BASArtifactID
    public let sourceProviderEgressBranchRef: BASTurnBranchRef
    public let sourceProviderExecutionRef: BASProviderExecutionRef
    public let sourceProviderProposalArtifactID: BASArtifactID
    public let sourceProviderEventHeadSealReceiptArtifactID: BASArtifactID
}

public struct BASStatePreparePayload: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let effectBranchRef: BASTurnBranchRef?
    public let expectedParentStateArtifactID: BASArtifactID
    public let expectedVersion: UInt64
    public let sourceEventID: String
    public let baseSnapshotArtifactID: BASArtifactID
    public let effectRequestArtifactID: BASArtifactID?
    public let allowedOutcomeSchemaArtifactID: BASArtifactID
    public let mutationConstraintArtifactID: BASArtifactID
    public let policyEpoch: UInt64
    public let deletionEpoch: UInt64
}

public struct BASStateEffectOutboxPayload: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let effectBranchRef: BASTurnBranchRef
    public let effectBoundaryInstanceID: String
    public let prepareArtifactID: BASArtifactID
    public let effectRequestArtifactID: BASArtifactID
    public let effectCausalPredecessorArtifactID: BASArtifactID
    public let recoveryPolicyArtifactID: BASArtifactID
    public let createdLogicalTime: UInt64
}

public struct BASStateCommitEventPayload: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let effectBranchRef: BASTurnBranchRef?
    public let prepareArtifactID: BASArtifactID
    public let expectedParentStateArtifactID: BASArtifactID
    public let expectedVersion: UInt64
    public let terminalEffectReceiptArtifactID: BASArtifactID?
    public let terminalEffectOutcome: BASEffectTerminalOutcome?
    public let orderedLaneMutationArtifactIDs: [BASArtifactID]
    public let baseSnapshotArtifactID: BASArtifactID
    public let policyEpoch: UInt64
    public let deletionEpoch: UInt64
    public let newStateArtifactID: BASArtifactID?
}

public enum BASK3StateCommitTransition: String, Codable, Sendable, CaseIterable {
    case prepare, stage, seal, activate
}

/// A transient read projection from the sole K3 writer. It is neither an
/// Artifact Mesh payload nor a receipt and therefore cannot become a second
/// state-lifecycle truth.
public struct BASK3ActivatedStateEvidence: Sendable, Equatable {
    public let turnOperationRef: BASTurnOperationRef
    public let prepareArtifactID: BASArtifactID
    public let outboxArtifactID: BASArtifactID?
    public let commitArtifactID: BASArtifactID
    public let eventID: String
    public let eventSequence: UInt64
    public let sourceRootArtifactID: BASArtifactID
    public let attestationArtifactID: BASArtifactID
    public let activeStateArtifactID: BASArtifactID?
    public let terminalEffectReceiptArtifactID: BASArtifactID?
    public let terminalEffectOutcome: BASEffectTerminalOutcome?
    public let policyEpoch: UInt64
    public let deletionEpoch: UInt64
}

/// W2 effect evidence vocabulary. Zone C later owns the reducer; these values
/// carry no dispatch implementation or mutable saga state.
public enum BASEffectRecoveryClass: String, Codable, Sendable, CaseIterable {
    case readOnly, idempotentWrite, queryableWrite, compensatable, irreversibleNonQueryable
}

public enum BASEffectDispatchBoundary: String, Codable, Sendable {
    case notCrossed, dispatchReadyDurable, localArmConsumed, providerCallStarted, providerReplyReceived
}

public struct BASEffectAdapterProfile: Codable, Sendable, Equatable {
    public let adapterID: String
    public let adapterVersion: String
    public let recoveryClass: BASEffectRecoveryClass
}

/// W2 value contract consumed by the W5 Zone-C producer. Its existence does
/// not enable dispatch; only the later broker can create a valid instance.
public struct BASEffectDispatchReadyReceiptPayload: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let effectBranchRef: BASTurnBranchRef
    public let effectBoundaryInstanceID: String
    public let outboxArtifactID: BASArtifactID
    public let toolInvocationArtifactID: BASArtifactID
    public let capabilityUseReceiptArtifactID: BASArtifactID
    public let requestDigest: String
    public let attemptRefArtifactID: BASArtifactID
    public let generationVectorArtifactID: BASArtifactID
}

public struct BASEffectReceiptPayload: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let effectBranchRef: BASTurnBranchRef
    public let effectBoundaryInstanceID: String
    public let outboxArtifactID: BASArtifactID
    public let toolInvocationArtifactID: BASArtifactID
    /// Identifies the governed `BASPersistedToolResultPayload`, never a raw
    /// independently persisted `BASToolResult`.
    public let toolResultArtifactID: BASArtifactID?
    public let capabilityUseReceiptArtifactID: BASArtifactID
    public let effectBoundaryPermitArtifactID: BASArtifactID
    public let boundaryAnchorReceiptArtifactID: BASArtifactID
    public let boundaryArmReceiptArtifactID: BASArtifactID
    public let executionBindingArtifactID: BASArtifactID?
    public let adapter: BASEffectAdapterProfile
    public let dispatchBoundary: BASEffectDispatchBoundary
    public let providerTransactionID: String?
    public let outcome: BASEffectTerminalOutcome
    public let observedStateArtifactID: BASArtifactID?
    public let parentEffectReceiptArtifactID: BASArtifactID?
}

public struct BASProviderEgressBoundaryPermit: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let payloadArtifactID: BASArtifactID
    public let destinationProfileDigest: String
    public let turnOperationRef: BASTurnOperationRef
    public let providerEgressBranchRef: BASTurnBranchRef
    public let egressBoundaryInstanceID: String
    public let attemptRefArtifactID: BASArtifactID
    public let generationVectorArtifactID: BASArtifactID
    public let policyEpoch: UInt64
    public let deletionEpoch: UInt64
    public let disclosureDecisionArtifactID: BASArtifactID
    public let authorizationGrantArtifactID: BASArtifactID
    public let capabilityUseReceiptArtifactID: BASArtifactID
    public let requestID: String
    public let boundaryOwnerEpoch: UInt64
    public let bootSessionID: String
}

public struct BASPublicationBoundaryPermit: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let terminalAnswerSourceProviderEgressBranchRef: BASTurnBranchRef
    public let finalPublicationBranchRef: BASTurnBranchRef
    public let publicationBoundaryInstanceID: String
    public let releasePreparationArtifactID: BASArtifactID
    public let replayManifestArtifactID: BASArtifactID
    public let spoolArtifactID: BASArtifactID
    public let terminalSourceReceiptArtifactID: BASArtifactID
    public let providerVisibilityReceiptArtifactID: BASArtifactID
    public let throughVisibilityProviderBranchChainArtifactID: BASArtifactID
    public let sinkProfileDigest: String
    public let attemptRefArtifactID: BASArtifactID
    public let generationVectorArtifactID: BASArtifactID
    public let policyEpoch: UInt64
    public let deletionEpoch: UInt64
    public let authorizationGrantArtifactID: BASArtifactID
    public let boundaryOwnerEpoch: UInt64
    public let bootSessionID: String
}

public struct BASStreamBatchBoundaryPermit: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let terminalAnswerSourceProviderEgressBranchRef: BASTurnBranchRef
    public let provisionalStreamBranchRef: BASTurnBranchRef
    public let streamBatchBoundaryInstanceID: String
    public let terminalSourceReceiptArtifactID: BASArtifactID
    public let providerVisibilityReceiptArtifactID: BASArtifactID
    public let orderedBatchVerificationReceiptArtifactIDs: [BASArtifactID]
    public let firstChunkIndex: UInt32
    public let lastChunkIndex: UInt32
    public let priorChainDigest: String
    public let resultingChainDigest: String
    public let byteCount: UInt64
    public let tokenCount: UInt64
    public let attemptRefArtifactID: BASArtifactID
    public let generationVectorArtifactID: BASArtifactID
    public let policyEpoch: UInt64
    public let deletionEpoch: UInt64
    public let authorizationGrantArtifactID: BASArtifactID
    public let capabilityUseReceiptArtifactID: BASArtifactID
    public let boundaryOwnerEpoch: UInt64
    public let bootSessionID: String
}

public struct BASEffectBoundaryPermit: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let effectBranchRef: BASTurnBranchRef
    public let effectBoundaryInstanceID: String
    public let outboxArtifactID: BASArtifactID
    public let dispatchReadyReceiptArtifactID: BASArtifactID
    public let attemptRefArtifactID: BASArtifactID
    public let generationVectorArtifactID: BASArtifactID
    public let policyEpoch: UInt64
    public let deletionEpoch: UInt64
    public let authorizationGrantArtifactID: BASArtifactID
    public let capabilityUseReceiptArtifactID: BASArtifactID
    public let boundaryOwnerEpoch: UInt64
    public let bootSessionID: String
}

public struct BASK3BoundarySourceCommit: Codable, Sendable, Equatable {
    public let permitArtifactID: BASArtifactID
    public let boundaryInstanceID: String
    public let turnOperationRef: BASTurnOperationRef
    public let turnBranchRef: BASTurnBranchRef
    public let sourceWatermark: UInt64
    public let sourceRootArtifactID: BASArtifactID
}

/// Transient read projection only; never ordinary-put or used to select a
/// "current" effect branch.
public struct BASK3PreparedEffectContextEvidence: Sendable, Equatable {
    public let turnOperationRef: BASTurnOperationRef
    public let effectBranchRef: BASTurnBranchRef
    public let effectBoundaryInstanceID: String
    public let outboxArtifactID: BASArtifactID
    public let boundSubjectArtifactID: BASArtifactID
    public let canonicalRequestDigest: String
    public let sourceK3RootArtifactID: BASArtifactID
}

/// Ephemeral, non-Codable result of the package-only handoff CAS. Only `.won`
/// from the current call is callable; `.alreadyPossible` is recovery/query-only.
package enum BASK3ProviderEgressHandoffOutcome: Sendable, Equatable {
    case won
    case alreadyPossible
}

/// Package-only view over the same K3 storage object. It is injected directly
/// into `BASProviderAttemptExecutor`; it is not part of either public K3 port.
package protocol BASK3ProviderEgressHandoffPort: Sendable {
    func beginProviderEgressHandoff(
        turnOperationRef: BASTurnOperationRef,
        providerEgressBranchRef: BASTurnBranchRef,
        providerExecutionRef: BASProviderExecutionRef,
        providerEgressBoundaryArmReceiptArtifactID: BASArtifactID
    ) async throws -> BASK3ProviderEgressHandoffOutcome
}

public protocol BASK3ControlNucleusStorage:
    AnyObject,
    BASEventLogStorage,
    BASBudgetLeaseControlPort,
    BASProviderBranchControlPort
{
    func prepareAndEnqueue(
        prepareArtifactID: BASArtifactID,
        prepare: BASStatePreparePayload,
        outboxArtifactID: BASArtifactID?,
        outbox: BASStateEffectOutboxPayload?
    ) async throws
    func appendAndStage(
        event: BASEventLogEntry,
        commitArtifactID: BASArtifactID,
        commit: BASStateCommitEventPayload
    ) async throws
    func seal(
        attestationArtifactID: BASArtifactID,
        attestation: BASArtifactAttestationPayload
    ) async throws
    func activate(commitArtifactID: BASArtifactID) async throws
    func lookupActivatedStateEvidence(
        turnOperationRef: BASTurnOperationRef,
        commitArtifactID: BASArtifactID
    ) async throws -> BASK3ActivatedStateEvidence?
    func handOffEffectToZoneC(
        turnOperationRef: BASTurnOperationRef,
        effectBranchRef: BASTurnBranchRef,
        outboxArtifactID: BASArtifactID
    ) async throws
    func lookupPreparedEffectContext(
        boundSubjectArtifactID: BASArtifactID,
        canonicalRequestDigest: String
    ) async throws -> BASK3PreparedEffectContextEvidence?
    func installPublicationPreparation(
        turnOperationRef: BASTurnOperationRef,
        terminalAnswerSourceProviderEgressBranchRef: BASTurnBranchRef,
        finalPublicationBranchRef: BASTurnBranchRef,
        releasePreparationArtifactID: BASArtifactID,
        replayManifestArtifactID: BASArtifactID,
        spoolArtifactID: BASArtifactID,
        terminalSourceReceiptArtifactID: BASArtifactID,
        providerVisibilityReceiptArtifactID: BASArtifactID,
        terminalPrefixProviderBranchChainArtifactID: BASArtifactID,
        throughVisibilityProviderBranchChainArtifactID: BASArtifactID,
        attemptRefArtifactID: BASArtifactID,
        generationVectorArtifactID: BASArtifactID,
        policyEpoch: UInt64,
        deletionEpoch: UInt64
    ) async throws
    func prepareProviderEgressBoundary(
        _ permit: BASProviderEgressBoundaryPermit
    ) async throws -> BASK3BoundarySourceCommit
    func preparePublicationBoundary(
        _ permit: BASPublicationBoundaryPermit
    ) async throws -> BASK3BoundarySourceCommit
    func prepareStreamBatchBoundary(
        _ permit: BASStreamBatchBoundaryPermit
    ) async throws -> BASK3BoundarySourceCommit
    func prepareEffectBoundary(
        _ permit: BASEffectBoundaryPermit
    ) async throws -> BASK3BoundarySourceCommit
    func armBoundary(
        source: BASK3BoundarySourceCommit,
        anchorReceiptArtifactID: BASArtifactID,
        anchor: BASBoundaryAnchorReceipt
    ) async throws -> BASBoundaryArmReceipt
}
```

Add explicit public initializers and `BASEventPayloadKind.stateCommit`; add `BASEventLogEntry.stateCommitEvent(...)` to encode a `BASStateCommitEventPayload` with sorted keys and the existing event identity/sequence rules. The payload has no commit ID/digest/signature. Store prepare, optional outbox, commit, causal-predecessor, attestation, and non-usable boundary-permit payloads through ordinary Artifact Mesh `put` before entering K3; an orphan artifact is harmless. `prepareAndEnqueue` receives the prepare Artifact ID/body plus an all-or-nothing optional outbox Artifact ID/body pair; `appendAndStage` receives the commit Artifact ID/body and rejects any event whose embedded commit reference differs; `seal` receives the attestation Artifact ID/body and reopens both before changing its row. K3 canonical-byte-equality-checks every supplied body against the already-durable Artifact Mesh object and transactionally stores only those references. The event references the commit artifact ID and remains the sole ordering/integrity truth. Every model-originated effect outbox references exactly one immutable `BASEffectCausalPredecessorPayload`; K3 reopens it before accepting the next non-reused `.effect` ordinal and equality-checks the same root/effect request, exact causal `.providerEgress` branch, complete `BASProviderExecutionRef`, proposal artifact, and K3 event-head-seal receipt against `BASProviderBranchControlPort` state. The source must be a policy-permitted internal proposal, never the answer-only terminal source, and its sealed proposal must name that exact effect request. A sibling/unsealed/rewritten proposal or mismatched execution field fails before effect allocation or prepare. The outbox carries only this causal artifact ID—not a copied Provider chain or future terminal/visibility truth—and Zone C may only follow the outbox/request IDs. Every effect-bearing prepare/outbox/commit then requires `effectBranchRef.kind == .effect`, `effectBranchRef.turnOperationRef == turnOperationRef`, and the K3-accepted stable ordinal. Every publication permit requires `.finalPublication` ordinal zero. Raw `operationID`, `turnID`, `branchID`, publication ID, and effect ID fields are forbidden as authority; an optional compatibility projection must decode back to and equality-check these exact typed refs.

`BASK3ControlNucleusStorage` is class-bound because same-K3 claims are object-identity invariants, not byte-equality claims. `BASSQLiteEventLogStorage` is the only production actor conformer; test conformers are actors/classes. Runtime, effect resolution, audit persistence, replay, and Qinao composition may compare that same actor reference directly. A value conformer, existential reboxing through `AnyObject`, or two equivalent SQLite handles cannot satisfy the gate.

Pin `StateStageArtifactHandleMutation.allCases` to missing commit artifact, same ID/different bytes, commit-ID/body mismatch, event/commit-reference mismatch, foreign turn/root, wrong parent/version, and reordered lane mutations. Pin `StateSealArtifactHandleMutation.allCases` to missing attestation, same ID/different bytes, wrong target commit, missing/foreign capability-use receipt, wrong policy epoch, and attestation replay onto a sibling staged row. Every stage mutation leaves no staged row; every seal mutation leaves the valid staged row invisible and unsealed.

At turn admission, the same `BEGIN IMMEDIATE … COMMIT` that installs `BASTurnOperationRef` and advances the active Attempt reopens the exact `budgetLeaseArtifactID`, bounded-decodes `BASBudgetLeasePayload`, equality-checks Attempt/generation/grant/policy/deletion/boot/deadline facts, and inserts one zero-spend lease row. `claimBudgetUse` reopens the exact already-stored envelope, invocation, optional parent use/witness, and active lease; checks their root/ring/edge/depth/branch/deadline/epoch equality; verifies the child is strictly deeper, the candidate digest is absent from the K3 visited set, and the phase-specific witness proves strict monotonic progress; then CASes the expected revision while atomically inserting the unique request/invocation/envelope/digest row and cumulative reserved token/byte/branch/remand/hop/cost/time counters. The same idempotency request returns byte-equal evidence after a lost reply; the same ID with changed bytes is corruption. Exhaustion, repeated/A↔B digest, missing/false witness, stale epoch, illegal edge/depth/branch/deadline, or post-effect regeneration inserts one typed proposal-only terminal outcome without spend and returns it idempotently. Only `converged + convergedVerified` terminal evidence is structurally adoptable downstream; K3 does not choose its semantic content. A `BASLayerSlice`, copied remaining count, Artifact Mesh receipt by itself, or Runtime-local set cannot reserve, spend, recover, or widen a lease. Query returns the K3 row/root and reconstructed canonical evidence; replay ordinary-puts/reopens that value only as an immutable projection. No LayerCell, Provider, K4, effect, state-activation, or publication call happens inside this port.

Extend `BASSQLiteEventLogStorage` to conform to `BASK3ControlNucleusStorage`; do not create a concrete sibling store. Its one actor-isolated SQLite handle owns the budget rows above and only the four K3 state-commit transitions `prepare`, `stage`, `seal`, and `activate`; budget claim is an orthogonal guard, and persisting the outbox artifact reference is part of `prepare`, not a fifth state transition. Because an effect branch is non-streaming and permits exactly one boundary instance, `effectBoundaryInstanceID` is the versioned canonical instance-zero projection of the exact `effectBranchRef`; the outbox may carry that projection before `put`, but `prepareAndEnqueue` recomputes it and atomically installs the sole accepted value with the validated causal predecessor, next effect ordinal, Attempt/head/root/branch/outbox rows. Qinao/Zone C cannot choose or replace it, and a free string fails decode. `installPublicationPreparation` is the sole K3 publication install and intentionally accepts only low-entropy IDs/typed refs available in W2. The W5 release coordinator first reopens and fully validates the governed spool, release-preparation, replay manifest, and both chain payloads in their owning modules. K3 then verifies that every supplied Artifact ID exists under the expected Attempt scope, equality-checks the terminal-source receipt/prefix ID, mode-specific visibility receipt/through-visibility ID, final branch, Attempt/generation/epochs, and latest joint coverage head against its own rows, and idempotently installs only that immutable ID tuple as K3-local `prepared`. K3 never imports or decodes a later W5/W6 high-level payload type, trusts a copied watermark vector, or opens the publication journal. A journal reservation failure leaves a non-usable prepared tuple that only the same IDs may resume or retire. `handOffEffectToZoneC` is the only owner transition from effect prepared to `handed_to_zone_c`, equality-checks that same active Attempt/root/branch/instance/outbox/causal-predecessor tuple, and exposes only the recovered outbox artifact reference. After a terminal/indeterminate effect receipt, `appendAndStage` requires `terminalEffectReceiptArtifactID` and `terminalEffectOutcome` to be either both nil for a no-effect commit or both present for an effect commit. In the latter case it reopens Task 5's receipt through Artifact Mesh and requires exact equality with that receipt's shared `BASEffectTerminalOutcome`; K3 never chooses or stores a second disposition vocabulary. It then uses the existing internal event append/integrity/HWM statements and the stage/head statements inside the same `BEGIN IMMEDIATE … COMMIT`; it must not call a public append method that commits early. One failure rolls the whole unit back, so replay never repairs an event/stage split.

Pin `EffectCausalPredecessorMutation.allCases` to root, effect-request, Provider-branch parent/kind/ordinal, every `BASProviderExecutionRef` field, proposal artifact, event-head-seal receipt, policy role/`answerOnly`, sealed-head, and proposal-to-effect-request linkage mutations. Every case must leave effect-allocation, prepare, handoff, K4 claim, boundary pending/anchor/arm, and adapter-call counts at zero.

That same actor/connection also implements Contracts Task 2A's six-method `BASProviderBranchControlPort` exactly—allocation, claim, event-head seal, terminal-source designation, visibility open, and branch-state lookup—and no public handoff method is added. In W4, Silicon ordinary-puts one immutable `BASProviderBranchPolicy`, one receipt-bound `BASPersistedOrganDescriptorPayload` wrapping the canonical `BASOrganDescriptor`, and one `BASSiliconExecutionBinding` that references the policy; K3 atomically installs policy/binding IDs, treats the binding/descriptor parent as opaque, and stores the exact `selectedProviderDescriptorArtifactID` in the allocation row plus allocation/claim receipts. Production allocation remains disabled until the policy/binding pair is jointly attached. The request contains no ordinal, caller-selected purpose, containment class, count, causality rule, `answerOnly`, or visibility rule; it carries the installed policy ID, one `stepRuleID`, requested role, descriptor-parent Artifact ID, plan/root proof, ordered causes, budget/deadline, and expected head. K3 derives the canonical `BASProviderStepPurpose` and permitted `BASProviderOutputRole` from that policy rule, allocates the sole ordinal, and freezes the opaque route identity; claim consumes the canonical sequence-zero `BASProviderExecutionRef` exactly once.

The existing seal request/receipt carries exactly two paired optional Artifact IDs: `providerEgressBoundaryArmReceiptArtifactID` and `providerObservedReceiptArtifactID`. Local `inProcessCertified` execution requires both nil; isolated/remote execution requires both nonnil. Silicon's executor derives that rule only from the allocation/claim-receipt-bound descriptor and validates provider/plan/payload/destination before invocation; K3 never parses those BASOrgan values. For remote success, K3 reopens the self-ID-free `BASProviderObservedReceipt`, exact allocation/claim/handoff rows, and arm→permit/anchor evidence; requires root/branch, sequence-zero claim, terminal event stable fields/sequence, descriptor ID, Attempt/generation/epochs/grant/use equality and a structurally complete terminal result; and atomically advances `sent_or_unknown → terminal_or_indeterminate` in the same transaction that stores the event-head seal/receipt and both evidence IDs. Missing/incomplete/foreign observation rolls the whole transaction back. Replay follows the lineage entry's existing allocation/claim/seal receipt references to reopen descriptor and paired egress evidence; no lineage/manifest egress array exists. Same-request replay is idempotent, but `sent_or_unknown` without authenticated terminal evidence is nonterminal, nonpublishable, and query-only.

A policy-derived `terminalAnswerCandidate` must still win `designateTerminalSource` before its answer-mode call. The later seal and visibility gate equality-check that pin and the complete causal branch chain. Missing or half-installed policy/binding, descriptor substitution, policy/rule/proof mutation, disallowed role, count exhaustion, gap/reuse, concurrent duplicate ordinal, second claim/call, sibling source, missing cause, answer-only tool proposal, post-visibility allocation, or changed observation fails closed. All rows and receipts extend the same `FULL` EventLog root; no registry, local ordinal/descriptor/policy/claim/source/visibility map, actor, store, connection, WAL, recovery loop, or second terminal CAS is introduced.

`openProviderVisibilityGate` receives a `BASProviderVisibilityMode` field only as a non-authoritative projection of the mode frozen in the jointly installed `BASProviderBranchPolicy`; K3 reopens that policy, derives the mode, and requires equality, so neither the request nor `BASSiliconExecutionBinding` can choose or own visibility semantics. `.incrementalVerified` binds the pre-call frozen deterministic incremental-verification policy receipt and later requires the matching per-chunk verification receipts; it does not display a byte. `.bufferedUntilVerified` binds the terminal Provider event head, every required `.verifierProposal` receipt causally authorized under the pinned source, and the L10 acceptance receipt. Missing/reordered/foreign evidence fails the K3 CAS. A successful gate permanently rejects further Provider allocation/claim/source replacement. Physical visibility remains separately impossible until each provisional stream batch or final publication wins its own K3 pending → K4 anchor → K3 arm sink fence.

The public boundary-fence methods are conditional transactions on the same K3 handle, not calls into K4, Zone C, a transport, or the publication journal. `prepareProviderEgressBoundary` applies only to isolated-extension/remote routes. It reopens the materialized request, L11/L14-approved destination/disclosure decision, K4 use receipt, K3 branch/claim and opaque selected-descriptor ID, active Attempt/generation/epochs, canonical instance-zero boundary, owner/boot epoch, and unused request ID; it does not parse BASOrgan or accept a restated containment class. It advances only `egress_prepared → egress_permit_pending`. K4 `anchorClaimedBoundary` covers that committed source root, and public `armBoundary` performs only `egress_permit_pending → egress_boundary_armed`.

The package-only `BASK3ProviderEgressHandoffPort` is a view over that exact same `BASSQLiteEventLogStorage` actor/connection, injected directly into `BASProviderAttemptExecutor.executeExactlyOnce`; no host, adapter, Qinao surface, or holder of either public K3 protocol can call it. Immediately before the executor's sole invoke closure, `beginProviderEgressHandoff` reopens the receipt-bound claim and descriptor ID, permit/anchor/arm, owner/boot epoch, and live deadline, then CASes `egress_boundary_armed → sent_or_unknown`. Only `.won` returned to that in-flight call may enter transport; exact replay returns non-callable `.alreadyPossible`. Successful authenticated terminal evidence enters the existing atomic `sealProviderEventHead` transaction described above. Crash before/during send, lost reply, or unsupported query remains `sent_or_unknown`; recovery queries/reconciles the same remote operation and may seal recovered evidence, but never sends or allocates again. A source scan permits `beginProviderEgressHandoff` only inside `BASProviderAttemptExecutor.executeExactlyOnce` and its focused tests.

`preparePublicationBoundary` requires the live Attempt/generation/epochs, exact root/pinned source/final branch, installed preparation/manifest/spool tuple, terminal-source receipt, mode-specific visibility row/receipt, latest joint coverage head, and validated through-visibility chain before advancing only `prepared → publication_permit_pending`. `prepareStreamBatchBoundary` additionally requires policy-derived `.incrementalVerified`, the exact pinned source and ordinal-zero stream, open matching visibility, claimed stream use receipt, and ordered deterministic checks over one contiguous range before `stream_permit_pending`; buffered mode and policy-only evidence are rejected. `lookupPreparedEffectContext(boundSubjectArtifactID:canonicalRequestDigest:)` is an exact-index, read-only query over the already-prepared outbox row: zero or more than one match, a nonactive Attempt, stale root/generation/epoch, wrong subject/digest, or non-`.effect` branch throws/fails nil and never falls back to a latest/current branch. It returns transient evidence only and performs no allocation, prepare, claim, handoff, or write. `prepareEffectBoundary` requires the matching K4 use receipt, Zone-C `DispatchReadyReceipt`, K3 `handed_to_zone_c`, and exact effect branch before `effect_permit_pending`. Every pending permit is non-usable.

For every boundary kind, `armBoundary` equality-checks the exact permit/anchor/source roots, still-live Attempt/generation/policy/deletion/owner/boot epochs, and monotonic deadline before its sole typed CAS. It stores canonical `BASBoundaryArmReceipt` bytes in the same row and returns a shorter handoff deadline; ordinary Artifact Mesh only reprojects those bytes. One winner exists; exact replay is read-only, conflicting denial proves no authorization, and after anchor uncertainty/owner loss/deadline expiry/emitted arm, recovery is query/reconcile/finalize-only with no replacement permit or arm.

Pin `PublicationVisibilityCloseMutation.allCases` to missing/foreign terminal-source receipt, missing/foreign visibility row or receipt, terminal-prefix/through-visibility chain mismatch, omitted/reordered post-pin verifier or L10 receipt, policy-derived mode mismatch, and sibling root/source/final-branch attachment. Every mutation must fail both install/prepare replay before publication pending, K4 anchor, K3 arm, or sink work.

For terminal sealing, the runtime calls the existing authority's exact `claimCapability(grantArtifactID:boundSubjectArtifactID:requestID:)` against the state-commit artifact, takes the returned ordinary store receipt's `body.artifactID` as the sole `BASCapabilityUseReceipt` artifact ID, and stores one generic `BASArtifactAttestationPayload` targeting that commit through ordinary Artifact Mesh `put`. K3 `seal(attestationArtifactID:attestation:)` reopens the attestation, records its Artifact ID plus the bound capability-use Artifact ID, and verifies their commit binding; `activate` atomically advances visible head, projector cursor, boundary-permit consumption, and the K3 root/HWM/deletion tuple only when there is no effect, the shared `terminalEffectOutcome == .succeeded`, or policy explicitly authorizes `.compensated`. Partial/cancelled/indeterminate never activate success. `lookupActivatedStateEvidence` is a fail-closed query over those same K3 rows: it returns a transient `BASK3ActivatedStateEvidence` only for the exact active turn/commit and exposes existing prepare/outbox/commit/event-root/attestation/state/effect handles without storing, signing, or ordinary-putting that projection. The query recomputes `sourceRootArtifactID` from the same EventLog integrity/HWM row and rejects any staged/sealed/active-root split; callers never supply that root. Runtime must repeat this exact K3 lookup, equality-check the whole projection, reopen every actual Artifact Mesh handle (including an optional outbox), and treat a nil `activeStateArtifactID` as legal only for a validated no-op state commit. K4 never writes K3 lifecycle rows.

Extend the current event-log schema/version lineage in `BASSQLiteEventLogStorage.swift` with K3 budget-lease/install/use/revision/visited-digest/terminal-outcome rows, Provider-branch allocation/claim/event-head/terminal-source/visibility rows, and prepare/outbox/staged/sealed/head/projector/boundary/deletion tables. Do not add a budget SQL resource/store, `SQL/026_state_commit_v1.sql`, a Provider registry schema, `EgressBroker`, a second database URL, or a second schema-version authority. Budget rows constrain exactly one lease per root, zero initial spend, unique idempotency request and envelope/invocation IDs, monotonic revision/cumulative ceilings, no repeated digest, strict parent/depth/edge/witness relation, and one idempotent terminal outcome for a denied claim; receipt artifacts never replace these rows. Provider rows constrain K3-only monotonic ordinals, one claim/call per branch, complete `ProviderExecutionRef`, exact causality/budget/binding, one pre-call terminal source, and a one-way visibility close. The state-commit tables constrain transitions to `prepare|stage|seal|activate`; the boundary table separately constrains exact rows to `egress_prepared|egress_permit_pending|egress_boundary_armed|sent_or_unknown|prepared|handed_to_zone_c|stream_permit_pending|publication_permit_pending|effect_permit_pending|visible_or_unknown|sink_boundary_armed|effect_boundary_possible|terminal_or_indeterminate` and contains no transport or Zone-C dispatch/ack/reconcile truth. Stream rows additionally constrain non-overlapping monotonic chunk ranges, prior/result chain heads, and cumulative grant ceilings. At connection open, set `journal_mode=WAL`, replace the current `synchronous=NORMAL` with `synchronous=FULL`, read back `wal` and integer `2`, and fail closed on mismatch. Keep file protection, integrity check, secure delete, and checkpointing in this same owner. Test budget install/use races, concurrent double-spend, repeated/A↔B digest, false/missing witness, cap/stale-epoch/illegal-edge rejection, crash/lost reply/reopen, post-effect reconciliation-only, allocation/claim/pin/visibility races, remote-erase versus pending/anchor/arm/handoff, concurrent egress double-consumption, crash-before-send, lost remote receipt, same-event/same-artifact idempotency, same-event/different-artifact conflict, head CAS loss, double-arm/range-overlap races, every pending→anchor→arm crash/owner/deadline boundary, all statement/commit power-loss boundaries, and absence of unsealed state from every visible-head API.

The same concrete storage also conforms to the package-only handoff port. Its Provider row stores the opaque selected-descriptor Artifact ID in allocation and claim receipts; its boundary row stores paired arm/observation IDs only inside the atomic terminal seal. Tests mutate descriptor identity/canonical bytes, Provider ID/containment, base-versus-event sequence fields, each observation field, request/receipt evidence pairing, handoff owner/deadline/CAS outcome, and every crash cut before/after `sent_or_unknown` and the terminal seal commit. They prove only the fresh package-only handoff winner invokes once, identical recovered terminal evidence seals idempotently, changed evidence corrupts/fails, and unresolved `sent_or_unknown` never reaches chain/spool/release. A source/link scan rejects any `beginProviderEgressHandoff` call outside `BASProviderAttemptExecutor` and focused K3 tests.

The duplicate-authority gate is executable:

```bash
test "$(rg -l 'BEGIN IMMEDIATE|sqlite3_open' BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift BehavioralAISubstrate/Sources/BASRuntimeCore/BASStateCommitContracts.swift | wc -l | tr -d ' ')" = "1"
test -z "$(rg -l 'actor BASStateCommitStore|class BASStateCommitStore|struct BASStateCommitStore' BehavioralAISubstrate/Sources)"
test -z "$(rg -l 'actor BASProviderBranch|class BASProviderBranchRegistry|struct BASProviderBranchStore' BehavioralAISubstrate/Sources)"
test -z "$(rg -l 'RSIManager|ControlLoopManager|BudgetLeaseManager|actor BASBudgetLease|class BASBudgetLease' BehavioralAISubstrate/Sources)"
test "$(rg -n '^public protocol BASBudgetLeaseControlPort' BehavioralAISubstrate/Sources --glob '*.swift' | wc -l | tr -d ' ')" = "1"
test "$(rg -n '^public protocol BASK3ControlNucleusStorage:' BehavioralAISubstrate/Sources --glob '*.swift' | wc -l | tr -d ' ')" = "1"
rg -A4 '^public protocol BASK3ControlNucleusStorage:' BehavioralAISubstrate/Sources --glob '*.swift' | rg -q 'AnyObject'
test -z "$(find BehavioralAISubstrate/Sources -path '*SQL*' -name '*state_commit*' -print)"
test -z "$(rg -n 'BASSiliconExecutionBinding' BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift BehavioralAISubstrate/Sources/BASRuntimeCore/BASStateCommitContracts.swift)"
```

- [ ] **Step 3: Run memory/event regressions and commit**

```bash
python3 /Users/changgeng/Project/Project06/Project06/scripts/check_qinao_owner_ledger.py --root /Users/changgeng/Project/Project06/Project06 --ledger /Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASStateCommitActivationTests|BASBudgetLeaseControlTests|BASEventSourcedMemoryAtomStoreTests|BASSQLiteStoreCrashRecoveryTests|BASMemoryAtomReplayDeterminismTests|BASEBrainSchemaGovernanceRegistryTests'
git add BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventPayloadKind.swift BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLog.swift BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift BehavioralAISubstrate/Sources/BASRuntimeCore/BASStateCommitContracts.swift BehavioralAISubstrate/Sources/BASSovereign/BASSovereignTokenAuthority.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASStateCommitActivationTests.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASBudgetLeaseControlTests.swift
git commit -m "feat: add sealed state prepare and commit"
```

### Task 5: Durable Zone-C Effect Broker and Five Recovery Classes

**Files:**
- Modify [ownership lifecycle]: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify [schema governance]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Modify [schema governance tests]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`
- Modify [E — governed persisted parent around the existing tool-result value]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrgan/BASOrganTool.swift`
- Modify [schema/compatibility tests]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASOrganToolTests.swift`
- Modify [E — target/product/test wiring for the M broker owner]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Package.swift`
- Create [M — sole Zone-C saga/reducer owner]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASEffectBroker/BASEffectBroker.swift`
- Create [storage for the same M owner]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASEffectBroker/BASEffectBrokerSQLiteStorage.swift`
- Create [schema for the same M owner]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASEffectBroker/SQL/001_effect_saga_v1.sql`
- Create [A — current tool dispatcher/provider boundary]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAppleEdgeWiring/BASToolEffectAdapter.swift`
- Modify [E — Qinao target imports the one broker product]: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Package.swift`
- Modify [E — bind the exact prepared subject into the existing risk permit]: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoRisk/QinaoRisk.swift`
- Modify [E — bind the same subject into the existing sovereign warrant]: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoSovereign/QinaoSovereign.swift`
- Modify [E — keep public facade, remove actor-local authority]: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift`
- Modify [E — bind the same subject into the existing signed snapshot proof]: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoSovereignSnapshotProof.swift`
- Create [A — stateless SDK-to-broker port/adapter]: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoEffectExecuting.swift`
- Modify [composition only — inject the exact same K3 and broker objects]: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift`
- Create [test]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEffectSagaCrashMatrixTests.swift`
- Create [test]: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoEffectFacadeBrokerTests.swift`

**Reuse Decision: A + M**

**Create Proof (production M — exactly eight gates):**

1. Repository search and existing candidates: run `rg -n 'BASToolInvocation|BASToolResult|actor BASToolDispatcher|BASToolInvocationGate|idempotency|reconcile' BehavioralAISubstrate/Sources/BASOrgan`; those payloads/gates stay canonical.
2. Apple/public/upstream primitives: Swift actors/`Task`, SQLite transactions/WAL, and provider idempotency/query APIs are sufficient mechanisms; no thread pool, daemon, custom protocol, or distributed transaction is introduced.
3. Absent invariant: the repository has no single durable Zone-C dispatch/ack/indeterminate/reconcile saga spanning the five recovery classes and no typed K3 `handed_to_zone_c` → K4 exact-branch claim → Zone-C `dispatch_ready` → K3 `effect_permit_pending` → K4 anchor → K3 arm → Zone-C consume fence; the public `QinaoRuntime.execute` facade currently bypasses any such saga.
4. Why E/composition/generics/A is insufficient: `QinaoRuntime` actor memory and `BASToolDispatcher` dispatch canonical calls but own no durable ambiguity/reconciliation state; a closure, thin adapter, `BASResult`, or composition cannot determine whether a provider call crossed the effect boundary after process death.
5. Single authority/state/storage/failure boundary: `BASEffectBroker` alone owns Zone-C dispatch/ack/indeterminate/reconcile plus local dispatch-ready/arm-consumption rows; K3 alone owns Attempt/outbox/pending/arm fences; L14/K4 remain authorization/claim/anchor owners; provider query/idempotency evidence drives recovery; corruption or unsupported ambiguity fails indeterminate.
6. Dependency/no-second-truth proof: public `QinaoRuntime.execute` → stateless `QinaoEffectExecuting` adapter → canonical turn/effect branch + K3 outbox reference → K4 exact-branch claim → Zone-C dispatch-ready → K3/K4/K3 permit-anchor-arm → Zone-C one-time local consume → thin `BASToolDispatcher` adapter/provider. Broker returns one receipt artifact ID to K3 and can neither stage/seal/activate state nor mint a turn/branch; the Qinao adapter owns no set, row, retry, or receipt.
7. Compatibility/retirement: the public `execute(toolName:payload:intent:signatures:)` signature remains. W0 temporarily makes the legacy closure/direct-dispatch composition fail closed; Task 5 then deletes the `ToolExecutor` closure initializer/property and `consumedBundles`, package-scopes the dispatcher behind the sole broker adapter, and leaves no production or source-level closure escape hatch. Focused tests inject a package-only `QinaoEffectExecuting` fake/recording broker seam, never a handler closure. Operational rollback deploys the preceding certified tree rather than keeping a live alternate executor. Legacy `operationID` is only versioned framing over Contracts' canonical branch projection plus the K3-owned effect-boundary instance, used at providers that require a string key; bounded decode reconstructs and equality-checks the exact typed branch, and arbitrary strings cannot enter the authority path.
8. Mutation/crash/replay/duplicate-authority tests: mutate every parent/branch/Attempt/generation/epoch/outbox/request/claim/permit/anchor/arm/receipt binding, crash before/after every K3/K4/Zone-C/provider boundary, replay the exact typed tuple, and fail if Qinao or K3 writes Zone-C state, broker writes K3 state, a second tool protocol appears, adapter execution occurs before exact local arm consumption, success lacks actuator evidence, or any ambiguous boundary blindly retries.

**Interfaces:**

- Consumes: typed `BASStateEffectOutboxPayload`, `BASTurnOperationRef`, exact `.effect` `BASTurnBranchRef`, Task 4's read-only prepared-effect K3 query and boundary port, Task 3's K4 capability/boundary ports, `BASArtifactStorePort`, and canonical `BASToolInvocation`/`BASToolResult`/`BASToolDispatcher`.
- Produces: the immutable package-hidden `QinaoPreparedEffectContext`, `QinaoPreparedEffectEvidenceLookup`, its single injected read-only resolver type, the sole `QinaoRuntime.makePreparedEffectContextResolver(lookup:)` factory, the package-only stateless `QinaoSovereignEffectExecutor`, `BASPersistedToolResultPayload`, `BASEffectDispatchReadyReceiptPayload`, `BASEffectReceiptPayload`, `BASEffectAdapter`, `BASEffectBroker`, and the existing `QinaoEffectExecuting` port; the broker's durable reducer vocabulary is exactly dispatch/ack/indeterminate/reconcile, and its dispatch-ready/arm-consumption columns are local fence evidence rather than a fourth global reducer. The factory/resolver/executor own no selection, allocation, storage, retry, or effect authority.

- [ ] **Step 1: Write the transition and recovery matrix**

```swift
func testIrreversibleNonQueryableAmbiguityNeverCallsAdapterAgain() async throws {
    let fixture = try makeBrokerFixture(
        recoveryClass: .irreversibleNonQueryable,
        failpoint: .afterAdapterCallBeforeReply
    )
    let result = try await fixture.broker.resume(
        turnOperationRef: fixture.turnOperationRef,
        effectBranchRef: fixture.effectBranchRef,
        effectBoundaryInstanceID: fixture.effectBoundaryInstanceID
    )
    XCTAssertEqual(result.transition, .indeterminate)
    XCTAssertEqual(result.receipt.outcome, .indeterminate)
    XCTAssertEqual(fixture.adapter.dispatchCount, 1)
}

func testQueryableWriteReconcilesSameTypedBoundaryWithoutRedispatch() async throws {
    let fixture = try makeLostReplyFixture(recoveryClass: .queryableWrite)
    let result = try await fixture.run()
    XCTAssertEqual(result.transition, .ack)
    XCTAssertEqual(result.receipt.outcome, .succeeded)
    XCTAssertEqual(result.receipt.turnOperationRef, fixture.turnOperationRef)
    XCTAssertEqual(result.receipt.effectBranchRef, fixture.effectBranchRef)
    XCTAssertEqual(result.receipt.effectBoundaryInstanceID, fixture.effectBoundaryInstanceID)
    XCTAssertEqual(fixture.adapter.queryCount, 1)
    XCTAssertEqual(fixture.adapter.dispatchCount, 1)
}

func testSameTypedBoundaryDifferentCanonicalRequestConflictsBeforeClaim() async throws {
    let fixture = try makeBrokerFixture()
    _ = try await fixture.broker.execute(
        turnOperationRef: fixture.turnOperationRef,
        effectBranchRef: fixture.effectBranchRef,
        effectBoundaryInstanceID: fixture.effectBoundaryInstanceID,
        outboxArtifactID: fixtureOutbox("a")
    )
    await XCTAssertThrowsErrorAsync {
        _ = try await fixture.broker.execute(
            turnOperationRef: fixture.turnOperationRef,
            effectBranchRef: fixture.effectBranchRef,
            effectBoundaryInstanceID: fixture.effectBoundaryInstanceID,
            outboxArtifactID: fixtureOutbox("b")
        )
    }
}

func testZoneCPayloadsCannotRestateOrReplaceProviderCausality() throws {
    for value in [
        try JSONEncoder().encode(fixtureEffectDispatchReadyReceipt()),
        try JSONEncoder().encode(fixtureEffectReceipt())
    ] {
        let keys = Set(try XCTUnwrap(JSONSerialization.jsonObject(with: value) as? [String: Any]).keys)
        XCTAssertTrue(keys.isDisjoint(with: [
            "effectCausalPredecessorArtifactID", "sourceProviderEgressBranchRef",
            "sourceProviderExecutionRef", "sourceProviderProposalArtifactID",
            "sourceProviderEventHeadSealReceiptArtifactID", "completeProviderBranchChainArtifactID"
        ]))
    }
}

func testAdapterCannotRunBeforeZoneCConsumesExactPermitAnchorArm() async throws {
    for failpoint in BASEffectBoundaryFailpoint.beforeAndAfterEveryHandshakeStep {
        let fixture = try makeBrokerFixture(failpoint: failpoint)
        _ = try? await fixture.broker.execute(
            turnOperationRef: fixture.turnOperationRef,
            effectBranchRef: fixture.effectBranchRef,
            effectBoundaryInstanceID: fixture.effectBoundaryInstanceID,
            outboxArtifactID: fixture.outboxArtifactID
        )
        if fixture.adapter.dispatchCount > 0 {
            let consumed = try XCTUnwrap(fixture.storage.consumedBoundaryTuple)
            XCTAssertEqual(consumed.permitArtifactID, fixture.permitArtifactID)
            XCTAssertEqual(consumed.anchorReceiptArtifactID, fixture.anchorArtifactID)
            XCTAssertEqual(consumed.armReceiptArtifactID, fixture.armArtifactID)
            XCTAssertEqual(consumed.effectBranchRef, fixture.effectBranchRef)
        }
    }
}

func testSuccessRequiresActualActuatorReceipt() async throws {
    let fixture = try makeLegacyDispatcherAdapterWithoutProviderEvidence()
    let result = try await fixture.broker.execute(
        turnOperationRef: fixture.turnOperationRef,
        effectBranchRef: fixture.effectBranchRef,
        effectBoundaryInstanceID: fixture.effectBoundaryInstanceID,
        outboxArtifactID: fixture.outboxArtifactID
    )
    XCTAssertNotEqual(result.receipt.outcome, .succeeded)
    XCTAssertNil(result.receipt.providerTransactionID)
}

func testQinaoFacadeForwardsOneK3RootAndEffectBranchAndNeverDirectExecutor() async throws {
    let fixture = makeQinaoBrokerFixture()
    _ = try await fixture.runtime.execute(
        toolName: fixture.intent.toolName,
        payload: fixture.payload,
        intent: fixture.intent,
        signatures: fixture.signatures
    )
    _ = try await fixture.runtime.execute(
        toolName: fixture.intent.toolName,
        payload: fixture.payload,
        intent: fixture.intent,
        signatures: fixture.signatures
    )
    XCTAssertEqual(fixture.effectExecutor.turnOperationRefs, [fixture.expectedTurnOperationRef, fixture.expectedTurnOperationRef])
    XCTAssertEqual(fixture.effectExecutor.effectBranchRefs, [fixture.expectedEffectBranchRef, fixture.expectedEffectBranchRef])
    XCTAssertEqual(fixture.legacyExecutorCallCount, 0)
    XCTAssertEqual(fixture.broker.uniqueEffectBoundaryCount, 1)
}

func testZoneCProductionStorageIsFullAndUniqueByTypedBoundary() async throws {
    let storage = try makeProductionEffectStorage()
    XCTAssertEqual(try storage.pragmasForTesting().journalMode, "wal")
    XCTAssertEqual(try storage.pragmasForTesting().synchronous, 2) // FULL
    XCTAssertTrue(try storage.hasUniqueEffectBoundaryConstraintForTesting())
    XCTAssertTrue(try storage.rawOperationIDColumnIsValidatedProjectionForTesting())
}

func testZoneCVocabularyAndSchemaRejectEveryK3Transition() throws {
    XCTAssertEqual(
        Set(BASEffectSagaTransition.allCases.map(\.rawValue)),
        Set(["dispatch", "ack", "indeterminate", "reconcile"])
    )
    for forbidden in ["prepare", "stage", "seal", "activate"] {
        let encoded = try JSONEncoder().encode(forbidden)
        XCTAssertThrowsError(
            try JSONDecoder().decode(BASEffectSagaTransition.self, from: encoded)
        )
        XCTAssertFalse(EffectSagaV1Schema.allStatementsSQL.contains(forbidden))
    }
}

func testEveryTransitionCrashGapAcrossEveryRecoveryClass() async throws {
    for recoveryClass in BASEffectRecoveryClass.allCases {
        for boundary in BASEffectSagaFailpoint.everyTransitionAndPermitAnchorArmBoundary {
            let result = try await runCrashRestart(recoveryClass: recoveryClass, failpoint: boundary)
            XCTAssertTrue(result.isAuditableTerminalOrExplicitlyIndeterminate)
            XCTAssertFalse(result.didSealPartialCancelledOrUnknownAsSuccess)
            XCTAssertLessThanOrEqual(result.adapterDispatchCount, 1)
            XCTAssertFalse(result.dispatchedWithoutExactLocalArmConsumption)
        }
    }
}
```

- [ ] **Step 2: Add product/target `BASEffectBroker`, its explicit Apple-edge imports, and run RED**

Before creating any of the three `M` files, generate the three ephemeral manifests required by the global gate—one exact `candidate_path` for `BASEffectBroker.swift`, one for `BASEffectBrokerSQLiteStorage.swift`, and one for `SQL/001_effect_saga_v1.sql`—then pass all three to one checker invocation. A directory candidate, one manifest reused with three paths, or a missing storage/schema manifest fails before creation:

```bash
python3 /Users/changgeng/Project/Project06/Project06/scripts/check_qinao_owner_ledger.py \
  --root /Users/changgeng/Project/Project06/Project06 \
  --ledger /Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json \
  --candidate-manifest "$TMPDIR/qinao-effect-broker.json" \
  --candidate-manifest "$TMPDIR/qinao-effect-broker-storage.json" \
  --candidate-manifest "$TMPDIR/qinao-effect-broker-schema.json"
```

The new target depends on `BASRuntimeCore` and `BASOrgan` only, attaches `BASSQLSchemaGen`, and does not depend on model adapters, UI, HostKit, or concrete K4. `BASOrgan` supplies the canonical `BASToolInvocation`/`BASToolResult` types; the broker introduces no replacements. Because `BASToolEffectAdapter.swift` directly conforms to `BASEffectAdapter` and directly invokes the existing `BASToolDispatcher`, extend the existing `BASAppleEdgeWiring` target with explicit direct dependencies on both `BASEffectBroker` and `BASOrgan`. Do not rely on `BASHostKit` transitive imports and do not add `BASSovereign`, `BASMemory`, or `BASLeaseLife` to the Apple edge. Add `BASEffectBroker` to `BehavioralAISubstrateTests` and consume generated `EffectSagaV1Schema.allStatementsSQL`; the schema cannot be an unused resource. Add the BehavioralAISubstrate `BASEffectBroker` product to the `QinaoRuntime` target, raise the Qinao package's iOS floor from 18 to 27, and keep the Qinao bridge stateless: it may translate and verify bindings but may not persist, retry, claim, rank, or dispatch.

After editing `Package.swift`, make the dependency boundary executable rather than documentary:

```bash
swift package --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate dump-package | \
python3 -c 'import json,sys; p=json.load(sys.stdin); d={t["name"]:{x["byName"][0] for x in t["dependencies"] if "byName" in x} for t in p["targets"]}; assert {"BASRuntimeCore","BASOrgan"} <= d["BASEffectBroker"]; assert {"BASEffectBroker","BASOrgan"} <= d["BASAppleEdgeWiring"]; assert not ({"BASSovereign","BASMemory","BASLeaseLife"} & d["BASAppleEdgeWiring"])'
swift package --package-path /Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK dump-package | \
python3 -c 'import json,sys; p=json.load(sys.stdin); d={t["name"]:{x["product"][0] for x in t["dependencies"] if "product" in x} for t in p["targets"]}; assert "BASEffectBroker" in d["QinaoRuntime"]; assert any(x.get("platformName") == "ios" and x.get("version") == "27.0" for x in p["platforms"])'
```

Then run RED:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter BASEffectSagaCrashMatrixTests
swift test --package-path /Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK --filter QinaoEffectFacadeBrokerTests
```

- [ ] **Step 3: Implement the exact adapter and state machine**

```swift
public enum BASEffectSagaTransition: String, Codable, Sendable, CaseIterable {
    case dispatch, ack, indeterminate, reconcile
}

public struct BASEffectProviderObservation: Codable, Sendable, Equatable {
    public let toolResult: BASToolResult?
    public let providerTransactionID: String?
    public let observedStateArtifactID: BASArtifactID?
    public let outcome: BASEffectTerminalOutcome
}

public protocol BASEffectAdapter: Sendable {
    var profile: BASEffectAdapterProfile { get }
    func dispatch(invocation: BASToolInvocation, idempotencyKey: String) async throws -> BASEffectProviderObservation
    func query(idempotencyKey: String) async throws -> BASEffectProviderObservation?
    func compensate(invocation: BASToolInvocation, priorResult: BASToolResult, idempotencyKey: String) async throws -> BASEffectProviderObservation
}

/// Persistence envelope only. `BASToolResult` remains the sole embedded tool
/// result value and keeps its existing adapter wire/ABI.
public struct BASPersistedToolResultPayload: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let result: BASToolResult

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        result: BASToolResult
    ) {
        self.schemaVersion = schemaVersion
        self.result = result
    }
}

/// Cross-package, return-only projection of facts already ordinary-put by the
/// broker. Public readability is required by QinaoRuntimeSDK; construction
/// remains inside the BehavioralAISubstrate package and creates no new truth.
public struct BASEffectBrokerExecution: Sendable {
    public let effectReceiptStoreReceipt: BASArtifactStoreReceipt
    public let effectReceipt: BASEffectReceiptPayload
    public let toolResultStoreReceipt: BASArtifactStoreReceipt?
    public let toolResultPayload: BASPersistedToolResultPayload?

    package init(
        effectReceiptStoreReceipt: BASArtifactStoreReceipt,
        effectReceipt: BASEffectReceiptPayload,
        toolResultStoreReceipt: BASArtifactStoreReceipt?,
        toolResultPayload: BASPersistedToolResultPayload?
    ) {
        self.effectReceiptStoreReceipt = effectReceiptStoreReceipt
        self.effectReceipt = effectReceipt
        self.toolResultStoreReceipt = toolResultStoreReceipt
        self.toolResultPayload = toolResultPayload
    }
}

package struct QinaoPreparedEffectContext: Sendable, Equatable {
    package let turnOperationRef: BASTurnOperationRef
    package let effectBranchRef: BASTurnBranchRef
    package let effectBoundaryInstanceID: String
    package let outboxArtifactID: BASArtifactID
    package let boundSubjectArtifactID: BASArtifactID
    package let canonicalRequestDigest: String
    package let sourceK3RootArtifactID: BASArtifactID

    package init(validating evidence: BASK3PreparedEffectContextEvidence) throws {
        guard evidence.effectBranchRef.kind == .effect,
              evidence.effectBranchRef.turnOperationRef == evidence.turnOperationRef,
              !evidence.effectBoundaryInstanceID.isEmpty,
              !evidence.canonicalRequestDigest.isEmpty
        else { throw QinaoPreparedEffectContextError.invalidEvidence }
        self.turnOperationRef = evidence.turnOperationRef
        self.effectBranchRef = evidence.effectBranchRef
        self.effectBoundaryInstanceID = evidence.effectBoundaryInstanceID
        self.outboxArtifactID = evidence.outboxArtifactID
        self.boundSubjectArtifactID = evidence.boundSubjectArtifactID
        self.canonicalRequestDigest = evidence.canonicalRequestDigest
        self.sourceK3RootArtifactID = evidence.sourceK3RootArtifactID
    }
}

package enum QinaoPreparedEffectContextError: Error, Equatable {
    case notPrepared
    case invalidEvidence
    case lookupBindingMismatch
}

package typealias QinaoPreparedEffectContextResolver = @Sendable (
    _ boundSubjectArtifactID: BASArtifactID,
    _ canonicalRequestDigest: String
) async throws -> QinaoPreparedEffectContext

package typealias QinaoPreparedEffectEvidenceLookup = @Sendable (
    _ boundSubjectArtifactID: BASArtifactID,
    _ canonicalRequestDigest: String
) async throws -> BASK3PreparedEffectContextEvidence?

extension QinaoRuntime {
    /// Sole production bridge from the owning K3 read view into the
    /// package-hidden facade context; it owns no lookup state or selection.
    package static func makePreparedEffectContextResolver(
        lookup: @escaping QinaoPreparedEffectEvidenceLookup
    ) -> QinaoPreparedEffectContextResolver {
        { boundSubjectArtifactID, canonicalRequestDigest in
            guard let evidence = try await lookup(
                boundSubjectArtifactID,
                canonicalRequestDigest
            ) else { throw QinaoPreparedEffectContextError.notPrepared }
            guard evidence.boundSubjectArtifactID == boundSubjectArtifactID,
                  evidence.canonicalRequestDigest == canonicalRequestDigest
            else { throw QinaoPreparedEffectContextError.lookupBindingMismatch }
            return try QinaoPreparedEffectContext(validating: evidence)
        }
    }
}

package protocol QinaoEffectExecuting: Sendable {
    func execute(
        preparedContext: QinaoPreparedEffectContext,
        toolName: String,
        payload: Data,
        intent: QinaoRiskGate.ActionIntent,
        signatures: QinaoRuntime.Signatures
    ) async throws -> QinaoEffectExecution
}

package struct QinaoEffectExecution: Sendable {
    let resultBytes: Data
    let effectReceiptArtifactID: BASArtifactID
    let receipt: BASEffectReceiptPayload
}

/// Composition adapter only. The actor reference is the exact broker already
/// installed in the authoritative host graph; this value owns no state or retry.
package struct QinaoSovereignEffectExecutor: QinaoEffectExecuting {
    package let broker: BASEffectBroker

    package init(broker: BASEffectBroker) {
        self.broker = broker
    }

    package func execute(
        preparedContext: QinaoPreparedEffectContext,
        toolName: String,
        payload: Data,
        intent: QinaoRiskGate.ActionIntent,
        signatures: QinaoRuntime.Signatures
    ) async throws -> QinaoEffectExecution {
        // Thin forwarding only: the broker independently reopens K3 and
        // equality-checks all seven expected fields before any claim/dispatch.
        try await broker.executePreparedEffect(
            turnOperationRef: preparedContext.turnOperationRef,
            effectBranchRef: preparedContext.effectBranchRef,
            effectBoundaryInstanceID: preparedContext.effectBoundaryInstanceID,
            outboxArtifactID: preparedContext.outboxArtifactID,
            expectedBoundSubjectArtifactID: preparedContext.boundSubjectArtifactID,
            expectedCanonicalRequestDigest: preparedContext.canonicalRequestDigest,
            expectedSourceK3RootArtifactID: preparedContext.sourceK3RootArtifactID
        ).asQinaoExecution(
            expectedToolName: toolName,
            expectedPayload: payload,
            expectedIntent: intent,
            expectedSignatures: signatures
        )
    }
}
```

Implement `BASEffectBroker` as the sole Zone-C actor/reducer over injected Artifact Mesh, the Task 4 K3 port, Task 3 K4 capability/boundary ports, SQLite storage, and the effect-adapter map. Its cross-package entry is exactly `public func executePreparedEffect(turnOperationRef:effectBranchRef:effectBoundaryInstanceID:outboxArtifactID:expectedBoundSubjectArtifactID:expectedCanonicalRequestDigest:expectedSourceK3RootArtifactID:) async throws -> BASEffectBrokerExecution`; the actor type, method, return type, and return fields are `public`, while the return initializer stays `package` inside BehavioralAISubstrate. It accepts the four execution coordinates `(turnOperationRef, effectBranchRef, effectBoundaryInstanceID, outboxArtifactID)` plus the three explicitly named equality expectations `(expectedBoundSubjectArtifactID, expectedCanonicalRequestDigest, expectedSourceK3RootArtifactID)`. Before K4 or adapter work it independently reopens K3 through its already-injected port and byte-equality-checks the complete seven-field prepared tuple; it rejects a non-`.effect` branch, parent mismatch, reused ordinal/instance, or outbox/subject/invocation/request-digest/root mismatch. Before returning, the broker itself reopens and validates the complete final graph—governed `BASEffectReceiptPayload`, permit → dispatch-ready/K3 evidence, K4 anchor, K3 arm, capability-use receipt, governed `BASPersistedToolResultPayload`, underlying tool invocation/request, and all seven expected tuple fields—and constructs `BASEffectBrokerExecution` only from that validated graph. Qinao receives no store/K3 verifier or closure. The final three input arguments are neither identity nor journal-key fields and may not be used to select a row. The outbox's immutable causal-predecessor reference remains K3-owned validation evidence: Zone C neither receives it as an input field nor copies, opens, replaces, or reinterprets Provider causality. The SQL uniqueness key remains exactly the canonical typed `(turn_operation_ref_artifact_id, effect_branch_kind, effect_branch_ordinal, effect_boundary_instance_id)` tuple. An optional `operation_id` column is only the bounded reversible compatibility encoding of `(effectBranchRef, effectBoundaryInstanceID)` and every read must decode/equality-check it; no API accepts it as authority. `asQinaoExecution` is a package-local QinaoRuntimeSDK extension over that already-validated public return projection; it only exact-checks the returned store-receipt IDs, payloads, outcome, tool name, public payload/intent/signature binding and unwraps successful result bytes. It owns no Artifact store, K3 port, verifier, receipt factory, or success inference.

Run the external-effect path in this exact order:

1. K3 `prepareAndEnqueue` has already reopened the outbox's exact causal Provider predecessor, allocated/accepted the next effect ordinal, and bound the outbox to the active Attempt, one parent `BASTurnOperationRef`, exact effect request, and exact effect branch. The stateless Qinao adapter asks K3 `handOffEffectToZoneC`; that sole K3 transaction rechecks the same outbox/causal-predecessor row, advances `prepared → handed_to_zone_c`, and returns only the outbox reference. Zone C persists `dispatch_pending` locally but cannot call an adapter or choose a different causal source.
2. Zone C calls K4 `claimCapability` with the grant/subject/request tuple bound to that exact effect branch. It retains only the ordinary store receipt's `body.artifactID` for the canonical `BASCapabilityUseReceipt`; replay first uses `lookupCapabilityUseReceipt`, and a same request with changed branch/outbox/digest fails closed.
3. In a second Zone-C `FULL` transaction, persist the claim reference and canonical request digest, advance to `dispatch_ready`, and store one self-ID-free `BASEffectDispatchReadyReceiptPayload` through ordinary Artifact Mesh `put`. `dispatch_ready` means durable intent only; adapter call count remains zero.
4. Present that receipt to K3. `prepareEffectBoundary` revalidates the exact active Attempt/generation/policy/deletion epochs, typed root/branch, K4 claim, current owner/boot epoch, and K3 state `handed_to_zone_c`; it advances `handed_to_zone_c → effect_permit_pending`, binds one non-usable `BASEffectBoundaryPermit`, and returns its committed EventLog source root.
5. Call K4 `anchorClaimedBoundary` with the exact permit/source/branch/instance/grant/use-receipt tuple. K4 proves same-or-newer root coverage, charges/records that instance, and returns the ordinary store receipt identifying `BASBoundaryAnchorReceipt`. Reopen and equality-check every field. Anchor issuance makes the boundary conservatively possible but cannot call the adapter.
6. Present that exact anchor artifact/payload to K3 `armBoundary`. K3 performs the sole CAS `effect_permit_pending → effect_boundary_possible` after revalidating the live Attempt/generation/epochs/owner/boot and arm deadline, durably records canonical `BASBoundaryArmReceipt` bytes, and returns them. Put/reopen the identical bytes through ordinary Artifact Mesh before Zone C sees an arm-receipt artifact ID; crash in this projection gap never reruns the CAS. A durable CAS denial proves no adapter call was authorized; missing arm/denial after owner loss is indeterminate.
7. Zone C advances its local row `dispatch_ready → dispatch_boundary_armed` only by atomically consuming that exact permit, anchor, and arm receipt once before `monotonicCallHandoffDeadline`. Only the local CAS winner calls the adapter once. Where a provider requires a string idempotency key, derive it only from versioned canonical bytes over Contracts' `effectBranchRef.canonicalLegacyProjection()` plus `effectBoundaryInstanceID`; every query must reconstruct with `BASTurnBranchRef.init(validatingCanonicalLegacyProjection:)` and equality-check the expected parent, exact `.effect` branch, and K3-owned instance.
8. A provider reply with actual actuator evidence applies `ack`; ambiguity applies `indeterminate`; evidence gathering applies `reconcile` and then `ack` or `indeterminate`. Embed the unchanged `BASToolResult` in one self-ID-free `BASPersistedToolResultPayload`, store/reopen that governed parent through `BASGovernedArtifactPayloadCodec`, and set `BASEffectReceiptPayload.toolResultArtifactID` only to the parent's ordinary Artifact ID. Store/reopen the governed effect receipt through the same path. The receipt carries the exact typed root/branch/instance, outbox/request, permit/anchor/arm/use-receipt artifact references, and the shared RuntimeCore `BASEffectTerminalOutcome`, never a free operation ID, copied Provider causality, or broker-local outcome enum. K3 consumes that exact terminal/indeterminate receipt artifact ID and equality-checks its shared outcome for later stage/seal/activate; nil outcome/receipt is legal only for a no-effect commit. The runtime's eventual final manifest separately reopens the K3 outbox causal predecessor, complete final Provider chain, governed tool-result parent, and effect receipt and binds them together; Zone C never tries to predict or duplicate that future chain. Raw `BASToolResult` remains embedded/return-only and is not independently ordinary-put or registered.

The append-only transition table permits exactly `dispatch|ack|indeterminate|reconcile`; `dispatch_pending`, claim-observed, `dispatch_ready`, and arm-consumed are constrained columns/fence evidence inside that same row, not additional reducer verbs. Its operation-local CAS revision is private recovery metadata, not an event sequence, timestamp, cursor, or integrity chain. Open its sole SQLite handle with read-back-asserted `journal_mode=WAL` and `synchronous=FULL`; mismatch or corruption blocks dispatch. Auditable order is emitted as typed observations through the existing `BASEventLogEntry` path. The table never records prepare/stage/seal/activate, and K3 never records provider dispatch/ack/reconciliation truth.

Recovery never blindly redispatches. Before K4 claim, resume only the same typed branch/instance. After a lost claim reply, lookup the same use receipt. After `dispatch_ready` but before K3 pending, resume only while the same Attempt/generation is live. After K3 pending, repeat only the exact anchor request. Immediately after K4 returns the anchor, only the same in-flight live owner may attempt the one K3 arm CAS. At or after anchor uncertainty, owner/boot loss, arm issuance, Zone-C arm consumption, provider-call start, or a lost provider reply, only query/reconcile/finalize the same provider operation; if truth cannot be established, remain `indeterminate`. Even read-only/idempotent/queryable profiles do not obtain a second arm or physical call after boundary possibility. Recovery class controls which query or separately authorized compensation is legal, not permission to repeat the original call. Compensation is a new effect ordinal/grant/boundary saga. Partial/cancelled/unknown or a legacy `BASToolResult` without durable provider/actuator evidence never become success or K3 activation authority. `BASToolEffectAdapter` contains translation/query wiring only and no retry policy or storage; `BASToolDispatcher` is unreachable except through this adapter in production.

Keep `QinaoRuntime.execute(toolName:payload:intent:signatures:)` source compatible. Extend the existing `QinaoRiskGate.ActionPermit`, `QinaoSovereignControlPlane.Warrant`, and `QinaoRuntime.SnapshotContinuityProof` values with the same trailing `boundSubjectArtifactID: BASArtifactID? = nil`; extend their existing issuance/initializer APIs with the same defaulted trailing input. For nil, each verifier must reproduce its exact legacy preimage byte-for-byte—no new delimiter, tag, empty field, or version byte—so old non-effect credentials remain valid. For nonnil, each existing signature/HMAC preimage uses one explicitly versioned, domain-separated, length-prefixed subject-binding suffix over the canonical `BASArtifactID.storageScalar`; a subject-bearing credential cannot be downgraded to the legacy preimage. No fourth subject field or wrapper is added to `QinaoRuntime.Signatures`. Legacy nil remains decodable and valid only for non-effect compatibility paths. Authoritative effect execution requires all three fields nonnil and exactly equal before resolver or broker invocation; nil, one-sided presence, pairwise mismatch, downgrade, or a signature whose subject bytes do not verify fails closed with zero lookup/claim/dispatch. This exact subject is only `outbox.effectRequestArtifactID`, the already-prepared governed effect-request Artifact ID. K3's prepared row reopens that exact artifact and equality-binds its canonical request digest, operation root, effect branch, outbox, and the receipt-reachable `toolInvocationArtifactID`; the tool-invocation ID is never an alternate subject. The subject is never derived from a session, credential ID, tool/payload, UUID, or current/latest branch.

Production composition calls only `QinaoRuntime.makePreparedEffectContextResolver(lookup:)`, passing a narrow closure over the exact same injected `BASK3ControlNucleusStorage` instance used by the owning runtime—production-concretely the same `BASSQLiteEventLogStorage` object—and forwarding only to `lookupPreparedEffectContext(boundSubjectArtifactID:canonicalRequestDigest:)`; no target outside `QinaoRuntime` directly constructs the package-hidden context. `QinaoSovereignHostAssembly` also constructs one `QinaoSovereignEffectExecutor` from the exact same `BASEffectBroker` actor already installed in that authoritative host graph. Production initialization injects that one immutable resolver and one stateless executor—never a current-branch lookup, actor-local map, alternate resolver/protocol, second K3, or second broker. After existing tool/payload/session/signature validation and the three-subject equality gate, the facade computes the already-signed canonical request digest from the unchanged intent/tool/payload/session/host binding, calls the resolver exactly once with `(boundSubjectArtifactID, canonicalRequestDigest)`, and requires the returned subject/digest to match. The resolver returns only a previously prepared K3 tuple: one root-bound `.effect` branch, its canonical boundary-instance projection, exact outbox, and source K3 root. It fails on zero, duplicate, unprepared, nonactive, sibling, stale-generation, digest, subject, root, or outbox mismatch; it cannot allocate a branch, choose the latest one, prepare an outbox, claim K4, write K3, or cache a result. The facade passes that whole `QinaoPreparedEffectContext` unchanged to `QinaoEffectExecuting`; `QinaoSovereignEffectExecutor` forwards it once, and the broker independently reopens/equality-checks the complete seven-field tuple against K3 before any claim or dispatch. The facade returns bytes only when the durable receipt binds the same typed root/branch/instance/outbox/invocation and exact permit/anchor/arm tuple, has `.succeeded`, and carries provider/actuator evidence; all indeterminate/partial/cancelled/failed outcomes remain typed errors. Identical public retries resolve the byte-identical prepared tuple and recover the same broker row/receipt without another adapter call. Source gates allow `QinaoPreparedEffectContext(validating:)` only inside `QinaoEffectExecuting.swift` and focused tests, require the factory and `QinaoSovereignEffectExecutor` exactly once, assert the assembly's K3 and broker references are object-identical to the authoritative graph, and reject direct QinaoDefaults context construction, a second resolver factory, a second executor implementation, a second K3, or a second broker.

- [ ] **Step 4: Run all crash boundaries and tool regressions**

`QinaoEffectFacadeBrokerTests` must additionally pin byte-for-byte legacy-nil preimages/signatures on a non-effect path; prove the nonnil domain/version/length suffix and downgrade rejection; reject nil on authoritative effect; mutate each one-of-three/pairwise/all-three subject binding; prove only `outbox.effectRequestArtifactID` is accepted while the receipt's tool-invocation ID is lineage-only; exercise valid signatures with a foreign prepared subject; mutate subject/digest/root/outbox after resolution; substitute resolver/broker objects; and repeat the identical request. Every invalid case must observe zero resolver-to-execution transition, K4 claim, Zone-C write, and adapter call. A production composition test asserts `===` identity for the one `BASSQLiteEventLogStorage` exposed as `BASK3ControlNucleusStorage` and the one `BASEffectBroker` captured by `QinaoSovereignEffectExecutor`.

```bash
swift package --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate dump-package | \
python3 -c 'import json,sys; p=json.load(sys.stdin); d={t["name"]:{x["byName"][0] for x in t["dependencies"] if "byName" in x} for t in p["targets"]}; assert {"BASRuntimeCore","BASOrgan"} <= d["BASEffectBroker"]; assert {"BASEffectBroker","BASOrgan"} <= d["BASAppleEdgeWiring"]; assert not ({"BASSovereign","BASMemory","BASLeaseLife"} & d["BASAppleEdgeWiring"])'
python3 /Users/changgeng/Project/Project06/Project06/scripts/check_qinao_owner_ledger.py --root /Users/changgeng/Project/Project06/Project06 --ledger /Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json
test -f /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASEffectBroker/BASEffectBroker.swift
test -f /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASEffectBroker/BASEffectBrokerSQLiteStorage.swift
test -f /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASEffectBroker/SQL/001_effect_saga_v1.sql
rg -q 'EffectSagaV1Schema\.allStatementsSQL' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASEffectBroker/BASEffectBrokerSQLiteStorage.swift
test -z "$(rg -n 'consumedBundles|toolExecutor\(' QinaoRuntimeSDK/Sources/QinaoRuntime --glob '*.swift')"
test "$(rg -n 'package struct QinaoSovereignEffectExecutor:[[:space:]]*QinaoEffectExecuting' QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoEffectExecuting.swift | wc -l | tr -d ' ')" = 1
test "$(rg -n 'makePreparedEffectContextResolver\(' QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoEffectExecuting.swift | wc -l | tr -d ' ')" = 1
! rg -n 'QinaoPreparedEffectContext\(validating:' QinaoRuntimeSDK/Sources/QinaoDefaults --glob '*.swift'
rg -q 'boundSubjectArtifactID' QinaoRuntimeSDK/Sources/QinaoRisk/QinaoRisk.swift QinaoRuntimeSDK/Sources/QinaoSovereign/QinaoSovereign.swift QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoSovereignSnapshotProof.swift
test -z "$(rg -n '\.dispatch\(' BehavioralAISubstrate/Sources --glob '*.swift' -g '!BASEffectBroker/**' -g '!BASAppleEdgeWiring/BASToolEffectAdapter.swift' | rg 'BASToolDispatcher')"
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASEffectSagaCrashMatrixTests|BASK4AuthorizationLedgerTests|BASStateCommitActivationTests|BASToolDispatcherTests|BASOrganToolTests|BASEBrainSchemaGovernanceRegistryTests'
swift test --package-path /Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK --filter QinaoEffectFacadeBrokerTests
```

- [ ] **Step 5: Commit**

After every Task 5 crash, source, and facade gate proves `QinaoRuntime.consumedBundles`, direct dispatcher execution, and synthetic executed receipts absent from production, remove exactly those three resolved entries from `effect.zone-c-saga.current_conflicts`, transition its status from `converging` to `implemented`, and run the shared checker plus checker unit tests before staging.

```bash
python3 scripts/check_qinao_owner_ledger.py --root "$PWD" --ledger "$PWD/docs/superpowers/specs/qinao-owner-ledger-v1.json"
python3 scripts/test_check_qinao_owner_ledger.py -v
git add docs/superpowers/specs/qinao-owner-ledger-v1.json BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift BehavioralAISubstrate/Sources/BASOrgan/BASOrganTool.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASOrganToolTests.swift BehavioralAISubstrate/Package.swift BehavioralAISubstrate/Sources/BASEffectBroker/BASEffectBroker.swift BehavioralAISubstrate/Sources/BASEffectBroker/BASEffectBrokerSQLiteStorage.swift BehavioralAISubstrate/Sources/BASEffectBroker/SQL/001_effect_saga_v1.sql BehavioralAISubstrate/Sources/BASAppleEdgeWiring/BASToolEffectAdapter.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEffectSagaCrashMatrixTests.swift QinaoRuntimeSDK/Package.swift QinaoRuntimeSDK/Sources/QinaoRisk/QinaoRisk.swift QinaoRuntimeSDK/Sources/QinaoSovereign/QinaoSovereign.swift QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoSovereignSnapshotProof.swift QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoEffectExecuting.swift QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoEffectFacadeBrokerTests.swift
git commit -m "feat: add durable zone c effect saga"
```

### Task 6: iOS 27 Enhanced Security Extension as a Thin K4 Process Adapter

**Files:**
- Modify [E/A — shared adapter bodies/port reuse low-entropy generics]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/EBrainControlPlaneCore.swift`
- Modify [E — product/target/test wiring only]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Package.swift`
- Create [A — host-only `Monitor`/`AppExtensionProcess`/`XPCSession` adapter]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASSovereignClient/BASSovereignEnhancedSecurityClient.swift`
- Create [A — host extension-point definition]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/Sources/App/BASSovereignEnhancedSecurityExtensionPoint.swift`
- Modify [A — existing app composition injects only the client port]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/Sources/App/BASDeviceTestApp.swift`
- Create [A — `AppExtension`/`@Bind`/`ConnectionHandler` entry]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/Sources/SovereignExtension/BASSovereignEnhancedSecurityExtension.swift`
- Create [A — stateless `XPCPeerHandler` bridge]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/Sources/SovereignExtension/BASSovereignXPCPeerHandler.swift`
- Create [Apple template entitlements]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/Resources/BASSovereignEnhancedSecurityExtension.entitlements`
- Modify [E — iOS 27 host/embed/sign/extension wiring]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/project.yml`
- Modify [generated output]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj/project.pbxproj`
- Create [test]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSovereignEnhancedSecurityBoundaryTests.swift`
- Create [test]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSovereignEffectEndToEndTests.swift`
- Create [physical-device test]: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSovereignEnhancedSecurityDeviceTests.swift`

**Reuse Decision: R + E + A; production M: none**

- Repository owner evidence: Task 3's `BASSovereignTokenAuthority` plus `BASSovereignLedgerSQLiteStorage` remain the only K4 authority/state owner; `EBrainControlPlaneCore.swift` already owns capability contracts and `BASLowEntropyPrimitives.swift` already owns `BASFrameEnvelope`/`BASResult`.
- Apple/public/upstream evidence: follow Apple's [Enhanced Security helper extension](https://developer.apple.com/documentation/xcode/creating-enhanced-security-helper-extensions), [`AppExtensionPoint`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint), [`AppExtensionProcess`](https://developer.apple.com/documentation/extensionfoundation/appextensionprocess), [`ConnectionHandler`](https://developer.apple.com/documentation/extensionfoundation/connectionhandler), and [`XPCPeerHandler`](https://developer.apple.com/documentation/xpc/xpcpeerhandler) APIs. System frameworks own discovery, process launch, session framing, peer acceptance, cancellation, and IPC.
- Adapter boundary: add only an operation body and result body inside the existing `BASFrameEnvelope`/`BASResult`; these values own no identity, authorization decision, persistence, retry, signer, or recovery state.
- Authority/storage/failure boundary: the extension composes the existing authority, existing SQLite storage, existing Artifact Mesh store, existing signer, and existing audit ledger once in its private container; the peer handler switches over calls and forwards them. Discovery/session failure and authority quarantine fail closed.
- Dependency direction: host → `BASSovereignClient` → ExtensionFoundation/XPC → extension target → existing `BASSovereignTokenAuthority`; the client cannot import `BASSovereign`, `BASMemory`, CryptoKit, Security, or SQLite, and the extension cannot import HostKit/UI.
- Compatibility/retirement: fakes implement the client port only in XCTest. Existing HostKit commit-token/warrant projection and verification linkage remains frozen for v1 reads, but cannot implement or satisfy `BASSovereignCapabilityClient`; every new iOS 27 issue/reserve/claim/spend/anchor release path injects the extension client and has no same-process fallback. Claim interruption repeats the same `(grantArtifactID, boundSubjectArtifactID, requestID)` tuple and uses the canonical lookup; boundary interruption repeats the byte-identical `(permitArtifactID, boundaryInstanceID, turnBranchRef, sourceRoot, requestID)` call and recovers the same anchor receipt rather than minting or reserving anew.
- Duplicate-authority test: source/build scans fail on `BASK4TransportContracts`, `BASSovereignHelperKit`, helper `Service`/authority facades, capability-specific or domain-specific request/permit/receipt declarations beyond the one common Task 3 boundary contract, `NWConnection`/POSIX sockets/private Mach/XPC-C APIs, or a client-side `BASSovereignTokenAuthority`; crash tests require byte-identical ordinary Artifact Mesh store receipts.

**Interfaces:**

- Consumes: existing `BASFrameEnvelope`, `BASResult`, `BASArtifactStoreReceipt`, `BASCapabilityGrant`, `BASArtifactID`, Task 3's exact four capability-lifecycle methods plus its two generic typed boundary-anchor methods, and Task 4 K3/Task 5 Zone-C ports for closure tests.
- Produces: `BASSovereignCapabilityClient`, one noncanonical `BASSovereignExtensionCallBody`, low-entropy request/reply typealiases, and `BASSovereignEnhancedSecurityClient`; no reply-domain type, canonical artifact, authority, store, transport envelope, capability-specific receipt, tool protocol, or host coordinator is produced.

- [ ] **Step 1: Write failing low-entropy, no-local-authority, interruption, and closure tests**

```swift
func testExtensionFramesAreAliasesOfExistingLowEntropyPrimitives() {
    let request: BASFrameEnvelope<BASSovereignExtensionCallBody> = fixtureExtensionRequest()
    let reply: BASFrameEnvelope<BASResult<BASArtifactStoreReceipt?>> = fixtureExtensionReply()
    let _: BASSovereignExtensionRequest = request
    let _: BASSovereignExtensionReply = reply
}

func testOversizedFrameIsRejectedBeforeAuthorityInvocation() async {
    let authority = makeCountingAuthorityBridge()
    let client = makeFakeExtensionClient(maximumCanonicalBytes: 4096, bridge: authority)
    do {
        _ = try await client.call(fixtureExtensionCall(payloadBytes: 4097))
        XCTFail("oversized frame must fail before authority invocation")
    } catch {
        XCTAssertEqual(error as? BASSovereignClientError, .messageTooLarge)
    }
    let invocationCount = await authority.invocationCount
    XCTAssertEqual(invocationCount, 0)
}

func testLostClaimReplyReconnectsAndLooksUpSameArtifactStoreReceipt() async throws {
    let fixture = makeInterruptedExtensionFixture(failpoint: .afterClaimCommitBeforeReply)
    let grantArtifactID = fixtureGrantArtifactID()
    let boundSubjectArtifactID = fixtureBoundSubjectArtifactID()
    try await fixture.client.reserveCapability(
        grantArtifactID: grantArtifactID,
        boundSubjectArtifactID: boundSubjectArtifactID,
        requestID: "claim-op-1"
    )
    do {
        _ = try await fixture.client.claimCapability(
            grantArtifactID: grantArtifactID,
            boundSubjectArtifactID: boundSubjectArtifactID,
            requestID: "claim-op-1"
        )
        XCTFail("injected lost reply must surface")
    } catch {
        XCTAssertEqual(error as? BASSovereignClientError, .interrupted)
    }
    let recovered = try await fixture.client.lookupCapabilityUseReceipt(
        grantArtifactID: grantArtifactID,
        boundSubjectArtifactID: boundSubjectArtifactID,
        requestID: "claim-op-1"
    )
    XCTAssertEqual(recovered, fixtureCapabilityUseArtifactStoreReceipt())
    let claimCount = await fixture.authority.claimCount
    let lookupCount = await fixture.authority.lookupCount
    let correlationIDs = await fixture.sessions.correlationIDs
    XCTAssertEqual(claimCount, 1)
    XCTAssertEqual(lookupCount, 1)
    XCTAssertEqual(correlationIDs, ["claim-op-1", "claim-op-1"])
}

func testLostBoundaryAnchorReplyReconnectsAndReturnsSameAnchorReceipt() async throws {
    let fixture = makeInterruptedExtensionFixture(failpoint: .afterBoundaryAnchorCommitBeforeReply)
    let request = fixtureBoundaryAnchorRequest(
        turnOperationRef: fixtureTurnOperationRef(),
        turnBranchRef: fixtureEffectBranchRef(ordinal: 2)
    )
    do {
        _ = try await fixture.client.anchorClaimedBoundary(request)
        XCTFail("injected lost reply must surface")
    } catch { }
    let recovered = try await fixture.client.anchorClaimedBoundary(request)
    XCTAssertEqual(recovered, fixtureBoundaryAnchorArtifactStoreReceipt())
    let anchorCount = await fixture.authority.anchorCount
    let callBodies = await fixture.sessions.callBodies
    XCTAssertEqual(anchorCount, 1)
    XCTAssertEqual(callBodies, [.anchorClaimedBoundary(request), .anchorClaimedBoundary(request)])
}

func testEndToEndLostRepliesDoNotMintOrDispatchAgain() async throws {
    let record = try await runEveryLostReplyGap(
        turnOperationRef: fixtureTurnOperationRef(),
        effectBranchRef: fixtureEffectBranchRef(ordinal: 1),
        effectBoundaryInstanceID: "effect-boundary-1",
        recoveryClass: .irreversibleNonQueryable
    )
    XCTAssertEqual(record.k4ClaimCount, 1)
    XCTAssertEqual(record.effectPermitCount, 1)
    XCTAssertEqual(record.effectAnchorCount, 1)
    XCTAssertEqual(record.effectArmWinnerCount, 1)
    XCTAssertEqual(record.zoneCDispatchCount, 1)
    XCTAssertEqual(record.publicationPermitCount, 1)
    XCTAssertEqual(record.publicationAnchorCount, 1)
    XCTAssertEqual(record.publicationArmWinnerCount, 1)
    XCTAssertEqual(record.k3ActivationCount, 1)
    XCTAssertEqual(record.exactPublicationCount, 1)
}
```

- [ ] **Step 2: Run RED before adding any extension/client production code**

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASSovereignEnhancedSecurityBoundaryTests|BASSovereignEffectEndToEndTests'
```

Expected: FAIL because `BASSovereignCapabilityClient`, the low-entropy extension aliases, and `BASSovereignEnhancedSecurityClient` do not exist.

- [ ] **Step 3: Extend existing capability contracts with adapter bodies and implement the thin host client**

Modify `EBrainControlPlaneCore.swift`; do not create a transport-contract file. The call enum below is a noncanonical adapter body. The reply carries only the existing ordinary Artifact Mesh store receipt (or `nil` for `Void`/not found) inside the existing `BASResult`; no extension-domain response or receipt type is introduced:

```swift
public protocol BASSovereignCapabilityClient: BASSovereignBoundaryAnchoring, Sendable {
    func issueCapability(
        _ grant: BASCapabilityGrant,
        requestID: String
    ) async throws -> BASArtifactStoreReceipt

    func reserveCapability(
        grantArtifactID: BASArtifactID,
        boundSubjectArtifactID: BASArtifactID,
        requestID: String
    ) async throws

    func claimCapability(
        grantArtifactID: BASArtifactID,
        boundSubjectArtifactID: BASArtifactID,
        requestID: String
    ) async throws -> BASArtifactStoreReceipt

    func lookupCapabilityUseReceipt(
        grantArtifactID: BASArtifactID,
        boundSubjectArtifactID: BASArtifactID,
        requestID: String
    ) async throws -> BASArtifactStoreReceipt?
}

public enum BASSovereignExtensionCallBody: Codable, Sendable, Hashable {
    case issueCapability(grant: BASCapabilityGrant, requestID: String)
    case reserveCapability(
        grantArtifactID: BASArtifactID,
        boundSubjectArtifactID: BASArtifactID,
        requestID: String
    )
    case claimCapability(
        grantArtifactID: BASArtifactID,
        boundSubjectArtifactID: BASArtifactID,
        requestID: String
    )
    case lookupCapabilityUseReceipt(
        grantArtifactID: BASArtifactID,
        boundSubjectArtifactID: BASArtifactID,
        requestID: String
    )
    case claimAndAnchorBoundary(BASBoundaryAnchorRequest)
    case anchorClaimedBoundary(BASBoundaryAnchorRequest)
}

public typealias BASSovereignExtensionRequest =
    BASFrameEnvelope<BASSovereignExtensionCallBody>

public typealias BASSovereignExtensionReply =
    BASFrameEnvelope<BASResult<BASArtifactStoreReceipt?>>
```

Every request uses `BASFrameEnvelopeHeader.schemaVersion == "1.0.0"`; `correlationID` must equal the call body's exact `requestID`, `producer` is either `host.sovereign-client` or `extension.sovereign-k4`, and no adapter may replace it on reconnect. Reject a non-`1.0.0` version, an empty request ID, a canonical encoding over 64 KiB, a mismatched reply correlation, or reuse of one request ID with different canonical call bytes before calling any authority method. Byte-identical replay of the same request ID is required for lost-reply recovery. The authority validates the grant's lifetime, every subject/typed-branch binding, permit/source root, boundary instance, and owner/boot epoch. Issue/claim/boundary-anchor replies carry `.some(BASArtifactStoreReceipt)`, reserve carries `.none`, and lookup carries the authority's optional ordinary receipt. The anchor reply's ordinary receipt identifies the self-ID-free `BASBoundaryAnchorReceipt`; it is not a transport receipt. A failed `BASResult` carries only stable diagnostics and is never persisted as another K4 receipt.

Add a `BASSovereignClient` library product/target depending only on `BASRuntimeCore`; its production file may import `Foundation`, `ExtensionFoundation`, and `XPC` under iOS 27 availability but cannot import sovereign/storage/crypto modules. The client takes the host's `AppExtensionPoint` and expected extension bundle ID, uses the public lifecycle exactly as follows, and owns only process/session/pending-continuation state:

```swift
#if os(iOS)
import ExtensionFoundation
import XPC

public enum BASSovereignClientError: Error, Equatable, Sendable {
    case extensionIdentityNotUnique
    case messageTooLarge
    case unsupportedSchemaVersion
    case correlationMismatch
    case deadlineExceeded
    case interrupted
    case cancelled
    case remoteFailure(String)
}

@available(iOS 27.0, *)
public actor BASSovereignEnhancedSecurityClient: BASSovereignCapabilityClient {
    private let extensionPoint: AppExtensionPoint
    private let expectedBundleIdentifier: String
    private var monitor: AppExtensionPoint.Monitor?
    private var process: AppExtensionProcess?
    private var session: XPCSession?

    public init(
        extensionPoint: AppExtensionPoint,
        expectedBundleIdentifier: String
    ) {
        self.extensionPoint = extensionPoint
        self.expectedBundleIdentifier = expectedBundleIdentifier
    }

    private func connect() async throws -> XPCSession {
        let monitor = try await AppExtensionPoint.Monitor(
            appExtensionPoint: extensionPoint
        )
        let matches = monitor.identities.filter {
            $0.bundleIdentifier == expectedBundleIdentifier
        }
        guard matches.count == 1, let identity = matches.first else {
            throw BASSovereignClientError.extensionIdentityNotUnique
        }
        let process = try await AppExtensionProcess(
            configuration: .init(
                appExtensionIdentity: identity,
                onInterruption: { [weak self] in
                    Task { await self?.handleInterruption() }
                }
            )
        )
        let session = try process.makeXPCSession()
        session.setIncomingMessageHandler {
            [weak self] (reply: BASSovereignExtensionReply) -> (any Encodable)? in
            Task { await self?.receive(reply) }
            return nil
        }
        session.setCancellationHandler { [weak self] error in
            Task { await self?.handleCancellation(error) }
        }
        try session.activate()
        self.monitor = monitor
        self.process = process
        self.session = session
        return session
    }
}
#endif
```

Complete the actor's six protocol methods with one shared `call` function: canonical-encode and size-check the existing frame, register one continuation by correlation, send the encodable frame with `XPCSession.send(_:)`, enforce bounded transport timeout/cancellation, and decode only the ordinary optional store-receipt result. On interruption, fail pending continuations with a retryable connection error and invalidate the process/session. Recovery orchestration repeats `issueCapability` or `reserveCapability` with identical arguments; after an ambiguous claim it first calls exact `lookupCapabilityUseReceipt` with the identical tuple and only resubmits `claimCapability` if lookup proves no stored receipt; after either boundary-anchor call it repeats only the byte-identical call and accepts only the same anchor store receipt. The thin client only reconnects through `Monitor`/`AppExtensionProcess` and maps those six calls; it never guesses whether issuance/claim/anchor committed and never creates a nonce, branch, instance, permit, receipt, retry policy, or local authority.

- [ ] **Step 4: Implement the official extension point, `ConnectionHandler`, and `XPCPeerHandler` bridge**

Define the bundle-only Enhanced Security point in the host app with the official result builder and no `Scope(.none)`:

```swift
import ExtensionFoundation

extension AppExtensionPoint {
    @Definition
    static var sovereignK4: AppExtensionPoint {
        AppExtensionPoint.Name("sovereignK4")
        AppExtensionPoint.UserInterface(false)
        AppExtensionPoint.EnhancedSecurity(true)
    }
}
```

The extension entry binds that exact host/name pair and uses `ConnectionHandler(onSessionRequest:)`. Accept each session by returning a concrete `XPCPeerHandler`; do not create an `NSXPCConnection` protocol, listener, socket, Mach service, daemon, or service facade:

```swift
import ExtensionFoundation
import XPC

protocol BASSovereignK4AppExtension: AppExtension {
    var bridge: BASSovereignExtensionBridge { get }
}

extension BASSovereignK4AppExtension {
    @MainActor
    var configuration: some AppExtensionConfiguration {
        ConnectionHandler(onSessionRequest: { [bridge] request in
            request.accept { session in
                BASSovereignXPCPeerHandler(session: session, bridge: bridge)
            }
        })
    }
}

@main
struct BASSovereignEnhancedSecurityExtension: BASSovereignK4AppExtension {
    @AppExtensionPoint.Bind
    var boundExtensionPoint: AppExtensionPoint {
        AppExtensionPoint.Identifier(
            host: "com.changgeng.basdevicetest",
            name: "sovereignK4"
        )
    }

    let bridge: BASSovereignExtensionBridge

    @MainActor
    init() {
        bridge = BASSovereignExtensionComposition.makeBridge()
    }
}
```

`BASSovereignExtensionComposition.makeBridge()` opens one extension-private Artifact Mesh store and the Task 3 `BASSovereignLedgerSQLiteStorage`, loads the Task 2 signer/trust manifest and existing audit ledger, constructs one existing `BASSovereignTokenAuthority`, and injects those objects into the bridge. It traps before accepting a session if any path, migration, key, manifest, ledger, or Artifact Mesh integrity check fails. It declares no App Group and exports no file URL, key, signer, SQLite handle, artifact bytes, or direct authority reference to the host.

The peer handler is a stateless async switch. Its bridge owns no mutable decision/retry state: it validates the existing frame/header/size, calls exactly one existing authority method with the extension-owned Artifact Mesh port, and returns the matching typed result with the same correlation ID.

```swift
import XPC

struct BASSovereignXPCPeerHandler: XPCPeerHandler {
    typealias Input = BASSovereignExtensionRequest
    typealias Output = any Encodable

    let session: XPCSession
    let bridge: BASSovereignExtensionBridge

    func handleIncomingRequest(
        _ request: BASSovereignExtensionRequest
    ) -> (any Encodable)? {
        Task {
            let reply = await bridge.handle(request)
            do {
                try session.send(reply)
            } catch {
                await bridge.noteReplyDeliveryFailure(
                    correlationID: request.header.correlationID
                )
            }
        }
        return nil
    }

    func handleCancellation(error: XPCRichError) {
        Task { await bridge.noteSessionCancellation(error) }
    }
}
```

Switch over the call body and invoke `authority.issueCapability(_:requestID:)`, `reserveCapability(grantArtifactID:boundSubjectArtifactID:requestID:)`, `claimCapability(grantArtifactID:boundSubjectArtifactID:requestID:)`, `lookupCapabilityUseReceipt(grantArtifactID:boundSubjectArtifactID:requestID:)`, `claimAndAnchorBoundary(_:)`, or `anchorClaimedBoundary(_:)` with those values unchanged. For issue, claim, and both anchor calls, place the returned ordinary `BASArtifactStoreReceipt` in the existing result body; for reserve place `nil`; for lookup forward the optional ordinary receipt. Wrap that existing result in the existing `BASFrameEnvelope`. The bridge defines no response-domain type, domain-specific permit, capability receipt wrapper, reservation handle, persistence, or authority logic. `noteReplyDeliveryFailure` and `noteSessionCancellation` emit observations to the existing audit/event ports only; they do not alter K4 state or retry work.

In `project.yml`, set the project/base/each target deployment floor to iOS `27.0`; set `EX_ENABLE_EXTENSION_POINT_GENERATION: YES` on the host and extension; add `BASSovereignEnhancedSecurityExtension` with `type: extensionkit-extension`, `PRODUCT_BUNDLE_IDENTIFIER: com.changgeng.basdevicetest.sovereign-k4`, `ENABLE_ENHANCED_SECURITY: YES`, `GENERATE_INFOPLIST_FILE: YES`, and no `info:`/`INFOPLIST_FILE`; embed/sign that target from `BASDeviceTestApp`. The host depends on `BASSovereignClient`, `BASEffectBroker`, and `BASAppleEdgeWiring`; the extension depends directly on `BASRuntimeCore`, `BASMemory`, and `BASSovereign`; device tests depend on the client/broker/edge products. There is no `BASSovereignHelperKit` target. Modify the existing `BASDeviceTestApp.swift` composition to instantiate `BASSovereignEnhancedSecurityClient(extensionPoint: .sovereignK4, expectedBundleIdentifier: "com.changgeng.basdevicetest.sovereign-k4")` as `any BASSovereignCapabilityClient` and inject that same client into the Task 1 release claim/anchor, Task 4 seal, and Task 5 effect claim/anchor ports. It must not construct `BASSovereignTokenAuthority`, a signer, a K4/artifact SQLite store, or an alternate client. Use these exact Apple-template entitlement values and no additional entitlement:

```xml
<dict>
  <key>com.apple.security.hardened-process</key><true/>
  <key>com.apple.security.hardened-process.checked-allocations</key><true/>
  <key>com.apple.security.hardened-process.checked-allocations.soft-mode</key><true/>
  <key>com.apple.security.hardened-process.dyld-ro</key><true/>
  <key>com.apple.security.hardened-process.enhanced-security-version-string</key><string>1</string>
  <key>com.apple.security.hardened-process.hardened-heap</key><true/>
  <key>com.apple.security.hardened-process.platform-restrictions-string</key><string>2</string>
</dict>
```

- [ ] **Step 5: Regenerate, prove the boundary, build GREEN, and run interruption recovery on a physical device**

```bash
set -euo pipefail
ROOT=/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate

swift test --package-path "$ROOT" --filter 'BASSovereignEnhancedSecurityBoundaryTests|BASSovereignEffectEndToEndTests'

CLIENT="$ROOT/Sources/BASSovereignClient"
EXTENSION="$ROOT/DeviceTestApp/Sources/SovereignExtension"
APP="$ROOT/DeviceTestApp/Sources/App/BASDeviceTestApp.swift"
AUTHORITY="$ROOT/Sources/BASSovereign/BASSovereignTokenAuthority.swift"
test ! -e "$ROOT/Sources/BASRuntimeCore/BASK4TransportContracts.swift"
test ! -e "$ROOT/Sources/BASSovereignHelperKit"
rg -q 'func issueCapability\(' "$AUTHORITY"
rg -q 'func reserveCapability\(' "$AUTHORITY"
rg -q 'func claimCapability\(' "$AUTHORITY"
rg -q 'func lookupCapabilityUseReceipt\(' "$AUTHORITY"
rg -q 'func claimAndAnchorBoundary\(' "$AUTHORITY"
rg -q 'func anchorClaimedBoundary\(' "$AUTHORITY"
test "$(rg -l 'public struct BASBoundaryAnchorRequest' "$ROOT/Sources" --glob '*.swift' | wc -l | tr -d ' ')" = "1"
test "$(rg -l 'public struct BASBoundaryAnchorReceipt' "$ROOT/Sources" --glob '*.swift' | wc -l | tr -d ' ')" = "1"
if rg -n 'public (struct|enum|typealias) BASCapability[A-Za-z]*(Issuance|Reservation|Claim)[A-Za-z]*(Request|Permit|Receipt)' "$ROOT/Sources" --glob '*.swift'; then
  exit 1
fi
if rg -n 'import (BASSovereign|BASMemory|CryptoKit|Security)|BASSovereignTokenAuthority|SQLite' "$CLIENT"; then
  exit 1
fi
if rg -n 'BASSovereignTokenAuthority|BASSovereignLedgerSQLiteStorage|BASSovereignSigner|BASArtifactSQLiteStore' "$APP"; then
  exit 1
fi
if rg -n 'NWConnection|NWListener|socket\(|xpc_connection_|mach_(msg|port)|NSXPCConnection' "$CLIENT" "$EXTENSION"; then
  exit 1
fi
rg -q '@Definition' "$ROOT/DeviceTestApp/Sources/App/BASSovereignEnhancedSecurityExtensionPoint.swift"
rg -q 'AppExtensionPoint\.EnhancedSecurity\(true\)' "$ROOT/DeviceTestApp/Sources/App/BASSovereignEnhancedSecurityExtensionPoint.swift"
rg -q '@AppExtensionPoint\.Bind' "$ROOT/DeviceTestApp/Sources/SovereignExtension/BASSovereignEnhancedSecurityExtension.swift"
rg -q 'ConnectionHandler\(onSessionRequest:' "$ROOT/DeviceTestApp/Sources/SovereignExtension/BASSovereignEnhancedSecurityExtension.swift"
rg -q 'XPCPeerHandler' "$ROOT/DeviceTestApp/Sources/SovereignExtension/BASSovereignXPCPeerHandler.swift"
rg -q 'AppExtensionPoint\.Monitor' "$CLIENT/BASSovereignEnhancedSecurityClient.swift"
rg -q 'AppExtensionProcess' "$CLIENT/BASSovereignEnhancedSecurityClient.swift"
rg -q 'XPCSession' "$CLIENT/BASSovereignEnhancedSecurityClient.swift"

cd /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp
xcodegen generate
xcodebuild -project BASDeviceTest.xcodeproj -scheme BASDeviceTestApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Expected: boundary tests PASS; both negative source scans are empty; every required official symbol scan succeeds; XcodeGen succeeds; generic iOS build succeeds and embeds one Enhanced Security ExtensionKit product.

Run the boundary suite on a physical iOS 27 device (never a simulator):

```bash
set -euo pipefail
: "${BAS_IOS27_DEVICE_UDID:?set a physical iOS 27 device UDID}"
cd /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp
xcodebuild -project BASDeviceTest.xcodeproj -scheme BASDeviceTestApp -destination "platform=iOS,id=${BAS_IOS27_DEVICE_UDID}" test -only-testing:BASDeviceTests/BASSovereignEnhancedSecurityDeviceTests
```

During that suite, Task 3 failpoints terminate the extension process before/after the real `issueCapability`, `reserveCapability`, `claimCapability`, `claimAndAnchorBoundary`, and `anchorClaimedBoundary` transaction commits and before/after their replies. After an ambiguous claim, also interrupt before/after the recovery lookup request/reply; after an ambiguous anchor, repeat only the byte-identical anchor frame. The host must observe `AppExtensionProcess.Configuration.onInterruption`, rediscover with `Monitor`, create a new `AppExtensionProcess`/`XPCSession`, and recover the same ordinary Artifact Mesh store receipt—through `lookupCapabilityUseReceipt` for claim or idempotent identical-call replay for anchor. There is no separate seal RPC or capability-transport operation in this matrix: terminal state sealing remains the existing L14 decision → generic K4 signing → K3 seal/activate flow and must not be invented inside capability-use recovery. Assert exactly one self-ID-free `BASCapabilityUseReceipt` per claim and one `BASBoundaryAnchorReceipt` per exact boundary instance exist under their ordinary receipts, the host cannot resolve or open the extension-private K4/Artifact-Mesh files, and no extension-domain issuance/reservation/use/anchor receipt wrapper is encoded. A generic build proves compilation only, not process isolation evidence.

- [ ] **Step 6: Run the complete sovereign/effect closure three times**

```bash
set -euo pipefail
python3 /Users/changgeng/Project/Project06/Project06/scripts/check_qinao_owner_ledger.py --root /Users/changgeng/Project/Project06/Project06 --ledger /Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json
for run in 1 2 3; do
  swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASSyntheticExecutionReceiptFreezeTests|BASSovereignEnhancedSecurityBoundaryTests|BASSovereignEffectEndToEndTests|BASResponseReleaseOrderingTests|BASSovereignSignerSuiteTests|BASK4AuthorizationLedgerTests|BASStateCommitActivationTests|BASBudgetLeaseControlTests|BASEffectSagaCrashMatrixTests|BASToolDispatcherTests'
  swift test --package-path /Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK --filter 'QinaoEffectFacadeFreezeTests|QinaoEffectFacadeBrokerTests'
done
```

Expected: three PASS runs; issuance, claim, and boundary anchoring return only ordinary `BASArtifactStoreReceipt` values, with one self-ID-free `BASCapabilityUseReceipt` per claim and one self-ID-free `BASBoundaryAnchorReceipt` per exact instance; K3 is one read-back-asserted `FULL` event/control database, owns the sole budget-lease install/use/revision CAS plus visited-digest/outcome rows, reopens and binds the Contracts-owned progress-witness Artifact ID, preserves one byte-equal recovered `BASBudgetUseReceipt`, keeps stopped loops proposal-only, retains prepare/stage/seal/activate as the state-commit vocabulary, exposes only transient `BASK3ActivatedStateEvidence`, and owns all stream/publication/effect pending/arm fences; the publication journal, helper-private K4, and Zone C each use their own read-back-asserted `FULL` failure domain and cannot write K3 rows; Zone C reducer vocabulary remains dispatch/ack/indeterminate/reconcile; `QinaoRuntime.execute` reaches the broker and no direct executor; no synthetic success, budget double-spend, fifth ring/RSI manager, unarmed adapter/sink call, duplicate irreversible dispatch, unsealed visible state, duplicate exact publication, parallel receipt type, independent `BASStateCommitStore`, or release-selectable same-process K4 implementation.

- [ ] **Step 7: Commit**

```bash
git add BehavioralAISubstrate/Package.swift BehavioralAISubstrate/Sources/BASRuntimeCore/EBrainControlPlaneCore.swift BehavioralAISubstrate/Sources/BASSovereignClient/BASSovereignEnhancedSecurityClient.swift BehavioralAISubstrate/DeviceTestApp/Sources/App/BASSovereignEnhancedSecurityExtensionPoint.swift BehavioralAISubstrate/DeviceTestApp/Sources/App/BASDeviceTestApp.swift BehavioralAISubstrate/DeviceTestApp/Sources/SovereignExtension/BASSovereignEnhancedSecurityExtension.swift BehavioralAISubstrate/DeviceTestApp/Sources/SovereignExtension/BASSovereignXPCPeerHandler.swift BehavioralAISubstrate/DeviceTestApp/Resources/BASSovereignEnhancedSecurityExtension.entitlements BehavioralAISubstrate/DeviceTestApp/project.yml BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj/project.pbxproj BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSovereignEnhancedSecurityBoundaryTests.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSovereignEffectEndToEndTests.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSovereignEnhancedSecurityDeviceTests.swift
git commit -m "feat: run sovereign authority in enhanced security extension"
```
