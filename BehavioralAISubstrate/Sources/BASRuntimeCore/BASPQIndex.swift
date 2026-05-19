// MARK: - BASPQIndex
// chapter 七百二十九 第二刀 / M2317
//
// Swift RAII wrapper for the Rust PQ index (chapter 七百二十九
// 第一刀)。 Holds an opaque pointer to the Rust-side allocation;
// deinit calls `bas_pq_index_free`。
//
// ## Public surface
//
//   init?(dim:m:k:)
//   func train(_ trainingSet: [Float], nTrain:, iters:) throws
//   func add(_ vector: [Float]) -> Int
//   func topK(_ query: [Float], k: Int) -> [(rowID: Int, distance: Float)]
//   var rowCount: Int
//   var byteSize: Int
//
// Final class (not actor) — the underlying Rust struct supports
// concurrent reads after construction;writes serialize via the
// caller's actor context。 `@unchecked Sendable` mirrors the
// chapter 七百二十二 BASBpeTokenizerHandle pattern。

import Foundation
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

public final class BASPQIndex: @unchecked Sendable {

    public enum BASPQIndexError: Error, Equatable {
        case constructionFailed
        case trainingFailed
        case addFailed
        case topKFailed
        case platformUnsupported
    }

    /// Opaque pointer to the Rust-side `Box<PqIndex>`。
    /// nonisolated(unsafe) so deinit can release without
    /// Swift 6 strict-concurrency warnings — mirrors the
    /// chapter 七百二十二 BASBpeTokenizerHandle pattern。
    fileprivate nonisolated(unsafe) var opaqueHandle:
        OpaquePointer?

    public let dim: Int
    public let m: Int
    public let k: Int

    /// Construct an untrained PQ index。 Returns nil on invalid
    /// parameters (dim not divisible by m,k > 256) or on
    /// platforms without the XCFramework (watchOS)。
    public init?(dim: Int, m: Int, k: Int) {
        self.dim = dim
        self.m = m
        self.k = k
        #if os(iOS) || os(macOS)
        guard let raw = bas_pq_index_new(dim, m, k)
        else { return nil }
        self.opaqueHandle = raw
        #else
        self.opaqueHandle = nil
        return nil
        #endif
    }

    deinit {
        #if os(iOS) || os(macOS)
        if let h = opaqueHandle {
            bas_pq_index_free(h)
        }
        #endif
    }

    /// Train the codebooks。 `trainingSet` is row-major
    /// (nTrain × dim) Float32。 `iters` is the Lloyd k-means
    /// iteration count (8-16 is typical)。
    public func train(
        trainingSet: [Float],
        nTrain: Int,
        iters: Int
    ) throws {
        #if os(iOS) || os(macOS)
        guard let h = opaqueHandle else {
            throw BASPQIndexError.platformUnsupported
        }
        guard trainingSet.count == nTrain * dim else {
            throw BASPQIndexError.trainingFailed
        }
        let rc = trainingSet.withUnsafeBufferPointer { tp in
            return bas_pq_index_train(
                h,
                tp.baseAddress, tp.count,
                nTrain, iters)
        }
        if rc != 0 {
            throw BASPQIndexError.trainingFailed
        }
        #else
        throw BASPQIndexError.platformUnsupported
        #endif
    }

    /// Encode + add a vector to the index。 Returns the assigned
    /// row index (0-indexed,monotonic)。 Throws if the dim
    /// doesn't match the index dim or the FFI rejects。
    @discardableResult
    public func add(_ vector: [Float]) throws -> Int {
        #if os(iOS) || os(macOS)
        guard let h = opaqueHandle else {
            throw BASPQIndexError.platformUnsupported
        }
        guard vector.count == dim else {
            throw BASPQIndexError.addFailed
        }
        let id = vector.withUnsafeBufferPointer { vp in
            return bas_pq_index_add(
                h, vp.baseAddress, vp.count)
        }
        if id < 0 {
            throw BASPQIndexError.addFailed
        }
        return Int(id)
        #else
        throw BASPQIndexError.platformUnsupported
        #endif
    }

    /// Top-K nearest neighbors via asymmetric distance。 Returns
    /// up to `k` (rowID,distance²) pairs sorted ascending by
    /// distance (lower = more similar for normalized L2)。
    public func topK(
        query: [Float], k: Int
    ) throws -> [(rowID: Int, distance: Float)] {
        #if os(iOS) || os(macOS)
        guard let h = opaqueHandle else {
            throw BASPQIndexError.platformUnsupported
        }
        guard query.count == dim, k > 0 else { return [] }
        var ids = [UInt64](repeating: 0, count: k)
        var dists = [Float](repeating: 0, count: k)
        let written = query.withUnsafeBufferPointer { qp in
            return ids.withUnsafeMutableBufferPointer { ip in
                return dists
                    .withUnsafeMutableBufferPointer { dp in
                        return bas_pq_index_top_k(
                            h,
                            qp.baseAddress, qp.count,
                            k,
                            ip.baseAddress,
                            dp.baseAddress,
                            ip.count)
                    }
            }
        }
        if written < 0 {
            throw BASPQIndexError.topKFailed
        }
        let n = Int(written)
        var out: [(rowID: Int, distance: Float)] = []
        out.reserveCapacity(n)
        for i in 0..<n {
            out.append(
                (rowID: Int(ids[i]),
                 distance: dists[i]))
        }
        return out
        #else
        throw BASPQIndexError.platformUnsupported
        #endif
    }

    /// Number of vectors currently stored in the index。
    public var rowCount: Int {
        #if os(iOS) || os(macOS)
        guard let h = opaqueHandle else { return 0 }
        let n = bas_pq_index_n_rows(h)
        return n < 0 ? 0 : Int(n)
        #else
        return 0
        #endif
    }

    /// Memory footprint in bytes (codebooks + codes)。 Use for
    /// budgeting vs Float32 baseline。
    public var byteSize: Int {
        #if os(iOS) || os(macOS)
        guard let h = opaqueHandle else { return 0 }
        let s = bas_pq_index_byte_size(h)
        return s < 0 ? 0 : Int(s)
        #else
        return 0
        #endif
    }
}
