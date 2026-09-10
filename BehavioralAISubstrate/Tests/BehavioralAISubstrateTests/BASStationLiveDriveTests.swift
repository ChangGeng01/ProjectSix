import XCTest
@testable import BASEvaluation

/// P3 真执行门(BAS_STATION_LIVE=1 + BAS_MEASUREMENT_STATION=1):station 全链
/// (Process→swift test→聚合解析→JSONL append→往返)打一个独立迷你包(避免同包 .build 锁)。
final class BASStationLiveDriveTests: XCTestCase {
    func testStationEndToEnd() throws {
        #if os(macOS)
        guard ProcessInfo.processInfo.environment["BAS_STATION_LIVE"] == "1" else {
            throw XCTSkip("set BAS_STATION_LIVE=1 BAS_MEASUREMENT_STATION=1 BAS_STATION_PKG=<dir>")
        }
        guard let pkg = ProcessInfo.processInfo.environment["BAS_STATION_PKG"] else {
            throw XCTSkip("BAS_STATION_PKG missing")
        }
        let ledger = URL(fileURLWithPath: pkg).appendingPathComponent("station_ledger.jsonl")
        let recs = BASSleepMeasurementStation.runIfPermitted(
            manifest: .init(suiteFilters: ["MiniTests"]), windowPermitted: true,
            ledgerURL: ledger, packageDirectory: URL(fileURLWithPath: pkg),
            nowMs: 1_000)
        let unwrapped = try XCTUnwrap(recs, "门全过必须执行")
        XCTAssertEqual(unwrapped.count, 1)
        XCTAssertEqual(unwrapped[0].executedTests, 2, "迷你包 2 用例")
        XCTAssertEqual(unwrapped[0].failures, 0)
        XCTAssertTrue(unwrapped[0].verdictCandidate.hasPrefix("GREEN"))
        let back = BASSleepMeasurementStation.readLedger(ledgerURL: ledger)
        XCTAssertEqual(back.records, unwrapped, "账本行往返 = 晨读验收")
        #else
        throw XCTSkip("macOS station only")
        #endif
    }
}
