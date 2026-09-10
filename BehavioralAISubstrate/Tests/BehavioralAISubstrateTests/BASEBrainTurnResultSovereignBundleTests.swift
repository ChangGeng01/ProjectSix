// MARK: - BASEBrainTurnResultSovereignBundleTests
// chapter 五百二十五 / M1477 — sovereign bundle tests

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASEBrainTurnResultSovereignBundleTests:
    XCTestCase
{

    func testEmptyBundleHasZeroPopulatedCount() {
        let bundle =
            BASEBrainTurnResultSovereignBundle()
        XCTAssertEqual(bundle.populatedFieldCount, 0)
        XCTAssertFalse(bundle.hasMinimumSovereignChain)
    }

    func testEmptyMatchesDefaultInit() {
        XCTAssertEqual(
            BASEBrainTurnResultSovereignBundle.empty,
            BASEBrainTurnResultSovereignBundle())
    }

    func testSovereignFieldCountPinnedToEight() {
        XCTAssertEqual(
            BASEBrainTurnResultSovereignBundle
                .sovereignFieldCount,
            8,
            "8 sovereign cluster fields:sovereignVerdict" +
            " + sovereignCommitTokens + sovereignWarrants" +
            " + sovereignLock + quarantineRecords +" +
            " sovereignAuditEntry +" +
            " sovereignActuationCommands +" +
            " sovereignExecutionReceipts")
    }

    func testPopulatedFieldCountCountsArrays() {
        let token = BASSovereignCommitToken(
            tokenID: "tok-1",
            sessionID: "s",
            turnID: "t",
            scope: .toolRead,
            actionDigest: "digest",
            snapshotRef: "snap",
            policyHash: "ph",
            ttlMs: 1000,
            nonce: "n",
            signature: "sig")
        let bundle =
            BASEBrainTurnResultSovereignBundle(
                sovereignCommitTokens: [token])
        XCTAssertEqual(bundle.populatedFieldCount, 1)
    }

    func testEquatableValueEquality() {
        let b1 =
            BASEBrainTurnResultSovereignBundle()
        let b2 =
            BASEBrainTurnResultSovereignBundle()
        XCTAssertEqual(b1, b2)
    }
}
