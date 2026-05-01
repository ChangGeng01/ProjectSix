import XCTest
@testable import BASSovereign

/// M296.3.zz factory — sync strategy factory contract tests.
///
/// Doctrine pinned:
/// - Each kind maps to its canonical strategy
/// - .leaderFollower without leaderDeviceID returns nil
/// - .leaderFollower with leaderDeviceID returns
///   LeaderFollowerStrategy
/// - makeAllStrategies with leaderDeviceID returns 4 strategies
/// - makeAllStrategies without leaderDeviceID returns 3 (skips
///   leaderFollower)
final class BASSovereignSyncStrategyFactoryTests: XCTestCase {

    // MARK: - Symmetric kinds

    func test_vectorClockMergeKind_returnsDefault() {
        let strategy = BASSovereignSyncStrategyFactory
            .makeStrategy(kind: .vectorClockMerge)
        XCTAssertNotNil(strategy)
        XCTAssertEqual(strategy?.kind, .vectorClockMerge)
    }

    func test_crdtKind_returnsLWW() {
        let strategy = BASSovereignSyncStrategyFactory
            .makeStrategy(kind: .crdt)
        XCTAssertNotNil(strategy)
        XCTAssertEqual(strategy?.kind, .crdt)
    }

    func test_gossipKind_returnsAntiEntropy() {
        let strategy = BASSovereignSyncStrategyFactory
            .makeStrategy(kind: .gossip)
        XCTAssertNotNil(strategy)
        XCTAssertEqual(strategy?.kind, .gossip)
    }

    // MARK: - Leader-follower

    func test_leaderFollowerKindWithoutID_returnsNil() {
        let strategy = BASSovereignSyncStrategyFactory
            .makeStrategy(
                kind: .leaderFollower,
                leaderDeviceID: nil)
        XCTAssertNil(strategy)
    }

    func test_leaderFollowerKindWithID_returnsStrategy() {
        let strategy = BASSovereignSyncStrategyFactory
            .makeStrategy(
                kind: .leaderFollower,
                leaderDeviceID: "L")
        XCTAssertNotNil(strategy)
        XCTAssertEqual(strategy?.kind, .leaderFollower)
    }

    // MARK: - makeAllStrategies

    func test_makeAllStrategies_withoutLeaderID_skipsLeaderFollower()
    {
        let strategies = BASSovereignSyncStrategyFactory
            .makeAllStrategies()
        XCTAssertEqual(strategies.count, 3)
        XCTAssertNotNil(strategies[.vectorClockMerge])
        XCTAssertNotNil(strategies[.crdt])
        XCTAssertNotNil(strategies[.gossip])
        XCTAssertNil(strategies[.leaderFollower])
    }

    func test_makeAllStrategies_withLeaderID_returnsFour() {
        let strategies = BASSovereignSyncStrategyFactory
            .makeAllStrategies(leaderDeviceID: "L")
        XCTAssertEqual(strategies.count, 4)
        for kind in BASSovereignSyncProtocolKind.allCases {
            XCTAssertNotNil(strategies[kind])
        }
    }

    // MARK: - End-to-end functional check via factory

    func test_factoryStrategiesAllProduceMergeOutput() async {
        let strategies = BASSovereignSyncStrategyFactory
            .makeAllStrategies(leaderDeviceID: "L")
        let frame = BASSovereignCrossDeviceLedgerFrame(
            auditEntryRef: "x",
            originDeviceID: "L",
            clock: BASSovereignCrossDeviceClock(
                deviceCounters: ["L": 1]))
        for (kind, strategy) in strategies {
            let result = await strategy.sync(
                local: [frame], remote: [])
            XCTAssertFalse(
                result.isEmpty,
                "strategy \(kind) must produce non-empty output for non-empty input")
        }
    }

    // MARK: - CRDT variant factory

    func test_crdtVariantHasTwoCases() {
        XCTAssertEqual(
            BASSovereignSyncStrategyFactory.CRDTVariant
                .allCases.count, 2)
    }

    func test_lwwVariantReturnsLWWStrategy() {
        let s = BASSovereignSyncStrategyFactory
            .makeCRDTVariant(.lwwElementSet)
        XCTAssertEqual(s.kind, .crdt)
        XCTAssertTrue(
            s is BASSovereignLWWElementSetStrategy)
    }

    func test_mvrVariantReturnsMVRStrategy() {
        let s = BASSovereignSyncStrategyFactory
            .makeCRDTVariant(.multiValueRegister)
        XCTAssertEqual(s.kind, .crdt)
        XCTAssertTrue(
            s is BASSovereignMultiValueRegisterStrategy)
    }

    func test_lwwAndMvrProduceDifferentOutputOnConcurrent()
        async
    {
        let lww = BASSovereignSyncStrategyFactory
            .makeCRDTVariant(.lwwElementSet)
        let mvr = BASSovereignSyncStrategyFactory
            .makeCRDTVariant(.multiValueRegister)
        let frameA = BASSovereignCrossDeviceLedgerFrame(
            auditEntryRef: "x",
            originDeviceID: "A",
            clock: BASSovereignCrossDeviceClock(
                deviceCounters: ["A": 5, "B": 1]))
        let frameB = BASSovereignCrossDeviceLedgerFrame(
            auditEntryRef: "x",
            originDeviceID: "B",
            clock: BASSovereignCrossDeviceClock(
                deviceCounters: ["A": 1, "B": 5]))
        let lwwOut = await lww.sync(
            local: [frameA], remote: [frameB])
        let mvrOut = await mvr.sync(
            local: [frameA], remote: [frameB])
        XCTAssertEqual(lwwOut.count, 1)
        XCTAssertEqual(mvrOut.count, 2)
    }

    func test_crdtVariantCodableRoundTrip() throws {
        for v in BASSovereignSyncStrategyFactory.CRDTVariant
            .allCases
        {
            let data = try JSONEncoder().encode(v)
            let decoded = try JSONDecoder().decode(
                BASSovereignSyncStrategyFactory.CRDTVariant
                    .self, from: data)
            XCTAssertEqual(decoded, v)
        }
    }
}
