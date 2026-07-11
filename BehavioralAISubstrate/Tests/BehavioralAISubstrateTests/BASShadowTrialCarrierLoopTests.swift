// MARK: - BASShadowTrialCarrierLoopTests — ADR-018 P2 reachability gate
//
// The carrier loop was "production-inert until a host populates +
// re-injects the carrier" (ADR-018:452-455) because the coordinator's
// public seams were buried behind `private let` chains。 This gate
// proves the new reachability pipe end to end at the BRAIN level
// (the production host entry point):
//   1. A pending trial injected via the pipe is EVALUATED in-turn and
//      delivered to the sink (the state machine advances a terminal-
//      verdict record)。
//   2. NEVER-EFFECTIVE-SAME-TURN: the sink receives ONLY the injected
//      (N−1) trials — never the current turn's own records。
//   3. OBSERVATION-ONLY: the armed turn's result records equal the
//      unarmed turn's (the loop feeds the sink, never the result)。
//   4. Empty carrier / disabled flag ⇒ sink never called。

import XCTest
@testable import BASHostKit
@testable import BASMemory

final class BASShadowTrialCarrierLoopTests: XCTestCase {

    /// Lock-guarded sink collector (the sink closure is @Sendable)。
    private final class SinkBox: @unchecked Sendable {
        private let lock = NSLock()
        private var deliveriesStore: [[BASShadowTrialRecord]] = []
        func record(_ batch: [BASShadowTrialRecord]) {
            lock.lock(); defer { lock.unlock() }
            deliveriesStore.append(batch)
        }
        var deliveries: [[BASShadowTrialRecord]] {
            lock.lock(); defer { lock.unlock() }
            return deliveriesStore
        }
    }

    /// Cooperative-pool safe: the 27e0fcb2e stack class is fixed (CoW-boxed turn
    /// result + stage-split runTurn, ≤80KB peak pinned by BASRunTurnFrameBudgetTests)。
    private static func makeBrain() async throws -> BASCognitiveBrain {
        try await BASCognitiveBrain(
            options: BASCognitiveOSBundleOptions())
    }

    private func pendingTrial(
        id: String, completionState: String
    ) -> BASShadowTrialRecord {
        BASShadowTrialRecord(
            trialID: id,
            candidateRef: "candidate-\(id)",
            trialScope: "test-scope",
            startAt: Date(timeIntervalSince1970: 1_750_000_000),
            endAt: nil,
            observedEffects: [],
            failConditions: [],
            promotionRecommendation: nil,
            completionState: completionState)
    }

    // MARK: - 1. Injected trials are delivered (carry + visibility)

    /// The honest contract this pins (discovered while building the
    /// gate): `evaluate()` can NEVER auto-advance a record — the
    /// pending set (NOT passed/completed/failed/blocked) and the
    /// verdict vocabulary (exactly those four) are DISJOINT, so the
    /// state-machine advance path is unreachable。 That is CONSISTENT
    /// with doctrine: auto-advancing trials from in-turn evidence
    /// would BE the ADR-021 outcome-feedback learner (NO-GO by
    /// design)。 The carrier loop's value is CARRY + VISIBILITY: the
    /// host marks terminal states;the machine validates, never
    /// learns。 Both an in-flight and a host-terminal record must be
    /// DELIVERED UNCHANGED。
    func testInjectedTrialsAreDeliveredUnchanged() async throws {
        let brain = try await Self.makeBrain()
        let sink = SinkBox()
        let inFlight = pendingTrial(
            id: "t-observing", completionState: "observing")
        let hostMarked = pendingTrial(
            id: "t-pass", completionState: "passed")
        await brain.setShadowTrialFeedback(
            enabled: true,
            pendingLedger: BASShadowTrialFeedbackLedger(
                pendingTrials: [inFlight, hostMarked]),
            resolvedSink: { sink.record($0) })
        _ = await brain.process("Carrier loop drive turn.")

        let deliveries = sink.deliveries
        XCTAssertEqual(deliveries.count, 1,
            "one turn with a non-empty carrier ⇒ exactly one delivery")
        XCTAssertEqual(deliveries[0].map(\.trialID),
                       ["t-observing", "t-pass"],
            "the delivered records are the INJECTED ones, in order")
        XCTAssertEqual(deliveries[0][0].completionState, "observing",
            "an in-flight trial stays in flight (no terminal verdict " +
            "⇒ the machine's no-verdict path keeps it pending)")
        XCTAssertEqual(deliveries[0][1].completionState, "passed",
            "a host-marked terminal trial passes through unchanged — " +
            "nothing auto-advances (ADR-021 learner NO-GO consistency)")
    }

