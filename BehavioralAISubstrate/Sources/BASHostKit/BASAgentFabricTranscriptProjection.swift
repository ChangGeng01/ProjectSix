// MARK: - BASAgentFabricTranscriptProjection
// chapter 一千零九 / M3750 — wires `Gate.TranscriptMode` from
// 🪜 SCAFFOLD → ✅ WIRED (per-agent summary projection)
//
// ## The scaffold condition
//
// Per `Docs/SCAFFOLD_VS_WIRED.md` ch 996:
//   > `BASAgentFabricGate.TranscriptMode.singleAgent` /
//   > `.compareAll` / `.compareSelected` | 🪜 SCAFFOLD | same
//   > as Tier — parsed,surfaced,not branched on substrate-side
//
// Full multi-chapter wire (per-agent transcript output paths
// with new `BASRenderFrame` variants) is genuinely Phase 9+
// scope。 But a SMALLER honest wire is achievable today:
// **per-agent activity summary projection**。 The substrate
// can already enumerate which agents emitted deltas in a turn
// (the ch 1002 TraceAnnotator does exactly this)。 Surfacing
// THAT as a typed per-agent summary IN the result bundle —
// gated by `transcriptMode` — is a real behavioral output
// difference between modes。
//
// ## What ch 1009 ships
//
// 1. `BASAgentFabricTranscriptSummary` value-struct DTO
//    carrying:
//    - per-agent delta counts
//    - per-agent delta-type sets
//    - total emit count
//    - source mode flag (echo of TranscriptMode used)
// 2. `BASAgentFabricTranscriptProjection.summarize(...)` —
//    pure-fn that builds a `BASAgentFabricTranscriptSummary`
//    from `(deltas: [BASAgentDelta],
//    mode: BASAgentFabricGate.TranscriptMode,
//    selectedAgents: [String])`。
//    - `.singleAgent` → returns nil (back-compat byte-equal
//      with pre-ch-1009 output)
//    - `.compareAll` → returns summary covering every agent
//    - `.compareSelected` → returns summary scoped to
//      selectedAgents (typically from `BAS_ACTIVE_AGENTS`)
//
// ## Why this is a real wire
//
// The output now DIFFERS by mode:
//   - `.singleAgent` produces nil summary (byte-equal old
//     behavior preserved per ADR-014 OPT-IN)
//   - Compare modes produce a populated typed summary that
//     hosts can render as per-agent transcripts
//
// This is a substantive behavioral wire — substrate's output
// shape genuinely varies by mode flag。 The substrate doesn't
// invent NEW BASRenderFrame variants (that's the future
// Phase 9+ work) but it DOES emit a typed summary that hosts
// can transform into render frames downstream。
//
// ## Discipline
//
// - Additive only — new DTO + new pure-fn
// - Deterministic — sorted output for byte-equal across runs
// - Backward compat — `.singleAgent` returns nil so existing
//   call sites produce identical results to pre-ch-1009

import Foundation
import BASMemory

/// Per-agent activity summary populated when host requests a
/// compare-mode transcript view。 Substrate produces this
/// summary;host transforms it into render frames downstream。
public struct BASAgentFabricTranscriptSummary:
    Sendable, Equatable, Hashable, Codable
{
    /// Per-agent entry — captures agentID + total delta count
    /// emitted by that agent + sorted delta-type rawValue set。
    public struct AgentEntry:
        Sendable, Equatable, Hashable, Codable
    {
        public let agentID: String
        public let deltaCount: Int
        /// Sorted delta-type rawValue list — e.g.
        /// `["add", "merge"]`。 Sorted for byte-equal output。
        public let deltaTypes: [String]

        public init(
            agentID: String,
            deltaCount: Int,
            deltaTypes: [String]
        ) {
            self.agentID = agentID
            self.deltaCount = deltaCount
            self.deltaTypes = deltaTypes
        }
    }

    /// Echo of the TranscriptMode rawValue used to build this
    /// summary — host can verify the mode actually applied。
    public let modeRawValue: String
    /// Sorted per-agent entries (sorted by agentID for byte-
    /// equal output)。
    public let perAgent: [AgentEntry]
    /// Total deltas across all included agents。
    public let totalDeltas: Int
    /// When mode == .compareSelected,the original
    /// selectedAgents list (lowercased + sorted)。 Empty for
    /// other modes。
    public let selectedAgents: [String]

    public init(
        modeRawValue: String,
        perAgent: [AgentEntry],
        totalDeltas: Int,
        selectedAgents: [String]
    ) {
        self.modeRawValue = modeRawValue
        self.perAgent = perAgent
        self.totalDeltas = totalDeltas
        self.selectedAgents = selectedAgents
    }
}

public enum BASAgentFabricTranscriptProjection {

    /// Build a per-agent transcript summary from the deltas
    /// emitted in this turn。 Pure-fn — same inputs always
    /// produce byte-equal output。
    ///
    /// - Parameters:
    ///   - deltas: ALL deltas emitted in the turn (any agent,
    ///     any domain)
    ///   - mode: TranscriptMode from `BASAgentFabricGate
    ///     .Activation.transcriptMode`
    ///   - selectedAgents: relevant only for
    ///     `.compareSelected` — lowercase the list before
    ///     passing (or this fn lowercases internally)
    /// - Returns: `nil` when `mode == .singleAgent` (byte-equal
    ///   pre-ch-1009 output);populated summary otherwise
    public static func summarize(
        deltas: [BASAgentDelta],
        mode: BASAgentFabricGate.TranscriptMode,
        selectedAgents: [String] = []
    ) -> BASAgentFabricTranscriptSummary? {
        switch mode {
        case .singleAgent:
            // Back-compat: no summary in single-agent mode
            return nil
        case .compareAll:
            return buildSummary(
                deltas: deltas,
                mode: mode,
                scopeFilter: nil)
        case .compareSelected:
            // Filter deltas to only those from selectedAgents
            let scope = Set(selectedAgents.map {
                $0.lowercased()
            })
            return buildSummary(
                deltas: deltas,
                mode: mode,
                scopeFilter: scope)
        }
    }

    private static func buildSummary(
        deltas: [BASAgentDelta],
        mode: BASAgentFabricGate.TranscriptMode,
        scopeFilter: Set<String>?
    ) -> BASAgentFabricTranscriptSummary {
        var counts: [String: Int] = [:]
        var typeSets: [String: Set<String>] = [:]
        for d in deltas {
            if let scope = scopeFilter {
                if !scope.contains(d.agentID.lowercased()) {
                    continue
                }
            }
            counts[d.agentID, default: 0] += 1
            typeSets[d.agentID, default: []]
                .insert(d.deltaType.rawValue)
        }
        let entries = counts.keys.sorted().map { agentID in
            BASAgentFabricTranscriptSummary.AgentEntry(
                agentID: agentID,
                deltaCount: counts[agentID] ?? 0,
                deltaTypes: (typeSets[agentID] ?? [])
                    .sorted())
        }
        let total = entries.reduce(0) { $0 + $1.deltaCount }
        let selected: [String]
        switch mode {
        case .compareSelected:
            selected = (scopeFilter.map { Array($0) } ?? [])
                .sorted()
        default:
            selected = []
        }
        return BASAgentFabricTranscriptSummary(
            modeRawValue: mode.rawValue,
            perAgent: entries,
            totalDeltas: total,
            selectedAgents: selected)
    }
}
