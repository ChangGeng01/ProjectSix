// MARK: - BASChapter966PersonaResolverTests
// chapter 九百六十六 / M3535 — Phase 4 ch1 tests:Persona Studio kickoff
//
// Test scope:
//   1. Role templates registry — count + content pin
//   2. All 9 core roles have explicit templates (no fallback fallthrough)
//   3. LOW-tier templates are sealed-default-shaped (skeptical / guarded)
//   4. Template visibility matches agent role design
//   5. Resolver pure-fn determinism (same input → same output)
//   6. Resolver applies role template by default (no overlay)
//   7. HIGH tier:userOverlay fully applied
//   8. MED tier:userOverlay ONLY tone+warmth+directness applied
//   9. LOW tier:userOverlay IGNORED entirely (sovereign-sealed)
//   10. hostOverlay applies on TOP of user overlay (host wins ties)
//   11. hostOverlay applies for all tiers (sovereign-authorized)
//   12. Clamp invariant — out-of-bound values pinned to [0,1]
//   13. NaN policy — NaN biases collapse to 0.5 (neutral middle)
//   14. Fallback path for non-templated roles (e.g. watchers)
//   15. Composition order: role → user → host (host last)
//   16. agentSpec.visibility wins over template visibility (drift defense)

import XCTest
@testable import BASMemory

final class BASChapter966PersonaResolverTests: XCTestCase {

    // MARK: - 1. Template registry pin

    func testTemplateCountIs12() {
        XCTAssertEqual(
            BASAgentPersonaRoleTemplates.templates.count, 12,
            "ch 966: template registry MUST have exactly 12 " +
            "templates (5 HIGH + 3 MED + 4 LOW per plan)")
        XCTAssertEqual(
            BASAgentPersonaRoleTemplates
                .expectedTemplateCount, 12)
    }

    func testHighTierTemplatesPresent() {
        let highRoles: [BASAgentRole] = [
            .planner, .critic, .memory, .risk, .surface]
        for role in highRoles {
            let t = BASAgentPersonaRoleTemplates
                .templates[role]
            XCTAssertNotNil(t,
                "ch 966: HIGH-tier role \(role) MUST have " +
                "explicit template")
            XCTAssertEqual(t?.visibility, .high,
                "ch 966: \(role) template visibility MUST be .high")
        }
    }

    func testMediumTierTemplatesPresent() {
        let medRoles: [BASAgentRole] = [
            .hostAlignment, .evolutionShadow, .scout]
        for role in medRoles {
            let t = BASAgentPersonaRoleTemplates
                .templates[role]
            XCTAssertNotNil(t)
            XCTAssertEqual(t?.visibility, .medium,
                "ch 966: \(role) MUST be MED tier")
        }
    }

    func testLowTierTemplatesPresent() {
        let lowRoles: [BASAgentRole] = [
            .sovereignSentinel, .actionPermit,
            .deleteRollbackSeal, .memorySeal]
        for role in lowRoles {
            let t = BASAgentPersonaRoleTemplates
                .templates[role]
            XCTAssertNotNil(t)
            XCTAssertEqual(t?.visibility, .low,
                "ch 966: \(role) MUST be LOW tier (sealed)")
        }
    }

    // MARK: - 2. LOW-tier sealed-default shape

    func testLowTierTemplatesAreSkepticalAndGuarded() {
        // LOW tier sealed-default agents enforce sovereign — so
        // their persona defaults MUST be high-skepticism +
        // high-guard + low-warmth + low-creativity
        let lowRoles: [BASAgentRole] = [
            .sovereignSentinel, .actionPermit,
            .deleteRollbackSeal, .memorySeal]
        for role in lowRoles {
            let t = BASAgentPersonaRoleTemplates
                .templates[role]!
            XCTAssertGreaterThanOrEqual(
                t.skepticism, 0.85,
                "ch 966: LOW-tier \(role) skepticism MUST be ≥ 0.85")
            XCTAssertGreaterThanOrEqual(
                t.guardBias, 0.85,
                "ch 966: LOW-tier \(role) guard MUST be ≥ 0.85")
            XCTAssertLessThanOrEqual(
                t.warmth, 0.20,
                "ch 966: LOW-tier \(role) warmth MUST be ≤ 0.20 " +
                "(sovereign agents stay cool)")
            XCTAssertLessThanOrEqual(
                t.creativityBias, 0.05,
                "ch 966: LOW-tier \(role) creativity MUST be " +
                "near-zero (sealed roles don't improvise)")
        }
    }

