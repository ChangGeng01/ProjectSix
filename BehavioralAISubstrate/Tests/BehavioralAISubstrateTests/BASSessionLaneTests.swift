import XCTest
@testable import BASMLXAdapter

/// 案3 gates — the pure session-lane elector, pinned over the exact shape matrix the audit's
/// composition bugs lived in (seam-1/4 class). Bodies stayed certified; this pins WHICH lane
/// every request shape rides.
final class BASSessionLaneTests: XCTestCase {

    private func lane(
        fused: Bool = false, capped: Bool = true, box: Bool = false,
        temp: Double = 0, cap: Int? = 48, weights: Bool = true, est: Int = 30
    ) -> MLXOrganAdapter.BASSessionLane {
        MLXOrganAdapter._sessionLane(
            fusedLaneEnabled: fused, cappedFusedEnabled: capped, hasLiveBox: box,
            temperature: temp, cap: cap, weightsAvailable: weights,
            estTokens: est, fusedMax: 250, cappedMax: 1024)
    }

    func testCappedFusedHappyPath() {
        XCTAssertEqual(lane(), .cappedFusedTranscript(transition: false))
    }

    func testSeamFourShapes_forcePooled() {
        XCTAssertEqual(lane(cap: nil), .pooled, "uncapped must ride pooled (the amnesia shape)")
        XCTAssertEqual(lane(cap: 385), .pooled, "cap>384 must ride pooled")
        XCTAssertEqual(lane(temp: 0.7), .pooled, "sampling must ride pooled")
    }

    func testLiveBoxAlwaysPools() {
        XCTAssertEqual(lane(box: true), .pooled)
        XCTAssertEqual(lane(fused: true, box: true), .pooled)
    }

    func testMissingWeightsPools() {
        XCTAssertEqual(lane(weights: false), .pooled)
        XCTAssertEqual(lane(fused: true, weights: false), .pooled)
    }

    func testHistoryOverflowTransitions() {
        XCTAssertEqual(lane(est: 1024), .cappedFusedTranscript(transition: true))
        XCTAssertEqual(lane(est: 1023), .cappedFusedTranscript(transition: false))
        XCTAssertEqual(lane(fused: true, est: 250), .fusedTranscript(transition: true))
        XCTAssertEqual(lane(fused: true, est: 249), .fusedTranscript(transition: false))
    }

    func testOptInFusedPrecedence() {
        // The opt-in lane ignores the cap and beats capped-fused — the certified guard order.
        XCTAssertEqual(lane(fused: true, cap: nil), .fusedTranscript(transition: false))
        XCTAssertEqual(lane(fused: true, cap: 48), .fusedTranscript(transition: false))
    }

    func testBothLanesOffPools() {
        XCTAssertEqual(lane(fused: false, capped: false), .pooled)
    }
}
