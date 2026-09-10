// MARK: - BASAgentWatcher
// chapter 九百七十 / M3555 — Phase 5 ch1:Watcher base protocol
//
// User design Section 9.8 + plan PHASE 5:Watchers are QUIET
// OBSERVERS。 They:
//
//   - HAVE NO writeDomains (read-only by design)
//   - Emit BASAgentWatcherHint records,never BASAgentDelta
//   - Run AFTER seats in the dispatcher (observation pass)
//   - Route to L14 sovereign sentinel via the audit ledger
//     (ch 972 aggregation)
//   - Cannot block or modify turn execution directly
//
// Per plan Phase 5 ch1:LOW risk (pure read-only)。 Per ch
// 956.11 H2:bounded by per-turn input size — no DoS surface。
//
// ## 7 watchers total per plan
//
// Ch 970 (this chapter) ships 3:
//   - Anomaly       — detects unusual turn patterns
//   - MemoryPollution — detects memory-injection attempts
//   - HostDrift     — detects drift from host constitution
//
// Ch 971 ships 2 more (Gaslight + ToolInjection)。
// Ch 972 ships final 2 (AxisDeviation + SanctumLeak) + hint
// aggregation into L14 audit ledger。
//
// ## Severity ladder
//
// Per plan:watchers emit at 4 severity levels。 The dispatcher
// (ch 970 aggregator) routes high-severity hints to L14
// sovereign sentinel for veto consideration。

import Foundation

// MARK: - Severity

public enum BASAgentWatcherSeverity: String,
    Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// Observed pattern,no concern。 Audit-only。
    case info
    /// Worth tracking。 Counter-incremented in audit ledger。
    case watch
    /// Sovereign should know。 Hint surfaces to L14 next cycle。
    case alert
    /// Sovereign-level violation。 Escalate to L14 IMMEDIATELY
    /// (sentinel may emit a turn-level lockdown verdict in
    /// response)。 Used sparingly — only for confirmed sovereign-
    /// boundary violations。
    case veto
}

// MARK: - Hint DTO

/// What a watcher emits per detection。 Slim record carrying
/// enough for audit replay + sovereign routing。 Per ch 956.11
/// CR1 + ch 967 trace-replay discipline:fully deterministic,
/// byte-equal for same input。
public struct BASAgentWatcherHint:
    Sendable, Equatable, Hashable, Codable
{
    public let hintID: String
    public let turnID: String
    public let watcherRole: BASAgentRole
    public let severity: BASAgentWatcherSeverity
    /// Short category code,e.g. "anomaly.candidate-count" /
    /// "memory.episode-conflict" / "hostdrift.tone-shift"。
    /// Used by L14 aggregator to bucket hints。
    public let category: String
    /// Human-readable one-line summary for trace replay。
    public let summary: String
    /// Sorted list of evidence strings — same discipline as
    /// `BASAgentDelta.reasonCodes` (deterministic for byte-equal
    /// trace replay)。
    public let evidence: [String]
    /// 0.0-1.0 — watcher's confidence in the detection。
    public let confidence: Double
    /// Optional candidate ref this hint targets,nil = turn-wide。
    public let candidateRef: String?
    /// Monotonic nanosecond timestamp for ch 956.5 recency。
    public let nowNanos: Int64

    public init(
        hintID: String,
        turnID: String,
        watcherRole: BASAgentRole,
        severity: BASAgentWatcherSeverity,
        category: String,
        summary: String,
        evidence: [String] = [],
        confidence: Double,
        candidateRef: String? = nil,
        nowNanos: Int64 = 0
    ) {
        self.hintID = hintID
        self.turnID = turnID
        self.watcherRole = watcherRole
        self.severity = severity
        self.category = category
        self.summary = summary
        // Sort evidence in init for deterministic round-trip
        self.evidence = evidence.sorted()
        // Clamp confidence per ch 956.11 CR1 fail-safe
        self.confidence = max(0.0, min(1.0, confidence))
        self.candidateRef = candidateRef
        self.nowNanos = nowNanos
    }
}

