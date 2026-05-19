// MARK: - BASMetalBatchedCosineSimilarityDispatcher
// chapter 七百十五 第二刀 / M2247
//
// Per architectural matrix「Metal:embedding similarity」 —
// query × corpus batched cosine on the GPU。 Dispatches the
// `batched_cosine_similarity` MSL kernel from SSMScan.metal
// (chapter 七百十五 第一刀)。
//
// Strategy:
//   - One Metal thread per corpus row
//   - Each thread computes its row's dot + norm_q + norm_r
//     + final score sequentially in dim
//   - All n_rows scores written to one output buffer in a
//     single dispatch — no CPU-side reduction needed
//
// Sibling to BASMetalCosineSimilarityDispatcher (single-pair
// version)。 Both use the same MTLLibrary loader + the same
// pipeline-memoization pattern。

import Foundation
#if canImport(Metal)
import Metal
#endif

public enum BASMetalBatchedCosineDispatcherError:
    Error, Equatable, Sendable, Codable
{
    case metalUnavailableOnPlatform
    case libraryUnavailable(message: String)
    case functionNotFound(name: String)
    case commandQueueCreationFailed
    case pipelineCreationFailed(message: String)
    case bufferAllocationFailed(name: String)
    case zeroLengthQuery
    case zeroCorpus
    case shapeMismatch(
        queryLen: Int, corpusLen: Int, dim: Int)

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
        case .zeroLengthQuery:
            return "zeroLengthQuery"
        case .zeroCorpus:
            return "zeroCorpus"
        case .shapeMismatch:
            return "shapeMismatch"
        }
    }
}

/// Actor dispatching the chapter 七百十五 第一刀
/// `batched_cosine_similarity` MSL kernel on the GPU。
public actor BASMetalBatchedCosineSimilarityDispatcher {

    public static let kernelSymbolName: String =
        "batched_cosine_similarity"

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

    /// Dispatch batched cosine similarity:returns an
    /// `n_rows`-length score array,score[r] = cosine(query,
    /// corpus.row[r])。
    public func dispatch(
        query: [Float],
        corpus: [Float],
        dim: Int
    ) async throws -> [Float] {
        #if canImport(Metal)
        guard !query.isEmpty,
              query.count == dim
        else {
            throw BASMetalBatchedCosineDispatcherError
                .zeroLengthQuery
        }
        guard !corpus.isEmpty else {
            throw BASMetalBatchedCosineDispatcherError
                .zeroCorpus
        }
        guard corpus.count % dim == 0 else {
            throw BASMetalBatchedCosineDispatcherError
                .shapeMismatch(
                    queryLen: query.count,
                    corpusLen: corpus.count,
                    dim: dim)
        }
        let nRows = corpus.count / dim
        let library: MTLLibrary
        do {
            library = try await loader.library()
        } catch {
            throw BASMetalBatchedCosineDispatcherError
                .libraryUnavailable(
                    message: String(describing: error))
        }
        let device = library.device
        if pipeline == nil {
            guard let function = library.makeFunction(
                name: Self.kernelSymbolName)
            else {
                throw
                    BASMetalBatchedCosineDispatcherError
                    .functionNotFound(
                        name: Self.kernelSymbolName)
            }
            do {
                pipeline = try await device
                    .makeComputePipelineState(
                        function: function)
            } catch {
                throw
                    BASMetalBatchedCosineDispatcherError
                    .pipelineCreationFailed(
                        message:
                            String(describing: error))
            }
        }
        guard let pipeline else {
            throw BASMetalBatchedCosineDispatcherError
                .pipelineCreationFailed(
                    message: "pipeline still nil")
        }
        if commandQueue == nil {
            commandQueue = device.makeCommandQueue()
        }
        guard let commandQueue else {
            throw BASMetalBatchedCosineDispatcherError
                .commandQueueCreationFailed
        }
        // Allocate buffers
        let queryBuf = try makeBuffer(
            device: device, floats: query, name: "query")
        let corpusBuf = try makeBuffer(
            device: device, floats: corpus, name: "corpus")
        let zeros = [Float](repeating: 0, count: nRows)
        let scoresBuf = try makeBuffer(
            device: device, floats: zeros,
            name: "scores")
        var shapeValues: [UInt32] = [
            UInt32(dim), UInt32(nRows)]
        guard let shapeBuf = device.makeBuffer(
            bytes: &shapeValues,
            length: MemoryLayout<UInt32>.size * 2,
            options: [])
        else {
            throw BASMetalBatchedCosineDispatcherError
                .bufferAllocationFailed(name: "shape")
        }
        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf
                .makeComputeCommandEncoder()
        else {
            throw BASMetalBatchedCosineDispatcherError
                .commandQueueCreationFailed
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(queryBuf,  offset: 0, index: 0)
        encoder.setBuffer(corpusBuf, offset: 0, index: 1)
        encoder.setBuffer(scoresBuf, offset: 0, index: 2)
        encoder.setBuffer(shapeBuf,  offset: 0, index: 3)
        // 1-D grid:n_rows threads, one thread per row
        let gridSize = MTLSize(
            width: nRows, height: 1, depth: 1)
        let groupSize = MTLSize(
            width: min(
                pipeline.maxTotalThreadsPerThreadgroup,
                nRows),
            height: 1, depth: 1)
        encoder.dispatchThreads(
            gridSize,
            threadsPerThreadgroup: groupSize)
        encoder.endEncoding()
        await withCheckedContinuation {
            (cont: CheckedContinuation<Void, Never>) in
            cmdBuf.addCompletedHandler { _ in
                cont.resume()
            }
            cmdBuf.commit()
        }
        let ptr = scoresBuf.contents().bindMemory(
            to: Float.self, capacity: nRows)
        var out = [Float](repeating: 0, count: nRows)
        for i in 0..<nRows {
            out[i] = ptr[i]
        }
        return out
        #else
        throw BASMetalBatchedCosineDispatcherError
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
            throw BASMetalBatchedCosineDispatcherError
                .bufferAllocationFailed(name: name)
        }
        return buf
    }
    #endif
}
