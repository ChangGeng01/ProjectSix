import XCTest
@testable import BASMemory

/// M386 — pin the contract that an active
/// `BASForbiddenKnowledgeCandidate` filters
/// `BASEvolutionLifecycleAction` calls through a typed gate.
///
/// What this file pins:
///
///   1. nil candidate → action passes unchanged (default-safe).
///   2. `sovereignReviewState == .rejected` blocks every advance
///      action; terminal actions (.withdraw / .fail) still pass.
///   3. `sovereignReviewState == .held` blocks `.startShadowTrial`
///      only; other actions pass.
///   4. `shadowTrialPolicy == .none` blocks `.startShadowTrial`
///      regardless of sovereign state.
///   5. Permissive states + permissive policies pass every action
///      through unchanged.
///   6. Reason code format is stable
///      (`lifecycle.gated:forbidden:<reason>`).
final class M386ForbiddenLifecycleGateTests: XCTestCase {

    // MARK: - Fixture helpers

    private func candidate(
        reviewState: BASSovereignReviewState = .pending,
        policy: BASShadowTrialPolicy = .standard
    ) -> BASForbiddenKnowledgeCandidate {
        BASForbiddenKnowledgeCandidate(
            candidateID: "fk-test",
            sourceRefs: ["src-1"],
            riskReasons: ["test-risk"],
            contaminationRefs: [],
            coolingPeriod: 60,
            shadowTrialPolicy: policy,
            sovereignReviewState: reviewState)
    }

    // MARK: - 1. nil candidate — action passes through

    func testNilCandidateActionPassesThrough() {
        for action in BASEvolutionLifecycleAction.allCases {
            let decision = BASForbiddenLifecycleGate.gate(
                action: action,
                candidate: nil)
            XCTAssertFalse(decision.refused)
            XCTAssertEqual(decision.action, action)
            XCTAssertEqual(decision.reasonCodes, [])
        }
    }

    // MARK: - 2. Rejected sovereign — advance actions blocked

    func testRejectedSovereignBlocksAdvanceActions() {
        // Chapter 九十一 deep-review fix #2: `.retract` is no
        // longer in the blocked set — see
        // `testRejectedSovereignAllowsRetractTooFromPromoted`.
        let c = candidate(reviewState: .rejected)
        let blocked: [BASEvolutionLifecycleAction] = [
            .registerCandidate,
            .startShadowTrial,
            .finalizeTrial,
            .promote,
        ]
        for action in blocked {
            let decision = BASForbiddenLifecycleGate.gate(
                action: action,
                candidate: c)
            XCTAssertTrue(
                decision.refused,
                "rejected sovereign should refuse \(action)")
            XCTAssertNil(decision.action)
            XCTAssertEqual(decision.reasonCodes, [
                "lifecycle.gated:forbidden:sovereign-rejected"
            ])
        }
    }

    // MARK: - 3. Rejected sovereign — terminal actions still pass

    func testRejectedSovereignAllowsTerminalActions() {
        let c = candidate(reviewState: .rejected)
        // Chapter 九十一 deep-review fix #2: `.retract` joins
        // `.withdraw` and `.fail` as exit-bound terminal
        // actions. `.retract` is the only path out of
        // `.promoted` per
        // `BASEvolutionLifecyclePolicy.validTransitions(from:
        // .promoted) = [.retract: .retracted]`. Refusing it
        // would strand a `.promoted` candidate with no exit
        // when sovereign rejects retroactively.
        let terminal: [BASEvolutionLifecycleAction] = [
            .withdraw,
            .fail,
            .retract,
        ]
        for action in terminal {
            let decision = BASForbiddenLifecycleGate.gate(
                action: action,
                candidate: c)
            XCTAssertFalse(
                decision.refused,
                "rejected sovereign must allow terminal \(action)")
            XCTAssertEqual(decision.action, action)
            XCTAssertEqual(decision.reasonCodes, [
                "lifecycle.gated:forbidden:sovereign-rejected:terminal-action-allowed"
            ])
        }
    }

    // MARK: - 3b. Chapter 九十一 fix-pin — .retract specifically

