import XCTest
@testable import BASSovereign

/// M296.3.zz gossip — anti-entropy gossip strategy contract tests.
///
/// Doctrine pinned:
/// - kind == .gossip
/// - Algorithmically equivalent to vector-clock merge (peer-
///   symmetric exchange of complete states)
/// - Convergent: sync(a, b) == sync(b, a) for any input pair
/// - Empty / single-side scenarios
final class BASSovereignAntiEntropyGossipStrategyTests: XCTestCase {

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

    // MARK: - Kind tag

    func test_kindIsGossip() {
        let s = BASSovereignAntiEntropyGossipStrategy()
        XCTAssertEqual(s.kind, .gossip)
    }

    // MARK: - Empty

    func test_emptyEmpty_returnsEmpty() async {
        let s = BASSovereignAntiEntropyGossipStrategy()
        let result = await s.sync(local: [], remote: [])
        XCTAssertEqual(result, [])
    }

    // MARK: - Convergent (peer-symmetric)

    func test_convergent_syncABEqualsSyncBA() async {
        let s = BASSovereignAntiEntropyGossipStrategy()
        let aFrames = [
            makeFrame(
                ref: "a", device: "A", counters: ["A": 1]),
            makeFrame(
                ref: "b", device: "A", counters: ["A": 2]),
        ]
        let bFrames = [
            makeFrame(
                ref: "c", device: "B", counters: ["B": 1]),
        ]
        let ab = await s.sync(local: aFrames, remote: bFrames)
        let ba = await s.sync(local: bFrames, remote: aFrames)
        XCTAssertEqual(ab, ba)
    }

    // MARK: - Equivalent to vector-clock merge

    func test_outputMatchesVectorClockMerge() async {
        let s = BASSovereignAntiEntropyGossipStrategy()
        let local = [
            makeFrame(
                ref: "x", device: "A", counters: ["A": 1]),
            makeFrame(
                ref: "y", device: "A", counters: ["A": 2]),
        ]
        let remote = [
            makeFrame(
                ref: "z", device: "B",
                counters: ["A": 2, "B": 1]),
        ]
        let viaGossip = await s.sync(
            local: local, remote: remote)
        let viaMerger = BASSovereignFragmentMerger.mergeOrdered(
            local, remote)
        XCTAssertEqual(viaGossip, viaMerger)
    }

    // MARK: - Causal preservation

    func test_causalOrderingPreserved() async {
        let s = BASSovereignAntiEntropyGossipStrategy()
        let v1 = makeFrame(
            ref: "first", device: "A", counters: ["A": 1])
        let v2 = makeFrame(
            ref: "second", device: "A",
            counters: ["A": 2])
        let result = await s.sync(
            local: [v2], remote: [v1])
        // Causal: v1 happened before v2 → v1 first in output.
        XCTAssertLessThan(
            result.firstIndex(of: v1)!,
            result.firstIndex(of: v2)!)
    }

    // MARK: - Existential dispatch

    func test_strategyUsableThroughExistential() async {
        let strategy: any BASSovereignFragmentSyncStrategy =
            BASSovereignAntiEntropyGossipStrategy()
        let result = await strategy.sync(
            local: [], remote: [])
        XCTAssertEqual(result, [])
        XCTAssertEqual(strategy.kind, .gossip)
    }
}
