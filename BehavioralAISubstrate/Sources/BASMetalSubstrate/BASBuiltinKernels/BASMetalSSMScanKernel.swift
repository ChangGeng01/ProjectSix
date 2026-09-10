// MARK: - BASMetalSSMScanKernel
// chapter 六百七十八 / M2089 第一刀 — REAL Metal compute
//                                    kernel actor wrapping
//                                    the chapter 677 / M2085
//                                    SSMScan.metal MSL kernel
//                                    + the chapter 677 / M2087
//                                    BASSSMScanShape typed
//                                    layout。
//
// ## Why "Metal" not "MPSGraph" in the name
//
// Plan-time naming used `BASMPSGraphSSMScanKernel` for
// symmetry with the 7 other MPSGraph kernels (matMul,
// rmsNorm,etc.)。 At implementation time the choice
// switched to raw `MTLComputePipelineState`:
//
//   - MPSGraph CANNOT express sequential cross-time
//     recurrence (h_t = A_bar * h_{t-1} + ...)
//   - The kernel needs a single-thread sequential loop
//     in MSL,not a graph of fused ops
//
// So the actor is named `BASMetalSSMScanKernel` to
// accurately reflect that it's a raw Metal compute
// pipeline,not MPSGraph。 This is the FIRST raw Metal
// compute kernel in the substrate;all prior kernels
// were either CPU stubs or MPSGraph。
//
// ## What this ships (M2089)
//
//   - `BASMetalSSMScanKernel` actor conforming to
//     `BASMetalKernel: Sendable`
//   - Compiles MSL source at init via
//     `device.makeLibrary(source: BASSSMScanMetalShader
//     Source.float32SourceMSL, options: nil)`
//   - typed key `(ssmScan, float32, metalBuffer)` —
//     sibling slot to chapter 496 / M1361 stub key
//     `(ssmScan, float32, metalBuffer)` — but with
//     REAL implementation (not identity scan)
//
// ## Input contract
//
// `evaluate(inputs:)` accepts 5 payloads in this order:
//   0. x      — (B, L, D) float32  input sequence
//   1. delta  — (B, L, D) float32  selective time step
//   2. A      — (D,)      float32  per-channel decay
//   3. B      — (B, L, D) float32  selective input proj
//   4. C      — (B, L, D) float32  selective output proj
//
// Shape (B, L, D) is read from descriptors[0].shape。
// All descriptors must be float32 + metalBuffer backing。
//
// Output:1 payload `y` — (B, L, D) float32 output。
//
// ## Failure modes
//
//   - `.frameworkUnavailable("Metal")` if Metal API
//     unreachable (e.g. watchOS dispatch)
//   - `.frameworkUnavailable("MTLLibrary")` if MSL
//     compilation fails at init
//   - `.frameworkUnavailable("MTLComputePipelineState")`
//     if pipeline state creation fails
//   - `.shapeMismatch(reason:)` if input count != 5 OR
//     shapes don't match the (B,L,D)/D contract
//   - `.dataTypeMismatch(...)` if any input is non-
//     float32
//   - `.deviceDispatchFailure(reason:)` on MTLBuffer
//     allocation OR command buffer execution failure
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed key + typed errors;
//     no magic literals in MSL upload paths
//   - chapter 二百一一 — single source-of-truth (MSL
//     source string is THE compilation input;.metal
//     file is documentation)
//   - chapter 三百九二 — replay-determinism (kernel
//     produces bit-stable IEEE Float32 output for
//     identical inputs;sequential reduction guarantees
//     no FMA-reorder across time steps)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive new kernel — old stub remains at the
//     same key slot via separate test-only injection
//     pending chapter 681 / M2101-M2104 stub repurpose)
//   - ADR-014 OPT-IN — purely additive

import Foundation
import Metal

