// MARK: - BASHostAlignmentSeat
// chapter 九百六十三 / M3520 — Phase 3 ch1:HostAlignment seat
//
// User design Section 9.5 + Single-Writer table:HostAlignment is a
// MED-visibility CORE agent (partial customization — style + cadence
// only)。 Per Single-Writer-Per-Domain HostAlignment is the SOLE
// writer for `.alignmentField` (NEW ch 963 domain — see enum)。
//
// CRITICAL invariant:HostAlignment CANNOT write `.hostVersion` —
// that's sovereign-locked per the plan's Single-Writer table:
//   `hostVersion → L5 + L14 (L13 proposes only)`
// HostAlignment's writeDomains contains ONLY `.alignmentField`。
// The graph actor enforces this at write time (per ch 956.5
// USER-PASS gap #1 + ch 956.11 CR2)。
//
// HostAlignment's job:check each candidate against the host
// constitution's boundary axes (user's protected values / topics)。
// If a candidate touches a protected axis,emit an alignment-delta
// with the appropriate severity。 Future Planner-v2 (ch 963+)
// reads `.alignmentField` to downweight candidates that violate
// host alignment;Risk + Surface also consume it for gate decisions。
//
// ## Design discipline
//
// Same pure-fn + slim-DTO pattern as ch 957-961。 HostAlignment
// does NOT directly import `BASHostConstitution` — the coordinator
// adapter (`BASAgentFabricAdapters` in BASOrchestration) builds the
// slim DTO from the live host constitution。 Keeps BASMemory
// independent of BASHostKit。

import Foundation

/// Slim DTO carrying the candidate fields HostAlignment needs。
public struct BASHostAlignmentCandidate:
    Sendable, Equatable, Hashable, Codable
{
    public let candidateID: String
    /// Short summary of the candidate action — used in payload
    /// audit trail。
    public let title: String
    /// Axes this candidate's action touches (e.g.
    /// ["financial","relational","privacy"])。 Empty list = the
    /// candidate doesn't touch any boundary axes (default-aligned)。
    public let touchesAxes: [String]

    public init(
        candidateID: String,
        title: String,
        touchesAxes: [String] = []
    ) {
        self.candidateID = candidateID
        self.title = title
        self.touchesAxes = touchesAxes
    }
}

/// Slim DTO carrying the host's protected-axes list + style
/// strictness。 Built by the coordinator adapter from the live
/// `BASHostConstitution.styleGenome` + `boundaryAxes`。
public struct BASHostAlignmentInput:
    Sendable, Equatable, Hashable, Codable
{
    public let candidates: [BASHostAlignmentCandidate]
    /// Axes the host user has marked as PROTECTED — actions
    /// touching these trigger alignment-deltas。 Per chapter
    /// 956.11 H2 DoS bound discipline,this is conceptually
    /// bounded by host-constitution size (typically <50)。
    public let hostBoundaryAxes: [String]
    /// Style strictness ∈ [0.0, 1.0] — at ≥0.7 even non-boundary
    /// candidates get a mild alignment-delta for audit purposes
    /// (style review)。 Mirrors the Critic's superegoActiveLevel
    /// pattern。
    public let styleStrictness: Double
    /// Host ID for audit trail。 Empty string = unknown / global
    /// fallback。
    public let hostID: String

    public init(
        candidates: [BASHostAlignmentCandidate] = [],
        hostBoundaryAxes: [String] = [],
        styleStrictness: Double = 0.5,
        hostID: String = ""
    ) {
        self.candidates = candidates
        self.hostBoundaryAxes = hostBoundaryAxes
        self.styleStrictness = styleStrictness
        self.hostID = hostID
    }
}

/// Alignment severity per candidate per rule。 Distinct enum from
/// Critic's severity (different semantic domain — host alignment
/// vs cost/benefit analysis)。
public enum BASHostAlignmentSeverity: String,
    Sendable, Equatable, Hashable, Codable, CaseIterable
{
    case aligned        // No concern, no delta emitted
    case styleNote      // Strict-mode audit-only note
    case axisTouch      // Single boundary-axis touch
    case multiAxisTouch // Multiple boundary-axis touches (severe)
}

public enum BASHostAlignmentSeat {

