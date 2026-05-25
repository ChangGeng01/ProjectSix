// MARK: - BASSovereignSentinelSeat
// chapter 九百六十四 / M3525 — Phase 3 ch2:SovereignSentinel seat
//
// User design Section 9.5-9.6 + Single-Writer table:SovereignSentinel
// is the LOAD-BEARING sealed-LOW seat — its job is to flag turns
// requiring sovereign veto。 Per visibility table (LOW tier):NO
// user customization。 Always force-default per Root Law 4 (单主权)。
//
// Single-Writer-Per-Domain:SovereignSentinel is the SOLE writer
// for `.sovereignVerdict`。 No other seat — not even HostAlignment
// or EvolutionShadow — may write this domain。 Per ch 963 tests
// + ch 956.5 USER-PASS gap #1,the graph actor enforces this at
// write time via per-agent writeDomains + global writer registry。
//
// ## What it does
//
// Per design,SovereignSentinel reads:
//   - Risk signals (manipulation,boundary touches,irreversibility)
//   - HostAlignment outputs (multi-axis boundary violations)
//   - User's host-constitution sovereign-locked axes
// And emits sovereign-verdict deltas with veto severity per turn。
//
// In Phase 3 ch2 (THIS chapter) the rules are heuristic — same
// thin-wrapper shape as the other seats。 Future ch 965+ wires
// the actual L14 `BASSovereignVerdictEngine.raise()` lambda via
// the coordinator adapter when the host has one configured。
//
// ## Sealed-LOW tier enforcement
//
// Per the plan's 3-tier visibility table:
//   - HIGH tier:user-customizable (Planner/Critic/Memory/Risk/Surface)
//   - MED tier:partial (HostAlignment/CompareModerator/Reflector)
//   - LOW tier:sealed-default (SovereignSentinel/ActionPermit/...)
//
// `agentSpec.visibility` MUST be `.low` for any SovereignSentinel
// agent — this seat doesn't enforce that constraint here (the
// registry layer does)。 But the seat's design pin says:
// no input field should let the host TUNE the veto thresholds。
// The thresholds are hard-coded constants in this file。

import Foundation

/// Per-candidate input for SovereignSentinel — minimum signals
/// needed to decide veto。 Mirrors fields from Risk + HostAlignment
/// + Critic seats since the sentinel makes the final call。
public struct BASSovereignSentinelCandidate:
    Sendable, Equatable, Hashable, Codable
{
    public let candidateID: String
    public let title: String
    /// 0.0 = irreversible action, 1.0 = trivially undoable
    public let reversibility: Double
    /// Count of host boundary axes this candidate touches。 Mirrors
    /// HostAlignment input。 ≥2 is a strong veto signal。
    public let touchesAxesCount: Int
    /// Whether the candidate has been flagged for a sovereign-
    /// locked axis touch (e.g. host-version mutation,deletion-
    /// manifest update,memory-seal write)。 Set by caller from
    /// the host constitution + permit gate state。
    public let touchesSovereignLockedAxis: Bool

    public init(
        candidateID: String,
        title: String,
        reversibility: Double,
        touchesAxesCount: Int = 0,
        touchesSovereignLockedAxis: Bool = false
    ) {
        self.candidateID = candidateID
        self.title = title
        self.reversibility = reversibility
        self.touchesAxesCount = touchesAxesCount
        self.touchesSovereignLockedAxis =
            touchesSovereignLockedAxis
    }
}

/// Slim DTO carrying candidates + turn-level signals for the
/// sentinel。 Built by the coordinator adapter from L11 risk
/// state + L7 frame + L5 host constitution + caller's emitted
/// candidates。
public struct BASSovereignSentinelInput:
    Sendable, Equatable, Hashable, Codable
{
    public let candidates:
        [BASSovereignSentinelCandidate]
    /// True if Scout / L7 flagged manipulation patterns this turn
    public let manipulationDetected: Bool
    /// True if Scout / L7 flagged boundary touches this turn
    public let boundaryTouched: Bool
    /// True if the user is in a heightened-protection mode
    /// (e.g. emergency,vulnerable state per host constitution)。
    /// Sealed signal — host sets this,not user。
    public let heightenedProtection: Bool

    public init(
        candidates: [BASSovereignSentinelCandidate] = [],
        manipulationDetected: Bool = false,
        boundaryTouched: Bool = false,
        heightenedProtection: Bool = false
    ) {
        self.candidates = candidates
        self.manipulationDetected = manipulationDetected
        self.boundaryTouched = boundaryTouched
        self.heightenedProtection = heightenedProtection
    }
}

