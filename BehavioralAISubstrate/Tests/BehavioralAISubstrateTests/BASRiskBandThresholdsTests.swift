// Audit ch1040 (C3): pins the risk-band cutoffs after de-duplicating the two copy-pasted
// `..<0.35 / ..<0.60 / ..<0.82` ladders into `BASRiskBandThresholds.band(for:)`. The boundary
// cases prove the shared classifier is byte-equal to the old inline ladders (half-open `..<`:
// the ceiling value itself falls into the NEXT band) and pin the cutoffs against drift.

import XCTest
@testable import BASHostKit
import BASPolicy

final class BASRiskBandThresholdsTests: XCTestCase {

    func testBandClassificationIncludingExactBoundaries() {
        XCTAssertEqual(BASRiskBandThresholds.band(for: 0.0), .low)
        XCTAssertEqual(BASRiskBandThresholds.band(for: 0.349), .low)
        XCTAssertEqual(BASRiskBandThresholds.band(for: 0.35), .medium,
            "half-open `..<0.35`: 0.35 is the FIRST medium")
        XCTAssertEqual(BASRiskBandThresholds.band(for: 0.599), .medium)
        XCTAssertEqual(BASRiskBandThresholds.band(for: 0.60), .high,
            "0.60 is the FIRST high")
        XCTAssertEqual(BASRiskBandThresholds.band(for: 0.819), .high)
        XCTAssertEqual(BASRiskBandThresholds.band(for: 0.82), .extreme,
            "0.82 is the FIRST extreme")
        XCTAssertEqual(BASRiskBandThresholds.band(for: 1.0), .extreme)
    }

    func testCutoffConstantsMatchTheHistoricalLadder() {
        XCTAssertEqual(BASRiskBandThresholds.lowCeiling, 0.35)
        XCTAssertEqual(BASRiskBandThresholds.mediumCeiling, 0.60)
        XCTAssertEqual(BASRiskBandThresholds.highCeiling, 0.82)
    }
}