    func testCriticTemplateHasHighSkepticism() {
        // Critic is the high-skepticism HIGH-tier agent
        let critic = BASAgentPersonaRoleTemplates
            .templates[.critic]!
        XCTAssertGreaterThanOrEqual(
            critic.skepticism, 0.7,
            "ch 966: Critic skepticism default MUST be ≥ 0.7 " +
            "(superego discipline)")
        XCTAssertGreaterThanOrEqual(
            critic.directness, 0.7,
            "ch 966: Critic directness default MUST be ≥ 0.7")
    }

    func testSurfaceTemplateIsWarmer() {
        // Surface is the user-facing seat — warmer than Critic
        let surface = BASAgentPersonaRoleTemplates
            .templates[.surface]!
        XCTAssertGreaterThanOrEqual(surface.warmth, 0.5)
    }

    // MARK: - 3. Determinism

    func testResolverDeterministicForSameInput() {
        let spec = makeAgent(role: .planner, vis: .high)
        let p1 = BASAgentPersonaResolver.resolve(
            agentSpec: spec, personaID: "p1")
        let p2 = BASAgentPersonaResolver.resolve(
            agentSpec: spec, personaID: "p1")
        XCTAssertEqual(p1, p2,
            "ch 966: same input MUST produce byte-equal output " +
            "(trace replay invariant)")
    }

    // MARK: - 4. Role template default (no overlay)

    func testResolverNoOverlayMatchesTemplate() {
        let spec = makeAgent(role: .planner, vis: .high)
        let p = BASAgentPersonaResolver.resolve(
            agentSpec: spec, personaID: "p1")
        let t = BASAgentPersonaRoleTemplates
            .templates[.planner]!
        XCTAssertEqual(p.tone, t.tone)
        XCTAssertEqual(p.warmth, t.warmth, accuracy: 0.0001)
        XCTAssertEqual(
            p.skepticism, t.skepticism, accuracy: 0.0001)
        XCTAssertEqual(p.agentID, spec.agentID)
        XCTAssertEqual(p.personaID, "p1")
    }

    // MARK: - 5. HIGH tier — full user overlay

    func testHighTier_FullUserOverlayApplied() {
        let spec = makeAgent(role: .planner, vis: .high)
        let user = userPersona(
            tone: "warm", warmth: 0.95, directness: 0.10,
            skepticism: 0.95, creativityBias: 0.85,
            challengeIntensity: 0.99)
        let p = BASAgentPersonaResolver.resolve(
            agentSpec: spec,
            userOverlay: user,
            personaID: "p1")
        // All fields from user overlay applied
        XCTAssertEqual(p.tone, "warm")
        XCTAssertEqual(p.warmth, 0.95, accuracy: 0.0001)
        XCTAssertEqual(p.directness, 0.10, accuracy: 0.0001)
        XCTAssertEqual(p.skepticism, 0.95, accuracy: 0.0001)
        XCTAssertEqual(
            p.creativityBias, 0.85, accuracy: 0.0001)
        XCTAssertEqual(
            p.challengeIntensity, 0.99, accuracy: 0.0001)
    }

    // MARK: - 6. MED tier — partial overlay (style + cadence only)

    func testMedTier_OnlyStyleFieldsApplied() {
        let spec = makeAgent(
            role: .hostAlignment, vis: .medium)
        let user = userPersona(
            tone: "warm", warmth: 0.95, directness: 0.10,
            skepticism: 0.99,   // SHOULD be ignored
            creativityBias: 0.99,  // SHOULD be ignored
            challengeIntensity: 0.99)  // SHOULD be ignored
        let p = BASAgentPersonaResolver.resolve(
            agentSpec: spec,
            userOverlay: user,
            personaID: "p1")
        // Style fields APPLIED
        XCTAssertEqual(p.tone, "warm",
            "ch 966 MED: tone MUST be applied from user overlay")
        XCTAssertEqual(p.warmth, 0.95, accuracy: 0.0001,
            "ch 966 MED: warmth MUST be applied")
        XCTAssertEqual(p.directness, 0.10, accuracy: 0.0001,
            "ch 966 MED: directness MUST be applied")
        // Cognitive biases NOT applied (still template values)
        let t = BASAgentPersonaRoleTemplates
            .templates[.hostAlignment]!
        XCTAssertEqual(
            p.skepticism, t.skepticism, accuracy: 0.0001,
            "ch 966 MED CRITICAL: skepticism MUST stay at " +
            "role-template value (user overlay rejected for " +
            "MED-tier cognitive biases)")
        XCTAssertEqual(
            p.creativityBias, t.creativityBias,
            accuracy: 0.0001,
            "ch 966 MED CRITICAL: creativity MUST stay at " +
            "template")
        XCTAssertEqual(
            p.challengeIntensity, t.challengeIntensity,
            accuracy: 0.0001,
            "ch 966 MED CRITICAL: challenge MUST stay at " +
            "template")
    }

