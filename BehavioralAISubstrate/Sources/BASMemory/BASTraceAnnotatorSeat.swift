// MARK: - BASTraceAnnotatorSeat
// chapter 一千零二 / M3715 — Closes `.annotate` 💀 DEAD case
//
// Per ch 995.9 META-REVIEW Round-14 HIGH-1 doctrine the
// `BASAgentDeltaType.annotate` case had been emitted by NO seat in
// the entire substrate since it shipped at ch 953。 The applier
// already grouped it with the payload-bearing `.add` / `.replace` /
// `.merge` branch (same write semantics),and `Docs/SCAFFOLD_VS_WIRED.md`
// recorded it as 💀 DEAD reserved for "a future audit-only trace
// seat that annotates without mutating"。 This is that seat。
//
// ## What it does
//
// Per turn,emits ONE `.annotate` delta against the
// `.traceAnnotation` domain that records:
//   - turnID
//   - sorted list of agentIDs that emitted at least one delta this
//     turn (deterministic — `agentIDs.sorted()`)
//   - per-agent emitted-delta counts
//   - total emitted-delta count
//
// The payload is deterministic minimal JSON — byte-equal across
// runs for the same input,enabling strong-mergeID hash invariance
// (ch 956.5 USER-PASS gap #5 contract)。
//
// ## Why a pure function,not an actor
//
// Mirrors the ch 957 Scout seat doctrine:no actor isolation,no
// I/O,no shared state beyond supplied input。 The coordinator
// (any future wire-up) can call it without taking an actor hop。
//
// ## Why a dedicated `.traceAnnotation` domain
//
// Single-Writer-Per-Domain (ch 956.5 USER-PASS gap #1) forbids the
// annotator from writing other agents' domains。 A dedicated domain
// means:
//   1. The TraceAnnotator never contends with a production writer
//   2. Audit / replay consumers can scope reads to one domain
//   3. Annotations cannot accidentally corrupt production state
//      (the applier's payload-bearing branch writes the JSON as-is,
//      so wrong-domain annotation would overwrite production payload)
//
// ## What it does NOT do
//
// - Does NOT mutate any production domain。 The seat is read-only
//   over the per-turn delta list passed in。
// - Does NOT register itself with the Agent Router automatically。
//   Phase 0+ wire-up to `BASAgentTurnRoster` is deferred (the seat
//   is shipped as a pure-fn ready for opt-in adoption)。
// - Does NOT block the turn。 The annotation is an additive write
//   to a domain no production seat reads,so failure to apply is
//   non-fatal (caller can log the per-delta outcome)。

import Foundation

/// Slim DTO carrying per-turn delta-emission summary。 The seat
/// reads this + emits one annotation delta。
public struct BASTraceAnnotatorInput:
    Sendable, Equatable, Hashable, Codable
{
    /// Per-turn ID — drives `targetObjectRef` namespacing。
    public let turnID: String
    /// All deltas emitted in the turn (any agent,any domain)。
    /// The seat reads only agentID + deltaID + deltaType counts —
    /// payloads are NOT read (annotations stay metadata-light)。
    public let emittedDeltas: [BASAgentDelta]

    public init(
        turnID: String,
        emittedDeltas: [BASAgentDelta]
    ) {
        self.turnID = turnID
        self.emittedDeltas = emittedDeltas
    }

    /// True when the turn had no observable delta activity — the
    /// seat MAY short-circuit emit (callers decide:per ch 957
    /// Scout precedent,zero-signal turns produce zero deltas)。
    public var isEmpty: Bool { emittedDeltas.isEmpty }
}

public enum BASTraceAnnotatorSeat {

    /// chapter 一千零十.5 / M3760 — Round-20 self-audit
    /// CRITICAL-1 fix:single canonical confidence formula
    /// for TraceAnnotator-derived signals。
    ///
    /// Pre-fix: ch 1002 `emit(...)` and ch 1006
    /// `BASAgentObservationAuditEmitter.observationFromAnnotator(...)`
    /// each computed `min(1.0, 0.5 + Double(agentSet.count) * 0.1)`
    /// independently — EXACT same divergence-risk pattern as
    /// the ch 1000.5 Round-19 ANE-consult 4-way duplication。
    /// A future arc tuning the formula in one place silently
    /// desynced the two projections of the "same signal"。
    ///
    /// Post-fix: ONE place computes the formula。 Both call
    /// sites delegate。 Future tuning changes ONE line。
    ///
    /// Formula: starts at 0.5,adds 0.1 per distinct emitting
    /// agent,clamps at 1.0。 Encodes the intuition that more
    /// agents observed → higher confidence the turn was
    /// substantively active。
    @inlinable
    public static func confidenceForAgentSet(
        count: Int
    ) -> Double {
        min(1.0, 0.5 + (Double(count) * 0.1))
    }

