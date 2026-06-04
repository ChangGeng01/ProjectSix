// MARK: - BASMambaSSMTurnGPUShadow
// chapter 一百八十七 — per-turn GPU shadow for the SSM operator (telemetry only)
//
// Runs the existing state-space Metal selective-scan kernel as a per-turn SHADOW alongside the
// authoritative CPU value path, and reports the CPU-vs-GPU MAE (`BASMambaGPUShadowParity`). The
// authoritative `ssmCaution` is ALWAYS the sync per-channel CPU reference (`BASSSMCautionInput`);
// this adds the GPU parity number as OBSERVATION-ONLY telemetry, a step toward an eventual
// GPU-authoritative path. ASYNC + GPU ⇒ NEVER on the sync byte-deterministic seam (ch883); it is
// host-callable from the observation surface / device probe only.
//
// NOTE on form: the operator's authoritative value path is the PER-CHANNEL reference scan, whereas the
// existing Metal kernel is STATE-SPACE. So this shadow exercises the GPU kernel on the turn's x/delta
// features in state-space form (a/b/c synthesized from the same fixed scan constants at a small fixed
// stateDim) — it measures GPU-kernel fidelity vs its CPU twin on real per-turn data, not a GPU
// recomputation of the per-channel ssmCaution (a per-channel GPU kernel is a deeper follow-up).

import Foundation
import BASOrchestration
import BASMetalSubstrate

public enum BASMambaSSMTurnGPUShadow {

    /// State-space stateDim for the GPU-shadow parity scan (a small, fixed multi-state scan).
    public static let shadowStateDim: Int = 4

    /// Build a state-space scan input from the per-turn signal: reuse the turn's x/delta (both B*L*D in
    /// either form) and synthesize a:(D*N) + b/c:(B*L*N) from the same fixed scan constants.
    static func stateSpaceInputs(
        from turn: BASMambaTurnScanInput, stateDim N: Int
    ) -> (BASMambaSSMScanInputs, BASMambaSSMShape) {
        let B = BASMambaTurnOperatorShape.batch
        let D = BASMambaTurnOperatorShape.hiddenDim
        let L = BASMambaTurnOperatorShape.sequenceLength
        let shape = BASMambaSSMShape(batch: B, hiddenDim: D, stateDim: N)
        let inputs = BASMambaSSMScanInputs(
            x: turn.x,
            delta: turn.delta,
            a: [Float](repeating: BASMambaTurnOperatorShape.aConstant, count: D * N),
            b: [Float](repeating: BASMambaTurnOperatorShape.bConstant, count: B * L * N),
            c: [Float](repeating: BASMambaTurnOperatorShape.cConstant, count: B * L * N),
            sequenceLength: L)
        return (inputs, shape)
    }

    /// CPU-vs-GPU selective-scan MAE for this turn's three sources, or nil (all sources empty OR GPU
    /// unavailable). ASYNC + GPU — telemetry only, off the byte-deterministic value path.
    public static func maeForTurn(
        affectLayers: [BASAffectLayer],
        turnHistory: [String],
        candidates: [BASCandidatePath],
        stateDim: Int = shadowStateDim
    ) async -> Double? {
        guard let turn = BASMambaTurnSignalBuilder.scanInput(
            affectLayers: affectLayers, turnHistory: turnHistory, candidates: candidates)
        else { return nil }
        let (inputs, shape) = stateSpaceInputs(from: turn, stateDim: stateDim)
        return await BASMambaGPUShadowParity.parityMAE(inputs: inputs, shape: shape)
    }

    /// The per-turn observation WITH the GPU-shadow MAE attached. The authoritative ssmCaution /
    /// finalMagnitude / counts are byte-identical to `BASSSMCautionInput.observation` (the CPU value is
    /// untouched by the shadow); only `gpuShadowMAE` is added. nil when all three sources are empty.
    public static func observationWithGPUShadow(
        sessionID: String,
        turnID: String,
        affectLayers: [BASAffectLayer],
        turnHistory: [String],
        candidates: [BASCandidatePath],
        stateDim: Int = shadowStateDim
    ) async -> BASMambaSSMTurnObservation? {
        guard let base = BASSSMCautionInput.observation(
            sessionID: sessionID, turnID: turnID,
            affectLayers: affectLayers, turnHistory: turnHistory, candidates: candidates)
        else { return nil }
        let mae = await maeForTurn(
            affectLayers: affectLayers, turnHistory: turnHistory,
            candidates: candidates, stateDim: stateDim)
        return BASMambaSSMTurnObservation(
            sessionID: base.sessionID,
            turnID: base.turnID,
            affectCount: base.affectCount,
            historyCount: base.historyCount,
            candidateCount: base.candidateCount,
            ssmCaution: base.ssmCaution,
            finalMagnitude: base.finalMagnitude,
            gpuShadowMAE: mae)
    }
}
