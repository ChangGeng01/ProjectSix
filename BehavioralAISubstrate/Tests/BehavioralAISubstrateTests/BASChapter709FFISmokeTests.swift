// MARK: - BASChapter709FFISmokeTests
//
// Skip-triage follow-on (2026-07-14) — restore Swift-side execution of two
// shipped C-ABI symbols that the chapter 八百七十九 archive skip silently
// dropped to ZERO.
//
// `BASChapter709TournamentTests` skips its whole class (print-only tournament,
// no asserted replacement — an honest skip), but it is the ONLY Swift caller
// repo-wide of `bas_ranker_softmax_simd` and `bas_ranker_layer_norm_welford`.
// Unlike chapter 711 — whose symbols stay covered by the RUNNING
// `BASChapter711ActivationABITests` — chapter 709 has no ABI twin, so the skip
// left both `extern "C"` wrappers in the shipped XCFramework unexercised from
// Swift. The Rust inner impls are unit-tested (src/softmax.rs, src/layer_norm.rs),
// so the ALGORITHMS were covered; what was not was the FFI boundary itself —
// signature drift, XCFramework linkage, and the rc / out-buffer contract.
//
// This is the cheap asserted replacement the archive skip said it lacked:
// milliseconds of CI, no tournament wall-clock, and it REDs if either wrapper
// stops linking or stops honouring its contract.

import XCTest
import Foundation
@testable import BASRuntimeCore

import BASRustMemoryTrackerBinary

final class BASChapter709FFISmokeTests: XCTestCase {

    /// `bas_ranker_softmax_simd` links, returns rc == 0, and produces a real
    /// softmax: all outputs in (0,1), summing to 1, order-preserving.
    func testSoftmaxSimdFFIContract() {
        let x: [Float] = [-2.0, -0.5, 0.0, 0.5, 3.0]
        var out = [Float](repeating: .nan, count: x.count)
        let rc = x.withUnsafeBufferPointer { xp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_softmax_simd(
                    xp.baseAddress, x.count,
                    op.baseAddress, op.count)
            }
        }
        XCTAssertEqual(rc, 0, "FFI wrapper must accept a well-formed call")
        XCTAssertEqual(out.reduce(0, +), 1.0, accuracy: 1e-5,
                       "softmax outputs must sum to 1")
        for v in out { XCTAssertTrue(v > 0 && v < 1, "each probability in (0,1); got \(v)") }
        XCTAssertEqual(out.firstIndex(of: out.max()!), 4,
                       "largest input must map to largest probability")
    }

    /// `bas_ranker_layer_norm_welford` links, returns rc == 0, and normalises to
    /// ~zero mean / ~unit variance.
    func testLayerNormWelfordFFIContract() {
        let x: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
        var out = [Float](repeating: .nan, count: x.count)
        let rc = x.withUnsafeBufferPointer { xp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_layer_norm_welford(
                    xp.baseAddress, x.count,
                    op.baseAddress, op.count,
                    1e-5)
            }
        }
        XCTAssertEqual(rc, 0, "FFI wrapper must accept a well-formed call")
        let mean = out.reduce(0, +) / Float(out.count)
        XCTAssertEqual(mean, 0.0, accuracy: 1e-4, "layer-norm output mean ≈ 0")
        let variance = out.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Float(out.count)
        XCTAssertEqual(variance, 1.0, accuracy: 1e-3, "layer-norm output variance ≈ 1")
    }

    /// The wrappers' documented rejection contract: a length mismatch between the
    /// input and the output buffer must return -2 rather than corrupt memory.
    func testFFIRejectsMismatchedBufferLengths() {
        let x: [Float] = [1.0, 2.0, 3.0]
        var out = [Float](repeating: 0, count: 2)   // deliberately wrong length
        let softmaxRC = x.withUnsafeBufferPointer { xp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_softmax_simd(
                    xp.baseAddress, x.count, op.baseAddress, op.count)
            }
        }
        XCTAssertEqual(softmaxRC, -2, "n != out_n must be rejected")
        let lnRC = x.withUnsafeBufferPointer { xp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_layer_norm_welford(
                    xp.baseAddress, x.count, op.baseAddress, op.count, 1e-5)
            }
        }
        XCTAssertEqual(lnRC, -2, "n != out_n must be rejected")
    }
}
