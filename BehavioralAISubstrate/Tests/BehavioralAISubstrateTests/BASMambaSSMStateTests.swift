// MARK: - BASMambaSSMStateTests
// chapter 四百五十 / M1178 — POST-SWEEP BIOMIMETIC

import XCTest
import Foundation
@testable import BASMetalSubstrate

/// PROOF tests for the M1177 BASMambaSSMState actor —
/// substrate's first biomimetic primitive (recurrent
/// hidden state + selective gating)。
///
/// Coverage:
///   - Construction + zero-init hidden state
///   - reset() zeroes state + call counter
///   - Single-call selectiveScan with simple inputs
///   - State PERSISTENCE across multiple calls
///   - Selective gating:Δ=0 freezes state;Δ>0
///     allows update (proves input-dependent gating
///     actually modulates state evolution)
///   - Output projection:y[t] = sum_n(C[t,n] * h[d,n])
///   - Multi-batch independence:state of batch 0
///     doesn't leak into batch 1
final class BASMambaSSMStateTests: XCTestCase {

    // MARK: - Construction + initial state

    func testConstructionZeroesHiddenState() async {
        let shape = BASMambaSSMShape(
            batch: 1, hiddenDim: 2, stateDim: 3)
        let actor = BASMambaSSMState(shape: shape)
        let initialState =
            await actor.currentHiddenStateSnapshot()
        XCTAssertEqual(
            initialState.count, 1 * 2 * 3,
            "hidden state size = batch * hiddenDim *" +
            " stateDim")
        XCTAssertTrue(
            initialState.allSatisfy { $0 == 0 },
            "fresh actor must have zero-initialized" +
            " hidden state")
        let initialCount =
            await actor.scanCallCount()
        XCTAssertEqual(initialCount, 0)
    }

    func testShapeClampsToOne() async {
        let shape = BASMambaSSMShape(
            batch: 0,
            hiddenDim: -5,
            stateDim: 0)
        XCTAssertEqual(shape.batch, 1,
            "batch must clamp to >= 1")
        XCTAssertEqual(shape.hiddenDim, 1)
        XCTAssertEqual(shape.stateDim, 1)
    }

    // MARK: - reset() behavior

    func testResetZeroesStateAndCounter() async throws {
        let shape = BASMambaSSMShape(
            batch: 1, hiddenDim: 2, stateDim: 2)
        let actor = BASMambaSSMState(shape: shape)
        // Run one scan to mutate state + bump counter
        let scan = BASMambaSSMScanInputs(
            x: [1, 1],            // (B=1, L=1, D=2)
            delta: [0.5, 0.5],
            a: [-1, -1, -1, -1],  // (D=2, N=2)
            b: [1, 1],            // (B=1, L=1, N=2)
            c: [1, 1],            // (B=1, L=1, N=2)
            sequenceLength: 1)
        _ = try await actor.selectiveScan(inputs: scan)
        let countAfterScan =
            await actor.scanCallCount()
        XCTAssertEqual(countAfterScan, 1)
        // reset must clear both
        await actor.reset()
        let postResetState =
            await actor.currentHiddenStateSnapshot()
        XCTAssertTrue(
            postResetState.allSatisfy { $0 == 0 })
        let postResetCount =
            await actor.scanCallCount()
        XCTAssertEqual(postResetCount, 0)
    }

    // MARK: - Single-step canonical scan

    /// One timestep with simple inputs;verify state
    /// evolves per the formula。
    /// Setup: B=1, D=1, N=1, L=1
    /// initial h = 0
    /// x = 2, Δ = 0.5, A = -1, B = 3, C = 4
    /// dA = exp(0.5 * -1) = exp(-0.5) ≈ 0.6065
    /// dB = 0.5 * 3 = 1.5
    /// h' = 0.6065 * 0 + 1.5 * 2 = 3.0
    /// y = 4 * 3.0 = 12.0
    func testSingleStepCanonicalUpdate() async throws {
        let shape = BASMambaSSMShape(
            batch: 1, hiddenDim: 1, stateDim: 1)
        let actor = BASMambaSSMState(shape: shape)
        let scan = BASMambaSSMScanInputs(
            x: [2.0],
            delta: [0.5],
            a: [-1.0],
            b: [3.0],
            c: [4.0],
            sequenceLength: 1)
        let outputs = try await actor.selectiveScan(
            inputs: scan)
        // Expected h' = 3.0 + ε from exp(-0.5)*0=0
        XCTAssertEqual(
            outputs.finalHiddenStateSnapshot.count, 1)
        XCTAssertEqual(
            outputs.finalHiddenStateSnapshot[0],
            3.0, accuracy: 1e-5,
            "h' = dA * 0 + dB * x = 1.5 * 2 = 3.0")
        XCTAssertEqual(
            outputs.y.count, 1)
        XCTAssertEqual(
            outputs.y[0], 12.0, accuracy: 1e-5,
            "y = C * h' = 4 * 3 = 12")
    }

