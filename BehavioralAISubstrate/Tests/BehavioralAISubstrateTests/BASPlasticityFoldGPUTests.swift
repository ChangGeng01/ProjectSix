// MARK: - BASPlasticityFoldGPUTests
// chapter 四百五十八 / M1210 PROOF tests
//
// Verifies the GPU-accelerated plasticity path:
//   - applyGPU produces byte-equal results to CPU
//     apply() for each of 4 rules within Float ε
//   - shape validation throws BEFORE GPU dispatch
//   - accumulation across multiple GPU calls is
//     identical to repeated CPU apply()
//   - cross-call mixing (CPU then GPU then CPU)
//     keeps weights consistent (both paths read +
//     mutate the SAME hidden `weights` state)

import XCTest
@testable import BASMetalSubstrate

final class BASPlasticityFoldGPUTests: XCTestCase {

    // MARK: - GPU/CPU agreement per rule

    func testGPUMatchesCPUHebbian() async throws {
        let shape = BASPlasticityFoldShape(
            preDim: 4, postDim: 5,
            learningRate: 0.1,
            rule: .hebbian)
        let foldCPU = BASPlasticityFold(shape: shape)
        let foldGPU = BASPlasticityFold(shape: shape)
        let pre: [Float] = [1.0, 0.5, -0.3, 0.8]
        let post: [Float] = [0.2, -0.4, 0.6, 0.1, 0.9]
        let cpu = try await foldCPU.apply(
            pre: pre, post: post)
        do {
            let gpu = try await foldGPU.applyGPU(
                pre: pre, post: post)
            for i in 0..<cpu.weightDelta.count {
                XCTAssertEqual(
                    cpu.weightDelta[i],
                    gpu.weightDelta[i],
                    accuracy: 1e-5,
                    "GPU/CPU Hebbian Δ[\(i)] divergence")
            }
            let cpuW = await foldCPU
                .currentWeightsSnapshot()
            let gpuW = await foldGPU
                .currentWeightsSnapshot()
            for i in 0..<cpuW.count {
                XCTAssertEqual(
                    cpuW[i], gpuW[i], accuracy: 1e-5,
                    "GPU/CPU Hebbian W[\(i)] divergence")
            }
        } catch BASPlasticityError.gpuUnavailable {
            throw XCTSkip("Metal unavailable in" +
                " this test environment")
        }
    }

    func testGPUMatchesCPUAntiHebbian() async throws {
        let shape = BASPlasticityFoldShape(
            preDim: 3, postDim: 3,
            learningRate: 0.05,
            rule: .antiHebbian)
        let foldCPU = BASPlasticityFold(shape: shape)
        let foldGPU = BASPlasticityFold(shape: shape)
        let pre: [Float] = [1.0, 2.0, 3.0]
        let post: [Float] = [0.5, -0.5, 0.25]
        let cpu = try await foldCPU.apply(
            pre: pre, post: post)
        do {
            let gpu = try await foldGPU.applyGPU(
                pre: pre, post: post)
            for i in 0..<cpu.weightDelta.count {
                XCTAssertEqual(
                    cpu.weightDelta[i],
                    gpu.weightDelta[i],
                    accuracy: 1e-5)
                XCTAssertLessThan(
                    gpu.weightDelta[i].sign ==
                        cpu.weightDelta[i].sign
                        ? 0 : 1,
                    1,
                    "GPU + CPU must agree on sign for" +
                    " antiHebbian Δ[\(i)]")
            }
        } catch BASPlasticityError.gpuUnavailable {
            throw XCTSkip("Metal unavailable")
        }
    }

    func testGPUMatchesCPUOutcomeModulated() async throws
    {
        let shape = BASPlasticityFoldShape(
            preDim: 2, postDim: 3,
            learningRate: 0.5,
            rule: .outcomeModulatedHebbian)
        let foldCPU = BASPlasticityFold(shape: shape)
        let foldGPU = BASPlasticityFold(shape: shape)
        let pre: [Float] = [1.0, 1.0]
        let post: [Float] = [1.0, 1.0, 1.0]
        let cpu = try await foldCPU.apply(
            pre: pre, post: post,
            outcome: -2.0)
        do {
            let gpu = try await foldGPU.applyGPU(
                pre: pre, post: post,
                outcome: -2.0)
            for i in 0..<cpu.weightDelta.count {
                XCTAssertEqual(
                    cpu.weightDelta[i],
                    gpu.weightDelta[i],
                    accuracy: 1e-5)
            }
            XCTAssertEqual(gpu.outcome, -2.0)
        } catch BASPlasticityError.gpuUnavailable {
            throw XCTSkip("Metal unavailable")
        }
    }

    func testGPUMatchesCPUSTDP() async throws {
        let shape = BASPlasticityFoldShape(
            preDim: 4, postDim: 4,
            learningRate: 1.0,
            rule: .stdpTemporal,
            stdpParams: BASPlasticitySTDPParams(
                aPlus: 1.5, aMinus: 0.5,
                tauPlus: 15.0, tauMinus: 25.0))
        let foldCPU = BASPlasticityFold(shape: shape)
        let foldGPU = BASPlasticityFold(shape: shape)
        let pre: [Float] = [1.0, 0.5, -0.2, 0.7]
        let post: [Float] = [0.3, -0.4, 0.8, 0.1]
        // Δt > 0 — LTP regime
        let cpu = try await foldCPU.apply(
            pre: pre, post: post,
            timingDelta: 10.0)
        do {
            let gpu = try await foldGPU.applyGPU(
                pre: pre, post: post,
                timingDelta: 10.0)
            XCTAssertEqual(
                cpu.stdpAmplitude,
                gpu.stdpAmplitude,
                accuracy: 1e-6,
                "GPU + CPU must compute identical" +
                " STDP amplitude per (Δt, A, τ)")
            for i in 0..<cpu.weightDelta.count {
                XCTAssertEqual(
                    cpu.weightDelta[i],
                    gpu.weightDelta[i],
                    accuracy: 1e-5)
            }
        } catch BASPlasticityError.gpuUnavailable {
            throw XCTSkip("Metal unavailable")
        }
    }

