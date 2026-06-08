// ADR-039 Phase 5 — Metal attention → NON-governance reasoning side-channel, proven through `runTurn`.
//
// Same safety net as the Phase-4 SSM sink: the emission is a PURE side-channel (it mutates nothing on the
// value path), so flag-on (sink wired) is byte-IDENTICAL to flag-off. The candidate-salience attention runs
// in the HOST off the turn thread, routed by the Phase-3 router; the Metal output ≈ the CPU reference.

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASMetalSubstrate

final class BASAttentionMetalReasoningRunTurnTests: XCTestCase {

    private func makeCoordinator(
        attentionMetalReasoningEnabled: Bool = false,
        attentionReasoningInputSink:
            (@Sendable (BASAttentionReasoningTurnInput) -> Void)? = nil
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
            attentionMetalReasoningEnabled: attentionMetalReasoningEnabled,
            attentionReasoningInputSink: attentionReasoningInputSink)
    }

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
        let off = makeCoordinator(attentionMetalReasoningEnabled: false)
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let none = BASCoordinatorTestStubs.makeStub()
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        assertDecisionEqual(off, none, "flag off (default) → byte-equal with no Phase-5 params (红线 7)")
    }

    func testSinkNeverFiresWhenFlagOff() {
        final class Box: @unchecked Sendable { var calls = 0 }
        let box = Box()
        _ = makeCoordinator(
            attentionMetalReasoningEnabled: false,
            attentionReasoningInputSink: { _ in box.calls += 1 })
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertEqual(box.calls, 0, "flag off → seam skipped → sink never fires")
    }

    // MARK: - THE boundary proof: flag-on emits, but the decision is BYTE-IDENTICAL to flag-off

    func testReasoningEmissionIsByteIdenticalToOff() throws {
        final class Box: @unchecked Sendable { var input: BASAttentionReasoningTurnInput? }
        let box = Box()
        let on = makeCoordinator(
            attentionMetalReasoningEnabled: true,
            attentionReasoningInputSink: { box.input = $0 })
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let off = makeCoordinator(attentionMetalReasoningEnabled: false)
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())

        let input = try XCTUnwrap(box.input,
            "flag-on emits the per-turn attention input (the stub turn has candidates → keys)")
        XCTAssertGreaterThan(input.input.kRows, 0, "emitted input carries the candidate keys")

        assertDecisionEqual(on, off,
            "Phase-5 attention emission must NOT perturb the decision (pure non-governance side-channel)")
        XCTAssertFalse(on.riskCard.factors.contains("attention"),
            "the reasoning path adds NO governance factor")
    }

    func testFlagOnDeterministicDecision() {
        let c = makeCoordinator(
            attentionMetalReasoningEnabled: true, attentionReasoningInputSink: { _ in })
        let r1 = c.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let r2 = c.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        assertDecisionEqual(r1, r2, "flag on → deterministic decision (emission is side-effect-free)")
    }

    // MARK: - Metal attention ≈ CPU reference (parity; Mac GPU, graceful skip), via the Phase-3 router

    func testMetalReasoningParityVsCpu() async throws {
        final class Box: @unchecked Sendable { var input: BASAttentionReasoningTurnInput? }
        let box = Box()
        _ = makeCoordinator(
            attentionMetalReasoningEnabled: true,
            attentionReasoningInputSink: { box.input = $0 })
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let payload = try XCTUnwrap(box.input)

        let cpuMag = BASAttentionMetalReasoning.magnitude(
            of: BASAttentionMetalReasoning.cpuReference(payload.input))

        guard let signal = await BASAttentionMetalReasoning.run(
            payload, loader: BASMetalKernelLibraryLoader(useMetalKernelV2: true),
            thermalState: .nominal, anePriority: .aneFirst)
        else { throw XCTSkip("Metal unavailable in this environment — parity certified on-device") }

        // nominal thermal ⇒ the router does NOT decline the GPU ⇒ Metal ran.
        XCTAssertTrue(signal.didRunOnGPU, "nominal thermal ⇒ router routes attention to the GPU")
        XCTAssertEqual(signal.magnitude, cpuMag, accuracy: 1e-4,
            "Metal attention reasoning magnitude ≈ the CPU reference within tolerance")
    }
}
