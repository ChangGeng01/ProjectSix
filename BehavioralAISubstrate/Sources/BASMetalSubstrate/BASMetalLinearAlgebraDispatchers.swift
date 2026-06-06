// MARK: - BASMetalLinearAlgebraDispatchers
// 主线 全面 开发: Metal GPU kernel dispatchers for
// RMSNorm + MatMul,aligned with the blueprint
// "Metal owns: embedding similarity / SSM / attention
// / RMSNorm / MatMul / GPU kernel"。
//
// Both kernels live in SSMScan.metal alongside the
// existing ssm_scan_float32 + vector_cosine_similarity
// kernels — one MTLLibrary,multiple kernels,one
// memoized compile cost。

import Foundation
#if canImport(Metal)
import Metal
#endif

// MARK: - RMSNorm

public enum BASMetalRMSNormDispatcherError: Error,
    Equatable, Sendable, Codable
{
    case metalUnavailableOnPlatform
    case libraryUnavailable(message: String)
    case functionNotFound(name: String)
    case commandQueueCreationFailed
    case pipelineCreationFailed(message: String)
    case bufferAllocationFailed(name: String)
    case zeroLengthVector
    /// GPU command buffer completed with a fault
    /// (`MTLCommandBuffer.error` was non-nil)。 The zero-
    /// filled output buffer is NOT a valid result — throw
    /// rather than return it as success。
    case commandBufferFailed(message: String)

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
        case .zeroLengthVector:
            return "zeroLengthVector"
        case .commandBufferFailed:
            return "commandBufferFailed"
        }
    }
}

