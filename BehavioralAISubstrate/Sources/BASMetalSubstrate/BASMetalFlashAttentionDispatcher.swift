// MARK: - BASMetalFlashAttentionDispatcher
// chapter 七百七 第一刀 / M2206
//
// Swift dispatcher for the chapter-七百五-第一刀 BASFlashAttention
// .metal tiled-attention kernel family。
//
// WIRED TODAY:all three forward paths —
//
//   - dispatch(q:qRows:qCols:k:kRows:v:vCols:)
//     → flash_attention_forward (unmasked)
//   - dispatch(q:qRows:qCols:k:kRows:v:vCols:mask:)
//     → flash_attention_forward_masked (additive boolean
//       key-exclusion mask, row-major [qRows × kRows] of
//       0 / non-0 bytes; non-0 ⇒ that key is excluded)
//   - dispatchCausal(q:qRows:qCols:k:kRows:v:vCols:)
//     → flash_attention_forward_causal (implicit lower-
//       triangular mask: query i attends only to key j ≤ i;
//       no host mask allocation needed)
//
// chapter 一千零四十 / ADR-019 consequential wiring — the masked
// + causal MSL kernels (`flash_attention_forward_masked` /
// `flash_attention_forward_causal`) are now built (their
// pipeline slots `maskedPipeline` / `causalPipeline` are
// memoized on first use,mirroring `forwardPipeline`)。 All
// three paths are GATED by GPU-vs-CPU parity tests
// (BASChapter1040FlashAttentionMaskedCausalParityTests) — the
// HARD RULE is no unverified GPU dispatch ships。
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
    /// Masked dispatch was handed a mask whose length is not
    /// `qRows * kRows` (row-major one byte per (query, key)
    /// pair)。 Caught host-side before the GPU dispatch so an
    /// undersized mask can never index out of bounds in-shader。
    case maskShapeMismatch(message: String)
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
        case .maskShapeMismatch:
            return "maskShapeMismatch"
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

    public var hasMemoizedMaskedPipeline: Bool {
        #if canImport(Metal)
        return maskedPipeline != nil
        #else
        return false
        #endif
    }

    public var hasMemoizedCausalPipeline: Bool {
        #if canImport(Metal)
        return causalPipeline != nil
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
        guard let pipeline = forwardPipeline else {
            throw BASMetalFlashAttentionDispatcherError
                .functionNotFound(name: Self.forwardSymbol)
        }
        return try await runFlashKernel(
            pipeline: pipeline, device: device,
            q: q, qRows: qRows, qCols: qCols,
            k: k, kRows: kRows,
            v: v, vCols: vCols,
            mask: nil)
        #else
        throw BASMetalFlashAttentionDispatcherError
            .metalUnavailableOnPlatform
        #endif
    }

    /// Masked forward path → `flash_attention_forward_masked`。
    ///
    /// `mask` is a row-major `[qRows × kRows]` array of bytes,one
    /// per (query row, key column) pair。 A non-zero byte EXCLUDES
    /// that key from the query's softmax (the in-shader scaled
    /// score is clamped to -INF before the online running-max +
    /// running-sum updates)。 A zero byte keeps the key。 This
    /// matches the additive-boolean-mask convention documented in
    /// the .metal kernel header。
    ///
    /// Equivalent to the unmasked path with the excluded keys
    /// removed from each row's attention,but computed in O(N)
    /// memory via the same tiling。 GATED by a GPU-vs-CPU parity
    /// test — see the file header。
    public func dispatch(
        q: [Float], qRows: Int, qCols: Int,
        k: [Float], kRows: Int,
        v: [Float], vCols: Int,
        mask: [UInt8]
    ) async throws -> [Float] {
        #if canImport(Metal)
        try Self.validateShapes(
            q: q, qRows: qRows, qCols: qCols,
            k: k, kRows: kRows,
            v: v, vCols: vCols)
        try Self.validateMask(
            mask: mask, qRows: qRows, kRows: kRows)
        let library = try await Self.resolveLibrary(
            loader: loader)
        let device = library.device
        try await ensureMaskedPipeline(
            library: library, device: device)
        try ensureCommandQueue(device: device)
        guard let pipeline = maskedPipeline else {
            throw BASMetalFlashAttentionDispatcherError
                .functionNotFound(name: Self.maskedSymbol)
        }
        return try await runFlashKernel(
            pipeline: pipeline, device: device,
            q: q, qRows: qRows, qCols: qCols,
            k: k, kRows: kRows,
            v: v, vCols: vCols,
            mask: mask)
        #else
        throw BASMetalFlashAttentionDispatcherError
            .metalUnavailableOnPlatform
        #endif
    }

    /// Causal forward path → `flash_attention_forward_causal`。
    ///
    /// Applies an implicit lower-triangular mask — query row i
    /// attends only to key columns j ≤ i — with NO host mask
    /// allocation。 Saves the caller one buffer + one transfer for
    /// the common autoregressive-decoder shape。 GATED by a GPU-
    /// vs-CPU parity test — see the file header。
    public func dispatchCausal(
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
        try await ensureCausalPipeline(
            library: library, device: device)
        try ensureCommandQueue(device: device)
        guard let pipeline = causalPipeline else {
            throw BASMetalFlashAttentionDispatcherError
                .functionNotFound(name: Self.causalSymbol)
        }
        return try await runFlashKernel(
            pipeline: pipeline, device: device,
            q: q, qRows: qRows, qCols: qCols,
            k: k, kRows: kRows,
            v: v, vCols: vCols,
            mask: nil)
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

    /// The masked kernel reads `mask[q_row * N + k_row]` for every
    /// (query, key) pair,so the host array must be exactly
    /// `qRows * kRows` bytes。 Validated before the GPU dispatch so
    /// an undersized mask can never read out of bounds in-shader。
    private static func validateMask(
        mask: [UInt8], qRows: Int, kRows: Int
    ) throws {
        guard mask.count == qRows * kRows else {
            throw BASMetalFlashAttentionDispatcherError
                .maskShapeMismatch(
                    message:
                        "mask.count (\(mask.count)) != " +
                        "qRows*kRows (\(qRows * kRows))")
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

    private func ensureMaskedPipeline(
        library: MTLLibrary, device: MTLDevice
    ) async throws {
        if maskedPipeline != nil { return }
        guard let fn = library.makeFunction(
            name: Self.maskedSymbol)
        else {
            throw BASMetalFlashAttentionDispatcherError
                .functionNotFound(
                    name: Self.maskedSymbol)
        }
        do {
            maskedPipeline = try await device
                .makeComputePipelineState(function: fn)
        } catch {
            throw BASMetalFlashAttentionDispatcherError
                .pipelineCreationFailed(
                    message: String(describing: error))
        }
    }

    private func ensureCausalPipeline(
        library: MTLLibrary, device: MTLDevice
    ) async throws {
        if causalPipeline != nil { return }
        guard let fn = library.makeFunction(
            name: Self.causalSymbol)
        else {
            throw BASMetalFlashAttentionDispatcherError
                .functionNotFound(
                    name: Self.causalSymbol)
        }
        do {
            causalPipeline = try await device
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

    private static func makeByteBuffer(
        device: MTLDevice, bytes: [UInt8],
        name: String
    ) throws -> MTLBuffer {
        guard let buf = bytes.withUnsafeBufferPointer({
            ptr -> MTLBuffer? in
            device.makeBuffer(
                bytes: ptr.baseAddress!,
                length: bytes.count
                    * MemoryLayout<UInt8>.size,
                options: [])
        })
        else {
            throw BASMetalFlashAttentionDispatcherError
                .bufferAllocationFailed(name: name)
        }
        return buf
    }

    /// Shared GPU plumbing for all three forward kernels。 The
    /// only per-kernel difference is the pipeline + whether a mask
    /// buffer is bound,which shifts the O / shape binding indices:
    ///
    ///   unmasked / causal:  Q@0 K@1 V@2 O@3 shape@4
    ///   masked:             Q@0 K@1 V@2 mask@3 O@4 shape@5
    ///
    /// Callers validate shapes (+ mask length) BEFORE calling this。
    /// Resumes by THROWING on a GPU fault so the zero-filled output
    /// buffer is never returned as a valid result。
    private func runFlashKernel(
        pipeline: MTLComputePipelineState,
        device: MTLDevice,
        q: [Float], qRows: Int, qCols: Int,
        k: [Float], kRows: Int,
        v: [Float], vCols: Int,
        mask: [UInt8]?
    ) async throws -> [Float] {
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
        guard let cmdBuf = commandQueue?
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
        if let mask {
            // Masked kernel signature: mask@3, O@4, shape@5。
            let maskBuf = try Self.makeByteBuffer(
                device: device, bytes: mask, name: "mask")
            encoder.setBuffer(maskBuf, offset: 0, index: 3)
            encoder.setBuffer(outBuf, offset: 0, index: 4)
            encoder.setBuffer(shapeBuf, offset: 0, index: 5)
        } else {
            // Unmasked / causal signature: O@3, shape@4。
            encoder.setBuffer(outBuf, offset: 0, index: 3)
            encoder.setBuffer(shapeBuf, offset: 0, index: 4)
        }
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
        // with the unchanged output buffer。 (Same async-handler
        // pattern the unmasked path used before this refactor —
        // avoids a blocking waitUntilCompleted on the actor。)
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
    }
    #endif
}
