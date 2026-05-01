import XCTest
@testable import QinaoSeats

/// M309 — pin that `QinaoAgentConcurrencyPhase` is load-bearing
/// at runtime via `seatsByPhase()` + `dispatchByPhase(snapshotID:)`
/// on `QinaoSeatRegistry`.
///
/// Pre-M309 the 3-phase partition (perception / cognition /
/// landing) was typed-pinned in `QinaoAgentFabricDoctrine` but
/// had **0 runtime callers** — `dispatch(snapshotID:)` ran every
/// registered seat fully in parallel without phase ordering,
/// making the doctrine pure typed reference. M309 ships an
/// additive runtime path that respects the phase partition.
///
/// What this file pins:
///
///   1. `seatsByPhase()` returns all 3 phases unconditionally
///      — empty phases map to empty arrays, never missing
///      keys (audit consumers can grep by phase
///      unconditionally).
///   2. The partition matches the doctrine — every registered
///      seat lands in exactly one phase, derivable from
///      `QinaoSeat.concurrencyPhase`.
///   3. `dispatchByPhase(snapshotID:)` runs phases in the
///      canonical order (perception → cognition → landing) and
///      returns SeatBoards for all 3 phases.
///   4. Empty registry produces 3 empty SeatBoards, not nil
///      entries.
///   5. Failures in one phase don't abort other phases (per-
///      phase isolation, mirroring `dispatch`'s per-seat
///      isolation).
///   6. Legacy `dispatch(snapshotID:)` keeps its flat-parallel
///      semantics — M309 is purely additive.
final class QinaoSeatPhaseDispatchTests: XCTestCase {

    // MARK: - Test seats

    /// Stub seat returning a deterministic verdict so tests can
    /// pin per-phase output without real loop signals.
    private struct StubSeat: QinaoSeatProtocol {
        let seat: QinaoSeat
        let urgency: Double
        func contribute(
            snapshotID: String
        ) async throws -> SeatVerdict {
            SeatVerdict(
                seat: seat,
                urgency: urgency,
                reasonCodes: ["stub"],
                note: "stub-\(seat.rawValue)")
        }
    }

    /// Stub seat that throws — used to test phase-level failure
    /// isolation.
    private struct ThrowingSeat: QinaoSeatProtocol {
        let seat: QinaoSeat
        struct StubError: Error {}
        func contribute(
            snapshotID _: String
        ) async throws -> SeatVerdict {
            throw StubError()
        }
    }

    // MARK: - 1. seatsByPhase always returns all 3 phases

    func testSeatsByPhaseAlwaysReturnsAllThreePhases() async {
        let registry = QinaoSeatRegistry()
        let partition = await registry.seatsByPhase()
        XCTAssertEqual(partition.count, 3)
        XCTAssertNotNil(partition[.perception])
        XCTAssertNotNil(partition[.cognition])
        XCTAssertNotNil(partition[.landing])
        XCTAssertEqual(partition[.perception], [])
        XCTAssertEqual(partition[.cognition], [])
        XCTAssertEqual(partition[.landing], [])
    }

    // MARK: - 2. Partition matches QinaoSeat.concurrencyPhase

    func testPartitionMatchesSeatConcurrencyPhaseExtension()
        async
    {
        let registry = QinaoSeatRegistry()
        // Register one seat from every phase.
        await registry.register(
            StubSeat(seat: .scout, urgency: 0.3))
        await registry.register(
            StubSeat(seat: .planner, urgency: 0.5))
        await registry.register(
            StubSeat(seat: .surface, urgency: 0.4))

        let partition = await registry.seatsByPhase()

        XCTAssertEqual(partition[.perception], [.scout])
        XCTAssertEqual(partition[.cognition], [.planner])
        XCTAssertEqual(partition[.landing], [.surface])

        // Cross-check via QinaoSeat.concurrencyPhase: every
        // partition entry agrees with the seat-level extension.
        for (phase, seats) in partition {
            for seat in seats {
                XCTAssertEqual(
                    seat.concurrencyPhase, phase,
                    "partition entry must match " +
                    "QinaoSeat.concurrencyPhase")
            }
        }
    }

    // MARK: - 3. dispatchByPhase runs all 3 phases in order

    func testDispatchByPhaseRunsAllThreePhases() async {
        let registry = QinaoSeatRegistry()
        await registry.register(
            StubSeat(seat: .scout, urgency: 0.3))
        await registry.register(
            StubSeat(seat: .memory, urgency: 0.4))
        await registry.register(
            StubSeat(seat: .planner, urgency: 0.5))
        await registry.register(
            StubSeat(seat: .critic, urgency: 0.6))
        await registry.register(
            StubSeat(seat: .surface, urgency: 0.7))

        let boards = await registry.dispatchByPhase(
            snapshotID: "session-m305")

        XCTAssertEqual(boards.count, 3)
        let perception = try? XCTUnwrap(boards[.perception])
        let cognition = try? XCTUnwrap(boards[.cognition])
        let landing = try? XCTUnwrap(boards[.landing])
        XCTAssertEqual(
            perception?.verdicts.map(\.seat).sorted {
                $0.rawValue < $1.rawValue
            },
            [.memory, .scout])
        XCTAssertEqual(
            cognition?.verdicts.map(\.seat).sorted {
                $0.rawValue < $1.rawValue
            },
            [.critic, .planner])
        XCTAssertEqual(
            landing?.verdicts.map(\.seat),
            [.surface])
    }

    // MARK: - 4. Empty registry produces 3 empty SeatBoards