// MARK: - Watcher observation input

/// Slim DTO bundling the turn-level signals all watchers may
/// inspect。 NOT BASAgentTurnInput directly — watchers only
/// need READ access to the input + emitted-deltas snapshot,
/// not the merge result or apply outcomes (those happen AFTER
/// watcher observation per Phase 5 design)。
///
/// Coordinator adapter (ch 970+ when wired) builds this from
/// the live `BASAgentTurnDispatcher.dispatch` mid-flight。
public struct BASAgentWatcherObservation:
    Sendable, Equatable, Hashable
{
    public let turnID: String
    public let scout: BASScoutInput
    public let plannerCandidates: [BASPlannerCandidate]
    public let risk: BASRiskInput
    public let surface: BASSurfaceInput
    public let memory: BASMemorySeatInput?
    public let critic: BASCriticSeatInput?
    public let hostAlignment: BASHostAlignmentInput?
    public let sovereignSentinel:
        BASSovereignSentinelInput?
    public let evolutionShadow:
        BASEvolutionShadowInput?
    /// Snapshot of deltas emitted by seats this turn (read-only)。
    public let emittedDeltas: [BASAgentDelta]
    public let nowNanos: Int64

    public init(
        turnID: String,
        scout: BASScoutInput = BASScoutInput(),
        plannerCandidates: [BASPlannerCandidate] = [],
        risk: BASRiskInput = BASRiskInput(),
        surface: BASSurfaceInput = BASSurfaceInput(),
        memory: BASMemorySeatInput? = nil,
        critic: BASCriticSeatInput? = nil,
        hostAlignment: BASHostAlignmentInput? = nil,
        sovereignSentinel:
            BASSovereignSentinelInput? = nil,
        evolutionShadow:
            BASEvolutionShadowInput? = nil,
        emittedDeltas: [BASAgentDelta] = [],
        nowNanos: Int64 = 0
    ) {
        self.turnID = turnID
        self.scout = scout
        self.plannerCandidates = plannerCandidates
        self.risk = risk
        self.surface = surface
        self.memory = memory
        self.critic = critic
        self.hostAlignment = hostAlignment
        self.sovereignSentinel = sovereignSentinel
        self.evolutionShadow = evolutionShadow
        self.emittedDeltas = emittedDeltas
        self.nowNanos = nowNanos
    }
}

// MARK: - Watcher protocol

/// All 7 watchers conform to this protocol。 Each is a pure
/// function — no actor,no I/O,no shared state。 Per ch 957-969
/// seat discipline。
public protocol BASAgentWatcher: Sendable {
    /// The role this watcher fills。 Must be one of the 7
    /// watcher roles from `BASAgentRole`。
    static var role: BASAgentRole { get }

    /// Inspect the observation + return any detected hints。
    /// Empty = no concerns found this turn (most common case)。
    /// Caller MUST pass a `seq` counter that's shared across
    /// watchers for the same turn (mirror of seat-emit
    /// discipline)。
    static func observe(
        _ observation: BASAgentWatcherObservation,
        seq: inout Int
    ) -> [BASAgentWatcherHint]
}

// MARK: - AnomalyWatcher

/// Detects unusual turn patterns:sudden risk escalations,
/// abnormal candidate counts,unusual scout signal volumes。
/// LOW-stakes — most signals trigger `.watch`,not `.alert`。
public enum BASAnomalyWatcher: BASAgentWatcher {
    public static let role: BASAgentRole = .anomalyWatcher

    /// SEALED thresholds — no caller can tune (defense against
    /// drift)。 Per ch 964 SovereignSentinel sealed-LOW pattern。
    public static let candidateCountAlert: Int = 50
    public static let pressureSignalAlert: Int = 20
    public static let manipulationSignalAlert: Int = 10

