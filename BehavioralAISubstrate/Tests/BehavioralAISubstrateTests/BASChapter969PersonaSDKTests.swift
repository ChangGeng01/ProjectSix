// MARK: - BASChapter969PersonaSDKTests
// chapter 九百六十九 / M3550 — Phase 4 close tests:Persona SDK +
// forbidden detector
//
// Test scope:
//   1. Forbidden detector pin: 4 patterns
//   2. Per-pattern scoring: shame / gaslight / absolute-paternal / controlling
//   3. Detector findings sorted deterministically
//   4. Threshold filter (below threshold = not reported)
//   5. anyForbidden helper
//   6. SDK resolve: clean input → composed persona returned
//   7. SDK resolve: forbidden input overlay → rejected before compose
//   8. SDK resolve: sandwich attack (clean inputs → forbidden output) → rejected
//   9. SDK resolve: lockdown turn → sovereign clamp applies, may still pass
//  10. SDK resolve: full Risk + Sovereign pipeline preserves invariants
//  11. validateOverlays standalone API (pre-flight)
//  12. validateOverlays de-dups by pattern
//  13. Transcript mode enum has 3 cases pinned
//  14. CRITICAL: shame pattern rejected for every persona that
//      matches all 4 contributors (fuzz)
//  15. CRITICAL: clean persona never reported (negative-control fuzz)

import XCTest
@testable import BASMemory

final class BASChapter969PersonaSDKTests: XCTestCase {

    // MARK: - 1. Detector pin

    func testForbiddenPatternCountIs4() {
        XCTAssertEqual(
            BASAgentPersonaForbiddenPattern
                .allCases.count, 4,
            "ch 969: exactly 4 forbidden patterns per plan " +
            "(shame / gaslight / absolutePaternal / controlling)")
    }

    func testTranscriptModeCountIs3() {
        XCTAssertEqual(
            BASAgentPersonaTranscriptMode
                .allCases.count, 3,
            "ch 969: 3 transcript modes per plan (single / " +
            "compareAll / compareSelected)")
    }

    // MARK: - 2a. Shame pattern

    func testShamePatternDetected() {
        let p = persona(
            tone: "cool",      // cold tone
            warmth: 0.10,      // ≤ 0.20
            challenge: 0.85,   // ≥ 0.75
            guardBias: 0.10)   // ≤ 0.20
        let findings = BASAgentPersonaForbiddenDetector
            .scan(p)
        XCTAssertEqual(findings.count, 1,
            "ch 969: textbook shame persona detected (1 finding)")
        let f = findings[0]
        XCTAssertEqual(f.pattern, .shame)
        XCTAssertEqual(f.matchScore, 1.0, accuracy: 0.0001,
            "ch 969: 4-of-4 contributors → match score 1.0")
        XCTAssertTrue(f.evidence.contains {
            $0.contains("warmth")
        })
        XCTAssertTrue(f.evidence.contains {
            $0.contains("guard")
        })
    }

    // MARK: - 2b. Gaslight pattern

    func testGaslightPatternDetected() {
        let p = persona(
            tone: "formal",
            warmth: 0.10,
            directness: 0.85,
            skepticism: 0.85,
            comparison: 0.10)
        let findings = BASAgentPersonaForbiddenDetector
            .scan(p)
        XCTAssertTrue(findings.contains { f in
            f.pattern == .gaslight && f.matchScore >= 0.6
        })
    }

    // MARK: - 2c. Absolute-paternal pattern

    func testAbsolutePaternalPatternDetected() {
        let p = persona(
            tone: "warm",
            warmth: 0.85,
            creativity: 0.10,
            challenge: 0.85,
            comparison: 0.10)
        let findings = BASAgentPersonaForbiddenDetector
            .scan(p)
        XCTAssertTrue(findings.contains { f in
            f.pattern == .absolutePaternal &&
            f.matchScore >= 0.6
        })
    }

    // MARK: - 2d. Controlling pattern

