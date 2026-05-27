// MARK: - BASChapter870BrainMPSGraphAttentionParityTests
// chapter 八百七十 / M3016 — Brain-level MPSGraph attention wiring
// + routing flip + Dv≠D fallback verification。
//
// Chapter 八百六十九 measured MPSGraph (warm) as 2.31-3.09× faster
// than scaled_dot_product AND FlashAttention at production shapes
// — but only via direct kernel calls,not through BASCognitiveBrain。
// Chapter 八百七十:
//   - Added `BASCognitiveBrain.mpsGraphAttention(...)` public method
//   - Brain-owned shared kernel + cache (so cache 30× speedup survives)
//   - Flipped `BASAutoRouteRanker.attentionChoice` rule from FA → MPSGraph
//   - Added Dv ≠ D fallback to .metalStandardAttention
//
// This test file pins the Brain-level integration:
//   - Parity: brain.mpsGraphAttention output ≡ brain.attention within 1e-4
//   - Cache reuse: same brain instance reuses kernel + cache across calls
//   - Routing: attentionAuto correctly dispatches the new choice
//   - Fallback: Dv ≠ D goes to .metalStandardAttention (not FA, not MPS)
//   - Constraint: mpsGraphAttention with Dv ≠ D throws specific error

import XCTest
@testable import BASRuntimeCore
@testable import BASHostKit
@testable import BASMetalSubstrate

