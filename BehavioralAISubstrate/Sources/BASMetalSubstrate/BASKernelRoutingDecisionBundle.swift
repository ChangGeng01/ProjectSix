// MARK: - BASKernelRoutingDecisionBundle
// chapter 五百四 / M1394 — 9th BASBundle<Item> adoption
//
// REAL CONSUMPTION of chapter 503 M1389 BASKernelRouting
// DecisionRecord as a BASBundle Item type。 Hosts that
// accumulate routing decisions across many dispatches
// can emit them as a single Codable BASBundle for audit
// replay + scheduler tuning。
//
// Companion to chapter 503 BASKernelRoutingDecision
// Observer — the observer's `snapshotAsBundle(bundleID:
// recordedAtMs:)` method (added in this file) returns
// the accumulated records packed into this typed bundle。
//
// HONEST SCOPE — chapter 五百四:
// =============================================================
// Pure-additive typed bundle adoption。 V1 byte-equality
// preserved。 ADR-014 OPT-IN — hosts must explicitly
// construct an observer + call snapshotAsBundle to use
// the typed surface。

import Foundation
import BASRuntimeCore

/// 9th REAL `BASBundle<Item>` typealias migration —
/// aggregate of N routing-decision records suitable for
/// audit replay + scheduler-tuning consumption。
public typealias BASKernelRoutingDecisionBundle =
    BASBundle<BASKernelRoutingDecisionRecord>

extension BASBundle
    where Item == BASKernelRoutingDecisionRecord
{
    /// Best-case-match count across all records。
    public var bestCaseMatchCount: Int {
        items.filter(\.matchedBestCase).count
    }

    /// Best-case-match ratio in [0, 1]。 Zero when empty。
    public var bestCaseMatchRatio: Double {
        guard !items.isEmpty else { return 0 }
        return Double(bestCaseMatchCount)
            / Double(items.count)
    }

    /// Per-tier distribution of records (typed map from
    /// BASANEEligibilityTier to count)。
    public var perTierCounts:
        [BASANEEligibilityTier: Int]
    {
        var counts: [BASANEEligibilityTier: Int] = [:]
        for item in items {
            counts[item.eligibilityTier, default: 0] += 1
        }
        return counts
    }

    /// Per-routing-choice distribution of records。
    public var perRoutingCounts:
        [BASKernelRoutingPreference: Int]
    {
        var counts:
            [BASKernelRoutingPreference: Int] = [:]
        for item in items {
            counts[item.chosenRouting, default: 0] += 1
        }
        return counts
    }
}

// MARK: - Observer wire-in

extension BASKernelRoutingDecisionObserver {

    /// Snapshot the accumulated routing decisions as a
    /// typed BASKernelRoutingDecisionBundle ready for
    /// audit emission。 Read-only — does not mutate
    /// observer state。 Items are in arrival order
    /// preserving M1389 semantics。
    public func snapshotAsBundle(
        bundleID: String,
        recordedAtMs: Int64
    ) -> BASKernelRoutingDecisionBundle {
        return BASKernelRoutingDecisionBundle(
            bundleID: bundleID,
            schemaVersion: "1.0.0",
            items: snapshot(),
            metadata: [
                "observer-source":
                    "BASKernelRoutingDecisionObserver"
            ],
            recordedAt: Date(
                timeIntervalSince1970:
                    TimeInterval(recordedAtMs)
                    / 1000.0))
    }
}
