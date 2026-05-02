import XCTest
@testable import BASOrchestration
@testable import BASPolicy

/// M406 — pin the contract that
/// `BASKunlunPermitEscalation.escalate(...)` translates an
/// `BASAxisAlignment` (M402 schema) into typed permit `stackedModes`
/// + `reasonCodes` extensions while preserving the single commit
/// mouth (`permit.mode` never changes).
///
/// What this file pins:
///
///   1. nil alignment → no escalation (permit unchanged, no reason
///      codes added).
///   2. Centered alignment (requiresGate=false) → no escalation.
///   3. Off-axis alignment with deviation codes → `.compare`
///      appended to stackedModes + per-deviation reason codes.
///   4. Deeply off-axis (centerScore < 0.3) → `.compare` AND
///      `.escalate` appended.
///   5. Red line 8 (humanAnchor.tone == .reserved) → escalation
///      suppressed; permit unchanged; suppression reason codes
///      emitted.
///   6. Single commit mouth — `permit.mode` is never modified.
///   7. Composability with M384 — pre-existing stackedModes are
///      preserved (additive); existing `.compare` is not
///      duplicated.
///   8. Reason codes are sorted deterministically per deviation
///      code list.
///
/// Pattern parallel: M384 BASAbyssalPermitEscalationTests.
final class M406KunlunPermitEscalationTests: XCTestCase {

    // MARK: - Test fixture

    private func makePermit(
        mode: BASActionPermitMode = .answer,
        stackedModes: [BASActionPermitMode] = [],
        reasonCodes: [String] = []
    ) -> BASActionPermit {
        BASActionPermit(
            mode: mode,
            stackedModes: stackedModes,
            reasonCodes: reasonCodes,
            allowedDomains: [],
            blockedDomains: [],
            assertionCeiling: "guarded",
            toolScope: "bounded",
            memoryScope: "standard",
            requireMirror: false,
            requireCompare: false,
            requireSecondCheck: false,
            outputLengthCap: 240,
            tonePolicy: "default",
            templatePolicy: "default",
            delayWindow: nil,
            substituteRequired: false,
            escalationHintRef: nil)
    }

    private func makeAlignment(
        centerScore: Double = 1.0,
        deviationCodes: [String] = [],
        requiresGate: Bool = false
    ) -> BASAxisAlignment {
        BASAxisAlignment(
            alignmentID: "test-align",
            targetRef: "test-target",
            axisRef: "test-axis",
            centerScore: centerScore,
            deviationCodes: deviationCodes,
            correctionHint: "",
            requiresGate: requiresGate)
    }

    // MARK: - 1. nil alignment → no escalation

    func testNilAlignmentNoEscalation() {
        let permit = makePermit()
        let decision = BASKunlunPermitEscalation.escalate(
            permit: permit,
            alignment: nil)
        XCTAssertEqual(decision.permit, permit)
        XCTAssertEqual(decision.reasonCodes, [])
        XCTAssertFalse(decision.triggered)
        XCTAssertFalse(decision.suppressedByHumanAnchor)
    }

    // MARK: - 2. Centered alignment → no escalation

    func testCenteredAlignmentNoEscalation() {
        let permit = makePermit()
        let alignment = makeAlignment(
            centerScore: 1.0,
            deviationCodes: [],
            requiresGate: false)
        let decision = BASKunlunPermitEscalation.escalate(
            permit: permit,
            alignment: alignment)
        XCTAssertEqual(decision.permit, permit)
        XCTAssertEqual(decision.reasonCodes, [])
        XCTAssertFalse(decision.triggered)
    }

    // MARK: - 3. Off-axis with deviation → .compare appended

    func testOffAxisAlignmentAppendsCompare() {
        let permit = makePermit()
        let alignment = makeAlignment(
            centerScore: 0.5,
            deviationCodes: ["risk-medium"],
            requiresGate: true)
        let decision = BASKunlunPermitEscalation.escalate(
            permit: permit,
            alignment: alignment)
        XCTAssertTrue(decision.triggered)
        XCTAssertFalse(decision.suppressedByHumanAnchor)
        XCTAssertEqual(decision.permit.mode, .answer,
            "single commit mouth: mode unchanged")
        XCTAssertTrue(
            decision.permit.stackedModes.contains(.compare),
            ".compare must be appended to stackedModes")
        XCTAssertTrue(
            decision.reasonCodes.contains(
                "permit.escalated:kunlun:requires-gate"))
        XCTAssertTrue(
            decision.reasonCodes.contains(
                "permit.escalated:kunlun:compare"))
        XCTAssertTrue(
            decision.reasonCodes.contains(
                "permit.escalated:kunlun:deviation:risk-medium"))
    }

    // MARK: - 4. Deeply off-axis → .compare AND .escalate

    func testDeeplyOffAxisAppendsBoth() {
        let permit = makePermit()
        let alignment = makeAlignment(
            centerScore: 0.1,
            deviationCodes: ["risk-extreme-axis-overreach"],
            requiresGate: true)
        let decision = BASKunlunPermitEscalation.escalate(
            permit: permit,
            alignment: alignment)
        XCTAssertTrue(decision.triggered)
        XCTAssertEqual(decision.permit.mode, .answer,
            "single commit mouth")
        XCTAssertTrue(
            decision.permit.stackedModes.contains(.compare))
        XCTAssertTrue(
            decision.permit.stackedModes.contains(.escalate),
            ".escalate appended for deep deviation")
        XCTAssertTrue(
            decision.reasonCodes.contains(
                "permit.escalated:kunlun:escalate-deep-deviation"))
    }

