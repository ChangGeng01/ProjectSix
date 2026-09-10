import XCTest
@testable import QinaoSeats

/// M292.2 — seat protocol + registry + parallel dispatch contract
/// tests.
///
/// Doctrine pinned by these tests:
/// - Empty registry → empty board, fully-attended (vacuously)
/// - Single seat → 1 verdict on the board
/// - 9 seats registered → 9 verdicts in seat raw-value ASC order
/// - Last-write-wins on duplicate seat registration
/// - One seat throwing records a per-seat failure, others succeed
/// - `verdict(for:)` round-trips
/// - `clear()` removes all seats
final class QinaoSeatRegistryTests: XCTestCase {

    // MARK: - Stub seats

    struct StubSeat: QinaoSeatProtocol {
        let seat: QinaoSeat
        let urgency: Double
        let reasonCodes: [String]
        func contribute(
            snapshotID: String
        ) async throws -> SeatVerdict {
            SeatVerdict(
                seat: seat,
                urgency: urgency,
                reasonCodes: reasonCodes,
                note: "snapshot:\(snapshotID)")
        }
    }

    struct ThrowingSeat: QinaoSeatProtocol {
        let seat: QinaoSeat
        struct StubError: Error, Equatable {
            let detail: String
        }
        func contribute(
            snapshotID: String
        ) async throws -> SeatVerdict {
            throw StubError(detail: "no-data:\(snapshotID)")
        }
    }

    // MARK: - Empty registry

    func test_emptyRegistry_returnsEmptyAttendedBoard() async {
        let r = QinaoSeatRegistry()
        let board = await r.dispatch(snapshotID: "s1")
        XCTAssertEqual(board.verdicts, [])
        XCTAssertTrue(board.isFullyAttended)
    }

    // MARK: - Registration

    func test_registerOneSeat_dispatchProducesOneVerdict()
        async
    {
        let r = QinaoSeatRegistry()
        await r.register(
            StubSeat(seat: .scout, urgency: 0.5, reasonCodes: []))
        let board = await r.dispatch(snapshotID: "s1")
        XCTAssertEqual(board.verdicts.count, 1)
        XCTAssertEqual(board.verdicts[0].seat, .scout)
        XCTAssertTrue(board.isFullyAttended)
    }

    func test_registerAllNineSeats_boardCarriesAllVerdicts()
        async
    {
        let r = QinaoSeatRegistry()
        for s in QinaoSeat.allCases {
            await r.register(
                StubSeat(seat: s, urgency: 0.4, reasonCodes: []))
        }
        let board = await r.dispatch(snapshotID: "s1")
        XCTAssertEqual(board.verdicts.count, 9)
        XCTAssertTrue(board.isFullyAttended)
    }

    func test_verdictOrderIsSeatNameAsc() async {
        let r = QinaoSeatRegistry()
        // Register in shuffled order to prove dispatch sorts.
        for s in QinaoSeat.allCases.shuffled() {
            await r.register(
                StubSeat(seat: s, urgency: 0.3, reasonCodes: []))
        }
        let board = await r.dispatch(snapshotID: "s1")
        let raws = board.verdicts.map(\.seat.rawValue)
        XCTAssertEqual(raws, raws.sorted())
    }

    // MARK: - Last-write-wins

    func test_duplicateSeatRegistration_lastWriteWins() async {
        let r = QinaoSeatRegistry()
        await r.register(StubSeat(
            seat: .scout, urgency: 0.2, reasonCodes: ["first"]))
        await r.register(StubSeat(
            seat: .scout, urgency: 0.9, reasonCodes: ["second"]))
        let board = await r.dispatch(snapshotID: "s1")
        XCTAssertEqual(board.verdicts.count, 1)
        XCTAssertEqual(
            board.verdicts[0].urgency, 0.9, accuracy: 1e-9)
        XCTAssertEqual(
            board.verdicts[0].reasonCodes, ["second"])
    }

    // MARK: - Failures

    func test_oneSeatThrows_othersSucceed_failureRecorded()
        async
    {
        let r = QinaoSeatRegistry()
        await r.register(
            StubSeat(seat: .scout, urgency: 0.4, reasonCodes: []))
        await r.register(ThrowingSeat(seat: .risk))
        await r.register(
            StubSeat(seat: .surface, urgency: 0.6, reasonCodes: []))

        let board = await r.dispatch(snapshotID: "s1")
        XCTAssertEqual(board.verdicts.count, 2)
        XCTAssertFalse(board.isFullyAttended)
        XCTAssertNotNil(board.failures[.risk])
        XCTAssertNil(board.failures[.scout])
        XCTAssertNil(board.failures[.surface])
    }

    // MARK: - Lookup

    func test_verdictForSeat_lookupRoundTrips() async throws {
        let r = QinaoSeatRegistry()
        await r.register(StubSeat(
            seat: .planner,
            urgency: 0.7,
            reasonCodes: ["plan-divergence"]))
        let board = await r.dispatch(snapshotID: "s1")
        let v = try XCTUnwrap(board.verdict(for: .planner))
        XCTAssertEqual(v.urgency, 0.7, accuracy: 1e-9)
        XCTAssertEqual(v.reasonCodes, ["plan-divergence"])
    }

    func test_verdictForSeat_returnsNilWhenAbsent() async {
        let r = QinaoSeatRegistry()
        let board = await r.dispatch(snapshotID: "s1")
        XCTAssertNil(board.verdict(for: .planner))
    }

    // MARK: - Clear

    func test_clearRemovesAllSeats() async {
        let r = QinaoSeatRegistry()
        await r.register(
            StubSeat(seat: .scout, urgency: 0.4, reasonCodes: []))
        await r.register(
            StubSeat(seat: .risk, urgency: 0.6, reasonCodes: []))
        let beforeClear = await r.registeredSeats().count
        XCTAssertEqual(beforeClear, 2)
        await r.clear()
        let afterClear = await r.registeredSeats().count
        XCTAssertEqual(afterClear, 0)
        let board = await r.dispatch(snapshotID: "s1")
        XCTAssertEqual(board.verdicts, [])
    }

    // MARK: - Registered seats listing

    func test_registeredSeatsReturnsAscOrder() async {
        let r = QinaoSeatRegistry()
        await r.register(
            StubSeat(seat: .surface, urgency: 0, reasonCodes: []))
        await r.register(
            StubSeat(seat: .critic, urgency: 0, reasonCodes: []))
        await r.register(
            StubSeat(seat: .memory, urgency: 0, reasonCodes: []))
        let registered = await r.registeredSeats()
        XCTAssertEqual(
            registered, [.critic, .memory, .surface])
    }

    // MARK: - Snapshot ID forwarded

    func test_snapshotIDForwardedToContribute() async {
        let r = QinaoSeatRegistry()
        await r.register(
            StubSeat(seat: .scout, urgency: 0, reasonCodes: []))
        let board = await r.dispatch(snapshotID: "weave-123")
        XCTAssertEqual(
            board.verdicts[0].note, "snapshot:weave-123")
    }
}