    // MARK: - 7. LOW tier — user overlay IGNORED entirely

    func testLowTier_UserOverlayCompletelyIgnored() {
        let spec = makeAgent(
            role: .sovereignSentinel, vis: .low)
        let user = userPersona(
            tone: "warm",  // tries to soften sentinel
            warmth: 0.95,
            directness: 0.10,
            skepticism: 0.10,  // tries to lower skepticism
            creativityBias: 0.95,
            challengeIntensity: 0.95,
            guardBias: 0.05)  // tries to remove guard
        let p = BASAgentPersonaResolver.resolve(
            agentSpec: spec,
            userOverlay: user,
            personaID: "p1")
        // ALL fields stay at template (user overlay sealed off)
        let t = BASAgentPersonaRoleTemplates
            .templates[.sovereignSentinel]!
        XCTAssertEqual(p.tone, t.tone,
            "ch 966 LOW CRITICAL: tone MUST stay sealed " +
            "(no user override allowed)")
        XCTAssertEqual(
            p.warmth, t.warmth, accuracy: 0.0001,
            "ch 966 LOW CRITICAL: warmth MUST stay sealed")
        XCTAssertEqual(
            p.skepticism, t.skepticism, accuracy: 0.0001,
            "ch 966 LOW CRITICAL: skepticism MUST stay sealed " +
            "(any user attempt to lower sovereign skepticism is " +
            "a Root Law 4 violation)")
        XCTAssertEqual(
            p.guardBias, t.guardBias, accuracy: 0.0001,
            "ch 966 LOW CRITICAL: guard MUST stay sealed")
        XCTAssertEqual(
            p.challengeIntensity, t.challengeIntensity,
            accuracy: 0.0001,
            "ch 966 LOW CRITICAL: challenge MUST stay sealed")
    }

    // MARK: - 8. Host overlay precedence

    func testHostOverlay_WinsOverUserOverlay() {
        let spec = makeAgent(role: .planner, vis: .high)
        let user = userPersona(
            warmth: 0.20, directness: 0.40)
        let host = userPersona(
            warmth: 0.80, directness: 0.95)
        let p = BASAgentPersonaResolver.resolve(
            agentSpec: spec,
            userOverlay: user,
            hostOverlay: host,
            personaID: "p1")
        // Host overlay wins
        XCTAssertEqual(
            p.warmth, 0.80, accuracy: 0.0001,
            "ch 966: host overlay MUST win over user overlay " +
            "(host is sovereign per Root Law 1)")
        XCTAssertEqual(
            p.directness, 0.95, accuracy: 0.0001)
    }

    func testHostOverlay_AppliesForAllTiers() {
        // Host can override for LOW tier too (going through
        // sovereign-authorized paths is the host's prerogative —
        // ch 968 will add the warrant gate)
        for tier in [BASAgentVisibility.high,
                     .medium, .low] {
            let spec = makeAgent(
                role: .sovereignSentinel, vis: tier)
            let host = userPersona(warmth: 0.55)
            let p = BASAgentPersonaResolver.resolve(
                agentSpec: spec,
                hostOverlay: host,
                personaID: "p1")
            XCTAssertEqual(
                p.warmth, 0.55, accuracy: 0.0001,
                "ch 966: host overlay MUST apply at tier \(tier)")
        }
    }

    // MARK: - 9. Clamp invariant

