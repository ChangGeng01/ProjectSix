// MARK: - BASChapter969_5UserPass6Tests
// chapter 九百六十九.5 / M3550.5 — USER-PASS-6 regression tests
//
// Per N-pass discipline (6th review cycle on ch 966-969 batch),
// catches 2 CRITICAL + 1 CRITICAL-GAP + 4 HIGH + 1 doc-HIGH +
// 2 doc-MED。 This file pins the regression tests for the fixes
// landed in this sub-chapter so the bugs cannot return。
//
// Fixes covered:
//   - CG1: SDK output validation now exempts LOW-tier
//          (sovereignty crisis avoidance)
//   - C1: Sovereign clamp LOW-tier emits per-field audit notes
//         even when value equals template (INV8 audit invariant)
//   - C2: Risk clamp NaN audit trail (INV5 + INV8 joint invariant)
//   - H2: SDK validateOverlays preserves evidence UNION across
//         user + host overlays with source tagging
//   - H3: Lockdown emits per-field audit notes (not just scope marker)
//   - H4: AbsolutePaternal pattern requires AND (warm-tone AND
//         high-warmth),not OR (false-positive fix)

import XCTest
@testable import BASMemory

final class BASChapter969_5UserPass6Tests: XCTestCase {

    // MARK: - CG1 regression: SDK exempts LOW tier from output validation

    func testCG1_LowTierSDKResolveAcceptsSentinelTemplate() {
        // sovereignSentinel template has skepticism=1.0,
        // directness=1.0, warmth=0.10, comparison=0.0 — matches
        // gaslight + controlling forbidden patterns。 Before
        // CG1 fix the SDK output validation would REJECT the
        // sovereign-blessed template itself — sovereignty crisis。
        let spec = BASAgentSpec(
            agentID: "sentinel.1",
            role: .sovereignSentinel,
            writeDomains: [.sovereignVerdict],
            defaultLeaseProfile: .sovereign,
            visibility: .low)
        let result = BASAgentPersonaSDK.resolve(
            BASAgentPersonaResolveRequest(
                agentSpec: spec,
                personaID: "p"))
        XCTAssertFalse(result.rejected,
            "ch 969.5 CG1: LOW-tier sovereignSentinel template " +
            "MUST NOT be rejected — sovereignty crisis avoided")
        XCTAssertNotNil(result.persona,
            "ch 969.5 CG1: LOW-tier persona MUST be returned")
        let t = BASAgentPersonaRoleTemplates
            .templates[.sovereignSentinel]!
        XCTAssertEqual(
            result.persona!.skepticism, t.skepticism,
            accuracy: 0.0001)
    }

    func testCG1_AllFourLowTierRolesResolveCleanlyThroughSDK() {
        // Sweep all 4 LOW-tier roles — none can be rejected
        // by SDK output validation
        let lowRoles: [BASAgentRole] = [
            .sovereignSentinel, .actionPermit,
            .deleteRollbackSeal, .memorySeal]
        for role in lowRoles {
            let spec = BASAgentSpec(
                agentID: "low.\(role.rawValue).1",
                role: role,
                writeDomains: [],
                defaultLeaseProfile: .sovereign,
                visibility: .low)
            let result = BASAgentPersonaSDK.resolve(
                BASAgentPersonaResolveRequest(
                    agentSpec: spec, personaID: "p"))
            XCTAssertFalse(result.rejected,
                "ch 969.5 CG1: LOW-tier \(role) rejected by SDK " +
                "— sovereignty crisis at template-default level")
            XCTAssertNotNil(result.persona)
        }
    }

