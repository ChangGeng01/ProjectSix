// MARK: - BASFivePilotErrorTypeCaseIdentifierGlobalUniquenessTests
// chapter 七百二十二 / M2223 第一刀 — (type, caseIdentifier)
//                                     global uniqueness matrix
//                                     across 5 pilot error
//                                     enums。
//
// ## Why
//
// Chapter 720 sealed per-pilot caseIdentifier uniqueness —
// every case within a single enum has a distinct identifier。
// But identifiers CAN collide ACROSS enums:both
// BASMPSGraphExecutableCacheCxxBridgeError AND
// BASRustMemoryUsageTrackerActorError have a `.nullPointer`
// case,both with `caseIdentifier == "nullPointer"`。
//
// For telemetry pipelines that ingest errors from multiple
// pilots and aggregate without type context (e.g. a flat
// log table),this would silently merge "C++ null pointer"
// and "Rust null pointer" into the same bucket。
//
// Solution:use the (TYPE_NAME, caseIdentifier) tuple as
// the GLOBAL aggregation key。 This file pins that the 22
// tuples across the 5 pilots are unique。
//
// Real-world value:downstream telemetry can safely use
// "BASMPSGraphExecutableCacheCxxBridgeError.nullPointer"
// (vs "BASRustMemoryUsageTrackerActorError.nullPointer")
// as a distinct aggregation key without losing per-pilot
// granularity。
//
// ## Coverage (5 per-pilot tuples + 1 cross-pilot uniqueness)
//
//   1-5. Each pilot's error enum:type-name string is
//        non-empty + matches expected substring + every
//        case's (typeName, caseIdentifier) tuple is well-
//        formed
//   6. Cross-pilot global uniqueness:22 distinct tuples
//      across all 5 enums

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotErrorTypeCaseIdentifierGlobalUniquenessTests: XCTestCase {

    /// Tuple type for the global aggregation key。 Hashable
    /// + Equatable + Sendable via auto-synthesis (both
    /// fields are String,which conforms to all three)。
    private struct TypeCaseIdentifierTuple: Hashable, Sendable {
        let typeName: String
        let caseIdentifier: String
    }

    /// Helper:assert a tuple is well-formed (both fields
    /// non-empty,typeName matches expected substring)。
    private func assertTupleWellFormed(
        _ tuple: TypeCaseIdentifierTuple,
        expectedTypeNameContains: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertFalse(tuple.typeName.isEmpty,
            "typeName must be non-empty",
            file: file, line: line)
        XCTAssertFalse(tuple.caseIdentifier.isEmpty,
            "caseIdentifier must be non-empty",
            file: file, line: line)
        XCTAssertTrue(
            tuple.typeName.contains(expectedTypeNameContains),
            "typeName '\(tuple.typeName)' must contain" +
            " expected substring '\(expectedTypeNameContains)'",
            file: file, line: line)
    }

    // MARK: - SQL pilot

    func testBASMemoryUsageTrackerErrorTypeCaseTuples() {
        let typeName = String(describing:
            BASMemoryUsageTracker.TrackerError.self)
        let cases: [BASMemoryUsageTracker.TrackerError] = [
            .openFailed(code: 0, message: ""),
            .prepareFailed(sql: "", message: ""),
            .stepFailed(sql: "", message: ""),
            .schemaVersionMismatch(found: 0, expected: 0),
            .unknownRecord(id: "")
        ]
        let tuples = cases.map {
            TypeCaseIdentifierTuple(
                typeName: typeName,
                caseIdentifier: $0.caseIdentifier)
        }
        for tuple in tuples {
            assertTupleWellFormed(
                tuple,
                expectedTypeNameContains: "TrackerError")
        }
        XCTAssertEqual(Set(tuples).count, 5,
            "5 SQL pilot tuples must be distinct")
    }

    // MARK: - C pilot

    func testBASMonotonicNanosErrorTypeCaseTuples() {
        let typeName = String(describing:
            BASMonotonicNanosError.self)
        let cases: [BASMonotonicNanosError] = [
            .nullOutPointer,
            .clockGetTimeSyscallFailed,
            .unknownReturnCode(0)
        ]
        let tuples = cases.map {
            TypeCaseIdentifierTuple(
                typeName: typeName,
                caseIdentifier: $0.caseIdentifier)
        }
        for tuple in tuples {
            assertTupleWellFormed(
                tuple,
                expectedTypeNameContains:
                    "BASMonotonicNanosError")
        }
        XCTAssertEqual(Set(tuples).count, 3,
            "3 C pilot tuples must be distinct")
    }

    // MARK: - Metal pilot

    func testBASMetalKernelLibraryLoaderErrorTypeCaseTuples() {
        let typeName = String(describing:
            BASMetalKernelLibraryLoaderError.self)
        let cases: [BASMetalKernelLibraryLoaderError] = [
            .metalUnavailableOnPlatform,
            .mtlDeviceUnavailable,
            .resourceURLMissing(resourceName: ""),
            .resourceReadFailed(message: ""),
            .metalCompilationFailed(message: "")
        ]
        let tuples = cases.map {
            TypeCaseIdentifierTuple(
                typeName: typeName,
                caseIdentifier: $0.caseIdentifier)
        }
        for tuple in tuples {
            assertTupleWellFormed(
                tuple,
                expectedTypeNameContains:
                    "BASMetalKernelLibraryLoaderError")
        }
        XCTAssertEqual(Set(tuples).count, 5,
            "5 Metal pilot tuples must be distinct")
    }

    // MARK: - C++ pilot

    func testBASMPSGraphExecutableCacheCxxBridgeErrorTypeCaseTuples() {
        let typeName = String(describing:
            BASMPSGraphExecutableCacheCxxBridgeError.self)
        let cases: [BASMPSGraphExecutableCacheCxxBridgeError] = [
            .nullPointer,
            .cxxInternalException,
            .unknownReturnCode(0)
        ]
        let tuples = cases.map {
            TypeCaseIdentifierTuple(
                typeName: typeName,
                caseIdentifier: $0.caseIdentifier)
        }
        for tuple in tuples {
            assertTupleWellFormed(
                tuple,
                expectedTypeNameContains:
                    "BASMPSGraphExecutableCacheCxxBridgeError")
        }
        XCTAssertEqual(Set(tuples).count, 3,
            "3 C++ pilot tuples must be distinct")
    }

    // MARK: - Rust pilot

    func testBASRustMemoryUsageTrackerActorErrorTypeCaseTuples() {
        let typeName = String(describing:
            BASRustMemoryUsageTrackerActorError.self)
        let cases: [BASRustMemoryUsageTrackerActorError] = [
            .rustBridgeUnavailableOnPlatform,
            .initFailed,
            .nullPointer,
            .rustInternalException,
            .jsonDecodeFailed(message: ""),
            .unknownReturnCode(0)
        ]
        let tuples = cases.map {
            TypeCaseIdentifierTuple(
                typeName: typeName,
                caseIdentifier: $0.caseIdentifier)
        }
        for tuple in tuples {
            assertTupleWellFormed(
                tuple,
                expectedTypeNameContains:
                    "BASRustMemoryUsageTrackerActorError")
        }
        XCTAssertEqual(Set(tuples).count, 6,
            "6 Rust pilot tuples must be distinct")
    }

    // MARK: - Cross-pilot global uniqueness

    /// Aggregates ALL 22 (typeName, caseIdentifier) tuples
    /// from across the 5 pilot error enums into a single
    /// Set + verifies cardinality == 22。 This proves that
    /// even when raw identifiers collide (e.g. `nullPointer`
    /// appears in BOTH C++ AND Rust enums),the type-prefixed
    /// tuples remain globally unique。 Future commits that
    /// add a case to any enum must update this test's
    /// expected count。
    func testAllFivePilotsGloballyUniqueTypeCaseTuples() {
        let typeNameSQL = String(describing:
            BASMemoryUsageTracker.TrackerError.self)
        let typeNameC = String(describing:
            BASMonotonicNanosError.self)
        let typeNameMetal = String(describing:
            BASMetalKernelLibraryLoaderError.self)
        let typeNameCxx = String(describing:
            BASMPSGraphExecutableCacheCxxBridgeError.self)
        let typeNameRust = String(describing:
            BASRustMemoryUsageTrackerActorError.self)

        var allTuples: Set<TypeCaseIdentifierTuple> = []

        // SQL pilot (5 cases)
        for c in [
            BASMemoryUsageTracker.TrackerError
                .openFailed(code: 0, message: ""),
            .prepareFailed(sql: "", message: ""),
            .stepFailed(sql: "", message: ""),
            .schemaVersionMismatch(found: 0, expected: 0),
            .unknownRecord(id: "")
        ] {
            allTuples.insert(TypeCaseIdentifierTuple(
                typeName: typeNameSQL,
                caseIdentifier: c.caseIdentifier))
        }

        // C pilot (3 cases)
        for c in [
            BASMonotonicNanosError.nullOutPointer,
            .clockGetTimeSyscallFailed,
            .unknownReturnCode(0)
        ] {
            allTuples.insert(TypeCaseIdentifierTuple(
                typeName: typeNameC,
                caseIdentifier: c.caseIdentifier))
        }

        // Metal pilot (5 cases)
        for c in [
            BASMetalKernelLibraryLoaderError
                .metalUnavailableOnPlatform,
            .mtlDeviceUnavailable,
            .resourceURLMissing(resourceName: ""),
            .resourceReadFailed(message: ""),
            .metalCompilationFailed(message: "")
        ] {
            allTuples.insert(TypeCaseIdentifierTuple(
                typeName: typeNameMetal,
                caseIdentifier: c.caseIdentifier))
        }

        // C++ pilot (3 cases)
        for c in [
            BASMPSGraphExecutableCacheCxxBridgeError
                .nullPointer,
            .cxxInternalException,
            .unknownReturnCode(0)
        ] {
            allTuples.insert(TypeCaseIdentifierTuple(
                typeName: typeNameCxx,
                caseIdentifier: c.caseIdentifier))
        }

        // Rust pilot (6 cases)
        for c in [
            BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform,
            .initFailed,
            .nullPointer,
            .rustInternalException,
            .jsonDecodeFailed(message: ""),
            .unknownReturnCode(0)
        ] {
            allTuples.insert(TypeCaseIdentifierTuple(
                typeName: typeNameRust,
                caseIdentifier: c.caseIdentifier))
        }

        // Total = 5 + 3 + 5 + 3 + 6 = 22 distinct tuples
        XCTAssertEqual(allTuples.count, 22,
            "All 22 (typeName, caseIdentifier) tuples" +
            " across 5 pilot error enums must be globally" +
            " unique. Got \(allTuples.count).")

        // Sanity:verify the known cross-pilot collision
        // on raw caseIdentifier is RESOLVED by the type
        // prefix。
        let cxxNullPointerTuple = TypeCaseIdentifierTuple(
            typeName: typeNameCxx,
            caseIdentifier: "nullPointer")
        let rustNullPointerTuple = TypeCaseIdentifierTuple(
            typeName: typeNameRust,
            caseIdentifier: "nullPointer")
        XCTAssertNotEqual(cxxNullPointerTuple,
            rustNullPointerTuple,
            "Type-prefixed tuples must distinguish C++ vs" +
            " Rust nullPointer cases even though raw" +
            " identifiers collide")
        XCTAssertTrue(allTuples.contains(cxxNullPointerTuple))
        XCTAssertTrue(allTuples.contains(rustNullPointerTuple))
    }
}
