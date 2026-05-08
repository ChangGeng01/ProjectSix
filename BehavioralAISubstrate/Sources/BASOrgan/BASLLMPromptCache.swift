// MARK: - BASLLMPromptCache — chapter 四百一 / M937
//
// Phase C step 2 of the LLM Extraction Engine MVP per user
// vision §9 ("榨干缓存和复用"): typed substrate-side prompt
// cache that splits requests into stable prefix + dynamic
// suffix, enabling cross-call reuse of the prefix's
// computation (matches Anthropic's prompt-caching pattern +
// OpenAI's automatic caching guidance)。
//
// User vision §9 pin:
//
// > LLM 很贵,长上下文很贵,复杂系统 prompt 很贵。
// > Anthropic prompt caching 文档说明工具定义、system
// > message、文本消息可缓存;OpenAI 建议把稳定内容放前面,
// > 把动态用户上下文放后面。
//
// ## What this ships
//
// In-process cache keyed by the stable-prefix HASH。Stores
// completed `BASOrganDraft` results for re-serving on
// identical (prefix + suffix) pairs。Telemetry distinguishes
// HIT (full match) / PARTIAL (prefix matched, suffix differed,
// caller can use the cached prefix-token-count for cost
// estimation) / MISS (no entry)。
//
// ## What this does NOT ship
//
//   - Vendor-side prompt cache APIs (Anthropic's or OpenAI's
//     server-side caching) — those are wire-protocol concerns
//     handled by the adapter
//   - Persistent cache across sessions (this is in-process
//     only;hosts that want SQLite persistence wrap the
//     actor)
//   - LRU eviction (FIFO eviction at `maxEntries` cap by
//     default — chapter 一百八十五 anti-magic-number cap)
//
// ## Composition with M932 engine
//
// Hosts wrap their `BASOrganAdapter` in a typed
// `BASLLMPromptCachingAdapter` (subclass / decorator) that
// consults the cache before delegating。No M932 engine
// modification required — it's just a smarter adapter。
//
// ## Doctrine pins held
//
// - 不变量 #1/#2/#3 — cache is observation
// - 红线 7 hint-only — cached drafts are HINTS;hosts gate
//   downstream
// - chapter 二百一一 single-source-of-truth — ONE typed
//   cache shape
// - chapter 一百八十五 anti-magic-number — eviction cap +
//   prefix-split heuristic named typed
// - chapter 三百九二 (M892) replay-determinism — same
//   prefix + same suffix → same cache key → same cached
//   draft

import Foundation
import BASRuntimeCore

// MARK: - Cache key

/// Typed Codable key for one cache lookup。Combines the
/// stable-prefix hash + the dynamic-suffix hash so a
/// match-prefix-but-differ-suffix lookup produces a typed
/// PARTIAL outcome rather than a full miss (caller can
/// surface "cached the system prompt but not the user
/// turn")。
public struct BASLLMPromptCacheKey:
    Codable, Equatable, Sendable, Hashable
{
    public let prefixHash: UInt64
    public let suffixHash: UInt64

    public init(
        prefixHash: UInt64,
        suffixHash: UInt64
    ) {
        self.prefixHash = prefixHash
        self.suffixHash = suffixHash
    }
}

// MARK: - Cache outcome

/// Typed enum of cache lookup results。Telemetry-class —
/// hosts surface in observability。
public enum BASLLMPromptCacheOutcome:
    Sendable, Equatable
{
    case miss
    /// Prefix matched, suffix did not — caller can re-issue
    /// the request but knows the prefix has been seen
    /// before (cost-estimation hint)。
    case partial(prefixHash: UInt64)
    case hit(draft: BASOrganDraft)

    public var isHit: Bool {
        if case .hit = self { return true }
        return false
    }
}

// MARK: - Cache entry

private struct BASLLMPromptCacheEntry: Sendable {
    let key: BASLLMPromptCacheKey
    let draft: BASOrganDraft
    let cachedAtMs: Int64
}

// MARK: - Cache actor

