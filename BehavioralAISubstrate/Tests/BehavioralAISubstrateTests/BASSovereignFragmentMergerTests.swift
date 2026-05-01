import XCTest
@testable import BASSovereign

/// M296.3.y — fragment merger contract tests.
///
/// Doctrine pinned:
/// - Empty + non-empty merge returns sorted non-empty
/// - Byte-identical frames are deduplicated
/// - Causally-ordered frames merge in causal order
/// - Concurrent frames tie-break on originDeviceID ASC
/// - Same-origin concurrent frames tie-break on auditEntryRef ASC
/// - Idempotent: merge(a, a) == sorted(a, dedup'd)
/// - Commutative: merge(a, b).set == merge(b, a).set
final class BASSovereignFragmentMergerTests: XCTestCase {

    private func makeFrame(
        ref: String,
        device: String,
        counters: [String: UInt64]
    ) -> BASSovereignCrossDeviceLedgerFrame {
        BASSovereignCrossDeviceLedgerFrame(
            auditEntryRef: ref,
            originDeviceID: device,
            clock: BASSovereignCrossDeviceClock(
                deviceCounters: counters))
    }

    // MARK: - Empty handling

    func test_emptyPlusEmpty_returnsEmpty() {
        let merged = BASSovereignFragmentMerger.mergeOrdered(
            [], [])
        XCTAssertEqual(merged, [])
    }

    func test_singleSidePopulated_returnsSorted() {
        let frames = [
            makeFrame(ref: "z", device: "B", counters: ["B": 2]),
            makeFrame(ref: "a", device: "A", counters: ["A": 1]),
        ]
        let merged = BASSovereignFragmentMerger.mergeOrdered(
            frames, [])
        // Both are concurrent; origin asc → A first.
        XCTAssertEqual(merged.first?.originDeviceID, "A")
    }

    // MARK: - Deduplication

    func test_byteIdenticalFramesDedupe() {
        let f1 = makeFrame(
            ref: "a", device: "A", counters: ["A": 1])
        let f2 = makeFrame(
            ref: "a", device: "A", counters: ["A": 1])
        let merged = BASSovereignFragmentMerger.mergeOrdered(
            [f1], [f2])
        XCTAssertEqual(merged.count, 1)
    }

    func test_partialDuplicates_differingClocksSurvive() {
        let f1 = makeFrame(
            ref: "a", device: "A", counters: ["A": 1])
        let f2 = makeFrame(
            ref: "a", device: "A", counters: ["A": 2])
        let merged = BASSovereignFragmentMerger.mergeOrdered(
            [f1], [f2])
        XCTAssertEqual(merged.count, 2)
    }

    // MARK: - Causal ordering

    func test_causallyOrderedFramesMergeInCausalOrder() {
        // f1 strictly before f2 (clock A:1 vs A:2).
        let f1 = makeFrame(
            ref: "first", device: "A", counters: ["A": 1])
        let f2 = makeFrame(
            ref: "second", device: "A", counters: ["A": 2])
        // f3 strictly before f4 on B.
        let f3 = makeFrame(
            ref: "alpha", device: "B", counters: ["B": 1])
        let f4 = makeFrame(
            ref: "beta", device: "B",
            counters: ["A": 2, "B": 2])
        let merged = BASSovereignFragmentMerger.mergeOrdered(
            [f2, f1], [f4, f3])
        // Each device's frames must appear in causal order.
        let f1Index = merged.firstIndex(of: f1)!
        let f2Index = merged.firstIndex(of: f2)!
        XCTAssertLessThan(f1Index, f2Index)
        let f3Index = merged.firstIndex(of: f3)!
        let f4Index = merged.firstIndex(of: f4)!
        XCTAssertLessThan(f3Index, f4Index)
    }

    // MARK: - Concurrent tie-break

    func test_concurrentFrames_tieBreakOnOriginAsc() {
        // f1 ahead on A, f2 ahead on B → concurrent.
        let f1 = makeFrame(
            ref: "x", device: "A",
            counters: ["A": 5, "B": 1])
        let f2 = makeFrame(
            ref: "y", device: "B",
            counters: ["A": 2, "B": 4])
        XCTAssertEqual(f1.compare(to: f2), .concurrent)
        let merged = BASSovereignFragmentMerger.mergeOrdered(
            [f1], [f2])
        XCTAssertEqual(merged[0], f1) // device A first
        XCTAssertEqual(merged[1], f2)
    }

    func test_sameOriginConcurrent_tieBreakOnAuditRefAsc() {
        // Two frames same origin, same clock → concurrent + same-origin.
        let f1 = makeFrame(
            ref: "ref-z", device: "A",
            counters: ["A": 1])
        let f2 = makeFrame(
            ref: "ref-a", device: "A",
            counters: ["A": 1])
        let merged = BASSovereignFragmentMerger.mergeOrdered(
            [f1], [f2])
        // ref-a sorts before ref-z.
        XCTAssertEqual(merged[0].auditEntryRef, "ref-a")
        XCTAssertEqual(merged[1].auditEntryRef, "ref-z")
    }

    // MARK: - Idempotent / Commutative

    func test_idempotent_mergeWithSelf() {
        let frames = [
            makeFrame(
                ref: "a", device: "A", counters: ["A": 1]),
            makeFrame(
                ref: "b", device: "B", counters: ["B": 1]),
        ]
        let once = BASSovereignFragmentMerger.mergeOrdered(
            frames, frames)
        let twice = BASSovereignFragmentMerger.mergeOrdered(
            once, once)
        XCTAssertEqual(once, twice)
        // dedup'd: still 2 frames.
        XCTAssertEqual(once.count, 2)
    }

    func test_commutative_setEquality() {
        let a = [
            makeFrame(
                ref: "a", device: "A", counters: ["A": 1]),
        ]
        let b = [
            makeFrame(
                ref: "b", device: "B", counters: ["B": 1]),
        ]
        let ab = BASSovereignFragmentMerger.mergeOrdered(a, b)
        let ba = BASSovereignFragmentMerger.mergeOrdered(b, a)
        XCTAssertEqual(Set(ab), Set(ba))
        // Order is the same because comparator is total.
        XCTAssertEqual(ab, ba)
    }

    // MARK: - Mixed scenarios

    func test_typicalSyncMerge() {
        // Device A: ticked twice locally → frames ref-a1, ref-a2.
        let a1 = makeFrame(
            ref: "ref-a1", device: "A", counters: ["A": 1])
        let a2 = makeFrame(
            ref: "ref-a2", device: "A", counters: ["A": 2])

        // Device B: ticked once, then ingested A's clock.
        let b1 = makeFrame(
            ref: "ref-b1", device: "B", counters: ["B": 1])
        let b2 = makeFrame(
            ref: "ref-b2", device: "B",
            counters: ["A": 2, "B": 2])

        let merged = BASSovereignFragmentMerger.mergeOrdered(
            [a1, a2], [b1, b2])

        // a1, a2 must keep order.
        XCTAssertLessThan(
            merged.firstIndex(of: a1)!,
            merged.firstIndex(of: a2)!)
        // b1, b2 must keep order.
        XCTAssertLessThan(
            merged.firstIndex(of: b1)!,
            merged.firstIndex(of: b2)!)
        // a2 happened before b2 (b ingested a's clock) →
        // a2 comes before b2 in merged.
        XCTAssertLessThan(
            merged.firstIndex(of: a2)!,
            merged.firstIndex(of: b2)!)
    }
}
