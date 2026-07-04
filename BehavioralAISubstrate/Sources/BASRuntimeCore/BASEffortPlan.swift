// ch1045 / v1.0 Phase-0 — BASEffortPlan: the squeeze-intensity controller (outline §8.1).
//
// Effort is the 压榨强度 dial. The user REQUESTS a level; L1 (lease/budget, thermal, energy) may
// DOWNGRADE it to the level that actually takes effect, recording WHY. The applied level expands
// deterministically into a budget — candidate count, agent count, memory depth, critic strength,
// risk-calibration detail, output detail, tool-verification strength — which the layers read to
// size their work. This is additive: the older 3-level `EffortPreference` (BASAgentRouter) stays;
// a host maps it to a `BASEffortLevel` if/when it adopts this richer model. The LLM invocation
// contract's `effortPlanRef` (ADR-028) points at a plan like this.

import Foundation

/// The requested/applied effort levels (outline §8.1). `auto` = "let the system choose"; it is a
/// REQUEST value — the applied level should resolve to a concrete tier (its budget defaults to the
/// balanced budget if left as auto).
public enum BASEffortLevel: String, Sendable, Equatable, Codable, CaseIterable, Hashable {
    case fast
    case balanced
    case deep
    case max
    case guarded
    case auto
}

/// The squeeze-intensity budget an applied effort level expands to. All counts are non-negative;
/// the 0…3 "strength" knobs are ordinal dials the layers interpret.
public struct BASEffortBudget: Sendable, Equatable, Codable {
    public let candidateCount: Int           // L9 候选数量
    public let agentCount: Int               // 并发 agent 数量
    public let memoryDepth: Int              // L8 记忆深度
    public let criticStrength: Int           // 反方强度 (0…3)
    public let riskCalibration: Int          // 风险校准细度 (0…3)
    public let outputDetail: Int             // 输出详细度 (0…3)
    public let toolVerificationStrength: Int // 工具验证强度 (0…3)

    /// P3 契合 (SYSTEM_EFFICIENCY_CAMPAIGN) — the decode-token budget derived from `outputDetail`:
    /// the biomimetic "adaptive think-budget" made concrete. A `.fast`-tier turn answers in a short
    /// breath (64 tok); only the deep tiers earn the full preset budget. Consumers `min()` this with
    /// their own caps; a nil-consumer keeps the historical preset budget (ADR-014).
    /// Mapping: outputDetail 0→64 · 1→160 · 2→384 · 3→1024.
    public var maxDecodeTokens: Int { [64, 160, 384, 1024][max(0, min(3, outputDetail))] }

    public init(
        candidateCount: Int, agentCount: Int, memoryDepth: Int,
        criticStrength: Int, riskCalibration: Int, outputDetail: Int,
        toolVerificationStrength: Int
    ) {
        self.candidateCount = max(0, candidateCount)
        self.agentCount = max(0, agentCount)
        self.memoryDepth = max(0, memoryDepth)
        self.criticStrength = max(0, min(3, criticStrength))
        self.riskCalibration = max(0, min(3, riskCalibration))
        self.outputDetail = max(0, min(3, outputDetail))
        self.toolVerificationStrength = max(0, min(3, toolVerificationStrength))
    }

    /// Deterministic level → budget mapping (single source of truth). Intensity rises
    /// fast < balanced < deep < max; `guarded` keeps a modest breadth but MAXES the safety dials
    /// (critic + risk-calibration + tool-verification); `auto` falls back to the balanced budget.
    public static func forLevel(_ level: BASEffortLevel) -> BASEffortBudget {
        switch level {
        case .fast:
            return BASEffortBudget(candidateCount: 1, agentCount: 1, memoryDepth: 1,
                criticStrength: 0, riskCalibration: 1, outputDetail: 1, toolVerificationStrength: 0)
        case .balanced, .auto:
            return BASEffortBudget(candidateCount: 2, agentCount: 2, memoryDepth: 3,
                criticStrength: 1, riskCalibration: 1, outputDetail: 2, toolVerificationStrength: 1)
        case .deep:
            return BASEffortBudget(candidateCount: 4, agentCount: 4, memoryDepth: 6,
                criticStrength: 2, riskCalibration: 2, outputDetail: 3, toolVerificationStrength: 2)
        case .max:
            return BASEffortBudget(candidateCount: 6, agentCount: 6, memoryDepth: 10,
                criticStrength: 3, riskCalibration: 3, outputDetail: 3, toolVerificationStrength: 3)
        case .guarded:
            return BASEffortBudget(candidateCount: 2, agentCount: 3, memoryDepth: 3,
                criticStrength: 3, riskCalibration: 3, outputDetail: 2, toolVerificationStrength: 3)
        }
    }
}

public struct BASEffortPlan: Sendable, Equatable, Codable {
    /// What the caller asked for.
    public let requested: BASEffortLevel
    /// What actually takes effect after L1 budget/thermal/energy arbitration.
    public let applied: BASEffortLevel
    /// Non-nil only when `applied != requested` — the reason for the downgrade/override (e.g.
    /// "thermal=serious", "budget_exhausted", "guarded_floor"). 诚实: a downgrade is always logged.
    public let overrideReason: String?

    public init(requested: BASEffortLevel, applied: BASEffortLevel, overrideReason: String?) {
        self.requested = requested
        self.applied = applied
        self.overrideReason = overrideReason
    }

    /// The squeeze budget derived from the APPLIED level (not the requested one).
    public var budget: BASEffortBudget { BASEffortBudget.forLevel(applied) }

    /// True when the applied level differs from the requested one.
    public var wasOverridden: Bool { applied != requested }

    /// Requested level granted as-is (no override).
    public static func granted(_ level: BASEffortLevel) -> BASEffortPlan {
        BASEffortPlan(requested: level, applied: level, overrideReason: nil)
    }

    /// A downgrade by L1: applied is what took effect, with a mandatory reason.
    public static func downgraded(
        requested: BASEffortLevel, to applied: BASEffortLevel, reason: String
    ) -> BASEffortPlan {
        BASEffortPlan(requested: requested, applied: applied, overrideReason: reason)
    }
}
