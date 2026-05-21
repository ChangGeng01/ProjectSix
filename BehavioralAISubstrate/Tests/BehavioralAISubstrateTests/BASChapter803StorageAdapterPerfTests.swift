// MARK: - BASChapter803StorageAdapterPerfTests
// chapter 八百三 / M2666-M2670 — storage adapter perf measurement
//
// 5-axis comparison (perf axis 1 only — write throughput) for
// the 6 storage adapter pairs shipped by the v0.59.0 STORAGE
// COMPLETION ARC。 Pure additive test chapter,zero risk to
// existing call sites。 Generates honest numbers to inform any
// future「flip SQLite to default」 decision per the established
// 「亏的不要硬上」 + 「多做比较」 discipline。
//
// ## Expected verdicts (honest plan-agent estimate)
//
// SQLite always loses on raw write throughput vs InMemory because
// it persists to disk + commits a WAL transaction per append。
// The question this chapter answers is HOW MUCH slower — to
// decide whether the durability win justifies the cost for
// production hosts。
//
//   - InMemory append: O(1) array append + dict index = ~100 ns
//   - SQLite append (WAL): prepare/bind/step + fsync = ~10-50 μs
//
// Expected ratio: 100-500× InMemory faster。 The actual numbers
// inform: (a) batch-insert APIs may be worth shipping,(b) hosts
// with strict latency budgets should stick with InMemory + their
// own snapshot strategy。
//
// 5-axis decision rule does NOT apply here because both paths
// stay opt-in;this measurement is informational。

import XCTest
@testable import BASMemory
@testable import BASSovereign

#if os(iOS) || os(macOS)

