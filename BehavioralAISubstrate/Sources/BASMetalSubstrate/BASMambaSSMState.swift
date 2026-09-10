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
import Metal

// MARK: - Typed shape

/// Typed shape descriptor for a `BASMambaSSMState`
/// instance。 All dims are positive Int;init clamps
/// to >= 1 to prevent zero-sized state degenerate
/// cases。
public struct BASMambaSSMShape:
    Equatable, Hashable, Sendable, Codable
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
    Equatable, Hashable, Sendable, Codable
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
    Equatable, Hashable, Sendable, Codable
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

public enum BASMambaSSMError:
    Error, Equatable, Sendable, Codable
{
    case shapeMismatch(reason: String)
    /// Metal device or compute pipeline could not be
    /// constructed。 Thrown by `selectiveScanGPU(...)`
    /// when Metal is unavailable (simulator without
    /// Metal,watchOS,etc)。 chapter 451 / M1181。
    case gpuUnavailable(reason: String)
    /// Live GPU dispatch failed (e.g. command buffer
    /// commit error)。 chapter 451 / M1181。
    case gpuDispatchFailure(reason: String)
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

    // MARK: - chapter 451 / M1181 — Lazy GPU pipeline

    /// Metal device,lazily initialized on first
    /// `selectiveScanGPU(...)` call。 nil until then,
    /// or after a `.frameworkUnavailable` throw。
    private var metalDevice: (any MTLDevice)?

    /// Metal command queue,paired with `metalDevice`。
    private var metalCommandQueue: (any MTLCommandQueue)?

    /// Compiled compute pipeline for selective-scan
    /// shader。 Lazy-built on first GPU call。
    private var metalPipeline:
        (any MTLComputePipelineState)?

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

    // MARK: - chapter 451 / M1181 — GPU selective-scan

    /// GPU-accelerated selective-scan via a runtime-
    /// compiled Metal compute kernel。 Threads are
    /// dispatched as (batch × hiddenDim) — each thread
    /// runs the sequential timestep loop for its own
    /// (b, d) pair。 Hidden state IS the same state
    /// `selectiveScan(...)` mutates;both methods can
    /// be interleaved freely。
    ///
    /// Throws `.gpuUnavailable` if Metal device or
    /// pipeline can't be built (simulator without
    /// Metal,watchOS)。 Lazy-builds the pipeline on
    /// first call;subsequent calls reuse the cached
    /// pipeline。
    ///
    /// Parallelism:O(B × D) threads each doing O(L × N)
    /// sequential work。 For typical Mamba shapes
    /// (B=1,D=128-512,N=16-64),this is 128-512
    /// concurrent threads,each doing ~L × N=512-4096
    /// ops。 Significantly faster than CPU for
    /// L >= ~32 sequences on Apple Silicon GPUs。
    // audit x-concurrency MED-9 — FIFO async mutex (mirrors BASPlasticityFold): selectiveScanGPU
    // reads the `hiddenState` baseline before its single GPU await and overwrites it after, so two
    // concurrent calls both captured the same pre-await state and the second lost the first's
    // update. For a RECURRENT scan (h_new depends on h_old) an accumulate-onto-current writeback is
    // UNSOUND, so serialization — one call airborne at a time, each reading a fresh baseline — is
    // the correct fix. The lock hands off in arrival order.
    private var scanBusy = false
    private var scanWaiters: [CheckedContinuation<Void, Never>] = []

    /// Run `op` under the per-actor scan lock — at most one op airborne across its await.
    func _serializeScan<T>(_ op: () async throws -> T) async rethrows -> T {
        if scanBusy {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                scanWaiters.append(c)
            }   // resumed via hand-off ⇒ we hold the lock
        } else {
            scanBusy = true
        }
        defer {
            if scanWaiters.isEmpty {
                scanBusy = false
            } else {
                scanWaiters.removeFirst().resume()
            }
        }
        return try await op()
    }

    public func selectiveScanGPU(
        inputs: BASMambaSSMScanInputs
    ) async throws -> BASMambaSSMScanOutputs {
        // audit x-concurrency MED-9: serialize so a concurrent scan reads a FRESH hiddenState.
        try await _serializeScan {
            try await self._selectiveScanGPULocked(inputs: inputs)
        }
    }

    private func _selectiveScanGPULocked(
        inputs: BASMambaSSMScanInputs
    ) async throws -> BASMambaSSMScanOutputs {
        let B = shape.batch
        let D = shape.hiddenDim
        let N = shape.stateDim
        let L = inputs.sequenceLength
        // Same shape validation as CPU path
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
        // Lazy build Metal pipeline
        try ensureMetalPipelineReady()
        guard let device = metalDevice,
              let queue = metalCommandQueue,
              let pipeline = metalPipeline else {
            throw BASMambaSSMError.gpuUnavailable(
                reason: "metal pipeline not ready")
        }
        // Allocate MTLBuffers for inputs + state + output
        let xBytes = B * L * D * MemoryLayout<Float>.stride
        let deltaBytes = B * L * D * MemoryLayout<Float>.stride
        let aBytes = D * N * MemoryLayout<Float>.stride
        let bBytes = B * L * N * MemoryLayout<Float>.stride
        let cBytes = B * L * N * MemoryLayout<Float>.stride
        let hBytes = B * D * N * MemoryLayout<Float>.stride
        let yBytes = B * L * D * MemoryLayout<Float>.stride
        guard let xBuf = inputs.x
            .withUnsafeBufferPointer({ ptr in
                device.makeBuffer(
                    bytes: ptr.baseAddress!,
                    length: xBytes,
                    options: .storageModeShared)
            })
        else {
            throw BASMambaSSMError.gpuDispatchFailure(
                reason: "alloc x failed")
        }
        guard let deltaBuf = inputs.delta
            .withUnsafeBufferPointer({ ptr in
                device.makeBuffer(
                    bytes: ptr.baseAddress!,
                    length: deltaBytes,
                    options: .storageModeShared)
            })
        else {
            throw BASMambaSSMError.gpuDispatchFailure(
                reason: "alloc delta failed")
        }
        guard let aBuf = inputs.a
            .withUnsafeBufferPointer({ ptr in
                device.makeBuffer(
                    bytes: ptr.baseAddress!,
                    length: aBytes,
                    options: .storageModeShared)
            })
        else {
            throw BASMambaSSMError.gpuDispatchFailure(
                reason: "alloc A failed")
        }
        guard let bBuf = inputs.b
            .withUnsafeBufferPointer({ ptr in
                device.makeBuffer(
                    bytes: ptr.baseAddress!,
                    length: bBytes,
                    options: .storageModeShared)
            })
        else {
            throw BASMambaSSMError.gpuDispatchFailure(
                reason: "alloc B failed")
        }
        guard let cBuf = inputs.c
            .withUnsafeBufferPointer({ ptr in
                device.makeBuffer(
                    bytes: ptr.baseAddress!,
                    length: cBytes,
                    options: .storageModeShared)
            })
        else {
            throw BASMambaSSMError.gpuDispatchFailure(
                reason: "alloc C failed")
        }
        // Hidden state buffer:upload current state
        // (the kernel writes-back the updated state)
        guard let hBuf = hiddenState
            .withUnsafeBufferPointer({ ptr in
                device.makeBuffer(
                    bytes: ptr.baseAddress!,
                    length: hBytes,
                    options: .storageModeShared)
            })
        else {
            throw BASMambaSSMError.gpuDispatchFailure(
                reason: "alloc h failed")
        }
        guard let yBuf = device.makeBuffer(
            length: yBytes,
            options: .storageModeShared)
        else {
            throw BASMambaSSMError.gpuDispatchFailure(
                reason: "alloc y failed")
        }
        // Constants buffer (B, L, D, N as uint32)
        // chapter 五百三十五 / M1517 — immutability per
        // user coding standards (var → let,never mutated)。
        let dims: [UInt32] = [
            UInt32(B), UInt32(L), UInt32(D), UInt32(N)
        ]
        guard let dimsBuf = dims
            .withUnsafeBufferPointer({ ptr in
                device.makeBuffer(
                    bytes: ptr.baseAddress!,
                    length: dims.count * MemoryLayout<UInt32>.stride,
                    options: .storageModeShared)
            })
        else {
            throw BASMambaSSMError.gpuDispatchFailure(
                reason: "alloc dims failed")
        }
        // Dispatch
        guard let cmdBuf = queue.makeCommandBuffer(),
              let encoder = cmdBuf
                .makeComputeCommandEncoder()
        else {
            throw BASMambaSSMError.gpuDispatchFailure(
                reason: "alloc command buffer/" +
                "encoder failed")
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(xBuf, offset: 0, index: 0)
        encoder.setBuffer(deltaBuf, offset: 0, index: 1)
        encoder.setBuffer(aBuf, offset: 0, index: 2)
        encoder.setBuffer(bBuf, offset: 0, index: 3)
        encoder.setBuffer(cBuf, offset: 0, index: 4)
        encoder.setBuffer(hBuf, offset: 0, index: 5)
        encoder.setBuffer(yBuf, offset: 0, index: 6)
        encoder.setBuffer(dimsBuf, offset: 0, index: 7)
        // Grid: B × D threads, one per (batch, hidden)
        // pair。 Each thread sequentially scans over
        // L timesteps × N state dims。
        let gridSize = MTLSize(
            width: B, height: D, depth: 1)
        // Threadgroup size — pick a reasonable default;
        // Metal will clamp to max for the pipeline。
        let maxTgw = pipeline
            .maxTotalThreadsPerThreadgroup
        let tgWidth = min(B, maxTgw)
        let tgHeight = min(D, max(1, maxTgw / tgWidth))
        let tgSize = MTLSize(
            width: tgWidth,
            height: tgHeight, depth: 1)
        encoder.dispatchThreads(
            gridSize, threadsPerThreadgroup: tgSize)
        encoder.endEncoding()
        // H3 (mega-audit, 2026-07-08): handler BEFORE commit — the
        // `commit(); await completed()` form deterministically hangs on
        // iPhone Air for tiny dispatches (ch1034 forensics);Mac stays
        // falsely green。 Canonical bridge per BASMetalKernelLibraryLoader。
        try await withCheckedThrowingContinuation {
            (cont: CheckedContinuation<Void, Error>) in
            cmdBuf.addCompletedHandler { buffer in
                if let err = buffer.error {
                    cont.resume(throwing:
                        BASMambaSSMError.gpuDispatchFailure(
                            reason: "command buffer error:" +
                            " \(err.localizedDescription)"))
                } else {
                    cont.resume()
                }
            }
            cmdBuf.commit()
        }
        // Read back updated hidden state + output
        let hUpdated = Array(
            UnsafeBufferPointer<Float>(
                start: hBuf.contents()
                    .assumingMemoryBound(
                        to: Float.self),
                count: B * D * N))
        let y = Array(
            UnsafeBufferPointer<Float>(
                start: yBuf.contents()
                    .assumingMemoryBound(
                        to: Float.self),
                count: B * L * D))
        hiddenState = hUpdated
        processedScanCalls += 1
        return BASMambaSSMScanOutputs(
            y: y,
            finalHiddenStateSnapshot: hiddenState)
    }

    // MARK: - chapter 455 / M1197 — snapshot persistence

    /// Capture an immutable snapshot of the actor's
    /// current state。 Safe to encode/persist
    /// (Codable via BASMambaSSMSnapshot)。
    public func exportSnapshot() -> BASMambaSSMSnapshot {
        return BASMambaSSMSnapshot(
            shape: shape,
            hiddenState: hiddenState,
            processedScanCalls: processedScanCalls)
    }

    /// Restore actor state from a previously-exported
    /// snapshot。 Throws `.shapeMismatch` if the
    /// snapshot's shape doesn't match the actor's
    /// shape,or if `hiddenState.count` doesn't match
    /// the expected B × D × N flat length。 Validation
    /// happens BEFORE any mutation — failure leaves
    /// the actor's state untouched。
    public func importSnapshot(
        _ snapshot: BASMambaSSMSnapshot
    ) throws {
        guard snapshot.shape == shape else {
            throw BASBiomimeticSnapshotError
                .shapeMismatch(
                    reason: "snapshot.shape" +
                    " (\(snapshot.shape)) !=" +
                    " actor.shape (\(shape))")
        }
        let expectedSize = shape.batch
            * shape.hiddenDim * shape.stateDim
        guard snapshot.hiddenState.count
            == expectedSize else {
            throw BASBiomimeticSnapshotError
                .shapeMismatch(
                    reason:
                    "snapshot.hiddenState.count" +
                    " (\(snapshot.hiddenState.count))" +
                    " != expected (\(expectedSize))")
        }
        // Direct mutation of private actor state:safe
        // because this method lives inside the actor
        // body (not an extension)。
        hiddenState = snapshot.hiddenState
        processedScanCalls = snapshot.processedScanCalls
    }

    /// Lazy-build the Metal pipeline on first GPU call。
    /// Subsequent calls are no-ops (pipeline is cached)。
    private func ensureMetalPipelineReady() throws {
        guard metalDevice == nil else { return }
        guard let dev = MTLCreateSystemDefaultDevice()
        else {
            throw BASMambaSSMError.gpuUnavailable(
                reason: "no default MTLDevice")
        }
        guard let queue = dev.makeCommandQueue() else {
            throw BASMambaSSMError.gpuUnavailable(
                reason: "no MTLCommandQueue")
        }
        // Compile Metal compute shader from source。
        // Each thread handles all timesteps + all state
        // dims for one (batch, hidden) pair。 Sequential
        // recurrence over t (required by Mamba's
        // selective-scan algorithm),parallel across
        // (batch × hiddenDim) grid。
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void selective_scan(
            device const float *x         [[buffer(0)]],
            device const float *delta     [[buffer(1)]],
            device const float *A         [[buffer(2)]],
            device const float *B         [[buffer(3)]],
            device const float *C         [[buffer(4)]],
            device float *h               [[buffer(5)]],
            device float *y               [[buffer(6)]],
            constant uint4 &dims          [[buffer(7)]],
            uint2 gid [[thread_position_in_grid]])
        {
            const uint b = gid.x;
            const uint d = gid.y;
            const uint B_dim = dims.x;
            const uint L     = dims.y;
            const uint D     = dims.z;
            const uint N     = dims.w;
            if (b >= B_dim || d >= D) {
                return;
            }
            for (uint t = 0; t < L; t++) {
                const float deltaTD =
                    delta[b * L * D + t * D + d];
                const float xTD =
                    x[b * L * D + t * D + d];
                float outAccum = 0.0;
                for (uint n = 0; n < N; n++) {
                    const float aDN = A[d * N + n];
                    const float bTN =
                        B[b * L * N + t * N + n];
                    const float cTN =
                        C[b * L * N + t * N + n];
                    const float dA =
                        exp(deltaTD * aDN);
                    const float dB = deltaTD * bTN;
                    const uint hIdx =
                        b * D * N + d * N + n;
                    const float newH =
                        dA * h[hIdx] + dB * xTD;
                    h[hIdx] = newH;
                    outAccum += cTN * newH;
                }
                y[b * L * D + t * D + d] = outAccum;
            }
        }
        """
        let library: any MTLLibrary
        do {
            library = try dev.makeLibrary(
                source: source, options: nil)
        } catch {
            throw BASMambaSSMError.gpuUnavailable(
                reason: "shader compile failed:" +
                " \(error.localizedDescription)")
        }
        guard let function = library.makeFunction(
            name: "selective_scan")
        else {
            throw BASMambaSSMError.gpuUnavailable(
                reason: "shader function" +
                " 'selective_scan' missing")
        }
        let pipe: any MTLComputePipelineState
        do {
            pipe = try dev.makeComputePipelineState(
                function: function)
        } catch {
            throw BASMambaSSMError.gpuUnavailable(
                reason: "pipeline build failed:" +
                " \(error.localizedDescription)")
        }
        self.metalDevice = dev
        self.metalCommandQueue = queue
        self.metalPipeline = pipe
    }
}
