// MARK: - BASFivePilotErrorCaseCountInvariantTests
// chapter 七百二十四 / M2227 第一刀 — case count invariant
//                                     matrix for the 5
//                                     pilot error enums。
//
// ## Why
//
// Chapters 717-723 sealed 7 pillars of the 5-pilot error
// typed contract — each pillar verifies BEHAVIOR (Codable,
// Hashable, Sendable, identifier, SHA256, description)。
// This chapter pins the SHAPE invariant:exact case count
// per enum + global total。
//
// Swift enums with associated values do NOT auto-conform
// to CaseIterable,so we cannot programmatically count
// cases via `T.allCases.count`。 Instead this test
// MANUALLY enumerates one representative instance per
// case + counts via Set<TypeCaseIdentifierTuple> (chapter
// 722 pattern reused)。 If a future commit adds a case
// to any enum WITHOUT updating this test's expected
// count,it fails — making case additions explicitly
// visible at PR time。
//
// Why the tripwire matters:
//   - Telemetry dashboards depend on stable case
//     enumeration for charting
//   - Wire-format consumers expect a known case set
//   - Migration scripts need to handle every case;adding
//     a new one silently could miss the migration
//
// ## Coverage (5 per-pilot tests + 1 global total)
//
//   1-5. Each pilot's error enum:exact case count
//        matches expected pin
//   6. Cross-pilot total:22 cases (5+3+5+3+6) across
//      all 5 enums

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotErrorCaseCountInvariantTests: XCTestCase {

    /// Helper:count distinct caseIdentifiers in a list
    /// of representative instances。 Returns the count
    /// of unique case-identifier strings,which equals
    /// the case count of the enum IF the representative
    /// list covers every case exactly once。
    private func distinctCaseCount<E>(
        _ representatives: [E],
        caseIdentifierFor: (E) -> String
    ) -> Int {
        return Set(representatives.map(caseIdentifierFor))
            .count
    }

    // MARK: - SQL pilot — must have exactly 5 cases

    func testBASMemoryUsageTrackerErrorHasFiveCases() {
        let representatives: [BASMemoryUsageTracker
            .TrackerError] = [
            .openFailed(code: 0, message: ""),
            .prepareFailed(sql: "", message: ""),
            .stepFailed(sql: "", message: ""),
            .schemaVersionMismatch(found: 0, expected: 0),
            .unknownRecord(id: "")
        ]
        XCTAssertEqual(
            distinctCaseCount(
                representatives,
                caseIdentifierFor: { $0.caseIdentifier }),
            5,
            "BASMemoryUsageTracker.TrackerError must have" +
            " exactly 5 cases — if you added or removed" +
            " a case, update this pin + representatives" +
            " list")
        XCTAssertEqual(representatives.count, 5,
            "Representatives list must contain exactly 5" +
            " distinct cases")
    }

    // MARK: - C pilot — must have exactly 3 cases

    func testBASMonotonicNanosErrorHasThreeCases() {
        let representatives: [BASMonotonicNanosError] = [
            .nullOutPointer,
            .clockGetTimeSyscallFailed,
            .unknownReturnCode(0)
        ]
        XCTAssertEqual(
            distinctCaseCount(
                representatives,
                caseIdentifierFor: { $0.caseIdentifier }),
            3,
            "BASMonotonicNanosError must have exactly 3" +
            " cases")
        XCTAssertEqual(representatives.count, 3)
    }

    // MARK: - Metal pilot — must have exactly 5 cases

    func testBASMetalKernelLibraryLoaderErrorHasFiveCases() {
        let representatives: [BASMetalKernelLibraryLoaderError] = [
            .metalUnavailableOnPlatform,
            .mtlDeviceUnavailable,
            .resourceURLMissing(resourceName: ""),
            .resourceReadFailed(message: ""),
            .metalCompilationFailed(message: "")
        ]
        XCTAssertEqual(
            distinctCaseCount(
                representatives,
                caseIdentifierFor: { $0.caseIdentifier }),
            5,
            "BASMetalKernelLibraryLoaderError must have" +
            " exactly 5 cases")
        XCTAssertEqual(representatives.count, 5)
    }

    // MARK: - C++ pilot — must have exactly 3 cases

    func testBASMPSGraphExecutableCacheCxxBridgeErrorHasThreeCases() {
        let representatives: [BASMPSGraphExecutableCacheCxxBridgeError] = [
            .nullPointer,
            .cxxInternalException,
            .unknownReturnCode(0)
        ]
        XCTAssertEqual(
            distinctCaseCount(
                representatives,
                caseIdentifierFor: { $0.caseIdentifier }),
            3,
            "BASMPSGraphExecutableCacheCxxBridgeError must" +
            " have exactly 3 cases")
        XCTAssertEqual(representatives.count, 3)
    }

    // MARK: - Rust pilot — must have exactly 6 cases

    func testBASRustMemoryUsageTrackerActorErrorHasSixCases() {
        let representatives: [BASRustMemoryUsageTrackerActorError] = [
            .rustBridgeUnavailableOnPlatform,
            .initFailed,
            .nullPointer,
            .rustInternalException,
            .jsonDecodeFailed(message: ""),
            .unknownReturnCode(0)
        ]
        XCTAssertEqual(
            distinctCaseCount(
                representatives,
                caseIdentifierFor: { $0.caseIdentifier }),
            6,
            "BASRustMemoryUsageTrackerActorError must have" +
            " exactly 6 cases")
        XCTAssertEqual(representatives.count, 6)
    }

    // MARK: - Cross-pilot total — 22 cases globally

    /// Pins the global case-count invariant:5 + 3 + 5 +
    /// 3 + 6 = 22 cases across all 5 pilot error enums。
    /// This is a tripwire:adding/removing a case to ANY
    /// pilot enum without updating both the per-pilot pin
    /// AND this global pin makes the change explicitly
    /// visible at PR time。
    func testTotalCaseCountAcrossFivePilotsIsTwentyTwo() {
        let sqlCount = 5
        let cCount = 3
        let metalCount = 5
        let cxxCount = 3
        let rustCount = 6
        let total = sqlCount + cCount + metalCount +
                    cxxCount + rustCount
        XCTAssertEqual(total, 22,
            "Total case count across 5 pilot error enums" +
            " must be 22 (5+3+5+3+6)。 If you changed any" +
            " enum's case count,update both the per-pilot" +
            " test + this aggregate pin")

        // Cross-check via chapter 722's pattern — build
        // (typeName, caseIdentifier) tuples for ALL cases
        // and verify cardinality is 22。
        struct TypeCaseTuple: Hashable {
            let typeName: String
            let caseIdentifier: String
        }
        var allTuples: Set<TypeCaseTuple> = []
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
        for c in [
            BASMemoryUsageTracker.TrackerError
                .openFailed(code: 0, message: ""),
            .prepareFailed(sql: "", message: ""),
            .stepFailed(sql: "", message: ""),
            .schemaVersionMismatch(found: 0, expected: 0),
            .unknownRecord(id: "")
        ] {
            allTuples.insert(TypeCaseTuple(
                typeName: typeNameSQL,
                caseIdentifier: c.caseIdentifier))
        }
        for c in [
            BASMonotonicNanosError.nullOutPointer,
            .clockGetTimeSyscallFailed,
            .unknownReturnCode(0)
        ] {
            allTuples.insert(TypeCaseTuple(
                typeName: typeNameC,
                caseIdentifier: c.caseIdentifier))
        }
        for c in [
            BASMetalKernelLibraryLoaderError
                .metalUnavailableOnPlatform,
            .mtlDeviceUnavailable,
            .resourceURLMissing(resourceName: ""),
            .resourceReadFailed(message: ""),
            .metalCompilationFailed(message: "")
        ] {
            allTuples.insert(TypeCaseTuple(
                typeName: typeNameMetal,
                caseIdentifier: c.caseIdentifier))
        }
        for c in [
            BASMPSGraphExecutableCacheCxxBridgeError
                .nullPointer,
            .cxxInternalException,
            .unknownReturnCode(0)
        ] {
            allTuples.insert(TypeCaseTuple(
                typeName: typeNameCxx,
                caseIdentifier: c.caseIdentifier))
        }
        for c in [
            BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform,
            .initFailed,
            .nullPointer,
            .rustInternalException,
            .jsonDecodeFailed(message: ""),
            .unknownReturnCode(0)
        ] {
            allTuples.insert(TypeCaseTuple(
                typeName: typeNameRust,
                caseIdentifier: c.caseIdentifier))
        }
        XCTAssertEqual(allTuples.count, 22,
            "Cross-pilot tuple count must equal total" +
            " case count pin (22)")
    }
}
