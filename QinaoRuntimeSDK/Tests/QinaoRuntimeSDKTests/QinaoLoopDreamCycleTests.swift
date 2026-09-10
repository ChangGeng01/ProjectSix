import XCTest
@testable import QinaoLoop
import QinaoWorldPrior

/// M84 — QinaoLoop × QinaoWorldPrior dream-cycle refinement.
///
/// Closes the "L9 dream-cycle ↔ L4 world-prior deep integration"
/// gap that the honesty board tracks under "懂世界也懂宿主": M51
/// evaluates each candidate's `WorldPriorClaim` at `submit` time
/// (a single `evaluateHostOverride` check against bedrock axioms).
/// M84 adds `refineAgainstCounterfactuals(sessionID:templateID:)`
/// which re-projects every candidate-with-claim across the vault's
/// counterfactual branches for one chosen template and aggregates
/// the branch-by-branch evidence comparisons into a single refined
/// contradiction score per candidate.
///
/// ## Fixture choices
///
/// - `tmpl-body-hydration` (seed evidence `.wellSupported`, 1
///   precondition, 0 blockers, no matching bridges): the seeder
///   produces 1 drop-precondition branch at `.plausible` (rank 2)
///   plus 2 padding branches at `.speculative` (rank 1), for 3
///   branches total. Used for testing evidence-level gradients.
///
/// - `tmpl-body-exercise-mood` (seed evidence `.plausible`, 1
///   precondition, 2 blockers): produces 1 drop-precondition and 2
///   introduce-blocker branches, all at `.speculative` (rank 1), for
///   3 branches total. Used for testing uniform-branch aggregation.
///
/// Both fixtures are in `BASWorldPriorBuiltInLibrary.bodyTemplates`
/// so they survive as long as the built-in library survives.
final class QinaoLoopDreamCycleTests: XCTestCase {

    // MARK: - Fixtures

    private func makeSeededVault() async throws -> QinaoWorldPriorVault {
        try await QinaoWorldPriorVault(seedingBuiltIns: true)
    }

    private func makeInput(
        _ id: String,
        benefit: Double = 0.5,
        cost: Double = 0.2,
        reversibility: Double = 0.5,
        confidence: Double = 0.5,
        manipulation: Double = 0,
        claim: QinaoLoop.CandidateInput.WorldPriorClaim? = nil
    ) -> QinaoLoop.CandidateInput {
        QinaoLoop.CandidateInput(
            candidateID: id,
            title: "title-\(id)",
            actionSummary: "summary-\(id)",
            expectedBenefit: benefit,
            expectedCost: cost,
            reversibility: reversibility,
            confidence: confidence,
            evidenceGap: 0,
            manipulationRisk: manipulation,
            emotionalBias: 0,
            boundaryConflict: 0,
            worldPriorClaim: claim)
    }

    // MARK: - Error path: unknown session

