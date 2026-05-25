// MARK: - BASScoutSeat
// chapter 九百五十七 / M3490 — Phase 1 ch2:Scout seat wrapper
//
// User design Section 9.1-9.3:Scout is a CORE agent (always-on,
// hot-seat profile) sitting at the front edge of L1+L2+L6。 In
// every turn,Scout reads the freshly-computed L6/L7 decompose
// frame + L1 lease state and emits `BASAgentDelta` proposals for
// the `.situationField` domain。
//
// Per Single-Writer-Per-Domain (ch 956.5 USER-PASS gap #1) Scout
// is the SOLE writer for `.situationField` — other agents may
// READ it (Planner uses pressure signals to weight candidates,
// Risk uses manipulation patterns to escalate) but never write。
//
// ## Why a pure function,not an actor
//
// Per ch 956.6 measurement-first discipline + 红线 7 OPT-IN:the
// seat is a pure `[BASAgentDelta]`-emitting function。 No actor,
// no I/O,no shared state beyond the supplied input。 This lets
// the coordinator (ch 958 wiring) call it without taking a new
// actor-isolation hop。 Per ch 956.11 H2 it also has no DoS
// surface — bounded by input size。
//
// ## What it emits
//
// One delta per high-signal cluster from the decompose frame:
//   - Pressure cluster (any non-empty `pressureSignals` /
//     `pressureVectors`) → 1 delta type=.merge,
//     targetObjectRef=`situationField#pressure-<turnID>`
//   - Manipulation cluster (any non-empty `manipulationSignals` /
//     `manipulationPatterns`) → 1 delta type=.merge,
//     targetObjectRef=`situationField#manipulation-<turnID>`
//   - Boundary cluster (any non-empty `boundaryTouches`) → 1
//     delta type=.merge,
//     targetObjectRef=`situationField#boundary-<turnID>`
//   - Goal-spine + contradictions → optional cluster
//
// Empty clusters produce NO delta (zero-delta turns are valid)。
// Per the Agent Fabric Section 9.4 priority,confidence is set
// by signal count + reasonCodes accumulate evidence prefixes
// for the audit ledger。
//
// ## Ownership + scoping
//
// `agentSpec` is the Scout's `BASAgentSpec` from the registry。
// `turnID` is the per-turn ID (collision-resistant per ch 956.5
// strong mergeID design)。 `seq` is an inout counter so multiple
// seats sharing a deltaID seq space (per-turn) don't collide。

import Foundation

/// Slim DTO carrying only the L7 decompose-frame signals the
/// Scout seat needs。 Decouples `BASMemory` (where this seat
/// lives) from `BASOrchestration` (where `BASDecomposeFrame`
/// lives — and which already imports BASMemory,so we cannot
/// import it back)。 Coordinator integration (ch 958+) builds
/// this DTO from the live frame via a one-line adapter。
public struct BASScoutInput:
    Sendable, Equatable, Hashable, Codable
{
    /// Raw pressure-signal strings (sorted by caller or here)
    public let pressureSignals: [String]
    /// Number of structured pressure vectors
    public let pressureVectorCount: Int
    /// Raw manipulation-signal strings
    public let manipulationSignals: [String]
    /// Number of structured manipulation patterns
    public let manipulationPatternCount: Int
    /// Number of boundary touches in this turn's frame
    public let boundaryTouchCount: Int
    /// Number of structured contradiction records
    public let contradictionRecordCount: Int
    /// Bare contradiction strings (sorted by caller or here)
    public let bareContradictions: [String]

    public init(
        pressureSignals: [String] = [],
        pressureVectorCount: Int = 0,
        manipulationSignals: [String] = [],
        manipulationPatternCount: Int = 0,
        boundaryTouchCount: Int = 0,
        contradictionRecordCount: Int = 0,
        bareContradictions: [String] = []
    ) {
        self.pressureSignals = pressureSignals
        self.pressureVectorCount = pressureVectorCount
        self.manipulationSignals = manipulationSignals
        self.manipulationPatternCount = manipulationPatternCount
        self.boundaryTouchCount = boundaryTouchCount
        self.contradictionRecordCount = contradictionRecordCount
        self.bareContradictions = bareContradictions
    }

    /// True when the input has no observable signal — no deltas
    /// will be emitted。 Caller can short-circuit before calling
    /// `emit()`。
    public var isEmpty: Bool {
        pressureSignals.isEmpty &&
        pressureVectorCount == 0 &&
        manipulationSignals.isEmpty &&
        manipulationPatternCount == 0 &&
        boundaryTouchCount == 0 &&
        contradictionRecordCount == 0
    }
}

public enum BASScoutSeat {

