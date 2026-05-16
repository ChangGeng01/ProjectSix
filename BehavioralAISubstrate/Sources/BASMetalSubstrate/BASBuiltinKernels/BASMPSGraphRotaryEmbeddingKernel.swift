// MARK: - BASMPSGraphRotaryEmbeddingKernel — chapter 四百四十九 / M1173
// 系统熵 reduction
//
// **POST-SWEEP REAL EXECUTION** chapter 3 — third + final
// chapter 431 CPU-stub kernel migrated to real GPU
// dispatch。 「原生利用神经引擎」 progress 2/3 → 3/3
// GPU kernels real after this ship。
//
// ## What this ships (M1173)
//
//   - `BASMPSGraphRotaryEmbeddingKernel` actor
//     conforming to `BASMetalKernel: Sendable`
//   - typed key `(rotaryEmbedding, float32, metalBuffer)`
//   - MPSGraph composition for RoPE (rotary positional
//     embedding) used by Gemma 3 / Llama 3 / Qwen 2
//     transformer attention:
//
//       x:        (seq, headDim)         [headDim must be even]
//       cos:      (seq, headDim/2)
//       sin:      (seq, headDim/2)
//
//       graph composition:
//         xReshape = reshape(x, [seq, halfDim, 2])
//         xEven    = slice(xReshape, dim 2, [0..1])    # (seq, halfDim, 1)
//         xOdd     = slice(xReshape, dim 2, [1..2])    # (seq, halfDim, 1)
//         xEvenFlat = reshape(xEven, [seq, halfDim])
//         xOddFlat  = reshape(xOdd,  [seq, halfDim])
//         newEven  = xEven * cos - xOdd * sin
//         newOdd   = xEven * sin + xOdd * cos
//         newEvenE = reshape(newEven, [seq, halfDim, 1])
//         newOddE  = reshape(newOdd,  [seq, halfDim, 1])
//         outPair  = concat([newEvenE, newOddE], dim 2)
//         output   = reshape(outPair, [seq, headDim])
//
//   - throws same typed errors as chapters 447/448 GPU
//     kernels
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed errors + typed key;
//     no magic literals beyond the IEEE 2 (pair size)
//   - chapter 二百一一 — one rotary GPU kernel under
//     typed key;CPU sibling under different backing-
//     kind key
//   - chapter 三百九二 — replay-determinism (GPU
//     produces output within 1e-5 absolute tolerance of
//     CPU reference;mul+sub+add chains less FMA-
//     sensitive than rmsNorm's sqrt+divide)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//   - 红线 7 — observation/computation only
//   - ADR-014 OPT-IN — additive

import Foundation
import Metal
@preconcurrency import MetalPerformanceShadersGraph

