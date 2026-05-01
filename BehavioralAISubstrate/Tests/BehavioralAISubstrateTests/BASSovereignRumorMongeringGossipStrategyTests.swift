import XCTest
@testable import BASSovereign

/// M296.3.zz higher gossip — rumor-mongering variant tests.
///
/// Doctrine pinned:
/// - kind == .gossip
/// - Output size ≤ mongerWindowSize
/// - Most recent fragments retained; older dropped when window
///   binds
/// - Window 0 → empty output
/// - Large window → identical to anti-entropy (no drops)
/// - Causal ordering preserved within retained subset
final class BASSovereignRumorMongeringGossipStrategyTests:
    XCTestCase
{

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
        let s = BASSovereignRumorMongeringGossipStrategy()
        XCTAssertEqual(s.kind, .gossip)
    }

    // MARK: - Window 0

    func test_zeroWindow_returnsEmpty() async {
        let s = BASSovereignRumorMongeringGossipStrategy(
            mongerWindowSize: 0)
        let frames = [
            makeFrame(
                ref: "a", device: "A",
                counters: ["A": 1]),
        ]
        let result = await s.sync(
            local: frames, remote: [])
        XCTAssertEqual(result, [])
    }

    // MARK: - Large window

    func test_largeWindow_keepsEverything() async {
        let s = BASSovereignRumorMongeringGossipStrategy(
            mongerWindowSize: 1000)
        let local = [
            makeFrame(
                ref: "a", device: "A",
                counters: ["A": 1]),
            makeFrame(
                ref: "b", device: "B",
                counters: ["B": 1]),
        ]
        let remote = [
            makeFrame(
                ref: "c", device: "C",
                counters: ["C": 1]),
        ]
        let result = await s.sync(
            local: local, remote: remote)
        XCTAssertEqual(result.count, 3)
    }

    func test_largeWindowMatchesAntiEntropy() async {
        let rumor = BASSovereignRumorMongeringGossipStrategy(
            mongerWindowSize: 1000)
        let antiEntropy =
            BASSovereignAntiEntropyGossipStrategy()
        let local = [
            makeFrame(
                ref: "a", device: "A",
                counters: ["A": 1]),
            makeFrame(
                ref: "b", device: "A",
                counters: ["A": 2]),
        ]
        let remote = [
            makeFrame(
                ref: "c", device: "B",
                counters: ["B": 1]),
        ]
        let r1 = await rumor.sync(
            local: local, remote: remote)
        let r2 = await antiEntropy.sync(
            local: local, remote: remote)
        XCTAssertEqual(r1, r2)
    }

    // MARK: - Bounded output

    func test_outputSizeBoundedByWindow() async {
        let s = BASSovereignRumorMongeringGossipStrategy(
            mongerWindowSize: 2)
        let frames = (1...5).map { i in
            makeFrame(
                ref: "ref-\(i)",
                device: "A",
                counters: ["A": UInt64(i)])
        }
        let result = await s.sync(
            local: frames, remote: [])
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Recency selection

    func test_recencyBound_keepsLatest() async {
        let s = BASSovereignRumorMongeringGossipStrategy(
            mongerWindowSize: 2)
        // 3 frames on A, ordered causally A:1 < A:2 < A:3.
        let f1 = makeFrame(
            ref: "first", device: "A",
            counters: ["A": 1])
        let f2 = makeFrame(
            ref: "second", device: "A",
            counters: ["A": 2])
        let f3 = makeFrame(
            ref: "third", device: "A",
            counters: ["A": 3])
        let result = await s.sync(
            local: [f1, f2, f3], remote: [])
        XCTAssertEqual(result.count, 2)
        // Window keeps the 2 most recent (f2 + f3); f1 dropped.
        XCTAssertTrue(result.contains(f2))
        XCTAssertTrue(result.contains(f3))
        XCTAssertFalse(result.contains(f1))
    }

    // MARK: - Causal ordering preserved within window

    func test_causalOrderingPreservedInWindow() async {
        let s = BASSovereignRumorMongeringGossipStrategy(
            mongerWindowSize: 3)
        let f1 = makeFrame(
            ref: "first", device: "A",
            counters: ["A": 1])
        let f2 = makeFrame(
            ref: "second", device: "A",
            counters: ["A": 2])
        let f3 = makeFrame(
            ref: "third", device: "A",
            counters: ["A": 3])
        let result = await s.sync(
            local: [f3, f1, f2], remote: [])
        // Output canonically ordered (ascending causal).
        XCTAssertEqual(result, [f1, f2, f3])
    }

    // MARK: - Empty + small inputs

    func test_emptyEmpty_returnsEmpty() async {
        let s = BASSovereignRumorMongeringGossipStrategy()
        let result = await s.sync(local: [], remote: [])
        XCTAssertEqual(result, [])
    }

    // MARK: - Existential dispatch

    func test_strategyUsableThroughExistential() async {
        let strategy: any BASSovereignFragmentSyncStrategy =
            BASSovereignRumorMongeringGossipStrategy()
        XCTAssertEqual(strategy.kind, .gossip)
        let result = await strategy.sync(
            local: [], remote: [])
        XCTAssertEqual(result, [])
    }

    // MARK: - Negative window clamped to 0

    func test_negativeWindowClampedToZero() async {
        let s = BASSovereignRumorMongeringGossipStrategy(
            mongerWindowSize: -10)
        XCTAssertEqual(s.mongerWindowSize, 0)
        let frames = [
            makeFrame(
                ref: "a", device: "A",
                counters: ["A": 1]),
        ]
        let result = await s.sync(
            local: frames, remote: [])
        XCTAssertEqual(result, [])
    }
}
