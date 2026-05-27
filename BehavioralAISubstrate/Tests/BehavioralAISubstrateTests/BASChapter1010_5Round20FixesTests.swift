// MARK: - BASChapter1010_5Round20FixesTests
// chapter 一千零十.5 / M3760 — Round-20 self-audit fix-of-fixes
//
// Round-20 self-audit caught 3 CRITICAL + 3 HIGH + 5 MED + 4 LOW
// findings across the「全面 收口 scaffold」arc (ch 1006-1010)。
// Same Round-19 lesson:cascade discipline must hunt same-class
// bugs at every shipped artifact。
//
// This sub-chapter ships the fixes + pin tests that prevent
// regression:
//
//   CRITICAL-1: confidence-formula duplication between ch 1002
//     TraceAnnotator and ch 1006 ObservationAuditEmitter →
//     single canonical helper `confidenceForAgentSet(count:)`
//   CRITICAL-2: ch 1006 signalRefs separator-injection (`:`,
//     `=`,`,` collisions) → U+001F + U+001E separators per
//     ch 982.5 lesson
//   CRITICAL-3: ch 1008 diagnostic separator-injection → same
//     U+001F discipline
//   HIGH-1: validator hardcoded role names drift from
//     BASAgentRole enum → exhaustive switch + derive at type-
//     init
//   HIGH-2: ch 1008 pipeline-level diagnostic emit untested →
//     behavioral test below
//   MED-1: ch 1006 confidence-band thresholds not tested at
//     boundaries → boundary tests below
//   MED-2: ch 1009 .compareSelected + empty selectedAgents
//     ambiguous semantic → pin test
//   MED-4: ch 1007 empty turnID accepted silently → pin test
//
// Tests pin all 8 fixes structurally so future regressions
// fail the suite。

