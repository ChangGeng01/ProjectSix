// MARK: - BASPhysicalMemoryProbe
// 主线 解构 重构 Round 3: sixth real C function in the
// C pilot。 Wraps `bas_physical_memory_bytes` (which calls
// sysctl(CTL_HW, HW_MEMSIZE) on Apple platforms) so Swift
// callers can read total physical RAM。 Counterpart to
// BASProcessMemoryProbe (RSS):RSS tells you how much YOU
// use,this tells you the total available。 Ratio gives
// memory-pressure dashboards a real denominator。

import Foundation
import BASCSystemBridge

/// Typed error cases for the physical-memory probe。
public enum BASPhysicalMemoryProbeError: Error, Equatable,
    Hashable, Sendable, Codable
{
    /// The C function received a null `out` pointer (-1)。
    case nullOutPointer

    /// `sysctl(HW_MEMSIZE)` failed (-2)。
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

/// Actor-isolated wrapper around the C physical-memory
/// probe。 Returns the host's total physical RAM in
/// bytes (uint64,since modern Apple silicon can exceed
/// 4 GB — HW_MEMSIZE supersedes HW_PHYSMEM for this
/// reason)。
public actor BASPhysicalMemoryProbe {

    /// ABI version pin matching the C-side
    /// `bas_physical_memory_bytes_version`。
    public static let cBridgeABIVersion: Int32 = 1

    /// Live C-side version read。
    public static func liveCBridgeABIVersion() -> Int32 {
        return bas_physical_memory_bytes_version()
    }

    private let useCBridge: Bool

    public init(useCBridge: Bool = false) {
        self.useCBridge = useCBridge
    }

    public var isUsingCBridge: Bool { useCBridge }

    /// Read total physical RAM in bytes。 Throws typed
    /// errors on V2 path; returns 0 on V1 path。
    public func current() throws -> UInt64 {
        guard useCBridge else { return 0 }
        var out: UInt64 = 0
        let rc = bas_physical_memory_bytes(&out)
        switch rc {
        case 0: return out
        case -1:
            throw BASPhysicalMemoryProbeError.nullOutPointer
        case -2:
            throw BASPhysicalMemoryProbeError.sysctlFailed
        case -3:
            throw BASPhysicalMemoryProbeError
                .unsupportedPlatform
        default:
            throw BASPhysicalMemoryProbeError
                .unknownReturnCode(rc)
        }
    }
}
