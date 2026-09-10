// MARK: - BASPlasticitySTDPTests
// chapter 四百五十七 / M1206 PROOF tests
//
// Verifies the 4th plasticity rule shipped in
// chapter 457 — Spike-Timing-Dependent Plasticity:
//   - BASPlasticitySTDPParams construction + clamping
//   - .stdpTemporal rule:
//     * Δt > 0 → LTP (positive weight delta)
//     * Δt < 0 → LTD (negative weight delta)
//     * Δt = 0 → zero weight delta
//     * Exponential decay (larger |Δt| → smaller |ΔW|)
//     * Asymmetric A_+ / A_- biases potentiation /
//       depression
//     * Asymmetric τ_+ / τ_- widens one window vs other
//   - Updated bundle carries timingDelta + stdpAmplitude
//   - Non-STDP rules ignore timingDelta (Hebbian /
//     antiHebbian / outcomeModulated unaffected)
//   - BASBiomimeticTurnObserver routes timingDelta into
//     plasticity fold under .stdpTemporal rule
//   - Backward-compat Codable round-trip of shape
//     missing stdpParams field defaults to canonical
//     Bi & Poo values

import XCTest
@testable import BASMetalSubstrate

final class BASPlasticitySTDPTests: XCTestCase {

    // MARK: - BASPlasticitySTDPParams clamping

    func testSTDPParamsDefaultsCanonical() {
        let p = BASPlasticitySTDPParams()
        XCTAssertEqual(p.aPlus, 1.0)
        XCTAssertEqual(p.aMinus, 1.0)
        XCTAssertEqual(p.tauPlus, 20.0)
        XCTAssertEqual(p.tauMinus, 20.0)
    }

    func testSTDPParamsClampsAmplitudesNonNegative() {
        let p = BASPlasticitySTDPParams(
            aPlus: -1.0,
            aMinus: -2.0,
            tauPlus: 10.0,
            tauMinus: 15.0)
        XCTAssertEqual(p.aPlus, 0)
        XCTAssertEqual(p.aMinus, 0)
        XCTAssertEqual(p.tauPlus, 10.0)
        XCTAssertEqual(p.tauMinus, 15.0)
    }

    func testSTDPParamsClampsTauPositive() {
        let p = BASPlasticitySTDPParams(
            aPlus: 1.0, aMinus: 1.0,
            tauPlus: -1.0, tauMinus: 0.0)
        XCTAssertGreaterThan(p.tauPlus, 0)
        XCTAssertGreaterThan(p.tauMinus, 0)
    }

    // MARK: - Rule enum 4 cases

    func testRuleEnumAllCasesIncludesSTDP() {
        XCTAssertTrue(BASPlasticityRule.allCases
            .contains(.stdpTemporal))
        XCTAssertEqual(
            BASPlasticityRule.stdpTemporal.rawValue,
            "stdp-temporal")
    }

    // MARK: - LTP: Δt > 0 → positive ΔW

    func testSTDPPositiveDeltaProducesLTP() async throws
    {
        let shape = BASPlasticityFoldShape(
            preDim: 2, postDim: 2,
            learningRate: 1.0,
            rule: .stdpTemporal,
            stdpParams: BASPlasticitySTDPParams(
                aPlus: 1.0, aMinus: 1.0,
                tauPlus: 20.0, tauMinus: 20.0))
        let fold = BASPlasticityFold(shape: shape)
        let result = try await fold.apply(
            pre: [1.0, 0.0],
            post: [0.0, 1.0],
            timingDelta: 10.0)  // Δt > 0 → LTP
        // amplitude = 1.0 * exp(-10/20) = exp(-0.5) ≈ 0.6065
        let expectedAmplitude: Float =
            1.0 * Foundation.expf(-10.0 / 20.0)
        XCTAssertEqual(
            result.stdpAmplitude,
            expectedAmplitude,
            accuracy: 1e-5)
        XCTAssertEqual(result.timingDelta, 10.0)
        // Δ[0,1] = scale * pre[0] * post[1] =
        //   learningRate * amplitude * 1.0 * 1.0
        XCTAssertEqual(
            result.weightDelta[0 * 2 + 1],
            expectedAmplitude,
            accuracy: 1e-5)
        XCTAssertGreaterThan(
            result.weightDelta[0 * 2 + 1], 0,
            "Δt > 0 with positive (pre × post) → LTP" +
            " (positive ΔW)")
    }

