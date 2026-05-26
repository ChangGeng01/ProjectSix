// MARK: - BASChapter995HostPipelineTests
// chapter 九百九十五 / M3680 — Host pipeline reference implementation
//
// Tests pin:
//   1. Pipeline returns activated=false when env-var gate disables
//   2. Pipeline returns activated=false when coordinator has no
//      agentFabric configured
//   3. Pipeline activates + runs full pipeline when gate enabled
//      + fabric configured
//   4. Diagnostics dict populated with expected keys
//   5. Pipeline composes with optional warrant validation
//   6. Pipeline composes with optional trace flush bridge

import XCTest
import Crypto
@testable import BASOrchestration
@testable import BASHostKit
@testable import BASMemory
@testable import BASSovereign
@testable import BASRuntimeCore
@testable import BASPolicy

final class BASChapter995HostPipelineTests: XCTestCase {

    func testCRITICAL_Gate_DefaultEnv_PipelineSkips() async throws {
        let fabric = makeFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.1",
            environmentOverride: [:])  // no BAS_AGENT_FABRIC
        let outcome = try await pipeline.runTurn(
            turnID: "t.1",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()])
        XCTAssertFalse(outcome.activated,
            "ch 995: empty env → gate disables → pipeline skips")
        XCTAssertEqual(
            outcome.diagnostics["gate.fabric"], "disabled")
        XCTAssertNotNil(outcome.skipReason)
        XCTAssertNil(outcome.result)
    }

    func testGate_Enabled_ButNoFabric_PipelineSkips() async throws {
        // Gate enabled but coordinator has no agentFabric
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
        XCTAssertFalse(outcome.activated,
            "ch 995: gate enabled but no fabric → still skips")
        XCTAssertEqual(
            outcome.diagnostics["gate.fabric"], "enabled")
        XCTAssertTrue(
            outcome.skipReason?.contains("no agentFabric")
                ?? false)
    }

    func testCRITICAL_Activated_FullPipelineRuns() async throws {
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
        XCTAssertTrue(outcome.activated,
            "ch 995 CRITICAL: gate + fabric configured → " +
            "pipeline activates")
        XCTAssertNil(outcome.skipReason)
        XCTAssertNotNil(outcome.result,
            "ch 995 CRITICAL: activated pipeline produces " +
            "fabric result")
        XCTAssertEqual(
            outcome.diagnostics["candidates.count"], "1")
        XCTAssertNotNil(
            outcome.diagnostics["deltas.emitted"])
    }

    func testDiagnostics_PopulatedWithGateTier() async throws {
        let fabric = makeFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.1",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
                "BAS_AGENT_TIER": "all",
                "BAS_TRANSCRIPT_MODE": "compareSelected",
            ])
        let outcome = try await pipeline.runTurn(
            turnID: "t.1",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()])
        XCTAssertEqual(
            outcome.diagnostics["gate.tier"], "all")
        XCTAssertEqual(
            outcome.diagnostics["gate.transcriptMode"],
            "compareSelected")
    }

    func testWarrantValidation_FlowsThrough() async throws {
        let fabric = makeFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let ledger = makeAuditLedger()
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.1",
            warrantLedger: ledger,
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
            ])
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
        let outcome = try await pipeline.runTurn(
            turnID: "t.1",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()],
            warrantValidation: (
                result: warrantResult,
                externalAgentID: "ext.alpha"))
        XCTAssertEqual(
            outcome.diagnostics["warrant.audit"], "appended")
        XCTAssertNotNil(
            outcome.result?.warrantAuditEntry)
    }

    func testHostConstitution_FlowsToDiagnostics()
        async throws
    {
        let constitution = BASHostConstitution(
            hostID: "user.alpha")
        let coordinator = BASEBrainRuntimeCoordinator(
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
            hostConstitution: constitution,
            agentFabric: makeFabric())
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
            outcome.diagnostics["host.id"], "user.alpha",
            "ch 995: host constitution ID flows into " +
            "pipeline diagnostics")
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
        BASAgentFabricRuntime(
            roster: BASAgentTurnRoster(
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
                    visibility: .high)),
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

    private func makeAuditLedger() -> BASSovereignAuditLedger {
        let key = SymmetricKey(size: .bits256)
        return BASSovereignAuditLedger(signingSecret: key)
    }
}
