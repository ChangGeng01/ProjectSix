import XCTest
@testable import BASRuntimeCore
@testable import BASMemory

/// H9 (mega-audit, 2026-07-08): ShadowTrialCoordinator optimistic-concurrency + ledger
/// rollback gates. Pins the four defects the audit found so L13's evolution governance
/// can't silently regress to a fail-open, ledger/state-divergent state:
///
///   F1  submit: concurrent check-then-act across the `await ledger.append` → two trials
///       open for one candidate + a permanent double ledger record.
///   F2  advanceOpenTrial (observe/reportFail): concurrent observes read the same record,
///       last-write-wins → a recorded ledger effect is LOST from in-memory state.
///   F3  finalize: the trial terminal state is committed BEFORE the seal/retraction appends;
///       if one throws, the trial is finalized but the retraction (the safety mechanism for
///       failed/blocked) is permanently lost — a partial commit the class header denies.
///   F8  promotionVerdict: empty evidence (no trials) → allowsPromotion=true (fail-open).
final class BASShadowTrialConcurrencyTests: XCTestCase {

    private static let now = Date(timeIntervalSince1970: 1_730_500_000)

    private func makeCandidate(id: String = "cand.v1") -> BASExperienceCandidate {
        BASExperienceCandidate(
            candidateID: id, sourceRefs: ["s1"], candidateType: .bias,
            summary: "s", stabilitySignal: 0.8, contaminationRisk: 0.1,
            hostScope: "h", sovereignScope: "sov")
    }

    private func makeCoordinator(ledger: any BASShadowTrialLedger) -> BASShadowTrialCoordinator {
        let now = Self.now
        return BASShadowTrialCoordinator(ledger: ledger, clock: { now })
    }

    // MARK: - F1: concurrent submit opens exactly one trial

    func testConcurrentSubmitSameCandidateOpensExactlyOne() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coordinator = makeCoordinator(ledger: ledger)
        let candidate = makeCandidate()

