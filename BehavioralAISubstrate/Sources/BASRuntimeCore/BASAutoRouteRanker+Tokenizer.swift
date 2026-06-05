// MARK: - BASAutoRouteRanker+Tokenizer
// God-object extraction (audit ch1040): the BPE tokenizer FFI passthroughs,
// split out of the 3800-line BASAutoRouteRanker.swift into a cohesive file.
// Pure relocation — same `BASAutoRouteRanker` namespace, same symbols, so every
// call site is unchanged and the move is byte-equal.

import Foundation
#if canImport(BASRustMemoryTrackerBinary)
import BASRustMemoryTrackerBinary
#endif

extension BASAutoRouteRanker {

    // MARK: - BPE tokenizer (chapter 七百二十二 第二刀 / M2282)
    //
    // Substrate's first on-device tokenizer。 Routes through the
    // bas-tokenizer Rust crate via the BASRustMemoryTracker
    // XCFramework's bundled C ABI。 No Swift baseline — net-new
    // capability per the chapter 七百二十一-七百三十 aggressive
    // evolution arc (delegated to external LLM providers until now)。
    //
    // Knife 2 surface:thin pass-through helpers that take a
    // `BASBpeTokenizerHandle` (caller owns vocab loading)。
    // Knife 4 will add `BASBpeTokenizer` Swift bridge actor with
    // bundle-resource vocab loading + thread-safe convenience API。

    /// ABI version of the bundled bas-tokenizer crate。 Pinned at
    /// 1 by `TOKENIZER_ABI_VERSION` in `Cargo/bas-tokenizer/src/
    /// lib.rs`。 Drift tests assert this matches the Rust-side
    /// constant so a future ABI bump cannot silently land。
    public static let bpeTokenizerExpectedABIVersion: Int32 = 1

    /// Returns the bas-tokenizer ABI version that the XCFramework
    /// was built against。 Pure pass-through to the Rust
    /// `bas_tokenizer_abi_version()` symbol。
    public static func bpeTokenizerABIVersion() -> Int32 {
        #if os(iOS) || os(macOS)
        return bas_tokenizer_abi_version()
        #else
        return 0
        #endif
    }

    /// Encode `text` into BPE token IDs using `tokenizer`。
    /// Returns `nil` only when the FFI rejects the input (invalid
    /// UTF-8 — extremely unlikely for `String.utf8` source)。
    ///
    /// Two-pass implementation:first call with capacity 0 to
    /// discover the true ID count,then a second call with the
    /// exact-sized buffer。 Mirrors how Rust returns "needed"
    /// even when output capacity is 0。 No leaks across the FFI
    /// boundary because Swift owns the output buffer。
    public static func bpeEncode(
        _ text: String,
        tokenizer: BASBpeTokenizerHandle
    ) -> [UInt32]? {
        #if os(iOS) || os(macOS)
        guard let raw = tokenizer.opaqueHandle else {
            return nil
        }
        let textBytes = Array(text.utf8)
        // Phase 1:discover required capacity。
        let needed = textBytes.withUnsafeBufferPointer { tp in
            return bas_tokenizer_encode(
                raw,
                tp.baseAddress, textBytes.count,
                nil, 0)
        }
        if needed < 0 { return nil }
        if needed == 0 { return [] }
        // Phase 2:fill the exact-sized buffer。
        var out = [UInt32](
            repeating: 0, count: Int(needed))
        let wrote = textBytes.withUnsafeBufferPointer { tp in
            return out.withUnsafeMutableBufferPointer { op in
                return bas_tokenizer_encode(
                    raw,
                    tp.baseAddress, textBytes.count,
                    op.baseAddress, op.count)
            }
        }
        guard wrote == needed else { return nil }
        return out
        #else
        return nil
        #endif
    }

