import XCTest
@testable import BASPolicy

/// chapter 二百六十三 / M746 — `BASRiskCalibrationBundle` +
/// `BASRiskCalibrationStratumDelta` typed-value coverage.
///
/// 附录 V Stage 4 Step 3 of 5. The bundle is the typed payload of
/// the ADR-012 Hybrid offline-pipeline. This suite verifies:
///
///   1. Schema versions pinned + Codable round-trip stable
///   2. Delta clamps to ±0.25 (defensive against operator typos)
///   3. NaN deltas resolved to 0 (defense against bad operator
///      input)
///   4. Bundle de-duplicates same-stratum deltas (last-wins)
///   5. `isWellFormed` enforces non-empty version + provenance +
///      warrant
///   6. Baseline sentinel has expected shape
///   7. `delta(forStratumKey:)` lookup
///   8. `totalEvidenceRowCount` aggregates correctly
///   9. `changingStrata` filters zero-delta strata
final class BASRiskCalibrationBundleTests: XCTestCase {

    // MARK: - 1. Schema versions pinned

    func testSchemaVersionsPinned() {
        XCTAssertEqual(
            BASRiskCalibrationBundle.currentSchemaVersion,
            "1.0.0")
        XCTAssertEqual(
            BASRiskCalibrationStratumDelta.currentSchemaVersion,
            "1.0.0")
    }

    // MARK: - 2. Delta clamp to ±maximumAbsoluteDelta

    func testDeltaClampsToMaximum() {
        let delta = BASRiskCalibrationStratumDelta(
            stratumKey: "tone=angry",
            mediumThresholdDelta: 5.0,
            highThresholdDelta: -3.0,
            extremeThresholdDelta: 0.1)
        XCTAssertEqual(
            delta.mediumThresholdDelta,
            BASRiskCalibrationStratumDelta.maximumAbsoluteDelta)
        XCTAssertEqual(
            delta.highThresholdDelta,
            -BASRiskCalibrationStratumDelta.maximumAbsoluteDelta)
        XCTAssertEqual(
            delta.extremeThresholdDelta, 0.1)
    }

    // MARK: - 3. NaN deltas resolved to 0

    func testNaNDeltasResolveToZero() {
        let delta = BASRiskCalibrationStratumDelta(
            stratumKey: "tone=angry",
            mediumThresholdDelta: .nan,
            highThresholdDelta: .nan,
            extremeThresholdDelta: .nan)
        XCTAssertEqual(delta.mediumThresholdDelta, 0)
        XCTAssertEqual(delta.highThresholdDelta, 0)
        XCTAssertEqual(delta.extremeThresholdDelta, 0)
    }

    // MARK: - 4. Bundle de-duplicates same-stratum (last-wins)

    func testBundleDeduplicatesSameStratumLastWins() {
        let v1 = BASRiskCalibrationStratumDelta(
            stratumKey: "tone=angry|stake=high",
            mediumThresholdDelta: 0.05,
            evidenceRowCount: 100)
        let v2 = BASRiskCalibrationStratumDelta(
            stratumKey: "tone=angry|stake=high",
            mediumThresholdDelta: 0.10,
            evidenceRowCount: 200)
        let other = BASRiskCalibrationStratumDelta(
            stratumKey: "tone=calm|stake=low",
            mediumThresholdDelta: 0.02,
            evidenceRowCount: 50)
        let bundle = BASRiskCalibrationBundle(
            bundleVersion: "v0.1.0",
            aggregateProvenanceRef: "test:input",
            strataDeltas: [v1, other, v2],
            sovereignWarrantRef: "warrant:test")
        XCTAssertEqual(bundle.strataDeltas.count, 2)
        let angry = bundle.delta(
            forStratumKey: "tone=angry|stake=high")
        XCTAssertEqual(angry?.mediumThresholdDelta, 0.10)
        XCTAssertEqual(angry?.evidenceRowCount, 200)
    }

    // MARK: - 5. isWellFormed enforces required fields

    func testIsWellFormedRequiresNonEmptyFields() {
        let good = BASRiskCalibrationBundle(
            bundleVersion: "v1.0.0",
            aggregateProvenanceRef: "agg:test",
            sovereignWarrantRef: "warrant:test")
        XCTAssertTrue(good.isWellFormed)

        let emptyVersion = BASRiskCalibrationBundle(
            bundleVersion: "",
            aggregateProvenanceRef: "agg:test",
            sovereignWarrantRef: "warrant:test")
        XCTAssertFalse(emptyVersion.isWellFormed)

        let baselineVersion = BASRiskCalibrationBundle(
            bundleVersion:
                BASRiskCalibrationBundle.baselineVersion,
            aggregateProvenanceRef: "agg:test",
            sovereignWarrantRef: "warrant:test")
        XCTAssertFalse(baselineVersion.isWellFormed)

        let emptyProvenance = BASRiskCalibrationBundle(
            bundleVersion: "v1.0.0",
            aggregateProvenanceRef: "",
            sovereignWarrantRef: "warrant:test")
        XCTAssertFalse(emptyProvenance.isWellFormed)

        let emptyWarrant = BASRiskCalibrationBundle(
            bundleVersion: "v1.0.0",
            aggregateProvenanceRef: "agg:test",
            sovereignWarrantRef: "")
        XCTAssertFalse(emptyWarrant.isWellFormed)
    }

    // MARK: - 6. Baseline sentinel has expected shape