        var opened = 0
        var rejected = 0
        await withTaskGroup(of: Bool.self) { group in
            for i in 0..<20 {
                group.addTask {
                    do {
                        _ = try await coordinator.submit(
                            candidate: candidate, sessionID: "s", turnID: "t-\(i)",
                            trialScope: "scope")
                        return true
                    } catch { return false }
                }
            }
            for await ok in group { if ok { opened += 1 } else { rejected += 1 } }
        }
        XCTAssertEqual(opened, 1, "exactly one concurrent submit may open a trial (got \(opened))")
        XCTAssertEqual(rejected, 19)
        // The ledger must have EXACTLY one shadow_trial_opened — no permanent double-record.
        let openedEntries = await ledger.all().filter { $0.eventKind == "shadow_trial_opened" }
        XCTAssertEqual(openedEntries.count, 1, "double ledger record on concurrent submit")
    }

    // MARK: - F2: concurrent observes lose no effect

    func testConcurrentObservesRecordEveryEffect() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coordinator = makeCoordinator(ledger: ledger)
        let candidate = makeCandidate()
        let trial = try await coordinator.submit(
            candidate: candidate, sessionID: "s", turnID: "t0", trialScope: "scope")

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    _ = try? await coordinator.observe(
                        trialID: trial.trialID, effect: "effect-\(i)", sessionID: "s", turnID: "t-\(i)")
                }
            }
        }
        let record = await coordinator.trial(for: trial.trialID)
        XCTAssertEqual(record?.observedEffects.count, 10,
            "every concurrent observe must persist its effect (got \(record?.observedEffects.count ?? -1))")
        // Ledger must have exactly 10 observe entries matching the 10 in-memory effects.
        let observeEntries = await ledger.all().filter { $0.eventKind == "shadow_trial_effect_observed" }
        XCTAssertEqual(observeEntries.count, 10, "ledger/state divergence on concurrent observe")
    }

    // MARK: - F3: finalize is atomic across the trial/seal/retraction appends

    func testFinalizePassedSealAppendFailureRollsBackAtomically() async throws {
        // Ledger fails on the seal append (2nd of the finalize sequence).
        let ledger = BASInMemoryShadowTrialLedger(failWhen: { entry in
            entry.eventKind == "evolution_seal_issued" ? "forced-seal-failure" : nil
        })
        let coordinator = makeCoordinator(ledger: ledger)
        let candidate = makeCandidate()
        let trial = try await coordinator.submit(
            candidate: candidate, sessionID: "s", turnID: "t0", trialScope: "scope")

        do {
            _ = try await coordinator.finalize(
                trialID: trial.trialID, outcome: .passed,
                promotionRecommendation: "promote", sessionID: "s", turnID: "t1")
            XCTFail("finalize should have thrown on seal append failure")
        } catch {}

        // Atomicity: the trial must NOT be finalized, and no seal committed.
        let record = await coordinator.trial(for: trial.trialID)
        XCTAssertTrue(record?.isPending ?? false,
            "trial must stay pending when the finalize sequence fails (was \(record?.completionState ?? "nil"))")
        let seal = await coordinator.seal(for: candidate.candidateID)
        XCTAssertNil(seal, "no seal may be committed when the finalize sequence fails")
    }

    func testFinalizeFailedRetractionAppendFailureRollsBackAtomically() async throws {
        // Failed outcome → a retraction is queued as the 3rd append. Fail it, and the
        // WHOLE finalize (incl. the trial terminal state + seal) must roll back — the
        // retraction (safety mechanism) must never be silently dropped while the trial
        // is left denied.
        let ledger = BASInMemoryShadowTrialLedger(failWhen: { entry in
            entry.eventKind == "retraction_order_queued" ? "forced-retraction-failure" : nil
        })
        let coordinator = makeCoordinator(ledger: ledger)
        let candidate = makeCandidate()
        let trial = try await coordinator.submit(
            candidate: candidate, sessionID: "s", turnID: "t0", trialScope: "scope")

        do {
            _ = try await coordinator.finalize(
                trialID: trial.trialID, outcome: .failed,
                promotionRecommendation: nil, sessionID: "s", turnID: "t1")
            XCTFail("finalize should have thrown on retraction append failure")
        } catch {}

        let record = await coordinator.trial(for: trial.trialID)
        XCTAssertTrue(record?.isPending ?? false,
            "trial must stay pending when the retraction append fails (was \(record?.completionState ?? "nil"))")
        let seal = await coordinator.seal(for: candidate.candidateID)
        XCTAssertNil(seal, "no seal may survive a rolled-back finalize")
        let retraction = await coordinator.retraction(for: candidate.candidateID)
        XCTAssertNil(retraction, "no retraction may be half-committed")
    }

    // MARK: - F8: promotion requires positive evidence (fail-closed)

    func testPromotionDeniedWithoutPositiveEvidence() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coordinator = makeCoordinator(ledger: ledger)
        // A candidate the coordinator has never seen: no trials, no seal.
        let verdict = await coordinator.promotionVerdict(for: "never-trialed")
        XCTAssertFalse(verdict.allowsPromotion,
            "a candidate with no trial evidence must NOT be promotable (fail-closed)")
    }

    func testPromotionAllowedWithPassedTrialAndSeal() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coordinator = makeCoordinator(ledger: ledger)
        let candidate = makeCandidate()
        let trial = try await coordinator.submit(
            candidate: candidate, sessionID: "s", turnID: "t0", trialScope: "scope")
        _ = try await coordinator.finalize(
            trialID: trial.trialID, outcome: .passed,
            promotionRecommendation: "promote", sessionID: "s", turnID: "t1")
        let verdict = await coordinator.promotionVerdict(for: candidate.candidateID)
        XCTAssertTrue(verdict.allowsPromotion,
            "a passed trial with an issued seal must be promotable (reasons: \(verdict.reasonCodes))")
    }
}
