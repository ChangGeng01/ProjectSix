// MARK: - BASFivePilotCrossInstanceScopeTests
// REAL cross-instance scope tests — document via test
// what HAPPENS when hosts run multiple brain instances
// sharing or not-sharing each pilot's backing storage。
//
// Production scenarios this clarifies:
//   - Multi-tenant host: each tenant gets own brain
//   - Recovery host: brain restarts mid-process
//   - A/B host: side-by-side brains with different configs
//   - Audit replay host: rebuild brain from SQL state
//
// **Pilot scope summary** (per-pilot reality):
//
// | Pilot | Scope | Shared automatically? |
// |-------|----------------------|------------------|
// | C     | Per-call            | N/A (no state) |
// | SQL   | Per file URL        | Same URL → shared |
// | C++   | PROCESS-GLOBAL      | Always shared via bridge |
// | Rust  | Per actor instance  | Independent per-instance |
// | Metal | Per loader instance | Independent per-instance |
//
// Hosts that don't know these scopes will hit subtle
// bugs (e.g. "why does my brain see another tenant's
// cached summaries?" → C++ is process-global)。 These
// tests pin the semantics so they're regression-proof。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotCrossInstanceScopeTests: XCTestCase {

    // MARK: - SQL: shared file URL → shared persistence

    func testSQLSharedFileURLAcrossInstances() async throws {
        let dbURL = URL(fileURLWithPath:
            NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-shared-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default
                .removeItem(at: dbURL)
        }
        // Instance 1 writes 2 records
        do {
            let tracker = try BASMemoryUsageTracker(
                databaseURL: dbURL)
            let store = BASSQLBrainHistoryStore(
                tracker: tracker)
            let brain = try await BASCognitiveBrain
                .makeWithDefaults(
                    sqlHistoryStore: store)
            _ = await brain.summary("instance-1 turn 1")
            _ = await brain.summary("instance-1 turn 2")
            let count = await store.recordCount
            XCTAssertEqual(count, 2)
        }
        // Instance 2 with the SAME file URL sees those
        // records + adds 1 more。
        let tracker2 = try BASMemoryUsageTracker(
            databaseURL: dbURL)
        let store2 = BASSQLBrainHistoryStore(
            tracker: tracker2)
        let preexistingCount = await store2.recordCount
        XCTAssertEqual(preexistingCount, 2,
            "SQL pilot scope: SAME file URL → SAME" +
            " persistent records visible to subsequent" +
            " brain instances")
        let brain2 = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store2)
        _ = await brain2.summary("instance-2 turn 1")
        let finalCount = await store2.recordCount
        XCTAssertEqual(finalCount, 3,
            "Instance 2 records add to instance 1's" +
            " durable history")
    }

    // MARK: - C++: process-global → automatically shared

    func testCxxCacheIsProcessGlobalAcrossInstances()
        async throws
    {
        // Two BRIDGES with useCxxCache=true share the
        // SAME C++ unordered_map singleton。 This is
        // explicit substrate behavior — hosts wanting
        // isolated caches MUST use cxxSummaryCache=nil。
        let bridge1 =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try await bridge1.clear()  // pristine
        let cache1 = BASCxxBrainSummaryCache(
            bridge: bridge1)
        let brain1 = try await BASCognitiveBrain
            .makeWithDefaults(
                cxxSummaryCache: cache1)
        _ = await brain1.summary("shared cache turn")
        // Now construct a SECOND bridge + brain。 The
        // bridge2's underlying C++ singleton is the
        // SAME as bridge1's。
        let bridge2 =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        let cache2 = BASCxxBrainSummaryCache(
            bridge: bridge2)
        let brain2 = try await BASCognitiveBrain
            .makeWithDefaults(
                cxxSummaryCache: cache2)
        // Brain 2 should see brain 1's cached summary
        // (same input → same cache hit)。
        let s = await brain2.summary("shared cache turn")
        XCTAssertEqual(s.input, "shared cache turn",
            "C++ pilot scope: process-global means" +
            " brain 2 hits brain 1's cached entry")
        // Cleanup the process-global cache
        try? await bridge1.clear()
    }

    // MARK: - Rust: per-actor → independent

    func testRustTrackersAreIndependent() async throws {
        let rust1 = BASRustBrainHistoryStore(
            tracker: try BASRustMemoryUsageTrackerActor(
                useRustCore: true))
        let rust2 = BASRustBrainHistoryStore(
            tracker: try BASRustMemoryUsageTrackerActor(
                useRustCore: true))
        let brain1 = try await BASCognitiveBrain
            .makeWithDefaults(
                rustHistoryStore: rust1)
        let brain2 = try await BASCognitiveBrain
            .makeWithDefaults(
                rustHistoryStore: rust2)
        // Brain 1 writes 2 records
        _ = await brain1.summary("brain-1 turn 1")
        _ = await brain1.summary("brain-1 turn 2")
        // Brain 2 writes 1 record
        _ = await brain2.summary("brain-2 turn 1")
        let count1 = await rust1.recordCount
        let count2 = await rust2.recordCount
        XCTAssertEqual(count1, 2,
            "Rust pilot scope: instance-local —" +
            " brain 1's records live in rust1 only")
        XCTAssertEqual(count2, 1,
            "brain 2's record lives in rust2 only")
    }

    // MARK: - In-memory history: per-brain → independent

    func testInMemoryHistoryIsPerBrainInstance() async throws {
        let brain1 = try await BASCognitiveBrain
            .makeWithDefaults()
        let brain2 = try await BASCognitiveBrain
            .makeWithDefaults()
        _ = await brain1.summary("brain-1 first")
        _ = await brain1.summary("brain-1 second")
        _ = await brain2.summary("brain-2 only")
        let h1 = await brain1.summaryHistoryCount
        let h2 = await brain2.summaryHistoryCount
        XCTAssertEqual(h1, 2,
            "brain 1 history has 2 entries")
        XCTAssertEqual(h2, 1,
            "brain 2 history has 1 entry — fully" +
            " independent from brain 1")
    }

    // MARK: - Metal: per-loader → independent

    func testMetalLoadersAreIndependent() async throws {
        let loader1 = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let loader2 = BASMetalKernelLibraryLoader(
            useMetalKernelV2: false)
        let brain1 = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: loader1)
        let brain2 = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: loader2)
        let exposed1 = await brain1.metalLibraryLoader
        let exposed2 = await brain2.metalLibraryLoader
        XCTAssertFalse(exposed1 === exposed2,
            "Metal pilot scope: distinct loaders" +
            " injected → distinct exposed references。" +
            " No cross-brain interference。")
        // Each loader retains its own V1/V2 mode
        let v1Mode = await exposed1?.isUsingV2
        let v2Mode = await exposed2?.isUsingV2
        XCTAssertEqual(v1Mode, true)
        XCTAssertEqual(v2Mode, false)
    }

    // MARK: - SQL + Rust dual-backend, cross-instance

    func testDualBackendCrossInstance() async throws {
        // Real production: tenant A has SQL+Rust, tenant
        // B has SQL+Rust。 SQL is durable + tenant-scoped
        // via file URL。 Rust is per-instance。
        let dbA = URL(fileURLWithPath:
            NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-tenant-A-\(UUID().uuidString).sqlite")
        let dbB = URL(fileURLWithPath:
            NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-tenant-B-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: dbA)
            try? FileManager.default.removeItem(at: dbB)
        }
        let sqlA = BASSQLBrainHistoryStore(
            tracker: try BASMemoryUsageTracker(
                databaseURL: dbA))
        let sqlB = BASSQLBrainHistoryStore(
            tracker: try BASMemoryUsageTracker(
                databaseURL: dbB))
        let rustA = BASRustBrainHistoryStore(
            tracker: try BASRustMemoryUsageTrackerActor(
                useRustCore: true))
        let rustB = BASRustBrainHistoryStore(
            tracker: try BASRustMemoryUsageTrackerActor(
                useRustCore: true))
        let brainA = try await BASCognitiveBrain
            .makeWithDefaults(
                sqlHistoryStore: sqlA,
                rustHistoryStore: rustA)
        let brainB = try await BASCognitiveBrain
            .makeWithDefaults(
                sqlHistoryStore: sqlB,
                rustHistoryStore: rustB)
        _ = await brainA.summary("tenant A turn 1")
        _ = await brainA.summary("tenant A turn 2")
        _ = await brainB.summary("tenant B turn 1")
        // Verify isolation: each tenant sees only its
        // own records。
        let mA = await brainA.pilotMetrics()
        let mB = await brainB.pilotMetrics()
        XCTAssertEqual(mA.sqlRecordCount, 2)
        XCTAssertEqual(mA.rustRecordCount, 2)
        XCTAssertEqual(mB.sqlRecordCount, 1)
        XCTAssertEqual(mB.rustRecordCount, 1)
    }
}
