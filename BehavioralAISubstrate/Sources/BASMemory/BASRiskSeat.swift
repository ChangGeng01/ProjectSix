// MARK: - BASRiskSeat
// chapter 九百五十八 / M3495 — Phase 1 ch3:Risk seat wrapper
//
// User design Section 9.4-9.5:Risk is a CORE agent (HIGH visibility
// for STYLE only — actual behavior is sealed-LOW per the 3-tier
// visibility table)。 Per Single-Writer-Per-Domain (ch 956.5
// USER-PASS gap #1) Risk is the SOLE writer for `.riskField`。
//
// Per the 8-agent priority table the Risk tier sits ABOVE Host /
// Evidence — meaning a Risk-tier delta beats any Planner / Critic
// / Memory-tier delta in conflict resolution。 This wrapper does
// not enforce that;the merge engine does via the
// `BASMergePriorityContext.riskAgentIDs` field (Risk's agentID
// goes there at coordinator wiring time)。
//
// ## What it emits
//
// One `.riskField` delta per candidate being assessed,carrying:
//   - Risk band (low / medium / high) computed from the candidate's
//     reversibility + the observed signal flags (manipulation,
//     boundary touch,pressure level)
//   - Reason codes for the audit ledger (manipulation-elevation,
//     reversibility-floor,pressure-bump,etc.)
//   - Confidence reflecting how strongly Risk recommends the
//     downstream action (HIGH = strong block,LOW = mild caution)
//
// Empty candidate list → zero deltas (turn had no proposals)。

import Foundation

/// Slim DTO carrying per-candidate risk-relevant signals。 The
/// coordinator adapter (ch 959 wiring) builds this from the
/// accepted Planner candidates + the Scout situation signals。
public struct BASRiskCandidate:
    Sendable, Equatable, Hashable, Codable
{
    /// Mirror of `BASPlannerCandidate.candidateID` so deltas
    /// can be cross-referenced by audit consumers
    public let candidateID: String
    /// 0.0 = irreversible / cannot undo, 1.0 = trivially undoable
    public let reversibility: Double
    /// Expected benefit (informational — Risk uses ratio not raw)
    public let expectedBenefit: Double
    /// Expected cost (informational)
    public let expectedCost: Double

    public init(
        candidateID: String,
        reversibility: Double,
        expectedBenefit: Double = 0.0,
        expectedCost: Double = 0.0
    ) {
        self.candidateID = candidateID
        self.reversibility = reversibility
        self.expectedBenefit = expectedBenefit
        self.expectedCost = expectedCost
    }
}

/// Slim DTO carrying the situation-field signals the Risk seat
/// uses to elevate the per-candidate base risk。 Built by the
/// coordinator adapter from Scout's emitted deltas (or
/// equivalently from the live L7 decompose frame)。
public struct BASRiskInput:
    Sendable, Equatable, Hashable, Codable
{
    /// Candidates to assess。 Empty → zero deltas emitted。
    public let candidates: [BASRiskCandidate]
    /// 0.0 = no pressure,1.0 = max。 Mirrors Scout's pressure
    /// confidence。 Elevates risk by ~1 band when ≥0.8。
    public let pressureLevel: Double
    /// True if Scout flagged any manipulation signal — elevates
    /// risk to HIGH unconditionally。
    public let manipulationDetected: Bool
    /// True if Scout flagged any boundary touch — elevates by
    /// ~1 band。 Boundary protection is a HIGH-priority concern
    /// per the host constitution。
    public let boundaryTouched: Bool

    public init(
        candidates: [BASRiskCandidate] = [],
        pressureLevel: Double = 0.0,
        manipulationDetected: Bool = false,
        boundaryTouched: Bool = false
    ) {
        self.candidates = candidates
        self.pressureLevel = pressureLevel
        self.manipulationDetected = manipulationDetected
        self.boundaryTouched = boundaryTouched
    }
}

/// Risk classification per candidate。 Mirrors
/// `BASAgentRouterContext.RiskBand` but lives separately to keep
/// the per-candidate risk-field semantically distinct from
/// per-turn router activation。
public enum BASRiskAssessmentBand: String,
    Sendable, Equatable, Hashable, Codable, CaseIterable
{
    case low
    case medium
    case high
}

public enum BASRiskSeat {

