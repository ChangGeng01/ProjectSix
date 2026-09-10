// MARK: - BASAgentFabricWatcherCollector
// chapter 一千零十二 / M3775 — Phase 9+ start: watcher pipeline
// integration making `Gate.Tier.core` vs `.all` genuinely
// behavioral
//
// ## What previous arcs left as scaffold
//
// Per `Docs/SCAFFOLD_VS_WIRED.md` (post-ch 1010.6):
//   - `Gate.Tier.core` / `.all`: ch 1008 added VALIDATION wire
//     (catches inconsistent activeAgents combos) but tier still
//     did NOT genuinely change substrate runtime output。
//   - 7 watcher implementations existed in BASMemory but were
//     never invoked from the host pipeline。
//
// Phase 9+ closes this gap incrementally:
//
//   ch 1012 (this chapter):
//     - Collect watcher hints per turn when fabric runs in
//       `.all` tier
//     - Audit hints via the L14 sovereign ledger using the
//       canonical `BASAgentObservationAuditEmitter` shape from
//       ch 1006 (since hints are observability artifacts,
//       analogous to observations)
//     - `.core` tier: watchers NOT invoked (byte-equal pre-fix
//       behavior preserved)
//     - `.all` tier: watchers invoked + hints landed in audit
//       ledger via signalRefs
//
// ## Why pure-fn + collect-then-audit pattern
//
// Per the ch 957 / ch 1002 seat doctrine: no actor, no I/O,
// no shared state beyond supplied input。 The collector is a
// pure-fn that takes a `BASAgentWatcherObservation` (already
// available from the dispatcher's per-turn snapshot)。
//
// Wiring the collector into the pipeline is a one-line tier-
// guard: when activation.tier == .all, call the collector +
// thread the hints to the audit-emitter helper that ch 1006
// established。
//
// ## Discipline
//
// - Additive only (red-line 7) — no existing seat / API
//   changed
// - ADR-014 OPT-IN — fabric default tier is `.core` so
//   pre-ch-1012 behavior preserved
// - Pure-fn `collect(...)` + `signalRefs(from:)` —
//   deterministic byte-equal output
// - Single canonical hint serialization (no parallel
//   formats per ch 1010.5/.6 single-canonical doctrine)
// - U+001F separator discipline (per Round-20 / Round-21
//   lessons applied uniformly)

import Foundation
import BASMemory
import BASSovereign
import BASRuntimeCore

public enum BASAgentFabricWatcherCollector {

    /// Run all 7 watchers against the per-turn observation。
    /// Returns sorted hints (sorted by watcherRole + severity +
    /// hintID for byte-equal determinism)。
    ///
    /// Empty hints array on a「nothing detected」turn — most
    /// turns produce zero hints (per plan PHASE 5 doctrine:
    /// watchers are quiet observers,not eager flaggers)。
    public static func collect(
        observation: BASAgentWatcherObservation,
        seq: inout Int
    ) -> [BASAgentWatcherHint] {
        var hints: [BASAgentWatcherHint] = []
        // 7 watchers, called in deterministic order for
        // byte-equal output。 Each watcher emits 0+ hints
        // appended to the shared list with the same seq
        // counter so hintIDs are unique within the turn。
        hints.append(contentsOf: BASAnomalyWatcher
            .observe(observation, seq: &seq))
        hints.append(contentsOf: BASMemoryPollutionWatcher
            .observe(observation, seq: &seq))
        hints.append(contentsOf: BASHostDriftWatcher
            .observe(observation, seq: &seq))
        hints.append(contentsOf: BASGaslightWatcher
            .observe(observation, seq: &seq))
        hints.append(contentsOf: BASToolInjectionWatcher
            .observe(observation, seq: &seq))
        hints.append(contentsOf: BASAxisDeviationWatcher
            .observe(observation, seq: &seq))
        hints.append(contentsOf: BASSanctumLeakWatcher
            .observe(observation, seq: &seq))
        // Sort for byte-equal output across runs
        return hints.sorted { lhs, rhs in
            if lhs.hintID != rhs.hintID {
                return lhs.hintID < rhs.hintID
            }
            return lhs.severity.rawValue <
                rhs.severity.rawValue
        }
    }

