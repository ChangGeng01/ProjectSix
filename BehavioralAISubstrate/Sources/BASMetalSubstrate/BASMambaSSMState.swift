// MARK: - BASMambaSSMState — chapter 四百五十 / M1177
// 系统熵 reduction
//
// **POST-SWEEP BIOMIMETIC** chapter 1 — first
// substrate-level state-space model primitive。 The
// 「不够仿生」 critique gets its first substantive
// answer here:typed actor maintaining a continuous
// hidden state across calls,with input-dependent
// selective gating modulating both the state-decay
// rate and the input-injection magnitude per step。
//
// ## Why this exists (system entropy framing)
//
// chapter 446 SWEEP CLOSE-OUT shipped 7 typed event
// payload kinds + replay-surface infrastructure。
// chapter 447-449 shipped 3 real GPU kernels (matMul +
// rmsNorm + rotaryEmbedding)。 But the substrate STILL
// had 0 biomimetic primitives:no recurrent state,no
// selective gating,no continuous adaptation,no
// content-dependent decay。
//
// Mamba (Gu & Dao 2023) is the modern state-space-model
// architecture:linear-time recurrence with input-
// dependent A,B,C,Δ projections that selectively
// modulate which prior state matters for the current
// computation。 The selective-scan operator IS the
// biomimetic core — biology has analogous selective
// gating throughout (thalamocortical attention,
// neuromodulators,working-memory gates)。
//
// chapter 450 ships the substrate's first
// **substrate-side BASMambaSSMState actor** with:
//
//   - typed hidden state `h: (B, D, N)`
//     (batch × hidden-dim × state-dim)
//   - CPU baseline `selectiveScan(input:Δ:A:B:C:)`
//     implementing the canonical SSM update:
//
//       for each timestep t in input sequence:
//         dA = exp(Δ[t] · A)                  // (B, D, N)  discretized decay
//         dB = Δ[t] · B[t]                    // (B, D, N)  discretized injection
//         h  = dA * h + dB * x[t]             // (B, D, N)  state update
//         y[t] = sum_n(C[t, :] * h[:, n])     // (B, D)     output projection
//
//   - actor isolation:state mutations are serialized
//     across concurrent callers
//   - state persistence across selectiveScan() calls
//     (THIS is the biomimetic property — hidden
//     activation continuously evolves across turns)
//   - `reset()` zeroes state (for new sessions or
//     state-flushing tests)
//
// ## Why CPU baseline first (chapter 451 ships GPU)
//
// SSM selective-scan with input-dependent A,B,C,Δ is
// NOT a standard MPSGraph op (no built-in scan
// primitive)。 GPU acceleration requires either:
//   1. Custom Metal kernel implementing the sequential
//      recurrence (chapter 451 will ship)
//   2. Unrolling the scan into per-step matMul ops
//      (works but loses the selective-scan compute
//      efficiency)
//
// chapter 450 ships the CPU reference + the typed API
// surface;chapter 451 ships the GPU kernel under the
// same `BASMambaSSMState` actor by adding a
// `selectiveScanGPU(input:Δ:A:B:C:)` companion or
// switching the existing method's hot path。 The CPU
// baseline IS testable + IS biomimetically meaningful
// — substrate finally has a recurrent state primitive。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed shape parameters
//     (batch / hiddenDim / stateDim) + typed Float arrays;
//     no magic numbers in the algorithm
//   - chapter 二百一一 — one BASMambaSSMState shape;
//     GPU acceleration (chapter 451) ships under same
//     actor's hot-path
//   - chapter 三百九二 — replay-determinism (state
//     evolution is deterministic per (input, Δ, A, B, C)
//     tuple)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive new primitive;no existing path touched)
//   - 红线 7 — observation/computation (Mamba SSM
//     output is hint, not commitment)
//   - ADR-014 OPT-IN — purely additive
//
// ## Significance — first biomimetic substrate primitive
//
// Before chapter 450:0 substrate-level state-space
// models,0 recurrent hidden states,0 selective gating
// primitives。 Every substrate op was stateless (each
// kernel call independent of prior calls)。
//
// After chapter 450:substrate has a **stateful** actor
// where hidden state persists across calls。 Input-
// dependent Δ + B + C modulate state evolution per step
// (selective gating)。 Biology-inspired primitive
// finally enters the substrate。
//
// 「不够仿生」 critique:0/10 → 4/10 (first primitive
// shipped;chapter 452 BASPredictiveCodingProbe adds
// adaptation loop;chapter 454+ adds plasticity)。

import Foundation

// MARK: - Typed shape

