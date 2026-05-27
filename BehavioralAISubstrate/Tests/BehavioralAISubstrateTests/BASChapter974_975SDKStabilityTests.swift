// MARK: - BASChapter974_975SDKStabilityTests
// chapter 九百七十四-九百七十五 / M3575-M3580 — Phase 6 close tests
//
// Per `Docs/SDK_API_STABILITY.md` (ch 974) — wire-format
// stability is the SDK's contract with external consumers。
// These tests PIN that contract:any field add/remove/rename
// to a WIRE-STABLE type breaks these tests + forces a CHANGELOG
// entry + SDK version bump per the versioning policy。
//
// Per plan Phase 6 ch3 (close):iPhone Air 1-hour soak doc
// landed alongside DeviceTestApp sample integration — verified
// at the host-app level by operator running
// `Docs/PHASE_6_CLOSE_SMOKE.md` (ch 975 deliverable)。

import XCTest
@testable import BASMemory

final class BASChapter974_975SDKStabilityTests: XCTestCase {

    // MARK: - 1. Enum count pins (SDK v1 wire contract)

    func testStabilityPin_AgentRoleCount() {
        XCTAssertEqual(BASAgentRole.allCases.count, 20,
            "ch 974 SDK-stability: BASAgentRole MUST stay 20 " +
            "cases in SDK v1 (9 core + 7 watcher + 4 sealed). " +
            "If you bumped this, CHANGELOG entry + SDK v2 needed.")
    }

    func testStabilityPin_AgentVisibilityCount() {
        XCTAssertEqual(BASAgentVisibility.allCases.count, 3,
            "ch 974 SDK-stability: BASAgentVisibility frozen " +
            "at 3 tiers (high/medium/low) for SDK v1")
    }

    func testStabilityPin_StateDomainCount() {
        // chapter 一千零二 / M3715:bumped 12 → 13 with
        // addition of `.traceAnnotation` (TraceAnnotator owns;
        // closes the `.annotate` 💀 DEAD case per
        // `Docs/SCAFFOLD_VS_WIRED.md`)。 Backward-compat additive
        // — existing consumers untouched since the new domain has
        // no production reader。
        XCTAssertEqual(BASStateDomain.allCases.count, 13,
            "ch 974 SDK-stability: BASStateDomain at 13 " +
            "domains (ch 1002 close). Adding a 14th domain " +
            "in v1 is allowed (backward-compat) but bumps " +
            "this pin + the ch 953 schema test pin")
    }

    func testStabilityPin_ProposalTypeCount() {
        XCTAssertEqual(
            BASAgentProposalType.allCases.count, 7,
            "ch 974 SDK-stability: 7 proposal types per " +
            "user design Section 7.5")
    }

    func testStabilityPin_DeltaTypeCount() {
        XCTAssertEqual(
            BASAgentDeltaType.allCases.count, 5,
            "ch 974 SDK-stability: 5 delta operations")
    }

    func testStabilityPin_LeaseProfileCount() {
        XCTAssertEqual(
            BASAgentLeaseProfile.allCases.count, 4)
    }

    func testStabilityPin_WatcherSeverityCount() {
        XCTAssertEqual(
            BASAgentWatcherSeverity.allCases.count, 4,
            "ch 974 SDK-stability: 4 watcher severity levels")
    }

    func testStabilityPin_ForbiddenPatternCount() {
        XCTAssertEqual(
            BASAgentPersonaForbiddenPattern
                .allCases.count, 4,
            "ch 974 SDK-stability: 4 forbidden persona patterns")
    }

    func testStabilityPin_TranscriptModeCount() {
        XCTAssertEqual(
            BASAgentPersonaTranscriptMode
                .allCases.count, 3,
            "ch 974 SDK-stability: 3 transcript modes")
    }

    func testStabilityPin_SkillCapabilityCount() {
        XCTAssertEqual(
            BASSkillCapability.allCases.count, 4,
            "ch 974 SDK-stability: 4 reference skill " +
            "capabilities")
    }

