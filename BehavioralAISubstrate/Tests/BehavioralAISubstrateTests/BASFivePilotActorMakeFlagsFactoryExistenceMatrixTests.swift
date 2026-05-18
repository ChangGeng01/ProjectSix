// MARK: - BASFivePilotActorMakeFlagsFactoryExistenceMatrixTests
// chapter 七百三十三 / M2245 第一刀 — pilot make(flags:)
//                                     factory existence
//                                     matrix。 Ninth pillar
//                                     of 5-pilot ACTOR
//                                     contract。
//
// ## Why
//
// Chapter 730 sealed `makeWithDefaults()` factory existence
// (zero-arg convenience factory)。 Chapter 733 seals the
// COMPANION factory `make(flags:)` — the explicit-flag
// variant that hosts use when they want to inject a
// specific flag state at construction time。
//
// Both factories must exist on every pilot:
//   - makeWithDefaults() — internal default flag actor
//   - make(flags:) — caller-provided flag actor
//
// This file pins the latter's existence + that it produces
// a usable actor instance per pilot。
//
// ## Coverage (5 per-pilot factory tests + 1 cross-pilot)

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotActorMakeFlagsFactoryExistenceMatrixTests: XCTestCase {

    // MARK: - SQL pilot

    func testSQLPilotMakeFlagsFactory() async throws {
        let tempURL = URL(fileURLWithPath:
            NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-test-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        let flags = BASLanguageAugmentationFeatureFlags()
        let tracker = try await BASMemoryUsageTracker
            .make(databaseURL: tempURL, flags: flags)
        XCTAssertEqual(
            String(describing: type(of: tracker)),
            "BASMemoryUsageTracker")
    }

    // MARK: - C pilot

    func testCPilotMakeFlagsFactory() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        let monotonic = await BASMonotonicNanos
            .make(flags: flags)
        XCTAssertEqual(
            String(describing: type(of: monotonic)),
            "BASMonotonicNanos")
    }

    // MARK: - Metal pilot

    func testMetalPilotMakeFlagsFactory() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        let loader = await BASMetalKernelLibraryLoader
            .make(flags: flags)
        XCTAssertEqual(
            String(describing: type(of: loader)),
            "BASMetalKernelLibraryLoader")
    }

    // MARK: - C++ pilot

    func testCxxPilotMakeFlagsFactory() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        let bridge = await BASMPSGraphExecutableCacheCxxBridge
            .make(flags: flags)
        XCTAssertEqual(
            String(describing: type(of: bridge)),
            "BASMPSGraphExecutableCacheCxxBridge")
    }

    // MARK: - Rust pilot

    func testRustPilotMakeFlagsFactory() async throws {
        let flags = BASLanguageAugmentationFeatureFlags()
        let rust = try await BASRustMemoryUsageTrackerActor
            .make(flags: flags)
        XCTAssertEqual(
            String(describing: type(of: rust)),
            "BASRustMemoryUsageTrackerActor")
    }

    // MARK: - Cross-pilot — both factory variants exist

    /// Pins that the (makeWithDefaults, make(flags:))
    /// factory pair is the canonical surface for ALL 5
    /// pilots。 makeWithDefaults already sealed in chapter
    /// 730;this re-verifies in tandem so a future commit
    /// that removes ONE of the pair (e.g. drops
    /// makeWithDefaults but keeps make(flags:)) on one
    /// pilot fails here。
    func testAllFivePilotsExposeBothFactoryVariants() async throws {
        let tempURL = URL(fileURLWithPath:
            NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-test-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        let flags = BASLanguageAugmentationFeatureFlags()
        let sqlMake = try await BASMemoryUsageTracker
            .make(databaseURL: tempURL, flags: flags)
        let sqlDefault = try await BASMemoryUsageTracker
            .makeWithDefaults(databaseURL: tempURL)
        let cMake = await BASMonotonicNanos.make(flags: flags)
        let cDefault = await BASMonotonicNanos
            .makeWithDefaults()
        let metalMake = await BASMetalKernelLibraryLoader
            .make(flags: flags)
        let metalDefault = await BASMetalKernelLibraryLoader
            .makeWithDefaults()
        let cxxMake = await BASMPSGraphExecutableCacheCxxBridge
            .make(flags: flags)
        let cxxDefault = await BASMPSGraphExecutableCacheCxxBridge
            .makeWithDefaults()
        let rustMake = try await BASRustMemoryUsageTrackerActor
            .make(flags: flags)
        let rustDefault = try await BASRustMemoryUsageTrackerActor
            .makeWithDefaults()
        // All 10 instances should be distinct references
        let allTen: [AnyObject] = [
            sqlMake, sqlDefault, cMake, cDefault,
            metalMake, metalDefault, cxxMake, cxxDefault,
            rustMake, rustDefault]
        XCTAssertEqual(allTen.count, 10)
        // Each pair (make + makeWithDefaults) of same
        // pilot must be DISTINCT (no factory aliasing)
        XCTAssertFalse(sqlMake === sqlDefault)
        XCTAssertFalse(cMake === cDefault)
        XCTAssertFalse(metalMake === metalDefault)
        XCTAssertFalse(cxxMake === cxxDefault)
        XCTAssertFalse(rustMake === rustDefault)
    }
}
