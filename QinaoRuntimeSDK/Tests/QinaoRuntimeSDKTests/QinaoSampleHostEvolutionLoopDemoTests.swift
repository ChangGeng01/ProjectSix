import XCTest
@testable import BASMemory

/// M333 — pin substrate contracts that
/// `QinaoSampleHost --evolution-loop-demo` relies on. Same
/// pattern as M313/M314/M322/M328/M329: demo lives in executable
/// target, tests pin BASMemory primitives the demo composes.
///
/// What this file pins:
///
///   1. `BASEvolutionLifecycleStage` enum has exactly 8 cases
///      (chapter 五十六 typed-pinned cardinality).
///   2. `BASEvolutionLifecycleAction` enum has exactly 7 cases.
///   3. Terminal stages return empty validTransitions.
///   4. `.promoted` is NOT terminal — `.retract` is the ONLY
///      legal exit.
///   5. `.withdraw` is blocked from `.promoted`.
///   6. `hasReachedPromotion` returns true for `.promoted` AND
///      `.retracted` (retraction implies promotion was achieved).
///   7. Full happy path traversable via `applying(...)` chain.
///   8. M305 aggregate correctly summarizes a collection.
final class QinaoSampleHostEvolutionLoopDemoTests: XCTestCase {

    // MARK: - 1. Stage cardinality

    func testStageEnumHasEightStableCases() {
        let stages = BASEvolutionLifecycleStage.allCases
        XCTAssertEqual(stages.count, 8)
        let rawValues = Set(stages.map(\.rawValue))
        let expected: Set<String> = [
            "proposed", "candidateRegistered",
            "shadowTrialing", "trialFinalized",
            "promoted", "retracted", "rejected",
            "withdrawn",
        ]
        XCTAssertEqual(rawValues, expected)
    }

    // MARK: - 2. Action cardinality

    func testActionEnumHasSevenStableCases() {
        let actions = BASEvolutionLifecycleAction.allCases
        XCTAssertEqual(actions.count, 7)
        let rawValues = Set(actions.map(\.rawValue))
        let expected: Set<String> = [
            "registerCandidate", "startShadowTrial",
            "finalizeTrial", "promote", "retract",
            "fail", "withdraw",
        ]
        XCTAssertEqual(rawValues, expected)
    }

    // MARK: - 3. Terminal stages

    func testTerminalStagesHaveEmptyValidTransitions() {
        for stage: BASEvolutionLifecycleStage in [
            .retracted, .rejected, .withdrawn,
        ] {
            let transitions = BASEvolutionLifecyclePolicy
                .validTransitions(from: stage)
            XCTAssertTrue(
                transitions.isEmpty,
                "terminal stage \(stage) must have empty " +
                "validTransitions, got \(transitions)")
        }
    }

    // MARK: - 4. Promoted non-terminal + only retract exits

    func testPromotedIsNotTerminalAndOnlyRetractExits() {
        XCTAssertFalse(
            BASEvolutionLifecycleStage.promoted.isTerminal)
        let transitions = BASEvolutionLifecyclePolicy
            .validTransitions(from: .promoted)
        XCTAssertEqual(
            Set(transitions.keys), [.retract])
        XCTAssertEqual(
            transitions[.retract], .retracted)
    }

    // MARK: - 5. Withdraw blocked from promoted

    func testWithdrawIsBlockedFromPromoted() {
        let promoted = BASEvolutionLifecycleSession(
            candidateID: "test-promoted",
            currentStage: .promoted,
            history: [])
        let result = promoted.applying(.withdraw)
        XCTAssertNil(
            result,
            "withdraw must be blocked from .promoted; got " +
            "\(String(describing: result))")
    }

    // MARK: - 6. hasReachedPromotion across stages

    func testHasReachedPromotionAcrossStages() {
        XCTAssertTrue(
            BASEvolutionLifecycleStage.promoted
                .hasReachedPromotion)
        XCTAssertTrue(
            BASEvolutionLifecycleStage.retracted
                .hasReachedPromotion)
        // None of the pre-promotion stages should be true.
        for stage: BASEvolutionLifecycleStage in [
            .proposed, .candidateRegistered,
            .shadowTrialing, .trialFinalized,
            .rejected, .withdrawn,
        ] {
            XCTAssertFalse(
                stage.hasReachedPromotion,
                "\(stage) must NOT have hasReachedPromotion " +
                "= true")
        }
    }

    // MARK: - 7. Happy path traversal

    func testFullHappyPathTraversable() {
        var session = BASEvolutionLifecycleSession(
            candidateID: "test-happy")
        session = session.applying(.registerCandidate)!
        XCTAssertEqual(
            session.currentStage, .candidateRegistered)
        session = session.applying(.startShadowTrial)!
        XCTAssertEqual(
            session.currentStage, .shadowTrialing)
        session = session.applying(.finalizeTrial)!
        XCTAssertEqual(
            session.currentStage, .trialFinalized)
        session = session.applying(.promote)!
        XCTAssertEqual(session.currentStage, .promoted)
        XCTAssertTrue(session.hasReachedPromotion)
        XCTAssertFalse(session.isTerminal)
        // Retract.
        session = session.applying(.retract)!
        XCTAssertEqual(session.currentStage, .retracted)
        XCTAssertTrue(session.hasReachedPromotion)
        XCTAssertTrue(session.isTerminal)
        // History records all 5 transitions.
        XCTAssertEqual(session.history.count, 5)
    }

    // MARK: - 8. M305 aggregate over 3 sessions

    func testAggregateOverThreeMixedSessions() {
        // Session A: promoted + retracted.
        var a = BASEvolutionLifecycleSession(
            candidateID: "a")
        a = a.applying(.registerCandidate)!
            .applying(.startShadowTrial)!
            .applying(.finalizeTrial)!
            .applying(.promote)!
            .applying(.retract)!
        // Session B: rejected.
        var b = BASEvolutionLifecycleSession(
            candidateID: "b")
        b = b.applying(.registerCandidate)!
            .applying(.startShadowTrial)!
            .applying(.fail)!
        // Session C: withdrawn.
        var c = BASEvolutionLifecycleSession(
            candidateID: "c")
        c = c.applying(.withdraw)!

        let agg = BASEvolutionLifecycleSession.aggregate(
            [a, b, c])
        XCTAssertNotNil(agg)
        XCTAssertEqual(agg?.count, 3)
        // All 3 are terminal.
        XCTAssertEqual(agg?.terminalCount, 3)
        // Only A reached promotion.
        XCTAssertEqual(agg?.promotedCount, 1)
        // Active stages (deduplicated current-stage values
        // in declaration order) — A=.retracted, B=.rejected,
        // C=.withdrawn.
        XCTAssertEqual(
            agg?.activeStages,
            [.retracted, .rejected, .withdrawn])
    }

    // MARK: - 9. Empty aggregate returns nil

    func testEmptyAggregateReturnsNil() {
        XCTAssertNil(
            BASEvolutionLifecycleSession.aggregate([]))
    }
}
