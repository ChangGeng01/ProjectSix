// MARK: - BASSSMScanFixtureRegistryTests
// chapter 六百七十九 / M2094 第二刀 — anti-drift PROOF tests
//                                    for the Swift-side
//                                    canonical fixture registry

import XCTest
@testable import BASMetalSubstrate

final class BASSSMScanFixtureRegistryTests: XCTestCase {

    typealias R = BASSSMScanFixtureRegistry

    // MARK: - Registry size

    func testFixtureCountIsSix() {
        XCTAssertEqual(R.fixtureCount, 6)
    }

    func testAllFixturesArrayMatchesCount() {
        XCTAssertEqual(
            R.allFixtures.count, R.fixtureCount)
    }

    // MARK: - All fixtures present

    func testAllSixFixturesPresent() {
        let expectedNames = [
            "zero_delta_zero_output",
            "identity_unit_step",
            "two_step_decay",
            "three_step_accumulation",
            "two_channel_independence",
            "two_batch_independence"
        ]
        for name in expectedNames {
            XCTAssertNotNil(
                R.fixture(named: name),
                "fixture '\(name)' must be in registry")
        }
    }

    // MARK: - Fixture-name lookup determinism

    func testLookupByNameReturnsSameInstance() {
        let f1 = R.fixture(named: "identity_unit_step")
        let f2 = R.fixture(named: "identity_unit_step")
        XCTAssertEqual(f1, f2)
    }

    func testUnknownNameReturnsNil() {
        XCTAssertNil(R.fixture(named: "nonexistent_fixture"))
    }

    // MARK: - Per-fixture shape consistency

    func testEveryFixtureInputArrayShapesMatchShape() {
        for fixture in R.allFixtures {
            let bld = fixture.shape.elementCount
            let d = Int(fixture.shape.D)

            XCTAssertEqual(
                fixture.x.count, bld,
                "fixture '\(fixture.name)' x array " +
                "(\(fixture.x.count)) must equal B×L×D " +
                "(\(bld))")
            XCTAssertEqual(
                fixture.delta.count, bld,
                "fixture '\(fixture.name)' delta array " +
                "(\(fixture.delta.count)) must equal " +
                "B×L×D (\(bld))")
            XCTAssertEqual(
                fixture.A.count, d,
                "fixture '\(fixture.name)' A array " +
                "(\(fixture.A.count)) must equal D " +
                "(\(d))")
            XCTAssertEqual(
                fixture.B.count, bld,
                "fixture '\(fixture.name)' B array " +
                "(\(fixture.B.count)) must equal B×L×D " +
                "(\(bld))")
            XCTAssertEqual(
                fixture.C.count, bld,
                "fixture '\(fixture.name)' C array " +
                "(\(fixture.C.count)) must equal B×L×D " +
                "(\(bld))")
            XCTAssertEqual(
                fixture.expectedY.count, bld,
                "fixture '\(fixture.name)' expectedY " +
                "array (\(fixture.expectedY.count)) " +
                "must equal B×L×D (\(bld))")
        }
    }

    // MARK: - Tolerance uniformity

    func testEveryFixtureUsesOneEMinus5Tolerance() {
        for fixture in R.allFixtures {
            XCTAssertEqual(
                fixture.tolerance, 1e-5, accuracy: 1e-10,
                "fixture '\(fixture.name)' must use 1e-5 " +
                "tolerance — tighter requires re-validation, " +
                "looser weakens the proof")
        }
    }

    // MARK: - Non-empty doc-fields

    func testEveryFixtureHasNonEmptyName() {
        for fixture in R.allFixtures {
            XCTAssertFalse(fixture.name.isEmpty)
        }
    }

    func testEveryFixtureHasNonEmptyDescription() {
        for fixture in R.allFixtures {
            XCTAssertFalse(fixture.description.isEmpty)
        }
    }

    func testEveryFixtureHasNonEmptyDerivation() {
        for fixture in R.allFixtures {
            XCTAssertFalse(fixture.derivation.isEmpty)
        }
    }

    // MARK: - Fixture name uniqueness

    func testEveryFixtureNameIsUnique() {
        let names = R.allFixtures.map { $0.name }
        XCTAssertEqual(
            Set(names).count, names.count,
            "fixture names must be globally unique")
    }

    // MARK: - Codable round-trip

    func testFixtureCodableRoundTrip() throws {
        let original = R.fixture02IdentityUnitStep
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASSSMScanFixture.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Individual fixture facts (anti-drift)

    func testFixture01ZeroDeltaShapeIsB1L4D2() {
        let f = R.fixture01ZeroDeltaZeroOutput
        XCTAssertEqual(f.shape.B, 1)
        XCTAssertEqual(f.shape.L, 4)
        XCTAssertEqual(f.shape.D, 2)
    }

    func testFixture02IdentityShape1x1x1() {
        let f = R.fixture02IdentityUnitStep
        XCTAssertEqual(f.shape.B, 1)
        XCTAssertEqual(f.shape.L, 1)
        XCTAssertEqual(f.shape.D, 1)
        XCTAssertEqual(f.expectedY, [2.5])
    }

    func testFixture03DecayHasExpMinus1Output() {
        let f = R.fixture03TwoStepDecay
        XCTAssertEqual(f.expectedY.count, 2)
        XCTAssertEqual(f.expectedY[0], 1.0)
        // exp(-1) ≈ 0.36787944
        XCTAssertEqual(
            f.expectedY[1], 0.36787944, accuracy: 1e-5)
    }

    func testFixture04AccumulationYields246() {
        let f = R.fixture04ThreeStepAccumulation
        XCTAssertEqual(f.expectedY, [2.0, 4.0, 6.0])
    }

    func testFixture05ChannelIndependenceYields1_1() {
        let f = R.fixture05TwoChannelIndependence
        XCTAssertEqual(f.expectedY, [1.0, 1.0])
    }

    func testFixture06BatchIndependenceYields1_7() {
        let f = R.fixture06TwoBatchIndependence
        XCTAssertEqual(f.expectedY, [1.0, 7.0])
    }
}