/// Actor dispatching the `vector_rmsnorm` MSL kernel
/// for Root Mean Square layer normalization。
public actor BASMetalRMSNormDispatcher {

    public static let kernelSymbolName: String =
        "vector_rmsnorm"

    /// Numerical stability epsilon added under the square
    /// root before reciprocal — matches the standard
    /// rmsnorm convention used by Llama/Mamba families。
    public static let defaultEpsilon: Float = 1e-6

    private let loader: BASMetalKernelLibraryLoader

    #if canImport(Metal)
    private var pipeline: MTLComputePipelineState?
    private var commandQueue: MTLCommandQueue?
    #endif

    public init(loader: BASMetalKernelLibraryLoader) {
        self.loader = loader
    }

    public var hasMemoizedPipeline: Bool {
        #if canImport(Metal)
        return pipeline != nil
        #else
        return false
        #endif
    }

    /// Compute y[i] = x[i] / sqrt(mean(x²) + eps)。
    /// Two-pass:CPU computes sum_sq + inv_rms,GPU
    /// scales。
    public func dispatch(
        x: [Float],
        epsilon: Float = BASMetalRMSNormDispatcher
            .defaultEpsilon
    ) async throws -> [Float] {
        #if canImport(Metal)
        guard !x.isEmpty else {
            throw BASMetalRMSNormDispatcherError
                .zeroLengthVector
        }
        let n = x.count
        // Pass 1: CPU sum-of-squares
        var sumSq: Float = 0
        for v in x { sumSq += v * v }
        let meanSq = sumSq / Float(n)
        let invRms = 1.0 / sqrtf(meanSq + epsilon)
        let library: MTLLibrary
        do {
            library = try await loader.library()
        } catch {
            throw BASMetalRMSNormDispatcherError
                .libraryUnavailable(
                    message: String(describing: error))
        }
        let device = library.device
        if pipeline == nil {
            guard let function = library.makeFunction(
                name: Self.kernelSymbolName)
            else {
                throw BASMetalRMSNormDispatcherError
                    .functionNotFound(
                        name: Self.kernelSymbolName)
            }
            do {
                pipeline = try await device
                    .makeComputePipelineState(
                        function: function)
            } catch {
                throw BASMetalRMSNormDispatcherError
                    .pipelineCreationFailed(
                        message: String(describing: error))
            }
        }
        guard let pipeline else {
            throw BASMetalRMSNormDispatcherError
                .pipelineCreationFailed(
                    message: "pipeline nil")
        }
        if commandQueue == nil {
            commandQueue = device.makeCommandQueue()
        }
        guard let commandQueue else {
            throw BASMetalRMSNormDispatcherError
                .commandQueueCreationFailed
        }
        let xBuf = try makeFloatBuffer(
            device: device, floats: x, name: "x")
        let zeros = [Float](repeating: 0, count: n)
        let yBuf = try makeFloatBuffer(
            device: device, floats: zeros, name: "y")
        // RMSNormShape struct {uint N, float inv_rms}
        // = 4 + 4 = 8 bytes, naturally aligned。
        var shape = RMSNormShape(
            N: UInt32(n), invRms: invRms)
        guard let shapeBuf = device.makeBuffer(
            bytes: &shape,
            length: MemoryLayout<RMSNormShape>.size,
            options: [])
        else {
            throw BASMetalRMSNormDispatcherError
                .bufferAllocationFailed(name: "shape")
        }
        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf
                .makeComputeCommandEncoder()
        else {
            throw BASMetalRMSNormDispatcherError
                .commandQueueCreationFailed
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(xBuf, offset: 0, index: 0)
        encoder.setBuffer(yBuf, offset: 0, index: 1)
        encoder.setBuffer(shapeBuf, offset: 0, index: 2)
        let gridSize = MTLSize(
            width: n, height: 1, depth: 1)
        let groupSize = MTLSize(
            width: 1, height: 1, depth: 1)
        encoder.dispatchThreads(
            gridSize, threadsPerThreadgroup: groupSize)
        encoder.endEncoding()
        // Resume by THROWING when the GPU faults — a non-nil
        // commandBuffer.error means the zero-filled output is
        // garbage, not a valid result。 Success path resumes
        // with the unchanged output buffer。
        try await withCheckedThrowingContinuation {
            (cont: CheckedContinuation<Void, Error>) in
            cmdBuf.addCompletedHandler { buffer in
                if let err = buffer.error {
                    cont.resume(throwing:
                        BASMetalRMSNormDispatcherError
                            .commandBufferFailed(
                                message:
                                    err.localizedDescription))
                } else {
                    cont.resume()
                }
            }
            cmdBuf.commit()
        }
        let yPtr = yBuf.contents().bindMemory(
            to: Float.self, capacity: n)
        return Array(UnsafeBufferPointer(
            start: yPtr, count: n))
        #else
        throw BASMetalRMSNormDispatcherError
            .metalUnavailableOnPlatform
        #endif
    }

    #if canImport(Metal)
    private struct RMSNormShape {
        let N: UInt32
        let invRms: Float
    }

    private func makeFloatBuffer(
        device: MTLDevice,
        floats: [Float],
        name: String
    ) throws -> MTLBuffer {
        guard let buf = floats.withUnsafeBufferPointer({
            ptr -> MTLBuffer? in
            device.makeBuffer(
                bytes: ptr.baseAddress!,
                length: floats.count
                    * MemoryLayout<Float>.size,
                options: [])
        })
        else {
            throw BASMetalRMSNormDispatcherError
                .bufferAllocationFailed(name: name)
        }
        return buf
    }
    #endif
}

// MARK: - MatMul

public enum BASMetalMatMulDispatcherError: Error,
    Equatable, Sendable, Codable
{
    case metalUnavailableOnPlatform
    case libraryUnavailable(message: String)
    case functionNotFound(name: String)
    case commandQueueCreationFailed
    case pipelineCreationFailed(message: String)
    case bufferAllocationFailed(name: String)
    case shapeMismatch(
        message: String)
    case zeroDimension
    /// GPU command buffer completed with a fault
    /// (`MTLCommandBuffer.error` was non-nil)。 The zero-
    /// filled output buffer is NOT a valid result — throw
    /// rather than return it as success。
    case commandBufferFailed(message: String)

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
        case .shapeMismatch:
            return "shapeMismatch"
        case .zeroDimension:
            return "zeroDimension"
        case .commandBufferFailed:
            return "commandBufferFailed"
        }
    }
}

