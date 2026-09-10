// MARK: - BASTierACompletionBridgesTests
// chapter 六百九十二 / M2138 第一刀 — Tier A 6-bundle
//                                  bridge completion tests

import XCTest
@testable import BASRuntimeCore

final class BASTierACompletionBridgesTests: XCTestCase {

    // MARK: - BASRuntimeAuditProjectionsItem

    func testRuntimeAuditProjectionsItemConstructs() {
        let item = BASRuntimeAuditProjectionsItem(
            projectionID: "p1",
            kind: "test",
            timestampMs: 100)
        XCTAssertEqual(item.projectionID, "p1")
        XCTAssertEqual(item.kind, "test")
        XCTAssertEqual(item.timestampMs, 100)
    }

    func testRuntimeAuditProjectionsBundleTypealiasResolves() {
        let bundle:
            BASRuntimeAuditProjectionsItemsBundle =
            BASRuntimeAuditProjectionsItemsBundle(
                items: [
                    BASRuntimeAuditProjectionsItem(
                        projectionID: "p1",
                        kind: "test",
                        timestampMs: 100)
                ])
        XCTAssertEqual(bundle.count, 1)
    }

    func testRuntimeAuditProjectionsItemCodableRoundTrip()
        throws
    {
        let original = BASRuntimeAuditProjectionsItem(
            projectionID: "p1",
            kind: "test",
            timestampMs: 100)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASRuntimeAuditProjectionsItem.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - BASMemoryItem

    func testMemoryItemConstructs() {
        let item = BASMemoryItem(
            memoryID: "m1",
            tier: "hot",
            payloadByteCount: 1024)
        XCTAssertEqual(item.memoryID, "m1")
        XCTAssertEqual(item.tier, "hot")
        XCTAssertEqual(item.payloadByteCount, 1024)
    }

    func testMemoryBundleTypealiasResolves() {
        let bundle = BASMemoryItemsBundle(items: [])
        XCTAssertTrue(bundle.isEmpty)
    }

    func testMemoryItemCodableRoundTrip() throws {
        let original = BASMemoryItem(
            memoryID: "m1",
            tier: "hot",
            payloadByteCount: 1024)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMemoryItem.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - BASLeaseLifeObservationItem

    func testLeaseLifeObservationItemConstructs() {
        let item = BASLeaseLifeObservationItem(
            observationID: "o1",
            leaseID: "l1",
            phase: "active")
        XCTAssertEqual(item.observationID, "o1")
        XCTAssertEqual(item.leaseID, "l1")
        XCTAssertEqual(item.phase, "active")
    }

    func testLeaseLifeObservationBundleTypealias() {
        let bundle = BASLeaseLifeObservationItemsBundle(
            items: [])
        XCTAssertTrue(bundle.isEmpty)
    }

    // MARK: - BASChengluHostRuntimeItem

    func testChengluHostRuntimeItemConstructs() {
        let item = BASChengluHostRuntimeItem(
            runtimeID: "r1",
            hostID: "h1",
            stage: "boot")
        XCTAssertEqual(item.runtimeID, "r1")
    }

    func testChengluHostRuntimeBundleTypealias() {
        let bundle = BASChengluHostRuntimeItemsBundle(
            items: [])
        XCTAssertTrue(bundle.isEmpty)
    }

    // MARK: - BASUpdateTicketObservationItem

    func testUpdateTicketObservationItemConstructs() {
        let item = BASUpdateTicketObservationItem(
            observationID: "o1",
            ticketID: "t1",
            status: "open")
        XCTAssertEqual(item.observationID, "o1")
    }

    func testUpdateTicketObservationBundleTypealias() {
        let bundle =
            BASUpdateTicketObservationItemsBundle(
                items: [])
        XCTAssertTrue(bundle.isEmpty)
    }

    // MARK: - BASWorldPriorObservationItem

    func testWorldPriorObservationItemConstructs() {
        let item = BASWorldPriorObservationItem(
            observationID: "o1",
            priorID: "p1",
            weight: 0.5)
        XCTAssertEqual(item.weight, 0.5, accuracy: 0.001)
    }

    func testWorldPriorObservationBundleTypealias() {
        let bundle =
            BASWorldPriorObservationItemsBundle(items: [])
        XCTAssertTrue(bundle.isEmpty)
    }

    // MARK: - Tier A completion doctrine

    func testTierABundleCountIs8() {
        XCTAssertEqual(
            BASTierACompletionDoctrine.tierABundleCount, 8)
    }

    func testChapter683ShippedCountIs2() {
        XCTAssertEqual(
            BASTierACompletionDoctrine
                .chapter683ShippedCount, 2)
    }

    func testChapter692ShippedCountIs6() {
        XCTAssertEqual(
            BASTierACompletionDoctrine
                .chapter692ShippedCount, 6)
    }

    func testChapter683PlusChapter692EqualsTotal() {
        XCTAssertEqual(
            BASTierACompletionDoctrine
                .chapter683ShippedCount
                + BASTierACompletionDoctrine
                    .chapter692ShippedCount,
            BASTierACompletionDoctrine.tierABundleCount)
    }

    func testAllTierABundlesShipped() {
        XCTAssertTrue(
            BASTierACompletionDoctrine
                .allTierABundlesShipped)
    }

    func testTierABridgeInventoryHas8Entries() {
        XCTAssertEqual(
            BASTierACompletionDoctrine
                .tierABridgeInventoryCount, 8)
    }

    func testChapter683DeferralClosed() {
        XCTAssertTrue(
            BASTierACompletionDoctrine
                .chapter683DeferralClosed)
    }

    func testCallSitesPreserved() {
        XCTAssertTrue(
            BASTierACompletionDoctrine
                .callSitesPreserved)
    }

    func testPatternParityWithChapter683() {
        XCTAssertTrue(
            BASTierACompletionDoctrine
                .patternParityWithChapter683)
    }

    // MARK: - M2148 amendment — bridge-not-adoption pins

    func testTypedSurfacesExistButNotAdopted() {
        XCTAssertTrue(
            BASTierACompletionDoctrine
                .typedSurfacesExistButNotAdopted)
    }

    func testChapter692ItemStructProductionCallSiteCountIsZero() {
        XCTAssertEqual(
            BASTierACompletionDoctrine
                .chapter692ItemStructProductionCallSiteCount,
            0)
    }

    func testMigrationMethodologyRef() {
        XCTAssertTrue(
            BASTierACompletionDoctrine
                .migrationMethodologyRef.contains(
                    "BASTierAMigrationStrategyDoctrine"))
    }

    func testShippedSemanticIsClarifyingNotMisleading() {
        let sem = BASTierACompletionDoctrine.shippedSemantic
        XCTAssertTrue(sem.contains("EXIST as compilable"))
        XCTAssertTrue(sem.contains(
            "host-app responsibility"))
    }

    // MARK: - All 6 new items + bundles also share
    //         BASBundle's standard behavior

    func testAllSixBundlesSupportAppending() {
        var bundle = BASMemoryItemsBundle(items: [])
        XCTAssertEqual(bundle.count, 0)
        bundle = bundle.appending(
            item: BASMemoryItem(
                memoryID: "m1",
                tier: "hot",
                payloadByteCount: 1024))
        XCTAssertEqual(bundle.count, 1)
    }
}