    // MARK: - LTD: Δt < 0 → negative ΔW

    func testSTDPNegativeDeltaProducesLTD() async throws
    {
        let shape = BASPlasticityFoldShape(
            preDim: 2, postDim: 2,
            learningRate: 1.0,
            rule: .stdpTemporal,
            stdpParams: BASPlasticitySTDPParams())
        let fold = BASPlasticityFold(shape: shape)
        let result = try await fold.apply(
            pre: [1.0, 0.0],
            post: [0.0, 1.0],
            timingDelta: -10.0)  // Δt < 0 → LTD
        // amplitude = -1.0 * exp(-10/20) ≈ -0.6065
        let expectedAmplitude: Float =
            -1.0 * Foundation.expf(-10.0 / 20.0)
        XCTAssertEqual(
            result.stdpAmplitude,
            expectedAmplitude,
            accuracy: 1e-5)
        XCTAssertLessThan(
            result.stdpAmplitude, 0,
            "Δt < 0 → STDP amplitude must be negative")
        XCTAssertLessThan(
            result.weightDelta[0 * 2 + 1], 0,
            "Δt < 0 with positive (pre × post) → LTD" +
            " (negative ΔW)")
    }

    // MARK: - Δt = 0 → no learning

    func testSTDPZeroDeltaProducesNoChange() async throws
    {
        let shape = BASPlasticityFoldShape(
            preDim: 2, postDim: 2,
            learningRate: 1.0,
            rule: .stdpTemporal,
            stdpParams: BASPlasticitySTDPParams())
        let fold = BASPlasticityFold(shape: shape)
        let result = try await fold.apply(
            pre: [1.0, 1.0],
            post: [1.0, 1.0],
            timingDelta: 0.0)
        XCTAssertEqual(result.stdpAmplitude, 0)
        for d in result.weightDelta {
            XCTAssertEqual(d, 0, accuracy: 1e-7,
                "Δt = 0 → no causal info → zero ΔW")
        }
        let weights = await fold.currentWeightsSnapshot()
        XCTAssertEqual(weights, [0, 0, 0, 0])
    }

    // MARK: - Exponential decay

    func testSTDPExponentialDecayLargerDeltaSmallerMagnitude()
        async throws
    {
        // Two folds:identical shape,different |Δt|。
        // Larger |Δt| must produce SMALLER |amplitude|。
        let shape = BASPlasticityFoldShape(
            preDim: 1, postDim: 1,
            learningRate: 1.0,
            rule: .stdpTemporal,
            stdpParams: BASPlasticitySTDPParams(
                aPlus: 1.0, aMinus: 1.0,
                tauPlus: 20.0, tauMinus: 20.0))
        let foldA = BASPlasticityFold(shape: shape)
        let foldB = BASPlasticityFold(shape: shape)
        let resultSmall = try await foldA.apply(
            pre: [1.0], post: [1.0],
            timingDelta: 5.0)
        let resultLarge = try await foldB.apply(
            pre: [1.0], post: [1.0],
            timingDelta: 100.0)
        XCTAssertGreaterThan(
            resultSmall.stdpAmplitude,
            resultLarge.stdpAmplitude,
            "smaller |Δt| → larger amplitude per" +
            " exponential decay")
        XCTAssertGreaterThan(
            resultSmall.weightDelta[0],
            resultLarge.weightDelta[0],
            "smaller |Δt| → larger ΔW")
        // Sanity:both still positive (LTP regime)
        XCTAssertGreaterThan(
            resultLarge.stdpAmplitude, 0)
    }

    // MARK: - Asymmetric A_+ / A_-

