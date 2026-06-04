// Phase 1 — Mamba/SSM as a real CPU-deterministic per-turn OPERATOR on live data (observation,
// byte-equal-off). Proves: the composite builder is fixed-shape + deterministic + bounded regardless
// of source counts; the history text→float is deterministic; the CPU scan → ssmCaution is deterministic
// + bounded [0,1]; and the host-callable probe is a no-op (byte-equal) when the sink is nil.

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASMetalSubstrate

final class BASMambaSSMTurnOperatorTests: XCTestCase {

    private func affect(_ i: Double, _ v: Double, _ s: Double) -> BASAffectLayer {
        BASAffectLayer(tone: "t", intensity: i, volatility: v, spilloverRisk: s)
    }
    private func candidate(_ benefit: Double, _ cost: Double,
                           _ rev: Double, _ conf: Double) -> BASCandidatePath {
        BASCandidatePath(
            candidateID: "c", title: "t", actionSummary: "a",
            expectedBenefit: benefit, expectedCost: cost, reversibility: rev, confidence: conf)
    }

    // MARK: - composite builder: fixed shape + determinism + empty handling

    func testScanInputFixedShapeRegardlessOfSourceCounts() throws {
        let expected = BASMambaTurnOperatorShape.batch
            * BASMambaTurnOperatorShape.sequenceLength
            * BASMambaTurnOperatorShape.hiddenDim

        let few = try XCTUnwrap(BASMambaTurnSignalBuilder.scanInput(
            affectLayers: [affect(0.5, 0.5, 0.5)], turnHistory: ["hi"],
            candidates: [candidate(0.1, 0.2, 0.3, 0.4)]))
        XCTAssertEqual(few.x.count, expected)
        XCTAssertEqual(few.delta.count, expected)
        XCTAssertEqual(few.b.count, expected)
        XCTAssertEqual(few.c.count, expected)
        XCTAssertEqual(few.a.count, BASMambaTurnOperatorShape.hiddenDim)

        // Overflow rows are capped → identical fixed shape; counts saturate at the caps.
        let many = try XCTUnwrap(BASMambaTurnSignalBuilder.scanInput(
            affectLayers: (0..<50).map { _ in affect(0.9, 0.9, 0.9) },
            turnHistory: (0..<50).map { "entry \($0)" },
            candidates: (0..<50).map { _ in candidate(0.5, 0.5, 0.5, 0.5) }))
        XCTAssertEqual(many.x.count, expected, "overflow capped → same fixed shape")
        XCTAssertEqual(many.affectCount, BASMambaTurnOperatorShape.maxAffectRows)
        XCTAssertEqual(many.historyCount, BASMambaTurnOperatorShape.maxHistoryRows)
        XCTAssertEqual(many.candidateCount, BASMambaTurnOperatorShape.maxCandidateRows)
    }

    func testScanInputDeterministicSameInputsSameBytes() throws {
        func mk() throws -> BASMambaTurnScanInput {
            try XCTUnwrap(BASMambaTurnSignalBuilder.scanInput(
                affectLayers: [affect(0.3, 0.6, 0.1)], turnHistory: ["alpha beta"],
                candidates: [candidate(0.2, 0.7, 0.4, 0.5)]))
        }
        XCTAssertEqual(try mk(), try mk(), "same inputs → byte-identical scan input")
    }

    func testEmptyAllThreeSourcesYieldsNil() {
        XCTAssertNil(BASMambaTurnSignalBuilder.scanInput(
            affectLayers: [], turnHistory: [], candidates: []))
    }

    func testHistoryRowDeterministicAndBounded() {
        let r1 = BASMambaTurnSignalBuilder.historyRow("hello world")
        XCTAssertEqual(r1, BASMambaTurnSignalBuilder.historyRow("hello world"),
            "the model-free text→float mapping is deterministic (golden)")
        XCTAssertEqual(r1.count, 3)
        XCTAssertEqual(r1[0], Float(2.0 / 64.0), accuracy: 1e-6, "2 tokens / cap 64")
        XCTAssertEqual(r1[1], Float(11.0 / 512.0), accuracy: 1e-6, "11 chars / cap 512")
        XCTAssertTrue(r1[2] >= 0 && r1[2] < 1, "fnv unit in [0,1)")
        XCTAssertNotEqual(r1[2], BASMambaTurnSignalBuilder.historyRow("goodbye moon")[2],
            "distinct texts → distinct fnv unit")
    }

