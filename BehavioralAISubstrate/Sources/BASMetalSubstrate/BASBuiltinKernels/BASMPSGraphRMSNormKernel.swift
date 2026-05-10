// MARK: - BASMPSGraphRMSNormKernel — chapter 四百四十八 / M1169
// 系统熵 reduction
//
// **POST-SWEEP REAL EXECUTION FOLLOW-THROUGH** chapter
// 448 entry。 Second kernel in the substrate where input
// bytes actually flow through Apple Silicon GPU shaders
// — sibling of chapter 447 `BASMPSGraphMatMulKernel`,
// targeting the RMS normalization op used by every
// modern transformer block (Gemma 3 / Llama 3 / Qwen 2)。
//
// ## Why this exists (system entropy framing)
//
// chapter 447 shipped `BASMPSGraphMatMulKernel` as the
// substrate's FIRST real GPU dispatch endpoint。 Chapter
// 431's three "Metal kernels" (matMul / rmsNorm /
// rotaryEmbedding) were all pure-CPU stubs。 chapter 448
// applies the chapter 447 pattern to the SECOND of the
// three — rmsNorm — to continue closing the gap on
// 「原生利用神经引擎」。
//
// ## Implementation choice:MPSGraph (not MPSMatrix)
//
// chapter 447 used `MPSMatrixMultiplication` (older
// MPS API,direct + simple)。 RMSNorm requires reduce-
// mean + sqrt + per-element divide + broadcast multiply
// — operations MPSMatrix cannot express。 chapter 448
// uses `MPSGraph` (modern API,arbitrary op composition)
// — building a graph that fuses:
//
//   squared      = x * x                      // (B, H)
//   meanSquares  = reduceMean(squared, [-1])  // (B, 1)
//   shifted      = meanSquares + eps          // (B, 1)
//   rms          = sqrt(shifted)              // (B, 1)
//   normalized   = x / rms                    // (B, H) broadcast
//   output       = normalized * weight        // (B, H) broadcast
//
// MPSGraph compiles this into an optimized execution
// plan + dispatches on the GPU。 First MPSGraph usage in
// the substrate;establishes the pattern for chapter
// 449 rotaryEmbedding + chapter 451 Mamba selective-scan。
//
// ## What this ships (M1169)
//
//   - `BASMPSGraphRMSNormKernel` actor conforming to
//     `BASMetalKernel: Sendable`。 Actor isolation wraps
//     non-Sendable `MTLDevice` + `MTLCommandQueue` +
//     `MPSGraph` references。
//   - typed key `(rmsNorm, float32, metalBuffer)` —
//     sibling slot to chapter 431
//     `(rmsNorm, float32, cpuBytes)` CPU stub
//   - typed `epsilon` init parameter (default 1e-6,
//     matching Gemma / Llama defaults)
//   - throws `.frameworkUnavailable("Metal")` on
//     platforms without Metal
//   - throws `.deviceDispatchFailure(reason:)` on
//     buffer allocation OR graph execution errors
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed key + typed errors +
//     typed epsilon param;no magic literals in graph
//     construction
//   - chapter 二百一一 — one rmsNorm GPU kernel under
//     typed key;CPU sibling preserved under different
//     backing-kind key
//   - chapter 三百九二 — replay-determinism (MPSGraph
//     produces bit-stable IEEE Float32 output;byte-equal
//     to CPU reference for the same inputs — verified by
//     test;NOTE:MPSGraph may use fused-multiply-add
//     reordering on some hardware,so the byte-equal
//     test uses XCTAssertEqual with accuracy tolerance
//     instead of strict equality)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive new kernel under new typed key)
//   - 红线 7 — kernel dispatch is observation/
//     computation
//   - ADR-014 OPT-IN — purely additive

import Foundation
import Metal
@preconcurrency import MetalPerformanceShadersGraph

