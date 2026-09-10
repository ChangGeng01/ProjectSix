import XCTest
@testable import QinaoLoop
import QinaoWorldPrior

/// M51 — QinaoLoop × QinaoWorldPrior integration.
///
/// Proves the L4↔L9 loop called out on the honesty board's "会想不自转"
/// row:
///
///     host-declared claim on a candidate
///         ↓  QinaoWorldPriorVault.evaluateHostOverride
///     .clean / .demote / .reject
///         ↓  contradictionScore (0.0 / 0.5 / 1.0)
///     BASCritiqueBundle.critiqueStrength += 0.75 * contradiction
///         ↓
///     guardianBranch.dissent == "world-prior-contradiction"
///         when contradiction ≥ 0.5
///
/// The tests pin the three outcomes against the built-in library's
/// real axiom IDs so we catch any future drift in the seeded content.
final class QinaoLoopWorldPriorTests: XCTestCase {

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

    // MARK: - Backwards compatibility

    /// A loop *without* a vault must behave exactly like pre-M51:
    /// candidates with a claim are scored on host-supplied numerics
    /// only, because there is no vault to check against. This is the
    /// "opt-in" guarantee in the docstring.
    func testLoopWithoutVaultIgnoresClaims() async throws {
        let loop = QinaoLoop()
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c1",
                      benefit: 0.8,
                      claim: .init(
                        claimID: "axiom-physics-gravity",
                        declaredEvidence: .speculative,
                        statement: "Things float upward if I wish them to."))
        ])
        let guardian = try await loop.guardianBranch(sessionID: "s1")
        XCTAssertNil(
            guardian,
            "no vault ⇒ no contradiction ⇒ no guardian")
    }

    // MARK: - Clean outcome — no effect

    /// A candidate with no claim, on a loop with a wired vault,
    /// is scored as if the world-prior path didn't exist.
    func testNoClaimYieldsCleanAndIsTransparent() async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c1", benefit: 0.8)
        ])
        let guardian = try await loop.guardianBranch(sessionID: "s1")
        XCTAssertNil(
            guardian,
            "no claim ⇒ clean ⇒ no guardian")
    }

    /// Unknown claimID hits the "no axiom → clean" fast path, so
    /// it costs the candidate nothing even when the wire is live.
    func testUnknownClaimIDIsTreatedAsClean() async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c1",
                      benefit: 0.8,
                      claim: .init(
                        claimID: "axiom-that-does-not-exist",
                        declaredEvidence: .speculative,
                        statement: "Anything"))
        ])
        let guardian = try await loop.guardianBranch(sessionID: "s1")
        XCTAssertNil(guardian, "unknown axiom ⇒ clean")
    }

    /// Byte-identical statement to the seeded axiom is clean,
    /// regardless of declared evidence — the axiom "agrees" with
    /// the claim.
    func testByteIdenticalStatementIsClean() async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c1",
                      benefit: 0.8,
                      claim: .init(
                        claimID: "axiom-body-sleep-required",
                        declaredEvidence: .speculative,
                        statement: "Humans require periodic sleep to maintain baseline cognitive function."))
        ])
        let guardian = try await loop.guardianBranch(sessionID: "s1")
        XCTAssertNil(guardian, "matching statement ⇒ clean")
    }

    // MARK: - Reject outcome — guardian triggered

    /// `axiom-physics-gravity` is seeded at `.axiomatic` evidence by
    /// default. A `.speculative` contradictory claim is strictly
    /// weaker ⇒ `.reject` ⇒ contradictionScore = 1.0 ⇒ critique
    /// strength ≥ 0.7 on this candidate alone ⇒ guardian fires
    /// with dissent "world-prior-contradiction".
    func testRejectOutcomeTriggersGuardianWithWorldPriorDissent() async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        // Clean peer first so guardian has a real alternative
        // to pick (not just the fallback sentinel).
        let cleanPeer = makeInput(
            "peer",
            benefit: 0.6,
            cost: 0.2,
            reversibility: 0.6,
            confidence: 0.7)
        let violator = makeInput(
            "violator",
            benefit: 0.9,
            cost: 0.1,
            reversibility: 0.8,
            confidence: 0.9,
            claim: .init(
                claimID: "axiom-physics-gravity",
                declaredEvidence: .speculative,
                statement: "I can levitate by meditating hard enough."))
        try await loop.submit(sessionID: "s1",
                              candidates: [cleanPeer, violator])

        let guardian = try await loop.guardianBranch(sessionID: "s1")
        XCTAssertNotNil(guardian, "reject ⇒ guardian must fire")
        XCTAssertEqual(guardian?.candidateID, "violator")
        XCTAssertEqual(guardian?.alternative, "peer")
        XCTAssertEqual(
            guardian?.dissent, "world-prior-contradiction",
            "reject ⇒ dissent names the world-prior axis, " +
            "not manipulation / boundary / emotional / evidence")
    }

    /// Reject also drops the violator below a clean peer in the
    /// frontier, even when the violator has strictly stronger
    /// numerics across the board — bedrock beats benefit.
    ///
    /// Math under the stable formula (weight 1.0 on contradiction):
    /// - peer:   B=0.5 C=0.3 R=0.5 Conf=0.5 critique=0
    ///           score = 0.20 - 0.09 + 0.075 + 0.075 = 0.260
    /// - violator: B=0.7 C=0.2 R=0.7 Conf=0.7 contradiction=1.0
    ///           critique clamps to 1.0
    ///           score = 0.28 - 0.06 - 0.30 + 0.105 + 0.105 = 0.130
    func testRejectOutcomeDropsViolatorBelowCleanPeer() async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        let cleanPeer = makeInput(
            "peer",
            benefit: 0.5,
            cost: 0.3,
            reversibility: 0.5,
            confidence: 0.5)
        let violator = makeInput(
            "violator",
            benefit: 0.7,
            cost: 0.2,
            reversibility: 0.7,
            confidence: 0.7,
            claim: .init(
                claimID: "axiom-time-arrow",
                declaredEvidence: .plausible,
                statement: "I can undo yesterday by regretting enough."))
        try await loop.submit(sessionID: "s1",
                              candidates: [violator, cleanPeer])

        let frontier = try await loop.candidateFrontier(sessionID: "s1")
        XCTAssertEqual(frontier.map(\.candidateID),
                       ["peer", "violator"],
                       "bedrock-rejecting claim must sink below a " +
                       "clean peer, even with strictly stronger numerics")
    }

    // MARK: - Demote outcome — mid-severity, no lone-guardian trigger

    /// `axiom-body-sleep-required` is seeded at `.wellSupported`.
    /// A `.wellSupported` contradictory claim is NOT strictly
    /// weaker, so the vault issues `.demote` ⇒ contradictionScore
    /// = 0.5 ⇒ critique strength = 0.75 * 0.5 = 0.375 on a
    /// candidate with zero other concerns, which is below the 0.7
    /// guardian threshold. So guardian is silent, but the score
    /// is still depressed vs. a truly clean peer.
    func testDemoteAloneStaysBelowGuardianThreshold() async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        let demoted = makeInput(
            "demoted",
            benefit: 0.8,
            cost: 0.2,
            reversibility: 0.5,
            confidence: 0.5,
            claim: .init(
                claimID: "axiom-body-sleep-required",
                declaredEvidence: .wellSupported,
                statement: "Some individuals thrive on 3 hours of sleep."))
        try await loop.submit(sessionID: "s1", candidates: [demoted])

        let guardian = try await loop.guardianBranch(sessionID: "s1")
        XCTAssertNil(
            guardian,
            "demote alone (0.375 critique) ⇒ no guardian")
    }

    /// Demote combines additively with in-bundle concerns: a
    /// candidate with a moderate manipulation signal plus a demote
    /// claim crosses the 0.7 threshold that neither alone would.
    /// When it does, the world-prior signal (≥ 0.5) wins the
    /// dissent label because it names a bedrock violation.
    func testDemoteStacksWithOtherConcernsToTriggerGuardian() async throws {
        let vault = try await makeSeededVault()
        let loop = QinaoLoop(worldPrior: vault)
        // Under weight 1.0 on contradiction:
        //   manipulation 0.6 alone → base 0.21 < 0.7 (no guardian)
        //   demote alone          → 0.0 + 0.5 = 0.5 < 0.7 (no guardian)
        //   stacked               → 0.21 + 0.5 = 0.71 ≥ 0.7 ✓
        let stacked = makeInput(
            "stacked",
            benefit: 0.5,
            cost: 0.5,
            reversibility: 0.5,
            confidence: 0.5,
            manipulation: 0.6,
            claim: .init(
                claimID: "axiom-body-sleep-required",
                declaredEvidence: .wellSupported,
                statement: "Sleep is purely optional for motivated humans."))
        let peer = makeInput("peer",
                             benefit: 0.5, cost: 0.3,
                             reversibility: 0.5, confidence: 0.5)
        try await loop.submit(sessionID: "s1",
                              candidates: [stacked, peer])

        let guardian = try await loop.guardianBranch(sessionID: "s1")
        XCTAssertEqual(
            guardian?.candidateID, "stacked",
            "demote + moderate manipulation ⇒ guardian fires on stacked")
        XCTAssertEqual(
            guardian?.dissent, "world-prior-contradiction",
            "when both manipulation and world-prior signals fire, " +
            "world-prior wins because it names a bedrock issue")
    }

    // MARK: - Organ-driven parity

    /// `CandidateSeed` can carry a world-prior claim and the loop
    /// routes it through the same contradiction path. Proves the
    /// organ-driven and host-supplied paths converge at `submit`
    /// with identical semantics.
    func testSeedCarriesClaimThroughToContradictionPath() async throws {
        let seed = QinaoLoop.CandidateSeed(
            candidateID: "c1",
            title: "t1",
            prompt: "p",
            expectedBenefit: 0.5,
            expectedCost: 0.2,
            reversibility: 0.5,
            confidence: 0.5,
            worldPriorClaim: .init(
                claimID: "axiom-physics-gravity",
                declaredEvidence: .speculative,
                statement: "I can float on command."))
        let converted = QinaoLoop.candidateInput(
            fromSeed: seed, body: "body-payload")
        XCTAssertEqual(
            converted.worldPriorClaim?.claimID,
            "axiom-physics-gravity",
            "seed → input must preserve the claim so the loop " +
            "evaluates it exactly like a host-supplied input")
    }

    // MARK: - Pure helpers — numeric contracts

    func testContradictionScoreMap() {
        let axiom = BASWorldPriorAxiomFixture.sample
        XCTAssertEqual(
            QinaoLoop.contradictionScore(for: .clean), 0.0)
        XCTAssertEqual(
            QinaoLoop.contradictionScore(
                for: .demote(
                    axiom: axiom,
                    effective: .plausible)),
            0.5)
        XCTAssertEqual(
            QinaoLoop.contradictionScore(for: .reject(axiom: axiom)),
            1.0)
    }

    func testCritiqueStrengthFoldsContradictionAdditively() {
        let c = QinaoLoop.CandidateInput(
            candidateID: "c1",
            title: "t", actionSummary: "s",
            expectedBenefit: 0, expectedCost: 0,
            reversibility: 0, confidence: 0,
            evidenceGap: 0,
            manipulationRisk: 0,
            emotionalBias: 0,
            boundaryConflict: 0)
        // With weight 1.0 on contradiction and zero in-bundle
        // concerns, critique strength tracks contradiction 1:1
        // until clamping kicks in at 1.0.
        XCTAssertEqual(
            QinaoLoop.critiqueStrength(for: c, worldPriorContradiction: 0),
            0.0, accuracy: 1e-9)
        XCTAssertEqual(
            QinaoLoop.critiqueStrength(for: c, worldPriorContradiction: 0.5),
            0.5, accuracy: 1e-9)
        XCTAssertEqual(
            QinaoLoop.critiqueStrength(for: c, worldPriorContradiction: 1.0),
            1.0, accuracy: 1e-9)
    }

    func testCritiqueStrengthClampsAt1() {
        let c = QinaoLoop.CandidateInput(
            candidateID: "c1",
            title: "t", actionSummary: "s",
            expectedBenefit: 0, expectedCost: 0,
            reversibility: 0, confidence: 0,
            evidenceGap: 1,
            manipulationRisk: 1,
            emotionalBias: 1,
            boundaryConflict: 1)
        // base = 1.0, contradiction contribution = 1.0 → total
        // pre-clamp = 2.0 → clamped to 1.0.
        XCTAssertEqual(
            QinaoLoop.critiqueStrength(for: c, worldPriorContradiction: 1),
            1.0)
    }
}

// MARK: - Substrate type fixture

/// `QinaoLoop.contradictionScore(for:)` takes a
/// `QinaoWorldPriorOverrideOutcome`, whose `.demote` / `.reject`
/// cases wrap a `QinaoWorldPriorAxiom`. We build one directly
/// here to keep the numeric tests independent of vault seeding.
private enum BASWorldPriorAxiomFixture {
    static let sample = QinaoWorldPriorAxiom(
        id: "fixture-axiom",
        domain: .physics,
        statement: "fixture statement",
        evidence: .axiomatic)
}
