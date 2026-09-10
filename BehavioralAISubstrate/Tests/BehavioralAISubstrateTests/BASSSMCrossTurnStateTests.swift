// Cross-turn SSM state — proofs the operator is now a TRUE temporal operator. Covers: the stateful scan
// is byte-identical to the stateless scan at zero init (the byte-equal-off anchor) + matches a
// hand-computed recurrence + carries a non-zero seed; the operator threads priorState (nil ⇒ unchanged
// caution, byte-equal-off; carried state ⇒ caution changes + state is carried; wrong-length ⇒ fresh);
// sustained pressure accumulates caution while the contractive (A<0) recurrence keeps the state bounded;
// and the new observation field is Codable-backward-compatible.

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASMetalSubstrate

final class BASSSMCrossTurnStateTests: XCTestCase {

    private func affect(_ i: Double, _ v: Double, _ s: Double) -> BASAffectLayer {
        BASAffectLayer(tone: "t", intensity: i, volatility: v, spilloverRisk: s)
    }
    private func cand(_ b: Double, _ c: Double, _ r: Double, _ cf: Double) -> BASCandidatePath {
        BASCandidatePath(candidateID: "c", title: "t", actionSummary: "a",
            expectedBenefit: b, expectedCost: c, reversibility: r, confidence: cf)
    }

    // MARK: - scanWithState (the per-channel state-threading reference)

    func testZeroInitMatchesStatelessScanByteForByte() throws {
        let shape = BASSSMScanShape(B: 1, L: 4, D: 2)
        let n = Int(shape.B) * Int(shape.L) * Int(shape.D)
        let x = (0..<n).map { Float($0 % 5) / 5.0 }
        let delta = [Float](repeating: 0.1, count: n)
        let a = [Float](repeating: -1.0, count: 2)
        let bMat = [Float](repeating: 0.2, count: n)
        let cMat = [Float](repeating: 0.3, count: n)
        let stateless = try BASSSMScanCPUReference.scan(
            x: x, delta: delta, A: a, B: bMat, C: cMat, shape: shape)
        let stateful = try BASSSMScanCPUReference.scanWithState(
            x: x, delta: delta, A: a, B: bMat, C: cMat, shape: shape,
            initialState: [Float](repeating: 0, count: 2))
        XCTAssertEqual(stateful.y, stateless, "zero init ⇒ y byte-identical to the stateless scan")
        XCTAssertEqual(stateful.finalState.count, 2)
        XCTAssertTrue(stateful.finalState.allSatisfy { $0.isFinite })
    }

    func testFinalStateMatchesHandComputedRecurrence() throws {
        // B=1, D=1, L=2; x=[1,1], Δ=0.1, A=-1, B=0.2, C=0.3, h0=0.
        // A_bar=e^-0.1≈0.904837, B_bar=0.02; h1=0.02; h2=0.904837*0.02+0.02≈0.0380967.
        let r = try BASSSMScanCPUReference.scanWithState(
            x: [1, 1], delta: [0.1, 0.1], A: [-1], B: [0.2, 0.2], C: [0.3, 0.3],
            shape: BASSSMScanShape(B: 1, L: 2, D: 1), initialState: [0])
        XCTAssertEqual(r.finalState[0], 0.0380967, accuracy: 1e-5)
    }

    func testNonZeroInitialStateCarriesForward() throws {
        let shape = BASSSMScanShape(B: 1, L: 2, D: 1)
        let zero = try BASSSMScanCPUReference.scanWithState(
            x: [1, 1], delta: [0.1, 0.1], A: [-1], B: [0.2, 0.2], C: [0.3, 0.3],
            shape: shape, initialState: [0])
        let seeded = try BASSSMScanCPUReference.scanWithState(
            x: [1, 1], delta: [0.1, 0.1], A: [-1], B: [0.2, 0.2], C: [0.3, 0.3],
            shape: shape, initialState: [0.5])
        XCTAssertNotEqual(zero.y, seeded.y, "a non-zero carried state changes the output")
        XCTAssertGreaterThan(seeded.finalState[0], zero.finalState[0], "the carried state persists")
    }

    func testWrongLengthInitialStateThrows() {
        let shape = BASSSMScanShape(B: 1, L: 2, D: 2)
        XCTAssertThrowsError(try BASSSMScanCPUReference.scanWithState(
            x: [Float](repeating: 0, count: 4), delta: [Float](repeating: 0.1, count: 4),
            A: [-1, -1], B: [Float](repeating: 0.2, count: 4), C: [Float](repeating: 0.3, count: 4),
            shape: shape, initialState: [0]), "initialState.count must equal B*D")
    }

    // MARK: - operator threading

    func testNilPriorStateIsByteEqualButCarriesStateOut() throws {
        let affs = [affect(0.8, 0.7, 0.6)]; let hist = ["tense moment"]; let cs = [cand(0.2, 0.8, 0.3, 0.4)]
        let obs = try XCTUnwrap(BASSSMCautionInput.observation(
            sessionID: "s", turnID: "t", affectLayers: affs, turnHistory: hist, candidates: cs,
            priorState: nil))
        let scalar = try XCTUnwrap(BASSSMCautionInput.cautionScalar(
            affectLayers: affs, turnHistory: hist, candidates: cs))
        XCTAssertEqual(obs.ssmCaution, scalar, "nil prior state ⇒ caution unchanged (byte-equal-off)")
        XCTAssertNotNil(obs.ssmStateOut, "the operator now carries its final state out (observation-only)")
        XCTAssertEqual(obs.ssmStateOut?.count, BASMambaTurnOperatorShape.hiddenDim)
    }

