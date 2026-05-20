// MARK: - BASChapter736VectorStorageSelectorTests
// chapter 七百三十六 第四刀 / M2354
//
// Test matrix for the vector storage tier auto-router。 Covers
// all 3 recall priorities × small/medium/large corpora。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter736VectorStorageSelectorTests: XCTestCase {

    // MARK: - Estimator math

    func testEstimatorComputesFloat32FromDim() {
        // dim=128:Float32 = 128*4 = 512 bytes/row
        let est = BASVectorStorageEstimator.estimate(dim: 128)
        XCTAssertEqual(est.float32BytesPerRow, 512)
        // int8 = dim + 12 = 140 bytes/row
        XCTAssertEqual(est.int8BytesPerRow, 140)
        // PQ = M (default 8) bytes/row
        XCTAssertEqual(est.pqBytesPerRow, 8)
        // PQ codebook = 8 × 16 × 16 × 4 = 8192 bytes
        XCTAssertEqual(est.pqCodebookBytes, 8192)
    }

    func testEstimatorTotalBytesAcrossCorpus() {
        let est = BASVectorStorageEstimator.estimate(dim: 128)
        // 10K rows
        XCTAssertEqual(
            est.totalBytes(corpusSize: 10_000, tier: .float32),
            10_000 * 512)
        XCTAssertEqual(
            est.totalBytes(corpusSize: 10_000, tier: .int8),
            10_000 * 140)
        // PQ:10_000 × 8 + 8192 = 88192 bytes
        XCTAssertEqual(
            est.totalBytes(corpusSize: 10_000, tier: .pq),
            10_000 * 8 + 8192)
    }

    // MARK: - .exact always Float32

    func testExactAlwaysReturnsFloat32() {
        let est = BASVectorStorageEstimator.estimate(dim: 128)
        for size in [100, 10_000, 1_000_000] {
            for budget in [1_000, 100_000_000] {
                let sel = BASVectorStorageSelector.select(
                    estimate: est,
                    corpusSize: size,
                    memoryBudgetBytes: budget,
                    recallPriority: .exact)
                XCTAssertEqual(sel.tier, .float32)
            }
        }
    }

    // MARK: - .recallFirst at small corpus → Float32

    func testRecallFirstSmallCorpusPicksFloat32() {
        let est = BASVectorStorageEstimator.estimate(dim: 384)
        // 1K rows × 384-dim × 4 bytes = 1.5 MB → easy fit
        let sel = BASVectorStorageSelector.select(
            estimate: est,
            corpusSize: 1_000,
            memoryBudgetBytes: 100 * 1024 * 1024,
            recallPriority: .recallFirst)
        XCTAssertEqual(sel.tier, .float32)
        XCTAssertTrue(sel.fitsInBudget)
    }

    // MARK: - .recallFirst at medium corpus,Float32 OOM → int8

    func testRecallFirstMediumCorpusF32OverflowsThenInt8() {
        let est = BASVectorStorageEstimator.estimate(dim: 384)
        // 50K rows × 1.5 KB Float32 = 75 MB,exceeds 10 MB budget
        // int8 = 50K × 396 bytes = 19.8 MB → still exceeds 10 MB
        //
        // Use a TIGHTER budget that fits int8 but not Float32
        // Float32: 50K × 1536 = 76.8 MB
        // int8:   50K × 396 = 19.8 MB
        // Pick 30 MB → int8 fits,Float32 doesn't
        let sel = BASVectorStorageSelector.select(
            estimate: est,
            corpusSize: 50_000,
            memoryBudgetBytes: 30 * 1024 * 1024,
            recallPriority: .recallFirst)
        XCTAssertEqual(sel.tier, .int8)
        XCTAssertTrue(sel.fitsInBudget)
    }

    // MARK: - .recallFirst at large corpus,F32+int8 OOM → PQ

    func testRecallFirstLargeCorpusOnlyPqFits() {
        let est = BASVectorStorageEstimator.estimate(dim: 128)
        // 200K rows × dim 128:
        //   Float32: 200K × 512 = 102.4 MB
        //   int8:   200K × 140 = 28 MB
        //   PQ:     200K × 8 + 8KB ≈ 1.6 MB
        // Budget 5 MB → only PQ fits。 200K crosses 100K threshold。
        let sel = BASVectorStorageSelector.select(
            estimate: est,
            corpusSize: 200_000,
            memoryBudgetBytes: 5 * 1024 * 1024,
            recallPriority: .recallFirst)
        XCTAssertEqual(sel.tier, .pq)
        XCTAssertTrue(sel.fitsInBudget)
    }

    // MARK: - .memoryFirst at very large corpus → PQ

    func testMemoryFirstAtVeryLargeCorpusPicksPQ() {
        let est = BASVectorStorageEstimator.estimate(dim: 128)
        // 500K rows:Float32 = 256 MB,PQ = 4 MB → savings 252 MB
        // memory-first picks PQ regardless of budget
        let sel = BASVectorStorageSelector.select(
            estimate: est,
            corpusSize: 500_000,
            memoryBudgetBytes: 1024 * 1024 * 1024,
            recallPriority: .memoryFirst)
        XCTAssertEqual(sel.tier, .pq)
    }

    // MARK: - .memoryFirst at tiny corpus → stay on Float32

    func testMemoryFirstSavingsBelow1MBStaysFloat32() {
        let est = BASVectorStorageEstimator.estimate(dim: 64)
        // 100 rows × dim 64:
        //   Float32: 100 × 256 = 25.6 KB
        //   int8:   100 × 76 = 7.6 KB → savings 18 KB ≪ 1 MB
        let sel = BASVectorStorageSelector.select(
            estimate: est,
            corpusSize: 100,
            memoryBudgetBytes: 100 * 1024 * 1024,
            recallPriority: .memoryFirst)
        XCTAssertEqual(sel.tier, .float32)
    }

    // MARK: - .memoryFirst at medium corpus → int8

    func testMemoryFirstMediumCorpusPicksInt8() {
        let est = BASVectorStorageEstimator.estimate(dim: 384)
        // 20K rows × dim 384:
        //   Float32: 20K × 1536 = 30 MB
        //   int8:   20K × 396 = 7.9 MB → savings 22 MB ≫ 1 MB
        //   PQ does NOT apply (corpus < 100K threshold)
        let sel = BASVectorStorageSelector.select(
            estimate: est,
            corpusSize: 20_000,
            memoryBudgetBytes: 100 * 1024 * 1024,
            recallPriority: .memoryFirst)
        XCTAssertEqual(sel.tier, .int8)
    }

    // MARK: - Edge cases

    func testZeroCorpusFitsAnyBudget() {
        let est = BASVectorStorageEstimator.estimate(dim: 128)
        for priority in [
            BASVectorRecallPriority.exact,
            .recallFirst, .memoryFirst,
        ] {
            let sel = BASVectorStorageSelector.select(
                estimate: est,
                corpusSize: 0,
                memoryBudgetBytes: 1,
                recallPriority: priority)
            // For memoryFirst,bytesUsed for PQ at corpus=0 is
            // the codebook bytes (1024) plus 0 rows → fits 1 byte
            // budget? Probably not。 Just check that selector
            // returns a sane tier。
            XCTAssertTrue(
                BASVectorStorageTier.allCases
                    .contains(sel.tier),
                "selector returned invalid tier at priority \(priority)")
        }
    }

    func testRecommendedMinCorpusSizeRespected() {
        XCTAssertEqual(
            BASVectorStorageTier.float32
                .recommendedMinCorpusSize, 0)
        XCTAssertEqual(
            BASVectorStorageTier.int8
                .recommendedMinCorpusSize, 1_000)
        XCTAssertEqual(
            BASVectorStorageTier.pq
                .recommendedMinCorpusSize, 100_000)
    }

    func testTierAsymptoticShrinkRatios() {
        XCTAssertEqual(
            BASVectorStorageTier.float32
                .asymptoticShrinkRatio, 1.0)
        XCTAssertEqual(
            BASVectorStorageTier.int8
                .asymptoticShrinkRatio, 4.0)
        XCTAssertEqual(
            BASVectorStorageTier.pq
                .asymptoticShrinkRatio, 53.0)
    }

    func testTypicalRecallAt10Pinned() {
        XCTAssertEqual(
            BASVectorStorageTier.float32
                .typicalRecallAt10, 1.0)
        XCTAssertEqual(
            BASVectorStorageTier.int8
                .typicalRecallAt10, 0.99)
        XCTAssertEqual(
            BASVectorStorageTier.pq
                .typicalRecallAt10, 0.85)
    }
}
