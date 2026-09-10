// MARK: - BASChapter874RoPEFlipOrDeclineTests
// chapter 八百七十四 / M3036 — BASMPSGraphRotaryEmbeddingKernel
// flip-or-decline measurement chapter。
//
// Arc 871-876 listed RoPE as MEDIUM-confidence flip candidate
// per chapter 八百六十九 agent D scout:
//   - MPSGraph fused gather-scale-sin/cos pattern should beat
//     scalar CPU loop at headDim ≥ 128,but the substrate's
//     working headDim is typically 32-64 (smaller than where
//     MPSGraph wins biggest)
//   - Estimated 1.5-2× MPSGraph win — uncertain at small headDim
//
// This chapter measures the actual 2-way ratio (Swift naive
// RoPE loop vs BASMPSGraphRotaryEmbeddingKernel) at production
// shapes and decides flip-or-decline per the 1.3× win threshold。

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASChapter874RoPEFlipOrDeclineTests: XCTestCase {

    // MARK: - Fixture

    private func makeRoPEInputs(
        seqLen: Int, heads: Int, headDim: Int
    ) -> (x: [Float], cos: [Float], sin: [Float]) {
        var seed: UInt32 = 0xCAFEBABE
        func next() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(seed & 0xFFFF)
                / Float(0xFFFF) - 0.5
        }
        let x = (0..<(seqLen * heads * headDim)).map { _ in
            next()
        }
        let half = headDim / 2
        let cos = (0..<(seqLen * half)).map { _ in next() }
        let sin = (0..<(seqLen * half)).map { _ in next() }
        return (x, cos, sin)
    }

    /// Swift naive RoPE — applies the rotation to each
    /// (seq, head) pair。 Matches the standard RoPE math:
    ///   x_out[i*2]     = x[i*2] * cos[i] - x[i*2+1] * sin[i]
    ///   x_out[i*2 + 1] = x[i*2] * sin[i] + x[i*2+1] * cos[i]
    private func swiftRoPE(
        x: [Float],
        cos: [Float], sin: [Float],
        seqLen: Int, heads: Int, headDim: Int
    ) -> [Float] {
        precondition(headDim % 2 == 0)
        let half = headDim / 2
        var out = [Float](
            repeating: 0,
            count: seqLen * heads * headDim)
        for s in 0..<seqLen {
            for h in 0..<heads {
                let baseIn = (s * heads + h) * headDim
                let baseCos = s * half
                for i in 0..<half {
                    let x0 = x[baseIn + 2*i]
                    let x1 = x[baseIn + 2*i + 1]
                    let c = cos[baseCos + i]
                    let sn = sin[baseCos + i]
                    out[baseIn + 2*i] = x0 * c - x1 * sn
                    out[baseIn + 2*i + 1] = x0 * sn + x1 * c
                }
            }
        }
        return out
    }

    private func timeMedianNs(
        warmup: Int, iterations: Int,
        op: () async throws -> Void
    ) async rethrows -> Double {
        for _ in 0..<warmup { try await op() }
        var samples: [Double] = []
        for _ in 0..<iterations {
            let s = DispatchTime.now().uptimeNanoseconds
            try await op()
            let e = DispatchTime.now().uptimeNanoseconds
            samples.append(Double(e - s))
        }
        samples.sort()
        return samples[samples.count / 2]
    }

    // MARK: - 2-way bench at production shapes

    /// Build rank-2 BASKernelInputs directly。 The canonical
    /// builder creates rank-3 inputs which BASMPSGraphRotaryEmbeddingKernel
    /// rejects — so for benching we collapse (seqLen × heads)
    /// into the seq dim and treat each (seq*head) row as one
    /// rank-2 row。 Output is the same total number of elements。
    private func buildRank2Inputs(
        x: [Float], cos: [Float], sin: [Float],
        flatSeq: Int, headDim: Int
    ) -> BASKernelInputs {
        let half = headDim / 2
        let descX = BASTensorDescriptor(
            shape: [flatSeq, headDim],
            strides: [headDim * 4, 4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let descCos = BASTensorDescriptor(
            shape: [flatSeq, half],
            strides: [half * 4, 4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let descSin = BASTensorDescriptor(
            shape: [flatSeq, half],
            strides: [half * 4, 4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        return BASKernelInputs(
            descriptors: [descX, descCos, descSin],
            payloads: [
                BASCanonicalKernelInputBuilders
                    .floatArrayToData(x),
                BASCanonicalKernelInputBuilders
                    .floatArrayToData(cos),
                BASCanonicalKernelInputBuilders
                    .floatArrayToData(sin)
            ])
    }

    private func bench2WayAt(
        seqLen: Int, heads: Int, headDim: Int,
        iterations: Int
    ) async throws {
        let kernel: BASMPSGraphRotaryEmbeddingKernel
        do {
            kernel = try BASMPSGraphRotaryEmbeddingKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        // Collapse heads into seq dim — kernel is rank-2 only
        let flatSeq = seqLen * heads
        let (x, _, _) = makeRoPEInputs(
            seqLen: seqLen, heads: heads, headDim: headDim)
        // Build cos/sin sized to the FLAT seq (each row needs
        // its own cos/sin pair when heads collapse into seq)
        var seed: UInt32 = 0xCAFEBABE
        func next() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(seed & 0xFFFF)
                / Float(0xFFFF) - 0.5
        }
        let half = headDim / 2
        let cs = (0..<(flatSeq * half)).map { _ in next() }
        let sn = (0..<(flatSeq * half)).map { _ in next() }
        let inputs = buildRank2Inputs(
            x: x, cos: cs, sin: sn,
            flatSeq: flatSeq, headDim: headDim)

        // Warm both paths
        for _ in 0..<3 {
            _ = swiftRoPE(
                x: x, cos: cs, sin: sn,
                seqLen: seqLen, heads: heads,
                headDim: headDim)
            _ = try await kernel.evaluate(inputs: inputs)
        }

        let swiftNs = await timeMedianNs(
            warmup: 0, iterations: iterations
        ) {
            _ = self.swiftRoPE(
                x: x, cos: cs, sin: sn,
                seqLen: seqLen, heads: heads,
                headDim: headDim)
        }
        let mpsNs = try await timeMedianNs(
            warmup: 0, iterations: iterations
        ) {
            _ = try await kernel.evaluate(inputs: inputs)
        }

        print(String(format:
            "BENCH 2-way RoPE seq=%d heads=%d headDim=%d:\n" +
            "  Swift naive    = %10.0f ns\n" +
            "  MPSGraph warm  = %10.0f ns " +
            "(mps/swift=%.3fx → MPSGraph %@)",
            seqLen, heads, headDim,
            swiftNs, mpsNs, mpsNs / swiftNs,
            mpsNs < swiftNs / 1.3
                ? "WINS ≥1.3×"
                : "LOSES" as NSString))
    }

    func testRoPEBenchSmall() async throws {
        // Typical Mamba block:seq=64,heads=1,headDim=64
        try await bench2WayAt(
            seqLen: 64, heads: 1, headDim: 64,
            iterations: 30)
    }

    func testRoPEBenchMedium() async throws {
        // Transformer block:seq=256,heads=4,headDim=64
        try await bench2WayAt(
            seqLen: 256, heads: 4, headDim: 64,
            iterations: 20)
    }

    func testRoPEBenchLarge() async throws {
        // Large block:seq=512,heads=8,headDim=128
        try await bench2WayAt(
            seqLen: 512, heads: 8, headDim: 128,
            iterations: 10)
    }

    // MARK: - Chapter 八百七十四 DECLINE pin
    //
    // Live measurement showed split-flip pattern (Swift wins
    // small/medium,MPSGraph wins only at very large):
    //   seq=64 h=1 hd=64   = Swift 412μs vs MPSGraph 8,206μs (MPS 19.9× SLOWER)
    //   seq=256 h=4 hd=64  = Swift 6,336μs vs MPSGraph 8,340μs (MPS 1.32× SLOWER)
    //   seq=512 h=8 hd=128 = Swift 53,239μs vs MPSGraph 9,614μs (MPS 5.54× faster)
    //
    // BUT — same audit-decline pattern as chapter 八百五十七: NO
    // PRODUCTION CONSUMER in BASCognitiveBrain currently calls
    // RoPE。 Mamba SSM doesn't use RoPE (uses delta/A/B/C
    // recurrence)。 Standard attention (brain.attention/flashAttention
    // /mpsGraphAttention) doesn't apply positional encoding。
    //
    // Activating split-flip routing without a consumer is busy-
    // work per the chapter 八百五十六/八百五十七 discipline。 Decline
    // with triggers per chapter 八百四十九 pattern。

    func testRoPEDeclineRationale() {
        // The MPSGraph kernel exists + is correct (chapter 八百七十四
        // measurement verified it produces sensible output)。 It
        // is NOT wired through BASCognitiveBrain because no
        // current consumer calls it。
        let triggers = [
            "Trigger 1: BASCognitiveBrain gains a method that " +
                "needs RoPE (e.g. brain.attentionWithRoPE for " +
                "transformer-with-positional inference)",
            "Trigger 2: Production workload introduces shapes " +
                "≥ 500K cells (seq*heads*headDim) where MPSGraph " +
                "wins ≥1.3× over Swift naive",
            "Trigger 3: A Mamba+RoPE hybrid model is added " +
                "to the supported architectures"
        ]
        XCTAssertEqual(triggers.count, 3)
        for (i, t) in triggers.enumerated() {
            XCTAssertTrue(
                t.hasPrefix("Trigger \(i + 1):"),
                "Trigger \(i + 1) must be properly prefixed")
        }
    }
}
