// MARK: - BASBpeTokenizer
// chapter 七百二十二 第四刀 / M2284
//
// Swift bridge actor for the bas-tokenizer Rust crate。 Layers
// the standard real-BPE-in-production trick — whitespace pre-
// tokenization — on top of the chapter 七百二十二 第二刀 raw
// `BASBpeTokenizerHandle`。 Knife 3 measurement showed the
// naive merge-loop cost is O(N²) per call;Knife 4 caps per-call
// input to typical word size (~5-30 bytes),turning the practical
// cost into ~O(N) amortized over the document。
//
// ## Public surface
//
//   - init(vocabData:mergesData:unknownTokenID:) throws
//   - func encode(_ text: String) async throws -> [UInt32]
//   - func decode(_ ids: [UInt32]) async throws -> String
//   - func vocabSize() async -> Int
//
// ## Why an actor
//
// The underlying `BASBpeTokenizerHandle` is `@unchecked Sendable`
// (read-only after construction)。 Wrapping in an actor gives:
//
//   1. Async-aware API that fits substrate's actor topology
//      (BASCognitiveBrain,BASMemoryUsageTracker etc all actors)
//   2. Single owner of the handle — host can drop the actor
//      reference + the Rust-side allocation releases via
//      `BASBpeTokenizerHandle.deinit` (RAII)
//   3. Future expansion room (caching pre-tokenized chunks,
//      batched encode across multiple texts,etc) without
//      breaking callers
//
// ## Bundling production vocab
//
// Substrate ships the actor + the pre-tokenization primitive;
// hosts ship their own vocab。 To bundle a vocab as an SPM
// `.process()` resource,a host package adds:
//
//   .target(
//       name: "MyHost",
//       resources: [.process("Resources/BPE")])
//
// then loads at startup:
//
//   let vocabURL = Bundle.module.url(
//       forResource: "vocab", withExtension: "bin")!
//   let mergesURL = Bundle.module.url(
//       forResource: "merges", withExtension: "bin")!
//   let vocab = try Data(contentsOf: vocabURL)
//   let merges = try Data(contentsOf: mergesURL)
//   let tokenizer = try BASBpeTokenizer(
//       vocabData: vocab, mergesData: merges,
//       unknownTokenID: 0)
//
// The wire format is documented in
// `Cargo/bas-memory-usage-tracker/include/bas_rust_memory_tracker.h`
// (BIG-ENDIAN length prefixes)。 `BASBpeTokenizerHandle
// .encodeVocabBuffer` / `.encodeMergesBuffer` produce the bytes
// from arrays of (token, id) / (left, right, rank) tuples — use
// these at host build time to convert vocab.json + merges.txt
// into the substrate's wire format。

import Foundation

