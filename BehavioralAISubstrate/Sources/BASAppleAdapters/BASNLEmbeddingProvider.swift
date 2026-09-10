// MARK: - BASNLEmbeddingProvider — chapter 三百六十 / M847
//
// Phase P1 G4 第四刀: Apple-platform `NaturalLanguage.NLEmbedding`
// conformer of `BASEmbeddingProvider`。Closes the production
// embedding path of G4 from M840 Cognitive OS roadmap。
//
// ## Why NaturalLanguage.NLEmbedding
//
// Per M840 §3.4 (G4 design):
// > Embedding: NaturalLanguage.NLEmbedding.wordEmbedding for
// > baseline (Apple-native, on-device, no model bundle needed)
//
// `NLEmbedding.wordEmbedding(for: .english)` returns a 100-dim
// pre-trained word2vec/GloVe-style embedding。No additional
// `.mlpackage` to bundle,no Core ML model load,zero startup
// cost on Apple platforms。Sufficient as a baseline for personal
// memory corpus < 10K atoms。
//
// **Sentence handling**: NLEmbedding doesn't ship a sentence
// embedding by default。This provider averages word embeddings
// (chapter 一百八十五 anti-magic-number — naive but typed +
// pinned)。For better semantic, hosts swap to a future
// MiniLM-converted Core ML conformer。
//
// ## Doctrine pins held
//
//   - All BASEmbeddingProvider doctrine pins apply
//   - chapter 三百二〇 (M807) Apple-platform gating idiom mirrored
//     (`#if canImport(NaturalLanguage)`)
//   - chapter 二百一一 single-source-of-truth — protocol stays in
//     BASMemory,Apple conformer here
//
// ## Performance characteristics
//
//   - First call: ~50-100ms (lazy NLEmbedding load)
//   - Subsequent calls: < 1ms per text on M1 (cached internally
//     by NLEmbedding)
//   - Memory: ~10MB for the bundled English embedding (loaded
//     once)
//   - Dimension: 100 (fixed by Apple's bundled embedding)

import Foundation

#if canImport(NaturalLanguage)
import NaturalLanguage
import BASMemory

/// `BASEmbeddingProvider` conformer backed by Apple's bundled
/// `NLEmbedding.wordEmbedding(for: .english)` (100-dim word2vec)。
///
/// **Sentence embedding strategy**: averages per-word embeddings
/// over the input text (whitespace-tokenized,lowercased)。Words
/// not in the embedding's vocabulary are skipped。Empty input or
/// all-OOV input produces a zero vector。
///
/// **Apple platforms only**: the file is gated by
/// `#if canImport(NaturalLanguage)`。Linux / cross-platform tests
/// use `BASStubEmbeddingProvider` instead。
public struct BASNLEmbeddingProvider: BASEmbeddingProvider {
    public let providerVersion: String
    public let dimension: Int

    /// Default version tag (chapter 八十七 raw value stability —
    /// audit walkers grep this)。
    public static let defaultVersion: String =
        "NLEmbedding-en-v1"

    /// Apple's bundled English embedding is 300-dim per
    /// `NLEmbedding.wordEmbedding(for: .english)?.dimension`
    /// on macOS 14 / iOS 17+ SDK at chapter 三百六十 / M847
    /// shipping date (2026-05-08)。Pinned as a typed constant
    /// per chapter 一百八十五,but Apple may bump SDK-side;the
    /// init reads the actual dimension from the embedding,not
    /// from this constant,so a future Apple bump won't break
    /// runtime — only the test pin needs updating。
    public static let englishWordDimension: Int = 300

    /// The underlying NLEmbedding。Captured at init for thread-
    /// safety + lazy-load amortization。`@unchecked Sendable` —
    /// NLEmbedding is documented thread-safe for read but not
    /// formally Sendable;wrapping at construction is safe per
    /// Apple's `NaturalLanguage` framework concurrency notes。
    private let embeddingBox: NLEmbeddingBox

    /// Initialize with the bundled English word embedding。
    /// Returns nil on platforms / OS versions where
    /// `NLEmbedding.wordEmbedding(for: .english)` returns nil
    /// (theoretical — should always succeed on iOS 13+ /
    /// macOS 10.15+)。
    public init?(
        providerVersion: String =
            BASNLEmbeddingProvider.defaultVersion
    ) {
        guard let embedding = NLEmbedding.wordEmbedding(
            for: .english)
        else {
            return nil
        }
        self.providerVersion = providerVersion
        self.dimension = embedding.dimension
        self.embeddingBox = NLEmbeddingBox(
            embedding: embedding)
    }

    public func embed(_ text: String) async -> BASEmbedding {
        guard !text.isEmpty else {
            return BASEmbedding(
                vector: Array(
                    repeating: 0, count: dimension),
                dimension: dimension,
                providerVersion: providerVersion)
        }
        // Naive sentence embedding: average per-word vectors。
        // Whitespace tokenize + lowercase + skip OOV。
        let tokens = text
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        var sum = [Double](
            repeating: 0, count: dimension)
        var hits = 0
        let embedding = embeddingBox.embedding
        for token in tokens {
            // NLEmbedding.vector(for:) returns [Double]?
            guard let vec = embedding.vector(for: token),
                  vec.count == dimension
            else { continue }
            for i in 0..<dimension {
                sum[i] += vec[i]
            }
            hits += 1
        }
        guard hits > 0 else {
            return BASEmbedding(
                vector: Array(
                    repeating: 0, count: dimension),
                dimension: dimension,
                providerVersion: providerVersion)
        }
        let denominator = Float(hits)
        let avg = sum.map { Float($0) / denominator }
        return BASEmbedding(
            vector: avg,
            dimension: dimension,
            providerVersion: providerVersion)
    }
}

/// `@unchecked Sendable` wrapper for `NLEmbedding`。
/// `NLEmbedding` is documented thread-safe for `.vector(for:)`
/// reads (immutable lookup table) but doesn't formally conform
/// to Sendable in current Apple SDK。Wrapping at construction
/// boundaries is safe per chapter 三百四七 / M834 Sendable
/// boxing precedent。
private struct NLEmbeddingBox: @unchecked Sendable {
    let embedding: NLEmbedding
}

#endif