    /// Decode `ids` back into a UTF-8 string via `tokenizer`。
    /// Returns `nil` when the token IDs decode to a non-UTF-8
    /// byte sequence (or the FFI signals a null pointer)。
    public static func bpeDecode(
        _ ids: [UInt32],
        tokenizer: BASBpeTokenizerHandle
    ) -> String? {
        #if os(iOS) || os(macOS)
        guard let raw = tokenizer.opaqueHandle else {
            return nil
        }
        if ids.isEmpty { return "" }
        // Phase 1:discover required byte capacity。
        let needed = ids.withUnsafeBufferPointer { ip in
            return bas_tokenizer_decode(
                raw,
                ip.baseAddress, ids.count,
                nil, 0)
        }
        if needed < 0 { return nil }
        if needed == 0 { return "" }
        // Phase 2:fill the exact-sized buffer。
        var out = [UInt8](
            repeating: 0, count: Int(needed))
        let wrote = ids.withUnsafeBufferPointer { ip in
            return out.withUnsafeMutableBufferPointer { op in
                return bas_tokenizer_decode(
                    raw,
                    ip.baseAddress, ids.count,
                    op.baseAddress, op.count)
            }
        }
        guard wrote == needed else { return nil }
        return String(decoding: out, as: UTF8.self)
        #else
        return nil
        #endif
    }

    /// Vocab size of the tokenizer handle (or -1 on null
    /// handle / FFI error)。
    public static func bpeVocabSize(
        _ tokenizer: BASBpeTokenizerHandle
    ) -> Int {
        #if os(iOS) || os(macOS)
        guard let raw = tokenizer.opaqueHandle else {
            return -1
        }
        return Int(bas_tokenizer_vocab_size(raw))
        #else
        return -1
        #endif
    }
}

// MARK: - BASBpeTokenizerHandle (chapter 七百二十二 第二刀 / M2282)
//
// RAII wrapper around the opaque `BasTokenizer*` returned by the
// `bas_tokenizer_new` FFI。 Owns the Rust-side heap allocation,
// calls `bas_tokenizer_free` in deinit。 Pass to
// `BASAutoRouteRanker.bpeEncode/bpeDecode` to drive the tokenizer。
//
// Vocab wire format (BIG-ENDIAN length prefixes):
//   vocab:  [u32 count][[u32 token_len][bytes][u32 id]]...
//   merges: [u32 count][[u32 ll][left][u32 rl][right][u32 rank]]...
//
// The handle is `final class` (not `actor`) because the underlying
// Rust tokenizer is read-only after construction — encode/decode
// take `&self` and never mutate state。 Concurrent reads are safe;
// the handle is `Sendable` via `nonisolated(unsafe)` on the pointer
// (single-writer-in-init, single-reader-in-encode/decode,no race)。
//
// Knife 4 will wrap this in a `BASBpeTokenizer` actor with bundle-
// resource vocab loading + a typed-error API。 This Knife 2 surface
// is the low-level building block。

public final class BASBpeTokenizerHandle: @unchecked Sendable {
    /// Underlying opaque pointer to the Rust-side
    /// `Box<bas_tokenizer::Tokenizer>`。 nil on platforms without
    /// the XCFramework (watchOS) OR when construction failed
    /// (malformed wire-format buffers)。
    ///
    /// `nonisolated(unsafe)` mirrors the chapter 七百六 / M2189
    /// BASRustMemoryUsageTrackerActor handle pattern — required
    /// because deinit must release the Rust-side `Box<Tokenizer>`
    /// and Swift 6 strict concurrency blocks non-Sendable access
    /// from nonisolated deinit otherwise。 Safe because the
    /// pointer is only mutated in init (single-writer) and
    /// dropped in deinit (no race after deinit fires)。
    fileprivate nonisolated(unsafe) var opaqueHandle:
        OpaquePointer?

