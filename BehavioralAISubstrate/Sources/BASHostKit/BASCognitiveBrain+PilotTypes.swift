// MARK: - BASCognitiveBrain pilot/health/config value types
// chapter 一千〇四十 / WS-brain-decomp — relocated from BASCognitiveBrain.swift (god-object split).
// Pure value types (Codable snapshots the brain returns). Same module + top-level names ⇒ byte-equal:
// every call site (the actor, its extensions, tests) resolves these unqualified, unchanged.

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

/// 持续性 发展 — Codable result of
/// `brain.verifyPilotInvariants()`。 Hosts use this in
/// tests + monitoring to assert cross-pilot data
/// consistency。
public struct BASCognitiveBrainPilotInvariantReport:
    Codable, Equatable, Sendable, Hashable
{
    /// Names of invariants that were applicable (both
    /// pilots wired so the comparison made sense)。
    public let checksRun: [String]

    /// Free-text description of any violated invariants。
    /// Empty when all checks passed。
    public let violations: [String]

    /// Snapshot of SQL.totalRecords at the time of the
    /// check (nil when SQL pilot not wired)。
    public let sqlTotalRecords: Int?

    /// Snapshot of Rust.totalRecords at the check time。
    public let rustTotalRecords: Int?

    /// Snapshot of C++ cache size at the check time。
    public let cxxCacheSize: Int?

    /// Host clock at the check time。
    public let collectedAt: Date

    public init(
        checksRun: [String],
        violations: [String],
        sqlTotalRecords: Int?,
        rustTotalRecords: Int?,
        cxxCacheSize: Int?,
        collectedAt: Date
    ) {
        self.checksRun = checksRun
        self.violations = violations
        self.sqlTotalRecords = sqlTotalRecords
        self.rustTotalRecords = rustTotalRecords
        self.cxxCacheSize = cxxCacheSize
        self.collectedAt = collectedAt
    }

    /// True when no checks were applicable OR all
    /// applicable checks passed。
    public var allInvariantsHeld: Bool {
        return violations.isEmpty
    }
}

/// 严查 修复 — Codable bundle of C-pilot OS-introspection
/// probes,included in `brain.healthSnapshot()` so the C
/// pilot's 5 native functions actually surface to
/// consumers instead of floating in BASRuntimeCore unused。
///
/// All fields Optional — nil on V1 mode / non-Apple build
/// hosts where the sysctl / mach calls return -3。 Hosts
/// that need strict error propagation can query each
/// probe directly via its actor。
public struct BASCognitiveBrainCSystemProbeSnapshot: Codable,
    Equatable, Sendable, Hashable
{
    /// `mach_task_basic_info(RESIDENT_SIZE)` — process RSS。
    public let residentMemoryBytes: UInt64?

    /// `task_threads()` — active Mach thread count for
    /// this process。
    public let threadCount: Int?

    /// `sysctl(HW_NCPU)` — host's logical CPU count
    /// (perf + efficiency cores combined on Apple silicon)。
    public let logicalCpuCount: Int?

    /// `sysctl(KERN_BOOTTIME) + gettimeofday` — host uptime
    /// in seconds since boot。
    public let systemUptimeSeconds: Int64?

    /// `sysctl(HW_MEMSIZE)` — total physical RAM bytes
    /// (uint64,supersedes legacy HW_PHYSMEM)。
    public let physicalMemoryBytes: UInt64?

    /// 持续性 发展 — process CPU time sample (user +
    /// system microseconds) from `getrusage(RUSAGE_SELF)`。
    /// Default nil for backward-compat with snapshots
    /// produced before this field landed。
    public let cpuTime: BASProcessCPUTimeSample?

    /// 持续性 发展 — process disk I/O block counts
    /// (ru_inblock + ru_oublock) from `getrusage`。
    /// Cumulative since process start;hosts diff across
    /// captures for I/O rate dashboards。 Default nil for
    /// backward-compat。
    public let diskIO: BASProcessDiskIOSample?

    public init(
        residentMemoryBytes: UInt64?,
        threadCount: Int?,
        logicalCpuCount: Int?,
        systemUptimeSeconds: Int64?,
        physicalMemoryBytes: UInt64?,
        cpuTime: BASProcessCPUTimeSample? = nil,
        diskIO: BASProcessDiskIOSample? = nil
    ) {
        self.residentMemoryBytes = residentMemoryBytes
        self.threadCount = threadCount
        self.logicalCpuCount = logicalCpuCount
        self.systemUptimeSeconds = systemUptimeSeconds
        self.physicalMemoryBytes = physicalMemoryBytes
        self.cpuTime = cpuTime
        self.diskIO = diskIO
    }

    /// Convenience:ratio of process RSS to total
    /// physical memory in [0, 1]。 Nil when either field
    /// is missing。 Useful for memory-pressure dashboards。
    public var residentMemoryFraction: Double? {
        guard let rss = residentMemoryBytes,
              let phys = physicalMemoryBytes,
              phys > 0
        else { return nil }
        return Double(rss) / Double(phys)
    }
}

