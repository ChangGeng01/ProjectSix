// MARK: - BASChapter876ScaffoldingKernelsAuditTests
// chapter 八百七十六 / M3046 — final arc 871-876 audit + seal。
//
// Re-verifies the「DECLINED-PENDING-CONSUMER」 set from
// chapter 八百五十七 + chapters 八百七十四 + 八百七十五:
//
// 5 `.metal` kernels with 0 production consumers in
// BASCognitiveBrain (per chapter 八百五十七 audit):
//   - BASConvKernels.metal
//   - BASLayerNormKernel.metal
//   - BASSoftmaxKernels.metal
//   - BASActivationKernels.metal
//   - BASReduceKernels.metal
//
// 2 MPSGraph kernels with 0 production consumers (per chapters
// 八百七十四 + 八百七十五 decline):
//   - BASMPSGraphRotaryEmbeddingKernel
//   - BASMPSGraphRMSNormKernel
//
// Plus chapter 八百七十一 / 八百七十二 / 八百七十 wins documented +
// chapter 八百七十三 decline rationale。
//
// This is the FINAL chapter in arc 871-876。 Pure-doc + audit
// pin,no code changes beyond the pinning test file。

import XCTest
@testable import BASRuntimeCore
@testable import BASHostKit
@testable import BASMemory

#if !os(iOS)  // ch 1022 source-gate: file-tree audit only meaningful on Mac dev box
final class BASChapter876ScaffoldingKernelsAuditTests: XCTestCase {

    /// chapter 八百九十一 / M3145 SERIOUS-3 fix from self-assess
    /// review: in-body mutation of `BASVectorIndex.useBatchedTopK
    /// = false / = true` without tearDown is the same anti-pattern
    /// chapters 718/729/727 explicitly fixed。 If any XCTAssert
    /// between the toggles traps,the global static leaks `false`
    /// into the rest of the sweep。 Defensive tearDown restores
    /// the production default (true) so subsequent tests are
    /// unaffected。
    override func tearDown() async throws {
        BASVectorIndex.useBatchedTopK = true
        try await super.tearDown()
    }

    // MARK: - Arc 871-876 outcome summary pin

    /// Pins the arc's chapter-by-chapter outcome。 Future
    /// arc-seal audits can grep this test to recover the
    /// completion-vs-decline tally。
    func testArc871To876OutcomesPinned() {
        let outcomes: [(chapter: String, outcome: String)] = [
            ("871",
             "WIRED — MatMul split-flip (MSL small,MPSGraph large ≥256³)"),
            ("871.5",
             "REVIEW-FIX — threshold to BASAutoRouteThresholds + " +
             "fence-post + new error enum + 4-way at 256³"),
            ("872",
             "WIRED — VectorIndex Rust+rayon (chunked v2,268-490× " +
             "vs Swift,useBatchedTopK default ON)"),
            ("873",
             "DECLINED — AuditAggregation rayon (Swift baseline " +
             "already <2ms at 5K records,FFI overhead would eat win)"),
            ("874",
             "DECLINED-PENDING-CONSUMER — RoPE MPSGraph " +
             "(wins large but no consumer in Brain)"),
            ("875",
             "DECLINED-PENDING-CONSUMER — RMSNorm MPSGraph " +
             "(wins large but no consumer in Brain)"),
            ("876",
             "AUDIT-SEAL — this chapter,no code change"),
        ]
        XCTAssertEqual(outcomes.count, 7,
            "Arc 871-876 produced exactly 7 chapter rows " +
            "(including 871.5 review-fix sub-chapter)")
        var wired = 0
        var declined = 0
        var other = 0
        for (_, outcome) in outcomes {
            if outcome.hasPrefix("WIRED") { wired += 1 }
            else if outcome.contains("DECLINED") {
                declined += 1
            } else { other += 1 }
        }
        XCTAssertEqual(wired, 2,
            "2 wirings (chapter 871 matMul + chapter 872 vector index)")
        XCTAssertEqual(declined, 3,
            "3 declines (chapter 873 aggregation + " +
            "chapter 874 RoPE + chapter 875 RMSNorm)")
        XCTAssertEqual(other, 2,
            "2 audit/review chapters (871.5 + 876)")
    }

    // MARK: - DECLINED-PENDING-CONSUMER set re-verification

