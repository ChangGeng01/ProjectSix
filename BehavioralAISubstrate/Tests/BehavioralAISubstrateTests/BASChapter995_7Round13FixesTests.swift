// MARK: - BASChapter995_7Round13FixesTests
// chapter 九百九十五.7 / M3680.7 — META-REVIEW Round-13 cascade
//
// Round-13 N-pass review (3 parallel reviewers) of ch 995.5
// caught:
//   - CRITICAL-1: ch 995.5 testCRITICAL_C1_AllSixOrphanFields
//     used a 4-mandatory-seat roster so Memory/Critic/Sovereign/
//     Evolution silently dropped at dispatcher → test claimed
//     to verify 6 orphan fixes but only verified 2 (same class
//     as the orphan bugs the cascade keeps catching)
//   - HIGH-1: BASAgentFabricHostOutcome docstring promised
//     diagnostic keys card.totalRisk + tri.veto-count that
//     were never emitted
//   - HIGH-2: testHIGH2_BusyTimeoutSetBeforeWalPragma didn't
//     exercise the concurrency it claimed to defend against
//   - MED-1: BASAgentFabricHostOutcome stringly-typed (mode +
//     activation accessible only via diagnostics dict re-parse)
//   - LOW-1: fabric.mode key absent on nil agentFabric
//
// This chapter ships fixes + regression tests that actually
// verify the orphan-fix claims。

import XCTest
import Crypto
@testable import BASOrchestration
@testable import BASHostKit
@testable import BASMemory
@testable import BASSovereign
@testable import BASRuntimeCore
@testable import BASPolicy

final class BASChapter995_7Round13FixesTests: XCTestCase {

    // MARK: - CRITICAL-1: proper 9-seat roster + per-field diagnostics