/// In-process LRU-style prompt cache。Single-writer actor。
public actor BASLLMPromptCache {

    /// chapter 一百八十五 anti-magic-number — default cap
    /// matches typical iPhone session memory budget
    /// (~100 cached drafts ≈ 100KB-1MB depending on draft
    /// body size)。
    public static let defaultMaxEntries: Int = 100

    private let maxEntries: Int
    private var entries: [BASLLMPromptCacheEntry] = []
    /// Index from key → array offset for O(1) lookup。
    private var keyIndex:
        [BASLLMPromptCacheKey: Int] = [:]
    /// Index from prefixHash → set of full keys (for
    /// PARTIAL outcome detection)。
    private var prefixIndex: [UInt64:
        Set<BASLLMPromptCacheKey>] = [:]

    private(set) var totalLookups: Int = 0
    private(set) var totalHits: Int = 0
    private(set) var totalPartials: Int = 0
    private(set) var totalMisses: Int = 0

    public init(
        maxEntries: Int =
            BASLLMPromptCache.defaultMaxEntries
    ) {
        precondition(maxEntries > 0,
            "maxEntries must be > 0")
        self.maxEntries = maxEntries
    }

    // MARK: - Lookup

    /// Lookup by typed key。Returns typed outcome。
    public func lookup(
        key: BASLLMPromptCacheKey
    ) -> BASLLMPromptCacheOutcome {
        totalLookups += 1
        if let idx = keyIndex[key] {
            totalHits += 1
            return .hit(draft: entries[idx].draft)
        }
        if prefixIndex[key.prefixHash] != nil {
            totalPartials += 1
            return .partial(prefixHash: key.prefixHash)
        }
        totalMisses += 1
        return .miss
    }

    // MARK: - Insert

    /// Insert a (key, draft) pair。Evicts the oldest entry
    /// when the cache is at cap (FIFO)。Calling with the
    /// same key replaces the existing entry。
    public func insert(
        key: BASLLMPromptCacheKey,
        draft: BASOrganDraft,
        cachedAtMs: Int64
    ) {
        // If key already present, replace
        if let idx = keyIndex[key] {
            entries[idx] = BASLLMPromptCacheEntry(
                key: key,
                draft: draft,
                cachedAtMs: cachedAtMs)
            return
        }
        // Evict if at cap (FIFO — oldest = entries.first)
        if entries.count >= maxEntries {
            let evicted = entries.removeFirst()
            removeFromIndices(evicted.key)
            // Reindex remaining entries (offsets shifted)
            rebuildKeyIndex()
        }
        let entry = BASLLMPromptCacheEntry(
            key: key, draft: draft,
            cachedAtMs: cachedAtMs)
        let newIdx = entries.count
        entries.append(entry)
        keyIndex[key] = newIdx
        prefixIndex[key.prefixHash, default: []]
            .insert(key)
    }

    // MARK: - Hit ratio

    /// Cache hit ratio in [0, 1]。Returns 0 when no lookups
    /// have happened。
    public var hitRatio: Double {
        guard totalLookups > 0 else { return 0 }
        return Double(totalHits) / Double(totalLookups)
    }

    // MARK: - Reset

    /// Clear all entries + zero telemetry。Useful for tests
    /// and per-session re-init。
    public func reset() {
        entries.removeAll()
        keyIndex.removeAll()
        prefixIndex.removeAll()
        totalLookups = 0
        totalHits = 0
        totalPartials = 0
        totalMisses = 0
    }

    // MARK: - Private helpers

    private func removeFromIndices(
        _ key: BASLLMPromptCacheKey
    ) {
        keyIndex[key] = nil
        prefixIndex[key.prefixHash]?.remove(key)
        if prefixIndex[key.prefixHash]?.isEmpty == true {
            prefixIndex.removeValue(
                forKey: key.prefixHash)
        }
    }

    private func rebuildKeyIndex() {
        keyIndex.removeAll(keepingCapacity: true)
        for (idx, entry) in entries.enumerated() {
            keyIndex[entry.key] = idx
        }
    }
}

// MARK: - Hashing helper

/// Pure-function namespace for typed prefix/suffix hashing。
/// Uses the same FNV-1a + length-prefix encoding as M907 +
/// M928 (chapter 三百九二 / M892 replay-determinism doctrine
/// — pipe-injection collision-safe)。
public enum BASLLMPromptCacheHasher {

    /// Hash the stable-prefix portion of a request:
    /// instructions + system context blobs + tool schema +
    /// output schema。These are the parts that DON'T change
    /// per user turn within a session。
    public static func prefixHash(
        instructions: String,
        contextBlobs: [String],
        tools: [BASTool],
        outputSchema: BASGuidedGenerationSchema?
    ) -> UInt64 {
        let toolNames = tools.map(\.name)
            .sorted()
            .joined(separator: ",")
        let schemaName = outputSchema?.schemaName ?? ""
        let blobsJoined = contextBlobs
            .map { "\($0.utf8.count):\($0)" }
            .joined()
        let combined =
            "\(instructions.utf8.count):\(instructions)"
            + "\(contextBlobs.count):" + blobsJoined
            + "\(toolNames.utf8.count):\(toolNames)"
            + "\(schemaName.utf8.count):\(schemaName)"
        return fnv1a(combined)
    }

    /// Hash the dynamic-suffix portion:user prompt + per-
    /// turn risk flags。Changes per turn。
    public static func suffixHash(
        userPrompt: String,
        riskFlags: [String]
    ) -> UInt64 {
        let flagsJoined = riskFlags
            .map { "\($0.utf8.count):\($0)" }
            .joined()
        let combined =
            "\(userPrompt.utf8.count):\(userPrompt)"
            + "\(riskFlags.count):" + flagsJoined
        return fnv1a(combined)
    }

    private static func fnv1a(_ s: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }
}
