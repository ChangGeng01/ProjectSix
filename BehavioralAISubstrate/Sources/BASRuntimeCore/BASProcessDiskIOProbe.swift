// MARK: - BASProcessDiskIOProbe
// 持续性 发展: eighth real C function in the C pilot。
// Wraps `bas_process_disk_io_blocks` (which calls
// `getrusage(RUSAGE_SELF)` ru_inblock + ru_oublock on
// Apple platforms) so Swift callers can read process
// block I/O counts。
//
// **Use case**: hosts running long-lived brain sessions
// want to detect when disk I/O climbs unexpectedly。
// E.g. SQL pilot WAL checkpointing,Codable persistence,
// or fault-mapped pages dragging in disk reads。 Sampling
// in_block / out_block across snapshots gives the I/O
// delta — paired with CPU time delta and RSS delta this
// completes a "what's the brain spending cycles on" view。

import Foundation
import BASCSystemBridge

/// Typed error cases for the disk-I/O probe。
public enum BASProcessDiskIOProbeError: Error, Equatable,
    Hashable, Sendable, Codable
{
    /// Either out_in or out_out was null (-1)。
    case nullOutPointer

    /// `getrusage` syscall failed (-2)。
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

/// Disk-I/O sample — input + output block counts at a
/// point in time。 Codable + Equatable so health
/// snapshots can persist + diff across captures。
public struct BASProcessDiskIOSample: Codable, Equatable,
    Sendable, Hashable
{
    /// `ru_inblock` — block input operations (reads
    /// from disk that required physical I/O,not cache
    /// hits)。 Cumulative since process start。
    public let inputBlocks: Int64

    /// `ru_oublock` — block output operations (writes
    /// to disk)。 Cumulative since process start。
    public let outputBlocks: Int64

    public init(inputBlocks: Int64, outputBlocks: Int64) {
        self.inputBlocks = inputBlocks
        self.outputBlocks = outputBlocks
    }

    /// Total blocks (in + out)。 Useful as a single-
    /// number "is this brain touching disk a lot" metric。
    public var totalBlocks: Int64 {
        return inputBlocks + outputBlocks
    }
}

/// Actor-isolated wrapper around the C disk-I/O probe。
public actor BASProcessDiskIOProbe {

    /// ABI version pin matching the C-side
    /// `bas_process_disk_io_blocks_version`。
    public static let cBridgeABIVersion: Int32 = 1

    /// Live C-side version read。
    public static func liveCBridgeABIVersion() -> Int32 {
        return bas_process_disk_io_blocks_version()
    }

    private let useCBridge: Bool

    public init(useCBridge: Bool = false) {
        self.useCBridge = useCBridge
    }

    public var isUsingCBridge: Bool { useCBridge }

    /// Sample the current process's block I/O counts。
    /// V1 path returns zero sample without calling
    /// getrusage。
    public func current() throws -> BASProcessDiskIOSample {
        guard useCBridge else {
            return BASProcessDiskIOSample(
                inputBlocks: 0, outputBlocks: 0)
        }
        var i: Int64 = 0
        var o: Int64 = 0
        let rc = bas_process_disk_io_blocks(&i, &o)
        switch rc {
        case 0:
            return BASProcessDiskIOSample(
                inputBlocks: i, outputBlocks: o)
        case -1:
            throw BASProcessDiskIOProbeError
                .nullOutPointer
        case -2:
            throw BASProcessDiskIOProbeError
                .getrusageFailed
        case -3:
            throw BASProcessDiskIOProbeError
                .unsupportedPlatform
        default:
            throw BASProcessDiskIOProbeError
                .unknownReturnCode(rc)
        }
    }
}
