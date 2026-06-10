// MARK: - BASSSMNeuromodulationField — T3.2 (SSM neuromodulation field extension, OBSERVATION-ONLY)
//
// Pure projector deriving a per-turn NEUROMODULATION SUGGESTION record from the CPU-deterministic
// `ssmCaution ∈ [0,1]`: more sustained temporal pressure ⇒ suggest MORE deliberation passes (L9) and a
// MORE CONSERVATIVE kernel power budget (L2). The record is attached to the (opt-in) SSM observation
// side-channel ONLY — it is NEVER written into `boundRiskCard` / `thoughtFrame` / the returned
// `BASEBrainTurnResult`, so it is OFF the replay-digest preimage by construction
// (`BASEBrainTurnResultReplayDigest` hashes the FULL turn result; zero SSM fields live there).
//
// SAFE BY CONSTRUCTION (the invariants are ENFORCED here, not just tested):
//   • ADR-019 raise-only — `suggestedTargetPasses(...)` is SIGN-PINNED ≥ the actual pass count by a
//     terminal clamp; a suggestion toward LESS deliberation is unrepresentable. A degenerate caution
//     (NaN / out-of-range) clamps to [0,1] first (NaN → 0 → suggestion == actual).
//   • Conserve-only — `suggestedOrganPowerBudget(...)` is SIGN-PINNED ≤ the host-hint budget tier by a
//     terminal `min`; a suggestion toward a HOTTER backend tier is unrepresentable.
//   • Gates never auto-promote — the output is a RECORD forever. Nothing in this file (or its single
//     call site) applies the suggested passes/budget to any live path; applying them would be a
//     separate, explicitly-gated future item.
//   • ADR-014 / 红线 7 — the single call site is nested behind `ssmNeuromodulationSuggestionsEnabled`
//     (default OFF) inside the already-flag-gated SSM operator block: flag-off ⇒ the field stays nil ⇒
//     byte-equal + zero computation.
//   • Purity — same inputs ⇒ same outputs. No clock, no randomness, no I/O: the L2 backends come from
//     the PURE Rust policy port (`bas_organ_router_select`) and the attention actual from the PURE
//     ADR-039 Phase-3 dispatch router (`BASMetalKernelDispatchRouter.decide`, replay-stable CHOICE).
//
// L2 POLICY-COUNTERFACTUAL HONESTY (load-bearing): `bas_organ_router_select` is a PURE policy function
// with NO live production caller today (Cargo/bas-organ-router/src/lib.rs — the L2 kernels are not yet
// routed through it). `suggestedBackendByFamily` is therefore a POLICY COUNTERFACTUAL — "what the Rust
// routing policy WOULD select at the suggested budget" vs "what it would select at the host-hint
// budget" — NOT a record of a dispatch that actually happened. The only LIVE deterministic routing
// surface recorded here is `actualAttentionBackend` (the ADR-039 Phase-3 attention CHOICE, recomputable
// from `request.deviceState`), and it speaks the dispatch-router vocabulary, not the organ-router one.

import Foundation
import BASRuntimeCore
import BASMetalSubstrate

