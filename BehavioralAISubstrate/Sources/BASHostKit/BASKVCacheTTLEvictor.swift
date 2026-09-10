// MARK: - BASKVCacheTTLEvictor
// chapter 六百九十一 / M2134 第一刀 — second post-FINAL-
//                                  SEAL follow-up arc:
//                                  TTL eviction policy
//                                  for BASKVCacheRegistry,
//                                  closing the chapter 500
//                                  / M1379 TTL-deferred
//                                  gap alongside the M2130
//                                  LRU implementation。
//
// ## Why TTL ships now
//
// Chapter 690 / M2130-M2133 closed the LRU branch of the
// chapter 500 4-policy contract。 TTL was the SECOND
// deferred policy。 This chapter 691 closes it,getting
// the substrate to 3-of-4 policies implemented
// (.explicitOnly + .lru + .ttl;.never is semantic-only)。
//
// ## Algorithm
//
// TTL eviction is straightforward:given per-session
// timestamps + current time + TTL window,evict every
// session whose timestamp + TTL < now。 Lazy sweep on
// access (no background tasks)。
//
// Pure function over inputs → deterministic decisions
// suitable for replay-determinism doctrine。

import Foundation

/// Typed eviction decision returned by the TTL evictor。
public struct BASKVCacheTTLEvictionDecision:
    Equatable, Hashable, Sendable, Codable
{
    /// Session IDs to evict (timestamp + ttl < now)。
    public let evictedSessionIDs: [String]

    /// Session IDs that remain in the cache。
    public let preservedSessionIDs: [String]

    /// Pre-eviction cache size。
    public let preEvictionSessionCount: Int

    /// Post-eviction cache size。
    public var postEvictionSessionCount: Int {
        return preservedSessionIDs.count
    }

    /// Number of sessions evicted by this decision。
    public var evictionCount: Int {
        return evictedSessionIDs.count
    }

    /// Time (ms) used as "now" for the decision。 Pinned
    /// in the decision for replay-determinism。
    public let nowMs: Int64

    /// TTL window in milliseconds used for the decision。
    public let ttlMs: Int64

    public init(
        evictedSessionIDs: [String],
        preservedSessionIDs: [String],
        preEvictionSessionCount: Int,
        nowMs: Int64,
        ttlMs: Int64
    ) {
        self.evictedSessionIDs = evictedSessionIDs
        self.preservedSessionIDs = preservedSessionIDs
        self.preEvictionSessionCount =
            preEvictionSessionCount
        self.nowMs = nowMs
        self.ttlMs = ttlMs
    }
}

/// Pure-function TTL evictor for BASKVCacheRegistry。
/// Operates on timestamp dictionaries to produce
/// deterministic eviction decisions for replay-stable
/// tests。
public enum BASKVCacheTTLEvictor {

    /// Default TTL window if the host doesn't specify
    /// one。 5 minutes (300 seconds = 300_000 ms) —
    /// reasonable for typical multi-turn LLM sessions
    /// where idle sessions can be purged after a few
    /// minutes without disrupting active flows。
    public static let defaultTtlMs: Int64 = 300_000

    /// Decide which sessions to evict given:
    ///   - Session timestamps (last-access in ms)
    ///   - Current "now" time in ms
    ///   - TTL window in ms
    ///
    /// A session is evicted iff (timestamp + ttlMs) <
    /// nowMs。 Equivalently:age = nowMs - timestamp > ttlMs。
    /// Pure function — no side effects,deterministic
    /// given inputs。 Preserved list ordered by timestamp
    /// DESCENDING (most-recent first) with sessionID
    /// alphabetical tiebreak。
    public static func decide(
        timestamps: [String: Int64],
        nowMs: Int64,
        ttlMs: Int64
    ) -> BASKVCacheTTLEvictionDecision {
        var evicted: [String] = []
        var preserved: [(id: String, ts: Int64)] = []

        for (id, ts) in timestamps {
            let age = nowMs - ts
            if age > ttlMs {
                evicted.append(id)
            } else {
                preserved.append((id, ts))
            }
        }

        // Sort evicted list by oldest-first (lowest
        // timestamp first) with alphabetical tiebreak
        evicted.sort {
            let lhsTs = timestamps[$0] ?? .min
            let rhsTs = timestamps[$1] ?? .min
            if lhsTs != rhsTs {
                return lhsTs < rhsTs
            }
            return $0 < $1
        }

        // Sort preserved list by newest-first
        preserved.sort {
            if $0.ts != $1.ts {
                return $0.ts > $1.ts
            }
            return $0.id < $1.id
        }

        return BASKVCacheTTLEvictionDecision(
            evictedSessionIDs: evicted,
            preservedSessionIDs: preserved.map(\.id),
            preEvictionSessionCount: timestamps.count,
            nowMs: nowMs,
            ttlMs: ttlMs)
    }

    /// Helper:check if a single session is expired
    /// per TTL bounds。 Convenience for one-off checks。
    public static func isExpired(
        timestamp: Int64,
        nowMs: Int64,
        ttlMs: Int64
    ) -> Bool {
        return (nowMs - timestamp) > ttlMs
    }
}
