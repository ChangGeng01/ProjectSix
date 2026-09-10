// MARK: - BASChapter968PersonaSovereignClampTests
// chapter 九百六十八 / M3545 — Phase 4 ch3 tests:Sovereign clamp
//
// Test scope:
//   1. Identity context + HIGH tier = no-op (fast path)
//   2. Identity context + LOW tier WITHOUT warrant → force-default
//   3. LOW tier WITH warrant for tone → tone survives, rest force-default
//   4. LOW tier WITH warrant for all fields → full overlay survives
//   5. LOCKDOWN: HIGH tier force-defaults regardless of overlay
//   6. LOCKDOWN: MED tier force-defaults
//   7. LOCKDOWN: LOW tier force-defaults (consistent with rule 2)
//   8. LOCKDOWN: warrant IGNORED (lockdown overrides warrant)
//   9. Heightened protection: creativity cap 0.30 across all tiers
//  10. Heightened protection: challenge cap 0.30 across all tiers
//  11. Heightened protection: skepticism / guard untouched
//  12. CRITICAL: LOW tier persona NEVER softer than template without warrant
//      (1000-iter fuzz)
//  13. Audit notes deterministic + sorted
//  14. lockdownApplied flag matches sovereign.lockdownTurn
//  15. Integration with ch 966 + ch 967 — full pipeline

import XCTest
@testable import BASMemory

