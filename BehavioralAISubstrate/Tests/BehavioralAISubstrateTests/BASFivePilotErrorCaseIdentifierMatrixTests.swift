// MARK: - BASFivePilotErrorCaseIdentifierMatrixTests
// chapter 七百二十 / M2219 第一刀 — caseIdentifier introspection
//                                    matrix for the 5 pilot
//                                    error enums。
//
// ## Why
//
// Chapters 717-719 sealed three typed-contract pillars for
// the 5 pilot error enums:
//   717:Codable round-trip idempotence (wire format)
//   718:Hashable Set-deduplication (telemetry dedup)
//   719:Sendable cross-Task transfer (concurrency)
//
// Chapter 720 adds the fourth pillar:**stable case-name
// introspection** via a `var caseIdentifier: String`
// computed property on each pilot error enum。 The
// identifier returns the lowerCamelCase case name with NO
// associated value data,enabling telemetry pipelines to
// aggregate errors by case discriminator WITHOUT leaking
// PII or implementation message text into the aggregation
// key。
//
// Real-world contract:given a stream of pilot errors,
// telemetry can answer "how many openFailed errors today"
// (case-level granularity) without exposing the SQLite
// error message,recordID,or any user data。
//
// ## Coverage (5 per-pilot tests + 1 cross-pilot uniqueness)
//
//   1-5. Each pilot's error enum:every case returns its
//        lowerCamelCase name + identifier is stable across
//        re-construction + identifiers don't include
//        associated value data + every case has a distinct
//        identifier (no two cases share the same name)
//   6. Cross-pilot uniqueness:identifiers within each enum
//      form a Set with cardinality equal to the case count
//      (no accidental collisions across enum cases)

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotErrorCaseIdentifierMatrixTests: XCTestCase {

    /// Helper:assert caseIdentifier conforms to the
    /// cross-pilot contract for a given case。
    ///   - non-empty
    ///   - starts with lowercase letter
    ///   - matches `expected` exactly (case-sensitive)
    ///   - does NOT contain any associated value sample
    ///     string (proves identifier doesn't leak payload)
    private func assertCaseIdentifierContract(
        actual: String,
        expected: String,
        notContainingAssociatedValueSample: String?,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertFalse(actual.isEmpty,
            "caseIdentifier must be non-empty",
            file: file, line: line)
        if let first = actual.first {
            XCTAssertTrue(first.isLowercase,
                "caseIdentifier '\(actual)' must start" +
                " with lowercase letter (lowerCamelCase" +
                " convention)",
                file: file, line: line)
        }
        XCTAssertEqual(actual, expected,
            "caseIdentifier must match expected" +
            " lowerCamelCase case name",
            file: file, line: line)
        if let sample = notContainingAssociatedValueSample {
            XCTAssertFalse(actual.contains(sample),
                "caseIdentifier '\(actual)' must NOT leak" +
                " associated value sample '\(sample)'",
                file: file, line: line)
        }
    }

    // MARK: - SQL pilot — BASMemoryUsageTracker.TrackerError

    func testBASMemoryUsageTrackerErrorCaseIdentifiers() {
        let cases: [(BASMemoryUsageTracker.TrackerError, String, String?)] = [
            (.openFailed(code: 14, message: "leak-this-msg"),
             "openFailed", "leak-this-msg"),
            (.prepareFailed(sql: "SELECT-LEAK", message: "x"),
             "prepareFailed", "SELECT-LEAK"),
            (.stepFailed(sql: "INSERT-LEAK", message: "y"),
             "stepFailed", "INSERT-LEAK"),
            (.schemaVersionMismatch(found: 2, expected: 1),
             "schemaVersionMismatch", nil),
            (.unknownRecord(id: "secret-uuid-leak"),
             "unknownRecord", "secret-uuid-leak")
        ]
        for (c, expected, leak) in cases {
            assertCaseIdentifierContract(
                actual: c.caseIdentifier,
                expected: expected,
                notContainingAssociatedValueSample: leak)
        }
        // Distinct cases must have distinct identifiers
        let identifiers = Set(cases.map { $0.0.caseIdentifier })
        XCTAssertEqual(identifiers.count, 5,
            "All 5 distinct cases must have distinct" +
            " identifiers")
    }

    // MARK: - C pilot — BASMonotonicNanosError

    func testBASMonotonicNanosErrorCaseIdentifiers() {
        let cases: [(BASMonotonicNanosError, String)] = [
            (.nullOutPointer, "nullOutPointer"),
            (.clockGetTimeSyscallFailed, "clockGetTimeSyscallFailed"),
            (.unknownReturnCode(-99), "unknownReturnCode")
        ]
        for (c, expected) in cases {
            assertCaseIdentifierContract(
                actual: c.caseIdentifier,
                expected: expected,
                notContainingAssociatedValueSample: nil)
        }
        // Different unknownReturnCode payloads share identifier
        XCTAssertEqual(
            BASMonotonicNanosError.unknownReturnCode(-99)
                .caseIdentifier,
            BASMonotonicNanosError.unknownReturnCode(42)
                .caseIdentifier,
            "Same case with different payloads must share" +
            " caseIdentifier (proves identifier independent" +
            " of associated value)")
        XCTAssertEqual(Set(cases.map { $0.0.caseIdentifier })
                .count, 3)
    }

    // MARK: - Metal pilot — BASMetalKernelLibraryLoaderError

    func testBASMetalKernelLibraryLoaderErrorCaseIdentifiers() {
        let cases: [(BASMetalKernelLibraryLoaderError, String, String?)] = [
            (.metalUnavailableOnPlatform,
             "metalUnavailableOnPlatform", nil),
            (.mtlDeviceUnavailable,
             "mtlDeviceUnavailable", nil),
            (.resourceURLMissing(resourceName: "LEAK-SHADER"),
             "resourceURLMissing", "LEAK-SHADER"),
            (.resourceReadFailed(message: "LEAK-DISK-MSG"),
             "resourceReadFailed", "LEAK-DISK-MSG"),
            (.metalCompilationFailed(message: "LEAK-SHADER-COMPILE-MSG"),
             "metalCompilationFailed", "LEAK-SHADER-COMPILE-MSG")
        ]
        for (c, expected, leak) in cases {
            assertCaseIdentifierContract(
                actual: c.caseIdentifier,
                expected: expected,
                notContainingAssociatedValueSample: leak)
        }
        XCTAssertEqual(Set(cases.map { $0.0.caseIdentifier })
                .count, 5)
    }

    // MARK: - C++ pilot — BASMPSGraphExecutableCacheCxxBridgeError

    func testBASMPSGraphExecutableCacheCxxBridgeErrorCaseIdentifiers() {
        let cases: [(BASMPSGraphExecutableCacheCxxBridgeError, String)] = [
            (.nullPointer, "nullPointer"),
            (.cxxInternalException, "cxxInternalException"),
            (.unknownReturnCode(-100), "unknownReturnCode")
        ]
        for (c, expected) in cases {
            assertCaseIdentifierContract(
                actual: c.caseIdentifier,
                expected: expected,
                notContainingAssociatedValueSample: nil)
        }
        XCTAssertEqual(Set(cases.map { $0.0.caseIdentifier })
                .count, 3)
    }

    // MARK: - Rust pilot — BASRustMemoryUsageTrackerActorError

    func testBASRustMemoryUsageTrackerActorErrorCaseIdentifiers() {
        let cases: [(BASRustMemoryUsageTrackerActorError, String, String?)] = [
            (.rustBridgeUnavailableOnPlatform,
             "rustBridgeUnavailableOnPlatform", nil),
            (.initFailed, "initFailed", nil),
            (.nullPointer, "nullPointer", nil),
            (.rustInternalException, "rustInternalException", nil),
            (.jsonDecodeFailed(message: "LEAK-DECODE-MSG"),
             "jsonDecodeFailed", "LEAK-DECODE-MSG"),
            (.unknownReturnCode(-99), "unknownReturnCode", nil)
        ]
        for (c, expected, leak) in cases {
            assertCaseIdentifierContract(
                actual: c.caseIdentifier,
                expected: expected,
                notContainingAssociatedValueSample: leak)
        }
        XCTAssertEqual(Set(cases.map { $0.0.caseIdentifier })
                .count, 6)
    }

    // MARK: - Cross-pilot uniqueness within each enum

    /// Confirms that across all 5 pilot error enums,every
    /// case has a distinct caseIdentifier WITHIN that enum
    /// (no two cases of the same enum share an identifier)。
    /// Identifiers MAY collide ACROSS enums (e.g. both C++
    /// and Rust bridges have `.nullPointer`) — that's fine
    /// because telemetry aggregation always knows the enum
    /// type context。
    func testCaseIdentifierUniquenessPerEnumCardinality() {
        // SQL pilot: 5 cases
        let sqlIdentifiers: Set<String> = [
            BASMemoryUsageTracker.TrackerError
                .openFailed(code: 0, message: "").caseIdentifier,
            BASMemoryUsageTracker.TrackerError
                .prepareFailed(sql: "", message: "").caseIdentifier,
            BASMemoryUsageTracker.TrackerError
                .stepFailed(sql: "", message: "").caseIdentifier,
            BASMemoryUsageTracker.TrackerError
                .schemaVersionMismatch(found: 0, expected: 0)
                .caseIdentifier,
            BASMemoryUsageTracker.TrackerError
                .unknownRecord(id: "").caseIdentifier
        ]
        XCTAssertEqual(sqlIdentifiers.count, 5)

        // C pilot: 3 cases
        let cIdentifiers: Set<String> = [
            BASMonotonicNanosError.nullOutPointer.caseIdentifier,
            BASMonotonicNanosError.clockGetTimeSyscallFailed.caseIdentifier,
            BASMonotonicNanosError.unknownReturnCode(0).caseIdentifier
        ]
        XCTAssertEqual(cIdentifiers.count, 3)

        // Metal pilot: 5 cases
        let metalIdentifiers: Set<String> = [
            BASMetalKernelLibraryLoaderError
                .metalUnavailableOnPlatform.caseIdentifier,
            BASMetalKernelLibraryLoaderError
                .mtlDeviceUnavailable.caseIdentifier,
            BASMetalKernelLibraryLoaderError
                .resourceURLMissing(resourceName: "")
                .caseIdentifier,
            BASMetalKernelLibraryLoaderError
                .resourceReadFailed(message: "")
                .caseIdentifier,
            BASMetalKernelLibraryLoaderError
                .metalCompilationFailed(message: "")
                .caseIdentifier
        ]
        XCTAssertEqual(metalIdentifiers.count, 5)

        // C++ pilot: 3 cases
        let cxxIdentifiers: Set<String> = [
            BASMPSGraphExecutableCacheCxxBridgeError
                .nullPointer.caseIdentifier,
            BASMPSGraphExecutableCacheCxxBridgeError
                .cxxInternalException.caseIdentifier,
            BASMPSGraphExecutableCacheCxxBridgeError
                .unknownReturnCode(0).caseIdentifier
        ]
        XCTAssertEqual(cxxIdentifiers.count, 3)

        // Rust pilot: 6 cases
        let rustIdentifiers: Set<String> = [
            BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform.caseIdentifier,
            BASRustMemoryUsageTrackerActorError
                .initFailed.caseIdentifier,
            BASRustMemoryUsageTrackerActorError
                .nullPointer.caseIdentifier,
            BASRustMemoryUsageTrackerActorError
                .rustInternalException.caseIdentifier,
            BASRustMemoryUsageTrackerActorError
                .jsonDecodeFailed(message: "").caseIdentifier,
            BASRustMemoryUsageTrackerActorError
                .unknownReturnCode(0).caseIdentifier
        ]
        XCTAssertEqual(rustIdentifiers.count, 6)

        // Total cases across 5 pilots = 5+3+5+3+6 = 22
        let totalCaseCount =
            sqlIdentifiers.count + cIdentifiers.count +
            metalIdentifiers.count + cxxIdentifiers.count +
            rustIdentifiers.count
        XCTAssertEqual(totalCaseCount, 22,
            "Combined case count across 5 pilot error" +
            " enums should be 22 (5+3+5+3+6)")
    }
}
