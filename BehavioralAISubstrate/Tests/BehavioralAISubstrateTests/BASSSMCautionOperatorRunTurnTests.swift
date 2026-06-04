// Phase 2 (sovereign-sensitive) — the SSM caution operator as an AUTHORITATIVE, raise-caution-only L11
// INPUT, proven through `runTurn`. The safety net for the L11 seam:
//   • byte-equal-off (flag off → decision identical to no SSM params; sink never fires)
//   • flag-on determinism (run twice → identical decision)
//   • never-lowers (flag on totalRisk ≥ flag off — the safe-direction property)
//   • exact raise math at the runTurn level (when the seam fires, on.totalRisk ==
//     raisedTotalRisk(off.totalRisk, ssmCaution) — robust to whether the stub turn is uncertain)
//   • REAL host runtime: on a genuinely-uncertain high-risk turn the seam FIRES, RAISES caution
//     (surfacing the factor), preserves the established flag-off baseline (byte-equal-off witness),
//     and the sovereign verdict STILL GATES (the operator can never downgrade the verdict — 不变量 #2).

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASSSMCautionOperatorRunTurnTests: XCTestCase {

    // MARK: - Coordinator-stub level

    private func makeCoordinator(
        ssmCautionOperatorEnabled: Bool = false,
        ssmCautionObservationSink:
            (@Sendable (BASMambaSSMTurnObservation) -> Void)? = nil
    ) -> BASEBrainRuntimeCoordinator {
        BASEBrainRuntimeCoordinator(
            powerClockService: StubPowerClock(),
            hostProfileService: StubHost(),
            contextService: StubContext(),
            decomposeService: StubDecompose(),
            memoryService: StubMemory(),
            loopService: StubLoop(),
            triSelfService: StubTriSelf(),
            riskService: StubRisk(),
            actionService: StubAction(),
            evolutionService: StubEvolution(),
            ssmCautionOperatorEnabled: ssmCautionOperatorEnabled,
            ssmCautionObservationSink: ssmCautionObservationSink)
    }

    /// Decision-field equality (the full Codable result is not byte-stable across runTurn calls — the
    /// L14 audit embeds a wall-clock `emittedAt` — so we compare the deterministic decision outputs the
    /// operator must not perturb, exactly like ch1042/ch1043's byte-equal-off witnesses).
    private func assertDecisionEqual(
        _ a: BASEBrainTurnResult, _ b: BASEBrainTurnResult, _ message: String
    ) {
        XCTAssertEqual(a.riskCard.totalRisk, b.riskCard.totalRisk, accuracy: 1e-12, message)
        XCTAssertEqual(a.riskCard.riskLevel, b.riskCard.riskLevel, message)
        XCTAssertEqual(a.mergedChoice.candidateID, b.mergedChoice.candidateID, message)
        XCTAssertEqual(a.actionPermit.mode, b.actionPermit.mode, message)
        XCTAssertEqual(a.sovereignVerdict?.verdictLevel, b.sovereignVerdict?.verdictLevel, message)
        XCTAssertEqual(a.renderedOutput, b.renderedOutput, message)
    }

    func testByteEqualOffWhenFlagDisabled() {
        let off = makeCoordinator(ssmCautionOperatorEnabled: false)
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let none = BASCoordinatorTestStubs.makeStub()
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        assertDecisionEqual(off, none, "flag off (default) → byte-equal with no SSM params (红线 7)")
    }

    func testSinkNeverFiresWhenFlagOff() {
        final class Box: @unchecked Sendable { var calls = 0 }
        let box = Box()
        _ = makeCoordinator(
            ssmCautionOperatorEnabled: false,
            ssmCautionObservationSink: { _ in box.calls += 1 })
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertEqual(box.calls, 0, "flag off → seam skipped → sink never fires (zero cost)")
    }

    func testFlagOnDeterministic() {
        let c = makeCoordinator(ssmCautionOperatorEnabled: true)
        let r1 = c.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let r2 = c.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        assertDecisionEqual(r1, r2, "flag on → deterministic across runs (CPU scan, no GPU/async)")
    }

    func testFlagOnNeverLowersRisk() {
        let on = makeCoordinator(ssmCautionOperatorEnabled: true)
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let off = makeCoordinator(ssmCautionOperatorEnabled: false)
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertGreaterThanOrEqual(on.riskCard.totalRisk, off.riskCard.totalRisk,
            "the operator can only RAISE risk, never lower it (safe-direction)")
    }

    /// EVERY-TURN state-tracking + factor-gated raise (chapter 一百八十九): the operator runs + EMITS on
    /// every flag-on turn (continuous state-tracking), but the RAISE is gated by genuine uncertainty.
    /// So keying off the FACTOR (raise applied), not the sink firing: when the factor is present
    /// on.totalRisk is EXACTLY off raised by the scaled increment; when absent the operator still ran
    /// (obs emitted) but did NOT raise ⇒ on is byte-equal to off.
    func testFlagOnEmitsEveryTurnAndRaiseIsFactorGated() throws {
        final class Box: @unchecked Sendable { var obs: BASMambaSSMTurnObservation? }
        let box = Box()
        let on = makeCoordinator(
            ssmCautionOperatorEnabled: true,
            ssmCautionObservationSink: { box.obs = $0 })
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let off = makeCoordinator(ssmCautionOperatorEnabled: false)
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())

        // Every-turn state-tracking: the operator runs + emits on EVERY flag-on turn (non-empty sources),
        // independent of whether it raises.
        let obs = try XCTUnwrap(box.obs,
            "flag-on emits the SSM observation every turn (continuous state-tracking)")
        if on.riskCard.factors.contains("ssm_temporal_caution") {
            // RAISE applied (a genuinely-uncertain turn): exact scaled-increment math.
            XCTAssertEqual(on.riskCard.totalRisk,
                BASSSMCautionInput.raisedTotalRisk(
                    off.riskCard.totalRisk, ssmCaution: obs.ssmCaution),
                accuracy: 1e-12,
                "raise applied → on.totalRisk == raisedTotalRisk(off.totalRisk, ssmCaution)")
            XCTAssertGreaterThanOrEqual(on.riskCard.totalRisk, off.riskCard.totalRisk,
                "the raise is in the safe direction")
        } else {
            // Observation emitted but NO raise (non-uncertain turn) → result byte-equal despite the
            // operator running (the state-tracking scan is observation-only).
            XCTAssertEqual(on.riskCard.totalRisk, off.riskCard.totalRisk, accuracy: 1e-12,
                "operator ran (obs emitted) but did not raise → on is byte-equal to off")
        }
    }

    // MARK: - Real host runtime: the seam FIRES + raises on a genuinely-uncertain turn
    //
    // The stub harness can't produce a genuinely-uncertain turn (the uncertaintyLedger is derived in the
    // pipeline, not set by stubs), so the FIRE proof uses the real host runtime on the same high-risk
    // fixture ch1039 uses for the P1.5a deliberation caution. (Sync path only — the async runtime-mode
    // surface SIGBUSes under XCTest per BASSignalTenIntegrationTestTriageDoctrine.)

    func testSSMCautionFiresAndRaisesAndVerdictStillGatesViaRealHostRuntime() throws {
        let configuration = BASHostConfiguration.fixtureGeneric
        let runtime = BASHostRuntime(configuration: configuration)
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .reflective,
            surface: .application,
            prompt: "Push into an irreversible high-stakes move now.",
            riskLevel: .high)
        let seed = try runtime.startSession(request)
        let currentBrain = seed.currentBrain
        let projection = BASBrainProjection(records: [], candidates: [], recentEvents: [])
        let device = BASCoordinatorTestStubs.nominalDeviceState

        let off = runtime.buildEBrainTurn(
            request: request, currentBrain: currentBrain, projection: projection,
            deviceStateOverride: device, ssmCautionOperatorEnabled: false)
        let on = runtime.buildEBrainTurn(
            request: request, currentBrain: currentBrain, projection: projection,
            deviceStateOverride: device, ssmCautionOperatorEnabled: true)

        // byte-equal-off witness: the established pre-operator baseline for this fixture is preserved
        // (ch1039 pins this exact fixture at .medium with no opt-in flags). If the flag-off path leaked,
        // this baseline would shift.
        XCTAssertEqual(off.riskCard.riskLevel, .medium,
            "flag off → the pre-operator baseline (.medium) is preserved (byte-equal-off witness)")
        XCTAssertFalse(off.riskCard.factors.contains("ssm_temporal_caution"),
            "flag off → the SSM caution factor is absent")

        // The seam genuinely FIRED on this uncertain turn (the factor is surfaced only inside the block).
        XCTAssertTrue(on.riskCard.factors.contains("ssm_temporal_caution"),
            "flag on + uncertain turn → the seam fired (caution factor surfaced)")

        // RAISE-ONLY — the safety property: on never below off.
        XCTAssertGreaterThanOrEqual(on.riskCard.totalRisk, off.riskCard.totalRisk,
            "the operator RAISES (never lowers) totalRisk")
        XCTAssertGreaterThanOrEqual(on.riskCard.riskLevel, off.riskCard.riskLevel,
            "the operator never downgrades the risk level")

        // VERDICT STILL GATES (不变量 #2): the raised risk flows as an INPUT the sovereign verdict
        // consumes downstream; the operator never bypasses it and can never DOWNGRADE the verdict.
        let onVerdict = try XCTUnwrap(on.sovereignVerdict,
            "the sovereign verdict still runs on the on-turn (not bypassed)")
        let offVerdict = try XCTUnwrap(off.sovereignVerdict)
        XCTAssertGreaterThanOrEqual(onVerdict.verdictLevel, offVerdict.verdictLevel,
            "the verdict still gates: the operator's INPUT can only raise, never downgrade, the verdict")

        // The on-turn is itself deterministic (re-run → identical decision).
        let on2 = runtime.buildEBrainTurn(
            request: request, currentBrain: currentBrain, projection: projection,
            deviceStateOverride: device, ssmCautionOperatorEnabled: true)
        XCTAssertEqual(on.riskCard.totalRisk, on2.riskCard.totalRisk, accuracy: 1e-12,
            "flag-on is a new but DETERMINISTIC baseline")
        XCTAssertEqual(on.sovereignVerdict?.verdictLevel, on2.sovereignVerdict?.verdictLevel,
            "flag-on verdict is deterministic")
    }
}
