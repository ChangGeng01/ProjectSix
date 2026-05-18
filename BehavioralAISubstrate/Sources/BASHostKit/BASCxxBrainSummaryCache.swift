// MARK: - BASCxxBrainSummaryCache
// Optional process-global cache for BASCognitiveBrainSummary
// values, backed by the chapter 705 C++ unordered_map pilot。
// Use only when shared in-process cache behavior is wanted;
// there is no built-in eviction policy。

import Foundation
import BASMetalSubstrate

/// Process-global Codable-JSON cache for brain summaries
/// keyed by input string。 Backed by the chapter 705 C++
/// pilot (std::unordered_map)。
public actor BASCxxBrainSummaryCache {

    private let bridge: BASMPSGraphExecutableCacheCxxBridge
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Cumulative hit count since cache init。 Increments
    /// on every successful `cachedSummary(forInput:)` call
    /// that returns non-nil。 Per-instance,not
    /// process-global (the C++ singleton tracks values,
    /// this wrapper tracks operations against it)。
    private var hitCount: Int = 0

    /// Cumulative miss count since cache init。
    /// Increments when lookup returns nil (cache miss) OR
    /// when bridge/decode failure surfaces as nil。
    private var missCount: Int = 0

    /// Build with the underlying C++ bridge。 Use
    /// `BASMPSGraphExecutableCacheCxxBridge(useCxxCache:
    /// true)` to enable the C++ path; pass `false` for a
    /// disabled no-op cache。
    public init(bridge: BASMPSGraphExecutableCacheCxxBridge) {
        self.bridge = bridge
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys]
        self.decoder = JSONDecoder()
    }

    /// Look up a cached summary。 Returns nil on miss,
    /// bridge failure, or decode failure。 Updates the
    /// hit/miss counters for telemetry。
    public func cachedSummary(
        forInput input: String
    ) async -> BASCognitiveBrainSummary? {
        let value: String?
        do {
            value = try await bridge.lookup(key: input)
        } catch {
            missCount += 1
            return nil
        }
        guard let valueStr = value,
              let data = valueStr.data(using: .utf8)
        else {
            missCount += 1
            return nil
        }
        guard let decoded = try? decoder.decode(
            BASCognitiveBrainSummary.self,
            from: data)
        else {
            missCount += 1
            return nil
        }
        hitCount += 1
        return decoded
    }

    /// Persist a summary into the C++ cache。 Throws if
    /// encoding or bridge insertion fails。 Unconditional
    /// overwrite — if an entry exists for the same input,
    /// it gets replaced。
    public func cacheSummary(
        _ summary: BASCognitiveBrainSummary
    ) async throws {
        let data = try encoder.encode(summary)
        guard let valueStr =
            String(data: data, encoding: .utf8)
        else { return }
        try await bridge.insert(
            key: summary.input, value: valueStr)
    }

    /// 主线 继续 开发 — first-write-wins cache insert。
    /// Uses the C++-side atomic `lookupOrInsert` primitive
    /// to insert under one mutex acquisition,returning
    /// the existing entry if one was already there。
    ///
    /// Eliminates the TOCTOU window present in
    /// `cacheSummary()` where two concurrent
    /// `brain.summary("identical input")` calls can both
    /// miss the cache,both compute,both insert,with the
    /// second clobbering the first。 Under
    /// `cacheSummaryIfAbsent`,the first inserter wins;
    /// the second's compute result is discarded in favor
    /// of the first's already-cached value。
    ///
    /// Returns a tuple of:
    ///   - the BASCognitiveBrainSummary that's now in
    ///     the cache (either the just-inserted `summary`
    ///     or a previously-cached one if the cache had a
    ///     race winner)
    ///   - wasPresent: true if an entry was already there
    ///     (this call did NOT insert); false if this call
    ///     was the one that inserted
    ///
    /// Throws on encode failure or bridge error。 Best-
    /// effort decode of the existing-entry case — if the
    /// existing entry fails to decode (cache corruption /
    /// schema drift),falls back to returning the provided
    /// `summary` as if this call had been first。
    @discardableResult
    public func cacheSummaryIfAbsent(
        _ summary: BASCognitiveBrainSummary
    ) async throws
        -> (summary: BASCognitiveBrainSummary,
            wasPresent: Bool)
    {
        let data = try encoder.encode(summary)
        guard let valueStr =
            String(data: data, encoding: .utf8)
        else {
            return (summary: summary, wasPresent: false)
        }
        let result = try await bridge.lookupOrInsert(
            key: summary.input, defaultValue: valueStr)
        if !result.wasPresent {
            // We are the inserter
            return (summary: summary, wasPresent: false)
        }
        // Cache already had an entry — try to decode it
        // and return that。 On decode failure,fall back
        // to returning ours (correctness preserved;the
        // existing entry is just opaque to this caller)。
        guard let existingData =
                result.value.data(using: .utf8),
              let decoded = try? decoder.decode(
                BASCognitiveBrainSummary.self,
                from: existingData)
        else {
            return (summary: summary, wasPresent: true)
        }
        return (summary: decoded, wasPresent: true)
    }

    /// Process-global cache size (across all brain
    /// instances sharing this cache singleton)。
    public func size() async -> Int64 {
        return await bridge.size()
    }

    /// Clear the process-global cache。 Affects ALL brain
    /// instances using this bridge — use with care。
    /// Also resets this instance's hit/miss counters。
    public func clear() async throws {
        try await bridge.clear()
        hitCount = 0
        missCount = 0
    }

    // MARK: - 主线 全面 提升: telemetry surface

    /// Cumulative cache hits observed by this wrapper
    /// instance。 Resets on `clear()`。
    public var cumulativeHits: Int { hitCount }

    /// Cumulative cache misses observed by this wrapper
    /// instance。 Resets on `clear()`。
    public var cumulativeMisses: Int { missCount }

    /// Total lookups (hits + misses)。 Useful for
    /// dashboards / hit-rate computation。
    public var cumulativeLookups: Int {
        return hitCount + missCount
    }

    /// Hit rate as a Double in [0, 1]。 Returns 0 when
    /// no lookups have happened (no division by zero)。
    /// Hosts use this for cache-effectiveness telemetry
    /// dashboards。
    public var hitRate: Double {
        let total = cumulativeLookups
        guard total > 0 else { return 0.0 }
        return Double(hitCount) / Double(total)
    }

    /// Codable telemetry snapshot。 Combines hit/miss
    /// counters + cache size into one bundle for hosts
    /// monitoring cache effectiveness。
    ///
    /// 主线 解构 重构 — also includes
    /// `contentByteSizeEstimate` (sum of stored key+value
    /// bytes computed in C++ under one mutex acquisition)
    /// AND `maxEntryByteSize` (largest single entry's
    /// key+value sum,Round 3)。
    /// Best-effort: 0 on bridge failure (V1 path or rare
    /// allocation-failure-during-iteration)。
    public func telemetrySnapshot() async
        -> BASCxxBrainSummaryCacheTelemetry
    {
        let sz = await bridge.size()
        let bytes: Int64 =
            (try? await bridge.byteSizeEstimate()) ?? 0
        let maxBytes: Int64 =
            (try? await bridge.maxEntryByteSize()) ?? 0
        return BASCxxBrainSummaryCacheTelemetry(
            hits: hitCount,
            misses: missCount,
            cacheSize: Int(sz),
            contentByteSizeEstimate: Int(bytes),
            maxEntryByteSize: Int(maxBytes))
    }
}

