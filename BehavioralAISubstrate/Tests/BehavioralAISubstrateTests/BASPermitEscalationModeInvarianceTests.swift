import XCTest
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

/// audit hostkit-spine F3 — SETTLES the "not-reproduced, closure-by-auditor-claim" finding with a
/// real teeth instead of an argument.
///
/// The claim (EBrainRuntimeCoordinator+RunTurn comment, ~L695): the gate-side humanAnchor derive
/// (pre-escalation, drives the red-line-8 suppression decision) and the audit-side humanAnchor
/// derive (post-escalation, recorded in the envelope) are "byte-identical by construction". F3
/// claimed this is FALSE on a permit.mode-escalation turn.
///
/// It is TRUE, and here is why, locked as a regression pin: `BASHumanAnchorProtocol.derive` reads
/// ONLY `permit.mode` (agencyRisk/alienation/dignity switch on it — see BASAbyssalProtocol), and
/// every permit escalation between the two derives (Abyssal / Kunlun / Cthulhu / assertion-ceiling)
/// is ADDITIVE — it appends to `stackedModes`/`reasonCodes` and rebuilds the permit with
/// `mode: permit.mode` UNCHANGED. So `permit.mode` is invariant across the seam ⇒ the two humanAnchor
/// signals are byte-identical. Reversal: change an escalation to mutate `.mode` and these red.
final class BASPermitEscalationModeInvarianceTests: XCTestCase {

    /// A pressure fixture guaranteed to fire the escalation (aggregateMagnitude ≥ the 0.6 floor).
    private func triggeringPressure() -> BASAbyssalPressure {
        BASAbyssalPressure(
            pressureID: "p", unknownLoad: 0.9, consequenceRadius: 0.9, evidenceDebt: 0.9,
            ontologyDistortion: 0.9, manipulationIndex: 0.9, narrativePollution: 0.9,
            recommendedModes: [.compare, .delay, .sovereignEscalate])
    }

    private func anchor(_ mode: BASActionPermitMode) -> BASHumanAnchorSignal {
        BASHumanAnchorProtocol.derive(
            anchorID: "a", hostSummaryRef: "h", riskLevel: .high, permitMode: mode, candidateCount: 3)
    }

    func testAbyssalEscalationPreservesModeSoGateAuditAnchorsAreByteIdentical() {
        let permit = BASActionPermit(mode: .answer, stackedModes: [])
        let pressure = triggeringPressure()
        XCTAssertGreaterThanOrEqual(pressure.aggregateMagnitude,
            BASAbyssalPermitEscalation.defaultTriggerFloor,
            "fixture guard: the pressure must actually cross the trigger floor")

        // humanAnchor nil ⇒ red-line-8 does NOT suppress ⇒ the escalation genuinely FIRES.
        let decision = BASAbyssalPermitEscalation.escalate(
            permit: permit, pressure: pressure, humanAnchor: nil)
        XCTAssertTrue(decision.triggered, "this must be a real escalation turn (fired, not skipped)")
        XCTAssertFalse(decision.reasonCodes.isEmpty,
            "a fired escalation appended reason codes — the permit genuinely changed")

        // THE INVARIANT F3 rests on: escalation is additive; the primary mode is preserved.
        XCTAssertEqual(decision.permit.mode, permit.mode,
            "escalation must NOT mutate the primary permit.mode (only stackedModes/reasonCodes grow)")

        // The F3 property itself: gate-side (pre) and audit-side (post) humanAnchor are byte-identical.
        XCTAssertEqual(anchor(permit.mode), anchor(decision.permit.mode),
            "gate-side and audit-side humanAnchor must be byte-identical — they can only diverge if "
            + "escalation changes permit.mode, which the additive doctrine forbids")
    }

    /// The .block boundary is where derive() diverges most (agencyRisk 0.75 vs 0.25). Pin that a
    /// .block-mode permit's escalation still preserves .block, so the audit anchor stays high-agency.
    func testEscalationFromBlockModeStillPreservesBlock() {
        let permit = BASActionPermit(mode: .block, stackedModes: [])
        let decision = BASAbyssalPermitEscalation.escalate(
            permit: permit, pressure: triggeringPressure(), humanAnchor: nil)
        XCTAssertEqual(decision.permit.mode, .block,
            "a .block turn must stay .block across escalation (else the audit anchor's agencyRisk flips)")
        XCTAssertEqual(anchor(.block), anchor(decision.permit.mode))
        // Sanity: the derive really IS mode-sensitive, so the invariance above is load-bearing, not vacuous.
        XCTAssertNotEqual(anchor(.block), anchor(.answer),
            "guard: derive() is mode-sensitive across the .block boundary (so mode-invariance matters)")
    }
}