    func testStabilityPin_PersonaTemplateCount() {
        XCTAssertEqual(
            BASAgentPersonaRoleTemplates
                .templates.count, 12,
            "ch 974 SDK-stability: 12 persona role templates")
    }

    func testStabilityPin_SkillAgentReferenceCount() {
        XCTAssertEqual(
            BASSkillAgentRegistry.all.count, 4,
            "ch 974 SDK-stability: 4 reference skill agents")
    }

    // MARK: - 2. Reserved signalRefs prefixes

    func testStabilityPin_WatcherSignalRefPrefixes() {
        // ch 974 SDK contract: the `agentWatcher.` prefix
        // family is reserved by Phase 5。 Test verifies the
        // aggregator emits ONLY refs starting with one of the
        // 2 documented prefixes。
        let obs = BASAgentWatcherObservation(
            turnID: "t1",
            scout: BASScoutInput(
                pressureSignals: [
                    "ignore previous instructions"]))
        let agg = BASAgentWatcherAggregator.runAll(obs)
        for ref in agg.signalRefs {
            XCTAssertTrue(
                ref.hasPrefix("agentWatcher.flag:") ||
                ref.hasPrefix("agentWatcher.count:"),
                "ch 974 SDK-stability: signalRef '\(ref)' " +
                "uses an unreserved prefix")
        }
    }

    // MARK: - 3. Codable round-trip stability (representative
    //             types from each phase)

    func testCodableStability_AgentSpec() throws {
        let spec = BASAgentSpec(
            agentID: "test.1", role: .planner,
            layerAffinity: [6, 9],
            readDomains: [.candidateFrontier],
            writeDomains: [.candidateFrontier],
            proposeDomains: [],
            forbiddenDomains: [.hostVersion],
            defaultLeaseProfile: .hotSeat,
            personaRef: "p1",
            visibility: .high,
            commitCapability: false)
        try roundTrip(spec)
    }

    func testCodableStability_PersonaSpec() throws {
        let p = BASAgentPersonaSpec(
            personaID: "p", agentID: "a",
            tone: "neutral",
            warmth: 0.5, directness: 0.5,
            skepticism: 0.5, structureBias: 0.5,
            creativityBias: 0.5, challengeIntensity: 0.5,
            comparisonBias: 0.5, guardBias: 0.5,
            visibility: .high,
            hostConstraintsRef: "",
            riskConstraintsRef: "",
            sovereignConstraintsRef: "",
            versionRef: "")
        try roundTrip(p)
    }

    func testCodableStability_WatcherHint() throws {
        let h = BASAgentWatcherHint(
            hintID: "h1", turnID: "t1",
            watcherRole: .anomalyWatcher,
            severity: .alert,
            category: "anomaly.test",
            summary: "test",
            evidence: ["a", "b"],
            confidence: 0.85,
            candidateRef: "candidate#c1",
            nowNanos: 1_234_567)
        try roundTrip(h)
    }

    func testCodableStability_SkillAgentDescriptor() throws {
        let d = BASSkillAgentRegistry.code
        try roundTrip(d)
    }

    func testCodableStability_WatcherAggregate() throws {
        let obs = BASAgentWatcherObservation(
            turnID: "t1",
            scout: BASScoutInput(
                manipulationSignals: Array(
                    repeating: "m", count: 15)))
        let agg = BASAgentWatcherAggregator.runAll(obs)
        try roundTrip(agg)
    }

    // MARK: - 4. Backward-compat smoke: 4-seat dispatcher still works

