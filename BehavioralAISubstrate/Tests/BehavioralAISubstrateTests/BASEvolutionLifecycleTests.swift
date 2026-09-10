import XCTest
@testable import BASMemory

/// 五十六 — full-body L13 evolution lifecycle tests.
///
/// Doctrine pinned:
/// - 8 stages / 7 actions
/// - `proposed` is initial; `retracted / rejected / withdrawn`
///   terminal; `.promoted` non-terminal (retraction reachable)
/// - State machine: only valid transitions accepted; invalid
///   returns nil
/// - History accumulates monotonically
/// - `hasReachedPromotion` true iff stage ∈ {promoted, retracted}
/// - End-to-end happy path: proposed → candidateRegistered →
///   shadowTrialing → trialFinalized → promoted (→ retracted)
/// - Withdraw reachable from any pre-promotion active stage
/// - Codable round-trip
final class BASEvolutionLifecycleTests: XCTestCase {

    // MARK: - Cardinality

    func test_eightStages() {
        XCTAssertEqual(
            BASEvolutionLifecycleStage.allCases.count, 8)
    }

    func test_sevenActions() {
        XCTAssertEqual(
            BASEvolutionLifecycleAction.allCases.count, 7)
    }

    // MARK: - Stage classification

    func test_terminalStagesAreRetractedRejectedWithdrawn() {
        XCTAssertTrue(
            BASEvolutionLifecycleStage.retracted.isTerminal)
        XCTAssertTrue(
            BASEvolutionLifecycleStage.rejected.isTerminal)
        XCTAssertTrue(
            BASEvolutionLifecycleStage.withdrawn.isTerminal)
    }

    func test_promotedIsNotTerminal_retractionReachable() {
        XCTAssertFalse(
            BASEvolutionLifecycleStage.promoted.isTerminal,
            ".promoted must be non-terminal — retraction is " +
            "a real path from there")
    }

    func test_activeStagesAreNotTerminal() {
        for stage: BASEvolutionLifecycleStage in [
            .proposed,
            .candidateRegistered,
            .shadowTrialing,
            .trialFinalized,
            .promoted,
        ] {
            XCTAssertFalse(stage.isTerminal)
        }
    }

    func test_hasReachedPromotionOnlyForPromotedAndRetracted() {
        XCTAssertTrue(
            BASEvolutionLifecycleStage.promoted
                .hasReachedPromotion)
        XCTAssertTrue(
            BASEvolutionLifecycleStage.retracted
                .hasReachedPromotion)
        for stage: BASEvolutionLifecycleStage in [
            .proposed,
            .candidateRegistered,
            .shadowTrialing,
            .trialFinalized,
            .rejected,
            .withdrawn,
        ] {
            XCTAssertFalse(
                stage.hasReachedPromotion,
                "stage \(stage.rawValue) must NOT report " +
                "promotion reached")
        }
    }

    // MARK: - Policy: valid transitions matrix

    func test_proposedAllowsRegisterAndWithdraw() {
        let valid = BASEvolutionLifecyclePolicy
            .validTransitions(from: .proposed)
        XCTAssertEqual(valid.count, 2)
        XCTAssertEqual(
            valid[.registerCandidate], .candidateRegistered)
        XCTAssertEqual(valid[.withdraw], .withdrawn)
    }

    func test_candidateRegisteredAllowsStartTrialAndWithdraw() {
        let valid = BASEvolutionLifecyclePolicy
            .validTransitions(from: .candidateRegistered)
        XCTAssertEqual(valid.count, 2)
        XCTAssertEqual(
            valid[.startShadowTrial], .shadowTrialing)
        XCTAssertEqual(valid[.withdraw], .withdrawn)
    }

    func test_shadowTrialingAllowsFinalizeFailWithdraw() {
        let valid = BASEvolutionLifecyclePolicy
            .validTransitions(from: .shadowTrialing)
        XCTAssertEqual(valid.count, 3)
        XCTAssertEqual(
            valid[.finalizeTrial], .trialFinalized)
        XCTAssertEqual(valid[.fail], .rejected)
        XCTAssertEqual(valid[.withdraw], .withdrawn)
    }

