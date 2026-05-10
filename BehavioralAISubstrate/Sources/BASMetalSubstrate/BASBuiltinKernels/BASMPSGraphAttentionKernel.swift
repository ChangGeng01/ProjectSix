// MARK: - BASMPSGraphAttentionKernel — chapter 四百五十三 / M1189
// 系统熵 reduction
//
// **POST-SWEEP REAL EXECUTION** chapter 4 GPU kernel
// — fourth real GPU-dispatching kernel + first GPU
// kernel composing matMul + transpose + softmax in
// one MPSGraph executable。 Closes the transformer
// kernel quartet (matMul + rmsNorm + rotaryEmbedding
// + attention) — substrate now has every primitive
// a modern attention block needs。
//
// ## What this ships (M1189 — GPU)
//
//   - `BASMPSGraphAttentionKernel` actor conforming
//     to `BASMetalKernel: Sendable`
//   - typed key `(attention, float32, metalBuffer)` —
//     sibling slot to chapter 453 CPU stub
//   - MPSGraph composition for single-head scaled
//     dot-product attention:
//       Q: (seqQ, dim)
//       K: (seqK, dim)
//       V: (seqK, dim)
//       kT       = transpose(K)
//       scoresRaw = Q · kT
//       scores   = scoresRaw / sqrt(dim)
//       attn     = softmax(scores, axis=-1)
//       output   = attn · V
//   - throws same typed errors as chapters 447-449
//     GPU kernels
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed errors + typed key;
//     softmax + scale composition fully in MPSGraph
//   - chapter 二百一一 — one attention GPU kernel
//     under typed key;CPU sibling under different
//     backing-kind key
//   - chapter 三百九二 — replay-determinism (MPSGraph
//     softMax + matMul produce deterministic IEEE
//     Float32 output;byte-equal-within-tolerance to
//     CPU reference)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//   - 红线 7 — observation/computation only
//   - ADR-014 OPT-IN — additive

import Foundation
import Metal
@preconcurrency import MetalPerformanceShadersGraph

