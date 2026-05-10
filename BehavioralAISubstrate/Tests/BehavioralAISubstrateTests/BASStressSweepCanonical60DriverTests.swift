// MARK: - BASStressSweepCanonical60DriverTests
// chapter 四百三十四 / M1112

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASStressSweepCanonical60DriverTests:
    XCTestCase
{

    // MARK: - Canonical fixture set shape

    func testCanonicalSetNamePinned() {
        XCTAssertEqual(
            BASStressSweepCanonical60Driver
                .canonicalSetName,
            "canonical-60")
    }

    func testCanonicalSetVersionPinned() {
        XCTAssertEqual(
            BASStressSweepCanonical60Driver
                .canonicalSetVersion,
            "1.0.0")
    }

    func testFixtureCountIsExactly60() {
        let set = BASStressSweepCanonical60Driver
            .canonicalFixtureSet()
        XCTAssertEqual(set.fixtureCount, 60,
            "Driver name claims '60' — must produce" +
            " exactly 60 typed keys")
    }

    func testKeyExpansionIsDeterministic() {
        let a = BASStressSweepCanonical60Driver
            .canonicalKeyExpansion()
        let b = BASStressSweepCanonical60Driver
            .canonicalKeyExpansion()
        XCTAssertEqual(a, b,
            "Cartesian product builder must be" +
            " deterministic (chapter 三百九二)")
    }

    // MARK: - Dimension coverage

    func testCoversAllThreeRisksUsedInBaseSet() {
        let set = BASStressSweepCanonical60Driver
            .canonicalFixtureSet()
        XCTAssertEqual(
            set.uniqueRiskBuckets.count, 3,
            "canonical60 covers low/medium/high" +
            " (.extreme reserved for separate" +
            " boundary-stress sweeps)")
    }

    func testCoversBothPermitModesUsedInBaseSet() {
        let set = BASStressSweepCanonical60Driver
            .canonicalFixtureSet()
        XCTAssertEqual(
            set.uniquePermitModes.count, 2,
            "canonical60 covers answer + delay")
    }

    func testCoversBothNeuralCoreStates() {
        let keys = BASStressSweepCanonical60Driver
            .canonicalKeyExpansion()
        let neuralWired = keys.filter {
            $0.neuralCoreWired
        }.count
        let neuralUnwired = keys.filter {
            !$0.neuralCoreWired
        }.count
        XCTAssertEqual(neuralWired, 48,
            "Base set: 3×2×2×2×2 = 48 keys with neural")
        XCTAssertEqual(neuralUnwired, 12,
            "Boundary: 3×2×2 = 12 keys without neural")
    }

    // MARK: - Identity stub runner end-to-end

    func testIdentitySweepReportsAllPass() async {
        let report = await BASStressSweepCanonical60Driver
            .runIdentitySweep()
        XCTAssertEqual(report.results.count, 60,
            "Sweep must produce one verdict per fixture")
        let passing = report.results.filter {
            $0.isPass
        }.count
        XCTAssertEqual(passing, 60,
            "Identity stub returns byte-identical" +
            " V1+V2 → all 60 fixtures must report pass")
    }

    func testIdentitySweepIsDeterministic() async {
        let r1 = await BASStressSweepCanonical60Driver
            .runIdentitySweep()
        let r2 = await BASStressSweepCanonical60Driver
            .runIdentitySweep()
        XCTAssertEqual(
            r1.results.map { $0.key },
            r2.results.map { $0.key },
            "fixture order must be deterministic")
        XCTAssertEqual(
            r1.results.map { $0.isPass },
            r2.results.map { $0.isPass },
            "verdicts must be deterministic")
    }

    // MARK: - Divergence stub runner end-to-end

    func testDivergenceSweepReportsAllFail() async {
        let report = await BASStressSweepCanonical60Driver
            .runDivergenceSweep()
        XCTAssertEqual(report.results.count, 60)
        let failing = report.results.filter {
            !$0.isPass
        }.count
        XCTAssertEqual(failing, 60,
            "Deterministic +1 divergence → all 60" +
            " fixtures must report fail (proves" +
            " harness fails closed)")
    }

    // MARK: - Set version + name surface forwarded

    func testSetCarriesPinnedNameAndVersion() {
        let set = BASStressSweepCanonical60Driver
            .canonicalFixtureSet()
        XCTAssertEqual(set.name, "canonical-60")
        XCTAssertEqual(set.setVersion, "1.0.0")
    }
}