/// Veto severity per candidate per rule。
public enum BASSovereignVetoSeverity: String,
    Sendable, Equatable, Hashable, Codable, CaseIterable
{
    case clear      // No veto, no delta emitted
    case escalate   // Watch this candidate, notify但不阻断
    case veto       // Block this candidate (full veto)
    case lockdown   // Block entire turn (sovereign-locked axis touched)
}

public enum BASSovereignSentinelSeat {

    // MARK: - SEALED rule thresholds (no user-tunable knobs)

    /// Threshold for "many" boundary axes → veto。 SEALED per
    /// LOW-tier visibility — no caller can override。
    public static let multiAxisVetoCount: Int = 2

    /// Threshold for "very irreversible" → veto when combined
    /// with manipulation。 SEALED。
    public static let irreversibilityFloor: Double = 0.2

    /// Pure-function:emit one veto delta per concerning candidate
    /// + optionally one turn-level lockdown delta。 Caller MUST
    /// pass `agentSpec.writeDomains` containing `.sovereignVerdict`。
    ///
    /// Veto rules (ordered — first match per candidate wins):
    ///   1. touchesSovereignLockedAxis → LOCKDOWN (block whole turn)
    ///   2. heightenedProtection AND
    ///      (manipulation OR boundary) → VETO
    ///   3. manipulation AND reversibility < floor → VETO
    ///   4. touchesAxesCount ≥ multiAxisVetoCount → VETO
    ///   5. manipulation OR boundary → ESCALATE
    ///   6. otherwise → CLEAR (no delta)
    public static func emit(
        from input: BASSovereignSentinelInput,
        turnID: String,
        agentSpec: BASAgentSpec,
        seq: inout Int,
        nowNanos: Int64 = 0
    ) -> [BASAgentDelta] {
        var out: [BASAgentDelta] = []
        var anyLockdown = false
        for candidate in input.candidates {
            let (severity, reasons) = assess(
                candidate: candidate, input: input)
            if severity == .clear { continue }
            seq += 1
            let conf: Double
            switch severity {
            case .lockdown: conf = 1.0
            case .veto: conf = 0.97
            case .escalate: conf = 0.85
            case .clear: conf = 0.0  // unreachable
            }
            if severity == .lockdown { anyLockdown = true }
            let payload = encodeVetoPayload(
                candidate: candidate,
                severity: severity,
                input: input)
            out.append(BASAgentDelta(
                deltaID:
                    "delta.\(turnID).sovereign.\(seq)",
                agentID: agentSpec.agentID,
                targetObjectRef:
                    "sovereignVerdict#sv-\(turnID)" +
                    "-\(candidate.candidateID)",
                deltaType: .merge,
                patchJson: payload,
                confidence: conf,
                createdAtNanos: nowNanos,
                reasonCodes:
                    ["sovereign.assess"] + reasons))
        }
        // Turn-level lockdown delta if ANY candidate hit lockdown
        if anyLockdown {
            seq += 1
            out.append(BASAgentDelta(
                deltaID:
                    "delta.\(turnID).sovereign.\(seq)",
                agentID: agentSpec.agentID,
                // chapter 九百六十四.5 USER-PASS-5 H3 fix:reserved
                // turn-level objectID uses a control character (\u{1F})
                // unit-separator prefix that NO valid candidateID can
                // contain (per-seat candidate IDs are caller-supplied
                // user-space strings;control chars are not used by
                // any existing emit path)。 Previously the literal
                // suffix "TURN-LOCKDOWN" could collide with a
                // candidate of that exact ID。
                targetObjectRef:
                    "sovereignVerdict#sv-\(turnID)-" +
                    "\u{001F}TURN-LOCKDOWN",
                deltaType: .merge,
                patchJson:
                    "{\"scope\":\"turn\"," +
                    "\"verdict\":\"lockdown\"," +
                    "\"reason\":\"sovereign-axis-touched\"}",
                confidence: 1.0,
                createdAtNanos: nowNanos,
                reasonCodes: [
                    "sovereign.turn-lockdown",
                    "sovereign.scope=turn",
                ]))
        }
        return out
    }

