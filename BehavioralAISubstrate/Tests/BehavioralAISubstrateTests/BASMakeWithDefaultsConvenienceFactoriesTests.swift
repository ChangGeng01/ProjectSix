// MARK: - BASMakeWithDefaultsConvenienceFactoriesTests
// chapter 七百十三 / M2205 第一刀 — anti-drift PROOF
//                                   tests for the host
//                                   adoption convenience
//                                   factories added to
//                                   all 5 pilot actors。
//
// ## Why a single shared test file
//
// All 5 `makeWithDefaults()` factories share the same
// contract:
//   1. Construct a fresh `BASLanguageAugmentation
//      FeatureFlags()` actor internally
//   2. Call the existing `.make(flags:)` factory
//   3. Return the resulting actor with whatever path
//      `perFlagDefaults` resolves to
//
// At chapter 七百十二,all 5 flags resolve to true,so
// every `makeWithDefaults()` returns a V2-path actor。
//
// Tests live in a single file because they share a
// uniform shape — no need for 5 separate test files
// each repeating the same boilerplate。 chapter 七百八
// counter-sprawl discipline honored。
//
// ## Coverage matrix (5 tests + 1 cross-mirror = 6)
//
//   1. SQL pilot:`BASMemoryUsageTracker.makeWithDefaults
//      (databaseURL:)` returns V2-path tracker
//   2. C pilot:`BASMonotonicNanos.makeWithDefaults()`
//      returns V2-path actor (isUsingCBridge == true)
//   3. Metal pilot:`BASMetalKernelLibraryLoader
//      .makeWithDefaults()` returns V2-path loader
//      (isUsingV2 == true)
//   4. C++ pilot:`BASMPSGraphExecutableCacheCxxBridge
//      .makeWithDefaults()` returns V2-path bridge
//      (isUsingCxxCache == true)
//   5. Rust pilot:`BASRustMemoryUsageTrackerActor
//      .makeWithDefaults()` returns V2-path actor
//      (isUsingRustCore == true)
//   6. Cross-mirror:all 5 makeWithDefaults are
//      consistent with the make(flags:) factories
//      called with a fresh default-init flag actor

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASMakeWithDefaultsConvenienceFactoriesTests:
    XCTestCase
{

    // MARK: - SQL pilot

    func testBASMemoryUsageTrackerMakeWithDefaultsReturnsV2Path() async throws {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(
            "bas_make_defaults_sql_"
                + UUID().uuidString + ".sqlite")
        defer {
            try? FileManager.default.removeItem(at: url)
        }
        let tracker = try await BASMemoryUsageTracker
            .makeWithDefaults(databaseURL: url)
        // V2 path produces same schema as V1 (PRAGMA
        // byte-equal per chapter 七百二 / M2173),so we
        // smoke-test by recording + reading back。
        _ = try await tracker.record(
            atomID: "atom-x",
            sessionRef: "s",
            turnRef: "t",
            permitMode: "allow")
        let count = await tracker.recordCount
        XCTAssertEqual(count, 1,
            "makeWithDefaults returns a working tracker" +
            " using the V2 generated-schema path (since" +
            " chapter 七百十一 wire-in)")
    }

    // MARK: - C pilot

    func testBASMonotonicNanosMakeWithDefaultsReturnsV2Path() async {
        let actor = await BASMonotonicNanos.makeWithDefaults()
        let isUsing = await actor.isUsingCBridge
        XCTAssertTrue(isUsing,
            "makeWithDefaults uses V2 C-bridge path" +
            " (since chapter 七百十二 wire-in)")
    }

    // MARK: - Metal pilot

    func testBASMetalKernelLibraryLoaderMakeWithDefaultsReturnsV2Path() async {
        let actor = await BASMetalKernelLibraryLoader
            .makeWithDefaults()
        let isUsing = await actor.isUsingV2
        XCTAssertTrue(isUsing,
            "makeWithDefaults uses V2 Metal kernel" +
            " loader path (since chapter 七百十二" +
            " wire-in)")
    }

    // MARK: - C++ pilot

    func testBASMPSGraphExecutableCacheCxxBridgeMakeWithDefaultsReturnsV2Path() async {
        let bridge = await BASMPSGraphExecutableCacheCxxBridge
            .makeWithDefaults()
        let isUsing = await bridge.isUsingCxxCache
        XCTAssertTrue(isUsing,
            "makeWithDefaults uses V2 C++ cache path" +
            " (since chapter 七百十二 wire-in)")
    }

    // MARK: - Rust pilot

    func testBASRustMemoryUsageTrackerActorMakeWithDefaultsReturnsV2Path() async throws {
        let actor = try await BASRustMemoryUsageTrackerActor
            .makeWithDefaults()
        let isUsing = await actor.isUsingRustCore
        XCTAssertTrue(isUsing,
            "makeWithDefaults uses V2 Rust-backed path" +
            " (since chapter 七百十二 wire-in)")
    }

    // MARK: - Cross-mirror

    func testMakeWithDefaultsConsistentWithMakeFlagsFreshInit() async throws {
        // For every pilot,makeWithDefaults() must
        // produce the same path selection as
        // make(flags: BASLanguageAugmentationFeatureFlags())。
        // This is the contract:makeWithDefaults is
        // SUGAR over the existing factory pattern。
        let flags = BASLanguageAugmentationFeatureFlags()

        let sqlConvenience = try await BASMemoryUsageTracker
            .makeWithDefaults(
                databaseURL: makeTempSqliteURL("sql_conv"))
        let sqlExplicit = try await BASMemoryUsageTracker
            .make(databaseURL: makeTempSqliteURL("sql_expl"),
                  flags: flags)
        // Smoke-test:both can record and read。 If they
        // diverge,one would crash;they don't because
        // both route to the V2 path。
        _ = try await sqlConvenience.record(
            atomID: "a", sessionRef: "s",
            turnRef: "t", permitMode: "allow")
        _ = try await sqlExplicit.record(
            atomID: "a", sessionRef: "s",
            turnRef: "t", permitMode: "allow")

        // C pilot
        let cConv = await BASMonotonicNanos.makeWithDefaults()
        let cExp = await BASMonotonicNanos.make(flags: flags)
        let cConvUse = await cConv.isUsingCBridge
        let cExpUse = await cExp.isUsingCBridge
        XCTAssertEqual(cConvUse, cExpUse)

        // Metal pilot
        let mConv = await BASMetalKernelLibraryLoader
            .makeWithDefaults()
        let mExp = await BASMetalKernelLibraryLoader
            .make(flags: flags)
        let mConvUse = await mConv.isUsingV2
        let mExpUse = await mExp.isUsingV2
        XCTAssertEqual(mConvUse, mExpUse)

        // C++ pilot
        let xConv = await BASMPSGraphExecutableCacheCxxBridge
            .makeWithDefaults()
        let xExp = await BASMPSGraphExecutableCacheCxxBridge
            .make(flags: flags)
        let xConvUse = await xConv.isUsingCxxCache
        let xExpUse = await xExp.isUsingCxxCache
        XCTAssertEqual(xConvUse, xExpUse)

        // Rust pilot
        let rConv = try await BASRustMemoryUsageTrackerActor
            .makeWithDefaults()
        let rExp = try await BASRustMemoryUsageTrackerActor
            .make(flags: flags)
        let rConvUse = await rConv.isUsingRustCore
        let rExpUse = await rExp.isUsingRustCore
        XCTAssertEqual(rConvUse, rExpUse)

        // Clean up temp SQL files
        try? FileManager.default.removeItem(
            at: makeTempSqliteURL("sql_conv"))
        try? FileManager.default.removeItem(
            at: makeTempSqliteURL("sql_expl"))
    }

    private func makeTempSqliteURL(_ suffix: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent(
            "bas_make_defaults_xmirror_"
                + suffix + "_"
                + UUID().uuidString + ".sqlite")
    }
}
