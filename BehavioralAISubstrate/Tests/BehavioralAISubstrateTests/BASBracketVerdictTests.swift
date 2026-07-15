import XCTest
@testable import BASOrgan

/// device-recon id13: Mac unit teeth for the drift-refusing bracket verdict —
/// the promote/decline rule the on-device probes previously hand-copied inline.
/// The adversarial cases pin that a within-drift swing is NOT a win and a real
/// past-drift gain IS, so a mis-copied expression can never silently promote.
final class BASBracketVerdictTests: XCTestCase {

    func testClearWinWhenChallengerFarBelowStableBracket() {
        // pre == post ⇒ zero drift; challenger clearly faster.
        let r = BASBracketVerdict.classify(preMs: 100, challengerMs: 50, postMs: 100)
        XCTAssertEqual(r.outcome, .win)
        XCTAssertEqual(r.bracketMs, 100)
        XCTAssertEqual(r.driftMs, 0)
        XCTAssertEqual(r.speedup, 2.0, accuracy: 1e-9)
    }

    func testInconclusiveWhenApparentGainIsWithinDrift() {
        // bracket=120, drift=40; challenger 90 beats bracket by 30 < 40 drift ⇒ noise.
        let r = BASBracketVerdict.classify(preMs: 100, challengerMs: 90, postMs: 140)
        XCTAssertEqual(r.outcome, .inconclusiveWithinDrift,
            "a gain smaller than the pre/post drift is not a real win")
    }

    func testWinWhenGainClearsTheDriftBand() {
        // Same drift=40 bracket=120; challenger 70 beats bracket by 50 > 40 ⇒ win.
        let r = BASBracketVerdict.classify(preMs: 100, challengerMs: 70, postMs: 140)
        XCTAssertEqual(r.outcome, .win)
    }

    func testInconclusiveWhenChallengerSlower() {
        let r = BASBracketVerdict.classify(preMs: 100, challengerMs: 150, postMs: 100)
        XCTAssertEqual(r.outcome, .inconclusiveWithinDrift)
        XCTAssertLessThan(r.speedup, 1.0)
    }

    func testFailedChallengerRunIsNeverAWin() {
        // challenger <= 0 (run failed / no timing) must not classify as a win,
        // and speedup is 0 (not a divide-by-zero inf).
        let r = BASBracketVerdict.classify(preMs: 100, challengerMs: 0, postMs: 100)
        XCTAssertEqual(r.outcome, .inconclusiveWithinDrift)
        XCTAssertEqual(r.speedup, 0)
    }

    func testExactlyAtDriftBoundaryIsNotAWin() {
        // challenger == bracket - drift exactly ⇒ strict `<` ⇒ not a win.
        let r = BASBracketVerdict.classify(preMs: 100, challengerMs: 80, postMs: 140)
        XCTAssertEqual(r.outcome, .inconclusiveWithinDrift,
            "the boundary is exclusive — must clear the drift band strictly")
    }
}