    func testClampHandlesOutOfRangeAndNaN() {
        XCTAssertEqual(BASMambaTurnSignalBuilder.clamp01(1.5), 1)
        XCTAssertEqual(BASMambaTurnSignalBuilder.clamp01(-0.5), 0)
        XCTAssertEqual(BASMambaTurnSignalBuilder.clamp01(.nan), 0)
    }

    // MARK: - CPU scan → ssmCaution: deterministic + bounded

    func testSSMCautionDeterministicAndBounded() throws {
        let input = try XCTUnwrap(BASMambaTurnSignalBuilder.scanInput(
            affectLayers: [affect(0.9, 0.9, 0.9), affect(0.8, 0.7, 0.6)],
            turnHistory: ["high tension escalating now"],
            candidates: [candidate(0.1, 0.9, 0.2, 0.3)]))
        let y1 = try BASSSMScanCPUReference.scan(
            x: input.x, delta: input.delta, A: input.a, B: input.b, C: input.c, shape: input.shape)
        let c1 = BASMambaSSMTurnObservationProjection.ssmCaution(fromScanOutput: y1)
        XCTAssertTrue(c1 >= 0 && c1 <= 1, "ssmCaution bounded [0,1]")
        XCTAssertGreaterThan(c1, 0, "non-trivial input → non-zero caution")

        let y2 = try BASSSMScanCPUReference.scan(
            x: input.x, delta: input.delta, A: input.a, B: input.b, C: input.c, shape: input.shape)
        XCTAssertEqual(c1, BASMambaSSMTurnObservationProjection.ssmCaution(fromScanOutput: y2),
            "CPU scan + reducer is deterministic")
    }

    // MARK: - host-callable probe: byte-equal-off + emits + deterministic observation

    func testRunShadowNilSinkIsByteEqualNoOp() {
        let obs = BASMambaSSMTurnObservationProjection.runShadowIfEnabled(
            sessionID: "s", turnID: "t",
            affectLayers: [affect(0.5, 0.5, 0.5)], turnHistory: ["x"], candidates: [], sink: nil)
        XCTAssertNil(obs, "nil sink ⇒ no run ⇒ byte-equal-off (红线 7)")
    }

    func testRunShadowEmitsAndIsDeterministic() {
        final class Box: @unchecked Sendable { var calls = 0 }
        let box = Box()
        let r1 = BASMambaSSMTurnObservationProjection.runShadowIfEnabled(
            sessionID: "s", turnID: "t",
            affectLayers: [affect(0.9, 0.8, 0.7)], turnHistory: ["tense"],
            candidates: [candidate(0.1, 0.9, 0.2, 0.3)],
            sink: { _ in box.calls += 1 })
        XCTAssertNotNil(r1)
        XCTAssertEqual(box.calls, 1, "sink fired exactly once")
        XCTAssertEqual(r1?.affectCount, 1)
        XCTAssertEqual(r1?.historyCount, 1)
        XCTAssertEqual(r1?.candidateCount, 1)
        XCTAssertTrue((r1?.ssmCaution ?? -1) >= 0 && (r1?.ssmCaution ?? 2) <= 1)

        let r2 = BASMambaSSMTurnObservationProjection.runShadowIfEnabled(
            sessionID: "s", turnID: "t",
            affectLayers: [affect(0.9, 0.8, 0.7)], turnHistory: ["tense"],
            candidates: [candidate(0.1, 0.9, 0.2, 0.3)], sink: { _ in })
        XCTAssertEqual(r1, r2, "same inputs ⇒ identical observation")
    }
}
