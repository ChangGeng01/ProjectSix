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
//
// chapter 六百九十 / M2131 第二刀 (post-seal follow-up):
// the deferred LRU implementation lands。 The registry
// gains:
//   - `capacity:` init parameter (defaults to nil =
//     unlimited,preserving M1306 behavior)
//   - access-tick tracking (incremented per storeSession
//     / cachedSession call)
//   - automatic LRU eviction when capacity reached AND
//     invalidationPolicy == .lru
//
// ADR-014 OPT-IN preserved:default init still
// .explicitOnly with no capacity limit (M1306 behavior)。
// LRU only activates when host explicitly opts in via
// `init(invalidationPolicy: .lru, capacity: N)`。

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

    /// chapter 六百九十 / M2131 第二刀 — per-session
    /// access-tick tracking for LRU eviction。 Incremented
    /// monotonically on each cachedSession / storeSession
    /// / appendToken call。 Used by the LRU evictor to
    /// determine which sessions are least-recently-used。
    private var accessTicks: [String: Int] = [:]
    private var nextAccessTick: Int = 1

    /// chapter 六百九十 / M2131 第二刀 — LRU eviction
    /// counter (audit observation)。 Bumped each time the
    /// registry evicts at least one session via LRU policy。
    private var lruEvictionCount: Int = 0

    /// chapter 五百二 / M1385 — typed invalidation policy
    /// captured at construction。
    public nonisolated let invalidationPolicy:
        BASKVCacheInvalidationPolicy

    /// chapter 六百九十 / M2131 第二刀 — capacity limit
    /// for LRU eviction。 nil = unlimited (M1306 behavior)。
    /// When invalidationPolicy == .lru AND capacity != nil,
    /// the registry consults BASKVCacheLRUEvictor after
    /// each storeSession / appendToken to enforce the
    /// capacity bound。
    public nonisolated let capacity: Int?

    /// chapter 六百九十一 / M2135 第二刀 — TTL window in
    /// milliseconds for the .ttl policy。 nil = no TTL
    /// (M1306 behavior preserved for non-.ttl policies)。
    /// When invalidationPolicy == .ttl AND ttlMs != nil,
    /// the registry consults BASKVCacheTTLEvictor on
    /// each storeSession / cachedSession / appendToken
    /// to lazily evict expired sessions。
    public nonisolated let ttlMs: Int64?

    /// chapter 六百九十一 / M2135 第二刀 — per-session
    /// timestamps for TTL eviction。 Updated on each
    /// access when invalidationPolicy == .ttl。
    private var timestamps: [String: Int64] = [:]

    /// chapter 六百九十一 / M2135 第二刀 — TTL eviction
    /// counter (audit observation)。 Bumped each time
    /// the registry evicts at least one session via
    /// TTL policy。
    private var ttlEvictionCount: Int = 0

    /// chapter 六百九十一 / M2135 第二刀 — Sendable clock
    /// for TTL timestamps。 Defaults to system clock
    /// (Date()) but can be overridden at construction
    /// for replay-deterministic tests。 Pure function;
    /// no side effects beyond reading wall-clock time。
    public typealias ClockMillisProvider =
        @Sendable () -> Int64
    private let clockMillisProvider:
        ClockMillisProvider

    /// Backward-compatible default init — preserves
    /// chapter 482 / M1306 behavior。 The invalidation
    /// policy defaults to `.explicitOnly` matching the
    /// implemented runtime behavior。
    public init() {
        self.invalidationPolicy = .explicitOnly
        self.capacity = nil
        self.ttlMs = nil
        self.clockMillisProvider =
            BASKVCacheRegistry.defaultClockMillisProvider
    }

    /// chapter 五百二 / M1385 — typed init accepting a
    /// host-declared invalidation policy。
    public init(
        invalidationPolicy:
            BASKVCacheInvalidationPolicy
    ) {
        self.invalidationPolicy = invalidationPolicy
        self.capacity = nil
        self.ttlMs = nil
        self.clockMillisProvider =
            BASKVCacheRegistry.defaultClockMillisProvider
    }

    /// chapter 六百九十 / M2131 第二刀 — typed init
    /// accepting BOTH policy AND capacity (LRU path)。
    public init(
        invalidationPolicy:
            BASKVCacheInvalidationPolicy,
        capacity: Int?
    ) {
        self.invalidationPolicy = invalidationPolicy
        self.capacity = capacity
        self.ttlMs = nil
        self.clockMillisProvider =
            BASKVCacheRegistry.defaultClockMillisProvider
    }

    /// chapter 六百九十一 / M2135 第二刀 — typed init
    /// accepting policy + capacity + TTL + clock。 When
    /// `invalidationPolicy == .ttl` AND `ttlMs != nil`,
    /// the registry lazily evicts expired sessions on
    /// each access。 The clock provider defaults to the
    /// system clock but can be overridden for replay-
    /// deterministic tests。
    ///
    /// Honest scope at M2135:
    ///   - `.lru` + capacity: FULLY implemented (M2131)
    ///   - `.ttl` + ttlMs:    FULLY implemented (this)
    ///   - `.explicitOnly`:    M1306 behavior preserved
    ///   - `.never`:           semantically equivalent
    ///     to `.explicitOnly` (no auto-eviction);typed
    ///     surface for hosts that want explicit "never
    ///     touch this cache" intent
    public init(
        invalidationPolicy:
            BASKVCacheInvalidationPolicy,
        capacity: Int? = nil,
        ttlMs: Int64? = nil,
        clockMillisProvider:
            ClockMillisProvider? = nil
    ) {
        self.invalidationPolicy = invalidationPolicy
        self.capacity = capacity
        self.ttlMs = ttlMs
        self.clockMillisProvider = clockMillisProvider
            ?? BASKVCacheRegistry
                .defaultClockMillisProvider
    }

    /// Default clock provider — reads system wall-clock
    /// in milliseconds since the unix epoch。 Sendable
    /// closure so it crosses actor boundaries cleanly。
    public static let defaultClockMillisProvider:
        ClockMillisProvider = {
        @Sendable () -> Int64 in
        return Int64(
            Date().timeIntervalSince1970 * 1000)
    }

    // MARK: - Lookup / store

    /// Look up the cached session for a sessionID。
    /// Records hit/miss observation。 Returns nil when
    /// no cache exists for the given session。
    ///
    /// chapter 六百九十 / M2131:bumps the per-session
    /// access tick when LRU policy is active (so future
    /// eviction decisions reflect this access)。
    public func cachedSession(
        for sessionID: String
    ) -> BASTransformerKVCacheSession? {
        // chapter 六百九十一 / M2135:lazy TTL sweep on
        // access — evict any stale sessions BEFORE
        // returning the requested session。
        if invalidationPolicy == .ttl {
            enforceTTLIfNeeded()
        }
        if let session = sessions[sessionID] {
            hitCount += 1
            if invalidationPolicy == .lru {
                accessTicks[sessionID] = nextAccessTick
                nextAccessTick += 1
            } else if invalidationPolicy == .ttl {
                timestamps[sessionID] =
                    clockMillisProvider()
            }
            return session
        }
        missCount += 1
        return nil
    }

    /// Store (or replace) a session cache。 Hosts call
    /// this after each turn to persist new KV tokens
    /// for cross-turn reuse。
    ///
    /// chapter 六百九十 / M2131:when invalidationPolicy
    /// is `.lru` AND capacity is set,evicts LRU sessions
    /// after the store to enforce the capacity bound。
    /// chapter 六百九十一 / M2135:when policy is `.ttl`,
    /// records the per-session timestamp + lazily evicts
    /// expired sessions。
    public func storeSession(
        _ session: BASTransformerKVCacheSession
    ) {
        sessions[session.sessionID] = session
        if invalidationPolicy == .lru {
            accessTicks[session.sessionID] = nextAccessTick
            nextAccessTick += 1
            enforceLRUCapacityIfNeeded()
        } else if invalidationPolicy == .ttl {
            timestamps[session.sessionID] =
                clockMillisProvider()
            enforceTTLIfNeeded()
        }
    }

    /// Append a single token cache entry at a specific
    /// layer for an existing session。 Creates the
    /// session on first call。 Convenience for the
    /// common per-token-per-layer flow。
    ///
    /// chapter 六百九十 / M2131:bumps the access tick
    /// and triggers LRU enforcement when applicable。
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
        if invalidationPolicy == .lru {
            accessTicks[sessionID] = nextAccessTick
            nextAccessTick += 1
            enforceLRUCapacityIfNeeded()
        } else if invalidationPolicy == .ttl {
            timestamps[sessionID] = clockMillisProvider()
            enforceTTLIfNeeded()
        }
    }

    // MARK: - TTL enforcement (chapter 六百九十一 / M2135)

    /// Internal helper:consult BASKVCacheTTLEvictor +
    /// apply the eviction decision when policy is .ttl
    /// and ttlMs is set。 No-op when ttlMs is nil。
    private func enforceTTLIfNeeded() {
        guard let ttl = ttlMs else { return }
        let now = clockMillisProvider()
        let decision = BASKVCacheTTLEvictor.decide(
            timestamps: timestamps,
            nowMs: now,
            ttlMs: ttl)
        guard decision.evictionCount > 0 else { return }
        for evictedID in decision.evictedSessionIDs {
            sessions.removeValue(forKey: evictedID)
            timestamps.removeValue(forKey: evictedID)
        }
        ttlEvictionCount += decision.evictionCount
    }

    // MARK: - LRU enforcement (chapter 六百九十 / M2131)

    /// Internal helper:consult BASKVCacheLRUEvictor +
    /// apply the eviction decision when capacity is set
    /// and exceeded。 No-op when capacity is nil or
    /// session count is within bounds。
    private func enforceLRUCapacityIfNeeded() {
        guard let cap = capacity, sessions.count > cap
        else { return }
        let decision = BASKVCacheLRUEvictor.decide(
            accessTicks: accessTicks,
            capacity: cap)
        guard decision.evictionCount > 0 else { return }
        for evictedID in decision.evictedSessionIDs {
            sessions.removeValue(forKey: evictedID)
            accessTicks.removeValue(forKey: evictedID)
        }
        lruEvictionCount += decision.evictionCount
    }

    // MARK: - Invalidation

    /// Explicit invalidate — removes the session cache
    /// for the given ID。 Used by hosts on session reset
    /// (e.g。 user context cleared)。
    public func invalidate(
        sessionID: String
    ) {
        sessions.removeValue(forKey: sessionID)
        accessTicks.removeValue(forKey: sessionID)
        timestamps.removeValue(forKey: sessionID)
    }

    /// Invalidate ALL sessions。 Used by tests + host
    /// teardown paths。
    public func invalidateAll() {
        sessions.removeAll()
        accessTicks.removeAll()
        timestamps.removeAll()
    }

    /// chapter 六百九十 / M2131 — total LRU evictions
    /// performed since registry construction。 Audit
    /// observation surface。 Always 0 when invalidation
    /// policy != .lru。
    public var totalLRUEvictions: Int {
        return lruEvictionCount
    }

    /// chapter 六百九十一 / M2135 — total TTL evictions
    /// performed since registry construction。 Audit
    /// observation surface。 Always 0 when invalidation
    /// policy != .ttl。
    public var totalTTLEvictions: Int {
        return ttlEvictionCount
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

    // MARK: - chapter 五百二 / M1387 — typed snapshot

    /// Capture a typed point-in-time observation of the
    /// registry's current state。 Real consumption of the
    /// M1385 invalidationPolicy wire-in + M1379 policy
    /// enum。 Suitable for audit emission + Codable
    /// replay。
    ///
    /// Honest scope:read-only。 No state mutation,no
    /// invalidation triggered。 ADR-014 OPT-IN preserved。
    public func snapshot(
        recordedAtMs: Int64
    ) -> BASKVCacheRegistryObservationSnapshot {
        return BASKVCacheRegistryObservationSnapshot(
            invalidationPolicy: invalidationPolicy,
            sessionCount: sessions.count,
            totalHits: hitCount,
            totalMisses: missCount,
            totalCachedBytes: sessions.values
                .reduce(0) { $0 + $1.totalCachedBytes },
            totalCachedTokens: sessions.values
                .reduce(0) { $0 + $1.totalCachedTokens },
            recordedAtMs: recordedAtMs)
    }
}
