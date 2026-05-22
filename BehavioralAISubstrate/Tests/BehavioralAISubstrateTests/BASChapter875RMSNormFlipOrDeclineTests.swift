// MARK: - BASChapter875RMSNormFlipOrDeclineTests
// chapter 八百七十五 / M3041 — BASMPSGraphRMSNormKernel flip-or-decline
// measurement chapter。
//
// Arc 871-876 plan listed RMSNorm as MEDIUM-confidence flip
// candidate:Metal dispatch overhead ~150μs likely dominates
// below hiddenDim ~1024,but substrate's working dims may
// exceed。 Per agent D scout estimated 1.2-1.8× MPSGraph win
// at large dim only。
//
// Also chapter 八百五十七 caught that NO PRODUCTION CONSUMER
// currently calls RMSNorm — same DECLINED-PENDING-CONSUMER
// situation as RoPE (chapter 八百七十四 decline)。

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASChapter875RMSNormFlipOrDeclineTests: XCTestCase {

    // MARK: - Fixture

    private func makeRMSNormInputs(
        batchSeq: Int, hiddenDim: Int
    ) -> (x: [Float], gamma: [Float]) {
        var seed: UInt32 = 0xCAFEBABE
        func next() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(seed & 0xFFFF)
                / Float(0xFFFF) - 0.5
        }
        let x = (0..<(batchSeq * hiddenDim)).map { _ in next() }
        let gamma = (0..<hiddenDim).map { _ in
            0.5 + next() / 2
        }
        return (x, gamma)
    }

    /// Swift naive RMSNorm reference。
    ///   rms_i = sqrt(mean(x[i, :]^2) + eps)
    ///   y[i, :] = (x[i, :] / rms_i) * gamma[:]
    private func swiftRMSNorm(
        x: [Float], gamma: [Float],
        batchSeq: Int, hiddenDim: Int,
        eps: Float = 1e-6
    ) -> [Float] {
        var out = [Float](
            repeating: 0,
            count: batchSeq * hiddenDim)
        let invDim = 1.0 / Float(hiddenDim)
        for s in 0..<batchSeq {
            let base = s * hiddenDim
            var sumSq: Float = 0
            for d in 0..<hiddenDim {
                let v = x[base + d]
                sumSq += v * v
            }
            let rms = (sumSq * invDim + eps).squareRoot()
            let invRms = 1.0 / rms
            for d in 0..<hiddenDim {
                out[base + d] =
                    x[base + d] * invRms * gamma[d]
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

    // MARK: - 2-way bench

    private func bench2WayAt(
        batchSeq: Int, hiddenDim: Int, iterations: Int
    ) async throws {
        let kernel: BASMPSGraphRMSNormKernel
        do {
            kernel = try BASMPSGraphRMSNormKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let (x, gamma) = makeRMSNormInputs(
            batchSeq: batchSeq, hiddenDim: hiddenDim)
        let inputs = BASCanonicalKernelInputBuilders.rmsNorm(
            input: x, gamma: gamma,
            batchSeq: batchSeq, hiddenDim: hiddenDim)

        // Warm both paths
        for _ in 0..<3 {
            _ = swiftRMSNorm(
                x: x, gamma: gamma,
                batchSeq: batchSeq, hiddenDim: hiddenDim)
            _ = try await kernel.evaluate(inputs: inputs)
        }

        let swiftNs = try await timeMedianNs(
            warmup: 0, iterations: iterations
        ) {
            _ = self.swiftRMSNorm(
                x: x, gamma: gamma,
                batchSeq: batchSeq, hiddenDim: hiddenDim)
        }
        let mpsNs = try await timeMedianNs(
            warmup: 0, iterations: iterations
        ) {
            _ = try await kernel.evaluate(inputs: inputs)
        }

        print(String(format:
            "BENCH 2-way RMSNorm batchSeq=%d hiddenDim=%d:\n" +
            "  Swift naive    = %10.0f ns\n" +
            "  MPSGraph warm  = %10.0f ns " +
            "(mps/swift=%.3fx → MPSGraph %@)",
            batchSeq, hiddenDim,
            swiftNs, mpsNs, mpsNs / swiftNs,
            mpsNs < swiftNs / 1.3
                ? "WINS ≥1.3×"
                : "LOSES" as NSString))
    }

    func testRMSNormBenchSmall() async throws {
        // Small Mamba block:batchSeq=64,hiddenDim=128
        try await bench2WayAt(
            batchSeq: 64, hiddenDim: 128, iterations: 30)
    }

    func testRMSNormBenchMedium() async throws {
        // Medium block:batchSeq=128,hiddenDim=512
        try await bench2WayAt(
            batchSeq: 128, hiddenDim: 512, iterations: 20)
    }

    func testRMSNormBenchLarge() async throws {
        // Large block:batchSeq=256,hiddenDim=2048
        try await bench2WayAt(
            batchSeq: 256, hiddenDim: 2048, iterations: 10)
    }

    // MARK: - Chapter 八百七十五 DECLINE pin
    //
    // Same audit-decline pattern as chapter 八百七十四 RoPE +
    // chapter 八百五十七 5-scaffold-kernels: NO PRODUCTION CONSUMER
    // in BASCognitiveBrain currently calls RMSNorm。 The kernel
    // exists + is shipping (chapter 四百四十七 era) but no Brain
    // method routes to it。

    func testRMSNormDeclineRationale() {
        let triggers = [
            "Trigger 1: BASCognitiveBrain gains a method " +
                "that needs RMSNorm (e.g. for transformer " +
                "or LayerNorm-variant block)",
            "Trigger 2: Production workload introduces shapes " +
                "where MPSGraph wins ≥1.3× over Swift naive " +
                "(per chapter 八百七十五 measurement,this is " +
                "expected at very large hiddenDim ≥ 2048)",
            "Trigger 3: A model architecture is added that " +
                "uses pre-norm + RMSNorm in its decoder/encoder"
        ]
        XCTAssertEqual(triggers.count, 3)
        for (i, t) in triggers.enumerated() {
            XCTAssertTrue(
                t.hasPrefix("Trigger \(i + 1):"),
                "Trigger \(i + 1) must be properly prefixed")
        }
    }
}
