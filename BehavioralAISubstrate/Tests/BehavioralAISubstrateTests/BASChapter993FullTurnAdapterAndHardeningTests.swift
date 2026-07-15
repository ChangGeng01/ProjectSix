// MARK: - BASChapter993FullTurnAdapterAndHardeningTests
// chapter 九百九十三 / M3670 — Cross-Module Integration Arc ch12:
// host-integration convenience + cross-arc separator hardening
//
// Three substantive items in one chapter:
//   A. `BASAgentFabricFullTurnAdapter.run(...)` — 14-step host
//      pipeline collapsed to 1 function call
//   B. `BASAgentFabricGate.activationFromEnvironment(...)` —
//      env-var probing per deferred item #6 substrate-side
//   C. `basSovereignAuditCanonicalBytes` separator-class
//      hardening per ch 982 Round-8 cross-arc concern

import XCTest
import Crypto
@testable import BASMemory
@testable import BASOrchestration
@testable import BASHostKit
@testable import BASSovereign
@testable import BASRuntimeCore
@testable import BASPolicy

final class BASChapter993FullTurnAdapterAndHardeningTests:
    XCTestCase
{

    // MARK: - A: BASAgentFabricFullTurnAdapter

    func testFullTurnAdapter_NilFabric_ReturnsNil() async throws {
        let coordinator = makeCoordinator(fabric: nil)
        let liveInputs = makeLiveInputs()
        let result = try await BASAgentFabricFullTurnAdapter
            .run(
                sessionID: "sess.1",
                turnID: "t.1",
                liveInputs: liveInputs,
                coordinator: coordinator)
        XCTAssertNil(result,
            "ch 993 A: nil agentFabric → adapter returns nil " +
            "no-op (preserves byte-equality)")
    }

    func testFullTurnAdapter_FabricConfigured_ProducesAllOutputs()
        async throws
    {
        let fabric = makeFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let liveInputs = makeLiveInputs()
        let result = try await BASAgentFabricFullTurnAdapter
            .run(
                sessionID: "sess.1",
                turnID: "t.1",
                liveInputs: liveInputs,
                coordinator: coordinator)
        XCTAssertNotNil(result,
            "ch 993 A: configured fabric → non-nil result bundle")
        XCTAssertNotNil(result?.turnResult)
        XCTAssertNil(result?.warrantAuditEntry,
            "ch 993 A: no warrant supplied → audit entry nil")
        XCTAssertNil(result?.flushedTraceEventCount,
            "ch 993 A: no trace bridge supplied → flush nil")
        XCTAssertEqual(
            result?.frontierProjection.frontierWidth, 1,
            "ch 993 A: frontier projection always computed " +
            "from candidates")
    }

    func testFullTurnAdapter_WithWarrantAndLedger() async throws {
        let fabric = makeFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let ledger = makeAuditLedger()
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "host-w-1",
            perAgentWarrantID: "agent-w-1",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.alpha")
        let warrantResult = BASSovereignWarrantValidator
            .validate(
                chain: chain,
                forExternalAgentID: "ext.alpha",
                nowNanos: 500_000_000_000)
        XCTAssertTrue(warrantResult.valid)
        var inputs = makeLiveInputs()
        inputs = BASAgentFabricLiveInputs(
            frame: inputs.frame,
            candidatePaths: inputs.candidatePaths,
            acceptedCandidateID: inputs.acceptedCandidateID,
            warrantValidation: (
                result: warrantResult,
                externalAgentID: "ext.alpha"))
        let result = try await BASAgentFabricFullTurnAdapter
            .run(
                sessionID: "sess.1",
                turnID: "t.1",
                liveInputs: inputs,
                coordinator: coordinator,
                warrantLedger: ledger)
        XCTAssertNotNil(result?.warrantAuditEntry,
            "ch 993 A: warrant + ledger supplied → entry " +
            "lands in ledger")
        XCTAssertEqual(
            result?.warrantAuditEntry?.entry.turnID, "t.1")
    }

    // MARK: - A': hostkit-rest MED-1 — flush failure must not fork host from ledger

    /// Event-log double whose `append` always throws — models the durable trace
    /// store failing AFTER the warrant already committed to the sovereign ledger.
    private struct ThrowingEventLog: BASEventLogStorage {
        struct Boom: Error {}
        func append(_ entry: BASEventLogEntry) async throws
            -> (wasNew: Bool, assignedSequenceNumber: Int64) { throw Boom() }
        func events(forSession sessionID: String) async -> [BASEventLogEntry] { [] }
        func events(sinceTimestampMs since: Int64, limit: Int) async -> [BASEventLogEntry] { [] }
        var totalCount: Int { get async { 0 } }
        func pruneEventsBefore(timestampMs cutoff: Int64) async throws -> Int { 0 }
    }

    func testFullTurnAdapter_FlushFailure_DeliversTurnResultWithPartialCommit()
        async throws
    {
        let fabric = makeFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let ledger = makeAuditLedger()
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "host-w-1",
            perAgentWarrantID: "agent-w-1",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.alpha")
        let warrantResult = BASSovereignWarrantValidator.validate(
            chain: chain, forExternalAgentID: "ext.alpha", nowNanos: 500_000_000_000)
        XCTAssertTrue(warrantResult.valid)

        // A traceLog with ≥1 event for the turn so flush actually reaches the
        // throwing eventLog append (an empty traceLog would flush 0 and never throw).
        let traceLog = BASAgentTraceLog()
        _ = await traceLog.append(BASAgentTraceEvent(
            turnID: "t.1", createdAtNanos: 1,
            kind: .mergeCompleted,
            payloadJson: #"{"merge_id":"m1","accepted":1,"rejected":0}"#))
        let bridge = BASAgentTraceLogEventLogBridge(
            traceLog: traceLog, eventLog: ThrowingEventLog(), sessionID: "sess.1")

        var inputs = makeLiveInputs()
        inputs = BASAgentFabricLiveInputs(
            frame: inputs.frame,
            candidatePaths: inputs.candidatePaths,
            acceptedCandidateID: inputs.acceptedCandidateID,
            warrantValidation: (result: warrantResult, externalAgentID: "ext.alpha"))

        // Must NOT throw despite the flush failing — the turn is delivered.
        var result: BASAgentFabricFullTurnResult?
        do {
            result = try await BASAgentFabricFullTurnAdapter.run(
                sessionID: "sess.1", turnID: "t.1", liveInputs: inputs,
                coordinator: coordinator, warrantLedger: ledger, traceLogBridge: bridge)
        } catch {
            return XCTFail("run() threw on flush failure — turnResult lost, host forks from ledger: \(error)")
        }

        XCTAssertNotNil(result, "the bundle must still be delivered on flush failure")
        XCTAssertNotNil(result?.turnResult, "turnResult must survive a flush failure")
        XCTAssertNil(result?.flushedTraceEventCount, "a failed flush reports no count")
        XCTAssertEqual(result?.partialCommit?.stage, "traceFlush",
            "the flush failure must be surfaced as an explicit partial-commit marker")
        // The warrant DID commit to the ledger — the host must have received the turn too (no fork).
        let entries = await ledger.entries(forSession: "sess.1", turn: "t.1")
        XCTAssertEqual(entries.count, 1,
            "warrant committed to ledger AND turn delivered to host — the two views agree")
        XCTAssertNotNil(result?.warrantAuditEntry)
    }

    func testFullTurnAdapter_FlushSuccess_NoPartialCommit() async throws {
        // Companion: the success path is unchanged — non-throwing eventLog ⇒ partialCommit nil,
        // flushedTraceEventCount == 1.
        let coordinator = makeCoordinator(fabric: makeFabric())
        let traceLog = BASAgentTraceLog()
        _ = await traceLog.append(BASAgentTraceEvent(
            turnID: "t.1", createdAtNanos: 1, kind: .mergeCompleted,
            payloadJson: #"{"merge_id":"m1","accepted":1,"rejected":0}"#))
        let bridge = BASAgentTraceLogEventLogBridge(
            traceLog: traceLog, eventLog: BASInMemoryEventLogStorage(), sessionID: "sess.1")
        let result = try await BASAgentFabricFullTurnAdapter.run(
            sessionID: "sess.1", turnID: "t.1", liveInputs: makeLiveInputs(),
            coordinator: coordinator, traceLogBridge: bridge)
        XCTAssertNil(result?.partialCommit, "success path: no partial-commit marker")
        XCTAssertEqual(result?.flushedTraceEventCount, 1, "success path: flush count reported")
    }

    // MARK: - B: BASAgentFabricGate env-var probing

    func testGate_DefaultEnvironment_FabricDisabled() {
        let activation = BASAgentFabricGate
            .activationFromEnvironment([:])
        XCTAssertFalse(activation.fabricEnabled,
            "ch 993 B: empty env → fabric disabled by default")
        XCTAssertEqual(activation.tier, .core)
        XCTAssertEqual(
            activation.transcriptMode, .singleAgent)
        XCTAssertTrue(activation.activeAgents.isEmpty)
    }

    func testGate_EnabledFlag_FabricActivated() {
        let activation = BASAgentFabricGate
            .activationFromEnvironment(
                ["BAS_AGENT_FABRIC": "enabled"])
        XCTAssertTrue(activation.fabricEnabled,
            "ch 993 B: BAS_AGENT_FABRIC=enabled → activated")
    }

    func testGate_DisabledExplicit_FabricOff() {
        let activation = BASAgentFabricGate
            .activationFromEnvironment(
                ["BAS_AGENT_FABRIC": "disabled"])
        XCTAssertFalse(activation.fabricEnabled,
            "ch 993 B: 'disabled' is NOT 'enabled' → off")
    }

    func testGate_TierAll() {
        let activation = BASAgentFabricGate
            .activationFromEnvironment([
                "BAS_AGENT_FABRIC": "enabled",
                "BAS_AGENT_TIER": "all",
            ])
        XCTAssertEqual(activation.tier, .all,
            "ch 993 B: BAS_AGENT_TIER=all selects all 20 agents")
    }

    func testGate_TranscriptCompareSelected() {
        let activation = BASAgentFabricGate
            .activationFromEnvironment([
                "BAS_AGENT_FABRIC": "enabled",
                "BAS_TRANSCRIPT_MODE": "compareSelected",
                "BAS_ACTIVE_AGENTS":
                    "Planner,Critic,Memory,Risk,Surface",
            ])
        XCTAssertEqual(
            activation.transcriptMode, .compareSelected)
        XCTAssertEqual(activation.activeAgents,
            ["Planner", "Critic", "Memory", "Risk", "Surface"])
    }

    func testGate_ActiveAgentsCSV_TrimsWhitespace() {
        let activation = BASAgentFabricGate
            .activationFromEnvironment([
                "BAS_ACTIVE_AGENTS":
                    "  Planner  , Critic , Memory ,, , Risk",
            ])
        XCTAssertEqual(activation.activeAgents,
            ["Planner", "Critic", "Memory", "Risk"],
            "ch 993 B: trims whitespace + filters empty " +
            "(robust to user-formatted env var)")
    }

    // MARK: - C: canonical-bytes separator hardening

    /// CRITICAL: closes ch 982 Round-8 cross-arc separator-class
    /// concern。 The pre-1.1.0 format joined ruleIDs/signalRefs/
    /// actionRefs with `","` — if any entry contained `,` (legit
    /// per caller-supplied opaque ID convention),signature
    /// collision was possible。 1.1.0 format uses U+001F (forbidden
    /// in normal content) so collision is impossible。
    func testCRITICAL_993_C_NewFormatBlocksSeparatorCollision() {
        // Two LOGICALLY DIFFERENT signalRef arrays that produce
        // IDENTICAL canonical bytes under the OLD format (because
        // "," collides with array element content)
        let entryA = BASSovereignAuditEntry(
            schemaVersion: "1.1.0",  // hardened
            auditID: "a",
            sessionID: "s",
            turnID: "t",
            verdictRef: "v",
            ruleIDs: [],
            signalRefs: ["foo,bar", "baz"],  // 2 elements
            actionRefs: [],
            snapshotRef: "",
            actor: .system,
            signature: "",
            appendedAt: Date(timeIntervalSince1970: 1))
        let entryB = BASSovereignAuditEntry(
            schemaVersion: "1.1.0",
            auditID: "a",
            sessionID: "s",
            turnID: "t",
            verdictRef: "v",
            ruleIDs: [],
            signalRefs: ["foo", "bar,baz"],  // 2 elements,
                                              // different split
            actionRefs: [],
            snapshotRef: "",
            actor: .system,
            signature: "",
            appendedAt: Date(timeIntervalSince1970: 1))
        // Under U+001F inner separator,these produce DIFFERENT
        // canonical bytes (because "foo,bar\u{001F}baz" !=
        // "foo\u{001F}bar,baz")
        let bytesA = basSovereignAuditCanonicalBytes(
            for: entryA,
            priorHash: "h",
            signingNamespace: "ns")
        let bytesB = basSovereignAuditCanonicalBytes(
            for: entryB,
            priorHash: "h",
            signingNamespace: "ns")
        XCTAssertNotEqual(bytesA, bytesB,
            "ch 993 CRITICAL-C: 1.1.0 format MUST prevent " +
            "signature collision for arrays whose elements " +
            "contain `,` (closes ch 982 Round-8 cross-arc " +
            "concern same class as ch 981.9 C1)")
    }

    /// Defense:OLD format (1.0.0) is STILL vulnerable to the
    /// collision class — preserved for backward compat only。
    /// This test pins the historical defect AND confirms why the
    /// 1.1.0 upgrade is correct。
    func test993_C_OldFormatStillVulnerable_BackwardCompatTrap() {
        let entryA = BASSovereignAuditEntry(
            // 1.0.0 default
            auditID: "a",
            sessionID: "s",
            turnID: "t",
            verdictRef: "v",
            ruleIDs: [],
            signalRefs: ["foo,bar", "baz"],
            actionRefs: [],
            snapshotRef: "",
            actor: .system,
            signature: "",
            appendedAt: Date(timeIntervalSince1970: 1))
        let entryB = BASSovereignAuditEntry(
            auditID: "a",
            sessionID: "s",
            turnID: "t",
            verdictRef: "v",
            ruleIDs: [],
            signalRefs: ["foo", "bar,baz"],
            actionRefs: [],
            snapshotRef: "",
            actor: .system,
            signature: "",
            appendedAt: Date(timeIntervalSince1970: 1))
        let bytesA = basSovereignAuditCanonicalBytes(
            for: entryA,
            priorHash: "h",
            signingNamespace: "ns")
        let bytesB = basSovereignAuditCanonicalBytes(
            for: entryB,
            priorHash: "h",
            signingNamespace: "ns")
        XCTAssertEqual(bytesA, bytesB,
            "ch 993 C: pre-fix 1.0.0 format COLLIDES on " +
            "separator-class inputs。 Pinned for historical " +
            "audit + as the rationale for the 1.1.0 upgrade。 " +
            "Callers wanting safety MUST opt into 1.1.0。")
    }

    /// Warrant audit bridge MUST default to the hardened 1.1.0
    /// format so warrant entries (the primary attack surface
    /// flagged by Round-8) get the collision-proof canonical
    /// bytes by default。
    func testCRITICAL_993_C_WarrantBridgeUsesHardenedFormat()
        async throws
    {
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "host-w-1",
            perAgentWarrantID: "agent-w-1",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.alpha")
        let result = BASSovereignWarrantValidator
            .validate(
                chain: chain,
                forExternalAgentID: "ext.alpha",
                nowNanos: 500_000_000_000)
        let entry = BASSovereignWarrantAuditBridge.buildEntry(
            validationResult: result,
            sessionID: "s",
            turnID: "t",
            externalAgentID: "ext.alpha")
        XCTAssertEqual(entry.schemaVersion, "1.2.0",
            "ch 993 CRITICAL-C: warrant bridge MUST default to the hardened format — " +
            "ch1044 D2 step-2 made that the INJECTIVE 1.2.0 form (closes Round-8 + the " +
            "composite-ref boundary ambiguity)")
    }

    // MARK: - Helpers

    private func makeCoordinator(
        fabric: BASAgentFabricRuntime?
    ) -> BASEBrainRuntimeCoordinator {
        BASEBrainRuntimeCoordinator(
            powerClockService:
                BASPlaceholderPowerClockService(),
            hostProfileService:
                BASPlaceholderHostProfileService(),
            contextService:
                BASPlaceholderContextService(),
            decomposeService:
                BASPlaceholderDecomposeService(),
            memoryService:
                BASPlaceholderMemoryService(),
            loopService:
                BASPlaceholderLoopService(),
            triSelfService:
                BASPlaceholderTriSelfService(),
            riskService:
                BASPlaceholderRiskService(),
            actionService:
                BASPlaceholderActionService(),
            evolutionService:
                BASPlaceholderEvolutionService(),
            agentFabric: fabric)
    }

    private func makeFabric() -> BASAgentFabricRuntime {
        let roster = BASAgentTurnRoster(
            scout: BASAgentSpec(
                agentID: "scout.1",
                role: .scout,
                writeDomains: [.situationField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            planner: BASAgentSpec(
                agentID: "planner.1",
                role: .planner,
                writeDomains: [.candidateFrontier],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            risk: BASAgentSpec(
                agentID: "risk.1",
                role: .risk,
                writeDomains: [.riskField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            surface: BASAgentSpec(
                agentID: "surface.1",
                role: .surface,
                writeDomains: [.renderFrame],
                defaultLeaseProfile: .hotSeat,
                visibility: .high))
        return BASAgentFabricRuntime(
            roster: roster,
            graph: BASSharedStateGraph())
    }

    private func makeLiveInputs() -> BASAgentFabricLiveInputs {
        BASAgentFabricLiveInputs(
            frame: BASDecomposeFrame(),
            candidatePaths: [
                BASCandidatePath(
                    candidateID: "c.1",
                    title: "test",
                    actionSummary: "a",
                    expectedBenefit: 0.5,
                    expectedCost: 0.2,
                    reversibility: 0.9,
                    confidence: 0.8),
            ],
            acceptedCandidateID: "c.1")
    }

    private func makeAuditLedger() -> BASSovereignAuditLedger {
        let key = SymmetricKey(size: .bits256)
        return BASSovereignAuditLedger(signingSecret: key)
    }
}
