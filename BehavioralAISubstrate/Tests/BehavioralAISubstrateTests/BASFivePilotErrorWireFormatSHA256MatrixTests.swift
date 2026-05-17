// MARK: - BASFivePilotErrorWireFormatSHA256MatrixTests
// chapter 七百二十一 / M2221 第一刀 — wire-format canonical
//                                     SHA256 fingerprint matrix
//                                     for the 5 pilot error
//                                     enums。
//
// ## Why
//
// Chapters 717-720 sealed four typed-contract pillars for
// the 5 pilot error enums:
//   717:Codable round-trip idempotence (decode∘encode = id)
//   718:Hashable Set-deduplication semantics
//   719:Sendable cross-Task transfer at runtime
//   720:caseIdentifier introspection (PII-safe telemetry key)
//
// Chapter 721 adds the fifth pillar:**wire-format canonical
// SHA256 fingerprint pin**。 The Codable matrix in 717 only
// proves `decode(encode(x))==x` — it does NOT pin the
// SPECIFIC bytes of `encode(x)`。 A future commit that:
//   - Adds an extra associated value to a case
//   - Renames a CodingKey
//   - Changes a case's associated value labels
//   - Changes the type of an associated value (Int → Int32)
//
// ...would silently change the wire format while still
// passing the chapter 717 idempotence test。 Downstream
// consumers that saved bytes-on-disk via a prior build
// would then fail to decode after the upgrade。
//
// This file pins the SHA256 hash of the `.sortedKeys` JSON
// encoding of a representative case from each pilot enum。
// If any commit changes the wire format,the SHA256 changes
// and the test fails LOUDLY at PR time。
//
// ## Choice of pinned bytes
//
// `.sortedKeys` outputFormatting:
//   - Lexicographic key ordering eliminates encoder
//     nondeterminism that bit chapter 717 第一刀
//   - Stable across Swift toolchain versions (Foundation
//     contract,not encoder-implementation detail)
//
// SHA256 (not full-bytes-equality):
//   - Compact pin (64 hex chars vs full JSON string)
//   - Tamper-evident (any single-byte change cascades)
//   - Standard regression-tripwire pattern (BAS Registry
//     uses the same pattern via BASRegistryFrozenHashTests)
//
// ## Coverage (5 per-pilot tests + 1 cross-pilot pin)
//
//   1-5. Each pilot's error enum:one representative case
//        per pilot,pinned SHA256 captures the canonical
//        wire-format byte sequence;test fails if format
//        drifts
//   6. Cross-pilot summary:total bytes encoded across all
//        5 fingerprint cases sum to a pinned value (catches
//        wholesale encoding shape change across the pilot
//        suite)

