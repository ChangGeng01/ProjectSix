import Foundation

/// B3 轨迹熵早退 — the A/B promotion VERDICT, as a pure function.
///
/// device-recon id12: the device A/B harness (BASTraceExitDeviceTests) computed
/// think-cut / quality-parity / budget-answered inline in a `summarize()` that
/// only `print()`ed them — the sole XCTAssert was `!rows.isEmpty` (plumbing:
/// always true once the harness runs). A regression in the verdict math, or an
/// EXIT arm that cut tokens by SACRIFICING correctness, printed a bad table but
/// still passed green. Extracting the documented criteria here makes them
/// Mac-unit-testable AND lets the device run ASSERT the gate, not just print it.
///
/// Documented criteria (BASTraceExitDeviceTests header §ENTROPY/§BUDGET):
///  - ENTROPY: quality must HOLD — `exit.correct >= ctrl.correct` is THE gate —
///    AND a positive think-token cut (mean exit.think < mean ctrl.think).
///  - BUDGET: every EXIT arm must produce post-`</think>` answer text
///    (`answerLen > 0`) where CTRL historically burns the whole cap thinking.
public enum BASTraceExitABVerdict {

    /// The per-arm signals the verdict reads (a projection of the device Row).
    public struct ArmSample: Sendable, Equatable {
        public let think: Int
        public let correct: Bool
        public let answerLen: Int
        public init(think: Int, correct: Bool, answerLen: Int) {
            self.think = think
            self.correct = correct
            self.answerLen = answerLen
        }
    }

    public struct Result: Sendable, Equatable {
        /// ENTROPY gate: EXIT correctness did not regress below CTRL.
        public let qualityHeld: Bool
        /// ENTROPY lever: fractional think-token reduction (EXIT vs CTRL). > 0 = cut.
        public let thinkCut: Double
        /// BUDGET gate: every EXIT arm emerged with a post-think answer.
        public let budgetAnswered: Bool
        /// Promote iff quality held AND a real think-cut AND the budget answer emerged.
        public let promote: Bool
    }

    private static func meanThink(_ xs: [ArmSample]) -> Double {
        xs.isEmpty ? 0 : Double(xs.map(\.think).reduce(0, +)) / Double(xs.count)
    }

    public static func evaluate(
        entropyExit: [ArmSample],
        entropyCtrl: [ArmSample],
        budgetExit: [ArmSample]
    ) -> Result {
        let qualityHeld =
            entropyExit.filter(\.correct).count >= entropyCtrl.filter(\.correct).count
        let mc = meanThink(entropyCtrl)
        let thinkCut = mc > 0 ? 1 - meanThink(entropyExit) / mc : 0
        // "answered" is a claim about the EXIT arm actually emerging with text —
        // vacuously-true on an empty set would be a false-green, so require ≥1.
        let budgetAnswered =
            !budgetExit.isEmpty && budgetExit.allSatisfy { $0.answerLen > 0 }
        let promote = qualityHeld && thinkCut > 0 && budgetAnswered
        return Result(
            qualityHeld: qualityHeld,
            thinkCut: thinkCut,
            budgetAnswered: budgetAnswered,
            promote: promote)
    }
}
