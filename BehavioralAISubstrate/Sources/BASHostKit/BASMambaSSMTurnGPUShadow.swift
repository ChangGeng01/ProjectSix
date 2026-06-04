// MARK: - BASMambaSSMTurnGPUShadow
// chapter 一百八十七 / 一百九十 — per-turn GPU shadow for the SSM operator (telemetry only)
//
// Runs the GPU twin of the operator's ACTUAL value-path scan as a per-turn SHADOW and reports the
// CPU-vs-GPU MAE (`BASMambaGPUShadowParity.perChannelParityMAE`). The authoritative `ssmCaution` is
// ALWAYS the sync per-channel CPU reference (`BASSSMCautionInput`); this adds the GPU parity number as
// OBSERVATION-ONLY telemetry, a step toward an eventual GPU-authoritative path. ASYNC + GPU ⇒ NEVER on
// the sync byte-deterministic seam (ch883); host-callable from the observation surface / device probe.
//
// chapter 一百九十 — the shadow now measures the operator's REAL per-channel scan: it compares
// `BASSSMScanCPUReference` (the operator's CPU value path) against `BASMetalSSMScanDispatcher` (its GPU
// twin, the chapter 677 `ssm_scan_float32` MSL kernel) on the turn's actual x/delta/A/B/C — closing the
// earlier "state-space proxy" caveat. The per-channel CPU↔GPU parity is itself proven ≤ 1e-5 by the
// chapter 680 numerical-proof tests.

import Foundation
import BASOrchestration
import BASMetalSubstrate

public enum BASMambaSSMTurnGPUShadow {

    /// A representative per-turn GPU-shadow MAE for an on-device probe / benchmark that lacks a live
    /// turn (a fixed high-pressure-shaped turn), or nil if Metal is unavailable. Lets the device probe
    /// measure the real-silicon CPU-vs-GPU parity with a single BASHostKit call (no extra imports).
    public static func representativeParityMAE() async -> Double? {
        await maeForTurn(
            affectLayers: [BASAffectLayer(
                tone: "t", intensity: 0.9, volatility: 0.8, spilloverRisk: 0.7)],
            turnHistory: ["high tension escalating now"],
            candidates: [BASCandidatePath(
                candidateID: "c", title: "t", actionSummary: "a",
                expectedBenefit: 0.2, expectedCost: 0.9, reversibility: 0.2, confidence: 0.3)])
    }

    /// PER-CHANNEL CPU-vs-GPU MAE on the operator's ACTUAL value-path scan for this turn's three sources,
    /// or nil (all sources empty OR GPU unavailable). ASYNC + GPU — telemetry only, off the
    /// byte-deterministic value path.
    public static func maeForTurn(
        affectLayers: [BASAffectLayer],
        turnHistory: [String],
        candidates: [BASCandidatePath]
    ) async -> Double? {
        guard let turn = BASMambaTurnSignalBuilder.scanInput(
            affectLayers: affectLayers, turnHistory: turnHistory, candidates: candidates)
        else { return nil }
        // The turn's REAL per-channel scan input (the same x/delta/A/B/C the CPU value path uses).
        return await BASMambaGPUShadowParity.perChannelParityMAE(
            x: turn.x, delta: turn.delta, A: turn.a, B: turn.b, C: turn.c, shape: turn.shape)
    }

    /// The per-turn observation WITH the GPU-shadow MAE attached. The authoritative ssmCaution /
    /// finalMagnitude / counts are byte-identical to `BASSSMCautionInput.observation` (the CPU value is
    /// untouched by the shadow); only `gpuShadowMAE` is added. nil when all three sources are empty.
    public static func observationWithGPUShadow(
        sessionID: String,
        turnID: String,
        affectLayers: [BASAffectLayer],
        turnHistory: [String],
        candidates: [BASCandidatePath]
    ) async -> BASMambaSSMTurnObservation? {
        guard let base = BASSSMCautionInput.observation(
            sessionID: sessionID, turnID: turnID,
            affectLayers: affectLayers, turnHistory: turnHistory, candidates: candidates)
        else { return nil }
        let mae = await maeForTurn(
            affectLayers: affectLayers, turnHistory: turnHistory, candidates: candidates)
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