final class BASChapter803StorageAdapterPerfTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "bas-test-perf-\(UUID().uuidString).sqlite")
    }

    override func tearDown() async throws {
        if let url = tempURL,
           FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        try await super.tearDown()
    }

    // MARK: - L8 atom-lifecycle

    func testL8AtomLifecyclePerf() async throws {
        let inMemory = BASInMemoryAtomLifecycleStore()
        let sqlite = try BASSQLiteAtomLifecycleStore(
            databaseURL: tempURL)
        let iters = 1_000

        let memNs = try await measureAsyncNanos {
            for i in 0..<iters {
                _ = try await inMemory.appendEvent(
                    BASAtomLifecycleEvent(
                        eventID: "mem-\(i)",
                        atomID: "atom",
                        sessionID: "sess",
                        fromPhaseByte: 0,
                        toPhaseByte: 1,
                        actionByte: 0,
                        outcome: 0,
                        recordedAtMs: Int64(i)))
            }
        }
        let sqlNs = try await measureAsyncNanos {
            for i in 0..<iters {
                _ = try await sqlite.appendEvent(
                    BASAtomLifecycleEvent(
                        eventID: "sql-\(i)",
                        atomID: "atom",
                        sessionID: "sess",
                        fromPhaseByte: 0,
                        toPhaseByte: 1,
                        actionByte: 0,
                        outcome: 0,
                        recordedAtMs: Int64(i)))
            }
        }
        printStorageScorecard(
            schema: "023 atom-lifecycle",
            iterations: iters,
            memNs: memNs, sqlNs: sqlNs)
        XCTAssertGreaterThan(memNs, 0)
        XCTAssertGreaterThan(sqlNs, 0)
    }

    // MARK: - L7 unknown ledger

    func testL7UnknownLedgerPerf() async throws {
        let inMemory = BASInMemoryUnknownLedgerStore()
        let sqlite = try BASSQLiteUnknownLedgerStore(
            databaseURL: tempURL)
        let iters = 1_000

        let memNs = try await measureAsyncNanos {
            for i in 0..<iters {
                _ = try await inMemory.appendRecord(
                    BASUnknownLedgerRecord(
                        eventID: "mem-\(i)",
                        sessionID: "sess",
                        turnID: "turn",
                        unknownText: "missing fact \(i)",
                        confidence: 0.8,
                        discoveredAtMs: Int64(i)))
            }
        }
        let sqlNs = try await measureAsyncNanos {
            for i in 0..<iters {
                _ = try await sqlite.appendRecord(
                    BASUnknownLedgerRecord(
                        eventID: "sql-\(i)",
                        sessionID: "sess",
                        turnID: "turn",
                        unknownText: "missing fact \(i)",
                        confidence: 0.8,
                        discoveredAtMs: Int64(i)))
            }
        }
        printStorageScorecard(
            schema: "011 unknown-ledger",
            iterations: iters,
            memNs: memNs, sqlNs: sqlNs)
        XCTAssertGreaterThan(memNs, 0)
        XCTAssertGreaterThan(sqlNs, 0)
    }

    // MARK: - L6 presence observations

    func testL6PresenceObservationsPerf() async throws {
        let inMemory = BASInMemoryPresenceObservationStore()
        let sqlite = try BASSQLitePresenceObservationStore(
            databaseURL: tempURL)
        let iters = 1_000

        let memNs = try await measureAsyncNanos {
            for i in 0..<iters {
                _ = try await inMemory.appendRecord(
                    BASPresenceObservationRecord(
                        eventID: "mem-\(i)",
                        sessionID: "sess",
                        turnID: "turn",
                        channelKind: "task",
                        salience: 0.5,
                        confidence: 0.8,
                        observedAtMs: Int64(i)))
            }
        }
        let sqlNs = try await measureAsyncNanos {
            for i in 0..<iters {
                _ = try await sqlite.appendRecord(
                    BASPresenceObservationRecord(
                        eventID: "sql-\(i)",
                        sessionID: "sess",
                        turnID: "turn",
                        channelKind: "task",
                        salience: 0.5,
                        confidence: 0.8,
                        observedAtMs: Int64(i)))
            }
        }
        printStorageScorecard(
            schema: "013 presence-observations",
            iterations: iters,
            memNs: memNs, sqlNs: sqlNs)
        XCTAssertGreaterThan(memNs, 0)
        XCTAssertGreaterThan(sqlNs, 0)
    }

    // MARK: - L5 version tree (BLOB column case)

    func testL5VersionTreePerf() async throws {
        let inMemory = BASInMemoryHostConstitutionVersionTreeStore()
        let sqlite = try BASSQLiteHostConstitutionVersionTreeStore(
            databaseURL: tempURL)
        // 32 bytes of zero — represents a SHA-256 hash placeholder。
        let placeholderHash = Data(count: 32)
        let iters = 1_000

        let memNs = try await measureAsyncNanos {
            for i in 0..<iters {
                _ = try await inMemory.appendVersion(
                    BASHostConstitutionVersionRecord(
                        versionID: "mem-v\(i)",
                        vaultID: "vault",
                        parentVersionID: nil,
                        createdAtMs: Int64(i),
                        signatureHash: placeholderHash,
                        isRollbackPoint: false,
                        mergedFromJson: nil))
            }
        }
        let sqlNs = try await measureAsyncNanos {
            for i in 0..<iters {
                _ = try await sqlite.appendVersion(
                    BASHostConstitutionVersionRecord(
                        versionID: "sql-v\(i)",
                        vaultID: "vault",
                        parentVersionID: nil,
                        createdAtMs: Int64(i),
                        signatureHash: placeholderHash,
                        isRollbackPoint: false,
                        mergedFromJson: nil))
            }
        }
        printStorageScorecard(
            schema: "014 host-constitution-version-tree",
            iterations: iters,
            memNs: memNs, sqlNs: sqlNs)
        XCTAssertGreaterThan(memNs, 0)
        XCTAssertGreaterThan(sqlNs, 0)
    }

    // MARK: - Async perf helpers

    /// Measure elapsed nanoseconds for an async block。 The block
    /// runs ONCE,not in a loop — caller embeds the iteration
    /// loop inside their body to keep async-bound overhead in
    /// scope。
    private func measureAsyncNanos(
        _ body: () async throws -> Void
    ) async throws -> UInt64 {
        let start = DispatchTime.now().uptimeNanoseconds
        try await body()
        let end = DispatchTime.now().uptimeNanoseconds
        return end - start
    }

    /// Print a scorecard line。 Mirrors `BASCrossLanguagePerfHarness`
    /// shape but adapted for storage InMemory vs SQLite (no
    /// flip-decision verdict — storage measurement is purely
    /// informational since both paths stay opt-in)。
    private func printStorageScorecard(
        schema: String,
        iterations: Int,
        memNs: UInt64,
        sqlNs: UInt64
    ) {
        let memPerIter = memNs / UInt64(iterations)
        let sqlPerIter = sqlNs / UInt64(iterations)
        let ratio = sqlNs > 0
            ? Double(sqlNs) / Double(memNs)
            : 0
        let memMs = Double(memNs) / 1_000_000.0
        let sqlMs = Double(sqlNs) / 1_000_000.0
        print("== STORAGE [\(schema)]: \(iterations) appends")
        print(String(format:
            "   InMemory: %.3f ms total / %d ns/iter",
            memMs, memPerIter))
        print(String(format:
            "   SQLite:   %.3f ms total / %d ns/iter",
            sqlMs, sqlPerIter))
        print(String(format:
            "   Ratio:    SQLite is %.1f× slower than InMemory",
            ratio))
        print("   Verdict:  INFORMATIONAL (both paths opt-in;" +
              " choose per durability vs latency budget)")
    }
}

#endif  // os(iOS) || os(macOS)
