import Foundation
import BASRuntimeCore

// MARK: - L14 sovereign audit-ledger coverage projection
//
// M38 — additive edge projection from `BASSovereignAuditLedger` (L14
// sovereign microkernel) to the neutral
// `BASObservationCoverageSummary` defined in `BASRuntimeCore` (M31).
// Extends the M32/M37 wave from 9-of-14 to **10-of-14** projected
// layers. Remaining four: L1 (leaseLife), L2 (neuralOrgan),
// L3 (thoughtFold), L5 (hostConstitution).
//
// L14 is the append-only audit authority for the substrate's three
// signing surfaces (`VerdictEngine` / `TokenAuthority` /
// `SnapshotManager`). Like L8 (M37), the ledger is not intrinsically
// bound to a single turn — it is session-scoped and records many
// turns' worth of entries. The projection therefore takes
// `turnID` / `sessionID` as arguments and filters the chain by that
// key pair before producing the summary.
//
// Design principles:
//   1. Additive — `BASSovereignAuditLedger`,
//      `BASSovereignAuditEntry`, and every consumer path are
//      untouched. Callers opt in via `coverageSummary(...)`.
//   2. Snapshot-based — projection is a read-side operation that
//      walks a value snapshot of the chain. No state mutation, no
//      hash-chain re-verification (verification remains
//      `verifyChainIntegrity()`'s job).
//   3. Neutral shape — the L14 reconciler consumes L14 in exactly
//      the same way it consumes L4/L6/L7/L8/L9/L10/L11/L12/L13 —
//      one `BASObservationCoverageSummary` per layer per turn.
//   4. Isolation preserved — the projection lives in `BASSovereign`
//      and imports only `BASRuntimeCore`; no downstream module
//      leaks into the microkernel.

// MARK: - Budget

/// Pure lookup: what does each audit-ledger entry cost the L1 wake
/// budget?
///
/// The two actors — `.system` (the substrate's own sovereign
/// modules writing verdicts / token issuance / snapshot boot checks)
/// and `.operator` (an explicit human-in-the-loop override) — carry
/// distinct budget weights. An operator-issued entry is treated as
/// slightly more expensive because it represents a manual override
/// event that deserves more audit attention, even though the
/// mechanical work is the same.
public enum BASSovereignAuditCoverageBudget {
    public static let systemEntryCost: Double = 0.10
    public static let operatorEntryCost: Double = 0.15

    /// Cost for a single audit-entry actor.
    public static func cost(
        for actor: BASSovereignAuditActor
    ) -> Double {
        switch actor {
        case .system: return systemEntryCost
        case .operator: return operatorEntryCost
        }
    }

    /// Clamped total cost for a batch of audit entries (expressed as
    /// `AppendedEntry` records from a ledger snapshot). Matches the
    /// convention set by the other layers' budget tables.
    public static func totalCost(
        for appendedEntries: [BASSovereignAuditLedger.AppendedEntry]
    ) -> Double {
        let sum = appendedEntries.reduce(0.0) { acc, appended in
            acc + cost(for: appended.entry.actor)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Pure projection

extension BASSovereignAuditLedger {
    /// Pure, synchronous projection helper. Given a pre-snapshotted
    /// batch of entries (produced by the actor's `snapshot()` or
    /// `entries(forSession:turn:)`), derive the neutral coverage
    /// summary. Factored out of the async `coverageSummary(...)`
    /// below so callers that already hold a snapshot (governance
    /// tooling, integration tests, replay harnesses) can reason over
    /// coverage without an actor hop, and so unit tests can pin the
    /// projection logic deterministically.
    public static func projectCoverage(
        from appendedEntries: [BASSovereignAuditLedger.AppendedEntry],
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASObservationCoverageSummary {
        // Filter to the requested turn/session first — `snapshot()`
        // is session-scoped only by virtue of the ledger being
        // per-session in practice, but nothing in the schema
        // forbids a multi-session ledger. Filtering here is cheap
        // and keeps the projection robust to that future shape.
        let scoped = appendedEntries.filter {
            $0.entry.turnID == turnID
                && $0.entry.sessionID == sessionID
        }
        // Distinct-verdict-ref count: each sovereign verdict is an
        // independent governance subject. Two entries pointing at
        // the same verdict (e.g., the verdict row + a token-issue
        // row referencing that verdict) collapse to one subject.
        let distinctVerdicts = Set(scoped.map { $0.entry.verdictRef })
        return BASObservationCoverageSummary(
            layer: .sovereign,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: scoped.count,
            distinctSubjectCount: distinctVerdicts.count,
            hasCoreSignalCoverage: Self.hasCoreSignalCoverage(
                in: scoped),
            budgetTotalCost:
                BASSovereignAuditCoverageBudget.totalCost(
                    for: scoped),
            emittedAt: emittedAt)
    }

    /// L14 has "core signal coverage" for a turn iff the sovereign
    /// actually *evaluated rules* during the turn — not merely
    /// stamped a no-op entry. Concretely: at least one entry exists
    /// for the turn AND at least one of those entries references a
    /// non-empty `ruleIDs` list. An entry with an empty `ruleIDs`
    /// might be a bookkeeping token rotation or a snapshot boot
    /// check; it proves the ledger is alive but not that the
    /// microkernel made a rule-bearing decision.
    public static func hasCoreSignalCoverage(
        in appendedEntries: [BASSovereignAuditLedger.AppendedEntry]
    ) -> Bool {
        guard !appendedEntries.isEmpty else { return false }
        return appendedEntries.contains { !$0.entry.ruleIDs.isEmpty }
    }

    /// Async coverage summary bound to a specific turn/session.
    /// Snapshots the ledger chain and projects via
    /// `projectCoverage(from:turnID:sessionID:emittedAt:)`. The
    /// `emittedAt` stamp defaults to "now" so the summary records
    /// when the governance coordinator asked the question.
    public func coverageSummary(
        turnID: String,
        sessionID: String,
        emittedAt: Date = Date()
    ) async -> BASObservationCoverageSummary {
        let appended = entries(
            forSession: sessionID, turn: turnID)
        return Self.projectCoverage(
            from: appended,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: emittedAt)
    }
}
