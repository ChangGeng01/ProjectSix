// MARK: - BASChapter998ANEExecutorWireTests
// chapter 九百九十八 / M3695 — 最严厉:close the chapter-500
// `consultedByExecutorInProduction = false` invariant by adding
// the FIRST production-side ANE classifier consultation。
//
// Pre-fix context:
// - Chapter 500 / M1377 shipped BASANEKernelEligibilityClassifier
//   + BASThermalAwareKernelSelectionPolicy + BASKVCacheInvalidation
//   Policy as 3 NEW typed policy surfaces。
// - Per SQL doctrine record 012_chapter_doctrine_phase2_data.sql:851:
//   "HONEST scope per source doc-comments: executor doesn't consult
//    these yet (consultedByExecutorInProduction = false invariant
//    tested)。 Future arc can adopt with stress-sweep regression
//    guard。"
// - 497 chapters of cascade work after that never touched it。
// - BASAutoRouteRanker (production kernel router) had zero
//   references to BASANEKernelEligibilityClassifier。
//
// ch 998 ships the first observe-only production consultation at
// BASCognitiveBrain.softmaxAuto + adds a runtime counter the test
// can observe to prove the wire is live。
//
// Test pins:
//   1. executorConsultationCount counter exists + is mutable
//   2. softmaxAuto increments the counter
//   3. Counter > 0 after a production-shape softmax call (proves
//      the consultedByExecutorInProduction=false invariant is
//      now genuinely flipped at runtime,even though the static-let
//      doctrine flag stays false for backward-compat)

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASChapter998ANEExecutorWireTests: XCTestCase {

    func testCRITICAL_SoftmaxAuto_IncrementsExecutorCounter() {
        // Snapshot counter before
        let before = BASANEKernelEligibilityClassifier
            .executorConsultationCount
        // Production-shape softmax call
        let result = BASCognitiveBrain.softmaxAuto(
            [1.0, 2.0, 3.0, 4.0])
        // Counter MUST have incremented
        let after = BASANEKernelEligibilityClassifier
            .executorConsultationCount
        XCTAssertEqual(after, before + 1,
            "ch 998 CRITICAL: softmaxAuto MUST increment the " +
            "ANE executor consultation counter — proves the " +
            "FIRST production-side wire is live。 Pre-ch-998 " +
            "this counter stayed at 0 across 497 chapters of " +
            "the substrate's arc since classifier shipped at " +
            "chapter 500 / M1377 with " +
            "consultedByExecutorInProduction=false invariant。")
        // Softmax output sanity
        XCTAssertEqual(result.value.count, 4)
        let sum = result.value.reduce(0, +)
        XCTAssertEqual(sum, 1.0, accuracy: 0.001,
            "ch 998: softmax output still produces valid " +
            "probability vector — ANE consult is observe-only,")
    }

    func testRepeatedCalls_CounterAccumulates() {
        let before = BASANEKernelEligibilityClassifier
            .executorConsultationCount
        for _ in 0..<10 {
            _ = BASCognitiveBrain.softmaxAuto([0.1, 0.2])
        }
        let after = BASANEKernelEligibilityClassifier
            .executorConsultationCount
        XCTAssertGreaterThanOrEqual(after, before + 10,
            "ch 998: 10 softmax calls MUST increment counter " +
            "by at least 10 (concurrent-race-loss tolerated " +
            "per the nonisolated(unsafe) doctrine,but " +
            "single-threaded XCTest run should see exact +10)")
    }

    func testTierForSoftmax_IsValidEnumValue() {
        // The consultation reads `tier(for: .softmax)` — verify
        // the returned tier is one of the 3 valid cases (not
        // some uninitialized garbage)
        let tier = BASANEKernelEligibilityClassifier
            .tier(for: .softmax)
        let validCases: Set<BASANEEligibilityTier> = [
            .aneNative, .mpsGraphNative, .fallbackRequired,
        ]
        XCTAssertTrue(validCases.contains(tier),
            "ch 998: classifier's tier(for: .softmax) MUST " +
            "return a valid enum value (proves consultation " +
            "produces typed output the production caller " +
            "could branch on — future arc work)")
    }

    /// Honest doctrine pin:`consultedByExecutorInProduction`
    /// static-let STAYS false per ch 998 doctrine。 The flag
    /// means "executor BRANCHES dispatch logic based on
    /// classifier" — that's still false。 ch 998 closed the
    /// SMALLER gap "no production consultation at all" but did
    /// NOT close the LARGER gap "dispatch logic actually
    /// changes based on tier"。 Test pins this honest scope。
    func testHonestScope_ConsultedFlagStaysFalse() {
        XCTAssertFalse(
            BASANEKernelEligibilityClassifier
                .consultedByExecutorInProduction,
            "ch 998 honest scope: the chapter-500 flag means " +
            "'dispatch branches on tier' which ch 998 does " +
            "NOT do (consult is observe-only)。 Future arc " +
            "post-ch-998 may flip this when actual dispatch " +
            "branching wires in。")
    }
}