    public static func observe(
        _ obs: BASAgentWatcherObservation,
        seq: inout Int
    ) -> [BASAgentWatcherHint] {
        var hints: [BASAgentWatcherHint] = []
        // Rule 1:candidate count surge
        if obs.plannerCandidates.count >=
            candidateCountAlert
        {
            seq += 1
            hints.append(BASAgentWatcherHint(
                hintID:
                    "hint.\(obs.turnID).anomaly.\(seq)",
                turnID: obs.turnID,
                watcherRole: role,
                severity: .watch,
                category: "anomaly.candidate-count",
                summary:
                    "planner emitted \(obs.plannerCandidates.count)" +
                    " candidates (≥ \(candidateCountAlert) threshold)",
                evidence: [
                    "anomaly.candidate-count=" +
                        "\(obs.plannerCandidates.count)",
                    "anomaly.threshold=" +
                        "\(candidateCountAlert)",
                ],
                confidence: 0.7,
                nowNanos: obs.nowNanos))
        }
        // Rule 2:pressure signal surge
        if obs.scout.pressureSignals.count >=
            pressureSignalAlert
        {
            seq += 1
            hints.append(BASAgentWatcherHint(
                hintID:
                    "hint.\(obs.turnID).anomaly.\(seq)",
                turnID: obs.turnID,
                watcherRole: role,
                severity: .watch,
                category: "anomaly.pressure-volume",
                summary:
                    "scout saw \(obs.scout.pressureSignals.count) " +
                    "pressure signals (≥ \(pressureSignalAlert))",
                evidence: [
                    "anomaly.pressure-count=" +
                        "\(obs.scout.pressureSignals.count)",
                ],
                confidence: 0.65,
                nowNanos: obs.nowNanos))
        }
        // Rule 3:manipulation signal surge → ALERT (more
        // serious than candidate-count anomaly)
        if obs.scout.manipulationSignals.count >=
            manipulationSignalAlert
        {
            seq += 1
            hints.append(BASAgentWatcherHint(
                hintID:
                    "hint.\(obs.turnID).anomaly.\(seq)",
                turnID: obs.turnID,
                watcherRole: role,
                severity: .alert,
                category: "anomaly.manipulation-volume",
                summary:
                    "scout saw " +
                    "\(obs.scout.manipulationSignals.count) " +
                    "manipulation signals (≥ " +
                    "\(manipulationSignalAlert)) — possible " +
                    "manipulation-storm attack",
                evidence: [
                    "anomaly.manipulation-count=" +
                        "\(obs.scout.manipulationSignals.count)",
                ],
                confidence: 0.85,
                nowNanos: obs.nowNanos))
        }
        return hints
    }
}

// MARK: - MemoryPollutionWatcher

/// Detects memory-injection / pollution attempts:duplicate
/// episode-arc IDs,recall-strength spikes paired with low
/// other signals (suggests caller is fabricating recall),
/// conflict-cluster IDs that don't appear in any other channel。
public enum BASMemoryPollutionWatcher: BASAgentWatcher {
    public static let role: BASAgentRole =
        .memoryPollutionWatcher

    /// SEALED threshold:recall strength above this without
    /// any pressure/manipulation/boundary signals suggests
    /// fabrication。
    public static let recallStrengthSuspect: Double = 0.85

