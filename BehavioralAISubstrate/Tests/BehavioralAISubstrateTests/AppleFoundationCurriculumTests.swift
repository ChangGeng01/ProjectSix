import XCTest
@testable import BASAppleAdapters
@testable import BASOrgan

/// M234 — coverage for the curriculum-flag wiring on
/// `AppleFoundationOrganAdapter`.
///
/// Pre-M234 the adapter hardcoded scout/core system prompts. M234
/// makes them delegate to `BASOrganCurriculum` and adds two opt-in
/// flags (`includeRiskCurriculum`, `includePermitCurriculum`).
///
/// These tests pin:
///   - default flags produce byte-equal pre-M234 output
///     (every existing audit ledger entry's prompt comparison
///     still matches)
///   - flag-on output appends the matching curriculum block
///   - both flags compose additively (Risk before Permit)
///   - the static legacy `systemInstructions(for:)` always returns
///     the no-curriculum baseline (callers using it as before
///     don't get surprise behavior)
final class AppleFoundationCurriculumTests: XCTestCase {

    private func makeRequest(role: BASOrganRole = .scout) -> BASOrganRequest {
        BASOrganRequest(
            requestID: "r-test",
            role: role,
            preset: role == .scout ? .scout : .core,
            instruction: "say hi")
    }

    // MARK: - 1. Default = pre-M234 backward compat

    func testDefaultAdapterHasBothCurriculumFlagsOff() async {
        let adapter = AppleFoundationOrganAdapter()
        XCTAssertFalse(adapter.includeRiskCurriculum)
        XCTAssertFalse(adapter.includePermitCurriculum)
    }

    func testDefaultInstructionsScoutEqualsBareScoutPrompt() async {
        let adapter = AppleFoundationOrganAdapter()
        let req = makeRequest(role: .scout)
        let actual = adapter.instructions(for: req)
        XCTAssertEqual(
            actual, BASOrganCurriculum.scoutBase,
            "default flags must reproduce the pre-M234 scout " +
            "string byte-for-byte")
    }

    func testDefaultInstructionsCoreEqualsBareCorePrompt() async {
        let adapter = AppleFoundationOrganAdapter()
        let req = makeRequest(role: .core)
        let actual = adapter.instructions(for: req)
        XCTAssertEqual(
            actual, BASOrganCurriculum.coreBase,
            "default flags must reproduce the pre-M234 core " +
            "string byte-for-byte")
    }

    func testStaticSystemInstructionsAlwaysReturnsBareBase() {
        // The legacy static helper is kept for tests + any caller
        // that already uses it. It must never return a curriculum-
        // augmented string regardless of any future global state.
        let scoutReq = makeRequest(role: .scout)
        let coreReq = makeRequest(role: .core)
        XCTAssertEqual(
            AppleFoundationOrganAdapter.systemInstructions(
                for: scoutReq),
            BASOrganCurriculum.scoutBase)
        XCTAssertEqual(
            AppleFoundationOrganAdapter.systemInstructions(
                for: coreReq),
            BASOrganCurriculum.coreBase)
    }

    // MARK: - 2. Risk curriculum flag

    func testRiskFlagAppendsRiskBlockToScout() async {
        let adapter = AppleFoundationOrganAdapter(
            includeRiskCurriculum: true)
        let actual = adapter.instructions(for: makeRequest(role: .scout))
        XCTAssertTrue(
            actual.hasPrefix(BASOrganCurriculum.scoutBase),
            "scout base must remain as the prefix")
        XCTAssertTrue(
            actual.contains("[RISK]"),
            "Risk Spine marker must appear in the prompt")
        XCTAssertFalse(
            actual.contains("[NEEDS_PERMIT]"),
            "Permit marker must not leak when only Risk is on")
    }

    // MARK: - 3. Permit curriculum flag

    func testPermitFlagAppendsPermitBlockToCore() async {
        let adapter = AppleFoundationOrganAdapter(
            includePermitCurriculum: true)
        let actual = adapter.instructions(for: makeRequest(role: .core))
        XCTAssertTrue(
            actual.hasPrefix(BASOrganCurriculum.coreBase))
        XCTAssertTrue(actual.contains("[NEEDS_PERMIT]"))
        XCTAssertFalse(
            actual.contains("[RISK]"),
            "Risk marker must not leak when only Permit is on")
    }

    // MARK: - 4. Both flags compose

    func testBothFlagsAppendBothBlocksInOrder() async {
        let adapter = AppleFoundationOrganAdapter(
            includeRiskCurriculum: true,
            includePermitCurriculum: true)
        let actual = adapter.instructions(for: makeRequest(role: .scout))
        XCTAssertTrue(actual.contains("[RISK]"))
        XCTAssertTrue(actual.contains("[NEEDS_PERMIT]"))
        let riskPos = actual.range(of: "[RISK]")?.lowerBound
        let permitPos = actual.range(of: "[NEEDS_PERMIT]")?.lowerBound
        XCTAssertNotNil(riskPos)
        XCTAssertNotNil(permitPos)
        if let r = riskPos, let p = permitPos {
            XCTAssertLessThan(
                r, p,
                "Risk Spine curriculum must precede Permit Knot " +
                "curriculum in the composed prompt")
        }
    }

    // MARK: - 5. Descriptor unchanged when flags are on

    func testDescriptorIdentityIsIndependentOfCurriculumFlags() async {
        let bare = AppleFoundationOrganAdapter()
        let curriculum = AppleFoundationOrganAdapter(
            includeRiskCurriculum: true,
            includePermitCurriculum: true)
        // Both producers must report the same providerID so audit
        // logs remain comparable across "bare" vs "curriculum"
        // configurations of the same provider.
        XCTAssertEqual(
            bare.descriptor.providerID,
            curriculum.descriptor.providerID,
            "providerID should not change just because the same " +
            "provider was configured with curriculum on; the " +
            "underlying model is identical")
    }
}
