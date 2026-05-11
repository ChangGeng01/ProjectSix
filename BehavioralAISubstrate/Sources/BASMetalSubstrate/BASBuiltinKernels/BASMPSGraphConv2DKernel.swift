// MARK: - BASMPSGraphConv2DKernel
// chapter 四百七十九 / M1294 — closes missing-conv2D gap
//
// Real GPU-dispatching 2D convolution via `MPSGraph`。
// 7th MPSGraph kernel to ship numerical-correctness PROOF。
// Brings BASNeuralOp coverage from 6-of-8 to 7-of-8。
// (ssmScan reserved for Tier 2 chapter 496。)
//
// Shape contract:
//   - input:rank-4 NHWC `[batch, height, width, inChannels]`
//   - weights:rank-4 HWIO `[kernelH, kernelW, inChannels, outChannels]`
//   - output:rank-4 NHWC `[batch, outH, outW, outChannels]`
//
// With stride=1 + padding=valid:outH = H − Hk + 1,
// outW = W − Wk + 1。
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — kernel is observation/computation
//   - chapter 一百八十五 — typed rank-4 inputs
//   - chapter 二百一一 — single source-of-truth for
//     conv2D GPU dispatch
//   - chapter 三百九二 — same inputs → same outputs
//     within IEEE Float32 tolerance
//   - ADR-014 OPT-IN — purely additive

import Foundation
import Metal
@preconcurrency import MetalPerformanceShadersGraph

/// Real GPU-dispatching 2D convolution via
/// `MPSGraph.convolution2D(...)`。 NHWC layout + valid
/// padding + stride 1。
public actor BASMPSGraphConv2DKernel: BASMetalKernel {

    public nonisolated let key: BASKernelKey =
        BASKernelKey(
            operation: .conv2D,
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
        guard inputs.descriptors.count == 2 else {
            throw BASKernelError.shapeMismatch(
                reason: "conv2D expects 2 inputs" +
                " (input + weights);got" +
                " \(inputs.descriptors.count)")
        }
        let descIn = inputs.descriptors[0]
        let descW = inputs.descriptors[1]
        for d in inputs.descriptors {
            guard d.dataType == .float32 else {
                throw BASKernelError.dataTypeMismatch(
                    expected: .float32,
                    actual: d.dataType)
            }
        }
        guard descIn.shape.count == 4 else {
            throw BASKernelError.shapeMismatch(
                reason: "conv2D input must be rank-4" +
                " (NHWC);got rank \(descIn.shape.count)")
        }
        guard descW.shape.count == 4 else {
            throw BASKernelError.shapeMismatch(
                reason: "conv2D weights must be rank-4" +
                " (HWIO);got rank \(descW.shape.count)")
        }
        let n = descIn.shape[0]
        let h = descIn.shape[1]
        let w = descIn.shape[2]
        let cin = descIn.shape[3]
        let hk = descW.shape[0]
        let wk = descW.shape[1]
        let cinW = descW.shape[2]
        let cout = descW.shape[3]
        guard cinW == cin else {
            throw BASKernelError.shapeMismatch(
                reason: "conv2D weights inChannels" +
                " (\(cinW)) must equal input channels" +
                " (\(cin))")
        }
        guard h >= hk, w >= wk else {
            throw BASKernelError.shapeMismatch(
                reason: "conv2D kernel \(hk)×\(wk)" +
                " larger than input \(h)×\(w)")
        }
        let outH = h - hk + 1
        let outW = w - wk + 1

        let startTick = DispatchTime.now()
            .uptimeNanoseconds
        let inBytes = n * h * w * cin * 4
        let wBytes = hk * wk * cin * cout * 4
        let outBytes = n * outH * outW * cout * 4

        guard let bufferIn = inputs.payloads[0]
            .withUnsafeBytes({ raw in
                device.makeBuffer(
                    bytes: raw.baseAddress!,
                    length: inBytes,
                    options: .storageModeShared)
            })
        else {
            throw BASKernelError.deviceDispatchFailure(
                reason: "alloc input failed")
        }
        guard let bufferW = inputs.payloads[1]
            .withUnsafeBytes({ raw in
                device.makeBuffer(
                    bytes: raw.baseAddress!,
                    length: wBytes,
                    options: .storageModeShared)
            })
        else {
            throw BASKernelError.deviceDispatchFailure(
                reason: "alloc weights failed")
        }
        guard let bufferOut = device.makeBuffer(
            length: outBytes,
            options: .storageModeShared)
        else {
            throw BASKernelError.deviceDispatchFailure(
                reason: "alloc output failed")
        }

        // Build the conv2D graph fresh per call
        // (caching deferred to chapter 480 M1296)
        let graph = MPSGraph()
        let inPlaceholder = graph.placeholder(
            shape: [NSNumber(value: n),
                    NSNumber(value: h),
                    NSNumber(value: w),
                    NSNumber(value: cin)],
            dataType: .float32, name: "in")
        let wPlaceholder = graph.placeholder(
            shape: [NSNumber(value: hk),
                    NSNumber(value: wk),
                    NSNumber(value: cin),
                    NSNumber(value: cout)],
            dataType: .float32, name: "weights")
        let convDesc = MPSGraphConvolution2DOpDescriptor(
            strideInX: 1,
            strideInY: 1,
            dilationRateInX: 1,
            dilationRateInY: 1,
            groups: 1,
            paddingStyle: .TF_VALID,
            dataLayout: .NHWC,
            weightsLayout: .HWIO)!
        let output = graph.convolution2D(
            inPlaceholder,
            weights: wPlaceholder,
            descriptor: convDesc,
            name: "output")

        // Wrap MTLBuffers
        let inTensorData = MPSGraphTensorData(
            bufferIn,
            shape: [NSNumber(value: n),
                    NSNumber(value: h),
                    NSNumber(value: w),
                    NSNumber(value: cin)],
            dataType: .float32)
        let wTensorData = MPSGraphTensorData(
            bufferW,
            shape: [NSNumber(value: hk),
                    NSNumber(value: wk),
                    NSNumber(value: cin),
                    NSNumber(value: cout)],
            dataType: .float32)
        let outTensorData = MPSGraphTensorData(
            bufferOut,
            shape: [NSNumber(value: n),
                    NSNumber(value: outH),
                    NSNumber(value: outW),
                    NSNumber(value: cout)],
            dataType: .float32)

        graph.run(
            with: commandQueue,
            feeds: [
                inPlaceholder: inTensorData,
                wPlaceholder: wTensorData
            ],
            targetOperations: nil,
            resultsDictionary: [output: outTensorData])

        let outData = Data(
            bytes: bufferOut.contents(),
            count: outBytes)
        let elapsed = DispatchTime.now()
            .uptimeNanoseconds &- startTick

        let outDesc = BASTensorDescriptor.contiguous(
            shape: [n, outH, outW, cout],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: _4D.rankTag)
        return BASKernelOutputs(
            descriptors: [outDesc],
            payloads: [outData],
            executionNanos: elapsed)
    }
}
