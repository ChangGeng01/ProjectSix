import XCTest
import Foundation
@testable import BASMemory

/// audit memory-a F5 — a failed durable write must NOT leave a phantom record in
/// the in-memory cache (cache/disk fork). The tracker now writes disk-then-cache:
/// on an insert failure the cache is untouched.
final class BASMemoryUsageTrackerWriteOrderTests: XCTestCase {

    private var url: URL!
    override func setUpWithError() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("uw-\(UUID().uuidString).sqlite")
    }
    override func tearDownWithError() throws {
        BASMemoryUsageTracker._forceWriteFailureForTesting = false
        for s in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + s))
        }
    }

    func testFailedInsertLeavesNoPhantomInCache() async throws {
        let tracker = try BASMemoryUsageTracker(databaseURL: url)
        _ = try await tracker.record(atomID: "a", sessionRef: "s", turnRef: "t", permitMode: "p")
        let before = await tracker.activeRecordCount
        XCTAssertEqual(before, 1)

        // Force the durable write to fail on the NEXT record.
        BASMemoryUsageTracker._forceWriteFailureForTesting = true
        do {
            _ = try await tracker.record(atomID: "b", sessionRef: "s", turnRef: "t", permitMode: "p")
            XCTFail("a failed durable write must throw")
        } catch { /* expected */ }

        let after = await tracker.activeRecordCount
        XCTAssertEqual(after, 1,
            "a failed insert must NOT add a phantom to the cache — the count stays 1 (no cache/disk fork)")
    }
}
