import XCTest
@testable import BASMemory

/// chapter 二百五十一 / M738 — `BASMemoryUsageTracker` coverage.
///
/// Stage 1 Step 1 of 3 (Memory Importance Loop). The tracker is
/// the typed primitive that turns "L8 had a recall event" into
/// queryable history the importance scorer (chapter 二百五十二)
/// reads + L8 retrieval (chapter 二百五十三) wires.
///
/// Two modes covered:
///
///   - In-memory (`BASMemoryUsageTracker()`) — actor-resident only.
///   - SQLite-backed (`init(databaseURL:)`) — cross-session via
///     the chapter 二百四十八 idiom.
final class BASMemoryUsageTrackerTests: XCTestCase {

    // MARK: - Fixtures

    private var tempURL: URL!

    override func setUpWithError() throws {
        tempURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "qinao-memory-usage-test-\(UUID().uuidString).sqlite")
    }

    override func tearDownWithError() throws {
        if let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-wal"))
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-shm"))
        }
    }

    // MARK: - 1. In-memory empty start

    func testInMemoryEmptyStart() async throws {
        let tracker = BASMemoryUsageTracker()
        let count = await tracker.recordCount
        XCTAssertEqual(count, 0)
    }

    // MARK: - 2. record returns recordID + populates store

    func testRecordReturnsIDAndPersists() async throws {
        let tracker = BASMemoryUsageTracker()
        let recordID = try await tracker.record(
            atomID: "atom-1",
            sessionRef: "sess-1",
            turnRef: "turn-1",
            permitMode: "answer")
        XCTAssertFalse(recordID.isEmpty)
        let count = await tracker.recordCount
        XCTAssertEqual(count, 1)
        let usage = await tracker.usageCount(forAtomID: "atom-1")
        XCTAssertEqual(usage, 1)
    }

    // MARK: - 3. Multiple records per atom counted correctly

    func testMultipleRecordsPerAtomCounted() async throws {
        let tracker = BASMemoryUsageTracker()
        for _ in 0..<5 {
            _ = try await tracker.record(
                atomID: "atom-hot",
                sessionRef: "sess",
                turnRef: "turn",
                permitMode: "answer")
        }
        _ = try await tracker.record(
            atomID: "atom-cold",
            sessionRef: "sess",
            turnRef: "turn",
            permitMode: "answer")
        let hotCount = await tracker.usageCount(forAtomID: "atom-hot")
        XCTAssertEqual(hotCount, 5)
        let coldCount = await tracker.usageCount(
            forAtomID: "atom-cold")
        XCTAssertEqual(coldCount, 1)
    }

    // MARK: - 4. markHelped flips state

    func testMarkHelpedTransitionsState() async throws {
        let tracker = BASMemoryUsageTracker()
        let recordID = try await tracker.record(
            atomID: "atom-1",
            sessionRef: "sess",
            turnRef: "turn",
            permitMode: "answer")
        var record = await tracker.record(forID: recordID)
        XCTAssertEqual(record?.helpedFlag, .unknown)

        try await tracker.markHelped(
            recordID: recordID, helped: true)
        record = await tracker.record(forID: recordID)
        XCTAssertEqual(record?.helpedFlag, .helped)

        try await tracker.markHelped(
            recordID: recordID, helped: false)
        record = await tracker.record(forID: recordID)
        XCTAssertEqual(record?.helpedFlag, .notHelped)
    }

    // MARK: - 5. markHelped on missing record throws

    func testMarkHelpedOnMissingThrows() async throws {
        let tracker = BASMemoryUsageTracker()
        do {
            try await tracker.markHelped(
                recordID: "no-such-id", helped: true)
            XCTFail("expected unknownRecord error")
        } catch
            BASMemoryUsageTracker.TrackerError.unknownRecord(let id)
        {
            XCTAssertEqual(id, "no-such-id")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - 6. recentRecords returns descending by retrievedAt

    func testRecentRecordsSortedDescending() async throws {
        let tracker = BASMemoryUsageTracker()
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let t1 = Date(timeIntervalSince1970: 1_700_000_100)
        let t2 = Date(timeIntervalSince1970: 1_700_000_200)
        _ = try await tracker.record(
            atomID: "atom-1",
            sessionRef: "s", turnRef: "t",
            permitMode: "answer", retrievedAt: t0)
        _ = try await tracker.record(
            atomID: "atom-1",
            sessionRef: "s", turnRef: "t",
            permitMode: "answer", retrievedAt: t1)
        _ = try await tracker.record(
            atomID: "atom-1",
            sessionRef: "s", turnRef: "t",
            permitMode: "answer", retrievedAt: t2)

        let recent = await tracker.recentRecords(
            forAtomID: "atom-1", limit: 10)
        XCTAssertEqual(
            recent.map { $0.retrievedAt },
            [t2, t1, t0])
    }

    // MARK: - 7. recentRecords respects limit

    func testRecentRecordsRespectsLimit() async throws {
        let tracker = BASMemoryUsageTracker()
        for i in 0..<10 {
            _ = try await tracker.record(
                atomID: "atom-1",
                sessionRef: "s", turnRef: "t",
                permitMode: "answer",
                retrievedAt: Date(
                    timeIntervalSince1970: Double(1_700_000_000 + i)))
        }
        let recent = await tracker.recentRecords(
            forAtomID: "atom-1", limit: 3)
        XCTAssertEqual(recent.count, 3)
    }

    // MARK: - 8. allRecords sorted ascending

    func testAllRecordsSortedAscending() async throws {
        let tracker = BASMemoryUsageTracker()
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let t1 = Date(timeIntervalSince1970: 1_700_000_100)
        _ = try await tracker.record(
            atomID: "atom-1",
            sessionRef: "s", turnRef: "t1",
            permitMode: "answer", retrievedAt: t1)
        _ = try await tracker.record(
            atomID: "atom-2",
            sessionRef: "s", turnRef: "t0",
            permitMode: "answer", retrievedAt: t0)

        let all = await tracker.allRecords()
        XCTAssertEqual(
            all.map { $0.retrievedAt }, [t0, t1])
    }

    // MARK: - 9. purge removes records older than cutoff

    func testPurgeOlderThanRemovesStaleRecords() async throws {
        let tracker = BASMemoryUsageTracker()
        let cutoff = Date(timeIntervalSince1970: 1_700_000_500)
        // 2 stale (before cutoff)
        _ = try await tracker.record(
            atomID: "atom-stale",
            sessionRef: "s", turnRef: "t",
            permitMode: "answer",
            retrievedAt: Date(
                timeIntervalSince1970: 1_700_000_100))
        _ = try await tracker.record(
            atomID: "atom-stale",
            sessionRef: "s", turnRef: "t",
            permitMode: "answer",
            retrievedAt: Date(
                timeIntervalSince1970: 1_700_000_200))
        // 1 fresh
        _ = try await tracker.record(
            atomID: "atom-fresh",
            sessionRef: "s", turnRef: "t",
            permitMode: "answer",
            retrievedAt: Date(
                timeIntervalSince1970: 1_700_000_900))

        let removed = try await tracker.purge(olderThan: cutoff)
        XCTAssertEqual(removed, 2)

        let count = await tracker.recordCount
        XCTAssertEqual(count, 1)
        let staleAfter = await tracker.usageCount(
            forAtomID: "atom-stale")
        XCTAssertEqual(staleAfter, 0)
        let freshAfter = await tracker.usageCount(
            forAtomID: "atom-fresh")
        XCTAssertEqual(freshAfter, 1)
    }

    // MARK: - 10. SQLite mode round-trip via reopen

    /// THE KEY TEST for SQLite mode — close → reopen → records
    /// reloaded byte-for-byte. Mirrors chapter 二百四十八's
    /// memory-atom cross-session pattern.
    func testSQLiteCrossSessionPersistence() async throws {
        // Session 1 — write + close
        do {
            let tracker = try BASMemoryUsageTracker(
                databaseURL: tempURL)
            _ = try await tracker.record(
                atomID: "atom-A",
                sessionRef: "s",
                turnRef: "t",
                permitMode: "answer",
                retrievedAt: Date(
                    timeIntervalSince1970: 1_700_000_000))
            _ = try await tracker.record(
                atomID: "atom-B",
                sessionRef: "s",
                turnRef: "t",
                permitMode: "delay",
                retrievedAt: Date(
                    timeIntervalSince1970: 1_700_000_100))
            let count1 = await tracker.recordCount
            XCTAssertEqual(count1, 2)
        }

        // Session 2 — reopen + verify
        let tracker2 = try BASMemoryUsageTracker(
            databaseURL: tempURL)
        let count2 = await tracker2.recordCount
        XCTAssertEqual(count2, 2)
        let allReloaded = await tracker2.allRecords()
        XCTAssertEqual(
            allReloaded.map { $0.atomID },
            ["atom-A", "atom-B"])
        XCTAssertEqual(allReloaded[0].permitMode, "answer")
        XCTAssertEqual(allReloaded[1].permitMode, "delay")
    }

    // MARK: - 11. SQLite markHelped survives reopen

    func testSQLiteMarkHelpedSurvivesReopen() async throws {
        let recordID: String
        do {
            let tracker = try BASMemoryUsageTracker(
                databaseURL: tempURL)
            recordID = try await tracker.record(
                atomID: "atom-1",
                sessionRef: "s",
                turnRef: "t",
                permitMode: "answer")
            try await tracker.markHelped(
                recordID: recordID, helped: true)
        }

        let tracker2 = try BASMemoryUsageTracker(
            databaseURL: tempURL)
        let record = await tracker2.record(forID: recordID)
        XCTAssertEqual(record?.helpedFlag, .helped)
    }

    // MARK: - 12. SQLite purge survives reopen

    func testSQLitePurgeSurvivesReopen() async throws {
        let cutoff = Date(timeIntervalSince1970: 1_700_000_500)
        do {
            let tracker = try BASMemoryUsageTracker(
                databaseURL: tempURL)
            _ = try await tracker.record(
                atomID: "atom-stale",
                sessionRef: "s", turnRef: "t",
                permitMode: "answer",
                retrievedAt: Date(
                    timeIntervalSince1970: 1_700_000_100))
            _ = try await tracker.record(
                atomID: "atom-fresh",
                sessionRef: "s", turnRef: "t",
                permitMode: "answer",
                retrievedAt: Date(
                    timeIntervalSince1970: 1_700_000_900))
            _ = try await tracker.purge(olderThan: cutoff)
        }

        let tracker2 = try BASMemoryUsageTracker(
            databaseURL: tempURL)
        let count = await tracker2.recordCount
        XCTAssertEqual(count, 1)
        let stale = await tracker2.usageCount(
            forAtomID: "atom-stale")
        XCTAssertEqual(stale, 0)
        let fresh = await tracker2.usageCount(
            forAtomID: "atom-fresh")
        XCTAssertEqual(fresh, 1)
    }

    // MARK: - 13. Schema version + record schema version pin

    func testSchemaVersionsPinned() {
        XCTAssertEqual(
            BASMemoryUsageTracker.schemaVersion, 1)
        XCTAssertEqual(
            BASMemoryUsageRecord.currentSchemaVersion, "1.0.0")
    }

    // MARK: - 14. HelpedFlag exhaustiveness

    func testHelpedFlagCases() {
        let cases: [BASMemoryUsageRecord.HelpedFlag] = [
            .unknown, .helped, .notHelped
        ]
        XCTAssertEqual(cases.count, 3)
        XCTAssertEqual(
            BASMemoryUsageRecord.HelpedFlag(
                rawValue: "unknown"),
            .unknown)
        XCTAssertEqual(
            BASMemoryUsageRecord.HelpedFlag(
                rawValue: "helped"),
            .helped)
        XCTAssertEqual(
            BASMemoryUsageRecord.HelpedFlag(
                rawValue: "notHelped"),
            .notHelped)
    }
}
