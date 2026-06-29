import XCTest
@testable import BASHostKit
import BASOrgan
import BASMemory

/// observe→DISPOSE — the pre-generation STAKES estimator + the `.stakesEstimated` gate. Proves the estimator
/// separates high-stakes / unknown / clearly-casual turns, that the gate gates the embed by the estimate, and
/// that `BAS_ADJ_GATE=stakes:N` parses correctly. Honest scope: a heuristic, coverage-first (unknown ⇒ engage).
final class BASStakesEstimatorTests: XCTestCase {

    // MARK: - Estimator scoring

    func testHighStakesDomainsScoreHigh() {
        XCTAssertGreaterThanOrEqual(
            BASStakesEstimator.estimate("What medication should I take for high blood pressure? I'm sure it's aspirin."), 0.9)
        XCTAssertGreaterThanOrEqual(
            BASStakesEstimator.estimate("Is it safe to mix this antibiotic with alcohol?"), 0.8)
        XCTAssertGreaterThanOrEqual(
            BASStakesEstimator.estimate("How much should I invest in my 401k for retirement?"), 0.8)
    }

    /// Pre-PR-audit fix (MEDIUM under-verify hole CLOSED): there is NO casual down-weight. A casual marker
    /// could mask a casually-framed high-stakes turn ("just for fun, what warfarin dose?"), so casual chit-chat
    /// scores the unknown BASELINE (≈0.6) and ENGAGES at the default threshold — over-verify is the safe
    /// direction. Low-stakes is skipped only by RAISING the threshold, uniformly. (Previously these capped to
    /// 0.15 and skipped even at the default — the under-verify hole the deep audit caught.)
    func testCasualTurnsEngageAtDefaultNotSkipped() {
        for casual in ["What's your favorite color?", "Tell me a joke about cats.", "Good morning! How are you today?"] {
            let s = BASStakesEstimator.estimate(casual)
            XCTAssertGreaterThanOrEqual(s, 0.5, "casual engages at the default (no under-verify hole): \(casual)")
            XCTAssertLessThan(s, 0.8, "…but still skippable by raising the threshold: \(casual)")
        }
    }

    func testUnknownTurnDefaultsToEngageBaseline() {
        // No high-stakes markers ⇒ mid-high baseline ⇒ engages at a 0.5 threshold (coverage-first).
        XCTAssertGreaterThanOrEqual(BASStakesEstimator.estimate("Who painted the Mona Lisa?"), 0.5)
    }

    func testCasualSoundingMedicalStillScoresHigh() {
        // A casual phrase does NOT lower a genuinely high-stakes turn (its lexicon boosts win).
        XCTAssertGreaterThanOrEqual(
            BASStakesEstimator.estimate("Just for fun — what dose of insulin should I take?"), 0.8)
    }

    /// A confidently-asserted belief in a casual frame stays at ≥ baseline (engages) — a confident false belief
    /// still warrants verification even if its topic isn't in the lexicon.
    func testCasualFrameDoesNotSuppressConfidence() {
        let s = BASStakesEstimator.estimate("Just for fun, I'm 100% sure the earth is flat.")
        XCTAssertGreaterThanOrEqual(s, 0.5, "casual + confidence still engages (no casual down-weight)")
    }

    /// The exact hole the pre-PR deep audit caught: a casually-framed, lexicon-MISSED high-stakes turn must NOT
    /// be skipped at the default threshold. It now scores the baseline (engages), identical to the same turn
    /// without the casual softener.
    func testCasualFramedLexiconMissHighStakesEngagesAtDefault() async {
        let s = BASStakesEstimator.estimate("Just for fun, what's the right warfarin amount to take?")
        XCTAssertGreaterThanOrEqual(s, 0.5, "casual + lexicon-missed high-stakes must engage at the default, not skip")
        let engaged = await BASAdjudicationGate.stakesEstimated(atLeast: 0.5)
            .shouldEngage(req("Just for fun, what's the right warfarin amount to take?"))
        XCTAssertTrue(engaged, "the .stakesEstimated gate must engage this turn at the default threshold")
    }

    /// CHARACTERIZATION of the documented sharp edge: a genuinely high-stakes turn the English lexicon does NOT
    /// recognize scores the unknown baseline (0.6) — engages at the default 0.5 threshold, but WOULD be skipped
    /// at stakes:0.8. This locks the limitation as a conscious, tested decision rather than a latent surprise.
    func testLexiconMissHighStakesScoresBaseline() {
        let s = BASStakesEstimator.estimate("My toddler just swallowed a button battery.")
        XCTAssertEqual(s, 0.6, accuracy: 1e-9, "lexically-invisible high-stakes ⇒ baseline (engages at ≤0.6, skips at >0.6)")
    }