/// 主线 全面 提升 — Codable unified health snapshot
/// returned by `brain.healthSnapshot()`。 One bundle weaves
/// every wired pilot's deep telemetry into a single
/// dashboard-shaped document。
///
/// Hosts use this to:
///   - render a single "pilot health" view (5 pilots × deep
///     telemetry each)
///   - persist periodic health snapshots for trend analysis
///   - detect pilot-wire-up regressions across releases
///   - compare two environments by Codable byte-diff
public struct BASCognitiveBrainHealthSnapshot: Codable,
    Equatable, Sendable, Hashable
{
    /// Which pilots are wired into this brain。
    public let pilotStatus: BASCognitiveBrainPilotStatus

    /// Per-pilot operational counts (storage events,
    /// cache sizes,in-memory history)。
    public let pilotMetrics: BASCognitiveBrainPilotMetrics

    /// SQL pilot's permit-mode + turns-this-session
    /// rollup,with isSQLBacked status。 Nil when the
    /// SQL pilot is not wired or the aggregation query
    /// failed。
    public let sqlAggregation:
        BASSQLBrainHistoryStoreAggregation?

    /// Rust pilot's permit-mode + session rollups +
    /// distinct-session count。 Nil when Rust pilot
    /// is not wired or the aggregation query failed。
    public let rustAggregation:
        BASRustBrainHistoryStoreAggregation?

    /// C++ pilot's cache hit/miss/hit-rate telemetry +
    /// current cache size。 Nil when C++ pilot is not
    /// wired。
    public let cxxTelemetry:
        BASCxxBrainSummaryCacheTelemetry?

    /// Optional pre-captured warmup result。 Nil means
    /// the snapshot was captured without running
    /// warmPilots first。 Pass a prior warmPilots() value
    /// at snapshot time to include warmup state。
    public let warmupResult:
        BASCognitiveBrainPilotWarmupResult?

    /// 严查 修复 — C-pilot system probes (RSS / thread
    /// count / CPU count / system uptime / physical
    /// memory)。 Default nil for backward-compat with
    /// historical snapshots produced before this field
    /// landed。 New snapshots populate this from real
    /// sysctl / mach calls when the host is Apple silicon。
    public let cSystemProbes:
        BASCognitiveBrainCSystemProbeSnapshot?

    /// 持续性 发展 — top-K most-frequent atoms via the
    /// Rust pilot's native top-K FFI。 Nil when Rust
    /// pilot is not wired。 Empty array when wired but
    /// no records yet。 Hosts use this for "most-
    /// repeated input" dashboards without re-running
    /// the Rust query separately。 Default nil for
    /// backward-compat。
    public let topAtoms: [BASTopAtomEntry]?

    /// 持续性 发展 — atom-count distribution percentiles
    /// (p50 / p95 / p99) computed inside Rust via sort
    /// + nearest-rank。 Nil when Rust pilot is not
    /// wired。 isEmpty when wired but no records exist。
    /// Hosts use this for "what's the typical repetition
    /// rate" dashboards。 Default nil for backward-compat。
    public let atomCountPercentiles: BASAtomCountPercentiles?

    /// 主线 Integrity 抽取 — Rust-computed SHA256 chain
    /// hash hex string (64 lowercase hex chars)。 Nil when
    /// Rust pilot not wired。 Hosts use this for tamper
    /// detection:store known-good value,re-fetch
    /// later,compare for drift。
    public let integrityChainHashHex: String?

    /// When the snapshot was collected (host clock)。
    public let collectedAt: Date

    public init(
        pilotStatus: BASCognitiveBrainPilotStatus,
        pilotMetrics: BASCognitiveBrainPilotMetrics,
        sqlAggregation:
            BASSQLBrainHistoryStoreAggregation?,
        rustAggregation:
            BASRustBrainHistoryStoreAggregation?,
        cxxTelemetry:
            BASCxxBrainSummaryCacheTelemetry?,
        warmupResult:
            BASCognitiveBrainPilotWarmupResult?,
        cSystemProbes:
            BASCognitiveBrainCSystemProbeSnapshot? = nil,
        topAtoms: [BASTopAtomEntry]? = nil,
        atomCountPercentiles:
            BASAtomCountPercentiles? = nil,
        integrityChainHashHex: String? = nil,
        collectedAt: Date
    ) {
        self.pilotStatus = pilotStatus
        self.pilotMetrics = pilotMetrics
        self.sqlAggregation = sqlAggregation
        self.rustAggregation = rustAggregation
        self.cxxTelemetry = cxxTelemetry
        self.warmupResult = warmupResult
        self.cSystemProbes = cSystemProbes
        self.topAtoms = topAtoms
        self.atomCountPercentiles = atomCountPercentiles
        self.integrityChainHashHex =
            integrityChainHashHex
        self.collectedAt = collectedAt
    }

    /// How many deep-telemetry sub-bundles populated。
    /// Useful as a single-number "depth" metric for
    /// dashboards: 0 = bare brain (C only),3 = fully-
    /// wired SQL + Rust + C++ pilots reporting depth。
    public var populatedDeepTelemetryCount: Int {
        return [
            sqlAggregation != nil,
            rustAggregation != nil,
            cxxTelemetry != nil,
        ].reduce(0) { $0 + ($1 ? 1 : 0) }
    }

    /// True when every wired pilot reported deep telemetry。
    /// A bare brain (no SQL/Rust/C++) returns true vacuously
    /// since there's nothing to fail。
    public var everyWiredPilotReportedDeepTelemetry: Bool {
        if pilotStatus.sqlActive && sqlAggregation == nil {
            return false
        }
        if pilotStatus.rustActive && rustAggregation == nil {
            return false
        }
        if pilotStatus.cxxActive && cxxTelemetry == nil {
            return false
        }
        return true
    }
}