    /// Pure-function:read scout input,emit deltas for
    /// `.situationField`。 Caller MUST pass `agentSpec.writeDomains`
    /// containing `.situationField` (the apply step enforces;
    /// this function only constructs)。
    ///
    /// - Parameters:
    ///   - input: slim DTO built from L7 decompose-frame
    ///   - turnID: per-turn ID for ref namespacing + reasonCodes
    ///   - agentSpec: Scout's registry spec (used for `agentID`)
    ///   - seq: per-turn delta sequence counter (inout — bumped
    ///     by each emitted delta)
    ///   - nowNanos: monotonic timestamp for the ch 956.5 USER-PASS
    ///     gap #5 real-recency tie-break。 Caller supplies (typically
    ///     `Int64(Date().timeIntervalSince1970 * 1_000_000_000)`)
    /// - Returns: list of deltas (may be empty for "nothing observed"
    ///   turns)
    public static func emit(
        from input: BASScoutInput,
        turnID: String,
        agentSpec: BASAgentSpec,
        seq: inout Int,
        nowNanos: Int64 = 0
    ) -> [BASAgentDelta] {
        var out: [BASAgentDelta] = []
        // Cluster 1:pressure。 Confidence scales by signal count
        // — capped at 1.0。 Reason codes include evidence prefixes
        // for downstream audit ledger。
        let pressureCount = input.pressureSignals.count +
            input.pressureVectorCount
        if pressureCount > 0 {
            seq += 1
            let conf = min(
                1.0, 0.5 + (Double(pressureCount) * 0.1))
            let payload = encodePressurePayload(input: input)
            out.append(BASAgentDelta(
                deltaID:
                    "delta.\(turnID).scout.\(seq)",
                agentID: agentSpec.agentID,
                targetObjectRef:
                    "situationField#pressure-\(turnID)",
                deltaType: .merge,
                patchJson: payload,
                confidence: conf,
                createdAtNanos: nowNanos,
                reasonCodes: [
                    "scout.pressure",
                    "evidence.signal-count=\(pressureCount)",
                ]))
        }
        // Cluster 2:manipulation。 Higher base confidence —
        // manipulation patterns are HIGH-stakes signals for
        // Risk agent escalation。
        let manipCount = input.manipulationSignals.count +
            input.manipulationPatternCount
        if manipCount > 0 {
            seq += 1
            let conf = min(
                1.0, 0.7 + (Double(manipCount) * 0.05))
            let payload = encodeManipPayload(input: input)
            out.append(BASAgentDelta(
                deltaID:
                    "delta.\(turnID).scout.\(seq)",
                agentID: agentSpec.agentID,
                targetObjectRef:
                    "situationField#manipulation-\(turnID)",
                deltaType: .merge,
                patchJson: payload,
                confidence: conf,
                createdAtNanos: nowNanos,
                reasonCodes: [
                    "scout.manipulation",
                    "evidence.signal-count=\(manipCount)",
                ]))
        }
        // Cluster 3:boundary touches。 Confidence reflects
        // discrete boundary count (each touch is a discrete event)。
        let boundaryCount = input.boundaryTouchCount
        if boundaryCount > 0 {
            seq += 1
            let conf = min(
                1.0, 0.6 + (Double(boundaryCount) * 0.1))
            let payload = encodeBoundaryPayload(input: input)
            out.append(BASAgentDelta(
                deltaID:
                    "delta.\(turnID).scout.\(seq)",
                agentID: agentSpec.agentID,
                targetObjectRef:
                    "situationField#boundary-\(turnID)",
                deltaType: .merge,
                patchJson: payload,
                confidence: conf,
                createdAtNanos: nowNanos,
                reasonCodes: [
                    "scout.boundary",
                    "evidence.touch-count=\(boundaryCount)",
                ]))
        }
        // Cluster 4:contradictions (if any) — emitted as a
        // distinct signal so Critic agent (ch 961) can attach
        // critique deltas later。
        let contradictionCount = input.contradictionRecordCount
        if contradictionCount > 0 {
            seq += 1
            let conf = min(
                1.0, 0.65 + (Double(contradictionCount) * 0.07))
            let payload = encodeContradictionPayload(input: input)
            out.append(BASAgentDelta(
                deltaID:
                    "delta.\(turnID).scout.\(seq)",
                agentID: agentSpec.agentID,
                targetObjectRef:
                    "situationField#contradiction-\(turnID)",
                deltaType: .merge,
                patchJson: payload,
                confidence: conf,
                createdAtNanos: nowNanos,
                reasonCodes: [
                    "scout.contradiction",
                    "evidence.record-count=" +
                        "\(contradictionCount)",
                ]))
        }
        return out
    }

    // MARK: - Payload encoders (deterministic minimal JSON)
    //
    // Pure functions producing a stable JSON shape per cluster。
    // Deterministic (sorted keys,no Date stamps) so the same
    // input produces byte-equal output across runs — critical
    // for the merge engine's strong-mergeID hash invariance。

    // MARK: - Payload encoders (deterministic minimal JSON)

    private static func encodePressurePayload(
        input: BASScoutInput
    ) -> String {
        let signals = input.pressureSignals.sorted()
        let vectorCount = input.pressureVectorCount
        var parts: [String] = []
        parts.append("\"signals\":[")
        parts.append(signals.map {
            "\"\($0.escapeForJSON())\""
        }.joined(separator: ","))
        parts.append("]")
        parts.append(",\"vector_count\":\(vectorCount)")
        return "{\(parts.joined())}"
    }

    private static func encodeManipPayload(
        input: BASScoutInput
    ) -> String {
        let signals = input.manipulationSignals.sorted()
        let patternCount = input.manipulationPatternCount
        var parts: [String] = []
        parts.append("\"signals\":[")
        parts.append(signals.map {
            "\"\($0.escapeForJSON())\""
        }.joined(separator: ","))
        parts.append("]")
        parts.append(",\"pattern_count\":\(patternCount)")
        return "{\(parts.joined())}"
    }

    private static func encodeBoundaryPayload(
        input: BASScoutInput
    ) -> String {
        return "{\"touch_count\":\(input.boundaryTouchCount)}"
    }

    private static func encodeContradictionPayload(
        input: BASScoutInput
    ) -> String {
        let bareList = input.bareContradictions.sorted()
        var parts: [String] = []
        parts.append(
            "\"record_count\":\(input.contradictionRecordCount)")
        parts.append(",\"bare\":[")
        parts.append(bareList.map {
            "\"\($0.escapeForJSON())\""
        }.joined(separator: ","))
        parts.append("]")
        return "{\(parts.joined())}"
    }
}

// MARK: - JSON escape helper (private to this file)

private extension String {
    /// Minimal JSON-string escape:backslash + double-quote。
    /// Sufficient for ASCII-safe substrate-internal signal IDs。
    /// For arbitrary user input,upgrade to full JSON encode。
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
