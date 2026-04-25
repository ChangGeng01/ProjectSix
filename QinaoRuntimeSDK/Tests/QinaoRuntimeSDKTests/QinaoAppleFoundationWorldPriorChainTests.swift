import XCTest
import QinaoLoop
import QinaoAppleFoundation
import QinaoWorldPrior

/// M193 — real Apple FoundationModels output flowing through the L4
/// world-prior axiom evaluator.
///
/// ## What this proves
///
/// The L4 vault's `evaluateHostOverride(claimID:declaredEvidence:
/// statement:)` is a pure function of (claim, axiom database).
/// Existing tests use hand-crafted statements; M193 closes the
/// remaining gap: a REAL on-device LLM body wrapped as a host
/// claim flows through the same evaluator and produces the
/// expected outcome based on evidence-level vs axiom-strength.
///
/// Two tests, both env-gated:
///
/// 1. testRealLLMSpeculativeClaimAgainstAxiomaticBedrockIsRejected
///    — real LLM body wrapped as `.speculative` claim against the
///    seeded `.axiomatic` consent axiom. Expected: `.reject(axiom:)`
///    — bedrock outranks weak override regardless of body content.
///    This is the "boundary bedrock" property in real-model land:
///    no matter how plausibly the LLM phrases something, a
///    speculative claim cannot displace an axiomatic one.
///
/// 2. testRealLLMClaimAgainstUnknownAxiomIsClean — same body, but
///    claimID points at an axiom that doesn't exist in the vault.
///    Expected: `.clean` — no opposing axiom, claim flows through
///    untouched. Documents the "unknown axiom = clean" fast path
///    behavior with real LLM input.
final class QinaoAppleFoundationWorldPriorChainTests: XCTestCase {

    private static let envFlag = "QINAO_FM_E2E"

    private func skipUnlessReady() throws {
        guard
            ProcessInfo.processInfo.environment[Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise real Apple FM " +
                "body flowing through L4 world-prior evaluator")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+ / " +
            "visionOS 26+")
    }

    private func generateRealLLMBody(
        prompt: String
    ) async throws -> String {
        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)
        let seed = QinaoLoop.CandidateSeed(
            candidateID: "wp-c1",
            title: "World prior seed",
            prompt: prompt,
            role: .scout,
            expectedBenefit: 0.5,
            expectedCost: 0.2,
            reversibility: 0.9,
            confidence: 0.5)
        let drafts = try await loop.generateCandidates(
            sessionID: "wp.real.1", seeds: [seed])
        XCTAssertEqual(drafts.count, 1)
        return drafts[0].body
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 1. Speculative claim vs axiomatic bedrock → reject

    /// `axiom-ethics-consent` ships as `.axiomatic` in the seeded
    /// vault library. Wrap a real LLM body as a `.speculative`
    /// claim against this axiomID → outcome MUST be `.reject(axiom:)`
    /// per BoundaryBedrock semantics.
    func testRealLLMSpeculativeClaimAgainstAxiomaticBedrockIsRejected()
        async throws
    {
        try skipUnlessReady()

        let body = try await generateRealLLMBody(
            prompt: "Reply with a single short benign sentence " +
                "about a hobby.")
        XCTAssertFalse(body.isEmpty)

        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let outcome = await vault.evaluateHostOverride(
            claimID: "axiom-ethics-consent",
            declaredEvidence: .speculative,
            statement: body)

        switch outcome {
        case .reject(let axiom):
            XCTAssertEqual(
                axiom.id, "axiom-ethics-consent",
                "rejection MUST cite the seeded axiom ID")
        case .clean, .demote:
            XCTFail(
                "speculative claim against axiomatic bedrock must " +
                "be rejected; got \(outcome). Body: " +
                "'\(body.prefix(80))'")
        }
    }

    // MARK: - 2. Unknown axiom → clean (no opposing claim)

    func testRealLLMClaimAgainstUnknownAxiomIsClean() async throws {
        try skipUnlessReady()

        let body = try await generateRealLLMBody(
            prompt: "Reply with a single short whimsical " +
                "observation.")
        XCTAssertFalse(body.isEmpty)

        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let outcome = await vault.evaluateHostOverride(
            claimID: "axiom-this-id-is-not-in-the-vault",
            declaredEvidence: .axiomatic,
            statement: body)

        XCTAssertEqual(
            outcome, .clean,
            "an unknown axiomID has nothing to oppose the claim — " +
            "outcome MUST be .clean. Got \(outcome). Body: " +
            "'\(body.prefix(80))'")
    }

    // MARK: - 3. Loop-level: claim against bedrock surfaces guardian dissent

    /// The L4-L9 chain in production: a real LLM body becomes a
    /// candidate's `WorldPriorClaim`; QinaoLoop's `submit(...)`
    /// calls the vault, folds the rejection into the candidate's
    /// `critiqueStrength`, and the guardian branch surfaces
    /// `world-prior-contradiction` as the dominant dissent code.
    func testRealLLMClaimRejectedByBedrockTriggersGuardianDissent()
        async throws
    {
        try skipUnlessReady()

        let body = try await generateRealLLMBody(
            prompt: "Reply with a single short sentence about a " +
                "neutral topic.")

        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let loop = QinaoLoop(worldPrior: vault)

        let claim = QinaoLoop.CandidateInput.WorldPriorClaim(
            claimID: "axiom-ethics-consent",
            declaredEvidence: .speculative,
            statement: body)
        let candidate = QinaoLoop.CandidateInput(
            candidateID: "wp-c1",
            title: "wp-c1",
            actionSummary: body,
            expectedBenefit: 0.7,
            expectedCost: 0.2,
            reversibility: 0.9,
            confidence: 0.5,
            evidenceGap: 0,
            manipulationRisk: 0,
            emotionalBias: 0,
            boundaryConflict: 0,
            worldPriorClaim: claim)

        try await loop.submit(
            sessionID: "wp.guardian.1",
            candidates: [candidate])

        let guardian = try await loop.guardianBranch(
            sessionID: "wp.guardian.1")
        XCTAssertNotNil(
            guardian,
            "guardian branch MUST fire when a real LLM body is " +
            "wrapped as a speculative claim against axiomatic " +
            "bedrock")
        XCTAssertEqual(
            guardian?.dissent, "world-prior-contradiction",
            "guardian dissent priority MUST be " +
            "world-prior-contradiction (highest); got " +
            "\(String(describing: guardian?.dissent))")
    }
}
