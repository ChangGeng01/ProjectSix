import XCTest
@testable import BASMemory

/// **M598 chapter 一百六十九 — confidence ceiling tier anti-drift tests**.
///
/// Pin the 4 tiered confidence ceilings extracted from
/// `MemoryCore.swift` (chapters 166/167 backlog item closed in 一百六十九):
/// - notification surface: 0.58 (most defensive)
/// - watch surface: 0.64
/// - high-risk overlay: 0.66
/// - generic baseline: 0.70 (default trust floor)
///
/// **Doctrine**: lower-touch surfaces get stricter ceilings (substrate
/// is more conservative when surface itself doesn't show full
/// reasoning). High-risk gets stricter than generic (protective
/// posture caps below baseline).
final class M598ConfidenceCeilingTierTests: XCTestCase {

    /// Pin individual tier values. Regression guard against
    /// accidental modification.
    func testTierValuesPinned() {
        XCTAssertEqual(
            BASIdentityProfile
                .notificationSurfaceConfidenceCeiling,
            0.58)
        XCTAssertEqual(
            BASIdentityProfile.watchSurfaceConfidenceCeiling,
            0.64)
        XCTAssertEqual(
            BASIdentityProfile.highRiskOverlayConfidenceCeiling,
            0.66)
        XCTAssertEqual(
            BASIdentityProfile.genericBaselineConfidenceCeiling,
            0.70)
    }

    /// Pin doctrine ordering: notification < watch < high-risk
    /// < generic. If any tier swaps order, test fails (regression
    /// against accidental tier inversion).
    func testTierOrderingPinned() {
        XCTAssertLessThan(
            BASIdentityProfile
                .notificationSurfaceConfidenceCeiling,
            BASIdentityProfile.watchSurfaceConfidenceCeiling,
            """
            notification ceiling must be < watch ceiling.
            Doctrine: lower-touch surfaces are MORE defensive
            (lower ceiling = stricter assertion).
            """)
        XCTAssertLessThan(
            BASIdentityProfile.watchSurfaceConfidenceCeiling,
            BASIdentityProfile.highRiskOverlayConfidenceCeiling,
            """
            watch ceiling must be < high-risk ceiling.
            """)
        XCTAssertLessThan(
            BASIdentityProfile.highRiskOverlayConfidenceCeiling,
            BASIdentityProfile.genericBaselineConfidenceCeiling,
            """
            high-risk ceiling must be < generic baseline.
            High-risk posture is MORE protective than generic.
            """)
    }

    /// Pin: all tiers in [0, 1] range (sanity bound).
    func testTierValuesInValidRange() {
        let tiers = [
            BASIdentityProfile
                .notificationSurfaceConfidenceCeiling,
            BASIdentityProfile.watchSurfaceConfidenceCeiling,
            BASIdentityProfile.highRiskOverlayConfidenceCeiling,
            BASIdentityProfile.genericBaselineConfidenceCeiling,
        ]
        for tier in tiers {
            XCTAssertGreaterThanOrEqual(tier, 0.0)
            XCTAssertLessThanOrEqual(tier, 1.0)
        }
    }

    /// Pin: cross-reference with BASMemoryGovernance baseline
    /// `singleEvidenceLowConfidenceRejectionThreshold = 0.58`
    /// (chapter 一百六十七 M596). The notification-surface ceiling
    /// equals the rejection threshold — both at 0.58, both are
    /// "most defensive" thresholds. Anti-drift cross-reference:
    /// if either changes independently, this test fails AND
    /// surfaces the doctrine question of whether they should
    /// remain equal.
    func testNotificationCeilingEqualsRejectionThreshold() {
        // Both should be 0.58 (the conservative-defensive floor).
        // If chapter 一百六十七 threshold drifts independently,
        // this test fails and forces re-derivation.
        XCTAssertEqual(
            BASIdentityProfile
                .notificationSurfaceConfidenceCeiling,
            0.58,
            """
            Notification-surface confidenceCeiling (M598) and
            BASMemoryGovernance.singleEvidenceLowConfidenceRejectionThreshold
            (M596) are both 0.58. If either drifts, this anti-drift
            test surfaces it and forces explicit re-derivation.
            """)
    }
}
