// MARK: - BASFivePilotErrorHashableMatrixTests
// chapter 七百十八 / M2215 第一刀 — Hashable conformance
//                                   matrix for the 5 pilot
//                                   error enums。
//
// ## Why
//
// Chapter 717 sealed Codable round-trip idempotence for
// the 5 pilot error enums。 The natural follow-on is
// Hashable conformance — useful for telemetry pipelines
// that need to deduplicate identical error instances
// (e.g. "have I seen this exact failure before?")。
//
// Swift auto-synthesizes Hashable for enums where every
// associated value type is itself Hashable。 The 5 error
// enums only use Int32 and String associated values,both
// Hashable,so adding `: Hashable` to each declaration is
// purely additive — no manual `func hash(into:)` needed。
//
// This file pins the Hashable conformance contract via 6
// tests covering Set-based deduplication semantics + the
// shared cross-pilot conformance proof。
//
// ## Coverage (5 tests + 1 cross-pilot)
//
//   1-5. Each pilot's error enum:Set deduplication
//        works (identical instances collapse,distinct
//        instances stay distinct)
//   6. All 5 enums satisfy the joint conformance
//      contract (Error + Equatable + Hashable + Sendable
//      + Codable)

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotErrorHashableMatrixTests: XCTestCase {

    /// Helper:assert Set<T> deduplicates identical
    /// instances and distinguishes distinct ones。 Three
    /// inputs minimum:two identical + one distinct。
    /// Result Set must have exactly 2 elements (the
    /// identical pair collapses,the distinct stays)。
    private func assertHashableDeduplication<T: Hashable>(
        identical1: T,
        identical2: T,
        distinct: T,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(identical1, identical2,
            "identical1 and identical2 must be Equatable-" +
            "equal",
            file: file, line: line)
        XCTAssertEqual(
            identical1.hashValue,
            identical2.hashValue,
            "Equatable-equal instances must have equal" +
            " hashValue (Swift Hashable contract)",
            file: file, line: line)
        XCTAssertNotEqual(identical1, distinct,
            "identical1 and distinct must NOT be Equatable" +
            "-equal",
            file: file, line: line)
        let set: Set<T> = [identical1, identical2, distinct]
        XCTAssertEqual(set.count, 2,
            "Set<T> must dedupe identical1/2 → 2 elements" +
            " total (\(set.count) found)",
            file: file, line: line)
        XCTAssertTrue(set.contains(identical1),
            "Set must contain identical1",
            file: file, line: line)
        XCTAssertTrue(set.contains(distinct),
            "Set must contain distinct",
            file: file, line: line)
    }

    // MARK: - SQL pilot — BASMemoryUsageTracker.TrackerError

    func testBASMemoryUsageTrackerErrorHashableDeduplication() {
        assertHashableDeduplication(
            identical1: BASMemoryUsageTracker.TrackerError
                .openFailed(code: 14, message: "unable"),
            identical2: BASMemoryUsageTracker.TrackerError
                .openFailed(code: 14, message: "unable"),
            distinct: BASMemoryUsageTracker.TrackerError
                .openFailed(code: 15, message: "unable")
        )
        // Case-discriminator check:same payload but
        // different case must hash to different buckets。
        let case1: BASMemoryUsageTracker.TrackerError =
            .prepareFailed(sql: "X", message: "Y")
        let case2: BASMemoryUsageTracker.TrackerError =
            .stepFailed(sql: "X", message: "Y")
        XCTAssertNotEqual(case1, case2)
        let crossCaseSet: Set<BASMemoryUsageTracker
            .TrackerError> = [case1, case2]
        XCTAssertEqual(crossCaseSet.count, 2,
            "Different cases with identical payloads must" +
            " stay distinct in Set")
    }

    // MARK: - C pilot — BASMonotonicNanosError

    func testBASMonotonicNanosErrorHashableDeduplication() {
        assertHashableDeduplication(
            identical1: BASMonotonicNanosError
                .unknownReturnCode(-99),
            identical2: BASMonotonicNanosError
                .unknownReturnCode(-99),
            distinct: BASMonotonicNanosError
                .unknownReturnCode(0)
        )
        // Sentinel cases (no associated values) must also
        // be Hashable + distinct from each other。
        let allSentinels: [BASMonotonicNanosError] = [
            .nullOutPointer,
            .clockGetTimeSyscallFailed
        ]
        let sentinelSet = Set(allSentinels)
        XCTAssertEqual(sentinelSet.count, 2,
            "Two distinct sentinel cases must stay distinct")
    }

    // MARK: - Metal pilot — BASMetalKernelLibraryLoaderError

    func testBASMetalKernelLibraryLoaderErrorHashableDeduplication() {
        assertHashableDeduplication(
            identical1: BASMetalKernelLibraryLoaderError
                .resourceURLMissing(
                    resourceName: "PhantomShader"),
            identical2: BASMetalKernelLibraryLoaderError
                .resourceURLMissing(
                    resourceName: "PhantomShader"),
            distinct: BASMetalKernelLibraryLoaderError
                .resourceURLMissing(
                    resourceName: "OtherShader")
        )
        // Sentinel cases must hash distinctly。
        let sentinels: [BASMetalKernelLibraryLoaderError] = [
            .metalUnavailableOnPlatform,
            .mtlDeviceUnavailable
        ]
        XCTAssertEqual(Set(sentinels).count, 2)
    }

    // MARK: - C++ pilot — BASMPSGraphExecutableCacheCxxBridgeError

    func testBASMPSGraphExecutableCacheCxxBridgeErrorHashableDeduplication() {
        assertHashableDeduplication(
            identical1: BASMPSGraphExecutableCacheCxxBridgeError
                .unknownReturnCode(-99),
            identical2: BASMPSGraphExecutableCacheCxxBridgeError
                .unknownReturnCode(-99),
            distinct: BASMPSGraphExecutableCacheCxxBridgeError
                .unknownReturnCode(-100)
        )
        // Sentinel + unknownReturnCode bucket distinctly。
        let mixed: [BASMPSGraphExecutableCacheCxxBridgeError] = [
            .nullPointer,
            .cxxInternalException,
            .unknownReturnCode(0)
        ]
        XCTAssertEqual(Set(mixed).count, 3)
    }

    // MARK: - Rust pilot — BASRustMemoryUsageTrackerActorError

    func testBASRustMemoryUsageTrackerActorErrorHashableDeduplication() {
        assertHashableDeduplication(
            identical1: BASRustMemoryUsageTrackerActorError
                .jsonDecodeFailed(message: "EOF"),
            identical2: BASRustMemoryUsageTrackerActorError
                .jsonDecodeFailed(message: "EOF"),
            distinct: BASRustMemoryUsageTrackerActorError
                .jsonDecodeFailed(message: "schema")
        )
        // All 6 cases (5 distinct cases used here) must
        // stay distinct in Set。
        let allDistinct: [BASRustMemoryUsageTrackerActorError] = [
            .rustBridgeUnavailableOnPlatform,
            .initFailed,
            .nullPointer,
            .rustInternalException,
            .unknownReturnCode(-1)
        ]
        XCTAssertEqual(Set(allDistinct).count, 5,
            "5 distinct cases must remain distinct in Set")
    }

    // MARK: - Cross-pilot conformance contract proof

    /// Pins that all 5 pilot error enums share the joint
    /// conformance contract:Error + Equatable + Hashable
    /// + Sendable + Codable。 This is a compile-time test
    /// — if a future commit removes any conformance from
    /// any enum,this generic helper fails to instantiate
    /// (the protocol composition won't resolve)。
    func testAllFivePilotErrorEnumsShareJointConformance() {
        func acceptsTypedErrorContract<
            T: Error & Equatable & Hashable & Sendable & Codable
        >(_: T.Type) {
            // Compile-time witness — no runtime work needed。
            // The function existing + being called proves
            // T satisfies the protocol composition。
        }

        // Witness all 5 pilot error types through the
        // joint contract。 Each line is a compile-time
        // proof that the type meets ALL 5 protocols。
        acceptsTypedErrorContract(
            BASMemoryUsageTracker.TrackerError.self)
        acceptsTypedErrorContract(
            BASMonotonicNanosError.self)
        acceptsTypedErrorContract(
            BASMetalKernelLibraryLoaderError.self)
        acceptsTypedErrorContract(
            BASMPSGraphExecutableCacheCxxBridgeError.self)
        acceptsTypedErrorContract(
            BASRustMemoryUsageTrackerActorError.self)
    }
}
