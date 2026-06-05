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
