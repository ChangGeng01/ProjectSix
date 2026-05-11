// MARK: - BASKVCacheInvalidationPolicy
// chapter 五百 / M1379 — typed KV cache invalidation
// policy surface
//
// The BASKVCacheRegistry (chapter 490 / M1337) shipped
// with `explicit-only` invalidation per the original
// plan (no LRU,no TTL — explicit per-session reset)。
// This typed policy enum names the 4 invalidation
// strategies a host can request,WITHOUT requiring the
// registry to implement all 4 today。
//
// 最创新 substantive push:typed policy surface lets
// audit walkers + future LRU/TTL implementations
// reference a stable contract from chapter 500 onward。
//
// HONEST DOCTRINE NOTE — chapter 五百:
// =============================================================
// At chapter 500 close-out:
//   - `.explicitOnly` is fully implemented (chapter 490)
//   - `.lru`, `.ttl`, `.never` are typed contract only;
//     not yet wired into BASKVCacheRegistry
//
// The policy enum is shipped FIRST so future
// implementation arcs have a stable target。 ADR-014
// OPT-IN compliance preserved — registry's current
// behavior (.explicitOnly) is unchanged。
//
// V1 byte-equality preserved — purely additive typed
// surface;no runtime behavior change at chapter 500
// close-out。

import Foundation

/// Typed invalidation policy for cross-turn KV cache
/// entries。 Names the 4 strategies a host can request。
public enum BASKVCacheInvalidationPolicy:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{

    /// Cache entries persist until explicitly removed via
    /// `BASKVCacheRegistry.remove(sessionID:)` or
    /// `BASKVCacheRegistry.removeAll()`。 Default at
    /// chapter 490 / M1337。 SHIPPED + IMPLEMENTED。
    case explicitOnly = "explicit-only"

    /// Cache entries evicted least-recently-used when
    /// the cache exceeds capacity。 NOT yet implemented
    /// at chapter 500 close-out — typed contract only。
    case lru = "lru"

    /// Cache entries expire after a time-to-live elapses。
    /// NOT yet implemented — typed contract only。
    case ttl = "ttl"

    /// Cache entries never invalidated (caller manages
    /// session lifecycle elsewhere)。 NOT yet wired —
    /// `.explicitOnly` is the implemented zero-config
    /// equivalent。 Typed contract only。
    case never = "never"
}

// MARK: - BASKVCacheInvalidationPolicyDoctrine

/// Doctrine namespace declaring which policies the
/// substrate actually implements + honest evidence
/// for the gap to full 4-policy coverage。
public enum BASKVCacheInvalidationPolicyDoctrine {

    /// The policy actually wired into BASKVCacheRegistry
    /// at chapter 500 close-out。 ALWAYS `.explicitOnly`。
    public static let activeImplementedPolicy:
        BASKVCacheInvalidationPolicy = .explicitOnly

    /// Set of policies the substrate currently honors。
    /// At chapter 500 close-out:only `.explicitOnly`。
    public static let implementedPolicies:
        Set<BASKVCacheInvalidationPolicy> = [
        .explicitOnly,
    ]

    /// Set of policies whose typed contract is shipped
    /// but implementation is deferred。
    public static let contractOnlyPolicies:
        Set<BASKVCacheInvalidationPolicy> = [
        .lru,
        .ttl,
        .never,
    ]

    /// Indicates whether the given policy is implemented
    /// at chapter 500 close-out。
    public static func isImplemented(
        _ policy: BASKVCacheInvalidationPolicy
    ) -> Bool {
        implementedPolicies.contains(policy)
    }

    /// Honest deferral evidence per non-implemented
    /// policy (suitable for audit emission)。
    public static func deferralEvidence(
        for policy: BASKVCacheInvalidationPolicy
    ) -> String? {
        switch policy {
        case .explicitOnly:
            return nil
        case .lru:
            return "lru:typed contract only;requires" +
                " capacity tracking + sorted access-order" +
                " state in BASKVCacheRegistry actor" +
                " (follow-up arc)"
        case .ttl:
            return "ttl:typed contract only;requires" +
                " per-entry timestamp + periodic sweep" +
                " task (follow-up arc)"
        case .never:
            return "never:typed contract only;identical" +
                " to .explicitOnly absent host eviction" +
                " hooks (follow-up arc)"
        }
    }
}
