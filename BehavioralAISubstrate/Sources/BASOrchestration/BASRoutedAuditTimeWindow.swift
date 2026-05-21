// MARK: - BASRoutedAuditTimeWindow
// chapter 八百十二 / M2711-M2715 — time-windowed audit query helpers
//
// Pure-fn helpers that filter audit records by epoch-ms time
// window。 Lets hosts ask「what happened in the last N seconds」
// or「between timestamps X and Y」 without each writing the same
// predicate by hand。
//
// Works across all 4 audit record types shipped by chapters
// 七百九十四 → 七百九十六:
//
//   - BASPresenceObservationRecord       (observedAtMs)
//   - BASUnknownLedgerRecord             (discoveredAtMs)
//   - BASContradictionLedgerRecord       (resolvedAtMs — nullable!)
//   - BASHostConstitutionVersionRecord   (createdAtMs)
//   - BASHostConstitutionDeletionRecord  (appliedAtMs)
//   - BASAtomLifecycleEvent              (recordedAtMs)
//
// Each record carries its time field under a different name (no
// shared protocol),so the helpers below provide per-type
// inline-friendly filters。
//
// ## Doctrine
//
// 「依旧 不删除 只 comment」 — no store touched。 These are
// pure functions over already-fetched arrays。 Hosts that want
// SQL-pushed time filtering can write their own predicate on
// top of the store's existing query API (e.g。 `WHERE
// observed_at_ms >= ?`)。 This helper module is the Swift-side
// counterpart for in-memory filtering after a bulk-fetch。
//
// ## Half-open window convention
//
// All time windows are HALF-OPEN: [startMs, endMs)。 startMs is
// INCLUDED;endMs is EXCLUDED。 Matches the common「up to but
// not including」 query semantic + avoids off-by-one when
// chaining windows back-to-back。
//
// `since(_:)` shortcuts to [sinceMs, Int64.max)。

import Foundation
import BASMemory
import BASSovereign

public enum BASRoutedAuditTimeWindow {

    // MARK: - L6 presence

    /// Filter `BASPresenceObservationRecord` array to those with
    /// `observedAtMs in [startMs, endMs)`。 Stable — preserves
    /// input insertion order。
    public static func presence(
        _ records: [BASPresenceObservationRecord],
        between startMs: Int64,
        and endMs: Int64
    ) -> [BASPresenceObservationRecord] {
        return records.filter { rec in
            rec.observedAtMs >= startMs && rec.observedAtMs < endMs
        }
    }

    /// Shortcut for [sinceMs, ∞)。
    public static func presence(
        _ records: [BASPresenceObservationRecord],
        since sinceMs: Int64
    ) -> [BASPresenceObservationRecord] {
        return presence(records, between: sinceMs, and: .max)
    }

    // MARK: - L7 unknown

    public static func unknowns(
        _ records: [BASUnknownLedgerRecord],
        between startMs: Int64,
        and endMs: Int64
    ) -> [BASUnknownLedgerRecord] {
        return records.filter { rec in
            rec.discoveredAtMs >= startMs && rec.discoveredAtMs < endMs
        }
    }

    public static func unknowns(
        _ records: [BASUnknownLedgerRecord],
        since sinceMs: Int64
    ) -> [BASUnknownLedgerRecord] {
        return unknowns(records, between: sinceMs, and: .max)
    }

    // MARK: - L7 contradictions
    //
    // Contradictions have TWO time fields:
    //   - inherent "discovered at" (no schema column;use
    //     externally-known ordering)
    //   - resolved_at_ms (NULLABLE for unresolved rows)
    //
    // The helpers here filter by resolved_at_ms — primary use
    // case is「show me what got resolved in the last hour」。
    // Hosts that need discovery-time filtering can iterate
    // their own array since the schema doesn't carry that
    // column directly。

    /// Filter contradictions to those resolved within [startMs,
    /// endMs)。 Unresolved rows (resolvedAtMs == nil) are
    /// EXCLUDED — they have no resolution timestamp to test。
    public static func contradictionsResolved(
        _ records: [BASContradictionLedgerRecord],
        between startMs: Int64,
        and endMs: Int64
    ) -> [BASContradictionLedgerRecord] {
        return records.filter { rec in
            guard let ms = rec.resolvedAtMs else { return false }
            return ms >= startMs && ms < endMs
        }
    }

    public static func contradictionsResolved(
        _ records: [BASContradictionLedgerRecord],
        since sinceMs: Int64
    ) -> [BASContradictionLedgerRecord] {
        return contradictionsResolved(
            records, between: sinceMs, and: .max)
    }

    /// Filter to records that are STILL UNRESOLVED at the time
    /// of inspection。 Returns rows whose `resolved` flag is
    /// false (equivalent to resolvedAtMs == nil per schema 012
    /// invariant)。 No time window — used to find current open
    /// contradictions。
    public static func contradictionsUnresolved(
        _ records: [BASContradictionLedgerRecord]
    ) -> [BASContradictionLedgerRecord] {
        return records.filter { !$0.resolved }
    }

    // MARK: - L5 host-constitution version tree

    public static func versions(
        _ records: [BASHostConstitutionVersionRecord],
        between startMs: Int64,
        and endMs: Int64
    ) -> [BASHostConstitutionVersionRecord] {
        return records.filter { rec in
            rec.createdAtMs >= startMs && rec.createdAtMs < endMs
        }
    }

    public static func versions(
        _ records: [BASHostConstitutionVersionRecord],
        since sinceMs: Int64
    ) -> [BASHostConstitutionVersionRecord] {
        return versions(records, between: sinceMs, and: .max)
    }

    // MARK: - L5 deletion manifest

    public static func deletions(
        _ records: [BASHostConstitutionDeletionRecord],
        between startMs: Int64,
        and endMs: Int64
    ) -> [BASHostConstitutionDeletionRecord] {
        return records.filter { rec in
            rec.appliedAtMs >= startMs && rec.appliedAtMs < endMs
        }
    }

    public static func deletions(
        _ records: [BASHostConstitutionDeletionRecord],
        since sinceMs: Int64
    ) -> [BASHostConstitutionDeletionRecord] {
        return deletions(records, between: sinceMs, and: .max)
    }

    // MARK: - L8 atom lifecycle

    public static func atomEvents(
        _ events: [BASAtomLifecycleEvent],
        between startMs: Int64,
        and endMs: Int64
    ) -> [BASAtomLifecycleEvent] {
        return events.filter { ev in
            ev.recordedAtMs >= startMs && ev.recordedAtMs < endMs
        }
    }

    public static func atomEvents(
        _ events: [BASAtomLifecycleEvent],
        since sinceMs: Int64
    ) -> [BASAtomLifecycleEvent] {
        return atomEvents(events, between: sinceMs, and: .max)
    }
}
