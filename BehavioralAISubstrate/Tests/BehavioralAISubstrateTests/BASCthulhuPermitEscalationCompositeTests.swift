import XCTest
@testable import BASOrchestration
@testable import BASPolicy

/// M446 (chapter 一百十七) — permit-escalation tests for L9 non-
/// Euclidean candidate routing + L10 cosmic-cold counterweight.
final class BASCthulhuPermitEscalationCompositeTests: XCTestCase {

    // MARK: - Empty inputs

    func testNoSourcesNoEscalation() {
        let permit = makePermit(stackedModes: [])
        let decision = BASCthulhuPermitEscalation.escalate(
            permit: permit,
            nonEuclideanCandidates: [],
            cosmicColdCounterweight: nil)
        XCTAssertFalse(decision.firedNonEuclidean)
        XCTAssertFalse(decision.firedCosmicCold)
        XCTAssertEqual(decision.reasonCodes, [])
        XCTAssertEqual(decision.permit, permit)
    }

    // MARK: - Non-Euclidean candidates

    func testCollapsedOnGraspForcesCompare() {
        let permit = makePermit(stackedModes: [])
        let candidate = BASNonEuclideanCandidate(
            candidateID: "ne-1",
            nonStandardTopology: "möbius-loop",
            consistentUnderPartialView: true,
            failureModeWhenGrasped: .collapsedOnGrasp,
            supportingAnchors: [])
        let decision = BASCthulhuPermitEscalation.escalate(
            permit: permit,
            nonEuclideanCandidates: [candidate],
            cosmicColdCounterweight: nil)
        XCTAssertTrue(decision.firedNonEuclidean)
        XCTAssertTrue(decision.permit.stackedModes.contains(.compare))
        XCTAssertTrue(decision.reasonCodes.contains {
            $0.contains("cthulhu-noneuclidean")
                && $0.contains("collapsed-on-grasp")
        })
    }

    func testTopologyDistortionForcesCompare() {
        let permit = makePermit(stackedModes: [])
        let candidate = BASNonEuclideanCandidate(
            candidateID: "ne-2",
            nonStandardTopology: "klein-bottle",
            consistentUnderPartialView: false,
            failureModeWhenGrasped: .topologyDistortion,
            supportingAnchors: [])
        let decision = BASCthulhuPermitEscalation.escalate(
            permit: permit,
            nonEuclideanCandidates: [candidate],
            cosmicColdCounterweight: nil)
        XCTAssertTrue(decision.firedNonEuclidean)
        XCTAssertTrue(decision.permit.stackedModes.contains(.compare))
    }

    func testBoundaryViolationDoesNotFireCompare() {
        let permit = makePermit(stackedModes: [])
        let candidate = BASNonEuclideanCandidate(
            candidateID: "ne-3",
            nonStandardTopology: "boundary-cross",
            consistentUnderPartialView: true,
            failureModeWhenGrasped: .boundaryViolation,
            supportingAnchors: [])
        let decision = BASCthulhuPermitEscalation.escalate(
            permit: permit,
            nonEuclideanCandidates: [candidate],
            cosmicColdCounterweight: nil)
        // boundaryViolation is handled by other gating layers
        // (host-constitution boundary checks); this helper
        // only fires for collapsedOnGrasp / topologyDistortion.
        XCTAssertFalse(decision.firedNonEuclidean)
    }

    func testNonEuclideanDoesNotDuplicateExistingMode() {
        let permit = makePermit(stackedModes: [.compare])
        let candidate = BASNonEuclideanCandidate(
            candidateID: "ne-4",
            nonStandardTopology: "x",
            consistentUnderPartialView: true,
            failureModeWhenGrasped: .collapsedOnGrasp,
            supportingAnchors: [])
        let decision = BASCthulhuPermitEscalation.escalate(
            permit: permit,
            nonEuclideanCandidates: [candidate],
            cosmicColdCounterweight: nil)
        let compareCount = decision.permit.stackedModes
            .filter { $0 == .compare }
            .count
        XCTAssertEqual(compareCount, 1,
                       "stackedModes must not duplicate .compare")
    }

    // MARK: - Cosmic cold counterweight

