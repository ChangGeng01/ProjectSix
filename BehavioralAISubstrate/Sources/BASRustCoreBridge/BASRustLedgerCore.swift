// MARK: - BASRustLedgerCore
// 主线 Ledger 抽取: stateless append-only chain step
// extracted from Swift CryptoKit into Rust。 The
// BASSovereignAuditLedger Swift implementation (~1323
// LOC) keeps its storage + state machine + querying;
// this commit moves the CRYPTOGRAPHIC CHAIN STEP into
// Rust。
//
// **What this provides**: a pure function
// `appendStep(previousHash:payload:)` that returns the
// next chain hash via SHA256(prev_hash || length(payload)
// big-endian || payload)。 No tracker handle,no
// allocator,no shared state — just the math。
//
// **Why this matters**: the chain step is the
// integrity-critical part of any append-only ledger。
// Moving it into Rust:
//   - Single cryptographic implementation (no two SHA256
//     paths drifting between Swift CryptoKit and Rust
//     sha2)
//   - Same length-prefixed encoding as
//     `bas_rust_tracker_compute_chain_hash` for
//     cross-primitive consistency
//   - Pure function = trivially testable + side-effect-
//     free

import Foundation

#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

/// Typed errors for the Rust ledger core step。
public enum BASRustLedgerCoreError: Error, Equatable,
    Hashable, Sendable, Codable
{
    /// Either previousHash wasn't 32 bytes,or the Rust
    /// FFI returned null-pointer error。
    case invalidInputSize

    /// Rust XCFramework unavailable on this platform
    /// (watchOS / Linux build host)。
    case rustBridgeUnavailableOnPlatform

    /// Unknown Rust return code。
    case unknownReturnCode(Int32)

    public var caseIdentifier: String {
        switch self {
        case .invalidInputSize:
            return "invalidInputSize"
        case .rustBridgeUnavailableOnPlatform:
            return "rustBridgeUnavailableOnPlatform"
        case .unknownReturnCode:
            return "unknownReturnCode"
        }
    }
}

/// Stateless namespace wrapping the Rust ledger append-
/// step FFI。 Use as a namespace,not an instantiable
/// type — there's no shared state to initialize。
public enum BASRustLedgerCore {

    #if os(iOS) || os(macOS)
    /// ABI version pin matching the Rust-side
    /// `bas_rust_ledger_append_step_version`。
    public static let abiVersion: Int32 = 1

    /// Live Rust-side version read。
    public static func liveABIVersion() -> Int32 {
        return bas_rust_ledger_append_step_version()
    }

    /// Compute the next chain hash given a previous hash
    /// (exactly 32 bytes) and an arbitrary payload。
    /// Returns the 32-byte SHA256 digest as Data。
    ///
    /// Genesis case:pass `Data(repeating: 0, count: 32)`
    /// as `previousHash` for the first ledger entry。
    /// Subsequent entries pass the previous entry's
    /// chain hash。
    public static func appendStep(
        previousHash: Data,
        payload: Data
    ) throws -> Data {
        guard previousHash.count == 32 else {
            throw BASRustLedgerCoreError
                .invalidInputSize
        }
        var outHash = [UInt8](
            repeating: 0, count: 32)
        let rc = previousHash.withUnsafeBytes {
            prevRaw -> Int32 in
            let prevPtr = prevRaw
                .bindMemory(to: UInt8.self)
                .baseAddress!
            return payload.withUnsafeBytes {
                payloadRaw -> Int32 in
                let payloadPtr: UnsafePointer<UInt8>? =
                    payload.isEmpty
                        ? nil
                        : payloadRaw
                            .bindMemory(to: UInt8.self)
                            .baseAddress
                return outHash
                    .withUnsafeMutableBufferPointer {
                        outBuf -> Int32 in
                        bas_rust_ledger_append_step(
                            prevPtr,
                            payloadPtr,
                            payload.count,
                            outBuf.baseAddress!)
                    }
            }
        }
        switch rc {
        case 0:
            return Data(outHash)
        case -1:
            throw BASRustLedgerCoreError
                .invalidInputSize
        default:
            throw BASRustLedgerCoreError
                .unknownReturnCode(rc)
        }
    }

    /// 32-byte genesis hash (all zeros) — first chain
    /// step's `previousHash`。 Matches the
    /// BASSovereignAuditLedger genesis convention。
    public static let genesisHash: Data = Data(
        repeating: 0, count: 32)

    #else

    /// Stub on platforms where the XCFramework is
    /// unavailable。 Always throws。
    public static let abiVersion: Int32 = 0

    public static func liveABIVersion() -> Int32 { 0 }

    public static func appendStep(
        previousHash: Data,
        payload: Data
    ) throws -> Data {
        throw BASRustLedgerCoreError
            .rustBridgeUnavailableOnPlatform
    }

    public static let genesisHash: Data = Data(
        repeating: 0, count: 32)

    #endif
}