    func testCarriedStateChangesCaution() throws {
        let affs = [affect(0.9, 0.9, 0.85)]; let hist = ["escalating now"]; let cs = [cand(0.2, 0.9, 0.2, 0.3)]
        let first = try XCTUnwrap(BASSSMCautionInput.observation(
            sessionID: "s", turnID: "t1", affectLayers: affs, turnHistory: hist, candidates: cs,
            priorState: nil))
        let carried = try XCTUnwrap(first.ssmStateOut)
        let second = try XCTUnwrap(BASSSMCautionInput.observation(
            sessionID: "s", turnID: "t2", affectLayers: affs, turnHistory: hist, candidates: cs,
            priorState: carried))
        XCTAssertNotEqual(first.ssmCaution, second.ssmCaution,
            "carrying the prior state changes the caution (the temporal effect)")
    }

    func testWrongLengthPriorStateTreatedAsFresh() throws {
        let affs = [affect(0.8, 0.7, 0.6)]; let hist = ["x"]; let cs = [cand(0.2, 0.8, 0.3, 0.4)]
        let fresh = try XCTUnwrap(BASSSMCautionInput.observation(
            sessionID: "s", turnID: "t", affectLayers: affs, turnHistory: hist, candidates: cs,
            priorState: nil))
        let wrong = try XCTUnwrap(BASSSMCautionInput.observation(
            sessionID: "s", turnID: "t", affectLayers: affs, turnHistory: hist, candidates: cs,
            priorState: [1, 2, 3, 4, 5]))
        XCTAssertEqual(fresh.ssmCaution, wrong.ssmCaution,
            "wrong-length prior state ⇒ treated as a fresh recurrence (defensive)")
    }

    // MARK: - temporal escalation + boundedness

    func testSustainedPressureAccumulatesAndStaysBounded() throws {
        let affs = [affect(0.95, 0.95, 0.9)]
        let hist = ["urgent now act immediately or lose everything"]
        let cs = [cand(0.1, 0.95, 0.1, 0.2)]
        var state: [Float]?
        var cautions: [Double] = []
        for i in 0..<20 {
            let obs = try XCTUnwrap(BASSSMCautionInput.observation(
                sessionID: "s", turnID: "t\(i)", affectLayers: affs, turnHistory: hist,
                candidates: cs, priorState: state))
            cautions.append(obs.ssmCaution)
            state = obs.ssmStateOut
            XCTAssertTrue((state ?? []).allSatisfy { $0.isFinite },
                "the carried state stays finite (A<0 contraction)")
        }
        XCTAssertGreaterThanOrEqual(cautions.last!, cautions.first!,
            "sustained pressure accumulates ⇒ caution never falls below the single-turn value")
        let finalMax = (state ?? []).map { abs($0) }.max() ?? 0
        XCTAssertLessThan(finalMax, 100, "the contractive recurrence keeps the carried state bounded")
    }

    // MARK: - Codable backward-compat

    func testObservationCodableWithAndWithoutStateOut() throws {
        let obs = BASMambaSSMTurnObservation(
            sessionID: "s", turnID: "t", affectCount: 1, historyCount: 1, candidateCount: 1,
            ssmCaution: 0.5, finalMagnitude: 0.01, gpuShadowMAE: nil, ssmStateOut: [0.1, 0.2, 0.3])
        XCTAssertEqual(try JSONDecoder().decode(
            BASMambaSSMTurnObservation.self, from: JSONEncoder().encode(obs)), obs)
        // A pre-field encoding (no ssmStateOut / no gpuShadowMAE) must still decode ⇒ both nil.
        let oldJSON = #"{"sessionID":"s","turnID":"t","affectCount":1,"historyCount":1,"candidateCount":1,"ssmCaution":0.5,"finalMagnitude":0.01}"#
        let decoded = try JSONDecoder().decode(
            BASMambaSSMTurnObservation.self, from: Data(oldJSON.utf8))
        XCTAssertNil(decoded.ssmStateOut)
        XCTAssertNil(decoded.gpuShadowMAE)
    }

    // MARK: - request wire-format (turnHistory + priorSSMState custom decoder)

    func testRequestCodableRoundTripWithNewFields() throws {
        let req = BASEBrainTurnRequest(
            userInput: "hi",
            deviceState: BASCoordinatorTestStubs.nominalDeviceState,
            hostID: "h",
            turnHistory: ["t1", "t2"],
            priorSSMState: [0.1, 0.2, 0.3])
        let decoded = try JSONDecoder().decode(
            BASEBrainTurnRequest.self, from: JSONEncoder().encode(req))
        XCTAssertEqual(decoded.turnHistory, ["t1", "t2"])
        XCTAssertEqual(decoded.priorSSMState, [0.1, 0.2, 0.3])
        XCTAssertEqual(decoded, req, "full Codable round-trip is identity")
    }

    func testRequestDecodesOldEncodingWithoutNewFields() throws {
        // Simulate a pre-turnHistory/priorSSMState encoding: encode, strip the new keys, decode.
        let req = BASEBrainTurnRequest(
            userInput: "hi",
            deviceState: BASCoordinatorTestStubs.nominalDeviceState,
            hostID: "h",
            turnHistory: ["x"],
            priorSSMState: [0.5])
        var obj = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(req)) as? [String: Any])
        obj.removeValue(forKey: "turnHistory")
        obj.removeValue(forKey: "priorSSMState")
        let stripped = try JSONSerialization.data(withJSONObject: obj)
        let decoded = try JSONDecoder().decode(BASEBrainTurnRequest.self, from: stripped)
        XCTAssertEqual(decoded.turnHistory, [], "absent turnHistory ⇒ [] (backward-compatible)")
        XCTAssertNil(decoded.priorSSMState, "absent priorSSMState ⇒ nil (backward-compatible)")
        XCTAssertEqual(decoded.userInput, "hi")
        XCTAssertEqual(decoded.hostID, "h")
    }
}