    public static func observe(
        _ obs: BASAgentWatcherObservation,
        seq: inout Int
    ) -> [BASAgentWatcherHint] {
        var hints: [BASAgentWatcherHint] = []
        guard let mem = obs.memory else { return hints }

        // Rule 1:duplicate episode-arc IDs
        let arcCounts = Dictionary(
            grouping: mem.episodeArcs, by: { $0 })
            .mapValues { $0.count }
        let dupArcs = arcCounts.filter { $0.value > 1 }
            .keys.sorted()
        if !dupArcs.isEmpty {
            seq += 1
            hints.append(BASAgentWatcherHint(
                hintID:
                    "hint.\(obs.turnID).mempol.\(seq)",
                turnID: obs.turnID,
                watcherRole: role,
                severity: .watch,
                category: "memory.duplicate-arc",
                summary:
                    "memory bundle contains " +
                    "\(dupArcs.count) duplicate episode-arc IDs",
                evidence: dupArcs.map {
                    "memory.dup-arc=\($0)"
                },
                confidence: 0.75,
                nowNanos: obs.nowNanos))
        }

        // Rule 2:high recall strength with zero scout signal
        // — suggests fabricated recall
        let totalScoutSignals =
            obs.scout.pressureSignals.count +
            obs.scout.manipulationSignals.count +
            obs.scout.boundaryTouchCount +
            obs.scout.bareContradictions.count
        if mem.recallStrength >= recallStrengthSuspect &&
           totalScoutSignals == 0 &&
           !mem.episodeArcs.isEmpty
        {
            seq += 1
            let recallStr =
                String(format: "%.3f", mem.recallStrength)
            hints.append(BASAgentWatcherHint(
                hintID:
                    "hint.\(obs.turnID).mempol.\(seq)",
                turnID: obs.turnID,
                watcherRole: role,
                severity: .alert,
                category: "memory.fabrication-suspect",
                summary:
                    "high recall strength (\(recallStr)) with " +
                    "zero scout signals — possible fabricated " +
                    "recall injection",
                evidence: [
                    "memory.recall-strength=\(recallStr)",
                    "memory.scout-signal-count=" +
                        "\(totalScoutSignals)",
                    "memory.arc-count=\(mem.episodeArcs.count)",
                ],
                confidence: 0.80,
                nowNanos: obs.nowNanos))
        }

        // Rule 3:conflict-cluster IDs that don't appear in
        // bare-contradictions or critic concerns — orphan
        // conflicts often indicate caller fabricated cluster
        // membership
        if !mem.conflictClusters.isEmpty {
            let bareSet = Set(obs.scout.bareContradictions)
            // Critic candidate IDs are a weak proxy — but
            // a cluster ID NOT appearing anywhere else is
            // suspect
            let criticIDs:Set<String> = Set(
                (obs.critic?.candidates ?? [])
                    .map { $0.candidateID })
            let orphanClusters = mem.conflictClusters.filter {
                !bareSet.contains($0) &&
                !criticIDs.contains($0)
            }
            if orphanClusters.count >=
                max(3, mem.conflictClusters.count / 2)
            {
                seq += 1
                hints.append(BASAgentWatcherHint(
                    hintID:
                        "hint.\(obs.turnID).mempol.\(seq)",
                    turnID: obs.turnID,
                    watcherRole: role,
                    severity: .watch,
                    category: "memory.orphan-conflict",
                    summary:
                        "\(orphanClusters.count) of " +
                        "\(mem.conflictClusters.count) " +
                        "conflict clusters have no scout/critic " +
                        "anchor",
                    evidence: [
                        "memory.orphan-cluster-count=" +
                            "\(orphanClusters.count)",
                        "memory.cluster-total=" +
                            "\(mem.conflictClusters.count)",
                    ],
                    confidence: 0.65,
                    nowNanos: obs.nowNanos))
            }
        }
        return hints
    }
}

// MARK: - HostDriftWatcher

/// Detects drift from host constitution:tone or style choices
/// from Surface seat that don't match host's declared style
/// genome,axis touches that don't appear in host's boundary
/// list,etc。
public enum BASHostDriftWatcher: BASAgentWatcher {
    public static let role: BASAgentRole = .hostDriftWatcher

    /// SEALED:if surface emits a mode that doesn't match the
    /// risk band by ≥ this many tiers,that's drift。 (e.g.
    /// risk=high but surface=delay is consistent;risk=low but
    /// surface=block is drift)。
    public static let modeTierMismatchAlert: Int = 2

