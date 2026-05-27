// MARK: - BASChapter1014_6Round23FixesTests
// chapter 一千零十四.6 / M3795 — Round-23 self-audit fix-of-fix-
// of-fix-of-fix (4th depth of cascade fix-chapter)
//
// Round-23 audit caught 5 CRITICAL + 7 HIGH + 9 MED + 2 LOW
// findings。 Cascade catch counts:
//   Round-19: 1 CRITICAL
//   Round-20: 3 CRITICAL
//   Round-21: 5 CRITICAL
//   Round-22: 2 CRITICAL
//   Round-23: 5 CRITICAL
//
// The cascade is NOT yet asymptoting — fresh sites of OLD bug
// classes keep surfacing at NEW code paths。
//
// Substantive fixes in this sub-chapter:
//   CRITICAL-1: pipeline early-return paths now emit
//     inspector.* keys via shared assembleOutcome helper
//   CRITICAL-3: ShadowTrialCoordinator 5 verdictRef sites
//     adopt U+001F separator (was using `:` injection-class)
//   CRITICAL-4: ch 1006 observationID JSON-escapes turnID
//     (was raw — same class as the LOW-1 fix that only got
//     the summary field)
//   CRITICAL-5: ch 1002 TraceAnnotator deltaID + targetObjectRef
//     JSON-escape turnID (same JSON-corruption surface as
//     CRITICAL-4)
//   HIGH-1: BASAgentObservationAuditEmitter wired into the
//     pipeline (was 💀 DEAD per Round-23 grep — only tests
//     consumed it)
//   HIGH-2: BASAgentFabricWatcherCollector.signalRefs now
//     consumed by pipeline (was 💀 DEAD)
//   HIGH-3: inspector.* keys restructured — single
//     `inspector.summary` JSON-encoded key replaces 3 byte-
//     equal-alias keys。 Genuinely-new typed signal vs
//     pre-existing diagnostics dict
//
// Tests pin each fix structurally。

import XCTest
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRuntimeCore
@testable import BASOrchestration
@testable import BASHostKit

final class BASChapter1014_6Round23FixesTests: XCTestCase {

    // MARK: - CRITICAL-1: inspector keys on early-return paths

