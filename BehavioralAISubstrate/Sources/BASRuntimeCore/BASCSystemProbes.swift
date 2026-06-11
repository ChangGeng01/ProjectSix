// MARK: - BASCSystemProbes
// chapter 七百六十一 第三刀 / M2458 — DEEPER LAYER-MIGRATION ARC
//
// Swift wrappers for the L1 C system probes shipped at
// chapter 七百六十一 第一-二刀:
//
//   - `bas_wallclock_nanos`     : sleep-INCLUSIVE clock
//                                  (mach_absolute_time + timebase)
//   - `bas_task_phys_footprint` : richer memory probe via
//                                  task_info(TASK_VM_INFO) —
//                                  phys_footprint + compressed +
//                                  internal bytes
//
// ## Layering note
//
// Lives in BASRuntimeCore (same module as BASMonotonicNanos)。
// Mirrors the actor-isolation pattern + opt-in flag pattern
// from BASMonotonicNanos (chapter 七百三 第二刀)。
//
// ## ADR-014 OPT-IN preserved
//
// V1 live default for `BASWallclockNanos`:`Date().timeIntervalSince1970`-
// derived nanos (which Apple's Swift stdlib computes via
// `gettimeofday`)。 Apple Swift's `Date()` is wall-clock —
// non-monotonic + includes sleep。 The C-side `mach_absolute_time`
// gives a strictly-better monotonic alternative,but exposing it
// is opt-in。
//
// V1 live default for `BASTaskVmInfo`:no Swift equivalent。
// `ProcessInfo.processInfo.physicalMemory` returns DEVICE total,
// not PROCESS footprint。 So for this probe there's no Swift V1
// baseline — the helper just routes the C call always when on
// Apple platforms,or returns nil on non-Apple。

import Foundation
import BASCSystemBridge

// MARK: - BASWallclockNanosError

/// Typed error cases for the sleep-INCLUSIVE wallclock C bridge。
public enum BASWallclockNanosError:
    Error, Equatable, Hashable, Sendable, Codable
{
    /// `bas_wallclock_nanos` returned -1 (null `out`)。
    case nullOutPointer
    /// `bas_wallclock_nanos` returned -2 (`mach_timebase_info`
    /// initialization failed — should never happen on a real
    /// Apple device)。
    case machTimebaseInitFailed
    /// `bas_wallclock_nanos` returned -3 (unsupported platform —
    /// non-Apple build host)。
    case unsupportedPlatform
    /// Unknown non-zero return code (future-proofing)。
    case unknownReturnCode(Int32)

    public var caseIdentifier: String {
        switch self {
        case .nullOutPointer:         return "nullOutPointer"
        case .machTimebaseInitFailed: return "machTimebaseInitFailed"
        case .unsupportedPlatform:    return "unsupportedPlatform"
        case .unknownReturnCode:      return "unknownReturnCode"
        }
    }
}

// MARK: - BASWallclockNanos

/// Actor wrapping `bas_wallclock_nanos`。 Reads the sleep-
/// INCLUSIVE monotonic clock via Mach time。 Counterpart to
/// `BASMonotonicNanos` (which wraps the sleep-EXCLUDED clock)。
///
/// Use this when you need to detect sleep latency (e.g。 thermal
/// management,attestation freshness checks after resume-from-
/// background)。 For turn-duration measurements,prefer
/// `BASMonotonicNanos` (sleep doesn't「count」)。
public actor BASWallclockNanos {

    /// V1 Swift baseline:`Date().timeIntervalSince1970` in nanos。
    /// Wall-clock,includes sleep,subject to NTP adjustments。
    /// Tests pin on this being the V1 baseline。
    public static func defaultV1Nanos() -> UInt64 {
        return UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
    }

    /// V2 raw C call。 Throws on non-zero return。
    public static func rawCNanos() throws -> UInt64 {
        var out: UInt64 = 0
        let rc = bas_wallclock_nanos(&out)
        switch rc {
        case 0:  return out
        case -1: throw BASWallclockNanosError.nullOutPointer
        case -2: throw BASWallclockNanosError.machTimebaseInitFailed
        case -3: throw BASWallclockNanosError.unsupportedPlatform
        default: throw BASWallclockNanosError.unknownReturnCode(rc)
        }
    }

    /// C-side ABI version pin。 Bumping the C function's
    /// `bas_wallclock_nanos_version` requires updating tests
    /// + this constant simultaneously。
    public static let cBridgeABIVersion: Int32 = 1

    /// Read the live C-side ABI version (calls the C function)。
    public static func liveCBridgeABIVersion() -> Int32 {
        return bas_wallclock_nanos_version()
    }

    // MARK: - Instance state

    private let useCBridge: Bool

    public init(useCBridge: Bool = false) {
        self.useCBridge = useCBridge
    }

    /// Return the current wall-clock nanosecond reading,picking
    /// V1 (Swift Date) / V2 (C mach_absolute_time) per flag snapshot。
    public func current() throws -> UInt64 {
        if useCBridge {
            return try Self.rawCNanos()
        }
        return Self.defaultV1Nanos()
    }

    public var isUsingCBridge: Bool { useCBridge }
}

// MARK: - BASTaskVmInfo

