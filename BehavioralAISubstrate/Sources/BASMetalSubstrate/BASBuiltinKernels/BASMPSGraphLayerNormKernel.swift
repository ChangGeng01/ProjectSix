// MARK: - BASMPSGraphLayerNormKernel
// chapter 四百七十九 / M1293 — closes missing-layerNorm gap
//
// Real GPU-dispatching layer normalization via `MPSGraph`。
// 6th MPSGraph kernel to ship numerical-correctness PROOF。
// Brings BASNeuralOp coverage from 5-of-8 to 6-of-8。
//
// Formula:
//   mean_i = mean(x_i)            (per-row mean)
//   var_i = mean((x_i - mean_i)²) (per-row variance)
//   y_ij = (x_ij - mean_i) / sqrt(var_i + eps) * gamma_j
//          + beta_j
//
// Differs from RMSNorm:layerNorm subtracts the per-row
// mean before normalizing,then applies BOTH gamma scale
// AND beta shift。 RMSNorm only divides by RMS (no mean
// subtraction) + only applies gamma。
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — kernel is observation/computation
//   - chapter 一百八十五 — typed inputs (x rank-2 +
//     gamma rank-1 + beta rank-1)
//   - chapter 二百一一 — single source-of-truth for
//     layerNorm GPU dispatch
//   - chapter 三百九二 — same inputs → same outputs
//     within IEEE Float32 reduction tolerance
//   - ADR-014 OPT-IN — purely additive

import Foundation
import Metal
@preconcurrency import MetalPerformanceShadersGraph

/// Real GPU-dispatching layer normalization via
/// `MPSGraph`。 Composes mean-centering + variance +
/// rsqrt + scale + shift。
public actor BASMPSGraphLayerNormKernel: BASMetalKernel {

    public nonisolated let key: BASKernelKey =
        BASKernelKey(
            operation: .layerNorm,
            dataType: .float32,
            backingKind: .metalBuffer)

    /// Numerical-stability epsilon。 Default 1e-5 matches
    /// PyTorch / TensorFlow defaults。
    public nonisolated let epsilon: Float

    private let device: any MTLDevice
    private let commandQueue: any MTLCommandQueue

    public init(epsilon: Float = 1e-5) throws {
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
        guard inputs.descriptors.count == 3 else {
            throw BASKernelError.shapeMismatch(
                reason: "layerNorm expects 3 inputs" +
                " (x, gamma, beta);got" +
                " \(inputs.descriptors.count)")
        }
        let descX = inputs.descriptors[0]
        let descG = inputs.descriptors[1]
        let descB = inputs.descriptors[2]
        for d in inputs.descriptors {
            guard d.dataType == .float32 else {
                throw BASKernelError.dataTypeMismatch(
                    expected: .float32,
                    actual: d.dataType)
            }
        }
        guard descX.shape.count == 2,
              descG.shape.count == 1,
              descB.shape.count == 1 else {
            throw BASKernelError.shapeMismatch(
                reason: "layerNorm expects rank-2 x +" +
                " rank-1 gamma + rank-1 beta")
        }
        let batch = descX.shape[0]
        let hidden = descX.shape[1]
        guard descG.shape[0] == hidden,
              descB.shape[0] == hidden else {
            throw BASKernelError.shapeMismatch(
                reason: "layerNorm gamma/beta length" +
                " must equal x hidden (\(hidden))")
        }

        let startTick = DispatchTime.now()
            .uptimeNanoseconds
        let xBytesCount = batch * hidden * 4
        let gBytesCount = hidden * 4
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
            throw BASKernelError.deviceDispatchFailure(
                reason: "alloc x failed")
        }
        guard let bufferG = inputs.payloads[1]
            .withUnsafeBytes({ raw in
                device.makeBuffer(
                    bytes: raw.baseAddress!,
                    length: gBytesCount,
                    options: .storageModeShared)
            })
        else {
            throw BASKernelError.deviceDispatchFailure(
                reason: "alloc gamma failed")
        }
        guard let bufferB = inputs.payloads[2]
            .withUnsafeBytes({ raw in
                device.makeBuffer(
                    bytes: raw.baseAddress!,
                    length: gBytesCount,
                    options: .storageModeShared)
            })
        else {
            throw BASKernelError.deviceDispatchFailure(
                reason: "alloc beta failed")
        }
        guard let bufferOut = device.makeBuffer(
            length: outBytesCount,
            options: .storageModeShared)
        else {
            throw BASKernelError.deviceDispatchFailure(
                reason: "alloc out failed")
        }

        // Build the layerNorm graph fresh per call
        // (caching deferred to chapter 480 M1296)
        let graph = MPSGraph()
        let xPlaceholder = graph.placeholder(
            shape: [NSNumber(value: batch),
                    NSNumber(value: hidden)],
            dataType: .float32, name: "x")
        let gPlaceholder = graph.placeholder(
            shape: [NSNumber(value: hidden)],
            dataType: .float32, name: "gamma")
        let bPlaceholder = graph.placeholder(
            shape: [NSNumber(value: hidden)],
            dataType: .float32, name: "beta")

        // mean_i = mean(x_i) per row
        let mean = graph.mean(
            of: xPlaceholder,
            axes: [NSNumber(value: 1)],
            name: "mean")
        // centered = x - mean (broadcasts)
        let centered = graph.subtraction(
            xPlaceholder, mean, name: "centered")
        // variance = mean(centered²) per row
        let centeredSq = graph.multiplication(
            centered, centered, name: "centeredSq")
        let variance = graph.mean(
            of: centeredSq,
            axes: [NSNumber(value: 1)],
            name: "variance")
        let epsTensor = graph.constant(
            Double(epsilon),
            shape: [1, 1],
            dataType: .float32)
        let varEps = graph.addition(
            variance, epsTensor, name: "varEps")
        let stddev = graph.squareRoot(
            with: varEps, name: "stddev")
        // normalized = centered / stddev
        let normalized = graph.division(
            centered, stddev, name: "normalized")
        // scaled = normalized * gamma (broadcasts)
        let scaled = graph.multiplication(
            normalized, gPlaceholder, name: "scaled")
        // output = scaled + beta (broadcasts)
        let output = graph.addition(
            scaled, bPlaceholder, name: "output")

        // Wrap MTLBuffers in MPSGraphTensorData
        let xTensorData = MPSGraphTensorData(
            bufferX,
            shape: [NSNumber(value: batch),
                    NSNumber(value: hidden)],
            dataType: .float32)
        let gTensorData = MPSGraphTensorData(
            bufferG,
            shape: [NSNumber(value: hidden)],
            dataType: .float32)
        let bTensorData = MPSGraphTensorData(
            bufferB,
            shape: [NSNumber(value: hidden)],
            dataType: .float32)
        let outTensorData = MPSGraphTensorData(
            bufferOut,
            shape: [NSNumber(value: batch),
                    NSNumber(value: hidden)],
            dataType: .float32)

        graph.run(
            with: commandQueue,
            feeds: [
                xPlaceholder: xTensorData,
                gPlaceholder: gTensorData,
                bPlaceholder: bTensorData
            ],
            targetOperations: nil,
            resultsDictionary: [output: outTensorData])

        let outBytes = Data(
            bytes: bufferOut.contents(),
            count: outBytesCount)
        let elapsed = DispatchTime.now()
            .uptimeNanoseconds &- startTick

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
