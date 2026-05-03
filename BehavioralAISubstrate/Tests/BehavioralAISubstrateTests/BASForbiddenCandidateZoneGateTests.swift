import XCTest
@testable import BASOrchestration
@testable import BASMemory

/// M447 (chapter 一百十七) — lifecycle-gate tests for L13
/// `BASForbiddenCandidateZone`.
final class BASForbiddenCandidateZoneGateTests: XCTestCase {

    // MARK: - No zone

    func testNoZoneAllowsAllActions() {
        for action in BASEvolutionLifecycleAction.allCases {
            let decision = BASForbiddenCandidateZoneGate.gate(
                action: action,
                candidateRef: "cand-x",
                zone: nil,
                satisfiedReleaseConditions: [])
            XCTAssertFalse(decision.denied,
                           "no-zone case must allow \(action.rawValue)")
            XCTAssertFalse(decision.wasQuarantined)
            XCTAssertEqual(decision.reasonCodes.count, 1)
            XCTAssertTrue(decision.reasonCodes[0].contains("no-zone"))
        }
    }

    // MARK: - Candidate not quarantined

    func testNotQuarantinedAllowsAllActions() {
        let zone = makeZone(
            quarantinedRefs: ["other-cand"],
            reasonCodes: ["other-reason"],
            releaseConditions: ["sovereign-warrant"])
        for action in BASEvolutionLifecycleAction.allCases {
            let decision = BASForbiddenCandidateZoneGate.gate(
                action: action,
                candidateRef: "cand-x",
                zone: zone,
                satisfiedReleaseConditions: [])
            XCTAssertFalse(decision.denied)
            XCTAssertFalse(decision.wasQuarantined)
            XCTAssertTrue(decision.reasonCodes[0].contains("not-quarantined"))
        }
    }

    // MARK: - Decommission actions always allowed

    func testRetractAllowedEvenWhenQuarantined() {
        let zone = makeZone(
            quarantinedRefs: ["cand-x"],
            reasonCodes: ["forbidden"],
            releaseConditions: ["sovereign-warrant"])
        let decision = BASForbiddenCandidateZoneGate.gate(
            action: .retract,
            candidateRef: "cand-x",
            zone: zone,
            satisfiedReleaseConditions: [])
        XCTAssertFalse(decision.denied)
        XCTAssertTrue(decision.wasQuarantined)
        XCTAssertTrue(decision.reasonCodes[0].contains("decommission-action"))
    }

    func testFailAllowedEvenWhenQuarantined() {
        let zone = makeZone(
            quarantinedRefs: ["cand-x"],
            reasonCodes: ["forbidden"],
            releaseConditions: ["sovereign-warrant"])
        let decision = BASForbiddenCandidateZoneGate.gate(
            action: .fail,
            candidateRef: "cand-x",
            zone: zone,
            satisfiedReleaseConditions: [])
        XCTAssertFalse(decision.denied)
    }

    func testWithdrawAllowedEvenWhenQuarantined() {
        let zone = makeZone(
            quarantinedRefs: ["cand-x"],
            reasonCodes: ["forbidden"],
            releaseConditions: ["sovereign-warrant"])
        let decision = BASForbiddenCandidateZoneGate.gate(
            action: .withdraw,
            candidateRef: "cand-x",
            zone: zone,
            satisfiedReleaseConditions: [])
        XCTAssertFalse(decision.denied)
    }

    func testRegisterCandidateAllowedEvenWhenQuarantined() {
        // Note: registerCandidate is the proposed → candidateRegistered
        // transition; quarantine is per-candidate so registering a
        // *new* candidate is not blocked.
        let zone = makeZone(
            quarantinedRefs: ["cand-x"],
            reasonCodes: ["forbidden"],
            releaseConditions: ["sovereign-warrant"])
        let decision = BASForbiddenCandidateZoneGate.gate(
            action: .registerCandidate,
            candidateRef: "cand-x",
            zone: zone,
            satisfiedReleaseConditions: [])
        XCTAssertFalse(decision.denied,
                       "registerCandidate doesn't grant trust; allowed")
    }

