// MARK: - BASAgentObservation
// chapter 九百五十三 / M3470 (Phase 0 / ch1)
//
// User design Section 7.3:
//
//   AgentObservation
//   - observation_id
//   - agent_id
//   - source_refs[]
//   - observed_domain
//   - summary
//   - confidence
//   - flags[]
//
// Observation is what an agent SEES in the shared state graph (Phase 0
// ch 954) — typed read result with provenance refs back to the source
// state objects + confidence + flags。
//
// Distinct from `BASAgentDelta` (a proposed change) and `BASAgentProposal`
// (a structured request)。 Observation is pure read-output。 Watcher
// agents emit observations,not deltas。

import Foundation

public struct BASAgentObservation:
    Sendable, Equatable, Hashable, Codable
{
    /// Stable unique observation identifier。 Format suggestion:
    /// `obs.<turnID>.<agentID>.<seq>`。
    public let observationID: String

    /// The agent that produced this observation。
    public let agentID: String

    /// References back to the source state objects this observation
    /// summarized。 Format: `<domain>#<objectID>` per user's Section
    /// 13.5 zero-copy state bus convention。 Empty = derived observation
    /// (computed from prior observations,not a state read)。
    public let sourceRefs: [String]

    /// Which state domain this observation pertains to。
    public let observedDomain: BASStateDomain

    /// Short prose summary of what was observed。 Bounded 1024 chars
    /// at the caller side (not enforced here — keeps schema permissive
    /// for fuzz testing edge cases)。
    public let summary: String

    /// Confidence in this observation ∈ [0.0, 1.0]。 Drives merge engine
    /// conflict resolution (Phase 0 ch 955) — higher confidence
    /// observations win evidence-tier conflicts。
    public let confidence: Double

    /// Tag strings — e.g. "anomaly", "memory-pollution", "host-drift",
    /// "axis-deviation"。 Watcher agents emit observations primarily
    /// for the flags (not the summary)。 Empty = clean observation。
    public let flags: [String]

    public init(
        observationID: String,
        agentID: String,
        sourceRefs: [String] = [],
        observedDomain: BASStateDomain,
        summary: String,
        confidence: Double,
        flags: [String] = []
    ) {
        self.observationID = observationID
        self.agentID = agentID
        self.sourceRefs = sourceRefs
        self.observedDomain = observedDomain
        self.summary = summary
        self.confidence = confidence
        self.flags = flags
    }
}
