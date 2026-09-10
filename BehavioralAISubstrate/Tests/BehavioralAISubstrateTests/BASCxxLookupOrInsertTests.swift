// MARK: - BASCxxLookupOrInsertTests
// 主线 全面 开发: C++ pilot now offers atomic
// `lookup_or_insert` — eliminates the TOCTOU race
// window between Swift-side lookup + insert calls。

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate
@testable import BASMPSGraphExecutableCacheCxx

final class BASCxxLookupOrInsertTests: XCTestCase {

    private func makeCleanBridge() async throws
        -> BASMPSGraphExecutableCacheCxxBridge
    {
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try await bridge.clear()
        return bridge
    }

    // MARK: - Empty cache → inserts default

    func testEmptyCacheInsertsDefault() async throws {
        let bridge = try await makeCleanBridge()
        let result = try await bridge.lookupOrInsert(
            key: "new-key", defaultValue: "default-val")
        XCTAssertEqual(result.value, "default-val")
        XCTAssertFalse(result.wasPresent,
            "Empty cache → default was inserted,not" +
            " found")
        // Verify the default was actually persisted
        let lookedUp = try await bridge.lookup(
            key: "new-key")
        XCTAssertEqual(lookedUp, "default-val",
            "Subsequent lookup must return the inserted" +
            " default")
        try? await bridge.clear()
    }

    // MARK: - Existing key → returns existing,no overwrite

    func testExistingKeyReturnsExisting() async throws {
        let bridge = try await makeCleanBridge()
        try await bridge.insert(
            key: "k", value: "original")
        let result = try await bridge.lookupOrInsert(
            key: "k", defaultValue: "default")
        XCTAssertEqual(result.value, "original",
            "Lookup hit returns EXISTING value,not the" +
            " default")
        XCTAssertTrue(result.wasPresent)
        // Verify the original wasn't clobbered
        let lookedUp = try await bridge.lookup(key: "k")
        XCTAssertEqual(lookedUp, "original",
            "Subsequent lookup confirms original is" +
            " untouched")
        try? await bridge.clear()
    }

    // MARK: - V1 path

    func testV1PathThrows() async throws {
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: false)
        do {
            _ = try await bridge.lookupOrInsert(
                key: "k", defaultValue: "v")
            XCTFail("V1 path must throw")
        } catch
            BASMPSGraphExecutableCacheCxxBridgeError
                .unknownReturnCode(let rc)
        {
            XCTAssertEqual(rc, -99,
                "V1 sentinel is -99 (same as insert/lookup)")
        }
    }

    // MARK: - Concurrent atomicity

    func testConcurrentLookupOrInsertIsAtomic() async throws {
        // Stress the atomic check-then-act under
        // concurrent contention。 Many tasks calling
        // lookup_or_insert with DIFFERENT defaults on
        // the SAME key — exactly ONE default should
        // win,everyone else sees the winner via
        // wasPresent=true。 Doing this in Swift with
        // separate lookup + insert calls would have a
        // race window where 2+ inserts could clobber。
        let bridge = try await makeCleanBridge()
        let key = "contended-key"
        let taskCount = 50
        await withTaskGroup(
            of: (value: String, wasPresent: Bool).self
        ) { group in
            for i in 0..<taskCount {
                group.addTask {
                    do {
                        return try await bridge
                            .lookupOrInsert(
                                key: key,
                                defaultValue: "task-\(i)")
                    } catch {
                        return (value: "error",
                            wasPresent: false)
                    }
                }
            }
            var insertedCount = 0
            var foundCount = 0
            var seenValues: Set<String> = []
            for await result in group {
                if !result.wasPresent {
                    insertedCount += 1
                }
                if result.wasPresent {
                    foundCount += 1
                }
                seenValues.insert(result.value)
            }
            XCTAssertEqual(insertedCount, 1,
                "EXACTLY ONE task must observe wasPresent" +
                " == false (the inserter)。 If more,the" +
                " TOCTOU window is open。 Got insertedCount" +
                " = \(insertedCount)")
            XCTAssertEqual(foundCount, taskCount - 1,
                "All other tasks must see wasPresent ==" +
                " true,returning the winner's value")
            XCTAssertEqual(seenValues.count, 1,
                "All tasks must agree on ONE value — the" +
                " winner's default。 Got: \(seenValues)")
        }
        try? await bridge.clear()
    }

    // MARK: - Raw C function

    func testRawCFunctionVersionPin() {
        XCTAssertEqual(
            bas_mps_cache_lookup_or_insert_version(), 1)
    }
}
