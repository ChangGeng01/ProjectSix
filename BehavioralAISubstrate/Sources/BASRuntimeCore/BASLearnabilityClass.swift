// SPDX-License-Identifier: Apache-2.0
// M515-M516 (chapter 一百三十) — Learnability typed boundary per
// user 8-point audit Point 7 (chapter 一百三十 Appendix P.4).
//
// ## Why this exists
//
// The substrate's vision tends toward "everything eventually gets
// smart" — but doctrine requires that some surfaces stay
// machine-mechanical-stable. Without typed-pinning the boundary,
// future contributors might attempt to learn / tune / drift any
// schema, including ones that are doctrine-load-bearing (L14 hard
// rules, token authority, commit ledger, permission boundary,
// host-authorization law).
//
// Three categories per audit Point 7:
//
//   A. 强可学习 (.strongLearnable)
//      Suitable for modeling, distillation, continuous improvement.
//      L6 临场眼 / L7 镜刃层 / L9 梦环层 / L12 柔手层 (partial).
//
//   B. 半可学习 (.semiLearnable)
//      Rules + learning hybrid.
//      L8 retrieval ordering / L10 tribunal ordering + remorse
//      prediction / L11 risk gate calibration / L13 candidate
//      refinement.
//
//   C. 尽量不可学习 / 仅离线更新 (.nonLearnable)
//      Must remain mechanically stable.
//      L14 玄戒层 / delete+freeze+rollback protocol / token+commit
//      protocol / core permission boundary / host authorization
//      law.
//
// "不是所有地方都该智能化。有些地方必须机械、笨、硬。"
//
// ## Doctrine pins
//
// - **BR-013 typed pin** (new red line, chapter 一百三十):
//   non-learnable domains MUST NOT route through learnable
//   training pipelines. Lint test enforces.
// - **Anti-drift**: every governance entry annotated with a
//   class; lint test catches schemas added without annotation.
// - **Stable kebab-case raw values**: cross-module string
//   consumers grep on raw value.
//
// ## DAG discipline
//
// Imports `Foundation` only. Pure value type at `BASRuntimeCore`
// (the leaf module). Other layers downstream consume this.

import Foundation

// MARK: - BASLearnabilityClass

/// 3-tier learnability classification per Appendix P.4 doctrine.
/// Each governance registry entry is annotated with one of these
/// values; runtime code consults it before routing through
/// learning pipelines.
public enum BASLearnabilityClass:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// 强可学习 — suitable for modeling, distillation, continuous
    /// learning loops. Examples: L6 anomaly detection / L7 mirror
    /// blade reasoning / L9 candidate generation / L12 surface
    /// rendering (partial).
    case strongLearnable = "strong-learnable"
    /// 半可学习 — rules + learning hybrid. Examples: L8 retrieval
    /// ordering / L10 tribunal ordering + remorse prediction /
    /// L11 risk-gate calibration / L13 candidate refinement.
    case semiLearnable = "semi-learnable"
    /// 不可学习 / 仅离线更新 — must remain mechanically stable.
    /// Examples: L14 sovereign verdict + warrant + commit token /
    /// audit ledger / delete-freeze-rollback protocol / core
    /// permission boundary / host authorization law.
    case nonLearnable = "non-learnable"

    /// Doctrine reference per audit Point 7 + chapter 一百三十
    /// Appendix P.4.
    public var whitePaperRef: String {
        switch self {
        case .strongLearnable:
            return "Audit Point 7 (chapter 一百三十 P.4) — modeling/distillation"
        case .semiLearnable:
            return "Audit Point 7 (chapter 一百三十 P.4) — rules+learning hybrid"
        case .nonLearnable:
            return "Audit Point 7 (chapter 一百三十 P.4) — mechanically stable, doctrine-load-bearing"
        }
    }

    /// Stable typed reason code prefix that appears in audit
    /// signalRefs when learnability becomes a routing decision
    /// (e.g. "learnability:non-learnable" indicates a schema that
    /// MUST NOT route through training pipelines this turn).
    public var auditCodePrefix: String {
        "learnability:\(rawValue)"
    }

    /// Brief policy description suitable for governance
    /// documentation.
    public var policyDescription: String {
        switch self {
        case .strongLearnable:
            return "Routes through training pipelines; supports continuous improvement."
        case .semiLearnable:
            return "Routes through training pipelines for calibration only; core rules remain hard-coded."
        case .nonLearnable:
            return "BLOCKED from training pipelines. Updates only via doctrine-versioned offline review."
        }
    }
}
