import XCTest
@testable import BASOrchestration
@testable import BASPolicy

/// M384 — pin the contract that
/// `BASAbyssalPressure.recommendedModes` translates into
/// `BASActionPermit.stackedModes` escalations and that the
/// human-anchor "reserved" tone red line (red line 8) suppresses
/// escalation.
///
/// What this file pins:
///
///   1. The 6-case translation table (BASAbyssalPressureMode →
///      BASActionPermitMode) is total: every case has a defined
///      mapping (either a target mode or a documented `nil`).
///   2. Below the trigger floor (default 0.6), no escalation fires
///      regardless of recommendedModes.
///   3. Above the floor with `recommendedModes` non-empty:
///      `permit.mode` is preserved (single-commit-mouth red line);
///      `stackedModes` gains every translatable mode (no duplicates);
///      `reasonCodes` gains `permit.escalated:abyssal:<mode>` per
///      recommendation.
///   4. Red line 8 lock — when `humanAnchor.recommendedSurfaceTone
///      == .reserved`, the escalation is suppressed and the
///      decision carries `permit.escalation-skipped:human-anchor-
///      reserved`.
///   5. nil pressure / nil humanAnchor / empty recommendedModes are
///      no-op (returns input permit unchanged).
final class M384AbyssalPermitEscalationTests: XCTestCase {

    // MARK: - Fixture helpers

    private func basePermit(
        mode: BASActionPermitMode = .answer,
        stackedModes: [BASActionPermitMode] = [],
        reasonCodes: [String] = []
    ) -> BASActionPermit {
        BASActionPermit(
            mode: mode,
            stackedModes: stackedModes,
            reasonCodes: reasonCodes)
    }

    private func pressure(
        magnitude: Double,
        recommendedModes: [BASAbyssalPressureMode]
    ) -> BASAbyssalPressure {
        // Spread the magnitude evenly across the six dimensions so
        // `aggregateMagnitude == magnitude`.
        BASAbyssalPressure(
            pressureID: "p-test",
            unknownLoad: magnitude,
            consequenceRadius: magnitude,
            evidenceDebt: magnitude,
            ontologyDistortion: magnitude,
            manipulationIndex: magnitude,
            narrativePollution: magnitude,
            recommendedModes: recommendedModes)
    }

    private func anchor(
        tone: BASHumanAnchorTone
    ) -> BASHumanAnchorSignal {
        BASHumanAnchorSignal(
            anchorID: "a-test",
            hostSummaryRef: "host:v1",
            agencyRisk: 0,
            alienationRisk: 0,
            dignityRisk: 0,
            overwhelmRisk: 0,
            recommendedSurfaceTone: tone,
            requiredAgencyReservation: "")
    }

    // MARK: - 1. Translation table is total

    func testTranslationTableIsTotal() {
        for mode in BASAbyssalPressureMode.allCases {
            // Just call the function. Total-coverage check is the
            // exhaustive switch statement; this loop pins behavior
            // for each case.
            let mapped = BASAbyssalPermitEscalation.translate(mode)
            switch mode {
            case .compare:
                XCTAssertEqual(mapped, .compare)
            case .delay:
                XCTAssertEqual(mapped, .delay)
            case .sovereignEscalate:
                XCTAssertEqual(mapped, .escalate)
            case .localDraft:
                XCTAssertEqual(mapped, .localOnly)
            case .guardianBranch:
                XCTAssertNil(mapped)
            case .humanAnchorCheck:
                XCTAssertNil(mapped)
            }
        }
    }

    // MARK: - 2. Below floor — no escalation

    /// audit blindspot-② HIGH: the live-wire UN-DEADLOCK. A pressure whose MEAN is below the old 0.6
    /// floor but which DOES carry per-dimension recommendations must now FIRE. This is exactly the
    /// production scenario the old mean gate suppressed: the sole producer pins 3 of 6 dims to 0 (max
    /// mean 0.5 < 0.6), yet a single live axis recommends a mode. Reversal to `aggregateMagnitude >=
    /// triggerFloor` reds — it returns triggered=false and silently drops [.compare, .delay].
    func testLowMeanWithRecommendationsStillFires() {
        let p = pressure(
            magnitude: 0.5,
            recommendedModes: [.compare, .delay])
        let permit = basePermit()
        let decision = BASAbyssalPermitEscalation.escalate(
            permit: permit,
            pressure: p,
            humanAnchor: nil)
        XCTAssertTrue(decision.triggered,
            "a low-MEAN pressure that carries recommendations must escalate — the old mean gate "
            + "falsely suppressed it, making the escalation dead on the live wire")
        XCTAssertEqual(decision.permit.stackedModes, [.compare, .delay])
    }