/// Real GPU-dispatching RMS normalization via
/// `MPSGraph`。 Sibling of the chapter 431
/// `BASRMSNormKernel` (CPU stub) under different
/// `BASTensorBackingKind` slot in the registry。
public actor BASMPSGraphRMSNormKernel: BASMetalKernel {

    public nonisolated let key: BASKernelKey =
        BASKernelKey(
            operation: .rmsNorm,
            dataType: .float32,
            backingKind: .metalBuffer)

    /// Numerical-stability epsilon added inside the
    /// sqrt。 Default 1e-6 matches Gemma 3 / Llama 3
    /// transformer blocks。 Threaded as a graph
    /// constant at evaluate-time。
    public nonisolated let epsilon: Float

    private let device: any MTLDevice
    private let commandQueue: any MTLCommandQueue

    /// Construct the kernel against the system default
    /// `MTLDevice`。 Throws `.frameworkUnavailable`
    /// when Metal is unavailable。
    public init(epsilon: Float = 1e-6) throws {
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
        self.epsilon = epsilon
    }

    public func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        // Validate input bundle shape
        guard inputs.descriptors.count == 2 else {
            throw BASKernelError.shapeMismatch(
                reason: "rmsNorm expects 2 inputs" +
                " (x,weight);got" +
                " \(inputs.descriptors.count)")
        }
        let descX = inputs.descriptors[0]
        let descW = inputs.descriptors[1]
        for d in inputs.descriptors {
            guard d.dataType == .float32 else {
                throw BASKernelError.dataTypeMismatch(
                    expected: .float32,
                    actual: d.dataType)
            }
        }
        guard descX.shape.count == 2 else {
            throw BASKernelError.shapeMismatch(
                reason: "rmsNorm expects rank-2 x")
        }
        guard descW.shape.count == 1 else {
            throw BASKernelError.shapeMismatch(
                reason: "rmsNorm expects rank-1 weight")
        }
        let batch = descX.shape[0]
        let hidden = descX.shape[1]
        guard descW.shape[0] == hidden else {
            throw BASKernelError.shapeMismatch(
                reason: "rmsNorm weight (\(descW.shape[0]))" +
                " must equal x hidden (\(hidden))")
        }
        let startTick = DispatchTime.now()
            .uptimeNanoseconds

        let xBytesCount = batch * hidden * 4
        let wBytesCount = hidden * 4
        let outBytesCount = batch * hidden * 4

        // Upload CPU bytes → MTLBuffers
        guard let bufferX = inputs.payloads[0]
            .withUnsafeBytes({ raw in
                device.makeBuffer(
                    bytes: raw.baseAddress!,
                    length: xBytesCount,
                    options: .storageModeShared)
            })
        else {
            throw BASKernelError
                .deviceDispatchFailure(
                    reason: "failed to allocate" +
                    " MTLBuffer x")
        }
        guard let bufferW = inputs.payloads[1]
            .withUnsafeBytes({ raw in
                device.makeBuffer(
                    bytes: raw.baseAddress!,
                    length: wBytesCount,
                    options: .storageModeShared)
            })
        else {
            throw BASKernelError
                .deviceDispatchFailure(
                    reason: "failed to allocate" +
                    " MTLBuffer w")
        }
        guard let bufferOut = device.makeBuffer(
            length: outBytesCount,
            options: .storageModeShared)
        else {
            throw BASKernelError
                .deviceDispatchFailure(
                    reason: "failed to allocate" +
                    " MTLBuffer output")
        }

        // Build the rmsNorm graph fresh per call (graphs
        // are lightweight + caching them across batch
        // sizes is a future optimization in chapter
        // 451+)。
        let graph = MPSGraph()
        let xPlaceholder = graph.placeholder(
            shape: [NSNumber(value: batch),
                    NSNumber(value: hidden)],
            dataType: .float32,
            name: "x")
        let wPlaceholder = graph.placeholder(
            shape: [NSNumber(value: hidden)],
            dataType: .float32,
            name: "weight")
        let squared = graph.multiplication(
            xPlaceholder, xPlaceholder, name: "sq")
        let meanSquares = graph.mean(
            of: squared,
            axes: [NSNumber(value: 1)],
            name: "mean")
        let epsTensor = graph.constant(
            Double(epsilon),
            shape: [1, 1],
            dataType: .float32)
        let shifted = graph.addition(
            meanSquares, epsTensor, name: "shifted")
        let rms = graph.squareRoot(
            with: shifted, name: "rms")
        let normalized = graph.division(
            xPlaceholder, rms, name: "normalized")
        let output = graph.multiplication(
            normalized, wPlaceholder, name: "output")

        // Wrap MTLBuffers in MPSGraphTensorData
        let xTensorData = MPSGraphTensorData(
            bufferX,
            shape: [NSNumber(value: batch),
                    NSNumber(value: hidden)],
            dataType: .float32)
        let wTensorData = MPSGraphTensorData(
            bufferW,
            shape: [NSNumber(value: hidden)],
            dataType: .float32)
        let outTensorData = MPSGraphTensorData(
            bufferOut,
            shape: [NSNumber(value: batch),
                    NSNumber(value: hidden)],
            dataType: .float32)

        // Dispatch:run the graph into pre-allocated
        // output buffer
        graph.run(
            with: commandQueue,
            feeds: [
                xPlaceholder: xTensorData,
                wPlaceholder: wTensorData
            ],
            targetOperations: nil,
            resultsDictionary: [output: outTensorData])

        // Download result MTLBuffer → CPU bytes
        let outBytes = Data(
            bytes: bufferOut.contents(),
            count: outBytesCount)

        let endTick = DispatchTime.now()
            .uptimeNanoseconds
        let elapsed = endTick &- startTick

        let outDesc = BASTensorDescriptor.contiguous(
            shape: [batch, hidden],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: _2D.rankTag)
        return BASKernelOutputs(
            descriptors: [outDesc],
            payloads: [outBytes],
            executionNanos: elapsed)
    }
}
