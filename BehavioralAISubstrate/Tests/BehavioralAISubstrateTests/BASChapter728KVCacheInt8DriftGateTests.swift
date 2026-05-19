// MARK: - BASChapter728KVCacheInt8DriftGateTests
// chapter 七百二十八 第三刀 / M2313
//
// Highest accuracy risk in the aggressive arc。 KV cache
// quantization simulation:replay 100 "turns" where each turn
// reads a token,quantizes the key/value tensors,then
// recovers them via dequantize for the downstream attention
// step。 Measure the accumulated drift across the sequence。
//
// Per plan-agent's honest reading of the test design:
//   "Long-context sessions may exceed 0.01 in drift。 Likely
//    flip-OFF。"
//
// This test pins the actual envelope so the chapter close-out
// (Knife 5) can decide based on evidence,not assumption。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter728KVCacheInt8DriftGateTests: XCTestCase {

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
        // L2-normalize so cosine semantics apply
        var sumSq: Float = 0
        for x in v { sumSq += x * x }
        let mag = sqrt(sumSq)
        if mag > 0 {
            for i in 0..<dim { v[i] /= mag }
        }
        return v
    }

    private func makeToken(
        seed: UInt64, dim: Int
    ) -> BASTransformerKVCacheToken {
        let k = unitVector(seed: seed * 7, dim: dim)
        let v = unitVector(seed: seed * 11 + 3, dim: dim)
        let kBytes = k.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let vBytes = v.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        return BASTransformerKVCacheToken(
            keyBytes: kBytes,
            valueBytes: vBytes,
            elementCount: dim)
    }

    private func float32Cosine(
        _ a: [Float], _ b: [Float]
    ) -> Float {
        var dot: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
        }
        return dot
    }

    private func bytesToFloatArray(
        _ d: Data
    ) -> [Float] {
        return d.withUnsafeBytes { rb in
            let p = rb.bindMemory(to: Float.self)
            return Array(p)
        }
    }

    // MARK: - Single-token round-trip drift

    func testSingleTokenRoundTripDrift() {
        #if os(iOS) || os(macOS)
        // 1 token at 128-element dim (typical per-layer KV
        // tensor size for a small model)。
        let dim = 128
        let token = makeToken(seed: 7, dim: dim)
        let quantized = token.toQuantizedInt8()
        XCTAssertNotNil(quantized)
        let recovered = quantized?.toFloat32Token()
        XCTAssertNotNil(recovered)
        let origK = bytesToFloatArray(token.keyBytes)
        let recK = bytesToFloatArray(recovered!.keyBytes)
        let origV = bytesToFloatArray(token.valueBytes)
        let recV = bytesToFloatArray(recovered!.valueBytes)
        // cosine(orig_k, rec_k) ≈ 1
        let cK = float32Cosine(origK, recK)
            / sqrt(float32Cosine(origK, origK)
                * float32Cosine(recK, recK))
        let cV = float32Cosine(origV, recV)
            / sqrt(float32Cosine(origV, origV)
                * float32Cosine(recV, recV))
        XCTAssertGreaterThan(cK, 0.99)
        XCTAssertGreaterThan(cV, 0.99)
        #endif
    }

    // MARK: - 100-turn replay drift accumulation

    func testReplayDriftAcross100Turns() {
        #if os(iOS) || os(macOS)
        let dim = 128
        let turns = 100

        // Simulate 100-turn replay:each turn reads a fresh
        // KV token,quantizes it,then computes an "attention
        // score" by dotting with a fresh query。 Track the
        // accumulated cosine drift between the Float32 path
        // and the int8 path over the whole sequence。

        var f32Scores: [Float] = []
        var int8Scores: [Float] = []
        f32Scores.reserveCapacity(turns)
        int8Scores.reserveCapacity(turns)

        for turn in 0..<turns {
            let token = makeToken(
                seed: UInt64(turn * 31 + 1), dim: dim)
            let query = unitVector(
                seed: UInt64(turn * 7 + 13), dim: dim)
            // Float32 reference:
            //   score = query · key (since query and key
            //   are unit vectors,this IS the cosine)
            let kF = bytesToFloatArray(token.keyBytes)
            let f32Score = float32Cosine(query, kF)
            f32Scores.append(f32Score)
            // int8 path:quantize key,dequantize,then dot
            // with the (Float32) query。 This is the actual
            // production semantic — the query stays Float32,
            // only the cached key is quantized。
            guard let quant = token.toQuantizedInt8(),
                  let recovered = quant.toFloat32Token()
            else {
                XCTFail("quantize/dequantize failed")
                return
            }
            let kRecovered = bytesToFloatArray(
                recovered.keyBytes)
            let i8Score = float32Cosine(query, kRecovered)
            int8Scores.append(i8Score)
        }

        // Accumulated drift = max per-turn absolute drift
        var maxDrift: Float = 0
        var driftSum: Double = 0
        for i in 0..<turns {
            let d = abs(f32Scores[i] - int8Scores[i])
            if d > maxDrift { maxDrift = d }
            driftSum += Double(d)
        }
        let avgDrift = driftSum / Double(turns)

        print("")
        print(
            "## chapter 七百二十八 第三刀 — KV cache 100-turn replay drift")
        print("")
        print(String(
            format: "  Turns:      %d (each turn: fresh key + query)",
            turns))
        print(String(
            format: "  Per-token dim: %d", dim))
        print(String(
            format: "  Max drift:  %.6f", maxDrift))
        print(String(
            format: "  Avg drift:  %.6f", avgDrift))
        print(String(
            format: "  Gate:       ≤ 0.01 (%@)",
            maxDrift <= 0.01 ? "PASS ✅" : "FAIL ❌"))
        print("")

        XCTAssertLessThanOrEqual(
            maxDrift, 0.01,
            "max KV-cache cosine drift \(maxDrift) exceeds 0.01")
        #endif
    }

    // MARK: - Memory shrink sanity

    func testKVQuantizationDelivers3xMemoryShrink() {
        #if os(iOS) || os(macOS)
        let dim = 256
        let token = makeToken(seed: 42, dim: dim)
        let quantized = token.toQuantizedInt8()!
        let ratio = quantized.memoryShrinkRatio
        print(String(
            format: "  KV memory shrink: %.2f×",
            ratio))
        // Per-token has 2 scales + element count + version
        // overhead → ratio approaches 4× as dim grows。 Gate
        // at ≥ 3× to leave headroom for the overhead at
        // smaller dims。
        XCTAssertGreaterThan(ratio, 3.0)
        #endif
    }
}
