import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

/// Context-IR step 3 teeth — the compiler's derivation is the IDENTITY over the routed
/// budget (byte-parity by construction). Any future admission POLICY (thermal-tiered
/// verbosity, surprise-gated depth…) must consciously update these pins: a red here means
/// the plan no longer mirrors the frame — verify the divergence is an ordered decision.
final class BASTurnContextCompilerTests: XCTestCase {

    func testPlanMirrorsTheRoutedBudgetExactly() {
        let frame = BASBudgetFrame.guardedLocal(
            maxLoops: 4, maxCandidates: 3, maxDecodeTokens: 256, retrievalDepth: 2)
        let plan = BASTurnContextCompiler.compile(routedBudget: frame)

        XCTAssertEqual(plan.deliberate.maxLoops, frame.maxLoops)
        XCTAssertEqual(plan.risk.maxLoops, frame.maxLoops)
        XCTAssertEqual(plan.risk.runMode, frame.runMode)
        XCTAssertEqual(plan.routedBudget, frame,
            "the whole-frame ride-along must be the same frame (service passes stay byte-identical)")
    }

    func testCompileIsPure() {
        let frame = BASBudgetFrame.guardedLocal(
            maxLoops: 2, maxCandidates: 2, maxDecodeTokens: 160, retrievalDepth: 1)
        let a = BASTurnContextCompiler.compile(routedBudget: frame)
        let b = BASTurnContextCompiler.compile(routedBudget: frame)
        XCTAssertEqual(a.deliberate.maxLoops, b.deliberate.maxLoops)
        XCTAssertEqual(a.risk.runMode, b.risk.runMode)
        XCTAssertEqual(a.routedBudget, b.routedBudget)
    }
}
