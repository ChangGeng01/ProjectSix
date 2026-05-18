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
    /// bridge failure, or decode failure。
    public func cachedSummary(
        forInput input: String
    ) async -> BASCognitiveBrainSummary? {
        let value: String?
        do {
            value = try await bridge.lookup(key: input)
        } catch {
            return nil
        }
        guard let valueStr = value,
              let data = valueStr.data(using: .utf8)
        else {
            return nil
        }
        return try? decoder.decode(
            BASCognitiveBrainSummary.self,
            from: data)
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
    public func clear() async throws {
        try await bridge.clear()
    }
}