    func testClampInvariant_OutOfBoundsValuesPinned() {
        let spec = makeAgent(role: .planner, vis: .high)
        let user = userPersona(
            warmth: 5.0,         // out of bound HIGH
            directness: -3.0,    // out of bound LOW
            skepticism: 1e10,    // huge
            creativityBias: -1.0,
            challengeIntensity: 100.0)
        let p = BASAgentPersonaResolver.resolve(
            agentSpec: spec,
            userOverlay: user,
            personaID: "p1")
        XCTAssertEqual(p.warmth, 1.0, accuracy: 0.0001,
            "ch 966: warmth 5.0 → clamped to 1.0")
        XCTAssertEqual(
            p.directness, 0.0, accuracy: 0.0001,
            "ch 966: directness -3.0 → clamped to 0.0")
        XCTAssertEqual(
            p.skepticism, 1.0, accuracy: 0.0001)
        XCTAssertEqual(
            p.creativityBias, 0.0, accuracy: 0.0001)
        XCTAssertEqual(
            p.challengeIntensity, 1.0, accuracy: 0.0001)
    }

    // MARK: - 10. NaN policy

    func testNaNCollapseToHalf() {
        let spec = makeAgent(role: .planner, vis: .high)
        let user = userPersona(
            warmth: Double.nan,
            directness: Double.nan,
            skepticism: Double.nan)
        let p = BASAgentPersonaResolver.resolve(
            agentSpec: spec,
            userOverlay: user,
            personaID: "p1")
        XCTAssertEqual(
            p.warmth, 0.5, accuracy: 0.0001,
            "ch 966 NaN: warmth=NaN → 0.5 (neutral middle)")
        XCTAssertEqual(
            p.directness, 0.5, accuracy: 0.0001)
        XCTAssertEqual(
            p.skepticism, 0.5, accuracy: 0.0001)
        XCTAssertFalse(p.warmth.isNaN,
            "ch 966 NaN: resolved persona MUST NEVER have NaN " +
            "biases (downstream consumers crash on NaN math)")
    }

    // MARK: - 11. Fallback for non-templated roles

    func testFallback_NonTemplatedRoleHasSafeDefaults() {
        // anomalyWatcher has no template — should hit fallback
        let spec = makeAgent(
            role: .anomalyWatcher, vis: .medium)
        let p = BASAgentPersonaResolver.resolve(
            agentSpec: spec, personaID: "p1")
        // Fallback is neutral middle (0.5 across all biases)
        XCTAssertEqual(p.tone, "neutral")
        XCTAssertEqual(p.warmth, 0.5, accuracy: 0.0001)
        XCTAssertEqual(p.directness, 0.5, accuracy: 0.0001)
        XCTAssertEqual(p.skepticism, 0.5, accuracy: 0.0001)
        XCTAssertEqual(
            p.guardBias, 0.5, accuracy: 0.0001)
    }

    // MARK: - 12. Visibility drift defense

    func testAgentSpecVisibilityWinsOverTemplate() {
        // If a host registers a Planner with LOW visibility
        // (unusual but allowed) the resolver MUST trust the
        // agentSpec visibility, not the template (defensive
        // against template drift)
        let spec = makeAgent(role: .planner, vis: .low)
        let user = userPersona(
            warmth: 0.95, challengeIntensity: 0.99)
        let p = BASAgentPersonaResolver.resolve(
            agentSpec: spec,
            userOverlay: user,
            personaID: "p1")
        XCTAssertEqual(p.visibility, .low,
            "ch 966 CRITICAL: agentSpec.visibility wins over " +
            "template (defensive)")
        // LOW behavior: user overlay ignored entirely
        let t = BASAgentPersonaRoleTemplates
            .templates[.planner]!
        XCTAssertEqual(
            p.warmth, t.warmth, accuracy: 0.0001,
            "ch 966: agentSpec vis=.low → user warmth ignored")
        XCTAssertEqual(
            p.challengeIntensity, t.challengeIntensity,
            accuracy: 0.0001,
            "ch 966: agentSpec vis=.low → user challenge ignored")
    }

    // MARK: - 13. Composition order proof

