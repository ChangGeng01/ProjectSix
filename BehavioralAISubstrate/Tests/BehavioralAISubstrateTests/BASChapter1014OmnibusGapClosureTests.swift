// MARK: - BASChapter1014OmnibusGapClosureTests
// chapter 一千零十四 / M3785 — 全面 一次性 完成 gap omnibus
//
// User invoked「全面 一次性 完成 gap 最努力 最 wired 最 满意
// 诚实模式」 — comprehensive one-shot gap closure with honest
// scope。 This chapter closes everything genuinely closable in
// a single shot:
//
//   1. HostOutcome substrate-side consumer wire (the LAST
//      remaining 🪜 SCAFFOLD trio: HostOutcome / .activation /
//      .fabricMode)
//   2. tierReadByExecutorInProduction honest split (closes
//      doctrine gap on chapter-500 invariant without lying
//      about substrate behavior)
//   3. Round-21 LOW-1: JSON-escape ch 1006 summary turnID
//   4. Round-21 LOW-2: ch 1007 defense commentary docstring
//
// What stays scaffold HONESTLY:
//   - `consultedByExecutorInProduction = false` (still false
//     — dispatch-branching semantic is genuinely multi-chapter
//     Phase 9++ scope)
//   - LOW-3: skill agents not in BASAgentRole enum (waits for
//     PHASE 6 to ship those cases)
//   - LOW-5: empty-turnID accepted silently (deferred —
//     hardening to throw would break callers without genuine
//     security benefit since downstream ledger rejects empty
//     sessionID,closing the actual attack surface)
//
// Tests pin all 4 closures + 1 honest-scope assertion that the
// remaining items STAY correctly-scoped scaffold。

import XCTest
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRuntimeCore
@testable import BASOrchestration
@testable import BASHostKit

final class BASChapter1014OmnibusGapClosureTests: XCTestCase {

    // MARK: - 1. HostOutcomeInspector — substrate consumer

    func testCRITICAL_Inspector_Summarize_BuildsCorrectSummary() {
        let activation = BASAgentFabricGate.Activation(
            fabricEnabled: true,
            tier: .core,
            transcriptMode: .singleAgent,
            activeAgents: [])
        let outcome = BASAgentFabricHostOutcome(
            result: nil,  // skipped run
            activated: false,
            skipReason: "test",
            activation: activation,
            fabricMode: .observationOnly,
            diagnostics: ["watcher.hintCount": "(core-tier)"])
        let summary = BASAgentFabricHostOutcomeInspector
            .summarize(outcome: outcome)
        XCTAssertFalse(summary.activated)
        XCTAssertEqual(summary.tier, "core")
        XCTAssertEqual(summary.fabricMode, "observationOnly")
        XCTAssertEqual(summary.deltaCount, 0)
        XCTAssertNil(summary.watcherHintCount,
            "ch 1014: `(core-tier)` sentinel MUST parse to " +
            "nil watcherHintCount (type-safe sentinel handling)")
        XCTAssertEqual(summary.skipReason, "test")
    }

    func testCRITICAL_Inspector_Category_Unconfigured() {
        let outcome = BASAgentFabricHostOutcome(
            result: nil,
            activated: false,
            activation: BASAgentFabricGate.Activation(),
            fabricMode: nil,  // no fabric configured
            diagnostics: [:])
        let category = BASAgentFabricHostOutcomeInspector
            .category(outcome: outcome)
        XCTAssertEqual(category, "fabric.run.unconfigured",
            "ch 1014: nil fabricMode → unconfigured category")
    }

    func testCRITICAL_Inspector_Category_Skipped() {
        let outcome = BASAgentFabricHostOutcome(
            result: nil,
            activated: false,
            skipReason: "gate disabled",
            activation: BASAgentFabricGate.Activation(),
            fabricMode: .observationOnly,
            diagnostics: [:])
        let category = BASAgentFabricHostOutcomeInspector
            .category(outcome: outcome)
        XCTAssertEqual(category, "fabric.run.skipped",
            "ch 1014: activated=false + fabricMode set → skipped")
    }

    /// Helper to build a minimal non-nil `BASAgentFabricFullTurnResult`
    /// — needed since ch 1014.5 CRITICAL-2 fix added the
    /// `fabric.run.no-result` category for `result == nil` outcomes。
    /// Tests that want to exercise the `clean` / `hints` categories
    /// must construct a non-nil result fixture。
    private static func makeMinimalResult()
        -> BASAgentFabricFullTurnResult
    {
        let turnResult = BASAgentTurnResult(
            emittedDeltas: [],
            mergeResult: BASAgentMergeResult(
                mergeID: "merge.test",
                acceptedDeltaIDs: [],
                rejectedDeltaIDs: [],
                conflictResolution: [],
                resultingStateRef: "",
                mergeReasonCodes: []),
            applyOutcomes: [],
            finalSeq: 0)
        return BASAgentFabricFullTurnResult(
            turnResult: turnResult,
            frontierProjection: BASCandidateFrontier(
                candidateIDs: [],
                dominanceOrder: [],
                frontierWidth: 0))
    }