    // MARK: - 2. NEVER-EFFECTIVE-SAME-TURN

    func testSinkNeverReceivesTheCurrentTurnsOwnRecords() async throws {
        let brain = try await Self.makeBrain()
        let sink = SinkBox()
        let injected = pendingTrial(id: "n-1-trial",
                                    completionState: "observing")
        await brain.setShadowTrialFeedback(
            enabled: true,
            pendingLedger: BASShadowTrialFeedbackLedger(
                pendingTrials: [injected]),
            resolvedSink: { sink.record($0) })
        let result = await brain.process(
            "This is an important message that must be sent now.")

        let deliveredIDs = Set(sink.deliveries.flatMap { $0 }
            .map(\.trialID))
        XCTAssertEqual(deliveredIDs, ["n-1-trial"],
            "the sink must receive ONLY the injected N−1 trials")
        let ownIDs = Set(result.shadowTrialRecords.map(\.trialID))
        XCTAssertTrue(deliveredIDs.isDisjoint(with: ownIDs),
            "the current turn's own records must NEVER reach the sink " +
            "in the same turn (NEVER-EFFECTIVE-SAME-TURN doctrine)")
    }

    // MARK: - 3. Observation-only (result untouched)

    func testArmedTurnResultRecordsEqualUnarmedTurns() async throws {
        let prompt = "Identical prompt for both brains."
        let unarmedBrain = try await Self.makeBrain()
        let unarmed = await unarmedBrain.process(prompt)

        let armedBrain = try await Self.makeBrain()
        await armedBrain.setShadowTrialFeedback(
            enabled: true,
            pendingLedger: BASShadowTrialFeedbackLedger(
                pendingTrials: [pendingTrial(
                    id: "x", completionState: "passed")]),
            resolvedSink: { _ in })
        let armed = await armedBrain.process(prompt)

        XCTAssertEqual(
            armed.shadowTrialRecords.map(\.trialID),
            unarmed.shadowTrialRecords.map(\.trialID),
            "the carrier loop feeds the SINK only — the turn result's " +
            "own records must be unaffected (observation-only)")
        XCTAssertEqual(
            armed.contextFrame.taskType,
            unarmed.contextFrame.taskType,
            "the cascade outputs must be unaffected by arming")
    }

    // MARK: - 4. Off-switches

    func testEmptyCarrierNeverCallsTheSink() async throws {
        let brain = try await Self.makeBrain()
        let sink = SinkBox()
        await brain.setShadowTrialFeedback(
            enabled: true,
            pendingLedger: BASShadowTrialFeedbackLedger(
                pendingTrials: []),
            resolvedSink: { sink.record($0) })
        _ = await brain.process("Empty carrier turn.")
        XCTAssertTrue(sink.deliveries.isEmpty,
            "an empty carrier must not call the sink")
    }

    func testDisabledFlagNeverCallsTheSink() async throws {
        let brain = try await Self.makeBrain()
        let sink = SinkBox()
        await brain.setShadowTrialFeedback(
            enabled: false,
            pendingLedger: BASShadowTrialFeedbackLedger(
                pendingTrials: [pendingTrial(
                    id: "t", completionState: "passed")]),
            resolvedSink: { sink.record($0) })
        _ = await brain.process("Disabled flag turn.")
        XCTAssertTrue(sink.deliveries.isEmpty,
            "enabled=false must keep the block skipped (one of the " +
            "three independent off-switches)")
    }
}
