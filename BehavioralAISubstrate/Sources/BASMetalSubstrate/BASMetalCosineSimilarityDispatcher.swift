// MARK: - BASMetalCosineSimilarityDispatcher
// 主线 Metal embedding similarity — 全面 开发
//
// Per the user's final blueprint, Metal should own
// "embedding similarity"。 This dispatcher computes
// the cosine similarity between two equal-length
// float32 vectors via the `vector_cosine_similarity`
// MSL kernel added to SSMScan.metal。
//
// Strategy:
//   - GPU computes per-element products (dot,
//     norm_a, norm_b)
//   - CPU does the final sum + sqrt + divide on the
//     three returned arrays
//
// This is honest:per-element products are exactly
// where GPU parallelism shines。 The final reduction
// is sub-microsecond on CPU for typical embedding
// sizes (≤ 1024)。 A full GPU reduction with
// threadgroup memory would be ~5% faster at large N
// but requires barrier synchronization that's not
// worth the complexity here。

import Foundation
#if canImport(Metal)
import Metal
#endif

/// Typed errors mirroring the dispatcher's failure
/// modes。 Names align with
/// BASMetalSSMScanDispatcherError for cross-pilot
/// consistency。
public enum BASMetalCosineSimilarityDispatcherError:
    Error, Equatable, Sendable, Codable
{
    case metalUnavailableOnPlatform
    case libraryUnavailable(message: String)
    case functionNotFound(name: String)
    case commandQueueCreationFailed
    case pipelineCreationFailed(message: String)
    case bufferAllocationFailed(name: String)
    case payloadCountMismatch(
        name: String, expected: Int, actual: Int)
    case zeroLengthVectors
    /// GPU command buffer completed with a fault
    /// (`MTLCommandBuffer.error` was non-nil)。 The zero-
    /// filled partials are NOT a valid result — throw
    /// rather than reduce them into a bogus similarity。
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
        case .payloadCountMismatch:
            return "payloadCountMismatch"
        case .zeroLengthVectors:
            return "zeroLengthVectors"
        case .commandBufferFailed:
            return "commandBufferFailed"
        }
    }
}

/// Codable result struct for a single cosine
/// similarity computation。 Carries the similarity in
/// [-1, 1] + the partial norms for hosts that want to
/// audit the GPU dispatch's intermediate state。
public struct BASMetalCosineSimilarityResult: Codable,
    Equatable, Sendable, Hashable
{
    /// cos(a, b) = sum(a[i]*b[i]) /
    ///             (sqrt(sum(a[i]²)) *
    ///              sqrt(sum(b[i]²)))。
    /// Range [-1, 1]。 NaN guard:if either norm is
    /// 0 (degenerate zero-vector input),similarity is
    /// 0 by convention。
    public let similarity: Float

    /// sqrt(sum(a[i]²)) — vector A's L2 norm。
    public let normA: Float

    /// sqrt(sum(b[i]²)) — vector B's L2 norm。
    public let normB: Float

    /// sum(a[i] * b[i]) — raw dot product (no
    /// normalization)。
    public let dotProduct: Float

    public init(
        similarity: Float,
        normA: Float,
        normB: Float,
        dotProduct: Float
    ) {
        self.similarity = similarity
        self.normA = normA
        self.normB = normB
        self.dotProduct = dotProduct
    }
}