    public static func observe(
        _ obs: BASAgentWatcherObservation,
        seq: inout Int
    ) -> [BASAgentWatcherHint] {
        var hints: [BASAgentWatcherHint] = []

        // Rule 1:HostAlignment seat flagged multi-axis touches
        // that the actual candidate axes don't fully cover
        // (suggests host constitution drifted from candidate
        // pre-classification)
        if let align = obs.hostAlignment {
            let hostAxes = Set(align.hostBoundaryAxes)
            for cand in align.candidates {
                let touched = Set(cand.touchesAxes)
                let untracked = touched.subtracting(hostAxes)
                if untracked.count >= 2 {
                    seq += 1
                    hints.append(BASAgentWatcherHint(
                        hintID:
                            "hint.\(obs.turnID).hostdrift.\(seq)",
                        turnID: obs.turnID,
                        watcherRole: role,
                        severity: .watch,
                        category: "hostdrift.untracked-axes",
                        summary:
                            "candidate \(cand.candidateID) " +
                            "touches \(untracked.count) axes " +
                            "not in host boundary list",
                        evidence: untracked.sorted().map {
                            "hostdrift.untracked=\($0)"
                        },
                        confidence: 0.70,
                        candidateRef:
                            "candidate#\(cand.candidateID)",
                        nowNanos: obs.nowNanos))
                }
            }
        }

        // Rule 2:Surface mode vs risk band mismatch (drift
        // signal — when these diverge,host constitution
        // suggests one but seat emitted the other)。
        // Skip when no planner candidates exist at all — degenerate
        // "no turn happened" state (BASSurfaceInput() default with
        // empty acceptedCandidateID is not drift,it's a no-op turn)。
        // riskBand: .low / .medium / .high
        // mode tiers (informal): block(5) / delay(4) /
        //   compare(3) / draftOnly(2) / answer(1)
        if !obs.plannerCandidates.isEmpty &&
           isMismatch(
                riskBand: obs.surface.riskBand,
                acceptedID: obs.surface.acceptedCandidateID)
        {
            seq += 1
            let acceptedStr =
                obs.surface.acceptedCandidateID ?? ""
            hints.append(BASAgentWatcherHint(
                hintID:
                    "hint.\(obs.turnID).hostdrift.\(seq)",
                turnID: obs.turnID,
                watcherRole: role,
                severity: .watch,
                category: "hostdrift.surface-risk-mismatch",
                summary:
                    "surface mode does not match risk band " +
                    "\(obs.surface.riskBand.rawValue) — possible " +
                    "host drift",
                evidence: [
                    "hostdrift.risk-band=" +
                        "\(obs.surface.riskBand.rawValue)",
                    "hostdrift.surface-accepted=\(acceptedStr)",
                ],
                confidence: 0.55,
                nowNanos: obs.nowNanos))
        }

        return hints
    }

    /// Heuristic:if risk is low but the surface seat declined
    /// to accept any candidate (acceptedCandidateID nil or empty),
    /// that's a mismatch worth observing。
    private static func isMismatch(
        riskBand: BASRiskAssessmentBand,
        acceptedID: String?
    ) -> Bool {
        switch riskBand {
        case .low:
            // Low risk but surface didn't accept → drift
            return (acceptedID ?? "").isEmpty
        case .medium, .high:
            return false  // expected
        }
    }
}

// MARK: - Watcher hint aggregator (ch 970 partial — ch 972 finalizes)

public enum BASAgentWatcherDispatch {
    /// Run the 3 ch 970 watchers against an observation。
    /// Returns concatenated hints across all watchers,with
    /// shared seq counter for hint-ID determinism。 Caller may
    /// run the full 7-watcher set via the ch 972 aggregator
    /// when wired。
    public static func runCh970(
        _ obs: BASAgentWatcherObservation
    ) -> [BASAgentWatcherHint] {
        var seq = 0
        var out: [BASAgentWatcherHint] = []
        out.append(contentsOf:
            BASAnomalyWatcher.observe(obs, seq: &seq))
        out.append(contentsOf:
            BASMemoryPollutionWatcher.observe(obs, seq: &seq))
        out.append(contentsOf:
            BASHostDriftWatcher.observe(obs, seq: &seq))
        return out
    }
}
