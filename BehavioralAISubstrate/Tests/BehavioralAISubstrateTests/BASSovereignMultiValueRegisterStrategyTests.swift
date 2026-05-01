import XCTest
@testable import BASSovereign

/// M296.3.zz higher CRDT — multi-value register strategy contract
/// tests.
///
/// Doctrine pinned:
/// - kind == .crdt (same family as LWW)
/// - Causal-ordered versions: older superseded, only latest kept
/// - Concurrent versions: ALL preserved (key MVR property)
/// - Different refs preserved
/// - Output ordered by canonical merger
final class BASSovereignMultiValueRegisterStrategyTests:
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

    func test_kindIsCRDT() {
        let s = BASSovereignMultiValueRegisterStrategy()
        XCTAssertEqual(s.kind, .crdt)
    }

    // MARK: - Empty

    func test_emptyEmpty_returnsEmpty() async {
        let s = BASSovereignMultiValueRegisterStrategy()
        let result = await s.sync(local: [], remote: [])
        XCTAssertEqual(result, [])
    }

    // MARK: - Causal collapse

    func test_causalOlderSuperseded() async {
        let s = BASSovereignMultiValueRegisterStrategy()
        let v1 = makeFrame(
            ref: "x", device: "A", counters: ["A": 1])
        let v2 = makeFrame(
            ref: "x", device: "A", counters: ["A": 5])
        let result = await s.sync(local: [v1], remote: [v2])
        XCTAssertEqual(result, [v2])
    }

    // MARK: - Concurrent preservation (key MVR property)

    func test_concurrentVersionsAllPreserved() async {
        let s = BASSovereignMultiValueRegisterStrategy()
        let frameA = makeFrame(
            ref: "x", device: "A",
            counters: ["A": 5, "B": 1])
        let frameB = makeFrame(
            ref: "x", device: "B",
            counters: ["A": 1, "B": 5])
        // A and B are concurrent on x.
        XCTAssertEqual(
            frameA.compare(to: frameB), .concurrent)
        let result = await s.sync(
            local: [frameA], remote: [frameB])
        // MVR: both concurrent versions preserved.
        XCTAssertEqual(result.count, 2)
        let originDevices = Set(result.map(\.originDeviceID))
        XCTAssertEqual(originDevices, ["A", "B"])
    }

    func test_threeConcurrent_allPreserved() async {
        let s = BASSovereignMultiValueRegisterStrategy()
        // Three concurrent versions on different devices.
        let fA = makeFrame(
            ref: "x", device: "A",
            counters: ["A": 3])
        let fB = makeFrame(
            ref: "x", device: "B",
            counters: ["B": 3])
        let fC = makeFrame(
            ref: "x", device: "C",
            counters: ["C": 3])
        let result = await s.sync(
            local: [fA], remote: [fB, fC])
        XCTAssertEqual(result.count, 3)
    }

    // MARK: - Mixed: causal + concurrent

    func test_mixedCausalAndConcurrent_concurrentSurvive()
        async
    {
        let s = BASSovereignMultiValueRegisterStrategy()
        // x has 3 versions: A's v1 (older), A's v2 (latest on A),
        // B's v1 (concurrent with both).
        let aV1 = makeFrame(
            ref: "x", device: "A", counters: ["A": 1])
        let aV2 = makeFrame(
            ref: "x", device: "A", counters: ["A": 2])
        let bV1 = makeFrame(
            ref: "x", device: "B", counters: ["B": 1])
        let result = await s.sync(
            local: [aV1, aV2], remote: [bV1])
        // aV1 is dominated by aV2 (causally older on A).
        // aV2 and bV1 are concurrent.
        // MVR: keep both aV2 and bV1; drop aV1.
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains(aV2))
        XCTAssertTrue(result.contains(bV1))
        XCTAssertFalse(result.contains(aV1))
    }

    // MARK: - Different refs preserved

    func test_differentRefsAllPreserved() async {
        let s = BASSovereignMultiValueRegisterStrategy()
        let x = makeFrame(
            ref: "x", device: "A", counters: ["A": 1])
        let y = makeFrame(
            ref: "y", device: "B", counters: ["B": 1])
        let result = await s.sync(local: [x], remote: [y])
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Distinguish from LWW

    func test_mvrPreservesConcurrentLWWPicksOne() async {
        let mvr = BASSovereignMultiValueRegisterStrategy()
        let lww = BASSovereignLWWElementSetStrategy()
        let frameA = makeFrame(
            ref: "x", device: "A",
            counters: ["A": 5, "B": 1])
        let frameB = makeFrame(
            ref: "x", device: "B",
            counters: ["A": 1, "B": 5])
        let mvrResult = await mvr.sync(
            local: [frameA], remote: [frameB])
        let lwwResult = await lww.sync(
            local: [frameA], remote: [frameB])
        XCTAssertEqual(mvrResult.count, 2)
        XCTAssertEqual(lwwResult.count, 1)
    }

    // MARK: - Existential dispatch

    func test_strategyUsableThroughExistential() async {
        let strategy: any BASSovereignFragmentSyncStrategy =
            BASSovereignMultiValueRegisterStrategy()
        let result = await strategy.sync(
            local: [], remote: [])
        XCTAssertEqual(result, [])
        XCTAssertEqual(strategy.kind, .crdt)
    }
}