/// Typed shape descriptor for a `BASMambaSSMState`
/// instance。 All dims are positive Int;init clamps
/// to >= 1 to prevent zero-sized state degenerate
/// cases。
public struct BASMambaSSMShape:
    Equatable, Hashable, Sendable
{

    /// Batch dimension B。 Number of independent state
    /// trajectories the actor maintains concurrently。
    public let batch: Int

    /// Hidden dimension D。 Feature width of the input
    /// at each timestep + output at each timestep。
    public let hiddenDim: Int

    /// State dimension N。 Width of the latent state
    /// the SSM maintains for each (batch, hidden)
    /// pair。 Mamba typically uses N=16 or N=64。
    public let stateDim: Int

    public init(
        batch: Int,
        hiddenDim: Int,
        stateDim: Int
    ) {
        self.batch = max(1, batch)
        self.hiddenDim = max(1, hiddenDim)
        self.stateDim = max(1, stateDim)
    }
}

// MARK: - Selective-scan input/output bundles

/// Typed input bundle for one `selectiveScan(...)`
/// call。 Carries the sequence inputs + the input-
/// dependent A/B/C/Δ projections。
public struct BASMambaSSMScanInputs:
    Equatable, Hashable, Sendable
{

    /// Input sequence x: (B, L, D)。 L is sequence
    /// length;each timestep contributes one D-dim
    /// vector per batch。
    public let x: [Float]

    /// Per-timestep selective-decay parameter
    /// Δ: (B, L, D)。 Larger Δ → more state change
    /// per step (state decays faster + new input
    /// injected harder)。 Biology analogue:
    /// neuromodulator gating。
    public let delta: [Float]

    /// State-transition matrix A: (D, N)。 Captures
    /// the BASE decay rate per (hidden, state) pair。
    /// Mamba uses A < 0 so exp(Δ · A) is in (0, 1)。
    public let a: [Float]

    /// Per-timestep input-injection projection
    /// B: (B, L, N)。 Modulates how much of x gets
    /// injected into state at each step。
    public let b: [Float]

    /// Per-timestep output-readout projection
    /// C: (B, L, N)。 Modulates which state dims
    /// contribute to the output at each step。
    public let c: [Float]

    /// Sequence length L。 Must match the L dim in
    /// x / delta / b / c。 Validated by the actor。
    public let sequenceLength: Int

    public init(
        x: [Float],
        delta: [Float],
        a: [Float],
        b: [Float],
        c: [Float],
        sequenceLength: Int
    ) {
        self.x = x
        self.delta = delta
        self.a = a
        self.b = b
        self.c = c
        self.sequenceLength = max(0, sequenceLength)
    }
}

/// Typed output bundle from `selectiveScan(...)`。
/// Carries the per-timestep output sequence + the
/// final post-scan hidden state snapshot (for audit
/// + replay)。
public struct BASMambaSSMScanOutputs:
    Equatable, Hashable, Sendable
{

    /// Output sequence y: (B, L, D)。 Each timestep
    /// gets one D-dim output (C · h)。
    public let y: [Float]

    /// Final hidden state snapshot: (B, D, N)。 The
    /// state inside the actor AFTER the scan
    /// completed。 Exposes the state for tests + audit
    /// without breaking actor isolation (snapshot is
    /// taken inside the actor)。
    public let finalHiddenStateSnapshot: [Float]

    public init(
        y: [Float],
        finalHiddenStateSnapshot: [Float]
    ) {
        self.y = y
        self.finalHiddenStateSnapshot =
            finalHiddenStateSnapshot
    }
}

// MARK: - Typed errors

public enum BASMambaSSMError: Error, Equatable, Sendable {
    case shapeMismatch(reason: String)
}

// MARK: - SSM state actor

