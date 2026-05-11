// MARK: - BASKVCacheRegistry
// chapter 四百八十二 / M1306 — actor-owned registry of
// per-session transformer KV caches。 Pairs with M1305
// BASTransformerKVCacheSession to provide the full
// cross-turn KV cache substrate surface。
//
// Hosts running multi-turn LLM inference get/put session
// caches via this registry。 Actor isolation ensures
// concurrent multi-session host access stays consistent。
//
// Invalidation:explicit-only at M1306 (matches the
// M1305 default policy)。 Tier 2 / chapter 480+ would
// add LRU eviction if memory pressure becomes a real
// concern in production deployments。
//
// chapter 五百二 / M1385 — wire-in:
// BASKVCacheInvalidationPolicy (chapter 500 M1379) now
// CONSUMED by the registry via an init parameter that
// defaults to `.explicitOnly` (preserves existing
// behavior)。 The policy field is exposed via the
// `invalidationPolicy` accessor so audit walkers can
// confirm what the host configured。
//
// HONEST SCOPE: at M1385,only `.explicitOnly` is
// implemented (matches BASKVCacheInvalidationPolicy
// Doctrine.implementedPolicies)。 Constructing the
// registry with any other policy stores the value but
// does NOT change runtime behavior — the LRU/TTL impl
// is a follow-up arc per the policy doctrine。

import Foundation
import BASRuntimeCore

/// Actor-owned registry mapping sessionID →
/// `BASTransformerKVCacheSession`。 Pure storage actor;
/// chapter 500 typed `BASKVCacheInvalidationPolicy`
/// captured at construction (default `.explicitOnly`
/// preserves M1306 behavior;LRU/TTL deferred per
/// BASKVCacheInvalidationPolicyDoctrine
/// .implementedPolicies)。
public actor BASKVCacheRegistry {

    private var sessions:
        [String: BASTransformerKVCacheSession] = [:]
    private var hitCount: Int = 0
    private var missCount: Int = 0

    /// chapter 五百二 / M1385 — typed invalidation policy
    /// captured at construction。 Currently informational
    /// only;the registry's actual invalidation behavior
    /// is gated by BASKVCacheInvalidationPolicyDoctrine
    /// .activeImplementedPolicy (which is `.explicitOnly`
    /// at chapter 502 close-out)。
    public nonisolated let invalidationPolicy:
        BASKVCacheInvalidationPolicy

    /// Backward-compatible default init — preserves
    /// chapter 482 / M1306 behavior。 The invalidation
    /// policy defaults to `.explicitOnly` matching the
    /// implemented runtime behavior。
    public init() {
        self.invalidationPolicy = .explicitOnly
    }

    /// chapter 五百二 / M1385 — typed init accepting a
    /// host-declared invalidation policy。 At chapter
    /// 502 close-out the policy is stored for audit
    /// emission but does NOT yet change runtime
    /// behavior for non-`.explicitOnly` values。
    /// Per honest scope:
    ///   - `.explicitOnly` is FULLY implemented
    ///   - `.lru` / `.ttl` / `.never` are typed contract
    ///     only — registry stores the value but invalidation
    ///     still follows `.explicitOnly` semantics until
    ///     follow-up arc wires the LRU/TTL paths
    public init(
        invalidationPolicy:
            BASKVCacheInvalidationPolicy
    ) {
        self.invalidationPolicy = invalidationPolicy
    }

    // MARK: - Lookup / store

    /// Look up the cached session for a sessionID。
    /// Records hit/miss observation。 Returns nil when
    /// no cache exists for the given session。
    public func cachedSession(
        for sessionID: String
    ) -> BASTransformerKVCacheSession? {
        if let session = sessions[sessionID] {
            hitCount += 1
            return session
        }
        missCount += 1
        return nil
    }

    /// Store (or replace) a session cache。 Hosts call
    /// this after each turn to persist new KV tokens
    /// for cross-turn reuse。
    public func storeSession(
        _ session: BASTransformerKVCacheSession
    ) {
        sessions[session.sessionID] = session
    }

    /// Append a single token cache entry at a specific
    /// layer for an existing session。 Creates the
    /// session on first call。 Convenience for the
    /// common per-token-per-layer flow。
    public func appendToken(
        _ token: BASTransformerKVCacheToken,
        atLayer layer: Int,
        sessionID: String
    ) {
        let existing = sessions[sessionID]
            ?? BASTransformerKVCacheSession(
                sessionID: sessionID)
        sessions[sessionID] = existing.appending(
            token: token, atLayer: layer)
    }

    // MARK: - Invalidation

    /// Explicit invalidate — removes the session cache
    /// for the given ID。 Used by hosts on session reset
    /// (e.g。 user context cleared)。
    public func invalidate(
        sessionID: String
    ) {
        sessions.removeValue(forKey: sessionID)
    }

    /// Invalidate ALL sessions。 Used by tests + host
    /// teardown paths。
    public func invalidateAll() {
        sessions.removeAll()
    }

    // MARK: - Observation accessors

    /// Total sessions currently cached。
    public var sessionCount: Int { sessions.count }

    /// Total cache hits since registry construction。
    public var totalHits: Int { hitCount }

    /// Total cache misses since registry construction。
    public var totalMisses: Int { missCount }

    /// Hit ratio。 Returns 0 when no lookups yet。
    public var hitRatio: Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0 }
        return Double(hitCount) / Double(total)
    }

    /// Total bytes stored across ALL sessions。 Tier 2
    /// LRU eviction policies will consult this for
    /// memory-budget enforcement。
    public var totalCachedBytes: Int {
        return sessions.values
            .reduce(0) { $0 + $1.totalCachedBytes }
    }

    /// Total cached tokens across all sessions。
    public var totalCachedTokens: Int {
        return sessions.values
            .reduce(0) { $0 + $1.totalCachedTokens }
    }
}
