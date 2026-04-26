import XCTest
@testable import BASOrgan

/// M232 — coverage for `BASOrganCurriculum`.
///
/// In-context T2 / T3 curriculum prompts replace weight training
/// for Risk Spine + Permit Knot organ behavior. Tests pin the
/// shape so hosts can parse model output reliably:
///
///   - role-only prompts byte-equal the pre-M232 strings
///     (regression-protect existing adapters)
///   - flags compose additively (Risk only / Permit only / both)
///   - structured markers (`[RISK]`, `[NEEDS_PERMIT]`) appear in
///     the curriculum text so hosts pattern-match against stable
///     tokens
///   - opt-out (default flags = false) preserves pre-M232 output
final class BASOrganCurriculumTests: XCTestCase {

    // MARK: - 1. Role-only prompts (backward compat)

    func testScoutBaseMatchesPreM232Text() {
        // The scout text was hardcoded in
        // AppleFoundationOrganAdapter / MLXOrganAdapter pre-M232.
        // Keeping the exact string protects every existing
        // production prompt log + every audit ledger entry that
        // recorded the prompt at draft-time.
        let expected = """
            You are the Scout tier of a behavioural AI substrate.
            Keep answers short, structured, and low-commitment.
            Prefer identifying risks and candidate angles over
            producing final prose.
            """
        XCTAssertEqual(
            BASOrganCurriculum.scoutBase, expected,
            "scoutBase must byte-equal pre-M232 text or every " +
            "existing audit ledger entry's prompt comparison " +
            "breaks")
    }

    func testCoreBaseMatchesPreM232Text() {
        let expected = """
            You are the Core tier of a behavioural AI substrate.
            Produce a considered response; you are being called
            because a draft has been admitted for full consideration.
            """
        XCTAssertEqual(
            BASOrganCurriculum.coreBase, expected,
            "coreBase must byte-equal pre-M232 text")
    }

    // MARK: - 2. Composition opt-out (default = pre-M232)

    func testComposedScoutWithoutCurriculaEqualsScoutBase() {
        let composed = BASOrganCurriculum.composedSystemPrompt(
            role: .scout)
        XCTAssertEqual(
            composed, BASOrganCurriculum.scoutBase,
            "default flags must reproduce pre-M232 scout prompt " +
            "byte-for-byte")
    }

    func testComposedCoreWithoutCurriculaEqualsCoreBase() {
        let composed = BASOrganCurriculum.composedSystemPrompt(
            role: .core)
        XCTAssertEqual(
            composed, BASOrganCurriculum.coreBase,
            "default flags must reproduce pre-M232 core prompt " +
            "byte-for-byte")
    }

    // MARK: - 3. Risk Spine curriculum

    func testRiskCurriculumDeclaresStableMarker() {
        // Hosts parse `[RISK]` lines in model output; the marker
        // must appear in the curriculum text or the model has no
        // way to learn it.
        XCTAssertTrue(
            BASOrganCurriculum.riskSpineCurriculum.contains("[RISK]"),
            "Risk Spine curriculum must declare the [RISK] marker")
    }

    func testRiskCurriculumLeadsWithRiskAwarenessHeading() {
        XCTAssertTrue(
            BASOrganCurriculum.riskSpineCurriculum
                .contains("Risk awareness (Risk Spine):"),
            "curriculum must include the heading hosts use to " +
            "filter model output")
    }

    func testComposedScoutWithRiskAppendsCurriculum() {
        let composed = BASOrganCurriculum.composedSystemPrompt(
            role: .scout, includeRiskCurriculum: true)
        XCTAssertTrue(
            composed.hasPrefix(BASOrganCurriculum.scoutBase),
            "composed prompt must keep the role base as prefix " +
            "(Risk curriculum is additive, not a replacement)")
        XCTAssertTrue(
            composed.contains("[RISK]"),
            "composed prompt must include the Risk marker")
    }

    func testComposedScoutWithRiskOnlyOmitsPermitMarker() {
        let composed = BASOrganCurriculum.composedSystemPrompt(
            role: .scout, includeRiskCurriculum: true)
        XCTAssertFalse(
            composed.contains("[NEEDS_PERMIT]"),
            "Risk-only curriculum must not leak the Permit marker")
    }

    // MARK: - 4. Permit Knot curriculum

    func testPermitCurriculumDeclaresStableMarker() {
        XCTAssertTrue(
            BASOrganCurriculum.permitKnotCurriculum
                .contains("[NEEDS_PERMIT]"),
            "Permit Knot curriculum must declare the " +
            "[NEEDS_PERMIT] marker")
    }

    func testPermitCurriculumLeadsWithPermitAwarenessHeading() {
        XCTAssertTrue(
            BASOrganCurriculum.permitKnotCurriculum
                .contains("Permit awareness (Permit Knot):"),
            "curriculum must include the heading hosts use to " +
            "filter model output")
    }

    func testComposedCoreWithPermitOnlyOmitsRiskMarker() {
        let composed = BASOrganCurriculum.composedSystemPrompt(
            role: .core, includePermitCurriculum: true)
        XCTAssertTrue(composed.contains("[NEEDS_PERMIT]"))
        XCTAssertFalse(
            composed.contains("[RISK]"),
            "Permit-only curriculum must not leak the Risk marker")
    }

    // MARK: - 5. Both curricula

    func testComposedCoreWithBothCurriculaIncludesBoth() {
        let composed = BASOrganCurriculum.composedSystemPrompt(
            role: .core,
            includeRiskCurriculum: true,
            includePermitCurriculum: true)
        XCTAssertTrue(composed.contains("[RISK]"))
        XCTAssertTrue(composed.contains("[NEEDS_PERMIT]"))
        XCTAssertTrue(composed.contains(BASOrganCurriculum.coreBase))
    }

    func testCompositionOrderIsBaseThenRiskThenPermit() {
        // The order matters for prompt-engineering predictability:
        // role establishes the persona, Risk frames behavior,
        // Permit gates side-effects.
        let composed = BASOrganCurriculum.composedSystemPrompt(
            role: .scout,
            includeRiskCurriculum: true,
            includePermitCurriculum: true)
        let riskRange = composed.range(
            of: "Risk awareness (Risk Spine):")
        let permitRange = composed.range(
            of: "Permit awareness (Permit Knot):")
        XCTAssertNotNil(riskRange)
        XCTAssertNotNil(permitRange)
        if let r = riskRange, let p = permitRange {
            XCTAssertLessThan(
                r.lowerBound, p.lowerBound,
                "Risk curriculum must precede Permit curriculum")
        }
    }

    // MARK: - 6. Marker uniqueness sanity

    func testMarkersAreDistinctAndStable() {
        // Hosts pattern-match these literal strings; they must
        // never collide with each other or with the body of the
        // curriculum text outside the structured marker lines.
        let riskHits = BASOrganCurriculum.riskSpineCurriculum
            .components(separatedBy: "[RISK]")
            .count - 1
        let permitHits = BASOrganCurriculum.permitKnotCurriculum
            .components(separatedBy: "[NEEDS_PERMIT]")
            .count - 1
        XCTAssertGreaterThan(
            riskHits, 0,
            "[RISK] must appear at least once (in the format " +
            "instructions)")
        XCTAssertGreaterThan(permitHits, 0)
        XCTAssertFalse(
            BASOrganCurriculum.riskSpineCurriculum
                .contains("[NEEDS_PERMIT]"))
        XCTAssertFalse(
            BASOrganCurriculum.permitKnotCurriculum
                .contains("[RISK]"))
    }
}