    func testCRITICAL_Inspector_Category_Clean() {
        let activation = BASAgentFabricGate.Activation(
            fabricEnabled: true,
            tier: .core,
            transcriptMode: .singleAgent,
            activeAgents: [])
        let outcome = BASAgentFabricHostOutcome(
            // ch 1014.5 CRITICAL-2 fix: clean category requires
            // non-nil result — nil result now categorizes as
            // fabric.run.no-result
            result: Self.makeMinimalResult(),
            activated: true,
            activation: activation,
            fabricMode: .observationOnly,
            diagnostics: [
                "watcher.hintCount":
                    BASAgentFabricHostOutcomeInspector
                        .coreTierSentinel,
            ])
        let category = BASAgentFabricHostOutcomeInspector
            .category(outcome: outcome)
        XCTAssertEqual(category, "fabric.run.clean",
            "ch 1014: activated + non-nil result + no hints " +
            "→ clean category")
        XCTAssertTrue(
            BASAgentFabricHostOutcomeInspector
                .isCleanRun(outcome: outcome))
    }

    func testCRITICAL_Inspector_Category_Hints() {
        let activation = BASAgentFabricGate.Activation(
            fabricEnabled: true,
            tier: .all,
            transcriptMode: .singleAgent,
            activeAgents: [])
        let outcome = BASAgentFabricHostOutcome(
            // ch 1014.5 CRITICAL-2 fix: non-nil result required
            result: Self.makeMinimalResult(),
            activated: true,
            activation: activation,
            fabricMode: .observationOnly,
            diagnostics: [
                "watcher.hintCount": "3",
                "watcher.rolesActive": "anomalyWatcher",
            ])
        let category = BASAgentFabricHostOutcomeInspector
            .category(outcome: outcome)
        XCTAssertEqual(category, "fabric.run.hints",
            "ch 1014: activated + non-nil result + hints>0 " +
            "→ hints category")
        XCTAssertFalse(
            BASAgentFabricHostOutcomeInspector
                .isCleanRun(outcome: outcome))
    }

    // MARK: - ch 1014.5 CRITICAL-2 — no-result category

    func testCRITICAL_5_NoResultCategory_DistinctFromClean() {
        // activated=true + result=nil now correctly produces
        // fabric.run.no-result (NOT fabric.run.clean which
        // would silently lie about a substantive failure state)
        let outcome = BASAgentFabricHostOutcome(
            result: nil,  // adapter returned nil
            activated: true,
            activation: BASAgentFabricGate.Activation(
                fabricEnabled: true,
                tier: .core,
                transcriptMode: .singleAgent,
                activeAgents: []),
            fabricMode: .observationOnly,
            diagnostics: [:])
        let category = BASAgentFabricHostOutcomeInspector
            .category(outcome: outcome)
        XCTAssertEqual(category, "fabric.run.no-result",
            "ch 1014.5 CRITICAL-2 fix: nil-result MUST NOT " +
            "silently classify as clean。 Distinct category " +
            "fabric.run.no-result for replay tooling")
        XCTAssertFalse(
            BASAgentFabricHostOutcomeInspector
                .isCleanRun(outcome: outcome),
            "ch 1014.5: no-result MUST NOT pass isCleanRun")
    }

    // MARK: - ch 1014.5 CRITICAL-1 — sentinel constant

    func testCRITICAL_6_SentinelConstant_SingleCanonical() {
        // The sentinel constant exists + has the expected value
        // — pipeline AND inspector both reference the constant
        // instead of hardcoding the literal "(core-tier)"
        XCTAssertEqual(
            BASAgentFabricHostOutcomeInspector
                .coreTierSentinel,
            "(core-tier)",
            "ch 1014.5 CRITICAL-1: shared sentinel constant " +
            "value sanity check")
    }

    // MARK: - ch 1014.5 HIGH-1 — Summary consumed by pipeline