/// Codable result of `brain.warmPilots()`。 Reports
/// which pilots had a warmable surface and which
/// succeeded。 Hosts use this to detect pilot wire-up
/// issues at startup (e.g. Metal loader present but
/// fails to compile = device-side problem)。
public struct BASCognitiveBrainPilotWarmupResult:
    Codable, Equatable, Sendable, Hashable
{
    /// True when the Metal pilot was wired into the
    /// brain (metalLibraryLoader != nil)。
    public let metalAttempted: Bool

    /// True when the Metal library compiled successfully
    /// (either fresh compile or already memoized)。
    /// False when metalAttempted is true but the compile
    /// failed,or when metalAttempted is false。
    public let metalSucceeded: Bool

    public init(
        metalAttempted: Bool,
        metalSucceeded: Bool
    ) {
        self.metalAttempted = metalAttempted
        self.metalSucceeded = metalSucceeded
    }

    /// All warmable pilots succeeded (or were not
    /// wired,which is not a failure)。
    public var allSucceeded: Bool {
        return !metalAttempted || metalSucceeded
    }
}

/// Codable runtime-configuration snapshot of the brain。
/// Returned by `brain.configSnapshot()`。 Completes the
/// observability triad with pilotStatus + pilotMetrics:
///   - pilotStatus: which pilots are wired (boolean flags)
///   - pilotMetrics: per-pilot operational counts
///   - configSnapshot (this): construction-time settings
///
/// Hosts use this for debug logs, reproducibility (same
/// config across processes), and config-regression
/// detection (alert when expected config drifts)。
public struct BASCognitiveBrainConfigSnapshot: Codable,
    Equatable, Sendable, Hashable
{
    /// Bounded LRU capacity for in-memory summary
    /// history (host-configurable at brain init)。
    public let summaryHistoryCapacity: Int

    /// Per-instance safety threshold (host-injectable
    /// at brain init,clamped to [0, 1])。
    public let safetyConfidenceThreshold: Double

    /// Embedded pilot-wire-up snapshot — which of the 5
    /// multi-language pilots are active on this brain。
    public let pilotStatus: BASCognitiveBrainPilotStatus

    public init(
        summaryHistoryCapacity: Int,
        safetyConfidenceThreshold: Double,
        pilotStatus: BASCognitiveBrainPilotStatus
    ) {
        self.summaryHistoryCapacity =
            summaryHistoryCapacity
        self.safetyConfidenceThreshold =
            safetyConfidenceThreshold
        self.pilotStatus = pilotStatus
    }
}