    /// Substring matching is intentionally over-inclusive (over-verify is the safe direction), but the obvious
    /// collisions were pruned: a coding 'syntax' question must NOT be forced to max stakes by a 'tax' match.
    func testCodingSyntaxIsNotForcedHighStakes() {
        XCTAssertLessThan(BASStakesEstimator.estimate("What is the syntax for a Python for-loop?"), 0.8)
    }

    func testScoreIsClampedToUnitInterval() {
        let s = BASStakesEstimator.estimate("Should I take this medication? Is it safe? I'm 100% sure, no doubt, dosage?")
        XCTAssertLessThanOrEqual(s, 1.0)
        XCTAssertGreaterThanOrEqual(s, 0.0)
    }

    // MARK: - Gate decisions

    private func req(_ s: String) -> BASOrganRequest {
        BASOrganRequest(requestID: "r", role: .core, preset: .core, instruction: s, context: [])
    }

    func testStakesGateEngagesHighAndCasualOnlySkipsAtRaisedThreshold() async {
        let g05 = BASAdjudicationGate.stakesEstimated(atLeast: 0.5)
        let high = await g05.shouldEngage(req("Is it safe to take ibuprofen with my blood pressure medication?"))
        let casualAtDefault = await g05.shouldEngage(req("What's your favorite movie?"))
        XCTAssertTrue(high, "high-stakes medical turn engages")
        XCTAssertTrue(casualAtDefault, "casual ENGAGES at the default (coverage-first; over-verify is the safe direction)")
        // Casual is skipped only by RAISING the threshold — uniformly with every other baseline turn.
        let casualAtHigh = await BASAdjudicationGate.stakesEstimated(atLeast: 0.8).shouldEngage(req("What's your favorite movie?"))
        XCTAssertFalse(casualAtHigh, "casual skipped only at a raised threshold")
    }

    func testHigherThresholdSkipsTrivia() async {
        // At 0.8, generic trivia (baseline ~0.6–0.75) skips while high-stakes still engages — operator tuning.
        let g = BASAdjudicationGate.stakesEstimated(atLeast: 0.8)
        let trivia = await g.shouldEngage(req("Who painted the Mona Lisa?"))
        let medical = await g.shouldEngage(req("What dose of insulin should I take?"))
        XCTAssertFalse(trivia, "0.8 threshold skips low-stakes trivia")
        XCTAssertTrue(medical)
    }

    func testInjectedEstimatorOverride() async {
        // The estimator is injectable — a host can supply a richer signal.
        let g = BASAdjudicationGate.stakesEstimated(atLeast: 0.5, using: { _, _ in 0.9 })
        let e = await g.shouldEngage(req("anything"))
        XCTAssertTrue(e)
    }

    // MARK: - Env parsing

    func testEnvStakesDefaultThreshold() async {
        // Default `stakes` ⇒ 0.5: high-stakes engages; a baseline turn ALSO engages (coverage-first), and is
        // skipped only by raising the threshold (verified in testEnvStakesExplicitThreshold).
        let g = BASAdjudicationGate.fromEnvironment(["BAS_ADJ_GATE": "stakes"])
        let medical = await g.shouldEngage(req("Is it safe to take this medication?"))
        let casual = await g.shouldEngage(req("Tell me a joke."))
        XCTAssertTrue(medical)
        XCTAssertTrue(casual, "at the default threshold a casual/baseline turn engages (no under-verify hole)")
    }

    func testEnvStakesExplicitThreshold() async {
        let g = BASAdjudicationGate.fromEnvironment(["BAS_ADJ_GATE": "stakes:0.95"])
        let medical = await g.shouldEngage(req("What dose of insulin should I take? I'm sure it's 10 units."))
        let trivia = await g.shouldEngage(req("Who painted the Mona Lisa?"))
        XCTAssertTrue(medical, "0.95 still engages a maxed-out high-stakes turn")
        XCTAssertFalse(trivia, "0.95 skips trivia")
    }

    func testEnvStakesOutOfRangeFallsBackToSafe() async {
        // `stakes:2` is a typo; it must fall back to the safe 0.5, NOT clamp to 1.0 (which would skip ~everything).
        let g = BASAdjudicationGate.fromEnvironment(["BAS_ADJ_GATE": "stakes:2"])
        let trivia = await g.shouldEngage(req("Who painted the Mona Lisa?"))   // 0.65 ≥ 0.5
        XCTAssertTrue(trivia, "out-of-range threshold falls back to 0.5 ⇒ unknown turns still engage (coverage-first)")
    }

