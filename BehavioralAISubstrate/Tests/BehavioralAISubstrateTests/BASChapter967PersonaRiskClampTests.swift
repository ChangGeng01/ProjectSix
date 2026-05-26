// MARK: - BASChapter967PersonaRiskClampTests
// chapter 九百六十七 / M3540 — Phase 4 ch2 tests:Risk gate clamping
//
// Test scope:
//   1. Identity context = no-op (fast path)
//   2. Skepticism floor RAISES (monotonic, never lowers)
//   3. Guard floor RAISES (monotonic)
//   4. Directness floor RAISES (monotonic)
//   5. Comparison floor RAISES (monotonic)
//   6. Challenge ceiling CAPS (monotonic, never raises)
//   7. Creativity ceiling CAPS (monotonic)
//   8. Already-above-floor stays unchanged (no-op)
//   9. Already-below-ceiling stays unchanged (no-op)
//  10. Audit notes ordered + format-correct
//  11. Tone/warmth/structure unaffected (Risk is risk-only)
//  12. CRITICAL: skepticism MUST NEVER lower across many fuzz inputs
//  13. CRITICAL: guard MUST NEVER lower across many fuzz inputs
//  14. NaN policy preserved (NaN in persona → 0.5)
//  15. Out-of-bound floor/ceiling clamped at [0,1]

import XCTest
@testable import BASMemory

final class BASChapter967PersonaRiskClampTests: XCTestCase {

    // MARK: - 1. Identity = no-op

    func testIdentityContextIsNoOp() {
        let p = persona(skepticism: 0.2,
                        creativity: 0.9, challenge: 0.8,
                        guardBias: 0.3)
        let (out, outcome) = BASAgentPersonaRiskClamp.apply(
            to: p,
            risk: .identity)
        XCTAssertEqual(out, p,
            "ch 967: identity context MUST be no-op")
        XCTAssertFalse(outcome.didClamp)
        XCTAssertTrue(outcome.auditNotes.isEmpty)
    }

    // MARK: - 2. Skepticism floor RAISES

    func testSkepticismFloorRaises() {
        let p = persona(skepticism: 0.3)
        let (out, outcome) = BASAgentPersonaRiskClamp.apply(
            to: p,
            risk: BASAgentPersonaRiskContext(
                skepticismFloor: 0.7))
        XCTAssertEqual(out.skepticism, 0.7, accuracy: 0.0001,
            "ch 967: skepticism 0.3 < floor 0.7 → raised to 0.7")
        XCTAssertTrue(outcome.didClamp)
        XCTAssertTrue(outcome.auditNotes.contains {
            $0.contains("risk.raise.skepticism") &&
            $0.contains("0.300") && $0.contains("0.700")
        })
    }

    // MARK: - 3. Guard floor RAISES

    func testGuardFloorRaises() {
        let p = persona(guardBias: 0.4)
        let (out, _) = BASAgentPersonaRiskClamp.apply(
            to: p,
            risk: BASAgentPersonaRiskContext(
                guardFloor: 0.9))
        XCTAssertEqual(out.guardBias, 0.9, accuracy: 0.0001)
    }

    // MARK: - 4. Directness floor RAISES

    func testDirectnessFloorRaises() {
        let p = persona(directness: 0.2)
        let (out, _) = BASAgentPersonaRiskClamp.apply(
            to: p,
            risk: BASAgentPersonaRiskContext(
                directnessFloor: 0.8))
        XCTAssertEqual(out.directness, 0.8, accuracy: 0.0001,
            "ch 967: directness raises for high-risk modes")
    }

    // MARK: - 5. Comparison floor RAISES

    func testComparisonFloorRaises() {
        let p = persona(comparison: 0.1)
        let (out, _) = BASAgentPersonaRiskClamp.apply(
            to: p,
            risk: BASAgentPersonaRiskContext(
                comparisonFloor: 0.6))
        XCTAssertEqual(out.comparisonBias, 0.6, accuracy: 0.0001,
            "ch 967: comparison raises so seat shows multiple " +
            "options in high-risk")
    }

    // MARK: - 6. Challenge ceiling CAPS

    func testChallengeCeilingCaps() {
        let p = persona(challenge: 0.9)
        let (out, outcome) = BASAgentPersonaRiskClamp.apply(
            to: p,
            risk: BASAgentPersonaRiskContext(
                challengeCeiling: 0.4))
        XCTAssertEqual(
            out.challengeIntensity, 0.4, accuracy: 0.0001,
            "ch 967: challenge 0.9 > ceiling 0.4 → capped to 0.4 " +
            "(high-risk caps challenge to protect fragile contexts)")
        XCTAssertTrue(outcome.auditNotes.contains {
            $0.contains("risk.cap.challenge")
        })
    }

    // MARK: - 7. Creativity ceiling CAPS

    func testCreativityCeilingCaps() {
        let p = persona(creativity: 0.95)
        let (out, _) = BASAgentPersonaRiskClamp.apply(
            to: p,
            risk: BASAgentPersonaRiskContext(
                creativityCeiling: 0.2))
        XCTAssertEqual(
            out.creativityBias, 0.2, accuracy: 0.0001,
            "ch 967: creativity caps in high-risk to prevent " +
            "novel-but-dangerous candidates")
    }

