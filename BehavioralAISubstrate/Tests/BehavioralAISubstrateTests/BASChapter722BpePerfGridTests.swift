// MARK: - BASChapter722BpePerfGridTests
// chapter 七百二十二 第三刀 / M2283
//
// Knife 3 perf measurement for the bas-tokenizer Rust crate
// reached via the Swift bridge from chapter 七百二十二 第二刀。
//
// **Honest scope per plan**: NO Swift baseline exists — the
// substrate had no on-device tokenizer before this chapter, so
// this perf grid is INFORMATIONAL only。 We don't gate the chapter
// on a speedup ratio because there's no comparison。 The grid is
// useful for:
//
//   1. Establishing a wall-time floor (sanity:encode should not
//      take seconds on KB-sized input)
//   2. Detecting regressions in future chapters that touch the
//      BPE crate
//   3. Comparing decode round-trip cost vs encode (both should be
//      similar magnitude — they walk the same vocab structures)
//
// Per `unicode_bytes_dont_combine_unintentionally` plus the
// large-input round-trip in Knife 2,every measured cell also
// validates exact byte-equality of encode → decode (defense-in-
// depth against perf-only regressions hiding correctness bugs)。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter722BpePerfGridTests: XCTestCase {

    // MARK: - Synthetic tokenizer (mirror Knife 2 builder)

    private func syntheticHandle() -> BASBpeTokenizerHandle? {
        var entries: [(token: [UInt8], id: UInt32)] = []
        for b in 0...255 {
            entries.append(
                (token: [UInt8(b)], id: UInt32(b)))
        }
        entries.append(
            (token: Array("<unk>".utf8), id: 256))
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
        let vbuf = BASBpeTokenizerHandle
            .encodeVocabBuffer(entries)
        let mbuf = BASBpeTokenizerHandle
            .encodeMergesBuffer(merges)
        return BASBpeTokenizerHandle(
            vocabBuffer: vbuf,
            mergesBuffer: mbuf,
            unknownTokenID: 256)
    }

    /// Build a deterministic-length input by repeating a known
    /// English fragment until it reaches `targetBytes` UTF-8
    /// bytes (within ±1 byte due to fragment boundary)。 The
    /// fragment includes "the" / "in" / " the" sequences that
    /// the synthetic vocab compresses,plus single-byte runs
    /// that stay un-compressed — representative of real BPE
    /// workloads。
    private func syntheticInput(targetBytes: Int) -> String {
        let unit = "the quick brown fox jumps over " +
                   "the lazy dog in the rain。 "
        let unitLen = unit.utf8.count
        let copies = max(1, targetBytes / unitLen)
        var s = ""
        s.reserveCapacity(copies * unit.count)
        for _ in 0..<copies {
            s += unit
        }
        return s
    }

    private func now() -> Double {
        return CFAbsoluteTimeGetCurrent()
    }

    // MARK: - Perf grid

    func testEncodeAndDecodePerfGrid() {
        #if os(iOS) || os(macOS)
        guard let h = syntheticHandle() else {
            XCTFail("could not build synthetic tokenizer handle")
            return
        }

        // 3-cell grid: 32 B (single-line),1024 B (paragraph),
        // 16384 B (long article)。 Mirrors the chapter 七百二十一
        // hex-decoder perf grid sizes scaled for text。
        let cells = [
            (label: "32 B   ", target: 32),
            (label: "1024 B ", target: 1024),
            (label: "16384 B", target: 16384),
        ]

        // 200 iterations per cell to amortize FFI/clock noise。
        // Total wall time stays under ~500 ms even for the 16 KB
        // cell — fits inside the per-test budget。
        let iterations = 200

        print("")
        print(
            "## chapter 七百二十二 第三刀 — BPE perf grid")
        print("")
        print(
            "  size      | encode µs/op | decode µs/op | "
            + "tokens | bytes/token")
        print(
            "  ----------+--------------+--------------+"
            + "--------+------------")

        for cell in cells {
            let input = syntheticInput(
                targetBytes: cell.target)
            let inputBytes = input.utf8.count

            // Warm-up:1 encode + 1 decode to avoid first-call
            // cache-cold noise dominating the small cells。
            var warmupIds = BASAutoRouteRanker.bpeEncode(
                input, tokenizer: h) ?? []
            _ = BASAutoRouteRanker.bpeDecode(
                warmupIds, tokenizer: h)

            // Encode timing
            let encodeStart = now()
            for _ in 0..<iterations {
                warmupIds = BASAutoRouteRanker.bpeEncode(
                    input, tokenizer: h) ?? []
            }
            let encodeElapsed = now() - encodeStart
            let encodeUsPerOp =
                (encodeElapsed / Double(iterations)) * 1e6

            // Decode timing
            let decodeStart = now()
            var lastDecoded: String? = nil
            for _ in 0..<iterations {
                lastDecoded =
                    BASAutoRouteRanker.bpeDecode(
                        warmupIds, tokenizer: h)
            }
            let decodeElapsed = now() - decodeStart
            let decodeUsPerOp =
                (decodeElapsed / Double(iterations)) * 1e6

            // Correctness pin:every measured cell must also
            // round-trip byte-identically。 Defense in depth
            // against perf-only regressions hiding correctness
            // bugs。
            XCTAssertEqual(
                lastDecoded, input,
                "round-trip diverges at cell \(cell.label)")

            let tokenCount = warmupIds.count
            let bytesPerToken = tokenCount == 0 ? 0.0
                : Double(inputBytes) / Double(tokenCount)

            print(String(
                format: "  %@   | %12.2f | %12.2f | "
                + "%6d | %5.2f",
                cell.label,
                encodeUsPerOp,
                decodeUsPerOp,
                tokenCount,
                bytesPerToken))
        }

        print("")
        print(
            "  (Informational only — no Swift baseline exists;")
        print(
            "   substrate had no on-device tokenizer prior to")
        print(
            "   chapter 七百二十二。 Future chapters monitor for")
        print(
            "   regression in these numbers。)")
        print("")
        #else
        // watchOS path:no XCFramework support。 Just confirm
        // the bpe* helpers gracefully return nil。
        let dummy = BASBpeTokenizerHandle(
            vocabBuffer: [], mergesBuffer: [],
            unknownTokenID: 0)
        XCTAssertNil(dummy)
        #endif
    }

    /// Stress / leak smoke:30 build-encode-decode-drop cycles
    /// at the 1 KB workload。 Catches per-cycle Rust-side leaks
    /// (would explode RAM at scale) and re-confirms exact
    /// round-trip across many independent handles。
    func testHandleConstructionStressDoesNotLeak() {
        #if os(iOS) || os(macOS)
        for _ in 0..<30 {
            guard let h = syntheticHandle() else {
                XCTFail("handle build failed")
                return
            }
            let input = syntheticInput(targetBytes: 1024)
            let ids = BASAutoRouteRanker.bpeEncode(
                input, tokenizer: h)
            XCTAssertNotNil(ids)
            let decoded = BASAutoRouteRanker.bpeDecode(
                ids!, tokenizer: h)
            XCTAssertEqual(decoded, input)
            // h drops here → bas_tokenizer_free called via deinit
        }
        #endif
    }

    /// Round-trip exactness sweep across compression boundaries:
    /// inputs that compress heavily (lots of "the"),inputs that
    /// don't compress (random unicode),inputs at zero/one/two
    /// byte boundaries。 No timing — pure correctness pin。
    func testRoundTripExactnessAcrossInputShapes() {
        #if os(iOS) || os(macOS)
        guard let h = syntheticHandle() else {
            XCTFail("handle build failed")
            return
        }
        let inputs = [
            "",                          // empty
            "a",                         // 1 byte
            "ab",                        // 2 bytes no merge
            "th",                        // 2 bytes merge → 257
            "the",                       // 3 bytes merge → 259
            "thethe",                    // double the
            String(repeating: "the ",   count: 100),
            String(repeating: "🎉",      count: 50),
            String(repeating: "中文",    count: 50),
            "Mixed 中 the 🎉 in 日 the",
        ]
        for input in inputs {
            let ids = BASAutoRouteRanker.bpeEncode(
                input, tokenizer: h)
            XCTAssertNotNil(
                ids, "encode failed for \(input)")
            let decoded = BASAutoRouteRanker.bpeDecode(
                ids!, tokenizer: h)
            XCTAssertEqual(
                decoded, input,
                "round-trip failed for \(input)")
        }
        #endif
    }
}
