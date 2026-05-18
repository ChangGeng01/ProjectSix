// MARK: - BASMetalSSMScanDispatcher
// 主线 全面 开发: Metal pilot graduates from "load + compile
// + memoize" to "actually DISPATCH the SSMScan kernel on
// the GPU"。 Real Float32 GPU compute,produced from the
// kernel source compiled at warmMetalKernel() time。
//
// **The journey of the Metal pilot**:
//
//   Round 0 (chapter 七百四):   load + compile only
//   Round 1 (主线 提升):        + brain.warmMetalKernel()
//                                memoize → 1700× speedup
//   Round 2 (主线 解构):        + compiledFunctionNames()
//                                MTLLibrary introspection
//   Round 3 (主线 全面 开发):    + dispatch SSMScan compute
//                                kernel on GPU (this file)
//
// After this commit,Metal goes from "passive library
// accessor" to "real compute target"。
//
// ## What this dispatcher does
//
// Given `BASSSMScanShape` + input buffers (x / delta / A
// / B / C),encodes a Metal compute dispatch invoking
// `ssm_scan_float32` from the loaded MTLLibrary。 Returns
// the output `y` buffer。 The math is identical to the
// CPU reference (BASSSMScanCPUReference);GPU produces
// the same results within IEEE float32 + sequential-
// reduction tolerance (MAE ≤ 1e-5 per chapter 392).
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3 — dispatch is observation +
//     numerical compute,never mutates host runtime
//     governance
//   - 红线 7 — no permit / watcher gate touched
//   - chapter 477 ADR-014 OPT-IN — loader is opt-in,
//     dispatch is gated by the same loader's V2 mode
//   - chapter 392 replay-determinism — same inputs
//     produce same outputs across runs
//   - chapter 一百八十五 anti-magic — typed errors,
//     not raw return codes

import Foundation
#if canImport(Metal)
import Metal
#endif

/// Typed errors from the Metal SSMScan dispatcher。
public enum BASMetalSSMScanDispatcherError: Error,
    Equatable, Sendable, Codable
{
    /// `canImport(Metal)` was false at build time。
    case metalUnavailableOnPlatform

    /// Loader returned no library (V1 path or compile
    /// failed)。
    case libraryUnavailable(message: String)

    /// `ssm_scan_float32` function symbol absent from the
    /// compiled library。
    case functionNotFound(name: String)

    /// Failed to create MTLCommandQueue。
    case commandQueueCreationFailed

    /// Failed to create MTLComputePipelineState (kernel
    /// likely has a signature mismatch with our buffer
    /// bindings)。
    case pipelineCreationFailed(message: String)

    /// Failed to allocate one of the MTLBuffers (e.g.
    /// shape would exceed device memory)。
    case bufferAllocationFailed(name: String)

    /// Input array's count doesn't match the shape's
    /// expected element count。
    case payloadCountMismatch(
        name: String, expected: Int, actual: Int)

    public var caseIdentifier: String {
        switch self {
        case .metalUnavailableOnPlatform:
            return "metalUnavailableOnPlatform"
        case .libraryUnavailable:
            return "libraryUnavailable"
        case .functionNotFound:
            return "functionNotFound"
        case .commandQueueCreationFailed:
            return "commandQueueCreationFailed"
        case .pipelineCreationFailed:
            return "pipelineCreationFailed"
        case .bufferAllocationFailed:
            return "bufferAllocationFailed"
        case .payloadCountMismatch:
            return "payloadCountMismatch"
        }
    }
}

