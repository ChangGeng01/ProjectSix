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
    /// Format per entry (chapter 一千零十.5 / M3760 — Round-20
    /// CRITICAL-2 fix:adopts the U+001F unit-separator + U+001E
    /// record-separator discipline ch 982.5 already standardized
    /// for warrant refs。 Pre-fix `:` + `=` + `,` separators
    /// were vulnerable to injection — observationID,agentID,or
    /// flags containing those characters silently corrupted the
    /// replay parser。 Post-fix the U+001F sentinels are illegal
    /// in normal text so collisions cannot happen):
    ///
    ///   `observation.<id>\u{001F}agent=<agentID>\u{001F}domain=<domain>\u{001F}flags=<sorted\u{001E}joined>\u{001F}conf=<band>`
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
        let unitSep = "\u{001F}"
        let recordSep = "\u{001E}"
        return sorted.map { obs in
            let band = confidenceBand(obs.confidence)
            // ch 1010.5 CRITICAL-2: U+001E (record separator)
            // for inner-list join — flag values may contain
            // `,` legitimately,but U+001E is illegal in
            // user-supplied text。
            let flagsStr = obs.flags.sorted()
                .joined(separator: recordSep)
            // ch 1010.5 CRITICAL-2: U+001F (unit separator)
            // for inter-field join — observationID / agentID
            // may contain `:` or `=` legitimately,but U+001F
            // is illegal in user-supplied text。
            return "observation.\(obs.observationID)" +
                "\(unitSep)agent=\(obs.agentID)" +
                "\(unitSep)domain=\(obs.observedDomain.rawValue)" +
                "\(unitSep)flags=\(flagsStr)" +
                "\(unitSep)conf=\(band)"
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
        // chapter 一千零十.6 / M3765 — Round-21 HIGH-4 fix:
        // delegate agentSet extraction to ch 1002 canonical
        // helper instead of inline-duplicating。 Same single-
        // canonical doctrine as the Round-20 confidence-formula
        // fix。 Future changes to how「agent set」 is computed
        // (e.g. excluding system agents) now update one place。
        let agentSet = BASTraceAnnotatorSeat
            .distinctAgentSet(from: input.emittedDeltas)
        // ch 1010.5 CRITICAL-1: delegate to single canonical
        // formula instead of inline duplication
        let conf = BASTraceAnnotatorSeat
            .confidenceForAgentSet(count: agentSet.count)
        let flags: [String] = [
            "trace-summary",
            "agent-count=\(agentSet.count)",
            "delta-count=\(totalEmits)",
        ]
        // chapter 一千零十四 / M3785 — Round-21 LOW-1 fix:
        // JSON-escape the turnID interpolation。 Pre-fix
        // turnID containing `"` / `\` / newline would corrupt
        // downstream JSON encoders。 ch 1002 TraceAnnotator
        // already uses `BASAgentFabricJSONEscape` for its
        // payload — ch 1006 now matches that discipline。
        // Same single-canonical doctrine as Round-20 confidence
        // formula。
        let escapedTurnID =
            BASAgentFabricJSONEscape.escape(input.turnID)
        let summary =
            "TraceAnnotator observed \(totalEmits) deltas " +
            "from \(agentSet.count) agents in turn " +
            "\(escapedTurnID)"
        // chapter 一千零十.6 / M3765 — Round-21 CRITICAL-5 fix:
        // `delta#<deltaID>` separator-injection class。 deltaID
        // convention is `delta.<turnID>.<agentID>.<seq>` —
        // contains `.` always,doesn't contain `#` by
        // convention but caller-supplied free-form per
        // BASAgentDelta schema。 Switch to U+001F separator
        // for consistency with signalRefs (line ~85)。 Sorted
        // for byte-equal output。
        let sourceRefs = input.emittedDeltas
            .map { "delta\u{001F}\($0.deltaID)" }
            .sorted()
        // chapter 一千零十四.6 / M3795 — Round-23 CRITICAL-4 fix:
        // JSON-escape turnID for observationID interpolation。
        // The summary field was escaped at ch 1014 LOW-1 fix,
        // but the observationID at the same call site was
        // missed。 Same JSON-corruption attack surface — `"` /
        // `\n` in turnID would corrupt downstream consumers
        // parsing the observationID。
        return [BASAgentObservation(
            observationID:
                "obs.\(escapedTurnID).trace.\(seq)",
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