    func testHighAntiFatalismForcesMirror() {
        let permit = makePermit(stackedModes: [])
        let counterweight = BASCosmicColdCounterweight(
            counterweightID: "ccc-1",
            dignityBias: 0.1,
            agencyFloor: 0.1,
            antiFatalism: 0.9,
            antiPaternalism: 0.1)
        let decision = BASCthulhuPermitEscalation.escalate(
            permit: permit,
            nonEuclideanCandidates: [],
            cosmicColdCounterweight: counterweight)
        XCTAssertTrue(decision.firedCosmicCold)
        XCTAssertTrue(decision.permit.stackedModes.contains(.mirror))
    }

    func testHighAntiPaternalismForcesMirror() {
        let permit = makePermit(stackedModes: [])
        let counterweight = BASCosmicColdCounterweight(
            counterweightID: "ccc-2",
            dignityBias: 0.1,
            agencyFloor: 0.1,
            antiFatalism: 0.1,
            antiPaternalism: 0.8)
        let decision = BASCthulhuPermitEscalation.escalate(
            permit: permit,
            nonEuclideanCandidates: [],
            cosmicColdCounterweight: counterweight)
        XCTAssertTrue(decision.firedCosmicCold)
        XCTAssertTrue(decision.permit.stackedModes.contains(.mirror))
    }

    func testHighDignityBiasForcesCompare() {
        let permit = makePermit(stackedModes: [])
        let counterweight = BASCosmicColdCounterweight(
            counterweightID: "ccc-3",
            dignityBias: 0.7,
            agencyFloor: 0.1,
            antiFatalism: 0.1,
            antiPaternalism: 0.1)
        let decision = BASCthulhuPermitEscalation.escalate(
            permit: permit,
            nonEuclideanCandidates: [],
            cosmicColdCounterweight: counterweight)
        XCTAssertTrue(decision.firedCosmicCold)
        XCTAssertTrue(decision.permit.stackedModes.contains(.compare))
    }

    func testLowAxesNoEscalation() {
        let permit = makePermit(stackedModes: [])
        let counterweight = BASCosmicColdCounterweight(
            counterweightID: "ccc-4",
            dignityBias: 0.1,
            agencyFloor: 0.1,
            antiFatalism: 0.1,
            antiPaternalism: 0.1)
        let decision = BASCthulhuPermitEscalation.escalate(
            permit: permit,
            nonEuclideanCandidates: [],
            cosmicColdCounterweight: counterweight)
        XCTAssertFalse(decision.firedCosmicCold)
        XCTAssertEqual(decision.permit.stackedModes, [])
    }

    // MARK: - Composability — both sources fire

    func testBothSourcesFireSimultaneously() {
        let permit = makePermit(stackedModes: [])
        let candidate = BASNonEuclideanCandidate(
            candidateID: "ne-5",
            nonStandardTopology: "x",
            consistentUnderPartialView: true,
            failureModeWhenGrasped: .collapsedOnGrasp,
            supportingAnchors: [])
        let counterweight = BASCosmicColdCounterweight(
            counterweightID: "ccc-5",
            dignityBias: 0.6,
            agencyFloor: 0.1,
            antiFatalism: 0.7,
            antiPaternalism: 0.1)
        let decision = BASCthulhuPermitEscalation.escalate(
            permit: permit,
            nonEuclideanCandidates: [candidate],
            cosmicColdCounterweight: counterweight)
        XCTAssertTrue(decision.firedNonEuclidean)
        XCTAssertTrue(decision.firedCosmicCold)
        XCTAssertTrue(decision.permit.stackedModes.contains(.compare))
        XCTAssertTrue(decision.permit.stackedModes.contains(.mirror))
        // Neither mode duplicated.
        XCTAssertEqual(
            decision.permit.stackedModes.filter { $0 == .compare }.count,
            1)
    }

    // MARK: - Anti-magic-number named-constant pins

    func testCosmicColdAxisThresholdStable() {
        XCTAssertEqual(
            BASCthulhuPermitEscalation.cosmicColdAxisThreshold,
            0.5, accuracy: 0.001)
    }

    // MARK: - Helpers

    private func makePermit(
        stackedModes: [BASActionPermitMode]
    ) -> BASActionPermit {
        BASActionPermit(
            mode: .answer,
            stackedModes: stackedModes)
    }
}