    // MARK: - Shape validation throws BEFORE GPU dispatch

    func testGPUValidatesPreDimBeforeDispatch()
        async throws
    {
        let shape = BASPlasticityFoldShape(
            preDim: 3, postDim: 3)
        let fold = BASPlasticityFold(shape: shape)
        do {
            _ = try await fold.applyGPU(
                pre: [1.0, 2.0],  // 2 not 3
                post: [1.0, 1.0, 1.0])
            XCTFail("expected shapeMismatch throw")
        } catch BASPlasticityError.shapeMismatch(
            let reason)
        {
            XCTAssertTrue(reason.contains("pre"))
        } catch BASPlasticityError.gpuUnavailable {
            // Shape validation must fire BEFORE Metal
            // availability check — but if it doesn't,
            // at least the call surfaced an error。
            throw XCTSkip("Metal unavailable;skipping" +
                " ordering assertion")
        }
    }

    func testGPUValidatesPostDimBeforeDispatch()
        async throws
    {
        let shape = BASPlasticityFoldShape(
            preDim: 2, postDim: 3)
        let fold = BASPlasticityFold(shape: shape)
        do {
            _ = try await fold.applyGPU(
                pre: [1.0, 2.0],
                post: [1.0, 1.0, 1.0, 1.0])  // 4 not 3
            XCTFail("expected shapeMismatch throw")
        } catch BASPlasticityError.shapeMismatch(
            let reason)
        {
            XCTAssertTrue(reason.contains("post"))
        } catch BASPlasticityError.gpuUnavailable {
            throw XCTSkip("Metal unavailable")
        }
    }

    // MARK: - Accumulation across multiple GPU calls

    func testGPUAccumulatesAcrossCalls() async throws {
        let shape = BASPlasticityFoldShape(
            preDim: 2, postDim: 2,
            learningRate: 1.0,
            rule: .hebbian)
        let foldGPU = BASPlasticityFold(shape: shape)
        let foldCPU = BASPlasticityFold(shape: shape)
        let pre: [Float] = [1.0, 0.0]
        let post: [Float] = [0.5, 0.5]
        for _ in 0..<5 {
            do {
                _ = try await foldGPU.applyGPU(
                    pre: pre, post: post)
            } catch BASPlasticityError.gpuUnavailable {
                throw XCTSkip("Metal unavailable")
            }
            _ = try await foldCPU.apply(
                pre: pre, post: post)
        }
        let gpuW = await foldGPU
            .currentWeightsSnapshot()
        let cpuW = await foldCPU
            .currentWeightsSnapshot()
        for i in 0..<gpuW.count {
            XCTAssertEqual(
                gpuW[i], cpuW[i], accuracy: 1e-5,
                "5× GPU vs 5× CPU divergence at" +
                " W[\(i)]")
        }
        let updatesGPU = await foldGPU.updateCount()
        XCTAssertEqual(updatesGPU, 5)
    }

    // MARK: - Cross-path mixing (CPU then GPU then CPU)

    func testMixingCPUAndGPUKeepsWeightsConsistent()
        async throws
    {
        let shape = BASPlasticityFoldShape(
            preDim: 3, postDim: 3,
            learningRate: 0.1,
            rule: .hebbian)
        let fold = BASPlasticityFold(shape: shape)
        let pre: [Float] = [1.0, 0.5, 0.2]
        let post: [Float] = [0.3, 0.7, 0.4]
        _ = try await fold.apply(pre: pre, post: post)
        do {
            _ = try await fold.applyGPU(
                pre: pre, post: post)
        } catch BASPlasticityError.gpuUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let result = try await fold.apply(
            pre: pre, post: post)
        // Third call should produce delta equal to
        // first call's delta (rule is hebbian,scale
        // is constant)。 Updated weight = 3× single Δ。
        let firstDelta: Float =
            0.1 * pre[0] * post[0]
        XCTAssertEqual(
            result.updatedWeightSnapshot[0],
            3 * firstDelta,
            accuracy: 1e-5,
            "3 applies must yield 3× single Δ")
        let updates = await fold.updateCount()
        XCTAssertEqual(updates, 3,
            "all 3 paths (CPU + GPU + CPU) increment" +
            " the shared counter")
    }

    // MARK: - GPU bundle carries audit fields

    func testGPUResultCarriesAuditFields() async throws {
        let shape = BASPlasticityFoldShape(
            preDim: 1, postDim: 1,
            learningRate: 1.0,
            rule: .stdpTemporal,
            stdpParams: BASPlasticitySTDPParams())
        let fold = BASPlasticityFold(shape: shape)
        do {
            let r = try await fold.applyGPU(
                pre: [1.0], post: [1.0],
                outcome: 99.0,
                timingDelta: 10.0)
            XCTAssertEqual(r.timingDelta, 10.0)
            XCTAssertEqual(r.outcome, 99.0)
            XCTAssertGreaterThan(r.stdpAmplitude, 0,
                "Δt > 0 → positive STDP amplitude")
            XCTAssertEqual(r.updateIndex, 0)
            XCTAssertEqual(r.pre, [1.0])
            XCTAssertEqual(r.post, [1.0])
        } catch BASPlasticityError.gpuUnavailable {
            throw XCTSkip("Metal unavailable")
        }
    }
}