/// Codable telemetry snapshot for BASCxxBrainSummaryCache。
/// Hosts use this to render cache-effectiveness dashboards
/// (hit rate, lookup throughput, memory pressure via
/// cache size)。
public struct BASCxxBrainSummaryCacheTelemetry: Codable,
    Equatable, Sendable, Hashable
{
    /// Cumulative hits since cache wrapper init / clear。
    public let hits: Int

    /// Cumulative misses since cache wrapper init / clear。
    public let misses: Int

    /// Current C++ cache entry count (process-global
    /// snapshot)。
    public let cacheSize: Int

    /// 主线 解构 重构 — sum of stored key+value bytes
    /// computed by the C++ side under one mutex acquisition。
    /// Excludes per-entry std::string + std::unordered_map
    /// overhead — a content-only estimate hosts can compare
    /// against a hard budget。 Set to 0 by the default
    /// initializer (backward-compat for snapshots produced
    /// before this field landed)。
    public let contentByteSizeEstimate: Int

    /// 主线 解构 重构 Round 3 — largest single entry's
    /// key.size + value.size sum,computed via a single-
    /// pass max scan in C++ under the same mutex。 Hosts
    /// use this to detect oversized-entry abuse (one huge
    /// entry can dominate `contentByteSizeEstimate`)。 Set
    /// to 0 by the default initializer for backward-compat。
    public let maxEntryByteSize: Int

    /// Total lookups (hits + misses)。
    public var totalLookups: Int { hits + misses }

    /// Hit rate in [0, 1]。 0 when no lookups have
    /// occurred yet。
    public var hitRate: Double {
        guard totalLookups > 0 else { return 0.0 }
        return Double(hits) / Double(totalLookups)
    }

    /// Average bytes per entry (rounded down)。 0 when the
    /// cache is empty。
    public var averageBytesPerEntry: Int {
        guard cacheSize > 0 else { return 0 }
        return contentByteSizeEstimate / cacheSize
    }

    /// 主线 解构 重构 Round 3 — entry-skew ratio。 Returns
    /// `maxEntryByteSize / averageBytesPerEntry` as a
    /// Double。 Values near 1.0 mean entries are roughly
    /// uniform; values >> 1.0 mean a few outsized entries
    /// dominate the cache。 Returns 0.0 when the cache is
    /// empty (no division by zero)。
    public var entrySkewRatio: Double {
        let avg = averageBytesPerEntry
        guard avg > 0 else { return 0.0 }
        return Double(maxEntryByteSize) / Double(avg)
    }

    public init(
        hits: Int,
        misses: Int,
        cacheSize: Int,
        contentByteSizeEstimate: Int = 0,
        maxEntryByteSize: Int = 0
    ) {
        self.hits = hits
        self.misses = misses
        self.cacheSize = cacheSize
        self.contentByteSizeEstimate =
            contentByteSizeEstimate
        self.maxEntryByteSize = maxEntryByteSize
    }
}
