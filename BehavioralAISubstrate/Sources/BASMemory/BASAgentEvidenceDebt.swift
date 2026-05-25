// MARK: - BASAgentEvidenceDebt
// chapter 九百六十二 / M3515 — Phase 2 close:cross-agent evidence-debt
//
// Per the plan Phase 2 ch3 goal:"cross-agent evidence-debt
// tracking — Planner reads from Memory's `.memoryBundle` + Critic's
// `.critiqueField` when re-proposing"。
//
// "Evidence debt" is the per-turn audit summary capturing what
// Memory + Critic surfaced + how the NEXT turn's Planner should
// weight these signals。 Conceptually:Memory says "we recalled
// arc-X" and Critic says "candidate-Y has severe concern" — those
// observations CARRY FORWARD as audit-trail debt the next turn
// must consider before re-proposing similar candidates。
//
// ## Why a separate struct vs reading deltas directly
//
// The dispatcher already emits Memory + Critic deltas as part of
// `BASAgentTurnResult.emittedDeltas`。 Callers COULD scan that list
// to extract memory + critique info,but:
//   1. Repeated scans bloat per-turn CPU (linear walk over 6+
//      deltas every time a consumer wants critique data)
//   2. Critique scoring is semantic logic — better encapsulated
//      once than inlined in every consumer
//   3. The summary IS the cross-turn contract — next-turn Planner
//      treats this struct as the input,not raw deltas
//
// Per ch 956.6 measurement-first discipline:single-pass derivation
// during dispatch is O(seats) not O(turns × consumers)。
//
// ## What this enables
//
// A future ch 963+ Planner-v2 can read `evidenceDebt` from prior
// turn's `BASAgentTurnResult` + use it to:
//   - Downweight candidates whose prior critique severity was
//     strong+ (Planner increases base confidence floor)
//   - Skip re-proposing candidates with memory-conflict-cluster
//     overlap (Planner avoids known-rejected paths)
//   - Surface aggregate critique pressure as a router signal
//     (high pressure → activate sovereign sentinel proactively)

import Foundation