    // MARK: - 3. At floor — escalation fires

    func testAtFloorEscalationFires() {
        // aggregateMagnitude == triggerFloor crosses the boundary.
        let p = pressure(
            magnitude: 0.6,
            recommendedModes: [.compare])
        let permit = basePermit()
        let decision = BASAbyssalPermitEscalation.escalate(
            permit: permit,
            pressure: p,
            humanAnchor: nil)
        XCTAssertTrue(decision.triggered)
        XCTAssertEqual(decision.permit.stackedModes, [.compare])
    }

    // MARK: - 4. Translatable modes appended; reason codes emitted

    func testTranslatableModesAppendedAndReasonCodesEmitted() {
        let p = pressure(
            magnitude: 0.8,
            recommendedModes: [
                .compare,
                .delay,
                .sovereignEscalate,
                .localDraft,
            ])
        let permit = basePermit()
        let decision = BASAbyssalPermitEscalation.escalate(
            permit: permit,
            pressure: p,
            humanAnchor: nil)
        XCTAssertTrue(decision.triggered)
        XCTAssertEqual(
            decision.permit.stackedModes,
            [.compare, .delay, .escalate, .localOnly])
        XCTAssertEqual(decision.reasonCodes, [
            "permit.escalated:abyssal:compare",
            "permit.escalated:abyssal:delay",
            "permit.escalated:abyssal:sovereign-escalate",
            "permit.escalated:abyssal:local-draft",
        ])
        // Single-commit-mouth red line: primary mode untouched.
        XCTAssertEqual(decision.permit.mode, .answer)
    }

    // MARK: - 5. Untranslatable modes only emit reason codes

    func testUntranslatableModesOnlyEmitReasonCodes() {
        let p = pressure(
            magnitude: 0.8,
            recommendedModes: [
                .guardianBranch,
                .humanAnchorCheck,
            ])
        let permit = basePermit()
        let decision = BASAbyssalPermitEscalation.escalate(
            permit: permit,
            pressure: p,
            humanAnchor: nil)
        XCTAssertTrue(decision.triggered)
        // No stack changes — guardian-branch / human-anchor-check
        // have no permit-mode equivalent.
        XCTAssertEqual(decision.permit.stackedModes, [])
        XCTAssertEqual(decision.reasonCodes, [
            "permit.escalated:abyssal:guardian-branch",
            "permit.escalated:abyssal:human-anchor-check",
        ])
    }

    // MARK: - 6. Existing stackedModes preserved; no duplicates

    func testExistingStackedModesPreservedAndNoDuplicates() {
        let p = pressure(
            magnitude: 0.8,
            recommendedModes: [.compare, .delay])
        // Pre-existing compare in stackedModes — should not double.
        let permit = basePermit(
            mode: .answer,
            stackedModes: [.compare, .mirror])
        let decision = BASAbyssalPermitEscalation.escalate(
            permit: permit,
            pressure: p,
            humanAnchor: nil)
        // compare already present — only delay newly appended.
        XCTAssertEqual(
            decision.permit.stackedModes,
            [.compare, .mirror, .delay])
        // Reason codes still emitted for both (audit trail of what
        // was recommended, even when no-op).
        XCTAssertEqual(decision.reasonCodes, [
            "permit.escalated:abyssal:compare",
            "permit.escalated:abyssal:delay",
        ])
    }

    // MARK: - 7. Red line 8 — reserved tone suppresses escalation

    func testRedLine8ReservedToneSuppressesEscalation() {
        let p = pressure(
            magnitude: 0.8,
            recommendedModes: [.compare, .delay])
        let permit = basePermit()
        let decision = BASAbyssalPermitEscalation.escalate(
            permit: permit,
            pressure: p,
            humanAnchor: anchor(tone: .reserved))
        XCTAssertTrue(decision.triggered)
        XCTAssertTrue(decision.suppressedByHumanAnchor)
        // Permit unchanged.
        XCTAssertEqual(decision.permit, permit)
        XCTAssertEqual(decision.permit.stackedModes, [])
        // Reason codes record the suppression.
        XCTAssertTrue(
            decision.reasonCodes.contains(
                "permit.escalation-skipped:human-anchor-reserved"))
        XCTAssertTrue(
            decision.reasonCodes.contains(
                "permit.escalation-suppressed:abyssal:compare"))
        XCTAssertTrue(
            decision.reasonCodes.contains(
                "permit.escalation-suppressed:abyssal:delay"))
    }

