import XCTest
import BASMemory
@testable import QinaoHost

/// M76 — QinaoFurnace tests.
///
/// The substrate `BASShadowTrialCoordinator` has its own exhaustive
/// suite (`BASShadowTrialCoordinatorTests`). This suite only proves
/// the façade behaviour:
///
/// 1. **Transitions delegate + translate errors.** The façade
///    preserves the coordinator's submit / observe / reportFail /
///    finalize state machine and translates every
///    `BASShadowTrialCoordinator.TrialError` case into the matching
///    `QinaoFurnace.FurnaceError` case (so host code never has to
///    catch a BAS error type).
/// 2. **Mirror types carry scalars verbatim.** `PromotionDecision`
///    and `TrialEvent` have different field names than their
///    substrate counterparts (redaction) but every scalar survives
///    the bridge.
/// 3. **Replay reads the owned ledger.** `allTrialEvents()` and
///    `replay(candidateID:)` read from the in-memory ledger and
///    return events in insertion order, filtered by the
///    action-refs contract.
/// 4. **Workbench orchestrates faithfully.** `runWorkbench` admits
///    → observes * N → reports-fail * M → finalizes in one call,
///    matching the same ledger sequence a hand-rolled driver would
///    produce.
/// 5. **Auto-promotion is the conjunction.** `promoted = (outcome
///    == .passed) && promotionDecision.allowsPromotion`. A
///    candidate with a prior failure passes the second trial but
///    still does not auto-promote.
final class QinaoFurnaceTests: XCTestCase {

    // MARK: - Fixtures

    private static let fixedNow = Date(timeIntervalSince1970: 1_730_500_000)

    private func makeClock() -> @Sendable () -> Date {
        let target = Self.fixedNow
        return { target }
    }

    private func makeCandidate(
        id: String = "candidate.bias-fix.v1",
        sourceRefs: [String] = ["src-1", "src-2"]
    ) -> BASExperienceCandidate {
        BASExperienceCandidate(
            candidateID: id,
            sourceRefs: sourceRefs,
            candidateType: .bias,
            summary: "summary for \(id)",
            stabilitySignal: 0.8,
            contaminationRisk: 0.1,
            hostScope: "host.domain.finance",
            sovereignScope: "sovereign.scope.growth")
    }

    private func makeFurnace(
        ledger: BASInMemoryShadowTrialLedger? = nil,
        trialIDs: [String] = [],
        sealIDs: [String] = [],
        retractionIDs: [String] = [],
        auditIDs: [String] = []
    ) -> (QinaoFurnace, BASInMemoryShadowTrialLedger) {
        let realLedger = ledger ?? BASInMemoryShadowTrialLedger()
        let trialPump = CounterPump(ids: trialIDs, prefix: "trial")
        let sealPump = CounterPump(ids: sealIDs, prefix: "seal")
        let retractionPump = CounterPump(ids: retractionIDs, prefix: "retract")
        let auditPump = CounterPump(ids: auditIDs, prefix: "audit")
        let furnace = QinaoFurnace(
            ledger: realLedger,
            clock: makeClock(),
            nextAuditID: { auditPump.next() },
            nextTrialID: { trialPump.next() },
            nextSealID: { sealPump.next() },
            nextRetractionID: { retractionPump.next() })
        return (furnace, realLedger)
    }

    // MARK: - Basic state-machine delegation

    func testSubmitOpensPendingTrial() async throws {
        let (furnace, _) = makeFurnace(trialIDs: ["t-1"])
        let record = try await furnace.submit(
            candidate: makeCandidate(),
            sessionID: "session-A",
            turnID: "turn-1",
            trialScope: "scope.growth")
        XCTAssertEqual(record.trialID, "t-1")
        XCTAssertEqual(record.completionState, "pending")
        XCTAssertTrue(record.isPending)
    }

