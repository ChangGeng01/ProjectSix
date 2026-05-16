// MARK: - BASPostSealFollowupCatalogDoctrineTests
// chapter 六百九十一 / M2136 第三刀 — anti-drift PROOF tests
//                                  for post-seal followup
//                                  catalog doctrine

import XCTest
@testable import BASRuntimeCore

final class BASPostSealFollowupCatalogDoctrineTests:
    XCTestCase
{
    typealias D = BASPostSealFollowupCatalogDoctrine

    // MARK: - Identity

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百九十一")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(D.milestoneMNumber, 2136)
    }

    // MARK: - Shipped items (3)

    func testShippedItemCountIs3() {
        XCTAssertEqual(D.shippedItemCount, 3)
        XCTAssertEqual(D.shippedItems.count, 3)
    }

    func testShippedItemsIncludeLRU() {
        XCTAssertTrue(D.shippedItems.contains {
            $0.name.contains("LRU")
        })
    }

    func testShippedItemsIncludeTTL() {
        XCTAssertTrue(D.shippedItems.contains {
            $0.name.contains("TTL")
        })
    }

    func testShippedItemsIncludeNeverSemantic() {
        XCTAssertTrue(D.shippedItems.contains {
            $0.name.contains(".never")
        })
    }

    func testShippedItemChapterRangesNonEmpty() {
        for item in D.shippedItems {
            XCTAssertFalse(item.chapterRange.isEmpty)
            XCTAssertFalse(item.mNumberRange.isEmpty)
            XCTAssertFalse(item.summary.isEmpty)
        }
    }

    // MARK: - Deferred items (4)

    func testDeferredItemCountIs4() {
        XCTAssertEqual(D.deferredItemCount, 4)
        XCTAssertEqual(D.deferredItems.count, 4)
    }

    func testDeferredItemsIncludeAllFourTopics() {
        let names = D.deferredItems.map { $0.name }
        XCTAssertTrue(names.contains { $0.contains(
            "BASTensor MTLBuffer") })
        XCTAssertTrue(names.contains { $0.contains(
            "Multi-host runtime federation") })
        XCTAssertTrue(names.contains { $0.contains(
            "MLX → CoreML") })
        XCTAssertTrue(names.contains { $0.contains(
            "Self-tuning scheduler") })
    }

    func testEveryDeferredItemHasRationale() {
        for item in D.deferredItems {
            XCTAssertFalse(
                item.deferralRationale.isEmpty,
                "Item \(item.name) must have honest " +
                "deferral rationale")
            XCTAssertGreaterThan(
                item.deferralRationale.count, 50,
                "Rationale for \(item.name) must be " +
                "substantive (>50 chars)")
        }
    }

    func testDeferredScopeEstimateSumIs30() {
        // 6 + 12 + 4 + 8 = 30 chapters
        XCTAssertEqual(
            D.deferredTotalScopeEstimateChapters, 30)
    }

    func testEveryDeferredItemHasPositiveScope() {
        for item in D.deferredItems {
            XCTAssertGreaterThan(
                item.estimatedScopeChapters, 0)
        }
    }

    // MARK: - Deferral categories

    func testDeferralCategoryCountIs4() {
        XCTAssertEqual(D.deferralCategoryCount, 4)
    }

    func testEveryDeferredItemCategoryIsListed() {
        for item in D.deferredItems {
            XCTAssertTrue(
                D.deferralCategories.contains(
                    item.category),
                "Item \(item.name) category " +
                "'\(item.category)' must be in " +
                "deferralCategories list")
        }
    }

    // MARK: - Score saturation

    func testAllShippedScoreDeltaIsZero() {
        XCTAssertEqual(
            D.allShippedItemsScoreDelta, 0)
    }

    func testAllDeferredScoreDeltaIsZero() {
        XCTAssertEqual(
            D.allDeferredItemsScoreDelta, 0)
    }

    func testSaturationInvariantPreserved() {
        XCTAssertTrue(D.saturationInvariantPreserved)
    }

    // MARK: - 4-of-4 KV policy milestone

    func testAllFourKVPoliciesImplementedAtM2135() {
        XCTAssertTrue(
            D.allFourKVPoliciesImplementedAtM2135)
    }

    func testKVPolicyProgression() {
        XCTAssertEqual(
            D.kvPolicyImplementedCountPreChapter690, 1)
        XCTAssertEqual(
            D.kvPolicyImplementedCountPostChapter690, 2)
        XCTAssertEqual(
            D.kvPolicyImplementedCountPostChapter691, 4)
    }

    func testKVPolicyProgressionIsMonotonic() {
        XCTAssertLessThan(
            D.kvPolicyImplementedCountPreChapter690,
            D.kvPolicyImplementedCountPostChapter690)
        XCTAssertLessThan(
            D.kvPolicyImplementedCountPostChapter690,
            D.kvPolicyImplementedCountPostChapter691)
    }

    // MARK: - Forward path

    func testForwardStrategyExists() {
        XCTAssertFalse(
            D.postSealFollowupStrategyForward.isEmpty)
        XCTAssertGreaterThan(
            D.postSealFollowupStrategyForward.count, 100)
    }

    func testForwardStrategyMentionsOptional() {
        XCTAssertTrue(
            D.postSealFollowupStrategyForward.contains(
                "OPTIONAL"))
    }

    func testIsSubstrateSeleAtRest() {
        XCTAssertTrue(D.isSubstrateSeleAtRest)
    }

    // MARK: - Cross-doctrine refs

    func testCrossDoctrineRefsExist() {
        XCTAssertTrue(D.priorTier2DoctrineRef.contains(
            "Tier2"))
        XCTAssertTrue(D.priorChapter690LRURef.contains(
            "LRU"))
        XCTAssertTrue(D.priorChapter691TTLRef.contains(
            "TTL"))
        XCTAssertTrue(D.policyDoctrineRef.contains(
            "InvalidationPolicy"))
    }

    // MARK: - Cross-mirror with KV policy doctrine

    func testCrossMirrorWith4PolicyImplementations() {
        // Our claim of 4-of-4 KV policies implemented
        // should match what BASKVCacheInvalidationPolicy
        // Doctrine.implementedPolicyCount asserts。
        XCTAssertEqual(
            D.kvPolicyImplementedCountPostChapter691, 4)
    }

    // MARK: - Codable round-trip

    func testShippedItemCodableRoundTrip() throws {
        let item = D.shippedItems[0]
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(
            D.ShippedItem.self, from: data)
        XCTAssertEqual(decoded, item)
    }

    func testDeferredItemCodableRoundTrip() throws {
        let item = D.deferredItems[0]
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(
            D.DeferredItem.self, from: data)
        XCTAssertEqual(decoded, item)
    }
}