    /// All 5 `.metal` files from chapter 八百五十七 audit are
    /// still present in the source tree。 They ship but have
    /// no production consumer。
    func testFiveScaffoldingMetalFilesStillPresent() {
        let metalSrcRoot = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("BASMetalSubstrate")
            .appendingPathComponent("BASBuiltinKernels")
        let kernelFiles = [
            "BASConvKernels.metal",
            "BASLayerNormKernel.metal",
            "BASSoftmaxKernels.metal",
            "BASActivationKernels.metal",
            "BASReduceKernels.metal"
        ]
        for kernel in kernelFiles {
            let url = metalSrcRoot
                .appendingPathComponent(kernel)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: url.path),
                "Chapter 八百五十七 scaffolding kernel `\(kernel)` " +
                "must still exist — kernels stay shipped while " +
                "DECLINED-PENDING-CONSUMER。 Activation chapter " +
                "would land in a future arc when a real Swift " +
                "consumer pulls them。")
        }
    }

    /// Both decline-pending-consumer MPSGraph kernels from
    /// chapters 八百七十四 + 八百七十五 are still present。
    func testTwoMPSGraphKernelsStillPresent() {
        let metalSrcRoot = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("BASMetalSubstrate")
            .appendingPathComponent("BASBuiltinKernels")
        let kernels = [
            "BASMPSGraphRotaryEmbeddingKernel.swift",
            "BASMPSGraphRMSNormKernel.swift"
        ]
        for kernel in kernels {
            let url = metalSrcRoot
                .appendingPathComponent(kernel)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: url.path),
                "DECLINED-PENDING-CONSUMER MPSGraph kernel " +
                "`\(kernel)` must still exist")
        }
    }

    // MARK: - Arc 871-876 wired-paths pin

    /// Pin that the 2 chapter 871 + 872 wirings remain in
    /// place — these are the arc's net production additions。
    func testChapter871MatMulMPSGraphActorCaseExists() {
        // .metalMatMulMPSGraphActor was added in chapter 871
        // — verify enum case still present
        let allCases = BASAutoRouteChoice.allCases
        XCTAssertTrue(
            allCases.contains(.metalMatMulMPSGraphActor),
            "Chapter 871 .metalMatMulMPSGraphActor case " +
            "must remain in BASAutoRouteChoice")
    }

    func testChapter872BatchedCosineRayonCaseExists() {
        // .rustBatchedCosineRayon added in chapter 872
        let allCases = BASAutoRouteChoice.allCases
        XCTAssertTrue(
            allCases.contains(.rustBatchedCosineRayon),
            "Chapter 872 .rustBatchedCosineRayon case " +
            "must remain in BASAutoRouteChoice")
    }

    func testChapter872VectorIndexUseBatchedTopKDefaultsTrue() {
        // Chapter 八百七十六.5 / M3055 — agent B 7th-pass review
        // HIGH-1 caught that the prior test only pinned
        // thresholds,not the actual default-flip。 Now pins
        // BASVectorIndex.useBatchedTopK == true explicitly。
        XCTAssertTrue(
            BASVectorIndex.useBatchedTopK,
            "Chapter 八百七十二 flipped BASVectorIndex." +
            "useBatchedTopK default false→true (Rust batched " +
            "is 268-490× faster than Swift per-pair)。 " +
            "If this fails,verify the default wasn't " +
            "reverted + that no stale tearDown in chapter " +
            "718/729 tests is leaking false state。")
        let thresholds = BASAutoRouteThresholds.mSeriesDefault
        XCTAssertEqual(
            thresholds.batchedCosineRayonMinRows, 3000,
            "Chapter 872 default rayon threshold = 3000")
        XCTAssertEqual(
            thresholds.matMulMPSGraphActorMinProduct,
            16_777_216,
            "Chapter 871 default MPSGraph actor threshold " +
            "= 16M (256³)")
    }

    // MARK: - Chapter 八百七十六.5 — VectorIndex end-to-end pin
    //
    // Agent B 7th-pass HIGH-3:chapter 872 byte-equality
    // only verified raw C ABI parity at 1K corpus,which is
    // BELOW the 3000 rayon threshold。 The public consumer-
    // facing BASVectorIndex.topK with corpus ≥ 3000 was
    // unverified end-to-end through the rayon path。

    func testVectorIndexTopKByteEqAtRayonThresholdCorpus()
        async throws
    {
        let dim = 64
        let rows = 3500  // above 3000 rayon threshold
        let k = 5
        var rng: UInt32 = 0xCAFE_BABE
        func next() -> Float {
            rng = rng &* 1664525 &+ 1013904223
            return Float(rng & 0xFFFF)
                / Float(0xFFFF) - 0.5
        }
        let queryVec = (0..<dim).map { _ in next() }
        let queryEmb = BASEmbedding(
            vector: queryVec,
            dimension: dim,
            providerVersion: "test").normalized

        let index = BASVectorIndex()
        for i in 0..<rows {
            let v = (0..<dim).map { _ in next() }
            let e = BASEmbedding(
                vector: v,
                dimension: dim,
                providerVersion: "test").normalized
            try await index.insert(
                BASVectorIndexEntry(
                    atomID: "atom-\(i)",
                    normalizedEmbedding: e,
                    domain: "default"))
        }

        // Run with sequential (force off + then back to true)
        BASVectorIndex.useBatchedTopK = false
        let seqResults = await index.topK(
            query: queryEmb, k: k)
        BASVectorIndex.useBatchedTopK = true
        let rayonResults = await index.topK(
            query: queryEmb, k: k)

        XCTAssertEqual(seqResults.count, k)
        XCTAssertEqual(rayonResults.count, k)
        // Same top-K atomIDs in same order
        for i in 0..<k {
            XCTAssertEqual(
                seqResults[i].atomID,
                rayonResults[i].atomID,
                "top-\(i) atomID must match between seq " +
                "and rayon paths at 3500-corpus")
            XCTAssertEqual(
                seqResults[i].score,
                rayonResults[i].score,
                accuracy: 1e-5,
                "top-\(i) score must match within 1e-5 " +
                "(byte-equal per chapter 872 guarantee)")
        }
    }
}
#endif