    /// chapter 九百六十四.5 — substring tests + ref consumers can
    /// recognize the reserved turn-level lockdown marker via this
    /// constant。 No caller can produce this byte sequence in a
    /// candidateID since the seat-emit path doesn't accept control
    /// chars + the marker starts with U+001F unit separator。
    public static let turnLockdownRefSuffix: String =
        "-\u{001F}TURN-LOCKDOWN"

    // MARK: - Veto assessment rule

    private static func assess(
        candidate: BASSovereignSentinelCandidate,
        input: BASSovereignSentinelInput
    ) -> (BASSovereignVetoSeverity, [String]) {
        var reasons: [String] = []
        // Rule 1: sovereign-axis touch → LOCKDOWN (highest)
        if candidate.touchesSovereignLockedAxis {
            reasons.append(
                "sovereign.severity=axis-lockdown")
            reasons.append(
                "sovereign.touched-locked-axis=true")
            return (.lockdown, reasons)
        }
        // Rule 2: heightened protection + concerning signal
        if input.heightenedProtection &&
           (input.manipulationDetected ||
            input.boundaryTouched) {
            reasons.append(
                "sovereign.severity=heightened-veto")
            reasons.append(
                "sovereign.heightened-protection=true")
            return (.veto, reasons)
        }
        // Rule 3: manipulation + irreversible
        if input.manipulationDetected &&
           candidate.reversibility < irreversibilityFloor {
            reasons.append(
                "sovereign.severity=manip-irreversible")
            return (.veto, reasons)
        }
        // Rule 4: multi-axis boundary violation
        if candidate.touchesAxesCount >=
            multiAxisVetoCount
        {
            reasons.append(
                "sovereign.severity=multi-axis-veto")
            reasons.append(
                "sovereign.touched-count=" +
                "\(candidate.touchesAxesCount)")
            return (.veto, reasons)
        }
        // Rule 5: manipulation OR boundary alone → ESCALATE
        if input.manipulationDetected ||
           input.boundaryTouched
        {
            reasons.append(
                "sovereign.severity=escalate")
            if input.manipulationDetected {
                reasons.append(
                    "sovereign.escalate-reason=manipulation")
            }
            if input.boundaryTouched {
                reasons.append(
                    "sovereign.escalate-reason=boundary")
            }
            return (.escalate, reasons)
        }
        // Rule 6: clear
        return (.clear, reasons)
    }

    // MARK: - Payload encoder

    private static func encodeVetoPayload(
        candidate: BASSovereignSentinelCandidate,
        severity: BASSovereignVetoSeverity,
        input: BASSovereignSentinelInput
    ) -> String {
        var parts: [String] = []
        parts.append(
            "\"candidate_id\":\"" +
            "\(candidate.candidateID.escapeForJSONSS())\"")
        parts.append(
            ",\"severity\":\"\(severity.rawValue)\"")
        let revStr = String(
            format: "%.6f", candidate.reversibility)
        parts.append(
            ",\"reversibility\":\(revStr)")
        parts.append(
            ",\"touches_locked_axis\":" +
            "\(candidate.touchesSovereignLockedAxis)")
        parts.append(
            ",\"touches_axes_count\":" +
            "\(candidate.touchesAxesCount)")
        parts.append(
            ",\"manipulation\":" +
            "\(input.manipulationDetected)")
        parts.append(
            ",\"boundary\":\(input.boundaryTouched)")
        parts.append(
            ",\"heightened\":" +
            "\(input.heightenedProtection)")
        return "{\(parts.joined())}"
    }
}

private extension String {
    func escapeForJSONSS() -> String {
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