    /// Pure-function:emit one alignment-delta per candidate with
    /// non-aligned severity。 Caller MUST pass `agentSpec.writeDomains`
    /// containing `.alignmentField`。
    ///
    /// Alignment rules (ordered — first match wins):
    ///   1. Candidate touches ≥2 host boundary axes → MULTI_AXIS_TOUCH
    ///   2. Candidate touches exactly 1 host boundary axis → AXIS_TOUCH
    ///   3. styleStrictness ≥ 0.7 AND no boundary touch → STYLE_NOTE
    ///   4. Otherwise → ALIGNED (no delta)
    public static func emit(
        from input: BASHostAlignmentInput,
        turnID: String,
        agentSpec: BASAgentSpec,
        seq: inout Int,
        nowNanos: Int64 = 0
    ) -> [BASAgentDelta] {
        let boundarySet = Set(input.hostBoundaryAxes)
        var out: [BASAgentDelta] = []
        for candidate in input.candidates {
            let (severity, touchedAxes, reasons) =
                assessAlignment(
                    candidate: candidate,
                    boundarySet: boundarySet,
                    styleStrictness: input.styleStrictness)
            if severity == .aligned { continue }
            seq += 1
            let conf: Double
            switch severity {
            case .multiAxisTouch: conf = 0.95
            case .axisTouch: conf = 0.80
            case .styleNote: conf = 0.50
            case .aligned: conf = 0.0  // unreachable
            }
            let payload = encodeAlignmentPayload(
                candidate: candidate,
                severity: severity,
                touchedAxes: touchedAxes,
                hostID: input.hostID,
                styleStrictness: input.styleStrictness)
            out.append(BASAgentDelta(
                deltaID:
                    "delta.\(turnID).hostalign.\(seq)",
                agentID: agentSpec.agentID,
                targetObjectRef:
                    "alignmentField#af-\(turnID)" +
                    "-\(candidate.candidateID)",
                deltaType: .merge,
                patchJson: payload,
                confidence: conf,
                createdAtNanos: nowNanos,
                reasonCodes:
                    ["hostalign.assess"] + reasons))
        }
        return out
    }

    // MARK: - Assessment rule

    private static func assessAlignment(
        candidate: BASHostAlignmentCandidate,
        boundarySet: Set<String>,
        styleStrictness: Double
    ) -> (
        BASHostAlignmentSeverity,
        [String],
        [String]
    ) {
        // Compute intersection of candidate's touched axes with
        // host's protected axes
        let touched = candidate.touchesAxes.filter {
            boundarySet.contains($0)
        }.sorted()  // sorted for deterministic payload
        var reasons: [String] = []
        if touched.count >= 2 {
            reasons.append("hostalign.multi-axis-touch")
            reasons.append(
                "hostalign.touched-count=\(touched.count)")
            return (.multiAxisTouch, touched, reasons)
        }
        if touched.count == 1 {
            reasons.append("hostalign.axis-touch")
            reasons.append("hostalign.touched=\(touched[0])")
            return (.axisTouch, touched, reasons)
        }
        // No boundary touch — only emit if strict mode
        if styleStrictness >= 0.7 {
            reasons.append("hostalign.strict-style-note")
            return (.styleNote, [], reasons)
        }
        return (.aligned, [], reasons)
    }

    // MARK: - Payload encoder

    private static func encodeAlignmentPayload(
        candidate: BASHostAlignmentCandidate,
        severity: BASHostAlignmentSeverity,
        touchedAxes: [String],
        hostID: String,
        styleStrictness: Double
    ) -> String {
        var parts: [String] = []
        parts.append(
            "\"candidate_id\":\"" +
            "\(candidate.candidateID.escapeForJSONHA())\"")
        parts.append(
            ",\"severity\":\"\(severity.rawValue)\"")
        parts.append(
            ",\"touched_axes\":[" +
            touchedAxes.map {
                "\"\($0.escapeForJSONHA())\""
            }.joined(separator: ",") +
            "]")
        parts.append(
            ",\"host_id\":\"\(hostID.escapeForJSONHA())\"")
        parts.append(
            ",\"strictness\":" +
            "\(String(format: "%.6f", styleStrictness))")
        return "{\(parts.joined())}"
    }
}

private extension String {
    /// JSON escape with HA suffix to avoid collision with other
    /// seat extensions (Swift can't disambiguate two file-private
    /// extensions with the same method name in the same module)。
    /// chapter 九百八十一.9 USER-PASS-10 ARC FINALIZE item 8
    /// migration:delegates to shared `BASAgentFabricJSONEscape`。
    func escapeForJSONHA() -> String {
        BASAgentFabricJSONEscape.escape(self)
    }
}
