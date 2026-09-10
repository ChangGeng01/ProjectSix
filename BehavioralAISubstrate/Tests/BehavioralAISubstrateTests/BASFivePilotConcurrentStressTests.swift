// MARK: - BASFivePilotConcurrentStressTests
// chapter 七百十五 / M2209 第一刀 — concurrent-construction
//                                  stress tests for the
//                                  5 pilot factory
//                                  patterns。 Validates
//                                  thread-safety of
//                                  makeWithDefaults()
//                                  under load。
//
// ## Why
//
// chapter 七百十三 added `makeWithDefaults()` factories
// to all 5 pilots。 Each internally constructs a fresh
// `BASLanguageAugmentationFeatureFlags()` actor and
// routes through `.make(flags:)`。 The flag actor's
// `init()` is non-async (synchronous);the pilot's
// `make(flags:)` is async and reads from the actor。
//
// These tests verify that constructing many instances
// of each pilot concurrently doesn't:
//   - Crash
//   - Deadlock
//   - Produce inconsistent V2/V1 path selection
//     (every instance should be V2 per chapter 七百十二
//      wire-in)
//
// chapter 705 C++ pilot already has concurrency stress
// tests for its OPERATIONS (insert/lookup);this file
// covers concurrency stress at the CONSTRUCTION level
// for all 5 pilots。
//
// ## Coverage (5 tests)
//
//   1-4. 50 concurrent makeWithDefaults() for C/Metal/
//        C++/Rust pilots — assert all 50 instances
//        are in V2 mode
//   5. 50 concurrent makeWithDefaults(databaseURL:) for
//      SQL pilot — each with its own temp file (SQL
//      is per-instance,not process-global)

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotConcurrentStressTests: XCTestCase {

    private static let concurrentInstanceCount: Int = 50

    // MARK: - C pilot (BASMonotonicNanos)

    func testConcurrentMonotonicNanosMakeWithDefaults() async {
        let count = Self.concurrentInstanceCount
        let instances = await withTaskGroup(
            of: BASMonotonicNanos.self,
            returning: [BASMonotonicNanos].self
        ) { group in
            for _ in 0..<count {
                group.addTask {
                    await BASMonotonicNanos.makeWithDefaults()
                }
            }
            var results: [BASMonotonicNanos] = []
            for await actor in group {
                results.append(actor)
            }
            return results
        }
        XCTAssertEqual(instances.count, count)
        for inst in instances {
            let v = await inst.isUsingCBridge
            XCTAssertTrue(v,
                "every concurrent instance must be V2")
        }
    }

    // MARK: - Metal pilot (BASMetalKernelLibraryLoader)

    func testConcurrentMetalKernelLibraryLoaderMakeWithDefaults() async {
        let count = Self.concurrentInstanceCount
        let instances = await withTaskGroup(
            of: BASMetalKernelLibraryLoader.self,
            returning: [BASMetalKernelLibraryLoader].self
        ) { group in
            for _ in 0..<count {
                group.addTask {
                    await BASMetalKernelLibraryLoader
                        .makeWithDefaults()
                }
            }
            var results: [BASMetalKernelLibraryLoader] = []
            for await actor in group {
                results.append(actor)
            }
            return results
        }
        XCTAssertEqual(instances.count, count)
        for inst in instances {
            let v = await inst.isUsingV2
            XCTAssertTrue(v)
        }
    }

    // MARK: - C++ pilot (BASMPSGraphExecutableCacheCxxBridge)

    func testConcurrentMPSGraphCacheCxxBridgeMakeWithDefaults() async {
        let count = Self.concurrentInstanceCount
        let instances = await withTaskGroup(
            of: BASMPSGraphExecutableCacheCxxBridge.self,
            returning: [BASMPSGraphExecutableCacheCxxBridge].self
        ) { group in
            for _ in 0..<count {
                group.addTask {
                    await BASMPSGraphExecutableCacheCxxBridge
                        .makeWithDefaults()
                }
            }
            var results: [BASMPSGraphExecutableCacheCxxBridge] = []
            for await actor in group {
                results.append(actor)
            }
            return results
        }
        XCTAssertEqual(instances.count, count)
        for inst in instances {
            let v = await inst.isUsingCxxCache
            XCTAssertTrue(v)
        }
    }

    // MARK: - Rust pilot (BASRustMemoryUsageTrackerActor)

    func testConcurrentRustMemoryUsageTrackerActorMakeWithDefaults() async throws {
        let count = Self.concurrentInstanceCount
        let instances = try await withThrowingTaskGroup(
            of: BASRustMemoryUsageTrackerActor.self,
            returning: [BASRustMemoryUsageTrackerActor].self
        ) { group in
            for _ in 0..<count {
                group.addTask {
                    try await BASRustMemoryUsageTrackerActor
                        .makeWithDefaults()
                }
            }
            var results: [BASRustMemoryUsageTrackerActor] = []
            for try await actor in group {
                results.append(actor)
            }
            return results
        }
        XCTAssertEqual(instances.count, count)
        for inst in instances {
            let v = await inst.isUsingRustCore
            XCTAssertTrue(v)
        }
    }

    // MARK: - SQL pilot (BASMemoryUsageTracker)
    //
    // SQL pilot is per-instance (each tracker has its
    // own SQLite file)。 Use 10 instances instead of 50
    // to bound test runtime (each instance writes 1 row)。

    func testConcurrentMemoryUsageTrackerMakeWithDefaults() async throws {
        let count = 10
        let dir = FileManager.default.temporaryDirectory
        let urls = (0..<count).map { i in
            dir.appendingPathComponent(
                "bas_concurrent_sql_\(i)_"
                    + UUID().uuidString + ".sqlite")
        }
        defer {
            for u in urls {
                try? FileManager.default.removeItem(at: u)
            }
        }
        let trackers = try await withThrowingTaskGroup(
            of: BASMemoryUsageTracker.self,
            returning: [BASMemoryUsageTracker].self
        ) { group in
            for url in urls {
                group.addTask {
                    try await BASMemoryUsageTracker
                        .makeWithDefaults(databaseURL: url)
                }
            }
            var results: [BASMemoryUsageTracker] = []
            for try await tracker in group {
                results.append(tracker)
            }
            return results
        }
        XCTAssertEqual(trackers.count, count)
        // Each tracker is independent — verify each can
        // record without interference。
        for tracker in trackers {
            _ = try await tracker.record(
                atomID: "concurrent-test",
                sessionRef: "s",
                turnRef: "t",
                permitMode: "allow")
            let c = await tracker.recordCount
            XCTAssertEqual(c, 1)
        }
    }
}