    func testBaselineSentinelShape() {
        let b = BASRiskCalibrationBundle.baseline
        XCTAssertEqual(
            b.bundleVersion,
            BASRiskCalibrationBundle.baselineVersion)
        XCTAssertEqual(b.strataDeltas.count, 0)
        XCTAssertFalse(b.isWellFormed)  // baseline is special
    }

    // MARK: - 7. delta(forStratumKey:) lookup

    func testDeltaLookupByStratumKey() {
        let d1 = BASRiskCalibrationStratumDelta(
            stratumKey: "tone=angry",
            mediumThresholdDelta: 0.1)
        let d2 = BASRiskCalibrationStratumDelta(
            stratumKey: "tone=calm",
            mediumThresholdDelta: 0.0)
        let bundle = BASRiskCalibrationBundle(
            bundleVersion: "v1.0.0",
            aggregateProvenanceRef: "agg:test",
            strataDeltas: [d1, d2],
            sovereignWarrantRef: "warrant:test")
        XCTAssertEqual(
            bundle.delta(forStratumKey: "tone=angry")?
                .mediumThresholdDelta,
            0.1)
        XCTAssertNotNil(
            bundle.delta(forStratumKey: "tone=calm"))
        XCTAssertNil(
            bundle.delta(forStratumKey: "tone=missing"))
    }

    // MARK: - 8. totalEvidenceRowCount aggregates

    func testTotalEvidenceRowCountAggregates() {
        let bundle = BASRiskCalibrationBundle(
            bundleVersion: "v1.0.0",
            aggregateProvenanceRef: "agg:test",
            strataDeltas: [
                BASRiskCalibrationStratumDelta(
                    stratumKey: "a", evidenceRowCount: 100),
                BASRiskCalibrationStratumDelta(
                    stratumKey: "b", evidenceRowCount: 50),
                BASRiskCalibrationStratumDelta(
                    stratumKey: "c", evidenceRowCount: 0),
            ],
            sovereignWarrantRef: "warrant:test")
        XCTAssertEqual(bundle.totalEvidenceRowCount, 150)
    }

    // MARK: - 9. changingStrata filters zero-delta

    func testChangingStrataFiltersZeroDelta() {
        let withChange = BASRiskCalibrationStratumDelta(
            stratumKey: "tone=angry",
            mediumThresholdDelta: 0.05)
        let zeroDelta = BASRiskCalibrationStratumDelta(
            stratumKey: "tone=calm",
            mediumThresholdDelta: 0)
        let bundle = BASRiskCalibrationBundle(
            bundleVersion: "v1.0.0",
            aggregateProvenanceRef: "agg:test",
            strataDeltas: [withChange, zeroDelta],
            sovereignWarrantRef: "warrant:test")
        XCTAssertEqual(bundle.changingStrata.count, 1)
        XCTAssertEqual(
            bundle.changingStrata.first?.stratumKey,
            "tone=angry")
    }

    // MARK: - 10. Codable round-trip preserves all fields

    func testBundleCodableRoundTrip() throws {
        let original = BASRiskCalibrationBundle(
            bundleVersion: "v1.2.3",
            producedAt: Date(timeIntervalSince1970: 1_700_000_000),
            aggregateProvenanceRef: "agg:test:abc123",
            strataDeltas: [
                BASRiskCalibrationStratumDelta(
                    stratumKey: "tone=angry|stake=high",
                    mediumThresholdDelta: 0.05,
                    highThresholdDelta: 0.10,
                    extremeThresholdDelta: 0.0,
                    evidenceRowCount: 250,
                    reasonCodes: [
                        "rollup:apr",
                        "review:claude-prim"
                    ])
            ],
            sovereignWarrantRef: "warrant:abc123",
            supersedesBundleVersion: "v1.2.2",
            summary: "April rollup, +medium for high-stake angry")
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(
            BASRiskCalibrationBundle.self, from: data)
        XCTAssertEqual(restored, original)
    }

    // MARK: - 11. ReasonCodes trim + filter empties

    func testReasonCodesTrimAndFilterEmpty() {
        let delta = BASRiskCalibrationStratumDelta(
            stratumKey: "tone=angry",
            reasonCodes: [
                "  rollup:apr  ",
                "",
                "review:claude-prim",
                "   "
            ])
        XCTAssertEqual(
            delta.reasonCodes,
            ["rollup:apr", "review:claude-prim"])
    }

    // MARK: - 12. evidenceRowCount clamp non-negative

    func testEvidenceRowCountClampsNonNegative() {
        let delta = BASRiskCalibrationStratumDelta(
            stratumKey: "tone=angry",
            evidenceRowCount: -100)
        XCTAssertEqual(delta.evidenceRowCount, 0)
    }

    // MARK: - 13. changesAnyThreshold flag

    func testChangesAnyThresholdFlag() {
        let allZero = BASRiskCalibrationStratumDelta(
            stratumKey: "tone=calm")
        XCTAssertFalse(allZero.changesAnyThreshold)

        let nonZero = BASRiskCalibrationStratumDelta(
            stratumKey: "tone=angry",
            mediumThresholdDelta: 0.05)
        XCTAssertTrue(nonZero.changesAnyThreshold)
    }

    // MARK: - 14. supersedesBundleVersion preserved

    func testSupersedesBundleVersionPreserved() {
        let bundle = BASRiskCalibrationBundle(
            bundleVersion: "v2.0.0",
            aggregateProvenanceRef: "agg",
            sovereignWarrantRef: "warrant",
            supersedesBundleVersion: "v1.5.0")
        XCTAssertEqual(
            bundle.supersedesBundleVersion, "v1.5.0")
    }
}
