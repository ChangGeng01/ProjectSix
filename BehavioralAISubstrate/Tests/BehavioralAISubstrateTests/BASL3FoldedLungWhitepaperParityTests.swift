import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore

/// M108 — L3 `折叠肺` whitepaper parity confirmation.
///
/// Unlike M106 / M107 (which closed actual missing types), L3 §6
/// core-object coverage is already **8/8 complete** at substrate
/// layer:
///
/// 1. MorphGraph            → BASMorphGraph
/// 2. PrecisionProfile      → BASPrecisionProfile
/// 3. ThoughtFold           → BASThoughtFold
/// 4. ResumeFrame           → BASResumeFrame
/// 5. HotColdMap            → BASHotColdMap
/// 6. OrganPackage          → BASOrganPackage
/// 7. LungState             → BASLungState
/// 8. RollbackAnchor        → BASRollbackAnchor
///
/// §7 "6 breath modes" (light / structured / deepExchange / guard
/// / quarantine / lockdown) are fully represented by the
/// `BASBreathMode` enum; §4 Breath-Fold-Resume triad is an
/// architectural framing (not a struct).
///
/// The only whitepaper-literal drift pre-M108 was
/// `ThoughtFold.host_mod_summary` (whitepaper) vs the substrate's
/// stored `hostEffectSummary`. M108 adds a zero-cost computed
/// alias `hostModSummary` bridging the two so a literal audit
/// grep passes; existing call sites are untouched.
///
/// These tests pin the parity state so future regressions (e.g.
/// removing a whitepaper type, renaming a breath mode) fail the
/// suite rather than silently drifting.
final class BASL3FoldedLungWhitepaperParityTests: XCTestCase {

    // MARK: - §6 core-object presence (type check)

    func testAllEightCoreObjectsExistAsSchemaVersioned() {
        // Each of these lines would fail to compile if the type
        // weren't present + weren't BASSchemaVersioned. The test
        // is structural — the call-through proves presence.
        XCTAssertEqual(
            BASMorphGraph.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASPrecisionProfile.currentSchemaVersion, "1.0.0")
        XCTAssertTrue(
            BASThoughtFold.currentSchemaVersion.hasPrefix("1."))
        XCTAssertEqual(
            BASResumeFrame.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASHotColdMap.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASOrganPackage.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASLungState.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASRollbackAnchor.currentSchemaVersion, "1.0.0")
    }

    // MARK: - §7 breath modes

    func testBreathModeContainsAllSixWhitepaperStates() {
        let expected: Set<String> = [
            "light",
            "structured",
            "deepExchange",
            "guard",
            "quarantine",
            "lockdown",
        ]
        let actual = Set(
            BASBreathMode.allCases.map(\.rawValue))
        XCTAssertEqual(
            actual, expected,
            "L3 §7 six-mode parity")
    }

    // MARK: - LungState breath phases

    func testBreathPhaseContainsWhitepaperFiveStates() {
        let phases = Set(
            BASBreathPhase.allCases.map(\.rawValue))
        // Whitepaper §6 LungState.breath_phase lists: inhale /
        // exchange / fold / rest / resume.
        XCTAssertTrue(phases.contains("inhale"))
        XCTAssertTrue(phases.contains("exchange"))
        XCTAssertTrue(phases.contains("fold"))
        XCTAssertTrue(phases.contains("rest"))
        XCTAssertTrue(phases.contains("resume"))
    }

    // MARK: - M108 hostModSummary alias

    func testHostModSummaryReadsHostEffectSummary() {
        let fold = BASThoughtFold(
            foldID: "fold.m108",
            compactSlots: ["k": "v"],
            candidateSignatures: [],
            hostEffectSummary: "boundary-mod-applied",
            restorePointer: "rp.1",
            checksum: "sha.1")
        XCTAssertEqual(
            fold.hostModSummary,
            "boundary-mod-applied",
            "alias forwards whitepaper-literal name to stored " +
                "hostEffectSummary")
    }

    func testHostModSummarySetterForwardsToHostEffectSummary() {
        var fold = BASThoughtFold(
            foldID: "fold.m108.rw",
            compactSlots: [:],
            candidateSignatures: [],
            hostEffectSummary: "",
            restorePointer: "rp.2",
            checksum: "sha.2")
        fold.hostModSummary = "written-via-alias"
        XCTAssertEqual(
            fold.hostEffectSummary,
            "written-via-alias",
            "setter forwards to the canonical stored field")
        XCTAssertEqual(
            fold.hostModSummary,
            "written-via-alias",
            "alias read reflects the write")
    }

    func testHostModSummaryAliasSurvivesCodableRoundTrip() throws {
        let orig = BASThoughtFold(
            foldID: "fold.m108.rt",
            compactSlots: [:],
            candidateSignatures: [],
            hostEffectSummary: "rt-payload",
            restorePointer: "rp.3",
            checksum: "sha.3")
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASThoughtFold.self, from: data)
        XCTAssertEqual(
            decoded.hostModSummary, "rt-payload",
            "alias reads same value after Codable round-trip")
        XCTAssertEqual(
            decoded.hostEffectSummary, "rt-payload",
            "canonical field equally preserved")
    }
}