    // MARK: - State persistence across calls

    /// **THE CRITICAL BIOMIMETIC PROPERTY** —
    /// hidden state persists across selectiveScan
    /// calls。 The actor's state is NOT cleared
    /// between calls (unlike stateless kernels)。
    /// This is the recurrence Mamba SSM provides。
    func testStatePersistsAcrossCalls() async throws {
        let shape = BASMambaSSMShape(
            batch: 1, hiddenDim: 1, stateDim: 1)
        let actor = BASMambaSSMState(shape: shape)
        // First scan:h = 0 → 3.0 (per testSingleStep
        // setup)
        let scan1 = BASMambaSSMScanInputs(
            x: [2.0], delta: [0.5], a: [-1.0],
            b: [3.0], c: [4.0], sequenceLength: 1)
        let out1 = try await actor.selectiveScan(
            inputs: scan1)
        XCTAssertEqual(
            out1.finalHiddenStateSnapshot[0],
            3.0, accuracy: 1e-5)
        // Second scan with x=0 + Δ=1.0:state must
        // DECAY (dA = exp(-1.0) ≈ 0.3679)
        // h'' = 0.3679 * 3.0 + 1.0 * 1.0 * 0 ≈ 1.1036
        let scan2 = BASMambaSSMScanInputs(
            x: [0.0],
            delta: [1.0],
            a: [-1.0],
            b: [1.0],
            c: [1.0],
            sequenceLength: 1)
        let out2 = try await actor.selectiveScan(
            inputs: scan2)
        let expectedH2 = expf(-1.0) * 3.0
        XCTAssertEqual(
            out2.finalHiddenStateSnapshot[0],
            expectedH2, accuracy: 1e-5,
            "after second scan,state must reflect" +
            " decay from prior state — proves persistence")
        // Scan call counter increments
        let count =
            await actor.scanCallCount()
        XCTAssertEqual(count, 2)
    }

    // MARK: - Selective gating

    /// **THE SELECTIVE GATING PROOF** — Δ=0 freezes
    /// state evolution entirely。 With Δ=0:
    ///   dA = exp(0 * A) = exp(0) = 1
    ///   dB = 0 * B = 0
    ///   h' = 1 * h + 0 * x = h    (unchanged)
    /// This is the input-dependent gating that makes
    /// Mamba "selective":the model can choose,per
    /// timestep + per feature,whether to update state
    /// or freeze it。
    func testZeroDeltaFreezesState() async throws {
        let shape = BASMambaSSMShape(
            batch: 1, hiddenDim: 1, stateDim: 1)
        let actor = BASMambaSSMState(shape: shape)
        // Warm-up:bring state to some non-zero value
        let warmup = BASMambaSSMScanInputs(
            x: [5.0], delta: [0.5], a: [-1.0],
            b: [2.0], c: [1.0], sequenceLength: 1)
        let warmupOut = try await actor.selectiveScan(
            inputs: warmup)
        let stateBeforeFreeze =
            warmupOut.finalHiddenStateSnapshot[0]
        XCTAssertNotEqual(
            stateBeforeFreeze, 0,
            "warm-up must produce non-zero state")
        // Now scan with Δ=0:state MUST stay frozen
        // (regardless of how big x is)
        let frozen = BASMambaSSMScanInputs(
            x: [9999.0],     // huge x,but...
            delta: [0.0],    // ...Δ=0 freezes everything
            a: [-1.0],
            b: [9999.0],     // ...and huge B doesn't help
            c: [1.0],
            sequenceLength: 1)
        let frozenOut = try await actor.selectiveScan(
            inputs: frozen)
        XCTAssertEqual(
            frozenOut.finalHiddenStateSnapshot[0],
            stateBeforeFreeze, accuracy: 1e-5,
            "Δ=0 must freeze state regardless of x" +
            " magnitude (selective gating proof)")
    }