/// Real GPU-dispatching rotary positional embedding
/// via `MPSGraph`。 Sibling of the chapter 431
/// `BASRotaryEmbeddingKernel` (CPU stub)。
public actor BASMPSGraphRotaryEmbeddingKernel:
    BASMetalKernel
{

    public nonisolated let key: BASKernelKey =
        BASKernelKey(
            operation: .rotaryEmbedding,
            dataType: .float32,
            backingKind: .metalBuffer)

    private let device: any MTLDevice
    private let commandQueue: any MTLCommandQueue

    /// M2038 chapter 六百六十五 第二刀:optional cache
    /// for `MPSGraphExecutable` amortization。 Default nil
    /// preserves M1190 byte-equality (graph.run path
    /// unchanged when cache=nil)。
    private let cache: BASMPSGraphExecutableCache?

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

    // MARK: - Graph build (shared between cache-on + cache-off)

    /// Build the rotaryEmbedding compute graph + return
    /// placeholders + output for binding。 Shared helper
    /// extracted at M2038 to avoid duplicating 80 LOC of
    /// op composition across cache-on / cache-off paths。
    private nonisolated func buildGraph(
        seqLen: Int,
        headDim: Int,
        halfDim: Int
    ) -> (
        graph: MPSGraph,
        xPlaceholder: MPSGraphTensor,
        cosPlaceholder: MPSGraphTensor,
        sinPlaceholder: MPSGraphTensor,
        output: MPSGraphTensor
    ) {
        let graph = MPSGraph()
        let xPlaceholder = graph.placeholder(
            shape: [NSNumber(value: seqLen),
                    NSNumber(value: headDim)],
            dataType: .float32, name: "x")
        let cosPlaceholder = graph.placeholder(
            shape: [NSNumber(value: seqLen),
                    NSNumber(value: halfDim)],
            dataType: .float32, name: "cos")
        let sinPlaceholder = graph.placeholder(
            shape: [NSNumber(value: seqLen),
                    NSNumber(value: halfDim)],
            dataType: .float32, name: "sin")

        let xReshape = graph.reshape(
            xPlaceholder,
            shape: [NSNumber(value: seqLen),
                    NSNumber(value: halfDim),
                    NSNumber(value: 2)],
            name: "xReshape")
        let xEven3D = graph.sliceTensor(
            xReshape, dimension: 2,
            start: 0, length: 1, name: "xEven3D")
        let xOdd3D = graph.sliceTensor(
            xReshape, dimension: 2,
            start: 1, length: 1, name: "xOdd3D")
        let xEvenFlat = graph.reshape(
            xEven3D,
            shape: [NSNumber(value: seqLen),
                    NSNumber(value: halfDim)],
            name: "xEvenFlat")
        let xOddFlat = graph.reshape(
            xOdd3D,
            shape: [NSNumber(value: seqLen),
                    NSNumber(value: halfDim)],
            name: "xOddFlat")
        let evenMulCos = graph.multiplication(
            xEvenFlat, cosPlaceholder, name: "evenMulCos")
        let oddMulSin = graph.multiplication(
            xOddFlat, sinPlaceholder, name: "oddMulSin")
        let newEven = graph.subtraction(
            evenMulCos, oddMulSin, name: "newEven")
        let evenMulSin = graph.multiplication(
            xEvenFlat, sinPlaceholder, name: "evenMulSin")
        let oddMulCos = graph.multiplication(
            xOddFlat, cosPlaceholder, name: "oddMulCos")
        let newOdd = graph.addition(
            evenMulSin, oddMulCos, name: "newOdd")
        let newEvenE = graph.reshape(
            newEven,
            shape: [NSNumber(value: seqLen),
                    NSNumber(value: halfDim),
                    NSNumber(value: 1)],
            name: "newEvenE")
        let newOddE = graph.reshape(
            newOdd,
            shape: [NSNumber(value: seqLen),
                    NSNumber(value: halfDim),
                    NSNumber(value: 1)],
            name: "newOddE")
        let outPair = graph.concatTensors(
            [newEvenE, newOddE],
            dimension: 2, name: "outPair")
        let output = graph.reshape(
            outPair,
            shape: [NSNumber(value: seqLen),
                    NSNumber(value: headDim)],
            name: "output")
        return (graph, xPlaceholder, cosPlaceholder,
                sinPlaceholder, output)
    }

    public func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        guard inputs.descriptors.count == 3 else {
            throw BASKernelError.shapeMismatch(
                reason: "rotaryEmbedding expects 3" +
                " inputs (x, cos, sin);got" +
                " \(inputs.descriptors.count)")
        }
        let descX = inputs.descriptors[0]
        let descCos = inputs.descriptors[1]
        let descSin = inputs.descriptors[2]
        for d in inputs.descriptors {
            guard d.dataType == .float32 else {
                throw BASKernelError.dataTypeMismatch(
                    expected: .float32,
                    actual: d.dataType)
            }
        }
        guard descX.shape.count == 2,
              descCos.shape.count == 2,
              descSin.shape.count == 2 else {
            throw BASKernelError.shapeMismatch(
                reason: "rotaryEmbedding expects rank-2" +
                " inputs")
        }
        let seqLen = descX.shape[0]
        let headDim = descX.shape[1]
        guard headDim % 2 == 0 else {
            throw BASKernelError.shapeMismatch(
                reason: "rotaryEmbedding headDim must" +
                " be even;got \(headDim)")
        }
        let halfDim = headDim / 2
        guard descCos.shape == [seqLen, halfDim],
              descSin.shape == [seqLen, halfDim] else {
            throw BASKernelError.shapeMismatch(
                reason: "rotaryEmbedding cos/sin must" +
                " be [\(seqLen), \(halfDim)]")
        }
        let startTick = DispatchTime.now()
            .uptimeNanoseconds

        let xBytesCount = seqLen * headDim * 4
        let cosBytesCount = seqLen * halfDim * 4
        let sinBytesCount = seqLen * halfDim * 4
        let outBytesCount = seqLen * headDim * 4

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
                    reason: "alloc x failed")
        }
        guard let bufferCos = inputs.payloads[1]
            .withUnsafeBytes({ raw in
                device.makeBuffer(
                    bytes: raw.baseAddress!,
                    length: cosBytesCount,
                    options: .storageModeShared)
            })
        else {
            throw BASKernelError
                .deviceDispatchFailure(
                    reason: "alloc cos failed")
        }
        guard let bufferSin = inputs.payloads[2]
            .withUnsafeBytes({ raw in
                device.makeBuffer(
                    bytes: raw.baseAddress!,
                    length: sinBytesCount,
                    options: .storageModeShared)
            })
        else {
            throw BASKernelError
                .deviceDispatchFailure(
                    reason: "alloc sin failed")
        }
        guard let bufferOut = device.makeBuffer(
            length: outBytesCount,
            options: .storageModeShared)
        else {
            throw BASKernelError
                .deviceDispatchFailure(
                    reason: "alloc out failed")
        }

        // Wrap MTLBuffers in MPSGraphTensorData (shared
        // across both cache-on and cache-off paths)
        let xTD = MPSGraphTensorData(
            bufferX,
            shape: [NSNumber(value: seqLen),
                    NSNumber(value: headDim)],
            dataType: .float32)
        let cosTD = MPSGraphTensorData(
            bufferCos,
            shape: [NSNumber(value: seqLen),
                    NSNumber(value: halfDim)],
            dataType: .float32)
        let sinTD = MPSGraphTensorData(
            bufferSin,
            shape: [NSNumber(value: seqLen),
                    NSNumber(value: halfDim)],
            dataType: .float32)
        let outTD = MPSGraphTensorData(
            bufferOut,
            shape: [NSNumber(value: seqLen),
                    NSNumber(value: headDim)],
            dataType: .float32)

        // M2038 chapter 六百六十五 第二刀:cache-on fast
        // path or cache-off baseline。 Cache-off branch
        // preserves M1190 byte-equality semantics for
        // hosts that haven't opted in (cache=nil)。
        if let cache = self.cache {
            let cacheKey = BASMPSGraphCacheKey(
                operation: .rotaryEmbedding,
                dataType: .float32,
                inputShapes: [
                    [seqLen, headDim],
                    [seqLen, halfDim],
                    [seqLen, halfDim]
                ])
            let executable: MPSGraphExecutable
            if let cached = await cache.cachedExecutable(
                forKey: cacheKey)
            {
                executable = cached
                await cache.recordHit(key: cacheKey)
            } else {
                let built = buildGraph(
                    seqLen: seqLen,
                    headDim: headDim,
                    halfDim: halfDim)
                let xShape = MPSGraphShapedType(
                    shape: [NSNumber(value: seqLen),
                            NSNumber(value: headDim)],
                    dataType: .float32)
                let cosShape = MPSGraphShapedType(
                    shape: [NSNumber(value: seqLen),
                            NSNumber(value: halfDim)],
                    dataType: .float32)
                let sinShape = MPSGraphShapedType(
                    shape: [NSNumber(value: seqLen),
                            NSNumber(value: halfDim)],
                    dataType: .float32)
                executable = built.graph.compile(
                    with: nil,
                    feeds: [
                        built.xPlaceholder: xShape,
                        built.cosPlaceholder: cosShape,
                        built.sinPlaceholder: sinShape
                    ],
                    targetTensors: [built.output],
                    targetOperations: nil,
                    compilationDescriptor: nil)
                await cache.storeExecutable(
                    executable, forKey: cacheKey)
                await cache.recordMiss(key: cacheKey)
            }
            let _ = executable.run(
                with: commandQueue,
                inputs: [xTD, cosTD, sinTD],
                results: [outTD],
                executionDescriptor: nil)
        } else {
            // Chapter 449 M1190 baseline path — graph.run
            // — byte-equality preserved
            let built = buildGraph(
                seqLen: seqLen,
                headDim: headDim,
                halfDim: halfDim)
            built.graph.run(
                with: commandQueue,
                feeds: [
                    built.xPlaceholder: xTD,
                    built.cosPlaceholder: cosTD,
                    built.sinPlaceholder: sinTD
                ],
                targetOperations: nil,
                resultsDictionary: [built.output: outTD])
        }

        let outBytes = Data(
            bytes: bufferOut.contents(),
            count: outBytesCount)

        let endTick = DispatchTime.now()
            .uptimeNanoseconds
        let elapsed = endTick &- startTick

        let outDesc = BASTensorDescriptor.contiguous(
            shape: [seqLen, headDim],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: _2D.rankTag)
        return BASKernelOutputs(
            descriptors: [outDesc],
            payloads: [outBytes],
            executionNanos: elapsed)
    }
}
