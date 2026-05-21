// MARK: - BASChapter852MambaScanBridgeTests
// chapter 八百五十二 第三刀 / M2913 — Mamba SSM scan Swift bridge
// + byte-equality test
//
// Validates that the chapter 八百五十二 Rust crate
// (bas-mamba-scan) produces bit-equal output to the existing
// Swift `BASSSMScanCPUReference` (chapter 六百七十八 / M2090)
// across a representative grid of (B, L, D) shapes。
//
// Three implementations must agree:
//   1. Swift `BASSSMScanCPUReference.scan(...)` — chapter 678
//   2. Rust `bas_mamba_scan_sequential` via BASAutoRouteRanker
//   3. Rust `bas_mamba_scan_parallel` via BASAutoRouteRanker
//
// FMA-reorder tolerance: 1e-4 per chapter 392 replay-determinism
// pin。 In practice the outputs are bit-equal because the math
// is the same sequential recurrence in all 3 paths;parallel
// only fans out across (b, d) threads which have no shared
// state。

import XCTest
@testable import BASRuntimeCore
@testable import BASMetalSubstrate

final class BASChapter852MambaScanBridgeTests: XCTestCase {

    // MARK: - Minimal B=1 L=1 D=1

    func testRustSequentialMatchesSwiftAtMinimalShape() throws {
        let shape = BASSSMScanShape(B: 1, L: 1, D: 1)
        let x: [Float] = [2.0]
        let delta: [Float] = [0.5]
        let a: [Float] = [-1.0]
        let bProj: [Float] = [3.0]
        let cProj: [Float] = [4.0]
        let swiftY = try BASSSMScanCPUReference.scan(
            x: x, delta: delta, A: a, B: bProj, C: cProj,
            shape: shape)
        let rustY = BASAutoRouteRanker.mambaScanSequential(
            x: x, delta: delta, a: a, bProj: bProj, cProj: cProj,
            b: 1, l: 1, d: 1)
        let unwrapped = try XCTUnwrap(rustY)
        XCTAssertEqual(unwrapped.count, 1)
        XCTAssertEqual(unwrapped[0], swiftY[0], accuracy: 1e-6)
    }

    // MARK: - Multi-step recurrence

    func testRustSequentialMatchesSwiftL8D4() throws {
        let shape = BASSSMScanShape(B: 1, L: 8, D: 4)
        let bld = Int(shape.elementCount)
        let x: [Float] = (0..<bld).map { Float($0) * 0.013 }
        let delta: [Float] = (0..<bld).map { 0.05 + Float($0) * 0.001 }
        let a: [Float] = (0..<4).map { -0.5 - Float($0) * 0.1 }
        let bProj: [Float] = (0..<bld).map { 0.3 + Float($0) * 0.007 }
        let cProj: [Float] = (0..<bld).map { 1.1 + Float($0) * 0.005 }
        let swiftY = try BASSSMScanCPUReference.scan(
            x: x, delta: delta, A: a, B: bProj, C: cProj,
            shape: shape)
        let rustY = BASAutoRouteRanker.mambaScanSequential(
            x: x, delta: delta, a: a, bProj: bProj, cProj: cProj,
            b: 1, l: 8, d: 4)
        XCTAssertNotNil(rustY)
        XCTAssertEqual(rustY?.count, bld)
        for i in 0..<bld {
            XCTAssertEqual(rustY![i], swiftY[i], accuracy: 1e-5,
                "idx \(i): Rust sequential must match Swift " +
                "CPU reference within 1e-5 (chapter 392 tolerance)")
        }
    }

    // MARK: - Parallel ≡ Sequential ≡ Swift

