// MARK: - BASSurfaceSeat
// chapter 九百五十八 / M3495 — Phase 1 ch3:Surface seat wrapper
//
// User design Section 9.6:Surface is a CORE agent (HIGH visibility,
// user-customizable per the 3-tier table — tone / warmth / structure
// can be tuned)。 Per Single-Writer-Per-Domain Surface is the SOLE
// writer for `.renderFrame`。
//
// Section 9.6 enumerates 8 surface modes:
//   .answer       — direct answer (default low-risk)
//   .compare      — show 2-3 alternatives side-by-side
//   .delay        — defer with explicit explanation
//   .draftOnly    — produce draft,don't auto-send
//   .localOnly    — keep response local,don't sync
//   .block        — refuse with explanation (high risk / sovereign veto)
//   .replace      — replace user-supplied content
//   .silentStub   — minimal placeholder,no commit
//
// Selection logic:
//   1. Sovereign veto pending → .block
//   2. ActionPermit not granted → .block
//   3. Risk band HIGH → .block (or .delay if reversibility OK)
//   4. Risk band MEDIUM AND irreversible action → .delay
//   5. User explicitly requested compare → .compare
//   6. Has accepted candidate → .answer
//   7. No accepted candidate → .silentStub
//
// All combinations produce exactly ONE delta — surface mode is
// a singleton per turn (per Single-Writer doctrine)。

import Foundation

/// 8 surface modes per Agent Fabric design Section 9.6。 Wire
/// format stable from ch 958 onward — adding modes is OK (Codable
/// rawValue),removing requires arc-level discussion。
public enum BASSurfaceSeatMode: String,
    Sendable, Equatable, Hashable, Codable, CaseIterable
{
    case answer
    case compare
    case delay
    case draftOnly
    case localOnly
    case block
    case replace
    case silentStub
}

/// Slim DTO carrying all inputs the Surface seat needs to pick
/// a mode。 Coordinator adapter (ch 959 wiring) constructs this
/// from the merged choice + risk gate + sovereign sentinel +
/// user request。
public struct BASSurfaceInput:
    Sendable, Equatable, Hashable, Codable
{
    /// ID of the candidate that won adjudication (nil = no
    /// accepted candidate → silent stub)
    public let acceptedCandidateID: String?
    /// True when L11 risk gate granted action permit
    public let actionPermitGranted: Bool
    /// Mirror of Risk seat's per-turn assessment for the
    /// accepted candidate (or .low when no candidate)
    public let riskBand: BASRiskAssessmentBand
    /// Reversibility of the accepted candidate (0.0-1.0)。 Used
    /// to decide block vs delay at MEDIUM risk
    public let reversibility: Double
    /// True when L14 sovereign sentinel flagged a veto
    public let sovereignVetoed: Bool
    /// True when user explicitly requested compare-mode UI
    public let userRequestsCompare: Bool

    public init(
        acceptedCandidateID: String? = nil,
        actionPermitGranted: Bool = true,
        riskBand: BASRiskAssessmentBand = .low,
        reversibility: Double = 1.0,
        sovereignVetoed: Bool = false,
        userRequestsCompare: Bool = false
    ) {
        self.acceptedCandidateID = acceptedCandidateID
        self.actionPermitGranted = actionPermitGranted
        self.riskBand = riskBand
        self.reversibility = reversibility
        self.sovereignVetoed = sovereignVetoed
        self.userRequestsCompare = userRequestsCompare
    }
}

public enum BASSurfaceSeat {

