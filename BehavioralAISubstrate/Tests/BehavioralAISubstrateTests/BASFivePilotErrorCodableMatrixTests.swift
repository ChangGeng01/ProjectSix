// MARK: - BASFivePilotErrorCodableMatrixTests
// chapter 七百十七 / M2213 第一刀 — comprehensive Codable
//                                   round-trip coverage
//                                   matrix for all 5
//                                   pilot error enums。
//
// ## Why
//
// Each pilot ships its own error enum with Codable
// conformance for wire-format compatibility。 Individual
// pilot test files cover their own enum cases (chapters
// 702-706 each contributed 3-6 Codable round-trip tests
// for their own error type)。
//
// This file adds a MATRIX-style test that:
//   1. Encodes EVERY case of every pilot error enum
//   2. Decodes back
//   3. Asserts the decoded value equals the original
//   4. Asserts the decoded value can be re-encoded to
//      the same bytes (idempotence)
//
// Catches future Codable conformance drift (e.g. someone
// adds a case without keeping it round-trippable)。
//
// ## Coverage (5 tests + 1 cross-pilot consistency)
//
//   1-5. Each pilot's full error enum case matrix
//   6. All 5 enums share Codable + Equatable + Sendable
//      conformance contract

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotErrorCodableMatrixTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Helper:assert encode → decode → re-encode is
    /// idempotent。 Equality is the test;byte-equality
    /// of the two encodes is the secondary assertion
    /// (proves no encoding nondeterminism)。
    private func assertCodableRoundTrip<T: Codable & Equatable>(
        _ value: T,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let data1 = try encoder.encode(value)
        let decoded = try decoder.decode(T.self, from: data1)
        XCTAssertEqual(decoded, value,
            "decoded value must equal original",
            file: file, line: line)
        let data2 = try encoder.encode(decoded)
        XCTAssertEqual(data1, data2,
            "re-encode must be byte-identical (no" +
            " encoding nondeterminism)",
            file: file, line: line)
    }

    // MARK: - SQL pilot — BASMemoryUsageTracker.TrackerError

    func testBASMemoryUsageTrackerErrorAllCasesRoundTrip() throws {
        let cases: [BASMemoryUsageTracker.TrackerError] = [
            .openFailed(code: 14, message: "unable to open"),
            .prepareFailed(sql: "SELECT *", message: "syntax"),
            .stepFailed(sql: "INSERT", message: "constraint"),
            .schemaVersionMismatch(found: 2, expected: 1),
            .unknownRecord(id: "missing-uuid")
        ]
        for c in cases {
            try assertCodableRoundTrip(c)
        }
    }

    // MARK: - C pilot — BASMonotonicNanosError

    func testBASMonotonicNanosErrorAllCasesRoundTrip() throws {
        let cases: [BASMonotonicNanosError] = [
            .nullOutPointer,
            .clockGetTimeSyscallFailed,
            .unknownReturnCode(-99),
            .unknownReturnCode(0),
            .unknownReturnCode(Int32.max)
        ]
        for c in cases {
            try assertCodableRoundTrip(c)
        }
    }

    // MARK: - Metal pilot — BASMetalKernelLibraryLoaderError

    func testBASMetalKernelLibraryLoaderErrorAllCasesRoundTrip() throws {
        let cases: [BASMetalKernelLibraryLoaderError] = [
            .metalUnavailableOnPlatform,
            .mtlDeviceUnavailable,
            .resourceURLMissing(
                resourceName: "PhantomShader"),
            .resourceReadFailed(message: "EIO"),
            .metalCompilationFailed(
                message: "syntax error")
        ]
        for c in cases {
            try assertCodableRoundTrip(c)
        }
    }

    // MARK: - C++ pilot — BASMPSGraphExecutableCacheCxxBridgeError

    func testBASMPSGraphExecutableCacheCxxBridgeErrorAllCasesRoundTrip() throws {
        let cases: [BASMPSGraphExecutableCacheCxxBridgeError] = [
            .nullPointer,
            .cxxInternalException,
            .unknownReturnCode(-99),
            .unknownReturnCode(42)
        ]
        for c in cases {
            try assertCodableRoundTrip(c)
        }
    }

    // MARK: - Rust pilot — BASRustMemoryUsageTrackerActorError

    func testBASRustMemoryUsageTrackerActorErrorAllCasesRoundTrip() throws {
        let cases: [BASRustMemoryUsageTrackerActorError] = [
            .rustBridgeUnavailableOnPlatform,
            .initFailed,
            .nullPointer,
            .rustInternalException,
            .jsonDecodeFailed(message: "parse failure"),
            .unknownReturnCode(-1)
        ]
        for c in cases {
            try assertCodableRoundTrip(c)
        }
    }

    // MARK: - Cross-pilot conformance contract

    func testAllFiveErrorEnumsConformToSendableAndEquatable() {
        // Compile-time check via type-erasing assignment。
        // If any enum drops Sendable or Equatable,this
        // function won't compile。
        let _: any (Error & Equatable & Sendable & Codable) =
            BASMemoryUsageTracker.TrackerError.unknownRecord(
                id: "x")
        let _: any (Error & Equatable & Sendable & Codable) =
            BASMonotonicNanosError.nullOutPointer
        let _: any (Error & Equatable & Sendable & Codable) =
            BASMetalKernelLibraryLoaderError
                .metalUnavailableOnPlatform
        let _: any (Error & Equatable & Sendable & Codable) =
            BASMPSGraphExecutableCacheCxxBridgeError
                .nullPointer
        let _: any (Error & Equatable & Sendable & Codable) =
            BASRustMemoryUsageTrackerActorError.initFailed
        XCTAssertTrue(true,
            "All 5 pilot error enums conform to" +
            " Error + Equatable + Sendable + Codable")
    }
}
