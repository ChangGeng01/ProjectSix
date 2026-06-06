// MARK: - BASMetalFlashAttentionDispatcher
// chapter 七百七 第一刀 / M2206
//
// Swift dispatcher for the chapter-七百五-第一刀 BASFlashAttention
// .metal tiled-attention kernel family。
//
// WIRED TODAY:only the unmasked forward path —
//
//   - dispatch(q:qRows:qCols:k:kRows:v:vCols:)
//
// NOT YET WIRED:the masked + causal MSL kernels
// (`flash_attention_forward_masked` /
// `flash_attention_forward_causal`) exist in the .metal
// source and their symbol names + pipeline slots
// (`maskedPipeline` / `causalPipeline`) are scaffolded
// below, but no Swift `dispatch(...mask:)` /
// `dispatchCausal(...)` entry point builds those pipelines
// yet。 The scaffolding is intentionally retained for the
// follow-up commit that wires them。
//
// Output is mathematically equivalent to the standard
// `scaled_dot_product_attention` kernel,but uses O(N) memory
// instead of O(N²) — wins on long sequences where the standard
// kernel exhausts threadgroup memory or thrashes the GPU caches。

import Foundation
#if canImport(Metal)
import Metal
#endif

public enum BASMetalFlashAttentionDispatcherError:
    Error, Equatable, Sendable, Codable
{
    case metalUnavailableOnPlatform
    case libraryUnavailable(message: String)
    case functionNotFound(name: String)
    case commandQueueCreationFailed
    case pipelineCreationFailed(message: String)
    case bufferAllocationFailed(name: String)
    case shapeMismatch(message: String)
    case zeroDimension
    case maxHeadDimExceeded(Int)
    case maxTileRowsExceeded(Int)
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
        case .maxHeadDimExceeded:
            return "maxHeadDimExceeded"
        case .maxTileRowsExceeded:
            return "maxTileRowsExceeded"
        case .commandBufferFailed:
            return "commandBufferFailed"
        }
    }
}

/// Tile sizes baked into the .metal kernel (V1)。
public enum BASMetalFlashAttentionTileConfig {
    public static let bR: Int = 32   // query tile rows
    public static let bC: Int = 32   // key/value tile cols
    public static let dMax: Int = 64 // head-dim cap
}

