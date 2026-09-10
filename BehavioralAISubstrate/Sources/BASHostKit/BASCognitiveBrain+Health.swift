// MARK: - BASCognitiveBrain summary-helped feedback · health snapshots · warm-pilots · C-probes
// chapter 一千〇四十 / WS-brain-decomp — relocated from BASCognitiveBrain.swift (god-object split).
// `extension BASCognitiveBrain` method cluster — same actor, same symbols, call sites unchanged.
// Pure relocation ⇒ byte-equal (cascade-digest net).

import Foundation
import CryptoKit
import BASMemory
import BASPolicy
import BASRuntimeCore
import BASMetalSubstrate
import BASRustCoreBridge
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

extension BASCognitiveBrain {
    /// 持续性 发展 — mark a summary as helped/notHelped。
    /// Updates the SQL + Rust history stores via their
    /// existing `markHelped(recordID:helped:)` paths。
    /// Requires the host to know the recordID — provided
    /// by `BASSQLBrainHistoryStore.recordSummary(_:)`
    /// return value。
    ///
    /// Best-effort:per-store failures non-fatal。
    /// Returns true when at least one store accepted the
    /// update。
    @discardableResult
    public func markSummaryHelped(
        recordID: String, helped: Bool
    ) async -> Bool {
        var accepted = false
        if let store = sqlHistoryStore {
            if let _ = try? await store
                .markHelped(
                    recordID: recordID, helped: helped)
            {
                accepted = true
            }
        }
        // Rust store doesn't yet expose markHelped — the
        // FFI surface stops at append + query。 Hosts
        // wanting cross-pilot mark must call the SQL
        // store directly for now。
        return accepted
    }