/// Actor dispatching the chapter-extended Metal kernel
/// `vector_cosine_similarity` on the GPU via the
/// chapter 704 MTLLibrary loader。 Sibling to
/// BASMetalSSMScanDispatcher — same pipeline-memoization
/// pattern。
public actor BASMetalCosineSimilarityDispatcher {

    /// Compiled-kernel symbol name (matches the MSL
    /// `kernel void` declaration in SSMScan.metal)。
    public static let kernelSymbolName: String =
        "vector_cosine_similarity"

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

    /// Dispatch the cosine-similarity kernel for two
    /// equal-length float32 vectors。 Throws on length
    /// mismatch / zero-length / Metal-side errors。
    public func dispatch(
        a: [Float],
        b: [Float]
    ) async throws -> BASMetalCosineSimilarityResult {
        #if canImport(Metal)
        guard a.count == b.count else {
            throw BASMetalCosineSimilarityDispatcherError
                .payloadCountMismatch(
                    name: "b",
                    expected: a.count,
                    actual: b.count)
        }
        guard !a.isEmpty else {
            throw BASMetalCosineSimilarityDispatcherError
                .zeroLengthVectors
        }
        let n = a.count
        let library: MTLLibrary
        do {
            library = try await loader.library()
        } catch {
            throw BASMetalCosineSimilarityDispatcherError
                .libraryUnavailable(
                    message: String(describing: error))
        }
        let device = library.device
        if pipeline == nil {
            guard let function = library.makeFunction(
                name: Self.kernelSymbolName)
            else {
                throw
                    BASMetalCosineSimilarityDispatcherError
                    .functionNotFound(
                        name: Self.kernelSymbolName)
            }
            do {
                pipeline = try await device
                    .makeComputePipelineState(
                        function: function)
            } catch {
                throw
                    BASMetalCosineSimilarityDispatcherError
                    .pipelineCreationFailed(
                        message:
                            String(describing: error))
            }
        }
        guard let pipeline else {
            throw BASMetalCosineSimilarityDispatcherError
                .pipelineCreationFailed(
                    message: "pipeline still nil")
        }
        if commandQueue == nil {
            commandQueue = device.makeCommandQueue()
        }
        guard let commandQueue else {
            throw BASMetalCosineSimilarityDispatcherError
                .commandQueueCreationFailed
        }
        // Allocate buffers
        let aBuf = try makeBuffer(
            device: device, floats: a, name: "a")
        let bBuf = try makeBuffer(
            device: device, floats: b, name: "b")
        let zeros = [Float](repeating: 0, count: n)
        let dotBuf = try makeBuffer(
            device: device, floats: zeros, name: "dot")
        let normABuf = try makeBuffer(
            device: device, floats: zeros, name: "norm_a")
        let normBBuf = try makeBuffer(
            device: device, floats: zeros, name: "norm_b")
        var shapeValues: [UInt32] = [UInt32(n)]
        guard let shapeBuf = device.makeBuffer(
            bytes: &shapeValues,
            length: MemoryLayout<UInt32>.size,
            options: [])
        else {
            throw BASMetalCosineSimilarityDispatcherError
                .bufferAllocationFailed(name: "shape")
        }
        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf
                .makeComputeCommandEncoder()
        else {
            throw BASMetalCosineSimilarityDispatcherError
                .commandQueueCreationFailed
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(aBuf,     offset: 0, index: 0)
        encoder.setBuffer(bBuf,     offset: 0, index: 1)
        encoder.setBuffer(dotBuf,   offset: 0, index: 2)
        encoder.setBuffer(normABuf, offset: 0, index: 3)
        encoder.setBuffer(normBBuf, offset: 0, index: 4)
        encoder.setBuffer(shapeBuf, offset: 0, index: 5)
        // 1-D grid:N threads
        let gridSize = MTLSize(
            width: n, height: 1, depth: 1)
        let groupSize = MTLSize(
            width: 1, height: 1, depth: 1)
        encoder.dispatchThreads(
            gridSize,
            threadsPerThreadgroup: groupSize)
        encoder.endEncoding()
        // Resume by THROWING on a GPU fault — reducing zero-
        // filled partials would yield a bogus similarity
        // returned as success。 Success path resumes with the
        // partials buffers unchanged。
        try await withCheckedThrowingContinuation {
            (cont: CheckedContinuation<Void, Error>) in
            cmdBuf.addCompletedHandler { buffer in
                if let err = buffer.error {
                    cont.resume(throwing:
                        BASMetalCosineSimilarityDispatcherError
                            .commandBufferFailed(
                                message:
                                    err.localizedDescription))
                } else {
                    cont.resume()
                }
            }
            cmdBuf.commit()
        }
        // Read partials back + reduce on CPU
        let dotPtr = dotBuf.contents().bindMemory(
            to: Float.self, capacity: n)
        let normAPtr = normABuf.contents().bindMemory(
            to: Float.self, capacity: n)
        let normBPtr = normBBuf.contents().bindMemory(
            to: Float.self, capacity: n)
        var dot: Float = 0
        var normASum: Float = 0
        var normBSum: Float = 0
        for i in 0..<n {
            dot += dotPtr[i]
            normASum += normAPtr[i]
            normBSum += normBPtr[i]
        }
        let normA = sqrtf(normASum)
        let normB = sqrtf(normBSum)
        // NaN guard:cosine is 0 by convention when
        // either vector is the zero vector (zero norm)。
        let sim: Float
        if normA == 0 || normB == 0 {
            sim = 0
        } else {
            sim = dot / (normA * normB)
        }
        return BASMetalCosineSimilarityResult(
            similarity: sim,
            normA: normA,
            normB: normB,
            dotProduct: dot)
        #else
        throw BASMetalCosineSimilarityDispatcherError
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
            throw BASMetalCosineSimilarityDispatcherError
                .bufferAllocationFailed(name: name)
        }
        return buf
    }
    #endif
}
