// MARK: - BASCxxVectorIndexBridge
// 主线 全面 开发: Swift bridge to the C++ flat in-
// memory vector NN index。
//
// HONEST scope:this is NOT a FAISS bridge — vendor
// FAISS is a 100K LOC dependency out of scope for one
// commit。 This bridge surfaces a small substrate-
// shipped flat cosine-NN index that aligns with the
// blueprint's "C++ owns nearest-neighbor"。 Future
// commits can vendor FAISS / HNSW behind the same
// Swift surface shape。

import Foundation
import BASMPSGraphExecutableCacheCxx

/// Typed errors mirroring the C ABI return codes。
public enum BASCxxVectorIndexBridgeError: Error,
    Equatable, Hashable, Sendable, Codable
{
    case nullPointer
    case cxxInternalException
    case jsonDecodeFailed(message: String)
    case unknownReturnCode(Int32)
    /// An empty input vector was passed. An empty `[Float]` yields a nil
    /// `baseAddress` from `withUnsafeBufferPointer`, which the FFI call would
    /// force-unwrap and trap on — so the bridge fails closed with this instead.
    case emptyVector

    public var caseIdentifier: String {
        switch self {
        case .nullPointer: return "nullPointer"
        case .cxxInternalException:
            return "cxxInternalException"
        case .jsonDecodeFailed:
            return "jsonDecodeFailed"
        case .unknownReturnCode:
            return "unknownReturnCode"
        case .emptyVector:
            return "emptyVector"
        }
    }
}

/// Codable search result entry — one (id, similarity)
/// pair returned by the C++ index search。
public struct BASCxxVectorIndexResult: Codable, Equatable,
    Sendable, Hashable
{
    public let id: String
    public let similarity: Float

    public init(id: String, similarity: Float) {
        self.id = id
        self.similarity = similarity
    }
}

/// Actor wrapping the C++ flat vector NN index。
/// Process-global underlying state — multiple actor
/// instances share the same C++ singleton。 Pattern
/// matches BASMPSGraphExecutableCacheCxxBridge。
public actor BASCxxVectorIndexBridge {

    private let useCxxIndex: Bool

    public init(useCxxIndex: Bool = false) {
        self.useCxxIndex = useCxxIndex
    }

    public var isUsingCxxIndex: Bool { useCxxIndex }

    /// ABI version pin matching the C-side
    /// `bas_mps_index_version`。
    public static let cxxBridgeABIVersion: Int32 = 1

    /// Live C-side version read。
    public static func liveCxxBridgeABIVersion() -> Int32 {
        return bas_mps_index_version()
    }

    /// Add (or replace) a vector keyed by `id`。 V1
    /// path throws `.unknownReturnCode(-99)` to prevent
    /// V1 callers from mutating shared state。
    public func add(
        id: String,
        vector: [Float]
    ) throws {
        guard useCxxIndex else {
            throw BASCxxVectorIndexBridgeError
                .unknownReturnCode(-99)
        }
        // Fail closed on an empty vector: `withUnsafeBufferPointer` hands back a
        // nil `baseAddress`, which the `baseAddress!` below would trap on.
        guard !vector.isEmpty else {
            throw BASCxxVectorIndexBridgeError.emptyVector
        }
        let rc = id.withCString { idPtr -> Int32 in
            vector.withUnsafeBufferPointer { buf in
                bas_mps_index_add(
                    idPtr,
                    buf.baseAddress!,
                    vector.count)
            }
        }
        switch rc {
        case 0: return
        case -1:
            throw BASCxxVectorIndexBridgeError
                .nullPointer
        case -2:
            throw BASCxxVectorIndexBridgeError
                .cxxInternalException
        default:
            throw BASCxxVectorIndexBridgeError
                .unknownReturnCode(rc)
        }
    }

    /// Search for the top-K nearest neighbors of `query`
    /// by cosine similarity。 Returns at most K results,
    /// sorted descending by similarity。 V1 path returns
    /// empty array (no shared state access)。
    public func search(
        query: [Float],
        k: Int
    ) throws -> [BASCxxVectorIndexResult] {
        guard useCxxIndex else { return [] }
        // Fail closed on an empty query (same nil-`baseAddress` trap as `add`).
        guard !query.isEmpty else {
            throw BASCxxVectorIndexBridgeError.emptyVector
        }
        var outPtr: UnsafeMutablePointer<CChar>?
        var outLen: Int = 0
        let rc = query.withUnsafeBufferPointer {
            buf -> Int32 in
            bas_mps_index_search(
                buf.baseAddress!,
                query.count,
                max(0, k),
                &outPtr,
                &outLen)
        }
        switch rc {
        case 0: break
        case -1:
            throw BASCxxVectorIndexBridgeError
                .nullPointer
        case -2:
            throw BASCxxVectorIndexBridgeError
                .cxxInternalException
        default:
            throw BASCxxVectorIndexBridgeError
                .unknownReturnCode(rc)
        }
        guard let outPtr else { return [] }
        defer { bas_mps_index_free_buffer(outPtr, outLen) }
        let data = Data(
            bytes: outPtr,
            count: outLen)
        do {
            return try JSONDecoder().decode(
                [BASCxxVectorIndexResult].self,
                from: data)
        } catch {
            throw BASCxxVectorIndexBridgeError
                .jsonDecodeFailed(
                    message: String(describing: error))
        }
    }

    /// Index size (process-global vector count)。
    /// V1 path returns 0。
    public func size() -> Int64 {
        guard useCxxIndex else { return 0 }
        return bas_mps_index_size()
    }

    /// Empty the index (process-global)。 V1 path is
    /// a no-op。
    public func clear() throws {
        guard useCxxIndex else { return }
        let rc = bas_mps_index_clear()
        if rc != 0 {
            throw BASCxxVectorIndexBridgeError
                .cxxInternalException
        }
    }
}
