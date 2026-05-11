// MARK: - BASEBrainHostRuntimeModeAdvisoryBundle
// chapter 五百四 / M1395 — 10th BASBundle<Item> adoption
//
// REAL CONSUMPTION of chapter 498 M1370 BASEBrainHostRuntime
// ModeAdvisory as a BASBundle Item type。 Hosts accumulating
// advisories via the M1391 ledger can emit them as a single
// Codable BASBundle for audit replay。
//
// Companion to chapter 503 M1391 BASEBrainHostRuntimeMode
// AdvisoryLedger — the ledger's `snapshotAsBundle(bundleID:
// recordedAtMs:)` method (added in this file) returns the
// accumulated advisories packed into this typed bundle。
//
// HONEST SCOPE — chapter 五百四:
// =============================================================
// Pure-additive typed bundle adoption。 V1 byte-equality
// preserved。 ADR-014 OPT-IN — hosts must explicitly
// construct a ledger + call snapshotAsBundle to use the
// typed surface。

import Foundation
import BASRuntimeCore

/// 10th REAL `BASBundle<Item>` typealias migration —
/// aggregate of N runtime-mode advisories suitable for
/// audit replay。
public typealias BASEBrainHostRuntimeModeAdvisoryBundle =
    BASBundle<BASEBrainHostRuntimeModeAdvisory>

extension BASBundle
    where Item == BASEBrainHostRuntimeModeAdvisory
{
    /// Count of advisories that were honored at recording
    /// time。
    public var honoredCount: Int {
        items.filter(\.wasHonored).count
    }

    /// Count of advisories the substrate did NOT honor。
    public var unhonoredCount: Int {
        items.count - honoredCount
    }

    /// Honored ratio in [0, 1]。 Zero when bundle empty。
    public var honoredRatio: Double {
        guard !items.isEmpty else { return 0 }
        return Double(honoredCount)
            / Double(items.count)
    }

    /// Distinct hosts represented in the bundle。
    public var distinctHostCount: Int {
        Set(items.map(\.hostID)).count
    }

    /// Per-mode distribution of advisories (typed map
    /// from BASTurnRuntimeMode to count)。
    public var perModeCounts:
        [BASTurnRuntimeMode: Int]
    {
        var counts: [BASTurnRuntimeMode: Int] = [:]
        for item in items {
            counts[item.preferredMode, default: 0] += 1
        }
        return counts
    }
}

// MARK: - Ledger wire-in

extension BASEBrainHostRuntimeModeAdvisoryLedger {

    /// Snapshot the accumulated advisories as a typed
    /// BASEBrainHostRuntimeModeAdvisoryBundle ready for
    /// audit emission。 Read-only — does not mutate
    /// ledger state。 Items are in arrival order
    /// preserving M1391 semantics。
    public func snapshotAsBundle(
        bundleID: String,
        recordedAtMs: Int64
    ) -> BASEBrainHostRuntimeModeAdvisoryBundle {
        return BASEBrainHostRuntimeModeAdvisoryBundle(
            bundleID: bundleID,
            schemaVersion: "1.0.0",
            items: allAdvisories(),
            metadata: [
                "ledger-source":
                    "BASEBrainHostRuntimeModeAdvisoryLedger"
            ],
            recordedAt: Date(
                timeIntervalSince1970:
                    TimeInterval(recordedAtMs)
                    / 1000.0))
    }
}
