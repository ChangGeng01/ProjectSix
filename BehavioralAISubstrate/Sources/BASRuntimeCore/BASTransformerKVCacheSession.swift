// MARK: - BASTransformerKVCacheSession
// chapter 四百八十二 / M1305 — jumps from Phase D sprawl
// migrations (now at 5-of-5 primitive coverage) directly
// to Phase G KV cache surface。 Highest-leverage remaining
// substrate work per chapter 477 deep-review (closes the
// "cross-turn KV cache none" gap on 最创新 directive)。
//
// Before M1305:substrate had NO surface for cross-turn
// transformer KV state。 Hosts running multi-turn LLM
// inference re-computed key/value tensors from scratch
// every turn — wasted compute + battery。
//
// M1305 ships the typed session surface。 M1306 ships
// the actor-owned registry that manages per-session
// caches。 M1307 closes chapter 482。
//
// ## What this ships
//
//   - `BASTransformerKVCacheLayerKey` — typed layer
//     identifier (sessionID + layerIndex)
//   - `BASTransformerKVCacheToken` — typed token cache
//     entry (per-layer key/value byte payloads)
//   - `BASTransformerKVCacheSession` — typed session
//     struct holding per-layer caches + token offset
//   - `BASTransformerKVCacheInvalidationPolicy` — typed
//     invalidation enum (explicit-only at M1305;LRU
//     deferred per chapter 477 plan stretch goal)

import Foundation

/// Typed layer identifier — pins a KV cache entry to a
/// specific session + transformer layer index。
public struct BASTransformerKVCacheLayerKey:
    Equatable, Hashable, Codable, Sendable
{
    public let sessionID: String
    public let layerIndex: Int

    public init(
        sessionID: String,
        layerIndex: Int
    ) {
        self.sessionID = sessionID
        self.layerIndex = layerIndex
    }
}

/// Typed token cache entry。 Per-layer key + value byte
/// payloads + element count for fast size queries。
public struct BASTransformerKVCacheToken:
    Equatable, Hashable, Codable, Sendable
{
    /// Raw bytes of the key tensor at this token offset。
    /// Shape = [headDim] per layer head。
    public let keyBytes: Data

    /// Raw bytes of the value tensor at this token offset。
    public let valueBytes: Data

    /// Element count (keyBytes.count / 4 for Float32)。
    /// Pinned for byte-count cross-check。
    public let elementCount: Int

    public init(
        keyBytes: Data,
        valueBytes: Data,
        elementCount: Int
    ) {
        self.keyBytes = keyBytes
        self.valueBytes = valueBytes
        self.elementCount = elementCount
    }
}

/// Typed invalidation policy enum。 chapter 477 plan
/// note:"ship with explicit-only invalidation (no LRU)
/// in M1336;LRU added in follow-up Tier 2 phase if
/// needed"。
public enum BASTransformerKVCacheInvalidationPolicy:
    String, Codable, Equatable, Hashable, Sendable,
    CaseIterable
{
    /// Cache entries persist until explicitly removed
    /// via `invalidate()` or session ends。
    case explicitOnly = "explicit-only"

    /// Cache entries evicted when total cached tokens
    /// exceeds `maxCachedTokens` (LRU)。 Reserved for
    /// Tier 2 — not implemented at M1305。
    case lruByTokenCount = "lru-by-token-count"

    /// Cache entries evicted when memory footprint
    /// exceeds `maxBytes`。 Reserved for Tier 2。
    case lruByMemoryBytes = "lru-by-memory-bytes"
}

/// Typed session struct holding per-layer KV caches +
/// token offset + invalidation policy。
public struct BASTransformerKVCacheSession:
    Equatable, Hashable, Codable, Sendable
{

    /// Session identifier (cross-turn correlation)。
    public let sessionID: String

    /// Per-layer cached tokens。 Outer dict keyed by
    /// layer index;inner array indexed by token
    /// position (0-based)。
    public let tokensByLayer: [Int: [BASTransformerKVCacheToken]]

    /// Current token offset (highest cached token
    /// position + 1)。 Equivalent to
    /// `tokensByLayer[0]?.count ?? 0` for non-empty
    /// caches where layer 0 always exists。
    public let tokenOffset: Int

    /// Invalidation policy。 Pinned at session creation;
    /// changing policy requires building a new session。
    public let invalidationPolicy:
        BASTransformerKVCacheInvalidationPolicy

    public init(
        sessionID: String,
        tokensByLayer:
            [Int: [BASTransformerKVCacheToken]] = [:],
        tokenOffset: Int = 0,
        invalidationPolicy:
            BASTransformerKVCacheInvalidationPolicy =
            .explicitOnly
    ) {
        self.sessionID = sessionID
        self.tokensByLayer = tokensByLayer
        self.tokenOffset = tokenOffset
        self.invalidationPolicy = invalidationPolicy
    }

    // MARK: - Pure builders

    /// Append a token cache entry at the given layer。
    /// Returns a new session value (immutable update)。
    public func appending(
        token: BASTransformerKVCacheToken,
        atLayer layer: Int
    ) -> BASTransformerKVCacheSession {
        var layers = tokensByLayer
        var tokens = layers[layer] ?? []
        tokens.append(token)
        layers[layer] = tokens
        let newOffset = max(
            tokenOffset, tokens.count)
        return BASTransformerKVCacheSession(
            sessionID: sessionID,
            tokensByLayer: layers,
            tokenOffset: newOffset,
            invalidationPolicy: invalidationPolicy)
    }

    /// Total cached token count summed across all
    /// layers。 Used by Tier 2 LRU eviction policies。
    public var totalCachedTokens: Int {
        return tokensByLayer.values
            .reduce(0) { $0 + $1.count }
    }

    /// Total bytes stored across all layer caches。
    public var totalCachedBytes: Int {
        var total = 0
        for tokens in tokensByLayer.values {
            for token in tokens {
                total += token.keyBytes.count
                total += token.valueBytes.count
            }
        }
        return total
    }
}