    // MARK: - Gateable actions denied when quarantined

    func testStartShadowTrialDeniedWhenQuarantined() {
        let zone = makeZone(
            quarantinedRefs: ["cand-x"],
            reasonCodes: ["forbidden"],
            releaseConditions: ["sovereign-warrant"])
        let decision = BASForbiddenCandidateZoneGate.gate(
            action: .startShadowTrial,
            candidateRef: "cand-x",
            zone: zone,
            satisfiedReleaseConditions: [])
        XCTAssertTrue(decision.denied)
        XCTAssertTrue(decision.wasQuarantined)
        XCTAssertFalse(decision.releaseConditionsMet)
        XCTAssertTrue(decision.reasonCodes[0].contains(
            "denied:startShadowTrial"))
        XCTAssertTrue(decision.reasonCodes[0].contains(
            "pending:sovereign-warrant"))
    }

    func testFinalizeTrialDeniedWhenQuarantined() {
        let zone = makeZone(
            quarantinedRefs: ["cand-x"],
            reasonCodes: ["forbidden"],
            releaseConditions: ["sovereign-warrant"])
        let decision = BASForbiddenCandidateZoneGate.gate(
            action: .finalizeTrial,
            candidateRef: "cand-x",
            zone: zone,
            satisfiedReleaseConditions: [])
        XCTAssertTrue(decision.denied)
    }

    func testPromoteDeniedWhenQuarantined() {
        let zone = makeZone(
            quarantinedRefs: ["cand-x"],
            reasonCodes: ["forbidden"],
            releaseConditions: ["sovereign-warrant"])
        let decision = BASForbiddenCandidateZoneGate.gate(
            action: .promote,
            candidateRef: "cand-x",
            zone: zone,
            satisfiedReleaseConditions: [])
        XCTAssertTrue(decision.denied)
    }

    // MARK: - Release conditions

    func testAllReleaseConditionsMetUnblocks() {
        let zone = makeZone(
            quarantinedRefs: ["cand-x"],
            reasonCodes: ["forbidden"],
            releaseConditions: [
                "sovereign-warrant", "host-explicit-recall",
            ])
        let decision = BASForbiddenCandidateZoneGate.gate(
            action: .startShadowTrial,
            candidateRef: "cand-x",
            zone: zone,
            satisfiedReleaseConditions: [
                "sovereign-warrant", "host-explicit-recall",
            ])
        XCTAssertFalse(decision.denied)
        XCTAssertTrue(decision.releaseConditionsMet)
        XCTAssertTrue(decision.reasonCodes[0].contains(
            "release-conditions-met"))
    }

    func testPartialConditionsMetStillDenied() {
        let zone = makeZone(
            quarantinedRefs: ["cand-x"],
            reasonCodes: ["forbidden"],
            releaseConditions: [
                "sovereign-warrant", "host-explicit-recall",
            ])
        let decision = BASForbiddenCandidateZoneGate.gate(
            action: .promote,
            candidateRef: "cand-x",
            zone: zone,
            satisfiedReleaseConditions: ["sovereign-warrant"])
        XCTAssertTrue(decision.denied)
        XCTAssertFalse(decision.releaseConditionsMet)
        XCTAssertTrue(decision.reasonCodes[0].contains(
            "pending:host-explicit-recall"))
    }

    // MARK: - Anti-magic-number doctrine

    func testGateableActionsListIsStable() {
        let expected: Set<BASEvolutionLifecycleAction> = [
            .startShadowTrial, .finalizeTrial, .promote,
        ]
        XCTAssertEqual(
            BASForbiddenCandidateZoneGate.gateableActions, expected)
    }

    // MARK: - Helpers

    private func makeZone(
        quarantinedRefs: [String],
        reasonCodes: [String],
        releaseConditions: [String]
    ) -> BASForbiddenCandidateZone {
        BASForbiddenCandidateZone(
            zoneID: "zone-1",
            quarantinedCandidateRefs: quarantinedRefs,
            quarantineReasonCodes: reasonCodes,
            releaseConditions: releaseConditions,
            auditRef: "audit-1")
    }
}