    func testCRITICAL_1_SkippedPath_EmitsInspectorKeys()
        async throws
    {
        // No fabric configured → early return path。 Pre-fix
        // inspector keys were missing。 Post-fix they're
        // present。
        let coordinator = makeCoordinator(fabric: nil)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.skip",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
            ])
        let outcome = try await pipeline.runTurn(
            turnID: "t.skip",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [])
        XCTAssertFalse(outcome.activated)
        XCTAssertNotNil(
            outcome.diagnostics["inspector.category"],
            "ch 1014.6 CRITICAL-1: skipped path MUST emit " +
            "inspector.category diagnostic")
        XCTAssertNotNil(
            outcome.diagnostics["inspector.summary"],
            "ch 1014.6 CRITICAL-1: skipped path MUST emit " +
            "inspector.summary diagnostic")
        XCTAssertEqual(
            outcome.diagnostics["inspector.category"],
            "fabric.run.unconfigured",
            "ch 1014.6 CRITICAL-1: nil-fabric path → " +
            "fabric.run.unconfigured category")
    }

    func testCRITICAL_1_DisabledFabric_EmitsInspectorKeys()
        async throws
    {
        let fabric = makeNineSeatFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.disabled",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "disabled",
            ])
        let outcome = try await pipeline.runTurn(
            turnID: "t.disabled",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [])
        XCTAssertFalse(outcome.activated)
        XCTAssertNotNil(
            outcome.diagnostics["inspector.category"],
            "ch 1014.6 CRITICAL-1: disabled-fabric path MUST " +
            "emit inspector.category")
        XCTAssertEqual(
            outcome.diagnostics["inspector.category"],
            "fabric.run.skipped",
            "ch 1014.6: disabled-fabric path → skipped category")
    }

    // MARK: - CRITICAL-3: ShadowTrial U+001F separator

    #if !os(iOS)  // ch 1022 source-gate: reads Mac dev tree
    func testCRITICAL_3_ShadowTrial_VerdictRef_UsesUnitSeparator()
        throws
    {
        // Grep the source — verify 0 raw `shadow_trial:` /
        // `evolution_seal:` / `retraction:` patterns at
        // verdictRef sites remain。
        let projectRoot =
            ProcessInfo.processInfo.environment[
                "BAS_PROJECT_ROOT"] ??
            "/Users/changgeng/Project/Project06/Project06/" +
            "BehavioralAISubstrate"
        let path =
            "\(projectRoot)/Sources/BASMemory/" +
            "ShadowTrialCoordinator.swift"
        let content = try String(
            contentsOfFile: path, encoding: .utf8)
        // verdictRef: "shadow_trial:..." pattern MUST NOT
        // appear (post-fix all use \u{001F})
        XCTAssertFalse(
            content.contains("verdictRef: \"shadow_trial:"),
            "ch 1014.6 CRITICAL-3: ShadowTrialCoordinator MUST " +
            "use U+001F separator,not `:`,for shadow_trial " +
            "verdictRef")
        XCTAssertFalse(
            content.contains("verdictRef: \"evolution_seal:"),
            "ch 1014.6 CRITICAL-3: ShadowTrialCoordinator MUST " +
            "use U+001F separator for evolution_seal verdictRef")
        XCTAssertFalse(
            content.contains("verdictRef:\n" +
                "                    \"retraction:"),
            "ch 1014.6 CRITICAL-3: retraction verdictRef uses " +
            "U+001F separator")
        // Positive check: U+001F MUST be present
        XCTAssertTrue(
            content.contains("\"shadow_trial\\u{001F}"),
            "ch 1014.6 CRITICAL-3: shadow_trial verdictRef MUST " +
            "use U+001F (escape sequence in source)")
    }
    #endif

    // MARK: - CRITICAL-4 + CRITICAL-5: JSON-escape siblings

    func testCRITICAL_4_5_TraceAnnotator_JSONEscapesTurnID() {
        let trickyTurnID = "t-with-\"quote\"\nand\nnewlines"
        let input = BASTraceAnnotatorInput(
            turnID: trickyTurnID,
            emittedDeltas: [
                BASAgentDelta(
                    deltaID: "d.1", agentID: "a",
                    targetObjectRef: "candidateFrontier#t",
                    deltaType: .add,
                    patchJson: "{}",
                    confidence: 0.5),
            ])
        let spec = BASAgentSpec(
            agentID: "trace", role: .scout,
            writeDomains: [.traceAnnotation],
            defaultLeaseProfile: .watcher,
            visibility: .low)
        // ch 1014.6 CRITICAL-5: deltaID + targetObjectRef
        // also use escaped turnID (LOW-1 only fixed summary)
        var seq = 0
        let deltas = BASTraceAnnotatorSeat.emit(
            from: input, agentSpec: spec, seq: &seq)
        XCTAssertEqual(deltas.count, 1)
        let delta = deltas[0]
        // Raw newline / quote MUST NOT appear in deltaID or
        // targetObjectRef
        XCTAssertFalse(delta.deltaID.contains("\n"),
            "ch 1014.6 CRITICAL-5: deltaID MUST escape newline")
        XCTAssertFalse(
            delta.targetObjectRef.contains("\n"),
            "ch 1014.6 CRITICAL-5: targetObjectRef MUST escape " +
            "newline")
        // ch 1014.6 CRITICAL-4: observation ID also escapes
        var obsSeq = 0
        let observations = BASAgentObservationAuditEmitter
            .observationFromAnnotator(
                input: input, agentSpec: spec, seq: &obsSeq)
        XCTAssertEqual(observations.count, 1)
        XCTAssertFalse(
            observations[0].observationID.contains("\n"),
            "ch 1014.6 CRITICAL-4: observationID MUST escape " +
            "newline in turnID")
    }

    // MARK: - HIGH-1: BASAgentObservationAuditEmitter wired

    func testHIGH_1_ObservationAuditEmitter_ConsumedByPipeline()
        async throws
    {
        let fabric = makeNineSeatFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.obs",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
            ])
        let outcome = try await pipeline.runTurn(
            turnID: "t.obs",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()])
        XCTAssertNotNil(
            outcome.diagnostics["observation.signalRefs"],
            "ch 1014.6 HIGH-1: pipeline MUST emit " +
            "observation.signalRefs proving ObservationAuditEmitter " +
            "is consumed")
    }

    // MARK: - HIGH-2: WatcherCollector.signalRefs consumed

    func testHIGH_2_WatcherCollector_SignalRefs_ConsumedByPipeline()
        async throws
    {
        let fabric = makeNineSeatFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.watch",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
                "BAS_AGENT_TIER": "all",
            ])
        let outcome = try await pipeline.runTurn(
            turnID: "t.watch",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()])
        XCTAssertNotNil(
            outcome.diagnostics["watcher.signalRefs"],
            "ch 1014.6 HIGH-2: .all tier MUST emit " +
            "watcher.signalRefs diagnostic")
        // .core tier produces sentinel
        let coreOutcome = try await BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.watch.core",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
                "BAS_AGENT_TIER": "core",
            ])
            .runTurn(
                turnID: "t.watch.core",
                decomposeFrame: BASDecomposeFrame(),
                candidatePaths: [makeCand()])
        XCTAssertEqual(
            coreOutcome.diagnostics["watcher.signalRefs"],
            BASAgentFabricHostOutcomeInspector
                .coreTierSentinel,
            "ch 1014.6 HIGH-2: .core tier emits sentinel for " +
            "watcher.signalRefs")
    }

    // MARK: - HIGH-3: inspector.summary replaces 3 alias keys

    func testHIGH_3_InspectorSummary_IsCanonicalTypedSignal()
        async throws
    {
        let fabric = makeNineSeatFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.summ",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
            ])
        let outcome = try await pipeline.runTurn(
            turnID: "t.summ",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()])
        let summaryJSON = outcome.diagnostics[
            "inspector.summary"]
        XCTAssertNotNil(summaryJSON,
            "ch 1014.6 HIGH-3: pipeline MUST emit " +
            "inspector.summary JSON")
        // Decode + verify the canonical typed shape
        guard let data = summaryJSON?.data(using: .utf8)
        else {
            XCTFail("ch 1014.6: inspector.summary not UTF-8")
            return
        }
        let decoded = try JSONDecoder().decode(
            BASAgentFabricHostOutcomeSummary.self, from: data)
        XCTAssertTrue(decoded.activated)
        XCTAssertEqual(decoded.tier, "core")
        XCTAssertEqual(decoded.fabricMode, "observationOnly")
    }

    // MARK: - Test fixtures

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

    private func makeNineSeatFabric() -> BASAgentFabricRuntime {
        BASAgentFabricRuntime(
            roster: BASAgentTurnRoster(
                scout: BASAgentSpec(
                    agentID: "scout.1", role: .scout,
                    writeDomains: [.situationField],
                    defaultLeaseProfile: .hotSeat,
                    visibility: .high),
                planner: BASAgentSpec(
                    agentID: "planner.1", role: .planner,
                    writeDomains: [.candidateFrontier],
                    defaultLeaseProfile: .hotSeat,
                    visibility: .high),
                risk: BASAgentSpec(
                    agentID: "risk.1", role: .risk,
                    writeDomains: [.riskField],
                    defaultLeaseProfile: .hotSeat,
                    visibility: .high),
                surface: BASAgentSpec(
                    agentID: "surface.1", role: .surface,
                    writeDomains: [.renderFrame],
                    defaultLeaseProfile: .hotSeat,
                    visibility: .high)),
            graph: BASSharedStateGraph())
    }

    private func makeCand() -> BASCandidatePath {
        BASCandidatePath(
            candidateID: "c.1", title: "test",
            actionSummary: "a",
            expectedBenefit: 0.3,
            expectedCost: 0.6,
            reversibility: 0.5,
            confidence: 0.5)
    }
}
