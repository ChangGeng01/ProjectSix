// MARK: - BASTurnRuntimeStressFixtureSetFilteringTests
// chapter 四百十二 / M1020

import XCTest
@testable import BASHostKit
@testable import BASPolicy

final class BASTurnRuntimeStressFixtureSetFilteringTests:
    XCTestCase
{

    // MARK: - Risk filter

    func testFilteredByRiskHighReducesToHighOnly() {
        let canonical =
            BASTurnRuntimeStressFixtureSet.canonical60()
        let high = canonical.filtered(byRisk: .high)
        // 60 / 4 risk buckets = 15 fixtures per bucket
        XCTAssertEqual(high.fixtureCount, 15)
        XCTAssertEqual(
            high.uniqueRiskBuckets, Set([.high]))
    }

    func testFilteredByRiskExtremeIsSubsetOfFifteen() {
        let canonical =
            BASTurnRuntimeStressFixtureSet.canonical60()
        let extreme = canonical.filtered(
            byRisk: .extreme)
        XCTAssertEqual(extreme.fixtureCount, 15)
    }

    // MARK: - Permit mode filter

    func testFilteredByPermitModeAnswerReducesTo12() {
        let canonical =
            BASTurnRuntimeStressFixtureSet.canonical60()
        let answer = canonical.filtered(
            byPermitMode: .answer)
        // 60 / 5 permit modes = 12 fixtures per mode
        XCTAssertEqual(answer.fixtureCount, 12)
        XCTAssertEqual(
            answer.uniquePermitModes, Set([.answer]))
    }

    // MARK: - Boolean filters

    func testFilteredByQuarantinesProducesSubset() {
        let canonical =
            BASTurnRuntimeStressFixtureSet.canonical60()
        let withQ = canonical.filtered(
            byQuarantines: true)
        let withoutQ = canonical.filtered(
            byQuarantines: false)
        XCTAssertEqual(
            withQ.fixtureCount + withoutQ.fixtureCount,
            canonical.fixtureCount,
            "the two boolean halves must partition the" +
            " full set")
    }

    func testFilteredByAnchorToneProducesSubset() {
        let canonical =
            BASTurnRuntimeStressFixtureSet.canonical60()
        let withT = canonical.filtered(
            byAnchorTone: true)
        let withoutT = canonical.filtered(
            byAnchorTone: false)
        XCTAssertEqual(
            withT.fixtureCount + withoutT.fixtureCount,
            canonical.fixtureCount)
    }

    func testFilteredByNeuralCoreProducesSubset() {
        let canonical =
            BASTurnRuntimeStressFixtureSet.canonical60()
        let wired = canonical.filtered(
            byNeuralCoreWired: true)
        let unwired = canonical.filtered(
            byNeuralCoreWired: false)
        XCTAssertEqual(
            wired.fixtureCount + unwired.fixtureCount,
            canonical.fixtureCount)
    }

    func testFilteredByEvolutionProducesSubset() {
        let canonical =
            BASTurnRuntimeStressFixtureSet.canonical60()
        let withE = canonical.filtered(
            byEvolutionFeedbackPresent: true)
        let withoutE = canonical.filtered(
            byEvolutionFeedbackPresent: false)
        XCTAssertEqual(
            withE.fixtureCount + withoutE.fixtureCount,
            canonical.fixtureCount)
    }

    // MARK: - Filter name suffix

    func testFilteredSetHasSuffixedName() {
        let canonical =
            BASTurnRuntimeStressFixtureSet.canonical60()
        let high = canonical.filtered(byRisk: .high)
        XCTAssertEqual(
            high.name,
            canonical.name +
                BASTurnRuntimeStressFixtureSet
                    .filteredSuffix)
    }

    // MARK: - Determinism

    func testFilterIsDeterministic() {
        let s = BASTurnRuntimeStressFixtureSet.canonical60()
        let a = s.filtered(byRisk: .high)
        let b = s.filtered(byRisk: .high)
        XCTAssertEqual(a, b)
    }

    // MARK: - Filter is immutable

    func testFilterDoesNotModifyOriginal() {
        let original =
            BASTurnRuntimeStressFixtureSet.canonical60()
        _ = original.filtered(byRisk: .high)
        XCTAssertEqual(original.fixtureCount, 60,
            "filtering must not mutate the original set")
    }
}
