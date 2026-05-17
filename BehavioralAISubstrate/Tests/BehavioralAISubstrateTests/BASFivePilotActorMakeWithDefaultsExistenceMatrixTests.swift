// MARK: - BASFivePilotActorMakeWithDefaultsExistenceMatrixTests
// chapter 七百三十 / M2239 第一刀 — pilot makeWithDefaults()
//                                   factory existence matrix。
//                                   Sixth pillar of 5-pilot
//                                   ACTOR contract。
//
// ## Why
//
// Chapters 725-729 sealed 5 pillars of the 5-pilot ACTOR
// contract (type-name / count / Sendable transfer /
// module-qualified / distinct-instance)。 Chapter 730 adds
// the sixth:proof that each pilot exposes the
// `makeWithDefaults()` async factory pattern (introduced
// in chapter 713)。
//
// The factory pattern wraps:
//   1. Constructing the actor
//   2. Consulting BASLanguageAugmentationFeatureFlags for
//      the per-pilot opt-in flag (default FALSE)
//   3. Sampling the flag ONCE at construction time
//
// Test exercises only the existence of the factory + that
// it returns a usable actor instance (V1 mode since flags
// default OFF)。 The chapter-713 close-out validated the
// behavior end-to-end;this matrix pins the SURFACE
// existence as a tripwire — a future commit that removes
// or renames `makeWithDefaults` on any pilot fails here
// at PR time。
//
// ## Coverage (5 per-pilot factory tests + 1 cross-pilot type)
//
//   1-5. Each pilot:`PilotActor.makeWithDefaults()`
//        returns a non-nil instance of the expected type
//   6. Cross-pilot:all 5 factories return distinct types
//      (no accidental cross-pilot factory aliasing)

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotActorMakeWithDefaultsExistenceMatrixTests: XCTestCase {

    // MARK: - SQL pilot (in-memory mode)

    func testBASMemoryUsageTrackerMakeWithDefaultsFactory() async throws {
        // SQL pilot's makeWithDefaults takes a URL (disk-
        // backed mode)。 Use a temporary path for the
        // surface-existence test。
        let tempURL = URL(fileURLWithPath:
            NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-test-\(UUID().uuidString).sqlite")
        let tracker = try await BASMemoryUsageTracker
            .makeWithDefaults(databaseURL: tempURL)
        XCTAssertEqual(
            String(describing: type(of: tracker)),
            "BASMemoryUsageTracker",
            "SQL pilot makeWithDefaults must return" +
            " BASMemoryUsageTracker instance")
        // Cleanup the temp DB file (best-effort)
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - C pilot

    func testBASMonotonicNanosMakeWithDefaultsFactory() async {
        let monotonic = await BASMonotonicNanos
            .makeWithDefaults()
        XCTAssertEqual(
            String(describing: type(of: monotonic)),
            "BASMonotonicNanos",
            "C pilot makeWithDefaults must return" +
            " BASMonotonicNanos instance")
    }

    // MARK: - Metal pilot

    func testBASMetalKernelLibraryLoaderMakeWithDefaultsFactory() async {
        let loader = await BASMetalKernelLibraryLoader
            .makeWithDefaults()
        XCTAssertEqual(
            String(describing: type(of: loader)),
            "BASMetalKernelLibraryLoader",
            "Metal pilot makeWithDefaults must return" +
            " BASMetalKernelLibraryLoader instance")
    }

    // MARK: - C++ pilot

    func testBASMPSGraphExecutableCacheCxxBridgeMakeWithDefaultsFactory() async {
        let bridge = await BASMPSGraphExecutableCacheCxxBridge
            .makeWithDefaults()
        XCTAssertEqual(
            String(describing: type(of: bridge)),
            "BASMPSGraphExecutableCacheCxxBridge",
            "C++ pilot makeWithDefaults must return" +
            " BASMPSGraphExecutableCacheCxxBridge instance")
    }

    // MARK: - Rust pilot

    func testBASRustMemoryUsageTrackerActorMakeWithDefaultsFactory() async throws {
        let rust = try await BASRustMemoryUsageTrackerActor
            .makeWithDefaults()
        XCTAssertEqual(
            String(describing: type(of: rust)),
            "BASRustMemoryUsageTrackerActor",
            "Rust pilot makeWithDefaults must return" +
            " BASRustMemoryUsageTrackerActor instance")
    }

    // MARK: - Cross-pilot factory return-type distinctness

    /// Pins that all 5 makeWithDefaults factories return
    /// distinct types。 Catches the (extremely unlikely
    /// but possible) regression where two pilots'
    /// factories converge on the same return type via
    /// a refactor.
    func testAllFiveMakeWithDefaultsReturnDistinctTypes() async throws {
        let tempURL = URL(fileURLWithPath:
            NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-test-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        let sqlType = String(describing:
            type(of: try await BASMemoryUsageTracker
                .makeWithDefaults(databaseURL: tempURL)))
        let cType = String(describing:
            type(of: await BASMonotonicNanos
                .makeWithDefaults()))
        let metalType = String(describing:
            type(of: await BASMetalKernelLibraryLoader
                .makeWithDefaults()))
        let cxxType = String(describing:
            type(of: await BASMPSGraphExecutableCacheCxxBridge
                .makeWithDefaults()))
        let rustType = String(describing:
            type(of: try await BASRustMemoryUsageTrackerActor
                .makeWithDefaults()))
        let allTypes: Set<String> = [
            sqlType, cType, metalType, cxxType, rustType]
        XCTAssertEqual(allTypes.count, 5,
            "5 pilot factories must return 5 distinct" +
            " types。 Got \(allTypes).")
    }
}