    func testCompositionOrder_RoleThenUserThenHost() {
        // Three different warmth values across template / user /
        // host — verify host wins (last in chain)
        let spec = makeAgent(role: .planner, vis: .high)
        let user = userPersona(warmth: 0.30)
        let host = userPersona(warmth: 0.70)
        let p = BASAgentPersonaResolver.resolve(
            agentSpec: spec,
            userOverlay: user,
            hostOverlay: host,
            personaID: "p1")
        XCTAssertEqual(
            p.warmth, 0.70, accuracy: 0.0001,
            "ch 966: composition order role→user→host means " +
            "host wins (host applied last)")
    }

    func testCompositionOrder_NilOverlaysFallThrough() {
        // Only template applies when both overlays nil
        let spec = makeAgent(role: .critic, vis: .high)
        let p = BASAgentPersonaResolver.resolve(
            agentSpec: spec,
            userOverlay: nil,
            hostOverlay: nil,
            personaID: "p1")
        let t = BASAgentPersonaRoleTemplates
            .templates[.critic]!
        XCTAssertEqual(
            p.skepticism, t.skepticism, accuracy: 0.0001)
        XCTAssertEqual(p.tone, t.tone)
    }

    // MARK: - 14. Ref pass-through

    func testRefPassThrough() {
        let spec = makeAgent(role: .planner, vis: .high)
        let p = BASAgentPersonaResolver.resolve(
            agentSpec: spec,
            hostConstraintsRef: "hostConstitution:h1:v3",
            riskConstraintsRef: "riskGate:rg1:v2",
            sovereignConstraintsRef: "sovereignSentinel:ss1",
            personaID: "p1",
            versionRef: "personaVersion:pv1")
        XCTAssertEqual(p.hostConstraintsRef,
            "hostConstitution:h1:v3")
        XCTAssertEqual(p.riskConstraintsRef,
            "riskGate:rg1:v2")
        XCTAssertEqual(p.sovereignConstraintsRef,
            "sovereignSentinel:ss1")
        XCTAssertEqual(p.versionRef, "personaVersion:pv1")
    }

    // MARK: - 15. All 20 BASAgentRole cases handled

    func testEveryRoleResolves() {
        // Defensive: every BASAgentRole.allCases case must
        // resolve successfully (templated OR fallback path)
        for role in BASAgentRole.allCases {
            let spec = makeAgent(role: role, vis: .medium)
            let p = BASAgentPersonaResolver.resolve(
                agentSpec: spec, personaID: "p")
            // No assertion on specific values — just no crash +
            // valid output spec
            XCTAssertFalse(p.warmth.isNaN,
                "ch 966: role \(role) MUST resolve cleanly")
            XCTAssertGreaterThanOrEqual(p.warmth, 0.0)
            XCTAssertLessThanOrEqual(p.warmth, 1.0)
        }
    }

    // MARK: - 16. Tone field unaffected by clamp (string)

    func testTonePassThrough() {
        let spec = makeAgent(role: .planner, vis: .high)
        let user = userPersona(tone: "playful")
        let p = BASAgentPersonaResolver.resolve(
            agentSpec: spec,
            userOverlay: user,
            personaID: "p1")
        XCTAssertEqual(p.tone, "playful")
    }

    // MARK: - Helpers

    private func makeAgent(
        role: BASAgentRole,
        vis: BASAgentVisibility
    ) -> BASAgentSpec {
        BASAgentSpec(
            agentID: "agent.\(role.rawValue).1",
            role: role,
            writeDomains: [],
            defaultLeaseProfile: .hotSeat,
            visibility: vis)
    }

    private func userPersona(
        tone: String = "neutral",
        warmth: Double = 0.5,
        directness: Double = 0.5,
        skepticism: Double = 0.5,
        structureBias: Double = 0.5,
        creativityBias: Double = 0.5,
        challengeIntensity: Double = 0.5,
        comparisonBias: Double = 0.5,
        guardBias: Double = 0.5
    ) -> BASAgentPersonaSpec {
        BASAgentPersonaSpec(
            personaID: "user-persona",
            agentID: "ignored-here",
            tone: tone,
            warmth: warmth,
            directness: directness,
            skepticism: skepticism,
            structureBias: structureBias,
            creativityBias: creativityBias,
            challengeIntensity: challengeIntensity,
            comparisonBias: comparisonBias,
            guardBias: guardBias,
            visibility: .high,
            hostConstraintsRef: "",
            riskConstraintsRef: "",
            sovereignConstraintsRef: "",
            versionRef: "")
    }
}