    func testObserveAdvancesToObserving() async throws {
        let (furnace, _) = makeFurnace(trialIDs: ["t-1"])
        _ = try await furnace.submit(
            candidate: makeCandidate(),
            sessionID: "session-A",
            turnID: "turn-1",
            trialScope: "scope.growth")
        let observed = try await furnace.observe(
            trialID: "t-1",
            effect: "first-effect",
            sessionID: "session-A",
            turnID: "turn-2")
        XCTAssertEqual(observed.completionState, "observing")
        XCTAssertEqual(observed.observedEffects, ["first-effect"])
    }

    func testReportFailAppendsFailCondition() async throws {
        let (furnace, _) = makeFurnace(trialIDs: ["t-1"])
        _ = try await furnace.submit(
            candidate: makeCandidate(),
            sessionID: "session-A",
            turnID: "turn-1",
            trialScope: "scope.growth")
        let reported = try await furnace.reportFail(
            trialID: "t-1",
            reason: "host-rejected",
            sessionID: "session-A",
            turnID: "turn-2")
        XCTAssertEqual(reported.failConditions, ["host-rejected"])
        XCTAssertEqual(reported.completionState, "observing")
    }

    func testFinalizePassedIssuesSealAndNoRetraction() async throws {
        let (furnace, _) = makeFurnace(
            trialIDs: ["t-1"],
            sealIDs: ["s-1"])
        _ = try await furnace.submit(
            candidate: makeCandidate(),
            sessionID: "session-A",
            turnID: "turn-1",
            trialScope: "scope.growth")
        let finalized = try await furnace.finalize(
            trialID: "t-1",
            outcome: .passed,
            sessionID: "session-A",
            turnID: "turn-2")
        XCTAssertEqual(finalized.completionState, "passed")
        let seal = await furnace.seal(for: "candidate.bias-fix.v1")
        XCTAssertEqual(seal?.sealID, "s-1")
        XCTAssertEqual(seal?.approvalState, "sealed")
        let retraction = await furnace.retraction(for: "candidate.bias-fix.v1")
        XCTAssertNil(retraction)
    }

    func testFinalizeFailedDeniesSealAndQueuesRetraction() async throws {
        let (furnace, _) = makeFurnace(
            trialIDs: ["t-1"],
            sealIDs: ["s-1"],
            retractionIDs: ["r-1"])
        _ = try await furnace.submit(
            candidate: makeCandidate(),
            sessionID: "session-A",
            turnID: "turn-1",
            trialScope: "scope.growth")
        let finalized = try await furnace.finalize(
            trialID: "t-1",
            outcome: .failed,
            sessionID: "session-A",
            turnID: "turn-2")
        XCTAssertEqual(finalized.completionState, "failed")
        let seal = await furnace.seal(for: "candidate.bias-fix.v1")
        XCTAssertEqual(seal?.approvalState, "denied")
        let retraction = await furnace.retraction(for: "candidate.bias-fix.v1")
        XCTAssertEqual(retraction?.orderID, "r-1")
        XCTAssertEqual(retraction?.executionState, "queued")
        XCTAssertEqual(
            retraction?.cascadeRefs,
            ["src-1", "src-2"],
            "cascade refs should equal the candidate's source refs")
    }

    func testFinalizeBlockedQueuesRetraction() async throws {
        let (furnace, _) = makeFurnace(
            trialIDs: ["t-1"],
            sealIDs: ["s-1"],
            retractionIDs: ["r-1"])
        _ = try await furnace.submit(
            candidate: makeCandidate(),
            sessionID: "session-A",
            turnID: "turn-1",
            trialScope: "scope.growth")
        let finalized = try await furnace.finalize(
            trialID: "t-1",
            outcome: .blocked,
            sessionID: "session-A",
            turnID: "turn-2")
        XCTAssertEqual(finalized.completionState, "blocked")
        let retraction = await furnace.retraction(for: "candidate.bias-fix.v1")
        XCTAssertEqual(retraction?.executionState, "queued")
    }

    // MARK: - Error translation

