import XCTest
@testable import BASMemory

/// **M599 chapter 一百七十 — memory load rate threshold anti-drift tests**.
///
/// Pin the 2 rate thresholds extracted from `MemoryCore.swift`
/// (chapter 一百六十六 §166.5 backlog item 3 of 5):
/// - `highPendingInfluenceThreshold = 0.34` (≈ 1/3)
/// - `lowTrustLoadThreshold = 0.25` (= 1/4)
///
/// Doctrine: low-trust is MORE concerning than merely-pending,
/// so the low-trust threshold is STRICTER (0.25 < 0.34).
final class M599MemoryLoadRateThresholdTests: XCTestCase {

    /// Pin individual threshold values.
    func testThresholdValuesPinned() {
        XCTAssertEqual(
            BASDecisionBrainState.highPendingInfluenceThreshold,
            0.34)
        XCTAssertEqual(
            BASDecisionBrainState.lowTrustLoadThreshold,
            0.25)
    }

    /// Pin doctrine ordering: low-trust < pending. Low-trust is
    /// stricter (lower threshold = flag fires sooner).
    func testThresholdOrderingPinned() {
        XCTAssertLessThan(
            BASDecisionBrainState.lowTrustLoadThreshold,
            BASDecisionBrainState.highPendingInfluenceThreshold,
            """
            Low-trust threshold (0.25) must be < pending
            threshold (0.34). Doctrine: low-trust sources are
            MORE concerning than merely-pending — flag should
            fire at lower load rate.
            """)
    }

    /// Pin: thresholds in [0, 1] sanity bound.
    func testThresholdsInValidRange() {
        let thresholds = [
            BASDecisionBrainState.highPendingInfluenceThreshold,
            BASDecisionBrainState.lowTrustLoadThreshold,
        ]
        for t in thresholds {
            XCTAssertGreaterThanOrEqual(t, 0.0)
            XCTAssertLessThanOrEqual(t, 1.0)
        }
    }

    /// Pin: thresholds derive from intuitive fractions.
    /// 0.25 = 1/4, 0.34 ≈ 1/3 — these are tier-style fractions
    /// (1/4 + 1/3 + ... fractional family). If anyone changes
    /// to non-intuitive value (e.g. 0.27), this test surfaces it.
    func testThresholdsAreFractionFamily() {
        // 0.25 = exactly 1/4
        XCTAssertEqual(
            BASDecisionBrainState.lowTrustLoadThreshold,
            1.0 / 4.0,
            accuracy: 0.001)
        // 0.34 ≈ 1/3 (within 0.01 tolerance — 1/3 = 0.333...)
        // Pinned at 0.34 to avoid float repetition; doctrine
        // intent is "approximately one-third".
        XCTAssertEqual(
            BASDecisionBrainState.highPendingInfluenceThreshold,
            0.34,
            accuracy: 0.001)
        // Doctrine intent (1/3): within 0.01
        XCTAssertEqual(
            BASDecisionBrainState.highPendingInfluenceThreshold,
            1.0 / 3.0,
            accuracy: 0.01)
    }
}
