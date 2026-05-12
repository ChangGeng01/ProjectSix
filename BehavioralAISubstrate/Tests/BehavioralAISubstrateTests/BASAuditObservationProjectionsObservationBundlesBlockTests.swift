// MARK: - BASAuditObservationProjectionsObservationBundles
//         BlockTests
// chapter 五百十四 / M1433 — 3rd typed input block tests
//
// PROOF tests for the 11-cognitive-bundle typed input
// block:
//   1. Empty block has zero populated count
//   2. Default-singleton .empty matches empty init
//   3. populatedBundleCount counts up correctly
//   4. hasFullObservationCoverage requires all 11
//   5. hasNoObservationCoverage true only when all nil
//   6. observationBundleCount pinned to 11
//   7. Equatable conformance value equality

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASWorldPrior

final class BASAuditObservationProjectionsObservationBundlesBlockTests:
    XCTestCase
{

    // MARK: - Fixtures

    private func makePresence()
        -> BASPresenceObservationBundle
    {
        return BASPresenceObservationBundle(
            turnID: "t",
            sessionID: "s",
            observations: [],
            emittedAt: Date(
                timeIntervalSince1970: 1_705_000_000))
    }

    private func makeRisk()
        -> BASRiskObservationBundle
    {
        return BASRiskObservationBundle(
            turnID: "t",
            sessionID: "s",
            observations: [],
            emittedAt: Date(
                timeIntervalSince1970: 1_705_000_000))
    }

    // MARK: - 1) Empty block has zero populated count

    func testEmptyBlockHasZeroPopulatedCount() {
        let block =
            BASAuditObservationProjectionsObservationBundlesBlock()
        XCTAssertEqual(block.populatedBundleCount, 0)
        XCTAssertFalse(block.hasFullObservationCoverage)
        XCTAssertTrue(block.hasNoObservationCoverage)
    }

    // MARK: - 2) .empty matches default init

    func testEmptySingletonMatchesDefaultInit() {
        let viaInit =
            BASAuditObservationProjectionsObservationBundlesBlock()
        let viaSingleton =
            BASAuditObservationProjectionsObservationBundlesBlock
                .empty
        XCTAssertEqual(viaInit, viaSingleton)
    }

    // MARK: - 3) populatedBundleCount counts correctly

    func testPopulatedBundleCountCountsCorrectly() {
        let p = makePresence()
        let r = makeRisk()
        let none =
            BASAuditObservationProjectionsObservationBundlesBlock()
        XCTAssertEqual(none.populatedBundleCount, 0)
        let one =
            BASAuditObservationProjectionsObservationBundlesBlock(
                presence: p)
        XCTAssertEqual(one.populatedBundleCount, 1)
        let two =
            BASAuditObservationProjectionsObservationBundlesBlock(
                presence: p,
                risk: r)
        XCTAssertEqual(two.populatedBundleCount, 2)
    }

    // MARK: - 4) hasFullObservationCoverage threshold

    func testHasFullObservationCoverageRequiresAllEleven() {
        // 2-of-11 must NOT be considered full
        let block =
            BASAuditObservationProjectionsObservationBundlesBlock(
                presence: makePresence(),
                risk: makeRisk())
        XCTAssertFalse(
            block.hasFullObservationCoverage)
        XCTAssertEqual(block.populatedBundleCount, 2)
    }

    // MARK: - 5) hasNoObservationCoverage is true at 0

    func testHasNoObservationCoverageThreshold() {
        let none =
            BASAuditObservationProjectionsObservationBundlesBlock()
        XCTAssertTrue(none.hasNoObservationCoverage)
        let one =
            BASAuditObservationProjectionsObservationBundlesBlock(
                presence: makePresence())
        XCTAssertFalse(one.hasNoObservationCoverage)
    }

    // MARK: - 6) observationBundleCount pinned to 11

    /// Anti-drift PROOF: this constant pins the surface
    /// size。 If a future chapter adds a 12th cognitive
    /// observation bundle field to BASAuditObservation
    /// Projections,this constant moves AND the block
    /// gains a matching field,or audit emission
    /// silently loses coverage。
    func testObservationBundleCountPinnedToEleven() {
        XCTAssertEqual(
            BASAuditObservationProjectionsObservationBundlesBlock
                .observationBundleCount,
            11,
            "Cognitive observation bundle count must" +
            " match BASAuditObservationProjections" +
            " cognitive-bundle field count")
    }

    // MARK: - 7) Equatable value equality

    func testEquatableValueEquality() {
        let p = makePresence()
        let b1 =
            BASAuditObservationProjectionsObservationBundlesBlock(
                presence: p,
                risk: makeRisk())
        let b2 =
            BASAuditObservationProjectionsObservationBundlesBlock(
                presence: p,
                risk: makeRisk())
        XCTAssertEqual(b1, b2)
        let b3 =
            BASAuditObservationProjectionsObservationBundlesBlock(
                presence: p)
        XCTAssertNotEqual(b1, b3)
    }
}