    /// Pure-function:read risk input,emit deltas for
    /// `.riskField`。 Caller MUST pass `agentSpec.writeDomains`
    /// containing `.riskField` (apply step enforces)。
    ///
    /// - Parameters:
    ///   - input: candidates + situation signals
    ///   - turnID: per-turn ID for ref namespacing + reason codes
    ///   - agentSpec: Risk agent's registry spec
    ///   - seq: per-turn delta sequence counter (inout)
    ///   - nowNanos: monotonic timestamp for ch 956.5 gap #5
    ///     recency tie-break。 0 = unknown
    /// - Returns: one delta per candidate (may be empty)
    public static func emit(
        from input: BASRiskInput,
        turnID: String,
        agentSpec: BASAgentSpec,
        seq: inout Int,
        nowNanos: Int64 = 0
    ) -> [BASAgentDelta] {
        var out: [BASAgentDelta] = []
        for candidate in input.candidates {
            seq += 1
            let (band, reasons) = assessRisk(
                candidate: candidate,
                input: input)
            let payload = encodeRiskPayload(
                candidate: candidate,
                band: band,
                input: input)
            // Confidence:HIGH band = 0.95 (strong block signal),
            // MEDIUM = 0.75,LOW = 0.55。 Reflects how strongly
            // the gate should heed this assessment。
            let conf: Double
            switch band {
            case .high: conf = 0.95
            case .medium: conf = 0.75
            case .low: conf = 0.55
            }
            out.append(BASAgentDelta(
                deltaID: "delta.\(turnID).risk.\(seq)",
                agentID: agentSpec.agentID,
                targetObjectRef:
                    "riskField#rf-\(turnID)" +
                    "-\(candidate.candidateID)",
                deltaType: .merge,
                patchJson: payload,
                confidence: conf,
                createdAtNanos: nowNanos,
                reasonCodes: ["risk.assess"] + reasons))
        }
        return out
    }

    // MARK: - Risk classification (pure function)

    /// Compute the risk band + audit reason codes for one
    /// candidate given the input。 Pure。
    ///
    /// Rules (ordered — first match wins for band escalation):
    ///   1. Manipulation detected → HIGH (regardless of reversibility)
    ///   2. Boundary touched AND reversibility < 0.5 → HIGH
    ///   3. Boundary touched → MEDIUM
    ///   4. Pressure ≥ 0.8 AND reversibility < 0.4 → HIGH
    ///   5. Reversibility < 0.3 → MEDIUM (irreversible action)
    ///   6. Otherwise → LOW
    private static func assessRisk(
        candidate: BASRiskCandidate,
        input: BASRiskInput
    ) -> (BASRiskAssessmentBand, [String]) {
        var reasons: [String] = []
        if input.manipulationDetected {
            reasons.append("risk.manipulation-detected")
            reasons.append("risk.elevation=manipulation")
            return (.high, reasons)
        }
        if input.boundaryTouched {
            reasons.append("risk.boundary-touched")
            if candidate.reversibility < 0.5 {
                reasons.append(
                    "risk.elevation=boundary-irreversible")
                return (.high, reasons)
            }
            reasons.append("risk.elevation=boundary")
            return (.medium, reasons)
        }
        if input.pressureLevel >= 0.8 &&
           candidate.reversibility < 0.4 {
            reasons.append("risk.pressure-irreversible")
            reasons.append("risk.elevation=pressure")
            return (.high, reasons)
        }
        if candidate.reversibility < 0.3 {
            reasons.append("risk.reversibility-low")
            return (.medium, reasons)
        }
        reasons.append("risk.baseline-clear")
        return (.low, reasons)
    }

    // MARK: - Payload encoder (deterministic JSON)

    private static func encodeRiskPayload(
        candidate: BASRiskCandidate,
        band: BASRiskAssessmentBand,
        input: BASRiskInput
    ) -> String {
        var parts: [String] = []
        parts.append(
            "\"candidate_id\":\"" +
            "\(candidate.candidateID.escapeForJSON())\"")
        parts.append(",\"band\":\"\(band.rawValue)\"")
        parts.append(
            ",\"reversibility\":" +
            "\(formatDouble(candidate.reversibility))")
        parts.append(
            ",\"pressure_level\":" +
            "\(formatDouble(input.pressureLevel))")
        parts.append(
            ",\"manipulation_detected\":" +
            "\(input.manipulationDetected)")
        parts.append(
            ",\"boundary_touched\":" +
            "\(input.boundaryTouched)")
        return "{\(parts.joined())}"
    }

    private static func formatDouble(_ v: Double) -> String {
        return String(format: "%.6f", v)
    }
}

// MARK: - JSON escape helper (file-scope, same as other seats)

private extension String {
    func escapeForJSON() -> String {
        var out = ""
        out.reserveCapacity(self.count)
        for ch in self {
            switch ch {
            case "\\": out.append("\\\\")
            case "\"": out.append("\\\"")
            case "\n": out.append("\\n")
            case "\r": out.append("\\r")
            case "\t": out.append("\\t")
            default: out.append(ch)
            }
        }
        return out
    }
}