/// Substrate-side state-space model actor maintaining
/// a continuous hidden state across `selectiveScan(...)`
/// calls。 Actor isolation serializes state mutations
/// for concurrent-task safety。
public actor BASMambaSSMState {

    public nonisolated let shape: BASMambaSSMShape

    /// Hidden state h: (B, D, N) flattened to
    /// row-major Float array。 Mutated by every
    /// `selectiveScan(...)` call;reset to zeros by
    /// `reset()`。
    private var hiddenState: [Float]

    /// Number of `selectiveScan(...)` calls processed
    /// since the most recent `reset()`。 Surfaced via
    /// `scanCallCount` accessor for audit + tests。
    private var processedScanCalls: Int = 0

    /// Construct a fresh SSM state for the given shape。
    /// Hidden state initialized to all zeros。
    public init(shape: BASMambaSSMShape) {
        self.shape = shape
        let totalCells =
            shape.batch * shape.hiddenDim * shape.stateDim
        self.hiddenState = Array(
            repeating: 0, count: totalCells)
    }

    /// Read-only snapshot of the current hidden state。
    /// Used by audit + tests to verify state evolution
    /// without breaking actor isolation。
    public func currentHiddenStateSnapshot() -> [Float] {
        return hiddenState
    }

    /// Read-only call count since last `reset()`。
    public func scanCallCount() -> Int {
        return processedScanCalls
    }

    /// Zero the hidden state + reset call counter。
    /// Used at session boundaries or when tests need
    /// a clean slate。
    public func reset() {
        hiddenState = Array(
            repeating: 0,
            count: shape.batch
                * shape.hiddenDim
                * shape.stateDim)
        processedScanCalls = 0
    }

    /// Execute selective-scan over a sequence。
    /// Mutates internal hidden state;returns output
    /// sequence + final-state snapshot。
    ///
    /// Algorithm (canonical Mamba selective-scan):
    /// ```
    /// for t in 0..<L:
    ///   for b in 0..<B:
    ///     for d in 0..<D:
    ///       deltaTD = delta[b, t, d]
    ///       for n in 0..<N:
    ///         dA = exp(deltaTD * A[d, n])
    ///         dB = deltaTD * B[b, t, n]
    ///         h[b, d, n] = dA * h[b, d, n] + dB * x[b, t, d]
    ///       y[b, t, d] = sum_n(C[b, t, n] * h[b, d, n])
    /// ```
    public func selectiveScan(
        inputs: BASMambaSSMScanInputs
    ) async throws -> BASMambaSSMScanOutputs {
        let B = shape.batch
        let D = shape.hiddenDim
        let N = shape.stateDim
        let L = inputs.sequenceLength
        // Shape validation
        guard inputs.x.count == B * L * D else {
            throw BASMambaSSMError.shapeMismatch(
                reason: "x.count must be B*L*D =" +
                " \(B*L*D);got \(inputs.x.count)")
        }
        guard inputs.delta.count == B * L * D else {
            throw BASMambaSSMError.shapeMismatch(
                reason: "delta.count must be B*L*D =" +
                " \(B*L*D);got \(inputs.delta.count)")
        }
        guard inputs.a.count == D * N else {
            throw BASMambaSSMError.shapeMismatch(
                reason: "a.count must be D*N =" +
                " \(D*N);got \(inputs.a.count)")
        }
        guard inputs.b.count == B * L * N else {
            throw BASMambaSSMError.shapeMismatch(
                reason: "b.count must be B*L*N =" +
                " \(B*L*N);got \(inputs.b.count)")
        }
        guard inputs.c.count == B * L * N else {
            throw BASMambaSSMError.shapeMismatch(
                reason: "c.count must be B*L*N =" +
                " \(B*L*N);got \(inputs.c.count)")
        }
        // Allocate output sequence
        var y: [Float] = Array(
            repeating: 0, count: B * L * D)
        // Sequential scan — each timestep depends on
        // prior state。 No parallelization across L
        // (the whole point of selective-scan is the
        // sequential recurrence)。
        for t in 0..<L {
            for b in 0..<B {
                for d in 0..<D {
                    let deltaTD = inputs.delta[
                        b * L * D + t * D + d]
                    let xTD = inputs.x[
                        b * L * D + t * D + d]
                    var outputAccum: Float = 0
                    for n in 0..<N {
                        let aDN = inputs.a[d * N + n]
                        let bTN = inputs.b[
                            b * L * N + t * N + n]
                        let cTN = inputs.c[
                            b * L * N + t * N + n]
                        // Discretized state-decay
                        // factor dA = exp(Δ · A)。
                        // For numerical stability when
                        // Δ * A is large negative,
                        // exp clamps to ~0 cleanly。
                        let dA = expf(deltaTD * aDN)
                        // Discretized input-injection
                        // dB = Δ · B
                        let dB = deltaTD * bTN
                        // State update:
                        //   h = dA * h + dB * x
                        let hIdx = b * D * N
                            + d * N + n
                        let newH =
                            dA * hiddenState[hIdx]
                            + dB * xTD
                        hiddenState[hIdx] = newH
                        // Output accumulation:
                        //   y[t, d] += C[t, n] * h[d, n]
                        outputAccum += cTN * newH
                    }
                    y[b * L * D + t * D + d] =
                        outputAccum
                }
            }
        }
        processedScanCalls += 1
        return BASMambaSSMScanOutputs(
            y: y,
            finalHiddenStateSnapshot: hiddenState)
    }
}