    func testCG1_HighTierStillRejectsForbiddenComposition() {
        // CG1 fix MUST NOT regress HIGH-tier output validation。
        // HIGH-tier with forbidden host overlay STILL rejects
        // at the input-validation step (Step 1)。
        let spec = BASAgentSpec(
            agentID: "p", role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let badHost = persona(
            tone: "cool", warmth: 0.10,
            challenge: 0.85, guardBias: 0.10)
        let result = BASAgentPersonaSDK.resolve(
            BASAgentPersonaResolveRequest(
                agentSpec: spec,
                hostOverlay: badHost,
                personaID: "p"))
        XCTAssertTrue(result.rejected,
            "ch 969.5 CG1 regression-defense: HIGH-tier with " +
            "forbidden overlay STILL rejects (CG1 fix only " +
            "exempted LOW-tier at OUTPUT step)")
    }

    // MARK: - C1 regression: LOW-tier per-field audit notes

    func testC1_LowTierEmitsPerFieldCheckNote() {
        let p = persona(
            visibility: .low,
            tone: "warm",  // ← differs from template
            warmth: 0.5)
        let (_, outcome) =
            BASAgentPersonaSovereignClamp.apply(
                to: p, sovereign: .identity,
                role: .sovereignSentinel)
        // Per ch 969.5 C1: every field MUST have either a
        // sovereign.check.<field>:status note OR a
        // sovereign.force.<field>:... note
        let fields = [
            "tone", "warmth", "directness", "skepticism",
            "structureBias", "creativityBias",
            "challengeIntensity", "comparisonBias",
            "guardBias"]
        for field in fields {
            let hasNote = outcome.auditNotes.contains {
                $0.contains("sovereign.check.\(field):") ||
                $0.contains("sovereign.force.\(field):")
            }
            XCTAssertTrue(hasNote,
                "ch 969.5 C1: LOW-tier field '\(field)' MUST " +
                "emit an audit note (check or force) — INV8 " +
                "trace replay invariant")
        }
    }

    func testC1_LowTierWithWarrantGrantNote() {
        let p = persona(
            visibility: .low,
            tone: "warm")
        let warrant = BASAgentPersonaSovereignWarrant(
            warrantID: "w-tone",
            grantedFields: ["tone"])
        let (out, outcome) =
            BASAgentPersonaSovereignClamp.apply(
                to: p,
                sovereign:
                    BASAgentPersonaSovereignContext(
                        warrant: warrant),
                role: .sovereignSentinel)
        XCTAssertEqual(out.tone, "warm",
            "ch 969.5 C1: warrant-granted field survives")
        XCTAssertTrue(outcome.auditNotes.contains {
            $0.contains("sovereign.check.tone:granted")
        }, "ch 969.5 C1: granted field MUST emit explicit " +
           "'granted' audit note")
    }

    // MARK: - C2 regression: NaN audit trail in Risk clamp

    func testC2_NaNBiasEmitsAuditNote() {
        let p = persona(
            skepticism: Double.nan,
            challenge: Double.nan)
        let (out, outcome) =
            BASAgentPersonaRiskClamp.apply(
                to: p,
                risk: BASAgentPersonaRiskContext(
                    skepticismFloor: 0.0,
                    challengeCeiling: 1.0))
        XCTAssertFalse(out.skepticism.isNaN)
        XCTAssertFalse(out.challengeIntensity.isNaN)
        XCTAssertTrue(outcome.didClamp,
            "ch 969.5 C2: NaN normalization MUST set didClamp=true")
        XCTAssertTrue(outcome.auditNotes.contains {
            $0.contains("risk.nan-normalize.skepticism")
        }, "ch 969.5 C2: NaN in skepticism MUST emit audit note " +
           "(INV5 + INV8 joint invariant)")
        XCTAssertTrue(outcome.auditNotes.contains {
            $0.contains("risk.nan-normalize.challenge")
        })
    }

    func testC2_NaNAuditNotesDeterministic() {
        let p = persona(directness: Double.nan)
        let (_, o1) =
            BASAgentPersonaRiskClamp.apply(
                to: p, risk: .identity)
        let (_, o2) =
            BASAgentPersonaRiskClamp.apply(
                to: p, risk: .identity)
        XCTAssertEqual(o1.auditNotes, o2.auditNotes,
            "ch 969.5 C2: NaN audit notes deterministic for " +
            "trace replay")
    }

    // MARK: - H2 regression: validateOverlays evidence UNION

    func testH2_EvidenceUnionAcrossUserAndHostSamePattern() {
        let userShame = persona(
            tone: "cool", warmth: 0.10,
            challenge: 0.85, guardBias: 0.10)
        let hostShame = persona(
            tone: "formal", warmth: 0.05,
            challenge: 0.95, guardBias: 0.05)
        let findings = BASAgentPersonaSDK.validateOverlays(
            userOverlay: userShame,
            hostOverlay: hostShame)
        XCTAssertEqual(findings.count, 1,
            "ch 969.5 H2: still de-duped to 1 finding")
        let f = findings[0]
        XCTAssertEqual(f.pattern, .shame)
        // Evidence MUST be tagged + include both sources
        let hasUserSrc = f.evidence.contains {
            $0.hasPrefix("source=user:")
        }
        let hasHostSrc = f.evidence.contains {
            $0.hasPrefix("source=host:")
        }
        XCTAssertTrue(hasUserSrc,
            "ch 969.5 H2: evidence MUST tag source=user: " +
            "(audit trail visibility for user-supplied " +
            "forbidden overlay)")
        XCTAssertTrue(hasHostSrc,
            "ch 969.5 H2: evidence MUST tag source=host:")
        XCTAssertEqual(f.matchScore, 1.0, accuracy: 0.0001,
            "ch 969.5 H2: highest score still preserved")
    }

    func testH2_EvidenceSortedDeterministic() {
        let userShame = persona(
            tone: "cool", warmth: 0.10,
            challenge: 0.85, guardBias: 0.10)
        let hostShame = persona(
            tone: "formal", warmth: 0.05,
            challenge: 0.95, guardBias: 0.05)
        let f1 = BASAgentPersonaSDK.validateOverlays(
            userOverlay: userShame, hostOverlay: hostShame)
        let f2 = BASAgentPersonaSDK.validateOverlays(
            userOverlay: userShame, hostOverlay: hostShame)
        XCTAssertEqual(f1, f2,
            "ch 969.5 H2: validateOverlays output deterministic")
    }

    // MARK: - H3 regression: lockdown per-field audit notes

    func testH3_LockdownEmitsPerFieldNotes() {
        let p = persona(
            visibility: .high,
            warmth: 0.95,        // ← differs from planner template
            skepticism: 0.30,    // ← differs
            challenge: 0.95)     // ← differs
        let (_, outcome) =
            BASAgentPersonaSovereignClamp.apply(
                to: p,
                sovereign:
                    BASAgentPersonaSovereignContext(
                        lockdownTurn: true),
                role: .planner)
        // Scope marker still emitted
        XCTAssertTrue(outcome.auditNotes.contains {
            $0.contains("sovereign.lockdown")
        })
        // Per-field force notes emitted for each CHANGED field
        XCTAssertTrue(outcome.auditNotes.contains {
            $0.contains("sovereign.force.warmth")
        }, "ch 969.5 H3: lockdown MUST emit per-field " +
           "'sovereign.force.warmth' for changed fields")
        XCTAssertTrue(outcome.auditNotes.contains {
            $0.contains("sovereign.force.skepticism")
        })
        XCTAssertTrue(outcome.auditNotes.contains {
            $0.contains("sovereign.force.challengeIntensity")
        })
    }

    func testH3_LockdownNoChangeNoForceNote() {
        // Persona that already matches template → only scope
        // marker emitted (no per-field force notes)
        let t = BASAgentPersonaRoleTemplates
            .templates[.planner]!
        let p = persona(
            visibility: .high,
            tone: t.tone,
            warmth: t.warmth,
            directness: t.directness,
            skepticism: t.skepticism,
            structure: t.structureBias,
            creativity: t.creativityBias,
            challenge: t.challengeIntensity,
            comparison: t.comparisonBias,
            guardBias: t.guardBias)
        let (_, outcome) =
            BASAgentPersonaSovereignClamp.apply(
                to: p,
                sovereign:
                    BASAgentPersonaSovereignContext(
                        lockdownTurn: true),
                role: .planner)
        let perFieldForceNotes = outcome.auditNotes.filter {
            $0.contains("sovereign.force.")
        }
        XCTAssertTrue(perFieldForceNotes.isEmpty,
            "ch 969.5 H3: identity-match persona under lockdown " +
            "emits NO per-field force notes (only scope marker)")
        XCTAssertTrue(outcome.auditNotes.contains {
            $0.contains("sovereign.lockdown")
        })
    }

    // MARK: - H4 regression: AbsolutePaternal AND logic

    func testH4_AbsolutePaternalRequiresWarmToneAndHighWarmth() {
        // Warm tone BUT low warmth → 3-of-4 = 0.75 → still
        // ABOVE threshold but the WARM contributor must NOT
        // fire because warmth is low (0.10)。 Verifies AND not OR。
        let p = persona(
            tone: "warm",
            warmth: 0.10,        // ← LOW warmth
            creativity: 0.10,
            challenge: 0.85,
            comparison: 0.10)
        let f = BASAgentPersonaForbiddenDetector
            .scoreAbsolutePaternal_visibleForTest(p)
        // Score:0.25 (challenge) + 0.25 (comparison) +
        // 0.25 (creativity) + 0.00 (warm-AND-warmth NOT met) = 0.75
        // Wait — that's still >= 0.6 → would still report。
        // The H4 fix changes WHICH evidence is reported,not the
        // score for this specific case。 Verify the evidence
        // string does NOT include the "warm-AND-warmth" marker
        let hasWarmEvidence = f.evidence.contains {
            $0.contains("warm-AND-warmth")
        }
        XCTAssertFalse(hasWarmEvidence,
            "ch 969.5 H4: warm tone with low warmth (0.10) MUST " +
            "NOT trigger the warm-AND-warmth contributor (it's " +
            "AND now,not OR)")
    }

    func testH4_AbsolutePaternalCleanWarmlessPersonaNoFalseTrigger() {
        // tone="cool", warmth=0.70 → previously OR-logic would
        // fire warm contributor on warmth alone。 With AND-logic
        // it does NOT fire (tone is cool, not warm)。
        let p = persona(
            tone: "cool",
            warmth: 0.70,
            creativity: 0.50,
            challenge: 0.50,
            comparison: 0.50)
        let findings = BASAgentPersonaForbiddenDetector
            .scan(p)
        XCTAssertFalse(findings.contains {
            $0.pattern == .absolutePaternal
        }, "ch 969.5 H4: cool tone + high warmth alone does NOT " +
           "trigger absolutePaternal (avoids false positives)")
    }

    func testH4_AbsolutePaternalTextbookStillDetected() {
        // BOTH warm tone AND high warmth → still detected
        let p = persona(
            tone: "warm",
            warmth: 0.85,
            creativity: 0.10,
            challenge: 0.85,
            comparison: 0.10)
        let findings = BASAgentPersonaForbiddenDetector
            .scan(p)
        XCTAssertTrue(findings.contains {
            $0.pattern == .absolutePaternal &&
            $0.matchScore >= 0.6
        }, "ch 969.5 H4: textbook absolutePaternal " +
           "(warm tone AND high warmth) still detected")
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

// MARK: - Test-only visibility hook for scoreAbsolutePaternal
//
// The scorer is private — expose a test-visible helper that
// scans + filters to just the absolutePaternal finding。 Keeps
// the test specific to the AND-logic field-evidence behavior
// without exposing internals broadly。

extension BASAgentPersonaForbiddenDetector {
    static func scoreAbsolutePaternal_visibleForTest(
        _ p: BASAgentPersonaSpec
    ) -> BASAgentPersonaForbiddenFinding {
        let findings = scan(p, reportThreshold: 0.0)
        return findings.first(where: {
            $0.pattern == .absolutePaternal
        }) ?? BASAgentPersonaForbiddenFinding(
            pattern: .absolutePaternal,
            matchScore: 0.0)
    }
}
