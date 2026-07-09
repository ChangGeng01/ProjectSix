import XCTest
@testable import BASEvaluation

/// P3 gates(RSI 章程)——睡眠窗测量站,verdict-only。
/// 验收:三重门(关=nil 零构造)/ 聚合行解析(绝不裸信退出码)/ 账本 append-only +
/// 解析器往返(晨读)。单夜等价 rider 与 7 夜一致率留站启用后验证。
final class BASSleepMeasurementStationTests: XCTestCase {

    private var dir: URL!
    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas_station_test_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)   // 测试自建临时目录
    }

    func testAggregateParsing() {
        let out = """
        Test Suite 'All tests' passed at 2026-07-07.
        \t Executed 42 tests, with 0 failures (0 unexpected) in 1.2 (1.3) seconds
        """
        let a = BASSleepMeasurementStation.parseAggregate(out)
        XCTAssertEqual(a?.tests, 42)
        XCTAssertEqual(a?.failures, 0)
        let f = BASSleepMeasurementStation.parseAggregate(
            "\t Executed 10 tests, with 2 failures (1 unexpected) in 1 (1) seconds")
        XCTAssertEqual(f?.failures, 2)
        XCTAssertNil(BASSleepMeasurementStation.parseAggregate("no aggregate here"),
                     "无聚合行必须 nil——绝不从退出码编造判决")
    }

    func testLedgerAppendAndRoundTrip() throws {
        let url = dir.appendingPathComponent("ledger.jsonl")
        let r1 = BASStationRunRecord(startedAtMs: 100, suiteFilter: "SuiteA", exitCode: 0,
                                     executedTests: 5, failures: 0, durationS: 1.5,
                                     verdictCandidate: "GREEN 5 tests")
        let r2 = BASStationRunRecord(startedAtMs: 200, suiteFilter: "SuiteB", exitCode: 1,
                                     executedTests: 9, failures: 1, durationS: 2.5,
                                     verdictCandidate: "RED 1/9 — triage required")
        try BASSleepMeasurementStation.appendToLedger([r1], ledgerURL: url)
        try BASSleepMeasurementStation.appendToLedger([r2], ledgerURL: url)   // 第二次 append 不重写
        let back = BASSleepMeasurementStation.readLedger(ledgerURL: url)
        XCTAssertEqual(back.records, [r1, r2], "append-only + 往返无损")
        XCTAssertEqual(back.unparseable, 0)
    }

    // audit organ-eval LOW-3: the station's runSuite now surfaces (do/catch + print) a ledger-write
    // failure instead of `try?`-swallowing it. Pin that appendToLedger genuinely throws on a bad path,
    // so that do/catch catches a real error (the surfacing itself is a non-fatal print, inspection-verified).
    func testLedgerAppendThrowsOnUncreatablePath() throws {
        let blocker = FileManager.default.temporaryDirectory
            .appendingPathComponent("blk-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: blocker.path, contents: Data("x".utf8))  // a FILE, not a dir
        defer { try? FileManager.default.removeItem(at: blocker) }
        let badURL = blocker.appendingPathComponent("sub").appendingPathComponent("ledger.jsonl")
        let r = BASStationRunRecord(startedAtMs: 1, suiteFilter: "S", exitCode: 0,
                                    executedTests: 1, failures: 0, durationS: 0.1, verdictCandidate: "G")
        XCTAssertThrowsError(
            try BASSleepMeasurementStation.appendToLedger([r], ledgerURL: badURL),
            "appendToLedger must throw on an uncreatable path — the station now surfaces this, not swallows it")
    }

    func testLedgerSurfacesCorruptLines() throws {
        let url = dir.appendingPathComponent("ledger.jsonl")
        let r = BASStationRunRecord(startedAtMs: 1, suiteFilter: "S", exitCode: 0,
                                    executedTests: 1, failures: 0, durationS: 0.1,
                                    verdictCandidate: "GREEN 1 tests")
        try BASSleepMeasurementStation.appendToLedger([r], ledgerURL: url)
        let h = try FileHandle(forWritingTo: url)
        try h.seekToEnd(); try h.write(contentsOf: Data("corrupt-line{{{\n".utf8)); try h.close()
        let back = BASSleepMeasurementStation.readLedger(ledgerURL: url)
        XCTAssertEqual(back.records.count, 1)
        XCTAssertEqual(back.unparseable, 1, "坏行必须计数暴露,不得静默丢弃")
    }

    #if os(macOS)
    func testGatesReturnNilWithoutOptIn() {
        // 门①:env 未设 ⇒ nil(零构造零执行)。本测试进程未设 BAS_MEASUREMENT_STATION。
        guard !BASSleepMeasurementStation.stationEnabled else {
            return   // 若外层以站开关跑全套件,本门另行人工验证
        }
        let r = BASSleepMeasurementStation.runIfPermitted(
            manifest: .init(suiteFilters: ["X"]), windowPermitted: true,
            ledgerURL: dir.appendingPathComponent("l.jsonl"),
            packageDirectory: dir, nowMs: 1)
        XCTAssertNil(r)
    }
    #endif
}