    /// Serialize hint list into deterministic ordered signalRef
    /// strings for L14 audit-ledger inclusion。 Mirrors ch 1006
    /// `BASAgentObservationAuditEmitter.signalRefs` shape:
    /// U+001F separators,sorted output。
    ///
    /// Format per entry:
    /// `watcherHint.<hintID>\u{001F}role=<role>\u{001F}severity=<sev>\u{001F}category=<cat>\u{001F}conf=<band>`
    ///
    /// Confidence band: `low` (<0.4) / `med` (<0.7) /
    /// `high` (>=0.7) — same band thresholds as ch 1006 per
    /// single-canonical doctrine。
    public static func signalRefs(
        from hints: [BASAgentWatcherHint]
    ) -> [String] {
        let sorted = hints.sorted { $0.hintID < $1.hintID }
        let sep = "\u{001F}"
        return sorted.map { hint in
            // ch 1015 / M3800 — Round-24 HIGH-1 fix:
            // delegate to canonical helper (was duplicated
            // inline at ch 1006 + ch 1012)
            let band = BASTraceAnnotatorSeat
                .confidenceBandFor(hint.confidence)
            return "watcherHint.\(hint.hintID)" +
                "\(sep)role=\(hint.watcherRole.rawValue)" +
                "\(sep)severity=\(hint.severity.rawValue)" +
                "\(sep)category=\(hint.category)" +
                "\(sep)conf=\(band)"
        }
    }

    /// Build an audit entry capturing the per-turn watcher
    /// collection。 Empty hints array still produces a「no
    /// concerns」 audit entry — symmetric to ch 1007 mode
    /// audit per ch 977 defense-in-depth doctrine。
    ///
    /// The entry's `signalRefs` contains the watcher-hint refs
    /// (or a single「none」 sentinel for empty)。 ruleIDs +
    /// actionRefs empty per observability-entry convention。
    public static func buildAuditEntry(
        hints: [BASAgentWatcherHint],
        sessionID: String,
        turnID: String,
        now: Date = Date()
    ) -> BASSovereignAuditEntry {
        let sep = "\u{001F}"
        let auditID =
            "agentFabricWatcher.audit\(sep)" +
            "\(turnID)\(sep)\(hints.count)"
        let verdictRef = hints.isEmpty
            ? "agentFabricWatcher\(sep)clean"
            : "agentFabricWatcher\(sep)hints\(sep)" +
              "\(hints.count)"
        let refs = hints.isEmpty
            ? ["watcherHint\(sep)none"]
            : signalRefs(from: hints)
        return BASSovereignAuditEntry(
            schemaVersion: BASSovereignAuditEntry
                .hardenedSchemaVersion,
            auditID: auditID,
            sessionID: sessionID,
            turnID: turnID,
            verdictRef: verdictRef,
            ruleIDs: [],
            signalRefs: refs,
            actionRefs: [],
            snapshotRef: "",
            actor: .system,
            signature: "",
            appendedAt: now)
    }

    /// One-call wrapper: collect + audit-append。 Mirrors ch
    /// 1003 / 1007 audit-bridge pattern。 Returns the appended
    /// ledger entry receipt for downstream verification。
    @discardableResult
    public static func collectAndAudit(
        observation: BASAgentWatcherObservation,
        sessionID: String,
        ledger: BASSovereignAuditLedger,
        seq: inout Int,
        now: Date = Date()
    ) async throws -> (
        hints: [BASAgentWatcherHint],
        appendedEntry: BASSovereignAuditLedger.AppendedEntry
    ) {
        let hints = collect(
            observation: observation, seq: &seq)
        let entry = buildAuditEntry(
            hints: hints,
            sessionID: sessionID,
            turnID: observation.turnID,
            now: now)
        let appended = try await ledger.append(entry)
        return (hints: hints, appendedEntry: appended)
    }

    // chapter 一千零十五 / M3800 — Round-24 HIGH-1 fix:
    // private `confidenceBand` deleted。 The pre-fix comment
    // claimed「same thresholds as ch 1006 — single canonical
    // doctrine」 yet violated it via duplicate inline impl。
    // Sole caller (line 118) now delegates to canonical
    // `BASTraceAnnotatorSeat.confidenceBandFor(_:)`。
}