    func testHIGH_1_SummaryConsumed_PipelineEmitsSummaryFields()
        async throws
    {
        // ch 1014.6 / M3795 — Round-23 HIGH-3 evolved: pre-ch-
        // 1014.6 the pipeline emitted 3 separate keys
        // (inspector.tier / .deltaCount / .watcherHintCount)
        // that were byte-equal aliases for existing diagnostics
        // (gate.tier / deltas.emitted / watcher.hintCount) —
        // hollow consumer。 Post-fix the pipeline emits a SINGLE
        // `inspector.summary` JSON-encoded key carrying the
        // typed Summary bundle。 Genuinely-new information vs
        // existing diagnostics (the typed shape is the value-add)。
        let fabric = makeNineSeatFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.summary",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
            ])
        let outcome = try await pipeline.runTurn(
            turnID: "t.summary",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()])
        // The Summary type IS consumed via JSON serialization
        // to the inspector.summary diagnostic
        let summaryJSON = outcome.diagnostics[
            "inspector.summary"]
        XCTAssertNotNil(summaryJSON,
            "ch 1014.6 HIGH-3: pipeline MUST emit " +
            "inspector.summary JSON-encoded key")
        // Decode + verify Summary fields
        let data = summaryJSON?.data(using: .utf8)
        XCTAssertNotNil(data)
        if let data {
            let decoded = try? JSONDecoder().decode(
                BASAgentFabricHostOutcomeSummary.self,
                from: data)
            XCTAssertNotNil(decoded,
                "ch 1014.6 HIGH-3: inspector.summary MUST " +
                "decode as canonical Summary type")
            XCTAssertEqual(decoded?.tier, "core")
            XCTAssertTrue(decoded?.activated ?? false)
        }
        // inspector.category still emitted as separate string
        XCTAssertNotNil(
            outcome.diagnostics["inspector.category"])
    }

    // MARK: - 1b. Pipeline emits inspector.category diagnostic

    func testCRITICAL_Pipeline_EmitsInspectorCategoryDiagnostic()
        async throws
    {
        let fabric = makeNineSeatFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.inspector",
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
            ])
        let outcome = try await pipeline.runTurn(
            turnID: "t.inspector",
            decomposeFrame: BASDecomposeFrame(),
            candidatePaths: [makeCand()])
        XCTAssertTrue(outcome.activated)
        let category = outcome.diagnostics[
            "inspector.category"]
        XCTAssertNotNil(category,
            "ch 1014 CRITICAL: pipeline MUST emit " +
            "inspector.category diagnostic — substrate-side " +
            "consumer of HostOutcome typed signals")
        // Default fixture: .core tier + activated → clean
        XCTAssertEqual(category, "fabric.run.clean")
    }

    // MARK: - 2. tierReadByExecutorInProduction honest split

    func testCRITICAL_TierReadFlag_True_DispatchBranchFlag_False() {
        // Honest doctrine split:
        //   - tierReadByExecutorInProduction: TRUE (since ch 998)
        //   - consultedByExecutorInProduction: FALSE (still — no
        //     dispatch branching on tier)
        XCTAssertTrue(
            BASANEKernelEligibilityClassifier
                .tierReadByExecutorInProduction,
            "ch 1014 CRITICAL: tier IS read by production " +
            "executor since ch 998 wired the consultation。 " +
            "This flag captures the actually-true state。")
        XCTAssertFalse(
            BASANEKernelEligibilityClassifier
                .consultedByExecutorInProduction,
            "ch 1014: dispatch-branching invariant STAYS " +
            "false。 Tier is OBSERVED but not BRANCHED on。 " +
            "Future Phase 9++ work flips this when actual " +
            "tier-based kernel-choice routing wires in。")
    }

    // MARK: - 3. Round-21 LOW-1 — ch 1006 summary JSON escape

    func testCRITICAL_LOW_1_ObservationSummary_JSONEscaped() {
        // Pre-fix turnID containing `"` would corrupt JSON
        // serializers downstream。 Post-fix the summary
        // includes a JSON-escaped form of turnID。
        let trickyTurnID = "t-with-\"quotes\"\nand\nnewlines"
        let input = BASTraceAnnotatorInput(
            turnID: trickyTurnID,
            emittedDeltas: [
                BASAgentDelta(
                    deltaID: "d.1", agentID: "a",
                    targetObjectRef:
                        "candidateFrontier#t",
                    deltaType: .add,
                    patchJson: "{}",
                    confidence: 0.5),
            ])
        var seq = 0
        let observations = BASAgentObservationAuditEmitter
            .observationFromAnnotator(
                input: input,
                agentSpec: BASAgentSpec(
                    agentID: "trace", role: .scout,
                    writeDomains: [.traceAnnotation],
                    defaultLeaseProfile: .watcher,
                    visibility: .low),
                seq: &seq)
        XCTAssertEqual(observations.count, 1)
        let summary = observations[0].summary
        // Escaped chars present:`\"` (escaped quote) +
        // `\n` (escaped newline)
        // ch 1014.5 / M3790 — Round-22 HIGH-2 fix: replace
        // weakening `||` with `&&` — turnID contains BOTH `"`
        // and `\n` so escape MUST produce BOTH escaped forms。
        // OR-weak test would pass if regression stripped one.
        XCTAssertTrue(
            summary.contains("\\\"") &&
            summary.contains("\\n"),
            "ch 1014.5 HIGH-2: summary MUST contain BOTH JSON-" +
            "escaped quote AND escaped newline (turnID has both)。 " +
            "Pre-fix `||` allowed regression to strip one。 " +
            "Got: \(summary)")
        // Raw control chars (literal newline / unescaped quote)
        // MUST NOT appear in the summary
        XCTAssertFalse(summary.contains("\n"),
            "ch 1014 LOW-1: summary MUST NOT contain raw " +
            "newline (would break downstream JSON encoders)")
    }

    // MARK: - 4. Round-21 LOW-2 — ch 1007 defense commentary

    #if !os(iOS)  // ch 1022 source-gate: reads Mac dev tree
    func test_LOW_2_FabricModeAuditEmitter_HasDefenseCommentary()
        throws
    {
        let projectRoot =
            BASSourceTreeAudit.repoRoot
        let path = "\(projectRoot)/Sources/BASOrchestration/" +
            "BASAgentFabricModeAuditEmitter.swift"
        let content = try String(
            contentsOfFile: path, encoding: .utf8)
        // Doctrine: explicit commentary mentioning the
        // 「ENUM-CONSTRAINED」 + 「CALLER-SUPPLIED」 distinction
        XCTAssertTrue(
            content.contains("ENUM-CONSTRAINED"),
            "ch 1014 LOW-2: ch 1007 source MUST disclose that " +
            "modeStr is enum-constrained (safe from injection)")
        XCTAssertTrue(
            content.contains("CALLER-SUPPLIED"),
            "ch 1014 LOW-2: ch 1007 source MUST disclose that " +
            "turnID is caller-supplied (needs separator " +
            "discipline)")
    }
    #endif

    // MARK: - 5. Honest scope pin — remaining items stay scaffold

    /// `consultedByExecutorInProduction` STAYS false。 Future
    /// Phase 9++ flips this when actual tier-based kernel-
    /// choice dispatch branches wire in。 Pin ensures we don't
    /// silently flip it without doing the substantive
    /// architectural work。
    ///
    /// chapter 一千零十四.5 / M3790 — Round-22 MED-3 fix:
    /// COUPLED state-machine pin。 Pre-fix test only checked
    /// the dispatch-branch flag in isolation。 Post-fix it
    /// also asserts the「illegal」 state (read=F, branch=T)
    /// cannot occur — protects against a future arc that
    /// accidentally flips the dispatch flag without the read
    /// flag,which would mean dispatch branches on a value
    /// the executor doesn't read (logically impossible)。
    func test_HonestScope_FlagStateMachine_LegalStatesOnly() {
        let consulted = BASANEKernelEligibilityClassifier
            .consultedByExecutorInProduction
        let tierRead = BASANEKernelEligibilityClassifier
            .tierReadByExecutorInProduction
        // The illegal state: branch=true + read=false
        // (dispatch branches on a value not read by executor)
        XCTAssertFalse(consulted && !tierRead,
            "ch 1014.5 MED-3 CRITICAL: illegal state " +
            "(consulted=true,tierRead=false) means dispatch " +
            "branches on a value executor doesn't read — " +
            "logically impossible per ch 1014 state-machine " +
            "doctrine。 If this fires,one of the two flags " +
            "was flipped without the other in lockstep。")
        // Pin current legal state:(read=T, branch=F) per
        // ch 1014 honest-scope split。 Future arc that flips
        // BOTH flags to true (legal post-Phase-9++ state)
        // would fail THIS line + force the update of THIS
        // test in lockstep with the dispatch arc — deliberate
        // tripwire。
        XCTAssertFalse(consulted,
            "ch 1014 HONEST SCOPE: dispatch-branch flag MUST " +
            "stay false until multi-chapter tier-based ANE-" +
            "dispatch arc lands。 If this fires,verify the " +
            "tierReadByExecutorInProduction flag is ALSO true " +
            "(legal post-Phase-9++ state requires both)。")
        XCTAssertTrue(tierRead,
            "ch 1014: tierReadByExecutorInProduction MUST be " +
            "true since ch 998 wired the production read site")
    }

    // MARK: - Test fixtures

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
            candidateID: "c.1",
            title: "test",
            actionSummary: "a",
            expectedBenefit: 0.3,
            expectedCost: 0.6,
            reversibility: 0.5,
            confidence: 0.5)
    }
}