/// The per-turn SSM neuromodulation suggestion RECORD (observation-only, suggestion ≠ application).
/// Carried as an optional field on `BASMambaSSMTurnObservation` (absent-key Codable-backward, the
/// `gpuShadowMAE` precedent). String-typed tiers/backends keep the JSON audit surface self-describing.
public struct BASSSMNeuromodulationSuggestion:
    Codable, Equatable, Hashable, Sendable
{
    /// Suggested deliberation pass budget — SIGN-PINNED ≥ `actualTargetPasses` (raise-only: more
    /// caution can only suggest MORE deliberation), clamped into the live loop's own normalization
    /// band (ceiling = the thermally-floored maxLoops the loop itself respects).
    public let suggestedTargetPasses: Int
    /// The pass budget the live loop ACTUALLY targeted this turn (1 when the loop is disabled).
    public let actualTargetPasses: Int
    /// `suggestedTargetPasses - actualTargetPasses` — ≥ 0 by the raise-only pin.
    public let deltaPasses: Int
    /// Suggested L2 organ power budget tier — SIGN-PINNED ≤ `hostHintBudget` (conserve-only).
    public let suggestedOrganPowerBudget: String
    /// The host-hint L2 budget tier (derived deterministically from the request's thermal level).
    public let hostHintBudget: String
    /// POLICY-COUNTERFACTUAL — the pure Rust routing policy's per-family backend at the SUGGESTED
    /// budget (`bas_organ_router_select`, no live production caller; see the file-header honesty note).
    /// Keyed by kernel-family name; empty when the FFI is unavailable on this platform.
    public let suggestedBackendByFamily: [String: String]
    /// The LIVE deterministic attention-path routing CHOICE (ADR-039 Phase-3
    /// `BASMetalKernelDispatchRouter.decide(op: .attention …)`), recomputed from the request's device
    /// state — replay-stable by design. nil when not derivable.
    public let actualAttentionBackend: String?

    public init(
        suggestedTargetPasses: Int,
        actualTargetPasses: Int,
        deltaPasses: Int,
        suggestedOrganPowerBudget: String,
        hostHintBudget: String,
        suggestedBackendByFamily: [String: String],
        actualAttentionBackend: String? = nil
    ) {
        self.suggestedTargetPasses = suggestedTargetPasses
        self.actualTargetPasses = actualTargetPasses
        self.deltaPasses = deltaPasses
        self.suggestedOrganPowerBudget = suggestedOrganPowerBudget
        self.hostHintBudget = hostHintBudget
        self.suggestedBackendByFamily = suggestedBackendByFamily
        self.actualAttentionBackend = actualAttentionBackend
    }
}

enum BASSSMNeuromodulationField {

    // MARK: - Calibration constants (chapter 一百八十五 — named, not magic literals)

    /// Caution at or above this steps the suggested L2 budget down ONE tier from the host hint.
    static let conserveOneTierThreshold = 1.0 / 3.0
    /// Caution at or above this steps the suggested L2 budget down TWO tiers (to the floor).
    static let conserveTwoTiersThreshold = 2.0 / 3.0
    /// Pinned probe shape for the L2 policy counterfactual — the mid band (256..<1024) where the
    /// budget tier materially changes the routing (constrained ⇒ CpuReference, normal/generous ⇒
    /// MpsGraph/RustSimd), so the record discriminates. A single pinned shape keeps the
    /// counterfactual deterministic and honest (it is a POLICY probe, not a live dispatch).
    static let counterfactualShapeSize: Int32 = 512

    /// The six kernel families the L2 policy routes, with their pinned record names (kebab-case,
    /// matching the `BASNeuralOp` raw-value vocabulary where the op exists there).
    static let familyNamePairs:
        [(family: BASAutoRouteRanker.OrganRouterFamily, name: String)] = [
            (.attention, "attention"),
            (.matMul, "mat-mul"),
            (.layerNorm, "layer-norm"),
            (.rmsNorm, "rms-norm"),
            (.softmax, "softmax"),
            (.activation, "activation"),
        ]

    // MARK: - Pure helpers

    /// Defensive [0,1] clamp shared by both projections — NaN → 0 (no suggestion drift), mirroring
    /// `BASSSMCautionInput.raisedTotalRisk`'s degenerate-scan handling.
    static func clampedCaution(_ ssmCaution: Double) -> Double {
        ssmCaution.isNaN ? 0 : min(1.0, max(0.0, ssmCaution))
    }

