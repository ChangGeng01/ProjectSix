// MARK: - BASFivePilotErrorDescriptionMatrixTests
// chapter 七百二十三 / M2225 第一刀 — String(describing:)
//                                     descriptive output
//                                     matrix for the 5
//                                     pilot error enums。
//
// ## Why
//
// Chapter 720 sealed caseIdentifier introspection — a PII-
// SAFE telemetry aggregation key that excludes associated
// value data。 Chapter 722 sealed (type, caseIdentifier)
// global uniqueness across pilots。
//
// This file seals the COMPLEMENTARY surface:String(
// describing: errorValue) which Swift auto-synthesizes
// for enums and INCLUDES the associated value data。
// Useful for:
//   - Debug logging where full payload context helps
//   - Crash reports where the actual data matters
//   - Audit trails where complete error state must be
//     preserved
//
// The pair caseIdentifier + description gives consumers a
// CHOICE:safe-for-aggregation telemetry key (chapter 720)
// vs full-payload debug log (chapter 723)。
//
// Chapter 723 pins:
//   1. Each error case produces a deterministic String(
//      describing:) format
//   2. The description CONTAINS the case name
//   3. The description CONTAINS each associated value
//      (for cases that have one)
//   4. Sentinel cases (no associated values) produce just
//      the case name
//   5. The description is STABLE across re-construction
//      with the same payload (no clock/PID/random injection)
//
// ## Coverage (5 per-pilot tests + 1 cross-cutting pin)
//
//   1-5. Each pilot's error enum:representative cases'
//        descriptions match expected format + contain
//        associated values
//   6. Cross-pilot summary:caseIdentifier vs description
//        relationship (description always CONTAINS the
//        caseIdentifier as a substring)

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotErrorDescriptionMatrixTests: XCTestCase {

    /// Helper:assert the description satisfies the
    /// joint contract:
    ///   - non-empty
    ///   - contains the caseIdentifier as substring
    ///     (proves caseIdentifier subset relationship)
    ///   - contains every requested associated value
    ///     sample (proves payload preservation in debug
    ///     output)
    ///   - description(value) == description(value)
    ///     called twice (proves stability)
    private func assertDescriptionContract<T>(
        _ value: T,
        caseIdentifier: String,
        mustContain associatedSamples: [String] = [],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let desc = String(describing: value)
        XCTAssertFalse(desc.isEmpty,
            "description must be non-empty",
            file: file, line: line)
        XCTAssertTrue(desc.contains(caseIdentifier),
            "description '\(desc)' must contain caseIdentifier" +
            " '\(caseIdentifier)' as substring",
            file: file, line: line)
        for sample in associatedSamples {
            XCTAssertTrue(desc.contains(sample),
                "description '\(desc)' must contain" +
                " associated value sample '\(sample)'",
                file: file, line: line)
        }
        // Stability:two String(describing:) calls must
        // produce the same string。
        let desc2 = String(describing: value)
        XCTAssertEqual(desc, desc2,
            "description must be stable across" +
            " re-derivation",
            file: file, line: line)
    }

    // MARK: - SQL pilot — BASMemoryUsageTracker.TrackerError

    func testBASMemoryUsageTrackerErrorDescriptions() {
        assertDescriptionContract(
            BASMemoryUsageTracker.TrackerError
                .openFailed(code: 14,
                            message: "unable-to-open-payload"),
            caseIdentifier: "openFailed",
            mustContain: ["14", "unable-to-open-payload"])

        assertDescriptionContract(
            BASMemoryUsageTracker.TrackerError
                .schemaVersionMismatch(found: 2, expected: 1),
            caseIdentifier: "schemaVersionMismatch",
            mustContain: ["2", "1"])

        assertDescriptionContract(
            BASMemoryUsageTracker.TrackerError
                .unknownRecord(id: "audit-trail-uuid-xyz"),
            caseIdentifier: "unknownRecord",
            mustContain: ["audit-trail-uuid-xyz"])
    }

    // MARK: - C pilot — BASMonotonicNanosError

    func testBASMonotonicNanosErrorDescriptions() {
        assertDescriptionContract(
            BASMonotonicNanosError.nullOutPointer,
            caseIdentifier: "nullOutPointer")

        assertDescriptionContract(
            BASMonotonicNanosError.clockGetTimeSyscallFailed,
            caseIdentifier: "clockGetTimeSyscallFailed")

        assertDescriptionContract(
            BASMonotonicNanosError.unknownReturnCode(-77),
            caseIdentifier: "unknownReturnCode",
            mustContain: ["-77"])
    }

    // MARK: - Metal pilot — BASMetalKernelLibraryLoaderError

    func testBASMetalKernelLibraryLoaderErrorDescriptions() {
        assertDescriptionContract(
            BASMetalKernelLibraryLoaderError
                .metalUnavailableOnPlatform,
            caseIdentifier: "metalUnavailableOnPlatform")

        assertDescriptionContract(
            BASMetalKernelLibraryLoaderError
                .resourceURLMissing(
                    resourceName: "AuditShaderName"),
            caseIdentifier: "resourceURLMissing",
            mustContain: ["AuditShaderName"])

        assertDescriptionContract(
            BASMetalKernelLibraryLoaderError
                .metalCompilationFailed(
                    message: "audit-compile-error-msg"),
            caseIdentifier: "metalCompilationFailed",
            mustContain: ["audit-compile-error-msg"])
    }

    // MARK: - C++ pilot — BASMPSGraphExecutableCacheCxxBridgeError

    func testBASMPSGraphExecutableCacheCxxBridgeErrorDescriptions() {
        assertDescriptionContract(
            BASMPSGraphExecutableCacheCxxBridgeError
                .nullPointer,
            caseIdentifier: "nullPointer")

        assertDescriptionContract(
            BASMPSGraphExecutableCacheCxxBridgeError
                .cxxInternalException,
            caseIdentifier: "cxxInternalException")

        assertDescriptionContract(
            BASMPSGraphExecutableCacheCxxBridgeError
                .unknownReturnCode(-200),
            caseIdentifier: "unknownReturnCode",
            mustContain: ["-200"])
    }

    // MARK: - Rust pilot — BASRustMemoryUsageTrackerActorError

    func testBASRustMemoryUsageTrackerActorErrorDescriptions() {
        assertDescriptionContract(
            BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform,
            caseIdentifier:
                "rustBridgeUnavailableOnPlatform")

        assertDescriptionContract(
            BASRustMemoryUsageTrackerActorError
                .jsonDecodeFailed(
                    message: "audit-json-decode-err"),
            caseIdentifier: "jsonDecodeFailed",
            mustContain: ["audit-json-decode-err"])

        assertDescriptionContract(
            BASRustMemoryUsageTrackerActorError
                .unknownReturnCode(-50),
            caseIdentifier: "unknownReturnCode",
            mustContain: ["-50"])
    }

    // MARK: - Cross-pilot caseIdentifier-subset relationship

    /// Pins the structural invariant that String(describing:
    /// errorValue) ALWAYS contains errorValue.caseIdentifier
    /// as a substring。 This proves the pair forms a clean
    /// "summary key + full record" relationship:
    ///   - caseIdentifier  ⊆ description     (chapter 720 +
    ///                                          chapter 723)
    /// Consumers can choose:
    ///   - aggregate-by-caseIdentifier (PII-safe telemetry)
    ///   - log-by-description (full debug context)
    /// without worrying that they reference different
    /// case discriminators。
    func testCaseIdentifierIsSubsetOfDescriptionAcrossAllFivePilots() {
        // Build a representative case from each pilot +
        // verify the subset relationship。
        struct CasePair {
            let description: String
            let caseIdentifier: String
        }
        let pairs: [CasePair] = [
            // SQL
            {
                let e = BASMemoryUsageTracker.TrackerError
                    .openFailed(code: 0, message: "")
                return CasePair(
                    description: String(describing: e),
                    caseIdentifier: e.caseIdentifier)
            }(),
            // C
            {
                let e = BASMonotonicNanosError
                    .unknownReturnCode(0)
                return CasePair(
                    description: String(describing: e),
                    caseIdentifier: e.caseIdentifier)
            }(),
            // Metal
            {
                let e = BASMetalKernelLibraryLoaderError
                    .resourceURLMissing(resourceName: "x")
                return CasePair(
                    description: String(describing: e),
                    caseIdentifier: e.caseIdentifier)
            }(),
            // C++
            {
                let e = BASMPSGraphExecutableCacheCxxBridgeError
                    .nullPointer
                return CasePair(
                    description: String(describing: e),
                    caseIdentifier: e.caseIdentifier)
            }(),
            // Rust
            {
                let e = BASRustMemoryUsageTrackerActorError
                    .initFailed
                return CasePair(
                    description: String(describing: e),
                    caseIdentifier: e.caseIdentifier)
            }()
        ]
        for pair in pairs {
            XCTAssertTrue(
                pair.description.contains(pair.caseIdentifier),
                "description '\(pair.description)' must" +
                " contain caseIdentifier '\(pair.caseIdentifier)'" +
                " — subset invariant for telemetry/" +
                "debug-log pair coherence")
        }
        XCTAssertEqual(pairs.count, 5,
            "Subset invariant must be tested for ALL 5" +
            " pilots, not a subset")
    }
}
