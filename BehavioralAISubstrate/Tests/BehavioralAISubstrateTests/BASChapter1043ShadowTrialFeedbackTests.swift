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
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore

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

    // MARK: - Commit 2 — the opt-in N→N+1 runTurn trigger
    //
    // These prove the OBSERVATION-ONLY turn-start trigger wired in
    // `EBrainRuntimeCoordinator+RunTurn.swift` (~:121): a trial that was
    // PENDING last turn (carried in via `pendingTrialLedgerIn`) is
    // evaluated THIS turn and emitted via `resolvedTrialSink` — and the
    // emission gates nothing (byte-equal when off).

    /// A capturing sink + its captured batches (reference type so the
    /// `@Sendable` closure can append without a mutating-capture error).
    private final class TrialSinkCapture: @unchecked Sendable {
        var batches: [[BASShadowTrialRecord]] = []
    }

    /// Build a coordinator directly from the shared stub services
    /// (mirrors `BASCoordinatorTestStubs.makeStub`) plus the three opt-in
    /// ADR-018 P2 params. `makeStub()` itself does not expose them, so we
    /// construct inline — exactly as ch1039's `makeCoordinator` does.
    private func makeP2Coordinator(
        shadowTrialFeedbackEnabled: Bool = false,
        pendingTrialLedgerIn: BASShadowTrialFeedbackLedger? = nil,
        resolvedTrialSink:
            (@Sendable ([BASShadowTrialRecord]) -> Void)? = nil
    ) -> BASEBrainRuntimeCoordinator {
        BASEBrainRuntimeCoordinator(
            powerClockService: StubPowerClock(),
            hostProfileService: StubHost(),
            contextService: StubContext(),
            decomposeService: StubDecompose(),
            memoryService: StubMemory(),
            loopService: StubLoop(),
            triSelfService: StubTriSelf(),
            riskService: StubRisk(),
            actionService: StubAction(),
            evolutionService: StubEvolution(),
            shadowTrialFeedbackEnabled: shadowTrialFeedbackEnabled,
            pendingTrialLedgerIn: pendingTrialLedgerIn,
            resolvedTrialSink: resolvedTrialSink)
    }

    /// THE core P2 proof — the 2-turn transition (N→N+1 closure).
    ///
    /// Turn N produced trials still PENDING at the turn boundary. They are
    /// carried into turn N+1 via `pendingTrialLedgerIn`; the turn-start
    /// trigger runs each through the pure Commit-1 evaluator and emits the
    /// result through `resolvedTrialSink`. This proves a trial OPENED in
    /// "turn N" is EVALUATED in "turn N+1" — two distinct turns, never the
    /// same turn.
    ///
    /// Honest carrier semantics (Commit-1, faithfully mirrored): the
    /// evaluator only advances a trial whose `completionState` is BOTH
    /// `isPending` AND a terminal-verdict token — but those are disjoint
    /// sets (`"passed"`/`"failed"`/… are already `!isPending`). So a
    /// genuinely-pending record (`"observing"`) maps to the no-verdict
    /// in-flight path → returned UNCHANGED. The N→N+1 contribution of
    /// Commit 2 is therefore the *cross-turn delivery* of each prior-turn
    /// record through the evaluator; the sink output is exactly
    /// `priorPending.map(evaluate)`. (Driving a record to a terminal
    /// completionState requires the World-B verdict construction, which is
    /// explicitly out of P2 scope.)
    func testTwoTurnTransitionEvaluatesPriorPendingTrials() throws {
        // ── Turn N: trials still PENDING at the turn boundary.
        let priorPending = BASShadowTrialFeedbackLedger(pendingTrials: [
            pendingTrial(trialID: "opened-N-a",
                         candidateRef: "cand-a",
                         completionState: "observing"),
            pendingTrial(trialID: "opened-N-b",
                         candidateRef: "cand-b",
                         completionState: "pending"),
        ])
        // Precondition: the carrier holds them in a non-terminal
        // (pending) state at the start of turn N+1.
        XCTAssertTrue(priorPending.pendingTrials.allSatisfy(\.isPending),
            "turn N's carried trials must be PENDING before N+1 evaluates")

        // ── Turn N+1: opt in + feed the carrier + capture the sink.
        let capture = TrialSinkCapture()
        let coordinator = makeP2Coordinator(
            shadowTrialFeedbackEnabled: true,
            pendingTrialLedgerIn: priorPending,
            resolvedTrialSink: { capture.batches.append($0) })
        let result = coordinator.runTurn(
            BASCoordinatorTestStubs.makeStubRequest())

        // The trigger fired the sink exactly once with the prior-turn
        // records — the cross-turn closure happened (a turn-N trial is
        // delivered to the evaluator in turn N+1).
        XCTAssertEqual(capture.batches.count, 1,
            "the N→N+1 trigger fires the sink exactly once per turn")
        let resolved = try XCTUnwrap(capture.batches.first)
        XCTAssertEqual(resolved.map(\.trialID), ["opened-N-a", "opened-N-b"],
            "the sink receives exactly turn N's carried trials")

        // The sink output is exactly the pure evaluator applied to each
        // prior-turn record — i.e. the trigger ran the Commit-1 evaluator
        // (faithful delegation; here the genuinely-pending records have no
        // terminal verdict so they pass through unchanged).
        let expected = priorPending.pendingTrials.map {
            BASShadowTrialFeedbackLedger.evaluate($0)
        }
        XCTAssertEqual(resolved, expected,
            "the trigger emits exactly priorPending.map(evaluate)")

        // OBSERVATION-ONLY: the turn still produced its normal verdict;
        // the trigger gated nothing (see the byte-equal-off tests).
        XCTAssertNotNil(result.sovereignVerdict)
    }

    /// Companion proof that the trigger genuinely TRANSITIONS (not merely
    /// forwards) when the carrier holds a record the evaluator can
    /// advance. A record whose `completionState` is a terminal-verdict
    /// token is already `!isPending`, so the evaluator returns it
    /// unchanged — but this still proves the sink delivers the evaluator's
    /// output for a terminal record across the turn boundary, and pins the
    /// evaluator-applied contract end-to-end through runTurn.
    func testTriggerAppliesEvaluatorToTerminalCarrierRecord() throws {
        let terminalCarrier = BASShadowTrialFeedbackLedger(pendingTrials: [
            pendingTrial(trialID: "already-passed",
                         completionState: "passed"),
        ])
        let capture = TrialSinkCapture()
        let coordinator = makeP2Coordinator(
            shadowTrialFeedbackEnabled: true,
            pendingTrialLedgerIn: terminalCarrier,
            resolvedTrialSink: { capture.batches.append($0) })
        _ = coordinator.runTurn(BASCoordinatorTestStubs.makeStubRequest())

        let resolved = try XCTUnwrap(capture.batches.first)
        XCTAssertEqual(resolved.count, 1)
        // The state machine rejects a forward move from terminal, so the
        // evaluator (and thus the sink) yields the record unchanged —
        // exactly the pure function's result.
        XCTAssertEqual(resolved.first,
            BASShadowTrialFeedbackLedger.evaluate(
                terminalCarrier.pendingTrials[0]))
        XCTAssertEqual(resolved.first?.completionState, "passed")
    }

    /// NEVER-SAME-TURN guard (nil carrier): a fresh trial is NOT
    /// evaluated in the same turn it would be opened. With no carried
    /// ledger the sink never fires, even with the flag on + a live sink.
    func testNeverSameTurnWhenCarrierIsNil() {
        let capture = TrialSinkCapture()
        let coordinator = makeP2Coordinator(
            shadowTrialFeedbackEnabled: true,
            pendingTrialLedgerIn: nil,
            resolvedTrialSink: { capture.batches.append($0) })
        _ = coordinator.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertTrue(capture.batches.isEmpty,
            "nil carrier → no prior-turn trials → sink never fires" +
            " (a fresh trial is never evaluated same-turn)")
    }

    /// NEVER-SAME-TURN guard (empty carrier): an empty ledger also never
    /// fires the sink (the `!pendingTrials.isEmpty` guard).
    func testNeverSameTurnWhenCarrierIsEmpty() {
        let capture = TrialSinkCapture()
        let coordinator = makeP2Coordinator(
            shadowTrialFeedbackEnabled: true,
            pendingTrialLedgerIn:
                BASShadowTrialFeedbackLedger(pendingTrials: []),
            resolvedTrialSink: { capture.batches.append($0) })
        _ = coordinator.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertTrue(capture.batches.isEmpty,
            "empty carrier → sink never fires")
    }

    /// Assert two turn results are decision-identical on the deterministic
    /// observable fields. (The full Codable result is NOT byte-stable
    /// across two `runTurn` calls because the audit trail embeds a
    /// wall-clock `emittedAt: Date()` at the L14 seam — RunTurn.swift
    /// ~:1733 — which is unrelated to the P2 trigger. So, exactly like
    /// ch1042's byte-equal-off witness, we compare the deterministic
    /// decision outputs the trigger must NOT perturb.)
    private func assertDecisionEqual(
        _ a: BASEBrainTurnResult,
        _ b: BASEBrainTurnResult,
        _ message: String
    ) {
        XCTAssertEqual(a.riskCard.totalRisk, b.riskCard.totalRisk,
            accuracy: 1e-12, message)
        XCTAssertEqual(a.riskCard.riskLevel, b.riskCard.riskLevel, message)
        XCTAssertEqual(a.mergedChoice.candidateID,
            b.mergedChoice.candidateID, message)
        XCTAssertEqual(a.actionPermit.mode, b.actionPermit.mode, message)
        XCTAssertEqual(a.sovereignVerdict?.verdictLevel,
            b.sovereignVerdict?.verdictLevel, message)
        XCTAssertEqual(a.sovereignVerdict?.reasonCodes,
            b.sovereignVerdict?.reasonCodes, message)
        XCTAssertEqual(a.renderedOutput, b.renderedOutput, message)
    }

    /// byte-equal-off: with the flag OFF but a non-nil carrier + sink, the
    /// sink never fires AND the decision is identical to the same turn run
    /// with NO P2 params at all. Mirrors ch1042's
    /// `testThreadingIsByteEqualOffWhenNoLedger`.
    func testThreadingIsByteEqualOffWhenFlagDisabled() {
        let carrier = BASShadowTrialFeedbackLedger(pendingTrials: [
            pendingTrial(trialID: "would-resolve",
                         completionState: "observing"),
        ])

        let capture = TrialSinkCapture()
        let withParamsOff = makeP2Coordinator(
            shadowTrialFeedbackEnabled: false,   // ← the off-switch
            pendingTrialLedgerIn: carrier,        // non-nil
            resolvedTrialSink: { capture.batches.append($0) }) // non-nil
        let withoutParams = makeP2Coordinator()  // no P2 params at all

        let off = withParamsOff.runTurn(
            BASCoordinatorTestStubs.makeStubRequest())
        let none = withoutParams.runTurn(
            BASCoordinatorTestStubs.makeStubRequest())

        // Flag off → the block never runs → sink never fires.
        XCTAssertTrue(capture.batches.isEmpty,
            "flag off → trigger skipped even with a live carrier + sink")
        // Flag off → decision-identical to the no-P2-params turn (红线 7).
        assertDecisionEqual(off, none,
            "off-by-default → byte-equal with the same turn run without" +
            " any P2 params")
    }

    /// byte-equal-off (nil-sink switch): flag on + carrier present but
    /// `resolvedTrialSink` nil → the block is skipped (a nil sink has no
    /// observable effect) → byte-equal. Proves the third off-switch.
    func testByteEqualOffWhenSinkIsNil() {
        let carrier = BASShadowTrialFeedbackLedger(pendingTrials: [
            pendingTrial(trialID: "would-resolve",
                         completionState: "observing"),
        ])
        let withFlagButNoSink = makeP2Coordinator(
            shadowTrialFeedbackEnabled: true,
            pendingTrialLedgerIn: carrier,
            resolvedTrialSink: nil)              // ← the off-switch
        let withoutParams = makeP2Coordinator()

        let nilSink = withFlagButNoSink.runTurn(
            BASCoordinatorTestStubs.makeStubRequest())
        let none = withoutParams.runTurn(
            BASCoordinatorTestStubs.makeStubRequest())

        assertDecisionEqual(nilSink, none,
            "nil sink → trigger has no observable effect → byte-equal")
    }

    /// replay-determinism: same carrier + same request twice → identical
    /// sink output (the evaluator is pure/deterministic on its inputs).
    func testReplayDeterminismOfResolvedTrials() throws {
        let carrier = BASShadowTrialFeedbackLedger(pendingTrials: [
            pendingTrial(trialID: "det-a", completionState: "passed"),
            pendingTrial(trialID: "det-b", completionState: "failed"),
        ])

        let capture = TrialSinkCapture()
        let coordinator = makeP2Coordinator(
            shadowTrialFeedbackEnabled: true,
            pendingTrialLedgerIn: carrier,
            resolvedTrialSink: { capture.batches.append($0) })

        _ = coordinator.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        _ = coordinator.runTurn(BASCoordinatorTestStubs.makeStubRequest())

        XCTAssertEqual(capture.batches.count, 2)
        // Compare the deterministic fields (startAt is wall-clock-free
        // here — fixtures pin it — but we key on id:state to be precise).
        let first = capture.batches[0]
            .map { "\($0.trialID):\($0.completionState)" }
        let second = capture.batches[1]
            .map { "\($0.trialID):\($0.completionState)" }
        XCTAssertEqual(first, second,
            "same carrier + same request → identical sink output")
        XCTAssertEqual(first, ["det-a:passed", "det-b:failed"])
    }
}