    /// Raise-only suggested deliberation pass budget. Linear in caution across the live loop's own
    /// normalization band: caution 0 ⇒ exactly `actualTargetPasses`; caution 1 ⇒ the thermally-floored
    /// ceiling (the SAME `BASDeliberationThermalFloor`-floored `maxLoops` bound the live `targetPasses`
    /// is min'd against), so the suggestion never exceeds what the loop itself would respect.
    /// ENFORCED INVARIANT: the terminal clamp pins the result to ≥ `actualTargetPasses` for EVERY
    /// input (including degenerate caution) — suggesting LESS deliberation is unrepresentable.
    static func suggestedTargetPasses(
        ssmCaution: Double,
        actualTargetPasses: Int,
        thermallyFlooredMaxLoops: Int
    ) -> Int {
        let s = clampedCaution(ssmCaution)
        let raiseFloor = max(1, actualTargetPasses)
        let bandCeiling = max(raiseFloor, thermallyFlooredMaxLoops)
        let raw = raiseFloor
            + Int((s * Double(bandCeiling - raiseFloor)).rounded())
        // The raise-only sign pin (≥ actual) + band cap — enforced, not assumed.
        return min(bandCeiling, max(raiseFloor, raw))
    }

    /// Deterministic host-hint L2 budget tier from the request's thermal level. Exhaustive switch
    /// (no `default:`) — the `BASDeliberationThermalFloor` anti-drift discipline: a future
    /// `BASThermalLevel` case forces an explicit compile-time decision here.
    static func hostHintBudget(
        thermalLevel: BASThermalLevel
    ) -> BASAutoRouteRanker.OrganRouterBudget {
        switch thermalLevel {
        case .nominal:
            return .generous
        case .warm:
            return .normal
        case .hot, .critical:
            return .constrained
        }
    }

    /// Conserve-only suggested L2 budget tier: the host hint stepped DOWN by 0/1/2 tiers as caution
    /// crosses the thresholds, floored at `.constrained`.
    /// ENFORCED INVARIANT: the terminal `min` pins the result tier to ≤ the host hint for EVERY
    /// input — suggesting a HOTTER backend tier is unrepresentable.
    static func suggestedOrganPowerBudget(
        ssmCaution: Double,
        hostHint: BASAutoRouteRanker.OrganRouterBudget
    ) -> BASAutoRouteRanker.OrganRouterBudget {
        let s = clampedCaution(ssmCaution)
        let tiersDown: Int32 = s >= conserveTwoTiersThreshold
            ? 2 : (s >= conserveOneTierThreshold ? 1 : 0)
        let floored = max(
            BASAutoRouteRanker.OrganRouterBudget.constrained.rawValue,
            hostHint.rawValue - tiersDown)
        // The conserve-only sign pin (≤ hint) — enforced, not assumed.
        let pinned = min(hostHint.rawValue, floored)
        return BASAutoRouteRanker.OrganRouterBudget(rawValue: pinned)
            ?? .constrained
    }

    /// POLICY-COUNTERFACTUAL per-family backend map at `budget` via the PURE Rust policy port
    /// (`bas_organ_router_select` — NO live production caller; see the file-header honesty note).
    /// Deterministic given the budget (pure i32 policy at a pinned probe shape). A family whose FFI
    /// call faults (or a non-Apple platform) is omitted rather than guessed.
    static func suggestedBackendByFamily(
        budget: BASAutoRouteRanker.OrganRouterBudget
    ) -> [String: String] {
        var byFamily: [String: String] = [:]
        for pair in familyNamePairs {
            guard let backend = BASAutoRouteRanker.organRouterSelect(
                family: pair.family,
                shapeSize: counterfactualShapeSize,
                budget: budget)
            else { continue }
            byFamily[pair.name] = backendName(backend)
        }
        return byFamily
    }

