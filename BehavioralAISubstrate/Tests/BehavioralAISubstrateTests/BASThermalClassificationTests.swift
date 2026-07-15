import XCTest
@testable import BASRuntimeCore

/// x-arch MED-1 (mega-audit #15, 2026-07-08): the loosely-typed `BASDeviceProfile.thermalState`
/// String is fed three vocabularies by different producers. These gates pin the canonical
/// classification: recognized thermal words route by real severity; the BASThermalLevel "hot"
/// word (which the old substring match missed) now downgrades; known non-thermal producer
/// strings do NOT falsely downgrade; and a genuinely unknown string fails CLOSED (serious),
/// not open — the exact bug that let an overheating device be decided as cool.
final class BASThermalClassificationTests: XCTestCase {

    // MARK: - severity ordering

    func testSeverityIsMonotonic() {
        XCTAssertLessThan(BASThermalBucket.nominal.severity, BASThermalBucket.fair.severity)
        XCTAssertLessThan(BASThermalBucket.fair.severity, BASThermalBucket.serious.severity)
        XCTAssertLessThan(BASThermalBucket.serious.severity, BASThermalBucket.critical.severity)
    }

    // MARK: - thermal vocabulary recognition (Bucket + Level + Darwin)

    func testBucketVocabularyParses() {
        XCTAssertEqual(BASThermalBucket.thermalSeverity(from: "nominal"), .nominal)
        XCTAssertEqual(BASThermalBucket.thermalSeverity(from: "fair"), .fair)
        XCTAssertEqual(BASThermalBucket.thermalSeverity(from: "serious"), .serious)
        XCTAssertEqual(BASThermalBucket.thermalSeverity(from: "critical"), .critical)
    }

    func testThermalLevelVocabularyMapsToBucket() {
        // The crux: BASThermalLevel {nominal, warm, hot, critical} — "hot" is thermally
        // serious but the old consumer's substring match for "serious" MISSED it.
        XCTAssertEqual(BASThermalBucket.thermalSeverity(from: "warm"), .fair)
        XCTAssertEqual(BASThermalBucket.thermalSeverity(from: "hot"), .serious)
        XCTAssertEqual(BASThermalLevel_Bridge.bucket(forThermalLevelRawValue: "hot"), .serious)
        XCTAssertEqual(BASThermalLevel_Bridge.bucket(forThermalLevelRawValue: "warm"), .fair)
    }

    func testCaseAndWhitespaceInsensitive() {
        XCTAssertEqual(BASThermalBucket.thermalSeverity(from: "  CRITICAL "), .critical)
        XCTAssertEqual(BASThermalBucket.thermalSeverity(from: "Hot"), .serious)
    }

    // MARK: - classification routing

    func testHotDowngradesForHeat() {
        // Regression for the fail-open: a "hot" device MUST now downgrade.
        XCTAssertTrue(BASThermalClassification.classify("hot").shouldDowngradeForHeat)
        XCTAssertTrue(BASThermalClassification.classify("serious").shouldDowngradeForHeat)
        XCTAssertTrue(BASThermalClassification.classify("critical").shouldDowngradeForHeat)
    }

    func testCoolStatesDoNotDowngrade() {
        XCTAssertFalse(BASThermalClassification.classify("nominal").shouldDowngradeForHeat)
        XCTAssertFalse(BASThermalClassification.classify("fair").shouldDowngradeForHeat)
        XCTAssertFalse(BASThermalClassification.classify("warm").shouldDowngradeForHeat)
    }

    func testKnownNonThermalProducerStringsDoNotFalselyDowngrade() {
        // The actual production producers push environmentClass rawValues + a power flag
        // into thermalState. These carry NO thermal signal, so they must NOT downgrade
        // (that would be over-conservative) — but they must be RECOGNIZED, not fall into
        // the fail-closed path meant for genuinely-unknown strings.
        for s in ["normal", "lowPower", "low_power", "memoryConstrained", "simulator", "nominal", ""] {
            let c = BASThermalClassification.classify(s)
            XCTAssertFalse(c.shouldDowngradeForHeat, "\(s) must not downgrade")
            if !s.isEmpty && s.lowercased() != "nominal" {
                XCTAssertEqual(c, .nonThermalNominal(s), "\(s) should classify as known non-thermal")
            }
        }
    }

    func testUnknownStringFailsClosed() {
        // The safety core: a string that is NEITHER a thermal reading NOR a known producer
        // value must fail CLOSED (route as serious) — an overheating device with a novel
        // thermal vocabulary must never be decided as cool.
        let c = BASThermalClassification.classify("xyzzy-unheard-of")
        XCTAssertEqual(c, .unrecognized("xyzzy-unheard-of"))
        XCTAssertTrue(c.shouldDowngradeForHeat, "unknown thermal state must fail closed (downgrade)")
        XCTAssertEqual(c.routingSeverity, .serious)
    }
}
