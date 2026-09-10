// MARK: - AxisDeviation + SanctumLeak + L14 Aggregator
// chapter 九百七十二 / M3565 — Phase 5 close
//
// User design Section 9.8 + plan PHASE 5 close:
//   - AxisDeviationWatcher — detects same host-axis touched
//     by MULTIPLE seats simultaneously (indicator of
//     coordinated boundary attack or systematic host drift)
//   - SanctumLeakWatcher — detects host-sealed data referenced
//     in non-sealed seat emissions (e.g. a watcher hint
//     leaking a sealed deletion-manifest ID into a public
//     surface render)
//   - L14 audit aggregator — collects ALL watcher hints from
//     all 7 watchers + routes high-severity hints to the
//     existing `SovereignAuditEntry.signalRefs` array via the
//     reserved `agentWatcher.flag:` prefix
//
// Per ch 953-969 discipline:additive only,no existing call
// sites touched。 Aggregator output is a per-turn record that
// can be plumbed into the dispatcher's trace log + the L14
// SovereignAuditLedger when the host wires it (Phase 6 SDK
// work)。 Phase 5 close ships the aggregator pure-fn;wiring
// is deferred per ADR-014 OPT-IN。
//
// ## Phase 5 close adversarial fuzz
//
// The Phase 5 close test suite injects known-bad inputs
// (gaslight prompts, injection markers, sanctum leak attempts,
// axis-deviation attacks) and asserts watchers fire correctly。

import Foundation

// MARK: - AxisDeviationWatcher

/// Detects when MULTIPLE candidates touch the same host boundary
/// axis in the same turn — sign of coordinated boundary attack
/// or systematic drift。 Different from HostDriftWatcher which
/// flags untracked-axis touches;this watcher flags
/// CONCENTRATED touches on tracked axes。
public enum BASAxisDeviationWatcher: BASAgentWatcher {
    public static let role: BASAgentRole = .axisDeviationWatcher

    /// SEALED:if the same host axis is touched by ≥ this many
    /// candidates in one turn,that's coordinated。
    public static let coordinatedTouchAlert: Int = 3

    /// SEALED:above this absolute touch count → veto。
    public static let coordinatedTouchVeto: Int = 5

    public static func observe(
        _ obs: BASAgentWatcherObservation,
        seq: inout Int
    ) -> [BASAgentWatcherHint] {
        guard let align = obs.hostAlignment else {
            return []
        }
        let hostAxes = Set(align.hostBoundaryAxes)
        // Count touches per axis ACROSS all candidates
        var axisCount: [String: Int] = [:]
        for cand in align.candidates {
            for axis in cand.touchesAxes
                where hostAxes.contains(axis)
            {
                axisCount[axis, default: 0] += 1
            }
        }
        var hints: [BASAgentWatcherHint] = []
        for (axis, count) in axisCount
            where count >= coordinatedTouchAlert
        {
            seq += 1
            let severity:
                BASAgentWatcherSeverity =
                    count >= coordinatedTouchVeto
                        ? .veto : .alert
            hints.append(BASAgentWatcherHint(
                hintID:
                    "hint.\(obs.turnID).axisdev.\(seq)",
                turnID: obs.turnID,
                watcherRole: role,
                severity: severity,
                category: "axisdev.coordinated-touch",
                summary:
                    "host axis '\(axis)' touched by \(count) " +
                    "candidates this turn (≥ " +
                    "\(coordinatedTouchAlert) threshold)",
                evidence: [
                    "axisdev.axis=\(axis)",
                    "axisdev.touch-count=\(count)",
                ],
                confidence:
                    severity == .veto ? 0.95 : 0.80,
                nowNanos: obs.nowNanos))
        }
        // Sort deterministically by axis name
        return hints.sorted {
            $0.category + ($0.evidence.first ?? "") <
            $1.category + ($1.evidence.first ?? "")
        }
    }
}

// MARK: - SanctumLeakWatcher

/// Detects sovereign-sealed data referenced in non-sealed seat
/// output。 Examples:
///   - A planner candidate's actionSummary mentions a sealed
///     deletion-manifest ID
///   - Surface accepted-candidate references a sovereign-locked
///     axis directly
///   - Memory bundle contains an episode-arc ID that was
///     supposed to be redacted
///
/// Detection is pattern-based — we look for reserved sealed
/// prefixes in non-sealed string fields。
public enum BASSanctumLeakWatcher: BASAgentWatcher {
    public static let role: BASAgentRole = .sanctumLeakWatcher

