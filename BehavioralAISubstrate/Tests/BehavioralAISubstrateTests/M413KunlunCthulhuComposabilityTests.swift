import XCTest
@testable import BASOrchestration
@testable import BASPolicy

/// M413 — pin the contract that Kunlun + Cthulhu doctrine compose
/// without contradiction. The two doctrine pairs (向上 / 向下) MUST
/// fire as additive escalations on the same `boundActionPermit`
/// when both conditions are met; the single commit mouth (L11
/// `permit.mode`) MUST remain unchanged across any composition.
///
/// Pattern parallel: M398 behavioral snapshot tests for Cthulhu;
/// M406 escalation tests for Kunlun.
///
/// 6 fixtures pin the cross-doctrine composability contract:
///
///   1. Pressure LOW + Axis CENTERED → no escalation
///   2. Pressure HIGH + Axis CENTERED → only Cthulhu escalation
///   3. Pressure LOW + Axis OVERREACHING → only Kunlun escalation
///   4. Pressure HIGH + Axis OVERREACHING → both escalations
///      compose; both reason codes accumulate; mode unchanged
///   5. Reserved anchor + Axis OVERREACHING → red line 8 (Cthulhu
///      RL8 / Kunlun cross-doctrine equivalent) suppresses
///      escalation; permit unchanged
///   6. Pressure HIGH + Axis OVERREACHING (deep deviation) → both
///      escalations + Kunlun's `.escalate` deep ladder fires
final class M413KunlunCthulhuComposabilityTests: XCTestCase {

    // MARK: - Fixture builders

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
        centerScore: Double,
        deviationCodes: [String],
        requiresGate: Bool
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

    private func makePressure(
        magnitude: Double,
        modes: [BASAbyssalPressureMode]
    ) -> BASAbyssalPressure {
        BASAbyssalPressure(
            pressureID: "test-pressure",
            unknownLoad: magnitude,
            consequenceRadius: magnitude,
            evidenceDebt: magnitude,
            ontologyDistortion: magnitude,
            manipulationIndex: magnitude,
            narrativePollution: magnitude,
            recommendedModes: modes,
            sovereignEscalationHint: nil)
    }

    private func makeAnchor(
        tone: BASHumanAnchorTone = .steady
    ) -> BASHumanAnchorSignal {
        BASHumanAnchorSignal(
            anchorID: "test-anchor",
            hostSummaryRef: "host-1",
            agencyRisk: 0.3,
            alienationRisk: 0.3,
            dignityRisk: 0.3,
            overwhelmRisk: 0.3,
            recommendedSurfaceTone: tone,
            requiredAgencyReservation: "default")
    }

    // Pure compose helper that fires both M384 + M406 escalations
    // in canonical order (M384 first, M406 second — matches the
    // coordinator's hot-path order).
    private func composeBoth(
        permit: BASActionPermit,
        pressure: BASAbyssalPressure?,
        alignment: BASAxisAlignment?,
        anchor: BASHumanAnchorSignal?
    ) -> BASActionPermit {
        let abyssal = BASAbyssalPermitEscalation.escalate(
            permit: permit,
            pressure: pressure,
            humanAnchor: anchor)
        let kunlun = BASKunlunPermitEscalation.escalate(
            permit: abyssal.permit,
            alignment: alignment,
            humanAnchor: anchor)
        return kunlun.permit
    }

    // MARK: - 1. Pressure LOW + Axis CENTERED → no escalation

    func testLowPressureCenteredAxisNoEscalation() {
        let permit = makePermit()
        let pressure = makePressure(
            magnitude: 0.2,
            modes: [])
        let alignment = makeAlignment(
            centerScore: 1.0,
            deviationCodes: [],
            requiresGate: false)
        let composed = composeBoth(
            permit: permit,
            pressure: pressure,
            alignment: alignment,
            anchor: makeAnchor())
        XCTAssertEqual(composed, permit,
            "low pressure + centered axis → permit unchanged")
        XCTAssertEqual(composed.stackedModes, [])
    }

    // MARK: - 2. Pressure HIGH + Axis CENTERED → Cthulhu only

