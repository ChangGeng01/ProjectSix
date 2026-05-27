// MARK: - BASChapter1001ActiveAgentsWireTests
// chapter 一千零一 / M3710 — wire BAS_ACTIVE_AGENTS env var to
// optional-seat filtering
//
// Pre-fix doctrine (ch 993-1000.5): BAS_ACTIVE_AGENTS was
// decorative — parsed into BASAgentFabricGate.Activation
// .activeAgents CSV and surfaced in diagnostics, but never
// affected pipeline behavior。 Per ch 995.5 SCAFFOLD doctrine,
// "tier/transcriptMode/activeAgents are advisory only"。
//
// Ch 1001 flips activeAgents from SCAFFOLD to WIRED:
// - Non-empty BAS_ACTIVE_AGENTS → pipeline filters which
//   optional seats receive input (Memory/Critic/HostAlignment/
//   SovereignSentinel/EvolutionShadow)
// - Mandatory 4 seats (Scout/Planner/Risk/Surface) always run
//   regardless (structurally required by BASAgentTurnInput)
// - Empty/unset BAS_ACTIVE_AGENTS → no filter (all optional
//   seats active, per pre-fix behavior — backward compat)
//
// Tests pin:
//   1. canonicalRoles normalizes case + maps aliases
//      ("hostalign" → "hostAlignment", etc.)
//   2. Empty active set → no filter (backward compat)
//   3. activeAgents=Memory,Critic → ONLY Memory + Critic
//      optional seats receive input
//   4. activeAgents excludes EvolutionShadow → no
//      evolutionProposal# delta emitted
//   5. diagnostic key filter.optionalSeatsActive surfaces the
//      filter set
//   6. host.id diagnostic still surfaces even when
//      HostAlignment is filtered out

import XCTest
@testable import BASOrchestration
@testable import BASHostKit
@testable import BASMemory
@testable import BASSovereign
@testable import BASRuntimeCore
@testable import BASPolicy

final class BASChapter1001ActiveAgentsWireTests: XCTestCase {

    // MARK: - canonicalRoles normalization

    func testCanonicalRoles_NormalizesCaseAndAliases() {
        // Standard names (case-insensitive)
        let standard = BASAgentFabricHostPipeline
            .canonicalRoles(fromActiveAgents: [
                "Memory", "critic", "HostAlignment",
                "sovereignSentinel", "EvolutionShadow",
            ])
        XCTAssertEqual(standard,
            ["memory", "critic", "hostAlignment",
             "sovereignSentinel", "evolutionShadow"])
        // Aliases recognized
        let aliases = BASAgentFabricHostPipeline
            .canonicalRoles(fromActiveAgents: [
                "hostalign", "sentinel", "evolution",
            ])
        XCTAssertEqual(aliases,
            ["hostAlignment", "sovereignSentinel",
             "evolutionShadow"],
            "ch 1001: aliases hostalign/sentinel/evolution " +
            "MUST normalize to canonical role names")
    }

    func testCanonicalRoles_DropsUnrecognized() {
        // Mandatory seats (Planner/Risk/etc.) are NOT in the
        // canonical filter set — they're always-on
        let result = BASAgentFabricHostPipeline
            .canonicalRoles(fromActiveAgents: [
                "Planner", "Memory", "InvalidRole",
            ])
        XCTAssertEqual(result, ["memory"],
            "ch 1001: unrecognized entries silently dropped;" +
            " mandatory-seat names (Planner) also dropped " +
            "since they don't gate optional-seat filtering")
    }

    func testCanonicalRoles_TrimsWhitespace() {
        let result = BASAgentFabricHostPipeline
            .canonicalRoles(fromActiveAgents: [
                "  Memory  ", " Critic ",
            ])
        XCTAssertEqual(result, ["memory", "critic"])
    }

    // MARK: - Wire behavior: empty filter = no filtering

