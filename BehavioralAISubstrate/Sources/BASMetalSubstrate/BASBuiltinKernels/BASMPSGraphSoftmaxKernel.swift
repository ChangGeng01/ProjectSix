// MARK: - BASMPSGraphSoftmaxKernel
// chapter 四百七十九 / M1292 — closes missing-softmax gap
//
// Real GPU-dispatching row-wise softmax via `MPSGraph`。
// 5th MPSGraph kernel to ship numerical-correctness PROOF
// (after matMul M1277, rmsNorm M1280, rotaryEmbedding
// M1282, attention M1284)。 Brings BASNeuralOp coverage
// from 4-of-8 to 5-of-8。
//
// Formula:y_ij = exp(x_ij - max(x_i)) / sum_k(exp(x_ik
// - max(x_i)))
//
// Row-wise: per-row max subtraction for numerical
// stability, then normalize so each row sums to 1。
// Reuses pattern of M1280 BASMPSGraphRMSNormKernel:
// fresh MPSGraph per call (caching deferred to chapter
// 480 M1296)。
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — kernel evaluation is observation
//   - chapter 一百八十五 — typed key + typed inputs
//   - chapter 二百一一 — single source-of-truth for
//     softmax GPU dispatch
//   - chapter 三百九二 — same inputs → same outputs
//     (deterministic within IEEE Float32 reduction
//     tolerance)
//   - 红线 7 — kernel computes;dispatch routes
//   - ADR-014 OPT-IN — purely additive

import Foundation
import Metal
@preconcurrency import MetalPerformanceShadersGraph

/// Real GPU-dispatching row-wise softmax via
/// `MPSGraph.softMax(with:axis:name:)`。
public actor BASMPSGraphSoftmaxKernel: BASMetalKernel {

    public nonisolated let key: BASKernelKey =
        BASKernelKey(
            operation: .softmax,
            dataType: .float32,
            backingKind: .metalBuffer)

    private let device: any MTLDevice
    private let commandQueue: any MTLCommandQueue
    private let cache: BASMPSGraphExecutableCache?

    /// Construct the kernel against the system default
    /// `MTLDevice`。 M2042:optional cache parameter for
    /// compile-cost amortization。 Default nil preserves
    /// M1292 baseline byte-equality。
    public init(
        cache: BASMPSGraphExecutableCache? = nil
    ) throws {
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
        self.cache = cache
    }

    public func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        guard inputs.descriptors.count == 1 else {
            throw BASKernelError.shapeMismatch(
                reason: "softmax expects 1 input (x);" +
                " got \(inputs.descriptors.count)")
        }
        let descX = inputs.descriptors[0]
        guard descX.dataType == .float32 else {
            throw BASKernelError.dataTypeMismatch(
                expected: .float32,
                actual: descX.dataType)
        }
        guard descX.shape.count == 2 else {
            throw BASKernelError.shapeMismatch(
                reason: "softmax expects rank-2 x" +
                " (rows × cols);got rank " +
                "\(descX.shape.count)")
        }
        let rows = descX.shape[0]
        let cols = descX.shape[1]
        guard rows > 0, cols > 0 else {
            throw BASKernelError.shapeMismatch(
                reason: "softmax dims must be > 0")
        }

        let startTick = DispatchTime.now()
            .uptimeNanoseconds
        let bytesCount = rows * cols * 4

        // Upload CPU bytes → MTLBuffer
        guard let bufferX = inputs.payloads[0]
            .withUnsafeBytes({ raw in
                device.makeBuffer(
                    bytes: raw.baseAddress!,
                    length: bytesCount,
                    options: .storageModeShared)
            })
        else {
            throw BASKernelError
                .deviceDispatchFailure(
                    reason: "failed to allocate" +
                    " MTLBuffer x")
        }
        guard let bufferOut = device.makeBuffer(
            length: bytesCount,
            options: .storageModeShared)
        else {
            throw BASKernelError
                .deviceDispatchFailure(
                    reason: "failed to allocate" +
                    " MTLBuffer output")
        }

        // Wrap MTLBuffers in MPSGraphTensorData (shared)
        let xTensorData = MPSGraphTensorData(
            bufferX,
            shape: [NSNumber(value: rows),
                    NSNumber(value: cols)],
            dataType: .float32)
        let outTensorData = MPSGraphTensorData(
            bufferOut,
            shape: [NSNumber(value: rows),
                    NSNumber(value: cols)],
            dataType: .float32)

        // M2042 chapter 六百六十六 第二刀:cache-on/off
        // branching。 cache=nil → M1292 baseline path
        // UNCHANGED。 cache=non-nil → compile + cache +
        // executable.run fast path。
        if let cache = self.cache {
            let cacheKey = BASMPSGraphCacheKey(
                operation: .softmax,
                dataType: .float32,
                inputShapes: [[rows, cols]])
            let executable: MPSGraphExecutable
            if let cached = await cache.cachedExecutable(
                forKey: cacheKey)
            {
                executable = cached
                await cache.recordHit(key: cacheKey)
            } else {
                let graph = MPSGraph()
                let xPlaceholder = graph.placeholder(
                    shape: [NSNumber(value: rows),
                            NSNumber(value: cols)],
                    dataType: .float32, name: "x")
                let output = graph.softMax(
                    with: xPlaceholder, axis: 1,
                    name: "output")
                let xShape = MPSGraphShapedType(
                    shape: [NSNumber(value: rows),
                            NSNumber(value: cols)],
                    dataType: .float32)
                executable = graph.compile(
                    with: nil,
                    feeds: [xPlaceholder: xShape],
                    targetTensors: [output],
                    targetOperations: nil,
                    compilationDescriptor: nil)
                await cache.storeExecutable(
                    executable, forKey: cacheKey)
                await cache.recordMiss(key: cacheKey)
            }
            let _ = executable.run(
                with: commandQueue,
                inputs: [xTensorData],
                results: [outTensorData],
                executionDescriptor: nil)
        } else {
            // M1292 baseline path — byte-equality preserved
            let graph = MPSGraph()
            let xPlaceholder = graph.placeholder(
                shape: [NSNumber(value: rows),
                        NSNumber(value: cols)],
                dataType: .float32, name: "x")
            let output = graph.softMax(
                with: xPlaceholder, axis: 1, name: "output")
            graph.run(
                with: commandQueue,
                feeds: [xPlaceholder: xTensorData],
                targetOperations: nil,
                resultsDictionary: [output: outTensorData])
        }

        // Download result
        let outBytes = Data(
            bytes: bufferOut.contents(),
            count: bytesCount)

        let endTick = DispatchTime.now()
            .uptimeNanoseconds
        let elapsed = endTick &- startTick

        let outDesc = BASTensorDescriptor.contiguous(
            shape: [rows, cols],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: _2D.rankTag)
        return BASKernelOutputs(
            descriptors: [outDesc],
            payloads: [outBytes],
            executionNanos: elapsed)
    }
}
