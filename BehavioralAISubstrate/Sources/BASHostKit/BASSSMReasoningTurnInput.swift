// ADR-039 Phase 4 — Metal SSMScan → NON-governance reasoning side-channel.
//
// The CPU `ssmCaution` operator (BASSSMCautionInput, RunTurn.swift:521-566) stays the AUTHORITATIVE,
// byte-deterministic value path that feeds the verdict — UNCHANGED. Phase 4 adds a SECOND, opt-in path: the
// coordinator emits the per-turn DETERMINISTIC scan input (the same `BASMambaTurnScanInput` the CPU path is
// built from) to a default-nil `ssmReasoningInputSink`; the HOST runs the Metal `SSMScan` kernel on it
// ASYNC, OFF the sync turn thread. The Metal result is a reasoning signal that:
//   • feeds NO verdict / permit / commit-token / render / seal / replay digest (it is never in the
//     BASEBrainTurnResult struct, which is the replay-digest preimage) → flag-on is byte-identical to off;
//   • NEVER folds into `request.priorSSMState` (the CPU `ssmStateOut` owns the deterministic recurrence);
//   • is computed off the turn thread, so a Metal wedge (ADR-038, uncancellable) can NEVER block the
//     deterministic path — the doctrine's "never block the deterministic path on Metal", honored strictly.

import Foundation
import BASMetalSubstrate

/// The per-turn DETERMINISTIC SSM scan input emitted to the (default-nil) reasoning sink. Carries the turn
/// identity so the host can attribute the asynchronously-computed reasoning signal. Pure value type.
public struct BASSSMReasoningTurnInput: Sendable, Equatable {
    public let sessionID: String
    public let turnID: String
    public let scanInput: BASMambaTurnScanInput
    public init(sessionID: String, turnID: String, scanInput: BASMambaTurnScanInput) {
        self.sessionID = sessionID
        self.turnID = turnID
        self.scanInput = scanInput
    }
}

/// The Metal-derived per-turn reasoning signal (NON-governance). `magnitude` = mean |y| of the Metal SSM
/// scan output (a bounded reasoning heuristic, never a verdict input). `didRunOnGPU` / `durationMs` feed the
/// endurance records. This NEVER crosses into the byte-deterministic spine.
public struct BASSSMReasoningSignal: Sendable, Equatable {
    public let sessionID: String
    public let turnID: String
    public let magnitude: Double
    public let didRunOnGPU: Bool
    public let durationMs: Double
    public init(
        sessionID: String, turnID: String,
        magnitude: Double, didRunOnGPU: Bool, durationMs: Double
    ) {
        self.sessionID = sessionID
        self.turnID = turnID
        self.magnitude = magnitude
        self.didRunOnGPU = didRunOnGPU
        self.durationMs = durationMs
    }
}

/// Host-side runner: dispatches the Metal `SSMScan` kernel on an emitted scan input and reduces the output
/// to a reasoning magnitude. ASYNC + GPU — the caller MUST invoke it OFF the sync turn thread (never inside
/// `runTurn`). Returns nil on a Metal fault (the caller records the fallback; nothing crosses governance).
public enum BASSSMMetalReasoning {

    /// Mean absolute value of the Metal SSM scan output — a deterministic-shape reasoning reduction. The
    /// VALUE is GPU-derived (non-bit-reproducible) → reasoning-side only, never the spine.
    static func magnitude(of y: [Float]) -> Double {
        guard !y.isEmpty else { return 0 }
        var acc: Double = 0
        for v in y { acc += Double(abs(v)) }
        return acc / Double(y.count)
    }

    /// Run the Metal SSMScan on the input + reduce. Returns nil if Metal faults / is unavailable. The
    /// caller is responsible for any timeout / in-flight gating (this is a plain async dispatch).
    public static func run(
        _ input: BASSSMReasoningTurnInput,
        loader: BASMetalKernelLibraryLoader
    ) async -> BASSSMReasoningSignal? {
        let s = input.scanInput
        let t0 = DispatchTime.now().uptimeNanoseconds
        guard let y = try? await BASMetalSSMScanDispatcher(loader: loader).dispatch(
            x: s.x, delta: s.delta, A: s.a, B: s.b, C: s.c, shape: s.shape)
        else { return nil }
        let ms = Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
        return BASSSMReasoningSignal(
            sessionID: input.sessionID, turnID: input.turnID,
            magnitude: magnitude(of: y), didRunOnGPU: true, durationMs: ms)
    }
}