#if !os(iOS)  // ch 1022 source-gate
final class BASChapter870BrainMPSGraphAttentionParityTests:
    XCTestCase
{

    private func makeAttentionInputs(
        M: Int, N: Int, D: Int, Dv: Int
    ) -> (q: [Float], k: [Float], v: [Float]) {
        var seed: UInt32 = 0xCAFEBABE
        func next() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(seed & 0xFFFF)
                / Float(0xFFFF) - 0.5
        }
        let q = (0..<(M * D)).map { _ in next() }
        let k = (0..<(N * D)).map { _ in next() }
        let v = (0..<(N * Dv)).map { _ in next() }
        return (q, k, v)
    }

    // MARK: - Knife 7: Brain-level parity

    /// brain.mpsGraphAttention(...) output must match brain.attention(...)
    /// within 1e-4 (chapter 392 IEEE Float32 tolerance) at the
    /// production shape that triggers the new routing。
    func testBrainMPSGraphMatchesBrainAttentionAtMedium()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (M, N, D, Dv) = (32, 64, 32, 32)
        let (q, k, v) = makeAttentionInputs(
            M: M, N: N, D: D, Dv: Dv)
        let mpsOut: [Float]
        do {
            mpsOut = try await brain.mpsGraphAttention(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal framework unavailable")
        }
        let stdOut = try await brain.attention(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv)
        XCTAssertEqual(mpsOut.count, stdOut.count)
        for i in 0..<mpsOut.count {
            XCTAssertEqual(mpsOut[i], stdOut[i],
                accuracy: 1e-4,
                "idx \(i): brain.mpsGraphAttention must " +
                "match brain.attention within 1e-4 at " +
                "(\(M),\(N),\(D))")
        }
    }

    func testBrainMPSGraphMatchesBrainAttentionAtLarge()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (M, N, D, Dv) = (32, 256, 32, 32)
        let (q, k, v) = makeAttentionInputs(
            M: M, N: N, D: D, Dv: Dv)
        let mpsOut: [Float]
        do {
            mpsOut = try await brain.mpsGraphAttention(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal framework unavailable")
        }
        let stdOut = try await brain.attention(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv)
        for i in 0..<mpsOut.count {
            XCTAssertEqual(mpsOut[i], stdOut[i],
                accuracy: 1e-4,
                "idx \(i): brain.mpsGraphAttention vs " +
                "brain.attention at large shape")
        }
    }

    // MARK: - Knife 8: Cache lifecycle

    /// Multiple brain.mpsGraphAttention calls at the same shape
    /// must reuse the lazily-initialized kernel + cache。 If a
    /// future refactor accidentally per-call new-instances the
    /// kernel,the 30.48× cache speedup measured at chapter 八百六十九
    /// collapses。 This test pins the「same instance,same shape,
    /// must speedup」 invariant by checking the second call is
    /// MUCH faster than the first (which includes cache miss +
    /// compile)。
    func testBrainMPSGraphCacheReusesAcrossCalls() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (M, N, D, Dv) = (32, 64, 32, 32)
        let (q, k, v) = makeAttentionInputs(
            M: M, N: N, D: D, Dv: Dv)

        // First call:cold path (compile + populate cache)
        let coldStart =
            DispatchTime.now().uptimeNanoseconds
        do {
            _ = try await brain.mpsGraphAttention(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal framework unavailable")
        }
        let coldEnd = DispatchTime.now().uptimeNanoseconds
        let coldNs = Double(coldEnd - coldStart)

        // 30 subsequent calls:warm cache,take median
        var warmSamples: [Double] = []
        for _ in 0..<30 {
            let s = DispatchTime.now().uptimeNanoseconds
            _ = try await brain.mpsGraphAttention(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
            let e = DispatchTime.now().uptimeNanoseconds
            warmSamples.append(Double(e - s))
        }
        warmSamples.sort()
        let warmNs = warmSamples[warmSamples.count / 2]

        print(String(format:
            "BENCH brain.mpsGraphAttention cache lifecycle " +
            "M=%d N=%d D=%d:\n" +
            "  cold (1st call) = %10.0f ns\n" +
            "  warm (median 30) = %10.0f ns " +
            "(speedup=%.2fx)",
            M, N, D, coldNs, warmNs, coldNs / warmNs))

        // Brain must be reusing kernel + cache。 If每次 new
        // kernel + cache,coldNs == warmNs (within noise)。
        // Pin: warm must be ≥4× faster than cold (chapter
        // 八百六十九 observed 30.48× speedup;weak pin at 4×)
        XCTAssertLessThan(warmNs, coldNs * 0.25,
            "Brain MPSGraph cache must reuse — second call " +
            "should be ≥4× faster than first。 " +
            "coldNs=\(coldNs) warmNs=\(warmNs) " +
            "speedup=\(coldNs/warmNs)x。 If close to 1× " +
            "→ kernel/cache is being recreated per-call")
    }

    // MARK: - Knife 9: attentionAuto routing dispatch

    /// brain.attentionAuto with Dv=D at production shape must
    /// route through .metalMPSGraphAttention and return the
    /// matching BASAutoRouteResult choice tag。
    func testAttentionAutoDispatchesMPSGraphAtProductionShape()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (M, N, D, Dv) = (32, 64, 32, 32)
        let (q, k, v) = makeAttentionInputs(
            M: M, N: N, D: D, Dv: Dv)
        let result: BASAutoRouteResult<[Float]>
        do {
            result = try await brain.attentionAuto(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal framework unavailable")
        }
        XCTAssertEqual(result.choice, .metalMPSGraphAttention,
            "attentionAuto must dispatch MPSGraph for " +
            "(\(M),\(N),\(D)) Dv=\(Dv) per chapter 八百七十 rule")
        XCTAssertEqual(result.value.count, M * Dv)
    }

    // MARK: - Knife 10: Dv ≠ D fallback

    /// Auto-router with Dv ≠ D must fall back to
    /// .metalStandardAttention (NOT .metalFlashAttention)。
    func testAttentionAutoFallsBackToStdAtDvMismatch()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (M, N, D, Dv) = (32, 64, 32, 16)  // Dv ≠ D
        let (q, k, v) = makeAttentionInputs(
            M: M, N: N, D: D, Dv: Dv)
        let result: BASAutoRouteResult<[Float]>
        do {
            result = try await brain.attentionAuto(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal framework unavailable")
        }
        XCTAssertEqual(result.choice, .metalStandardAttention,
            "attentionAuto with Dv=\(Dv) ≠ D=\(D) must fall " +
            "back to std (chapter 八百六十八 measured FA as " +
            "slower than std,so fallback to slower would be wrong)")
        XCTAssertEqual(result.value.count, M * Dv)
    }

    /// Direct brain.mpsGraphAttention with Dv ≠ D must throw
    /// the specific BASCognitiveBrainAttentionError variant
    /// rather than silently returning wrong output。
    func testBrainMPSGraphThrowsOnDvMismatch() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (M, N, D, Dv) = (8, 16, 32, 16)  // Dv ≠ D
        let (q, k, v) = makeAttentionInputs(
            M: M, N: N, D: D, Dv: Dv)
        do {
            _ = try await brain.mpsGraphAttention(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
            XCTFail("Expected throw on Dv ≠ D")
        } catch BASCognitiveBrainAttentionError
            .mpsGraphDvDimensionMustEqualD(
                let qC, let vC)
        {
            XCTAssertEqual(qC, D)
            XCTAssertEqual(vC, Dv)
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal framework unavailable")
        }
    }
}
#endif
