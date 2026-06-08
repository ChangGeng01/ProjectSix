// ADR-038 §10 — BASMetalGPUProbe instrument-validation tests.
//
// These tests run on a HEALTHY GPU (the macOS CI/dev machine). They validate the probe INSTRUMENT:
// on a working GPU it must report ALL_COMPLETED with a real completion latency. That is the control
// that makes the on-device WEDGED reading meaningful — if the same probe reports WEDGED on a poisoned
// device, the difference isolates Metal-firmware-vs-MLX-bug (the discriminating experiment).
//
// We deliberately do NOT (and cannot) reproduce a real GPU wedge in a unit test — a wedge requires the
// on-device MLX decode path. So these tests pin: (1) healthy GPU → completed; (2) the summary's
// verdict/flag logic over synthetic outcomes (the part that interprets a wedge), which IS unit-testable.

import XCTest
@testable import BASMetalSubstrate

final class BASMetalGPUProbeTests: XCTestCase {

    // MARK: Instrument control — healthy GPU completes

    func testHealthyGPUProbeAllCompleted() throws {
        #if canImport(Metal)
        // On a machine with no Metal device (rare headless CI), the probe reports setupFailed — that is
        // honest, not a test failure; skip the GPU assertion there.
        let summary = BASMetalGPUProbe.runSuite(iterations: 5, timeoutSec: 8.0)
        if summary.setupFailed {
            throw XCTSkip("no usable Metal device on this host — probe setupFailed (honest, not a wedge)")
        }
        XCTAssertEqual(summary.iterations, 5)
        XCTAssertTrue(summary.allCompleted,
                      "healthy GPU must complete every probe iteration; got \(summary.outcomes)")
        XCTAssertEqual(summary.timedOut, 0)
        XCTAssertEqual(summary.errored, 0)
        XCTAssertFalse(summary.anyWedged)
        for o in summary.outcomes {
            XCTAssertEqual(o.status, .completed)
            XCTAssertGreaterThan(o.elapsedMs, 0)
        }
        #else
        throw XCTSkip("Metal not available on this platform")
        #endif
    }

    func testHealthyGPUVerdictLineReadsCompleted() throws {
        #if canImport(Metal)
        let summary = BASMetalGPUProbe.runSuite(iterations: 3, timeoutSec: 8.0)
        if summary.setupFailed { throw XCTSkip("no usable Metal device on this host") }
        let line = summary.verdictLine(context: "unit-test")
        XCTAssertTrue(line.contains("verdict=ALL_COMPLETED"), "got: \(line)")
        XCTAssertTrue(line.contains("MLX-CAUSED"), "healthy verdict must carry the discriminating reading; got: \(line)")
        XCTAssertTrue(line.hasPrefix("📊 ch1025 metal-probe"))
        #else
        throw XCTSkip("Metal not available on this platform")
        #endif
    }

    func testHealthyGPUSessionProbeOnceCompletes() throws {
        #if canImport(Metal)
        guard let session = BASMetalGPUProbeSession.make() else {
            throw XCTSkip("no usable Metal device on this host")
        }
        // Multiple ticks on the SAME long-lived sibling queue all complete on a healthy GPU — this is
        // the instrument the concurrent heartbeat uses during an on-device run.
        for _ in 0..<3 {
            let o = session.probeOnce(timeoutSec: 8.0)
            XCTAssertEqual(o.status, .completed, "healthy session probe must complete; got \(o)")
            XCTAssertGreaterThan(o.elapsedMs, 0)
        }
        #else
        throw XCTSkip("Metal not available on this platform")
        #endif
    }

    // MARK: Summary interpretation logic (synthetic outcomes — the wedge-reading path)

    func testSummaryAllCompletedFlags() {
        let outcomes = (0..<4).map {
            BASMetalGPUProbeOutcome(status: .completed, elapsedMs: Double($0 + 1), detail: "status=completed")
        }
        let s = BASMetalGPUProbeSummary(outcomes: outcomes, setupFailed: false)
        XCTAssertTrue(s.allCompleted)
        XCTAssertFalse(s.anyWedged)
        XCTAssertEqual(s.completed, 4)
        XCTAssertTrue(s.verdictLine(context: "x").contains("verdict=ALL_COMPLETED"))
    }

    func testSummaryWedgedWhenAnyTimedOut() {
        let outcomes = [
            BASMetalGPUProbeOutcome(status: .completed, elapsedMs: 1, detail: ""),
            BASMetalGPUProbeOutcome(status: .timedOut, elapsedMs: 8000, detail: "no completion"),
        ]
        let s = BASMetalGPUProbeSummary(outcomes: outcomes, setupFailed: false)
        XCTAssertFalse(s.allCompleted)
        XCTAssertTrue(s.anyWedged)
        XCTAssertEqual(s.timedOut, 1)
        let line = s.verdictLine(context: "concurrent")
        XCTAssertTrue(line.contains("verdict=WEDGED"), "got: \(line)")
        XCTAssertTrue(line.contains("Apple-driver/firmware"), "wedge verdict must carry the firmware-leaning reading; got: \(line)")
    }

    func testSummaryWedgedWhenErrored() {
        let outcomes = [
            BASMetalGPUProbeOutcome(status: .errored, elapsedMs: 5, detail: "status=error"),
        ]
        let s = BASMetalGPUProbeSummary(outcomes: outcomes, setupFailed: false)
        XCTAssertTrue(s.anyWedged)
        XCTAssertFalse(s.allCompleted)
        XCTAssertTrue(s.verdictLine(context: "x").contains("verdict=WEDGED"))
    }

    func testSummarySetupFailedIsNeitherCompletedNorWedged() {
        let s = BASMetalGPUProbeSummary(outcomes: [], setupFailed: true)
        XCTAssertFalse(s.allCompleted)
        XCTAssertFalse(s.anyWedged)  // setup-failed ≠ a GPU wedge — keep them distinct
        XCTAssertTrue(s.verdictLine(context: "probe-only").contains("verdict=SETUP_FAILED"))
    }
}