    func testDuplicateActiveTrialSurfacesTypedError() async throws {
        let (furnace, _) = makeFurnace(trialIDs: ["t-1", "t-2"])
        _ = try await furnace.submit(
            candidate: makeCandidate(),
            sessionID: "session-A",
            turnID: "turn-1",
            trialScope: "scope.growth")
        do {
            _ = try await furnace.submit(
                candidate: makeCandidate(),
                sessionID: "session-A",
                turnID: "turn-2",
                trialScope: "scope.growth")
            XCTFail("expected candidateAlreadyHasActiveTrial")
        } catch QinaoFurnace.FurnaceError
            .candidateAlreadyHasActiveTrial(let candidateID, let trialID)
        {
            XCTAssertEqual(candidateID, "candidate.bias-fix.v1")
            XCTAssertEqual(trialID, "t-1")
        }
    }

    func testUnknownTrialObserveSurfacesTypedError() async throws {
        let (furnace, _) = makeFurnace()
        do {
            _ = try await furnace.observe(
                trialID: "nonexistent",
                effect: "e",
                sessionID: "session-A",
                turnID: "turn-1")
            XCTFail("expected unknownTrial")
        } catch QinaoFurnace.FurnaceError.unknownTrial(let id) {
            XCTAssertEqual(id, "nonexistent")
        }
    }

    func testFinalizeAlreadyFinalizedSurfacesTypedError() async throws {
        let (furnace, _) = makeFurnace(
            trialIDs: ["t-1"],
            sealIDs: ["s-1"])
        _ = try await furnace.submit(
            candidate: makeCandidate(),
            sessionID: "session-A",
            turnID: "turn-1",
            trialScope: "scope.growth")
        _ = try await furnace.finalize(
            trialID: "t-1",
            outcome: .passed,
            sessionID: "session-A",
            turnID: "turn-2")
        do {
            _ = try await furnace.finalize(
                trialID: "t-1",
                outcome: .failed,
                sessionID: "session-A",
                turnID: "turn-3")
            XCTFail("expected trialAlreadyFinalized")
        } catch QinaoFurnace.FurnaceError
            .trialAlreadyFinalized(let id, let state)
        {
            XCTAssertEqual(id, "t-1")
            XCTAssertEqual(state, "passed")
        }
    }

    func testInvalidInputSurfacesTypedError() async throws {
        let (furnace, _) = makeFurnace()
        do {
            _ = try await furnace.submit(
                candidate: makeCandidate(),
                sessionID: "",
                turnID: "turn-1",
                trialScope: "scope.growth")
            XCTFail("expected invalidInput")
        } catch QinaoFurnace.FurnaceError.invalidInput(let reason) {
            XCTAssertEqual(reason, "empty-sessionID")
        }
    }

    func testLedgerAppendFailureSurfacesTypedError() async throws {
        let failingLedger = BASInMemoryShadowTrialLedger { _ in "forced-failure" }
        let (furnace, _) = makeFurnace(
            ledger: failingLedger,
            trialIDs: ["t-1"])
        do {
            _ = try await furnace.submit(
                candidate: makeCandidate(),
                sessionID: "session-A",
                turnID: "turn-1",
                trialScope: "scope.growth")
            XCTFail("expected ledgerAppendFailed")
        } catch QinaoFurnace.FurnaceError.ledgerAppendFailed {
            // ok — reason string wraps the BAS LedgerError description
        }
    }

    // MARK: - Promotion decision mirror

    func testPromotionDecisionBlocksAfterFailedTrial() async throws {
        let (furnace, _) = makeFurnace(
            trialIDs: ["t-1"],
            sealIDs: ["s-1"],
            retractionIDs: ["r-1"])
        _ = try await furnace.submit(
            candidate: makeCandidate(),
            sessionID: "session-A",
            turnID: "turn-1",
            trialScope: "scope.growth")
        _ = try await furnace.finalize(
            trialID: "t-1",
            outcome: .failed,
            sessionID: "session-A",
            turnID: "turn-2")
        let decision = await furnace.promotionDecision(
            for: "candidate.bias-fix.v1")
        XCTAssertFalse(decision.allowsPromotion)
        XCTAssertTrue(decision.reasonCodes.contains("evolution.shadow_trial_failed"))
        XCTAssertTrue(decision.reasonCodes.contains("evolution.retraction_pending"))
        XCTAssertEqual(decision.primaryReason, decision.reasonCodes.first)
    }