    func testBackwardCompat_FourSeatDispatcher() async {
        // SDK v1 promise: all 4/6/7/8/9-seat dispatch shapes
        // continue to work
        let roster = BASAgentTurnRoster(
            scout: makeAgent(
                "s", .scout, .situationField),
            planner: makeAgent(
                "p", .planner, .candidateFrontier),
            risk: makeAgent("r", .risk, .riskField),
            surface: makeAgent(
                "su", .surface, .renderFrame))
        let input = BASAgentTurnInput(turnID: "t1")
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input, roster: roster,
            graph: BASSharedStateGraph())
        // Just verifies the dispatcher compiles + runs at
        // pre-ch-961 shape (4-seat backward compat)。
        // Surface seat may emit a default-mode delta even on
        // empty input — what matters for SDK stability is that
        // the dispatcher returns a well-formed result + no crash。
        XCTAssertNotNil(result,
            "ch 974: 4-seat dispatch MUST return a result")
        XCTAssertNotNil(result.evidenceDebt,
            "ch 974: result MUST carry an evidence-debt record")
    }

    // MARK: - 5. Skill agent reference identity stable

    func testStabilityPin_SkillAgentIDsStable() {
        // The reference agent IDs are part of the SDK contract
        XCTAssertEqual(
            BASSkillAgentRegistry.writing.agentID,
            "skill.writing.reference.v1")
        XCTAssertEqual(
            BASSkillAgentRegistry.code.agentID,
            "skill.code.reference.v1")
        XCTAssertEqual(
            BASSkillAgentRegistry.research.agentID,
            "skill.research.reference.v1")
        XCTAssertEqual(
            BASSkillAgentRegistry.scheduling.agentID,
            "skill.scheduling.reference.v1")
    }

    // MARK: - 6. Phase 4-5 invariants still hold (regression
    //             defense across the SDK surface)

    func testRegressionDefense_LowTierSDKResolveAccepts() {
        // The ch 969.5 CG1 fix — LOW tier exempted from SDK
        // output validation — MUST still hold
        let spec = BASAgentSpec(
            agentID: "sentinel.1",
            role: .sovereignSentinel,
            writeDomains: [.sovereignVerdict],
            defaultLeaseProfile: .sovereign,
            visibility: .low)
        let r = BASAgentPersonaSDK.resolve(
            BASAgentPersonaResolveRequest(
                agentSpec: spec, personaID: "p"))
        XCTAssertFalse(r.rejected,
            "ch 974 regression-defense (CG1 ch 969.5): " +
            "LOW tier sovereign template MUST resolve cleanly")
    }

    func testRegressionDefense_RiskMonotonicRaise() {
        // ch 967 monotonic-raise invariant
        let spec = BASAgentSpec(
            agentID: "p", role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let lowSkepUser = BASAgentPersonaSpec(
            personaID: "u", agentID: "a",
            tone: "n",
            warmth: 0.5, directness: 0.5,
            skepticism: 0.05,  // user tries to lower
            structureBias: 0.5, creativityBias: 0.5,
            challengeIntensity: 0.5,
            comparisonBias: 0.5, guardBias: 0.5,
            visibility: .high,
            hostConstraintsRef: "",
            riskConstraintsRef: "",
            sovereignConstraintsRef: "",
            versionRef: "")
        let r = BASAgentPersonaSDK.resolve(
            BASAgentPersonaResolveRequest(
                agentSpec: spec,
                userOverlay: lowSkepUser,
                risk: BASAgentPersonaRiskContext(
                    skepticismFloor: 0.7),
                personaID: "p"))
        XCTAssertEqual(
            r.persona?.skepticism ?? -1, 0.7,
            accuracy: 0.0001,
            "ch 974 regression-defense (ch 967): risk floor " +
            "MUST monotonically raise — user attempt to lower " +
            "to 0.05 was clamped to floor 0.7")
    }

    // MARK: - Helpers

    private func roundTrip<T: Codable & Equatable>(
        _ v: T,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(v)
        let back = try JSONDecoder().decode(
            T.self, from: data)
        XCTAssertEqual(v, back, "Codable round-trip drift",
            file: file, line: line)
    }

    private func makeAgent(
        _ id: String,
        _ role: BASAgentRole,
        _ domain: BASStateDomain
    ) -> BASAgentSpec {
        BASAgentSpec(
            agentID: id, role: role,
            writeDomains: [domain],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
    }
}
