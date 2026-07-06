import XCTest
import BASSovereign
@testable import BASHostKit

/// 触发器①落地 gates — the per-turn honesty line (the honesty observation's first NAMED
/// consumer). Pure: lexicon-applicability detector + n/a(zh) rendering + old-JSON compat.
/// Env-gated (run under BAS_HONESTY_OBSERVE=1): the coordinator auto-installs the log-line
/// sink when the host provides none — the opt-in flip that fires trigger ①.
final class BASHonestyTurnLogTests: XCTestCase {

    // MARK: - lexicon applicability (the anti-false-green guard)

    func testEnglishBodyIsApplicable() {
        XCTAssertTrue(BASModelHonestySignal.lexiconApplicable(
            to: "That is genuinely impressive work — the results speak for themselves."))
    }

    func testChineseBodyIsNotApplicable() {
        XCTAssertFalse(BASModelHonestySignal.lexiconApplicable(
            to: "这个想法非常出色,你完全是个天才,绝对是有史以来最好的方案。"),
            "a CJK-dominant flattery bomb must NOT be readable by English lexicons")
    }

    func testMixedBodyThreshold() {
        // Mostly-English with a few CJK tokens stays applicable…
        XCTAssertTrue(BASModelHonestySignal.lexiconApplicable(
            to: "The plan (计划) looks reasonable and the numbers check out across the board."))
        // …mostly-Chinese with a few English tokens does not.
        XCTAssertFalse(BASModelHonestySignal.lexiconApplicable(
            to: "方案没问题,数字也对得上,OK 的。"))
    }

    func testEmptyOrSymbolicBodyDefaultsApplicable() {
        XCTAssertTrue(BASModelHonestySignal.lexiconApplicable(to: ""))
        XCTAssertTrue(BASModelHonestySignal.lexiconApplicable(to: "1234 !!! ---"))
    }

    // MARK: - the 🪞 line

    func testSummaryLineRendersBands() {
        let r = BASModelHonestyObservationRecord(
            eventID: "s#t#model-honesty", sessionID: "s", turnID: "t",
            axes: BASModelHonestySignal.axes("You are absolutely a genius, the best ever."),
            observedAtMs: 0)
        XCTAssertTrue(r.summaryLine.hasPrefix("🪞 honesty id=s#t "))
        XCTAssertFalse(r.summaryLine.contains("n/a(zh)"))
        XCTAssertTrue(r.summaryLine.contains("flattery="))
    }

    func testSummaryLineRendersNAOnChineseTurns() {
        let r = BASModelHonestyObservationRecord(
            eventID: "s#t#model-honesty", sessionID: "s", turnID: "t",
            axes: BASModelHonestySignal.axes("你真是天才"),   // axes are vacuously 0 here
            observedAtMs: 0, lexiconApplicable: false)
        let line = r.summaryLine
        XCTAssertEqual(line.components(separatedBy: "n/a(zh)").count - 1, 3,
                       "ALL THREE axes must render n/a(zh) — never a false-green band: \(line)")
    }

    func testOldJSONDecodesApplicableTrue() throws {
        let r = BASModelHonestyObservationRecord(
            eventID: "e", sessionID: "s", turnID: "t",
            axes: BASModelHonestySignal.axes("fine"), observedAtMs: 1)
        var obj = try XCTUnwrap(try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(r)) as? [String: Any])
        obj.removeValue(forKey: "lexiconApplicable")          // simulate a pre-flag record
        let old = try JSONDecoder().decode(
            BASModelHonestyObservationRecord.self,
            from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertTrue(old.lexiconApplicable)
    }

    // MARK: - the auto-installed consumer (run under BAS_HONESTY_OBSERVE=1)

    func testEnvArmsTheDefaultLogSink() throws {
        guard ProcessInfo.processInfo.environment["BAS_HONESTY_OBSERVE"] == "1" else {
            throw XCTSkip("run under BAS_HONESTY_OBSERVE=1 — the opt-in that fires trigger ①")
        }
        let coord = BASCoordinatorTestStubs.makeStub()
        XCTAssertNotNil(coord.modelHonestyObservationSink,
                        "env opt-in must auto-install the log-line consumer")
        _ = coord.runTurn(BASCoordinatorTestStubs.makeStubRequest())   // prints one 🪞 line
    }

    func testNoEnvMeansNilSink() throws {
        guard ProcessInfo.processInfo.environment["BAS_HONESTY_OBSERVE"] != "1" else {
            throw XCTSkip("plain-env variant")
        }
        let coord = BASCoordinatorTestStubs.makeStub()
        XCTAssertNil(coord.modelHonestyObservationSink,
                     "without opt-in the lane stays dark (nothing computed — byte-equal)")
    }
}