/// Per-turn summary of Memory + Critic signals。 Computed by the
/// dispatcher from the emitted deltas;returned as part of
/// `BASAgentTurnResult` for next-turn consumption。
public struct BASAgentEvidenceDebt:
    Sendable, Equatable, Hashable, Codable
{
    /// Episode arcs the Memory seat surfaced (recall context)。
    /// Sorted for determinism。
    public let memoryEpisodeArcs: [String]

    /// Conflict-cluster IDs Memory surfaced (caution signal —
    /// Planner-next should be aware of these patterns)。
    public let memoryConflictClusters: [String]

    /// Continuity-anchor IDs Memory surfaced (long-running
    /// threads still active)。
    public let memoryContinuityAnchors: [String]

    /// Per-candidate critique severity from Critic。 Map is keyed
    /// by `candidateID` — candidates with `.none` severity DO NOT
    /// appear (Critic doesn't emit a delta for them)。
    public let critiqueByCandidateID:
        [String: BASCriticConcernSeverity]

    /// Aggregate critique pressure ∈ [0.0, 1.0]。 Defined as:
    ///   (# candidates with critique severity ≥ strong) /
    ///   max(1, total candidates Critic was given)
    /// If Critic emitted no deltas (no concerning candidates),
    /// pressure is 0.0。
    public let aggregateCritiquePressure: Double

    /// Total `.memoryBundle` deltas emitted this turn。
    public let memoryDeltaCount: Int

    /// Total `.critiqueField` deltas emitted this turn。
    public let criticDeltaCount: Int

    public init(
        memoryEpisodeArcs: [String] = [],
        memoryConflictClusters: [String] = [],
        memoryContinuityAnchors: [String] = [],
        critiqueByCandidateID:
            [String: BASCriticConcernSeverity] = [:],
        aggregateCritiquePressure: Double = 0.0,
        memoryDeltaCount: Int = 0,
        criticDeltaCount: Int = 0
    ) {
        self.memoryEpisodeArcs = memoryEpisodeArcs
        self.memoryConflictClusters = memoryConflictClusters
        self.memoryContinuityAnchors = memoryContinuityAnchors
        self.critiqueByCandidateID = critiqueByCandidateID
        self.aggregateCritiquePressure =
            aggregateCritiquePressure
        self.memoryDeltaCount = memoryDeltaCount
        self.criticDeltaCount = criticDeltaCount
    }

    /// The empty / no-evidence default。 Returned when neither
    /// Memory nor Critic emitted any deltas this turn (which is
    /// also the case for 4-seat callers that don't wire those
    /// seats)。
    public static let empty = BASAgentEvidenceDebt()

    // MARK: - Derivation (pure function)

    /// Derive an evidence-debt summary from a turn's emitted
    /// deltas + the inputs that fed Memory + Critic。 Pure。
    ///
    /// - Parameters:
    ///   - emitted: ALL deltas emitted this turn (only Memory
    ///     + Critic ones are inspected;others ignored)
    ///   - memoryInput: the BASMemorySeatInput passed to dispatch
    ///     (used to read the per-cluster ID lists directly,since
    ///     Memory's delta payload JSON doesn't expose them)
    ///   - criticInput: the BASCriticSeatInput passed to dispatch
    ///     (used to compute aggregateCritiquePressure denominator
    ///     — total candidate count regardless of whether each got
    ///     a delta)
    /// - Returns: aggregated evidence-debt summary
    public static func derive(
        emitted: [BASAgentDelta],
        memoryInput: BASMemorySeatInput?,
        criticInput: BASCriticSeatInput?
    ) -> BASAgentEvidenceDebt {
        // Pull memory IDs directly from input (more accurate +
        // cheaper than parsing payload JSON)
        let memArcs =
            memoryInput?.episodeArcs.sorted() ?? []
        let memConflicts =
            memoryInput?.conflictClusters.sorted() ?? []
        let memAnchors =
            memoryInput?.continuityAnchors.sorted() ?? []
        // Count Memory + Critic deltas (filter by targetObjectRef
        // prefix — the seats use stable ref namespace per ch 961)
        var memoryCount = 0
        var criticCount = 0
        var critiqueMap:
            [String: BASCriticConcernSeverity] = [:]
        for d in emitted {
            if d.targetObjectRef.hasPrefix("memoryBundle#") {
                memoryCount += 1
            } else if d.targetObjectRef
                .hasPrefix("critiqueField#")
            {
                criticCount += 1
                // Extract candidateID from ref
                // Format: "critiqueField#cf-<turnID>-<candID>"
                if let candID = extractCandidateID(
                    fromCritiqueRef: d.targetObjectRef)
                {
                    // Decode severity from payload JSON
                    let sev = extractSeverity(
                        fromPayload: d.patchJson)
                    critiqueMap[candID] = sev
                }
            }
        }
        // Aggregate pressure:strong+ candidates / total candidates
        let totalCandidates = criticInput?.candidates.count ?? 0
        let strongPlusCount = critiqueMap.values.filter {
            $0 == .strong || $0 == .severe
        }.count
        let pressure: Double
        if totalCandidates > 0 {
            pressure = Double(strongPlusCount) /
                Double(totalCandidates)
        } else {
            pressure = 0.0
        }
        return BASAgentEvidenceDebt(
            memoryEpisodeArcs: memArcs,
            memoryConflictClusters: memConflicts,
            memoryContinuityAnchors: memAnchors,
            critiqueByCandidateID: critiqueMap,
            aggregateCritiquePressure: pressure,
            memoryDeltaCount: memoryCount,
            criticDeltaCount: criticCount)
    }

    // MARK: - Helpers

    /// Parse `candidateID` out of `"critiqueField#cf-<turnID>-<candID>"`。
    /// Returns nil if the ref doesn't match the expected shape。
    private static func extractCandidateID(
        fromCritiqueRef ref: String
    ) -> String? {
        // Strip "critiqueField#cf-" prefix
        let prefix = "critiqueField#cf-"
        guard ref.hasPrefix(prefix) else { return nil }
        let after = String(ref.dropFirst(prefix.count))
        // After is "<turnID>-<candID>" — turnID is single dash-free
        // token in our seat impl,but candID itself may contain
        // dashes。 Heuristic:split on FIRST dash from left,take
        // everything after as candID。
        guard let dash = after.firstIndex(of: "-")
        else { return nil }
        let candID = String(after[
            after.index(after: dash)...])
        return candID.isEmpty ? nil : candID
    }

    /// Extract severity from a critic-payload JSON。 Looks for
    /// `"severity":"<name>"` substring (cheap, robust to
    /// other JSON fields)。 Returns `.none` on parse failure。
    private static func extractSeverity(
        fromPayload payload: String
    ) -> BASCriticConcernSeverity {
        let key = "\"severity\":\""
        guard let kRange = payload.range(of: key) else {
            return .none
        }
        let after = payload[kRange.upperBound...]
        guard let closeQuote = after.firstIndex(of: "\"")
        else { return .none }
        let sevStr = String(after[..<closeQuote])
        return BASCriticConcernSeverity(rawValue: sevStr)
            ?? .none
    }
}
