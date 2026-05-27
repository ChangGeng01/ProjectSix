// MARK: - BASRustAtomFilterTests
// 主线 解构 重构 Round 3: Rust pilot now pushes the
// atom-id filter into the existing FFI。 The C function
// `bas_rust_tracker_query(atom_id, ...)` accepts an
// atom_id arg (empty string = all,non-empty = filter)。
// Before this commit Swift only ever passed empty string;
// this round adds `recordsForAtom(atomID:)` that uses
// the filter — pushing the WHERE-like op into Rust。

import XCTest
@testable import BASHostKit
@testable import BASRustCoreBridge

#if !os(iOS)  // ch 1022 source-gate
final class BASRustAtomFilterTests: XCTestCase {

    // MARK: - Direct tracker actor

    func testRecordsForAtomFiltersOnRustSide() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        // Insert 3 records for atom "A", 2 for atom "B"
        for i in 0..<3 {
            _ = try await tracker.record(
                atomID: "A", sessionRef: "S",
                turnRef: String(i), permitMode: "safe")
        }
        for i in 0..<2 {
            _ = try await tracker.record(
                atomID: "B", sessionRef: "S",
                turnRef: String(i + 3), permitMode: "safe")
        }
        let aRecords = try await tracker.recordsForAtom(
            atomID: "A")
        let bRecords = try await tracker.recordsForAtom(
            atomID: "B")
        let missing = try await tracker.recordsForAtom(
            atomID: "no-such-atom")
        XCTAssertEqual(aRecords.count, 3,
            "Filter A → 3 records")
        XCTAssertEqual(bRecords.count, 2,
            "Filter B → 2 records")
        XCTAssertEqual(missing.count, 0,
            "Filter missing atom → 0 records")
        for record in aRecords {
            XCTAssertEqual(record.atomID, "A",
                "Filter must exclude other atoms")
        }
    }

    func testAllRecordsStillReturnsEverything() async throws {
        // Sanity check: passing empty atom_id (which
        // `allRecords()` does under the hood) still
        // returns the full set after the refactor。
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        for i in 0..<5 {
            _ = try await tracker.record(
                atomID: "atom\(i)", sessionRef: "S",
                turnRef: String(i), permitMode: "safe")
        }
        let all = try await tracker.allRecords()
        XCTAssertEqual(all.count, 5,
            "allRecords still returns the full set after" +
            " the atom-filter refactor")
    }

    func testRecordsForAtomEmptyStringReturnsAll()
        async throws
    {
        // The Rust FFI contract: empty atom_id = no filter。
        // Our `allRecords()` relies on this. Pin it。
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        _ = try await tracker.record(
            atomID: "X", sessionRef: "S",
            turnRef: "0", permitMode: "safe")
        _ = try await tracker.record(
            atomID: "Y", sessionRef: "S",
            turnRef: "1", permitMode: "safe")
        let filtered = try await tracker.recordsForAtom(
            atomID: "")
        XCTAssertEqual(filtered.count, 2,
            "Empty atomID == no filter == all records")
    }

    // MARK: - Brain store wrappers

    func testStoreUsageCountViaRust() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let store = BASRustBrainHistoryStore(
            tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(rustHistoryStore: store)
        _ = await brain.summary("repeat")
        _ = await brain.summary("once")
        _ = await brain.summary("repeat")
        _ = await brain.summary("repeat")
        let repeatCount = try await store
            .usageCountViaRust(forInput: "repeat")
        let onceCount = try await store
            .usageCountViaRust(forInput: "once")
        XCTAssertEqual(repeatCount, 3)
        XCTAssertEqual(onceCount, 1)
    }

    func testStoreRecordsForInputViaRust() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let store = BASRustBrainHistoryStore(
            tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(rustHistoryStore: store)
        _ = await brain.summary("target")
        _ = await brain.summary("other")
        _ = await brain.summary("target")
        let records = try await store
            .recordsForInputViaRust(forInput: "target")
        XCTAssertEqual(records.count, 2,
            "Rust-side filter returned 2 target records")
        let targetAtom = BASRustBrainHistoryStore.atomID(
            forInput: "target")
        for record in records {
            XCTAssertEqual(record.atomID, targetAtom,
                "Filter excludes 'other' atom")
        }
    }

    // MARK: - V1 path

    func testV1PathThrows() async throws {
        // V1 path = no Rust handle = throws
        // rustBridgeUnavailableOnPlatform on every call。
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: false)
        do {
            _ = try await tracker.recordsForAtom(
                atomID: "anything")
            XCTFail("V1 path must throw")
        } catch {
            // Expected
            XCTAssertTrue(
                error is BASRustMemoryUsageTrackerActorError)
        }
    }

    // MARK: - Parity: Rust side filter == Swift side filter

    func testRustFilterParityWithSwiftFold() async throws {
        // Run the same data through both paths and
        // verify identical counts。
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        for i in 0..<10 {
            _ = try await tracker.record(
                atomID: (i % 2 == 0) ? "even" : "odd",
                sessionRef: "S",
                turnRef: String(i), permitMode: "safe")
        }
        // Rust-side filter
        let rustEven = try await tracker.recordsForAtom(
            atomID: "even")
        // Swift-side fold (equivalent to old behavior)
        let allRecords = try await tracker.allRecords()
        let swiftEven = allRecords.filter {
            $0.atomID == "even"
        }
        XCTAssertEqual(rustEven.count, 5)
        XCTAssertEqual(swiftEven.count, 5)
        XCTAssertEqual(
            Set(rustEven.map { $0.recordID }),
            Set(swiftEven.map { $0.recordID }),
            "Same set of recordIDs from both paths")
    }
}
#endif
