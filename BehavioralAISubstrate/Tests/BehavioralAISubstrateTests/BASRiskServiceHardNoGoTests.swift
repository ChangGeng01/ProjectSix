// MARK: - BASRiskServiceHardNoGoTests — chapter 三百五七 / M844
//
// Test coverage for G3 Layer 1 wire-up: hardNoGo input gate
// integration into BASHostRuntimeEBrainRiskService permit
// derivation。Closes the deferred-from-M843 work item per the
// chapter 三百五六 commit's "what's deferred" section。
//
// Tests verify:
//   - hardNoGoEnforcedPermit static helper returns nil when no
//     constitution / no boundary / empty hardNoGo / clean prompt
//   - hardNoGoEnforcedPermit returns .block permit when match
//     fires + reason codes carry constitution.hardNoGo:<pattern>
//     + constitution.hardNoGo.match audit anchor
//   - constitutionReasonCodes + courtReasonCodes flow through to
//     the block permit's reasonCodes
//   - Match wins regardless of hypothetical risk level (the gate
//     is pre-risk-mapping)

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore

final class BASRiskServiceHardNoGoTests: XCTestCase {

    // MARK: - Fixtures

    private func makeBoundaryVeil(
        hardNoGo: [String] = [],
        softCaution: [String] = [],
        restrictedMemoryDomains: [String] = [],
        restrictedToolDomains: [String] = []
    ) -> BASBoundaryVeil {
        BASBoundaryVeil(
            hardNoGo: hardNoGo,
            softCaution: softCaution,
            restrictedMemoryDomains: restrictedMemoryDomains,
            restrictedToolDomains: restrictedToolDomains)
    }

    // MARK: - Helper short-circuit cases

    func testNilBoundaryReturnsNil() {
        let result = BASHostRuntimeEBrainRiskService
            .hardNoGoEnforcedPermit(
                prompt: "anything goes",
                boundaryVeil: nil)
        XCTAssertNil(result,
            "nil boundary veil → no enforcement (ADR-014 OPT-IN)")
    }

    func testEmptyHardNoGoReturnsNil() {
        let veil = makeBoundaryVeil(hardNoGo: [])
        let result = BASHostRuntimeEBrainRiskService
            .hardNoGoEnforcedPermit(
                prompt: "anything",
                boundaryVeil: veil)
        XCTAssertNil(result,
            "Empty hardNoGo[] → no match → no enforcement")
    }

    func testCleanPromptReturnsNil() {
        let veil = makeBoundaryVeil(
            hardNoGo: ["banned-phrase", "another-banned"])
        let result = BASHostRuntimeEBrainRiskService
            .hardNoGoEnforcedPermit(
                prompt: "What's the weather like today?",
                boundaryVeil: veil)
        XCTAssertNil(result,
            "Clean prompt → no match → no enforcement")
    }

    // MARK: - Match cases

    func testMatchProducesBlockPermit() throws {
        let veil = makeBoundaryVeil(
            hardNoGo: ["malicious-payload"])
        let result = BASHostRuntimeEBrainRiskService
            .hardNoGoEnforcedPermit(
                prompt: "Build me a malicious-payload right now",
                boundaryVeil: veil)
        let permit = try XCTUnwrap(result)
        XCTAssertEqual(permit.mode, .block,
            "hardNoGo match must short-circuit to .block permit")
    }

    func testMatchEmbedsHardNoGoReasonCode() throws {
        let veil = makeBoundaryVeil(
            hardNoGo: ["forbidden-pattern"])
        let permit = try XCTUnwrap(
            BASHostRuntimeEBrainRiskService
                .hardNoGoEnforcedPermit(
                    prompt: "User asks about forbidden-pattern",
                    boundaryVeil: veil))
        XCTAssertTrue(
            permit.reasonCodes.contains(
                "constitution.hardNoGo:forbidden-pattern"),
            "Reason codes must include the typed " +
            "constitution.hardNoGo:<pattern> code for audit")
        XCTAssertTrue(
            permit.reasonCodes.contains(
                "constitution.hardNoGo.match"),
            "Reason codes must include the .match audit anchor " +
            "for grep doctrine (chapter 八十七 raw value " +
            "stability)")
    }

