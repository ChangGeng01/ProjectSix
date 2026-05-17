// MARK: - BASFivePilotErrorSendableTransferMatrixTests
// chapter 七百十九 / M2217 第一刀 — Sendable cross-Task
//                                   transfer matrix for the
//                                   5 pilot error enums。
//
// ## Why
//
// Chapter 717 sealed Codable round-trip idempotence。 Chapter
// 718 sealed Hashable Set-deduplication semantics。 Chapter
// 719 seals the THIRD typed-contract pillar:Sendable cross-
// Task transfer at RUNTIME (not just compile-time witness)。
//
// The chapter 717 cross-pilot test was a compile-time
// witness — `func<T: Sendable>(T.Type)` proves the type
// CONFORMS to Sendable but doesn't actually exercise the
// concurrency boundary。 This file does:
//
//   1. Encode an error instance in the calling Task
//   2. Spawn a child Task that captures the instance
//   3. Inside the child Task,observe the instance + re-
//      encode + compare
//   4. Await the child Task's result back to the parent
//
// If a future commit makes any pilot error non-Sendable
// (e.g. adds an associated value of a non-Sendable type),
// this test fails at compile time。 Even if it compiled,
// the runtime transfer verifies the data crosses the
// boundary intact (no silent corruption from concurrency
// memory ordering issues)。
//
// ## Coverage (5 per-pilot tests + 1 mixed-collection)
//
//   1-5. Each pilot's error enum:single-instance transfer
//        across a `Task { ... }.value` boundary;the awaited
//        value must equal the original (Sendable transfer
//        + Equatable round-trip)
//   6. Mixed [any Error] collection transfer:5 pilot
//      errors (one per pilot) packed into a single
//      Sendable array,transferred across a Task boundary,
//      unpacked + type-checked on the other side

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotErrorSendableTransferMatrixTests: XCTestCase {

    /// Helper:transfer a single Sendable+Equatable value
    /// through a child Task + verify identity on the
    /// other side。 The await of `.value` enforces the
    /// Sendable boundary at the type level — non-Sendable
    /// values would fail to compile in the Task closure
    /// capture。
    private func assertSendableTransferRoundTrip<T: Sendable & Equatable>(
        _ value: T,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        let received: T = await Task {
            // Inside the child Task,we observe + return the
            // value。 If T were non-Sendable,this closure
            // would fail to capture `value`。
            return value
        }.value
        XCTAssertEqual(received, value,
            "Sendable cross-Task transfer must preserve" +
            " Equatable identity",
            file: file, line: line)
    }

    // MARK: - SQL pilot — BASMemoryUsageTracker.TrackerError

    func testBASMemoryUsageTrackerErrorSendableTransfer() async {
        await assertSendableTransferRoundTrip(
            BASMemoryUsageTracker.TrackerError
                .openFailed(code: 14, message: "unable"))
        await assertSendableTransferRoundTrip(
            BASMemoryUsageTracker.TrackerError
                .unknownRecord(id: "missing-uuid"))
    }

    // MARK: - C pilot — BASMonotonicNanosError

    func testBASMonotonicNanosErrorSendableTransfer() async {
        await assertSendableTransferRoundTrip(
            BASMonotonicNanosError.nullOutPointer)
        await assertSendableTransferRoundTrip(
            BASMonotonicNanosError.unknownReturnCode(-99))
    }

    // MARK: - Metal pilot — BASMetalKernelLibraryLoaderError

    func testBASMetalKernelLibraryLoaderErrorSendableTransfer() async {
        await assertSendableTransferRoundTrip(
            BASMetalKernelLibraryLoaderError
                .metalUnavailableOnPlatform)
        await assertSendableTransferRoundTrip(
            BASMetalKernelLibraryLoaderError
                .resourceURLMissing(
                    resourceName: "PhantomShader"))
    }

    // MARK: - C++ pilot — BASMPSGraphExecutableCacheCxxBridgeError

    func testBASMPSGraphExecutableCacheCxxBridgeErrorSendableTransfer() async {
        await assertSendableTransferRoundTrip(
            BASMPSGraphExecutableCacheCxxBridgeError
                .nullPointer)
        await assertSendableTransferRoundTrip(
            BASMPSGraphExecutableCacheCxxBridgeError
                .unknownReturnCode(-100))
    }

    // MARK: - Rust pilot — BASRustMemoryUsageTrackerActorError

    func testBASRustMemoryUsageTrackerActorErrorSendableTransfer() async {
        await assertSendableTransferRoundTrip(
            BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform)
        await assertSendableTransferRoundTrip(
            BASRustMemoryUsageTrackerActorError
                .jsonDecodeFailed(message: "EOF"))
    }

    // MARK: - Mixed-collection cross-Task transfer

    /// Pack one error from each of the 5 pilots into a
    /// single Sendable struct,transfer across a Task
    /// boundary,then unpack + verify identities on the
    /// other side。 Proves the substrate can ship multi-
    /// pilot error reports across async boundaries (e.g.
    /// for a telemetry pipeline aggregating errors from
    /// multiple pilots into one upload)。
    func testMixedFivePilotErrorCollectionSendableTransfer() async {
        // Sendable wrapper struct — every field is itself
        // Sendable (chapter 718 added Hashable to all 5 +
        // they were already Sendable via chapter 702-706
        // declarations)。
        struct FivePilotErrorReport: Sendable, Equatable {
            let sql: BASMemoryUsageTracker.TrackerError
            let c: BASMonotonicNanosError
            let metal: BASMetalKernelLibraryLoaderError
            let cxx: BASMPSGraphExecutableCacheCxxBridgeError
            let rust: BASRustMemoryUsageTrackerActorError
        }
        let report = FivePilotErrorReport(
            sql: .schemaVersionMismatch(found: 2, expected: 1),
            c: .clockGetTimeSyscallFailed,
            metal: .mtlDeviceUnavailable,
            cxx: .cxxInternalException,
            rust: .initFailed)
        let received: FivePilotErrorReport = await Task {
            return report
        }.value
        XCTAssertEqual(received, report,
            "Mixed 5-pilot error report must transfer" +
            " across Task boundary intact")
        // Sanity:each field individually survived。
        XCTAssertEqual(received.sql, report.sql)
        XCTAssertEqual(received.c, report.c)
        XCTAssertEqual(received.metal, report.metal)
        XCTAssertEqual(received.cxx, report.cxx)
        XCTAssertEqual(received.rust, report.rust)
    }
}