    /// SEALED reserved prefixes that ONLY sovereign-tier seats
    /// should reference。 Any non-sovereign seat string field
    /// containing one of these prefixes is suspect。
    public static let sealedPrefixes: [String] = [
        "sealed:",
        "sovereign-locked:",
        "deletion-manifest:",
        "host-version-private:",
        "memory-seal:",
    ]

    public static func observe(
        _ obs: BASAgentWatcherObservation,
        seq: inout Int
    ) -> [BASAgentWatcherHint] {
        var leaks: [(field: String, value: String, prefix: String)] = []

        // Scan planner candidate action summaries
        for cand in obs.plannerCandidates {
            for prefix in sealedPrefixes {
                if cand.actionSummary.lowercased()
                    .contains(prefix.lowercased())
                {
                    leaks.append((
                        field:
                            "planner.action-summary." +
                                cand.candidateID,
                        value: cand.actionSummary,
                        prefix: prefix))
                }
                if cand.title.lowercased()
                    .contains(prefix.lowercased())
                {
                    leaks.append((
                        field: "planner.title." +
                            cand.candidateID,
                        value: cand.title,
                        prefix: prefix))
                }
            }
        }

        // Scan memory bundle episode arcs / anchors (non-sealed
        // domain — Memory is HIGH tier,not sovereign-locked)
        if let mem = obs.memory {
            for arc in mem.episodeArcs {
                for prefix in sealedPrefixes
                    where arc.lowercased()
                        .contains(prefix.lowercased())
                {
                    leaks.append((
                        field: "memory.episode-arc",
                        value: arc, prefix: prefix))
                }
            }
            for anchor in mem.continuityAnchors {
                for prefix in sealedPrefixes
                    where anchor.lowercased()
                        .contains(prefix.lowercased())
                {
                    leaks.append((
                        field: "memory.continuity-anchor",
                        value: anchor, prefix: prefix))
                }
            }
        }

        if leaks.isEmpty { return [] }

        // Group by prefix for clean audit notes — but emit one
        // hint per leak (sovereign needs per-instance attribution)
        var hints: [BASAgentWatcherHint] = []
        for leak in leaks {
            seq += 1
            hints.append(BASAgentWatcherHint(
                hintID:
                    "hint.\(obs.turnID).sanctum.\(seq)",
                turnID: obs.turnID,
                watcherRole: role,
                // Sanctum leak is sovereign-level — ALWAYS .veto
                // (the only way to be here is sealed data
                // appearing in non-sealed channel,which by
                // definition violates Root Law 4)
                severity: .veto,
                category: "sanctum.leak",
                summary:
                    "sealed prefix '\(leak.prefix)' leaked " +
                    "into \(leak.field)",
                evidence: [
                    "sanctum.field=\(leak.field)",
                    "sanctum.leaked-prefix=\(leak.prefix)",
                ],
                confidence: 0.95,
                candidateRef: leak.field,
                nowNanos: obs.nowNanos))
        }
        return hints.sorted {
            $0.hintID < $1.hintID
        }
    }
}

// MARK: - L14 Audit aggregator

/// Per-turn aggregated watcher hint record。 Caller (dispatcher
/// when wired,or SDK consumer running watchers directly)
/// surfaces this for the L14 SovereignAuditLedger to absorb via
/// the existing `signalRefs [String]` array using reserved
/// prefixes:
///
///   - `agentWatcher.flag:<role>:<category>:<hintID>`
///     for every hint at .alert + .veto severity
///   - `agentWatcher.count:<severity>:<count>`
///     for per-severity total
///
/// Zero schema change to `SovereignAuditEntry` — uses the
/// existing absorption channel per ch 953 hostConstitution
/// reuse pattern。
public struct BASWatcherAuditAggregate:
    Sendable, Equatable, Hashable, Codable
{
    public let turnID: String
    public let allHints: [BASAgentWatcherHint]
    /// Count of hints per severity (sorted by severity rawValue
    /// for deterministic round-trip)。
    public let bySeverity: [String: Int]
    /// Count of hints per watcher role。
    public let byRole: [String: Int]
    /// `signalRefs` array entries ready to absorb into the
    /// L14 audit ledger。 Sorted。
    public let signalRefs: [String]
    /// True if any hint reached `.veto` severity — caller
    /// should consider this turn for sovereign-sentinel
    /// re-evaluation。
    public let anyVeto: Bool
    /// True if any hint reached `.alert` or `.veto`。 Used by
    /// callers to decide whether to surface the aggregate to
    /// audit at all (skip when only .info / .watch present)。
    public let actionable: Bool

    public init(
        turnID: String,
        allHints: [BASAgentWatcherHint],
        bySeverity: [String: Int],
        byRole: [String: Int],
        signalRefs: [String],
        anyVeto: Bool,
        actionable: Bool
    ) {
        self.turnID = turnID
        self.allHints = allHints
        self.bySeverity = bySeverity
        self.byRole = byRole
        self.signalRefs = signalRefs
        self.anyVeto = anyVeto
        self.actionable = actionable
    }
}

