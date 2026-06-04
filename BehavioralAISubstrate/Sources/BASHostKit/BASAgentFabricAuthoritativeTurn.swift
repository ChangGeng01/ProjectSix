// MARK: - BASAgentFabricAuthoritativeTurn — host wiring for the multi-round authoritative loop
//
// Makes `BASAgentFabricMultiRoundLoop` FUNCTIONAL end-to-end: composes the existing pieces so a host can
// go from a turn's L7/L9 outputs → the converged authoritative input → an enriched NEXT request in one
// call. The host owns the cross-turn threading (turn N's result enriches turn N+1); the enriched input
// flows through the SAME verdict-gated cascade (INPUT-class — 红线 7; 不变量 #2 神经不掌权; the sovereign
// verdict stays the sole authority). Additive (no runTurn / verdict / coordinator code); opt-in
// (`mode == .observationOnly` ⇒ loop inert ⇒ the request is returned UNCHANGED ⇒ byte-equal-off).
//
// Data flow: `BASEBrainTurnResult` (decompose + candidates) → `BASAgentFabricAdapters.turnInput` →
// `BASAgentFabricMultiRoundLoop.run(runtime:)` → `finalProjection` →
// `BASAgentFabricAuthoritativeProjection.enrichedRequest` → the host's next `coordinator.runTurn(...)`.

import Foundation
import BASOrchestration
import BASMemory

public enum BASAgentFabricAuthoritativeTurn {

    /// Build the fabric input from a turn's decompose + candidates (via `BASAgentFabricAdapters`), run
    /// the multi-round loop on `runtime`, and return its result (carrying the converged finalProjection).
    public static func loopResult(
        decomposeFrame: BASDecomposeFrame,
        candidatePaths: [BASCandidatePath],
        acceptedCandidateID: String? = nil,
        runtime: BASAgentFabricRuntime,
        config: BASAgentFabricMultiRoundConfig,
        refine: @Sendable (BASAgentTurnInput, BASAgentFabricAuthoritativeInput) -> BASAgentTurnInput
            = { input, _ in input }
    ) async -> BASAgentFabricMultiRoundResult {
        let input = BASAgentFabricAdapters.turnInput(
            turnID: config.baseTurnID,
            decomposeFrame: decomposeFrame,
            candidatePaths: candidatePaths,
            acceptedCandidateID: acceptedCandidateID,
            nowNanos: config.nowNanos)
        return await BASAgentFabricMultiRoundLoop.run(
            runtime: runtime, initialInput: input, config: config, refine: refine)
    }

    /// Run the loop for THIS turn's outputs and enrich the NEXT request with the converged conclusions.
    /// Returns `next` UNCHANGED when the loop produced no projection (mode-inert / no accepted deltas) —
    /// byte-equal-off. The host then runs the (possibly-enriched) request through the normal
    /// verdict-gated turn; the `loop` result is returned alongside for audit/telemetry.
    public static func enrichedNextRequest(
        _ next: BASEBrainTurnRequest,
        decomposeFrame: BASDecomposeFrame,
        candidatePaths: [BASCandidatePath],
        acceptedCandidateID: String? = nil,
        runtime: BASAgentFabricRuntime,
        config: BASAgentFabricMultiRoundConfig,
        refine: @Sendable (BASAgentTurnInput, BASAgentFabricAuthoritativeInput) -> BASAgentTurnInput
            = { input, _ in input }
    ) async -> (request: BASEBrainTurnRequest, loop: BASAgentFabricMultiRoundResult) {
        let loop = await loopResult(
            decomposeFrame: decomposeFrame,
            candidatePaths: candidatePaths,
            acceptedCandidateID: acceptedCandidateID,
            runtime: runtime,
            config: config,
            refine: refine)
        guard let projection = loop.finalProjection else { return (next, loop) }
        return (
            BASAgentFabricAuthoritativeProjection.enrichedRequest(next, with: projection),
            loop)
    }
}
