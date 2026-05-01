import XCTest
@testable import QinaoSeats

/// 六十五.3 — residency manager tests.
final class QinaoSeatResidencyManagerTests: XCTestCase {

    /// Mock seat impl for any seat kind.
    private struct MockSeat: QinaoSeatProtocol {
        let seat: QinaoSeat
        func contribute(
            snapshotID: String
        ) async throws -> SeatVerdict {
            SeatVerdict(seat: seat, urgency: 0)
        }
    }

    private static let mockFactory:
        @Sendable (QinaoSeat) -> (
            any QinaoSeatProtocol
        )? = { seat in
        MockSeat(seat: seat)
    }

    func test_initRegistersAllHotSeats() async {
        let mgr =
            await QinaoSeatResidencyManager(
                factory: Self.mockFactory)
        let active = await mgr.activeSeats()
        // Hot seats: scout + risk + surface +
        // sovereignSentinel
        XCTAssertEqual(
            active,
            [
                .scout, .risk, .surface,
                .sovereignSentinel,
            ])
    }

    func test_wakeupColdSeat() async {
        let mgr =
            await QinaoSeatResidencyManager(
                factory: Self.mockFactory)
        let woken = await mgr.wakeup(seat: .planner)
        XCTAssertTrue(woken)
        let active = await mgr.activeSeats()
        XCTAssertTrue(active.contains(.planner))
    }

    func test_wakeupHotSeatIsNoOp() async {
        let mgr =
            await QinaoSeatResidencyManager(
                factory: Self.mockFactory)
        let woken = await mgr.wakeup(seat: .scout)
        XCTAssertFalse(
            woken,
            "hot seat is already on; wakeup is no-op")
        let active = await mgr.activeSeats()
        XCTAssertTrue(active.contains(.scout))
    }

    func test_wakeupIdempotent() async {
        let mgr =
            await QinaoSeatResidencyManager(
                factory: Self.mockFactory)
        let first = await mgr.wakeup(seat: .planner)
        let second = await mgr.wakeup(seat: .planner)
        XCTAssertTrue(first)
        XCTAssertFalse(
            second,
            "second wakeup is a no-op (idempotent)")
    }

    func test_sleepColdSeat() async {
        let mgr =
            await QinaoSeatResidencyManager(
                factory: Self.mockFactory)
        await mgr.wakeup(seat: .planner)
        let slept = await mgr.sleep(seat: .planner)
        XCTAssertTrue(slept)
        let active = await mgr.activeSeats()
        XCTAssertFalse(active.contains(.planner))
    }

    func test_sleepHotSeatRefused() async {
        let mgr =
            await QinaoSeatResidencyManager(
                factory: Self.mockFactory)
        let slept = await mgr.sleep(seat: .scout)
        XCTAssertFalse(
            slept,
            "hot core stays on by doctrine; sleep refused")
        let active = await mgr.activeSeats()
        XCTAssertTrue(
            active.contains(.scout),
            "hot seat must remain active")
    }

    func test_sleepUnawakedColdNoOp() async {
        let mgr =
            await QinaoSeatResidencyManager(
                factory: Self.mockFactory)
        // Planner hasn't been woken; sleep is no-op.
        let slept = await mgr.sleep(seat: .planner)
        XCTAssertFalse(slept)
    }

    func test_awakenedColdSeatsView() async {
        let mgr =
            await QinaoSeatResidencyManager(
                factory: Self.mockFactory)
        await mgr.wakeup(seat: .planner)
        await mgr.wakeup(seat: .critic)
        let cold = await mgr.awakenedColdSeatsView()
        XCTAssertEqual(cold, [.planner, .critic])
    }

    func test_underlyingRegistryDispatchable() async throws {
        let mgr =
            await QinaoSeatResidencyManager(
                factory: Self.mockFactory)
        await mgr.wakeup(seat: .planner)
        let registry =
            await mgr.underlyingRegistry()
        let seats = await registry.registeredSeats()
        // Hot 4 + planner = 5 seats.
        XCTAssertEqual(seats.count, 5)
    }
}
