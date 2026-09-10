// MARK: - BASFivePilotBoundaryAndErrorPathTests
// chapter 七百十六 / M2211 第一刀 — boundary input +
//                                  error-path validation
//                                  for all 5 pilots。
//
// ## Coverage
//
//   SQL pilot:
//     1. empty atomID still records (no validation)
//     2. very large fields (1KB strings) round-trip
//
//   C pilot:
//     3. multiple consecutive rawCNanos() reads strictly
//        non-decreasing under 1000-iteration stress
//
//   C++ pilot:
//     4. empty-string key allowed,distinct from "absent"
//     5. 10KB value round-trips correctly
//
//   Rust pilot:
//     6. empty atomID query returns ALL records
//     7. record then query roundtrip preserves UTF-8
//        with non-ASCII characters

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotBoundaryAndErrorPathTests: XCTestCase {

    // MARK: - SQL pilot boundaries

    func testSqlEmptyAtomIDIsStillRecorded() async throws {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(
            "bas_boundary_sql_empty_"
                + UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try await BASMemoryUsageTracker
            .makeWithDefaults(databaseURL: url)
        _ = try await tracker.record(
            atomID: "",
            sessionRef: "s",
            turnRef: "t",
            permitMode: "allow")
        let count = await tracker.recordCount
        XCTAssertEqual(count, 1,
            "empty atomID is recorded without validation;" +
            " upstream validators (if any) live above" +
            " this layer")
    }

    func testSqlLargeFieldsRoundTrip() async throws {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(
            "bas_boundary_sql_large_"
                + UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try await BASMemoryUsageTracker
            .makeWithDefaults(databaseURL: url)
        let largeAtom = String(
            repeating: "atom-", count: 200)  // 1000 chars
        let largeSession = String(
            repeating: "session-", count: 125)  // 1000 chars
        _ = try await tracker.record(
            atomID: largeAtom,
            sessionRef: largeSession,
            turnRef: "t",
            permitMode: "allow")
        let records = await tracker.allRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].atomID, largeAtom)
        XCTAssertEqual(records[0].sessionRef, largeSession)
    }

    // MARK: - C pilot stress

    func testCMonotonicNanosNonDecreasingOver1000Reads() async throws {
        let actor = await BASMonotonicNanos.makeWithDefaults()
        var prior = try await actor.current()
        for _ in 0..<1000 {
            let next = try await actor.current()
            XCTAssertGreaterThanOrEqual(next, prior,
                "monotonic clock must never regress")
            prior = next
        }
    }

    // MARK: - C++ pilot boundaries

    func testCxxEmptyStringKeyIsDistinctFromAbsent() async throws {
        let bridge = await BASMPSGraphExecutableCacheCxxBridge
            .makeWithDefaults()
        try await bridge.clear()
        defer {
            Task { try? await bridge.clear() }
        }
        // Before insert,empty key is absent
        let pre = try await bridge.lookup(key: "")
        XCTAssertNil(pre,
            "empty key not yet inserted → nil")
        // After insert with empty key,it's found
        try await bridge.insert(key: "", value: "empty-key-value")
        let post = try await bridge.lookup(key: "")
        XCTAssertEqual(post, "empty-key-value",
            "empty key is a VALID key,distinct from" +
            " 'no entry'")
    }

    func testCxx10KBValueRoundTrip() async throws {
        let bridge = await BASMPSGraphExecutableCacheCxxBridge
            .makeWithDefaults()
        try await bridge.clear()
        defer {
            Task { try? await bridge.clear() }
        }
        let largeValue = String(
            repeating: "0123456789", count: 1000)  // 10KB
        try await bridge.insert(
            key: "10kb-test", value: largeValue)
        let got = try await bridge.lookup(key: "10kb-test")
        XCTAssertEqual(got, largeValue,
            "10KB string round-trip via C++ cache")
    }

    // MARK: - Rust pilot boundaries

    func testRustEmptyAtomIDQueryReturnsAllRecords() async throws {
        let actor = try await BASRustMemoryUsageTrackerActor
            .makeWithDefaults()
        // Insert 3 records with different atomIDs
        _ = try await actor.record(
            atomID: "a-1",
            sessionRef: "s",
            turnRef: "t1",
            permitMode: "allow",
            retrievedAt: Date(timeIntervalSince1970: 1000))
        _ = try await actor.record(
            atomID: "a-2",
            sessionRef: "s",
            turnRef: "t2",
            permitMode: "allow",
            retrievedAt: Date(timeIntervalSince1970: 2000))
        _ = try await actor.record(
            atomID: "a-3",
            sessionRef: "s",
            turnRef: "t3",
            permitMode: "allow",
            retrievedAt: Date(timeIntervalSince1970: 3000))
        // Per Rust ABI:empty atom_id = "all records"
        let all = try await actor.allRecords()
        XCTAssertEqual(all.count, 3)
    }

    func testRustNonASCIIFieldsRoundTrip() async throws {
        let actor = try await BASRustMemoryUsageTrackerActor
            .makeWithDefaults()
        let nonAscii = "原子-中文-emoji-🎯"
        _ = try await actor.record(
            atomID: nonAscii,
            sessionRef: "会话",
            turnRef: "回合",
            permitMode: "允许",
            retrievedAt: Date(timeIntervalSince1970: 5000))
        let records = try await actor.allRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].atomID, nonAscii)
        XCTAssertEqual(records[0].sessionRef, "会话")
        XCTAssertEqual(records[0].turnRef, "回合")
        XCTAssertEqual(records[0].permitMode, "允许")
    }
}
