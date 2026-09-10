import XCTest

/// audit tests-arch ⑤ — teeth for the wall-clock perf gate. Reversal (make enabled() return true
/// unconditionally / drop the gate in assertBelow) reds testAssertBelowRecordsWhenGateDisabled.
final class BASPerfGateSupportTests: XCTestCase {

    func testEnabledParsing() {
        XCTAssertTrue(BASPerfGate.enabled(["BAS_PERF_GATE": "1"]), "=1 enforces")
        XCTAssertFalse(BASPerfGate.enabled([:]), "unset ⇒ disabled (default: don't enforce timing)")
        XCTAssertFalse(BASPerfGate.enabled(["BAS_PERF_GATE": "0"]), "=0 disabled")
        XCTAssertFalse(BASPerfGate.enabled(["BAS_PERF_GATE": "true"]), "only the literal 1 enables")
    }

    /// With the gate OFF (the default), a value OVER the bound must NOT fail the test — it is only
    /// recorded, so a slow CI run can't false-red. If the ambient env has the gate ON, skip (this
    /// test is about the record-path). Reverting the gate to always-enforce makes this red.
    func testAssertBelowRecordsWhenGateDisabled() throws {
        try XCTSkipUnless(!BASPerfGate.enabled(),
            "this test exercises the gate-OFF record path; skipped when BAS_PERF_GATE=1")
        BASPerfGate.assertBelow(999.0, 1.0, "intentionally-over-bound — must be recorded, not failed")
        // Reaching here without an XCTest failure proves the assertion was suppressed (recorded).
    }
}