    func test_trialFinalizedAllowsPromoteFailWithdraw() {
        let valid = BASEvolutionLifecyclePolicy
            .validTransitions(from: .trialFinalized)
        XCTAssertEqual(valid.count, 3)
        XCTAssertEqual(valid[.promote], .promoted)
        XCTAssertEqual(valid[.fail], .rejected)
        XCTAssertEqual(valid[.withdraw], .withdrawn)
    }

    func test_promotedAllowsOnlyRetract() {
        let valid = BASEvolutionLifecyclePolicy
            .validTransitions(from: .promoted)
        XCTAssertEqual(valid.count, 1)
        XCTAssertEqual(valid[.retract], .retracted)
        // No withdraw from promoted — once promoted, change
        // must go through retraction.
        XCTAssertNil(valid[.withdraw])
    }

    func test_terminalStagesReturnEmptyTransitions() {
        XCTAssertTrue(
            BASEvolutionLifecyclePolicy.validTransitions(
                from: .retracted
            ).isEmpty)
        XCTAssertTrue(
            BASEvolutionLifecyclePolicy.validTransitions(
                from: .rejected
            ).isEmpty)
        XCTAssertTrue(
            BASEvolutionLifecyclePolicy.validTransitions(
                from: .withdrawn
            ).isEmpty)
    }

    // MARK: - Apply policy

    func test_applyValidActionReturnsTransition() {
        let t = BASEvolutionLifecyclePolicy.apply(
            .registerCandidate, from: .proposed)
        XCTAssertEqual(t?.from, .proposed)
        XCTAssertEqual(t?.to, .candidateRegistered)
        XCTAssertEqual(t?.action, .registerCandidate)
    }

    func test_applyInvalidActionReturnsNil() {
        // Cannot promote directly from .proposed.
        XCTAssertNil(
            BASEvolutionLifecyclePolicy.apply(
                .promote, from: .proposed))
        // Cannot register candidate from terminal.
        XCTAssertNil(
            BASEvolutionLifecyclePolicy.apply(
                .registerCandidate, from: .rejected))
    }

    // MARK: - Session: end-to-end happy path

    func test_endToEndHappyPathToPromotion() throws {
        var s = BASEvolutionLifecycleSession(
            candidateID: "cand-001")
        XCTAssertEqual(s.currentStage, .proposed)
        XCTAssertEqual(s.history.count, 0)

        s = try XCTUnwrap(s.applying(.registerCandidate))
        XCTAssertEqual(s.currentStage, .candidateRegistered)

        s = try XCTUnwrap(s.applying(.startShadowTrial))
        XCTAssertEqual(s.currentStage, .shadowTrialing)

        s = try XCTUnwrap(s.applying(.finalizeTrial))
        XCTAssertEqual(s.currentStage, .trialFinalized)

        s = try XCTUnwrap(s.applying(.promote))
        XCTAssertEqual(s.currentStage, .promoted)
        XCTAssertTrue(s.hasReachedPromotion)
        XCTAssertFalse(s.isTerminal)

        XCTAssertEqual(s.history.count, 4)
    }

    func test_endToEndHappyPathThenRetract() throws {
        var s = BASEvolutionLifecycleSession(
            candidateID: "cand-002")
        for action: BASEvolutionLifecycleAction in [
            .registerCandidate,
            .startShadowTrial,
            .finalizeTrial,
            .promote,
            .retract,
        ] {
            s = try XCTUnwrap(s.applying(action))
        }
        XCTAssertEqual(s.currentStage, .retracted)
        XCTAssertTrue(s.hasReachedPromotion)
        XCTAssertTrue(s.isTerminal)
        XCTAssertEqual(s.history.count, 5)
        XCTAssertEqual(
            s.history.last?.action, .retract)
    }

    // MARK: - Failure paths