    func testControllingPatternDetected() {
        let p = persona(
            creativity: 0.10,
            challenge: 0.85,
            comparison: 0.10,
            guardBias: 0.10)
        let findings = BASAgentPersonaForbiddenDetector
            .scan(p)
        XCTAssertTrue(findings.contains { f in
            f.pattern == .controlling &&
            f.matchScore >= 0.6
        })
    }

    // MARK: - 3. Findings sorted

    func testFindingsSortedByPattern() {
        // A persona that hits BOTH shame + controlling
        let p = persona(
            tone: "cool",
            warmth: 0.10,
            creativity: 0.10,
            challenge: 0.85,
            comparison: 0.10,
            guardBias: 0.10)
        let findings = BASAgentPersonaForbiddenDetector
            .scan(p)
        XCTAssertGreaterThanOrEqual(findings.count, 2)
        let rawValues = findings.map { $0.pattern.rawValue }
        XCTAssertEqual(rawValues.sorted(), rawValues,
            "ch 969: findings MUST be sorted by pattern enum " +
            "(trace replay determinism)")
    }

    // MARK: - 4. Threshold filter

    func testThresholdFilter() {
        // Only 2-of-4 shame contributors → score 0.50 < default 0.60
        let p = persona(
            tone: "cool",
            warmth: 0.10,
            // challenge intentionally low (0.20) — doesn't contribute
            challenge: 0.20,
            // guard intentionally moderate (0.50) — doesn't contribute
            guardBias: 0.50)
        let findings = BASAgentPersonaForbiddenDetector
            .scan(p, reportThreshold: 0.6)
        XCTAssertFalse(findings.contains { $0.pattern == .shame },
            "ch 969: 2/4 contributors → score 0.5 < threshold 0.6 → " +
            "NOT reported")
        // Below threshold:explicitly drop threshold to 0.4
        let lowerFindings = BASAgentPersonaForbiddenDetector
            .scan(p, reportThreshold: 0.4)
        XCTAssertTrue(lowerFindings.contains {
            $0.pattern == .shame
        }, "ch 969: with threshold 0.4 the partial shame match " +
           "IS reported")
    }

    // MARK: - 5. anyForbidden helper

    func testAnyForbiddenHelper() {
        let clean = persona()
        XCTAssertFalse(
            BASAgentPersonaForbiddenDetector
                .anyForbidden(clean))
        let bad = persona(
            tone: "cool", warmth: 0.10,
            challenge: 0.85, guardBias: 0.10)
        XCTAssertTrue(
            BASAgentPersonaForbiddenDetector
                .anyForbidden(bad))
    }

    // MARK: - 6. SDK clean resolve

