import XCTest
@testable import BASSovereign

/// M296.3.z — typed sync protocol kind + strategy contract tests.
///
/// Doctrine pinned:
/// - 4 protocol kinds (vectorClockMerge / crdt / leaderFollower
///   / gossip) — manifest v2 explicit list
/// - All kinds Codable + raw values stable
/// - VectorClockMergeStrategy delegates to M296.3.y merger
///   (output identical to direct merger call)
/// - Strategy is async / Sendable
final class BASSovereignFragmentSyncStrategyTests: XCTestCase {

    // MARK: - Kind enum

    func test_syncProtocolKindHasFourCases() {
        XCTAssertEqual(
            BASSovereignSyncProtocolKind.allCases.count, 4)
    }

    func test_syncProtocolKindRawValuesPinned() {
        XCTAssertEqual(
            BASSovereignSyncProtocolKind.vectorClockMerge
                .rawValue,
            "vectorClockMerge")
        XCTAssertEqual(
            BASSovereignSyncProtocolKind.crdt.rawValue,
            "crdt")
        XCTAssertEqual(
            BASSovereignSyncProtocolKind.leaderFollower
                .rawValue,
            "leaderFollower")
        XCTAssertEqual(
            BASSovereignSyncProtocolKind.gossip.rawValue,
            "gossip")
    }

    func test_kindCodableRoundTrip() throws {
        for k in BASSovereignSyncProtocolKind.allCases {
            let data = try JSONEncoder().encode(k)
            let decoded = try JSONDecoder().decode(
                BASSovereignSyncProtocolKind.self, from: data)
            XCTAssertEqual(decoded, k)
        }
    }

    // MARK: - VectorClockMergeStrategy

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

    func test_vectorClockStrategyKindIsVectorClockMerge() {
        let s = BASSovereignVectorClockMergeStrategy()
        XCTAssertEqual(s.kind, .vectorClockMerge)
    }

    func test_vectorClockStrategy_emptyEmpty() async {
        let s = BASSovereignVectorClockMergeStrategy()
        let result = await s.sync(local: [], remote: [])
        XCTAssertEqual(result, [])
    }

    func test_vectorClockStrategy_delegatesToMerger() async {
        let s = BASSovereignVectorClockMergeStrategy()
        let local = [
            makeFrame(
                ref: "a1", device: "A",
                counters: ["A": 1]),
            makeFrame(
                ref: "a2", device: "A",
                counters: ["A": 2]),
        ]
        let remote = [
            makeFrame(
                ref: "b1", device: "B",
                counters: ["A": 2, "B": 1]),
        ]
        let viaStrategy = await s.sync(
            local: local, remote: remote)
        let viaMerger = BASSovereignFragmentMerger.mergeOrdered(
            local, remote)
        XCTAssertEqual(viaStrategy, viaMerger)
    }

    func test_vectorClockStrategy_typicalSyncFlow() async {
        let s = BASSovereignVectorClockMergeStrategy()
        let a1 = makeFrame(
            ref: "a1", device: "A",
            counters: ["A": 1])
        let a2 = makeFrame(
            ref: "a2", device: "A",
            counters: ["A": 2])
        let b1 = makeFrame(
            ref: "b1", device: "B",
            counters: ["B": 1])
        let b2 = makeFrame(
            ref: "b2", device: "B",
            counters: ["A": 2, "B": 2])
        let merged = await s.sync(
            local: [a1, a2], remote: [b1, b2])
        // Causal: a1 < a2; b1 < b2; a2 < b2.
        XCTAssertLessThan(
            merged.firstIndex(of: a1)!,
            merged.firstIndex(of: a2)!)
        XCTAssertLessThan(
            merged.firstIndex(of: b1)!,
            merged.firstIndex(of: b2)!)
        XCTAssertLessThan(
            merged.firstIndex(of: a2)!,
            merged.firstIndex(of: b2)!)
    }

    // MARK: - Strategy is Sendable / dispatchable through `any`

    func test_strategyUsableThroughExistential() async {
        let strategy: any BASSovereignFragmentSyncStrategy =
            BASSovereignVectorClockMergeStrategy()
        let result = await strategy.sync(
            local: [], remote: [])
        XCTAssertEqual(result, [])
        XCTAssertEqual(strategy.kind, .vectorClockMerge)
    }
}
