import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASAdmin

/// M114 — L9 `梦环层` whitepaper §5 closure tests.
///
/// L9 §5 lists 12 concept objects. Pre-M114 substrate had 7:
/// CandidatePath / CandidateFrontier / UncertaintyLedger /
/// EvidenceDebt / ConvergenceCertificate / LoopLeaseReceipt /
/// SovereignBreakpointHint. 5 gaps:
/// 1. ThoughtLoopState (§5.1 aggregator)
/// 2. CounterfactualBranch (§5.4)
/// 3. OutcomeProjection (§5.5)
/// 4. AdversarialBrief (§5.6)
/// 5. HostAlignmentMap (§5.7)
///
/// Plus 3 supporting enums: BASThoughtLoopStopReason (5-case),
/// BASCandidatePathStatus (5-case), BASSovereignBreakSuggestedAction
/// (4-case).
///
/// M114 closes all 5 structs + 3 enums.
final class BASL9DreamLoopWhitepaperTests: XCTestCase {

    // MARK: - 1. All 5 new types exist

    func testAllFiveNewL9TypesSchemaVersionOneDotZero() {
        XCTAssertEqual(
            BASThoughtLoopState.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASCounterfactualBranch.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASOutcomeProjection.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASAdversarialBrief.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASHostAlignmentMap.currentSchemaVersion, "1.0.0")
    }

    // MARK: - 2. Enum raw values

    func testThoughtLoopStopReasonHasFiveCases() {
        let expected: Set<String> = [
            "converged", "leaseEnd", "sovereignCut",
            "guardTakeover", "pending"
        ]
        XCTAssertEqual(
            Set(BASThoughtLoopStopReason.allCases
                .map(\.rawValue)),
            expected)
    }

    func testCandidatePathStatusHasFiveCases() {
        let expected: Set<String> = [
            "active", "dominated", "guard",
            "delayed", "cut"
        ]
        XCTAssertEqual(
            Set(BASCandidatePathStatus.allCases
                .map(\.rawValue)),
            expected)
    }

    func testSovereignBreakActionHasFourCases() {
        let expected: Set<String> = [
            "shrink", "cut", "freeze", "stop"
        ]
        XCTAssertEqual(
            Set(BASSovereignBreakSuggestedAction.allCases
                .map(\.rawValue)),
            expected)
    }

    // MARK: - 3. ThoughtLoopState

    func testThoughtLoopStateBasicFields() {
        let s = BASThoughtLoopState(
            loopID: "loop.1",
            canonicalFrameRef: "ccf.1",
            memoryBundleRef: "mb.1",
            activeFrontierRef: "cf.1",
            counterfactualRefs: ["cb.1"],
            projectionRefs: ["op.1"],
            adversarialRefs: ["ab.1"],
            uncertaintyRef: "ul.1",
            evidenceDebtRef: "ed.1",
            convergenceRef: "cc.1",
            leaseRef: "lease.1",
            sovereignBreakRefs: ["sbh.1"],
            stopReason: .converged)
        XCTAssertEqual(s.loopID, "loop.1")
        XCTAssertEqual(s.stopReason, .converged)
        XCTAssertEqual(s.counterfactualRefs, ["cb.1"])
    }

    // MARK: - 4. CounterfactualBranch

    func testCounterfactualBranchClampsUncertainty() {
        let b = BASCounterfactualBranch(
            branchID: "cb.1",
            alteredCondition: "what if no deadline",
            parentCandidateRef: "p.1",
            uncertainty: 1.7)
        XCTAssertEqual(b.uncertainty, 1.0)
    }

    // MARK: - 5. OutcomeProjection

    func testOutcomeProjectionClampsConfidenceAndLoss() {
        let p = BASOutcomeProjection(
            projectionID: "op.1",
            candidateRef: "c.1",
            reversibilityLoss: 2.0,
            confidenceBand: -0.5)
        XCTAssertEqual(p.reversibilityLoss, 1.0)
        XCTAssertEqual(p.confidenceBand, 0.0)
    }

    // MARK: - 6. AdversarialBrief

    func testAdversarialBriefAllSixSeverityFieldsClamp() {
        let b = BASAdversarialBrief(
            briefID: "ab.1",
            candidateRef: "c.1",
            evidenceGap: 2.0,
            emotionalBias: -0.1,
            manipulationRisk: 1.5,
            boundaryConflict: 0.5,
            hostMisalignment: -0.3,
            severity: 1.2)
        XCTAssertEqual(b.evidenceGap, 1.0)
        XCTAssertEqual(b.emotionalBias, 0.0)
        XCTAssertEqual(b.manipulationRisk, 1.0)
        XCTAssertEqual(b.boundaryConflict, 0.5)
        XCTAssertEqual(b.hostMisalignment, 0.0)
        XCTAssertEqual(b.severity, 1.0)
    }

    // MARK: - 7. HostAlignmentMap

    func testHostAlignmentMapBasicFields() {
        let m = BASHostAlignmentMap(
            candidateRef: "c.1",
            alignedGoals: ["g.1", "g.2"],
            violatedValues: ["privacy"],
            relationImpactRefs: ["r.bob"],
            longTermAlignmentScore: 0.6)
        XCTAssertEqual(m.alignedGoals, ["g.1", "g.2"])
        XCTAssertEqual(m.violatedValues, ["privacy"])
        XCTAssertEqual(m.longTermAlignmentScore, 0.6)
    }

    // MARK: - 8. Codable round-trip for new types

    func testThoughtLoopStateCodableRoundTrip() throws {
        let orig = BASThoughtLoopState(
            loopID: "rt.loop",
            stopReason: .guardTakeover)
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASThoughtLoopState.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    func testCounterfactualBranchCodableRoundTrip() throws {
        let orig = BASCounterfactualBranch(
            branchID: "rt.cb",
            alteredCondition: "rt cond",
            parentCandidateRef: "rt.p",
            uncertainty: 0.5)
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASCounterfactualBranch.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    // MARK: - 9. Registry membership

    func testAllFiveNewL9TypesRegistered() {
        let ids = Set(
            BASEBrainSchemaGovernanceRegistry.governedSchemas
                .map(\.objectID))
        XCTAssertTrue(ids.contains("ThoughtLoopState"))
        XCTAssertTrue(ids.contains("CounterfactualBranch"))
        XCTAssertTrue(ids.contains("OutcomeProjection"))
        XCTAssertTrue(ids.contains("AdversarialBrief"))
        XCTAssertTrue(ids.contains("HostAlignmentMap"))
    }
}