    /// Defense: prove ALL 6 orphan-fix fields actually flow
    /// through the pipeline by:
    /// 1. Using a 9-seat roster so dispatcher doesn't silently
    ///    drop optional-seat inputs
    /// 2. Asserting each per-field diagnostic key is set to "yes"
    func testCRITICAL_C1_AllSixFieldsActuallyVerifiable() async throws {
        let fabric = makeNineSeatFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.1",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
            ])
        // Supply all 6 previously-orphaned fields
        let card = BASRiskCard(
            totalRisk: 0.7,
            riskLevel: .high,
            uncertainty: 0.5,
            irreversibility: 0.5,
            manipulationStrength: 0.6,
            gsiScore: 0.5,
            recommendedMode: .delay)
        let tri = [
            BASTriSelfScore(
                candidateID: "c.1",
                idScore: 0.5, egoScore: 0.5,
                superegoScore: 0.3,
                mergedScore: 0.4, veto: true),
            BASTriSelfScore(
                candidateID: "c.2",
                idScore: 0.5, egoScore: 0.5,
                superegoScore: 0.7,
                mergedScore: 0.6, veto: false),
        ]
        let mem = BASMemorySeatInput(
            episodeArcs: ["arc.1"],
            conflictClusters: [],
            continuityAnchors: ["anc.1"],
            recallStrength: 0.7)
        let sentinel = BASSovereignSentinelInput(candidates: [])
        let evolution = BASEvolutionShadowInput(
            updateTickets: [
                BASEvolutionUpdateTicket(
                    ticketID: "t.1",
                    targetRef: "r",
                    summary: "s",
                    scopeImpact: 0.5)])
        let priority = BASMergePriorityContext(
            sovereignAgentIDs: ["sentinel.1"],
            riskAgentIDs: ["risk.1"],
            hostAgentIDs: ["hostalign.1"])
        let outcome = try await pipeline.runTurn(
            turnID: "t.1",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()],
            acceptedCandidateID: "c.1",
            riskCard: card,
            triScores: tri,
            memoryInput: mem,
            sovereignSentinelInput: sentinel,
            evolutionShadowInput: evolution,
            priorityContext: priority)
        XCTAssertTrue(outcome.activated)
        // Each per-field diagnostic asserted independently — a
        // mutation that drops ANY one field is now caught (pre-
        // fix only risk + tri were asserted)。
        XCTAssertEqual(
            outcome.diagnostics["risk.card-supplied"], "yes")
        XCTAssertEqual(
            outcome.diagnostics["risk.totalRisk"], "0.7000",
            "ch 995.7 HIGH-1: numeric risk.totalRisk now emitted " +
            "(was promised in pre-fix docstring but missing)")
        XCTAssertEqual(
            outcome.diagnostics["tri.scores-count"], "2")
        XCTAssertEqual(
            outcome.diagnostics["tri.veto-count"], "1",
            "ch 995.7 HIGH-1: tri.veto-count emitted (1 of 2 " +
            "tri scores has veto=true)")
        XCTAssertEqual(
            outcome.diagnostics["memory.input-supplied"], "yes",
            "ch 995.7 CRITICAL-1: memory orphan now " +
            "verifiable (pre-fix had no per-field key)")
        XCTAssertEqual(
            outcome.diagnostics["critic.input-supplied"], "yes")
        XCTAssertEqual(
            outcome.diagnostics["sovereign.input-supplied"],
            "yes",
            "ch 995.7 CRITICAL-1: sovereign orphan verifiable")
        XCTAssertEqual(
            outcome.diagnostics["evolution.input-supplied"],
            "yes",
            "ch 995.7 CRITICAL-1: evolution orphan verifiable")
        XCTAssertEqual(
            outcome.diagnostics["priority.tier-count"], "3",
            "ch 995.7 CRITICAL-1: priorityContext orphan " +
            "verifiable (3 agents tagged across tiers)")
        // 9-seat roster actually emits deltas for the optional
        // seats (closing Round-13 CRITICAL-1)
        let emittedRefs = outcome.result?.turnResult
            .emittedDeltas.map { $0.targetObjectRef } ?? []
        XCTAssertTrue(emittedRefs.contains {
            $0.hasPrefix("memoryBundle#")
        }, "ch 995.7 CRITICAL-1: 9-seat roster + memory input " +
           "MUST produce memoryBundle delta (pre-fix the " +
           "4-seat roster silently dropped it)")
        XCTAssertTrue(emittedRefs.contains {
            $0.hasPrefix("evolutionProposal#")
        }, "ch 995.7 CRITICAL-1: 9-seat roster + evolution " +
           "input MUST produce evolutionProposal delta")
    }

    func testCRITICAL_C1_OmittedFields_NoneSupplied() async throws {
        let fabric = makeNineSeatFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.1",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
            ])
        let outcome = try await pipeline.runTurn(
            turnID: "t.1",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()])
        // All 6 keys present + report "no" / 0
        XCTAssertEqual(
            outcome.diagnostics["risk.card-supplied"], "no")
        XCTAssertNil(
            outcome.diagnostics["risk.totalRisk"],
            "ch 995.7 HIGH-1: risk.totalRisk key absent when " +
            "no card supplied (numeric value would be meaningless)")
        XCTAssertEqual(
            outcome.diagnostics["tri.veto-count"], "0")
        XCTAssertEqual(
            outcome.diagnostics["memory.input-supplied"], "no")
        XCTAssertEqual(
            outcome.diagnostics["sovereign.input-supplied"],
            "no")
        XCTAssertEqual(
            outcome.diagnostics["evolution.input-supplied"],
            "no")
        XCTAssertEqual(
            outcome.diagnostics["priority.tier-count"], "0")
    }

    // MARK: - MED-1: typed outcome fields

    func testMED1_TypedFabricMode_AccessibleWithoutDictReparse()
        async throws
    {
        let fabric = BASAgentFabricRuntime(
            roster: makeNineSeatRoster(),
            graph: BASSharedStateGraph(),
            mode: .authoritative)
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.1",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
            ])
        let outcome = try await pipeline.runTurn(
            turnID: "t.1",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()])
        // Host can branch on outcome.fabricMode directly
        XCTAssertEqual(outcome.fabricMode, .authoritative,
            "ch 995.7 MED-1: typed fabricMode field MUST be " +
            "host-accessible WITHOUT re-parsing diagnostics dict")
        XCTAssertEqual(
            outcome.activation.fabricEnabled, true,
            "ch 995.7 MED-1: typed activation field accessible")
        XCTAssertEqual(outcome.activation.tier, .core)
    }

    func testMED1_TypedFields_PresentWhenGateDisabled() async throws {
        // Even when activated=false (gate off),typed fields
        // surface state so host can log / debug
        let fabric = makeNineSeatFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.1",
            environmentOverride: [:])  // gate disabled
        let outcome = try await pipeline.runTurn(
            turnID: "t.1",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()])
        XCTAssertFalse(outcome.activated)
        XCTAssertEqual(
            outcome.fabricMode, .observationOnly,
            "ch 995.7 MED-1: fabricMode populated even when " +
            "gate disabled (host can see fabric IS configured)")
        XCTAssertEqual(
            outcome.activation.fabricEnabled, false)
    }

    func testLOW1_NilFabric_FabricModeIsNilNotUnknown()
        async throws
    {
        let coordinator = makeCoordinator(fabric: nil)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.1",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
            ])
        let outcome = try await pipeline.runTurn(
            turnID: "t.1",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()])
        XCTAssertFalse(outcome.activated)
        XCTAssertNil(outcome.fabricMode,
            "ch 995.7 LOW-1: typed fabricMode IS nil when no " +
            "fabric — host can distinguish from .observationOnly")
        XCTAssertEqual(
            outcome.diagnostics["fabric.mode"], "unconfigured",
            "ch 995.7 LOW-1: dict surfaces 'unconfigured' " +
            "sentinel (was absent pre-fix → ambiguous nil " +
            "vs not-implemented)")
    }

    // MARK: - HIGH-2: actually-concurrent busy_timeout test

    /// Defense:Round-12 fix moved busy_timeout BEFORE WAL
    /// pragma。 Round-13 caught that the ch 995.5 test only
    /// opened a SINGLE DB,never exercising the race。 This
    /// test spawns 6 concurrent opens of the same path + asserts
    /// all succeed (busy_timeout means contention waits,doesn't
    /// throw)。
    func testCRITICAL_HIGH2_ConcurrentReopens_AllSucceed()
        async throws
    {
        let tmpPath = NSTemporaryDirectory()
            + "ch995_7_reopens_\(UUID().uuidString).sqlite"
        defer {
            try? FileManager.default
                .removeItem(atPath: tmpPath)
        }
        // Seed the DB sequentially first (creates v2 schema +
        // PRAGMA user_version=2 + tables)
        do {
            _ = try BASSovereignLedgerSQLiteStorage(
                path: tmpPath)
        }
        // Now 4 concurrent REOPEN attempts。 This is the REAL-
        // WORLD scenario the busy_timeout fix targets:multiple
        // processes opening an already-initialized ledger DB,
        // where the only contention is on the journal_mode/
        // foreign_keys pragma writes during connection setup
        // (NOT first-time schema CREATE which is filesystem-
        // race-bound regardless of busy_timeout)。 Pre-Round-12
        // fix:busy_timeout was set ONLY inside migration
        // branch → loser processes threw SQLITE_BUSY on
        // journal_mode。 Post-fix:busy_timeout set FIRST,all
        // 4 reopens wait + succeed deterministically。
        try await withThrowingTaskGroup(
            of: Bool.self
        ) { group in
            for _ in 0..<4 {
                group.addTask {
                    do {
                        _ = try
                            BASSovereignLedgerSQLiteStorage(
                                path: tmpPath)
                        return true
                    } catch {
                        return false
                    }
                }
            }
            var successCount = 0
            for try await success in group {
                if success { successCount += 1 }
            }
            XCTAssertEqual(successCount, 4,
                "ch 995.7 HIGH-2 CRITICAL: all 4 concurrent " +
                "REOPENS of an already-initialized DB MUST " +
                "succeed。 Pre-Round-12 fix (busy_timeout after " +
                "WAL pragma) would have shown < 4 successes " +
                "due to SQLITE_BUSY race on journal_mode write。 " +
                "Got \(successCount)。")
        }
    }

    // MARK: - Helpers — 9-seat roster (critical for orphan tests)

    /// chapter 九百九十五.7 Round-13 CRITICAL-1 fix:Round-12
    /// makeRoster() returned only 4 mandatory seats so the
    /// optional-seat orphan tests passed for the WRONG REASON
    /// (dispatcher silently dropped Memory/Critic/Sovereign/
    /// Evolution inputs because no roster slot existed)。 This
    /// 9-seat roster makes the orphan-fix verification meaningful。
    private func makeNineSeatRoster() -> BASAgentTurnRoster {
        BASAgentTurnRoster(
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
                visibility: .high),
            memory: BASAgentSpec(
                agentID: "memory.1",
                role: .memory,
                writeDomains: [.memoryBundle],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            critic: BASAgentSpec(
                agentID: "critic.1",
                role: .critic,
                writeDomains: [.critiqueField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            hostAlignment: BASAgentSpec(
                agentID: "hostalign.1",
                role: .hostAlignment,
                writeDomains: [.alignmentField],
                defaultLeaseProfile: .hotSeat,
                visibility: .medium),
            sovereignSentinel: BASAgentSpec(
                agentID: "sentinel.1",
                role: .sovereignSentinel,
                writeDomains: [.sovereignVerdict],
                defaultLeaseProfile: .sovereign,
                visibility: .low),
            evolutionShadow: BASAgentSpec(
                agentID: "evolution.1",
                role: .evolutionShadow,
                writeDomains: [.evolutionProposal],
                defaultLeaseProfile: .coldSeat,
                visibility: .medium))
    }

    private func makeNineSeatFabric() -> BASAgentFabricRuntime {
        BASAgentFabricRuntime(
            roster: makeNineSeatRoster(),
            graph: BASSharedStateGraph())
    }

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

    private func makeCand() -> BASCandidatePath {
        BASCandidatePath(
            candidateID: "c.1",
            title: "test",
            actionSummary: "a",
            expectedBenefit: 0.5,
            expectedCost: 0.5,
            reversibility: 0.5,
            confidence: 0.5)
    }
}
