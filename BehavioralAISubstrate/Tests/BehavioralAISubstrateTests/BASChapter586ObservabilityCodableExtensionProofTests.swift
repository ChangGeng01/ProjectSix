// MARK: - BASChapter586ObservabilityCodableExtensionProofTests
// chapter 五百八十六 / M1722 — PROOF tests for the 2
//                          newly-Codable BAS
//                          Observability types shipped
//                          at M1721 (first-ever BAS
//                          Observability Codable
//                          extension)
//
// ## Coverage (2 compile-time conformance tests)
//
// First-ever BASObservability Codable extension。
// Opens module #6 territory (after BASHostKit +
// BASRuntimeCore + BASMemory + BASOrchestration +
// BASLeaseLife)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1721 → M1722

import XCTest
import Foundation
@testable import BASObservability

final class BASChapter586ObservabilityCodableExtensionProofTests:
    XCTestCase
{

    func testUnifiedStorageLocatorLocationsConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASUnifiedStorageLocator.Locations(
                root: URL(fileURLWithPath: "/"),
                auditLedgerURL: URL(fileURLWithPath: "/"),
                lifecycleURL: URL(fileURLWithPath: "/")))
    }

    func testCheckpointResultConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASUpdateTicketLifecycleSQLiteStorage.CheckpointResult(
                wasBusy: false,
                walFramesAtStart: 0,
                framesMerged: 0))
    }
}
