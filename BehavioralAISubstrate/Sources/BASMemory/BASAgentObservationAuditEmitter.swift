// MARK: - BASAgentObservationAuditEmitter
// chapter 一千零六 / M3735 — wires `BASAgentObservation` from
// 🪜 SCAFFOLD (mislabeled — was actually 💀 DEAD) → ✅ WIRED
//
// ## The mislabeled-DEAD condition
//
// `Docs/SCAFFOLD_VS_WIRED.md` ch 996 inventory listed
// `BASAgentObservation` as「🪜 SCAFFOLD — watcher hint surface;
// substrate doesn't branch but L14 audit reads」。 But grep
// proves NO substrate consumer reads `BASAgentObservation`
// anywhere outside the type's own definition file and ch 953's
// schema property test:
//
//   grep -rn "BASAgentObservation" Sources/
//     → only BASAgentObservation.swift declares it
//   grep -rn "BASAgentObservation" Tests/
//     → only BASChapter953 instantiates it for schema testing
//
// Per the ch 996 taxonomy this is 💀 DEAD (no emitter + no
// reader),NOT 🪜 SCAFFOLD (which requires AT LEAST a surface
// reader)。 The ch 996 doctrine entry was inaccurate。
//
// ## What ch 1006 ships
//
// 1. `BASAgentObservationAuditEmitter.signalRefs(from:)` — pure
//    function that serializes a list of `BASAgentObservation`s
//    into sorted `observation.*` prefixed signalRef strings,
//    ready for inclusion in a `BASSovereignAuditEntry.signalRefs`
//    field。 Deterministic byte-equal output for same input。
// 2. `BASAgentObservationAuditEmitter.observationFromAnnotator(
//    input:agentSpec:)` — pure function that builds ONE
//    BASAgentObservation summarizing what a TraceAnnotator
//    would emit for the same input。 Companion to the ch 1002
//    `.annotate` delta — the observation captures the SAME data
//    in the observation schema instead of delta schema。
// 3. Pin test verifying that the emitted observation +
//    serialized signalRefs roundtrip through the audit ledger
//    without loss。
//
// ## Why this is the right closure scope
//
// Hosts adopting per-turn agent-fabric audit get a canonical
// way to consume observations:
//   - TraceAnnotator (ch 1002) emits the `.annotate` delta as
//     the state-graph projection
//   - This emitter produces the OBSERVATION-schema projection
//     of the SAME signal,which lands in the L14 audit ledger
//     via signalRefs (no schema change)
//
// Future arcs may extend more seats to ALSO emit observations
// (per ch 953 design Section 7.3 each agent CAN emit
// observations alongside deltas)。 This chapter is the canonical
// reference for that wire pattern。
//
// ## Discipline
//
// - Additive only — no existing seat / API changes
// - Pure functions (no I/O,deterministic byte-equal)
// - Reuse hardened canonical-bytes format via the existing
//   `BASSovereignAuditEntry` schemaVersion 1.1.0 path

import Foundation

public enum BASAgentObservationAuditEmitter {

    /// Build a deterministic ordered list of signalRef strings
    /// from a list of `BASAgentObservation`s。 Each ref encodes
    /// observationID + agentID + observedDomain + flags + a
    /// confidence band so audit-ledger replay can reconstruct
    /// the observation set without round-tripping the full
    /// observation payload。
    ///
    /// Format per entry:
    ///   `observation.<observationID>:agent=<agentID>:domain=<domain>:flags=<sorted,comma>:conf=<band>`
    ///
    /// Confidence band:`low` (<0.4) / `med` (<0.7) / `high` (>=0.7)
    /// — keeps the ref length bounded across fuzz inputs while
    /// preserving enough signal for audit triage。
    ///
    /// Output is sorted by `observationID` for byte-equal
    /// determinism。
    public static func signalRefs(
        from observations: [BASAgentObservation]
    ) -> [String] {
        let sorted = observations.sorted {
            $0.observationID < $1.observationID
        }
        return sorted.map { obs in
            let band = confidenceBand(obs.confidence)
            let flagsStr = obs.flags.sorted()
                .joined(separator: ",")
            return "observation.\(obs.observationID)" +
                ":agent=\(obs.agentID)" +
                ":domain=\(obs.observedDomain.rawValue)" +
                ":flags=\(flagsStr)" +
                ":conf=\(band)"
        }
    }

    /// Build ONE BASAgentObservation summarizing what a
    /// TraceAnnotator emits for the same input。 Companion to
    /// the ch 1002 `BASTraceAnnotatorSeat.emit` — the
    /// observation captures the same provenance signal but in
    /// the observation schema (per-domain summary) instead of
    /// the delta schema (proposed state change)。
    ///
    /// - Parameters:
    ///   - input: TraceAnnotator input (same DTO ch 1002 seat
    ///     accepts)
    ///   - agentSpec: TraceAnnotator's registry spec
    ///   - seq: per-turn observation seq counter (inout)
    /// - Returns: empty array on empty input;single-element
    ///   array otherwise (mirrors ch 1002 emit's zero-or-one
    ///   shape)
    public static func observationFromAnnotator(
        input: BASTraceAnnotatorInput,
        agentSpec: BASAgentSpec,
        seq: inout Int
    ) -> [BASAgentObservation] {
        guard !input.isEmpty else { return [] }
        seq += 1
        let totalEmits = input.emittedDeltas.count
        let agentSet = Set(input.emittedDeltas.map { $0.agentID })
        let conf = min(
            1.0, 0.5 + (Double(agentSet.count) * 0.1))
        let flags: [String] = [
            "trace-summary",
            "agent-count=\(agentSet.count)",
            "delta-count=\(totalEmits)",
        ]
        let summary =
            "TraceAnnotator observed \(totalEmits) deltas " +
            "from \(agentSet.count) agents in turn " +
            "\(input.turnID)"
        // Source refs:include refs back to each emitted delta
        // so audit replay can reconstruct the originating turn
        let sourceRefs = input.emittedDeltas
            .map { "delta#\($0.deltaID)" }
            .sorted()
        return [BASAgentObservation(
            observationID:
                "obs.\(input.turnID).trace.\(seq)",
            agentID: agentSpec.agentID,
            sourceRefs: sourceRefs,
            observedDomain: .traceAnnotation,
            summary: summary,
            confidence: conf,
            flags: flags)]
    }

    // MARK: - Internal

    private static func confidenceBand(
        _ conf: Double
    ) -> String {
        if conf < 0.4 { return "low" }
        if conf < 0.7 { return "med" }
        return "high"
    }
}