public enum BASAgentWatcherAggregator {

    /// Run ALL 7 watchers + build the per-turn aggregate。
    /// Pure function。 Caller decides whether/how to surface
    /// the aggregate to the L14 audit ledger via
    /// `aggregate.signalRefs`。
    public static func runAll(
        _ obs: BASAgentWatcherObservation
    ) -> BASWatcherAuditAggregate {
        var seq = 0
        var all: [BASAgentWatcherHint] = []
        // ch 970 trio
        all.append(contentsOf:
            BASAnomalyWatcher.observe(obs, seq: &seq))
        all.append(contentsOf:
            BASMemoryPollutionWatcher.observe(obs, seq: &seq))
        all.append(contentsOf:
            BASHostDriftWatcher.observe(obs, seq: &seq))
        // ch 971 pair
        all.append(contentsOf:
            BASGaslightWatcher.observe(obs, seq: &seq))
        all.append(contentsOf:
            BASToolInjectionWatcher.observe(obs, seq: &seq))
        // ch 972 pair (this chapter)
        all.append(contentsOf:
            BASAxisDeviationWatcher.observe(obs, seq: &seq))
        all.append(contentsOf:
            BASSanctumLeakWatcher.observe(obs, seq: &seq))
        return aggregate(turnID: obs.turnID, hints: all)
    }

    /// Pure-fn aggregator — exposed for callers that have
    /// hints from a custom watcher set。
    public static func aggregate(
        turnID: String,
        hints: [BASAgentWatcherHint]
    ) -> BASWatcherAuditAggregate {
        var bySev: [String: Int] = [:]
        var byRole: [String: Int] = [:]
        var refs: [String] = []
        var anyVeto = false
        var actionable = false
        for h in hints {
            bySev[h.severity.rawValue,
                  default: 0] += 1
            byRole[h.watcherRole.rawValue,
                   default: 0] += 1
            if h.severity == .veto {
                anyVeto = true
                actionable = true
            }
            if h.severity == .alert {
                actionable = true
            }
            // signalRef format reserves the `agentWatcher.`
            // prefix per ch 953 SovereignAuditEntry absorption
            // contract
            if h.severity == .alert ||
               h.severity == .veto
            {
                refs.append(
                    "agentWatcher.flag:" +
                    "\(h.watcherRole.rawValue):" +
                    "\(h.category):" +
                    "\(h.hintID)")
            }
        }
        // Per-severity totals as signalRefs entries
        for (sev, count) in bySev.sorted(by: {
            $0.key < $1.key
        }) {
            refs.append(
                "agentWatcher.count:\(sev):\(count)")
        }
        return BASWatcherAuditAggregate(
            turnID: turnID,
            allHints: hints,
            bySeverity: bySev,
            byRole: byRole,
            signalRefs: refs.sorted(),
            anyVeto: anyVeto,
            actionable: actionable)
    }
}

// MARK: - Extended dispatcher (7 watchers — Phase 5 close)

public extension BASAgentWatcherDispatch {
    /// Phase 5 close — run all 7 watchers + return aggregated
    /// record。 This replaces `runCh970` + `runCh971` as the
    /// canonical entry point for Phase 5 consumers。
    static func runPhase5(
        _ obs: BASAgentWatcherObservation
    ) -> BASWatcherAuditAggregate {
        BASAgentWatcherAggregator.runAll(obs)
    }
}
