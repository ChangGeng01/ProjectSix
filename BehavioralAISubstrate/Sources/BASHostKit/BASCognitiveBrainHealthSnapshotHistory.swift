// MARK: - BASCognitiveBrainHealthSnapshotHistory
// 主线 全面 开发: bounded ring buffer of brain health
// snapshots。 Hosts use this to see TRENDS over time —
// "is cache hit rate climbing?", "is RSS growing?",
// "did permitMode distribution shift after the last
// release?" — rather than just the current instant。
//
// **Why a separate actor (not state inside the brain
// itself)**: hosts may want multiple histories with
// different capacities (e.g. last-100 + last-10k), and
// may want to share one history across multiple brain
// instances (multi-tenant servers)。 Decoupled actor
// gives them that control。

import Foundation

/// Bounded ring buffer of BASCognitiveBrainHealthSnapshot
/// values。 Append is O(1) amortized; reads are O(N)
/// where N is the current count (bounded by capacity)。
public actor BASCognitiveBrainHealthSnapshotHistory {

    /// Maximum number of snapshots retained。 Older
    /// snapshots are dropped when the buffer is full
    /// and a new snapshot is appended。
    public let capacity: Int

    /// Backing storage。 Logical "newest" is at
    /// `snapshots[snapshots.count - 1]`,oldest at
    /// `snapshots[0]`。
    private var snapshots: [BASCognitiveBrainHealthSnapshot] = []

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
        snapshots.reserveCapacity(self.capacity)
    }

    /// Append a snapshot。 If the buffer is at capacity,
    /// drops the oldest snapshot first。
    public func append(
        _ snapshot: BASCognitiveBrainHealthSnapshot
    ) {
        if snapshots.count >= capacity {
            snapshots.removeFirst()
        }
        snapshots.append(snapshot)
    }

    /// Convenience:capture a snapshot from the given
    /// brain and append it。 The capture goes through
    /// `brain.healthSnapshot(warmupResult:)` — pass any
    /// pre-captured warmup result to include it。
    public func capture(
        from brain: BASCognitiveBrain,
        warmupResult: BASCognitiveBrainPilotWarmupResult? = nil
    ) async {
        let snap = await brain.healthSnapshot(
            warmupResult: warmupResult)
        append(snap)
    }

    /// Current count of retained snapshots。
    public var count: Int { snapshots.count }

    /// True when the buffer is empty。
    public var isEmpty: Bool { snapshots.isEmpty }

    /// All snapshots,oldest first。 Returns a snapshot of
    /// the buffer state — caller iteration is independent
    /// of subsequent appends。
    public var all: [BASCognitiveBrainHealthSnapshot] {
        return snapshots
    }

    /// Most recent N snapshots,newest first。 Returns
    /// fewer than N when the buffer has fewer entries。
    public func mostRecent(
        limit: Int
    ) -> [BASCognitiveBrainHealthSnapshot] {
        let take = min(max(0, limit), snapshots.count)
        return Array(snapshots.suffix(take).reversed())
    }

    /// Drop all stored snapshots。 Buffer-capacity stays
    /// unchanged。
    public func clear() {
        snapshots.removeAll(keepingCapacity: true)
    }

    // MARK: - 主线 全面 开发: trend summaries

    /// Trend summary across the retained snapshots。
    /// Nil when fewer than 2 snapshots exist (can't
    /// compute a trend from one point)。
    public func trendSummary()
        -> BASCognitiveBrainHealthSnapshotTrend?
    {
        guard snapshots.count >= 2 else { return nil }
        let oldest = snapshots.first!
        let newest = snapshots.last!
        let totalEventsOldest = oldest.pilotMetrics
            .totalStorageEvents
        let totalEventsNewest = newest.pilotMetrics
            .totalStorageEvents
        // Hit rate trend if C++ pilot is active in both
        let hitRateOldest = oldest.cxxTelemetry?.hitRate
        let hitRateNewest = newest.cxxTelemetry?.hitRate
        // Cache byte trend
        let cacheBytesOldest = oldest.cxxTelemetry?
            .contentByteSizeEstimate
        let cacheBytesNewest = newest.cxxTelemetry?
            .contentByteSizeEstimate
        // 主线 继续 开发 — C-probe trend deltas。
        // residentMemoryDelta + threadCountDelta surface
        // memory-pressure / thread-leak signals。
        let rssOldest = oldest.cSystemProbes?
            .residentMemoryBytes
        let rssNewest = newest.cSystemProbes?
            .residentMemoryBytes
        let threadOldest = oldest.cSystemProbes?
            .threadCount
        let threadNewest = newest.cSystemProbes?
            .threadCount
        let uptimeOldest = oldest.cSystemProbes?
            .systemUptimeSeconds
        let uptimeNewest = newest.cSystemProbes?
            .systemUptimeSeconds
        // Time span
        let elapsed = newest.collectedAt
            .timeIntervalSince(oldest.collectedAt)
        return BASCognitiveBrainHealthSnapshotTrend(
            snapshotCount: snapshots.count,
            spanSeconds: elapsed,
            totalStorageEventsDelta:
                totalEventsNewest - totalEventsOldest,
            hitRateDelta: deltaOptional(
                hitRateOldest, hitRateNewest),
            cacheContentBytesDelta: deltaOptional(
                cacheBytesOldest, cacheBytesNewest),
            residentMemoryDelta: deltaUInt64(
                rssOldest, rssNewest),
            threadCountDelta: deltaOptional(
                threadOldest, threadNewest),
            systemUptimeDelta: deltaOptional(
                uptimeOldest, uptimeNewest))
    }

    private func deltaOptional<T: Numeric>(
        _ old: T?, _ new: T?
    ) -> T? {
        guard let old, let new else { return nil }
        return new - old
    }

    /// 主线 继续 开发 — UInt64 delta as Int64 to allow
    /// signed deltas (memory can drop as well as grow)。
    private func deltaUInt64(
        _ old: UInt64?, _ new: UInt64?
    ) -> Int64? {
        guard let old, let new else { return nil }
        // Saturating signed delta so an enormous drop
        // (extremely unlikely) doesn't overflow Int64。
        if new >= old {
            let raw = new - old
            return raw <= UInt64(Int64.max)
                ? Int64(raw)
                : Int64.max
        }
        let raw = old - new
        return raw <= UInt64(Int64.max)
            ? -Int64(raw)
            : Int64.min
    }
}

