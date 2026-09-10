// MARK: - BASCPUCountProbe
// 主线 解构 重构: fourth real C function in the C pilot。
// Wraps `bas_cpu_count_logical` (which calls sysctl
// CTL_HW.HW_NCPU on Apple platforms) so Swift callers can
// read the host's logical CPU count for runtime concurrency
// budgeting + cascade telemetry。
//
// Companion to BASMonotonicNanos + BASProcessMemoryProbe +
// BASThreadCountProbe。 Each one a small native systems
// call wrapped in a typed Swift actor — the C pilot's
// "OS-level introspection" surface。
//
// **Use case**: brain hosts running on heterogeneous
// Apple silicon (perf + efficiency cores) want to size
// concurrent work to physical hardware。 ProcessInfo
// .processorCount returns the same value but goes through
// Swift runtime initialization — the direct sysctl path
// is sub-microsecond on Apple silicon。

import Foundation
import BASCSystemBridge

/// Typed error cases for the CPU-count probe。
public enum BASCPUCountProbeError: Error, Equatable,
    Hashable, Sendable, Codable
{
    /// The C function received a null `out` pointer (-1)。
    case nullOutPointer

    /// The `sysctl` call failed (-2)。
    case sysctlFailed

    /// Build host is not Apple (-3)。
    case unsupportedPlatform

    /// Unknown return code from the C function。
    case unknownReturnCode(Int32)

    public var caseIdentifier: String {
        switch self {
        case .nullOutPointer: return "nullOutPointer"
        case .sysctlFailed: return "sysctlFailed"
        case .unsupportedPlatform:
            return "unsupportedPlatform"
        case .unknownReturnCode:
            return "unknownReturnCode"
        }
    }
}

/// Actor-isolated wrapper around the C CPU-count probe。
/// Follows the same pattern as the other three C probes:
/// sampled-once useCBridge flag,V1 fallback returns 0
/// when the C bridge is opted out。
public actor BASCPUCountProbe {

    /// ABI version pin matching the C-side
    /// `bas_cpu_count_logical_version`。
    public static let cBridgeABIVersion: Int32 = 1

    /// Live C-side version read。
    public static func liveCBridgeABIVersion() -> Int32 {
        return bas_cpu_count_logical_version()
    }

    private let useCBridge: Bool

    public init(useCBridge: Bool = false) {
        self.useCBridge = useCBridge
    }

    public var isUsingCBridge: Bool { useCBridge }

    /// Read the host's logical CPU count via sysctl。
    /// Throws typed errors on the V2 path; returns 0 on
    /// the V1 path (no syscall)。
    public func current() throws -> Int32 {
        guard useCBridge else { return 0 }
        var out: Int32 = 0
        let rc = bas_cpu_count_logical(&out)
        switch rc {
        case 0: return out
        case -1:
            throw BASCPUCountProbeError.nullOutPointer
        case -2:
            throw BASCPUCountProbeError.sysctlFailed
        case -3:
            throw BASCPUCountProbeError
                .unsupportedPlatform
        default:
            throw BASCPUCountProbeError
                .unknownReturnCode(rc)
        }
    }
}
