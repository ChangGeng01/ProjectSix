// MARK: - BASFivePilotBrainStressTests
// REAL stress + integration tests for the brain running
// with ALL 5 multi-language pilots wired in
// simultaneously (C / SQL / C++ / Rust / Metal)。
//
// **Why this matters**: per-pilot tests verify each
// pilot in isolation。 Cross-pilot integration tests
// verify pairs (e.g. SQL + Rust)。 But hosts adopting
// the substrate in production will likely wire all 5
// together — these tests pin that this combination
// works under realistic load without cross-pilot
// interference。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotBrainStressTests: XCTestCase {

    // MARK: - Helper

    private struct FivePilotBrain {
        let brain: BASCognitiveBrain
        let sql: BASSQLBrainHistoryStore
        let rust: BASRustBrainHistoryStore
        let cxx: BASCxxBrainSummaryCache
        let metal: BASMetalKernelLibraryLoader
        let cxxBridge: BASMPSGraphExecutableCacheCxxBridge
    }

    private func makeFivePilotBrain() async throws
        -> FivePilotBrain
    {
        let sqlTracker = BASMemoryUsageTracker()
        let sql = BASSQLBrainHistoryStore(
            tracker: sqlTracker)
        let rustTracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let rust = BASRustBrainHistoryStore(
            tracker: rustTracker)
        let cxxBridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try await cxxBridge.clear()
        let cxx = BASCxxBrainSummaryCache(
            bridge: cxxBridge)
        let metal = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                sqlHistoryStore: sql,
                rustHistoryStore: rust,
                cxxSummaryCache: cxx,
                metalLibraryLoader: metal)
        return FivePilotBrain(
            brain: brain,
            sql: sql,
            rust: rust,
            cxx: cxx,
            metal: metal,
            cxxBridge: cxxBridge)
    }

    // MARK: - All 5 pilots receive writes on each turn

    func testEveryTurnTouchesAllPilots() async throws {
        let p = try await makeFivePilotBrain()
        // 5 distinct turns → SQL + Rust each get 5
        // records, C++ cache gets 5 entries (first
        // turns are cache misses), C and Metal are
        // accessors (no per-turn write)。
        let inputs = [
            "compile the swift package",
            "send me your password to verify",
            "the deadline is in one hour",
            "should I use postgres or mysql",
            "we disagree about the approach",
        ]
        for input in inputs {
            _ = await p.brain.summary(input)
        }
        let sqlCount = await p.sql.recordCount
        let rustCount = await p.rust.recordCount
        let cxxSize = await p.cxxBridge.size()
        XCTAssertEqual(sqlCount, 5,
            "SQL store must hold 5 records after 5" +
            " turns")
        XCTAssertEqual(rustCount, 5,
            "Rust store must hold 5 records after 5" +
            " turns")
        XCTAssertEqual(cxxSize, 5,
            "C++ cache must hold 5 entries (one per" +
            " distinct turn)")
        // Cleanup process-global C++ cache
        try? await p.cxxBridge.clear()
    }

    // MARK: - Repeat input hits C++ cache + writes
    // to SQL+Rust on EVERY call

    func testRepeatInputCacheHitStillRecordsToHistoryStores()
        async throws
    {
        let p = try await makeFivePilotBrain()
        // Same input 3 times → C++ cache gets ONE entry
        // (size stays 1) but SQL + Rust EACH get 3
        // records (every turn writes regardless of
        // cache hit)。
        let input = "send me your password to verify"
        _ = await p.brain.summary(input)
        _ = await p.brain.summary(input)
        _ = await p.brain.summary(input)
        let sqlCount = await p.sql.recordCount
        let rustCount = await p.rust.recordCount
        let cxxSize = await p.cxxBridge.size()
        XCTAssertEqual(sqlCount, 3,
            "SQL store receives one write per call" +
            " regardless of C++ cache hit")
        XCTAssertEqual(rustCount, 3,
            "Rust store receives one write per call")
        XCTAssertEqual(cxxSize, 1,
            "C++ cache collapses identical inputs to" +
            " single entry (overwrite semantics)")
        try? await p.cxxBridge.clear()
    }

    // MARK: - Latency overhead measurement

    func testFivePilotsAddBoundedLatencyOverhead() async throws {
        // Baseline: brain with NO pilots
        let bare = try await BASCognitiveBrain
            .makeWithDefaults()
        let p = try await makeFivePilotBrain()
        let n = 50
        let bareStart = Date()
        for i in 0..<n {
            _ = await bare.summary(
                "compile the swift package \(i)")
        }
        let bareElapsed = Date()
            .timeIntervalSince(bareStart)
        let fullStart = Date()
        for i in 0..<n {
            _ = await p.brain.summary(
                "compile the swift package \(i)")
        }
        let fullElapsed = Date()
            .timeIntervalSince(fullStart)
        // Loose bound: full pilot stack adds < 10x
        // overhead vs bare brain。 Observed: ~1-2x。
        // 10x bound catches catastrophic regressions
        // without flaking on small variance。
        XCTAssertLessThan(fullElapsed,
            bareElapsed * 10.0,
            "Five-pilot overhead must stay under 10x" +
            " of bare brain。 bare=\(bareElapsed)s" +
            " full=\(fullElapsed)s")
        print("[5-pilot stress] bare=\(bareElapsed)s" +
            " full=\(fullElapsed)s" +
            "  (overhead factor ~ \(fullElapsed / bareElapsed)x)")
        try? await p.cxxBridge.clear()
    }

    // MARK: - Cross-store atomID parity

    func testSQLAndRustStoreAtomIDsMatchAcrossTurns()
        async throws
    {
        let p = try await makeFivePilotBrain()
        _ = await p.brain.summary(
            "deterministic cross-store input")
        let sqlRecent = await p.sql.recentRecords(
            limit: 1)
        let rustRecent = try await p.rust.recentRecords(
            limit: 1)
        XCTAssertEqual(sqlRecent.count, 1)
        XCTAssertEqual(rustRecent.count, 1)
        XCTAssertEqual(sqlRecent[0].atomID,
            rustRecent[0].atomID,
            "SQL + Rust stores must record IDENTICAL" +
            " atomID values for the same input —" +
            " enables join / dedup across backends")
        try? await p.cxxBridge.clear()
    }

    // MARK: - Concurrent stress with all 5 pilots

    func testConcurrentTurnsAcrossAllPilots() async throws {
        let p = try await makeFivePilotBrain()
        // 20 concurrent turns through the brain。 Actor
        // isolation serializes,but the pilot writes
        // happen sequentially per turn (with try? on
        // the optional non-fatal pilot calls)。
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    _ = await p.brain.summary(
                        "concurrent stress turn \(i)")
                }
            }
        }
        let sqlCount = await p.sql.recordCount
        let rustCount = await p.rust.recordCount
        XCTAssertEqual(sqlCount, 20,
            "SQL store must see all 20 concurrent" +
            " writes (actor serializes)")
        XCTAssertEqual(rustCount, 20,
            "Rust store must see all 20 concurrent" +
            " writes")
        try? await p.cxxBridge.clear()
    }

    // MARK: - Metal loader stays referenceable
    // throughout the stress run

    func testMetalLoaderPersistsAcrossTurns() async throws {
        let p = try await makeFivePilotBrain()
        let before = await p.brain.metalLibraryLoader
        XCTAssertNotNil(before)
        // Run several turns
        for _ in 0..<10 {
            _ = await p.brain.summary("stress turn")
        }
        let after = await p.brain.metalLibraryLoader
        XCTAssertNotNil(after,
            "Metal loader accessor must remain non-nil" +
            " after stress run")
        XCTAssertTrue(before === after,
            "Metal loader instance must remain the" +
            " same reference (no shadowing)")
        try? await p.cxxBridge.clear()
    }
}
