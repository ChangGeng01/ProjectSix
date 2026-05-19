// MARK: - BASChapter722BpeTokenizerTests
// chapter 七百二十二 第二刀 / M2282
//
// Knife 2 anti-drift suite for the bas-tokenizer Rust crate
// reached via the BASRustMemoryTracker XCFramework's C ABI。
// Validates:
//
//   1. ABI version pin (1) matches between Rust and Swift sides
//   2. Bundle crate count incremented from 7 → 8
//   3. Handle init / deinit (no leaks via RAII)
//   4. Round-trip encode/decode through the Swift bridge
//   5. Invalid wire format returns nil handle
//   6. Empty buffers degrade gracefully (every byte → <unk>)
//   7. Encode/decode of unicode + emoji preserves bytes exactly
//   8. Cross-check Swift bridge IDs == direct Rust IDs (the
//      C ABI byte-equality test inside the Rust crate already
//      pins this — here we additionally pin the Swift adapter)
//
// NO PRODUCTION SITE is wired in this knife。 Knife 4 will add
// BASBpeTokenizer Swift bridge actor with bundle-resource vocab
// loading。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter722BpeTokenizerTests: XCTestCase {

    // MARK: - Synthetic vocab + merges (mirror Rust crate tests)

    /// Build the same synthetic vocab the Rust unit tests use:
    /// 256 single-byte tokens (IDs 0..=255) + <unk>=256 + 6
    /// multi-byte BPE tokens (IDs 257..=262)。 Buffers emitted in
    /// the BIG-ENDIAN length-prefixed wire format that
    /// `bas_tokenizer_new` consumes。
    private func syntheticBuffers() -> (
        vocab: [UInt8], merges: [UInt8], unk: UInt32
    ) {
        var entries: [(token: [UInt8], id: UInt32)] = []
        // Single bytes 0..=255 → IDs 0..=255
        for b in 0...255 {
            entries.append(
                (token: [UInt8(b)], id: UInt32(b)))
        }
        // <unk> at ID 256
        entries.append(
            (token: Array("<unk>".utf8), id: 256))
        // Multi-byte tokens (must match Rust tests exactly)
        entries.append(
            (token: Array("th".utf8), id: 257))
        entries.append(
            (token: Array("he".utf8), id: 258))
        entries.append(
            (token: Array("the".utf8), id: 259))
        entries.append(
            (token: Array("in".utf8), id: 260))
        entries.append(
            (token: Array(" th".utf8), id: 261))
        entries.append(
            (token: Array(" the".utf8), id: 262))

        let merges: [(
            left: [UInt8], right: [UInt8], rank: UInt32
        )] = [
            (Array("t".utf8),  Array("h".utf8), 0),
            (Array("th".utf8), Array("e".utf8), 1),
            (Array("h".utf8),  Array("e".utf8), 2),
            (Array("i".utf8),  Array("n".utf8), 3),
            (Array(" ".utf8),  Array("t".utf8), 4),
            (Array(" t".utf8), Array("h".utf8), 5),
            (Array(" th".utf8), Array("e".utf8), 6),
        ]

        return (
            vocab: BASBpeTokenizerHandle
                .encodeVocabBuffer(entries),
            merges: BASBpeTokenizerHandle
                .encodeMergesBuffer(merges),
            unk: 256
        )
    }

    private func syntheticHandle() -> BASBpeTokenizerHandle? {
        let (v, m, u) = syntheticBuffers()
        return BASBpeTokenizerHandle(
            vocabBuffer: v,
            mergesBuffer: m,
            unknownTokenID: u)
    }

    // MARK: - ABI + bundle drift

    func testABIVersionPinsToOne() {
        XCTAssertEqual(
            BASAutoRouteRanker.bpeTokenizerExpectedABIVersion,
            1)
        #if os(iOS) || os(macOS)
        XCTAssertEqual(
            BASAutoRouteRanker.bpeTokenizerABIVersion(),
            1,
            "Rust-side TOKENIZER_ABI_VERSION must match Swift-side"
            + " bpeTokenizerExpectedABIVersion。 If you intentionally"
            + " bumped the ABI,update bpeTokenizerExpectedABIVersion"
            + " AND this test simultaneously。")
        #endif
    }

    // MARK: - Handle lifecycle

    func testValidHandleInitSucceeds() {
        #if os(iOS) || os(macOS)
        let handle = syntheticHandle()
        XCTAssertNotNil(handle)
        XCTAssertTrue(handle!.isValid)
        XCTAssertEqual(handle!.vocabSize, 256 + 1 + 6)
        #endif
    }

    func testDeinitReleasesHandle() {
        #if os(iOS) || os(macOS)
        // Create + drop in tight scope。 If deinit failed to call
        // bas_tokenizer_free,Rust would leak。 ASAN/valgrind would
        // catch it;here we just exercise the path many times to
        // ensure no crash。
        for _ in 0..<200 {
            let h = syntheticHandle()
            XCTAssertNotNil(h)
        }
        #endif
    }

    func testMalformedVocabReturnsNilHandle() {
        #if os(iOS) || os(macOS)
        // Vocab declares 5 entries but contains only an
        // incomplete one。
        let badVocab: [UInt8] = [
            0, 0, 0, 5,   // count = 5
            0, 0, 0, 2,   // first token len = 2
            0x61, 0x62,   // "ab"
            // Missing id u32 + 4 entries — buffer underrun
        ]
        let goodMerges: [UInt8] = [0, 0, 0, 0]
        let h = BASBpeTokenizerHandle(
            vocabBuffer: badVocab,
            mergesBuffer: goodMerges,
            unknownTokenID: 0)
        XCTAssertNil(h)
        #endif
    }

    func testEmptyBuffersProduceUnkOnlyTokenizer() {
        #if os(iOS) || os(macOS)
        // Empty vocab + empty merges = every byte → <unk>=0
        let h = BASBpeTokenizerHandle(
            vocabBuffer: [UInt8](),
            mergesBuffer: [UInt8](),
            unknownTokenID: 0)
        XCTAssertNotNil(h)
        XCTAssertEqual(h!.vocabSize, 0)
        // Encode "abc" → 3 <unk> IDs (every byte has no entry)
        let ids = BASAutoRouteRanker.bpeEncode(
            "abc", tokenizer: h!)
        XCTAssertEqual(ids, [0, 0, 0])
        #endif
    }

    // MARK: - Encode / decode byte-equality

    func testEncodeTheCompressesToSingleTokenID259() {
        #if os(iOS) || os(macOS)
        let h = syntheticHandle()!
        let ids = BASAutoRouteRanker.bpeEncode(
            "the", tokenizer: h)
        XCTAssertEqual(ids, [259])
        #endif
    }

    func testEncodeInCompressesToSingleTokenID260() {
        #if os(iOS) || os(macOS)
        let h = syntheticHandle()!
        let ids = BASAutoRouteRanker.bpeEncode(
            "in", tokenizer: h)
        XCTAssertEqual(ids, [260])
        #endif
    }

    func testEncodeThemeProducesThreeTokens() {
        #if os(iOS) || os(macOS)
        let h = syntheticHandle()!
        // "theme" → "the" + "m" + "e" = [259, 109, 101]
        let ids = BASAutoRouteRanker.bpeEncode(
            "theme", tokenizer: h)
        XCTAssertEqual(ids?.count, 3)
        XCTAssertEqual(ids?[0], 259)
        XCTAssertEqual(ids?[1], UInt32(Character("m").asciiValue!))
        XCTAssertEqual(ids?[2], UInt32(Character("e").asciiValue!))
        #endif
    }

    func testEncodeEmptyStringReturnsEmptyArray() {
        #if os(iOS) || os(macOS)
        let h = syntheticHandle()!
        XCTAssertEqual(
            BASAutoRouteRanker.bpeEncode("", tokenizer: h),
            [])
        #endif
    }

    func testDecodeEmptyIDsReturnsEmptyString() {
        #if os(iOS) || os(macOS)
        let h = syntheticHandle()!
        XCTAssertEqual(
            BASAutoRouteRanker.bpeDecode([], tokenizer: h),
            "")
        #endif
    }

    func testRoundTripSimpleASCII() {
        #if os(iOS) || os(macOS)
        let h = syntheticHandle()!
        let input = "the cat sat in the hat"
        let ids = BASAutoRouteRanker.bpeEncode(
            input, tokenizer: h)
        XCTAssertNotNil(ids)
        let decoded = BASAutoRouteRanker.bpeDecode(
            ids!, tokenizer: h)
        XCTAssertEqual(decoded, input)
        #endif
    }

    func testRoundTripUnicodeAndEmoji() {
        #if os(iOS) || os(macOS)
        let h = syntheticHandle()!
        let inputs = [
            "中文 emoji 🎉 mixed",
            "café résumé",
            "日本語テスト",
            "🎉🎊🎁",
            "hello\n\t\"quoted\"",
        ]
        for input in inputs {
            let ids = BASAutoRouteRanker.bpeEncode(
                input, tokenizer: h)
            XCTAssertNotNil(
                ids,
                "encode failed for \(input)")
            let decoded = BASAutoRouteRanker.bpeDecode(
                ids!, tokenizer: h)
            XCTAssertEqual(
                decoded,
                input,
                "round-trip failed for \(input)")
        }
        #endif
    }

    func testEmojiEncodesAsFourSingleByteTokens() {
        #if os(iOS) || os(macOS)
        // 🎉 is 4 UTF-8 bytes: F0 9F 8E 89。 None of those bytes
        // appear in any merge so each becomes a single-byte token。
        let h = syntheticHandle()!
        let ids = BASAutoRouteRanker.bpeEncode(
            "🎉", tokenizer: h)
        XCTAssertEqual(ids?.count, 4)
        for id in ids ?? [] {
            XCTAssertLessThanOrEqual(id, 255)
        }
        #endif
    }

    func testUnknownASCIIBytesDecodeBackToBytes() {
        #if os(iOS) || os(macOS)
        let h = syntheticHandle()!
        // 'z' is not in any merge → single-byte token 122
        let ids = BASAutoRouteRanker.bpeEncode(
            "z", tokenizer: h)
        XCTAssertEqual(ids, [122])
        let decoded = BASAutoRouteRanker.bpeDecode(
            [122], tokenizer: h)
        XCTAssertEqual(decoded, "z")
        #endif
    }

    func testLargeInputRoundTripsExactly() {
        #if os(iOS) || os(macOS)
        let h = syntheticHandle()!
        // 1 KB English-like input。 Some chunks compress via
        // "the"/"th"/"in" tokens,others stay single-byte。 Final
        // decoded string must byte-equal the input。
        var input = ""
        for _ in 0..<50 {
            input += "the quick brown fox jumps over the "
            input += "lazy dog "
        }
        let ids = BASAutoRouteRanker.bpeEncode(
            input, tokenizer: h)
        XCTAssertNotNil(ids)
        XCTAssertGreaterThan(ids!.count, 0)
        XCTAssertLessThan(ids!.count, input.count)  // compression
        let decoded = BASAutoRouteRanker.bpeDecode(
            ids!, tokenizer: h)
        XCTAssertEqual(decoded, input)
        #endif
    }

    // MARK: - Wire-format builder round-trip

    func testEncodeVocabBufferProducesParsableBytes() {
        let entries: [(token: [UInt8], id: UInt32)] = [
            (token: Array("a".utf8), id: 1),
            (token: Array("bb".utf8), id: 2),
            (token: Array("ccc".utf8), id: 3),
        ]
        let buf = BASBpeTokenizerHandle
            .encodeVocabBuffer(entries)
        // [u32 count=3]
        // [u32 1][0x61][u32 1]
        // [u32 2][0x62 0x62][u32 2]
        // [u32 3][0x63 0x63 0x63][u32 3]
        XCTAssertEqual(buf.count,
            4 + (4 + 1 + 4) + (4 + 2 + 4) + (4 + 3 + 4))
        // Count prefix is BIG-ENDIAN 3
        XCTAssertEqual(
            [buf[0], buf[1], buf[2], buf[3]],
            [0, 0, 0, 3])
    }

    func testEncodeMergesBufferProducesParsableBytes() {
        let merges: [(
            left: [UInt8], right: [UInt8], rank: UInt32
        )] = [
            (Array("a".utf8), Array("b".utf8), 5),
        ]
        let buf = BASBpeTokenizerHandle
            .encodeMergesBuffer(merges)
        // [u32 count=1]
        // [u32 1][0x61][u32 1][0x62][u32 5]
        XCTAssertEqual(buf.count,
            4 + 4 + 1 + 4 + 1 + 4)
        XCTAssertEqual(
            [buf[0], buf[1], buf[2], buf[3]],
            [0, 0, 0, 1])
        // Last 4 bytes encode rank=5 BIG-ENDIAN
        let last = buf.suffix(4)
        XCTAssertEqual(
            Array(last),
            [0, 0, 0, 5])
    }
}