    /// Pure-function:read surface input,emit ONE delta for
    /// `.renderFrame`。 Always emits exactly one delta (the
    /// `.silentStub` mode handles "nothing to surface")。 Caller
    /// MUST pass `agentSpec.writeDomains` containing `.renderFrame`。
    ///
    /// - Parameters:
    ///   - input: merged choice + risk gate + sovereign + user
    ///   - turnID: per-turn ID for ref namespacing + reason codes
    ///   - agentSpec: Surface agent's registry spec
    ///   - seq: per-turn delta sequence counter (inout)
    ///   - nowNanos: ch 956.5 gap #5 recency timestamp
    /// - Returns: exactly one delta (never empty)
    public static func emit(
        from input: BASSurfaceInput,
        turnID: String,
        agentSpec: BASAgentSpec,
        seq: inout Int,
        nowNanos: Int64 = 0
    ) -> [BASAgentDelta] {
        seq += 1
        let (mode, reasons) = pickMode(input: input)
        let payload = encodeSurfacePayload(
            input: input, mode: mode)
        // Confidence reflects how clearly the inputs dictate the
        // mode。 .block / .silentStub from explicit signals = 0.95。
        // Compare mode (user-requested) = 0.85。 Answer = 0.7
        // (default,many alternatives could have been chosen)。
        let conf: Double
        switch mode {
        case .block, .silentStub: conf = 0.95
        case .compare: conf = 0.85
        case .delay, .draftOnly, .localOnly, .replace: conf = 0.8
        case .answer: conf = 0.7
        }
        return [BASAgentDelta(
            deltaID: "delta.\(turnID).surface.\(seq)",
            agentID: agentSpec.agentID,
            // Surface domain object ID is per-turn singleton
            targetObjectRef: "renderFrame#rf-\(turnID)",
            deltaType: .replace,
            patchJson: payload,
            confidence: conf,
            createdAtNanos: nowNanos,
            reasonCodes: ["surface.choose"] + reasons)]
    }

    // MARK: - Mode picker (pure function with explicit priority)

    /// Pick the surface mode for the input。 Pure。 Priority order
    /// (top wins):
    ///
    ///   sovereign veto > permit denied > high-risk > med-risk
    ///   irreversible > user compare > has candidate > no candidate
    ///
    /// Returns mode + accumulated reason codes for the audit ledger。
    private static func pickMode(
        input: BASSurfaceInput
    ) -> (BASSurfaceSeatMode, [String]) {
        var reasons: [String] = []
        // 1. Sovereign veto wins everything
        if input.sovereignVetoed {
            reasons.append("surface.sovereign-veto")
            return (.block, reasons)
        }
        // 2. Action permit denied → block
        if !input.actionPermitGranted {
            reasons.append("surface.permit-denied")
            return (.block, reasons)
        }
        // 3. High-risk:block by default。 If reversibility is
        // sufficient (≥0.7),delay instead of block — gives user
        // option to confirm。
        if input.riskBand == .high {
            if input.reversibility >= 0.7 {
                reasons.append("surface.risk-high-but-reversible")
                return (.delay, reasons)
            }
            reasons.append("surface.risk-high-irreversible")
            return (.block, reasons)
        }
        // 4. Medium-risk + irreversible → delay (give user time)
        if input.riskBand == .medium &&
           input.reversibility < 0.5 {
            reasons.append("surface.risk-med-irreversible")
            return (.delay, reasons)
        }
        // 5. User explicitly requested compare
        if input.userRequestsCompare {
            reasons.append("surface.user-compare")
            return (.compare, reasons)
        }
        // 6. Has a candidate → answer
        if input.acceptedCandidateID != nil {
            reasons.append("surface.accepted-candidate")
            return (.answer, reasons)
        }
        // 7. Fallback:silent stub (nothing to surface)
        reasons.append("surface.no-candidate")
        return (.silentStub, reasons)
    }

    // MARK: - Payload encoder

    private static func encodeSurfacePayload(
        input: BASSurfaceInput,
        mode: BASSurfaceSeatMode
    ) -> String {
        var parts: [String] = []
        parts.append("\"mode\":\"\(mode.rawValue)\"")
        parts.append(
            ",\"candidate_id\":" +
            "\(jsonStringOrNull(input.acceptedCandidateID))")
        parts.append(
            ",\"permit_granted\":" +
            "\(input.actionPermitGranted)")
        parts.append(
            ",\"risk_band\":\"\(input.riskBand.rawValue)\"")
        parts.append(
            ",\"reversibility\":" +
            "\(formatDouble(input.reversibility))")
        parts.append(
            ",\"sovereign_vetoed\":" +
            "\(input.sovereignVetoed)")
        parts.append(
            ",\"user_compare\":\(input.userRequestsCompare)")
        return "{\(parts.joined())}"
    }

    private static func jsonStringOrNull(_ s: String?) -> String {
        guard let s else { return "null" }
        return "\"\(s.escapeForJSON())\""
    }

    private static func formatDouble(_ v: Double) -> String {
        return String(format: "%.6f", v)
    }
}

// MARK: - JSON escape helper (file-scope, same as other seats)

// chapter 九百八十一.9 USER-PASS-10 ARC FINALIZE item 8
// migration:delegates to shared `BASAgentFabricJSONEscape`。
private extension String {
    func escapeForJSON() -> String {
        BASAgentFabricJSONEscape.escape(self)
    }
}
