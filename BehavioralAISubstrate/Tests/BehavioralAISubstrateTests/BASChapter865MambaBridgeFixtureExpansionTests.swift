// MARK: - BASChapter865MambaBridgeFixtureExpansionTests
// chapter 八百六十五 第三刀 / M2981 — expand the Swift bridge
// fixture grid (originally chapter 八百五十二) to:
//   1. Production-scale shapes (B=8 L=64 D=128 ≈ a real Mamba
//      block batch),
//   2. Boundary conditions (L=0 / D=0 / B=0 — all must return
//      nil per the bridge's bld>0 guard),
//   3. Asymmetric shapes (B≫1 with D=1; D≫1 with B=1) — the
//      v2 par_chunks_mut path can degenerate when only one
//      dimension is parallelizable。 Verify byte-equality
//      across both paths still holds。
//
// All fixtures still compare ALL THREE paths
// (Swift CPU reference + Rust sequential + Rust parallel
// v2) — byte-equality maintained per the chapter 八百六十三
// guarantee。 Tolerance 1e-4 per chapter 392 FMA-reorder pin。
//
// Why a new file (NOT mutate chapter 八百五十二's tests):the
// 三百九十二 immutable-fixture doctrine — chapter-specific tests
// pin THAT chapter's contract,not future enhancements。

import XCTest
@testable import BASRuntimeCore
@testable import BASMetalSubstrate

final class BASChapter865MambaBridgeFixtureExpansionTests: XCTestCase {

    // MARK: - Helper: deterministic xorshift RNG

    private final class XorshiftRng {
        private var state: UInt64
        init(seed: UInt64) { self.state = seed }
        func next() -> Float {
            state ^= state &<< 13
            state ^= state &>> 7
            state ^= state &<< 17
            return Float(state % 1_000) / 1_000.0
        }
    }

    // MARK: - Boundary: zero-dimension shapes return nil

    func testBridgeRejectsZeroLength() {
        // L=0 → bld=0 → bridge guard returns nil
        let r = BASAutoRouteRanker.mambaScanSequential(
            x: [], delta: [], a: [Float](repeating: -1, count: 4),
            bProj: [], cProj: [],
            b: 2, l: 0, d: 4)
        XCTAssertNil(r,
            "L=0 must be rejected by bld>0 guard")
    }

    func testBridgeRejectsZeroChannels() {
        // D=0 → bld=0 → bridge guard returns nil。 Note a.count
        // is checked separately (a.count == Int(d) means a=[]
        // is consistent),so this strictly exercises the bld>0
        // guard not the count-mismatch path。
        let r = BASAutoRouteRanker.mambaScanSequential(
            x: [], delta: [], a: [],
            bProj: [], cProj: [],
            b: 2, l: 4, d: 0)
        XCTAssertNil(r,
            "D=0 must be rejected by bld>0 guard")
    }

    func testBridgeRejectsZeroBatch() {
        let r = BASAutoRouteRanker.mambaScanSequential(
            x: [], delta: [],
            a: [Float](repeating: -1, count: 4),
            bProj: [], cProj: [],
            b: 0, l: 8, d: 4)
        XCTAssertNil(r, "B=0 must be rejected")
    }

    func testParallelBridgeRejectsZeroLength() {
        let r = BASAutoRouteRanker.mambaScanParallel(
            x: [], delta: [], a: [Float](repeating: -1, count: 4),
            bProj: [], cProj: [],
            b: 2, l: 0, d: 4)
        XCTAssertNil(r, "Parallel L=0 must be rejected too")
    }

    // MARK: - Production-scale shapes (B=8 L=64 D=128)

    func testRustParallelMatchesSwiftAtProductionScaleSmall() throws {
        // B=8 L=64 D=128 — about 65,536 cells。 Crosses the
        // chapter 八百六十三 parallel-v2 cutover threshold
        // (≈64K cells per the production crossover finding)。
        try assertAllThreePathsByteEqualAtShape(b: 8, l: 64, d: 128,
                                                seed: 0xA17EE_B0E_FACE_FEED)
    }

