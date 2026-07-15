import XCTest
@testable import BASOrgan

/// Pins the greedy block-K accept simulation — the measurement core of the Gate-2 draft-α experiment.
final class BASAcceptanceBlockReducerTests: XCTestCase {

    // All positions agree, n=8, K=4: round1 accepts 4 (full block) then bonus → pos 5; round2 accepts 3 (hits the
    // sequence end) then bonus → done. rounds=2, accepted=7, a=3.5.
    func testAllAgreeFullBlocks() {
        let r = BASAcceptanceBlockReducer.reduce(agreement: Array(repeating: true, count: 8), k: 4)
        XCTAssertEqual(r.rounds, 2)
        XCTAssertEqual(r.accepted, 7)
        XCTAssertEqual(r.meanAcceptedPerRound, 3.5, accuracy: 1e-9)
        XCTAssertEqual(r.tokensPerRound, 4.5, accuracy: 1e-9)   // net ≈ 4.5× at f→0
    }

    // The free-form wall: nothing agrees → every round accepts 0 draft tokens, advancing only by the correction.
    // rounds=n, accepted=0, a=0 → net ≈ 1× (no speedup). This is the DON'T_BUILD signal.
    func testNoneAgreeIsTheWall() {
        let r = BASAcceptanceBlockReducer.reduce(agreement: Array(repeating: false, count: 4), k: 4)
        XCTAssertEqual(r.rounds, 4)
        XCTAssertEqual(r.accepted, 0)
        XCTAssertEqual(r.meanAcceptedPerRound, 0, accuracy: 1e-9)
        XCTAssertEqual(r.tokensPerRound, 1.0, accuracy: 1e-9)   // net ≈ 1×
    }

    // Alternating agree/disagree, K=4: each round accepts exactly 1 then the disagreement is the correction.
    // [T,F,T,F] → rounds=2, accepted=2, a=1.0.
    func testAlternating() {
        let r = BASAcceptanceBlockReducer.reduce(agreement: [true, false, true, false], k: 4)
        XCTAssertEqual(r.rounds, 2)
        XCTAssertEqual(r.accepted, 2)
        XCTAssertEqual(r.meanAcceptedPerRound, 1.0, accuracy: 1e-9)
    }

    // K=1 (single-token spec): max 1 accepted per round; all-agree → a=1.0, tokensPerRound=2.0 (the classic 2× ceiling).
    func testK1AllAgreeIsTwoX() {
        let r = BASAcceptanceBlockReducer.reduce(agreement: Array(repeating: true, count: 4), k: 1)
        XCTAssertEqual(r.rounds, 2)
        XCTAssertEqual(r.accepted, 2)
        XCTAssertEqual(r.tokensPerRound, 2.0, accuracy: 1e-9)
    }

    // A trailing PARTIAL block (generation stopped by EOS mid-block) is still a real round.
    // n=3 all agree, K=4 → 1 round, 3 accepted.
    func testTrailingPartialBlockCounts() {
        let r = BASAcceptanceBlockReducer.reduce(agreement: [true, true, true], k: 4)
        XCTAssertEqual(r.rounds, 1)
        XCTAssertEqual(r.accepted, 3)
        XCTAssertEqual(r.meanAcceptedPerRound, 3.0, accuracy: 1e-9)
    }

    // Empty sequence → no rounds, a defined as 0 (no divide-by-zero).
    func testEmptyIsZero() {
        let r = BASAcceptanceBlockReducer.reduce(agreement: [], k: 4)
        XCTAssertEqual(r.rounds, 0)
        XCTAssertEqual(r.accepted, 0)
        XCTAssertEqual(r.meanAcceptedPerRound, 0, accuracy: 1e-9)
    }
}
