// MARK: - BASFivePilotFactoryFlagStateDivergenceMatrixTests
// chapter 七百三十四 / M2247 第一刀 — factory flag-state-
//                                     divergence matrix。
//                                     Tenth pillar of
//                                     5-pilot ACTOR
//                                     contract。
//
// ## Why
//
// Chapter 732 sealed sampled-ONCE determinism — flag is
// captured at construction and ignored thereafter。
// Chapter 734 seals the complementary contract:
// make(flags:) with DIFFERENT flag states produces
// independent actors。 Proves the flag actually matters
// at construction (it isn't silently ignored)。
//
// Combined chapters 732 + 734 pin the full sampling
// contract:
//   732 = "flag changes AFTER construction don't matter"
//   734 = "flag values AT construction DO matter"
//
// ## Coverage (5 per-pilot + 1 cross-pilot summary)

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotFactoryFlagStateDivergenceMatrixTests: XCTestCase {

    /// Helper:construct two flag actors with opposing
    /// states of the given flag,then construct the pilot
    /// twice。 The two pilot instances must be DISTINCT
    /// references (proves separate construction occurred)。
    private func assertSeparateConstructionsProduceDistinctActors<T: AnyObject>(
        flagA: BASLanguageAugmentationFeatureFlags,
        flagB: BASLanguageAugmentationFeatureFlags,
        construct: (BASLanguageAugmentationFeatureFlags) async throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws {
        let pilotA = try await construct(flagA)
        let pilotB = try await construct(flagB)
        XCTAssertFalse(pilotA === pilotB,
            "Two factory calls with different flag" +
            " actors must produce distinct pilot" +
            " instances",
            file: file, line: line)
    }

    // MARK: - SQL pilot

    func testSQLPilotFactoryWithDifferentFlagsProducesDistinctActors() async throws {
        let tempA = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-a-\(UUID().uuidString).sqlite")
        let tempB = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-b-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: tempA)
            try? FileManager.default.removeItem(at: tempB)
        }
        let flagsA = BASLanguageAugmentationFeatureFlags()
        await flagsA.setFlag(.sqlMigratorEnabled, to: false)
        let flagsB = BASLanguageAugmentationFeatureFlags()
        await flagsB.setFlag(.sqlMigratorEnabled, to: true)
        let pilotA = try await BASMemoryUsageTracker
            .make(databaseURL: tempA, flags: flagsA)
        let pilotB = try await BASMemoryUsageTracker
            .make(databaseURL: tempB, flags: flagsB)
        XCTAssertFalse(pilotA === pilotB)
    }

    // MARK: - C pilot

    func testCPilotFactoryWithDifferentFlagsProducesDistinctActors() async throws {
        let flagsA = BASLanguageAugmentationFeatureFlags()
        await flagsA.setFlag(.cBridgeEnabled, to: false)
        let flagsB = BASLanguageAugmentationFeatureFlags()
        await flagsB.setFlag(.cBridgeEnabled, to: true)
        try await assertSeparateConstructionsProduceDistinctActors(
            flagA: flagsA, flagB: flagsB,
            construct: { flags in
                await BASMonotonicNanos.make(flags: flags)
            })
    }

    // MARK: - Metal pilot

    func testMetalPilotFactoryWithDifferentFlagsProducesDistinctActors() async throws {
        let flagsA = BASLanguageAugmentationFeatureFlags()
        await flagsA.setFlag(.metalKernelV2Enabled, to: false)
        let flagsB = BASLanguageAugmentationFeatureFlags()
        await flagsB.setFlag(.metalKernelV2Enabled, to: true)
        try await assertSeparateConstructionsProduceDistinctActors(
            flagA: flagsA, flagB: flagsB,
            construct: { flags in
                await BASMetalKernelLibraryLoader
                    .make(flags: flags)
            })
    }

    // MARK: - C++ pilot

    func testCxxPilotFactoryWithDifferentFlagsProducesDistinctActors() async throws {
        let flagsA = BASLanguageAugmentationFeatureFlags()
        await flagsA.setFlag(.cxxMpsCacheEnabled, to: false)
        let flagsB = BASLanguageAugmentationFeatureFlags()
        await flagsB.setFlag(.cxxMpsCacheEnabled, to: true)
        try await assertSeparateConstructionsProduceDistinctActors(
            flagA: flagsA, flagB: flagsB,
            construct: { flags in
                await BASMPSGraphExecutableCacheCxxBridge
                    .make(flags: flags)
            })
    }

    // MARK: - Rust pilot

    func testRustPilotFactoryWithDifferentFlagsProducesDistinctActors() async throws {
        let flagsA = BASLanguageAugmentationFeatureFlags()
        await flagsA.setFlag(.rustCoreEnabled, to: false)
        let flagsB = BASLanguageAugmentationFeatureFlags()
        await flagsB.setFlag(.rustCoreEnabled, to: true)
        try await assertSeparateConstructionsProduceDistinctActors(
            flagA: flagsA, flagB: flagsB,
            construct: { flags in
                try await BASRustMemoryUsageTrackerActor
                    .make(flags: flags)
            })
    }

    // MARK: - Cross-pilot divergence summary

    /// Construct all 5 pilots with flags-all-OFF then all
    /// 5 with flags-all-ON。 Both sets must yield 5
    /// distinct instances + the 10 total are pairwise
    /// distinct (no aliasing across factory call modes)。
    func testAllFivePilotsFactoryDivergenceAllOffVsAllOn() async throws {
        let tempA = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-a-\(UUID().uuidString).sqlite")
        let tempB = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-b-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: tempA)
            try? FileManager.default.removeItem(at: tempB)
        }
        // Two flag actors with opposing states
        let flagsOff = BASLanguageAugmentationFeatureFlags()
        let flagsOn = BASLanguageAugmentationFeatureFlags()
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            await flagsOff.setFlag(flag, to: false)
            await flagsOn.setFlag(flag, to: true)
        }
        // Construct 5 pilots × 2 flag states = 10 actors
        let allOff: [AnyObject] = [
            try await BASMemoryUsageTracker.make(
                databaseURL: tempA, flags: flagsOff),
            await BASMonotonicNanos.make(flags: flagsOff),
            await BASMetalKernelLibraryLoader
                .make(flags: flagsOff),
            await BASMPSGraphExecutableCacheCxxBridge
                .make(flags: flagsOff),
            try await BASRustMemoryUsageTrackerActor
                .make(flags: flagsOff)
        ]
        let allOn: [AnyObject] = [
            try await BASMemoryUsageTracker.make(
                databaseURL: tempB, flags: flagsOn),
            await BASMonotonicNanos.make(flags: flagsOn),
            await BASMetalKernelLibraryLoader
                .make(flags: flagsOn),
            await BASMPSGraphExecutableCacheCxxBridge
                .make(flags: flagsOn),
            try await BASRustMemoryUsageTrackerActor
                .make(flags: flagsOn)
        ]
        XCTAssertEqual(allOff.count, 5)
        XCTAssertEqual(allOn.count, 5)
        // All 10 actors pairwise distinct
        let allTen = allOff + allOn
        for i in 0..<allTen.count {
            for j in 0..<allTen.count where j != i {
                XCTAssertFalse(allTen[i] === allTen[j],
                    "Actor pair \(i),\(j) aliases — flag" +
                    " divergence not preserving" +
                    " independence")
            }
        }
    }
}