public actor BASMetalFlashAttentionDispatcher {

    public static let forwardSymbol: String =
        "flash_attention_forward"
    public static let maskedSymbol: String =
        "flash_attention_forward_masked"
    public static let causalSymbol: String =
        "flash_attention_forward_causal"

    private let loader: BASMetalKernelLibraryLoader

    #if canImport(Metal)
    private var forwardPipeline: MTLComputePipelineState?
    private var maskedPipeline: MTLComputePipelineState?
    private var causalPipeline: MTLComputePipelineState?
    private var commandQueue: MTLCommandQueue?
    #endif

    public init(loader: BASMetalKernelLibraryLoader) {
        self.loader = loader
    }

    public var hasMemoizedForwardPipeline: Bool {
        #if canImport(Metal)
        return forwardPipeline != nil
        #else
        return false
        #endif
    }

    public func dispatch(
        q: [Float], qRows: Int, qCols: Int,
        k: [Float], kRows: Int,
        v: [Float], vCols: Int
    ) async throws -> [Float] {
        #if canImport(Metal)
        try Self.validateShapes(
            q: q, qRows: qRows, qCols: qCols,
            k: k, kRows: kRows,
            v: v, vCols: vCols)
        let library = try await Self.resolveLibrary(
            loader: loader)
        let device = library.device
        try await ensureForwardPipeline(
            library: library, device: device)
        try ensureCommandQueue(device: device)
        let outputCount = qRows * vCols
        let outBuf = try Self.makeFloatBuffer(
            device: device,
            floats: [Float](
                repeating: 0, count: outputCount),
            name: "out")
        let qBuf = try Self.makeFloatBuffer(
            device: device, floats: q, name: "Q")
        let kBuf = try Self.makeFloatBuffer(
            device: device, floats: k, name: "K")
        let vBuf = try Self.makeFloatBuffer(
            device: device, floats: v, name: "V")
        var shape = FlashAttnShape(
            M: UInt32(qRows), N: UInt32(kRows),
            D: UInt32(qCols), Dv: UInt32(vCols))
        guard let shapeBuf = device.makeBuffer(
            bytes: &shape,
            length: MemoryLayout<FlashAttnShape>.size,
            options: [])
        else {
            throw BASMetalFlashAttentionDispatcherError
                .bufferAllocationFailed(name: "shape")
        }
        guard let pipeline = forwardPipeline,
              let cmdBuf = commandQueue?
                .makeCommandBuffer(),
              let encoder = cmdBuf
                .makeComputeCommandEncoder()
        else {
            throw BASMetalFlashAttentionDispatcherError
                .commandQueueCreationFailed
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(qBuf, offset: 0, index: 0)
        encoder.setBuffer(kBuf, offset: 0, index: 1)
        encoder.setBuffer(vBuf, offset: 0, index: 2)
        encoder.setBuffer(outBuf, offset: 0, index: 3)
        encoder.setBuffer(shapeBuf, offset: 0, index: 4)
        let bR = BASMetalFlashAttentionTileConfig.bR
        let numTiles = (qRows + bR - 1) / bR
        encoder.dispatchThreadgroups(
            MTLSize(width: numTiles, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(
                width: bR, height: 1, depth: 1))
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
                        BASMetalFlashAttentionDispatcherError
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
            to: Float.self, capacity: outputCount)
        return Array(UnsafeBufferPointer(
            start: outPtr, count: outputCount))
        #else
        throw BASMetalFlashAttentionDispatcherError
            .metalUnavailableOnPlatform
        #endif
    }

    // MARK: - Internal helpers

    #if canImport(Metal)
    private struct FlashAttnShape {
        let M: UInt32
        let N: UInt32
        let D: UInt32
        let Dv: UInt32
    }

    private static func validateShapes(
        q: [Float], qRows: Int, qCols: Int,
        k: [Float], kRows: Int,
        v: [Float], vCols: Int
    ) throws {
        guard qRows > 0, qCols > 0, kRows > 0, vCols > 0
        else {
            throw BASMetalFlashAttentionDispatcherError
                .zeroDimension
        }
        guard qCols <= BASMetalFlashAttentionTileConfig.dMax,
              vCols <= BASMetalFlashAttentionTileConfig.dMax
        else {
            throw BASMetalFlashAttentionDispatcherError
                .maxHeadDimExceeded(
                    max(qCols, vCols))
        }
        guard q.count == qRows * qCols else {
            throw BASMetalFlashAttentionDispatcherError
                .shapeMismatch(
                    message:
                        "q.count (\(q.count)) != qRows*qCols")
        }
        guard k.count == kRows * qCols else {
            throw BASMetalFlashAttentionDispatcherError
                .shapeMismatch(
                    message:
                        "k.count (\(k.count)) != kRows*qCols")
        }
        guard v.count == kRows * vCols else {
            throw BASMetalFlashAttentionDispatcherError
                .shapeMismatch(
                    message:
                        "v.count (\(v.count)) != kRows*vCols")
        }
    }

    private static func resolveLibrary(
        loader: BASMetalKernelLibraryLoader
    ) async throws -> MTLLibrary {
        do {
            return try await loader.library()
        } catch {
            throw BASMetalFlashAttentionDispatcherError
                .libraryUnavailable(
                    message: String(describing: error))
        }
    }

    private func ensureForwardPipeline(
        library: MTLLibrary, device: MTLDevice
    ) async throws {
        if forwardPipeline != nil { return }
        guard let fn = library.makeFunction(
            name: Self.forwardSymbol)
        else {
            throw BASMetalFlashAttentionDispatcherError
                .functionNotFound(
                    name: Self.forwardSymbol)
        }
        do {
            forwardPipeline = try await device
                .makeComputePipelineState(function: fn)
        } catch {
            throw BASMetalFlashAttentionDispatcherError
                .pipelineCreationFailed(
                    message: String(describing: error))
        }
    }

    private func ensureCommandQueue(
        device: MTLDevice
    ) throws {
        if commandQueue != nil { return }
        commandQueue = device.makeCommandQueue()
        if commandQueue == nil {
            throw BASMetalFlashAttentionDispatcherError
                .commandQueueCreationFailed
        }
    }

    private static func makeFloatBuffer(
        device: MTLDevice, floats: [Float],
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
            throw BASMetalFlashAttentionDispatcherError
                .bufferAllocationFailed(name: name)
        }
        return buf
    }
    #endif
}