    func testPromotionDecisionAllowsAfterPassedCleanTrial() async throws {
        let (furnace, _) = makeFurnace(
            trialIDs: ["t-1"],
            sealIDs: ["s-1"])
        _ = try await furnace.submit(
            candidate: makeCandidate(),
            sessionID: "session-A",
            turnID: "turn-1",
            trialScope: "scope.growth")
        _ = try await furnace.finalize(
            trialID: "t-1",
            outcome: .passed,
            sessionID: "session-A",
            turnID: "turn-2")
        let decision = await furnace.promotionDecision(
            for: "candidate.bias-fix.v1")
        XCTAssertTrue(decision.allowsPromotion)
        XCTAssertTrue(decision.reasonCodes.isEmpty)
        XCTAssertNil(decision.primaryReason)
    }

    // MARK: - TrialEvent mirror + replay

    func testAllTrialEventsReflectsFullLedgerChain() async throws {
        let (furnace, _) = makeFurnace(
            trialIDs: ["t-1"],
            sealIDs: ["s-1"],
            retractionIDs: ["r-1"])
        _ = try await furnace.submit(
            candidate: makeCandidate(),
            sessionID: "session-A",
            turnID: "turn-1",
            trialScope: "scope.growth")
        _ = try await furnace.observe(
            trialID: "t-1",
            effect: "e1",
            sessionID: "session-A",
            turnID: "turn-2")
        _ = try await furnace.reportFail(
            trialID: "t-1",
            reason: "host-rejected",
            sessionID: "session-A",
            turnID: "turn-3")
        _ = try await furnace.finalize(
            trialID: "t-1",
            outcome: .failed,
            sessionID: "session-A",
            turnID: "turn-4")
        let events = await furnace.allTrialEvents()
        let kinds = events.map(\.eventKind)
        XCTAssertEqual(kinds, [
            "shadow_trial_opened",
            "shadow_trial_effect_observed",
            "shadow_trial_fail_condition_recorded",
            "shadow_trial_failed",
            "evolution_seal_denied",
            "retraction_order_queued",
        ])
    }

    func testReplayFiltersByCandidateID() async throws {
        let (furnace, _) = makeFurnace(
            trialIDs: ["t-A", "t-B"],
            sealIDs: ["s-A", "s-B"])
        _ = try await furnace.submit(
            candidate: makeCandidate(id: "cand.A"),
            sessionID: "session-A",
            turnID: "turn-1",
            trialScope: "scope.A")
        _ = try await furnace.submit(
            candidate: makeCandidate(id: "cand.B"),
            sessionID: "session-A",
            turnID: "turn-2",
            trialScope: "scope.B")
        _ = try await furnace.finalize(
            trialID: "t-A",
            outcome: .passed,
            sessionID: "session-A",
            turnID: "turn-3")
        _ = try await furnace.finalize(
            trialID: "t-B",
            outcome: .passed,
            sessionID: "session-A",
            turnID: "turn-4")
        let replayA = await furnace.replay(candidateID: "cand.A")
        XCTAssertEqual(replayA.map(\.eventKind), [
            "shadow_trial_opened",
            "shadow_trial_passed",
            "evolution_seal_issued",
        ])
        XCTAssertTrue(
            replayA.allSatisfy { $0.actionRefs.contains("cand.A") })
        XCTAssertFalse(
            replayA.contains(where: { $0.actionRefs.contains("cand.B") }))
    }

    func testTrialEventSubjectRefPreservesSubstrateValue() async throws {
        let (furnace, ledger) = makeFurnace(trialIDs: ["t-xyz"])
        _ = try await furnace.submit(
            candidate: makeCandidate(),
            sessionID: "session-A",
            turnID: "turn-1",
            trialScope: "scope.growth")
        let qinaoEvents = await furnace.allTrialEvents()
        let substrateEntries = await ledger.all()
        XCTAssertEqual(qinaoEvents.count, substrateEntries.count)
        XCTAssertEqual(qinaoEvents[0].subjectRef, "shadow_trial\u{001F}t-xyz")
        XCTAssertEqual(
            qinaoEvents[0].subjectRef,
            substrateEntries[0].verdictRef,
            "subjectRef should carry verdictRef's value verbatim")
    }