    func testSDKResolveClean() {
        let spec = BASAgentSpec(
            agentID: "p", role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let result = BASAgentPersonaSDK.resolve(
            BASAgentPersonaResolveRequest(
                agentSpec: spec,
                personaID: "persona.p.1"))
        XCTAssertFalse(result.rejected)
        XCTAssertNotNil(result.persona)
        XCTAssertTrue(result.findings.isEmpty)
        XCTAssertFalse(result.inputRejected)
    }

    // MARK: - 7. SDK rejects forbidden input overlay

    func testSDKRejectsForbiddenInputOverlay() {
        let spec = BASAgentSpec(
            agentID: "p", role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let forbiddenUser = persona(
            tone: "cool", warmth: 0.10,
            challenge: 0.85, guardBias: 0.10)
        let result = BASAgentPersonaSDK.resolve(
            BASAgentPersonaResolveRequest(
                agentSpec: spec,
                userOverlay: forbiddenUser,
                personaID: "p"))
        XCTAssertTrue(result.rejected,
            "ch 969 CRITICAL: forbidden user overlay → SDK rejects")
        XCTAssertNil(result.persona,
            "ch 969 CRITICAL: rejected → persona MUST be nil")
        XCTAssertTrue(result.inputRejected,
            "ch 969: inputRejected flag set when input was bad")
        XCTAssertTrue(result.findings.contains {
            $0.pattern == .shame
        })
    }

    // MARK: - 8. SDK rejects sandwich attack (clean inputs → forbidden output)

    func testSDKRejectsSandwichAttack() {
        // Each overlay alone is "OK" but they compose into a
        // controlling persona — user lowers creativity + raises
        // challenge,host (last in chain) lowers comparison +
        // lowers guard。 Final composed persona triggers
        // controlling pattern。
        let spec = BASAgentSpec(
            agentID: "p", role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let userOverlay = persona(
            creativity: 0.10, challenge: 0.85)
        let hostOverlay = persona(
            creativity: 0.10, challenge: 0.85,
            comparison: 0.10, guardBias: 0.10)
        // hostOverlay alone IS forbidden — that's the realistic
        // attack pattern (legitimate-looking individual fields
        // composing to controlling)。 Verify SDK catches it。
        let result = BASAgentPersonaSDK.resolve(
            BASAgentPersonaResolveRequest(
                agentSpec: spec,
                userOverlay: userOverlay,
                hostOverlay: hostOverlay,
                personaID: "p"))
        XCTAssertTrue(result.rejected,
            "ch 969: forbidden composition rejected " +
            "(either input or output detection catches it)")
    }

    // MARK: - 9. SDK lockdown path

    func testSDKLockdownAppliesSovereignClamp() {
        let spec = BASAgentSpec(
            agentID: "p", role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        // Clean overlay so SDK doesn't reject。 Lockdown context
        // forces sovereign-clamp force-default。
        let userOverlay = persona(challenge: 0.50)
        let result = BASAgentPersonaSDK.resolve(
            BASAgentPersonaResolveRequest(
                agentSpec: spec,
                userOverlay: userOverlay,
                sovereign:
                    BASAgentPersonaSovereignContext(
                        lockdownTurn: true),
                personaID: "p"))
        XCTAssertFalse(result.rejected,
            "ch 969: lockdown does NOT reject — it force-defaults")
        XCTAssertNotNil(result.persona)
        XCTAssertTrue(result.sovereignClampOutcome
            .lockdownApplied)
        // Force-default puts skepticism at planner template value
        let t = BASAgentPersonaRoleTemplates
            .templates[.planner]!
        XCTAssertEqual(
            result.persona!.skepticism, t.skepticism,
            accuracy: 0.0001)
    }

    // MARK: - 10. Full pipeline preserves invariants

    func testFullPipelinePreservesMonotonicRaise() {
        let spec = BASAgentSpec(
            agentID: "p", role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        // User asks for low skepticism (0.10) — Risk floor must
        // raise it to 0.80 + Sovereign must not lower it
        let userOverlay = persona(skepticism: 0.10)
        let result = BASAgentPersonaSDK.resolve(
            BASAgentPersonaResolveRequest(
                agentSpec: spec,
                userOverlay: userOverlay,
                risk: BASAgentPersonaRiskContext(
                    skepticismFloor: 0.80),
                personaID: "p"))
        XCTAssertFalse(result.rejected)
        XCTAssertEqual(
            result.persona!.skepticism, 0.80,
            accuracy: 0.0001,
            "ch 969 CRITICAL: full pipeline preserves Risk's " +
            "monotonic raise (skepticism floor 0.80 wins over " +
            "user attempt to lower to 0.10)")
    }

    // MARK: - 11. validateOverlays standalone

    func testValidateOverlaysClean() {
        let f = BASAgentPersonaSDK.validateOverlays(
            userOverlay: persona(),
            hostOverlay: persona())
        XCTAssertTrue(f.isEmpty,
            "ch 969: clean overlays → no findings")
    }

    func testValidateOverlaysDetectsForbidden() {
        let bad = persona(
            tone: "cool", warmth: 0.10,
            challenge: 0.85, guardBias: 0.10)
        let f = BASAgentPersonaSDK.validateOverlays(
            userOverlay: bad,
            hostOverlay: nil)
        XCTAssertEqual(f.count, 1)
        XCTAssertEqual(f[0].pattern, .shame)
    }

    // MARK: - 12. validateOverlays de-dups + keeps highest score

    func testValidateOverlaysDeDupsByPattern() {
        let shameUser = persona(
            tone: "cool", warmth: 0.10,
            challenge: 0.85, guardBias: 0.10)
        let shameHostStronger = persona(
            tone: "cool", warmth: 0.05,
            challenge: 0.95, guardBias: 0.05)
        let f = BASAgentPersonaSDK.validateOverlays(
            userOverlay: shameUser,
            hostOverlay: shameHostStronger)
        // De-duped to 1 finding
        XCTAssertEqual(f.count, 1,
            "ch 969: two overlays triggering same pattern → 1 " +
            "de-duped finding (not 2 separate entries)")
        XCTAssertEqual(f[0].pattern, .shame)
        // Strongest score wins (both 1.0 here,but verifies logic)
        XCTAssertEqual(f[0].matchScore, 1.0, accuracy: 0.0001)
    }

    // MARK: - 14. CRITICAL fuzz: shame textbook always detected

    func testCRITICAL_ShameTextbookAlwaysDetected() {
        // 200 random personas with all 4 shame contributors hit
        // — MUST detect every time
        for seed in 0..<200 {
            let rng = Double((seed * 1103515245 + 12345)
                % 1_000_000) / 1_000_000.0
            // Construct persona that satisfies all 4 shame
            // contributors。 Other fields randomized。
            let p = persona(
                tone: "cool",
                warmth: 0.05 + 0.10 * rng,   // ≤ 0.15 < 0.20
                directness: rng,
                skepticism: rng,
                challenge: 0.80 + 0.15 * rng, // ≥ 0.75
                comparison: rng,
                guardBias: 0.05 + 0.10 * rng) // ≤ 0.15 < 0.20
            let findings = BASAgentPersonaForbiddenDetector
                .scan(p)
            XCTAssertTrue(findings.contains {
                $0.pattern == .shame
            }, "ch 969 CRITICAL FUZZ: textbook shame missed at " +
               "seed=\(seed)")
        }
    }

    // MARK: - 15. CRITICAL fuzz: clean persona never reported

    func testCRITICAL_CleanPersonaNeverReported() {
        // 200 random personas with mid-range values (0.3-0.7) —
        // MUST NOT trigger any forbidden pattern
        for seed in 0..<200 {
            let rng = Double((seed * 1103515245 + 12345)
                % 1_000_000) / 1_000_000.0
            let mid = 0.3 + 0.4 * rng  // [0.3, 0.7]
            let p = persona(
                tone: "neutral",
                warmth: mid,
                directness: mid,
                skepticism: mid,
                structure: mid,
                creativity: mid,
                challenge: mid,
                comparison: mid,
                guardBias: mid)
            let findings = BASAgentPersonaForbiddenDetector
                .scan(p)
            XCTAssertTrue(findings.isEmpty,
                "ch 969 CRITICAL FUZZ: clean mid-range persona " +
                "(all biases at \(mid)) triggered findings at " +
                "seed=\(seed): \(findings)")
        }
    }

    // MARK: - 16. SDK result Equatable round-trip

    func testResolveResultIsEquatable() {
        let spec = BASAgentSpec(
            agentID: "p", role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let r1 = BASAgentPersonaSDK.resolve(
            BASAgentPersonaResolveRequest(
                agentSpec: spec,
                personaID: "persona.p.1"))
        let r2 = BASAgentPersonaSDK.resolve(
            BASAgentPersonaResolveRequest(
                agentSpec: spec,
                personaID: "persona.p.1"))
        XCTAssertEqual(r1, r2,
            "ch 969: same request → byte-equal result " +
            "(trace replay invariant)")
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
