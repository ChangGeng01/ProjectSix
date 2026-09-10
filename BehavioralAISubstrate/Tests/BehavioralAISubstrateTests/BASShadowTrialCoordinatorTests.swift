import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASSovereign
@testable import BASOrchestration

/// Tests for the L13 shadow-trial coordinator (M11).
///
/// The coordinator's promise: every transition a candidate takes
/// through the trial pipeline is:
///
///   1. typed (you cannot end up in a state not in the enum)
///   2. atomic w.r.t. the ledger (if the append fails, nothing else
///      is mutated)
///   3. audited (every transition appends exactly one ledger entry)
///   4. promotion-gate aware (derived verdict matches the schema
///      counter rules from `BASEvolutionPromotionGate`)
///
/// The `testSovereignLedgerBridgeJoinsChains` integration test is the
/// highlight. It proves the shadow-trial chain is not a shadow ledger
/// running in parallel to the sovereign one — every shadow-trial
/// event lands on the **same** hash chain as the sovereign verdict
/// entries, so integrity of one implies integrity of the other.
final class BASShadowTrialCoordinatorTests: XCTestCase {

    // MARK: - Fixtures

    private static let fixedNow = Date(timeIntervalSince1970: 1_730_500_000)

    private func makeClock() -> @Sendable () -> Date {
        let target = Self.fixedNow
        return { target }
    }

    private func makeCandidate(
        id: String = "candidate.bias-fix.v1",
        candidateType: BASExperienceCandidateType = .bias,
        sourceRefs: [String] = ["src-1", "src-2"],
        stability: Double = 0.8,
        contamination: Double = 0.1,
        hostScope: String = "host.domain.finance",
        sovereignScope: String = "sovereign.scope.growth"
    ) -> BASExperienceCandidate {
        BASExperienceCandidate(
            candidateID: id,
            sourceRefs: sourceRefs,
            candidateType: candidateType,
            summary: "summary for \(id)",
            stabilitySignal: stability,
            contaminationRisk: contamination,
            hostScope: hostScope,
            sovereignScope: sovereignScope)
    }

    private func makeCoordinator(
        ledger: any BASShadowTrialLedger,
        trialIDs: [String] = [],
        sealIDs: [String] = [],
        retractionIDs: [String] = [],
        auditIDs: [String] = []
    ) -> BASShadowTrialCoordinator {
        // Deterministic ID pumps: peel from the front of each list,
        // fall back to a prefix+counter if the list is exhausted.
        let trialCounter = CounterPump(ids: trialIDs, prefix: "trial")
        let sealCounter = CounterPump(ids: sealIDs, prefix: "seal")
        let retractionCounter = CounterPump(ids: retractionIDs, prefix: "retract")
        let auditCounter = CounterPump(ids: auditIDs, prefix: "audit")
        return BASShadowTrialCoordinator(
            ledger: ledger,
            clock: makeClock(),
            nextAuditID: { auditCounter.next() },
            nextTrialID: { trialCounter.next() },
            nextSealID: { sealCounter.next() },
            nextRetractionID: { retractionCounter.next() })
    }

    // MARK: - submit

    func testSubmitOpensPendingTrialAndAppendsOneEntry() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coordinator = makeCoordinator(
            ledger: ledger,
            trialIDs: ["t-1"],
            auditIDs: ["a-1"])
        let candidate = makeCandidate()

        let record = try await coordinator.submit(
            candidate: candidate,
            sessionID: "session-A",
            turnID: "turn-1",
            trialScope: "scope.growth")

        XCTAssertEqual(record.trialID, "t-1")
        XCTAssertEqual(record.candidateRef, candidate.candidateID)
        XCTAssertEqual(record.trialScope, "scope.growth")
        XCTAssertEqual(record.completionState, "pending")
        XCTAssertTrue(record.isPending)
        XCTAssertTrue(record.observedEffects.isEmpty)
        XCTAssertTrue(record.failConditions.isEmpty)
        XCTAssertNil(record.endAt)