    func test_failFromShadowTrialingReachesRejected() throws {
        var s = BASEvolutionLifecycleSession(
            candidateID: "cand-003")
        s = try XCTUnwrap(s.applying(.registerCandidate))
        s = try XCTUnwrap(s.applying(.startShadowTrial))
        s = try XCTUnwrap(s.applying(.fail))
        XCTAssertEqual(s.currentStage, .rejected)
        XCTAssertTrue(s.isTerminal)
        XCTAssertFalse(s.hasReachedPromotion)
    }

    func test_failFromTrialFinalizedReachesRejected() throws {
        var s = BASEvolutionLifecycleSession(
            candidateID: "cand-004")
        s = try XCTUnwrap(s.applying(.registerCandidate))
        s = try XCTUnwrap(s.applying(.startShadowTrial))
        s = try XCTUnwrap(s.applying(.finalizeTrial))
        s = try XCTUnwrap(s.applying(.fail))
        XCTAssertEqual(s.currentStage, .rejected)
    }

    func test_withdrawFromAnyPrePromotionStageWorks() throws {
        for startActions in [
            [BASEvolutionLifecycleAction](),
            [.registerCandidate],
            [.registerCandidate, .startShadowTrial],
            [
                .registerCandidate,
                .startShadowTrial,
                .finalizeTrial,
            ],
        ] {
            var s = BASEvolutionLifecycleSession(
                candidateID: "cand-w")
            for action in startActions {
                s = try XCTUnwrap(s.applying(action))
            }
            XCTAssertFalse(s.isTerminal)
            s = try XCTUnwrap(
                s.applying(.withdraw),
                "withdraw must work from \(s.currentStage)")
            XCTAssertEqual(s.currentStage, .withdrawn)
            XCTAssertTrue(s.isTerminal)
        }
    }

    func test_withdrawNotAllowedFromPromoted() throws {
        var s = BASEvolutionLifecycleSession(
            candidateID: "cand-p")
        for action: BASEvolutionLifecycleAction in [
            .registerCandidate,
            .startShadowTrial,
            .finalizeTrial,
            .promote,
        ] {
            s = try XCTUnwrap(s.applying(action))
        }
        XCTAssertEqual(s.currentStage, .promoted)
        // Withdraw from .promoted is invalid — change requires
        // explicit retraction.
        XCTAssertNil(s.applying(.withdraw))
    }

    // MARK: - Invalid transitions

    func test_invalidActionsReturnNilWithoutMutation() {
        let s = BASEvolutionLifecycleSession(
            candidateID: "cand-x")
        // Promote without trial.
        XCTAssertNil(s.applying(.promote))
        // Retract without promotion.
        XCTAssertNil(s.applying(.retract))
        // Finalize without starting trial.
        XCTAssertNil(s.applying(.finalizeTrial))
        // Original session unchanged (immutable).
        XCTAssertEqual(s.currentStage, .proposed)
        XCTAssertEqual(s.history.count, 0)
    }

    func test_terminalStageRejectsAllActions() throws {
        var s = BASEvolutionLifecycleSession(
            candidateID: "cand-t")
        s = try XCTUnwrap(s.applying(.registerCandidate))
        s = try XCTUnwrap(s.applying(.startShadowTrial))
        s = try XCTUnwrap(s.applying(.fail))
        XCTAssertEqual(s.currentStage, .rejected)
        for action in BASEvolutionLifecycleAction.allCases {
            XCTAssertNil(
                s.applying(action),
                "terminal stage must reject \(action)")
        }
    }

    // MARK: - History monotonicity

    func test_historyAccumulatesMonotonically() throws {
        var s = BASEvolutionLifecycleSession(
            candidateID: "cand-h")
        s = try XCTUnwrap(s.applying(.registerCandidate))
        s = try XCTUnwrap(s.applying(.startShadowTrial))
        s = try XCTUnwrap(s.applying(.finalizeTrial))
        XCTAssertEqual(s.history.count, 3)
        XCTAssertEqual(
            s.history.map(\.action), [
                .registerCandidate,
                .startShadowTrial,
                .finalizeTrial,
            ])
        XCTAssertEqual(
            s.history.map(\.from), [
                .proposed,
                .candidateRegistered,
                .shadowTrialing,
            ])
        XCTAssertEqual(
            s.history.map(\.to), [
                .candidateRegistered,
                .shadowTrialing,
                .trialFinalized,
            ])
    }