    /// 全面 开发 — export the brain's health snapshot
    /// history as NDJSON (one JSON object per line)。
    /// Returns an empty string when no history is
    /// configured (capacity 0) or the buffer is empty。
    ///
    /// Hosts use this for:
    ///   - one-line dump to file / pipe / stdout
    ///   - upload to dashboards expecting NDJSON
    ///   - persisting brain state between sessions
    ///
    /// Date encoding uses `.millisecondsSince1970` to
    /// match SQL ms-precision (the same strategy the
    /// healthSnapshot Codable round-trip test uses)。
    /// Each line is one BASCognitiveBrainHealthSnapshot
    /// emitted in oldest-first order。
    public func exportHealthHistoryJSON() async -> String {
        guard let history = healthHistory else {
            return ""
        }
        let snaps = await history.all
        if snaps.isEmpty { return "" }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy =
            .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        var lines: [String] = []
        lines.reserveCapacity(snaps.count)
        for snap in snaps {
            guard let data = try? encoder.encode(snap),
                  let line = String(
                    data: data, encoding: .utf8)
            else { continue }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    /// 主线 继续 开发 — capture a healthSnapshot and
    /// append to the brain's owned ring buffer。 No-op
    /// when `healthHistory` is nil (capacity was 0 at
    /// init)。 Returns the captured snapshot so callers
    /// can also use it directly。
    ///
    /// Pass an optional `warmupResult` to include the
    /// Metal warmup state — same parameter as
    /// `healthSnapshot(warmupResult:)`。
    @discardableResult
    public func recordHealthSnapshot(
        warmupResult: BASCognitiveBrainPilotWarmupResult? = nil
    ) async -> BASCognitiveBrainHealthSnapshot {
        let snap = await healthSnapshot(
            warmupResult: warmupResult)
        if let history = healthHistory {
            await history.append(snap)
        }
        return snap
    }

    /// 主线 全面 开发 — Metal cosine similarity via the
    /// SSMScan.metal-resident `vector_cosine_similarity`
    /// kernel。 Per the user's blueprint,Metal owns
    /// embedding similarity。
    ///
    /// Dispatches the kernel on the GPU,reads partial
    /// products back,reduces on CPU,returns a Codable
    /// result struct with similarity + intermediate norms。
    ///
    /// Throws BASMetalCosineSimilarityDispatcherError on
    /// length mismatch / zero-length / Metal-side errors。
    /// Throws .libraryUnavailable when no Metal loader
    /// is wired。

    /// Pre-warm all warmable pilots in one call。
    /// Currently warms:
    ///   - Metal kernel compile (when loader wired)
    /// Other pilots either have no warmup cost (C is
    /// stateless,SQL opens connection at construction)
    /// or warm themselves on first access (C++ singleton
    /// init,Rust handle from constructor)。
    ///
    /// Returns a typed bundle reporting which warmups
    /// were attempted + which succeeded。 Hosts call
    /// this at brain init to amortize warm cost off
    /// the first user-facing turn。
    @discardableResult
    public func warmPilots() async
        -> BASCognitiveBrainPilotWarmupResult
    {
        let metalAttempted = metalLibraryLoader != nil
        let metalSucceeded: Bool
        if metalAttempted {
            metalSucceeded = await warmMetalKernel()
        } else {
            metalSucceeded = false
        }
        return BASCognitiveBrainPilotWarmupResult(
            metalAttempted: metalAttempted,
            metalSucceeded: metalSucceeded)
    }

    /// 主线 全面 提升 — unified pilot health snapshot。
    /// Combines pilotStatus + pilotMetrics with every
    /// pilot's deep telemetry surface into one Codable
    /// document hosts can ship to a dashboard / observability
    /// pipeline。
    ///
    /// Per-pilot deep telemetry included:
    ///   - SQL pilot → BASSQLBrainHistoryStoreAggregation
    ///     (permit-mode distribution via native GROUP BY)
    ///   - Rust pilot → BASRustBrainHistoryStoreAggregation
    ///     (permit + session rollups)
    ///   - C++ pilot → BASCxxBrainSummaryCacheTelemetry
    ///     (hit/miss/hit-rate + cache size)
    ///   - Metal pilot → BASCognitiveBrainPilotWarmupResult
    ///     (warmup state — set when warmPilots already ran)
    ///   - C pilot → recorded via pilotStatus.cActive
    ///     (no host-pluggable storage to aggregate)
    ///
    /// Best-effort:per-pilot query failures surface as nil
    /// in the relevant Optional field rather than throwing
    /// the whole snapshot。 Hosts that want strict error
    /// propagation should call each underlying pilot
    /// surface directly。
    ///
    /// - Parameter warmupResult:optional pre-captured
    ///   warmup result。 Pass the value returned by a prior
    ///   `warmPilots()` call to include it in the snapshot
    ///   without re-running warmup。 Nil means "snapshot
    ///   doesn't include warmup state"。
    public func healthSnapshot(
        warmupResult: BASCognitiveBrainPilotWarmupResult? = nil
    ) async -> BASCognitiveBrainHealthSnapshot {
        let status = pilotStatus
        let metrics = await pilotMetrics()
        let sqlAgg: BASSQLBrainHistoryStoreAggregation?
        if let store = sqlHistoryStore {
            sqlAgg = try? await store.aggregationSnapshot()
        } else { sqlAgg = nil }
        let rustAgg: BASRustBrainHistoryStoreAggregation?
        if let store = rustHistoryStore {
            rustAgg = try? await store.aggregationSnapshot()
        } else { rustAgg = nil }
        let cxxTele: BASCxxBrainSummaryCacheTelemetry?
        if let cache = cxxSummaryCache {
            cxxTele = await cache.telemetrySnapshot()
        } else { cxxTele = nil }
        // 严查 修复 — actually surface the C-pilot probes
        // that were created but never consumed。 Query each
        // probe;best-effort,failures surface as nil。
        let cProbes = await captureCSystemProbes()
        // 持续性 发展 — top-K leaderboard via Rust pilot's
        // native top_k_atoms FFI。 Best-effort:nil when
        // Rust not wired or query fails。 Top-5 is small
        // enough to include unconditionally without
        // bloating the snapshot。
        let topAtoms: [BASTopAtomEntry]?
        let atomCountPercentiles: BASAtomCountPercentiles?
        let integrityChainHashHex: String?
        if let store = rustHistoryStore {
            topAtoms = try? await store.topKAtoms(limit: 5)
            atomCountPercentiles = try? await store
                .atomCountPercentiles()
            integrityChainHashHex = try? await store
                .integrityChainHashHex()
        } else {
            topAtoms = nil
            atomCountPercentiles = nil
            integrityChainHashHex = nil
        }
        return BASCognitiveBrainHealthSnapshot(
            pilotStatus: status,
            pilotMetrics: metrics,
            sqlAggregation: sqlAgg,
            rustAggregation: rustAgg,
            cxxTelemetry: cxxTele,
            warmupResult: warmupResult,
            cSystemProbes: cProbes,
            topAtoms: topAtoms,
            atomCountPercentiles: atomCountPercentiles,
            integrityChainHashHex:
                integrityChainHashHex,
            collectedAt: Date())
    }

    /// 严查 修复 — gather C-pilot system probes into one
    /// Codable bundle for inclusion in healthSnapshot。
    /// All four V2 probes are queried; failures (V1 mode
    /// or non-Apple platform) surface as nil per-field。
    private func captureCSystemProbes() async
        -> BASCognitiveBrainCSystemProbeSnapshot
    {
        let rssProbe = BASProcessMemoryProbe(
            useCBridge: true)
        let threadProbe = BASThreadCountProbe(
            useCBridge: true)
        let cpuProbe = BASCPUCountProbe(useCBridge: true)
        let uptimeProbe = BASSystemUptimeProbe(
            useCBridge: true)
        let physProbe = BASPhysicalMemoryProbe(
            useCBridge: true)
        let cpuTimeProbe = BASProcessCPUTimeProbe(
            useCBridge: true)
        let diskIOProbe = BASProcessDiskIOProbe(
            useCBridge: true)
        let rss = try? await rssProbe.current()
        let threads = try? await threadProbe.current()
        let cpus = try? await cpuProbe.current()
        let uptime = try? await uptimeProbe.current()
        let physMem = try? await physProbe.current()
        let cpuTime = try? await cpuTimeProbe.current()
        let diskIO = try? await diskIOProbe.current()
        return BASCognitiveBrainCSystemProbeSnapshot(
            residentMemoryBytes: rss,
            threadCount: threads.map { Int($0) },
            logicalCpuCount: cpus.map { Int($0) },
            systemUptimeSeconds: uptime,
            physicalMemoryBytes: physMem,
            cpuTime: cpuTime,
            diskIO: diskIO)
    }
}