import XCTest
import CryptoKit
@testable import BASMemory
@testable import BASSovereign
@testable import BASOrchestration
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASChapter1010_5Round20FixesTests: XCTestCase {

    // MARK: - CRITICAL-1: single canonical confidence formula

    func testCRITICAL_1_ConfidenceFormula_SingleCanonical()
        async throws
    {
        // Both call sites MUST delegate to the canonical
        // helper。 The helper returns deterministic output for
        // a given agent-count input。
        for count in 0..<10 {
            let canonical = BASTraceAnnotatorSeat
                .confidenceForAgentSet(count: count)
            let expected = min(
                1.0, 0.5 + (Double(count) * 0.1))
            XCTAssertEqual(canonical, expected, accuracy: 1e-9,
                "ch 1010.5 CRITICAL-1: canonical helper MUST " +
                "produce `min(1.0, 0.5 + count*0.1)` for " +
                "count=\(count)")
        }
        // Now verify BOTH ch 1002 + ch 1006 produce IDENTICAL
        // confidence for the same input — proves single-source
        // delegation。
        let deltas = [
            BASAgentDelta(
                deltaID: "delta.t.a.1",
                agentID: "alpha",
                targetObjectRef: "candidateFrontier#t",
                deltaType: .add,
                patchJson: "{}",
                confidence: 0.5),
            BASAgentDelta(
                deltaID: "delta.t.b.1",
                agentID: "beta",
                targetObjectRef: "candidateFrontier#t",
                deltaType: .add,
                patchJson: "{}",
                confidence: 0.5),
        ]
        let input = BASTraceAnnotatorInput(
            turnID: "t", emittedDeltas: deltas)
        let spec = BASAgentSpec(
            agentID: "trace",
            role: .scout,
            writeDomains: [.traceAnnotation],
            defaultLeaseProfile: .watcher,
            visibility: .low)
        var seq1 = 0; var seq2 = 0
        let deltaOut = BASTraceAnnotatorSeat.emit(
            from: input, agentSpec: spec, seq: &seq1)
        let obsOut = BASAgentObservationAuditEmitter
            .observationFromAnnotator(
                input: input, agentSpec: spec, seq: &seq2)
        XCTAssertEqual(deltaOut.count, 1)
        XCTAssertEqual(obsOut.count, 1)
        XCTAssertEqual(
            deltaOut[0].confidence,
            obsOut[0].confidence,
            accuracy: 1e-9,
            "ch 1010.5 CRITICAL-1: ch 1002 + ch 1006 MUST " +
            "produce byte-equal confidence for same input " +
            "(single canonical formula delegation)")
    }

    // MARK: - CRITICAL-2: signalRefs use U+001F + U+001E

    func testCRITICAL_2_SignalRefs_UseUnitSeparator() {
        let obs = BASAgentObservation(
            observationID: "obs.test",
            agentID: "agent:with:colons",
            observedDomain: .traceAnnotation,
            summary: "x",
            confidence: 0.5,
            flags: ["flag,with,commas", "flag=with=equals"])
        let refs = BASAgentObservationAuditEmitter
            .signalRefs(from: [obs])
        XCTAssertEqual(refs.count, 1)
        let ref = refs[0]
        // Inter-field separator MUST be U+001F
        XCTAssertTrue(ref.contains("\u{001F}agent="),
            "ch 1010.5 CRITICAL-2: ref MUST use U+001F " +
            "before `agent=` field — ch 982.5 lesson applied")
        XCTAssertTrue(ref.contains("\u{001F}domain="))
        XCTAssertTrue(ref.contains("\u{001F}flags="))
        XCTAssertTrue(ref.contains("\u{001F}conf="))
        // Flags joined with U+001E (record separator) so
        // legitimate `,` in flag values doesn't corrupt parsing
        XCTAssertTrue(
            ref.contains(
                "flag,with,commas\u{001E}flag=with=equals"),
            "ch 1010.5 CRITICAL-2: flags joined with U+001E,got: " +
            "\(ref)")
        // The injection-prone agentID with colons MUST NOT
        // create extra field boundaries — verify by counting
        // U+001F occurrences (exactly 4 = 4 inter-field
        // boundaries: agent / domain / flags / conf)
        let sep1FCount = ref.filter { $0 == "\u{001F}" }.count
        XCTAssertEqual(sep1FCount, 4,
            "ch 1010.5 CRITICAL-2: agentID with `:` MUST NOT " +
            "create extra field boundaries — exactly 4 U+001F " +
            "in ref, got \(sep1FCount): \(ref)")
    }

    // MARK: - CRITICAL-3: ch 1008 diagnostic uses U+001F

    func testCRITICAL_3_TierDiagnostic_UsesUnitSeparator() {
        // Use `.all` tier + injection attempt — `.all` mode
        // detects unknown names (catches typos / injection)。
        // `.core` mode only checks for watcher/skill names,
        // unknown names are silently allowed (kept as "future
        // core agent" by design)。
        let activation = BASAgentFabricGate.Activation(
            fabricEnabled: true,
            tier: .all,
            transcriptMode: .singleAgent,
            activeAgents: [
                "Planner",  // legitimate core seat
                "evil:tier=all:agent=injected",  // injection
            ])
        let diag = BASAgentTierActivationValidator
            .validate(activation)
        // 1 mismatch diagnostic (only the unknown name
        // triggers,Planner is legitimate)。 Separator
        // discipline ensures the diagnostic STRING uses U+001F
        // so downstream parsers cannot be fooled by `:` in
        // the agent name itself。
        XCTAssertEqual(diag.count, 1,
            "ch 1010.5 CRITICAL-3: exactly 1 mismatch (the " +
            "injection name);Planner is a legitimate core seat")
        let d = diag[0]
        // Diagnostic uses U+001F not `:` for top-level field
        // boundaries — even though the injected name contains
        // multiple `:`,the diagnostic class prefix
        // (tier.mismatch) is still extractable via U+001F
        // split rather than ambiguous `:` split
        XCTAssertTrue(
            d.contains("tier.mismatch\u{001F}"),
            "ch 1010.5 CRITICAL-3: diagnostic MUST use " +
            "U+001F after class prefix, got: \(d)")
        // Verify exactly 2 U+001F (one after class prefix,
        // one before agent= field) — proves the injection
        // doesn't create extra boundaries
        let sepCount = d.filter { $0 == "\u{001F}" }.count
        XCTAssertEqual(sepCount, 2,
            "ch 1010.5 CRITICAL-3: exactly 2 U+001F field " +
            "boundaries — injection name's `:` chars MUST " +
            "NOT create extra boundaries。 Got \(sepCount) " +
            "in: \(d)")
    }

    // MARK: - HIGH-1: validator name sets derived from enum

    func testCRITICAL_HIGH_1_NameSetsDerivedFromEnum() {
        // The validator's coreSeatNames MUST exactly match the
        // 9 core BASAgentRole cases (lowercased rawValue)。 If
        // a future arc adds a 10th core case,this test fires
        // because the derivation includes it but the expected
        // set below doesn't。 The exhaustive switch in
        // BASAgentTierActivationValidator.category(of:) ALSO
        // fails compile in that scenario — defense in depth。
        let expectedCore: Set<String> = [
            "scout", "memory", "planner", "critic",
            "hostalignment", "risk", "surface",
            "sovereignsentinel", "evolutionshadow",
        ]
        XCTAssertEqual(
            BASAgentTierActivationValidator.coreSeatNames,
            expectedCore,
            "ch 1010.5 HIGH-1: coreSeatNames MUST be derived " +
            "from BASAgentRole enum — adding a new case bumps " +
            "both this set + the exhaustive switch")
        let expectedWatchers: Set<String> = [
            "anomalywatcher", "gaslightwatcher",
            "memorypollutionwatcher", "hostdriftwatcher",
            "toolinjectionwatcher", "axisdeviationwatcher",
            "sanctumleakwatcher",
        ]
        XCTAssertEqual(
            BASAgentTierActivationValidator.watcherNames,
            expectedWatchers,
            "ch 1010.5 HIGH-1: watcherNames MUST be derived " +
            "from BASAgentRole enum")
    }

    // MARK: - HIGH-2: host-pipeline behavioral test for ch 1008
    //
    // ch 1008 added `diagnostics["gate.tierValidation"]` to
    // the host pipeline。 Pre-fix the diagnostic emit had no
    // behavioral pipeline test — only the validator's
    // unit-test coverage。 A refactor that drops the
    // pipeline emit would pass all ch 1008 unit tests but
    // silently lose the wire。

    func testCRITICAL_HIGH_2_PipelineEmitsTierValidationDiag()
        async throws
    {
        let fabric = makeNineSeatFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.tier.test",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
                "BAS_AGENT_TIER": "core",
                "BAS_ACTIVE_AGENTS":
                    "Planner,Critic,Memory",
            ])
        let outcome = try await pipeline.runTurn(
            turnID: "t.tier.1",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()])
        XCTAssertTrue(outcome.activated)
        let tierDiag = outcome.diagnostics[
            "gate.tierValidation"]
        XCTAssertNotNil(tierDiag,
            "ch 1010.5 HIGH-2: pipeline MUST emit " +
            "gate.tierValidation diagnostic when fabric runs")
        XCTAssertTrue(
            tierDiag?.contains("tier.consistent") ?? false,
            "ch 1010.5 HIGH-2: tier.core + core seat names = " +
            "consistent diagnostic. Got: \(tierDiag ?? "nil")")
    }

    func test_HIGH_2_PipelineEmitsMismatchOnInvalidCombo()
        async throws
    {
        let fabric = makeNineSeatFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.tier.bad",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
                "BAS_AGENT_TIER": "core",
                "BAS_ACTIVE_AGENTS":
                    "anomalyWatcher,Planner",
            ])
        let outcome = try await pipeline.runTurn(
            turnID: "t.tier.2",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()])
        let tierDiag = outcome.diagnostics[
            "gate.tierValidation"]
        XCTAssertTrue(
            tierDiag?.contains("tier.mismatch") ?? false,
            "ch 1010.5 HIGH-2: tier.core + watcher name = " +
            "mismatch diagnostic must appear in pipeline " +
            "diagnostics. Got: \(tierDiag ?? "nil")")
    }

    // MARK: - MED-1: confidence band boundary cases

    func test_MED_1_ConfidenceBands_AtExactBoundaries() {
        // band thresholds: <0.4 → low, <0.7 → med, >=0.7 → high
        // boundary cases:
        //   conf=0.3999 → low (just under 0.4)
        //   conf=0.4    → med (exactly 0.4)
        //   conf=0.6999 → med (just under 0.7)
        //   conf=0.7    → high (exactly 0.7)
        let cases: [(conf: Double, expectedBand: String)] = [
            (0.0, "low"),
            (0.3999, "low"),
            (0.4, "med"),
            (0.5, "med"),
            (0.6999, "med"),
            (0.7, "high"),
            (1.0, "high"),
        ]
        for (conf, expectedBand) in cases {
            let obs = BASAgentObservation(
                observationID: "obs.\(conf)",
                agentID: "a",
                observedDomain: .traceAnnotation,
                summary: "",
                confidence: conf)
            let refs = BASAgentObservationAuditEmitter
                .signalRefs(from: [obs])
            XCTAssertEqual(refs.count, 1)
            XCTAssertTrue(
                refs[0].contains("conf=\(expectedBand)"),
                "ch 1010.5 MED-1: conf=\(conf) MUST → band " +
                "\(expectedBand), got ref: \(refs[0])")
        }
    }

    // MARK: - MED-2: compareSelected + empty selectedAgents

    func test_MED_2_CompareSelected_EmptySelection_ReturnsEmpty() {
        let deltas = [
            BASAgentDelta(
                deltaID: "d.1",
                agentID: "planner",
                targetObjectRef: "candidateFrontier#t",
                deltaType: .add,
                patchJson: "{}",
                confidence: 0.5),
        ]
        let result = BASAgentFabricTranscriptProjection
            .summarize(
                deltas: deltas,
                mode: .compareSelected,
                selectedAgents: [])
        // PIN the semantic: empty selectedAgents in
        // compareSelected mode returns summary with empty
        // perAgent + totalDeltas=0 (NOT nil)。 Hosts can
        // distinguish "no selection requested" from "selection
        // but nothing matched" by checking selectedAgents
        // field。
        XCTAssertNotNil(result,
            "ch 1010.5 MED-2: .compareSelected MUST return " +
            "non-nil summary even with empty selectedAgents")
        XCTAssertEqual(result?.perAgent.count, 0,
            "ch 1010.5 MED-2: empty selection → empty perAgent")
        XCTAssertEqual(result?.totalDeltas, 0)
        XCTAssertEqual(result?.selectedAgents, [],
            "ch 1010.5 MED-2: selectedAgents echo MUST be empty")
    }

    // MARK: - MED-4: ch 1007 empty turnID pin test

    func test_MED_4_FabricMode_EmptyTurnID_StillBuildsEntry() {
        // PIN the current semantic: empty turnID does NOT
        // throw at buildEntry — the ledger contract only
        // rejects empty sessionID。 Future hardening can flip
        // this to throw,but for now the test pins what
        // happens so the behavior is explicit。
        let entry = BASAgentFabricModeAuditEmitter.buildEntry(
            mode: .authoritative,
            sessionID: "s",
            turnID: "")
        XCTAssertFalse(entry.auditID.isEmpty,
            "ch 1010.5 MED-4: empty turnID still produces a " +
            "non-empty auditID (current pin — future arc may " +
            "harden to throw)")
        // The auditID contains a `..` substring when turnID
        // is empty — this is observable via grep so hosts can
        // detect the case in audit replay
        XCTAssertTrue(
            entry.auditID.contains(".."),
            "ch 1010.5 MED-4: empty-turnID auditID is " +
            "observable via `..` substring in replay — pin " +
            "so future hardening (throw on empty turnID) " +
            "fails this test explicitly")
    }

    // MARK: - Test fixtures (copied from ch 1001 pattern)

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
                    visibility: .high)),
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
