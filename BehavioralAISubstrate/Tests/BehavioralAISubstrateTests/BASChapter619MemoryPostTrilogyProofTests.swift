// MARK: - BASChapter619MemoryPostTrilogyProofTests
// chapter 六百一十九 / M1854 — PROOF tests for the M1853
//                              BASMemory Codable
//                              extension post-trilogy
//                              gap-fill
//
// ## Coverage (3 compile-time conformance tests)
//
// BASMemory post-trilogy gap-fill — 3 types:
//
//   - BASEventSourcedMemoryAtomStoreCachePolicy (3-case
//     enum with Int associated value)
//   - BASMemoryTieringReconciliationOutcome (9-field
//     struct)
//   - BASMemoryTieringReconcilerOrdering (3-case enum,
//     no associated values)
//
// FIFTH post-hexa-catalog gap-fill chapter (615 + 616
// + 617 + 618 + 619)。 First non-BASOrgan post-hexa
// gap-fill (diversifying the run)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 590 BASMemory post-cross-module-arc
//     trilogy seal precedent
//   - chapter 614 gap-fill hexa catalog precedent
//   - chapter 615-618 prior post-hexa precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1853 → M1854

import XCTest
@testable import BASMemory

final class BASChapter619MemoryPostTrilogyProofTests:
    XCTestCase
{

    func testEventSourcedMemoryAtomStoreCachePolicyConformsToCodable() {
        // #18: real round-trip (non-CaseIterable enum, representative cases)
        assertCodableRoundTrips(
            BASEventSourcedMemoryAtomStoreCachePolicy.lazy)
        assertCodableRoundTrips(
            BASEventSourcedMemoryAtomStoreCachePolicy
                .cachedWithTTL(seconds: 0))
    }

    func testMemoryTieringReconciliationOutcomeConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASMemoryTieringReconciliationOutcome(
                evaluatedCount: 0,
                heldCount: 0,
                promotedCount: 0,
                demotedCount: 0,
                quarantineSuggestedCount: 0,
                evictSuggestedCount: 0,
                decisions: [],
                startedAt: Date(timeIntervalSince1970: 0),
                completedAt: Date(timeIntervalSince1970: 0)))
    }

    func testMemoryTieringReconcilerOrderingConformsToCodable() {
        // #18: real round-trip (non-CaseIterable enum, representative cases)
        assertCodableRoundTrips(
            BASMemoryTieringReconcilerOrdering.insertionOrder)
        assertCodableRoundTrips(
            BASMemoryTieringReconcilerOrdering.highestHeatFirst)
    }
}