    /// Pin the chapter 九十一 deep-review fix #2: `.retract`
    /// must be allowed when sovereign-rejected so a `.promoted`
    /// candidate can always reach `.retracted` (its only exit).
    /// Pre-fix this test would have failed (gate refused
    /// `.retract`).
    func testRejectedSovereignAllowsRetractAsTerminalExit() {
        let c = candidate(reviewState: .rejected)
        let decision = BASForbiddenLifecycleGate.gate(
            action: .retract,
            candidate: c)
        XCTAssertFalse(decision.refused)
        XCTAssertEqual(decision.action, .retract)
        XCTAssertEqual(decision.reasonCodes, [
            "lifecycle.gated:forbidden:sovereign-rejected:terminal-action-allowed"
        ])
    }

    // MARK: - 4. Held sovereign blocks startShadowTrial only

    func testHeldSovereignBlocksStartShadowTrialOnly() {
        let c = candidate(reviewState: .held)
        // startShadowTrial blocked.
        let blocked = BASForbiddenLifecycleGate.gate(
            action: .startShadowTrial,
            candidate: c)
        XCTAssertTrue(blocked.refused)
        XCTAssertNil(blocked.action)
        XCTAssertEqual(blocked.reasonCodes, [
            "lifecycle.gated:forbidden:sovereign-held:trial-start-refused"
        ])
        // Other actions pass.
        let allowed: [BASEvolutionLifecycleAction] = [
            .registerCandidate,
            .finalizeTrial,
            .promote,
            .retract,
            .fail,
            .withdraw,
        ]
        for action in allowed {
            let decision = BASForbiddenLifecycleGate.gate(
                action: action,
                candidate: c)
            XCTAssertFalse(decision.refused)
            XCTAssertEqual(decision.action, action)
        }
    }

    // MARK: - 5. policy == .none blocks startShadowTrial only

    func testPolicyNoneBlocksStartShadowTrialOnly() {
        let c = candidate(
            reviewState: .pending,
            policy: .none)
        let blocked = BASForbiddenLifecycleGate.gate(
            action: .startShadowTrial,
            candidate: c)
        XCTAssertTrue(blocked.refused)
        XCTAssertEqual(blocked.reasonCodes, [
            "lifecycle.gated:forbidden:shadow-trial-policy-none"
        ])
        // Other actions pass under .none policy.
        for action: BASEvolutionLifecycleAction in [
            .registerCandidate, .finalizeTrial, .promote,
            .retract, .fail, .withdraw,
        ] {
            let decision = BASForbiddenLifecycleGate.gate(
                action: action,
                candidate: c)
            XCTAssertFalse(decision.refused)
            XCTAssertEqual(decision.action, action)
        }
    }

    // MARK: - 6. Permissive review state + policy = pass-through

    func testPermissiveStatePassesAllActions() {
        let permissiveStates: [BASSovereignReviewState] = [
            .pending, .cleared, .notReferred,
        ]
        let permissivePolicies: [BASShadowTrialPolicy] = [
            .manualOnly, .restricted, .standard, .escalated,
        ]
        for state in permissiveStates {
            for policy in permissivePolicies {
                let c = candidate(
                    reviewState: state,
                    policy: policy)
                for action in BASEvolutionLifecycleAction.allCases {
                    let decision = BASForbiddenLifecycleGate.gate(
                        action: action,
                        candidate: c)
                    XCTAssertFalse(
                        decision.refused,
                        "permissive (\(state),\(policy)) should pass \(action)")
                    XCTAssertEqual(decision.action, action)
                    XCTAssertEqual(decision.reasonCodes, [])
                }
            }
        }
    }

    // MARK: - 7. Held sovereign + policy=.none ordering

    func testHeldSovereignAndPolicyNoneSovereignWins() {
        // Sovereign-held check happens first; policy=.none would
        // also have refused .startShadowTrial. The reason code
        // pins which one fired.
        let c = candidate(
            reviewState: .held,
            policy: .none)
        let decision = BASForbiddenLifecycleGate.gate(
            action: .startShadowTrial,
            candidate: c)
        XCTAssertTrue(decision.refused)
        XCTAssertEqual(decision.reasonCodes, [
            "lifecycle.gated:forbidden:sovereign-held:trial-start-refused"
        ])
    }
}
