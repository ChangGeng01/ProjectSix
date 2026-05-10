// MARK: - BASMPSGraphMatMulKernel — chapter 四百四十七 / M1165
// 系统熵 reduction
//
// **POST-SWEEP RADICAL EXECUTION FOLLOW-THROUGH** chapter
// 447 entry。 Sibling of chapter 431 M1099
// `BASMatMulKernel` (the CPU-stub triple-loop kernel),
// but this one ACTUALLY dispatches matrix multiply
// through `MetalPerformanceShaders` (MPS) on a real
// `MTLDevice` — first kernel in the substrate where
// input bytes leave the CPU,traverse a Metal command
// buffer,get computed by GPU shaders,and return as
// byte-equal output。
//
// ## Why this exists (system entropy framing)
//
// User audit (2026-05-11) surfaced the brutal truth:
// chapter 446 close-out "POST-RADICAL EVOLUTION SWEEP
// COMPLETE" was over-claim — the 3 chapter 431
// "builtin kernels" (matMul / rmsNorm / rotaryEmbedding)
// were all pure-CPU triple-loop stubs with ZERO Metal
// API calls,ZERO MTLBuffer usage,ZERO ANE leverage。
// "Native Apple Silicon foundation" was scaffolding。
// The original 2026-05-10 directive 「原生利用神经引擎」
// stood at 0% completion across 84 commits。
//
// chapter 447 opens the **POST-SWEEP RADICAL EXECUTION
// FOLLOW-THROUGH** — proving the substrate can actually
// dispatch compute through Apple Silicon。 M1165 ships
// the first kernel where data BYTES flow through:
//
//   1. Upload `[M×K]` input A from CPU bytes into
//      `MTLBuffer` via `device.makeBuffer(bytes:)`
//   2. Upload `[K×N]` input B same way
//   3. Wrap each in `MPSMatrix(buffer:descriptor:)`
//   4. Allocate `MTLBuffer` for output `[M×N]`
//   5. Build `MPSMatrixMultiplication` kernel
//   6. Encode to `MTLCommandBuffer`,commit,wait
//   7. Read result MTLBuffer bytes back to CPU `Data`
//   8. Return as Sendable `BASKernelOutputs`
//
// This is genuine GPU execution。 The result Data
// produced by this kernel is byte-equal to the CPU
// reference kernel's output (verified by the M1166 test)
// — same IEEE Float32 arithmetic,just executed on the
// GPU's vector ALUs。
//
// ## What this ships (M1165)
//
//   - `BASMPSGraphMatMulKernel` actor conforming to
//     `BASMetalKernel: Sendable`。 actor isolation
//     wraps the non-Sendable `MTLDevice` +
//     `MTLCommandQueue` references。
//   - typed key `(matMul, float32, metalBuffer)` —
//     SIBLING slot to chapter 431's
//     `(matMul, float32, cpuBytes)` CPU stub。 Both can
//     register with the same `BASMetalKernelRegistry`
//     under different keys;the scheduler routes via
//     `BASTensorBackingKind`。
//   - throws `.frameworkUnavailable("Metal")` if
//     `MTLCreateSystemDefaultDevice()` returns nil
//     (iOS Simulator without Metal,or watchOS,or any
//     env where Metal is unavailable)。
//   - throws `.deviceDispatchFailure(reason:)` if any
//     MTLBuffer allocation OR command buffer commit
//     fails at runtime。
//
// ## Sendable discipline
//
// Actor isolation is the answer。 `MTLDevice` +
// `MTLCommandQueue` are reference types that aren't
// Sendable;wrapping the kernel as an `actor` lets it
// hold them internally + serializes evaluate() calls so
// concurrent dispatch from multiple tasks doesn't race
// on the command queue。
//
// Inputs + outputs flow as `Data` (Sendable) per the
// `BASMetalKernel` protocol contract。 CPU → MTLBuffer
// upload + MTLBuffer → CPU download happen inside the
// actor context;callers never see the MTLBuffer
// directly。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     errors,typed key,typed bundles;no raw integers
//     except shape values derived from input
//     descriptors)
//   - chapter 二百一一 — single source-of-truth (one
//     matMul GPU kernel under one typed key;CPU
//     sibling kernel under different backing-kind key)
//   - chapter 三百九二 — replay-determinism (IEEE
//     Float32 arithmetic;GPU produces same bytes as
//     CPU for the same inputs — verified by M1166 test)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive new kernel under new key;CPU sibling
//     untouched;no V1 dispatch path touched)
//   - 红线 7 — hint-only (kernel dispatch is observation
//     /computation,not commitment authority)
//   - ADR-014 OPT-IN — purely additive
//
// ## Significance — first kernel where bytes actually
//                    flow through Apple Silicon
//
// Before M1165:every "Metal kernel" in the substrate
// was a CPU triple-loop wearing a Metal-shaped hat。
// 「原生利用神经引擎」 was 0% complete despite "84
// commits / 17 waves / chapters 427-446"。
//
// After M1165:byte data really flows
// CPU → MTLBuffer → MPS shader → MTLBuffer → CPU。 The
// substrate's "native Apple Silicon" claim now has at
// least ONE truthful endpoint。 Future kernels (rmsNorm
// MPS dispatch + rotaryEmbedding MPS dispatch +
// attention + softmax + Mamba selective-scan) ship
// under this pattern。
//
// chapter 447 = post-sweep REAL execution。 Chapter
// 446's "SWEEP COMPLETE" is reframed (in
// `BASChapter447EntropyDoctrine`) as "SCAFFOLDING
// COMPLETE,real execution begins"。

