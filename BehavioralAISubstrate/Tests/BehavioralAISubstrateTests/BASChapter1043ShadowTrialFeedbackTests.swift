// MARK: - BASChapter1043ShadowTrialFeedbackTests
// chapter 一千零四十三 / ADR-018 P2 (Commit 1)
//
// Proves the DORMANT shadow-trial feedback carrier behaves as a pure,
// append-only value type with deterministic Codable round-trips, and
// that its pure evaluator faithfully delegates phase transitions to
// `BASShadowTrialStateMachineCore` (record-in → record-out).
//
// Chapter 1043 (1042 is taken by the evidence carrier). DORMANT:
// nothing in production reads the carrier yet.

import XCTest
@testable import BASMemory

final class BASChapter1043ShadowTrialFeedbackTests: XCTestCase {

    // MARK: - Fixtures

    /// A pending trial fixture (`completionState: "pending"`). A pending
    /// record is the one the evaluator can advance when it carries a
    /// terminal verdict.
    private func pendingTrial(
        trialID: String = "t1",
        candidateRef: String = "cand-1",
        completionState: String = "pending"
    ) -> BASShadowTrialRecord {
        BASShadowTrialRecord(
            trialID: trialID,
            candidateRef: candidateRef,
            trialScope: "draft_only",
            completionState: completionState)
    }

    // MARK: - Codable round-trip

    func testFeedbackLedgerCodableRoundTrip() throws {
        let ledger = BASShadowTrialFeedbackLedger(pendingTrials: [
            BASShadowTrialRecord(
                trialID: "t1", candidateRef: "c1",
                trialScope: "draft_only", completionState: "pending"),
            BASShadowTrialRecord(
                trialID: "t2", candidateRef: "c2",
                trialScope: "compare_only", completionState: "observing"),
        ])
        let data = try JSONEncoder().encode(ledger)
        let decoded = try JSONDecoder().decode(
            BASShadowTrialFeedbackLedger.self, from: data)
        XCTAssertEqual(decoded, ledger)
    }

    // MARK: - Immutable append (红线 4)

    func testFeedbackLedgerAppendingReturnsNewCopy() {
        let original = BASShadowTrialFeedbackLedger(pendingTrials: [
            BASShadowTrialRecord(
                trialID: "t1", candidateRef: "c1",
                trialScope: "draft_only", completionState: "pending"),
        ])
        let appended = BASShadowTrialRecord(
            trialID: "t2", candidateRef: "c2",
            trialScope: "compare_only", completionState: "observing")
        let extended = original.appending(appended)

        // Original is unchanged (immutability 红线 4).
        XCTAssertEqual(original.pendingTrials.count, 1)
        // New value has the appended record.
        XCTAssertEqual(extended.pendingTrials.count, 2)
        XCTAssertEqual(extended.pendingTrials.last, appended)
    }

    // MARK: - Pure evaluator delegates to the state machine

    func testEvaluateTransitionsPendingTrial() {
        // A pending trial whose completionState carries a terminal
        // "passed" verdict → evaluate advances it to a "passed"
        // terminal record (the machine seals it).
        let trial = pendingTrial(completionState: "passed")
        let evaluated = BASShadowTrialFeedbackLedger.evaluate(trial)

        // Cross-check: the evaluator must yield exactly what the state
        // machine says for an in-flight trial with a "passed" verdict
        // (.advanceTo(.sealed)), mapped back to "passed".
        let stateMachine = BASShadowTrialStateMachineCore()
        let expected = stateMachine.transition(.init(
            currentPhase: .trialInFlight, verdictRaw: "passed"))
        XCTAssertEqual(expected, .advanceTo(.sealed))

        // The evaluated record reached a terminal "passed" state...
        XCTAssertEqual(evaluated.completionState, "passed")
        XCTAssertTrue(evaluated.isPassed)
        // ...and preserves identity/metadata (record-in → record-out).
        XCTAssertEqual(evaluated.trialID, trial.trialID)
        XCTAssertEqual(evaluated.candidateRef, trial.candidateRef)
        XCTAssertEqual(evaluated.trialScope, trial.trialScope)
    }

    func testEvaluateTransitionsFailingTrialToFailed() {
        // A pending trial carrying a "failed" verdict → the machine
        // retracts it → evaluate records "failed".
        let trial = pendingTrial(completionState: "failed")
        let stateMachine = BASShadowTrialStateMachineCore()
        let expected = stateMachine.transition(.init(
            currentPhase: .trialInFlight, verdictRaw: "failed"))
        XCTAssertEqual(expected, .advanceTo(.retracted))

        let evaluated = BASShadowTrialFeedbackLedger.evaluate(trial)
        XCTAssertEqual(evaluated.completionState, "failed")
        XCTAssertTrue(evaluated.isFailed)
    }

    func testEvaluateLeavesNonTerminalPendingUnchanged() {
        // A genuinely-pending trial (no terminal verdict) → modeled as
        // in-flight with no verdict → the machine keeps it in flight
        // (.advanceTo(.trialInFlight)), which has no terminal
        // completionState to record → the record is returned UNCHANGED,
        // faithfully mirroring the machine's no-verdict in-flight path.
        let observing = pendingTrial(completionState: "observing")
        let stateMachine = BASShadowTrialStateMachineCore()
        let direct = stateMachine.transition(.init(
            currentPhase: .trialInFlight, verdictRaw: nil))
        XCTAssertEqual(direct, .advanceTo(.trialInFlight))

        let evaluated = BASShadowTrialFeedbackLedger.evaluate(observing)
        XCTAssertEqual(evaluated, observing)
    }

    func testEvaluateLeavesTerminalRecordUnchanged() {
        // An already-terminal record (isPassed) has no legal forward
        // move — the machine rejects sealed/retracted transitions — so
        // the evaluator returns it UNCHANGED.
        let sealed = pendingTrial(completionState: "completed")
        XCTAssertTrue(sealed.isPassed)
        let evaluated = BASShadowTrialFeedbackLedger.evaluate(sealed)
        XCTAssertEqual(evaluated, sealed)
    }

    // MARK: - Replay determinism (红线 4)

    func testEvaluateIsDeterministic() {
        let trial = pendingTrial(
            trialID: "det", candidateRef: "cand-det",
            completionState: "passed")
        let first = BASShadowTrialFeedbackLedger.evaluate(trial)
        let second = BASShadowTrialFeedbackLedger.evaluate(trial)
        XCTAssertEqual(first, second)
    }
}