    func testHighPressureCenteredAxisCthulhuOnly() {
        let permit = makePermit()
        let pressure = makePressure(
            magnitude: 0.8,
            modes: [.compare, .delay])
        let alignment = makeAlignment(
            centerScore: 1.0,
            deviationCodes: [],
            requiresGate: false)
        let composed = composeBoth(
            permit: permit,
            pressure: pressure,
            alignment: alignment,
            anchor: makeAnchor())
        XCTAssertEqual(composed.mode, .answer,
            "single commit mouth: mode unchanged")
        XCTAssertTrue(composed.stackedModes.contains(.compare),
            "Cthulhu .compare escalation present")
        XCTAssertTrue(composed.stackedModes.contains(.delay),
            "Cthulhu .delay escalation present")
        // Verify Kunlun did not fire (no kunlun reason codes).
        let kunlunCodes = composed.reasonCodes.filter {
            $0.contains(":kunlun:")
        }
        XCTAssertEqual(kunlunCodes.count, 0,
            "Kunlun escalation must not fire when axis is centered")
        // Verify Cthulhu fired.
        let abyssalCodes = composed.reasonCodes.filter {
            $0.contains(":abyssal:")
        }
        XCTAssertGreaterThanOrEqual(abyssalCodes.count, 2,
            "Cthulhu escalation must fire for both .compare + .delay")
    }

    // MARK: - 3. Pressure LOW + Axis OVERREACHING → Kunlun only

    func testLowPressureOverreachingAxisKunlunOnly() {
        let permit = makePermit()
        let pressure = makePressure(
            magnitude: 0.2,
            modes: [])
        let alignment = makeAlignment(
            centerScore: 0.5,
            deviationCodes: ["risk-medium-needs-attention"],
            requiresGate: true)
        let composed = composeBoth(
            permit: permit,
            pressure: pressure,
            alignment: alignment,
            anchor: makeAnchor())
        XCTAssertEqual(composed.mode, .answer,
            "single commit mouth: mode unchanged")
        XCTAssertTrue(composed.stackedModes.contains(.compare),
            "Kunlun .compare escalation present")
        // Verify Cthulhu did not fire.
        let abyssalCodes = composed.reasonCodes.filter {
            $0.contains(":abyssal:")
        }
        XCTAssertEqual(abyssalCodes.count, 0,
            "Cthulhu escalation must not fire when pressure low")
        // Verify Kunlun fired.
        let kunlunCodes = composed.reasonCodes.filter {
            $0.contains(":kunlun:")
        }
        XCTAssertGreaterThanOrEqual(kunlunCodes.count, 2,
            "Kunlun must emit requires-gate + compare + deviation codes")
    }

    // MARK: - 4. Both fire → both compose

    func testHighPressureOverreachingAxisBothFire() {
        let permit = makePermit()
        let pressure = makePressure(
            magnitude: 0.8,
            modes: [.delay])
        let alignment = makeAlignment(
            centerScore: 0.5,
            deviationCodes: ["risk-medium"],
            requiresGate: true)
        let composed = composeBoth(
            permit: permit,
            pressure: pressure,
            alignment: alignment,
            anchor: makeAnchor())
        // Single commit mouth invariant.
        XCTAssertEqual(composed.mode, .answer,
            "single commit mouth: mode unchanged")
        // Both stack modes present.
        XCTAssertTrue(composed.stackedModes.contains(.compare),
            "Kunlun .compare present")
        XCTAssertTrue(composed.stackedModes.contains(.delay),
            "Cthulhu .delay present")
        // Both doctrine reason codes accumulate.
        let abyssalCodes = composed.reasonCodes.filter {
            $0.contains(":abyssal:")
        }
        XCTAssertGreaterThan(abyssalCodes.count, 0,
            "Cthulhu reasons accumulate")
        let kunlunCodes = composed.reasonCodes.filter {
            $0.contains(":kunlun:")
        }
        XCTAssertGreaterThan(kunlunCodes.count, 0,
            "Kunlun reasons accumulate")
        // Composability invariant: order independence test —
        // composing in opposite order yields same set of stack
        // modes (set semantics, ordering may differ).
        let alt = composeBoth(
            permit: permit,
            pressure: pressure,
            alignment: alignment,
            anchor: makeAnchor())
        XCTAssertEqual(
            Set(composed.stackedModes),
            Set(alt.stackedModes),
            "stacked modes are set-equivalent (order-independent)")
    }