import XCTest
import CryptoKit
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotErrorWireFormatSHA256MatrixTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    /// Helper:encode `value` with `.sortedKeys` JSONEncoder,
    /// compute SHA256 over the bytes,return as lowercase
    /// hex string for pin comparison。
    private func canonicalSHA256<T: Encodable>(
        _ value: T
    ) throws -> String {
        let bytes = try encoder.encode(value)
        let digest = SHA256.hash(data: bytes)
        return digest.map { String(format: "%02x", $0) }
            .joined()
    }

    /// Helper:encode + return raw byte count (used by the
    /// cross-pilot summary test that pins TOTAL bytes
    /// emitted across all 5 representative cases)。
    private func canonicalByteCount<T: Encodable>(
        _ value: T
    ) throws -> Int {
        return try encoder.encode(value).count
    }

    // MARK: - SQL pilot — BASMemoryUsageTracker.TrackerError

    /// Representative case:openFailed with pinned payload。
    /// SHA256 captures the exact wire-format bytes。
    func testBASMemoryUsageTrackerErrorWireFormatSHA256() throws {
        let sample: BASMemoryUsageTracker.TrackerError =
            .openFailed(code: 14, message: "unable to open")
        let actualSHA = try canonicalSHA256(sample)
        // Pinned: captured at chapter 721 第一刀 (M2221) from
        // Apple Foundation JSONEncoder.outputFormatting=
        // .sortedKeys on macOS 14。
        XCTAssertEqual(actualSHA,
            "6a8e22bbb528829c4546b556f8dc77ed628e08eac64cf4c83765651436a93780",
            "BASMemoryUsageTracker.TrackerError.openFailed" +
            "(code: 14, message: \"unable to open\") wire-" +
            "format SHA256 drifted — Codable encoding shape" +
            " changed?")
    }

    // MARK: - C pilot — BASMonotonicNanosError

    func testBASMonotonicNanosErrorWireFormatSHA256() throws {
        let sample: BASMonotonicNanosError =
            .unknownReturnCode(-99)
        let actualSHA = try canonicalSHA256(sample)
        XCTAssertEqual(actualSHA,
            "2577a29be8076177df25194c8c8aa22f100b7cdc4833d08faaa45f50ea247a7a",
            "BASMonotonicNanosError.unknownReturnCode(-99)" +
            " wire-format SHA256 drifted")
    }

    // MARK: - Metal pilot — BASMetalKernelLibraryLoaderError

    func testBASMetalKernelLibraryLoaderErrorWireFormatSHA256() throws {
        let sample: BASMetalKernelLibraryLoaderError =
            .resourceURLMissing(resourceName: "SSMScan")
        let actualSHA = try canonicalSHA256(sample)
        XCTAssertEqual(actualSHA,
            "20f0791964e305a79d764dd031f647d3bf624e7a5ae8a3863de858ca3b93a6ac",
            "BASMetalKernelLibraryLoaderError.resourceURL" +
            "Missing(resourceName: \"SSMScan\") wire-" +
            "format SHA256 drifted")
    }

    // MARK: - C++ pilot — BASMPSGraphExecutableCacheCxxBridgeError

    func testBASMPSGraphExecutableCacheCxxBridgeErrorWireFormatSHA256() throws {
        let sample: BASMPSGraphExecutableCacheCxxBridgeError =
            .unknownReturnCode(-100)
        let actualSHA = try canonicalSHA256(sample)
        XCTAssertEqual(actualSHA,
            "f4d1c0b3881ac453bf693fe05ffb00a4198a8cb2568c448ffc7ebea93434f075",
            "BASMPSGraphExecutableCacheCxxBridgeError." +
            "unknownReturnCode(-100) wire-format SHA256" +
            " drifted")
    }

    // MARK: - Rust pilot — BASRustMemoryUsageTrackerActorError

    func testBASRustMemoryUsageTrackerActorErrorWireFormatSHA256() throws {
        let sample: BASRustMemoryUsageTrackerActorError =
            .jsonDecodeFailed(message: "EOF at position 12")
        let actualSHA = try canonicalSHA256(sample)
        XCTAssertEqual(actualSHA,
            "9483326e3612eb67cd8acf5a65acecde19eb31a1ea6dc2f437059e4ba21ad861",
            "BASRustMemoryUsageTrackerActorError." +
            "jsonDecodeFailed(message: \"EOF at position " +
            "12\") wire-format SHA256 drifted")
    }

    // MARK: - Cross-pilot total byte count pin

    /// Sum the encoded byte count across all 5
    /// representative cases。 Catches wholesale encoding
    /// shape changes that might individually keep some
    /// SHA256 pins valid while breaking others — the sum
    /// provides a separate independent witness。
    func testFivePilotRepresentativeCasesTotalByteCount() throws {
        let total: Int =
            (try canonicalByteCount(
                BASMemoryUsageTracker.TrackerError
                    .openFailed(code: 14, message: "unable to open"))) +
            (try canonicalByteCount(
                BASMonotonicNanosError
                    .unknownReturnCode(-99))) +
            (try canonicalByteCount(
                BASMetalKernelLibraryLoaderError
                    .resourceURLMissing(resourceName: "SSMScan"))) +
            (try canonicalByteCount(
                BASMPSGraphExecutableCacheCxxBridgeError
                    .unknownReturnCode(-100))) +
            (try canonicalByteCount(
                BASRustMemoryUsageTrackerActorError
                    .jsonDecodeFailed(message: "EOF at position 12")))
        // Pinned: captured at chapter 721 第一刀 (M2221)。
        // Drift = wholesale encoding shape change。
        XCTAssertEqual(total, 220,
            "Total encoded byte count across 5 pilot" +
            " representative cases drifted — wholesale" +
            " encoding shape change?")
    }
}