/// Real GPU-dispatching scaled dot-product attention
/// via `MPSGraph`。 Single-head;multihead would batch
/// across an outer head dimension。
public actor BASMPSGraphAttentionKernel: BASMetalKernel {

    public nonisolated let key: BASKernelKey =
        BASKernelKey(
            operation: .attention,
            dataType: .float32,
            backingKind: .metalBuffer)

    private let device: any MTLDevice
    private let commandQueue: any MTLCommandQueue

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
        guard inputs.descriptors.count == 3 else {
            throw BASKernelError.shapeMismatch(
                reason: "attention expects 3 inputs" +
                " (Q,K,V);got" +
                " \(inputs.descriptors.count)")
        }
        let descQ = inputs.descriptors[0]
        let descK = inputs.descriptors[1]
        let descV = inputs.descriptors[2]
        for d in inputs.descriptors {
            guard d.dataType == .float32 else {
                throw BASKernelError.dataTypeMismatch(
                    expected: .float32,
                    actual: d.dataType)
            }
        }
        guard descQ.shape.count == 2,
              descK.shape.count == 2,
              descV.shape.count == 2 else {
            throw BASKernelError.shapeMismatch(
                reason: "attention expects rank-2 Q/K/V")
        }
        let seqQ = descQ.shape[0]
        let dim = descQ.shape[1]
        let seqK = descK.shape[0]
        guard descK.shape[1] == dim,
              descV.shape[0] == seqK,
              descV.shape[1] == dim else {
            throw BASKernelError.shapeMismatch(
                reason: "attention shape mismatch;" +
                " expected Q=(sQ,D),K=(sK,D),V=(sK,D)")
        }
        let startTick = DispatchTime.now()
            .uptimeNanoseconds

        let qBytes = seqQ * dim * 4
        let kBytes = seqK * dim * 4
        let vBytes = seqK * dim * 4
        let outBytes = seqQ * dim * 4

        guard let qBuf = inputs.payloads[0]
            .withUnsafeBytes({ raw in
                device.makeBuffer(
                    bytes: raw.baseAddress!,
                    length: qBytes,
                    options: .storageModeShared)
            })
        else {
            throw BASKernelError
                .deviceDispatchFailure(
                    reason: "alloc Q failed")
        }
        guard let kBuf = inputs.payloads[1]
            .withUnsafeBytes({ raw in
                device.makeBuffer(
                    bytes: raw.baseAddress!,
                    length: kBytes,
                    options: .storageModeShared)
            })
        else {
            throw BASKernelError
                .deviceDispatchFailure(
                    reason: "alloc K failed")
        }
        guard let vBuf = inputs.payloads[2]
            .withUnsafeBytes({ raw in
                device.makeBuffer(
                    bytes: raw.baseAddress!,
                    length: vBytes,
                    options: .storageModeShared)
            })
        else {
            throw BASKernelError
                .deviceDispatchFailure(
                    reason: "alloc V failed")
        }
        guard let outBuf = device.makeBuffer(
            length: outBytes,
            options: .storageModeShared)
        else {
            throw BASKernelError
                .deviceDispatchFailure(
                    reason: "alloc output failed")
        }

        // Build attention graph
        let graph = MPSGraph()
        let qP = graph.placeholder(
            shape: [NSNumber(value: seqQ),
                    NSNumber(value: dim)],
            dataType: .float32, name: "Q")
        let kP = graph.placeholder(
            shape: [NSNumber(value: seqK),
                    NSNumber(value: dim)],
            dataType: .float32, name: "K")
        let vP = graph.placeholder(
            shape: [NSNumber(value: seqK),
                    NSNumber(value: dim)],
            dataType: .float32, name: "V")
        // K^T: (dim, seqK)
        let kT = graph.transposeTensor(
            kP,
            dimension: 0,
            withDimension: 1,
            name: "kT")
        // scoresRaw = Q · K^T: (seqQ, seqK)
        let scoresRaw = graph.matrixMultiplication(
            primary: qP,
            secondary: kT,
            name: "scoresRaw")
        // scale = 1 / sqrt(dim)
        let scale = graph.constant(
            1.0 / sqrt(Double(dim)),
            shape: [1, 1],
            dataType: .float32)
        let scores = graph.multiplication(
            scoresRaw, scale, name: "scores")
        // softmax row-wise (axis=-1 → axis=1 for rank-2)
        let attn = graph.softMax(
            with: scores, axis: 1, name: "attn")
        // output = attn · V: (seqQ, dim)
        let output = graph.matrixMultiplication(
            primary: attn,
            secondary: vP,
            name: "output")

        let qTD = MPSGraphTensorData(
            qBuf,
            shape: [NSNumber(value: seqQ),
                    NSNumber(value: dim)],
            dataType: .float32)
        let kTD = MPSGraphTensorData(
            kBuf,
            shape: [NSNumber(value: seqK),
                    NSNumber(value: dim)],
            dataType: .float32)
        let vTD = MPSGraphTensorData(
            vBuf,
            shape: [NSNumber(value: seqK),
                    NSNumber(value: dim)],
            dataType: .float32)
        let outTD = MPSGraphTensorData(
            outBuf,
            shape: [NSNumber(value: seqQ),
                    NSNumber(value: dim)],
            dataType: .float32)

        graph.run(
            with: commandQueue,
            feeds: [
                qP: qTD,
                kP: kTD,
                vP: vTD
            ],
            targetOperations: nil,
            resultsDictionary: [output: outTD])

        let outData = Data(
            bytes: outBuf.contents(),
            count: outBytes)

        let endTick = DispatchTime.now()
            .uptimeNanoseconds
        let elapsed = endTick &- startTick

        let outDesc = BASTensorDescriptor.contiguous(
            shape: [seqQ, dim],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: _2D.rankTag)
        return BASKernelOutputs(
            descriptors: [outDesc],
            payloads: [outData],
            executionNanos: elapsed)
    }
}
