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

    func testLocalOnlyPermitRendersLocalOnly() {
        // M291 — `.localOnly` permit now resolves to its own
        // first-class soft-hand mode, no longer falling back to
        // `.draft`. Host-private surface (journal / notes / scratch)
        // is doctrinally distinct from a deferred draft.
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.localOnly),
            verdict: nil)
        XCTAssertEqual(mode, .localOnly)
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

    // MARK: - M282 selector rationale

    func testM282RationaleIncludesVerdictTier() {
        let r = BASSoftHandModeSelector.selectModeWithRationale(
            permit: makePermit(.answer),
            verdict: makeVerdict(.quarantine))
        XCTAssertEqual(r.mode, .silentStub)
        XCTAssertTrue(
            r.reasonCodes.contains("verdict:quarantine"),
            "quarantine reason must be visible in rationale")
        XCTAssertTrue(
            r.reasonCodes.contains("tier:catastrophic"),
            "tier must be tagged for audit grouping")
    }

    func testM282RationaleIncludesPermitMode() {
        let r = BASSoftHandModeSelector.selectModeWithRationale(
            permit: makePermit(.block),
            verdict: nil)
        XCTAssertEqual(r.mode, .boundary)
        XCTAssertEqual(r.reasonCodes, ["permit:block"])
    }

    func testM282RationaleAnswerWithCandidateCount() {
        let r = BASSoftHandModeSelector.selectModeWithRationale(
            permit: makePermit(.answer),
            verdict: nil,
            candidateCount: 3)
        XCTAssertEqual(r.mode, .compare)
        XCTAssertTrue(
            r.reasonCodes.contains("permit:answer"))
        XCTAssertTrue(
            r.reasonCodes.contains("candidate-count:3"))
    }

    func testM282RationaleFallbackTagged() {
        let r = BASSoftHandModeSelector.selectModeWithRationale(
            permit: nil, verdict: nil)
        XCTAssertEqual(r.mode, .silentStub)
        XCTAssertEqual(
            r.reasonCodes,
            ["fallback:no-permit-no-verdict"])
    }

    func testM282SelectModeMatchesRationaleMode() {
        // The shorter selectMode entry must always agree with
        // the rationale-emitting overload's mode field.
        let cases: [(BASActionPermitMode?, BASSovereignVerdictLevel?, Int)] = [
            (.answer, .quarantine, 0),
            (.block, nil, 0),
            (.delay, nil, 0),
            (.answer, nil, 5),
            (.answer, .pass, 1),
            (nil, nil, 0),
        ]
        for (permitMode, verdictLevel, count) in cases {
            let permit = permitMode.map { makePermit($0) }
            let verdict = verdictLevel.map { makeVerdict($0) }
            let modeOnly =
                BASSoftHandModeSelector.selectMode(
                    permit: permit,
                    verdict: verdict,
                    candidateCount: count)
            let result =
                BASSoftHandModeSelector.selectModeWithRationale(
                    permit: permit,
                    verdict: verdict,
                    candidateCount: count)
            XCTAssertEqual(
                modeOnly, result.mode,
                "selectMode and selectModeWithRationale must " +
                "agree for case (\(String(describing: permitMode)), " +
                "\(String(describing: verdictLevel)), \(count))")
        }
    }

    // MARK: - M281 component identifier bridge

    func testM281ComponentIdentifierForEveryMode() {
        // Every BASSoftHandMode case maps to a stable
        // identifier matching QinaoUI.ComponentID rawValues.
        // Cross-module string contract — either side can change
        // independently as long as both sides hold this table.
        XCTAssertEqual(
            BASSoftHandMode.compare.componentIdentifier,
            "compare-panel")
        XCTAssertEqual(
            BASSoftHandMode.draft.componentIdentifier,
            "draft-shell")
        XCTAssertEqual(
            BASSoftHandMode.delay.componentIdentifier,
            "delay-packet")
        XCTAssertEqual(
            BASSoftHandMode.boundary.componentIdentifier,
            "boundary-script")
        XCTAssertEqual(
            BASSoftHandMode.silentStub.componentIdentifier,
            "silent-stub")
        XCTAssertEqual(
            BASSoftHandMode.localOnly.componentIdentifier,
            "local-only-sheet")
    }

    func testM281IdentifiersAreUnique() {
        let allIDs = Set(
            BASSoftHandMode.allCases.map(
                \.componentIdentifier))
        XCTAssertEqual(
            allIDs.count, BASSoftHandMode.allCases.count,
            "every mode must have a unique component identifier")
    }

    func testM281SelectThenIdentifierEndToEnd() {
        // The canonical L12 flow: selector → mode → identifier.
        // Verdict + permit drive a typed mode; identifier is
        // the cross-module contract the host uses to look up
        // the QinaoUI view.
        let mode = BASSoftHandModeSelector.selectMode(
            permit: makePermit(.block),
            verdict: nil)
        XCTAssertEqual(mode, .boundary)
        XCTAssertEqual(
            mode.componentIdentifier, "boundary-script")
    }

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
