// MARK: - BASKVCacheRegistryObservationSnapshot
// chapter 五百二 / M1387 — typed point-in-time snapshot
// of a BASKVCacheRegistry's state
//
// Real consumption of:
//   - M1379 BASKVCacheInvalidationPolicy (typed policy)
//   - M1385 BASKVCacheRegistry.invalidationPolicy field
//     (wire-in)
//
// The snapshot is a Codable + Equatable record suitable
// for audit emission + Codable replay。 BASKVCacheRegistry
// exposes a typed `snapshot()` actor method that returns
// the current state as one immutable value — useful for
// scheduler tuning + end-of-turn audit emission。
//
// HONEST SCOPE:snapshot is a read-only typed view。 It
// does NOT mutate registry state or affect cache
// invalidation behavior。 ADR-014 OPT-IN preserved。

import Foundation
import BASRuntimeCore

/// Typed point-in-time snapshot of a BASKVCacheRegistry
/// state。 Includes the typed invalidation policy + the
/// hit/miss/byte aggregates。
public struct BASKVCacheRegistryObservationSnapshot:
    Equatable, Hashable, Codable, Sendable
{
    public let invalidationPolicy:
        BASKVCacheInvalidationPolicy
    public let sessionCount: Int
    public let totalHits: Int
    public let totalMisses: Int
    public let totalCachedBytes: Int
    public let totalCachedTokens: Int
    public let recordedAtMs: Int64

    public init(
        invalidationPolicy:
            BASKVCacheInvalidationPolicy,
        sessionCount: Int,
        totalHits: Int,
        totalMisses: Int,
        totalCachedBytes: Int,
        totalCachedTokens: Int,
        recordedAtMs: Int64
    ) {
        self.invalidationPolicy = invalidationPolicy
        self.sessionCount = sessionCount
        self.totalHits = totalHits
        self.totalMisses = totalMisses
        self.totalCachedBytes = totalCachedBytes
        self.totalCachedTokens = totalCachedTokens
        self.recordedAtMs = recordedAtMs
    }

    /// Total lookups (hits + misses)。
    public var totalLookups: Int {
        totalHits + totalMisses
    }

    /// Hit ratio in [0, 1]。 Returns 0 when no lookups。
    public var hitRatio: Double {
        guard totalLookups > 0 else { return 0 }
        return Double(totalHits) / Double(totalLookups)
    }
}
