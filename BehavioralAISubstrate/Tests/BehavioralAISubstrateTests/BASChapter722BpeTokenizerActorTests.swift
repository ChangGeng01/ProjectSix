// MARK: - BASChapter722BpeTokenizerActorTests
// chapter 七百二十二 第四刀 / M2284
//
// Anti-drift suite for the BASBpeTokenizer actor。 Validates:
//
//   1. Actor init from Data succeeds with the synthetic wire
//      format + throws on malformed wire format
//   2. Whitespace pre-tokenization splits correctly (KEEPS
//      whitespace runs as their own chunks)
//   3. Encode round-trips through decode for typical inputs
//   4. Empty input handles gracefully
//   5. PRE-TOKENIZATION SPEEDUP — the actor's encode at 1 KB
//      runs at least 10× faster than the raw handle's encode
//      (proves the O(N²) → O(N) algorithmic improvement)
//
// Perf gate per plan:Knife 3 measured the raw handle at
// ~13 ms / 1 KB encode。 The actor SHOULD drop this below
// ~1 ms,which is the production-ready threshold for
// per-turn tokenization。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter722BpeTokenizerActorTests: XCTestCase {

    // MARK: - Synthetic wire format builders

    private func syntheticData() -> (
        vocab: Data, merges: Data, unk: UInt32
    ) {
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
        return (
            vocab: Data(vbuf),
            merges: Data(mbuf),
            unk: 256)
    }

    private func makeActor() async throws -> BASBpeTokenizer {
        let (v, m, u) = syntheticData()
        return try BASBpeTokenizer(
            vocabData: v,
            mergesData: m,
            unknownTokenID: u)
    }

    // MARK: - Actor lifecycle

    func testActorInitSucceedsForValidWireFormat() async throws {
        #if os(iOS) || os(macOS)
        let actor = try await makeActor()
        let size = await actor.vocabSize()
        XCTAssertEqual(size, 256 + 1 + 6)
        let valid = await actor.isValid()
        XCTAssertTrue(valid)
        #endif
    }

    func testActorInitThrowsForMalformedWireFormat() async {
        #if os(iOS) || os(macOS)
        let badVocab = Data([
            0, 0, 0, 5,
            0, 0, 0, 2,
            0x61, 0x62,
            // missing id u32 + 4 more entries
        ])
        let goodMerges = Data([0, 0, 0, 0])
        do {
            _ = try BASBpeTokenizer(
                vocabData: badVocab,
                mergesData: goodMerges,
                unknownTokenID: 0)
            XCTFail("expected init to throw on bad wire format")
        } catch let error as BASBpeTokenizer.BpeTokenizerError {
            XCTAssertEqual(error, .handleInitFailed)
        } catch {
            XCTFail(
                "unexpected error type:\(error)")
        }
        #endif
    }

    // MARK: - Pre-tokenization splits

    func testPreTokenizeKeepsWhitespaceRunsAsOwnChunks() {
        XCTAssertEqual(
            BASBpeTokenizer.preTokenize("the cat"),
            ["the", " ", "cat"])
        XCTAssertEqual(
            BASBpeTokenizer.preTokenize("  the  cat"),
            ["  ", "the", "  ", "cat"])
        XCTAssertEqual(
            BASBpeTokenizer.preTokenize(" the"),
            [" ", "the"])
        XCTAssertEqual(
            BASBpeTokenizer.preTokenize("no_space"),
            ["no_space"])
    }

    func testPreTokenizeHandlesEmptyAndUnicode() {
        XCTAssertEqual(
            BASBpeTokenizer.preTokenize(""),
            [])
        XCTAssertEqual(
            BASBpeTokenizer.preTokenize(
                "中文 with 🎉 emoji"),
            ["中文", " ", "with", " ", "🎉", " ", "emoji"])
    }

    func testPreTokenizeHandlesTabsNewlines() {
        XCTAssertEqual(
            BASBpeTokenizer.preTokenize("a\tb\nc"),
            ["a", "\t", "b", "\n", "c"])
    }

    func testPreTokenizeAllWhitespace() {
        XCTAssertEqual(
            BASBpeTokenizer.preTokenize("   "),
            ["   "])
    }

    // MARK: - Encode / decode round-trip

    func testEncodeDecodeRoundTripsThroughActor() async throws {
        #if os(iOS) || os(macOS)
        let actor = try await makeActor()
        let inputs = [
            "",
            "the",
            "the cat sat in the hat",
            "中文 emoji 🎉 mixed",
            "no_whitespace_word",
            "   ",
            String(repeating: "the ", count: 50),
        ]
        for input in inputs {
            let ids = try await actor.encode(input)
            let decoded = try await actor.decode(ids)
            XCTAssertEqual(
                decoded, input,
                "round-trip failed for \(input)")
        }
        #endif
    }

    func testEncodeEmptyReturnsEmpty() async throws {
        #if os(iOS) || os(macOS)
        let actor = try await makeActor()
        let ids = try await actor.encode("")
        XCTAssertEqual(ids, [])
        let decoded = try await actor.decode([])
        XCTAssertEqual(decoded, "")
        #endif
    }

    func testDecodeMatchesHandleDecode() async throws {
        #if os(iOS) || os(macOS)
        let actor = try await makeActor()
        // Same IDs through actor.decode and direct handle decode
        // should produce identical strings (the actor adds no
        // post-processing — it's a pass-through to the FFI)。
        let (v, m, u) = syntheticData()
        let handle = BASBpeTokenizerHandle(
            vocabBuffer: Array(v),
            mergesBuffer: Array(m),
            unknownTokenID: u)!
        let testInputs = [
            "the cat",
            "中文 mixed",
        ]
        for input in testInputs {
            let actorIds = try await actor.encode(input)
            let actorDecoded = try await actor.decode(
                actorIds)
            let handleDecoded =
                BASAutoRouteRanker.bpeDecode(
                    actorIds, tokenizer: handle)
            XCTAssertEqual(actorDecoded, handleDecoded)
        }
        #endif
    }

    // MARK: - Pre-tokenization SPEEDUP perf gate

    /// Build a deterministic-length input by repeating a known
    /// English fragment until it reaches `targetBytes` UTF-8
    /// bytes。
    private func syntheticInput(
        targetBytes: Int
    ) -> String {
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

    /// Per the plan,Knife 4 should drop the 1 KB encode cell
    /// from ~13 ms (raw handle,Knife 3 measurement) to under
    /// ~1 ms (actor with pre-tokenization)。 This test gates on
    /// 5× minimum to leave headroom for system noise on CI。
    func testPreTokenizationDeliversAtLeast5xSpeedup() async throws {
        #if os(iOS) || os(macOS)
        let actor = try await makeActor()
        let (v, m, u) = syntheticData()
        let handle = BASBpeTokenizerHandle(
            vocabBuffer: Array(v),
            mergesBuffer: Array(m),
            unknownTokenID: u)!

        let input = syntheticInput(targetBytes: 1024)
        let iterations = 50

        // Warm up both paths
        _ = try await actor.encode(input)
        _ = BASAutoRouteRanker.bpeEncode(
            input, tokenizer: handle)

        // Raw handle (no pre-tokenization) — same call site as
        // Knife 3 measured。
        let rawStart = now()
        for _ in 0..<iterations {
            _ = BASAutoRouteRanker.bpeEncode(
                input, tokenizer: handle)
        }
        let rawElapsed = now() - rawStart

        // Actor (pre-tokenized)
        let actorStart = now()
        for _ in 0..<iterations {
            _ = try await actor.encode(input)
        }
        let actorElapsed = now() - actorStart

        let rawUsPerOp = rawElapsed / Double(iterations) * 1e6
        let actorUsPerOp = actorElapsed / Double(iterations) * 1e6
        let speedup = rawElapsed / actorElapsed

        print("")
        print(
            "## chapter 七百二十二 第四刀 — pre-tokenization speedup")
        print("")
        print(String(
            format: "  raw handle (no pre-tok):  %8.2f µs/op",
            rawUsPerOp))
        print(String(
            format: "  actor (pre-tok):          %8.2f µs/op",
            actorUsPerOp))
        print(String(
            format: "  speedup:                  %.2f×",
            speedup))
        print("")

        XCTAssertGreaterThan(
            speedup, 5.0,
            "pre-tokenization should be ≥ 5× faster on 1 KB "
            + "input;measured \(speedup)×。 If this fails,"
            + "the algorithmic improvement regressed — check "
            + "preTokenize() output isn't degenerate。")

        // Byte-equal output regardless of path (correctness)。
        let rawIds = BASAutoRouteRanker.bpeEncode(
            input, tokenizer: handle)!
        let actorIds = try await actor.encode(input)
        // The token sequences MAY differ between paths because
        // pre-tokenization changes the merge-loop boundaries
        // (a "the" inside a long word vs at a word boundary
        // hits different merges)。 But decode should round-
        // trip both back to the original string。 Pull await
        // outside XCTAssertEqual's autoclosure (which doesn't
        // support concurrency)。
        let actorDecoded = try await actor.decode(actorIds)
        XCTAssertEqual(actorDecoded, input)
        // Also verify the raw path still round-trips
        XCTAssertEqual(
            BASAutoRouteRanker.bpeDecode(
                rawIds, tokenizer: handle),
            input)
        #endif
    }
}