    /// chapter 一千零十.6 / M3765 — Round-21 HIGH-4 fix:
    /// canonical「distinct agent set」 extraction from a list
    /// of deltas。 Was duplicated inline at ch 1002 + ch 1006。
    /// Future change to the agent-set semantics (e.g. excluding
    /// system agents) now updates ONE place。
    @inlinable
    public static func distinctAgentSet(
        from deltas: [BASAgentDelta]
    ) -> Set<String> {
        Set(deltas.map { $0.agentID })
    }

    /// Pure function:read input + emit one `.annotate` delta。
    /// Returns empty array when input has no emitted deltas to
    /// annotate (annotating empty turns is wasted state-graph
    /// space; future hosts that want "audit even empty turns" can
    /// pass a synthetic delta and the seat will annotate that)。
    ///
    /// - Parameters:
    ///   - input: per-turn delta summary
    ///   - agentSpec: TraceAnnotator's registry spec (must include
    ///     `.traceAnnotation` in `writeDomains`)
    ///   - seq: per-turn delta sequence counter (inout — bumped
    ///     by each emitted delta; expect to bump by 0 or 1)
    ///   - nowNanos: ch 956.5 gap #5 recency tie-break timestamp
    /// - Returns: `[BASAgentDelta]` of length 0 or 1
    public static func emit(
        from input: BASTraceAnnotatorInput,
        agentSpec: BASAgentSpec,
        seq: inout Int,
        nowNanos: Int64 = 0
    ) -> [BASAgentDelta] {
        guard !input.isEmpty else { return [] }
        seq += 1
        let payload = encodeAnnotationPayload(
            from: input.emittedDeltas)
        let totalEmits = input.emittedDeltas.count
        // ch 1010.6 HIGH-4: delegate to canonical helper
        let agentSet = Self.distinctAgentSet(
            from: input.emittedDeltas)
        // ch 1010.5 CRITICAL-1: delegate to single canonical
        // formula instead of inline duplication
        let conf = Self.confidenceForAgentSet(
            count: agentSet.count)
        return [BASAgentDelta(
            deltaID:
                "delta.\(input.turnID).trace.\(seq)",
            agentID: agentSpec.agentID,
            targetObjectRef:
                "traceAnnotation#turn-\(input.turnID)",
            deltaType: .annotate,
            patchJson: payload,
            confidence: conf,
            createdAtNanos: nowNanos,
            reasonCodes: [
                "trace.summary",
                "evidence.delta-count=\(totalEmits)",
                "evidence.agent-count=\(agentSet.count)",
            ])]
    }

    // MARK: - Payload encoder (deterministic minimal JSON)

    /// Build a deterministic JSON shape from the emitted-deltas
    /// list。 Sorted by agentID for byte-equal output across runs。
    ///
    /// Shape (example):
    /// ```json
    /// {
    ///   "total":3,
    ///   "per_agent":[
    ///     {"agent":"critic","count":1},
    ///     {"agent":"planner","count":1},
    ///     {"agent":"surface","count":1}
    ///   ],
    ///   "delta_types":["add","merge","replace"]
    /// }
    /// ```
    private static func encodeAnnotationPayload(
        from deltas: [BASAgentDelta]
    ) -> String {
        // Per-agent count (sorted by agentID)
        var counts: [String: Int] = [:]
        var typeSet: Set<String> = []
        for d in deltas {
            counts[d.agentID, default: 0] += 1
            typeSet.insert(d.deltaType.rawValue)
        }
        let sortedAgents = counts.keys.sorted()
        var parts: [String] = []
        parts.append("\"total\":\(deltas.count)")
        parts.append(",\"per_agent\":[")
        let perAgent = sortedAgents.map { agent -> String in
            let c = counts[agent] ?? 0
            return "{\"agent\":\"\(agent.escapeForJSON())\"," +
                "\"count\":\(c)}"
        }
        parts.append(perAgent.joined(separator: ","))
        parts.append("]")
        parts.append(",\"delta_types\":[")
        let sortedTypes = typeSet.sorted()
        parts.append(sortedTypes.map {
            "\"\($0.escapeForJSON())\""
        }.joined(separator: ","))
        parts.append("]")
        return "{\(parts.joined())}"
    }
}

// MARK: - JSON escape helper (private to this file)

private extension String {
    /// Mirrors ch 957 Scout seat doctrine — delegates to shared
    /// `BASAgentFabricJSONEscape` for byte-equal output。
    func escapeForJSON() -> String {
        BASAgentFabricJSONEscape.escape(self)
    }
}