    func testRustParallelMatchesSwiftAtProductionScaleMid() throws {
        // B=4 L=128 D=64 — 32,768 cells,below cutover but
        // still a realistic small Mamba block。
        try assertAllThreePathsByteEqualAtShape(b: 4, l: 128, d: 64,
                                                seed: 0xBEEF_CAFE_BABE)
    }

    // MARK: - Asymmetric shapes

    func testAsymmetricLargeBatchSingleChannel() throws {
        // B=32 L=8 D=1 — par_chunks_mut by batch gives 32 tasks
        // of 8 cells each。 Perfect parallelism。 Byte-eq still
        // holds because each (b, d=0) task has its own private
        // h scalar (no shared state)。
        try assertAllThreePathsByteEqualAtShape(b: 32, l: 8, d: 1,
                                                seed: 0xC0DE_C0DE)
    }

    func testAsymmetricSingleBatchManyChannels() throws {
        // B=1 L=8 D=64 — par_chunks_mut by batch gives ONE
        // task of 512 cells。 Degenerate — no parallelism
        // benefit but byte-eq guarantee unchanged。
        try assertAllThreePathsByteEqualAtShape(b: 1, l: 8, d: 64,
                                                seed: 0xDEAD_BEEF)
    }

    // MARK: - Long-sequence shape

    func testLongSequenceL256() throws {
        // L=256 — recurrence length stress。 At each (b, d)
        // pair we accumulate h over 256 steps;numerical
        // differences (if any) would compound here。
        try assertAllThreePathsByteEqualAtShape(b: 2, l: 256, d: 16,
                                                seed: 0xFEED_FACE)
    }

    // MARK: - Helper

    /// Build a deterministic fixture at (b, l, d) and assert
    /// all three paths (Swift CPU,Rust sequential,Rust
    /// parallel v2) produce byte-equal output within the
    /// chapter 392 1e-4 tolerance。
    private func assertAllThreePathsByteEqualAtShape(
        b: Int, l: Int, d: Int, seed: UInt64
    ) throws {
        let shape = BASSSMScanShape(
            B: UInt32(b), L: UInt32(l), D: UInt32(d))
        let bld = Int(shape.elementCount)
        let rng = XorshiftRng(seed: seed)

        let x: [Float] = (0..<bld).map { _ in rng.next() }
        let delta: [Float] = (0..<bld).map { _ in
            0.01 + 0.1 * rng.next()
        }
        let a: [Float] = (0..<d).map { _ in -1.0 - rng.next() }
        let bProj: [Float] = (0..<bld).map { _ in rng.next() }
        let cProj: [Float] = (0..<bld).map { _ in rng.next() }

        let swiftY = try BASSSMScanCPUReference.scan(
            x: x, delta: delta, A: a, B: bProj, C: cProj,
            shape: shape)
        let rustSeq = BASAutoRouteRanker.mambaScanSequential(
            x: x, delta: delta, a: a, bProj: bProj, cProj: cProj,
            b: Int32(b), l: Int32(l), d: Int32(d))
        let rustPar = BASAutoRouteRanker.mambaScanParallel(
            x: x, delta: delta, a: a, bProj: bProj, cProj: cProj,
            b: Int32(b), l: Int32(l), d: Int32(d))

        let seq = try XCTUnwrap(rustSeq,
            "Sequential bridge must produce non-nil " +
            "at shape (\(b), \(l), \(d))")
        let par = try XCTUnwrap(rustPar,
            "Parallel bridge must produce non-nil " +
            "at shape (\(b), \(l), \(d))")

        XCTAssertEqual(seq.count, bld,
            "Sequential count must equal \(bld)")
        XCTAssertEqual(par.count, bld,
            "Parallel count must equal \(bld)")

        // Rust sequential ≡ Rust parallel — bit-equal
        // guarantee per chapter 八百六十三
        XCTAssertEqual(seq, par,
            "Rust seq and par must be bit-equal at " +
            "shape (\(b), \(l), \(d))")

        // Rust vs Swift CPU reference within chapter 392
        // tolerance (1e-4)
        for i in 0..<bld {
            XCTAssertEqual(seq[i], swiftY[i], accuracy: 1e-4,
                "shape (\(b), \(l), \(d)) idx \(i): " +
                "Rust must match Swift within 1e-4")
        }
    }
}
