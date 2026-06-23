#if !os(iOS)
import XCTest
@testable import BASHostKit
@testable import BASMLXAdapter
@testable import BASMetalSubstrate
import Foundation

/// QINAO Substrate-100 gates — Phase-2 batch 9 (host-testable tail: metal SSM parity #8 + prompt-lookup identity #15).
final class BASQINAOSubstrateGatesBatch9Tests: XCTestCase {

    func test_qinao_metal_vs_cpu_ssm_scan_parity_mae() async throws {
    // QINAO substrate gate #8 — authoritative CPU SSM scan
    // (BASSSMScanCPUReference.scan) vs the Metal GPU twin
    // (BASMetalSSMScanDispatcher.dispatch) must agree within the
    // documented MAE bound. RAISED BAR over the existing
    // testGPUMatchesCPUReferenceAtMAE_1e_5 (single shape, mae<1e-5):
    //   (a) tighter tolerance — mae <= 1e-6 (and maxErr <= 1e-5)
    //   (b) a SWEEP of several representative shapes, not one.
    // Mirrors BASMetalSSMScanDispatcherTests construction verbatim
    // (V2 loader, LCG fixtures, MAE reduction) and the
    // BASMambaGPUShadowParity "nil OR tiny MAE" Metal-absent guard:
    // if Metal is unavailable the V2 dispatch throws
    // .libraryUnavailable, in which case we skip rather than fail.
    let tightMAE: Float = 1e-6
    let tightMaxErr: Float = 1e-5
    // Representative shapes exercising batch/time/channel iteration
    // at several sizes (existing test only used B:2,L:4,D:3).
    let shapes: [BASSSMScanShape] = [
        BASSSMScanShape(B: 1, L: 2, D: 2),
        BASSSMScanShape(B: 2, L: 4, D: 3),
        BASSSMScanShape(B: 2, L: 8, D: 4),
        BASSSMScanShape(B: 3, L: 6, D: 5),
        BASSSMScanShape(B: 1, L: 16, D: 8)
    ]
    let loader = BASMetalKernelLibraryLoader(useMetalKernelV2: true)
    let dispatcher = BASMetalSSMScanDispatcher(loader: loader)
    var ranAtLeastOne = false
    var worstMAE: Float = 0
    var worstMaxErr: Float = 0
    for shape in shapes {
        let bld = shape.elementCount
        let dCount = Int(shape.D)
        // Deterministic pseudo-random inputs (LCG) — verbatim from
        // the existing testGPUMatchesCPUReferenceAtMAE_1e_5.
        var seed: UInt32 = 0x600D5EED
        func next() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(seed & 0xFFFF) / Float(0xFFFF) - 0.5
        }
        let x     = (0..<bld).map { _ in next() }
        let delta = (0..<bld).map { _ in next() * 0.5 + 0.5 }
        let A     = (0..<dCount).map { _ in next() - 1.0 }
        let B     = (0..<bld).map { _ in next() }
        let C     = (0..<bld).map { _ in next() }
        // GPU dispatch — Metal-absent guard mirrors the shadow
        // parity test's "nil OR tiny MAE" tolerance for hosts
        // without Metal (V2 loader surfaces .libraryUnavailable).
        let gpuY: [Float]
        do {
            gpuY = try await dispatcher.dispatch(
                x: x, delta: delta, A: A, B: B, C: C, shape: shape)
        } catch BASMetalSSMScanDispatcherError.libraryUnavailable {
            print("QINAO-GATE metal_vs_cpu_ssm_scan_parity_mae: " +
                "SKIP (Metal unavailable on host — acceptable)")
            continue
        }
        // CPU authoritative reference
        let cpuY = try BASSSMScanCPUReference.scan(
            x: x, delta: delta, A: A, B: B, C: C, shape: shape)
        XCTAssertEqual(gpuY.count, cpuY.count)
        XCTAssertEqual(gpuY.count, bld)
        var maxErr: Float = 0
        var sumErr: Float = 0
        for i in 0..<gpuY.count {
            let err = abs(gpuY[i] - cpuY[i])
            maxErr = max(maxErr, err)
            sumErr += err
        }
        let mae = sumErr / Float(gpuY.count)
        worstMAE = max(worstMAE, mae)
        worstMaxErr = max(worstMaxErr, maxErr)
        XCTAssertLessThanOrEqual(mae, tightMAE,
            "RAISED BAR: GPU vs CPU MAE must be <= 1e-6 for shape " +
            "B=\(shape.B),L=\(shape.L),D=\(shape.D). " +
            "Got mae=\(mae),maxErr=\(maxErr)")
        XCTAssertLessThanOrEqual(maxErr, tightMaxErr,
            "RAISED BAR: per-element maxErr must be <= 1e-5 for " +
            "shape B=\(shape.B),L=\(shape.L),D=\(shape.D). " +
            "Got maxErr=\(maxErr)")
        ranAtLeastOne = true
    }
    guard ranAtLeastOne else {
        print("QINAO-GATE metal_vs_cpu_ssm_scan_parity_mae: " +
            "SKIP (no shape ran — Metal unavailable)")
        return
    }
    print("QINAO-GATE metal_vs_cpu_ssm_scan_parity_mae: PASS " +
        "\(shapes.count) shapes, worstMAE=\(worstMAE) <= " +
        "\(tightMAE), worstMaxErr=\(worstMaxErr) <= \(tightMaxErr)")
}

    func test_qinao_prompt_lookup_spec_token_identity() {
    // QINAO gate #15 — prompt-lookup speculative decode is BYTE-IDENTICAL to plain greedy.
    //
    // The decoder's identity property is STRUCTURAL: `BASPromptLookupDecoder.generate` only ever emits the
    // target model's own argmax (the accept-longest-prefix `while` + `for i in 0...acc` emit loop), so the
    // drafter can change ONLY the acceptance rate, never an emitted byte. That loop's correctness rests on the
    // exact contract of `BASPromptLookupDrafter.propose(over:)`: it returns a VERBATIM slice of the running
    // token sequence taken from the recurrence point — never a fabricated token. If that holds, verify-and-trim
    // can never accept a token the model wouldn't have produced; if it were violated, the decoder could emit a
    // non-greedy token. So the host-runnable byte-identity gate IS the source-of-truth slice contract.
    //
    // The full `generate` path is `#if canImport(MLXLLM)`-gated and needs a real `any LanguageModel` + MLX model
    // asset (absent on a Mac host) — see api_notes. This mirrors BASPromptLookupDrafterTests (the model-free
    // `propose` path) exactly, but RAISES THE BAR from a handful of hand-checked vectors to a 3960-case
    // deterministic randomized sweep asserting the slice contract with tolerance 0 (exact integer identity) over
    // every (ngramMin, ngramMax, K) the production decoder uses.

    // Deterministic LCG so the sweep is reproducible (plain local struct; no captured-var mutation).
    struct QINAORNG {
        var state: UInt64
        mutating func next(_ bound: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 33) % UInt64(bound))
        }
    }

    // Reference: independently recompute the prompt-lookup contract (longest-n-first, most-recent prior
    // occurrence, K-clamped verbatim continuation). Must match `propose` token-for-token.
    func expectedPropose(_ tokens: [Int], ngramMin: Int, ngramMax: Int, K: Int) -> [Int] {
        let count = tokens.count
        guard count >= 2 else { return [] }
        var n = min(ngramMax, count - 1)
        while n >= ngramMin {
            let needleStart = count - n
            var i = count - n - 1
            while i >= 0 {
                var k = 0
                var match = true
                while k < n { if tokens[i + k] != tokens[needleStart + k] { match = false; break }; k += 1 }
                if match {
                    let start = i + n
                    if start < count {
                        let end = min(start + K, count)
                        return Array(tokens[start..<end])
                    }
                }
                i -= 1
            }
            n -= 1
        }
        return []
    }

    var rng = QINAORNG(state: 0x51AB4D0C5EED5151)

    // Sweep the exact configs the production decoder uses (default ngramMin=1, ngramMax=3, K=4 plus neighbors)
    // over a SMALL alphabet so n-grams genuinely recur (the repetitive regime prompt-lookup targets).
    let configs: [(Int, Int, Int)] = [(1, 3, 4), (2, 2, 4), (1, 1, 1), (1, 3, 1), (2, 3, 8), (1, 4, 6)]
    let alphabetSizes = [2, 3, 5]
    let trialsPerCell = 220
    var totalCases = 0

    for (ngramMin, ngramMax, K) in configs {
        let drafter = BASPromptLookupDrafter(ngramMin: ngramMin, ngramMax: ngramMax, numDraftTokens: K)
        for alpha in alphabetSizes {
            for _ in 0..<trialsPerCell {
                let len = rng.next(40)                                   // 0..39 incl. too-short edge cases
                var seq = [Int]()
                seq.reserveCapacity(len)
                for _ in 0..<len { seq.append(rng.next(alpha)) }

                let got = drafter.propose(over: seq)
                let want = expectedPropose(seq, ngramMin: ngramMin, ngramMax: ngramMax, K: K)

                // RAISED BAR vs the existing per-vector tests: tolerance 0, full token-sequence identity.
                XCTAssertEqual(got, want,
                    "propose must be a verbatim K-clamped slice (cfg \(ngramMin)/\(ngramMax)/\(K), seq \(seq))")

                // Decoder byte-identity precondition: EVERY proposed token must literally appear, contiguously,
                // in the running sequence (a fabricated token would break greedy-identity).
                if !got.isEmpty {
                    var foundContiguous = false
                    if got.count <= seq.count {
                        var s = 0
                        while s + got.count <= seq.count {
                            if Array(seq[s..<s + got.count]) == got { foundContiguous = true; break }
                            s += 1
                        }
                    }
                    XCTAssertTrue(foundContiguous,
                        "proposed draft must be a verbatim contiguous slice of the sequence (cfg \(ngramMin)/\(ngramMax)/\(K))")
                    XCTAssertLessThanOrEqual(got.count, K, "draft length must never exceed K")
                }
                totalCases += 1
            }
        }
    }

    XCTAssertEqual(totalCases, configs.count * alphabetSizes.count * trialsPerCell,
        "the full deterministic sweep must have executed")
    // HONEST SCOPE (audit 2026-06-24): this proves BASPromptLookupDrafter.propose ALWAYS returns a verbatim
    // K-clamped contiguous slice — a NECESSARY (not sufficient) condition for greedy byte-identity. The full
    // verify/accept/emit loop in BASPromptLookupDecoder.generate is MLXLLM-gated and is NOT host-run here.
    print("QINAO-GATE prompt_lookup_spec_token_identity: PASS (\(totalCases) cases, tolerance 0; real BASPromptLookupDrafter.propose always returns a verbatim K-clamped slice — NECESSARY condition for greedy identity; full emit loop is MLXLLM-gated, not host-run)")
}
}
#endif