import Foundation
import Metal
@preconcurrency import MetalPerformanceShaders

/// Real GPU-dispatching matrix multiply via
/// `MPSMatrixMultiplication`。 Sibling of the chapter
/// 431 `BASMatMulKernel` (CPU stub) under different
/// `BASTensorBackingKind` slot in the registry。
public actor BASMPSGraphMatMulKernel: BASMetalKernel {

    public nonisolated let key: BASKernelKey =
        BASKernelKey(
            operation: .matMul,
            dataType: .float32,
            backingKind: .metalBuffer)

    private let device: any MTLDevice
    private let commandQueue: any MTLCommandQueue

    /// Construct the kernel against the system default
    /// `MTLDevice`。 Throws `.frameworkUnavailable`
    /// when Metal is unavailable (simulator without
    /// Metal,watchOS,etc)。 Hosts that successfully
    /// construct one can safely call `evaluate(...)`
    /// across concurrent tasks — actor isolation
    /// serializes command-queue access。
    public init() throws {
        guard let dev = MTLCreateSystemDefaultDevice()
        else {
            throw BASKernelError.frameworkUnavailable(
                framework: "Metal")
        }
        guard let queue = dev.makeCommandQueue() else {
            throw BASKernelError
                .frameworkUnavailable(
                    framework: "MTLCommandQueue")
        }
        self.device = dev
        self.commandQueue = queue
    }

    public func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        // Validate input bundle shape
        guard inputs.descriptors.count == 2 else {
            throw BASKernelError.shapeMismatch(
                reason: "matMul expects exactly 2" +
                " inputs (A,B);got" +
                " \(inputs.descriptors.count)")
        }
        let descA = inputs.descriptors[0]
        let descB = inputs.descriptors[1]
        for d in inputs.descriptors {
            guard d.dataType == .float32 else {
                throw BASKernelError.dataTypeMismatch(
                    expected: .float32,
                    actual: d.dataType)
            }
        }
        guard descA.shape.count == 2,
              descB.shape.count == 2 else {
            throw BASKernelError.shapeMismatch(
                reason: "matMul expects rank-2 inputs")
        }
        let M = descA.shape[0]
        let K = descA.shape[1]
        let K2 = descB.shape[0]
        let N = descB.shape[1]
        guard K == K2 else {
            throw BASKernelError.shapeMismatch(
                reason: "matMul inner dims must match:" +
                " A is \(M)×\(K),B is \(K2)×\(N)")
        }
        let startTick = DispatchTime.now()
            .uptimeNanoseconds

        // Upload CPU bytes → MTLBuffers
        let aBytesCount = M * K * 4
        let bBytesCount = K * N * 4
        let cBytesCount = M * N * 4
        guard let bufferA = inputs.payloads[0]
            .withUnsafeBytes({ rawBuffer in
                device.makeBuffer(
                    bytes: rawBuffer.baseAddress!,
                    length: aBytesCount,
                    options: .storageModeShared)
            })
        else {
            throw BASKernelError
                .deviceDispatchFailure(
                    reason: "failed to allocate" +
                    " MTLBuffer A")
        }
        guard let bufferB = inputs.payloads[1]
            .withUnsafeBytes({ rawBuffer in
                device.makeBuffer(
                    bytes: rawBuffer.baseAddress!,
                    length: bBytesCount,
                    options: .storageModeShared)
            })
        else {
            throw BASKernelError
                .deviceDispatchFailure(
                    reason: "failed to allocate" +
                    " MTLBuffer B")
        }
        guard let bufferC = device.makeBuffer(
            length: cBytesCount,
            options: .storageModeShared)
        else {
            throw BASKernelError
                .deviceDispatchFailure(
                    reason: "failed to allocate" +
                    " MTLBuffer C")
        }

        // Wrap in MPSMatrix descriptors
        let descMatrixA = MPSMatrixDescriptor(
            rows: M,
            columns: K,
            rowBytes: K * 4,
            dataType: .float32)
        let descMatrixB = MPSMatrixDescriptor(
            rows: K,
            columns: N,
            rowBytes: N * 4,
            dataType: .float32)
        let descMatrixC = MPSMatrixDescriptor(
            rows: M,
            columns: N,
            rowBytes: N * 4,
            dataType: .float32)
        let matrixA = MPSMatrix(
            buffer: bufferA, descriptor: descMatrixA)
        let matrixB = MPSMatrix(
            buffer: bufferB, descriptor: descMatrixB)
        let matrixC = MPSMatrix(
            buffer: bufferC, descriptor: descMatrixC)

        // Build + encode MPSMatrixMultiplication
        // C := alpha * (A × B) + beta * C
        let matmul = MPSMatrixMultiplication(
            device: device,
            transposeLeft: false,
            transposeRight: false,
            resultRows: M,
            resultColumns: N,
            interiorColumns: K,
            alpha: 1.0,
            beta: 0.0)
        guard let commandBuffer = commandQueue
            .makeCommandBuffer()
        else {
            throw BASKernelError
                .deviceDispatchFailure(
                    reason: "failed to make" +
                    " MTLCommandBuffer")
        }
        matmul.encode(
            commandBuffer: commandBuffer,
            leftMatrix: matrixA,
            rightMatrix: matrixB,
            resultMatrix: matrixC)
        commandBuffer.commit()
        // Swift concurrency-aware wait for the GPU。
        // `completed()` is the async-context counterpart
        // of the now-deprecated `waitUntilCompleted()`。
        // Returns when the command buffer reaches
        // .completed status (success or failure)。
        _ = await commandBuffer.completed()
        if let err = commandBuffer.error {
            throw BASKernelError
                .deviceDispatchFailure(
                    reason: "command buffer error:" +
                    " \(err.localizedDescription)")
        }

        // Download MTLBuffer C → CPU bytes
        let outBytes = Data(
            bytes: bufferC.contents(),
            count: cBytesCount)

        let endTick = DispatchTime.now()
            .uptimeNanoseconds
        let elapsed = endTick &- startTick

        // Build output descriptor — note backingKind is
        // .metalBuffer (this kernel's slot)
        let outDesc = BASTensorDescriptor.contiguous(
            shape: [M, N],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: _2D.rankTag)
        return BASKernelOutputs(
            descriptors: [outDesc],
            payloads: [outBytes],
            executionNanos: elapsed)
    }
}