    func testSTDPAsymmetricAmplitudesBiasLearning()
        async throws
    {
        // A_+ = 2.0,A_- = 0.5 → potentiation
        // 4× stronger than depression at same |Δt|。
        let shape = BASPlasticityFoldShape(
            preDim: 1, postDim: 1,
            learningRate: 1.0,
            rule: .stdpTemporal,
            stdpParams: BASPlasticitySTDPParams(
                aPlus: 2.0, aMinus: 0.5,
                tauPlus: 20.0, tauMinus: 20.0))
        let foldLTP = BASPlasticityFold(shape: shape)
        let foldLTD = BASPlasticityFold(shape: shape)
        let ltp = try await foldLTP.apply(
            pre: [1.0], post: [1.0],
            timingDelta: 10.0)
        let ltd = try await foldLTD.apply(
            pre: [1.0], post: [1.0],
            timingDelta: -10.0)
        // |amplitude_LTP| / |amplitude_LTD| should
        // ≈ A_+ / A_- = 4×
        let ratio = ltp.stdpAmplitude
            / (-ltd.stdpAmplitude)
        XCTAssertEqual(ratio, 4.0, accuracy: 1e-5)
    }

    func testSTDPAsymmetricTauWidensWindow() async throws
    {
        // τ_+ = 20,τ_- = 5 → LTP window 4× wider。 At
        // |Δt| = 20:
        //   amplitude_LTP = 1.0 * exp(-20/20) = exp(-1) ≈ 0.368
        //   amplitude_LTD = -1.0 * exp(-20/5)  = -exp(-4) ≈ -0.0183
        // → |LTP amplitude| ≈ 20× |LTD amplitude|
        let shape = BASPlasticityFoldShape(
            preDim: 1, postDim: 1,
            learningRate: 1.0,
            rule: .stdpTemporal,
            stdpParams: BASPlasticitySTDPParams(
                aPlus: 1.0, aMinus: 1.0,
                tauPlus: 20.0, tauMinus: 5.0))
        let foldLTP = BASPlasticityFold(shape: shape)
        let foldLTD = BASPlasticityFold(shape: shape)
        let ltp = try await foldLTP.apply(
            pre: [1.0], post: [1.0],
            timingDelta: 20.0)
        let ltd = try await foldLTD.apply(
            pre: [1.0], post: [1.0],
            timingDelta: -20.0)
        let ratio = ltp.stdpAmplitude
            / (-ltd.stdpAmplitude)
        XCTAssertGreaterThan(ratio, 15.0,
            "wider τ_+ relative to τ_- must inflate" +
            " LTP amplitude vs LTD at same |Δt|")
    }

    // MARK: - Non-STDP rules ignore timingDelta

    func testHebbianIgnoresTimingDelta() async throws {
        let shape = BASPlasticityFoldShape(
            preDim: 1, postDim: 1,
            learningRate: 1.0,
            rule: .hebbian)
        let foldA = BASPlasticityFold(shape: shape)
        let foldB = BASPlasticityFold(shape: shape)
        let resultNoDelta = try await foldA.apply(
            pre: [2.0], post: [3.0])
        let resultWithDelta = try await foldB.apply(
            pre: [2.0], post: [3.0],
            timingDelta: 99.0)
        XCTAssertEqual(
            resultNoDelta.weightDelta,
            resultWithDelta.weightDelta,
            "hebbian rule must produce identical ΔW" +
            " regardless of timingDelta")
        XCTAssertEqual(
            resultWithDelta.stdpAmplitude, 0,
            "non-STDP rules must record zero stdpAmplitude")
        XCTAssertEqual(
            resultWithDelta.timingDelta, 99.0,
            "timingDelta still recorded into bundle" +
            " for audit even when rule ignores it")
    }

    // MARK: - Observer routing

    func testObserverRoutesTimingDeltaIntoFold()
        async throws
    {
        let shape = BASPlasticityFoldShape(
            preDim: 1, postDim: 1,
            learningRate: 1.0,
            rule: .stdpTemporal,
            stdpParams: BASPlasticitySTDPParams())
        let fold = BASPlasticityFold(shape: shape)
        let observer = BASBiomimeticTurnObserver(
            plasticity: fold)
        let signal = BASBiomimeticTurnSignal(
            plasticityPre: [1.0],
            plasticityPost: [1.0],
            plasticityTimingDelta: 10.0)
        let obs = try await observer.observe(signal)
        XCTAssertNotNil(obs.plasticity)
        XCTAssertEqual(
            obs.plasticity?.timingDelta, 10.0,
            "observer must propagate timingDelta into" +
            " plasticity.apply")
        XCTAssertGreaterThan(
            obs.plasticity?.stdpAmplitude ?? 0, 0,
            "Δt = 10 (LTP regime) → positive amplitude")
    }

