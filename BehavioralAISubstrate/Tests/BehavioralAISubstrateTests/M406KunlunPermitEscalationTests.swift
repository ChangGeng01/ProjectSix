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

    // MARK: - 9. M417 fix-pin: kunlun:compare attribution always
    //          emitted even when .compare was upstream-added

    /// M417 chapter 九十七 deep-review M1 fix: when an upstream
    /// escalation (e.g. M384 abyssal) already added `.compare` to
    /// stackedModes, M406 MUST still emit
    /// `permit.escalated:kunlun:compare` so the kunlun-attribution
    /// of the compare-mode request is not lost. Pre-fix the
    /// attribution code was gated on the same `!seen.contains(.compare)`
    /// guard as the stack-mode append, dropping cross-doctrine
    /// composability traceability.
    func testKunlunCompareAttributionAlwaysEmitted() {
        // Permit already has .compare (e.g. from upstream M384).
        let permit = makePermit(
            stackedModes: [.compare],
            reasonCodes: ["permit.escalated:abyssal:compare"])
        let alignment = makeAlignment(
            centerScore: 0.5,
            deviationCodes: [],
            requiresGate: true)
        let decision = BASKunlunPermitEscalation.escalate(
            permit: permit,
            alignment: alignment)
        // Stack mode count remains 1 (no duplication).
        let compareCount = decision.permit.stackedModes
            .filter { $0 == .compare }
            .count
        XCTAssertEqual(compareCount, 1,
            ".compare must not be duplicated in stackedModes")
        // BUT the kunlun-attribution code MUST be emitted.
        XCTAssertTrue(
            decision.reasonCodes.contains(
                "permit.escalated:kunlun:compare"),
            "kunlun:compare attribution must be emitted even when M384 already added .compare")
        // The abyssal-attribution from M384 is preserved in the
        // permit's reasonCodes.
        XCTAssertTrue(
            decision.permit.reasonCodes.contains(
                "permit.escalated:abyssal:compare"),
            "M384 abyssal:compare attribution preserved")
        XCTAssertTrue(
            decision.permit.reasonCodes.contains(
                "permit.escalated:kunlun:compare"),
            "M406 kunlun:compare attribution appended to permit reasonCodes")
    }

    /// M417 fix-pin extension: same attribution-always-emit logic
    /// applies to `.escalate` deep-deviation ladder.
    func testKunlunEscalateAttributionAlwaysEmittedOnDeepDeviation() {
        // Permit already has .escalate (e.g. from upstream).
        let permit = makePermit(
            stackedModes: [.escalate])
        let alignment = makeAlignment(
            centerScore: 0.1,  // deep deviation
            deviationCodes: ["x"],
            requiresGate: true)
        let decision = BASKunlunPermitEscalation.escalate(
            permit: permit,
            alignment: alignment)
        let escalateCount = decision.permit.stackedModes
            .filter { $0 == .escalate }
            .count
        XCTAssertEqual(escalateCount, 1,
            ".escalate must not be duplicated")
        XCTAssertTrue(
            decision.reasonCodes.contains(
                "permit.escalated:kunlun:escalate-deep-deviation"),
            "kunlun:escalate-deep-deviation attribution must be emitted even when .escalate already in stackedModes")
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

    // MARK: - 10. M417 H1 fix-pin: suppression codes harvestable

    /// M417 chapter 九十七 deep-review H1 fix-pin: when red line
    /// 8 fires (humanAnchor.tone == .reserved), the M406
    /// escalation-decision's reasonCodes carry the suppression
    /// codes (`permit.escalation-skipped:kunlun-axis-anchor-reserved`
    /// + per-deviation `permit.escalation-suppressed:kunlun:<code>`).
    /// Pre-fix these were discarded at the coordinator's gating
    /// block; post-fix they are harvested via the new
    /// `escalationSuppressionCodes` parameter on
    /// `buildSovereignAuditEntry` and emitted to signalRefs.
    ///
    /// This test pins the helper's contract: the decision MUST
    /// carry the suppression codes when reserved-anchor fires, so
    /// the coordinator's harvest step can capture them.
    func testReservedAnchorSuppressionCodesAreHarvestable() {
        let permit = makePermit()
        let alignment = makeAlignment(
            centerScore: 0.5,
            deviationCodes: ["risk-medium", "axis-shift"],
            requiresGate: true)
        let reservedAnchor = BASHumanAnchorSignal(
            anchorID: "test-reserved",
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
            humanAnchor: reservedAnchor)
        XCTAssertTrue(decision.suppressedByHumanAnchor,
            "decision must report suppression for red line 8")
        XCTAssertTrue(decision.triggered,
            "decision must report triggered=true (gate would have fired)")
        // The decision's reasonCodes (NOT the permit's!) carry
        // the suppression markers. The coordinator's H1 fix-pin
        // harvests these.
        XCTAssertTrue(
            decision.reasonCodes.contains(
                "permit.escalation-skipped:kunlun-axis-anchor-reserved"),
            "decision must carry the typed suppression marker")
        XCTAssertTrue(
            decision.reasonCodes.contains(
                "permit.escalation-suppressed:kunlun:risk-medium"),
            "per-deviation suppression marker present")
        XCTAssertTrue(
            decision.reasonCodes.contains(
                "permit.escalation-suppressed:kunlun:axis-shift"),
            "all per-deviation suppression markers present")
        // The permit itself is unchanged — single commit mouth.
        XCTAssertEqual(decision.permit, permit,
            "permit unchanged when suppression fires")
    }
}