    // MARK: - 8. Other anchor tones DO permit escalation

    func testNonReservedAnchorTonesDoNotSuppress() {
        for tone: BASHumanAnchorTone in [.plain, .steady, .warm] {
            let p = pressure(
                magnitude: 0.8,
                recommendedModes: [.compare])
            let permit = basePermit()
            let decision = BASAbyssalPermitEscalation.escalate(
                permit: permit,
                pressure: p,
                humanAnchor: anchor(tone: tone))
            XCTAssertFalse(
                decision.suppressedByHumanAnchor,
                "tone \(tone) should not suppress escalation")
            XCTAssertEqual(
                decision.permit.stackedModes, [.compare])
        }
    }

    // MARK: - 9. nil pressure → no-op

    func testNilPressureNoOp() {
        let permit = basePermit()
        let decision = BASAbyssalPermitEscalation.escalate(
            permit: permit,
            pressure: nil,
            humanAnchor: anchor(tone: .reserved))
        XCTAssertFalse(decision.triggered)
        XCTAssertEqual(decision.reasonCodes, [])
        XCTAssertEqual(decision.permit, permit)
    }

    // MARK: - 10. Empty recommendedModes → no escalation effect

    func testEmptyRecommendedModesNoEffect() {
        let p = pressure(
            magnitude: 0.9,
            recommendedModes: [])
        let permit = basePermit()
        let decision = BASAbyssalPermitEscalation.escalate(
            permit: permit,
            pressure: p,
            humanAnchor: nil)
        // audit blindspot-② HIGH: no recommendations ⇒ nothing to escalate ⇒ NOT triggered. (Under
        // the old mean gate this was triggered=true even with zero modes to apply — a spurious fire.)
        XCTAssertFalse(decision.triggered)
        XCTAssertEqual(decision.reasonCodes, [])
        XCTAssertEqual(decision.permit, permit)
    }

    // MARK: - 11. Custom triggerFloor honored

    func testCustomTriggerFloorHonored() {
        let p = pressure(
            magnitude: 0.4,
            recommendedModes: [.compare])
        let permit = basePermit()
        // audit blindspot-② HIGH: `triggerFloor` no longer gates (the gate is recommendation
        // non-emptiness); it is retained only for API/signature stability. This fires because there
        // IS a recommendation, not because of the custom floor — passing triggerFloor is a no-op.
        let decision = BASAbyssalPermitEscalation.escalate(
            permit: permit,
            pressure: p,
            humanAnchor: nil,
            triggerFloor: 0.3)
        XCTAssertTrue(decision.triggered)
        XCTAssertEqual(decision.permit.stackedModes, [.compare])
    }

    // MARK: - 12. Gate boundary — recommendation-based (audit blindspot-② HIGH)

    /// audit blindspot-② HIGH: the gate boundary is now "did the producer recommend >=1 mode",
    /// independent of the pressure MEAN. A pressure with ZERO recommendations does not fire (even at
    /// high mean); a pressure with exactly ONE recommendation fires (even at low mean). The old test
    /// pinned the mean `>=`-floor inequality — the very gate that made the escalation dead on the live
    /// wire — so it was pinning the bug.
    func testGateBoundaryIsRecommendationNonEmptiness() {
        let permit = basePermit()
        // High mean but NO recommendations → does NOT fire.
        let pNone = pressure(magnitude: 0.9, recommendedModes: [])
        XCTAssertFalse(
            BASAbyssalPermitEscalation.escalate(
                permit: permit, pressure: pNone, humanAnchor: nil).triggered,
            "zero recommendations must NOT fire, regardless of the (now-irrelevant) mean")
        // Low mean but ONE recommendation → fires.
        let pOne = pressure(magnitude: 0.1, recommendedModes: [.compare])
        XCTAssertTrue(
            BASAbyssalPermitEscalation.escalate(
                permit: permit, pressure: pOne, humanAnchor: nil).triggered,
            "one recommendation must fire, regardless of the (now-irrelevant) mean")
    }
}
