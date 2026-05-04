// SPDX-License-Identifier: Apache-2.0
// M513-M514 (chapter 一百三十) — Counter-Host Check primitive
// per user 8-point audit Point 8 (chapter 一百三十 Appendix P.3).
//
// ## Why this exists
//
// The L5 (host constitution) + L8 (hippocampal memory) + L13
// (evolution furnace) combination is doctrinally powerful but
// also dangerous: it can form a "host self-confirmation loop":
//
//   1. System sees a tendency in host history (L8 memory)
//   2. Writes a host candidate (L13 update ticket)
//   3. The candidate begins lightly influencing interpretation +
//      suggestions (L5 host constitution)
//   4. Host behaves more like that tendency because system treats
//      them that way
//   5. System observes "yes, the host really IS this way" and
//      reinforces the candidate
//
// This converts "辅助理解" (assist understanding) into "塑造人格"
// (shape personality) over time. The system becomes "会温柔塑造
// 宿主" (gently shapes host) rather than "守主权" (guards
// sovereignty).
//
// Counter-Host Check is the doctrine-level defense:
//
//   Each long-term host candidate, before promotion, MUST be
//   asked: is this a real stable pattern, or a system-induced
//   drift?
//
// If `.systemInducedDrift`, the candidate cannot promote without
// explicit sovereign override (L14 warrant).
//
// ## Doctrine pins
//
// - 不变量 #3 加固 — "私有经验不进权重" + "不通过宿主自证循环
//   塑造宿主"
// - L13 promotion gate consumes the outcome (M514 L13 wire)
// - Single commit mouth preserved — Counter-Host Check is hint;
//   actual gating still routes through L11 permit + L14 warrant
// - Schema-only ship + production-wire pattern per chapter 一百
//   十八 doctrine
//
// ## DAG discipline
//
// Imports `Foundation` + `BASRuntimeCore` only. Pure value type.

import Foundation
import BASRuntimeCore

// MARK: - BASCounterHostCheckOutcome

/// 4 outcome cases for Counter-Host Check per Appendix P.3 doctrine.
/// Stable kebab-case raw values for cross-module audit-walker grep.
public enum BASCounterHostCheckOutcome:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// 真稳定模式 — host pattern existed before system observation
    /// AND would persist if the candidate were not introduced.
    /// Promotion path open (subject to L11/L14 normal flow).
    case genuineHostPattern = "genuine-host-pattern"
    /// 系统引导自证 — host behavior shifted noticeably AFTER system
    /// began surfacing the candidate; substantive evidence the
    /// candidate is shaping (not reflecting) the host. Promotion
    /// blocked unless L14 sovereign override.
    case systemInducedDrift = "system-induced-drift"
    /// 证据不足判断 — neither pattern stability nor system-induction
    /// can be confirmed (e.g. cooling period not yet elapsed).
    /// Treated as defer (not block, not approve).
    case insufficientEvidence = "insufficient-evidence"
    /// 非宿主候选 — candidate doesn't claim to update host
    /// constitution (e.g. tool-call candidate, memory candidate).
    /// Counter-Host Check elides; outcome is sentinel.
    case notApplicable = "not-applicable"
}

// MARK: - BASCounterHostCheck

/// Per-candidate counter-host-check readout. Producers (L13
/// `BASUpdateTicketLifecycleCoordinator`) call
/// `BASCounterHostCheckProtocol.derive(...)` per long-term host
/// candidate before promotion; the outcome routes the candidate
/// through L11/L14 normal flow OR forces sovereign override.
///
/// Doctrine invariant per Appendix P.3:
///
///   - When `outcome == .systemInducedDrift`, L13 promotion gate
///     MUST block promotion unless an L14 sovereign warrant
///     explicitly overrides.
public struct BASCounterHostCheck:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier (e.g. `"counter-host-check:<candidateID>"`).
    public var checkID: String
    /// Stable ref to the L13 candidate being checked.
    public var candidateRef: String
    /// Stable ref to the host baseline snapshot used as
    /// counterfactual reference (e.g.
    /// `"host-baseline:<hostVersionID>"`). Empty when no baseline
    /// is available (typically in `.notApplicable` or
    /// `.insufficientEvidence` outcomes).
    public var hostBaselineRef: String
    /// Observed delta in host behavior since the candidate began
    /// influencing surfaces. Domain: `[0, 1]` clamped — 0 = no
    /// observable shift; 1 = maximum observable shift. Higher =
    /// more likely system-induced.
    public var observedDelta: Double
    /// Estimated probability the observed delta is system-induced
    /// (rather than genuine pattern). Domain: `[0, 1]` clamped.
    /// Above `systemInducedRiskThreshold` (0.6) the outcome
    /// resolves to `.systemInducedDrift`.
    public var inducedRiskScore: Double
    /// Outcome enum.
    public var outcome: BASCounterHostCheckOutcome
    /// Stable typed reason codes describing the check inputs and
    /// decision. Trimmed, empties filtered.
    public var reasonCodes: [String]

    public init(
        schemaVersion: String =
            BASCounterHostCheck.currentSchemaVersion,
        checkID: String,
        candidateRef: String,
        hostBaselineRef: String,
        observedDelta: Double,
        inducedRiskScore: Double,
        outcome: BASCounterHostCheckOutcome,
        reasonCodes: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.checkID = checkID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.candidateRef = candidateRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.hostBaselineRef = hostBaselineRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.observedDelta = min(1, max(0, observedDelta))
        self.inducedRiskScore = min(1, max(0, inducedRiskScore))
        self.outcome = outcome
        self.reasonCodes = reasonCodes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Doctrine invariant per Appendix P.3: when outcome is
    /// `.systemInducedDrift`, promotion gate must block.
    public var requiresSovereignOverride: Bool {
        outcome == .systemInducedDrift
    }
}

