// MARK: - BASEmbeddingProvider — chapter 三百六十 / M847
//
// Phase P1 G4 第一刀: typed embedding provider protocol + cross-
// platform stub conformer。Closes G4 from M840 Cognitive OS
// roadmap (vector RAG MVP)。
//
// ## Why this exists
//
// Per chapter 三百五三 / M840 audit, the existing memory pipeline
// has **zero vector / embedding infrastructure**:retrieval is
// purely tier-ordered prefix。No semantic search,no nearest-
// neighbor candidates,no reranker pipeline。
//
// G4 ships the foundational primitive: a typed embedding contract
// that hosts can wire to either:
//   - Apple `NaturalLanguage.NLEmbedding.wordEmbedding` (Apple-
//     platform-only,no model bundle required) — see
//     `BASNLEmbeddingProvider` in BASAppleAdapters (chapter 三百六十
//     companion file)
//   - A converted MiniLM `.mlpackage` (~22MB) once trained — fits
//     the existing chapter 三百三六 BASChengluMemoryAspirational
//     Adapter pattern
//   - A stub for tests (hash-based deterministic pseudo-embedding,
//     this file)
//
// ## What this file ships (M847 第一刀)
//
//   - `BASEmbedding` typed value (Float32 array + dimensionality)
//   - `BASEmbeddingProvider` Sendable async protocol
//   - `BASStubEmbeddingProvider` deterministic stub conformer
//
// Companion files in the same chapter:
//   - `BASVectorIndex.swift` (BASMemory) — in-memory cosine
//     similarity index
//   - `BASVectorReranker.swift` (BASMemory) — reranker protocol +
//     identity stub
//   - `BASNLEmbeddingProvider.swift` (BASAppleAdapters) — Apple
//     NLEmbedding conformer
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — embedding is pure transformation,
//     no permit/verdict mutation,no runtime weight write
//   - 红线 7 hint-only — embedding similarity is INPUT to
//     retrieval scoring,not a decision-class signal
//   - 单提交口 (L11/L14) 不变 — embedding feeds memory service,
//     never bypasses the gate
//   - chapter 二百一一 single-source-of-truth — ONE protocol,
//     N conformers (stub + NLEmbedding + future MiniLM)
//   - chapter 一百八十五 anti-magic-number — default dimension +
//     stub seed pinned typed constants
//   - ADR-014 OPT-IN → PROD — provider is opt-in primitive;
//     hosts that don't wire it use existing tier-ordered
//     retrieval (no behavior change)

import Foundation
import CryptoKit

// MARK: - BASEmbedding

/// Typed Sendable Codable Float32 embedding value。
///
/// **Dimensionality contract**: `vector.count == dimension`。
/// Producers MUST emit consistent dimensions across calls;
/// consumers verify via `BASVectorIndex.bind(dimension:)`。
public struct BASEmbedding: Codable, Equatable, Sendable {
    /// Float32 embedding vector。Float32 (vs Double) chosen for
    /// memory efficiency at scale (10K atoms × 384 dim × 4 bytes
    /// = 15 MB vs 30 MB)。
    public let vector: [Float]

    /// Pin: vector.count MUST equal this。Stored explicitly so
    /// readers don't need to call `.count` (microopt) + so empty
    /// vectors carry their intended dim (encode/decode safety)。
    public let dimension: Int

    /// Provider identifier — caller stamps this from the
    /// provider that produced the embedding (e.g.
    /// `"NLEmbedding-en-v1"`,`"MiniLM-L6-v2"`,`"stub-v1"`)。
    /// Used to detect cross-provider compatibility issues at
    /// retrieval time。
    public let providerVersion: String

    public init(
        vector: [Float],
        dimension: Int,
        providerVersion: String
    ) {
        precondition(vector.count == dimension,
            "BASEmbedding: vector.count (\(vector.count)) " +
            "must equal dimension (\(dimension))")
        self.vector = vector
        self.dimension = dimension
        self.providerVersion = providerVersion
    }