/// 主线 全面 开发 — Codable trend summary across a
/// BASCognitiveBrainHealthSnapshotHistory's retained
/// snapshots。 Hosts use this to render "is the brain
/// trending healthier or unhealthier" dashboards。
public struct BASCognitiveBrainHealthSnapshotTrend: Codable,
    Equatable, Sendable, Hashable
{
    /// Number of snapshots the trend was computed across。
    public let snapshotCount: Int

    /// Seconds between the oldest and newest snapshot in
    /// the buffer。 0 when both timestamps collide。
    public let spanSeconds: TimeInterval

    /// Delta of `pilotMetrics.totalStorageEvents` between
    /// oldest and newest snapshot。 Positive = brain has
    /// accumulated more state。
    public let totalStorageEventsDelta: Int

    /// Delta of C++ cache hit rate between oldest and
    /// newest snapshot。 Nil if C++ pilot was missing in
    /// either snapshot。 Positive = hit rate climbing。
    public let hitRateDelta: Double?

    /// Delta of C++ cache content byte size between
    /// oldest and newest snapshot。 Nil if C++ pilot
    /// missing。 Positive = cache growing。
    public let cacheContentBytesDelta: Int?

    /// 主线 继续 开发 — process resident memory delta in
    /// bytes (signed Int64,positive = RSS grew,negative
    /// = RSS shrank)。 Nil if C probes missing in either
    /// snapshot。 Hosts use this to detect leaks across
    /// trend windows。
    public let residentMemoryDelta: Int64?

    /// Thread count delta — positive = thread creation,
    /// negative = thread teardown。 Nil if C probes
    /// missing in either snapshot。
    public let threadCountDelta: Int?

    /// System uptime delta in seconds。 Should be
    /// non-negative — host boot time doesn't change。
    /// Nil if C probes missing in either snapshot。
    /// Useful as a sanity-check for the time span
    /// (should approximately equal spanSeconds rounded
    /// down)。
    public let systemUptimeDelta: Int64?

    public init(
        snapshotCount: Int,
        spanSeconds: TimeInterval,
        totalStorageEventsDelta: Int,
        hitRateDelta: Double?,
        cacheContentBytesDelta: Int?,
        residentMemoryDelta: Int64? = nil,
        threadCountDelta: Int? = nil,
        systemUptimeDelta: Int64? = nil
    ) {
        self.snapshotCount = snapshotCount
        self.spanSeconds = spanSeconds
        self.totalStorageEventsDelta =
            totalStorageEventsDelta
        self.hitRateDelta = hitRateDelta
        self.cacheContentBytesDelta = cacheContentBytesDelta
        self.residentMemoryDelta = residentMemoryDelta
        self.threadCountDelta = threadCountDelta
        self.systemUptimeDelta = systemUptimeDelta
    }

    /// Convenience:storage-events per second over the
    /// trend span。 Returns 0 when span is 0 or negative。
    public var storageEventsPerSecond: Double {
        guard spanSeconds > 0 else { return 0 }
        return Double(totalStorageEventsDelta)
            / spanSeconds
    }

    /// 主线 继续 开发 — residentMemoryDelta normalized to
    /// bytes-per-second over the trend span。 Useful as
    /// a "leak rate" signal。 Nil when delta or span
    /// missing。 Sign preserved。
    public var residentMemoryBytesPerSecond: Double? {
        guard let delta = residentMemoryDelta,
              spanSeconds > 0
        else { return nil }
        return Double(delta) / spanSeconds
    }
}