// MARK: - BASCounterHostCheckProtocol

/// Pure-function helper for deriving a `BASCounterHostCheck` from
/// per-candidate state. Producers feed in already-computed
/// (observedDelta, inducedRiskScore) signals and the helper
/// resolves the outcome via threshold mapping.
///
/// Mapping doctrine (per Appendix P.3):
///
///   - `inducedRiskScore >= systemInducedRiskThreshold` (0.6) →
///     `.systemInducedDrift`
///   - `observedDelta < genuinePatternDeltaCeiling` (0.2) +
///     non-empty hostBaselineRef → `.genuineHostPattern`
///   - empty hostBaselineRef OR (observedDelta in middle band) →
///     `.insufficientEvidence`
///   - applicabilityFlag == false → `.notApplicable`
///     (caller-decided: when candidate doesn't update host
///     constitution)
public enum BASCounterHostCheckProtocol {

    /// Threshold above which the outcome resolves to
    /// `.systemInducedDrift`. Tuned conservatively — promotion
    /// blocking is high-cost, so the threshold favors letting
    /// genuine patterns through over forcing sovereign-override
    /// pressure. Anti-magic-number: named static.
    public static let systemInducedRiskThreshold: Double = 0.6

    /// Threshold below which observedDelta indicates a genuine
    /// (pre-existing) host pattern. Anti-magic-number: named
    /// static.
    public static let genuinePatternDeltaCeiling: Double = 0.2

    /// Pure-function derive helper.
    public static func derive(
        candidateRef: String,
        hostBaselineRef: String,
        observedDelta: Double,
        inducedRiskScore: Double,
        appliesToHostConstitution: Bool,
        turnID: String
    ) -> BASCounterHostCheck {
        let outcome = resolveOutcome(
            hostBaselineRef: hostBaselineRef,
            observedDelta: observedDelta,
            inducedRiskScore: inducedRiskScore,
            appliesToHostConstitution:
                appliesToHostConstitution)
        let codes = reasonCodes(
            outcome: outcome,
            inducedRiskScore: inducedRiskScore,
            observedDelta: observedDelta)
        return BASCounterHostCheck(
            checkID: "counter-host-check:\(turnID):\(candidateRef)",
            candidateRef: candidateRef,
            hostBaselineRef: hostBaselineRef,
            observedDelta: observedDelta,
            inducedRiskScore: inducedRiskScore,
            outcome: outcome,
            reasonCodes: codes)
    }

    private static func resolveOutcome(
        hostBaselineRef: String,
        observedDelta: Double,
        inducedRiskScore: Double,
        appliesToHostConstitution: Bool
    ) -> BASCounterHostCheckOutcome {
        guard appliesToHostConstitution else {
            return .notApplicable
        }
        let normalizedRisk = min(1, max(0, inducedRiskScore))
        let normalizedDelta = min(1, max(0, observedDelta))
        if normalizedRisk >= systemInducedRiskThreshold {
            return .systemInducedDrift
        }
        let hasBaseline = !hostBaselineRef.trimmingCharacters(
            in: .whitespacesAndNewlines).isEmpty
        guard hasBaseline else {
            return .insufficientEvidence
        }
        if normalizedDelta < genuinePatternDeltaCeiling {
            return .genuineHostPattern
        }
        return .insufficientEvidence
    }

    private static func reasonCodes(
        outcome: BASCounterHostCheckOutcome,
        inducedRiskScore: Double,
        observedDelta: Double
    ) -> [String] {
        var codes: [String] = []
        codes.append("counter-host:outcome:\(outcome.rawValue)")
        let formattedRisk = String(
            format: "%.3f", min(1, max(0, inducedRiskScore)))
        let formattedDelta = String(
            format: "%.3f", min(1, max(0, observedDelta)))
        codes.append("counter-host:risk:\(formattedRisk)")
        codes.append("counter-host:delta:\(formattedDelta)")
        if outcome == .systemInducedDrift {
            codes.append(
                "counter-host:requires-sovereign-override")
        }
        return codes
    }
}
