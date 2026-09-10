// MARK: - BASChapter735TierSelectorTests
// chapter 七百三十五 第四刀 / M2349
//
// Test matrix for the memory-pressure-aware tier selector。 Covers
// all 3 accuracy priorities × 3 memory pressure levels = 9 cells
// + edge cases。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter735TierSelectorTests: XCTestCase {

    // MARK: - Estimator math

    func testEstimatorComputesFloat32FromSessionShape() {
        // 10 turns × 8 layers × 128-elem tensors:
        //   per token Float32 = 128 × 4 × 2 = 1024 bytes
        //   per session = 10 × 8 × 1024 = 81,920 bytes
        let est = BASKVCacheBudgetEstimator.estimate(
            turnsPerSession: 10,
            layersPerToken: 8,
            elementsPerTensor: 128)
        XCTAssertEqual(est.float32BytesPerSession, 81_920)
        XCTAssertEqual(est.float16BytesPerSession, 40_960)
        XCTAssertEqual(est.int8BytesPerSession, 20_480)
    }

    func testEstimatorTotalBytesAcrossSessions() {
        let est = BASKVCacheBudgetEstimator.estimate(
            turnsPerSession: 10,
            layersPerToken: 8,
            elementsPerTensor: 128)
        XCTAssertEqual(
            est.totalBytes(sessionCount: 4, tier: .float32),
            81_920 * 4)
        XCTAssertEqual(
            est.totalBytes(sessionCount: 4, tier: .float16),
            40_960 * 4)
        XCTAssertEqual(
            est.totalBytes(sessionCount: 4, tier: .int8),
            20_480 * 4)
    }

    // MARK: - Selection grid:9 cells (3 priorities × 3 budgets)

    private func estimate() -> BASKVCacheBudgetEstimate {
        // Realistic session shape:50 turns × 16 layers × 256
        // dim → 50 × 16 × 256 × 4 × 2 = 1,638,400 bytes per
        // session = 1.6 MB Float32 per session
        return BASKVCacheBudgetEstimator.estimate(
            turnsPerSession: 50,
            layersPerToken: 16,
            elementsPerTensor: 256)
    }

    // 1. .exact always returns Float32

    func testExactAlwaysReturnsFloat32() {
        let est = estimate()
        for budget in [0, 1_000_000, 100_000_000] {
            for sessions in [1, 4, 64] {
                let sel = BASKVCacheTierSelector.select(
                    estimate: est,
                    sessionCount: sessions,
                    memoryBudgetBytes: budget,
                    accuracyPriority: .exact)
                XCTAssertEqual(sel.tier, .float32)
            }
        }
    }

    // 2. .accuracyFirst:Float32 fits → pick Float32

    func testAccuracyFirstPicksFloat32WhenItFits() {
        let est = estimate()
        // 4 sessions × 1.6 MB = 6.4 MB Float32。 Budget 8 MB
        // → Float32 fits。
        let sel = BASKVCacheTierSelector.select(
            estimate: est,
            sessionCount: 4,
            memoryBudgetBytes: 8 * 1024 * 1024,
            accuracyPriority: .accuracyFirst)
        XCTAssertEqual(sel.tier, .float32)
        XCTAssertTrue(sel.fitsInBudget)
    }

    // 3. .accuracyFirst:Float32 OOM,Float16 fits → Float16

    func testAccuracyFirstPicksFloat16WhenF32Overflows() {
        let est = estimate()
        // 8 sessions × 1.6 MB = 12.8 MB Float32 — exceeds budget
        // 10 MB。 Float16 = 6.4 MB → fits。
        let sel = BASKVCacheTierSelector.select(
            estimate: est,
            sessionCount: 8,
            memoryBudgetBytes: 10 * 1024 * 1024,
            accuracyPriority: .accuracyFirst)
        XCTAssertEqual(sel.tier, .float16)
        XCTAssertTrue(sel.fitsInBudget)
    }

    // 4. .accuracyFirst:Float16 also OOM → fall to int8

    func testAccuracyFirstFallsToInt8WhenF16AlsoOverflows() {
        let est = estimate()
        // 32 sessions × 1.6 MB = 51.2 MB Float32。 Float16 =
        // 25.6 MB still exceeds 8 MB budget。 int8 = 12.8 MB
        // — exceeds budget too but is the best we can do。
        let sel = BASKVCacheTierSelector.select(
            estimate: est,
            sessionCount: 32,
            memoryBudgetBytes: 8 * 1024 * 1024,
            accuracyPriority: .accuracyFirst)
        XCTAssertEqual(sel.tier, .int8)
        XCTAssertFalse(sel.fitsInBudget)
    }

    // 5. .memoryFirst:Float32 fits + int8 savings < 1 MB →
    //    stay on Float32

    func testMemoryFirstStaysOnF32WhenSavingsBelow1MB() {
        // Tiny session:turns=1,layers=2,dim=16
        //   Float32:1 × 2 × 16 × 4 × 2 = 256 bytes
        //   int8: 64 bytes → savings 192 bytes per session
        // 4 sessions × 192 = 768 bytes savings → well under 1 MB
        let est = BASKVCacheBudgetEstimator.estimate(
            turnsPerSession: 1,
            layersPerToken: 2,
            elementsPerTensor: 16)
        let sel = BASKVCacheTierSelector.select(
            estimate: est,
            sessionCount: 4,
            memoryBudgetBytes: 100 * 1024 * 1024,
            accuracyPriority: .memoryFirst)
        XCTAssertEqual(sel.tier, .float32)
    }

    // 6. .memoryFirst:large sessions → int8

    func testMemoryFirstPicksInt8AtLargeSessionCount() {
        let est = estimate()
        // 32 sessions × 1.6 MB Float32 = 51.2 MB
        // int8 saving = 32 × (1.6 - 0.4) MB ≈ 38 MB ≫ 1 MB
        // → memory-first picks int8 regardless of budget
        let sel = BASKVCacheTierSelector.select(
            estimate: est,
            sessionCount: 32,
            memoryBudgetBytes: 200 * 1024 * 1024,
            accuracyPriority: .memoryFirst)
        XCTAssertEqual(sel.tier, .int8)
    }

    // MARK: - Edge cases

    func testZeroSessionsAlwaysFitsBudget() {
        let est = estimate()
        for priority in [
            BASKVCacheAccuracyPriority.exact,
            .accuracyFirst, .memoryFirst,
        ] {
            let sel = BASKVCacheTierSelector.select(
                estimate: est,
                sessionCount: 0,
                memoryBudgetBytes: 1,
                accuracyPriority: priority)
            XCTAssertTrue(
                sel.fitsInBudget,
                "0 sessions must fit any budget at \(priority)")
            XCTAssertEqual(sel.bytesUsed, 0)
        }
    }

    func testReasonStringIsPopulated() {
        let est = estimate()
        let sel = BASKVCacheTierSelector.select(
            estimate: est,
            sessionCount: 4,
            memoryBudgetBytes: 16 * 1024 * 1024,
            accuracyPriority: .accuracyFirst)
        XCTAssertFalse(sel.reason.isEmpty)
    }
}
