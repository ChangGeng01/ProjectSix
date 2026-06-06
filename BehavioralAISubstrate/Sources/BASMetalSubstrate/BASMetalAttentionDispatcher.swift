// MARK: - BASMetalAttentionDispatcher
// 主线 全面 开发: Metal GPU dispatcher for single-head
// scaled dot-product attention。 Closes the last
// blueprint row in Metal's "embedding similarity / SSM
// / attention / RMSNorm / MatMul" group。
//
// Computes:
//   attention(Q, K, V) = softmax(Q · K^T / sqrt(D)) · V
//
// Each GPU thread handles ONE output cell — two passes
// over the sequence inside the kernel (numerically-
// stable softmax via max-subtract trick)。
//
// Honest scope:single-head,no masking,no tiling。 For
// typical chat-shaped sequence lengths this is fast
// enough。 Multi-head + FlashAttention-style tiling are
// follow-up commits。

import Foundation
#if canImport(Metal)
import Metal
#endif

public enum BASMetalAttentionDispatcherError: Error,
    Equatable, Sendable, Codable
{
    case metalUnavailableOnPlatform
    case libraryUnavailable(message: String)
    case functionNotFound(name: String)
    case commandQueueCreationFailed
    case pipelineCreationFailed(message: String)
    case bufferAllocationFailed(name: String)
    case shapeMismatch(message: String)
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

/// Actor dispatching the `scaled_dot_product_attention`
/// MSL kernel for single-head attention。
public actor BASMetalAttentionDispatcher {

    public static let kernelSymbolName: String =
        "scaled_dot_product_attention"

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

    /// Compute attention(Q, K, V) where:
    ///   Q is M × D  (queries)
    ///   K is N × D  (keys, same D as Q)
    ///   V is N × Dv (values, same N as K)
    ///   output is M × Dv
    ///
    /// All matrices are row-major float32 arrays。
    public func dispatch(
        q: [Float], qRows: Int, qCols: Int,
        k: [Float], kRows: Int,
        v: [Float], vCols: Int
    ) async throws -> [Float] {
        #if canImport(Metal)
        guard qRows > 0, qCols > 0,
              kRows > 0, vCols > 0
        else {
            throw BASMetalAttentionDispatcherError
                .zeroDimension
        }
        // Q is M×D, K is N×D, V is N×Dv
        let M = qRows
        let D = qCols
        let N = kRows
        let Dv = vCols
        guard q.count == M * D else {
            throw BASMetalAttentionDispatcherError
                .shapeMismatch(
                    message: "q.count (\(q.count))" +
                        " != M*D (\(M * D))")
        }
        guard k.count == N * D else {
            throw BASMetalAttentionDispatcherError
                .shapeMismatch(
                    message: "k.count (\(k.count))" +
                        " != N*D (\(N * D))")
        }
        guard v.count == N * Dv else {
            throw BASMetalAttentionDispatcherError
                .shapeMismatch(
                    message: "v.count (\(v.count))" +
                        " != N*Dv (\(N * Dv))")
        }
        let library: MTLLibrary
        do {
            library = try await loader.library()
        } catch {
            throw BASMetalAttentionDispatcherError
                .libraryUnavailable(
                    message: String(describing: error))
        }
        let device = library.device
        if pipeline == nil {
            guard let function = library.makeFunction(
                name: Self.kernelSymbolName)
            else {
                throw BASMetalAttentionDispatcherError
                    .functionNotFound(
                        name: Self.kernelSymbolName)
            }
            do {
                pipeline = try await device
                    .makeComputePipelineState(
                        function: function)
            } catch {
                throw BASMetalAttentionDispatcherError
                    .pipelineCreationFailed(
                        message: String(describing: error))
            }
        }
        guard let pipeline else {
            throw BASMetalAttentionDispatcherError
                .pipelineCreationFailed(
                    message: "pipeline nil")
        }
        if commandQueue == nil {
            commandQueue = device.makeCommandQueue()
        }
        guard let commandQueue else {
            throw BASMetalAttentionDispatcherError
                .commandQueueCreationFailed
        }
        let qBuf = try makeFloatBuffer(
            device: device, floats: q, name: "Q")
        let kBuf = try makeFloatBuffer(
            device: device, floats: k, name: "K")
        let vBuf = try makeFloatBuffer(
            device: device, floats: v, name: "V")
        let zeros = [Float](
            repeating: 0, count: M * Dv)
        let outBuf = try makeFloatBuffer(
            device: device, floats: zeros, name: "out")
        var shape = AttentionShape(
            M: UInt32(M),
            N: UInt32(N),
            D: UInt32(D),
            Dv: UInt32(Dv))
        guard let shapeBuf = device.makeBuffer(
            bytes: &shape,
            length: MemoryLayout<AttentionShape>.size,
            options: [])
        else {
            throw BASMetalAttentionDispatcherError
                .bufferAllocationFailed(name: "shape")
        }
        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf
                .makeComputeCommandEncoder()
        else {
            throw BASMetalAttentionDispatcherError
                .commandQueueCreationFailed
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(qBuf, offset: 0, index: 0)
        encoder.setBuffer(kBuf, offset: 0, index: 1)
        encoder.setBuffer(vBuf, offset: 0, index: 2)
        encoder.setBuffer(outBuf, offset: 0, index: 3)
        encoder.setBuffer(shapeBuf, offset: 0, index: 4)
        let gridSize = MTLSize(
            width: M, height: Dv, depth: 1)
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
                        BASMetalAttentionDispatcherError
                            .commandBufferFailed(
                                message:
                                    err.localizedDescription))
                } else {
                    cont.resume()
                }
            }
            cmdBuf.commit()
        }
        let outPtr = outBuf.contents().bindMemory(
            to: Float.self, capacity: M * Dv)
        return Array(UnsafeBufferPointer(
            start: outPtr, count: M * Dv))
        #else
        throw BASMetalAttentionDispatcherError
            .metalUnavailableOnPlatform
        #endif
    }

    #if canImport(Metal)
    private struct AttentionShape {
        let M: UInt32
        let N: UInt32
        let D: UInt32
        let Dv: UInt32
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
            throw BASMetalAttentionDispatcherError
                .bufferAllocationFailed(name: name)
        }
        return buf
    }
    #endif
}
