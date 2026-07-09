import XCTest
@testable import BASMLXAdapter

/// audit mlx-decode MED-1 — the MTP chain draft width must honor its KV bound.
/// `maxDraftWidth = maxSeq-1-pos0` goes ≤ 0 once the fixed [2048,…] mtpK/mtpV buffer
/// is full (pos0 ≥ 2047). The old inline `max(1, min(…))` returned 1 even then, so the
/// draft wrote `mtpK[pos0 ..< pos0+1]` OUT OF BOUNDS. The clamp now floors at 0 = "no
/// legal draft" and the caller plain-refeeds instead.
final class BASClampedChainWidthTests: XCTestCase {

    private func w(_ k: Int, _ headroom: Int, _ maxDraft: Int) -> Int {
        BASQwen35MTPSpecDecoder.clampedChainWidth(
            preferredK: k, tCapHeadroom: headroom, maxDraftWidth: maxDraft)
    }

    // THE fix — a full/overrun KV bound yields 0 draft, never a 1 that overruns.
    func testKVFullYieldsZeroDraft() {
        XCTAssertEqual(w(3, 11, 0), 0, "maxDraftWidth 0 (buffer full) ⇒ no legal draft")
        XCTAssertEqual(w(3, 11, -1), 0, "a negative bound (pos0 past maxSeq) never returns a positive width")
        XCTAssertEqual(w(3, 11, -50), 0)
    }

    func testNormalRegimeUnchanged() {
        XCTAssertEqual(w(3, 11, 100), 3, "preferredK wins when it is the smallest positive bound")
        XCTAssertEqual(w(3, 1, 100), 1, "the tCap headroom bound wins")
        XCTAssertEqual(w(2, 11, 5), 2, "preferredK still wins over a larger maxDraftWidth")
        XCTAssertEqual(w(9, 4, 6), 4, "the tightest of the three bounds wins")
    }

    // audit mlx-decode MED-1 (complete) — b81490202 clamped only the FUSED-chain draft width; the
    // per-position write bound (mtpForward writes mtpK[pos]) was still unguarded on the sampling,
    // greedy, chain, and compiled lanes. mtpStreamHasRoom gates every draft site.
    private func room(_ pos: Int, _ width: Int) -> Bool {
        BASQwen35MTPSpecDecoder.mtpStreamHasRoom(pos: pos, width: width)
    }

    func testStreamBoundGuardsThePerPositionWrite() {
        let maxSeq = BASQwen35MTPSpecDecoder.maxSeq   // 2048
        // A single draft at the last valid slot is OK; one past the end is NOT (mtpK[maxSeq] overruns).
        XCTAssertTrue(room(maxSeq - 1, 1), "pos maxSeq-1 writes the last valid slot")
        XCTAssertFalse(room(maxSeq, 1), "pos maxSeq would write out of bounds")
        XCTAssertFalse(room(maxSeq + 5, 1), "well past the end is never in bounds")
        XCTAssertFalse(room(-1, 1), "a negative position is never in bounds")
        // A k-wide chain writes pos … pos+k-1: the LAST must stay < maxSeq.
        XCTAssertTrue(room(maxSeq - 5, 5), "a 5-wide chain ending exactly at the last slot fits")
        XCTAssertFalse(room(maxSeq - 4, 5), "a 5-wide chain that would write mtpK[maxSeq] does NOT fit")
    }
}
