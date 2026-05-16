// MARK: - BASKVCacheLRUEvictor
// chapter 六百九十 / M2130 第一刀 — post-seal arc:LRU
//                                eviction policy for
//                                BASKVCacheRegistry,
//                                closing the chapter 500
//                                / M1379 LRU-deferred
//                                stretch goal。
//
// ## Why this ships post-FINAL-SEAL
//
// The wild-rolling-meerkat plan listed "LRU eviction
// policy for BASKVCacheRegistry (currently explicit-only
// invalidation)" as a stretch goal NOT in scope of the
// 46-chapter arc。 The plan formally sealed at chapter
// 689 / M2129 with 60/60 score achieved。 This chapter
// 690 ships ONE concrete stretch goal — LRU eviction —
// as post-seal follow-up arc。
//
// Post-seal arcs do NOT move directive scores (already
// at 60/60) but ship genuine production value:KV cache
// memory pressure management for hosts running long
// multi-turn LLM sessions。
//
// ## What this ships
//
// BASKVCacheLRUEvictor — pure-Swift struct holding the
// LRU eviction algorithm:
//
//   - Tracks access order via [sessionID:lastAccessTick]
//   - On capacity overflow,evicts the least-recently-
//     used session
//   - Operates on dictionary snapshots (no mutation —
//     callers apply the eviction decision separately)
//   - Pure function over inputs → deterministic eviction
//     decisions across replay
//
// Phase O bundle pattern repeated:additive struct,no
// breaking changes,no V1 byte-equality impact (existing
// .explicitOnly registry path unchanged)。

import Foundation

/// Typed eviction decision returned by the LRU evictor。
/// Names the sessionIDs to evict + which were preserved。
public struct BASKVCacheLRUEvictionDecision:
    Equatable, Hashable, Sendable, Codable
{
    /// Session IDs the host should remove (oldest first
    /// — typically `[1]` for incremental eviction,but
    /// could be `[N]` if multiple sessions exceed capacity
    /// at once after a batch insert)。
    public let evictedSessionIDs: [String]

    /// Session IDs that remain in the cache after
    /// eviction。 Always preserved。
    public let preservedSessionIDs: [String]

    /// Pre-eviction cache size (sessions count)。
    public let preEvictionSessionCount: Int

    /// Post-eviction cache size。 Equals
    /// `preservedSessionIDs.count`。 Computed for
    /// audit clarity。
    public var postEvictionSessionCount: Int {
        return preservedSessionIDs.count
    }

    /// Number of sessions evicted by this decision。
    public var evictionCount: Int {
        return evictedSessionIDs.count
    }

    public init(
        evictedSessionIDs: [String],
        preservedSessionIDs: [String],
        preEvictionSessionCount: Int
    ) {
        self.evictedSessionIDs = evictedSessionIDs
        self.preservedSessionIDs = preservedSessionIDs
        self.preEvictionSessionCount =
            preEvictionSessionCount
    }
}

/// Pure-function LRU evictor for BASKVCacheRegistry。
/// Operates on access-order dictionaries to produce
/// deterministic eviction decisions。
public enum BASKVCacheLRUEvictor {

    /// Default capacity if the host doesn't specify one
    /// at registry construction。 Chosen conservatively:
    /// 64 active sessions covers typical multi-session
    /// host deployments (e.g. 8-16 chat panes × 4
    /// retention slots) without OOM risk on M-series
    /// silicon。 Hosts with different load profiles can
    /// override via `BASKVCacheRegistry.init(capacity:)`。
    public static let defaultCapacity: Int = 64

    /// Decide which sessions to evict given:
    ///   - Current session IDs with their last-access
    ///     ticks (higher = more recent)
    ///   - Target capacity (max session count)
    ///
    /// Returns a typed decision struct。 Pure function —
    /// no side effects,deterministic given inputs。
    public static func decide(
        accessTicks: [String: Int],
        capacity: Int
    ) -> BASKVCacheLRUEvictionDecision {
        let preCount = accessTicks.count

        // No eviction needed when within capacity
        if preCount <= capacity {
            return BASKVCacheLRUEvictionDecision(
                evictedSessionIDs: [],
                preservedSessionIDs:
                    sortedByAccessTickDescending(
                        accessTicks),
                preEvictionSessionCount: preCount)
        }

        // Sort sessions by access tick ASCENDING (oldest
        // first) → those at the front are eviction
        // candidates
        let sortedAscending = accessTicks
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value < rhs.value
                }
                // Tiebreak by sessionID for determinism
                return lhs.key < rhs.key
            }
            .map { $0.key }

        let evictionCount = preCount - capacity
        let evictedIDs = Array(
            sortedAscending.prefix(evictionCount))
        let preservedIDs = Array(
            sortedAscending.dropFirst(evictionCount))

        return BASKVCacheLRUEvictionDecision(
            evictedSessionIDs: evictedIDs,
            preservedSessionIDs: preservedIDs,
            preEvictionSessionCount: preCount)
    }

    /// Helper:return sessionIDs sorted by access tick
    /// DESCENDING (most-recently-used first)。 Used when
    /// no eviction is needed but caller wants a typed
    /// ordering。
    public static func sortedByAccessTickDescending(
        _ accessTicks: [String: Int]
    ) -> [String] {
        return accessTicks
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return lhs.key < rhs.key
            }
            .map { $0.key }
    }
}
