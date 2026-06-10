// MARK: - BASSystemProbe
// chapter 七百四 第四刀 / M2194
//
// Swift actor wrapping the chapter-七百三-第五刀 C system probes
// (bas_thermal_probe / bas_cpu_*_count / bas_memory_*)。 Hosts
// use this for "should I throttle / defer this turn?" decisions
// before kicking off heavy compute。
//
// Per 「术业有专攻」 — C owns the Darwin sysctl + host_statistics64
// + mach_host_self syscalls。 Swift orchestrates。 The actor wraps
// the raw C calls into a typed snapshot that's Codable + Sendable
// for downstream consumers (BASLeaseLife thermal scheduler,
// BASMetalBenchmarkHarness performance gates, etc。)。
//
// ## Why this lives in BASRuntimeCore
//
// BASCSystemBridge is already a dep of BASRuntimeCore (added at
// chapter 七百一 / M2167 第一刀 for BASMonotonicNanos)。 No new
// build-graph edges needed。

import Foundation
#if canImport(BASCSystemBridge)
import BASCSystemBridge
#endif

/// Typed thermal bucket mirroring the 4-bucket Darwin thermal
/// state。 Pinned raw values for wire stability。
public enum BASThermalBucket:
    String, Sendable, Equatable, Hashable,
    CaseIterable, Codable
{
    case nominal   = "nominal"
    case fair      = "fair"
    case serious   = "serious"
    case critical  = "critical"
}

/// One-shot read of the host's thermal + CPU + memory state。
/// Value-typed so callers can pass it across actor boundaries
/// without ownership concerns。
public struct BASSystemSnapshot:
    Sendable, Equatable, Hashable, Codable
{
    /// Thermal bucket from Foundation.ProcessInfo.thermalState。
    public let thermalBucket: BASThermalBucket?

    /// Convenience accessor — Foundation.ProcessInfo always
    /// reports a thermal state on Apple platforms,so this
    /// returns the non-optional bucket。
    public var thermalBucketOrNominal: BASThermalBucket {
        return thermalBucket ?? .nominal
    }
    /// Total logical CPU cores (hw.ncpu)。
    public let cpuLogicalCount: Int
    /// Total physical CPU cores (hw.physicalcpu)。
    public let cpuPhysicalCount: Int
    /// Performance cores (Apple Silicon)。 0 on Intel。
    public let cpuPerformanceCount: Int
    /// Efficiency cores (Apple Silicon)。 0 on Intel。
    public let cpuEfficiencyCount: Int
    /// CPU brand string,e.g。 "Apple M2 Pro"。
    public let cpuBrand: String
    /// Total physical RAM in bytes (hw.memsize)。
    public let memoryTotalBytes: Int64
    /// Memory pressure 0–100 percent estimate。
    public let memoryPressurePercent: Int
    /// VM page size in bytes (typically 4096 or 16384)。
    public let vmPageSize: Int64
    /// 全面进化 T2.3 低熵 — task_vm_info.phys_footprint:the jetsam-
    /// relevant per-process memory number (what the kernel actually
    /// kills on)。 Optional + nil default:synthesized Codable omits
    /// the absent key,so persisted snapshots and all existing call
    /// sites stay byte-stable。 nil = probe unavailable/failed (never
    /// 0-as-unknown)。
    public let physFootprintBytes: UInt64?
    /// task_vm_info.compressed bytes (companion to phys footprint)。
    public let compressedBytes: UInt64?
    /// task_vm_info.internal bytes (companion to phys footprint)。
    public let internalBytes: UInt64?

    public init(
        thermalBucket: BASThermalBucket,
        cpuLogicalCount: Int,
        cpuPhysicalCount: Int,
        cpuPerformanceCount: Int,
        cpuEfficiencyCount: Int,
        cpuBrand: String,
        memoryTotalBytes: Int64,
        memoryPressurePercent: Int,
        vmPageSize: Int64,
        physFootprintBytes: UInt64? = nil,
        compressedBytes: UInt64? = nil,
        internalBytes: UInt64? = nil
    ) {
        self.thermalBucket = thermalBucket
        self.cpuLogicalCount = cpuLogicalCount
        self.cpuPhysicalCount = cpuPhysicalCount
        self.cpuPerformanceCount = cpuPerformanceCount
        self.cpuEfficiencyCount = cpuEfficiencyCount
        self.cpuBrand = cpuBrand
        self.memoryTotalBytes = memoryTotalBytes
        self.memoryPressurePercent = memoryPressurePercent
        self.vmPageSize = vmPageSize
        self.physFootprintBytes = physFootprintBytes
        self.compressedBytes = compressedBytes
        self.internalBytes = internalBytes
    }
}