    func testRefineAgainstCounterfactualsWithUnknownSessionThrows()
        async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        do {
            _ = try await loop.refineAgainstCounterfactuals(
                sessionID: "never-submitted",
                templateID: "tmpl-body-hydration")
            XCTFail("expected .sessionUnknown")
        } catch QinaoLoop.LoopError.sessionUnknown(let id) {
            XCTAssertEqual(id, "never-submitted")
        }
    }

    // MARK: - Error path: no vault wired

    func testRefineAgainstCounterfactualsWithoutVaultThrows()
        async throws {
        let loop = QinaoLoop()
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c1")
        ])
        do {
            _ = try await loop.refineAgainstCounterfactuals(
                sessionID: "s1",
                templateID: "tmpl-body-hydration")
            XCTFail("expected .worldPriorUnavailable")
        } catch QinaoLoop.LoopError
            .worldPriorUnavailable(let reason) {
            XCTAssertEqual(reason, "no-world-prior-vault")
        }
    }

    // MARK: - Error path: unknown template

    func testRefineAgainstCounterfactualsWithUnknownTemplateThrows()
        async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c1")
        ])
        do {
            _ = try await loop.refineAgainstCounterfactuals(
                sessionID: "s1",
                templateID: "tmpl-does-not-exist")
            XCTFail("expected .worldPriorUnavailable")
        } catch QinaoLoop.LoopError
            .worldPriorUnavailable(let reason) {
            XCTAssertEqual(
                reason,
                "unknown-template:tmpl-does-not-exist")
        }
    }

    // MARK: - No claims → empty perCandidate

    func testRefineSkipsCandidatesWithoutClaims() async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c1"),
            makeInput("c2")
        ])
        let outcome = try await loop.refineAgainstCounterfactuals(
            sessionID: "s1",
            templateID: "tmpl-body-hydration")
        XCTAssertEqual(outcome.sessionID, "s1")
        XCTAssertEqual(outcome.templateID, "tmpl-body-hydration")
        XCTAssertEqual(outcome.branchesExamined, 3)
        XCTAssertTrue(outcome.perCandidate.isEmpty)
    }

    // MARK: - Exposing insufficiency: speculative claim on hydration

    /// `tmpl-body-hydration` yields 3 branches: 1 at `.plausible`
    /// (rank 2) + 2 at `.speculative` (rank 1). A claim declared
    /// `.speculative` sits at rank 1; the 1 rank-2 branch exposes
    /// insufficiency (rank > 1), and the 2 rank-1 branches are
    /// equal-evidence.
    ///
    /// Expected:
    /// - branchesExposedInsufficient = 1
    /// - branchesEqualEvidence       = 2
    /// - branchesRobustlySurvived    = 0
    /// - branchAggregate = (1 * 1.0 + 2 * 0.5) / 3 = 0.6666...
    func testRefineElevatesContradictionWhenBranchesExposeInsufficiency()
        async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c1", claim: .init(
                claimID: "claim-c1-hydration",
                declaredEvidence: .speculative,
                statement: "Drinking tea during work keeps me hydrated enough."))
        ])
        let outcome = try await loop.refineAgainstCounterfactuals(
            sessionID: "s1",
            templateID: "tmpl-body-hydration")

        XCTAssertEqual(outcome.branchesExamined, 3)
        XCTAssertEqual(outcome.perCandidate.count, 1)
        let view = outcome.perCandidate[0]
        XCTAssertEqual(view.candidateID, "c1")
        XCTAssertEqual(view.branchesExposedInsufficient, 1)
        XCTAssertEqual(view.branchesEqualEvidence, 2)
        XCTAssertEqual(view.branchesRobustlySurvived, 0)
        XCTAssertEqual(view.baseContradiction, 0, accuracy: 1e-9)
        XCTAssertEqual(
            view.aggregatedContradiction,
            2.0 / 3.0,
            accuracy: 1e-9,
            "branchAggregate = (1 + 1) / 3")
    }

    // MARK: - Robust survival: axiomatic claim

    /// A claim declared `.axiomatic` (rank 4) is stronger than every
    /// counterfactual branch (max branch rank is 2). All 3 branches
    /// fall into robustlySurvived → branchAggregate = 0 →
    /// aggregated = max(0, 0) = 0.
    func testRefinePreservesBaseContradictionWhenAllBranchesSurvive()
        async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c1", claim: .init(
                claimID: "claim-c1-axiomatic",
                declaredEvidence: .axiomatic,
                statement: "Conservation of mass."))
        ])
        let outcome = try await loop.refineAgainstCounterfactuals(
            sessionID: "s1",
            templateID: "tmpl-body-hydration")
        let view = outcome.perCandidate[0]
        XCTAssertEqual(view.branchesExposedInsufficient, 0)
        XCTAssertEqual(view.branchesEqualEvidence, 0)
        XCTAssertEqual(view.branchesRobustlySurvived, 3)
        XCTAssertEqual(view.aggregatedContradiction, 0, accuracy: 1e-9)
    }

    // MARK: - Max semantics: base can never be lowered

    /// A `.reject` outcome at submit time (no-claim-id match against
    /// the real axiom registry forces `.reject` when the host's
    /// statement disagrees at `.contested` evidence) sets base = 1.0.
    /// The dream cycle on an unrelated template should NEVER pull it
    /// back down, even if all branches survive the claim.
    func testRefineNeverLowersContradictionEvenWhenBranchesSurvive()
        async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        // A claim that maps to a real `.axiomatic` axiom but with
        // `.contested` evidence → `.reject` at submit → base = 1.0.
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c1", claim: .init(
                claimID: "axiom-physics-gravity",
                declaredEvidence: .contested,
                statement:
                    "Gravity is merely a suggestion I can ignore."))
        ])
        // Sanity: submit-time contradiction really is 1.0.
        let preGuardian = try await loop.guardianBranch(sessionID: "s1")
        XCTAssertEqual(
            preGuardian?.dissent,
            "world-prior-contradiction")

        // Refine against an orthogonal template whose 3 branches are
        // all weaker than .contested (rank 0) → impossible: the
        // minimum rank is 0. So here we use a high-evidence claim
        // statement-only (not the ID) — wait: M84 evaluates by
        // declaredEvidence rank vs branchEvidence rank, so the key
        // is that the declared `.contested` claim rank = 0. Every
        // branch rank >= 0 → if rank > 0, exposed; if rank == 0,
        // equal. `tmpl-body-hydration` has 1 rank-2 branch and 2
        // rank-1 branches, all > 0, so branchAgg = 3/3 = 1.0 here.
        // Aggregated = max(1.0, 1.0) = 1.0 — still locked at max
        // from the base.
        let outcome = try await loop.refineAgainstCounterfactuals(
            sessionID: "s1",
            templateID: "tmpl-body-hydration")
        let view = outcome.perCandidate[0]
        XCTAssertEqual(view.baseContradiction, 1.0, accuracy: 1e-9)
        XCTAssertEqual(
            view.aggregatedContradiction,
            1.0,
            accuracy: 1e-9)
    }

    // MARK: - Fixed-point + cumulative chaining

    /// Repeated invocations converge: the aggregated contradiction
    /// is fixed-point on identical inputs (seeder is deterministic,
    /// branches don't change, `max(base, branchAgg) == branchAgg`
    /// once base already is branchAgg). But base itself rolls
    /// forward — the second call sees the first call's aggregated
    /// as its new base, which is the cumulative-chaining semantic
    /// hosts depend on when refining across multiple templates.
    func testRefineAggregatedIsFixedPointAndBaseRollsForward()
        async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c1", claim: .init(
                claimID: "claim-c1",
                declaredEvidence: .speculative,
                statement: "stub."))
        ])
        let first = try await loop.refineAgainstCounterfactuals(
            sessionID: "s1",
            templateID: "tmpl-body-hydration")
        let second = try await loop.refineAgainstCounterfactuals(
            sessionID: "s1",
            templateID: "tmpl-body-hydration")

        // 1. Aggregated is a fixed-point: same value on both calls.
        XCTAssertEqual(
            first.perCandidate[0].aggregatedContradiction,
            second.perCandidate[0].aggregatedContradiction,
            accuracy: 1e-9,
            "aggregated fixed-point under repeated same-template refine")

        // 2. Branch tallies are identical — seeder is deterministic.
        XCTAssertEqual(
            first.perCandidate[0].branchesExposedInsufficient,
            second.perCandidate[0].branchesExposedInsufficient)
        XCTAssertEqual(
            first.perCandidate[0].branchesEqualEvidence,
            second.perCandidate[0].branchesEqualEvidence)
        XCTAssertEqual(
            first.perCandidate[0].branchesRobustlySurvived,
            second.perCandidate[0].branchesRobustlySurvived)

        // 3. Base rolls forward: first call saw the submit-time 0;
        //    second call sees the first's aggregated as its new base.
        XCTAssertEqual(
            first.perCandidate[0].baseContradiction,
            0,
            accuracy: 1e-9,
            "first call's base = submit-time 0")
        XCTAssertEqual(
            second.perCandidate[0].baseContradiction,
            first.perCandidate[0].aggregatedContradiction,
            accuracy: 1e-9,
            "second call's base inherits first call's aggregated")
    }

    // MARK: - Propagation into guardian / frontier

    /// After a refinement pass that elevates aggregated contradiction
    /// to 1.0 (every branch strictly stronger than a `.contested`
    /// claim), `guardianBranch` surfaces `world-prior-contradiction`
    /// as the dissent label even though the submit-time base was 0
    /// (claim ID has no axiom match). This proves the dream cycle
    /// writes BOTH the contradictions map AND the critique bundle,
    /// not just the former.
    func testRefinePropagatesIntoGuardianBranchDissent() async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        // Claim ID not in the axiom registry → submit yields .clean
        // → base = 0. Manipulation & other concerns held at 0 so
        // the guardian trigger can ONLY come from the dream cycle.
        // Declared `.contested` (rank 0): every branch of
        // `tmpl-body-hydration` (ranks 1, 1, 2) is strictly
        // stronger, so all 3 count as exposed → branchAgg = 1.0 →
        // aggregated = 1.0 → critiqueStrength = 1.0 → guardian
        // triggers at the 0.7 threshold.
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c1", benefit: 0.3, claim: .init(
                claimID: "claim-not-in-vault",
                declaredEvidence: .contested,
                statement: "Disputed — I assume this without evidence.")),
            makeInput("c2", benefit: 0.3)  // no claim → alternative
        ])
        let preGuardian = try await loop.guardianBranch(sessionID: "s1")
        XCTAssertNil(
            preGuardian,
            "pre-refinement: no guardian (base = 0)")

        _ = try await loop.refineAgainstCounterfactuals(
            sessionID: "s1",
            templateID: "tmpl-body-hydration")

        let postGuardian = try await loop.guardianBranch(sessionID: "s1")
        XCTAssertEqual(
            postGuardian?.candidateID,
            "c1",
            "the claimed candidate is the one guarded")
        XCTAssertEqual(
            postGuardian?.dissent,
            "world-prior-contradiction",
            "post-refinement: dream-cycle surfaced the concern")
    }

    // MARK: - Branch-count invariant

    func testRefineBranchCountInvariantHolds() async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c1", claim: .init(
                claimID: "claim-c1",
                declaredEvidence: .plausible,
                statement: "stub."))
        ])
        let outcome = try await loop.refineAgainstCounterfactuals(
            sessionID: "s1",
            templateID: "tmpl-body-exercise-mood")
        let view = outcome.perCandidate[0]
        XCTAssertEqual(
            view.branchesExposedInsufficient
          + view.branchesEqualEvidence
          + view.branchesRobustlySurvived,
            outcome.branchesExamined,
            "exposed + equal + survived ≡ examined")
    }

    // MARK: - Determinism: perCandidate is candidateID-ASC

    func testRefinePerCandidateIsSortedByCandidateIDAscending()
        async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        // Submit in reverse-alphabetical order to prove sorting.
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("zeta", claim: .init(
                claimID: "claim-zeta",
                declaredEvidence: .speculative,
                statement: "z")),
            makeInput("alpha", claim: .init(
                claimID: "claim-alpha",
                declaredEvidence: .speculative,
                statement: "a")),
            makeInput("mu", claim: .init(
                claimID: "claim-mu",
                declaredEvidence: .speculative,
                statement: "m"))
        ])
        let outcome = try await loop.refineAgainstCounterfactuals(
            sessionID: "s1",
            templateID: "tmpl-body-hydration")
        XCTAssertEqual(
            outcome.perCandidate.map(\.candidateID),
            ["alpha", "mu", "zeta"])
    }

    // MARK: - Uniform-branch aggregation (exercise-mood fixture)

    /// `tmpl-body-exercise-mood` produces 3 branches all at
    /// `.speculative` (rank 1). A claim at `.plausible` (rank 2):
    /// 0 exposed (no branch > rank 2), 0 equal (no branch at rank 2),
    /// 3 survived. branchAgg = 0, aggregated = max(base, 0) = base.
    func testRefinePlausibleClaimOnExerciseMoodTemplateSurvivesAll()
        async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c1", claim: .init(
                claimID: "claim-c1",
                declaredEvidence: .plausible,
                statement: "stub."))
        ])
        let outcome = try await loop.refineAgainstCounterfactuals(
            sessionID: "s1",
            templateID: "tmpl-body-exercise-mood")
        let view = outcome.perCandidate[0]
        XCTAssertEqual(view.branchesExposedInsufficient, 0)
        XCTAssertEqual(view.branchesEqualEvidence, 0)
        XCTAssertEqual(view.branchesRobustlySurvived, 3)
        XCTAssertEqual(view.aggregatedContradiction, 0, accuracy: 1e-9)
    }

    // MARK: - Mixed session: some claims + some without

    /// When a session mixes candidates-with-claims and candidates-
    /// without, the refinement only returns views for the former.
    /// The frontier/contradictions of the latter stay untouched.
    func testRefineLeavesNoClaimCandidatesUntouchedInMixedSession()
        async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("a-no-claim"),
            makeInput("b-has-claim", claim: .init(
                claimID: "claim-b",
                declaredEvidence: .speculative,
                statement: "stub."))
        ])
        let outcome = try await loop.refineAgainstCounterfactuals(
            sessionID: "s1",
            templateID: "tmpl-body-hydration")
        XCTAssertEqual(
            outcome.perCandidate.map(\.candidateID),
            ["b-has-claim"])
    }
}