    // MARK: - 5. Red line 8 — reserved tone suppresses

    func testReservedHumanAnchorSuppressesEscalation() {
        let permit = makePermit()
        let alignment = makeAlignment(
            centerScore: 0.5,
            deviationCodes: ["risk-medium"],
            requiresGate: true)
        let anchor = BASHumanAnchorSignal(
            anchorID: "test-anchor",
            hostSummaryRef: "host-1",
            agencyRisk: 0.5,
            alienationRisk: 0.5,
            dignityRisk: 0.5,
            overwhelmRisk: 0.5,
            recommendedSurfaceTone: .reserved,
            requiredAgencyReservation: "preserve-distance")
        let decision = BASKunlunPermitEscalation.escalate(
            permit: permit,
            alignment: alignment,
            humanAnchor: anchor)
        XCTAssertTrue(decision.suppressedByHumanAnchor)
        XCTAssertTrue(decision.triggered)
        XCTAssertEqual(decision.permit, permit,
            "permit unchanged when red line 8 fires")
        XCTAssertTrue(
            decision.reasonCodes.contains(
                "permit.escalation-skipped:kunlun-axis-anchor-reserved"))
        XCTAssertTrue(
            decision.reasonCodes.contains(
                "permit.escalation-suppressed:kunlun:risk-medium"))
    }

    // MARK: - 6. Single commit mouth invariant

    func testSingleCommitMouthInvariantAcrossAllModes() {
        // Every starting mode must be preserved through
        // escalation. Pin: permit.mode is never modified.
        let alignment = makeAlignment(
            centerScore: 0.1,
            deviationCodes: ["x"],
            requiresGate: true)
        for mode in BASActionPermitMode.allCases {
            let permit = makePermit(mode: mode)
            let decision = BASKunlunPermitEscalation.escalate(
                permit: permit,
                alignment: alignment)
            XCTAssertEqual(decision.permit.mode, mode,
                "mode \(mode) must be preserved through escalation")
        }
    }

    // MARK: - 7. Composability with M384 — additive only

    func testCompositionPreservesExistingStackedModes() {
        // Permit already has .delay in stackedModes (e.g. from
        // M384 abyssal escalation). M406 must preserve it.
        let permit = makePermit(
            stackedModes: [.delay],
            reasonCodes: ["permit.escalated:abyssal:delay"])
        let alignment = makeAlignment(
            centerScore: 0.5,
            deviationCodes: ["axis-shift"],
            requiresGate: true)
        let decision = BASKunlunPermitEscalation.escalate(
            permit: permit,
            alignment: alignment)
        XCTAssertTrue(
            decision.permit.stackedModes.contains(.delay),
            "M384 escalation preserved")
        XCTAssertTrue(
            decision.permit.stackedModes.contains(.compare),
            "M406 escalation appended")
        XCTAssertTrue(
            decision.permit.reasonCodes.contains(
                "permit.escalated:abyssal:delay"),
            "M384 reason code preserved")
        XCTAssertTrue(
            decision.permit.reasonCodes.contains(
                "permit.escalated:kunlun:requires-gate"),
            "M406 reason code appended")
    }

    func testExistingCompareNotDuplicated() {
        // Permit already has .compare (from a different upstream
        // escalation, e.g. abyssal). M406 must not double up.
        let permit = makePermit(
            stackedModes: [.compare])
        let alignment = makeAlignment(
            centerScore: 0.5,
            deviationCodes: [],
            requiresGate: true)
        let decision = BASKunlunPermitEscalation.escalate(
            permit: permit,
            alignment: alignment)
        let compareCount = decision.permit.stackedModes
            .filter { $0 == .compare }
            .count
        XCTAssertEqual(compareCount, 1,
            ".compare must not be duplicated")
    }

    // MARK: - 8. Deviation code ordering deterministic

    func testDeviationCodesEmittedInSortedOrder() {
        let permit = makePermit()
        let alignment = makeAlignment(
            centerScore: 0.5,
            deviationCodes: ["zebra", "alpha", "mango"],
            requiresGate: true)
        let decision = BASKunlunPermitEscalation.escalate(
            permit: permit,
            alignment: alignment)
        // Find indices of the three deviation reason codes.
        let codes = decision.reasonCodes
        let alphaIdx = codes.firstIndex {
            $0.contains("deviation:alpha")
        }
        let mangoIdx = codes.firstIndex {
            $0.contains("deviation:mango")
        }
        let zebraIdx = codes.firstIndex {
            $0.contains("deviation:zebra")
        }
        XCTAssertNotNil(alphaIdx)
        XCTAssertNotNil(mangoIdx)
        XCTAssertNotNil(zebraIdx)
        if let a = alphaIdx, let m = mangoIdx, let z = zebraIdx {
            XCTAssertLessThan(a, m,
                "deviation codes must be sorted: alpha < mango")
            XCTAssertLessThan(m, z,
                "deviation codes must be sorted: mango < zebra")
        }
    }
}
