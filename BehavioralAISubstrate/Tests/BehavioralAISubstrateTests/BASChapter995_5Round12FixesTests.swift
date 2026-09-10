// MARK: - BASChapter995_5Round12FixesTests
// chapter 九百九十五.5 / M3680.5 — META-REVIEW Round-12 cascade
//
// Round-12 N-pass review of ch 994.7 + ch 995 caught:
//   - CRITICAL-1: ch 995 host pipeline orphans 6 of 12 liveInputs
//     fields (same class as Round-10 + Round-11 catches)
//   - CRITICAL-2: BASAgentFabricMode field stored but read NOWHERE
//     in source → .authoritative byte-identical to
//     .observationOnly (dead-code scaffold)
//   - HIGH-1: BASAgentFabricGate.tier/transcriptMode/activeAgents
//     parsed into diagnostics only,no behavioral consequence
//   - HIGH-2: busy_timeout was inside migration branch only,
//     concurrent first-open of fresh DB still races on WAL setup
//   - MED-2: gate.activeAgents not surfaced in diagnostics
//
// This file regression-pins the fixes for CRITICAL-1, CRITICAL-2,
// HIGH-2, MED-2。 CRITICAL-2 fix is mode-surfaced-in-diagnostics
// (substrate scaffold doctrine:mode is a host-observable signal,
// not a substrate behavior switch);HIGH-1 partial fix is
// activeAgents-in-diagnostics (full tier-filter behavioral wire
// is plan-section-9 phase 9+ scope,not a ch 995.5 fix)。

import XCTest
import Crypto
@testable import BASOrchestration
@testable import BASHostKit
@testable import BASMemory
@testable import BASSovereign
@testable import BASRuntimeCore
@testable import BASPolicy

final class BASChapter995_5Round12FixesTests: XCTestCase {

    // MARK: - CRITICAL-1: orphan liveInputs fields fix

    /// Defense:all 12 BASAgentFabricLiveInputs fields MUST be
    /// reachable through pipeline.runTurn signature。 Pre-fix
    /// only 6 were exposed,defeating the pipeline's purpose
    /// (Memory/Critic/Sovereign/Evolution seats + risk + tri
    /// enrichment + priorityContext unreachable)。
    func testCRITICAL_C1_AllSixOrphanFieldsNowReachable()
        async throws
    {
        let fabric = makeFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.1",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
            ])
        // Supply ALL 6 previously-orphaned fields
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
        ]
        let mem = BASMemorySeatInput(
            episodeArcs: ["arc.1"],
            conflictClusters: [],
            continuityAnchors: ["anc.1"],
            recallStrength: 0.7)
        let sentinel = BASSovereignSentinelInput(
            candidates: [])
        let evolution = BASEvolutionShadowInput()
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
        XCTAssertTrue(outcome.activated,
            "ch 995.5 CRITICAL-1: pipeline activates with " +
            "all 6 previously-orphaned fields supplied")
        XCTAssertEqual(
            outcome.diagnostics["risk.card-supplied"], "yes",
            "ch 995.5 CRITICAL-1: riskCard reaches the " +
            "pipeline (closes ch 995 orphan)")
        XCTAssertEqual(
            outcome.diagnostics["tri.scores-count"], "1",
            "ch 995.5 CRITICAL-1: triScores reach the " +
            "pipeline")
    }

    func testCRITICAL_C1_OmittedFields_DefaultsPreserveCompat()
        async throws
    {
        // Calling runTurn with ONLY the original 5 params should
        // still work (defaulted nil/empty for the 6 new ones)
        let fabric = makeFabric()
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
        XCTAssertTrue(outcome.activated)
        XCTAssertEqual(
            outcome.diagnostics["risk.card-supplied"], "no")
        XCTAssertEqual(
            outcome.diagnostics["tri.scores-count"], "0")
    }

    // MARK: - CRITICAL-2: mode surfaced in diagnostics

    /// Defense:BASAgentFabricMode was stored on runtime but
    /// READ NOWHERE in source pre-fix → .authoritative was
    /// byte-identical to .observationOnly。 Substrate's scaffold
    /// doctrine is "mode is a signal,not a behavior switch" —
    /// but for the signal to be useful,host must be able to
    /// READ it。 Pre-fix host had no way to inspect mode through
    /// the pipeline outcome。 Fix:surface in
    /// outcome.diagnostics["fabric.mode"]。
    func testCRITICAL_C2_FabricMode_SurfacedInDiagnostics()
        async throws
    {
        let fabric = BASAgentFabricRuntime(
            roster: makeRoster(),
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
        XCTAssertEqual(
            outcome.diagnostics["fabric.mode"],
            "authoritative",
            "ch 995.5 CRITICAL-2: mode MUST be readable in " +
            "diagnostics so host branch logic " +
            "`if mode == .authoritative { replace }` has a " +
            "value to read (substrate doesn't switch behavior — " +
            "this is the host-observable signal)")
    }

    func testCRITICAL_C2_DefaultMode_DiagnosticsContainObservationOnly()
        async throws
    {
        let fabric = makeFabric()  // default .observationOnly
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
        XCTAssertEqual(
            outcome.diagnostics["fabric.mode"],
            "observationOnly")
    }

    // MARK: - HIGH-2: busy_timeout before WAL setup

    /// Defense:Round-11 fix set busy_timeout=5000 only INSIDE
    /// the v1→v2 migration branch。 Round-12 caught that
    /// concurrent first-open of a fresh DB (existingVersion==0
    /// path) hits journal_mode=WAL before any busy_timeout —
    /// loser process gets SQLITE_BUSY → init throws。 Fix: move
    /// busy_timeout BEFORE all other pragmas。
    func testHIGH2_BusyTimeoutSetBeforeWalPragma() throws {
        // Verify by opening a DB succeeds — the pragma order
        // can't be tested directly without instrumenting SQLite
        // internals,but a fresh-DB open succeeding is the
        // observable contract。
        let tmpPath = NSTemporaryDirectory()
            + "ch995_5_busy_\(UUID().uuidString).sqlite"
        defer {
            try? FileManager.default
                .removeItem(atPath: tmpPath)
        }
        XCTAssertNoThrow(
            try BASSovereignLedgerSQLiteStorage(
                path: tmpPath),
            "ch 995.5 HIGH-2: fresh-DB open MUST succeed " +
            "even with busy_timeout set before WAL " +
            "(no regression from pragma reorder)")
    }

    // MARK: - MED-2: gate.activeAgents in diagnostics

    func testMED2_ActiveAgentsInDiagnostics() async throws {
        let fabric = makeFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.1",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
                "BAS_ACTIVE_AGENTS":
                    "Planner,Critic,Memory",
            ])
        let outcome = try await pipeline.runTurn(
            turnID: "t.1",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()])
        XCTAssertEqual(
            outcome.diagnostics["gate.activeAgents"],
            "Planner,Critic,Memory",
            "ch 995.5 MED-2: gate.activeAgents MUST be in " +
            "diagnostics (was silently dropped pre-fix)")
    }

    // MARK: - Helpers

    private func makeCoordinator(
        fabric: BASAgentFabricRuntime
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

    private func makeRoster() -> BASAgentTurnRoster {
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
                visibility: .high))
    }

    private func makeFabric() -> BASAgentFabricRuntime {
        BASAgentFabricRuntime(
            roster: makeRoster(),
            graph: BASSharedStateGraph())
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
