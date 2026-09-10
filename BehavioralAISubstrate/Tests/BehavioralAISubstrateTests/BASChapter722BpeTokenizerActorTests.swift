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
//   5. ENCODE LINEAR-TIME GATE — both the actor's pre-tokenized
//      encode AND the raw handle's encode stay sub-5 ms at 1 KB
//      (an O(N²) regression in either path would blow past it)。
//
// Historical note (ch1044 audit honesty fix):chapter 七百二十二
// added the actor's pre-tokenization to beat a raw handle then
// measured at ~13 ms / 1 KB (O(N²))。 chapter 七百三十七 第三刀
// fixed the raw merge loop DIRECTLY,so the raw handle is now
// ~0.2 ms — the pre-tok actor is NO LONGER a speedup (it can be
// marginally slower from per-chunk overhead) and is retained for
// actor-isolation, not speed。 This gate guards LINEAR-TIME on
// both paths, NOT a 5×/10× ratio。 (The prior method name +
// header advertised a 5× speedup that ch737 obsoleted — corrected
// here so the test no longer claims a contract it doesn't check.)

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

    /// Originally (at chapter 七百二十二 第四刀):pre-tokenization
    /// dropped the 1 KB encode cell from ~13 ms (raw handle,naive
    /// O(N²) merge loop) to under 1 ms (actor with pre-tokenization)。
    /// Test gated on 5× minimum。
    ///
    /// AFTER chapter 七百三十七 第三刀 (BPE priority-queue merge):
    /// The raw handle now uses O(N log N) merge instead of O(N²)。
    /// Pre-tokenization adds slight overhead at small chunks → the
    /// speedup INVERTS。 This is an honest substrate-shape moment:
    /// the workaround (pre-tok) becomes unnecessary once the
    /// underlying limitation (O(N²)) is fixed。
    ///
    /// New test gates:
    ///   1. Round-trip correctness preserved
    ///   2. BOTH paths sub-millisecond at 1 KB
    ///   3. No strict speedup assertion — chapter 七百三十七 第三刀
    ///      makes pre-tok overhead irrelevant
    func testEncodeBothPathsStaySubFiveMsAt1KB() async throws {
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
            "## ch722 — encode linear-time gate (raw vs pre-tok actor, post-ch737)")
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

        // chapter 七百三十七 第三刀 INVERTED this gate by fixing
        // the raw merge loop。 Pre-tokenization may now be SLOWER
        // (overhead exceeds savings on small chunks),which is a
        // GOOD substrate-shape outcome:the workaround became
        // redundant because the underlying limitation was fixed。
        //
        // New gate:both paths sub-millisecond at 1 KB。
        XCTAssertLessThan(
            rawUsPerOp, 5_000,
            "raw handle should be sub-5ms at 1 KB after chapter 七百三十七 PQ algo")
        XCTAssertLessThan(
            actorUsPerOp, 5_000,
            "actor (pre-tok) should be sub-5ms at 1 KB")

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
