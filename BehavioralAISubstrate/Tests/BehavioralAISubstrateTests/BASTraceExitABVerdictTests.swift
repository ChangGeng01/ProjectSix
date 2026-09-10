import XCTest
@testable import BASOrgan

/// device-recon id12: Mac unit teeth for the trace-exit A/B promotion verdict —
/// the logic the device harness previously only printed. Each adversarial case
/// (quality drop / no think-cut / budget unanswered) flips `promote` to false,
/// so the verdict math can never silently green a bad A/B outcome.
final class BASTraceExitABVerdictTests: XCTestCase {

    private typealias S = BASTraceExitABVerdict.ArmSample

    func testPromoteWhenQualityHeldThinkCutAndBudgetAnswered() {
        let r = BASTraceExitABVerdict.evaluate(
            entropyExit: [S(think: 60, correct: true, answerLen: 20),
                          S(think: 80, correct: true, answerLen: 15)],
            entropyCtrl: [S(think: 120, correct: true, answerLen: 20),
                          S(think: 140, correct: false, answerLen: 15)],
            budgetExit:  [S(think: 40, correct: true, answerLen: 12)])
        XCTAssertTrue(r.qualityHeld, "exit 2 correct >= ctrl 1 correct")
        XCTAssertGreaterThan(r.thinkCut, 0, "mean exit think 70 < mean ctrl think 130")
        XCTAssertTrue(r.budgetAnswered)
        XCTAssertTrue(r.promote)
    }

    func testNoPromoteWhenQualityRegresses() {
        // EXIT cut tokens by SACRIFICING correctness — the gate must block it.
        let r = BASTraceExitABVerdict.evaluate(
            entropyExit: [S(think: 30, correct: false, answerLen: 10),
                          S(think: 30, correct: false, answerLen: 10)],
            entropyCtrl: [S(think: 120, correct: true, answerLen: 20),
                          S(think: 130, correct: true, answerLen: 20)],
            budgetExit:  [S(think: 40, correct: true, answerLen: 12)])
        XCTAssertFalse(r.qualityHeld)
        XCTAssertFalse(r.promote, "a quality regression must never promote")
    }

    func testNoPromoteWhenNoThinkCut() {
        // Quality held but EXIT thought at least as long → no lever, no promote.
        let r = BASTraceExitABVerdict.evaluate(
            entropyExit: [S(think: 130, correct: true, answerLen: 20)],
            entropyCtrl: [S(think: 120, correct: true, answerLen: 20)],
            budgetExit:  [S(think: 40, correct: true, answerLen: 12)])
        XCTAssertTrue(r.qualityHeld)
        XCTAssertLessThanOrEqual(r.thinkCut, 0)
        XCTAssertFalse(r.promote)
    }

    func testNoPromoteWhenBudgetArmNeverAnswers() {
        // The budget-regime EXIT arm burned the cap without emerging → no promote.
        let r = BASTraceExitABVerdict.evaluate(
            entropyExit: [S(think: 60, correct: true, answerLen: 20)],
            entropyCtrl: [S(think: 120, correct: true, answerLen: 20)],
            budgetExit:  [S(think: 128, correct: false, answerLen: 0)])
        XCTAssertFalse(r.budgetAnswered)
        XCTAssertFalse(r.promote)
    }

    func testEmptyBudgetSetIsNotVacuouslyAnswered() {
        // Guard against the empty-set false-green: no budget samples ⇒ not answered.
        let r = BASTraceExitABVerdict.evaluate(
            entropyExit: [S(think: 60, correct: true, answerLen: 20)],
            entropyCtrl: [S(think: 120, correct: true, answerLen: 20)],
            budgetExit:  [])
        XCTAssertFalse(r.budgetAnswered)
        XCTAssertFalse(r.promote)
    }
}