    // MARK: - Multi-batch independence

    /// State at batch 0 must NOT leak into batch 1。
    /// Same Δ/A/B/C across batches but different x
    /// values → independent state evolution per batch。
    func testMultiBatchIndependence() async throws {
        let shape = BASMambaSSMShape(
            batch: 2, hiddenDim: 1, stateDim: 1)
        let actor = BASMambaSSMState(shape: shape)
        // x[batch=0, t=0, d=0] = 1
        // x[batch=1, t=0, d=0] = 100
        let scan = BASMambaSSMScanInputs(
            x: [1.0, 100.0],
            delta: [0.5, 0.5],
            a: [-1.0],
            b: [1.0, 1.0],
            c: [1.0, 1.0],
            sequenceLength: 1)
        let outputs = try await actor.selectiveScan(
            inputs: scan)
        // Both batches start from h=0
        // batch 0: dA=exp(-0.5), dB=0.5, x=1 → h=0.5
        // batch 1: dA=exp(-0.5), dB=0.5, x=100 → h=50
        XCTAssertEqual(
            outputs.finalHiddenStateSnapshot.count, 2)
        XCTAssertEqual(
            outputs.finalHiddenStateSnapshot[0],
            0.5, accuracy: 1e-5,
            "batch 0 state = 0.5")
        XCTAssertEqual(
            outputs.finalHiddenStateSnapshot[1],
            50.0, accuracy: 1e-4,
            "batch 1 state = 50 (independent of batch 0)")
    }

    // MARK: - Multi-timestep scan

    /// Run a 3-step scan in one call;verify state
    /// at the end matches what 3 sequential single-
    /// step scans would produce。
    func testMultiTimestepScanMatchesSequential() async throws {
        let shape = BASMambaSSMShape(
            batch: 1, hiddenDim: 1, stateDim: 1)
        // Run as 3 separate single-step scans
        let sequential = BASMambaSSMState(shape: shape)
        var stateSeq: Float = 0
        for t in 0..<3 {
            let x: Float = Float(t + 1)
            let scan = BASMambaSSMScanInputs(
                x: [x], delta: [0.3], a: [-1.0],
                b: [1.0], c: [1.0], sequenceLength: 1)
            let out = try await sequential
                .selectiveScan(inputs: scan)
            stateSeq = out.finalHiddenStateSnapshot[0]
        }
        // Run as 1 scan with sequenceLength=3
        let combined = BASMambaSSMState(shape: shape)
        let scanCombined = BASMambaSSMScanInputs(
            x: [1.0, 2.0, 3.0],
            delta: [0.3, 0.3, 0.3],
            a: [-1.0],
            b: [1.0, 1.0, 1.0],
            c: [1.0, 1.0, 1.0],
            sequenceLength: 3)
        let outCombined = try await combined
            .selectiveScan(inputs: scanCombined)
        XCTAssertEqual(
            outCombined.finalHiddenStateSnapshot[0],
            stateSeq, accuracy: 1e-5,
            "multi-step scan must equal sequential" +
            " single-step scans")
        XCTAssertEqual(outCombined.y.count, 3,
            "L=3 scan produces 3 output values")
    }

    // MARK: - Shape validation errors

    func testShapeMismatchThrows() async {
        let shape = BASMambaSSMShape(
            batch: 1, hiddenDim: 1, stateDim: 1)
        let actor = BASMambaSSMState(shape: shape)
        // x size wrong for sequenceLength=1
        let badScan = BASMambaSSMScanInputs(
            x: [1.0, 2.0, 3.0],     // expected 1, got 3
            delta: [0.5],
            a: [-1.0],
            b: [1.0],
            c: [1.0],
            sequenceLength: 1)
        do {
            _ = try await actor.selectiveScan(
                inputs: badScan)
            XCTFail("expected shape mismatch throw")
        } catch BASMambaSSMError
            .shapeMismatch(let reason)
        {
            XCTAssertTrue(reason.contains("x.count"))
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }
}
