// MARK: - BASMemorySeat
// chapter 九百六十一 / M3510 — Phase 2 ch2:Memory seat wrapper
//
// User design Section 9.3-9.5:Memory is a CORE agent (HIGH
// visibility for tone — actual storage decisions are sealed-LOW
// per memorySeal)。 Per Single-Writer-Per-Domain (ch 956.5
// USER-PASS gap #1) Memory is the SOLE writer for `.memoryBundle`。
//
// Per the Single-Writer table from ch 953 commentary,Memory
// wraps `memoryService` (L8) and emits structured memory
// references as deltas keyed by:
//   - EpisodeArc — recalled episode trajectories
//   - ConflictCluster — detected contradiction clusters from
//     prior turns
//   - ContinuityAnchor — long-term continuity references
//
// Future fabric-authoritative mode will let Planner read these
// to weight candidates against historical context (e.g.
// "user previously rejected similar proposal at episode-arc X")。
//
// ## DTO not Type
//
// Per same module-dep rationale as Scout/Planner,Memory takes
// `BASMemorySeatInput` slim DTO rather than direct `BASMemoryBundle`
// from BASOrchestration。 Coordinator adapter (`BASAgentFabricAdapters`)
// builds the DTO from the live L8 service output。

import Foundation

/// Slim DTO carrying the recall + continuity signals the Memory
/// seat surfaces。 Built by the coordinator adapter from L8
/// memoryService output。
public struct BASMemorySeatInput:
    Sendable, Equatable, Hashable, Codable
{
    /// Recalled episode arc IDs (sorted by caller or here)。
    /// Each ID maps to a prior turn's narrative arc。
    public let episodeArcs: [String]
    /// Detected conflict-cluster IDs from prior turns。
    /// Sorted ID list — Memory does not analyze conflicts here,
    /// just surfaces them as evidence。
    public let conflictClusters: [String]
    /// Continuity-anchor IDs the recall pipeline surfaced as
    /// relevant to this turn (long-running threads,promises
    /// made,etc.)。
    public let continuityAnchors: [String]
    /// Overall recall strength ∈ [0.0, 1.0] — Memory's confidence
    /// in this turn's recall quality (e.g. semantic-similarity
    /// score)。 Drives the delta confidence。
    public let recallStrength: Double

    public init(
        episodeArcs: [String] = [],
        conflictClusters: [String] = [],
        continuityAnchors: [String] = [],
        recallStrength: Double = 0.0
    ) {
        self.episodeArcs = episodeArcs
        self.conflictClusters = conflictClusters
        self.continuityAnchors = continuityAnchors
        self.recallStrength = recallStrength
    }

    /// True when no recall surface is present — Memory will
    /// emit zero deltas。
    public var isEmpty: Bool {
        episodeArcs.isEmpty &&
        conflictClusters.isEmpty &&
        continuityAnchors.isEmpty
    }
}

public enum BASMemorySeat {

    /// Pure-function:emit one delta per cluster type that has
    /// non-empty content。 Caller MUST pass `agentSpec.writeDomains`
    /// containing `.memoryBundle` (apply step enforces)。
    ///
    /// Emission shape:
    ///   - 1 delta for episodes (if non-empty) → `memoryBundle#episodes-<turnID>`
    ///   - 1 delta for conflicts (if non-empty) → `memoryBundle#conflicts-<turnID>`
    ///   - 1 delta for anchors (if non-empty) → `memoryBundle#anchors-<turnID>`
    /// Confidence scales with `recallStrength` and per-cluster
    /// item count;capped at 1.0。
    public static func emit(
        from input: BASMemorySeatInput,
        turnID: String,
        agentSpec: BASAgentSpec,
        seq: inout Int,
        nowNanos: Int64 = 0
    ) -> [BASAgentDelta] {
        var out: [BASAgentDelta] = []
        // Cluster 1: episode arcs (recall continuation)
        if !input.episodeArcs.isEmpty {
            seq += 1
            let conf = clampConfidence(
                input.recallStrength
                + 0.05 * Double(input.episodeArcs.count))
            out.append(BASAgentDelta(
                deltaID: "delta.\(turnID).memory.\(seq)",
                agentID: agentSpec.agentID,
                targetObjectRef:
                    "memoryBundle#episodes-\(turnID)",
                deltaType: .merge,
                patchJson: encodeIDListPayload(
                    label: "episode_arcs",
                    ids: input.episodeArcs),
                confidence: conf,
                createdAtNanos: nowNanos,
                reasonCodes: [
                    "memory.episodes",
                    "evidence.count=\(input.episodeArcs.count)",
                ]))
        }
        // Cluster 2: conflict clusters (continuity risk signal)
        if !input.conflictClusters.isEmpty {
            seq += 1
            let conf = clampConfidence(
                input.recallStrength
                + 0.1 * Double(input.conflictClusters.count))
            out.append(BASAgentDelta(
                deltaID: "delta.\(turnID).memory.\(seq)",
                agentID: agentSpec.agentID,
                targetObjectRef:
                    "memoryBundle#conflicts-\(turnID)",
                deltaType: .merge,
                patchJson: encodeIDListPayload(
                    label: "conflict_clusters",
                    ids: input.conflictClusters),
                confidence: conf,
                createdAtNanos: nowNanos,
                reasonCodes: [
                    "memory.conflicts",
                    "evidence.count=" +
                        "\(input.conflictClusters.count)",
                ]))
        }
        // Cluster 3: continuity anchors (long-term threads)
        if !input.continuityAnchors.isEmpty {
            seq += 1
            let conf = clampConfidence(
                input.recallStrength
                + 0.03 * Double(input.continuityAnchors.count))
            out.append(BASAgentDelta(
                deltaID: "delta.\(turnID).memory.\(seq)",
                agentID: agentSpec.agentID,
                targetObjectRef:
                    "memoryBundle#anchors-\(turnID)",
                deltaType: .merge,
                patchJson: encodeIDListPayload(
                    label: "continuity_anchors",
                    ids: input.continuityAnchors),
                confidence: conf,
                createdAtNanos: nowNanos,
                reasonCodes: [
                    "memory.anchors",
                    "evidence.count=" +
                        "\(input.continuityAnchors.count)",
                ]))
        }
        return out
    }

    // MARK: - Helpers

    private static func clampConfidence(
        _ v: Double
    ) -> Double {
        max(0.0, min(1.0, v))
    }

    /// Deterministic JSON encoder for ID-list payloads。 Sorts the
    /// IDs before emitting so byte-equal payloads come out for
    /// byte-equal inputs (ch 956.5 strong-mergeID hash invariance)。
    private static func encodeIDListPayload(
        label: String,
        ids: [String]
    ) -> String {
        let sorted = ids.sorted()
        let listJoined = sorted.map {
            "\"\($0.escapeForJSONMS())\""
        }.joined(separator: ",")
        return "{\"\(label)\":[\(listJoined)]," +
            "\"count\":\(sorted.count)}"
    }
}

// MARK: - JSON escape helper (file-scope per ch 957/958/959 pattern)

private extension String {
    /// Minimal JSON-string escape。 Name disambiguated from other
    /// seat helpers (escapeForJSON / eForJ) by suffix `MS`
    /// (memory-seat) — Swift can't disambiguate two file-private
    /// extensions with the same name in the same module。
    func escapeForJSONMS() -> String {
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
