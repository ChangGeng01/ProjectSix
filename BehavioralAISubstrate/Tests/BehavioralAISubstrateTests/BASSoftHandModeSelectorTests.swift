import XCTest
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

/// L12 / M280 — coverage for `BASSoftHandModeSelector`.
///
/// Pin the mapping table:
/// permit + verdict → BASSoftHandMode.
final class BASSoftHandModeSelectorTests: XCTestCase {

    // MARK: - Verdict tier (highest priority)

    func testQuarantineVerdictForcesSilentStub() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.answer),
            verdict: makeVerdict(.quarantine))
        XCTAssertEqual(
            mode, .silentStub,
            "quarantine must render nothing actionable " +
            "regardless of permit")
    }

    func testRollbackVerdictForcesSilentStub() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.answer),
            verdict: makeVerdict(.rollback))
        XCTAssertEqual(mode, .silentStub)
    }

    func testDeadStopVerdictForcesSilentStub() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.answer),
            verdict: makeVerdict(.deadStop))
        XCTAssertEqual(mode, .silentStub)
    }

    func testToolCutVerdictRendersBoundary() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.answer),
            verdict: makeVerdict(.toolCut))
        XCTAssertEqual(
            mode, .boundary,
            "toolCut must surface boundary so host knows " +
            "execution stopped")
    }

    func testMemoryFreezeRendersBoundary() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.answer),
            verdict: makeVerdict(.memoryFreeze))
        XCTAssertEqual(mode, .boundary)
    }

    func testThrottleVerdictRendersDraft() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.answer),
            verdict: makeVerdict(.throttle))
        XCTAssertEqual(
            mode, .draft,
            "throttle = draft, not commit")
    }

    func testShadowLockRendersDraft() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.answer),
            verdict: makeVerdict(.shadowLock))
        XCTAssertEqual(mode, .draft)
    }

    func testPassVerdictFallsThroughToPermitMode() {
        // pass verdict → look at permit (which is .answer here →
        // .draft default for single candidate)
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.answer),
            verdict: makeVerdict(.pass))
        XCTAssertEqual(mode, .draft)
    }

    // MARK: - Permit mode tier

    func testBlockPermitRendersBoundary() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.block),
            verdict: nil)
        XCTAssertEqual(mode, .boundary)
    }

    func testReplacePermitRendersBoundary() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.replace),
            verdict: nil)
        XCTAssertEqual(mode, .boundary)
    }

    func testDelayPermitRendersDelay() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.delay),
            verdict: nil)
        XCTAssertEqual(mode, .delay)
    }

    func testDraftOnlyPermitRendersCompare() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.draftOnly),
            verdict: nil)
        XCTAssertEqual(mode, .compare)
    }

    func testComparePermitRendersCompare() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.compare),
            verdict: nil)
        XCTAssertEqual(mode, .compare)
    }

    func testEscalatePermitRendersBoundary() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.escalate),
            verdict: nil)
        XCTAssertEqual(mode, .boundary)
    }

    func testMirrorPermitRendersDraft() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.mirror),
            verdict: nil)
        XCTAssertEqual(mode, .draft)
    }

    func testLocalOnlyPermitRendersDraft() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.localOnly),
            verdict: nil)
        XCTAssertEqual(mode, .draft)
    }

    // MARK: - Multi-candidate hint

    func testAnswerWithMultipleCandidatesRendersCompare() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.answer),
            verdict: nil,
            candidateCount: 3)
        XCTAssertEqual(
            mode, .compare,
            "≥2 candidates + .answer mode = compare")
    }

    func testAnswerWithSingleCandidateRendersDraft() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.answer),
            verdict: nil,
            candidateCount: 1)
        XCTAssertEqual(mode, .draft)
    }

    // MARK: - No-permit fallback

    func testNoPermitNoVerdictRendersSilentStub() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: nil,
            verdict: nil)
        XCTAssertEqual(
            mode, .silentStub,
            "no permit + no verdict = render nothing actionable")
    }

    func testNoPermitWithPassVerdictRendersSilentStub() {
        let mode = BASSoftHandModeSelector.selectMode(
            permit: nil,
            verdict: makeVerdict(.pass))
        XCTAssertEqual(
            mode, .silentStub,
            "verdict.pass alone (no permit) is fail-safe stub")
    }

    // MARK: - Verdict-only convenience

    func testVerdictOnlyConvenienceMatchesFullSelector() {
        let v = makeVerdict(.quarantine)
        let full = BASSoftHandModeSelector.selectMode(
            permit: nil, verdict: v)
        let conv = BASSoftHandModeSelector.selectMode(
            forVerdict: v)
        XCTAssertEqual(full, conv)
        XCTAssertEqual(conv, .silentStub)
    }

    // MARK: - Doctrine: verdict overrides permit

    func testVerdictBeatsPermissivePermit() {
        // Permit says .answer (most permissive) but verdict
        // says .toolCut → must surface boundary, not draft.
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.answer),
            verdict: makeVerdict(.toolCut))
        XCTAssertEqual(
            mode, .boundary,
            "verdict severity must override permit's " +
            "permissiveness")
    }

    // MARK: - Helpers

    private func makePermit(
        _ mode: BASActionPermitMode
    ) -> BASActionPermit {
        BASActionPermit(
            mode: mode,
            reasonCodes: ["test"],
            requireSecondCheck: false,
            outputLengthCap: 200,
            tonePolicy: "calm",
            templatePolicy: "test")
    }

    private func makeVerdict(
        _ level: BASSovereignVerdictLevel
    ) -> BASSovereignVerdict {
        BASSovereignVerdict(
            verdictID: "v-\(UUID().uuidString)",
            verdictLevel: level,
            latched: true,
            reasonCodes: ["test"],
            revokedPermissions: [],
            userStubMode: .refusalOnly,
            policyHash: "test-policy-hash")
    }
}