/// Actor that dispatches the chapter 677 SSMScan kernel
/// on the GPU via the chapter 704 MTLLibrary loader。
///
/// Construction is cheap;the heavy work (kernel function
/// lookup + pipeline state creation) happens lazily on
/// first `dispatch(...)` call and is memoized for
/// subsequent calls。
public actor BASMetalSSMScanDispatcher {

    /// Compiled-kernel symbol name expected in the loaded
    /// library (matches the MSL `kernel void` declaration)。
    public static let kernelSymbolName: String =
        "ssm_scan_float32"

    private let loader: BASMetalKernelLibraryLoader

    #if canImport(Metal)
    /// Memoized pipeline state — built on first dispatch,
    /// reused thereafter。 Same pipeline state is safe to
    /// reuse across encoder instances per Metal docs。
    private var pipeline: MTLComputePipelineState?

    /// Memoized command queue — building one per dispatch
    /// would be wasteful。
    private var commandQueue: MTLCommandQueue?
    #endif

    public init(loader: BASMetalKernelLibraryLoader) {
        self.loader = loader
    }

    /// Whether the dispatcher has memoized its pipeline
    /// state。 Tests use this to assert lazy-init
    /// semantics。
    public var hasMemoizedPipeline: Bool {
        #if canImport(Metal)
        return pipeline != nil
        #else
        return false
        #endif
    }

    /// Dispatch the SSMScan kernel on the GPU and return
    /// the float32 output array y of length (B × L × D)。
    ///
    /// All input arrays must match the shape's element
    /// count (or D-count for A)。 Throws on Metal-side
    /// errors with typed cases — host code can pattern-
    /// match without parsing strings。
    public func dispatch(
        x: [Float],
        delta: [Float],
        A: [Float],
        B: [Float],
        C: [Float],
        shape: BASSSMScanShape
    ) async throws -> [Float] {
        #if canImport(Metal)
        // Validate input lengths first — same checks as
        // the CPU reference for parity。
        let bldCount = shape.elementCount
        let dCount = Int(shape.D)
        if x.count != bldCount {
            throw BASMetalSSMScanDispatcherError
                .payloadCountMismatch(
                    name: "x",
                    expected: bldCount, actual: x.count)
        }
        if delta.count != bldCount {
            throw BASMetalSSMScanDispatcherError
                .payloadCountMismatch(
                    name: "delta",
                    expected: bldCount, actual: delta.count)
        }
        if A.count != dCount {
            throw BASMetalSSMScanDispatcherError
                .payloadCountMismatch(
                    name: "A",
                    expected: dCount, actual: A.count)
        }
        if B.count != bldCount {
            throw BASMetalSSMScanDispatcherError
                .payloadCountMismatch(
                    name: "B",
                    expected: bldCount, actual: B.count)
        }
        if C.count != bldCount {
            throw BASMetalSSMScanDispatcherError
                .payloadCountMismatch(
                    name: "C",
                    expected: bldCount, actual: C.count)
        }
        let library: MTLLibrary
        do {
            library = try await loader.library()
        } catch {
            throw BASMetalSSMScanDispatcherError
                .libraryUnavailable(
                    message: String(describing: error))
        }
        let device = library.device
        // Build / memoize pipeline state
        if pipeline == nil {
            guard let function = library.makeFunction(
                name: Self.kernelSymbolName)
            else {
                throw BASMetalSSMScanDispatcherError
                    .functionNotFound(
                        name: Self.kernelSymbolName)
            }
            do {
                pipeline = try await device
                    .makeComputePipelineState(
                        function: function)
            } catch {
                throw BASMetalSSMScanDispatcherError
                    .pipelineCreationFailed(
                        message: String(describing: error))
            }
        }
        guard let pipeline else {
            throw BASMetalSSMScanDispatcherError
                .pipelineCreationFailed(
                    message: "pipeline still nil")
        }
        // Build / memoize command queue
        if commandQueue == nil {
            commandQueue = device.makeCommandQueue()
        }
        guard let commandQueue else {
            throw BASMetalSSMScanDispatcherError
                .commandQueueCreationFailed
        }
        // Allocate input + output buffers
        let xBuf = try makeBuffer(
            device: device, floats: x, name: "x")
        let deltaBuf = try makeBuffer(
            device: device, floats: delta, name: "delta")
        let aBuf = try makeBuffer(
            device: device, floats: A, name: "A")
        let bBuf = try makeBuffer(
            device: device, floats: B, name: "B")
        let cBuf = try makeBuffer(
            device: device, floats: C, name: "C")
        // Output buffer — pre-zeroed Float32 (B,L,D)
        let zeros = [Float](
            repeating: 0.0, count: bldCount)
        let yBuf = try makeBuffer(
            device: device, floats: zeros, name: "y")
        // Shape buffer:3 contiguous UInt32
        var shapeValues: [UInt32] = [
            shape.B, shape.L, shape.D]
        guard let shapeBuf = device.makeBuffer(
            bytes: &shapeValues,
            length: MemoryLayout<UInt32>.size * 3,
            options: [])
        else {
            throw BASMetalSSMScanDispatcherError
                .bufferAllocationFailed(name: "shape")
        }
        // Encode + dispatch
        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf
                .makeComputeCommandEncoder()
        else {
            throw BASMetalSSMScanDispatcherError
                .commandQueueCreationFailed
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(xBuf,     offset: 0, index: 0)
        encoder.setBuffer(deltaBuf, offset: 0, index: 1)
        encoder.setBuffer(aBuf,     offset: 0, index: 2)
        encoder.setBuffer(bBuf,     offset: 0, index: 3)
        encoder.setBuffer(cBuf,     offset: 0, index: 4)
        encoder.setBuffer(yBuf,     offset: 0, index: 5)
        encoder.setBuffer(shapeBuf, offset: 0, index: 6)
        // Dispatch (B, D, 1) grid with 1×1×1 threadgroup
        // — matches the kernel's per-(b,d) thread layout
        let gridSize = MTLSize(
            width: Int(shape.B),
            height: Int(shape.D),
            depth: 1)
        let groupSize = MTLSize(
            width: 1, height: 1, depth: 1)
        encoder.dispatchThreads(
            gridSize,
            threadsPerThreadgroup: groupSize)
        encoder.endEncoding()
        // Bridge the Metal completion-callback API to
        // async without making MTLCommandBuffer cross the
        // suspension point (it isn't Sendable)。 The
        // continuation resumes from the callback fired by
        // the GPU driver thread。
        await withCheckedContinuation {
            (cont: CheckedContinuation<Void, Never>) in
            cmdBuf.addCompletedHandler { _ in
                cont.resume()
            }
            cmdBuf.commit()
        }
        // Read back
        let yPtr = yBuf.contents().bindMemory(
            to: Float.self, capacity: bldCount)
        return Array(
            UnsafeBufferPointer(
                start: yPtr, count: bldCount))
        #else
        throw BASMetalSSMScanDispatcherError
            .metalUnavailableOnPlatform
        #endif
    }

    #if canImport(Metal)
    private func makeBuffer(
        device: MTLDevice,
        floats: [Float],
        name: String
    ) throws -> MTLBuffer {
        let byteCount =
            floats.count * MemoryLayout<Float>.size
        guard let buf = floats.withUnsafeBufferPointer({
            ptr -> MTLBuffer? in
            device.makeBuffer(
                bytes: ptr.baseAddress!,
                length: byteCount,
                options: [])
        })
        else {
            throw BASMetalSSMScanDispatcherError
                .bufferAllocationFailed(name: name)
        }
        return buf
    }
    #endif
}
