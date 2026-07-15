import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

/// Context-IR step 3 teeth — the compiler's derivation is the IDENTITY over the routed
/// budget (byte-parity by construction). Any future admission POLICY (thermal-tiered
/// verbosity, surprise-gated depth…) must consciously update these pins: a red here means
/// the plan no longer mirrors the frame — verify the divergence is an ordered decision.
final class BASTurnContextCompilerTests: XCTestCase {

    func testPlanMirrorsTheRoutedBudgetExactly() {
        // PROPERTY SWEEP (audit: pinning at only {2,4} let threshold policies like
        // min(maxLoops, 4) pass silently). Any non-identity derivation must red here.
        let loopValues = [0, 1, 2, 3, 4, 5, 7, 16, 64, 1_000]
        let modes: [BASEBrainRunMode] = [.dormant, .pulse, .sentinel, .guard, .quarantine,
                                         .lockdown, .engage, .reflect, .deepLoop, .recovery]
        for loops in loopValues {
            for mode in modes {
                var frame = BASBudgetFrame.guardedLocal(
                    maxLoops: loops, maxCandidates: 3, maxDecodeTokens: 256, retrievalDepth: 2)
                frame.runMode = mode
                let plan = BASTurnContextCompiler.compile(routedBudget: frame)
                XCTAssertEqual(plan.deliberate.maxLoops, frame.maxLoops,
                    "identity broken at maxLoops=\(loops) — if this is an ORDERED admission "
                    + "policy, update these pins consciously")
                XCTAssertEqual(plan.risk.maxLoops, frame.maxLoops, "maxLoops=\(loops)")
                XCTAssertEqual(plan.risk.runMode, frame.runMode, "runMode=\(mode)")
                XCTAssertEqual(plan.routedBudget, frame,
                    "whole-frame ride-along must be the same frame (maxLoops=\(loops), mode=\(mode))")
            }
        }
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
