// MARK: - BASInt8VectorIndexEntry
// chapter 七百二十七 第一刀 / M2306
//
// int8-quantized counterpart to BASVectorIndexEntry。 Stores
// pre-normalized embedding as int8 + scale (per chapter 七百
// 二十六 quantization),achieving ~4× memory shrink at the
// cost of a small cosine-drift envelope (≤ 0.01 per the
// chapter 七百二十七 quality gate)。
//
// ## Codable schema versioning
//
// v1 (legacy): `BASVectorIndexEntry` (Float32 embedding)
// v2 (new):    this struct (int8 + scale embedding)
//
// Hosts that have a legacy v1 corpus on disk continue to load it
// as Float32 — no automatic re-quantization。 New corpora can opt
// in to v2 via `BASVectorIndex.useInt8VectorStorage` flag (chapter
// 七百二十七 第二刀)。 The schema-version field on each entry
// preserves the decoder dispatch。

import Foundation
import BASRuntimeCore

/// int8-quantized typed row in the vector index。 Pairs an atom
/// ID with a quantized embedding + scale + free-form metadata。
public struct BASInt8VectorIndexEntry:
    Codable, Sendable, Equatable
{
    /// Atom ID (matches `BASGovernedMemory.id.uuidString`)。
    public let atomID: String

    /// Pre-normalized embedding quantized to int8。 The
    /// `BASQuantizedTensor` wrapper carries (shape,data,scale,
    /// version)。
    public let quantizedEmbedding: BASQuantizedTensor

    /// Free-form domain tag (matches BASVectorIndexEntry.domain)。
    public let domain: String

    /// Free-form payload metadata (matches BASVectorIndexEntry
    /// .metadata)。
    public let metadata: [String: String]

    /// Schema version pin — 2 for int8 entries。 Legacy v1
    /// Float32 entries use BASVectorIndexEntry,not this type。
    public let schemaVersion: Int

    public init(
        atomID: String,
        quantizedEmbedding: BASQuantizedTensor,
        domain: String = "",
        metadata: [String: String] = [:],
        schemaVersion: Int = 2
    ) {
        self.atomID = atomID
        self.quantizedEmbedding = quantizedEmbedding
        self.domain = domain
        self.metadata = metadata
        self.schemaVersion = schemaVersion
    }

    /// Convenience initializer that quantizes a Float32
    /// embedding on the fly。 Returns nil if quantization
    /// fails (FFI error;extremely unlikely from valid input)。
    public init?(
        atomID: String,
        normalizedEmbedding: [Float],
        domain: String = "",
        metadata: [String: String] = [:]
    ) {
        guard let qt = BASQuantizedTensor(
            floatValues: normalizedEmbedding,
            shape: [normalizedEmbedding.count])
        else { return nil }
        self.init(
            atomID: atomID,
            quantizedEmbedding: qt,
            domain: domain,
            metadata: metadata)
    }

    /// Dimension of the original Float32 embedding (equals
    /// `quantizedEmbedding.count`)。
    public var dimension: Int {
        return quantizedEmbedding.count
    }

    /// Memory cost in bytes (int8 buffer + scale + metadata
    /// overhead — atomID + domain + metadata excluded since
    /// those are present in the Float32 entry too)。
    public var embeddingByteSize: Int {
        return quantizedEmbedding.byteSize
    }
}