final class BASChapter968PersonaSovereignClampTests:
    XCTestCase
{

    // MARK: - 1. Identity + HIGH = no-op fast path

    func testIdentityHighTierNoOp() {
        let p = persona(visibility: .high, skepticism: 0.3)
        let (out, outcome) =
            BASAgentPersonaSovereignClamp.apply(
                to: p,
                sovereign: .identity,
                role: .planner)
        XCTAssertEqual(out, p,
            "ch 968: identity + HIGH = no-op fast path")
        XCTAssertFalse(outcome.didClamp)
        XCTAssertFalse(outcome.lockdownApplied)
    }

    // MARK: - 2. LOW WITHOUT warrant → force-default

    func testLowTierWithoutWarrantForceDefaults() {
        // LOW agent with "softened" persona (someone tried to
        // make sentinel warm + low-skepticism via host overlay
        // back at ch 966)。 Sovereign ch 968 must force-default
        // because no warrant accompanies it。
        let p = persona(
            visibility: .low,
            tone: "warm",      // softened from template "formal"
            warmth: 0.85,      // softened from 0.10
            skepticism: 0.20,  // softened from 1.00
            guardBias: 0.10)   // softened from 1.00
        let (out, outcome) =
            BASAgentPersonaSovereignClamp.apply(
                to: p,
                sovereign: .identity,
                role: .sovereignSentinel)
        let t = BASAgentPersonaRoleTemplates
            .templates[.sovereignSentinel]!
        XCTAssertEqual(out.tone, t.tone,
            "ch 968 CRITICAL: LOW-tier tone force-defaulted")
        XCTAssertEqual(
            out.warmth, t.warmth, accuracy: 0.0001,
            "ch 968 CRITICAL: LOW-tier warmth force-defaulted")
        XCTAssertEqual(
            out.skepticism, t.skepticism, accuracy: 0.0001,
            "ch 968 CRITICAL: LOW-tier skepticism force-defaulted " +
            "(was 0.20 — sovereign agent can NEVER be 0.20 skeptical)")
        XCTAssertEqual(
            out.guardBias, t.guardBias, accuracy: 0.0001)
        XCTAssertTrue(outcome.didClamp)
        XCTAssertTrue(outcome.auditNotes.contains {
            $0.contains("sovereign.no-warrant")
        })
    }

    // MARK: - 3. LOW WITH partial warrant — only granted fields survive

    func testLowTierPartialWarrantToneOnly() {
        let p = persona(
            visibility: .low,
            tone: "warm",
            skepticism: 0.20,
            guardBias: 0.20)
        let warrant = BASAgentPersonaSovereignWarrant(
            warrantID: "w1",
            grantedFields: ["tone"],
            reason: "clinical-warm-tone-ward-setting")
        let (out, outcome) =
            BASAgentPersonaSovereignClamp.apply(
                to: p,
                sovereign: BASAgentPersonaSovereignContext(
                    warrant: warrant),
                role: .sovereignSentinel)
        let t = BASAgentPersonaRoleTemplates
            .templates[.sovereignSentinel]!
        XCTAssertEqual(out.tone, "warm",
            "ch 968: warrant granted tone — survives clamp")
        XCTAssertEqual(
            out.skepticism, t.skepticism, accuracy: 0.0001,
            "ch 968 CRITICAL: warrant did NOT grant skepticism — " +
            "force-defaulted despite warrant being present")
        XCTAssertEqual(
            out.guardBias, t.guardBias, accuracy: 0.0001)
        XCTAssertTrue(outcome.auditNotes.contains {
            $0.contains("sovereign.warrant:w1")
        })
    }

    // MARK: - 4. LOW WITH full warrant — full overlay survives

    func testLowTierFullWarrantAllFieldsSurvive() {
        let p = persona(
            visibility: .low,
            tone: "warm",
            warmth: 0.85,
            directness: 0.30,
            skepticism: 0.40,
            structure: 0.30,
            creativity: 0.60,
            challenge: 0.40,
            comparison: 0.50,
            guardBias: 0.45)
        let warrant = BASAgentPersonaSovereignWarrant(
            warrantID: "w-full",
            grantedFields: [
                "tone", "warmth", "directness",
                "skepticism", "structureBias",
                "creativityBias", "challengeIntensity",
                "comparisonBias", "guardBias",
            ])
        let (out, _) =
            BASAgentPersonaSovereignClamp.apply(
                to: p,
                sovereign: BASAgentPersonaSovereignContext(
                    warrant: warrant),
                role: .sovereignSentinel)
        XCTAssertEqual(out, p,
            "ch 968: full warrant → LOW overlay fully survives")
    }

    // MARK: - 5. LOCKDOWN HIGH tier force-defaults

    func testLockdownHighTierForceDefaults() {
        let p = persona(
            visibility: .high,
            skepticism: 0.30,
            challenge: 0.90,
            guardBias: 0.30)
        let sovereign = BASAgentPersonaSovereignContext(
            lockdownTurn: true)
        let (out, outcome) =
            BASAgentPersonaSovereignClamp.apply(
                to: p,
                sovereign: sovereign,
                role: .planner)
        let t = BASAgentPersonaRoleTemplates
            .templates[.planner]!
        XCTAssertEqual(
            out.skepticism, t.skepticism, accuracy: 0.0001,
            "ch 968 CRITICAL: lockdown force-defaults HIGH-tier " +
            "skepticism (no agent deviates during lockdown)")
        XCTAssertEqual(
            out.challengeIntensity, t.challengeIntensity,
            accuracy: 0.0001)
        XCTAssertEqual(
            out.guardBias, t.guardBias, accuracy: 0.0001)
        XCTAssertTrue(outcome.lockdownApplied)
        XCTAssertTrue(outcome.auditNotes.contains {
            $0.contains("sovereign.lockdown")
        })
    }

    // MARK: - 6 + 7. LOCKDOWN MED + LOW tier force-defaults

    func testLockdownMedTierForceDefaults() {
        let p = persona(
            visibility: .medium,
            warmth: 0.90,
            skepticism: 0.20)
        let (out, outcome) =
            BASAgentPersonaSovereignClamp.apply(
                to: p,
                sovereign: BASAgentPersonaSovereignContext(
                    lockdownTurn: true),
                role: .hostAlignment)
        let t = BASAgentPersonaRoleTemplates
            .templates[.hostAlignment]!
        XCTAssertEqual(out.warmth, t.warmth, accuracy: 0.0001)
        XCTAssertEqual(
            out.skepticism, t.skepticism, accuracy: 0.0001)
        XCTAssertTrue(outcome.lockdownApplied)
    }

    func testLockdownLowTierForceDefaults() {
        let p = persona(
            visibility: .low,
            tone: "warm",
            warmth: 0.99)
        let (out, _) =
            BASAgentPersonaSovereignClamp.apply(
                to: p,
                sovereign: BASAgentPersonaSovereignContext(
                    lockdownTurn: true),
                role: .sovereignSentinel)
        let t = BASAgentPersonaRoleTemplates
            .templates[.sovereignSentinel]!
        XCTAssertEqual(out.tone, t.tone)
        XCTAssertEqual(out.warmth, t.warmth, accuracy: 0.0001)
    }

    // MARK: - 8. LOCKDOWN warrant IGNORED

    func testLockdownOverridesWarrant() {
        let p = persona(
            visibility: .low, tone: "warm", warmth: 0.90)
        let warrant = BASAgentPersonaSovereignWarrant(
            warrantID: "w1",
            grantedFields: ["tone", "warmth"])
        let (out, outcome) =
            BASAgentPersonaSovereignClamp.apply(
                to: p,
                sovereign: BASAgentPersonaSovereignContext(
                    lockdownTurn: true, warrant: warrant),
                role: .sovereignSentinel)
        let t = BASAgentPersonaRoleTemplates
            .templates[.sovereignSentinel]!
        XCTAssertEqual(out.tone, t.tone,
            "ch 968 CRITICAL: lockdown OVERRIDES warrant (no " +
            "warrant survives lockdown per Root Law 4)")
        XCTAssertEqual(out.warmth, t.warmth, accuracy: 0.0001)
        XCTAssertTrue(outcome.lockdownApplied)
    }

    // MARK: - 9. Heightened protection caps creativity 0.30

    func testHeightenedProtectionCapsCreativity() {
        let p = persona(
            visibility: .high, creativity: 0.95)
        let (out, outcome) =
            BASAgentPersonaSovereignClamp.apply(
                to: p,
                sovereign: BASAgentPersonaSovereignContext(
                    heightenedProtection: true),
                role: .planner)
        XCTAssertEqual(
            out.creativityBias, 0.30, accuracy: 0.0001,
            "ch 968: heightened protection caps creativity at 0.30 " +
            "(prevent novel candidates in vulnerable state)")
        XCTAssertTrue(outcome.auditNotes.contains {
            $0.contains("sovereign.cap.creativity") &&
            $0.contains("heightened-protection")
        })
    }

    // MARK: - 10. Heightened protection caps challenge 0.30

    func testHeightenedProtectionCapsChallenge() {
        let p = persona(
            visibility: .high, challenge: 0.95)
        let (out, _) =
            BASAgentPersonaSovereignClamp.apply(
                to: p,
                sovereign: BASAgentPersonaSovereignContext(
                    heightenedProtection: true),
                role: .planner)
        XCTAssertEqual(
            out.challengeIntensity, 0.30, accuracy: 0.0001)
    }

    // MARK: - 11. Heightened protection: skepticism/guard untouched

    func testHeightenedProtectionLeavesDefensiveBiasesAlone() {
        let p = persona(
            visibility: .high,
            skepticism: 0.90,
            guardBias: 0.90)
        let (out, _) =
            BASAgentPersonaSovereignClamp.apply(
                to: p,
                sovereign: BASAgentPersonaSovereignContext(
                    heightenedProtection: true),
                role: .planner)
        XCTAssertEqual(
            out.skepticism, 0.90, accuracy: 0.0001,
            "ch 968: heightened protection does NOT touch " +
            "skepticism (Risk arm at ch 967 handles that)")
        XCTAssertEqual(
            out.guardBias, 0.90, accuracy: 0.0001)
    }

    // MARK: - 12. CRITICAL fuzz: LOW tier never softer than template

    func testCRITICAL_LowTierNeverSofterThanTemplateNoWarrant() {
        // 1000 random LOW-tier personas with attempted softening
        // → output MUST match template (no exceptions without
        // warrant)
        for seed in 0..<1000 {
            let f = Double((seed * 1103515245 + 12345)
                % 1_000_000) / 1_000_000.0
            let p = persona(
                visibility: .low,
                warmth: f,
                directness: 1.0 - f,
                skepticism: f,
                creativity: 1.0 - f,
                challenge: f,
                guardBias: f)
            let (out, _) =
                BASAgentPersonaSovereignClamp.apply(
                    to: p,
                    sovereign: .identity,
                    role: .sovereignSentinel)
            let t = BASAgentPersonaRoleTemplates
                .templates[.sovereignSentinel]!
            XCTAssertEqual(out.warmth, t.warmth, accuracy: 0.0001,
                "ch 968 CRITICAL FUZZ: LOW warmth force-default " +
                "broken at seed=\(seed) (got \(out.warmth) " +
                "vs template \(t.warmth))")
            XCTAssertEqual(
                out.skepticism, t.skepticism, accuracy: 0.0001,
                "ch 968 CRITICAL FUZZ: LOW skepticism broken at " +
                "seed=\(seed)")
            XCTAssertEqual(
                out.guardBias, t.guardBias, accuracy: 0.0001)
        }
    }

    // MARK: - 13. Audit notes deterministic + sorted

    func testAuditNotesDeterministicallySorted() {
        let p = persona(
            visibility: .low, tone: "warm", warmth: 0.5)
        let sovereign = BASAgentPersonaSovereignContext(
            warrant: BASAgentPersonaSovereignWarrant(
                warrantID: "w1"))
        let (_, o1) =
            BASAgentPersonaSovereignClamp.apply(
                to: p, sovereign: sovereign,
                role: .sovereignSentinel)
        let (_, o2) =
            BASAgentPersonaSovereignClamp.apply(
                to: p, sovereign: sovereign,
                role: .sovereignSentinel)
        XCTAssertEqual(o1, o2,
            "ch 968: same input → byte-equal outcome " +
            "(trace replay invariant)")
        XCTAssertEqual(
            o1.auditNotes.sorted(), o1.auditNotes,
            "ch 968: audit notes MUST be sorted")
    }

    // MARK: - 14. lockdownApplied flag matches input

    func testLockdownAppliedFlagMatchesInput() {
        for lockdown in [true, false] {
            let p = persona(visibility: .high)
            let (_, outcome) =
                BASAgentPersonaSovereignClamp.apply(
                    to: p,
                    sovereign:
                        BASAgentPersonaSovereignContext(
                            lockdownTurn: lockdown),
                    role: .planner)
            XCTAssertEqual(
                outcome.lockdownApplied, lockdown,
                "ch 968: lockdownApplied flag MUST equal " +
                "input.lockdownTurn (caller depends on this)")
        }
    }

    // MARK: - 15. Full pipeline integration: ch 966 + 967 + 968

    func testFullPipeline_ResolverPlusRiskPlusSovereign() {
        let spec = BASAgentSpec(
            agentID: "planner.1", role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        // Step 1:resolve (ch 966)
        let p1 = BASAgentPersonaResolver.resolve(
            agentSpec: spec, personaID: "p1")
        // Step 2:Risk clamp (ch 967)
        let (p2, riskOut) =
            BASAgentPersonaRiskClamp.apply(
                to: p1,
                risk: BASAgentPersonaRiskContext(
                    skepticismFloor: 0.7))
        XCTAssertEqual(
            p2.skepticism, 0.7, accuracy: 0.0001,
            "ch 967 risk floor raised skepticism")
        // Step 3:Sovereign clamp (ch 968) — heightened protection
        let (p3, sovOut) =
            BASAgentPersonaSovereignClamp.apply(
                to: p2,
                sovereign: BASAgentPersonaSovereignContext(
                    heightenedProtection: true),
                role: .planner)
        XCTAssertEqual(
            p3.creativityBias, 0.30, accuracy: 0.0001,
            "ch 968 sovereign capped creativity at 0.30 (heightened)")
        XCTAssertEqual(
            p3.skepticism, 0.7, accuracy: 0.0001,
            "ch 968 sovereign DID NOT lower the risk-raised " +
            "skepticism — full chain preserves monotonic raise")
        XCTAssertTrue(riskOut.didClamp)
        XCTAssertTrue(sovOut.didClamp)
    }

    // MARK: - 16. Warrant helpers

    func testWarrantGrantsField() {
        let w = BASAgentPersonaSovereignWarrant(
            warrantID: "w",
            grantedFields: ["tone", "warmth"])
        XCTAssertTrue(w.grants("tone"))
        XCTAssertTrue(w.grants("warmth"))
        XCTAssertFalse(w.grants("skepticism"))
    }

    func testWarrantGrantsFieldsSorted() {
        let w = BASAgentPersonaSovereignWarrant(
            warrantID: "w",
            grantedFields: ["warmth", "tone"])
        XCTAssertEqual(w.grantedFields, ["tone", "warmth"],
            "ch 968: warrant fields auto-sorted for deterministic " +
            "fingerprint")
    }

    // MARK: - Helpers

    private func persona(
        visibility: BASAgentVisibility = .high,
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
            visibility: visibility,
            hostConstraintsRef: "",
            riskConstraintsRef: "",
            sovereignConstraintsRef: "",
            versionRef: "")
    }
}
