// MARK: - BASThreadCountProbe
// 主线 解构 重构: third real C function in the C pilot。
// Wraps `bas_thread_count` (which calls `task_threads` on
// Apple platforms) so Swift callers can read the calling
// process's active Mach thread count for cascade telemetry。
//
// Companion to BASMonotonicNanos + BASProcessMemoryProbe。
// Together the three probes form the C pilot's "OS-level
// introspection" surface — each one a small native
// systems call wrapped in a typed Swift actor。
//
// **Use case**: brain hosts running long sessions want
// to detect runaway-task / thread-leak conditions。
// Sampling the thread count at brain init + after N turns
// gives hosts a typed observation surface for cascade
// thread accounting。

import Foundation
import BASCSystemBridge

/// Typed error cases for the thread-count probe。
public enum BASThreadCountProbeError: Error, Equatable,
    Hashable, Sendable, Codable
{
    /// The C function received a null `out` pointer (-1)。
    case nullOutPointer

    /// The Mach `task_threads` call failed (-2)。
    case machTaskThreadsFailed

    /// Build host is not Apple (-3)。
    case unsupportedPlatform

    /// Unknown return code from the C function。
    case unknownReturnCode(Int32)

    public var caseIdentifier: String {
        switch self {
        case .nullOutPointer: return "nullOutPointer"
        case .machTaskThreadsFailed:
            return "machTaskThreadsFailed"
        case .unsupportedPlatform:
            return "unsupportedPlatform"
        case .unknownReturnCode:
            return "unknownReturnCode"
        }
    }
}

/// Actor-isolated wrapper around the C thread-count probe。
/// Follows the BASProcessMemoryProbe pattern: sampled-once
/// useCBridge flag,V1 fallback returns 0 when the C bridge
/// is opted out。
public actor BASThreadCountProbe {

    /// ABI version pin matching the C-side
    /// `bas_thread_count_version`。
    public static let cBridgeABIVersion: Int32 = 1

    /// Live C-side version read。
    public static func liveCBridgeABIVersion() -> Int32 {
        return bas_thread_count_version()
    }

    /// Sampled-once flag — when false,`current()` returns
    /// 0 instead of querying the C bridge。
    private let useCBridge: Bool

    public init(useCBridge: Bool = false) {
        self.useCBridge = useCBridge
    }

    public var isUsingCBridge: Bool { useCBridge }

    /// Read the calling process's active Mach thread count。
    /// Throws typed errors on the V2 path; returns 0 on
    /// the V1 path (no syscall)。
    public func current() throws -> Int32 {
        guard useCBridge else { return 0 }
        var out: Int32 = 0
        let rc = bas_thread_count(&out)
        switch rc {
        case 0: return out
        case -1:
            throw BASThreadCountProbeError.nullOutPointer
        case -2:
            throw BASThreadCountProbeError
                .machTaskThreadsFailed
        case -3:
            throw BASThreadCountProbeError
                .unsupportedPlatform
        default:
            throw BASThreadCountProbeError
                .unknownReturnCode(rc)
        }
    }
}