/// Real GPU-dispatching Mamba selective-scan kernel via
/// raw `MTLComputePipelineState`。 First raw Metal compute
/// kernel in the substrate。
public actor BASMetalSSMScanKernel: BASMetalKernel {

    public nonisolated let key: BASKernelKey =
        BASKernelKey(
            operation: .ssmScan,
            dataType: .float32,
            backingKind: .metalBuffer)

    private let device: any MTLDevice
    private let commandQueue: any MTLCommandQueue
    private let pipelineState: any MTLComputePipelineState

    /// Construct the kernel by compiling the chapter 677
    /// M2085 MSL kernel source at init time。 The actor
    /// caches the compiled `MTLComputePipelineState` so
    /// per-call dispatch only pays buffer allocation +
    /// command-buffer encoding cost (no recompile)。
    public init() throws {
        guard let dev = MTLCreateSystemDefaultDevice()
        else {
            throw BASKernelError.frameworkUnavailable(
                framework: "Metal")
        }
        guard let queue = dev.makeCommandQueue() else {
            throw BASKernelError.frameworkUnavailable(
                framework: "MTLCommandQueue")
        }
        // Compile MSL source string at init。 The Swift
        // mirror at BASSSMScanMetalShaderSource.float32
        // SourceMSL is the source of truth (the .metal
        // file is documentation reference)。
        let library: any MTLLibrary
        do {
            library = try dev.makeLibrary(
                source: BASSSMScanMetalShaderSource
                    .float32SourceMSL,
                options: nil)
        } catch {
            throw BASKernelError.frameworkUnavailable(
                framework:
                    "MTLLibrary (SSMScan.metal " +
                    "compilation failed:" +
                    "\(error.localizedDescription))")
        }
        guard let function = library.makeFunction(
            name: BASSSMScanMetalShaderSource
                .float32KernelName)
        else {
            throw BASKernelError.frameworkUnavailable(
                framework: "MTLFunction " +
                    "(ssm_scan_float32 not found in " +
                    "compiled library)")
        }
        let pipeline: any MTLComputePipelineState
        do {
            pipeline = try dev
                .makeComputePipelineState(function: function)
        } catch {
            throw BASKernelError.frameworkUnavailable(
                framework: "MTLComputePipelineState " +
                    "creation failed:" +
                    "\(error.localizedDescription)")
        }
        self.device = dev
        self.commandQueue = queue
        self.pipelineState = pipeline
    }

    public func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        // Validate input bundle shape
        guard inputs.descriptors.count == 5 else {
            throw BASKernelError.shapeMismatch(
                reason: "ssmScan expects 5 inputs " +
                "(x,delta,A,B,C);got " +
                "\(inputs.descriptors.count)")
        }
        for d in inputs.descriptors {
            guard d.dataType == .float32 else {
                throw BASKernelError.dataTypeMismatch(
                    expected: .float32,
                    actual: d.dataType)
            }
        }
        let descX = inputs.descriptors[0]
        let descDelta = inputs.descriptors[1]
        let descA = inputs.descriptors[2]
        let descB = inputs.descriptors[3]
        let descC = inputs.descriptors[4]

        // x/delta/B/C are rank-3 (B, L, D)
        guard descX.shape.count == 3 else {
            throw BASKernelError.shapeMismatch(
                reason: "ssmScan x must be rank-3 (B,L,D)" +
                ";got rank \(descX.shape.count)")
        }
        // A is rank-1 (D,)
        guard descA.shape.count == 1 else {
            throw BASKernelError.shapeMismatch(
                reason: "ssmScan A must be rank-1 (D,)" +
                ";got rank \(descA.shape.count)")
        }
        // delta/B/C must match x's shape
        for (name, desc) in [
            ("delta", descDelta),
            ("B", descB),
            ("C", descC)
        ] {
            guard desc.shape == descX.shape else {
                throw BASKernelError.shapeMismatch(
                    reason: "ssmScan \(name) shape " +
                    "\(desc.shape) must equal x shape " +
                    "\(descX.shape)")
            }
        }
        let batch = descX.shape[0]
        let length = descX.shape[1]
        let channels = descX.shape[2]
        // A's D must match x's D
        guard descA.shape[0] == channels else {
            throw BASKernelError.shapeMismatch(
                reason: "ssmScan A (\(descA.shape[0])) " +
                "must equal x channels (\(channels))")
        }

        let shape = try BASSSMScanShape.validated(
            B: UInt32(batch),
            L: UInt32(length),
            D: UInt32(channels))

        let startTick = DispatchTime.now()
            .uptimeNanoseconds

        let payloadByteCount = shape.payloadByteCount
        let aByteCount = shape.aBufferByteCount

        // Upload CPU bytes → MTLBuffers
        let bufX = try makeBuffer(
            from: inputs.payloads[0],
            byteCount: payloadByteCount,
            label: "x")
        let bufDelta = try makeBuffer(
            from: inputs.payloads[1],
            byteCount: payloadByteCount,
            label: "delta")
        let bufA = try makeBuffer(
            from: inputs.payloads[2],
            byteCount: aByteCount,
            label: "A")
        let bufB = try makeBuffer(
            from: inputs.payloads[3],
            byteCount: payloadByteCount,
            label: "B")
        let bufC = try makeBuffer(
            from: inputs.payloads[4],
            byteCount: payloadByteCount,
            label: "C")
        guard let bufY = device.makeBuffer(
            length: payloadByteCount,
            options: .storageModeShared)
        else {
            throw BASKernelError.deviceDispatchFailure(
                reason: "failed to allocate output y")
        }

        // Allocate shape constant buffer (MemoryLayout size)
        var shapeStruct = shape
        guard let bufShape = withUnsafeBytes(
            of: &shapeStruct,
            { raw -> (any MTLBuffer)? in
                device.makeBuffer(
                    bytes: raw.baseAddress!,
                    length: MemoryLayout<BASSSMScanShape>
                        .size,
                    options: .storageModeShared)
            })
        else {
            throw BASKernelError.deviceDispatchFailure(
                reason: "failed to allocate shape buffer")
        }

        // Encode + dispatch
        guard let cmdBuf = commandQueue.makeCommandBuffer()
        else {
            throw BASKernelError.deviceDispatchFailure(
                reason: "failed to make command buffer")
        }
        guard let encoder =
            cmdBuf.makeComputeCommandEncoder()
        else {
            throw BASKernelError.deviceDispatchFailure(
                reason: "failed to make compute encoder")
        }
        encoder.setComputePipelineState(pipelineState)
        encoder.setBuffer(bufX,     offset: 0, index: 0)
        encoder.setBuffer(bufDelta, offset: 0, index: 1)
        encoder.setBuffer(bufA,     offset: 0, index: 2)
        encoder.setBuffer(bufB,     offset: 0, index: 3)
        encoder.setBuffer(bufC,     offset: 0, index: 4)
        encoder.setBuffer(bufY,     offset: 0, index: 5)
        encoder.setBuffer(bufShape, offset: 0, index: 6)

        // Threadgroup dispatch:1 thread per (b, d) pair
        let gridSize = MTLSize(
            width: batch,
            height: channels,
            depth: 1)
        // Threadgroup size:simple 1×1×1 — each (b, d)
        // thread is independent except for its own
        // sequential time loop。
        let threadgroupSize = MTLSize(
            width: 1,
            height: 1,
            depth: 1)
        encoder.dispatchThreads(
            gridSize,
            threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()

        // Use addCompletedHandler + CheckedContinuation to
        // bridge from cmdBuf's MainActor-isolated completion
        // callback to async/await。 Avoids data-race warning
        // on non-Sendable cmdBuf.completed() async surface。
        await withCheckedContinuation {
            (cont: CheckedContinuation<Void, Never>) in
            cmdBuf.addCompletedHandler { _ in
                cont.resume()
            }
            cmdBuf.commit()
        }

        if let error = cmdBuf.error {
            throw BASKernelError.deviceDispatchFailure(
                reason:
                    "command buffer error:" +
                    "\(error.localizedDescription)")
        }

        // Download y bytes back to Data
        let yPointer = bufY.contents()
            .assumingMemoryBound(to: UInt8.self)
        let yData = Data(
            bytes: yPointer,
            count: payloadByteCount)

        let endTick = DispatchTime.now().uptimeNanoseconds
        let elapsedNanos = endTick - startTick

        // Build output bundle — single output `y` with
        // the same descriptor shape as input x。 Reuse
        // descX's rankTag since y is the same rank-3
        // (B, L, D) shape category。
        let yDescriptor = BASTensorDescriptor.contiguous(
            shape: descX.shape,
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: descX.rankTag)

        return BASKernelOutputs(
            descriptors: [yDescriptor],
            payloads: [yData],
            executionNanos: elapsedNanos)
    }

    /// Helper to upload payload bytes to MTLBuffer with
    /// strict byte-count validation。
    private func makeBuffer(
        from data: Data,
        byteCount: Int,
        label: String
    ) throws -> any MTLBuffer {
        guard data.count == byteCount else {
            throw BASKernelError.shapeMismatch(
                reason: "ssmScan \(label) payload " +
                "(\(data.count) bytes) must equal " +
                "expected (\(byteCount) bytes)")
        }
        guard let buf = data.withUnsafeBytes({
            raw -> (any MTLBuffer)? in
            device.makeBuffer(
                bytes: raw.baseAddress!,
                length: byteCount,
                options: .storageModeShared)
        }) else {
            throw BASKernelError.deviceDispatchFailure(
                reason: "failed to allocate \(label) " +
                "MTLBuffer")
        }
        return buf
    }
}
