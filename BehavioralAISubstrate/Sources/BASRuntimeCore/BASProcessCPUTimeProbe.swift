// MARK: - BASProcessCPUTimeProbe
// 持续性 发展: seventh real C function in the C pilot。
// Wraps `bas_process_cpu_time_micros` (which calls
// `getrusage(RUSAGE_SELF)` on Apple platforms) so Swift
// callers can read user + system CPU microseconds for
// cascade telemetry — complements wall-clock latency。
//
// **Why this matters**: wall-clock latency (BASMonotonic
// Nanos) includes I/O wait + sleep + dispatcher gaps。
// CPU time only counts cycles the kernel scheduled FOR
// this process。 The ratio is the actual specialty
// signal:
//   - wall ≈ CPU → CPU-bound work (BASCognitiveBrain
//                  cascade running tight)
//   - wall ≫ CPU → I/O / GPU / network bound (Metal
//                  dispatch waiting on GPU,SQL on disk)

import Foundation
import BASCSystemBridge

/// Typed error cases for the CPU-time probe。
public enum BASProcessCPUTimeProbeError: Error, Equatable,
    Hashable, Sendable, Codable
{
    /// Either out_user or out_system was null (-1)。
    case nullOutPointer

    /// `getrusage` syscall failed (-2)。 Extremely rare —
    /// only fails on EFAULT (bad pointer,which the Swift
    /// wrapper never produces) or EINVAL (invalid who arg,
    /// which the wrapper hard-codes to RUSAGE_SELF)。
    case getrusageFailed

    /// Non-Apple build host (-3)。
    case unsupportedPlatform

    /// Unknown return code。
    case unknownReturnCode(Int32)

    public var caseIdentifier: String {
        switch self {
        case .nullOutPointer: return "nullOutPointer"
        case .getrusageFailed: return "getrusageFailed"
        case .unsupportedPlatform:
            return "unsupportedPlatform"
        case .unknownReturnCode:
            return "unknownReturnCode"
        }
    }
}

/// CPU-time snapshot — user + system microseconds at a
/// point in time。 Codable + Equatable so brain health
/// snapshots can persist it for trend analysis (CPU-time
/// per snapshot,delta across captures)。
public struct BASProcessCPUTimeSample: Codable, Equatable,
    Sendable, Hashable
{
    /// User-mode CPU microseconds since process start。
    public let userMicros: Int64

    /// System-mode CPU microseconds since process start。
    /// Counts time the kernel spent on behalf of this
    /// process (syscalls,page faults handled,etc)。
    public let systemMicros: Int64

    public init(userMicros: Int64, systemMicros: Int64) {
        self.userMicros = userMicros
        self.systemMicros = systemMicros
    }

    /// Total CPU time (user + system) in microseconds。
    public var totalMicros: Int64 {
        return userMicros + systemMicros
    }
}

/// Actor-isolated wrapper around the C CPU-time probe。
public actor BASProcessCPUTimeProbe {

    /// ABI version pin matching the C-side
    /// `bas_process_cpu_time_micros_version`。
    public static let cBridgeABIVersion: Int32 = 1

    /// Live C-side version read。
    public static func liveCBridgeABIVersion() -> Int32 {
        return bas_process_cpu_time_micros_version()
    }

    private let useCBridge: Bool

    public init(useCBridge: Bool = false) {
        self.useCBridge = useCBridge
    }

    public var isUsingCBridge: Bool { useCBridge }

    /// Sample the current process's user + system CPU
    /// time。 V1 path returns zero sample without
    /// calling getrusage。
    public func current() throws -> BASProcessCPUTimeSample {
        guard useCBridge else {
            return BASProcessCPUTimeSample(
                userMicros: 0, systemMicros: 0)
        }
        var u: Int64 = 0
        var s: Int64 = 0
        let rc = bas_process_cpu_time_micros(&u, &s)
        switch rc {
        case 0:
            return BASProcessCPUTimeSample(
                userMicros: u, systemMicros: s)
        case -1:
            throw BASProcessCPUTimeProbeError
                .nullOutPointer
        case -2:
            throw BASProcessCPUTimeProbeError
                .getrusageFailed
        case -3:
            throw BASProcessCPUTimeProbeError
                .unsupportedPlatform
        default:
            throw BASProcessCPUTimeProbeError
                .unknownReturnCode(rc)
        }
    }
}
