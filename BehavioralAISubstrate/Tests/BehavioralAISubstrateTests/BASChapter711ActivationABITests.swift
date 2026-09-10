// MARK: - BASChapter711ActivationABITests
// chapter 七百十一 第二刀 / M2227
//
// Smoke-tests for the 6 new Rust activation C ABI exports:
//   - bas_ranker_gelu_exact / _simd
//   - bas_ranker_gelu_tanh_approx / _simd
//   - bas_ranker_silu / _simd
//
// Confirms the XCFramework rebuild correctly carried the new
// `#[no_mangle]` symbols + the Swift bridge sees them through
// the BASRustMemoryTrackerBinary module map。 Numerical pinning
// is on the Rust side (activations.rs tests);here we only
// verify (i) return code 0,(ii) output not all-zero,(iii)
// reference value at a single anchor point。

import XCTest
import Foundation
@testable import BASRuntimeCore

#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

final class BASChapter711ActivationABITests: XCTestCase {

    #if os(iOS) || os(macOS)
    private static let anchor: [Float] = [
        0.0, 1.0, 2.0, -1.0]

    func testGeluExactReturnsZeroAndMatchesTorch() {
        let x = Self.anchor
        var out = [Float](repeating: 0, count: x.count)
        let rc = x.withUnsafeBufferPointer { xp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_gelu_exact(
                    xp.baseAddress, x.count,
                    op.baseAddress, op.count)
            }
        }
        XCTAssertEqual(rc, 0)
        XCTAssertEqual(out[0], 0.0, accuracy: 1e-6)
        XCTAssertEqual(out[1], 0.8413447, accuracy: 5e-5)
        XCTAssertEqual(out[2], 1.9544997, accuracy: 5e-5)
        XCTAssertEqual(out[3], -0.15865529, accuracy: 5e-5)
    }

    func testGeluExactSIMDMatchesScalar() {
        let dim = 64
        let x: [Float] = (0..<dim).map {
            Float($0 - 32) * 0.1 }
        var scalar = [Float](repeating: 0, count: dim)
        var simd = [Float](repeating: 0, count: dim)
        _ = x.withUnsafeBufferPointer { xp in
            scalar.withUnsafeMutableBufferPointer { op in
                bas_ranker_gelu_exact(
                    xp.baseAddress, dim,
                    op.baseAddress, dim)
            }
        }
        _ = x.withUnsafeBufferPointer { xp in
            simd.withUnsafeMutableBufferPointer { op in
                bas_ranker_gelu_exact_simd(
                    xp.baseAddress, dim,
                    op.baseAddress, dim)
            }
        }
        for i in 0..<dim {
            XCTAssertEqual(scalar[i], simd[i],
                accuracy: 1e-6)
        }
    }

    func testGeluTanhApproxReturnsZeroAndMatchesTorch() {
        let x = Self.anchor
        var out = [Float](repeating: 0, count: x.count)
        let rc = x.withUnsafeBufferPointer { xp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_gelu_tanh_approx(
                    xp.baseAddress, x.count,
                    op.baseAddress, op.count)
            }
        }
        XCTAssertEqual(rc, 0)
        XCTAssertEqual(out[0], 0.0, accuracy: 1e-6)
        XCTAssertEqual(out[1], 0.84119, accuracy: 5e-4)
        XCTAssertEqual(out[2], 1.95459, accuracy: 5e-4)
        XCTAssertEqual(out[3], -0.15881, accuracy: 5e-4)
    }

    func testGeluTanhApproxSIMDMatchesScalar() {
        let dim = 63
        let x: [Float] = (0..<dim).map {
            Float($0 - 31) * 0.13 }
        var scalar = [Float](repeating: 0, count: dim)
        var simd = [Float](repeating: 0, count: dim)
        _ = x.withUnsafeBufferPointer { xp in
            scalar.withUnsafeMutableBufferPointer { op in
                bas_ranker_gelu_tanh_approx(
                    xp.baseAddress, dim,
                    op.baseAddress, dim)
            }
        }
        _ = x.withUnsafeBufferPointer { xp in
            simd.withUnsafeMutableBufferPointer { op in
                bas_ranker_gelu_tanh_approx_simd(
                    xp.baseAddress, dim,
                    op.baseAddress, dim)
            }
        }
        for i in 0..<dim {
            XCTAssertEqual(scalar[i], simd[i],
                accuracy: 1e-6)
        }
    }

    func testSiluReturnsZeroAndMatchesTorch() {
        let x = Self.anchor
        var out = [Float](repeating: 0, count: x.count)
        let rc = x.withUnsafeBufferPointer { xp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_silu(
                    xp.baseAddress, x.count,
                    op.baseAddress, op.count)
            }
        }
        XCTAssertEqual(rc, 0)
        XCTAssertEqual(out[0], 0.0, accuracy: 1e-6)
        XCTAssertEqual(out[1], 0.7310586, accuracy: 5e-5)
        XCTAssertEqual(out[2], 1.7615942, accuracy: 5e-5)
        XCTAssertEqual(out[3], -0.2689414, accuracy: 5e-5)
    }

    func testSiluSIMDMatchesScalar() {
        let dim = 128
        let x: [Float] = (0..<dim).map {
            Float($0 - 64) * 0.05 }
        var scalar = [Float](repeating: 0, count: dim)
        var simd = [Float](repeating: 0, count: dim)
        _ = x.withUnsafeBufferPointer { xp in
            scalar.withUnsafeMutableBufferPointer { op in
                bas_ranker_silu(
                    xp.baseAddress, dim,
                    op.baseAddress, dim)
            }
        }
        _ = x.withUnsafeBufferPointer { xp in
            simd.withUnsafeMutableBufferPointer { op in
                bas_ranker_silu_simd(
                    xp.baseAddress, dim,
                    op.baseAddress, dim)
            }
        }
        for i in 0..<dim {
            XCTAssertEqual(scalar[i], simd[i],
                accuracy: 1e-6)
        }
    }

    func testActivationsRejectNullPointer() {
        var out = [Float](repeating: 0, count: 4)
        let rc = out.withUnsafeMutableBufferPointer { op in
            bas_ranker_gelu_exact(
                nil, 4, op.baseAddress, 4)
        }
        XCTAssertEqual(rc, -1)
    }

    func testActivationsRejectLengthMismatch() {
        let x: [Float] = [0, 1, 2, 3]
        var out = [Float](repeating: 0, count: 3)
        let rc = x.withUnsafeBufferPointer { xp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_silu(
                    xp.baseAddress, x.count,
                    op.baseAddress, op.count)
            }
        }
        XCTAssertEqual(rc, -2)
    }
    #endif
}