    func testSignalDefaultTimingDeltaZero() {
        let signal = BASBiomimeticTurnSignal(
            plasticityPre: [1.0],
            plasticityPost: [1.0])
        XCTAssertEqual(
            signal.plasticityTimingDelta, 0,
            "default timingDelta must be 0 (safe for" +
            " non-STDP rules)")
    }

    // MARK: - Shape Codable backward-compat

    func testShapeCodableRoundTripWithSTDPParams()
        throws
    {
        let shape = BASPlasticityFoldShape(
            preDim: 3, postDim: 4,
            learningRate: 0.5,
            rule: .stdpTemporal,
            stdpParams: BASPlasticitySTDPParams(
                aPlus: 1.5, aMinus: 0.5,
                tauPlus: 25.0, tauMinus: 15.0))
        let data = try JSONEncoder().encode(shape)
        let decoded = try JSONDecoder()
            .decode(
                BASPlasticityFoldShape.self,
                from: data)
        XCTAssertEqual(decoded, shape)
        XCTAssertEqual(decoded.stdpParams.aPlus, 1.5)
        XCTAssertEqual(decoded.stdpParams.aMinus, 0.5)
        XCTAssertEqual(decoded.stdpParams.tauPlus, 25.0)
        XCTAssertEqual(decoded.stdpParams.tauMinus, 15.0)
    }

    func testShapeCodableBackwardCompatDefaultsSTDP()
        throws
    {
        // Simulate a pre-chapter-457 encoded shape JSON
        // (no stdpParams key)。 Decoder must fall back
        // to canonical Bi & Poo defaults。
        let legacyJSON = """
        {
            "preDim": 2,
            "postDim": 3,
            "learningRate": 0.1,
            "rule": "hebbian"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder()
            .decode(
                BASPlasticityFoldShape.self,
                from: legacyJSON)
        XCTAssertEqual(decoded.preDim, 2)
        XCTAssertEqual(decoded.postDim, 3)
        XCTAssertEqual(decoded.learningRate, 0.1)
        XCTAssertEqual(decoded.rule, .hebbian)
        XCTAssertEqual(decoded.stdpParams.aPlus, 1.0,
            "legacy snapshot must default to canonical" +
            " Bi & Poo A_+ = 1.0")
        XCTAssertEqual(decoded.stdpParams.tauPlus, 20.0,
            "legacy snapshot must default to canonical" +
            " Bi & Poo τ_+ = 20.0")
    }

    // MARK: - Snapshot round-trip preserves STDP state

    func testSnapshotPreservesSTDPShape() async throws {
        let shape = BASPlasticityFoldShape(
            preDim: 1, postDim: 1,
            learningRate: 0.5,
            rule: .stdpTemporal,
            stdpParams: BASPlasticitySTDPParams(
                aPlus: 2.0, aMinus: 0.8,
                tauPlus: 18.0, tauMinus: 22.0))
        let fold = BASPlasticityFold(shape: shape)
        _ = try await fold.apply(
            pre: [1.0], post: [1.0],
            timingDelta: 10.0)
        let snap = await fold.exportSnapshot()
        XCTAssertEqual(snap.shape.rule, .stdpTemporal)
        XCTAssertEqual(snap.shape.stdpParams.aPlus, 2.0)
        XCTAssertEqual(
            snap.shape.stdpParams.tauMinus, 22.0)
        // Codable round-trip
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder()
            .decode(
                BASPlasticitySnapshot.self,
                from: data)
        XCTAssertEqual(decoded, snap)
        // Restore onto fresh fold
        let foldB = BASPlasticityFold(shape: shape)
        try await foldB.importSnapshot(decoded)
        let weightsA = await fold.currentWeightsSnapshot()
        let weightsB = await foldB
            .currentWeightsSnapshot()
        XCTAssertEqual(weightsA, weightsB)
    }
}