/// Actor dispatching the `matmul_float32` MSL kernel
/// for small dense matrix multiplication。 Each GPU
/// thread computes ONE output cell C[i,j]。
public actor BASMetalMatMulDispatcher {

    public static let kernelSymbolName: String =
        "matmul_float32"

    private let loader: BASMetalKernelLibraryLoader

    #if canImport(Metal)
    private var pipeline: MTLComputePipelineState?
    private var commandQueue: MTLCommandQueue?
    #endif

    public init(loader: BASMetalKernelLibraryLoader) {
        self.loader = loader
    }

    public var hasMemoizedPipeline: Bool {
        #if canImport(Metal)
        return pipeline != nil
        #else
        return false
        #endif
    }

    /// Compute C = A · B where:
    ///   A is M × K row-major
    ///   B is K × N row-major
    ///   C is M × N row-major (returned)
    ///
    /// Throws on shape mismatch or zero dimension。
    public func dispatch(
        a: [Float], aRows: Int, aCols: Int,
        b: [Float], bRows: Int, bCols: Int
    ) async throws -> [Float] {
        #if canImport(Metal)
        guard aRows > 0, aCols > 0, bCols > 0 else {
            throw BASMetalMatMulDispatcherError
                .zeroDimension
        }
        guard aCols == bRows else {
            throw BASMetalMatMulDispatcherError
                .shapeMismatch(
                    message: "aCols (\(aCols))" +
                        " != bRows (\(bRows))")
        }
        guard a.count == aRows * aCols else {
            throw BASMetalMatMulDispatcherError
                .shapeMismatch(
                    message: "a.count" +
                        " (\(a.count))" +
                        " != aRows * aCols" +
                        " (\(aRows * aCols))")
        }
        guard b.count == bRows * bCols else {
            throw BASMetalMatMulDispatcherError
                .shapeMismatch(
                    message: "b.count" +
                        " (\(b.count))" +
                        " != bRows * bCols" +
                        " (\(bRows * bCols))")
        }
        let library: MTLLibrary
        do {
            library = try await loader.library()
        } catch {
            throw BASMetalMatMulDispatcherError
                .libraryUnavailable(
                    message: String(describing: error))
        }
        let device = library.device
        if pipeline == nil {
            guard let function = library.makeFunction(
                name: Self.kernelSymbolName)
            else {
                throw BASMetalMatMulDispatcherError
                    .functionNotFound(
                        name: Self.kernelSymbolName)
            }
            do {
                pipeline = try await device
                    .makeComputePipelineState(
                        function: function)
            } catch {
                throw BASMetalMatMulDispatcherError
                    .pipelineCreationFailed(
                        message: String(describing: error))
            }
        }
        guard let pipeline else {
            throw BASMetalMatMulDispatcherError
                .pipelineCreationFailed(
                    message: "pipeline nil")
        }
        if commandQueue == nil {
            commandQueue = device.makeCommandQueue()
        }
        guard let commandQueue else {
            throw BASMetalMatMulDispatcherError
                .commandQueueCreationFailed
        }
        let aBuf = try makeFloatBuffer(
            device: device, floats: a, name: "A")
        let bBuf = try makeFloatBuffer(
            device: device, floats: b, name: "B")
        let zeros = [Float](
            repeating: 0, count: aRows * bCols)
        let cBuf = try makeFloatBuffer(
            device: device, floats: zeros, name: "C")
        var shape = MatMulShape(
            M: UInt32(aRows),
            N: UInt32(bCols),
            K: UInt32(aCols))
        guard let shapeBuf = device.makeBuffer(
            bytes: &shape,
            length: MemoryLayout<MatMulShape>.size,
            options: [])
        else {
            throw BASMetalMatMulDispatcherError
                .bufferAllocationFailed(name: "shape")
        }
        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf
                .makeComputeCommandEncoder()
        else {
            throw BASMetalMatMulDispatcherError
                .commandQueueCreationFailed
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(aBuf, offset: 0, index: 0)
        encoder.setBuffer(bBuf, offset: 0, index: 1)
        encoder.setBuffer(cBuf, offset: 0, index: 2)
        encoder.setBuffer(shapeBuf, offset: 0, index: 3)
        let gridSize = MTLSize(
            width: aRows, height: bCols, depth: 1)
        let groupSize = MTLSize(
            width: 1, height: 1, depth: 1)
        encoder.dispatchThreads(
            gridSize, threadsPerThreadgroup: groupSize)
        encoder.endEncoding()
        // Resume by THROWING when the GPU faults — a non-nil
        // commandBuffer.error means the zero-filled output is
        // garbage, not a valid result。 Success path resumes
        // with the unchanged output buffer。
        try await withCheckedThrowingContinuation {
            (cont: CheckedContinuation<Void, Error>) in
            cmdBuf.addCompletedHandler { buffer in
                if let err = buffer.error {
                    cont.resume(throwing:
                        BASMetalMatMulDispatcherError
                            .commandBufferFailed(
                                message:
                                    err.localizedDescription))
                } else {
                    cont.resume()
                }
            }
            cmdBuf.commit()
        }
        let cPtr = cBuf.contents().bindMemory(
            to: Float.self, capacity: aRows * bCols)
        return Array(UnsafeBufferPointer(
            start: cPtr, count: aRows * bCols))
        #else
        throw BASMetalMatMulDispatcherError
            .metalUnavailableOnPlatform
        #endif
    }

    #if canImport(Metal)
    private struct MatMulShape {
        let M: UInt32
        let N: UInt32
        let K: UInt32
    }

    private func makeFloatBuffer(
        device: MTLDevice,
        floats: [Float],
        name: String
    ) throws -> MTLBuffer {
        guard let buf = floats.withUnsafeBufferPointer({
            ptr -> MTLBuffer? in
            device.makeBuffer(
                bytes: ptr.baseAddress!,
                length: floats.count
                    * MemoryLayout<Float>.size,
                options: [])
        })
        else {
            throw BASMetalMatMulDispatcherError
                .bufferAllocationFailed(name: name)
        }
        return buf
    }
    #endif
}