/// Typed snapshot of `task_info(TASK_VM_INFO)` output。 Returned
/// by `BASTaskVmInfoProbe.snapshot()`。
public struct BASTaskVmInfo:
    Sendable, Equatable, Hashable, Codable
{
    /// OS-tracked memory footprint used by jetsam decisions。
    public let physFootprintBytes: UInt64
    /// Bytes the VM compressor has compressed (iOS swap surrogate)。
    public let compressedBytes: UInt64
    /// Private anonymous memory (heap + stack)。
    public let internalBytes: UInt64

    public init(
        physFootprintBytes: UInt64,
        compressedBytes: UInt64,
        internalBytes: UInt64
    ) {
        self.physFootprintBytes = physFootprintBytes
        self.compressedBytes = compressedBytes
        self.internalBytes = internalBytes
    }
}

// MARK: - BASTaskVmInfoError

public enum BASTaskVmInfoError:
    Error, Equatable, Hashable, Sendable, Codable
{
    /// `bas_task_phys_footprint` returned -1 (null `out`)。
    case nullOutPointer
    /// `bas_task_phys_footprint` returned -2 (Mach call failed)。
    case machCallFailed
    /// `bas_task_phys_footprint` returned -3 (non-Apple platform)。
    case unsupportedPlatform
    case unknownReturnCode(Int32)

    public var caseIdentifier: String {
        switch self {
        case .nullOutPointer:      return "nullOutPointer"
        case .machCallFailed:      return "machCallFailed"
        case .unsupportedPlatform: return "unsupportedPlatform"
        case .unknownReturnCode:   return "unknownReturnCode"
        }
    }
}

// MARK: - BASTaskVmInfoProbe

/// Actor wrapping `bas_task_phys_footprint`。 No V1 Swift
/// equivalent (Apple SDK doesn't expose per-process TASK_VM_INFO
/// without using Foundation private APIs)。 The C bridge is the
/// only path — opt-in flag still consulted so callers that
/// don't want any C surface get a nil snapshot。
public actor BASTaskVmInfoProbe {

    /// V2 raw C call。 Throws on non-zero return。
    public static func rawSnapshot() throws -> BASTaskVmInfo {
        var phys: UInt64 = 0
        var comp: UInt64 = 0
        var intl: UInt64 = 0
        let rc = bas_task_phys_footprint(&phys, &comp, &intl)
        switch rc {
        case 0:  return BASTaskVmInfo(
                    physFootprintBytes: phys,
                    compressedBytes: comp,
                    internalBytes: intl)
        case -1: throw BASTaskVmInfoError.nullOutPointer
        case -2: throw BASTaskVmInfoError.machCallFailed
        case -3: throw BASTaskVmInfoError.unsupportedPlatform
        default: throw BASTaskVmInfoError.unknownReturnCode(rc)
        }
    }

    public static let cBridgeABIVersion: Int32 = 1

    public static func liveCBridgeABIVersion() -> Int32 {
        return bas_task_phys_footprint_version()
    }

    private let useCBridge: Bool

    public init(useCBridge: Bool = false) {
        self.useCBridge = useCBridge
    }

    /// Snapshot the current TASK_VM_INFO state。 Returns nil
    /// when the C bridge is disabled (V1 has no equivalent)。
    public func snapshot() throws -> BASTaskVmInfo? {
        if useCBridge {
            return try Self.rawSnapshot()
        }
        return nil
    }

    public var isUsingCBridge: Bool { useCBridge }
}

// MARK: - Flag-aware factories

extension BASWallclockNanos {
    public static func make(
        flags: BASLanguageAugmentationFeatureFlags
    ) async -> BASWallclockNanos {
        let useCBridge = await flags.isEnabled(.cBridgeEnabled)
        return BASWallclockNanos(useCBridge: useCBridge)
    }

    public static func makeWithDefaults() async -> BASWallclockNanos {
        let flags = BASLanguageAugmentationFeatureFlags()
        return await make(flags: flags)
    }
}

extension BASTaskVmInfoProbe {
    public static func make(
        flags: BASLanguageAugmentationFeatureFlags
    ) async -> BASTaskVmInfoProbe {
        let useCBridge = await flags.isEnabled(.cBridgeEnabled)
        return BASTaskVmInfoProbe(useCBridge: useCBridge)
    }

    public static func makeWithDefaults() async -> BASTaskVmInfoProbe {
        let flags = BASLanguageAugmentationFeatureFlags()
        return await make(flags: flags)
    }
}

// MARK: - iOS 27 P6 — App Swap statistics probe

/// Typed surface over `bas_vm_swap_stats` (vm_statistics64
/// rev4/rev5: swapfile pages + App Swap donated pages)。 Probe
/// honesty: nil on ANY non-zero rc — the OS response signal is
/// either real or absent, never guessed (mirrors BASTaskVmInfoProbe)。
public enum BASVmSwapStatsProbe {

    public struct Snapshot: Sendable, Equatable {
        public let swapPages: UInt64
        public let donatedPages: UInt64
    }

    public static let cBridgeABIVersion: Int32 = 1

    public static func liveCBridgeABIVersion() -> Int32 {
        return bas_vm_swap_stats_version()
    }

    /// nil ⇒ unavailable (pre-27 SDK at compile time, pre-rev4
    /// kernel at runtime, or mach failure)。
    public static func rawSnapshot() -> Snapshot? {
        var swap: UInt64 = 0
        var donated: UInt64 = 0
        guard bas_vm_swap_stats(&swap, &donated) == 0 else {
            return nil
        }
        return Snapshot(swapPages: swap, donatedPages: donated)
    }
}
