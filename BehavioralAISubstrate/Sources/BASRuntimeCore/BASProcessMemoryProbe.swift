// MARK: - BASProcessMemoryProbe
// 主线 全面 提升: second real C function in the C pilot。
// Wraps `bas_process_resident_memory_bytes` (which calls
// `mach_task_basic_info` on Apple platforms) so Swift
// callers can read RSS for cascade telemetry。
//
// Companion to BASMonotonicNanos (chapter 703 first C
// function). Together they prove the C pilot can carry
// MULTIPLE production-shaped functions,not just a single
// proof-of-concept call。
//
// **Use case**: long-running brain hosts want to monitor
// memory pressure during cascade execution。 Reading RSS
// at brain init + after N turns gives hosts the
// resident-memory delta — useful for leak detection +
// thermal-budgeting telemetry。

import Foundation
import BASCSystemBridge

/// Typed error cases for the resident-memory probe。
public enum BASProcessMemoryProbeError: Error, Equatable,
    Hashable, Sendable, Codable
{
    /// The C function received a null `out` pointer (-1)。
    /// Should never happen via this Swift wrapper since
    /// we always supply a valid stack variable。
    case nullOutPointer

    /// The Mach `task_info` call failed (-2)。 Extremely
    /// rare — would indicate kernel-level task port
    /// corruption。
    case machTaskInfoFailed

    /// Build host is not Apple (-3)。 Substrate ships
    /// Apple-only in production;this case surfaces only
    /// in Linux build-host inspections。
    case unsupportedPlatform

    /// Unknown return code from the C function。 Carries
    /// the raw int32_t so the audit ledger can record
    /// the unexpected value。
    case unknownReturnCode(Int32)

    public var caseIdentifier: String {
        switch self {
        case .nullOutPointer: return "nullOutPointer"
        case .machTaskInfoFailed:
            return "machTaskInfoFailed"
        case .unsupportedPlatform:
            return "unsupportedPlatform"
        case .unknownReturnCode:
            return "unknownReturnCode"
        }
    }
}

/// Actor-isolated wrapper around the C resident-memory
/// probe。 Follows the same pattern as BASMonotonicNanos:
/// sampled-once useCBridge flag,V1 fallback returns 0
/// when the C bridge is opted out。
public actor BASProcessMemoryProbe {

    /// ABI version pin matching the C-side
    /// `bas_process_resident_memory_bytes_version`。
    public static let cBridgeABIVersion: Int32 = 1

    /// Live C-side version read。
    public static func liveCBridgeABIVersion() -> Int32 {
        return bas_process_resident_memory_bytes_version()
    }

    /// Sampled-once flag — when false,`current()` returns
    /// 0 instead of querying the C bridge。 Mirrors
    /// BASMonotonicNanos's V1/V2 semantics。
    private let useCBridge: Bool

    public init(useCBridge: Bool = false) {
        self.useCBridge = useCBridge
    }

    public var isUsingCBridge: Bool { useCBridge }

    /// Read the calling process's RSS in bytes。 Throws
    /// typed errors on the V2 path; returns 0 on the
    /// V1 path (no syscall)。
    public func current() throws -> UInt64 {
        guard useCBridge else { return 0 }
        var out: UInt64 = 0
        let rc = bas_process_resident_memory_bytes(&out)
        switch rc {
        case 0: return out
        case -1:
            throw BASProcessMemoryProbeError
                .nullOutPointer
        case -2:
            throw BASProcessMemoryProbeError
                .machTaskInfoFailed
        case -3:
            throw BASProcessMemoryProbeError
                .unsupportedPlatform
        default:
            throw BASProcessMemoryProbeError
                .unknownReturnCode(rc)
        }
    }
}
