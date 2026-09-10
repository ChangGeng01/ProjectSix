// MARK: - BASKernelDispatchStatisticsRecorder
// chapter 五百三 / M1390 — actor that accumulates dispatch
// attempt cards into a statistics bundle
//
// REAL CONSUMPTION of chapter 499 typed surfaces:
//   - M1373 BASKernelDispatchStatisticsBundle (7th
//     BASBundle adoption) — aggregate per-(op, success)
//     dispatch counts
//   - M1375 BASKernelDispatchAttemptCard (4th BASCard
//     adoption) — typed per-attempt classification
//
// Hosts call `recordAttempt(card:)` per dispatch attempt;
// `snapshot()` returns the accumulated typed statistics
// bundle ready for audit emission。
//
// HONEST SCOPE — chapter 五百三:
// =============================================================
// Recorder is OPT-IN substrate observability surface。 No
// production executor wires it at chapter 503 close-out。
// V1 byte-equality preserved — recording is pure-additive
// observation。

import Foundation
import BASRuntimeCore

/// Actor-isolated accumulator that consumes typed
/// BASKernelDispatchAttemptCard records and emits a
/// typed BASKernelDispatchStatisticsBundle snapshot。
public actor BASKernelDispatchStatisticsRecorder {

    /// Per-(operation, success) tally。 Keyed on a
    /// composite to dedup across many attempts。
    private var tallies:
        [TallyKey: Int] = [:]
    private var totalAttempts: Int = 0

    private struct TallyKey: Hashable {
        let operation: BASNeuralOp
        let succeeded: Bool
    }

    public init() {}

    /// Record one dispatch attempt classified by typed
    /// card kind。 The recorder maps the card's typed
    /// kind to a success bool:.success → true,others
    /// → false。 Preserves the chapter 499 M1375 typed
    /// taxonomy。
    public func recordAttempt(
        card: BASKernelDispatchAttemptCard
    ) {
        let succeeded = (card.kind == .success)
        let key = TallyKey(
            operation: card.body.operation,
            succeeded: succeeded)
        tallies[key, default: 0] += 1
        totalAttempts += 1
    }

    /// Convenience variant accepting raw fields when
    /// constructing a card just for recording would be
    /// overkill。
    public func recordAttempt(
        operation: BASNeuralOp,
        kind: BASKernelDispatchAttemptKind
    ) {
        let succeeded = (kind == .success)
        let key = TallyKey(
            operation: operation,
            succeeded: succeeded)
        tallies[key, default: 0] += 1
        totalAttempts += 1
    }

    /// Snapshot the accumulated state as a typed
    /// BASKernelDispatchStatisticsBundle。 Read-only —
    /// no state mutation。 Items are returned in a
    /// deterministic order (sorted by op rawValue then
    /// succeeded flag) to enable replay-determinism
    /// per chapter 三百九二。
    public func snapshot(
        bundleID: String,
        recordedAtMs: Int64
    ) -> BASKernelDispatchStatisticsBundle {
        let sortedKeys = tallies.keys.sorted {
            if $0.operation.rawValue
                != $1.operation.rawValue
            {
                return $0.operation.rawValue
                    < $1.operation.rawValue
            }
            // false < true sort for deterministic order
            return !$0.succeeded && $1.succeeded
        }
        let items = sortedKeys.map { key in
            BASKernelDispatchStatisticsBundleItem(
                operation: key.operation,
                succeeded: key.succeeded,
                count: tallies[key] ?? 0)
        }
        return BASKernelDispatchStatisticsBundle(
            bundleID: bundleID,
            schemaVersion: "1.0.0",
            items: items,
            metadata: [
                "total-attempts":
                    "\(totalAttempts)",
                "recorder-source":
                    "BASKernelDispatchStatisticsRecorder"
            ],
            recordedAt: Date(
                timeIntervalSince1970:
                    TimeInterval(recordedAtMs)
                    / 1000.0))
    }

    // MARK: - Read accessors

    public var totalRecordedAttempts: Int {
        totalAttempts
    }

    /// Count of distinct (op, success) tally buckets。
    public var distinctTallyCount: Int {
        tallies.count
    }

    /// Reset internal state — useful for tests + per-
    /// turn recorder instances。
    public func reset() {
        tallies.removeAll()
        totalAttempts = 0
    }
}