    /// The LIVE deterministic attention-path routing CHOICE — the ADR-039 Phase-3 router recomputed
    /// from the request's device state (thermal level + NPU availability). The CHOICE is a pure
    /// function of its inputs (replay-stable by ADR-039 design); only the kernel COMPUTE behind it is
    /// approximate, and none of that runs here.
    static func actualAttentionBackend(
        thermalLevel: BASThermalLevel,
        npuAvailable: Bool
    ) -> String {
        BASMetalKernelDispatchRouter.decide(
            op: .attention,
            thermalState: thermalSnapshot(for: thermalLevel),
            anePriority: npuAvailable ? .aneFirst : .gpuOnly
        ).routing.rawValue
    }

    /// `BASThermalLevel` (control-plane vocabulary) → `BASCapabilityThermalSnapshot` (substrate
    /// vocabulary). Exhaustive switch — anti-drift discipline as above.
    static func thermalSnapshot(
        for thermalLevel: BASThermalLevel
    ) -> BASCapabilityThermalSnapshot {
        switch thermalLevel {
        case .nominal:
            return .nominal
        case .warm:
            return .fair
        case .hot:
            return .serious
        case .critical:
            return .critical
        }
    }

    /// Pinned record name for an L2 budget tier.
    static func budgetName(
        _ budget: BASAutoRouteRanker.OrganRouterBudget
    ) -> String {
        switch budget {
        case .constrained: return "constrained"
        case .normal: return "normal"
        case .generous: return "generous"
        }
    }

    /// Pinned record name for an L2 backend.
    static func backendName(
        _ backend: BASAutoRouteRanker.OrganRouterBackend
    ) -> String {
        switch backend {
        case .cpuReference: return "cpu-reference"
        case .metalKernel: return "metal-kernel"
        case .mpsGraph: return "mps-graph"
        case .rustSimd: return "rust-simd"
        }
    }

    // MARK: - Composer

    /// Compose the full per-turn suggestion RECORD. Pure: same inputs ⇒ same record (no clock, no
    /// randomness, no I/O). Both sign pins (raise-only passes, conserve-only budget) are enforced by
    /// the component projections above.
    static func suggestion(
        ssmCaution: Double,
        actualTargetPasses: Int,
        thermallyFlooredMaxLoops: Int,
        thermalLevel: BASThermalLevel,
        npuAvailable: Bool
    ) -> BASSSMNeuromodulationSuggestion {
        let hint = hostHintBudget(thermalLevel: thermalLevel)
        let budget = suggestedOrganPowerBudget(
            ssmCaution: ssmCaution, hostHint: hint)
        let passes = suggestedTargetPasses(
            ssmCaution: ssmCaution,
            actualTargetPasses: actualTargetPasses,
            thermallyFlooredMaxLoops: thermallyFlooredMaxLoops)
        return BASSSMNeuromodulationSuggestion(
            suggestedTargetPasses: passes,
            actualTargetPasses: actualTargetPasses,
            deltaPasses: passes - actualTargetPasses,
            suggestedOrganPowerBudget: budgetName(budget),
            hostHintBudget: budgetName(hint),
            suggestedBackendByFamily: suggestedBackendByFamily(budget: budget),
            actualAttentionBackend: actualAttentionBackend(
                thermalLevel: thermalLevel, npuAvailable: npuAvailable))
    }
}

extension BASMambaSSMTurnObservation {

    /// Immutable copy with the (observation-only) neuromodulation suggestion attached — the input
    /// observation is never mutated. Used at the single flag-gated emission site in `runTurn`.
    func attaching(
        neuromodulationSuggestion: BASSSMNeuromodulationSuggestion?
    ) -> BASMambaSSMTurnObservation {
        BASMambaSSMTurnObservation(
            sessionID: sessionID,
            turnID: turnID,
            affectCount: affectCount,
            historyCount: historyCount,
            candidateCount: candidateCount,
            ssmCaution: ssmCaution,
            finalMagnitude: finalMagnitude,
            gpuShadowMAE: gpuShadowMAE,
            ssmStateOut: ssmStateOut,
            neuromodulationSuggestion: neuromodulationSuggestion)
    }
}