    /// Construct a tokenizer from already-serialized vocab +
    /// merges buffers in the documented BIG-ENDIAN wire format。
    /// Returns nil when:
    ///   - platform has no XCFramework support (watchOS)
    ///   - Rust FFI rejects the wire format (length-prefix
    ///     underrun)
    public init?(
        vocabBuffer: [UInt8],
        mergesBuffer: [UInt8],
        unknownTokenID: UInt32
    ) {
        #if os(iOS) || os(macOS)
        // Empty vocab + empty merges is a degenerate-but-legal
        // tokenizer (every byte → <unk>)。 Rust side accepts it。
        let raw: OpaquePointer? =
            vocabBuffer.withUnsafeBufferPointer { vp in
                mergesBuffer.withUnsafeBufferPointer { mp in
                    return bas_tokenizer_new(
                        vp.baseAddress, vocabBuffer.count,
                        mp.baseAddress, mergesBuffer.count,
                        unknownTokenID)
                }
            }
        guard let nonNil = raw else { return nil }
        self.opaqueHandle = nonNil
        #else
        self.opaqueHandle = nil
        return nil
        #endif
    }

    deinit {
        #if os(iOS) || os(macOS)
        if let h = opaqueHandle {
            // Safe to call from deinit;Rust side just drops
            // the `Box<Tokenizer>` allocation。
            bas_tokenizer_free(h)
        }
        #endif
    }

    /// True iff the handle holds a valid Rust-side allocation。
    /// False on watchOS and on construction failure。
    public var isValid: Bool {
        return opaqueHandle != nil
    }

    /// Vocab size。 -1 on invalid handle。
    public var vocabSize: Int {
        return BASAutoRouteRanker.bpeVocabSize(self)
    }

    // MARK: - Convenience wire-format builders
    //
    // Static helpers that emit the BIG-ENDIAN length-prefixed
    // buffers that `bas_tokenizer_new` consumes。 Used by tests
    // (and by knife 4's BASBpeTokenizer actor) to avoid hand-
    // rolling the byte layout at every call site。

    /// Build the BIG-ENDIAN vocab wire buffer。 Entries are emitted
    /// in caller-provided order — order does not affect tokenizer
    /// behavior since the Rust side stores entries in a HashMap。
    public static func encodeVocabBuffer(
        _ entries: [(token: [UInt8], id: UInt32)]
    ) -> [UInt8] {
        var buf: [UInt8] = []
        buf.reserveCapacity(
            4 + entries.reduce(0) {
                $0 + 4 + $1.token.count + 4
            })
        appendU32BE(&buf, UInt32(entries.count))
        for (token, id) in entries {
            appendU32BE(&buf, UInt32(token.count))
            buf.append(contentsOf: token)
            appendU32BE(&buf, id)
        }
        return buf
    }

    /// Build the BIG-ENDIAN merges wire buffer。 Merges are
    /// applied lowest-rank-first by the Rust BPE engine,so the
    /// caller controls order via the `rank` field (NOT array
    /// position)。
    public static func encodeMergesBuffer(
        _ merges: [(
            left: [UInt8],
            right: [UInt8],
            rank: UInt32)]
    ) -> [UInt8] {
        var buf: [UInt8] = []
        buf.reserveCapacity(
            4 + merges.reduce(0) {
                $0 + 4 + $1.left.count + 4
                + $1.right.count + 4
            })
        appendU32BE(&buf, UInt32(merges.count))
        for (l, r, rank) in merges {
            appendU32BE(&buf, UInt32(l.count))
            buf.append(contentsOf: l)
            appendU32BE(&buf, UInt32(r.count))
            buf.append(contentsOf: r)
            appendU32BE(&buf, rank)
        }
        return buf
    }

    private static func appendU32BE(
        _ buf: inout [UInt8], _ value: UInt32
    ) {
        buf.append(UInt8((value >> 24) & 0xff))
        buf.append(UInt8((value >> 16) & 0xff))
        buf.append(UInt8((value >>  8) & 0xff))
        buf.append(UInt8( value        & 0xff))
    }
}
