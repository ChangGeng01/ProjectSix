// MARK: - BASPredictiveCodingProbeTests
// chapter 四百五十二 / M1186 — POST-SWEEP BIOMIMETIC

import XCTest
import Foundation
@testable import BASMetalSubstrate

/// PROOF tests for the M1185 BASPredictiveCodingProbe
/// actor — substrate's first **closed-loop adaptive**
/// primitive。 Validates:
///
///   - Construction + initial prediction state
///   - Single observation produces correct error +
///     updated prediction per μ ← μ + α · ε
///   - Running MSE accumulates correctly across
///     observations
///   - Repeated observation of CONSTANT signal causes
///     prediction to CONVERGE on the signal (closed-
///     loop adaptation property)
///   - Distribution shift causes MSE to RISE then
///     decline as model recalibrates (adaptation signal
///     property)
///   - Learning rate 0 freezes prediction;learning
///     rate 1 snaps prediction fully to observation
///   - reset() restores initial state
///   - Shape mismatch throws
final class BASPredictiveCodingProbeTests:
    XCTestCase
{

    // MARK: - Construction + initial state

    func testConstructionUsesInitialPrediction() async {
        let shape = BASPredictiveCodingProbeShape(
            dim: 3,
            learningRate: 0.1,
            initialPrediction: [1.0, 2.0, 3.0])
        let probe = BASPredictiveCodingProbe(
            shape: shape)
        let initial =
            await probe.currentPredictionSnapshot()
        XCTAssertEqual(initial, [1.0, 2.0, 3.0])
        let count = await probe.observationCount()
        XCTAssertEqual(count, 0)
        let mse = await probe.runningMSE()
        XCTAssertEqual(mse, 0,
            "MSE is 0 before any observation")
    }

    func testEmptyInitialPredictionDefaultsToZeros() async {
        let shape = BASPredictiveCodingProbeShape(
            dim: 4)  // empty initialPrediction → zeros
        let probe = BASPredictiveCodingProbe(
            shape: shape)
        let initial =
            await probe.currentPredictionSnapshot()
        XCTAssertEqual(initial, [0, 0, 0, 0])
    }

    func testShapeClampsLearningRateAndDim() async {
        let shape = BASPredictiveCodingProbeShape(
            dim: -3, learningRate: 2.5)
        XCTAssertEqual(shape.dim, 1,
            "dim must clamp to >= 1")
        XCTAssertEqual(shape.learningRate, 1.0,
            "learningRate must clamp to <= 1.0")
    }

    // MARK: - Single observation correctness

    /// observed = [4, 5, 6], μ = [1, 2, 3], α = 0.5
    /// error = [3, 3, 3]
    /// μ' = [1 + 0.5*3, 2 + 0.5*3, 3 + 0.5*3]
    ///    = [2.5, 3.5, 4.5]
    /// per-obs squared error sum = 9 + 9 + 9 = 27
    /// MSE = 27 / 3 = 9
    func testSingleObservationCanonical() async throws {
        let shape = BASPredictiveCodingProbeShape(
            dim: 3,
            learningRate: 0.5,
            initialPrediction: [1.0, 2.0, 3.0])
        let probe = BASPredictiveCodingProbe(
            shape: shape)
        let result = try await probe.observe(
            [4.0, 5.0, 6.0])
        XCTAssertEqual(result.observed,
            [4.0, 5.0, 6.0])
        XCTAssertEqual(result.priorPrediction,
            [1.0, 2.0, 3.0])
        XCTAssertEqual(result.error,
            [3.0, 3.0, 3.0])
        XCTAssertEqual(result.updatedPrediction,
            [2.5, 3.5, 4.5])
        XCTAssertEqual(result.runningMSE, 9.0,
            accuracy: 1e-5)
        XCTAssertEqual(result.observationIndex, 0)
        // Actor state mutated
        let after =
            await probe.currentPredictionSnapshot()
        XCTAssertEqual(after, [2.5, 3.5, 4.5])
    }

    // MARK: - Closed-loop convergence (THE biomimetic proof)

    /// **CLOSED-LOOP ADAPTATION PROOF**:repeatedly
    /// observing the same constant signal must drive
    /// the prediction TO converge on the signal。 This
    /// is the bedrock predictive-coding property —
    /// model adapts to its observations。
    func testRepeatedObservationConvergesOnSignal() async throws {
        let shape = BASPredictiveCodingProbeShape(
            dim: 2,
            learningRate: 0.3,
            initialPrediction: [0.0, 0.0])
        let probe = BASPredictiveCodingProbe(
            shape: shape)
        let constantSignal: [Float] = [5.0, 10.0]
        // Observe 50 times
        var lastResult:
            BASPredictiveCodingObservation? = nil
        for _ in 0..<50 {
            lastResult = try await probe.observe(
                constantSignal)
        }
        let finalPrediction =
            await probe.currentPredictionSnapshot()
        // After 50 observations with α=0.3,prediction
        // should be VERY close to the signal
        XCTAssertEqual(
            finalPrediction[0], 5.0, accuracy: 0.01,
            "prediction[0] must converge on signal[0]" +
            " after 50 observations")
        XCTAssertEqual(
            finalPrediction[1], 10.0, accuracy: 0.01,
            "prediction[1] must converge on signal[1]")
        // Final error should be near zero
        XCTAssertLessThan(
            abs(lastResult!.error[0]), 0.05,
            "final error must shrink to near zero" +
            " (closed-loop convergence proof)")
    }

    /// **ADAPTATION SIGNAL PROOF**:running MSE must
    /// DECREASE as prediction converges。 Larger error
    /// early,smaller error late → MSE trends down。
    func testRunningMSEDecreasesAsPredictionConverges() async throws {
        let shape = BASPredictiveCodingProbeShape(
            dim: 1,
            learningRate: 0.4,
            initialPrediction: [0.0])
        let probe = BASPredictiveCodingProbe(
            shape: shape)
        // Observe constant 10 thirty times
        var mseHistory: [Float] = []
        for _ in 0..<30 {
            let r = try await probe.observe([10.0])
            mseHistory.append(r.runningMSE)
        }
        // MSE at obs 0 = (10-0)^2 = 100。
        // MSE later should be much smaller (running
        // mean over many small errors)。
        let mseEarly = mseHistory[0]
        let mseLate = mseHistory.last!
        XCTAssertGreaterThan(mseEarly, mseLate,
            "MSE must decrease as prediction adapts" +
            " (early=\(mseEarly), late=\(mseLate))")
    }

    // MARK: - Learning rate boundary behavior

    /// Learning rate = 0 → prediction frozen,no
    /// adaptation。 MSE accumulates but prediction
    /// never changes。
    func testZeroLearningRateFreezesPrediction() async throws {
        let shape = BASPredictiveCodingProbeShape(
            dim: 1,
            learningRate: 0.0,
            initialPrediction: [3.0])
        let probe = BASPredictiveCodingProbe(
            shape: shape)
        // Hammer with observations far from 3.0
        for _ in 0..<10 {
            _ = try await probe.observe([99.0])
        }
        let frozen =
            await probe.currentPredictionSnapshot()
        XCTAssertEqual(
            frozen[0], 3.0,
            "α=0 must freeze prediction at initial" +
            " value regardless of observations")
        // But running MSE should still accumulate
        let mse = await probe.runningMSE()
        XCTAssertEqual(mse, 96.0 * 96.0, accuracy: 0.1,
            "MSE per-obs = (99-3)^2 / 1 = 9216;" +
            " running MSE = same since all obs identical")
    }

    /// Learning rate = 1 → prediction snaps fully to
    /// observation in 1 step。
    func testFullLearningRateSnapsToObservation() async throws {
        let shape = BASPredictiveCodingProbeShape(
            dim: 1,
            learningRate: 1.0,
            initialPrediction: [0.0])
        let probe = BASPredictiveCodingProbe(
            shape: shape)
        _ = try await probe.observe([7.5])
        let snapped =
            await probe.currentPredictionSnapshot()
        XCTAssertEqual(snapped[0], 7.5,
            "α=1 must snap prediction fully to" +
            " observation (μ' = μ + 1·(obs-μ) = obs)")
    }

    // MARK: - Distribution shift → MSE rises

    /// **ADAPTATION TO SHIFTING DISTRIBUTION**:
    /// observe constant A,probe converges → MSE low。
    /// Then observe constant B (different):probe's
    /// FIRST observation of B gives large error,then
    /// the running-MSE eventually shrinks as probe
    /// recalibrates to B。 This is the substrate
    /// reacting to a distribution shift via the
    /// adaptation signal。
    func testDistributionShiftReflectsInError() async throws {
        let shape = BASPredictiveCodingProbeShape(
            dim: 1,
            learningRate: 0.3,
            initialPrediction: [0.0])
        let probe = BASPredictiveCodingProbe(
            shape: shape)
        // Phase 1:converge on signal A=5
        for _ in 0..<20 {
            _ = try await probe.observe([5.0])
        }
        let predAfterA =
            await probe.currentPredictionSnapshot()
        XCTAssertEqual(
            predAfterA[0], 5.0, accuracy: 0.05)
        // Now shift the distribution:observe B=50
        // The FIRST observation of B should produce a
        // LARGE error
        let firstBObs = try await probe.observe([50.0])
        XCTAssertGreaterThan(
            abs(firstBObs.error[0]), 40.0,
            "first observation post-shift must have" +
            " large error (~45) — substrate reacting" +
            " to distribution shift")
        // After many more B observations,prediction
        // recalibrates
        for _ in 0..<50 {
            _ = try await probe.observe([50.0])
        }
        let predAfterB =
            await probe.currentPredictionSnapshot()
        XCTAssertEqual(
            predAfterB[0], 50.0, accuracy: 0.5,
            "prediction must recalibrate to new signal" +
            " after distribution shift")
    }

    // MARK: - reset()

    func testResetRestoresInitialState() async throws {
        let shape = BASPredictiveCodingProbeShape(
            dim: 2,
            learningRate: 0.5,
            initialPrediction: [1.0, 2.0])
        let probe = BASPredictiveCodingProbe(
            shape: shape)
        _ = try await probe.observe([10.0, 20.0])
        let count1 = await probe.observationCount()
        XCTAssertEqual(count1, 1)
        await probe.reset()
        let restored =
            await probe.currentPredictionSnapshot()
        XCTAssertEqual(restored, [1.0, 2.0])
        let count2 = await probe.observationCount()
        XCTAssertEqual(count2, 0)
        let mse = await probe.runningMSE()
        XCTAssertEqual(mse, 0)
    }

    // MARK: - Shape validation

    func testShapeMismatchThrows() async {
        let shape = BASPredictiveCodingProbeShape(
            dim: 3,
            learningRate: 0.1)
        let probe = BASPredictiveCodingProbe(
            shape: shape)
        do {
            _ = try await probe.observe(
                [1.0, 2.0])  // wrong count
            XCTFail("expected shape mismatch")
        } catch BASPredictiveCodingError
            .shapeMismatch(let reason)
        {
            XCTAssertTrue(
                reason.contains("observation.count"))
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }
}