    func testCRITICAL_EmptyActiveAgents_NoFiltering()
        async throws
    {
        let fabric = makeNineSeatFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.1",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
                // No BAS_ACTIVE_AGENTS → no filter
            ])
        let outcome = try await pipeline.runTurn(
            turnID: "t.1",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()],
            memoryInput: BASMemorySeatInput(
                episodeArcs: ["a"], conflictClusters: [],
                continuityAnchors: ["c"], recallStrength: 0.7),
            sovereignSentinelInput:
                BASSovereignSentinelInput(candidates: [
                    BASSovereignSentinelCandidate(
                        candidateID: "c.1", title: "test",
                        reversibility: 0.5,
                        touchesAxesCount: 1,
                        touchesSovereignLockedAxis: true)]),
            evolutionShadowInput:
                BASEvolutionShadowInput(updateTickets: [
                    BASEvolutionUpdateTicket(
                        ticketID: "t.1", targetRef: "r",
                        summary: "s", scopeImpact: 0.5)]))
        XCTAssertTrue(outcome.activated)
        XCTAssertEqual(
            outcome.diagnostics["filter.optionalSeatsActive"],
            "(no-filter)",
            "ch 1001 CRITICAL: empty BAS_ACTIVE_AGENTS = no " +
            "filter (backward compat)")
        // All 3 supplied optional seats should emit deltas
        let emittedRefs = outcome.result?.turnResult
            .emittedDeltas.map { $0.targetObjectRef } ?? []
        XCTAssertTrue(emittedRefs.contains {
            $0.hasPrefix("memoryBundle#")
        }, "ch 1001: no filter → Memory delta emitted")
        XCTAssertTrue(emittedRefs.contains {
            $0.hasPrefix("sovereignVerdict#")
        }, "ch 1001: no filter → Sovereign delta emitted")
        XCTAssertTrue(emittedRefs.contains {
            $0.hasPrefix("evolutionProposal#")
        }, "ch 1001: no filter → Evolution delta emitted")
    }

    // MARK: - Wire behavior: filter excludes optional seats

    func testCRITICAL_FilterExcludes_OptionalSeatsSkipped()
        async throws
    {
        let fabric = makeNineSeatFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.1",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
                "BAS_ACTIVE_AGENTS": "Memory",
                // Only Memory listed → other optional seats
                // get nil inputs → no deltas emitted by them
            ])
        let outcome = try await pipeline.runTurn(
            turnID: "t.1",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()],
            memoryInput: BASMemorySeatInput(
                episodeArcs: ["a"], conflictClusters: [],
                continuityAnchors: ["c"], recallStrength: 0.7),
            sovereignSentinelInput:
                BASSovereignSentinelInput(candidates: [
                    BASSovereignSentinelCandidate(
                        candidateID: "c.1", title: "test",
                        reversibility: 0.5,
                        touchesAxesCount: 1,
                        touchesSovereignLockedAxis: true)]),
            evolutionShadowInput:
                BASEvolutionShadowInput(updateTickets: [
                    BASEvolutionUpdateTicket(
                        ticketID: "t.1", targetRef: "r",
                        summary: "s", scopeImpact: 0.5)]))
        XCTAssertTrue(outcome.activated)
        XCTAssertEqual(
            outcome.diagnostics["filter.optionalSeatsActive"],
            "memory",
            "ch 1001 CRITICAL: filter set surfaces in " +
            "diagnostic for host visibility")
        let emittedRefs = outcome.result?.turnResult
            .emittedDeltas.map { $0.targetObjectRef } ?? []
        // Memory IS in filter → emits
        XCTAssertTrue(emittedRefs.contains {
            $0.hasPrefix("memoryBundle#")
        }, "ch 1001 CRITICAL: Memory in filter set → delta " +
           "emitted")
        // Sovereign + Evolution NOT in filter → NO emits
        XCTAssertFalse(emittedRefs.contains {
            $0.hasPrefix("sovereignVerdict#")
        }, "ch 1001 CRITICAL: Sovereign NOT in filter set → " +
           "input nilled → seat does NOT emit。 Pre-ch-1001 " +
           "this delta would have been emitted regardless of " +
           "env var (decorative-scaffold class).")
        XCTAssertFalse(emittedRefs.contains {
            $0.hasPrefix("evolutionProposal#")
        }, "ch 1001 CRITICAL: Evolution NOT in filter set → " +
           "input nilled → seat does NOT emit")
    }

    /// Defense:host.id diagnostic STILL surfaces even when
    /// HostAlignment is filtered out (the constitution is
    /// available to the pipeline regardless of seat-filter)。
    func testCRITICAL_HostIdSurfaces_EvenWhenHostAlignmentFiltered()
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
            agentFabric: makeNineSeatFabric())
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.1",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
                "BAS_ACTIVE_AGENTS": "Memory",
                // HostAlignment NOT in list → filtered out
            ])
        let outcome = try await pipeline.runTurn(
            turnID: "t.1",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()])
        XCTAssertEqual(
            outcome.diagnostics["host.id"], "user.alpha",
            "ch 1001: host.id diagnostic MUST surface from " +
            "ORIGINAL coordinator constitution, NOT the post-" +
            "filter effective constitution (which is nil " +
            "since HostAlignment isn't in activeAgents)")
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

    private func makeNineSeatFabric() -> BASAgentFabricRuntime {
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
                    visibility: .medium)),
            graph: BASSharedStateGraph())
    }

    private func makeCand() -> BASCandidatePath {
        BASCandidatePath(
            candidateID: "c.1",
            title: "test",
            actionSummary: "a",
            expectedBenefit: 0.3,
            expectedCost: 0.6,
            reversibility: 0.5,
            confidence: 0.5)
    }
}