    /// L2 norm of the vector (chapter 一百八十五 anti-magic-number
    /// — used by cosine similarity)。Cached in normalize()。
    public var l2Norm: Float {
        sqrt(vector.reduce(0) { $0 + $1 * $1 })
    }

    /// Return the L2-normalized vector (unit length)。If the
    /// vector is zero (l2Norm == 0),returns a zero vector (no
    /// division by zero)。
    public var normalized: BASEmbedding {
        let n = l2Norm
        guard n > 0 else { return self }
        return BASEmbedding(
            vector: vector.map { $0 / n },
            dimension: dimension,
            providerVersion: providerVersion)
    }
}

// MARK: - BASEmbeddingProvider

/// Async Sendable protocol for producing embeddings of text input。
/// Conformers may use:
///   - Apple `NLEmbedding` (BASAppleAdapters companion file)
///   - Converted MiniLM-L6-v2 / similar via Core ML
///   - Stub deterministic embeddings (this file)
///
/// **Determinism**: same `(text, providerVersion)` pair MUST
/// produce the same embedding。Required for replay correctness
/// (G1 BASEventReplayRunner)。
public protocol BASEmbeddingProvider: Sendable {
    /// Stable provider version identifier。Surfaced in result's
    /// `providerVersion` field。
    var providerVersion: String { get }

    /// Embedding dimension this provider produces (constant
    /// across calls)。
    var dimension: Int { get }

    /// Produce an embedding for the given text。Empty input
    /// produces a zero vector (caller-defined semantic — typically
    /// "no signal,don't include in similarity computations")。
    func embed(_ text: String) async -> BASEmbedding
}

// MARK: - BASStubEmbeddingProvider

/// Deterministic stub conformer for tests + cross-platform
/// development。Uses SHA256 of the input text to generate a
/// pseudo-random Float32 vector。
///
/// **NOT semantic**: similar texts produce wildly different
/// vectors。This is a placeholder that satisfies the contract
/// (Sendable / deterministic / fixed dimension) for code that
/// needs a provider during build but cannot bundle NLEmbedding
/// (e.g. Linux CI tests)。
///
/// **Default dimension**: 32 (small for fast tests)。Hosts can
/// pass a different dim at construction。
public struct BASStubEmbeddingProvider: BASEmbeddingProvider {
    public let providerVersion: String
    public let dimension: Int
    public let seed: UInt64

    /// Default dim chosen small for fast tests (chapter 一百八十五
    /// — pinned named constant)。
    public static let defaultDimension: Int = 32

    /// Default version tag — used by audit walkers to identify
    /// stub provenance。
    public static let defaultVersion: String = "stub-v1"

    public init(
        dimension: Int = BASStubEmbeddingProvider.defaultDimension,
        seed: UInt64 = 0,
        providerVersion: String =
            BASStubEmbeddingProvider.defaultVersion
    ) {
        self.dimension = dimension
        self.seed = seed
        self.providerVersion = providerVersion
    }

    public func embed(_ text: String) async -> BASEmbedding {
        guard !text.isEmpty else {
            return BASEmbedding(
                vector: Array(
                    repeating: 0, count: dimension),
                dimension: dimension,
                providerVersion: providerVersion)
        }
        // Hash input + seed → bytes → fold into Float32 vector
        var hasher = SHA256()
        hasher.update(data: Data("\(seed)|".utf8))
        hasher.update(data: Data(text.utf8))
        let digest = hasher.finalize()
        // Generate 32 bytes of hash;cycle through bytes to fill
        // arbitrary dimension。Each Float32 ∈ [-1, 1]
        let bytes = Array(digest)
        var vec: [Float] = []
        vec.reserveCapacity(dimension)
        for i in 0..<dimension {
            let byte = bytes[i % bytes.count]
            // Map [0, 255] → [-1, 1]
            let normalized = Float(byte) / 127.5 - 1.0
            vec.append(normalized)
        }
        return BASEmbedding(
            vector: vec,
            dimension: dimension,
            providerVersion: providerVersion)
    }
}