        let entries = await ledger.all()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].eventKind, "shadow_trial_opened")
        XCTAssertEqual(entries[0].auditID, "a-1")
        XCTAssertEqual(entries[0].actionRefs, [candidate.candidateID])
        XCTAssertEqual(entries[0].snapshotRef, "scope.growth")
        // ch 1014.6 / M3795 — Round-23 CRITICAL-3 fix: U+001F
        XCTAssertEqual(entries[0].verdictRef,
            "shadow_trial\u{001F}t-1")
        XCTAssertEqual(entries[0].ruleIDs, ["L13.shadow_trial_opened"])
        XCTAssertEqual(entries[0].signalRefs, candidate.sourceRefs)
    }

    func testSubmitRejectsDuplicateActiveTrialForSameCandidate() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coordinator = makeCoordinator(
            ledger: ledger,
            trialIDs: ["t-1", "t-2"],
            auditIDs: ["a-1", "a-2"])
        let candidate = makeCandidate()

        _ = try await coordinator.submit(
            candidate: candidate,
            sessionID: "s",
            turnID: "t",
            trialScope: "scope")

        do {
            _ = try await coordinator.submit(
                candidate: candidate,
                sessionID: "s",
                turnID: "t",
                trialScope: "scope")
            XCTFail("duplicate submit should have thrown")
        } catch let error as BASShadowTrialCoordinator.TrialError {
            guard case .candidateAlreadyHasActiveTrial(
                let cid, let tid) = error else {
                return XCTFail("wrong error: \(error)")
            }
            XCTAssertEqual(cid, candidate.candidateID)
            XCTAssertEqual(tid, "t-1")
        }

        // The second submit must not have added a ledger entry.
        let count = await ledger.count()
        XCTAssertEqual(count, 1)
    }

    func testSubmitRejectsEmptyScope() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coordinator = makeCoordinator(ledger: ledger)

        do {
            _ = try await coordinator.submit(
                candidate: makeCandidate(),
                sessionID: "s",
                turnID: "t",
                trialScope: "   ")
            XCTFail("empty scope must throw")
        } catch let error as BASShadowTrialCoordinator.TrialError {
            XCTAssertEqual(error, .invalidInput(reason: "empty-trialScope"))
        }
        let count = await ledger.count()
        XCTAssertEqual(count, 0)
    }

    // MARK: - observe / reportFailCondition

    func testObserveTransitionsToObservingAndAppends() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coordinator = makeCoordinator(
            ledger: ledger,
            trialIDs: ["t-1"],
            auditIDs: ["a-1", "a-2", "a-3"])
        _ = try await coordinator.submit(
            candidate: makeCandidate(),
            sessionID: "s",
            turnID: "t-1",
            trialScope: "scope")

        let r1 = try await coordinator.observe(
            trialID: "t-1",
            effect: "neutral-response-shift",
            sessionID: "s",
            turnID: "t-1")
        XCTAssertEqual(r1.completionState, "observing")
        XCTAssertEqual(r1.observedEffects, ["neutral-response-shift"])

        let r2 = try await coordinator.observe(
            trialID: "t-1",
            effect: "latency-increase",
            sessionID: "s",
            turnID: "t-2")
        XCTAssertEqual(r2.completionState, "observing")
        XCTAssertEqual(r2.observedEffects, ["neutral-response-shift", "latency-increase"])

        let kinds = await ledger.eventKinds()
        XCTAssertEqual(kinds, [
            "shadow_trial_opened",
            "shadow_trial_effect_observed",
            "shadow_trial_effect_observed",
        ])
    }

    func testReportFailConditionAccumulatesWithoutFinalizing() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coordinator = makeCoordinator(
            ledger: ledger,
            trialIDs: ["t-1"],
            auditIDs: ["a-1", "a-2"])
        _ = try await coordinator.submit(
            candidate: makeCandidate(),
            sessionID: "s",
            turnID: "t-1",
            trialScope: "scope")

        let updated = try await coordinator.reportFailCondition(
            trialID: "t-1",
            reason: "host-boundary-violation",
            sessionID: "s",
            turnID: "t-1")
        XCTAssertEqual(updated.completionState, "observing",
            "fail condition alone must not terminate the trial")
        XCTAssertEqual(updated.failConditions, ["host-boundary-violation"])
        XCTAssertTrue(updated.isPending)
    }

    func testObserveOnUnknownTrialThrows() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coordinator = makeCoordinator(ledger: ledger)
        do {
            _ = try await coordinator.observe(
                trialID: "nope",
                effect: "anything",
                sessionID: "s",
                turnID: "t")
            XCTFail("unknown trial must throw")
        } catch let error as BASShadowTrialCoordinator.TrialError {
            XCTAssertEqual(error, .unknownTrial(id: "nope"))
        }
    }

    // MARK: - finalize: passed / failed / blocked

    func testFinalizePassedIssuesApprovedSealNoRetraction() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coordinator = makeCoordinator(
            ledger: ledger,
            trialIDs: ["t-1"],
            sealIDs: ["seal-1"],
            auditIDs: ["a-1", "a-2", "a-3"])
        let candidate = makeCandidate()
        _ = try await coordinator.submit(
            candidate: candidate,
            sessionID: "s",
            turnID: "t-1",
            trialScope: "scope")

        let finalized = try await coordinator.finalize(
            trialID: "t-1",
            outcome: .passed,
            promotionRecommendation: "promote-with-scope:growth",
            sessionID: "s",
            turnID: "t-1")

        XCTAssertEqual(finalized.completionState, "passed")
        XCTAssertTrue(finalized.isPassed)
        XCTAssertEqual(finalized.promotionRecommendation, "promote-with-scope:growth")
        XCTAssertNotNil(finalized.endAt)

        let seal = await coordinator.seal(for: candidate.candidateID)
        XCTAssertNotNil(seal)
        XCTAssertEqual(seal?.approvalState, "sealed")
        XCTAssertTrue(seal?.isApproved == true)
        XCTAssertEqual(seal?.allowedScope, candidate.sovereignScope)
        XCTAssertEqual(seal?.trialRequired, true)

        let retraction = await coordinator.retraction(for: candidate.candidateID)
        XCTAssertNil(retraction, "passed outcome must not queue a retraction")

        let kinds = await ledger.eventKinds()
        XCTAssertEqual(kinds, [
            "shadow_trial_opened",
            "shadow_trial_passed",
            "evolution_seal_issued",
        ])
    }

    func testFinalizeFailedDeniesSealAndQueuesRetraction() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coordinator = makeCoordinator(
            ledger: ledger,
            trialIDs: ["t-1"],
            sealIDs: ["seal-1"],
            retractionIDs: ["r-1"],
            auditIDs: ["a-1", "a-2", "a-3", "a-4"])
        let candidate = makeCandidate(sourceRefs: ["src-x", "src-y"])
        _ = try await coordinator.submit(
            candidate: candidate,
            sessionID: "s",
            turnID: "t-1",
            trialScope: "scope")

        let finalized = try await coordinator.finalize(
            trialID: "t-1",
            outcome: .failed,
            promotionRecommendation: nil,
            sessionID: "s",
            turnID: "t-1")

        XCTAssertEqual(finalized.completionState, "failed")
        XCTAssertTrue(finalized.isFailed)

        let seal = await coordinator.seal(for: candidate.candidateID)
        XCTAssertEqual(seal?.approvalState, "denied")
        XCTAssertTrue(seal?.isDenied == true)

        let retraction = await coordinator.retraction(for: candidate.candidateID)
        XCTAssertNotNil(retraction)
        XCTAssertEqual(retraction?.executionState, "queued")
        XCTAssertEqual(retraction?.targetRefs, [candidate.candidateID])
        XCTAssertEqual(retraction?.cascadeRefs, candidate.sourceRefs,
            "cascade must mirror candidate.sourceRefs")
        XCTAssertEqual(retraction?.reasonCodes, ["L13.shadow_trial_failed"])

        let kinds = await ledger.eventKinds()
        XCTAssertEqual(kinds, [
            "shadow_trial_opened",
            "shadow_trial_failed",
            "evolution_seal_denied",
            "retraction_order_queued",
        ])
    }

    func testFinalizeBlockedDeniesSealWithBlockedReason() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coordinator = makeCoordinator(
            ledger: ledger,
            trialIDs: ["t-1"],
            sealIDs: ["seal-1"],
            retractionIDs: ["r-1"],
            auditIDs: ["a-1", "a-2", "a-3", "a-4"])
        let candidate = makeCandidate()
        _ = try await coordinator.submit(
            candidate: candidate,
            sessionID: "s",
            turnID: "t-1",
            trialScope: "scope")
        let finalized = try await coordinator.finalize(
            trialID: "t-1",
            outcome: .blocked,
            promotionRecommendation: nil,
            sessionID: "s",
            turnID: "t-1")
        XCTAssertEqual(finalized.completionState, "blocked")
        XCTAssertTrue(finalized.isFailed)

        let retraction = await coordinator.retraction(for: candidate.candidateID)
        XCTAssertEqual(retraction?.reasonCodes, ["L13.shadow_trial_blocked"])
    }

    func testFinalizeRejectsAlreadyFinalizedTrial() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coordinator = makeCoordinator(
            ledger: ledger,
            trialIDs: ["t-1"],
            sealIDs: ["seal-1"],
            auditIDs: ["a-1", "a-2", "a-3"])
        _ = try await coordinator.submit(
            candidate: makeCandidate(),
            sessionID: "s",
            turnID: "t-1",
            trialScope: "scope")
        _ = try await coordinator.finalize(
            trialID: "t-1",
            outcome: .passed,
            promotionRecommendation: nil,
            sessionID: "s",
            turnID: "t-1")

        do {
            _ = try await coordinator.finalize(
                trialID: "t-1",
                outcome: .failed,
                promotionRecommendation: nil,
                sessionID: "s",
                turnID: "t-1")
            XCTFail("double finalize must throw")
        } catch let error as BASShadowTrialCoordinator.TrialError {
            XCTAssertEqual(error, .trialAlreadyFinalized(id: "t-1", state: "passed"))
        }
    }

    // MARK: - Atomicity

    func testLedgerFailureRollsBackTrialOpen() async throws {
        // Ledger refuses every append. Submit must throw and the
        // coordinator's state must be untouched.
        let ledger = BASInMemoryShadowTrialLedger(
            failWhen: { _ in "simulated-chain-break" })
        let coordinator = makeCoordinator(
            ledger: ledger,
            trialIDs: ["t-1"],
            auditIDs: ["a-1"])
        do {
            _ = try await coordinator.submit(
                candidate: makeCandidate(),
                sessionID: "s",
                turnID: "t",
                trialScope: "scope")
            XCTFail("submit must throw when ledger rejects")
        } catch let error as BASShadowTrialCoordinator.TrialError {
            guard case .ledgerAppendFailed = error else {
                return XCTFail("wrong error: \(error)")
            }
        }
        let pending = await coordinator.pendingTrials()
        XCTAssertTrue(pending.isEmpty, "trial state must not exist after ledger reject")
        let loaded = await coordinator.trial(for: "t-1")
        XCTAssertNil(loaded)
    }

    // MARK: - Promotion gate parity

    func testPromotionVerdictAllowsWhenPassed() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coordinator = makeCoordinator(
            ledger: ledger,
            trialIDs: ["t-1"],
            sealIDs: ["seal-1"],
            auditIDs: ["a-1", "a-2", "a-3"])
        let candidate = makeCandidate()
        _ = try await coordinator.submit(
            candidate: candidate,
            sessionID: "s",
            turnID: "t-1",
            trialScope: "scope")
        _ = try await coordinator.finalize(
            trialID: "t-1",
            outcome: .passed,
            promotionRecommendation: nil,
            sessionID: "s",
            turnID: "t-1")

        let verdict = await coordinator.promotionVerdict(for: candidate.candidateID)
        XCTAssertTrue(verdict.allowsPromotion)
        XCTAssertTrue(verdict.reasonCodes.isEmpty)
    }

    func testPromotionVerdictBlocksWhenPending() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coordinator = makeCoordinator(
            ledger: ledger,
            trialIDs: ["t-1"],
            auditIDs: ["a-1"])
        let candidate = makeCandidate()
        _ = try await coordinator.submit(
            candidate: candidate,
            sessionID: "s",
            turnID: "t-1",
            trialScope: "scope")

        let verdict = await coordinator.promotionVerdict(for: candidate.candidateID)
        XCTAssertFalse(verdict.allowsPromotion)
        XCTAssertTrue(verdict.reasonCodes.contains("evolution.shadow_trial_pending"))
    }

    func testPromotionVerdictBlocksWhenFailedAndRetractionPending() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coordinator = makeCoordinator(
            ledger: ledger,
            trialIDs: ["t-1"],
            sealIDs: ["seal-1"],
            retractionIDs: ["r-1"],
            auditIDs: ["a-1", "a-2", "a-3", "a-4"])
        let candidate = makeCandidate()
        _ = try await coordinator.submit(
            candidate: candidate,
            sessionID: "s",
            turnID: "t-1",
            trialScope: "scope")
        _ = try await coordinator.finalize(
            trialID: "t-1",
            outcome: .failed,
            promotionRecommendation: nil,
            sessionID: "s",
            turnID: "t-1")

        let verdict = await coordinator.promotionVerdict(for: candidate.candidateID)
        XCTAssertFalse(verdict.allowsPromotion)
        XCTAssertTrue(verdict.reasonCodes.contains("evolution.shadow_trial_failed"))
        XCTAssertTrue(verdict.reasonCodes.contains("evolution.seal_denied"))
        XCTAssertTrue(verdict.reasonCodes.contains("evolution.retraction_pending"))
    }

    // MARK: - Sovereign ledger bridge integration

    /// The highlight test of M11: prove the shadow-trial chain and
    /// the sovereign verdict chain share a single hash chain. If we
    /// append a verdict entry via the sovereign API, then drive the
    /// coordinator through a full pass, then append another verdict,
    /// the whole ledger's chain integrity still holds and every
    /// shadow-trial event is present at the expected position.
    func testSovereignLedgerBridgeJoinsChains() async throws {
        let ledger = BASSovereignAuditLedger.withSeed("m11-bridge-test-seed")

        // Sovereign entry #1 — something that happened before any
        // trial was opened.
        _ = try await ledger.append(BASSovereignAuditEntry(
            auditID: "sov-1",
            sessionID: "session-X",
            turnID: "turn-1",
            verdictRef: "verdict:something-else",
            snapshotRef: "snap-pre-trial",
            signature: "",
            appendedAt: Self.fixedNow))

        // Drive a full passed trial through the coordinator using
        // the same ledger (via the BASOrchestration bridge).
        let coordinator = makeCoordinator(
            ledger: ledger,
            trialIDs: ["t-1"],
            sealIDs: ["seal-1"],
            auditIDs: ["sov-trial-open", "sov-trial-pass", "sov-seal-issued"])
        let candidate = makeCandidate()
        _ = try await coordinator.submit(
            candidate: candidate,
            sessionID: "session-X",
            turnID: "turn-2",
            trialScope: "scope.growth")
        _ = try await coordinator.finalize(
            trialID: "t-1",
            outcome: .passed,
            promotionRecommendation: "promote",
            sessionID: "session-X",
            turnID: "turn-2")

        // Sovereign entry #2 — something that happened after.
        _ = try await ledger.append(BASSovereignAuditEntry(
            auditID: "sov-2",
            sessionID: "session-X",
            turnID: "turn-3",
            verdictRef: "verdict:post-trial",
            snapshotRef: "snap-post-trial",
            signature: "",
            appendedAt: Self.fixedNow))

        // One chain, five entries, all linked.
        let count = await ledger.count()
        XCTAssertEqual(count, 5)
        try await ledger.verifyChainIntegrity()

        // Shadow-trial entries are present in the sovereign chain.
        let trialOpen = try await ledger.query(byAuditRef: "sov-trial-open")
        XCTAssertEqual(trialOpen.entry.verdictRef,
            "shadow_trial\u{001F}t-1")
        XCTAssertEqual(trialOpen.entry.actionRefs, [candidate.candidateID])

        let trialPass = try await ledger.query(byAuditRef: "sov-trial-pass")
        XCTAssertEqual(trialPass.entry.ruleIDs, ["L13.shadow_trial_passed"])

        let sealIssued = try await ledger.query(byAuditRef: "sov-seal-issued")
        XCTAssertEqual(sealIssued.entry.verdictRef,
            "evolution_seal\u{001F}seal-1")
        XCTAssertEqual(sealIssued.entry.ruleIDs, ["L13.evolution_seal_issued"])
    }

    /// A coordinator driving the sovereign ledger must not produce
    /// any signature collisions or chain breaks across a longer
    /// session. Runs observe→observe→reportFail→finalize with every
    /// transition going through the bridge, then asks the sovereign
    /// ledger to verify its own chain.
    func testSovereignLedgerBridgeKeepsChainIntactAcrossFullSession() async throws {
        let ledger = BASSovereignAuditLedger.withSeed("m11-bridge-full-session")
        let coordinator = makeCoordinator(
            ledger: ledger,
            trialIDs: ["t-1"],
            sealIDs: ["seal-1"],
            retractionIDs: ["r-1"],
            auditIDs: ["o-open", "o-eff-1", "o-eff-2", "o-fail-cond",
                       "o-final", "o-seal", "o-retract"])
        let candidate = makeCandidate()
        _ = try await coordinator.submit(
            candidate: candidate,
            sessionID: "session-long",
            turnID: "turn-1",
            trialScope: "scope")
        _ = try await coordinator.observe(
            trialID: "t-1",
            effect: "latency-spike",
            sessionID: "session-long",
            turnID: "turn-2")
        _ = try await coordinator.observe(
            trialID: "t-1",
            effect: "empathy-regression",
            sessionID: "session-long",
            turnID: "turn-3")
        _ = try await coordinator.reportFailCondition(
            trialID: "t-1",
            reason: "hostBoundary-breached",
            sessionID: "session-long",
            turnID: "turn-4")
        _ = try await coordinator.finalize(
            trialID: "t-1",
            outcome: .failed,
            promotionRecommendation: nil,
            sessionID: "session-long",
            turnID: "turn-5")

        let count = await ledger.count()
        XCTAssertEqual(count, 7, "7 ledger appends: open+2 observe+1 failCond+final+seal+retract")
        try await ledger.verifyChainIntegrity()

        let kinds: [String] = try await [
            ledger.query(byAuditRef: "o-open").entry.ruleIDs.first,
            ledger.query(byAuditRef: "o-eff-1").entry.ruleIDs.first,
            ledger.query(byAuditRef: "o-eff-2").entry.ruleIDs.first,
            ledger.query(byAuditRef: "o-fail-cond").entry.ruleIDs.first,
            ledger.query(byAuditRef: "o-final").entry.ruleIDs.first,
            ledger.query(byAuditRef: "o-seal").entry.ruleIDs.first,
            ledger.query(byAuditRef: "o-retract").entry.ruleIDs.first,
        ].map { $0 ?? "" }
        XCTAssertEqual(kinds, [
            "L13.shadow_trial_opened",
            "L13.shadow_trial_effect_observed",
            "L13.shadow_trial_effect_observed",
            "L13.shadow_trial_fail_condition_recorded",
            "L13.shadow_trial_failed",
            "L13.evolution_seal_denied",
            "L13.retraction_order_queued",
        ])
    }

    // MARK: - resumeTrial (cross-process resume, The Ledger increment 3)

    /// The gap resumeTrial fills: a fresh coordinator (a new process) cannot finalize a trial it
    /// never saw, because trial state is in-memory only and never rehydrated from the ledger.
    func testFinalizeWithoutResumeThrowsUnknownTrial() async throws {
        let coordinator = makeCoordinator(ledger: BASInMemoryShadowTrialLedger())
        do {
            _ = try await coordinator.finalize(
                trialID: "trial-never-opened-here", outcome: .passed,
                promotionRecommendation: nil, sessionID: "s", turnID: "t")
            XCTFail("finalize on an unknown trial must throw")
        } catch let error as BASShadowTrialCoordinator.TrialError {
            guard case .unknownTrial = error else { return XCTFail("wrong error: \(error)") }
        }
    }

    /// The real cross-process flow: coordinator A opens a trial and shares a ledger; a SEPARATE
    /// coordinator B (fresh in-memory state) resumes that trial from the persisted record and
    /// finalizes it through the public API. Proves the seam lets observe()/finalize() drive a
    /// trial opened by a dead process — and that finalize still appends exactly the terminal
    /// events (no re-open).
    func testResumeTrialThenFinalizePassesAndSeals() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let candidate = makeCandidate()

        // Process A: open.
        let coordA = makeCoordinator(ledger: ledger, trialIDs: ["t-1"], auditIDs: ["a-open"])
        let opened = try await coordA.submit(
            candidate: candidate, sessionID: "s", turnID: "t", trialScope: "scope.growth")
        let openedCount = await ledger.count()
        XCTAssertEqual(openedCount, 1)

        // Process B: fresh coordinator, SAME ledger. It knows nothing until it resumes.
        let coordB = makeCoordinator(
            ledger: ledger, sealIDs: ["seal-1"], auditIDs: ["a-final", "a-seal"])
        try await coordB.resumeTrial(candidate: candidate, record: opened)

        let done = try await coordB.finalize(
            trialID: "t-1", outcome: .passed, promotionRecommendation: "adopt",
            sessionID: "s", turnID: "t2")
        XCTAssertEqual(done.completionState, "passed")

        // The promotion verdict fires over the resumed history + fresh seal → allowed.
        let verdict = await coordB.promotionVerdict(for: candidate.candidateID)
        XCTAssertTrue(verdict.allowsPromotion, "resumed+passed trial must allow promotion: \(verdict.reasonCodes)")
        XCTAssertTrue(verdict.reasonCodes.isEmpty)

        // Exactly the terminal events were appended (open + passed + seal = 3); resume added none.
        let kinds = await ledger.all().map(\.eventKind)
        XCTAssertEqual(kinds, ["shadow_trial_opened", "shadow_trial_passed", "evolution_seal_issued"])
    }

    /// resumeTrial fails closed: mismatched candidate/record, an already-terminal record, and a
    /// double-resume of a live trial are all rejected — no silent state corruption.
    func testResumeTrialGuardsFailClosed() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let candidate = makeCandidate()
        let coord = makeCoordinator(ledger: ledger, trialIDs: ["t-1"], auditIDs: ["a-1"])
        let record = try await coord.submit(
            candidate: candidate, sessionID: "s", turnID: "t", trialScope: "scope")

        // (a) candidate/record mismatch.
        let other = makeCandidate(id: "candidate.other.v1")
        let fresh1 = makeCoordinator(ledger: BASInMemoryShadowTrialLedger())
        do {
            try await fresh1.resumeTrial(candidate: other, record: record)
            XCTFail("mismatched candidate must throw")
        } catch let e as BASShadowTrialCoordinator.TrialError {
            guard case .invalidInput = e else { return XCTFail("wrong error: \(e)") }
        }

        // (b) already-terminal record cannot be resumed for further finalize.
        var terminal = record
        terminal.completionState = "passed"
        let fresh2 = makeCoordinator(ledger: BASInMemoryShadowTrialLedger())
        do {
            try await fresh2.resumeTrial(candidate: candidate, record: terminal)
            XCTFail("terminal record must throw")
        } catch let e as BASShadowTrialCoordinator.TrialError {
            guard case .trialAlreadyFinalized = e else { return XCTFail("wrong error: \(e)") }
        }

        // (c) double-resume of a live trial on the SAME coordinator is rejected.
        do {
            try await coord.resumeTrial(candidate: candidate, record: record)
            XCTFail("double-resume of a resident trial must throw")
        } catch let e as BASShadowTrialCoordinator.TrialError {
            // resident trial ⇒ duplicateTrial (or activeTrial); either is a fail-closed rejection.
            switch e {
            case .duplicateTrial, .candidateAlreadyHasActiveTrial: break
            default: XCTFail("wrong error: \(e)")
            }
        }
    }
}

// MARK: - Utilities

/// Thread-safe monotonic pump for deterministic IDs. Exposed through
/// a closure so the coordinator sees it as `@Sendable () -> String`.
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
