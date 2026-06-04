// ① Metal/Mamba per-turn GPU SHADOW — CPU-vs-GPU selective-scan parity telemetry. Proves the GPU Metal
// kernel tracks its deterministic CPU twin within a tight MAE on real (per-turn-derived) inputs, that
// the shadow is observation-only (the authoritative CPU ssmCaution is untouched), that empty sources →
// nil, and that the new observation field is Codable-backward-compatible. The GPU path runs on the
// Mac's Metal during `swift test`; where Metal is unavailable the primitive returns nil (treated as
// "no shadow this run"), so these tests assert "nil OR tiny MAE".

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASMetalSubstrate

final class BASMambaGPUShadowParityTests: XCTestCase {

    private func affect(_ i: Double, _ v: Double, _ s: Double) -> BASAffectLayer {
        BASAffectLayer(tone: "t", intensity: i, volatility: v, spilloverRisk: s)
    }
    private func cand(_ b: Double, _ c: Double, _ r: Double, _ cf: Double) -> BASCandidatePath {
        BASCandidatePath(candidateID: "c", title: "t", actionSummary: "a",
            expectedBenefit: b, expectedCost: c, reversibility: r, confidence: cf)
    }

    // MARK: - parity primitive

    func testParityMAEIsTinyOrNilWhenNoMetal() async {
        let B = 1, D = 3, N = 4, L = 8
        let shape = BASMambaSSMShape(batch: B, hiddenDim: D, stateDim: N)
        let inputs = BASMambaSSMScanInputs(
            x: (0..<(B * L * D)).map { Float($0 % 7) / 7.0 },
            delta: [Float](repeating: 0.1, count: B * L * D),
            a: [Float](repeating: -1.0, count: D * N),
            b: [Float](repeating: 0.2, count: B * L * N),
            c: [Float](repeating: 0.3, count: B * L * N),
            sequenceLength: L)
        let mae = await BASMambaGPUShadowParity.parityMAE(inputs: inputs, shape: shape)
        if let mae {
            print("GPUSHADOW | parity MAE (cpu vs gpu, state-space) = \(mae)")
            XCTAssertGreaterThanOrEqual(mae, 0)
            XCTAssertLessThan(mae, 1e-4, "the GPU kernel tracks its CPU twin within a tight MAE")
        } else {
            print("GPUSHADOW | parity MAE = nil (Metal unavailable — acceptable)")
        }
    }

    // MARK: - per-turn helper

    func testMaeForTurnSmallOrNil() async {
        let mae = await BASMambaSSMTurnGPUShadow.maeForTurn(
            affectLayers: [affect(0.9, 0.8, 0.7)], turnHistory: ["tense moment now"],
            candidates: [cand(0.2, 0.9, 0.2, 0.3)])
        if let mae {
            print("GPUSHADOW | maeForTurn = \(mae)")
            XCTAssertTrue(mae >= 0 && mae < 1e-4)
        }
    }

    func testRepresentativeParityMAESmallOrNil() async {
        let mae = await BASMambaSSMTurnGPUShadow.representativeParityMAE()
        if let mae {
            print("GPUSHADOW | representative parity MAE = \(mae)")
            XCTAssertTrue(mae >= 0 && mae < 1e-4, "representative on-device probe MAE is tight")
        }
    }

    func testMaeForTurnEmptyIsNil() async {
        let mae = await BASMambaSSMTurnGPUShadow.maeForTurn(
            affectLayers: [], turnHistory: [], candidates: [])
        XCTAssertNil(mae, "all-empty sources → no scan input → nil (no GPU work)")
    }

    func testGPUShadowDoesNotPerturbAuthoritativeCaution() async throws {
        let affects = [affect(0.8, 0.7, 0.6)]
        let hist = ["a tense turn"]
        let cands = [cand(0.2, 0.8, 0.3, 0.4)]
        let base = try XCTUnwrap(BASSSMCautionInput.observation(
            sessionID: "s", turnID: "t",
            affectLayers: affects, turnHistory: hist, candidates: cands))
        let withGpuOpt = await BASMambaSSMTurnGPUShadow.observationWithGPUShadow(
            sessionID: "s", turnID: "t",
            affectLayers: affects, turnHistory: hist, candidates: cands)
        let withGpu = try XCTUnwrap(withGpuOpt)
        // The authoritative CPU value is byte-identical with vs without the shadow.
        XCTAssertEqual(withGpu.ssmCaution, base.ssmCaution, "GPU shadow never perturbs the CPU ssmCaution")
        XCTAssertEqual(withGpu.finalMagnitude, base.finalMagnitude)
        XCTAssertEqual(withGpu.affectCount, base.affectCount)
        XCTAssertEqual(withGpu.historyCount, base.historyCount)
        XCTAssertEqual(withGpu.candidateCount, base.candidateCount)
        if let mae = withGpu.gpuShadowMAE { XCTAssertTrue(mae >= 0 && mae < 1e-4) }
    }

    // MARK: - observation Codable backward-compat

    func testObservationCodableWithAndWithoutGpuField() throws {
        let obs = BASMambaSSMTurnObservation(
            sessionID: "s", turnID: "t", affectCount: 1, historyCount: 1, candidateCount: 1,
            ssmCaution: 0.5, finalMagnitude: 0.01, gpuShadowMAE: 0.0001)
        let data = try JSONEncoder().encode(obs)
        XCTAssertEqual(try JSONDecoder().decode(BASMambaSSMTurnObservation.self, from: data), obs)
        // A pre-field encoding (no gpuShadowMAE key) must still decode → nil.
        let oldJSON = #"{"sessionID":"s","turnID":"t","affectCount":1,"historyCount":1,"candidateCount":1,"ssmCaution":0.5,"finalMagnitude":0.01}"#
        let decodedOld = try JSONDecoder().decode(
            BASMambaSSMTurnObservation.self, from: Data(oldJSON.utf8))
        XCTAssertNil(decodedOld.gpuShadowMAE, "absent key decodes to nil (backward-compatible)")
    }
}