    func testPromotionDecisionCodableRoundTrip() throws {
        let original = QinaoFurnace.PromotionDecision(
            allowsPromotion: false,
            reasonCodes: ["evolution.shadow_trial_failed", "evolution.retraction_pending"],
            primaryReason: "evolution.shadow_trial_failed")
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(original)
        let decoded = try JSONDecoder().decode(
            QinaoFurnace.PromotionDecision.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testTrialEventCodableRoundTrip() throws {
        let original = QinaoFurnace.TrialEvent(
            auditID: "a-1",
            sessionID: "session-A",
            turnID: "turn-1",
            subjectRef: "shadow_trial:t-1",
            ruleIDs: ["L13.shadow_trial_opened"],
            signalRefs: ["src-1"],
            actionRefs: ["cand.1"],
            snapshotRef: "scope.growth",
            signaturePayload: "shadow_trial_opened|t-1|cand.1|pending",
            appendedAt: Date(timeIntervalSince1970: 1_730_500_000),
            eventKind: "shadow_trial_opened")
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(original)
        let decoded = try JSONDecoder().decode(
            QinaoFurnace.TrialEvent.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Workbench

    func testRunWorkbenchPassedHappyPath() async throws {
        let (furnace, _) = makeFurnace(
            trialIDs: ["t-1"],
            sealIDs: ["s-1"])
        let plan = QinaoFurnace.WorkbenchPlan(
            candidate: makeCandidate(),
            trialScope: "scope.growth",
            outcome: .passed,
            promotionRecommendation: "admit")
        let receipt = try await furnace.runWorkbench(
            plan: plan,
            sessionID: "session-A",
            turnID: "turn-1")
        XCTAssertEqual(receipt.trialID, "t-1")
        XCTAssertEqual(receipt.finalState, "passed")
        XCTAssertEqual(receipt.seal?.approvalState, "sealed")
        XCTAssertNil(receipt.retraction)
        XCTAssertTrue(receipt.promotionDecision.allowsPromotion)
    }

    func testRunWorkbenchRecordsObservationsAndFailConditions() async throws {
        let (furnace, _) = makeFurnace(
            trialIDs: ["t-1"],
            sealIDs: ["s-1"])
        let plan = QinaoFurnace.WorkbenchPlan(
            candidate: makeCandidate(),
            trialScope: "scope.growth",
            observedEffects: ["e1", "e2"],
            failConditions: ["drift"],
            outcome: .passed)
        let receipt = try await furnace.runWorkbench(
            plan: plan,
            sessionID: "session-A",
            turnID: "turn-1")
        let trial = await furnace.trial(for: receipt.trialID)
        XCTAssertEqual(trial?.observedEffects, ["e1", "e2"])
        XCTAssertEqual(trial?.failConditions, ["drift"])
        XCTAssertEqual(trial?.completionState, "passed")
    }

    func testRunWorkbenchFailedQueuesRetraction() async throws {
        let (furnace, _) = makeFurnace(
            trialIDs: ["t-1"],
            sealIDs: ["s-1"],
            retractionIDs: ["r-1"])
        let plan = QinaoFurnace.WorkbenchPlan(
            candidate: makeCandidate(),
            trialScope: "scope.growth",
            failConditions: ["regression-detected"],
            outcome: .failed)
        let receipt = try await furnace.runWorkbench(
            plan: plan,
            sessionID: "session-A",
            turnID: "turn-1")
        XCTAssertEqual(receipt.finalState, "failed")
        XCTAssertEqual(receipt.retraction?.executionState, "queued")
        XCTAssertFalse(receipt.promotionDecision.allowsPromotion)
    }

    // MARK: - Auto-promotion

    func testAttemptAutoPromotionPassedAndCleanPromotes() async throws {
        let (furnace, _) = makeFurnace(
            trialIDs: ["t-1"],
            sealIDs: ["s-1"])
        let plan = QinaoFurnace.WorkbenchPlan(
            candidate: makeCandidate(),
            trialScope: "scope.growth",
            outcome: .passed)
        let receipt = try await furnace.attemptAutoPromotion(
            plan: plan,
            sessionID: "session-A",
            turnID: "turn-1")
        XCTAssertEqual(receipt.candidateID, "candidate.bias-fix.v1")
        XCTAssertEqual(receipt.outcome, .passed)
        XCTAssertTrue(receipt.promoted)
        XCTAssertTrue(receipt.promotionDecision.allowsPromotion)
    }

    func testAttemptAutoPromotionFailedDoesNotPromote() async throws {
        let (furnace, _) = makeFurnace(
            trialIDs: ["t-1"],
            sealIDs: ["s-1"],
            retractionIDs: ["r-1"])
        let plan = QinaoFurnace.WorkbenchPlan(
            candidate: makeCandidate(),
            trialScope: "scope.growth",
            outcome: .failed)
        let receipt = try await furnace.attemptAutoPromotion(
            plan: plan,
            sessionID: "session-A",
            turnID: "turn-1")
        XCTAssertFalse(receipt.promoted)
        XCTAssertFalse(receipt.promotionDecision.allowsPromotion)
    }

    func testAttemptAutoPromotionPassedButPriorFailureBlocks() async throws {
        // First trial fails; second trial on same candidate passes.
        // Promotion gate still blocks because historical failed count
        // is 1 AND the retraction from trial-1 is still queued.
        let (furnace, _) = makeFurnace(
            trialIDs: ["t-1", "t-2"],
            sealIDs: ["s-1", "s-2"],
            retractionIDs: ["r-1"])
        let first = QinaoFurnace.WorkbenchPlan(
            candidate: makeCandidate(),
            trialScope: "scope.growth",
            outcome: .failed)
        _ = try await furnace.runWorkbench(
            plan: first,
            sessionID: "session-A",
            turnID: "turn-1")
        let second = QinaoFurnace.WorkbenchPlan(
            candidate: makeCandidate(),
            trialScope: "scope.growth",
            outcome: .passed)
        let receipt = try await furnace.attemptAutoPromotion(
            plan: second,
            sessionID: "session-A",
            turnID: "turn-2")
        XCTAssertEqual(receipt.outcome, .passed)
        XCTAssertFalse(receipt.promoted,
            "prior failure + pending retraction should keep promoted=false")
        XCTAssertTrue(
            receipt.promotionDecision.reasonCodes.contains(
                "evolution.shadow_trial_failed"))
    }

    // MARK: - Read-side

    func testReadSideMethodsProjectCoordinatorState() async throws {
        let (furnace, _) = makeFurnace(
            trialIDs: ["t-1"],
            sealIDs: ["s-1"])
        _ = try await furnace.submit(
            candidate: makeCandidate(),
            sessionID: "session-A",
            turnID: "turn-1",
            trialScope: "scope.growth")
        let pending = await furnace.pendingTrials()
        XCTAssertEqual(pending.count, 1)
        let candidate = await furnace.candidate(for: "candidate.bias-fix.v1")
        XCTAssertEqual(candidate?.candidateID, "candidate.bias-fix.v1")
        let history = await furnace.trials(for: "candidate.bias-fix.v1")
        XCTAssertEqual(history.count, 1)
    }
}

// MARK: - Utilities

/// Thread-safe monotonic pump for deterministic IDs. Mirrors the
/// pattern used in `BASShadowTrialCoordinatorTests` so the Qinao
/// suite's ID vocabulary matches the substrate suite's.
private final class CounterPump: @unchecked Sendable {
    private let lock = NSLock()
    private var nextIndex = 0
    private let ids: [String]
    private let prefix: String

    init(ids: [String], prefix: String) {
        self.ids = ids
        self.prefix = prefix
    }

    func next() -> String {
        lock.lock()
        defer { lock.unlock() }
        if nextIndex < ids.count {
            let value = ids[nextIndex]
            nextIndex += 1
            return value
        }
        let value = "\(prefix)-auto-\(nextIndex)"
        nextIndex += 1
        return value
    }
}