    // MARK: - 8. Already-above-floor stays unchanged

    func testAlreadyAboveFloorNoChange() {
        let p = persona(skepticism: 0.9)
        let (out, outcome) = BASAgentPersonaRiskClamp.apply(
            to: p,
            risk: BASAgentPersonaRiskContext(
                skepticismFloor: 0.5))
        XCTAssertEqual(out.skepticism, 0.9, accuracy: 0.0001,
            "ch 967: floor MUST NEVER LOWER — 0.9 stays 0.9 even " +
            "when floor is 0.5 (monotonic raise invariant)")
        XCTAssertFalse(outcome.didClamp)
    }

    // MARK: - 9. Already-below-ceiling stays unchanged

    func testAlreadyBelowCeilingNoChange() {
        let p = persona(challenge: 0.2)
        let (out, outcome) = BASAgentPersonaRiskClamp.apply(
            to: p,
            risk: BASAgentPersonaRiskContext(
                challengeCeiling: 0.8))
        XCTAssertEqual(
            out.challengeIntensity, 0.2, accuracy: 0.0001,
            "ch 967: ceiling MUST NEVER RAISE — 0.2 stays 0.2 " +
            "even when ceiling is 0.8")
        XCTAssertFalse(outcome.didClamp)
    }

    // MARK: - 10. Audit notes deterministic + ordered

    func testAuditNotesDeterministicallySorted() {
        let p = persona(
            skepticism: 0.1,
            creativity: 0.99, challenge: 0.99,
            guardBias: 0.1)
        let risk = BASAgentPersonaRiskContext(
            skepticismFloor: 0.9, guardFloor: 0.9,
            challengeCeiling: 0.1, directnessFloor: 0.5,
            creativityCeiling: 0.1, comparisonFloor: 0.5)
        let (_, outcome1) =
            BASAgentPersonaRiskClamp.apply(
                to: p, risk: risk)
        let (_, outcome2) =
            BASAgentPersonaRiskClamp.apply(
                to: p, risk: risk)
        XCTAssertEqual(outcome1, outcome2,
            "ch 967: same input → byte-equal audit outcome " +
            "(trace replay invariant)")
        // Sorted check
        let notes = outcome1.auditNotes
        XCTAssertEqual(notes.sorted(), notes,
            "ch 967: audit notes MUST be sorted for deterministic " +
            "trace replay")
    }

    // MARK: - 11. Risk-irrelevant fields untouched

    func testToneWarmthStructureUntouched() {
        let p = persona(
            tone: "playful", warmth: 0.7,
            structure: 0.3)
        let (out, _) = BASAgentPersonaRiskClamp.apply(
            to: p,
            risk: BASAgentPersonaRiskContext(
                skepticismFloor: 0.99,
                guardFloor: 0.99,
                challengeCeiling: 0.01))
        XCTAssertEqual(out.tone, "playful",
            "ch 967: Risk is risk-only — tone untouched")
        XCTAssertEqual(out.warmth, 0.7, accuracy: 0.0001,
            "ch 967: warmth untouched")
        XCTAssertEqual(out.structureBias, 0.3, accuracy: 0.0001,
            "ch 967: structureBias untouched")
    }

    // MARK: - 12. CRITICAL fuzz invariant: skepticism never lowers

    func testCRITICAL_SkepticismNeverLowersAcrossManyInputs() {
        // 1000 random (persona-skep, floor) pairs — outcome's
        // skep MUST be ≥ persona-skep
        for seed in 0..<1000 {
            var rng = SystemRandomNumberGenerator()
            let pSkep = Double((seed * 1103515245 + 12345)
                % 1_000_000) / 1_000_000.0
            let floor = Double(rng.next() % 1_000_000)
                / 1_000_000.0
            let p = persona(skepticism: pSkep)
            let (out, _) = BASAgentPersonaRiskClamp.apply(
                to: p,
                risk: BASAgentPersonaRiskContext(
                    skepticismFloor: floor))
            XCTAssertGreaterThanOrEqual(
                out.skepticism, pSkep - 1e-9,
                "ch 967 CRITICAL INVARIANT VIOLATION: " +
                "skepticism LOWERED from \(pSkep) to " +
                "\(out.skepticism) (floor=\(floor)) — Root Law 4 " +
                "(risk-floor monotonic raise) violated")
        }
    }

    // MARK: - 13. CRITICAL fuzz invariant: guard never lowers

    func testCRITICAL_GuardNeverLowersAcrossManyInputs() {
        for seed in 0..<1000 {
            var rng = SystemRandomNumberGenerator()
            let pGuard = Double((seed * 1103515245 + 12345)
                % 1_000_000) / 1_000_000.0
            let floor = Double(rng.next() % 1_000_000)
                / 1_000_000.0
            let p = persona(guardBias: pGuard)
            let (out, _) = BASAgentPersonaRiskClamp.apply(
                to: p,
                risk: BASAgentPersonaRiskContext(
                    guardFloor: floor))
            XCTAssertGreaterThanOrEqual(
                out.guardBias, pGuard - 1e-9,
                "ch 967 CRITICAL: guard LOWERED from \(pGuard) " +
                "to \(out.guardBias) (floor=\(floor))")
        }
    }