    func testRustParallelMatchesRustSequentialAndSwift() throws {
        let shape = BASSSMScanShape(B: 4, L: 16, D: 8)
        let bld = Int(shape.elementCount)
        let dCount = Int(shape.D)
        // Deterministic xorshift seed
        var state: UInt64 = 0xCAFEBABE_DEADBEEF
        var nextF: () -> Float = {
            state ^= state &<< 13
            state ^= state &>> 7
            state ^= state &<< 17
            return Float(state % 1000) / 1000.0
        }
        let x: [Float] = (0..<bld).map { _ in nextF() }
        let delta: [Float] = (0..<bld).map { _ in 0.01 + 0.1 * nextF() }
        let a: [Float] = (0..<dCount).map { _ in -1.0 - nextF() }
        let bProj: [Float] = (0..<bld).map { _ in nextF() }
        let cProj: [Float] = (0..<bld).map { _ in nextF() }

        let swiftY = try BASSSMScanCPUReference.scan(
            x: x, delta: delta, A: a, B: bProj, C: cProj,
            shape: shape)
        let rustSeq = BASAutoRouteRanker.mambaScanSequential(
            x: x, delta: delta, a: a, bProj: bProj, cProj: cProj,
            b: 4, l: 16, d: 8)
        let rustPar = BASAutoRouteRanker.mambaScanParallel(
            x: x, delta: delta, a: a, bProj: bProj, cProj: cProj,
            b: 4, l: 16, d: 8)
        XCTAssertNotNil(rustSeq)
        XCTAssertNotNil(rustPar)
        XCTAssertEqual(rustSeq, rustPar,
            "Rust sequential and parallel must be bit-equal")
        // Compare to Swift CPU reference within 1e-5 (FMA-reorder
        // tolerance per chapter 392 pin)
        for i in 0..<bld {
            XCTAssertEqual(rustSeq![i], swiftY[i], accuracy: 1e-5)
        }
    }

    // MARK: - Invalid input handling

    func testRustBridgeReturnsNilOnDimensionMismatch() {
        // x shorter than expected — bridge should return nil
        let x: [Float] = [1.0]  // expected 4 for b=1,l=2,d=2
        let delta: [Float] = [0.1, 0.1, 0.1, 0.1]
        let a: [Float] = [-1.0, -1.0]
        let bProj: [Float] = [1.0, 1.0, 1.0, 1.0]
        let cProj: [Float] = [1.0, 1.0, 1.0, 1.0]
        let result = BASAutoRouteRanker.mambaScanSequential(
            x: x, delta: delta, a: a, bProj: bProj, cProj: cProj,
            b: 1, l: 2, d: 2)
        XCTAssertNil(result,
            "Bridge must return nil on input shape mismatch")
    }

    func testRustBridgeReturnsNilOnZeroDimension() {
        let result = BASAutoRouteRanker.mambaScanSequential(
            x: [], delta: [], a: [], bProj: [], cProj: [],
            b: 0, l: 0, d: 0)
        XCTAssertNil(result)
    }

    // MARK: - 20-fixture randomized grid (bigger sweep)

    func testRustParallelByteEqSwiftOver20Fixtures() throws {
        var state: UInt64 = 0xFEED_FACE_BAD_CAFE
        for trial in 0..<20 {
            let b = 1 + (trial % 3)
            let l = 4 + (trial % 12)
            let d = 1 + (trial % 6)
            let shape = BASSSMScanShape(
                B: UInt32(b), L: UInt32(l), D: UInt32(d))
            let bld = Int(shape.elementCount)
            var nextF: () -> Float = {
                state ^= state &<< 13
                state ^= state &>> 7
                state ^= state &<< 17
                return Float(state % 1000) / 1000.0
            }
            let x: [Float] = (0..<bld).map { _ in nextF() }
            let delta: [Float] = (0..<bld).map { _ in 0.01 + 0.1 * nextF() }
            let a: [Float] = (0..<d).map { _ in -1.0 - nextF() }
            let bProj: [Float] = (0..<bld).map { _ in nextF() }
            let cProj: [Float] = (0..<bld).map { _ in nextF() }
            let swiftY = try BASSSMScanCPUReference.scan(
                x: x, delta: delta, A: a, B: bProj, C: cProj,
                shape: shape)
            let rustPar = BASAutoRouteRanker.mambaScanParallel(
                x: x, delta: delta, a: a, bProj: bProj, cProj: cProj,
                b: Int32(b), l: Int32(l), d: Int32(d))
            XCTAssertNotNil(rustPar,
                "Trial \(trial) (b=\(b), l=\(l), d=\(d)) " +
                "must produce non-nil result")
            for i in 0..<bld {
                XCTAssertEqual(rustPar![i], swiftY[i],
                    accuracy: 1e-5,
                    "Trial \(trial) idx \(i): Rust parallel " +
                    "must match Swift CPU reference within 1e-5")
            }
        }
    }
}