public actor BASBpeTokenizer {

    public enum BpeTokenizerError: Error, Equatable {
        /// `bas_tokenizer_new` rejected the wire-format buffers
        /// (length-prefix underrun or null pointer)。
        case handleInitFailed
        /// Underlying C ABI encode FFI rejected the input
        /// (typically invalid UTF-8)。
        case encodeFailed
        /// Underlying C ABI decode FFI rejected the IDs
        /// (typically: decoded bytes are not valid UTF-8)。
        case decodeFailed
        /// XCFramework not available on the current platform
        /// (e.g。 watchOS)。
        case platformUnsupported
    }

    /// RAII handle owning the Rust-side `Box<Tokenizer>`。 Actor
    /// isolation makes mutation here single-writer-single-reader
    /// by construction;the underlying handle is read-only after
    /// init so encode/decode can run concurrently from many
    /// actor calls without contention。
    private let handle: BASBpeTokenizerHandle

    /// Construct from raw vocab + merges Data (the BIG-ENDIAN
    /// length-prefixed wire format that `bas_tokenizer_new`
    /// consumes)。 Throws on malformed wire-format or platform
    /// without XCFramework support。
    public init(
        vocabData: Data,
        mergesData: Data,
        unknownTokenID: UInt32
    ) throws {
        guard let h = BASBpeTokenizerHandle(
            vocabBuffer: Array(vocabData),
            mergesBuffer: Array(mergesData),
            unknownTokenID: unknownTokenID)
        else {
            throw BpeTokenizerError.handleInitFailed
        }
        guard h.isValid else {
            throw BpeTokenizerError.platformUnsupported
        }
        self.handle = h
    }

    /// Encode `text` into BPE token IDs using whitespace pre-
    /// tokenization。 Splits input on whitespace runs (KEEPING
    /// whitespace as its own chunks so vocab tokens like " the"
    /// still merge inside their chunk),then encodes each chunk
    /// independently and concatenates IDs。
    ///
    /// Pre-tokenization is the standard real-BPE-in-production
    /// trick that converts the naive O(N²) merge-loop cost into
    /// O(N) amortized over the document。
    ///
    /// Returns empty array for empty input。 Throws
    /// `.encodeFailed` if any chunk's FFI encode rejects the
    /// bytes (extremely unlikely since chunks come from a valid
    /// Swift String → always valid UTF-8)。
    public func encode(_ text: String) throws -> [UInt32] {
        if text.isEmpty { return [] }
        let chunks = Self.preTokenize(text)
        var ids: [UInt32] = []
        ids.reserveCapacity(text.count)
        for chunk in chunks {
            guard let chunkIds = BASAutoRouteRanker.bpeEncode(
                chunk, tokenizer: handle)
            else {
                throw BpeTokenizerError.encodeFailed
            }
            ids.append(contentsOf: chunkIds)
        }
        return ids
    }

    /// Decode token IDs back into a UTF-8 string。 Throws
    /// `.decodeFailed` if the IDs decode to bytes that are not
    /// valid UTF-8 (e.g。 an `<unk>` token mid-sequence that
    /// produces a malformed multi-byte sequence)。
    public func decode(_ ids: [UInt32]) throws -> String {
        if ids.isEmpty { return "" }
        guard let s = BASAutoRouteRanker.bpeDecode(
            ids, tokenizer: handle)
        else {
            throw BpeTokenizerError.decodeFailed
        }
        return s
    }

    /// Number of distinct tokens in the vocab。
    public func vocabSize() -> Int {
        return handle.vocabSize
    }

    /// Whether the actor is wrapping a valid Rust-side
    /// allocation。 False on watchOS or after construction
    /// failure (though init throws in the latter case)。
    public func isValid() -> Bool {
        return handle.isValid
    }

    // MARK: - Whitespace pre-tokenization

    /// Split `text` on whitespace runs。 Returns alternating non-
    /// whitespace + whitespace chunks。 KEEPS whitespace chunks
    /// (rather than discarding them) so vocab tokens that span
    /// a leading whitespace — like GPT-2's " the" / Llama's
    /// "▁the" — still merge inside their chunk。
    ///
    /// Mirrors the GPT-2 byte-level BPE pre-tokenization minus
    /// the punctuation-split (which would require host-provided
    /// regex)。 Hosts that need GPT-2 / Llama exact behavior
    /// should override by passing pre-chunked input via a
    /// custom Tokenizer subclass。
    ///
    /// Examples:
    ///   "the cat"     → ["the", " ", "cat"]
    ///   "  the  cat"  → ["  ", "the", "  ", "cat"]
    ///   " the"        → [" ", "the"]
    ///   "no_space"    → ["no_space"]
    public static func preTokenize(
        _ text: String
    ) -> [String] {
        if text.isEmpty { return [] }
        var chunks: [String] = []
        var current = ""
        var inWhitespace: Bool? = nil
        for scalar in text.unicodeScalars {
            let isWs = scalar.properties
                .isWhitespace
            if inWhitespace == nil {
                inWhitespace = isWs
            } else if isWs != inWhitespace {
                chunks.append(current)
                current = ""
                inWhitespace = isWs
            }
            current.append(Character(scalar))
        }
        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }
}