    func testEmptyRegistryProducesThreeEmptyBoards() async {
        let registry = QinaoSeatRegistry()
        let boards = await registry.dispatchByPhase(
            snapshotID: "session-m305-empty")
        XCTAssertEqual(boards.count, 3)
        for phase in QinaoAgentConcurrencyPhase.allCases {
            let board = boards[phase]
            XCTAssertNotNil(
                board,
                "phase \(phase) must have an entry, even " +
                "when empty")
            XCTAssertTrue(board?.verdicts.isEmpty ?? false)
            XCTAssertTrue(board?.failures.isEmpty ?? false)
        }
    }

    // MARK: - 5. Phase-level failure isolation

    func testPhaseFailuresDoNotAbortOtherPhases() async {
        let registry = QinaoSeatRegistry()
        // Cognition phase has a throwing seat.
        await registry.register(
            StubSeat(seat: .scout, urgency: 0.3))
        await registry.register(
            ThrowingSeat(seat: .planner))
        await registry.register(
            StubSeat(seat: .critic, urgency: 0.5))
        await registry.register(
            StubSeat(seat: .surface, urgency: 0.7))

        let boards = await registry.dispatchByPhase(
            snapshotID: "session-m305-throw")

        // Perception unaffected.
        XCTAssertEqual(
            boards[.perception]?.verdicts.map(\.seat),
            [.scout])
        XCTAssertTrue(
            boards[.perception]?.failures.isEmpty ?? false)
        // Cognition: planner failed, critic still produces.
        XCTAssertEqual(
            boards[.cognition]?.verdicts.map(\.seat),
            [.critic])
        XCTAssertNotNil(boards[.cognition]?.failures[.planner])
        // Landing unaffected.
        XCTAssertEqual(
            boards[.landing]?.verdicts.map(\.seat),
            [.surface])
        XCTAssertTrue(
            boards[.landing]?.failures.isEmpty ?? false)
    }

    // MARK: - 6. Legacy dispatch keeps flat-parallel semantics

    func testLegacyDispatchUnaffectedByM309() async {
        let registry = QinaoSeatRegistry()
        await registry.register(
            StubSeat(seat: .scout, urgency: 0.3))
        await registry.register(
            StubSeat(seat: .planner, urgency: 0.5))
        await registry.register(
            StubSeat(seat: .surface, urgency: 0.7))

        let board = await registry.dispatch(
            snapshotID: "session-m305-legacy")
        // All 3 seats present in one flat board, raw-value ASC.
        XCTAssertEqual(
            board.verdicts.map(\.seat),
            [.planner, .scout, .surface])
        XCTAssertTrue(board.failures.isEmpty)
    }

    // MARK: - 7. dispatchByPhase ordering — perception runs
    //           BEFORE cognition before landing
    //
    /// Pin via timestamps: each stub records a monotonically
    /// increasing tick; perception ticks must all be < cognition
    /// ticks < landing ticks (within a phase order is non-
    /// deterministic, but across phases is strict).

    actor PhaseTicker {
        var tick = 0
        func next() -> Int { tick += 1; return tick }
    }

    private struct TickerSeat: QinaoSeatProtocol {
        let seat: QinaoSeat
        let ticker: PhaseTicker
        let recorder: PhaseRecorder
        func contribute(
            snapshotID _: String
        ) async throws -> SeatVerdict {
            let t = await ticker.next()
            await recorder.record(seat: seat, tick: t)
            return SeatVerdict(
                seat: seat, urgency: 0.5,
                reasonCodes: [], note: "tick:\(t)")
        }
    }

    actor PhaseRecorder {
        var ticks: [QinaoSeat: Int] = [:]
        func record(seat: QinaoSeat, tick: Int) {
            ticks[seat] = tick
        }
    }

    func testPhaseOrderingIsStrictAcrossPhases() async {
        let ticker = PhaseTicker()
        let recorder = PhaseRecorder()
        let registry = QinaoSeatRegistry()
        // Two seats per phase.
        await registry.register(
            TickerSeat(
                seat: .scout, ticker: ticker,
                recorder: recorder))
        await registry.register(
            TickerSeat(
                seat: .memory, ticker: ticker,
                recorder: recorder))
        await registry.register(
            TickerSeat(
                seat: .planner, ticker: ticker,
                recorder: recorder))
        await registry.register(
            TickerSeat(
                seat: .critic, ticker: ticker,
                recorder: recorder))
        await registry.register(
            TickerSeat(
                seat: .surface, ticker: ticker,
                recorder: recorder))
        await registry.register(
            TickerSeat(
                seat: .sovereignSentinel,
                ticker: ticker, recorder: recorder))

        _ = await registry.dispatchByPhase(
            snapshotID: "session-m305-order")
        let ticks = await recorder.ticks
        let perceptionTicks = [
            ticks[.scout]!, ticks[.memory]!,
        ]
        let cognitionTicks = [
            ticks[.planner]!, ticks[.critic]!,
        ]
        let landingTicks = [
            ticks[.surface]!, ticks[.sovereignSentinel]!,
        ]
        let perceptionMax = perceptionTicks.max()!
        let cognitionMin = cognitionTicks.min()!
        let cognitionMax = cognitionTicks.max()!
        let landingMin = landingTicks.min()!
        XCTAssertLessThan(
            perceptionMax, cognitionMin,
            "perception must complete before cognition starts")
        XCTAssertLessThan(
            cognitionMax, landingMin,
            "cognition must complete before landing starts")
    }
}
