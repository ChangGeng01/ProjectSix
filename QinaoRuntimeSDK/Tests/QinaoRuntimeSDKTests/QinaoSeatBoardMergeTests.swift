import XCTest
@testable import QinaoSeats

/// M292.4 — cross-seat verdict merger contract tests.
///
/// Doctrine pinned:
/// - Empty board → consensus 0, loudest nil, empty dissent/silent
/// - Single seat → consensus = urgency, loudest = that seat
/// - Mean includes zeros (silent seats lower consensus)
/// - Loudest tie-break is seat raw-value ASC
/// - Dissent threshold is exactly 0.3 (|x - mean| > 0.3)
/// - Silent uses strict equality (== 0), not approx zero
/// - `MergedSeatBoard.board` preserves original verbatim
final class QinaoSeatBoardMergeTests: XCTestCase {

    private func v(
        _ seat: QinaoSeat,
        _ urgency: Double
    ) -> SeatVerdict {
        SeatVerdict(seat: seat, urgency: urgency)
    }

    // MARK: - Empty / single

    func test_empty_zeroEverywhere() {
        let board = SeatBoard(verdicts: [])
        let m = board.merge()
        XCTAssertEqual(m.consensusUrgency, 0, accuracy: 1e-9)
        XCTAssertNil(m.loudestSeat)
        XCTAssertEqual(m.dissent, [])
        XCTAssertEqual(m.silentSeats, [])
    }

    func test_single_consensusEqualsUrgency() {
        let board = SeatBoard(verdicts: [v(.scout, 0.7)])
        let m = board.merge()
        XCTAssertEqual(m.consensusUrgency, 0.7, accuracy: 1e-9)
        XCTAssertEqual(m.loudestSeat, .scout)
        XCTAssertEqual(m.dissent, [])
        XCTAssertEqual(m.silentSeats, [])
    }

    // MARK: - Mean / loudest

    func test_meanIncludesZeros() {
        let board = SeatBoard(verdicts: [
            v(.scout, 0.6),
            v(.risk, 0),
            v(.critic, 0.6),
        ])
        let m = board.merge()
        XCTAssertEqual(m.consensusUrgency, 0.4, accuracy: 1e-9)
    }

    func test_loudestTieBreaksOnSeatRawAsc() {
        let board = SeatBoard(verdicts: [
            v(.scout, 0.5),
            v(.risk, 0.5),
        ])
        let m = board.merge()
        // critic < risk < scout in raw asc; here only risk + scout
        // tie. ASC: risk first.
        XCTAssertEqual(m.loudestSeat, .risk)
    }

    func test_loudestPicksHighestEvenWhenSorted() {
        let board = SeatBoard(verdicts: [
            v(.critic, 0.4),
            v(.risk, 0.9),
            v(.scout, 0.2),
        ])
        let m = board.merge()
        XCTAssertEqual(m.loudestSeat, .risk)
    }

    // MARK: - Dissent

    func test_dissentNamesSeatsBeyondThreshold() {
        // mean = 0.5; dissent threshold |x - 0.5| > 0.3 → > 0.8 or < 0.2.
        let board = SeatBoard(verdicts: [
            v(.scout, 0.5),
            v(.risk, 0.9),  // |0.9-0.5| = 0.4 > 0.3 → dissent
            v(.critic, 0.1), // |0.1-0.5| = 0.4 > 0.3 → dissent
            v(.surface, 0.5),
        ])
        let m = board.merge()
        XCTAssertEqual(m.consensusUrgency, 0.5, accuracy: 1e-9)
        XCTAssertEqual(m.dissent, [.critic, .risk]) // ASC raw
    }

    func test_dissentEmptyWhenAllAgree() {
        let board = SeatBoard(verdicts: [
            v(.scout, 0.6),
            v(.risk, 0.7),
            v(.critic, 0.6),
        ])
        let m = board.merge()
        XCTAssertEqual(m.dissent, [])
    }

    func test_dissentExclusiveAtNearBoundary() {
        // mean = 0.5. Verdicts 0.79 and 0.21 are 0.29 away (< 0.3).
        // Per doctrine `> 0.3` (strict), they're NOT dissent.
        // (0.8 / 0.2 themselves trip FP rounding past 0.3 — avoided
        // here so the boundary test is FP-stable.)
        let board = SeatBoard(verdicts: [
            v(.scout, 0.5),
            v(.risk, 0.79),
            v(.critic, 0.21),
        ])
        let m = board.merge()
        XCTAssertEqual(m.consensusUrgency, 0.5, accuracy: 1e-9)
        XCTAssertEqual(m.dissent, [])
    }

    // MARK: - Silent

    func test_silentUsesStrictZero() {
        let board = SeatBoard(verdicts: [
            v(.scout, 0),
            v(.risk, 0.001),  // quiet, not silent
            v(.critic, 0),
        ])
        let m = board.merge()
        XCTAssertEqual(m.silentSeats, [.critic, .scout]) // ASC
    }

    func test_silentEmptyWhenNothingSilent() {
        let board = SeatBoard(verdicts: [
            v(.scout, 0.4),
            v(.risk, 0.5),
        ])
        let m = board.merge()
        XCTAssertEqual(m.silentSeats, [])
    }

    // MARK: - Board preservation

    func test_boardPreservedVerbatim() {
        let original = SeatBoard(
            verdicts: [v(.scout, 0.7)],
            failures: [.risk: "no-data"])
        let m = original.merge()
        XCTAssertEqual(m.board, original)
    }
}
