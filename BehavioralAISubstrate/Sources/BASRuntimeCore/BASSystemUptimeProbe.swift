// MARK: - BASSystemUptimeProbe
// 主线 解构 重构 Round 3: fifth real C function in the
// C pilot。 Wraps `bas_system_uptime_seconds` (which calls
// sysctl(KERN_BOOTTIME) + gettimeofday on Apple platforms)
// so Swift callers can read host uptime for cascade
// telemetry + cross-process correlation。
//
// Companion to BASMonotonicNanos + BASProcessMemoryProbe +
// BASThreadCountProbe + BASCPUCountProbe。 Each one a
// small native systems call wrapped in a typed Swift
// actor — the C pilot's "OS-level introspection" surface。

import Foundation
import BASCSystemBridge

/// Typed error cases for the system-uptime probe。
public enum BASSystemUptimeProbeError: Error, Equatable,
    Hashable, Sendable, Codable
{
    /// The C function received a null `out` pointer (-1)。
    case nullOutPointer

    /// `sysctl(KERN_BOOTTIME)` OR `gettimeofday` failed (-2)。
    case sysctlOrGettimeofdayFailed

    /// Build host is not Apple (-3)。
    case unsupportedPlatform

    /// Unknown return code from the C function。
    case unknownReturnCode(Int32)

    public var caseIdentifier: String {
        switch self {
        case .nullOutPointer: return "nullOutPointer"
        case .sysctlOrGettimeofdayFailed:
            return "sysctlOrGettimeofdayFailed"
        case .unsupportedPlatform:
            return "unsupportedPlatform"
        case .unknownReturnCode:
            return "unknownReturnCode"
        }
    }
}

/// Actor-isolated wrapper around the C system-uptime probe。
public actor BASSystemUptimeProbe {

    /// ABI version pin matching the C-side
    /// `bas_system_uptime_seconds_version`。
    public static let cBridgeABIVersion: Int32 = 1

    /// Live C-side version read。
    public static func liveCBridgeABIVersion() -> Int32 {
        return bas_system_uptime_seconds_version()
    }

    private let useCBridge: Bool

    public init(useCBridge: Bool = false) {
        self.useCBridge = useCBridge
    }

    public var isUsingCBridge: Bool { useCBridge }

    /// Read host uptime in seconds since boot。 Throws
    /// typed errors on V2 path; returns 0 on V1 path
    /// (no syscall)。
    public func current() throws -> Int64 {
        guard useCBridge else { return 0 }
        var out: Int64 = 0
        let rc = bas_system_uptime_seconds(&out)
        switch rc {
        case 0: return out
        case -1:
            throw BASSystemUptimeProbeError.nullOutPointer
        case -2:
            throw BASSystemUptimeProbeError
                .sysctlOrGettimeofdayFailed
        case -3:
            throw BASSystemUptimeProbeError
                .unsupportedPlatform
        default:
            throw BASSystemUptimeProbeError
                .unknownReturnCode(rc)
        }
    }
}
