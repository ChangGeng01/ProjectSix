// ADR-039 Phase 5 — Metal attention → NON-governance reasoning side-channel (the FIRST live consumer of
// the Phase-3 dispatch router). Mirrors the Phase-4 SSM reasoning sink exactly:
//   • runTurn emits the per-turn DETERMINISTIC attention input to a default-nil sink (Metal-free, sync);
//   • the HOST runs `BASMetalAttentionDispatcher` OFF the sync turn thread, ROUTED by
//     `BASMetalKernelDispatchRouter.decide(op:.attention …)` (thermal-critical ⇒ CPU);
//   • the result is a salience reasoning magnitude that feeds NO verdict/permit/commit/render/seal/replay
//     and never folds into governance — so a Metal wedge can NEVER block the deterministic path.

import Foundation
import BASMetalSubstrate

/// The per-turn DETERMINISTIC attention input emitted to the (default-nil) reasoning sink (+ turn identity).
public struct BASAttentionReasoningTurnInput: Sendable, Equatable {
    public let sessionID: String
    public let turnID: String
    public let input: BASAttentionTurnInput
    public init(sessionID: String, turnID: String, input: BASAttentionTurnInput) {
        self.sessionID = sessionID
        self.turnID = turnID
        self.input = input
    }
}

/// The Metal-derived per-turn attention reasoning signal (NON-governance). `magnitude` = mean |attention
/// output| (a bounded reasoning heuristic, never a verdict input). Never crosses the byte-deterministic spine.
public struct BASAttentionReasoningSignal: Sendable, Equatable {
    public let sessionID: String
    public let turnID: String
    public let magnitude: Double
    public let routing: String       // the Phase-3 router's CHOICE (mps-graph / raw-metal / cpu-stub)
    public let didRunOnGPU: Bool
    public let durationMs: Double
    public init(
        sessionID: String, turnID: String, magnitude: Double,
        routing: String, didRunOnGPU: Bool, durationMs: Double
    ) {
        self.sessionID = sessionID
        self.turnID = turnID
        self.magnitude = magnitude
        self.routing = routing
        self.didRunOnGPU = didRunOnGPU
        self.durationMs = durationMs
    }
}

/// Host-side runner: dispatches Metal single-head attention on an emitted input, ROUTED by the Phase-3
/// router, and reduces the output to a reasoning magnitude. ASYNC + GPU — the caller MUST invoke it OFF the
/// sync turn thread (never inside runTurn). Returns nil on a Metal fault (caller records the fallback).
public enum BASAttentionMetalReasoning {

    /// Mean absolute value of the attention output — a deterministic-shape reasoning reduction.
    static func magnitude(of y: [Float]) -> Double {
        guard !y.isEmpty else { return 0 }
        var acc: Double = 0
        for v in y { acc += Double(abs(v)) }
        return acc / Double(y.count)
    }

    /// Pure-CPU single-head attention reference: softmax(Q·Kᵀ/√D)·V → (1×D). Used for parity tests AND as
    /// the deterministic compute when the router declines the accelerator (thermal-critical).
    public static func cpuReference(_ inp: BASAttentionTurnInput) -> [Float] {
        let D = inp.cols, N = inp.kRows
        guard D > 0, N > 0, inp.q.count == D, inp.k.count == N * D, inp.v.count == N * D else { return [] }
        let scale = 1.0 / Float(D).squareRoot()
        var scores = [Float](repeating: 0, count: N)
        for j in 0..<N {
            var dot: Float = 0
            for d in 0..<D { dot += inp.q[d] * inp.k[j * D + d] }
            scores[j] = dot * scale
        }
        let maxScore = scores.max() ?? 0          // numerically-stable softmax
        var sum: Float = 0
        for j in 0..<N { scores[j] = Foundation.exp(scores[j] - maxScore); sum += scores[j] }
        if sum > 0 { for j in 0..<N { scores[j] /= sum } }
        var out = [Float](repeating: 0, count: D)
        for j in 0..<N { for d in 0..<D { out[d] += scores[j] * inp.v[j * D + d] } }
        return out
    }

    /// Run attention ROUTED by the Phase-3 router (thermal-critical / cpu-stub ⇒ the CPU reference, no GPU).
    /// Returns nil on a Metal fault. ASYNC + GPU — invoke OFF the sync turn thread.
    public static func run(
        _ payload: BASAttentionReasoningTurnInput,
        loader: BASMetalKernelLibraryLoader,
        thermalState: BASCapabilityThermalSnapshot,
        anePriority: BASAcceleratorPriority
    ) async -> BASAttentionReasoningSignal? {
        let inp = payload.input
        let decision = BASMetalKernelDispatchRouter.decide(
            op: .attention, thermalState: thermalState, anePriority: anePriority)
        let t0 = DispatchTime.now().uptimeNanoseconds

        if decision.declinedAccelerator {
            // Router declined the GPU (thermal-critical) → deterministic CPU reference, no Metal.
            let y = cpuReference(inp)
            let ms = Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
            return BASAttentionReasoningSignal(
                sessionID: payload.sessionID, turnID: payload.turnID, magnitude: magnitude(of: y),
                routing: decision.routing.rawValue, didRunOnGPU: false, durationMs: ms)
        }

        guard let y = try? await BASMetalAttentionDispatcher(loader: loader).dispatch(
            q: inp.q, qRows: inp.qRows, qCols: inp.cols,
            k: inp.k, kRows: inp.kRows, v: inp.v, vCols: inp.cols)
        else { return nil }
        let ms = Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
        return BASAttentionReasoningSignal(
            sessionID: payload.sessionID, turnID: payload.turnID, magnitude: magnitude(of: y),
            routing: decision.routing.rawValue, didRunOnGPU: true, durationMs: ms)
    }
}
