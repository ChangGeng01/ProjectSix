// ADR-039 Phase 4 — Metal SSMScan → NON-governance reasoning side-channel, proven through `runTurn`.
//
// The CPU `ssmCaution` operator (the authoritative verdict input) is UNCHANGED. Phase 4 adds an OPT-IN
// emission of the per-turn DETERMINISTIC scan input to a default-nil `ssmReasoningInputSink`; the HOST runs
// the Metal SSMScan OFF the turn thread. The safety net:
//   • byte-equal-off (flag off → decision identical to no params; sink never fires)
//   • EMISSION IS PURELY SIDE-CHANNEL — flag-on (sink wired) → decision BYTE-IDENTICAL to flag-off. Unlike
//     ssmCaution (which can RAISE risk), the reasoning emission mutates NOTHING on the value path, so the
//     verdict / risk / permit / rendered output are unchanged AND no "ssm_temporal_caution" factor appears.
//   • the emitted scan input is the REAL per-turn input, and the Metal reasoning ≈ the CPU scan (parity).

import XCTest
import Metal
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASMetalSubstrate

final class BASSSMMetalReasoningRunTurnTests: XCTestCase {

    private func makeCoordinator(
        ssmMetalReasoningEnabled: Bool = false,
        ssmReasoningInputSink:
            (@Sendable (BASSSMReasoningTurnInput) -> Void)? = nil
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
            ssmMetalReasoningEnabled: ssmMetalReasoningEnabled,
            ssmReasoningInputSink: ssmReasoningInputSink)
    }

    /// Decision-field equality (the full Codable result embeds a wall-clock `emittedAt`, so we compare the
    /// deterministic decision outputs the reasoning emission must not perturb — same witness as the
    /// ssmCaution / ch1042 / ch1043 byte-equal-off tests).
    private func assertDecisionEqual(
        _ a: BASEBrainTurnResult, _ b: BASEBrainTurnResult, _ message: String
    ) {
        XCTAssertEqual(a.riskCard.totalRisk, b.riskCard.totalRisk, accuracy: 1e-12, message)
        XCTAssertEqual(a.riskCard.riskLevel, b.riskCard.riskLevel, message)
        XCTAssertEqual(a.riskCard.factors, b.riskCard.factors, message)
        XCTAssertEqual(a.mergedChoice.candidateID, b.mergedChoice.candidateID, message)
        XCTAssertEqual(a.actionPermit.mode, b.actionPermit.mode, message)
        XCTAssertEqual(a.sovereignVerdict?.verdictLevel, b.sovereignVerdict?.verdictLevel, message)
        XCTAssertEqual(a.renderedOutput, b.renderedOutput, message)
    }

    // MARK: - byte-equal-off

    func testByteEqualOffWhenFlagDisabled() {
        let off = makeCoordinator(ssmMetalReasoningEnabled: false)
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let none = BASCoordinatorTestStubs.makeStub()
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        assertDecisionEqual(off, none, "flag off (default) → byte-equal with no Phase-4 params (红线 7)")
    }

    func testSinkNeverFiresWhenFlagOff() {
        final class Box: @unchecked Sendable { var calls = 0 }
        let box = Box()
        _ = makeCoordinator(
            ssmMetalReasoningEnabled: false,
            ssmReasoningInputSink: { _ in box.calls += 1 })
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertEqual(box.calls, 0, "flag off → seam skipped → sink never fires (zero cost)")
    }

    // MARK: - THE boundary proof: flag-on emits, but the decision is BYTE-IDENTICAL to flag-off

    func testReasoningEmissionIsByteIdenticalToOff() throws {
        final class Box: @unchecked Sendable { var input: BASSSMReasoningTurnInput? }
        let box = Box()
        let on = makeCoordinator(
            ssmMetalReasoningEnabled: true,
            ssmReasoningInputSink: { box.input = $0 })
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let off = makeCoordinator(ssmMetalReasoningEnabled: false)
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())

        // The sink fired with the REAL per-turn scan input...
        let input = try XCTUnwrap(box.input,
            "flag-on emits the per-turn SSM scan input to the reasoning sink")
        XCTAssertFalse(input.scanInput.x.isEmpty, "the emitted scan input carries the turn's x sequence")

        // ...yet the DECISION is byte-identical: the reasoning emission is a pure side-channel that mutates
        // NOTHING on the value path (no risk raise, no factor, no verdict/permit/render change).
        assertDecisionEqual(on, off,
            "Phase-4 reasoning emission must NOT perturb the decision (pure non-governance side-channel)")
        XCTAssertFalse(on.riskCard.factors.contains("ssm_temporal_caution"),
            "the reasoning path adds NO governance factor (it is not the caution operator)")
    }

    func testFlagOnDeterministicDecision() {
        let c = makeCoordinator(
            ssmMetalReasoningEnabled: true, ssmReasoningInputSink: { _ in })
        let r1 = c.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let r2 = c.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        assertDecisionEqual(r1, r2, "flag on → deterministic decision (emission is side-effect-free)")
    }

    // MARK: - the emitted input is real, and the Metal reasoning ≈ the CPU scan (parity; Mac GPU)

    func testMetalReasoningParityVsCpu() async throws {
        final class Box: @unchecked Sendable { var input: BASSSMReasoningTurnInput? }
        let box = Box()
        _ = makeCoordinator(
            ssmMetalReasoningEnabled: true,
            ssmReasoningInputSink: { box.input = $0 })
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let input = try XCTUnwrap(box.input)
        let s = input.scanInput

        // CPU reference reduction (deterministic).
        let yCPU = try BASSSMScanCPUReference.scan(
            x: s.x, delta: s.delta, A: s.a, B: s.b, C: s.c, shape: s.shape)
        let cpuMag = BASSSMMetalReasoning.magnitude(of: yCPU)

        // Skip ONLY on genuine GPU absence. `run(...)` returning nil is the runner's
        // own ERROR CHANNEL, not a Metal-availability probe — treating it as one
        // made an SSM kernel regression indistinguishable from a headless box, and
        // greened it while citing an on-device certification the nil no longer
        // establishes.
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("No Metal device on this host — SSM GPU parity is GPU-only")
        }
        let produced = await BASSSMMetalReasoning.run(
            input, loader: BASMetalKernelLibraryLoader(useMetalKernelV2: true))
        let signal = try XCTUnwrap(
            produced,
            "BASSSMMetalReasoning.run must produce a signal on a Metal-capable host")
        XCTAssertTrue(signal.didRunOnGPU)
        XCTAssertEqual(signal.magnitude, cpuMag, accuracy: 1e-4,
            "Metal SSM reasoning magnitude ≈ the CPU scan within tolerance (non-governance signal)")
    }
}
