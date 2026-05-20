// MARK: - BASChapter731AutoregressiveKVDriftTests
// chapter 七百三十一 第三刀 / M2328
//
// Addresses the chapter 七百二十八 KV cache scope-gap:
//
//   "The 100-turn drift gate uses INDEPENDENT turns (not
//    autoregressive compounding)。 Real LLM sessions where token
//    i depends on tokens 0..i-1 could see multiplicative drift
//    — substrate doesn't measure that。"
//
// This test builds an autoregressive simulator:each step's
// query is the running ATTENTION OUTPUT of the previous step
// (= softmax-weighted sum of dequantized KV cache entries)。
// Drift compounds across the sequence。 Measure the worst-case
// compounded drift envelope across a 100-step sequence。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter731AutoregressiveKVDriftTests:
    XCTestCase
{

    private func unitVector(
        seed: UInt64, dim: Int
    ) -> [Float] {
        var s = seed
        var v = [Float](repeating: 0, count: dim)
        for i in 0..<dim {
            s &+= 0x9E37_79B9_7F4A_7C15
            var z = s
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z = z ^ (z >> 31)
            v[i] = (Float(z & 0xFFFF_FFFF)
                / Float(UInt32.max)) * 2 - 1
        }
        var sumSq: Float = 0
        for x in v { sumSq += x * x }
        let mag = sqrt(sumSq)
        if mag > 0 {
            for i in 0..<dim { v[i] /= mag }
        }
        return v
    }

    /// Stable softmax with mean-shift。
    private func softmax(_ x: [Float]) -> [Float] {
        guard !x.isEmpty else { return [] }
        let xmax = x.max() ?? 0
        var ex = x.map { exp($0 - xmax) }
        let sum = ex.reduce(0, +)
        if sum > 0 {
            for i in 0..<ex.count { ex[i] /= sum }
        }
        return ex
    }

    private func dot(_ a: [Float], _ b: [Float]) -> Float {
        var s: Float = 0
        for i in 0..<a.count { s += a[i] * b[i] }
        return s
    }

    private func cosine(_ a: [Float], _ b: [Float]) -> Float {
        let d = dot(a, b)
        let na = sqrt(dot(a, a))
        let nb = sqrt(dot(b, b))
        return d / (na * nb + 1e-12)
    }

    /// Simulate one attention step:given query + KV pairs,
    /// compute attention output = sum_i softmax(q·K[i]) × V[i]。
    private func attentionStep(
        query: [Float],
        keys: [[Float]],
        values: [[Float]]
    ) -> [Float] {
        let dim = query.count
        var scores: [Float] = []
        scores.reserveCapacity(keys.count)
        for k in keys {
            scores.append(dot(query, k))
        }
        let weights = softmax(scores)
        var out = [Float](repeating: 0, count: dim)
        for (i, w) in weights.enumerated() {
            for j in 0..<dim {
                out[j] += w * values[i][j]
            }
        }
        // L2-renormalize for unit-vector contract
        var sumSq: Float = 0
        for x in out { sumSq += x * x }
        let mag = sqrt(sumSq)
        if mag > 0 {
            for j in 0..<dim { out[j] /= mag }
        }
        return out
    }

    /// Quantize a Float32 vector through the BASTransformer
    /// KVCacheToken → quantize → dequantize round-trip。
    private func quantizeRoundTrip(
        _ v: [Float]
    ) -> [Float]? {
        let bytes = v.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let token = BASTransformerKVCacheToken(
            keyBytes: bytes,
            valueBytes: bytes,
            elementCount: v.count)
        guard let q = token.toQuantizedInt8(),
              let back = q.toFloat32Token()
        else { return nil }
        return back.keyBytes.withUnsafeBytes { rb in
            let p = rb.bindMemory(to: Float.self)
            return Array(p)
        }
    }

    // MARK: - The autoregressive drift simulation

    func testAutoregressiveDriftAcross100Steps() {
        #if os(iOS) || os(macOS)
        let dim = 64
        let nKVPairs = 50
        let nSteps = 100

        // Build the KV cache (deterministic from seed)
        var keysF32: [[Float]] = []
        var valuesF32: [[Float]] = []
        for i in 0..<nKVPairs {
            keysF32.append(unitVector(
                seed: UInt64(i * 31 + 1), dim: dim))
            valuesF32.append(unitVector(
                seed: UInt64(i * 31 + 17), dim: dim))
        }
        // int8-quantized cache (one round-trip per entry)
        var keysI8: [[Float]] = []
        var valuesI8: [[Float]] = []
        for i in 0..<nKVPairs {
            guard let k = quantizeRoundTrip(keysF32[i]),
                  let v = quantizeRoundTrip(valuesF32[i])
            else {
                XCTFail("KV quantize failed at \(i)")
                return
            }
            keysI8.append(k)
            valuesI8.append(v)
        }

        // Initial query = uniform random
        var qF32 = unitVector(seed: 999_888, dim: dim)
        var qI8 = qF32  // start identical

        // Run 100 autoregressive steps。 Each step the query is
        // the previous step's attention output (= running
        // context vector)。 Drift accumulates because qI8 is
        // computed against quantized KV while qF32 uses
        // Float32 KV。
        var minCosOverSteps: Float = 1.0
        var maxDriftOverSteps: Float = 0.0
        var driftAtStep: [Float] = []
        driftAtStep.reserveCapacity(nSteps)

        for step in 0..<nSteps {
            let nextF32 = attentionStep(
                query: qF32,
                keys: keysF32,
                values: valuesF32)
            let nextI8 = attentionStep(
                query: qI8,
                keys: keysI8,
                values: valuesI8)
            // Compare the two attention outputs (both unit
            // vectors)
            let c = cosine(nextF32, nextI8)
            let drift = 1.0 - c
            driftAtStep.append(drift)
            if c < minCosOverSteps {
                minCosOverSteps = c
            }
            if drift > maxDriftOverSteps {
                maxDriftOverSteps = drift
            }
            qF32 = nextF32
            qI8 = nextI8
        }

        print("")
        print(
            "## chapter 七百三十一 第三刀 — autoregressive KV drift")
        print("")
        print(String(
            format: "  Sequence: %d steps × %d KV pairs × %d dim",
            nSteps, nKVPairs, dim))
        print(String(
            format: "  Min cosine(f32_out, i8_out): %.6f",
            minCosOverSteps))
        print(String(
            format: "  Max compounded drift:        %.6f",
            maxDriftOverSteps))
        print("")
        print(
            "  Drift progression (every 10 steps):")
        for s in stride(from: 0, to: nSteps, by: 10) {
            print(String(
                format: "    step %3d: drift = %.6f",
                s, driftAtStep[s]))
        }
        print("")
        print(
            "  Chapter 七百二十八 measured per-token (independent)")
        print(
            "  drift at ≤ 0.001。 This test pins the COMPOUNDED")
        print(
            "  drift across an actual autoregressive sequence,")
        print(
            "  where each step's query depends on the previous")
        print(
            "  step's attention output。 The gate question:does")
        print(
            "  the compounded drift stay within a usable envelope")
        print(
            "  for production multi-turn inference?")
        print("")
        print(String(
            format: "  Honest gate (≤ 0.1 for usable inference): %@",
            maxDriftOverSteps <= 0.1 ? "PASS ✅" : "FAIL ❌"))
        print("")

        // Honest gate: compounded drift should stay BELOW 0.1
        // (= cosine ≥ 0.9 between Float32 and int8 attention
        // outputs at every step)。 Above 0.1 the int8 cache
        // would meaningfully diverge from Float32 over the
        // session。
        XCTAssertLessThanOrEqual(
            maxDriftOverSteps, 0.1,
            "Compounded autoregressive drift exceeds 0.1")
        #endif
    }

    func testAutoregressiveDriftSettlesNotBlowsUp() {
        #if os(iOS) || os(macOS)
        // Variant test:longer sequence (200 steps),smaller
        // KV cache。 Verifies drift SETTLES rather than blowing
        // up exponentially。 If int8 introduces a systematic
        // bias the sequence would drift unboundedly。
        let dim = 32
        let nKVPairs = 20
        let nSteps = 200

        var keysF32: [[Float]] = []
        var valuesF32: [[Float]] = []
        for i in 0..<nKVPairs {
            keysF32.append(unitVector(
                seed: UInt64(i * 31 + 1), dim: dim))
            valuesF32.append(unitVector(
                seed: UInt64(i * 31 + 17), dim: dim))
        }
        var keysI8: [[Float]] = []
        var valuesI8: [[Float]] = []
        for i in 0..<nKVPairs {
            keysI8.append(
                quantizeRoundTrip(keysF32[i])!)
            valuesI8.append(
                quantizeRoundTrip(valuesF32[i])!)
        }
        var qF32 = unitVector(seed: 123_456, dim: dim)
        var qI8 = qF32
        var driftsLastHalf: [Float] = []
        var driftsFirstHalf: [Float] = []
        for step in 0..<nSteps {
            qF32 = attentionStep(
                query: qF32,
                keys: keysF32, values: valuesF32)
            qI8 = attentionStep(
                query: qI8,
                keys: keysI8, values: valuesI8)
            let d = 1.0 - cosine(qF32, qI8)
            if step < nSteps / 2 {
                driftsFirstHalf.append(d)
            } else {
                driftsLastHalf.append(d)
            }
        }
        let maxFirst = driftsFirstHalf.max() ?? 0
        let maxLast = driftsLastHalf.max() ?? 0
        print("")
        print(
            "## chapter 七百三十一 第三刀 — drift settling")
        print(String(
            format: "  Max drift first half:  %.6f",
            maxFirst))
        print(String(
            format: "  Max drift last half:   %.6f",
            maxLast))
        print(String(
            format: "  Ratio (last / first):  %.2fx",
            maxLast / max(maxFirst, 1e-6)))
        print("")
        // Honest gate: drift should NOT explode (ratio not
        // wildly > 2)。 If int8 had systematic bias the ratio
        // would be >> 1。
        XCTAssertLessThanOrEqual(
            maxLast,
            max(maxFirst, 0.01) * 2.0,
            "Drift growing unboundedly across sequence")
        #endif
    }
}