    // MARK: - stagesVisited

    func test_stagesVisitedIncludesProposedAndAllAdvances()
        throws
    {
        var s = BASEvolutionLifecycleSession(
            candidateID: "cand-v")
        for action: BASEvolutionLifecycleAction in [
            .registerCandidate,
            .startShadowTrial,
            .finalizeTrial,
            .promote,
            .retract,
        ] {
            s = try XCTUnwrap(s.applying(action))
        }
        XCTAssertEqual(s.stagesVisited, [
            .proposed,
            .candidateRegistered,
            .shadowTrialing,
            .trialFinalized,
            .promoted,
            .retracted,
        ])
    }

    // MARK: - Codable round-trip

    func test_sessionCodableRoundTrip() throws {
        var s = BASEvolutionLifecycleSession(
            candidateID: "cand-codable")
        s = try XCTUnwrap(s.applying(.registerCandidate))
        s = try XCTUnwrap(s.applying(.startShadowTrial))
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(
            BASEvolutionLifecycleSession.self, from: data)
        XCTAssertEqual(decoded, s)
    }

    func test_stageCodableRoundTrip() throws {
        for stage in BASEvolutionLifecycleStage.allCases {
            let data = try JSONEncoder().encode(stage)
            let decoded = try JSONDecoder().decode(
                BASEvolutionLifecycleStage.self, from: data)
            XCTAssertEqual(decoded, stage)
        }
    }

    func test_actionCodableRoundTrip() throws {
        for action in BASEvolutionLifecycleAction.allCases {
            let data = try JSONEncoder().encode(action)
            let decoded = try JSONDecoder().decode(
                BASEvolutionLifecycleAction.self, from: data)
            XCTAssertEqual(decoded, action)
        }
    }

    // MARK: - Raw value stability

    func test_stageRawValuesPinned() {
        XCTAssertEqual(
            BASEvolutionLifecycleStage.proposed.rawValue,
            "proposed")
        XCTAssertEqual(
            BASEvolutionLifecycleStage
                .candidateRegistered.rawValue,
            "candidateRegistered")
        XCTAssertEqual(
            BASEvolutionLifecycleStage.shadowTrialing.rawValue,
            "shadowTrialing")
        XCTAssertEqual(
            BASEvolutionLifecycleStage.trialFinalized.rawValue,
            "trialFinalized")
        XCTAssertEqual(
            BASEvolutionLifecycleStage.promoted.rawValue,
            "promoted")
        XCTAssertEqual(
            BASEvolutionLifecycleStage.retracted.rawValue,
            "retracted")
        XCTAssertEqual(
            BASEvolutionLifecycleStage.rejected.rawValue,
            "rejected")
        XCTAssertEqual(
            BASEvolutionLifecycleStage.withdrawn.rawValue,
            "withdrawn")
    }

    func test_actionRawValuesPinned() {
        XCTAssertEqual(
            BASEvolutionLifecycleAction
                .registerCandidate.rawValue,
            "registerCandidate")
        XCTAssertEqual(
            BASEvolutionLifecycleAction
                .startShadowTrial.rawValue,
            "startShadowTrial")
        XCTAssertEqual(
            BASEvolutionLifecycleAction
                .finalizeTrial.rawValue,
            "finalizeTrial")
        XCTAssertEqual(
            BASEvolutionLifecycleAction.promote.rawValue,
            "promote")
        XCTAssertEqual(
            BASEvolutionLifecycleAction.retract.rawValue,
            "retract")
        XCTAssertEqual(
            BASEvolutionLifecycleAction.fail.rawValue, "fail")
        XCTAssertEqual(
            BASEvolutionLifecycleAction.withdraw.rawValue,
            "withdraw")
    }
}
