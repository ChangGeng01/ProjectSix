import XCTest
@testable import BASSovereign

/// M296.3.zz (partial) — leader-follower strategy contract tests.
///
/// Doctrine pinned:
/// - kind == .leaderFollower
/// - All leader frames preserved verbatim
/// - Non-leader frames with novel auditEntryRef preserved
/// - Non-leader frames whose auditEntryRef the leader has → discarded
/// - Final ordering follows merger's deterministic rules
final class BASSovereignLeaderFollowerStrategyTests: XCTestCase {

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

    func test_kindIsLeaderFollower() {
        let s = BASSovereignLeaderFollowerStrategy(
            leaderDeviceID: "leader")
        XCTAssertEqual(s.kind, .leaderFollower)
    }

    // MARK: - Leader frames preserved

    func test_allLeaderFramesPreserved() async {
        let s = BASSovereignLeaderFollowerStrategy(
            leaderDeviceID: "L")
        let leaderFrames = [
            makeFrame(
                ref: "x", device: "L", counters: ["L": 1]),
            makeFrame(
                ref: "y", device: "L", counters: ["L": 2]),
        ]
        let result = await s.sync(
            local: leaderFrames, remote: [])
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(
            result.contains { $0.auditEntryRef == "x" })
        XCTAssertTrue(
            result.contains { $0.auditEntryRef == "y" })
    }

    // MARK: - Novel non-leader frames

    func test_followerFrameWithNovelRefPreserved() async {
        let s = BASSovereignLeaderFollowerStrategy(
            leaderDeviceID: "L")
        let leader = [
            makeFrame(
                ref: "x", device: "L", counters: ["L": 1]),
        ]
        let follower = [
            makeFrame(
                ref: "y", device: "F", counters: ["F": 1]),
        ]
        let result = await s.sync(
            local: leader, remote: follower)
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(
            result.contains { $0.auditEntryRef == "y" })
    }

    // MARK: - Conflict: leader wins

    func test_followerFrameWithConflictingRef_discarded()
        async
    {
        let s = BASSovereignLeaderFollowerStrategy(
            leaderDeviceID: "L")
        let leaderFrame = makeFrame(
            ref: "x", device: "L", counters: ["L": 1])
        // Follower also has a frame for "x" — but follower's
        // clock is more advanced. Per doctrine, leader's frame
        // still wins.
        let followerFrame = makeFrame(
            ref: "x", device: "F",
            counters: ["L": 1, "F": 5])
        let result = await s.sync(
            local: [leaderFrame], remote: [followerFrame])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], leaderFrame)
        XCTAssertEqual(result[0].originDeviceID, "L")
    }

    // MARK: - Pure follower input (no leader frames)

    func test_noLeaderFrames_allFollowersPass() async {
        let s = BASSovereignLeaderFollowerStrategy(
            leaderDeviceID: "L")
        let follower = [
            makeFrame(
                ref: "a", device: "A", counters: ["A": 1]),
            makeFrame(
                ref: "b", device: "B", counters: ["B": 1]),
        ]
        let result = await s.sync(
            local: [], remote: follower)
        // No leader frames → leaderRefs is empty → all
        // followers pass through.
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Both empty

    func test_emptyEmpty_returnsEmpty() async {
        let s = BASSovereignLeaderFollowerStrategy(
            leaderDeviceID: "L")
        let result = await s.sync(local: [], remote: [])
        XCTAssertEqual(result, [])
    }

    // MARK: - Deterministic ordering

    func test_orderingFollowsMergerSemantics() async {
        let s = BASSovereignLeaderFollowerStrategy(
            leaderDeviceID: "L")
        let l1 = makeFrame(
            ref: "first", device: "L", counters: ["L": 1])
        let l2 = makeFrame(
            ref: "second", device: "L", counters: ["L": 2])
        // Pass in shuffled.
        let result = await s.sync(
            local: [l2, l1], remote: [])
        // Causal: L's clock 1 < clock 2 → first before second.
        XCTAssertEqual(
            result.firstIndex(of: l1)!,
            result.startIndex)
        XCTAssertEqual(
            result.firstIndex(of: l2)!,
            result.endIndex.advanced(by: -1))
    }

    // MARK: - Existential dispatch

    func test_strategyUsableThroughExistential() async {
        let strategy: any BASSovereignFragmentSyncStrategy =
            BASSovereignLeaderFollowerStrategy(
                leaderDeviceID: "L")
        let result = await strategy.sync(
            local: [], remote: [])
        XCTAssertEqual(result, [])
        XCTAssertEqual(strategy.kind, .leaderFollower)
    }

    // MARK: - Mixed scenario

    func test_mixedScenario_leaderWinsOnConflict_followerNovelPasses()
        async
    {
        let s = BASSovereignLeaderFollowerStrategy(
            leaderDeviceID: "L")
        // Leader has refs x, y.
        let lx = makeFrame(
            ref: "x", device: "L", counters: ["L": 1])
        let ly = makeFrame(
            ref: "y", device: "L", counters: ["L": 2])
        // Follower has conflicting x (discard) + novel z (keep).
        let fx = makeFrame(
            ref: "x", device: "F",
            counters: ["L": 1, "F": 1])
        let fz = makeFrame(
            ref: "z", device: "F",
            counters: ["L": 2, "F": 2])
        let result = await s.sync(
            local: [lx, ly], remote: [fx, fz])
        XCTAssertEqual(result.count, 3)
        let refs = Set(result.map(\.auditEntryRef))
        XCTAssertEqual(refs, ["x", "y", "z"])
        // x must come from leader, not follower.
        let xFrame = result.first {
            $0.auditEntryRef == "x"
        }!
        XCTAssertEqual(xFrame.originDeviceID, "L")
    }
}
