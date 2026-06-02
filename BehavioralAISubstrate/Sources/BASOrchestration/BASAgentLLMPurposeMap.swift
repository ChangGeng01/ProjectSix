// ch1046 / v1.0 §7 (单脑多席) — bridge the existing 9 席 (agent roles) to the LLM-call contract.
//
// ## Honest scope (what is and is NOT new)
//
// The 9 named 席 ALREADY EXIST as first-class roles on the agent fabric: `BASAgentRole`
// (Sources/BASMemory/BASAgentFabricEnums.swift) enumerates scout / memory / planner / critic /
// hostAlignment / risk / surface / sovereignSentinel / evolutionShadow + 7 watchers + 4
// sovereign seals = 20 named roles, with personas (`BASAgentPersonaRoleTemplates`), proposals
// (`BASAgentProposal`), a merge engine and the single-commit gate (单提交口). None of that is
// rebuilt here.
//
// What was MISSING is the connection between a 席 and the v1.0 LLM-call keystone
// (`BASLLMInvocationContract` / `BASContractEnforcingOrganAdapter`, ADR-028): nothing declared
// WHICH kind of LLM "squeeze" each 席 performs, and a `BASProcessTrace` could not record WHICH 席
// made a call. This file is that bridge — the canonical 席 → `BASLLMCallPurpose` map plus a
// convenience that builds a 席-attributed contract-enforcing adapter.
//
// Opt-in / byte-equal-off (ADR-014): nothing routes through this map unless a host calls it; a 席
// whose calls are not wrapped is unchanged.
//
// ## The map (grounded in the purpose enum's own L-layer tie-points)
//
//   scout             → .decompose  (L7 structure extraction — breaks the problem down)
//   planner           → .plan       (L9 candidate frontier)
//   critic            → .critique   (reverse-side correctness review)
//   risk              → .risk       (L11 risk feature extraction)
//   surface           → .render     (L12 surface generation)
//   evolutionShadow   → .distill    (L13 distillation-trajectory extraction)
//   sovereignSentinel → .verify     (sovereign-safety validation pass)
//   hostAlignment     → .verify     (host-constitution-fit validation — the SAME purpose as the
//                                    sentinel, distinguished by SCOPE, recorded via agentRef)
//   memory            → nil         (retrieval/consolidation 席 — served deterministically; it does
//                                    NOT 压榨 the model generatively, so it has no LLM purpose)
//   watchers (7) / seals (3) / compareModerator → nil  (observe / gate / moderate — not generative
//                                    LLM call sites)

import BASMemory
import BASOrgan

/// Canonical bridge from a 席 (`BASAgentRole`) to the LLM-call contract layer. Pure / stateless.
public enum BASAgentLLMPurposeMap {

    /// The default LLM-call purpose a 席 uses when it invokes the model under contract. Returns nil
    /// for governor / retrieval 席 (memory, the watchers, the seals, the moderator): they observe,
    /// gate, or serve memory deterministically — there is no generative call to contract. The switch
    /// is exhaustive over all 20 `BASAgentRole` cases (the compiler enforces totality).
    public static func defaultPurpose(for role: BASAgentRole) -> BASLLMCallPurpose? {
        switch role {
        // Generative 席 (8) — each squeezes the model for its L-layer structural asset.
        case .scout:             return .decompose
        case .planner:           return .plan
        case .critic:            return .critique
        case .risk:              return .risk
        case .surface:           return .render
        case .evolutionShadow:   return .distill
        case .sovereignSentinel: return .verify
        case .hostAlignment:     return .verify

        // Retrieval 席 — memory is served deterministically, not generated.
        case .memory:            return nil

        // Watcher 席 (7) — observe streams for anomalies; they do not call the model generatively.
        case .anomalyWatcher, .gaslightWatcher, .memoryPollutionWatcher, .hostDriftWatcher,
             .toolInjectionWatcher, .axisDeviationWatcher, .sanctumLeakWatcher:
            return nil

        // Sovereign seals / moderator (4) — gate or moderate commits; not generative call sites.
        case .actionPermit, .deleteRollbackSeal, .memorySeal, .compareModerator:
            return nil
        }
    }

    /// True iff this 席 is a generative LLM call site (i.e. it has a default purpose).
    public static func isGenerative(_ role: BASAgentRole) -> Bool {
        defaultPurpose(for: role) != nil
    }

    /// Builds a contract-enforcing organ adapter scoped to a 席: every LLM call it makes carries the
    /// 席's purpose-contract, is gated fail-closed (禁止随便问模型 — the model is NOT called on a
    /// contract violation), and emits a `BASProcessTrace` stamped with `agentRef = role.rawValue`
    /// (so the trace records WHICH 席 made the call). Returns nil for a non-generative 席 — the caller
    /// then uses `inner` unwrapped (no contract path, byte-equal-off).
    ///
    /// Per-席 policy (`forbiddenContext` / `verifierRef` / `sovereignConstraints` / `sovereignCheck`)
    /// is supplied by the host; binding a 席's real calls to this adapter is the host's deliberate
    /// install step (ADR-028 honest layer-2), not a silent default.
    public static func enforcingAdapter(
        for role: BASAgentRole,
        inner: any BASOrganAdapter,
        forbiddenContext: [String] = [],
        verifierRef: String? = nil,
        sovereignConstraints: [String] = [],
        sovereignCheck: (@Sendable (BASLLMInvocationContract, BASOrganRequest) -> String?)? = nil,
        traceSink: (@Sendable (BASProcessTrace) -> Void)? = nil
    ) -> BASContractEnforcingOrganAdapter? {
        guard let purpose = defaultPurpose(for: role) else { return nil }
        return BASContractEnforcingOrganAdapter(
            inner: inner,
            purpose: purpose,
            agentRef: role.rawValue,
            forbiddenContext: forbiddenContext,
            verifierRef: verifierRef,
            sovereignConstraints: sovereignConstraints,
            sovereignCheck: sovereignCheck,
            traceSink: traceSink)
    }
}
