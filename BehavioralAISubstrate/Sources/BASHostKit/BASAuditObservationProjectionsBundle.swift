// MARK: - BASAuditObservationProjectionsBundle
// chapter 五百十二 / M1427 — 12th BASBundle<Item> adoption
//
// Wraps the M1425 BASAuditObservationProjectionsBundle
// Observation as a BASBundle Item so hosts replaying N
// turns get a typed Codable batch surface for audit
// walker consumption。
//
// ## Why this exists
//
// Chapter 512 closes the wire-in chain for the chapter
// 511 projection blocks:
//
//   1. M1425 typed per-turn observation record ✓
//   2. M1426 actor accumulator ✓
//   3. M1427 (this file) BASBundle<Item> typealias
//   4. M1428 close-out + doctrine sync
//
// The observer's `snapshot()` returns
// `[BASAuditObservationProjectionsBundleObservation]`;
// callers wrap it in this typed bundle (or call the
// extension's `snapshotAsBundle()` factory) to obtain
// a Codable / Hashable / Sendable typed batch suitable
// for:
//
//   - Multi-turn replay reconstruction
//   - Cross-host audit walker consumption
//   - Event-log persistence as a single typed item
//   - Doctrine-bench aggregation queries
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface — old observer snapshot
//     API still returns the raw array
//   - chapter 三百九二:replay-determinism via Codable +
//     Hashable + sortedKeys-friendly fields
//   - chapter 四百二十九:typed-surface count 57 → 58
//   - 12th BASBundle<Item> adoption (11 → 12)
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1426 → M1427

import Foundation
import BASRuntimeCore

/// 12th REAL `BASBundle<Item>` typealias migration — batch
/// of N per-turn projection-block emission observations
/// for multi-turn replay / inspection。
public typealias BASAuditObservationProjectionsBundle =
    BASBundle<BASAuditObservationProjectionsBundleObservation>

// MARK: - Bundle-side coverage rollups

extension BASBundle
    where
    Item ==
        BASAuditObservationProjectionsBundleObservation
{

    /// Count of items where both blocks fired。 Useful
    /// for "how many turns had full audit-projection
    /// coverage in this replay?" audit rollups。
    public var fullyCoveredTurnCount: Int {
        items.filter(\.hasBothBlocks).count
    }

    /// Count of items where neither block fired — host
    /// bypassed both convenience inits on those turns。
    public var coldTurnCount: Int {
        items.filter(\.hasNoBlocks).count
    }

    /// Fully-covered ratio in [0, 1]。 Zero when bundle
    /// empty。
    public var fullyCoveredTurnRatio: Double {
        guard !items.isEmpty else { return 0 }
        return Double(fullyCoveredTurnCount)
            / Double(items.count)
    }

    /// Sum of populated-block counts across all items
    /// (each fullyCovered = +2,each partial = +1,
    /// each uncovered = +0)。
    public var cumulativePopulatedBlockCount: Int {
        items.reduce(0) {
            $0 + $1.populatedBlockCount
        }
    }

    /// Distinct turn IDs in the bundle。 Hosts that emit
    /// one record per turn expect this to equal
    /// `items.count`。
    public var distinctTurnCount: Int {
        Set(items.map(\.turnID)).count
    }

    /// Items whose `kunlunCovered` is true,in arrival
    /// order。
    public var kunlunCoveredItems: [Item] {
        items.filter(\.kunlunCovered)
    }

    /// Items whose `cthulhuCovered` is true,in arrival
    /// order。
    public var cthulhuCoveredItems: [Item] {
        items.filter(\.cthulhuCovered)
    }
}

// MARK: - Observer-to-bundle bridge

extension BASAuditObservationProjectionsBundleObserver {

    /// Snapshot the observer's current records as a
    /// typed `BASAuditObservationProjectionsBundle`。
    /// Convenience for callers that want the typed batch
    /// surface directly without spelling the typealias
    /// at the call site。 Delegates to `snapshot()` (the
    /// canonical actor-isolated read path) and wraps the
    /// array in the BASBundle init。
    public func snapshotAsBundle()
        -> BASAuditObservationProjectionsBundle
    {
        return BASAuditObservationProjectionsBundle(
            items: snapshot())
    }
}