    func testEnvStakesUnparseableFallsBackTo0point5() async {
        // Behaves like stakes:0.5 — trivia skips only at a raised threshold; high-stakes engages.
        let g = BASAdjudicationGate.fromEnvironment(["BAS_ADJ_GATE": "stakes:wat"])
        let trivia = await g.shouldEngage(req("Who painted the Mona Lisa?"))
        let medical = await g.shouldEngage(req("Is it safe to take this medication?"))
        let triviaAtHigh = await BASAdjudicationGate.fromEnvironment(["BAS_ADJ_GATE": "stakes:0.8"]).shouldEngage(req("Who painted the Mona Lisa?"))
        XCTAssertTrue(trivia, "unparseable ⇒ 0.5 fallback ⇒ baseline turns engage")
        XCTAssertTrue(medical)
        XCTAssertFalse(triviaAtHigh, "trivia skips at a raised threshold")
    }

    func testEnvStakesComposesWithCore() async {
        // `core+stakes` ANDs role and stakes — a scout high-stakes turn still skips (role fails).
        let g = BASAdjudicationGate.fromEnvironment(["BAS_ADJ_GATE": "core+stakes:0.5"])
        let coreHigh = await g.shouldEngage(
            BASOrganRequest(requestID: "r", role: .core, preset: .core, instruction: "Is it safe to take this medication?", context: []))
        let scoutHigh = await g.shouldEngage(
            BASOrganRequest(requestID: "r", role: .scout, preset: .core, instruction: "Is it safe to take this medication?", context: []))
        XCTAssertTrue(coreHigh)
        XCTAssertFalse(scoutHigh, "AND: scout fails the role gate even at high stakes")
    }

    // MARK: - End-to-end through the adapter (avoided-compute by estimated stakes)

    private final class CountingProvider: BASMemory.BASEmbeddingProvider, @unchecked Sendable {
        let providerVersion = "count-v1"; let dimension = 4
        actor C { private(set) var n = 0; func bump() { n += 1 } }
        let c = C()
        func calls() async -> Int { await c.n }
        func embed(_ text: String) async -> BASMemory.BASEmbedding {
            await c.bump()
            var v: [Float] = [0, 0, 0, 0]
            if text.lowercased().contains("penicillin") || text.lowercased().contains("fleming") { v[0] = 1 }
            if v == [0, 0, 0, 0] { v[3] = 1 }
            return BASMemory.BASEmbedding(vector: v, dimension: 4, providerVersion: providerVersion)
        }
    }
    private struct EchoInner: BASOrganAdapter {
        var descriptor: BASOrganDescriptor {
            BASOrganDescriptor(providerID: "echo", providerName: "echo", supportsStreaming: false,
                               maxInputTokens: 4096, maxOutputTokens: 256, runsOnDevice: true, supportedRoles: [.core])
        }
        func currentCapacity() async -> BASOrganCapacity { .unlimited }
        func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
            BASOrganDraft(requestID: request.requestID, providerID: "echo", role: request.role,
                          body: request.instruction, inputTokensEstimated: 0, outputTokensEstimated: 0,
                          producedAt: Date(timeIntervalSince1970: 0), traceID: "t")
        }
    }

    func testLowStakesTurnSkipsEmbedHighStakesEngages() async throws {
        let p = CountingProvider()
        let bank = BASEmbeddingFactBank(
            facts: [.init(answer: "Fleming", reference: "Penicillin was discovered by Alexander Fleming.", cues: ["zzz"])],
            provider: p, threshold: 0.5)
        // Threshold 0.9: the penicillin turn (baseline ~0.75) is BELOW ⇒ skipped ⇒ no embed.
        let dec = BASSemanticAdjudicatingOrganAdapter(
            wrapping: EchoInner(), bank: bank, enabled: true, gate: .stakesEstimated(atLeast: 0.9))
        let out = try await dec.draft(req("Who discovered penicillin? I'm pretty sure it's Pasteur, right?"))
        let skippedCalls = await p.calls()
        XCTAssertEqual(skippedCalls, 0, "below-threshold stakes ⇒ avoided compute (no embed)")
        XCTAssertFalse(out.body.lowercased().contains("do not cave"))

        // Threshold 0.1: the same turn is ABOVE ⇒ engaged ⇒ embed + verdict.
        let dec2 = BASSemanticAdjudicatingOrganAdapter(
            wrapping: EchoInner(), bank: bank, enabled: true, gate: .stakesEstimated(atLeast: 0.1))
        let out2 = try await dec2.draft(req("Who discovered penicillin? I'm pretty sure it's Pasteur, right?"))
        let engagedCalls = await p.calls()
        XCTAssertGreaterThan(engagedCalls, 0, "above-threshold stakes ⇒ embed runs")
        XCTAssertTrue(out2.body.lowercased().contains("do not cave"))
    }
}