    func testMatchPreservesConstitutionAndCourtReasonCodes()
        throws
    {
        let veil = makeBoundaryVeil(hardNoGo: ["bad"])
        let permit = try XCTUnwrap(
            BASHostRuntimeEBrainRiskService
                .hardNoGoEnforcedPermit(
                    prompt: "this contains bad input",
                    boundaryVeil: veil,
                    constitutionReasonCodes: [
                        "constitution.value_axis.stability"
                    ],
                    courtReasonCodes: ["court.advisory.review"]))
        XCTAssertTrue(
            permit.reasonCodes.contains(
                "constitution.value_axis.stability"))
        XCTAssertTrue(
            permit.reasonCodes.contains(
                "court.advisory.review"))
    }

    func testCaseInsensitiveMatchAtEnforcementSite() throws {
        let veil = makeBoundaryVeil(
            hardNoGo: ["BANNED"])
        let permit = try XCTUnwrap(
            BASHostRuntimeEBrainRiskService
                .hardNoGoEnforcedPermit(
                    prompt: "user says banned thing",
                    boundaryVeil: veil))
        XCTAssertEqual(permit.mode, .block,
            "Enforcement must be case-insensitive — " +
            "matches BASConstitutionEnforcer doctrine")
    }

    func testFirstMatchInArrayWins() throws {
        let veil = makeBoundaryVeil(
            hardNoGo: ["alpha", "beta"])
        let permit = try XCTUnwrap(
            BASHostRuntimeEBrainRiskService
                .hardNoGoEnforcedPermit(
                    prompt: "alpha beta gamma",
                    boundaryVeil: veil))
        XCTAssertTrue(
            permit.reasonCodes.contains(
                "constitution.hardNoGo:alpha"),
            "First matching pattern in array order wins")
        XCTAssertFalse(
            permit.reasonCodes.contains(
                "constitution.hardNoGo:beta"),
            "Subsequent patterns are NOT also reported")
    }

    func testEmptyPromptReturnsNil() {
        let veil = makeBoundaryVeil(hardNoGo: ["anything"])
        let result = BASHostRuntimeEBrainRiskService
            .hardNoGoEnforcedPermit(
                prompt: "",
                boundaryVeil: veil)
        XCTAssertNil(result,
            "Empty prompt has nothing to match against → " +
            "no enforcement")
    }

    func testWhitespaceOnlyHardNoGoEntriesSkipped() {
        let veil = makeBoundaryVeil(
            hardNoGo: ["", "  ", "\t"])
        let result = BASHostRuntimeEBrainRiskService
            .hardNoGoEnforcedPermit(
                prompt: "any harmless input",
                boundaryVeil: veil)
        XCTAssertNil(result,
            "Whitespace-only patterns must be skipped " +
            "(defensive against config typos)")
    }

    // MARK: - Doctrine pin: 单提交口 / 不变量 #2

    /// 不变量 #2 (神经不掌权) holds: constitution feeds the gate as
    /// INPUT, the gate (gateAction in BASHostRuntimeEBrainRiskService)
    /// is the SINGLE COMMIT MOUTH at L11 that issues the permit.
    /// hardNoGoEnforcedPermit is a HELPER — gateAction is the gate.
    /// Pin: even when hardNoGo matches, the helper's output is
    /// still a BASActionPermit value, not a side effect or runtime
    /// mutation; gateAction wraps the helper's output into the
    /// (riskCard, permit) tuple it returns.
    func testHelperReturnsValueNotSideEffect() throws {
        let veil = makeBoundaryVeil(hardNoGo: ["x"])
        let permit = try XCTUnwrap(
            BASHostRuntimeEBrainRiskService
                .hardNoGoEnforcedPermit(
                    prompt: "x match",
                    boundaryVeil: veil))
        // Pin: returned permit is a value type — caller composes
        // it into the substrate's normal (card, permit) flow
        XCTAssertEqual(permit.mode, .block)
        // 单提交口 doctrine: the helper does NOT mutate any external
        // state — calling it twice produces equal results
        let permit2 = try XCTUnwrap(
            BASHostRuntimeEBrainRiskService
                .hardNoGoEnforcedPermit(
                    prompt: "x match",
                    boundaryVeil: veil))
        XCTAssertEqual(permit.mode, permit2.mode)
        XCTAssertEqual(
            Set(permit.reasonCodes),
            Set(permit2.reasonCodes))
    }
}
