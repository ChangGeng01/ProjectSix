import XCTest
@testable import BASMLXAdapter

/// 案5 gates — the pressure ladder's pure hysteresis machine. Thresholds are fractions of the
/// RESOLVED cap (缝7); rungs latch on fire and re-arm only a full band above their threshold
/// (anti-thrash — the U1 design's spill-storm failure mode).
final class BASPressureLadderTests: XCTestCase {

    private func ladder(cap: Int = 1000) -> BASPressureLadder {
        BASPressureLadder(config: .init(capBytes: cap))    // thresholds: 150/100/50, band 50
    }

    // MARK: - audit mlx-adapter-core MED-6 — the deepest rung subsumes milder actions

    func testClearAllSessionsSubsumesDropSpecDecoder() {
        // THE fix: firing rung 3 (clearAllSessions) must ALSO execute rung 2's decoder drop —
        // clearAllSessions latched it too, but the old deepest-only switch left the ~300MB
        // decoder resident.
        let actions = BASPressureLadder.reclaimActions(forDeepest: .clearAllSessions)
        XCTAssertTrue(actions.contains(.dropSpecDecoder),
            "a rung-3 collapse must also drop the spec decoder (rung 2), not leave it resident")
        XCTAssertTrue(actions.contains(.clearAllSessions))
    }

    func testDropSpecDecoderSubsumesParkColdSeats() {
        let actions = BASPressureLadder.reclaimActions(forDeepest: .dropSpecDecoder)
        XCTAssertTrue(actions.contains(.parkColdSeats), "rung 2 also parked cold seats (rung 1)")
        XCTAssertTrue(actions.contains(.dropSpecDecoder))
    }

    func testParkColdSeatsIsJustItself() {
        XCTAssertEqual(BASPressureLadder.reclaimActions(forDeepest: .parkColdSeats), [.parkColdSeats])
    }

    func testGradualDescentFiresRungsInOrder() {
        var l = ladder()
        XCTAssertNil(l.advise(headroomBytes: 400).fired, "plenty of headroom must be a no-op")
        XCTAssertEqual(l.advise(headroomBytes: 140).fired, .parkColdSeats)
        XCTAssertNil(l.advise(headroomBytes: 130).fired, "rung 1 latched — no refire")
        XCTAssertEqual(l.advise(headroomBytes: 90).fired, .dropSpecDecoder)
        XCTAssertEqual(l.advise(headroomBytes: 40).fired, .clearAllSessions)
        XCTAssertNil(l.advise(headroomBytes: 30).fired, "all latched")
        XCTAssertEqual(l.firedHistory, [.parkColdSeats, .dropSpecDecoder, .clearAllSessions])
    }

    func testCollapseFiresWorstRungFirst() {
        var l = ladder()
        // memory falls straight through every threshold — act at the SEVERE rung (its actuator
        // subsumes the milder ones); the milder rungs latch too (no pointless follow-up fires).
        XCTAssertEqual(l.advise(headroomBytes: 30).fired, .clearAllSessions)
        XCTAssertNil(l.advise(headroomBytes: 25).fired)
    }

    func testRearmNeedsFullBandAboveThreshold() {
        var l = ladder()
        XCTAssertEqual(l.advise(headroomBytes: 140).fired, .parkColdSeats)
        XCTAssertNil(l.advise(headroomBytes: 160).fired, "inside the re-arm band — still latched")
        XCTAssertNil(l.advise(headroomBytes: 210).fired, "recovery above threshold+band re-arms silently")
        XCTAssertEqual(l.advise(headroomBytes: 140).fired, .parkColdSeats,
                       "re-armed rung fires again on the next descent")
    }

    func testZeroAndNegativeHeadroomClampSafely() {
        var l = ladder()
        XCTAssertEqual(l.advise(headroomBytes: 0).fired, .clearAllSessions)
        var l2 = ladder()
        XCTAssertEqual(l2.advise(headroomBytes: -5).fired, .clearAllSessions)
    }

    // MARK: - audit mlx-adapter-core MED-11 — recovery re-arm is REPORTED (not a ratchet)

    func testRearmEventIsReportedForCacheLimitRestore() {
        var l = ladder()
        // Straight collapse latches rung 3 (and the milder rungs).
        XCTAssertEqual(l.advise(headroomBytes: 30).fired, .clearAllSessions)
        // Full recovery: headroom rises a band above rung 3's threshold (50) + band (50) = 100.
        let recovered = l.advise(headroomBytes: 210)
        XCTAssertNil(recovered.fired, "recovery fires nothing new…")
        XCTAssertTrue(recovered.rearmed.contains(.clearAllSessions),
            "…but the rung-3 RE-ARM must be reported so the adapter can RESTORE the clamped cacheLimit")
    }

    func testMacWiringIsInert() async {
        // Off-iOS the headroom probe is nil ⇒ the adapter's _pressureCheck must be a no-op even
        // when armed (the ladder is a device lever; Mac tests stay deterministic).
        #if !os(iOS)
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        await adapter._pressureCheck(keeping: nil)
        let fired = await adapter.pressureLadderTelemetry()
        XCTAssertTrue(fired.isEmpty)
        #endif
    }
}