/// Codable snapshot of per-pilot operational counts。
/// Returned by `brain.pilotMetrics()`。 Hosts use this
/// for dashboards / health monitoring。
public struct BASCognitiveBrainPilotMetrics: Codable,
    Equatable, Sendable, Hashable
{
    /// Number of records currently persisted in the
    /// SQL pilot's backing store。 0 when SQL pilot
    /// is not wired or query failed。
    public let sqlRecordCount: Int

    /// Number of records currently held in the Rust
    /// pilot's tracker。 0 when Rust pilot not wired or
    /// query failed (e.g. XCFramework slice missing)。
    public let rustRecordCount: Int

    /// Number of entries in the C++ pilot's process-
    /// global summary cache。 0 when C++ pilot not
    /// wired。
    public let cxxCacheSize: Int

    /// Number of summaries currently held in the
    /// brain's in-memory bounded LRU history buffer。
    public let inMemorySummaryCount: Int

    public init(
        sqlRecordCount: Int,
        rustRecordCount: Int,
        cxxCacheSize: Int,
        inMemorySummaryCount: Int
    ) {
        self.sqlRecordCount = sqlRecordCount
        self.rustRecordCount = rustRecordCount
        self.cxxCacheSize = cxxCacheSize
        self.inMemorySummaryCount = inMemorySummaryCount
    }

    /// Total persisted/cached events across the four
    /// storage-shaped pilots。 Useful single-number
    /// "how busy is this brain" metric for dashboards。
    public var totalStorageEvents: Int {
        return sqlRecordCount + rustRecordCount
            + cxxCacheSize + inMemorySummaryCount
    }
}

/// Codable snapshot of which pilots are wired into a
/// brain instance。 Returned by `brain.pilotStatus`。
public struct BASCognitiveBrainPilotStatus: Codable,
    Equatable, Sendable, Hashable
{
    /// C pilot — high-resolution latency clock。
    /// Always active (built into the brain;not
    /// host-injectable)。
    public let cActive: Bool

    /// SQL pilot — durable SQLite-backed history
    /// persistence。 Active when sqlHistoryStore was
    /// passed at construction time。
    public let sqlActive: Bool

    /// C++ pilot — process-global summary cache。
    /// Active when cxxSummaryCache was passed。
    public let cxxActive: Bool

    /// Rust pilot — fast in-process history telemetry。
    /// Active when rustHistoryStore was passed。
    public let rustActive: Bool

    /// Metal pilot — kernel library accessor for
    /// downstream Mamba/SSM compute。 Active when
    /// metalLibraryLoader was passed。
    public let metalActive: Bool

    /// Convenience: total count of active pilots
    /// (always at least 1 since C is always active)。
    public var activeCount: Int {
        return [cActive, sqlActive, cxxActive,
            rustActive, metalActive]
            .reduce(0) { $0 + ($1 ? 1 : 0) }
    }

    /// All 5 active = fully-wired production setup。
    public var allActive: Bool {
        return cActive && sqlActive && cxxActive
            && rustActive && metalActive
    }

    public init(
        cActive: Bool,
        sqlActive: Bool,
        cxxActive: Bool,
        rustActive: Bool,
        metalActive: Bool
    ) {
        self.cActive = cActive
        self.sqlActive = sqlActive
        self.cxxActive = cxxActive
        self.rustActive = rustActive
        self.metalActive = metalActive
    }
}