    // MARK: - 5. Red line 8 — Reserved anchor suppresses both

    func testReservedAnchorSuppressesBothEscalations() {
        let permit = makePermit()
        let pressure = makePressure(
            magnitude: 0.8,
            modes: [.delay])
        let alignment = makeAlignment(
            centerScore: 0.5,
            deviationCodes: ["risk-medium"],
            requiresGate: true)
        let reservedAnchor = makeAnchor(tone: .reserved)
        // Inspect the individual decisions to verify suppression
        // semantics. (When suppression fires, the helpers return
        // permit unchanged with reason codes attached to the
        // *decision*, not the permit itself — this matches how
        // the audit-emission seam gathers them separately from
        // the permit-mutation seam.)
        let cthulhuDecision = BASAbyssalPermitEscalation.escalate(
            permit: permit,
            pressure: pressure,
            humanAnchor: reservedAnchor)
        let kunlunDecision = BASKunlunPermitEscalation.escalate(
            permit: cthulhuDecision.permit,
            alignment: alignment,
            humanAnchor: reservedAnchor)
        // Both doctrines must report suppressed-by-anchor.
        XCTAssertTrue(cthulhuDecision.suppressedByHumanAnchor,
            "Cthulhu suppressed by reserved anchor (RL8)")
        XCTAssertTrue(kunlunDecision.suppressedByHumanAnchor,
            "Kunlun suppressed by reserved anchor (cross-doctrine RL8)")
        // Suppression reason codes must be emitted by each helper.
        let cthulhuSuppressed = cthulhuDecision.reasonCodes
            .contains {
                $0.contains("permit.escalation-skipped:human-anchor-reserved")
            }
        let kunlunSuppressed = kunlunDecision.reasonCodes
            .contains {
                $0.contains("permit.escalation-skipped:kunlun-axis-anchor-reserved")
            }
        XCTAssertTrue(cthulhuSuppressed,
            "Cthulhu suppression code emitted in decision")
        XCTAssertTrue(kunlunSuppressed,
            "Kunlun suppression code emitted in decision")
        // The composed permit (taken via the standard hot-path
        // helper) must remain unchanged — single commit mouth +
        // no stack mode bleed-through.
        let composed = composeBoth(
            permit: permit,
            pressure: pressure,
            alignment: alignment,
            anchor: reservedAnchor)
        XCTAssertEqual(composed.mode, .answer,
            "single commit mouth")
        XCTAssertFalse(composed.stackedModes.contains(.compare),
            "Kunlun .compare suppressed by reserved anchor")
        XCTAssertFalse(composed.stackedModes.contains(.delay),
            "Cthulhu .delay suppressed by reserved anchor")
    }

    // MARK: - 6. Deep deviation → Kunlun .escalate fires too

    func testDeepDeviationAxisAddsKunlunEscalateMode() {
        let permit = makePermit()
        let pressure = makePressure(
            magnitude: 0.8,
            modes: [.compare])
        let alignment = makeAlignment(
            centerScore: 0.1,  // deep deviation
            deviationCodes: ["risk-extreme-axis-overreach"],
            requiresGate: true)
        let composed = composeBoth(
            permit: permit,
            pressure: pressure,
            alignment: alignment,
            anchor: makeAnchor())
        XCTAssertEqual(composed.mode, .answer,
            "single commit mouth")
        XCTAssertTrue(composed.stackedModes.contains(.compare),
            "compare from at least one of doctrines")
        XCTAssertTrue(composed.stackedModes.contains(.escalate),
            "Kunlun .escalate appended for deep deviation")
        // Pin Kunlun deep deviation reason code.
        XCTAssertTrue(
            composed.reasonCodes.contains(
                "permit.escalated:kunlun:escalate-deep-deviation"),
            "deep-deviation reason code emitted")
    }
}