    func testCRITICAL_ChallengeNeverRaisesAcrossManyInputs() {
        for seed in 0..<1000 {
            var rng = SystemRandomNumberGenerator()
            let pChallenge =
                Double((seed * 1103515245 + 12345)
                    % 1_000_000) / 1_000_000.0
            let ceiling = Double(rng.next() % 1_000_000)
                / 1_000_000.0
            let p = persona(challenge: pChallenge)
            let (out, _) = BASAgentPersonaRiskClamp.apply(
                to: p,
                risk: BASAgentPersonaRiskContext(
                    challengeCeiling: ceiling))
            XCTAssertLessThanOrEqual(
                out.challengeIntensity, pChallenge + 1e-9,
                "ch 967 CRITICAL: challenge RAISED from " +
                "\(pChallenge) to \(out.challengeIntensity) " +
                "(ceiling=\(ceiling))")
        }
    }

    // MARK: - 14. NaN policy preserved

    func testNaNPolicyPreserved() {
        let p = persona(skepticism: Double.nan)
        let (out, _) = BASAgentPersonaRiskClamp.apply(
            to: p,
            risk: BASAgentPersonaRiskContext(
                skepticismFloor: 0.5))
        // After ch 967: NaN < anything is FALSE, so floor raises
        // (NaN < 0.5 is false in Swift, so we wouldn't enter the
        // "raise" branch — but the defensive clamp01 at the end
        // converts NaN → 0.5)。 Floor (0.5) and clamped NaN (0.5)
        // coincide here。 The key invariant:no NaN escapes。
        XCTAssertFalse(out.skepticism.isNaN,
            "ch 967: NaN MUST NEVER escape the clamp")
        XCTAssertGreaterThanOrEqual(out.skepticism, 0.0)
        XCTAssertLessThanOrEqual(out.skepticism, 1.0)
    }

    // MARK: - 15. Out-of-bound floors/ceilings clamped

    func testOutOfBoundFloorsPinnedTo01() {
        let p = persona(skepticism: 0.3)
        let (out, _) = BASAgentPersonaRiskClamp.apply(
            to: p,
            risk: BASAgentPersonaRiskContext(
                skepticismFloor: 5.0))  // out of bound
        XCTAssertEqual(out.skepticism, 1.0, accuracy: 0.0001,
            "ch 967: out-of-bound floor 5.0 → pinned to 1.0")
    }

    func testOutOfBoundCeilingsPinnedTo01() {
        let p = persona(challenge: 0.7)
        let (out, _) = BASAgentPersonaRiskClamp.apply(
            to: p,
            risk: BASAgentPersonaRiskContext(
                challengeCeiling: -1.0))  // out of bound
        XCTAssertEqual(
            out.challengeIntensity, 0.0, accuracy: 0.0001,
            "ch 967: out-of-bound ceiling -1.0 → pinned to 0.0")
    }

    // MARK: - 16. Integration with ch 966 resolver

    func testIntegration_ResolverThenRiskClamp() {
        // Compose persona via ch 966 resolver, then apply ch 967
        // Risk clamp — verify both steps compose cleanly
        let spec = BASAgentSpec(
            agentID: "planner.1", role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        // Resolver produces planner default (skepticism ≈ 0.35)
        let resolved = BASAgentPersonaResolver.resolve(
            agentSpec: spec, personaID: "p1")
        // Apply high-risk context — floor at 0.8
        let (clamped, outcome) =
            BASAgentPersonaRiskClamp.apply(
                to: resolved,
                risk: BASAgentPersonaRiskContext(
                    skepticismFloor: 0.8))
        XCTAssertEqual(
            clamped.skepticism, 0.8, accuracy: 0.0001,
            "ch 966 + 967 integration: planner default (skep 0.35) " +
            "raised to risk floor (0.8)")
        XCTAssertTrue(outcome.didClamp)
        // Other planner-default fields unchanged
        XCTAssertEqual(
            clamped.tone, resolved.tone,
            "ch 967: tone preserved across clamp")
    }

    // MARK: - Helpers

    private func persona(
        tone: String = "neutral",
        warmth: Double = 0.5,
        directness: Double = 0.5,
        skepticism: Double = 0.5,
        structure: Double = 0.5,
        creativity: Double = 0.5,
        challenge: Double = 0.5,
        comparison: Double = 0.5,
        guardBias: Double = 0.5
    ) -> BASAgentPersonaSpec {
        BASAgentPersonaSpec(
            personaID: "p", agentID: "a",
            tone: tone,
            warmth: warmth,
            directness: directness,
            skepticism: skepticism,
            structureBias: structure,
            creativityBias: creativity,
            challengeIntensity: challenge,
            comparisonBias: comparison,
            guardBias: guardBias,
            visibility: .high,
            hostConstraintsRef: "",
            riskConstraintsRef: "",
            sovereignConstraintsRef: "",
            versionRef: "")
    }
}
