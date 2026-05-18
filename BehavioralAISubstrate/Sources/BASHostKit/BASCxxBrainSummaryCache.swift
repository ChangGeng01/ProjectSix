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
    /// encoding or bridge insertion fails。
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
    public func telemetrySnapshot() async
        -> BASCxxBrainSummaryCacheTelemetry
    {
        let sz = await bridge.size()
        return BASCxxBrainSummaryCacheTelemetry(
            hits: hitCount,
            misses: missCount,
            cacheSize: Int(sz))
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

    /// Total lookups (hits + misses)。
    public var totalLookups: Int { hits + misses }

    /// Hit rate in [0, 1]。 0 when no lookups have
    /// occurred yet。
    public var hitRate: Double {
        guard totalLookups > 0 else { return 0.0 }
        return Double(hits) / Double(totalLookups)
    }

    public init(
        hits: Int,
        misses: Int,
        cacheSize: Int
    ) {
        self.hits = hits
        self.misses = misses
        self.cacheSize = cacheSize
    }
}
