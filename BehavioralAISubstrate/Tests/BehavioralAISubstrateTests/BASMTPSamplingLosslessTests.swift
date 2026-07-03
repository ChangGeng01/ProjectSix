import XCTest
import MLX
import MLXNN
@testable import BASMLXAdapter

/// DISTRIBUTION-losslessness of the spec-sampling verdict math (the certifiable core): for arbitrary p (target)
/// and q (draft), the accept/residual procedure must output EXACTLY the production-transformed target
/// distribution. 30k-trial empirical TV distance vs exact p, plain-temp and top-p variants.
final class BASMTPSamplingLosslessTests: XCTestCase {

    private func run(trials: Int, temperature: Float, topP: Float,
                     targetLogits: [Float], draftLogits: [Float]) -> Double {
        let v = targetLogits.count
        let tl = MLXArray(targetLogits)
        // exact production-transformed p (mirror of the vendored sampler)
        var lp = logSoftmax(tl.asType(.float32))
        if topP > 0 && topP < 1 {
            let si = argSort(lp, axis: -1)
            let sl = takeAlong(lp, si, axis: -1)
            let cum = cumsum(exp(sl), axis: -1)
            let filtered = MLX.where(cum .> (1 - topP), sl, MLXArray(-Float.infinity))
            lp = putAlong(lp, si, values: filtered, axis: -1)
        }
        let pExact = softmax(lp * (1 / temperature), axis: -1).asArray(Float.self)
        let qlp = logSoftmax(MLXArray(draftLogits).asType(.float32))
        var counts = [Int](repeating: 0, count: v)
        for _ in 0 ..< trials {
            let d = categorical(qlp * (1 / temperature)).item(Int.self)
            let u = Float.random(in: 0 ..< 1)
            let verdict = BASQwen35MTPSpecDecoder.samplingVerdict(
                targetLogits: tl, draftLogprobsSub: qlp, draftVocab: v,
                temperature: temperature, topP: topP, draftId: d, u: u)
            let outTok = verdict.accepted ? d : categorical(verdict.residualLogits).item(Int.self)
            counts[outTok] += 1
        }
        var tv = 0.0
        for i in 0 ..< v {
            tv += abs(Double(counts[i]) / Double(trials) - Double(pExact[i]))
        }
        return tv / 2
    }

    func testLosslessPlainTemperature() {
        let tv = run(trials: 30_000, temperature: 0.7, topP: 1.0,
                     targetLogits: [2.0, 1.2, 0.4, -0.5, -1.0, 0.9, -2.0, 1.6],
                     draftLogits: [1.1, 1.9, -0.2, 0.1, -1.5, 0.2, -0.5, 0.8])   // q deliberately ≠ p
        print("=== SAMPLING-LOSSLESS temp-only TV = \(tv) ===")
        XCTAssertLessThan(tv, 0.02, "output distribution must equal the target distribution")
    }

    func testLosslessWithTopP() {
        let tv = run(trials: 30_000, temperature: 0.7, topP: 0.8,
                     targetLogits: [2.0, 1.2, 0.4, -0.5, -1.0, 0.9, -2.0, 1.6],
                     draftLogits: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])      // uniform draft (worst case)
        print("=== SAMPLING-LOSSLESS top-p TV = \(tv) ===")
        XCTAssertLessThan(tv, 0.02, "top-p transformed distribution must be preserved")
    }

    func testDraftSubVocabResidualCoversTail() {
        // draft covers only the first 4 ids (sub-head analog) — tail tokens must still appear per p.
        let tv = run(trials: 30_000, temperature: 1.0, topP: 1.0,
                     targetLogits: [0.5, 0.5, 0.5, 0.5, 2.5, 0.5, 0.5, 2.5],
                     draftLogits: [1.0, 1.0, 1.0, 1.0, -1e9, -1e9, -1e9, -1e9])
        print("=== SAMPLING-LOSSLESS sub-vocab TV = \(tv) ===")
        XCTAssertLessThan(tv, 0.02, "residual sampling must cover ids outside the draft's support")
    }
}