/// Actor that probes the host's runtime state via the C system
/// bridge。 Caller-isolated:hosts can keep one instance for the
/// process lifetime + ask `await probe.probe()` whenever they
/// need a fresh snapshot。
public actor BASSystemProbe {

    public init() {}

    /// Take a snapshot of the current host state。 Performs ~7
    /// fast sysctl/mach calls — typical latency < 100 μs on
    /// Apple Silicon。 Safe to call from any actor context。
    public func probe() -> BASSystemSnapshot {
        return Self.snapshotNow()
    }

    /// Convenience predicate — true if the host is currently
    /// experiencing thermal or memory pressure that the
    /// substrate's runtime scheduler should react to。
    /// Thresholds:thermal >= .serious OR memory pressure > 80%。
    public func isUnderPressure() -> Bool {
        let s = Self.snapshotNow()
        if let t = s.thermalBucket,
            t == .serious || t == .critical {
            return true
        }
        if s.memoryPressurePercent > 80 {
            return true
        }
        return false
    }

    // MARK: - Static implementation
    //
    // Static + non-isolated so the actor's `probe()` doesn't
    // re-enter itself when synchronizing with the C bridge。
    // The C calls are all reentrant + lock-free (sysctl,
    // host_statistics64 are documented thread-safe)。

    private static func snapshotNow() -> BASSystemSnapshot {
        #if canImport(BASCSystemBridge)
        // chapter 七百四 第四刀 — hybrid probe strategy。
        //
        // 术业有专攻 mix:
        //   - Foundation.ProcessInfo handles "easy" Apple-API
        //     values that Swift exposes cleanly (CPU count,
        //     total memory, thermal state)
        //   - Direct C ABI handles values Foundation doesn't
        //     expose (perf/efficiency-core split,VM page size,
        //     memory-pressure percent)
        //
        // This avoids C-calling-convention bridging quirks in
        // the easy-path probes while still exercising the
        // chapter-七百三-第五刀 C system bridge for the hard
        // values。
        let info = ProcessInfo.processInfo
        let logical = info.activeProcessorCount
        let physical = info.processorCount
        let totalMem = Int64(info.physicalMemory)
        let thermal = mapThermalState(info.thermalState)

        // Apple-Silicon-specific perf/efficiency split via C bridge
        var perf: Int32 = -1
        _ = bas_cpu_performance_count(&perf)
        var eff: Int32 = -1
        _ = bas_cpu_efficiency_count(&eff)

        // Memory pressure + page size via C bridge
        var pressure: Int32 = 0
        _ = bas_memory_pressure_percent(&pressure)

        // T2.3 低熵 — task_vm_info footprint trio via C bridge。
        // rc != 0 ⇒ nil (probe honesty:never 0-as-unknown)。
        var physFootprint: UInt64 = 0
        var compressed: UInt64 = 0
        var internalBytes: UInt64 = 0
        let footprintRC = bas_task_phys_footprint(
            &physFootprint, &compressed, &internalBytes)

        return BASSystemSnapshot(
            thermalBucket: thermal,
            cpuLogicalCount: logical,
            cpuPhysicalCount: physical,
            cpuPerformanceCount: Int(max(0, perf)),
            cpuEfficiencyCount: Int(max(0, eff)),
            cpuBrand: probeCPUBrand(),
            memoryTotalBytes: max(0, totalMem),
            memoryPressurePercent: Int(max(0, pressure)),
            vmPageSize: probeVMPageSize(),
            physFootprintBytes: footprintRC == 0 ? physFootprint : nil,
            compressedBytes: footprintRC == 0 ? compressed : nil,
            internalBytes: footprintRC == 0 ? internalBytes : nil)
        #else
        // Non-Apple build host fallback — values zeroed but the
        // struct shape stays。
        return BASSystemSnapshot(
            thermalBucket: nil,
            cpuLogicalCount: 0, cpuPhysicalCount: 0,
            cpuPerformanceCount: 0, cpuEfficiencyCount: 0,
            cpuBrand: "",
            memoryTotalBytes: 0,
            memoryPressurePercent: 0,
            vmPageSize: 0)
        #endif
    }

    #if canImport(BASCSystemBridge)
    /// Map Foundation.ProcessInfo.ThermalState to our 4-bucket
    /// schema。 Foundation's bucket is .nominal / .fair /
    /// .serious / .critical;mapping is 1-to-1。
    private static func mapThermalState(
        _ s: ProcessInfo.ThermalState
    ) -> BASThermalBucket {
        switch s {
        case .nominal:  return .nominal
        case .fair:     return .fair
        case .serious:  return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }

    private static func probeCPUBrand() -> String {
        var buf = [CChar](repeating: 0, count: 256)
        let rc = buf.withUnsafeMutableBufferPointer { bp in
            bas_cpu_brand(bp.baseAddress, 256)
        }
        if rc < 0 { return "" }
        // Truncate at the NUL terminator + decode as UTF-8 (String(cString: [CChar]) is deprecated).
        let length = buf.firstIndex(of: 0) ?? buf.count
        return String(decoding: buf[..<length].map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private static func probeVMPageSize() -> Int64 {
        // POSIX getpagesize() — same value as Darwin's
        // vm_page_size but without the deprecation warning。
        // 4 KiB on Intel,16 KiB on Apple Silicon。
        return Int64(getpagesize())
    }
    #endif
}
