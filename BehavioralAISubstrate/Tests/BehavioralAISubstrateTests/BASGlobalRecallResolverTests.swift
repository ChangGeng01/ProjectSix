// ADR-037 — unit tests for BASGlobalRecallResolver (the global-recall seam's atomForID backing).
// Now SPM-testable after relocation from the DeviceTestApp host into BASHostKit. Pins the contract the
// runner's lockstep depends on: put returns the FIFO-evicted ids, the map stays bounded to the cap, and
// re-put / floor / miss behave correctly.

import XCTest
import BASHostKit
import BASMemory
import BASRuntimeCore

final class BASGlobalRecallResolverTests: XCTestCase {

    private func atom(_ s: String) -> BASMemoryAtom {
        BASL8RoutedMemoryService.memoryAtom(from: BASGovernedMemory(
            kind: .semantic, content: s, scope: .user, sensitivity: .low,
            tier: .warm, confidence: 0.7, sourceType: "test",
            governanceStatus: .candidate, provenanceSummary: "resolver-test"))
    }

    /// Over the cap, `put` returns the OLDEST-inserted ids (FIFO), the map stays bounded, and evicted
    /// ids are no longer resolvable while the newest `cap` are — the exact contract the runner mirrors
    /// into the engine (HIGH-1 lockstep).
    func testFIFOEvictionReturnsOldestIdsAndBoundsCount() {
        let cap = BASGlobalRecallResolver.minCap          // 64 (floor — smallest expressible cap)
        let r = BASGlobalRecallResolver(cap: cap)
        var evicted: [String] = []
        for i in 0..<(cap + 10) { evicted += r.put(id: "id-\(i)", atom: atom("a\(i)"), domain: "d") }
        XCTAssertEqual(evicted, (0..<10).map { "id-\($0)" },
            "the 10 oldest ids must be evicted, in FIFO order")
        XCTAssertEqual(r.count, cap, "map stays bounded to the cap")
        XCTAssertNil(r.lookupSync(id: "id-0"), "evicted id must not resolve")
        XCTAssertNotNil(r.lookupSync(id: "id-\(cap + 9)"), "newest id must resolve")
    }

    /// Re-putting an existing id updates the value WITHOUT a second `order` entry (no double-count, no
    /// spurious eviction) — the basis for the runner's exactly-once sync gate.
    func testRePutUpdatesValueWithoutDoubleCount() {
        let r = BASGlobalRecallResolver(cap: BASGlobalRecallResolver.minCap)
        XCTAssertTrue(r.put(id: "x", atom: atom("x1"), domain: "d").isEmpty)
        let ev = r.put(id: "x", atom: atom("x2"), domain: "d")
        XCTAssertTrue(ev.isEmpty, "re-put of an existing id must not evict")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.lookupSync(id: "x")?.atom.summary, "x2", "value is updated to the latest")
    }

    /// The cap is floored at `minCap` (a tiny configured cap can't shrink the corpus below the floor).
    func testCapIsFlooredAtMinCap() {
        let r = BASGlobalRecallResolver(cap: 1)            // below minCap
        for i in 0..<BASGlobalRecallResolver.minCap {
            XCTAssertTrue(r.put(id: "i\(i)", atom: atom("a"), domain: "d").isEmpty,
                "no eviction until the floor is exceeded")
        }
        XCTAssertEqual(r.count, BASGlobalRecallResolver.minCap)
        XCTAssertEqual(r.put(id: "over", atom: atom("a"), domain: "d"), ["i0"],
            "the floor+1th insert evicts the oldest")
    }

    func testLookupMissReturnsNil() {
        let r = BASGlobalRecallResolver(cap: BASGlobalRecallResolver.minCap)
        XCTAssertNil(r.lookupSync(id: "absent"))
    }
}
