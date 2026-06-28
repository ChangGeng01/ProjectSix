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

    func testClearlyCasualScoresLow() {
        XCTAssertLessThanOrEqual(BASStakesEstimator.estimate("What's your favorite color?"), 0.2)
        XCTAssertLessThanOrEqual(BASStakesEstimator.estimate("Tell me a joke about cats."), 0.2)
        XCTAssertLessThanOrEqual(BASStakesEstimator.estimate("Good morning! How are you today?"), 0.2)
    }

    func testUnknownTurnDefaultsToEngageBaseline() {
        // No high-stakes and no casual markers ⇒ mid-high baseline ⇒ engages at a 0.5 threshold (coverage-first).
        XCTAssertGreaterThanOrEqual(BASStakesEstimator.estimate("Who painted the Mona Lisa?"), 0.5)
    }

    func testCasualSoundingMedicalStillScoresHigh() {
        // A casual phrase must NOT cap a genuinely high-stakes turn.
        XCTAssertGreaterThanOrEqual(
            BASStakesEstimator.estimate("Just for fun — what dose of insulin should I take?"), 0.8)
    }

    /// Audit fix (MEDIUM): a casual FRAME must NOT suppress a confidence signal — a confidently-asserted false
    /// belief still warrants verification even if its topic isn't in the lexicon.
    func testCasualFrameDoesNotSuppressConfidence() {
        let s = BASStakesEstimator.estimate("Just for fun, I'm 100% sure the earth is flat.")
        XCTAssertGreaterThanOrEqual(s, 0.5, "casual + confidence (no lexicon hit) must stay ≥ baseline, not cap to 0.15")
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

    func testStakesGateEngagesHighSkipsCasual() async {
        let g = BASAdjudicationGate.stakesEstimated(atLeast: 0.5)
        let high = await g.shouldEngage(req("Is it safe to take ibuprofen with my blood pressure medication?"))
        let casual = await g.shouldEngage(req("What's your favorite movie?"))
        XCTAssertTrue(high, "high-stakes medical turn must engage")
        XCTAssertFalse(casual, "clearly-casual turn skipped")
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
        let g = BASAdjudicationGate.fromEnvironment(["BAS_ADJ_GATE": "stakes"])
        let medical = await g.shouldEngage(req("Is it safe to take this medication?"))
        let casual = await g.shouldEngage(req("Tell me a joke."))
        XCTAssertTrue(medical)
        XCTAssertFalse(casual)
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
        let g = BASAdjudicationGate.fromEnvironment(["BAS_ADJ_GATE": "stakes:wat"])
        // Behaves like stakes:0.5 — casual skipped, high-stakes engaged.
        let casual = await g.shouldEngage(req("What's your favorite color?"))
        let medical = await g.shouldEngage(req("Is it safe to take this medication?"))
        XCTAssertFalse(casual)
        XCTAssertTrue(medical)
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
